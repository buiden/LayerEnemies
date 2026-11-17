-- All-not-found mode: exercise real startup, slash commands, observer and chat filters.
local T=...
local test,eq,yes,no=T.test,T.eq,T.yes,T.no
local FORMAT='No player named "%s" is currently playing.'
local function text(name) return string.format(FORMAT,name) end
local function filterLine(filter,msg,id)
    return filter({},"CHAT_MSG_SYSTEM",msg,"","","","","",0,0,"",0,id)
end
local function eventLine(msg,id)
    T.deliver("CHAT_MSG_SYSTEM",msg,"","","","","",0,0,"",0,id)
end
local function setup(options,saved)
    options=options or {}
    local filter,hooks,calls,attempts=nil,{},0,{}
    ChatFrame_AddMessageEventFilter=function(event,fn) eq(event,"CHAT_MSG_SYSTEM"); filter=fn end
    local N=T.load(saved,function()
        -- Model native post-hooks separately, without replacing the send functions.
        local function client() calls=calls+1; return "unchanged" end
        C_ChatInfo.SendChatMessage=options.modern~=false and client or nil
        SendChatMessage=options.legacy~=false and client or nil
        local previous=hooksecurefunc
        hooksecurefunc=function(tbl,key,fn)
            local path
            if tbl==C_ChatInfo and key=="SendChatMessage" then path="modern"
            elseif tbl=="SendChatMessage" then path="legacy"; fn=key
            else return previous(tbl,key,fn) end
            attempts[path]=(attempts[path] or 0)+1
            local target=path=="modern" and C_ChatInfo.SendChatMessage or SendChatMessage
            if options.throw or options[path]==false or type(target)~="function" then error("unavailable hook") end
            eq(type(fn),"function"); hooks[path]=fn
        end
        if options.noHook then hooksecurefunc=nil end
        ERR_CHAT_PLAYER_NOT_FOUND_S=FORMAT
    end)
    ChatFrame_AddMessageEventFilter=nil
    N.Net.SHIP.hh=true
    local function typed(path,name,kind)
        local api=path=="modern" and C_ChatInfo.SendChatMessage or SendChatMessage
        local result=api("private message",kind or "WHISPER",nil,name)
        if hooks[path] then hooks[path]("private message",kind or "WHISPER",nil,name) end
        return result
    end
    return N,filter,typed,hooks,function() return calls end,attempts
end
local function send(N,name)
    return N.Wire.send("HeadHunter","1AN:LayerEnemies","WHISPER",name,{net="hh",prio="mesh"})
end
local function logged(needle,first)
    for i=first or 1,#T.log() do if T.log()[i]:find(needle,1,true) then return true end end
end
local function counts(own,other,shown)
    local before=#T.log(); SlashCmdList.LAYERENEMIES("net")
    local needle="hidden (LayerEnemies whispers): "..own.."; hidden (other addons): "..other.."; shown (your own whisper or mode): "..shown
    local found=0
    for i=before+1,#T.log() do if T.log()[i]==needle then found=found+1 end end
    eq(found,1,"exact /le net counters: "..needle)
end

test("QuietAll modes: booleans migrate, strings survive, invalid values default on",function()
    local cases={{true,"on"},{false,"off"},{"on","on"},{"off","off"},{"all","all"},
        {"bad","on"},{17,"on"},{T.secret,"on"},{ {},"on"}}
    T.load(); eq(LayerEnemiesDB.quietWhispers,"on")
    for _,case in ipairs(cases) do
        T.load({quietWhispers=case[1]}); eq(LayerEnemiesDB.quietWhispers,case[2])
    end
end)
test("QuietAll modes: slash accepts all, persists it and reports current scope",function()
    T.load()
    for _,mode in ipairs({"all","off","on"}) do
        SlashCmdList.LAYERENEMIES("quiet "..mode); eq(LayerEnemiesDB.quietWhispers,mode)
        SlashCmdList.LAYERENEMIES("quiet"); yes(T.log()[#T.log()]:find("quiet "..mode,1,true))
        yes(T.log()[#T.log()]:find(mode=="off" and "visible" or mode=="on" and "LayerEnemies" or "your own",1,true))
        T.load(LayerEnemiesDB); eq(LayerEnemiesDB.quietWhispers,mode)
    end
    SlashCmdList.LAYERENEMIES("quiet maybe"); eq(LayerEnemiesDB.quietWhispers,"on")
    yes(logged("/le quiet on|off|all"))
end)

test("QuietAll hook: both secure post-hooks install at startup without sends or replacements",function()
    local N,filter,typed,hooks,calls,attempts=setup()
    eq(type(hooks.modern),"function"); eq(type(hooks.legacy),"function")
    eq(calls(),0); eq(T.forbidden(),0)
    local modern,legacy=C_ChatInfo.SendChatMessage,SendChatMessage
    N.Main.start(); N.Wire.registerWhisperObserver()
    eq(attempts.modern,1); eq(attempts.legacy,1)
    eq(C_ChatInfo.SendChatMessage,modern); eq(SendChatMessage,legacy)
    eq(typed("modern","Manual Person"),"unchanged"); eq(calls(),1)
    eq(#T.sent(),0)
end)
test("QuietAll filter: any localized not-found is hidden, only typed targets are excepted",function()
    local N,filter,typed=setup(); SlashCmdList.LAYERENEMIES("quiet all")
    yes(filterLine(filter,text("Other Person"),1))
    yes(filterLine(filter,text("Unknown.Invalid"),2),"all matching lines, not only valid addon targets")
    typed("modern","Manual Person"); no(filterLine(filter,text("Manual Person"),3))
    typed("legacy","Legacy Person"); no(filterLine(filter,text("Legacy Person"),4))
    yes(filterLine(filter,text("Different Person"),5))
    no(filterLine(filter,"Unrelated system announcement",6))
    eq(#T.sent(),0); eq(T.forbidden(),0)
end)
test("QuietAll hook: each available API works alone and failed installs fall back to on",function()
    for _,available in ipairs({"modern","legacy"}) do
        local N,filter,typed,hooks=setup({modern=available=="modern",legacy=available=="legacy"})
        eq(type(hooks[available]),"function"); SlashCmdList.LAYERENEMIES("quiet all")
        yes(filterLine(filter,text("Other Person"),1))
        typed(available,"Manual Person"); no(filterLine(filter,text("Manual Person"),2))
    end
    for _,options in ipairs({{modern=false,legacy=false},{noHook=true},{throw=true}}) do
        local N,filter=setup(options); SlashCmdList.LAYERENEMIES("quiet all")
        no(filterLine(filter,text("Other Person"),1))
        yes(send(N,"Our Person")); yes(filterLine(filter,text("Our Person"),2))
        local first=#T.log()+1
        SlashCmdList.LAYERENEMIES("net")
        yes(logged("all behaves like on",first)); no(N.Main.error)
    end
end)

test("QuietAll counters: own, other and shown decisions are separate and per event",function()
    for _,eventFirst in ipairs({true,false}) do
        local N,filter,typed=setup(); SlashCmdList.LAYERENEMIES("quiet all"); counts(0,0,0)
        local function line(name,id,hidden)
            if eventFirst then eventLine(text(name),id) end
            for i=1,3 do eq(filterLine(filter,text(name),id),hidden) end
            if not eventFirst then eventLine(text(name),id) end
        end
        yes(send(N,"Our Person")); line("Our Person",1,true); counts(1,0,0)
        line("Other Person",2,true); counts(1,1,0)
        typed("modern","Manual Person"); line("Manual Person",3,false); counts(1,1,1)
        SlashCmdList.LAYERENEMIES("quiet off")
        T.clock(T.clock()+3); yes(send(N,"Next Person")); line("Next Person",4,false)
        line("Another Person",5,false); counts(1,1,3)
        SlashCmdList.LAYERENEMIES("quiet on"); line("Final Person",6,false); counts(1,1,4)
        no(filterLine(filter,"Unrelated",7)); counts(1,1,4)
    end
end)
test("QuietAll counters: observer-only hides are not counted and reload resets totals",function()
    local N,filter,typed=setup(); SlashCmdList.LAYERENEMIES("quiet all")
    eventLine(text("Other Person"),1); counts(0,0,0)
    yes(filterLine(filter,text("Other Person"),1)); counts(0,1,0)
    local saved=LayerEnemiesDB; N,filter=setup(nil,saved); eq(LayerEnemiesDB.quietWhispers,"all"); counts(0,0,0)
end)
test("QuietAll manual: only WHISPER is recorded, with existing full name normalization",function()
    local N,filter,typed=setup(); SlashCmdList.LAYERENEMIES("quiet all")
    for i,kind in ipairs({"SAY","GUILD","CHANNEL","BN_WHISPER","whisper",T.secret}) do
        typed("modern","Other Person",kind); yes(filterLine(filter,text("Other Person"),i))
    end
    typed("modern","First Surname-TestRealm")
    no(filterLine(filter,text("FIRST SURNAME"),11)); no(filterLine(filter,text("First Surname-TestRealm"),12))
    yes(filterLine(filter,text("FirstSurname"),13)); yes(filterLine(filter,text("First Surname-7105"),14))
    typed("legacy","Foreign Surname-7105")
    no(filterLine(filter,text("FOREIGN SURNAME-7105"),15)); yes(filterLine(filter,text("Foreign Surname"),16))
    yes(filterLine(filter,text("Foreign Surname-7106"),17))
    typed("modern",T.secret); typed("modern","Invalid.Name"); yes(filterLine(filter,text("Invalid.Name"),18))
end)
test("QuietAll manual: ten-second strict expiry, rollback and refresh do not extend on notices",function()
    for _,age in ipairs({0,9.999,10,-.001}) do
        local N,filter,typed=setup(); typed("modern","Manual Person")
        SlashCmdList.LAYERENEMIES("quiet all"); T.clock(T.clock()+age)
        eq(filterLine(filter,text("Manual Person"),1),age>=10 or age<0)
    end
    local N,filter,typed=setup(); SlashCmdList.LAYERENEMIES("quiet all"); typed("modern","Manual Person")
    T.clock(19); no(filterLine(filter,text("Manual Person"),1)); T.clock(20); yes(filterLine(filter,text("Manual Person"),2))
    typed("legacy","Manual Person"); no(filterLine(filter,text("Manual Person"),3))
    T.clock(29.999); no(filterLine(filter,text("Manual Person"),4)); T.clock(30); yes(filterLine(filter,text("Manual Person"),5))
end)
test("QuietAll manual: sixteen distinct targets bounded and duplicate hooks refresh one slot",function()
    local N,filter,typed=setup(); SlashCmdList.LAYERENEMIES("quiet all")
    for i=1,16 do typed("modern","Manual "..T.abc(i)) end
    no(filterLine(filter,text("Manual a"),1)); no(filterLine(filter,text("Manual p"),2))
    typed("legacy","Manual a"); typed("modern","Manual a")
    typed("modern","Manual q")
    no(filterLine(filter,text("Manual a"),3)); yes(filterLine(filter,text("Manual b"),4))
    for i=3,17 do no(filterLine(filter,text("Manual "..T.abc(i)),10+i)) end
end)
test("QuietAll bookkeeping: manual exception does not alter own offline consumption in any mode",function()
    for _,mode in ipairs({"off","on","all"}) do
        for _,eventFirst in ipairs({true,false}) do
            local N,filter,typed=setup(); SlashCmdList.LAYERENEMIES("quiet "..mode)
            yes(send(N,"Shared Person")); T.clock(13); yes(send(N,"Shared Person"))
            typed("modern","Shared Person")
            local marks,real=0,N.Wire.markOffline
            N.Wire.markOffline=function(...) marks=marks+1; return real(...) end
            if eventFirst then eventLine(text("Shared Person"),1) end
            for i=1,3 do eq(filterLine(filter,text("Shared Person"),1),mode=="on") end
            if not eventFirst then eventLine(text("Shared Person"),1) end
            local untilAt=N.Wire.offlineUntil("Shared Person",T.clock()); eq(untilAt,T.clock()+3600); eq(marks,1)
            T.clock(14); eq(filterLine(filter,text("Shared Person"),2),mode=="on"); eq(marks,1)
            eq(N.Wire.offlineUntil("Shared Person",T.clock()),untilAt)
        end
    end
end)
test("QuietAll decisions: repeated frames freeze both outcomes across mode and time changes",function()
    for _,id in ipairs({71,false}) do
        local N,filter,typed=setup(); SlashCmdList.LAYERENEMIES("quiet all")
        local lineID=id or nil
        yes(filterLine(filter,text("Other Person"),lineID))
        typed("modern","Other Person"); SlashCmdList.LAYERENEMIES("quiet off")
        for i=1,3 do yes(filterLine(filter,text("Other Person"),lineID)) end
        counts(0,1,0)
        no(filterLine(filter,text("Manual Person"),72)); typed("modern","Manual Person")
        SlashCmdList.LAYERENEMIES("quiet all"); T.clock(20)
        no(filterLine(filter,text("Manual Person"),72)); yes(filterLine(filter,text("Manual Person"),73))
        counts(0,2,1)
    end
end)
test("QuietAll privacy: no target, message or counter is saved and reload forgets manual names",function()
    local N,filter,typed=setup(); SlashCmdList.LAYERENEMIES("quiet all")
    local keys={}; for k in pairs(LayerEnemiesDB) do keys[k]=true end
    typed("modern","Manual Person"); no(filterLine(filter,text("Manual Person"),1))
    yes(filterLine(filter,text("Other Person"),2))
    local function inspect(v)
        if type(v)=="string" then no(v:find("Person",1,true)); no(v:find("private message",1,true))
        elseif type(v)=="table" then for k,x in pairs(v) do inspect(k); inspect(x) end end
    end
    inspect(LayerEnemiesDB)
    for k in pairs(LayerEnemiesDB) do yes(keys[k],"unexpected saved field "..k) end
    N,filter=setup(nil,LayerEnemiesDB); yes(filterLine(filter,text("Manual Person"),3)); counts(0,1,0)
end)
test("QuietAll safety: exact localized pattern only and protected callbacks never escape",function()
    local N,filter,typed,hooks=setup(); SlashCmdList.LAYERENEMIES("quiet all")
    no(filterLine(filter,"prefix "..text("Other Person"),1)); no(filterLine(filter,text("Other Person").." suffix",2))
    for _,value in ipairs({T.secret,{},false,string.rep("x",513)}) do no(filterLine(filter,value,3)) end
    local original=N.Invite.name; N.Invite.name=function() error("unreadable target") end
    yes(pcall(hooks.modern,"x","WHISPER",nil,"Manual Person")); N.Invite.name=original
    local clock=GetTime; GetTime=function() error("unreadable time") end
    yes(pcall(hooks.legacy,"x","WHISPER",nil,"Manual Person")); GetTime=clock
    ERR_CHAT_PLAYER_NOT_FOUND_S=nil; no(filterLine(filter,text("Other Person"),4))
    ERR_CHAT_PLAYER_NOT_FOUND_S="%s %s"; no(filterLine(filter,text("Other Person"),5))
    ERR_CHAT_PLAYER_NOT_FOUND_S="[Missing]. (%1$s) + 100%%?"
    yes(filterLine(filter,"[Missing]. (Other Person) + 100%?",6))
    typed("modern","Manual Person"); no(filterLine(filter,"[Missing]. (Manual Person) + 100%?",7))
end)
test("QuietAll status: no-hook query explains fallback instead of claiming blanket hiding",function()
    setup({noHook=true}); SlashCmdList.LAYERENEMIES("quiet all"); SlashCmdList.LAYERENEMIES("quiet")
    yes(T.log()[#T.log()]:find("all behaves like on",1,true))
end)
test("QuietAll decisions: a numeric fingerprint collision can never hide a manual failure",function()
    local N,filter,typed=setup(); SlashCmdList.LAYERENEMIES("quiet all")
    local found=false
    for i=1,100 do
        local name=debug.getupvalue(N.Wire.system,i)
        if not name then break end
        if name=="noticeFingerprint" then debug.setupvalue(N.Wire.system,i,function() return 1 end); found=true; break end
    end
    yes(found); typed("modern","Manual Person")
    eq(#text("Others Person"),#text("Manual Person"))
    yes(filterLine(filter,text("Others Person"),41))
    no(filterLine(filter,text("Manual Person"),41),"same ID and fingerprint, different text")
    for i=1,3 do yes(filterLine(filter,text("Others Person"),41)) end
    counts(0,1,1)
end)
test("QuietAll coexistence: all mode works with donors loaded without starting their sends",function()
    local N,filter,typed=setup(); local addons=T.loaded()
    addons.HeadHunter=true; addons.WarEffortScout=true; addons.LayerSwap=true; addons.BuloLayerForever=true
    SlashCmdList.LAYERENEMIES("quiet all")
    local ok,why,called=send(N,"Donor Target"); no(ok); eq(why,"stand down"); no(called)
    yes(filterLine(filter,text("Donor Target"),1)); no(N.Wire.offlineUntil("Donor Target",T.clock()))
    typed("modern","Donor Target"); no(filterLine(filter,text("Donor Target"),2))
    eq(#T.sent(),0); counts(0,1,1)
end)
