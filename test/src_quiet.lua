-- Own-whisper notices: real Wire, real Main event dispatch, synthetic client chat frames.
local T=...
local test,eq,yes,no=T.test,T.eq,T.yes,T.no
local FORMAT='No player named "%s" is currently playing.'
local function setup(saved,api)
    local registrations,filter=0,nil
    ChatFrame_AddMessageEventFilter=api or function(event,fn)
        eq(event,"CHAT_MSG_SYSTEM"); registrations=registrations+1; filter=fn
    end
    local N=T.load(saved)
    ChatFrame_AddMessageEventFilter=nil
    N.Net.SHIP.hh=true; N.Net.SHIP.we=true
    ERR_CHAT_PLAYER_NOT_FOUND_S=FORMAT
    return N,function() return filter,registrations end
end
local function send(N,name)
    return N.Wire.send("HeadHunter","1AN:LayerEnemies","WHISPER",name,{net="hh",prio="mesh"})
end
local function text(name) return string.format(FORMAT,name) end
local function tick(n) T.clock(T.clock()+n) end
-- CHAT_MSG_SYSTEM has text at arg1 and lineID at arg11. Other payload is deliberately inert.
local function filterLine(filter,frame,msg,id,event)
    return filter(frame,event or "CHAT_MSG_SYSTEM",msg,"","","","","",0,0,"",0,id)
end
local function eventLine(msg,id)
    T.deliver("CHAT_MSG_SYSTEM",msg,"","","","","",0,0,"",0,id)
end
local function marks(N)
    local count=0; local real=N.Wire.markOffline
    N.Wire.markOffline=function(...) count=count+1; return real(...) end
    return function() return count end
end
local function countLine(expected,others)
    local start=#T.log()
    SlashCmdList.LAYERENEMIES("net")
    local seen=0
    local needle="hidden (LayerEnemies whispers): "..expected..";"
    -- Preserve the old uncorrelated-evidence assertions independently of the new
    -- UI's shown counter (which also counts our own notices when the mode is off).
    if others~=nil then eq(LayerEnemies.Wire.unmatchedNotices(),others) end
    for i=start+1,#T.log() do
        if T.log()[i]:find(needle,1,true) then seen=seen+1 end
    end
    eq(seen,1,"/le net counter")
end

test("Quiet names: spaced home name is recorded and matched without compacting",function()
    local N=setup()
    yes(send(N,"First Surname-TestRealm")); eq(T.sent()[1].target,"First Surname")
    no(N.Wire.system(text("FirstSurname")))
    eq(N.Wire.system(text("First Surname")),"first surname")
    eq(N.Wire.offlineUntil("First Surname-TestRealm",T.clock()),T.clock()+3600)
end)
test("Quiet names: foreign suffix is required and distinct namesakes stay ambiguous",function()
    local N=setup()
    yes(send(N,"First Surname-7105")); eq(T.sent()[1].target,"First Surname-7105")
    no(N.Wire.system(text("First Surname")))
    tick(3); yes(send(N,"First Surname"))
    no(N.Wire.system(text("First Surname")))
    eq(N.Wire.system(text("First Surname-7105")),"first surname-7105")
    no(N.Wire.system(text("First Surname")),"consumed namesake still prevents guessing")
    eq(N.Wire.system(text("First Surname-TestRealm")),"first surname")
end)
test("Quiet names: pattern characters in a surname are invalid targets not wildcard matches",function()
    local N=setup()
    for _,name in ipairs({"First Sur.name","First Sur%name","First Sur[name]","First Sur+name"}) do
        local ok,why,called=send(N,name)
        no(ok); eq(why,"bad text"); no(called); no(N.Wire.system(text(name)))
    end
    eq(#T.sent(),0)
    yes(send(N,"First Surname")); no(N.Wire.system(text("First Sur.name")))
    eq(N.Wire.system(text("First Surname")),"first surname")
end)

test("Quiet: own localized failure is hidden by a once-registered filter",function()
    local N,registered=setup()
    local filter,count=registered(); eq(count,1,"one filter registered at startup"); eq(type(filter),"function")
    T.deliver("PLAYER_LOGIN"); N.Main.start(); local _,again=registered(); eq(again,1)
    local extra=0; ChatFrame_AddMessageEventFilter=function() extra=extra+1 end
    N.Wire.registerSystemFilter(); ChatFrame_AddMessageEventFilter=nil; eq(extra,0,"even a direct repeat cannot register twice")
    yes(send(N,"First Surname"))
    yes(filter({},"CHAT_MSG_SYSTEM",text("First Surname")),"hide our failure")
    eq(N.Wire.offlineUntil("First Surname",T.clock()),T.clock()+3600)
    eq(#T.sent(),1,"filter sends nothing")
end)

test("Quiet: lineID hides three chat frames once in either dispatcher order",function()
    for _,eventFirst in ipairs({true,false}) do
        local N,registered=setup(); local filter=registered(); local marked=marks(N)
        yes(send(N,"First Surname")); local msg=text("First Surname")
        if eventFirst then eventLine(msg,101) end
        yes(filterLine(filter,{},msg,101))
        no(filterLine(filter,{},text("Unknown Person"),102))
        -- A distinct ID is another line even within the same tick.
        no(filterLine(filter,{},msg,103),"one attempt cannot hide a different line")
        for i=2,3 do yes(filterLine(filter,{},msg,101),"same line in frame "..i) end
        if not eventFirst then eventLine(msg,101) end
        eq(marked(),1,"one mark, not one per frame/event handler")
        tick(.01); no(filterLine(filter,{},msg,104)); eventLine(msg,104)
        eq(marked(),1); no(N.Main.error)
    end
end)
test("Quiet: missing lineID deduplicates only this tick, not a later identical failure",function()
    for _,eventFirst in ipairs({true,false}) do
        local N,registered=setup(); local filter=registered(); local marked=marks(N)
        yes(send(N,"First Surname")); local msg=text("First Surname")
        if eventFirst then eventLine(msg) end
        for i=1,3 do yes(filterLine(filter,{},msg),"same-tick frame "..i) end
        if not eventFirst then eventLine(msg) end
        eq(marked(),1)
        tick(.001); no(filterLine(filter,{},msg)); eventLine(msg); eq(marked(),1)
    end
end)

test("Quiet: saved mode defaults on and off never disables offline bookkeeping",function()
    local N,registered=setup(); local filter=registered(); local marked=marks(N)
    eq(LayerEnemiesDB.quietWhispers,"on"); countLine(0)
    SlashCmdList.LAYERENEMIES("quiet off"); eq(LayerEnemiesDB.quietWhispers,"off")
    yes(T.log()[#T.log()]:find("quiet off",1,true),"visible switch feedback")
    yes(send(N,"First Surname")); eventLine(text("First Surname"),201)
    for i=1,3 do no(filterLine(filter,{},text("First Surname"),201)) end
    eq(marked(),1); countLine(0)
    SlashCmdList.LAYERENEMIES("quiet on"); eq(LayerEnemiesDB.quietWhispers,"on")
    yes(T.log()[#T.log()]:find("quiet on",1,true))
    no(filterLine(filter,{},text("First Surname"),201),"off decision stays shown for this line")
    tick(.01); no(filterLine(filter,{},text("First Surname"),202),"off also consumed the attempt")
    tick(3); yes(send(N,"Second Surname"))
    for i=1,3 do yes(filterLine(filter,{},text("Second Surname"),203)) end
    eventLine(text("Second Surname"),203); countLine(1); eq(marked(),2)
    local saved=LayerEnemiesDB
    N,registered=setup(saved); eq(LayerEnemiesDB.quietWhispers,"on"); countLine(0)
    SlashCmdList.LAYERENEMIES("quiet off"); saved=LayerEnemiesDB
    N,registered=setup(saved); eq(LayerEnemiesDB.quietWhispers,"off"); countLine(0)
    SlashCmdList.LAYERENEMIES("quiet maybe"); eq(LayerEnemiesDB.quietWhispers,"off")
    yes(T.log()[#T.log()]:find("/le quiet on|off",1,true))
end)
test("Quiet: hidden counter counts lines, not chat frames or observer-only events",function()
    local N,registered=setup(); local filter=registered(); yes(send(N,"First Surname"))
    eventLine(text("First Surname"),301); countLine(0)
    for i=1,3 do yes(filterLine(filter,{},text("First Surname"),301)) end
    countLine(1); tick(1); no(filterLine(filter,{},text("First Surname"),302)); countLine(1)
    eq(#T.sent(),1)
end)
test("Quiet: unmatched localized notices count once per line, never by chat frame",function()
    for _,eventFirst in ipairs({true,false}) do
        local N,registered=setup(); local filter=registered(); local msg=text("Other Person")
        if eventFirst then eventLine(msg,401) end
        for i=1,3 do no(filterLine(filter,{},msg,401)) end
        if not eventFirst then eventLine(msg,401) end
        countLine(0,1)
        -- A later identical line is another notice; quiet off still counts.
        SlashCmdList.LAYERENEMIES("quiet off"); tick(.01); eventLine(msg,402)
        no(filterLine(filter,{},msg,402)); countLine(0,2)
        yes(send(N,"First Surname")); eventLine(text("First Surname"),403)
        no(filterLine(filter,{},text("First Surname"),403)); countLine(0,2)
        eventLine("Some other system announcement",404); eventLine(T.secret,405)
        ERR_CHAT_PLAYER_NOT_FOUND_S=nil; eventLine(msg,406); countLine(0,2)
        ERR_CHAT_PLAYER_NOT_FOUND_S=FORMAT
        eventLine(text("First Sur.name"),407); countLine(0,3)
        local saved=LayerEnemiesDB; N,registered=setup(saved); countLine(0,0)
    end
end)

test("Quiet: each pending whisper hides one notice without renewing the offline hold",function()
    local N,registered=setup(); local filter=registered(); local marked=marks(N)
    yes(send(N,"First Surname")); tick(3); yes(send(N,"First Surname"))
    yes(filterLine(filter,{},text("First Surname"),501)); local untilAt=N.Wire.offlineUntil("First Surname",T.clock())
    tick(1); yes(filterLine(filter,{},text("First Surname"),502)); eventLine(text("First Surname"),502)
    tick(1); no(filterLine(filter,{},text("First Surname"),503))
    eq(marked(),1,"existing offline evidence is consumed across this identity, not renewed")
    eq(N.Wire.offlineUntil("First Surname",T.clock()),untilAt); countLine(2,1)
end)
test("Quiet: synchronous offline still leaves one display receipt, not another offline stamp",function()
    local N,registered=setup(); local filter=registered(); local marked=marks(N)
    local real=C_ChatInfo.SendAddonMessage
    C_ChatInfo.SendAddonMessage=function() return 12 end
    local ok,why,called=send(N,"First Surname"); C_ChatInfo.SendAddonMessage=real
    no(ok); eq(why,"offline"); yes(called); eq(marked(),1)
    local untilAt=N.Wire.offlineUntil("First Surname",T.clock()); tick(1)
    for i=1,3 do yes(filterLine(filter,{},text("First Surname"),601)) end
    eventLine(text("First Surname"),601); eq(marked(),1)
    eq(N.Wire.offlineUntil("First Surname",T.clock()),untilAt)
    tick(1); no(filterLine(filter,{},text("First Surname"),602)); countLine(1,1)
end)

test("Quiet: non-system, unrelated, unknown and invalid-name lines are never hidden",function()
    local N,registered=setup(); local filter=registered(); yes(send(N,"First Surname"))
    no(filterLine(filter,{},text("First Surname"),701,"CHAT_MSG_WHISPER"))
    for i,msg in ipairs({"Welcome to the realm",text("Other Person"),text("FirstSurname"),text("First Sur.name"),
        "prefix "..text("First Surname"),text("First Surname").." suffix"}) do
        no(filterLine(filter,{},msg,710+i))
    end
    no(N.Wire.offlineUntil("First Surname",T.clock()))
    yes(filterLine(filter,{},text("First Surname"),720)); countLine(1,3)
end)
test("Quiet: only the localized supported template matches, with literal pattern punctuation",function()
    local N,registered=setup(); local filter=registered(); yes(send(N,"First Surname"))
    ERR_CHAT_PLAYER_NOT_FOUND_S=nil; no(filterLine(filter,{},text("First Surname"),801))
    for _,format in ipairs({"%s","%d","%s %s",T.secret,{},"Missing %2$s!"}) do
        ERR_CHAT_PLAYER_NOT_FOUND_S=format; no(filterLine(filter,{},text("First Surname"),801))
    end
    ERR_CHAT_PLAYER_NOT_FOUND_S="[Absent]. (%1$s) + 100%%?"
    no(filterLine(filter,{},text("First Surname"),802),"no English fallback")
    no(filterLine(filter,{},"[Absent]X (First Surname) + 100%?",803))
    yes(filterLine(filter,{},"[Absent]. (First Surname) + 100%?",804)); countLine(1,0)
end)
test("Quiet: secret unreadable text, clocks and throwing predicates fail open",function()
    local N,registered=setup(); local filter=registered(); yes(send(N,"First Surname"))
    for _,msg in ipairs({T.secret,{},false,123,string.rep("x",513),"bad\ntext"}) do
        local ok,hide=pcall(filterLine,filter,{},msg,901); yes(ok); eq(hide,false)
    end
    local real=GetTime; GetTime=function() error("unreadable clock") end
    no(filterLine(filter,{},text("First Surname"),902)); GetTime=real
    local issecret=issecretvalue; issecretvalue=function() error("unreadable predicate") end
    local ok,hide=pcall(filterLine,filter,{},text("First Surname"),903); issecretvalue=issecret
    yes(ok); eq(hide,false)
    local who=N.Invite.name; N.Invite.name=function() error("unreadable identity") end
    ok,hide=pcall(filterLine,filter,{},text("First Surname"),904); N.Invite.name=who
    yes(ok); eq(hide,false)
    yes(filterLine(filter,{},text("First Surname"),905)); countLine(1,0)
end)
test("Quiet: absent or throwing registration is harmless, one attempt only",function()
    ChatFrame_AddMessageEventFilter=nil
    local N=T.load(); no(N.Main.error); N.Wire.registerSystemFilter()
    local calls=0
    N=setup(nil,function() calls=calls+1; error("unavailable filter") end)
    N.Wire.registerSystemFilter(); eq(calls,1); no(N.Main.error)
    -- No filter does not stop the old event observer or unmatched counting.
    yes(send(N,"First Surname")); eventLine(text("First Surname"),1001)
    yes(N.Wire.offlineUntil("First Surname",T.clock())); eventLine(text("Other Person"),1002); countLine(0,1)
end)
test("Quiet: 30-second boundary and backward clock invalidate whisper evidence",function()
    for _,age in ipairs({29.999,30,-.001}) do
        local N,registered=setup(); local filter=registered(); yes(send(N,"First Surname")); tick(age)
        eq(filterLine(filter,{},text("First Surname"),1101),age==29.999)
    end
end)
test("Quiet: retained foreign namesakes never let a bare name hide the wrong line",function()
    local N,registered=setup(); local filter=registered()
    yes(send(N,"First Surname")); tick(3); yes(send(N,"First Surname-7105"))
    no(filterLine(filter,{},text("First Surname"),1201))
    yes(filterLine(filter,{},text("First Surname-7105"),1202))
    no(filterLine(filter,{},text("First Surname"),1203),"consumed namesake is still ambiguous")
    yes(filterLine(filter,{},text("First Surname-TestRealm"),1204)); countLine(2,2)
end)
test("Quiet: locally blocked, queued-only and missing-API whispers supply no display receipt",function()
    local N,registered=setup(); local filter=registered()
    N.Net.setSwitch("hh",false); no(send(N,"Blocked Person")); N.Net.setSwitch("hh",true)
    no(filterLine(filter,{},text("Blocked Person"),1301))
    local real=C_ChatInfo.SendAddonMessage; C_ChatInfo.SendAddonMessage=false
    no(send(N,"Missing Person")); C_ChatInfo.SendAddonMessage=real
    no(filterLine(filter,{},text("Missing Person"),1302))
    for i=1,4 do yes(N.Wire.send("HeadHunter","1AN:LayerEnemies","WHISPER","Filler"..T.abc(i),{net="hh",prio="own"})) end
    local ok,why=N.Wire.send("HeadHunter","1AN:LayerEnemies","WHISPER","Queued Person",{net="hh",prio="mesh",queue=true})
    yes(ok); eq(why,"queued"); no(filterLine(filter,{},text("Queued Person"),1303)); eq(#T.sent(),4)
end)
test("Quiet: rejected or throwing client calls never hide another cause's notice",function()
    for _,result in ipairs({3,8,9,false,T.secret,"throw"}) do
        local N,registered=setup(); local filter=registered()
        C_ChatInfo.SendAddonMessage=function() if result=="throw" then error("client error") end; return result end
        local ok,_,called=send(N,"First Surname"); no(ok); yes(called)
        no(filterLine(filter,{},text("First Surname"),1401)); countLine(0,1)
    end
end)
test("Quiet: nothing about notice identities or counts is saved",function()
    local N,registered=setup(); local filter=registered(); local keys={}
    for key in pairs(LayerEnemiesDB) do keys[key]=true end
    yes(send(N,"First Surname")); yes(filterLine(filter,{},text("First Surname"),1501))
    eventLine(text("Other Person"),1502); countLine(1,1)
    for key,value in pairs(LayerEnemiesDB) do
        yes(keys[key],"unexpected saved field "..key)
        no(type(value)=="string" and (value:find("First",1,true) or value:find("Other",1,true)))
    end
    eq(type(LayerEnemiesDB.quietWhispers),"string")
end)
local function upvalue(fn,wanted)
    for i=1,100 do
        local name,value=debug.getupvalue(fn,i)
        if not name then break end
        if name==wanted then return value end
    end
    error("missing upvalue "..wanted)
end
test("Quiet: unmatched diagnostics retain no names, including no-ID deduplication",function()
    local N,registered=setup(); local filter=registered(); local msg=text("Other Person")
    for i=1,3 do no(filterLine(filter,{},msg)) end
    eventLine(msg); countLine(0,1)
    local function noNames(value)
        if type(value)=="string" then no(value:find("Other",1,true),"unmatched text/name retained")
        elseif type(value)=="table" then for k,v in pairs(value) do noNames(k); noNames(v) end end
    end
    noNames(upvalue(N.Wire.system,"notices"))
    tick(.001); eventLine(msg); countLine(0,2)
end)
test("Quiet: correlation and message ledgers obey the original capacity and expiry",function()
    local N,registered=setup(); local filter=registered()
    eq(N.Wire.RECENT_MAX,64); eq(N.Wire.RECENT_WINDOW,30)
    N.Wire.RECENT_MAX=2
    yes(send(N,"Oldest Person")); tick(3); yes(send(N,"Middle Person")); tick(3); yes(send(N,"Newest Person"))
    no(filterLine(filter,{},text("Oldest Person"),1601)); yes(filterLine(filter,{},text("Middle Person"),1602))
    yes(filterLine(filter,{},text("Newest Person"),1603))
    eq(#upvalue(N.Wire.system,"notices"),2)
    for i=1,10 do no(filterLine(filter,{},text("Unknown"..T.abc(i)),1610+i)) end
    eq(#upvalue(N.Wire.system,"notices"),2)
    no(filterLine(filter,{},text("Middle Person"),1602),"evicted decision fails open, no receipt revived")
    tick(30); no(filterLine(filter,{},text("Newest Person"),1603),"expired decision fails open")
end)
test("Quiet: accepted legacy boolean send also supplies one display receipt",function()
    local N,registered=setup(); local filter=registered()
    C_ChatInfo.SendAddonMessage=function() return true end
    yes(send(N,"First Surname")); yes(filterLine(filter,{},text("First Surname"),1701))
    no(filterLine(filter,{},text("Other Person"),1701),"ID cannot hide different text")
end)
test("Quiet: readable-looking secret strings are not compared or hidden",function()
    local N,registered=setup(); local filter=registered(); yes(send(N,"First Surname"))
    local real=issecretvalue; local msg=text("First Surname")
    issecretvalue=function(v) return rawequal(v,msg) or real(v) end
    no(filterLine(filter,{},msg,1801)); issecretvalue=real; countLine(0,0)
    issecretvalue=function(v) return rawequal(v,FORMAT) or real(v) end
    no(filterLine(filter,{},msg,1802)); issecretvalue=real; countLine(0,0)
    yes(filterLine(filter,{},msg,1803)); countLine(1,0)
end)
test("Quiet: donor presence leaves send stand-down policy unchanged",function()
    local N,registered=setup(); local filter=registered(); local addons=T.loaded()
    addons.HeadHunter=true; addons.WarEffortScout=true; addons.LayerSwap=true; addons.BuloLayerForever=true
    local ok,why,called=send(N,"First Surname"); no(ok); eq(why,"stand down"); no(called)
    ok,why,called=N.Wire.send("WEFF1","P|x","WHISPER","First Surname",{net="we",prio="embassy"})
    no(ok); eq(why,"stand down"); no(called)
    no(filterLine(filter,{},text("First Surname"),1901)); yes(N.Main.hostBlocked())
    -- Explicit hop requests have no donor stand-down, unlike the automatic guild host.
    local line=N.Hop.line(100,"8000",0,.5,.5)
    yes(N.Wire.send("LayerSwap",line,"WHISPER","First Surname",{prio="click"}))
    yes(filterLine(filter,{},text("First Surname"),1902)); eq(#T.sent(),1)
end)
