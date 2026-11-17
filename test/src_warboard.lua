-- Protocol-only constructed fixtures. No WarBoard/library code is loaded.
local h=...
local eq,yes,no=h.eq,h.yes,h.no
local active
local function allowedFrame(N,id,text)
    if text:match("^WBF1|[HA]|5|[^|]+|LayerEnemies/[^|]+|0$") then return true end
    if text:sub(1,7)~="WBF1|D|" then return false end
    local raw=N.Codec.addonDecode(text:sub(8)); local plain=raw and N.Codec.inflate(raw,4000)
    local e=plain and N.Codec.aceRead(plain)
    if not e or (e.t~="FBAK" and e.t~="FBUN") then return false end
    local peer=N.WarBoard.state.peers[id]; local who=N.BNet.who(id,true)
    local me=N.Adapters.warboardSelf(); local d=e.d
    if not peer or not peer.confirmed or not who or not me or not d or who.guid~=d.targetGuid
        or d.hunterGuid~=me.guid or d.hunterName~=me.name or d.hunterFaction~="Alliance" or d.faction~="Alliance"
        or e.av~="LayerEnemies/1.1.0" or e.senderName~=me.name or e.rs~="pvp" or e.v~=5 then return false end
    return e.t=="FBUN" or (N.WarBoardTrack.on and N.Find.tracked(N.Main.find,N.OpenMap.bnName(who.name,who.realm)))
end
local function checkSends()
    if not active then return end
    eq(active.badSend,0,"no forbidden attempt, even if protected callbacks swallowed it")
    for _,s in ipairs(h.sent()) do
        if s.prefix=="WarBoard" or s.prefix=="WarBoardBN" then
            eq(s.kind,"BN","WarBoard never uses addon/chat routes")
            yes(allowedFrame(active,s.target,s.text),"truthful H/A or verified own-Find FBAK / scoped FBUN only")
        end
    end
end
local function test(name,fn)
    h.test("WarBoard: "..name,function() active=nil; fn(); checkSends() end)
end
local function setup(name)
    checkSends()
    local N=h.load(); active=N
    N.badSend=0
    yes(N.WarBoard,"registered WarBoard source exists")
    yes(N.shipped.warboard,"source ships on"); N.Net.SHIP.warboard=true
    _G.WOW_PROJECT_ID=42
    _G.GetRealmName=function() return "PvP 123" end
    C_AddOns.GetAddOnMetadata=function(addon,key) eq(addon,"LayerEnemies"); eq(key,"Version"); return "1.1.0" end
    C_BattleNet.GetGameAccountInfoByID=function(id)
        return {gameAccountID=id,characterName="Enemy Player",realmName="123",factionName="Horde",clientProgram="WoW",
            isOnline=true,wowProjectID=42,isInCurrentRegion=true}
    end
    N.BNet.peers=function() return {} end
    local queued=N.BNet.send
    N.BNet.send=function(net,id,prefix,text,prio,still)
        if net=="warboard" or prefix=="WarBoard" or prefix=="WarBoardBN" then
            if net~="warboard" or prefix~="WarBoard" or not allowedFrame(N,id,text) then
                N.badSend=N.badSend+1
            end
        end
        return queued(net,id,prefix,text,prio,still)
    end
    local ordinary=N.Wire.send
    N.Wire.send=function(prefix,...)
        if prefix=="WarBoard" or prefix=="WarBoardBN" then N.badSend=N.badSend+1 end
        return ordinary(prefix,...)
    end
    if name then yes(N.Find.add(N.Main.find,name)) end
    return N
end
local function inbound(text,id,prefix)
    h.deliver("BN_CHAT_MSG_ADDON",prefix or "WarBoard",text,"WHISPER",id or 71)
end
local function hello(kind,rs,proto)
    return "WBF1|"..(kind or "H").."|"..(proto or "5").."|"..(rs or "pvp").."|1.6.3|3"
end
local function sends(kind)
    local out={}
    for _,s in ipairs(h.sent()) do
        if s.prefix=="WarBoard" and (not kind or s.text:sub(6,6)==kind) then out[#out+1]=s end
    end
    return out
end
local function advance(n) for _=1,n do h.advance(1) end end
local function queueOtherThirty(N)
    local fixture=assert(loadfile("test/bnet_queue_fixture.lua"))(h)
    local rows={{"wanted","WNTDB",4},{"overlord","OLQueue",8}}
    for _,r in ipairs(rows) do fixture.register(N,r[1],r[2]) end
    local existing=#N.Sources.lines(); local count=0
    repeat count=count+1 until 12+count*math.max(1,math.floor(30/(existing+count)))>=30
    yes(existing+count<=32,"saturate global budget with eligible non-WarBoard sources")
    for i=1,count do
        local name,prefix="load"..h.abc(i),"Load"..i
        fixture.register(N,name,prefix); rows[#rows+1]={name,prefix}
    end
    local total=0
    for _,r in ipairs(rows) do
        for _=1,math.min(r[3] or fixture.defaultShare(N),30-total) do
            yes(N.BNet.send(r[1],71,r[2],"load","own")); total=total+1
        end
    end
    eq(total,30); eq(N.BNet.queued(),30)
end

test("compatible H answers once through shared queue; A never answered",function()
    local N=setup()
    yes(N.Sources.owns("WarBoard")); yes(N.Sources.owns("WarBoardBN"))
    inbound(hello()); eq(#sends(),0,"not an immediate client call")
    advance(1); eq(#sends("A"),1); eq(sends()[1].text,"WBF1|A|5|pvp|LayerEnemies/1.1.0|0")
    inbound(hello("A")); advance(2); eq(#sends(),1)
    yes(N.WarBoard.state.peers[71])
end)

test("wrong ruleset H gets own A but no peer; wrong protocol gets nothing",function()
    local N=setup()
    inbound(hello("A")); yes(N.WarBoard.state.peers[71])
    inbound(hello("H","normal")); advance(1); eq(#sends("A"),1); no(N.WarBoard.state.peers[71])
    inbound(hello("H","pvp","4")); advance(1); eq(#sends(),1)
    inbound(hello("H","unknown")); advance(1); eq(#sends(),1)
    GetRealmName=function() return "123" end
    inbound(hello()); advance(1); eq(#sends(),1)
end)

test("queue refusal does not spend H admission cooldown",function()
    local N=setup(); local attempts=0; local queued=N.BNet.send
    N.BNet.send=function(...) attempts=attempts+1; return queued(...) end
    N.BNet.peers=function()
        local rows={}
        for i=1,12 do rows[i]={id=70+i,faction="Horde"} end
        return rows
    end
    advance(1); eq(attempts,12); eq(N.BNet.queued(),10)
    yes(N.WarBoard.state.hellos[71],"an admitted H spends the cooldown before dispatch")
    eq(N.WarBoard.state.hellos[81],nil,"queue refusal must not spend a 600-second cooldown")
    eq(N.WarBoard.state.hellos[82],nil,"each refused account remains eligible")
    advance(59); eq(attempts,12,"no immediate retry between scans"); eq(#sends("H"),10)
    advance(1); eq(attempts,14,"next scan can admit the two refused accounts")
    advance(2); eq(#sends("H"),12)
    eq(sends("H")[11].target,81); eq(sends("H")[12].target,82)
end)

test("round robin starts after the last admitted account in stable ID order",function()
    local N=setup(); local order={}; local scans=0; local queued=N.BNet.send
    N.BNet.send=function(net,id,...)
        order[#order+1]=id
        return queued(net,id,...)
    end
    N.BNet.peers=function()
        scans=scans+1; local rows={{id=1,faction="Alliance"}}
        -- Enumeration order changes; the last greeted account leaves before scan 3.
        for i=1,40 do
            local id=scans==1 and 70+i or 111-i
            if scans<3 or id~=90 then rows[#rows+1]={id=id,faction="Horde"} end
        end
        rows[#rows+1]={id=71,faction="Horde"} -- friend/community duplicate
        return rows
    end
    advance(1); eq(#order,20); eq(N.BNet.queued(),10)
    for i=1,20 do eq(order[i],70+i) end
    advance(60); eq(scans,2); eq(#order,40)
    for i=1,20 do eq(order[20+i],80+i,"resume after last accepted, not last refused") end
    advance(60); eq(scans,3); eq(#order,60)
    for i=1,20 do eq(order[40+i],90+i,"removed cursor and reordered roster keep their place") end
    advance(60); eq(scans,4); eq(#order,70)
    for i=1,10 do eq(order[60+i],100+i,"wrap skips accounts still on cooldown") end
    advance(10); eq(#sends("H"),40)
end)

for _,count in ipairs({12,20,25,40}) do
    for _,mixed in ipairs({false,true}) do
        test("hello reach over sixty minutes for "..count.." accounts"..(mixed and " with owed and shared traffic" or ""),function()
            local N=setup(); local scans,attempts,lastScan=0,0,nil
            local queued=N.BNet.send
            N.BNet.send=function(net,id,prefix,text,prio,still)
                if net=="warboard" and text:sub(6,6)=="H" then
                    attempts=attempts+1; yes(attempts<=20,"at most twenty selections per scan")
                end
                return queued(net,id,prefix,text,prio,still)
            end
            N.BNet.peers=function()
                if lastScan then yes(h.clock()-lastScan>=60,"scan cadence remains sixty seconds") end
                lastScan=h.clock(); scans=scans+1; attempts=0
                local rows={}
                for i=1,count do rows[i]={id=70+i,faction="Horde"} end
                return rows
            end
            local traffic={}
            if mixed then
                local fixture=assert(loadfile("test/bnet_queue_fixture.lua"))(h)
                traffic={{"wanted","WNTDB",4},{"overlord","OLQueue",8}}
                for _,r in ipairs(traffic) do fixture.register(N,r[1],r[2]) end
                -- Enough distinct registered sources to exercise the shared 30/min cap.
                for i=1,8 do
                    local name,prefix="reach"..h.abc(i),"Reach"..i
                    fixture.register(N,name,prefix); traffic[#traffic+1]={name,prefix,1}
                end
            end
            for minute=1,60 do
                if mixed then
                    for _,r in ipairs(traffic) do
                        for _=1,r[3] do yes(N.BNet.send(r[1],71,r[2],"load","own")) end
                    end
                    for i=1,6 do inbound(hello(),70+i) end
                    eq(N.BNet.queued(),26,"six owed answers alongside twenty normal frames")
                end
                advance(60)
            end
            eq(scans,60)
            local greeted,last,all,wb,answers={},{},{},{},{}
            for _,s in ipairs(h.sent()) do if s.kind=="BN" then
                all[#all+1]=s
                if s.prefix=="WarBoard" then
                    wb[#wb+1]=s
                    if s.text:sub(6,6)=="H" then
                        yes(s.target>=71 and s.target<=70+count)
                        if last[s.target] then yes(s.at-last[s.target]>=600,"per-account H dispatch cooldown") end
                        last[s.target]=s.at; greeted[s.target]=true
                    else answers[#answers+1]=s end
                end
            end end
            local reached=N.Safe.count(greeted)
            print("REACH "..count..(mixed and " mixed" or " alone")..": "..reached.."/"..count)
            eq(reached,count,"every continuously eligible account receives a hello")
            for _,entry in ipairs({{all,30},{wb,10},{answers,6}}) do
                local first=1
                for i,s in ipairs(entry[1]) do
                    while s.at-entry[1][first].at>=60 do first=first+1 end
                    yes(i-first+1<=entry[2],"rolling shared/source/answer budget")
                end
            end
            for i=2,#all do yes(all[i].at-all[i-1].at>=1,"shared one-second pace") end
            if mixed then
                eq(#answers,360,"owed answers keep their full six-per-minute allowance")
                for i=1,6 do eq(all[i].text:sub(1,6),"WBF1|A","owed answers precede older normal work and discovery") end
                local high=0; local first=1
                for i,s in ipairs(all) do
                    while s.at-all[first].at>=60 do first=first+1 end
                    high=math.max(high,i-first+1)
                end
                eq(high,30,"exercise, not merely stay below, the shared cap")
            end
            no(N.Main.error)
        end)
    end
end

for _,mode in ipairs({"missing","secret","throwing"}) do
    test("unreadable hello cursor skips "..mode.." names without spending the selection budget",function()
        local N=setup(); local order={}; local scans=0
        local lookup=C_BattleNet.GetGameAccountInfoByID
        C_BattleNet.GetGameAccountInfoByID=function(id)
            local r=lookup(id)
            if id>=81 and id<=102 then
                r.characterName=mode=="secret" and h.secret or nil
                if mode=="throwing" then
                    setmetatable(r,{__index=function(_,key)
                        if key=="characterName" then error("unreadable character name") end
                    end})
                end
            end
            return r
        end
        local queued=N.BNet.send
        N.BNet.send=function(net,id,...)
            if net=="warboard" then order[#order+1]=id end
            return queued(net,id,...)
        end
        N.BNet.peers=function()
            scans=scans+1; local rows={}
            for id=71,115 do rows[#rows+1]={id=id,faction="Horde"} end
            return rows
        end
        for id=81,102 do eq(N.BNet.who(id),nil,"fixture name is unreadable through the real adapter") end
        advance(1); eq(scans,1)
        eq(#order,20,"unreadable accounts do not consume readable selections")
        eq(N.BNet.queued(),10,"shared admission cap is unchanged")
        for i=1,10 do eq(order[i],70+i); eq(order[10+i],102+i) end
        eq(N.WarBoard.state.lastHello,102,"cursor passes unreadable names but not readable queue refusals")
        for id=81,102 do eq(N.WarBoard.state.hellos[id],nil,"unreadable names spend no cooldown") end
        advance(60); eq(scans,2)
        eq(#order,33,"next pass starts after the unreadable block; earlier hellos stay on cooldown")
        for i=1,13 do eq(order[20+i],102+i) end
        advance(10); eq(#sends("H"),20)
        no(N.Main.error)
    end)
end

for _,unreadable in ipairs({false,true}) do
    test("unreadable hello reach over sixty minutes with "..(unreadable and "22 unreadable" or "all readable").." of 45 accounts",function()
        local N=setup(); local scans,attempts,lastScan=0,0,nil
        local function blocked(id) return unreadable and id>=81 and id<=102 end
        local lookup=C_BattleNet.GetGameAccountInfoByID
        C_BattleNet.GetGameAccountInfoByID=function(id)
            local r=lookup(id)
            if blocked(id) then r.characterName=nil end
            return r
        end
        local queued=N.BNet.send
        N.BNet.send=function(net,id,prefix,text,prio,still)
            if net=="warboard" and text:sub(6,6)=="H" then
                attempts=attempts+1
                yes(attempts<=20,"unchanged twenty-account selection cap")
                no(blocked(id),"unreadable accounts never enter the hello queue")
            end
            return queued(net,id,prefix,text,prio,still)
        end
        N.BNet.peers=function()
            if lastScan then yes(h.clock()-lastScan>=60,"unchanged sixty-second scan cadence") end
            lastScan=h.clock(); scans=scans+1; attempts=0
            local rows={}
            for id=71,115 do rows[#rows+1]={id=id,faction="Horde"} end
            return rows
        end
        for id=71,115 do
            eq(N.BNet.who(id)~=nil,not blocked(id),"live identity readability matches the fixture")
        end
        advance(3600); eq(scans,60)
        local out=sends("H"); local greeted,last={},{}
        local first=1
        for i,s in ipairs(out) do
            yes(s.target>=71 and s.target<=115); no(blocked(s.target))
            if last[s.target] then yes(s.at-last[s.target]>=600,"unchanged per-account hello cooldown") end
            last[s.target]=s.at; greeted[s.target]=true
            while s.at-out[first].at>=60 do first=first+1 end
            yes(i-first+1<=10,"unchanged ten-per-minute WarBoard budget")
            if i>1 then yes(s.at-out[i-1].at>=1,"unchanged shared one-second pace") end
        end
        local after=0
        for id=103,115 do if greeted[id] then after=after+1 end end
        local expected=unreadable and 23 or 45
        print("UNREADABLE REACH "..(unreadable and "22 missing" or "none")..": "..
            N.Safe.count(greeted).."/"..expected.."; after block "..after.."/13")
        eq(N.Safe.count(greeted),expected,"all readable accounts greeted within sixty minutes")
        eq(after,13,"readable accounts after the block are not starved")
        eq(#sends("A"),0); eq(#out,#h.sent(),"only permitted hellos are emitted")
        no(N.Main.error)
    end)
end

test("discovery selects twenty opposite accounts at sixty seconds and greets once per six hundred",function()
    local N=setup(); local scans=0
    local attempts=0; local queued=N.BNet.send
    N.BNet.send=function(...) attempts=attempts+1; return queued(...) end
    N.BNet.peers=function()
        scans=scans+1; local rows={{id=1,faction="Alliance"}}
        for i=1,25 do rows[#rows+1]={id=70+i,faction="Horde"} end
        return rows
    end
    advance(1); eq(scans,1); eq(attempts,20,"selection cap independent of queue admission")
    eq(N.BNet.queued(),10,"the shared queue admits only WarBoard's ten slots")
    advance(59); eq(scans,1); eq(#sends("H"),10)
    advance(1); eq(scans,2)
    advance(59); eq(#sends("H"),20); eq(attempts,35,"next scan reconsiders refusals and rotates")
    advance(480); eq(#sends("H"),25,"all twenty-five accounts reached before any repeat")
    advance(120); eq(#sends("H"),45); eq(attempts,60,"only the first two cohorts are eligible again")
    local last={}
    for _,s in ipairs(sends("H")) do
        yes(s.target>=71 and s.target<=95)
        if last[s.target] then yes(s.at-last[s.target]>=600,"per-account actual send gap") end
        last[s.target]=s.at
    end
end)

test("A six per rolling minute including delayed queue; WarBoard ten shared thirty",function()
    local N=setup()
    for i=1,12 do inbound(hello(),70+i) end
    eq(N.BNet.queued(),6,"answer admission cap independent of dispatch cap")
    advance(12); eq(#sends("A"),6)
    advance(48); inbound(hello(),99); advance(1)
    -- At the exact boundary from the first actual A, one slot opens.
    eq(#sends("A"),7)
    local out=sends("A")
    for _,s in ipairs(out) do local count=0
        for _,v in ipairs(out) do if v.at>s.at-60 and v.at<=s.at then count=count+1 end end
        yes(count<=6)
    end
end)

for _,mode in ipairs({"share","public","switch","combat","instance"}) do
    test(mode.." stops new sends and cancels queued answers",function()
        local N=setup(); inbound(hello()); eq(N.BNet.queued(),1)
        if mode=="share" then N.Main.setShare(false)
        elseif mode=="public" then N.Net.setConsent("guild")
        elseif mode=="switch" then N.Net.setSwitch("warboard",false)
        elseif mode=="combat" then h.combat(true) else h.instance(true) end
        inbound(hello(),72); advance(5); eq(#sends(),0); eq(N.BNet.queued(),0)
        if mode=="share" then N.Main.setShare(true)
        elseif mode=="public" then N.Net.setConsent("public")
        elseif mode=="switch" then N.Net.setSwitch("warboard",true)
        elseif mode=="combat" then h.combat(false) else h.instance(false) end
        advance(5); eq(#sends(),0,"old answer cannot revive")
    end)
end

test("stand down cancels queued H and A when the real addon loads",function()
    local N=setup()
    local send,checks=N.BNet.send,{}
    N.BNet.send=function(net,id,prefix,text,prio,still,...)
        if net=="warboard" then checks[#checks+1]=still end
        return send(net,id,prefix,text,prio,still,...)
    end
    N.BNet.peers=function() return {{id=71,faction="Horde"}} end
    advance(1); eq(N.BNet.queued(),1,"hello queued before donor loads")
    inbound(hello()); eq(N.BNet.queued(),2,"answer queued before donor loads")
    eq(#sends(),0,"neither frame has reached the client")
    h.loaded().WarBoard=true
    eq(#checks,2)
    -- E2 also checks the transport gate; independently prove the real source's
    -- final predicates, so one redundant guard cannot conceal the other's loss.
    for _,still in ipairs(checks) do no(still(h.clock()),"source final guard honors donor load") end
    advance(2); eq(#sends(),0,"loading the donor cancels both queued kinds")
    eq(N.BNet.queued(),0)
    inbound(hello()); inbound(hello("H","normal"),72)
    advance(2); eq(#sends(),0,"neither same- nor other-ruleset H is answered")
    h.loaded().WarBoard=false
    advance(60); eq(#sends(),0,"cancelled work never revives")
    inbound(hello()); advance(1); eq(#sends("A"),1,"fresh traffic works without the donor")
end)

test("live account identity and ruleset rechecked at dispatch",function()
    local N=setup(); inbound(hello())
    GetRealmName=function() return "Normal 123" end
    advance(1); eq(#sends(),0)
    N=setup(); inbound(hello())
    local old=C_BattleNet.GetGameAccountInfoByID
    C_BattleNet.GetGameAccountInfoByID=function(id) local r=old(id); r.factionName="Alliance"; return r end
    advance(1); eq(#sends(),0)
end)

-- All tests, including receive-only/fuzz additions below, share the send allowlist.
local function wire(N,t,d,extra)
    local e={t=t,v=5,rs="pvp",d=d}
    for k,v in pairs(extra or {}) do e[k]=v end
    return N.Codec.addonEncode(N.Codec.deflateStored(N.Codec.aceWrite(e)))
end
local function data(N,t,d,extra,id) inbound("WBF1|D|"..wire(N,t,d,extra),id) end
local function shrd(seq)
    return {faction="Horde",guid="Player-1-ABC",name="Enemy",realm="Player",sentAt=seq or h.wall()*1000,
        isGroupLeader=false,shard="123",zone="Ashenvale",mapID=100}
end
local function position()
    return {targetName="Enemy Player",targetGuid="Player-1-ABC",faction="Horde",rank=3,worldX=12,worldY=34,
        instanceID=1,zone="Ashenvale",subZone="Astranaar",shard="123",sentAt=h.wall(),roster={}}
end
local function kill(kind)
    return {id="example",guid="Player-1-ABC",name="Enemy Player",faction="Horde",rv=3,atype=kind or "pvp_kill",
        creditDelta=1,contributionDelta=1,kills=1,t=h.wall(),zone="Ashenvale"}
end
local function row(N) return N.Find.rows(N.Main.find,h.clock(),100)[1] end
local function known(N,name)
    local p=N.Known.get(N.Main.find.known,name or "Enemy Player-123",h.clock()); return p and p.reported
end
local function confirmed(N,id) inbound(hello("A"),id) end
local function localData(N,t,d,dist,sender,prefix,extra)
    for _,part in ipairs(N.Codec.aceCommSplit(wire(N,t,d,extra))) do
        h.deliver("CHAT_MSG_ADDON",prefix or "WarBoard",part,dist or "GUILD",sender or "Enemy Player-123")
    end
end

for _,loaded in ipairs({true,false}) do
    test((loaded and "stand down" or "donor absent").." H and A over thirty minutes of incoming H traffic",function()
        local N=setup("Enemy Player"); h.loaded().WarBoard=loaded
        eq(C_AddOns.IsAddOnLoaded("WarBoard"),loaded,"use addon-loaded state, not donor saved tables")
        local scans,attempts,received=0,0,0
        N.BNet.peers=function() scans=scans+1; return {{id=71,faction="Horde"}} end
        local queued=N.BNet.send
        N.BNet.send=function(net,...)
            if net=="warboard" then attempts=attempts+1 end
            return queued(net,...)
        end
        for _=1,30 do
            for i=1,6 do inbound(hello("H",i<=4 and "pvp" or "normal"),70+i) end
            yes(N.WarBoard.state.peers[71],"matching H is still read")
            eq(N.WarBoard.state.peers[75],nil,"other-ruleset H is not a peer")
            inbound(hello("A"),77); yes(N.WarBoard.state.peers[77],"A is still read, never answered")
            data(N,"SHRD",shrd())
            local r=row(N)
            eq(r.source,"warboard"); eq(r.shard,"123"); eq(r.got,h.clock(),"fresh BN payload still reaches Find")
            eq(r.evidenceKind,"self"); no(r.canAsk); received=received+1
            advance(60)
        end
        local hellos,answers=#sends("H"),#sends("A")
        print("STANDDOWN loaded="..tostring(loaded).." minutes=30 H="..hellos.." A="..answers.." scans="..scans.." BN_SHRD="..received)
        eq(hellos,loaded and 0 or 3,"thirty-minute H count")
        eq(answers,loaded and 0 or 180,"thirty-minute A count")
        eq(#sends(),hellos+answers,"no other WarBoard message kind")
        eq(attempts,loaded and 0 or 183,"stand down never even submits to the send queue")
        eq(scans,loaded and 0 or 30,"stand down leaves discovery stopped")
        eq(N.BNet.queued(),0); no(N.Main.error)
    end)
end

test("SHRD own zone and shard through registry, with sequence not seconds; clear and expiry",function()
    local N=setup("Enemy Player"); confirmed(N)
    data(N,"SHRD",shrd(),{ttl=1})
    local r=row(N); eq(r.source,"warboard"); eq(r.zone,100); eq(r.shard,"123"); no(r.layer); no(r.canAsk)
    eq(r.evidenceKind,"self"); eq(r.observedAt,nil); yes(r.detail:find("time unknown",1,true))
    local text=N.Main.findDetails(r); yes(text:find("shard 123",1,true)); yes(text:find("Ashenvale",1,true))
    local at=h.clock(); h.clock(at+179); yes(row(N).reported)
    h.clock(at+180); no(row(N).reported); no(known(N))
    h.clock(at+181); h.wall(h.wall()+181); data(N,"SHRD",shrd(),{ttl=1}); yes(row(N).reported)
    local d=shrd(h.wall()*1000+1); d.clear=true; d.zone=nil; d.shard=nil
    data(N,"SHRD",d,{ttl=1}); no(row(N).reported); no(known(N))
    data(N,"SHRD",shrd(),{ttl=1}); no(row(N).reported,"older sequence cannot undo clear")
end)

test("FBLP world coordinates convert only via client with axis order; labels survive no conversion",function()
    local N=setup("Enemy Player"); confirmed(N)
    data(N,"FBLP",position()); local r=row(N)
    eq(r.evidenceKind,"self"); eq(r.x,nil); eq(r.y,nil)
    yes(r.detail:find("Astranaar",1,true)); yes(r.detail:find("own position",1,true))
    CreateVector2D=function(x,y) eq(x,34); eq(y,12); return {x=x,y=y} end
    C_Map.GetMapPosFromWorldPos=function(instance,v) eq(instance,1); eq(v.x,34); eq(v.y,12)
        return 100,{GetXY=function() return .2,.4 end} end
    local d=position(); d.approximate=true; d.sentAt=d.sentAt+1
    data(N,"FBLP",d); r=row(N); eq(r.x,.2); eq(r.y,.4); eq(r.map,100)
    yes(r.detail:find("approximate",1,true)); yes(r.detail:find("labels are current",1,true))
    no(r.canAsk); no(r.layer)
    local text=N.Main.findDetails(r); yes(text:find("20,40",1,true)); yes(text:find("Astranaar",1,true))
end)

test("FREC names killer not victim, self witness relay and cached retain original age",function()
    local N=setup("Enemy Player"); confirmed(N)
    local d=kill(); d.t=d.t-50
    data(N,"FREC",d); local r=row(N); eq(r.evidenceKind,"self"); eq(r.age,50)
    yes(r.detail:find("killer zone",1,true)); eq(r.observedAt,h.clock()-50)
    d=kill("witnessed_pvp_kill"); d.creditDelta=0; d.witnessName="Other Witness"; d.witnessGuid="Player-1-BBB"; d.targetGuid="Player-1-CCC"
    localData(N,"FREC",d,"PARTY","Other Witness"); eq(row(N).evidenceKind,"witness")
    d.id="relay"; localData(N,"FREC",d,"GUILD","Relay Carrier"); eq(row(N).evidenceKind,"relayed")
    h.clock(h.clock()+1); h.wall(h.wall()+1); d.id="snapshot"; d.t=h.wall()
    data(N,"FCBD",{requestId="id",kind="witnessed_kills",page=1,rulesVersion=3,relayName="Enemy Player",
        relayGuid="Player-1-ABC",faction="Horde",entries={d}})
    eq(row(N).evidenceKind,"cached")
end)

test("FBLC and FCBD coarse locations are cached, no ledger saved or victim sighting fabricated",function()
    local N=setup("Enemy Player"); confirmed(N)
    local d={targetGuid="Player-1-ABC",targetName="Enemy Player",zone="Ashenvale",faction="Horde",sentAt=h.wall()-70}
    data(N,"FBLC",d); eq(row(N).evidenceKind,"cached"); eq(row(N).age,70)
    d.sentAt=h.wall()-10
    data(N,"FCBD",{requestId="id",kind="bounty_locations",page=1,rulesVersion=3,relayName="Enemy Player",
        relayGuid="Player-1-ABC",faction="Horde",entries={d}})
    eq(row(N).age,10); eq(row(N).evidenceKind,"cached")
    eq(LayerEnemiesDB.warboard,nil); eq(LayerEnemiesDB.players,nil)
end)

test("unconfirmed wrong faction expired peer and reused account identity cannot inject data",function()
    local N=setup("Enemy Player")
    data(N,"SHRD",shrd()); no(row(N).reported)
    confirmed(N); local d=shrd(); d.faction="Alliance"; data(N,"SHRD",d); no(row(N).reported)
    h.clock(h.clock()+1200); h.wall(h.wall()+1200); data(N,"SHRD",shrd()); no(row(N).reported)
    confirmed(N); local read=C_BattleNet.GetGameAccountInfoByID
    C_BattleNet.GetGameAccountInfoByID=function(id) local r=read(id); r.characterName="Different Person"; return r end
    data(N,"SHRD",shrd()); no(row(N).reported)
end)

test("addon routes use honest relayed labels, read under stand-down, never whisper or send",function()
    for _,dist in ipairs({"GUILD","PARTY","RAID","CHANNEL"}) do
        for _,prefix in ipairs({"WarBoard","WarBoardBN"}) do
            local N=setup("Enemy Player"); h.loaded().WarBoard=true
            localData(N,"SHRD",shrd(),dist,"Relay Carrier",prefix)
            eq(row(N).evidenceKind,"relayed",dist..prefix); eq(#sends(),0)
            local sounds=0; N.Main.alertSound=function() sounds=sounds+1 end
            N.Main.findAlerts(); eq(sounds,0)
        end
    end
    local N=setup("Enemy Player"); localData(N,"SHRD",shrd(),"WHISPER"); no(row(N).reported)
end)

test("only own Find or live guild Watch names stored; no arbitrary name memory",function()
    local N=setup(); confirmed(N); data(N,"SHRD",shrd()); eq(next(N.Main.find.known.entries),nil)
    eq(next(N.WarBoard.state.shards),nil)
    local hash=N.Watch.hash("Enemy Player")
    N.Watch.receive(N.Main.watch,"T|1|aa|1|1|"..hash,"Guild Peer",h.clock())
    local d=shrd(); d.sentAt=d.sentAt+1; data(N,"SHRD",d); yes(known(N)); eq(#N.Main.find.names,0)
end)

test("audit D and reordered F vectors decode, encoded pipes stay opaque, dedupe across routes",function()
    local N=setup("Test Scout"); h.wall(1794873600)
    local read=C_BattleNet.GetGameAccountInfoByID
    C_BattleNet.GetGameAccountInfoByID=function(id) local r=read(id); r.characterName="Test Scout"; return r end
    confirmed(N)
    local function hex(s) return (s:gsub("..",function(p) return string.char(tonumber(p,16)) end)) end
    local payload=hex("3d8e5d0b824010457f51d1f6a1f56809158444b7e74b536e25a82beb2ad443bfbd91a099b7e1ce399786672210d89d52a267b6207c4b347d43484f9871349e11adad73eb33a92c71b66df85c70739d3e86503233443e80ee720b85ab899df3b9261f5d9113c7525ed68fcc28596f88facf509395b252f90fa58e9004a5c5abf9329e45936188a2dd7ad735072bda8057cd3dc52bd64cb5d7dbd54a4bdec34d884a9a7dca2c8e1874f905")
    yes(payload:find("|",1,true))
    inbound("WBF1|F|1-2-1|2|2|"..payload:sub(86)); no(row(N).reported)
    inbound("WBF1|F|1-2-1|1|2|"..payload:sub(1,85)); eq(row(N).shard,"123")
    local got=row(N).got; h.clock(h.clock()+10); inbound("WBF1|D|"..payload)
    eq(row(N).got,got,"dedupe retains first receipt")
    h.deliver("CHAT_MSG_ADDON","WarBoardBN",payload,"CHANNEL","Relay Carrier"); eq(row(N).got,got)
    eq(#sends(),0)
end)

for _,field in ipairs({"v","rs","faction","sentAt","shard","zone","mapID","name","realm","guid","ttl"}) do
    test("invalid SHRD "..field.." fails silent",function()
        local N=setup("Enemy Player"); confirmed(N)
        local d=shrd(); local e={ttl=1}
        if field=="v" then e.v=6 elseif field=="rs" then e.rs="normal" elseif field=="ttl" then e.ttl=2
        elseif field=="faction" then e.faction="Alliance" elseif field=="sentAt" then d.sentAt=(h.wall()-121)*1000
        elseif field=="mapID" then d.mapID=-1 elseif field=="guid" then d.guid=8 else d[field]="bad|data" end
        data(N,"SHRD",d,e); no(row(N).reported); no(N.Main.error)
    end)
end

local function parts(encoded,token,count)
    local out={}; local size=math.ceil(#encoded/count)
    for i=1,count do out[i]="WBF1|F|"..token.."|"..i.."|"..count.."|"..encoded:sub((i-1)*size+1,i*size) end
    return out
end

test("fragment limits sixty four parts sixteen streams ninety seconds and sender isolation",function()
    local N=setup("Enemy Player"); confirmed(N)
    local e=wire(N,"SHRD",shrd())
    local p=parts(e,"aaa",64)
    for i=64,1,-1 do inbound(p[i]) end
    eq(row(N).shard,"123"); eq(next(N.WarBoard.state.parts),nil)
    N=setup("Enemy Player"); confirmed(N); e=wire(N,"SHRD",shrd())
    p=parts(e,"aaa",65); for _,v in ipairs(p) do inbound(v) end; no(row(N).reported)
    N=setup("Enemy Player"); confirmed(N); e=wire(N,"SHRD",shrd())
    -- Spread streams over accounts so the two/account quota cannot mask the
    -- independent global cap. This deliberately migrates the former 16/account fixture.
    for id=72,79 do confirmed(N,id) end
    for i=1,17 do local a=parts(e,string.format("%x",i),2); inbound(a[1],71+math.floor((i-1)/2)) end
    eq(N.Safe.count(N.WarBoard.state.parts),16)
    p=parts(e,"11",2); inbound(p[2],79); no(row(N).reported,"seventeenth stream refused")
    p=parts(e,"1",2); inbound(p[2],72); no(row(N).reported,"different account cannot finish")
    h.clock(h.clock()+90); h.wall(h.wall()+90); inbound(p[2]); no(row(N).reported,"exact expiry")
    eq(N.Safe.count(N.WarBoard.state.parts),1,"expired slots reclaimed before new tail")
end)

test("fragment conflict and first duplicate keep age and contents",function()
    local N=setup("Enemy Player"); confirmed(N)
    local e=wire(N,"SHRD",shrd()); local p=parts(e,"a",2)
    inbound(p[1]); inbound("WBF1|F|a|1|2|corrupt"); inbound(p[2]); yes(row(N).reported)
    N=setup("Enemy Player"); confirmed(N); p=parts(wire(N,"SHRD",shrd()),"a",2)
    inbound(p[1]); inbound("WBF1|F|a|1|3|conflict"); inbound(p[2]); no(row(N).reported)
end)

test("frame four thousand bytes and assembled/inflated limits reject valid oversized data",function()
    local N=setup("Enemy Player"); confirmed(N)
    -- Arbitrary serializer whitespace is legal, making exact size positives possible.
    -- FREC's per-type ceiling exceeds the frame ceiling; SHRD no longer does.
    local text=N.Codec.aceWrite({t="FREC",v=5,rs="pvp",d=kill()})
    local function padded(size)
        for n=size-80,size do
            local e=N.Codec.addonEncode(N.Codec.deflateStored(text..string.rep(" ",n-#text)))
            if #e+7==size then return "WBF1|D|"..e end
        end
        error("no exact-size fixture")
    end
    local exact=padded(4000); eq(#exact,4000); inbound(exact); yes(row(N).reported)
    N=setup("Enemy Player"); confirmed(N)
    local over=padded(4001); eq(#over,4001); inbound(over); no(row(N).reported)
    no(N.WarBoard.decode(string.rep("a",262145)))
    local bomb=assert(io.open("test/fixtures/warboard-bomb.bin","rb")):read("*a")
    no(N.WarBoard.decode(bomb),"independent zlib bomb exceeds inflated ceiling")
end)

test("inbound rolling frame cap applies before decoding and bounds sender rate memory",function()
    local N=setup("Enemy Player"); confirmed(N)
    for _=1,119 do inbound("WBF1|D|invalid") end
    data(N,"SHRD",shrd()); no(row(N).reported,"121st frame rejected")
    h.clock(h.clock()+60); h.wall(h.wall()+60); data(N,"SHRD",shrd()); yes(row(N).reported)
    N=setup()
    for i=1,201 do inbound(hello("A"),i) end
    eq(N.Safe.count(N.WarBoard.state.peers),200); eq(N.Safe.count(N.WarBoard.state.rates),200)
    h.clock(h.clock()+60); h.wall(h.wall()+60); inbound(hello("A"),201)
    eq(N.Safe.count(N.WarBoard.state.peers),200,"peer bound independent of input buckets")
end)

test("dedupe ring bounded at five hundred twelve and one MiB with fresh evidence admitted",function()
    local N=setup("Enemy Player"); confirmed(N)
    for i=1,513 do
        -- Stay inside the new sixteen-decodes/ten-seconds budget so it cannot
        -- conceal a broken accepted-packet eviction bound.
        if i%16==0 then h.clock(h.clock()+10); h.wall(h.wall()+10) end
        local d=kill(); d.id="id"..i; data(N,"FREC",d)
    end
    eq(#N.WarBoard.state.seenOrder,512); yes(N.WarBoard.state.seenBytes<=1048576); yes(row(N).reported)
end)

test("A dispatch cap survives a shared-budget delay and global queue never exceeds thirty",function()
    local N=setup(); queueOtherThirty(N)
    advance(30); eq(#h.sent(),30)
    for i=1,6 do inbound(hello(),70+i) end
    advance(30); eq(#sends(),0,"shared cap holds answers")
    advance(6); eq(#sends("A"),6)
    advance(24) -- sixty since queued, thirty since first actual A
    for i=1,6 do inbound(hello(),80+i) end
    advance(10); eq(#sends("A"),6,"second delayed cohort dropped, not burst")
end)

for _,mode in ipairs({"share","public","switch"}) do
    test(mode.." off then on before timer cannot resurrect queued data",function()
        local N=setup(); inbound(hello()); eq(N.BNet.queued(),1)
        if mode=="share" then N.Main.setShare(false); N.Main.setShare(true)
        elseif mode=="public" then N.Net.setConsent("guild"); N.Net.setConsent("public")
        else N.Net.setSwitch("warboard",false); N.Net.setSwitch("warboard",true) end
        advance(2); eq(#sends(),0)
    end)
end

test("no unsolicited application response or forwarding; FBAK requires verified Find target",function()
    local N=setup("Enemy Player"); confirmed(N)
    for _,t in ipairs({"FBAK","FBUN","FCRQ","KSRQ","WBTP","WBTA","KSTR","FCON","FWDA","FBNT","FBCP","FBCW","FBCL","FBPR","MOVE"}) do
        data(N,t,position()); localData(N,t,position())
    end
    data(N,"SHRD",shrd()); data(N,"FBLP",position()); data(N,"FREC",kill())
    advance(5); eq(#sends(),0); eq(N.badSend,0)
end)

test("source clear cannot erase FBLP or other networks and expiry is measured without UI mutations",function()
    local N=setup("Enemy Player"); confirmed(N)
    data(N,"SHRD",shrd()); data(N,"FBLP",position()); eq(row(N).evidenceTag,"FBLP")
    local d=shrd(h.wall()*1000+1); d.clear=true; data(N,"SHRD",d)
    eq(row(N).evidenceTag,"FBLP")
    yes(N.Sources.register{name="probe",prefixes={}})
    yes(N.Sources.offer{name="Enemy Player-123",net="probe",kind="self",tag="SHRD",zone="Ashenvale",got=h.clock()})
    d.sentAt=d.sentAt+1; data(N,"SHRD",d); eq(row(N).source,"probe")
end)

test("safe fields clocks and conversions fail closed, source input cannot change saved fields",function()
    local N=setup("Enemy Player"); confirmed(N)
    local save=N.Codec.aceWrite(LayerEnemiesDB)
    for _,v in ipairs({h.secret,{},false,42,"",string.rep("a",4001)}) do
        inbound(v); h.deliver("CHAT_MSG_ADDON","WarBoard",v,"GUILD","Enemy Player")
    end
    for _,change in ipairs({{sentAt=h.wall()-121},{sentAt=h.wall()+121},{worldX=100000001},{worldY=-100000001},
        {instanceID=100001},{rank=15},{approximate=1},{subZone=string.rep("a",101)},{shard=string.rep("a",21)},
        {roster={[101]={guid="g",name="n"}}}}) do
        local d=position(); for k,v in pairs(change) do d[k]=v end
        data(N,"FBLP",d); no(row(N).reported)
    end
    h.clock(h.clock()-1); data(N,"FBLP",position()); no(row(N).reported); h.clock(h.clock()+1)
    local old=issecretvalue
    local frame="WBF1|D|"..wire(N,"FBLP",position())
    for _,hidden in ipairs({"PvP 123","Horde",42,71}) do
        _G.issecretvalue=function(v) return rawequal(v,hidden) or old(v) end
        inbound(hello()); inbound(frame)
        _G.issecretvalue=old; no(row(N).reported)
    end
    eq(N.Codec.aceWrite(LayerEnemiesDB),save); no(N.Main.error)
end)

test("relayed FBLP still carries target coordinates and different current zone labels",function()
    local N=setup("Enemy Player")
    CreateVector2D=function(x,y) return {x=x,y=y} end
    C_Map.GetMapPosFromWorldPos=function() return 200,{GetXY=function() return .3,.6 end} end
    local d=position(); d.approximate=true
    localData(N,"FBLP",d,"GUILD","Relay Carrier")
    local r=row(N); eq(r.evidenceKind,"relayed"); eq(r.pos,"enemy"); eq(r.zone,200)
    yes(r.detail:find("Ashenvale",1,true)); yes(r.detail:find("Astranaar",1,true)); yes(r.detail:find("approximate",1,true))
end)

test("client child-map conversion must be converted again to the displayed zone",function()
    local N=setup("Enemy Player"); confirmed(N)
    CreateVector2D=function(x,y) return {x=x,y=y} end
    local calls=0
    C_Map.GetMapPosFromWorldPos=function(instance,vec,override)
        calls=calls+1
        if not override then return 101,{GetXY=function() return .9,.8 end} end
        eq(override,100); return 100,{GetXY=function() return .2,.3 end}
    end
    data(N,"FBLP",position()); local r=row(N); eq(calls,2); eq(r.zone,100); eq(r.map,100); eq(r.x,.2); eq(r.y,.3)
end)

test("FREC optional structural corruption rejected without importing reward logic",function()
    for _,change in ipairs({{isRepeat="yes"},{rewardWarCredit=-1},{clearedBountyIds={"same","same"}},
        {targetName=string.rep("a",81)},{claimVerification=string.rep("a",21)},{witnessGuid=false}}) do
        local N=setup("Enemy Player"); confirmed(N)
        local d=kill(); for k,v in pairs(change) do d[k]=v end
        data(N,"FREC",d); no(row(N).reported)
    end
end)

test("H delayed dispatch never repeats an account before six hundred actual seconds",function()
    local N=setup(); queueOtherThirty(N)
    N.BNet.peers=function() return {{id=71,faction="Horde"}} end
    advance(80); eq(#sends("H"),1)
    advance(570); eq(#sends("H"),1,"queued early does not permit an early actual hello")
end)

-- Real H/A consumers preserve the newer registry's admission and age contracts.
test("H cannot consume owed reserve while six real A answers use it",function()
    local N=setup(); local fixture=assert(loadfile("test/bnet_queue_fixture.lua"))(h)
    local filled=0
    for _,r in ipairs({{"wanted","WNTDB",4},{"overlord","OLQueue",8}}) do
        fixture.register(N,r[1],r[2])
        for _=1,r[3] do yes(N.BNet.send(r[1],71,r[2],"normal","own")); filled=filled+1 end
    end
    local serial=0
    while filled<52 do
        serial=serial+1; local name,prefix="fill"..h.abc(serial),"Fill"..serial
        fixture.register(N,name,prefix)
        for _=1,math.min(fixture.defaultShare(N),52-filled) do
            yes(N.BNet.send(name,71,prefix,"normal","own")); filled=filled+1
        end
    end
    eq(N.BNet.queued(),52)
    N.BNet.peers=function() return {{id=71,faction="Horde"}} end
    N.WarBoard.tick(N.WarBoard.state,N.Adapters.warboardContext())
    eq(N.BNet.queued(),52,"real H cannot take any owed-only slot")
    for i=1,6 do inbound(hello(),70+i) end
    eq(N.BNet.queued(),58,"real A uses six of the eight reserved slots")
    for i=1,2 do
        local name,prefix="owed"..h.abc(i),"Owed"..i
        fixture.register(N,name,prefix); yes(N.BNet.send(name,71,prefix,"owed","owed"))
    end
    eq(N.BNet.queued(),60)
    no(N.BNet.send("warboard",99,"WarBoard","WBF1|A|5|pvp|LayerEnemies/1.1.0|0","owed"))
    advance(6); eq(#sends("A"),6); eq(#sends("H"),0)
    advance(2); eq(#h.sent(),8)
    for _,r in ipairs(h.sent()) do no(r.text=="normal","all owed work precedes normal work") end
    eq(N.BNet.queued(),52); advance(1); eq(#h.sent(),9)
end)

for _,cmd in ipairs({"H","A"}) do for _,elapsed in ipairs({60,60.001,61}) do
    test(cmd.." respects shared queue age at "..elapsed.." seconds",function()
        local N=setup()
        if cmd=="H" then
            N.BNet.peers=function() return {{id=71,faction="Horde"}} end
            N.WarBoard.tick(N.WarBoard.state,N.Adapters.warboardContext())
        else inbound(hello()) end
        eq(N.BNet.queued(),1)
        h.advance(elapsed)
        eq(#sends(cmd),elapsed==60 and 1 or 0,"sixty seconds is live; older H and A expire")
        eq(N.BNet.queued(),0)
        advance(120); eq(#sends(cmd),elapsed==60 and 1 or 0,"expired frames never retry")
    end)
end end

test("H admission gap is six hundred even before dispatch",function()
    local N=setup(); N.BNet.peers=function() return {{id=71,faction="Horde"}} end
    local at=h.clock(); N.WarBoard.tick(N.WarBoard.state,N.Adapters.warboardContext()); eq(N.BNet.queued(),1)
    advance(1); eq(#sends("H"),1)
    h.clock(at+599); N.WarBoard.state.scan=nil
    N.WarBoard.tick(N.WarBoard.state,N.Adapters.warboardContext()); eq(N.BNet.queued(),0)
    h.clock(at+600); N.WarBoard.state.scan=nil
    N.WarBoard.tick(N.WarBoard.state,N.Adapters.warboardContext()); eq(N.BNet.queued(),1)
end)

test("confirmed fragment sender isolation does not confuse identical character accounts",function()
    local N=setup("Enemy Player"); confirmed(N,71); confirmed(N,72)
    local p=parts(wire(N,"SHRD",shrd()),"aaa",2)
    inbound(p[1],71); inbound(p[2],72); no(row(N).reported)
    inbound(p[2],71); yes(row(N).reported)
end)

test("dedupe FBLP retains observed and received clocks across differently routed copies",function()
    local N=setup("Enemy Player"); confirmed(N)
    local e=wire(N,"FBLP",position()); inbound("WBF1|D|"..e)
    local got=row(N).got; local at=row(N).at; h.clock(h.clock()+61) -- beyond the new short-lived hash window
    inbound("WBF1|D|"..e); eq(row(N).got,got); eq(row(N).at,at)
end)

test("dedupe byte bound evicts older accepted encoded packets",function()
    local N=setup("Enemy Player"); confirmed(N)
    for i=1,400 do
        -- Stay inside the new sixteen-decodes/ten-seconds budget so it cannot
        -- conceal a broken accepted-packet eviction bound.
        if i%16==0 then h.clock(h.clock()+10); h.wall(h.wall()+10) end
        local d=kill(); d.id="id"..i
        data(N,"FREC",d,{padding=string.rep("p",3000)})
    end
    yes(row(N).reported); yes(N.WarBoard.state.seenBytes<=1048576)
    yes(#N.WarBoard.state.seenOrder>300,"exercise byte eviction, not decode throttling")
    yes(#N.WarBoard.state.seenOrder<400)
end)

test("untracked FBLP and FREC never reach Known or save names",function()
    local N=setup(); confirmed(N); data(N,"FBLP",position()); data(N,"FREC",kill())
    eq(next(N.Main.find.known.entries),nil); eq(#N.Main.find.names,0); eq(#N.WarBoard.state.seenOrder,0)
end)

test("silent claim poll never alerts or sounds after a source receive",function()
    local N=setup("Enemy Player"); confirmed(N); data(N,"FREC",kill())
    yes(row(N).reported); no(N.Find.alert(N.Main.find,row(N),h.clock()))
    local sounds=0; N.Main.alertSound=function() sounds=sounds+1 end
    N.Main.findAlerts(); eq(sounds,0)
end)

test("SHRD ordering rejects different bytes with equal or older sequences",function()
    local N=setup("Enemy Player"); confirmed(N); data(N,"SHRD",shrd())
    local d=shrd(); d.shard="124"; data(N,"SHRD",d); eq(row(N).shard,"123")
    d.sentAt=d.sentAt-1; d.shard="125"; data(N,"SHRD",d); eq(row(N).shard,"123")
end)

test("rollback refusal drops an H before queuing an answer",function()
    local N=setup(); confirmed(N)
    h.clock(h.clock()+10); h.wall(h.wall()+10); confirmed(N)
    h.clock(h.clock()-1); inbound(hello())
    eq(N.BNet.queued(),0,"rollback must not create new send authority")
end)

test("full WarBoard evidence is measured before laying out the Find row",function()
    local N=setup("Enemy Player"); confirmed(N); local d=position(); d.approximate=true
    d.zone=string.rep("Long zone ",9); d.subZone=string.rep("Long subzone ",7)
    data(N,"FBLP",d); local U=N.UI; U.toggle(); U.select("find")
    local r=U.pool[1]; yes(r and r:IsShown()); local detail=N.Main.findDetails(row(N))
    eq(r.sub:GetText(),detail); yes(r.sub:GetHeight()>=r.sub:GetStringHeight(),"full details measured before height")
    yes(r:GetHeight()>r.sub:GetHeight()+30,"buttons outside wrapped details")
    local policy=N.Main.hopPreview(row(N))
    no(policy.enabled); no(row(N).canAsk,"source hint cannot enable a hop or ask request")
end)

test("SHRD clear and sequence follow the player across direct and relayed identity spellings",function()
    for _,relayFirst in ipairs({false,true}) do
        local N=setup("Enemy Player"); confirmed(N)
        local d=shrd()
        if relayFirst then localData(N,"SHRD",d,"GUILD","Relay Carrier") else data(N,"SHRD",d) end
        yes(row(N).reported)
        local clear=shrd(d.sentAt+1); clear.clear=true; clear.zone=nil; clear.shard=nil
        if relayFirst then data(N,"SHRD",clear) else localData(N,"SHRD",clear,"GUILD","Relay Carrier") end
        no(row(N).reported,"clear crosses carrier spelling")
        -- Different bytes avoid transport dedupe; the player's sequence still wins.
        d.shard="124"; localData(N,"SHRD",d,"GUILD","Relay Carrier"); data(N,"SHRD",d)
        no(row(N).reported,"older cross-route record cannot resurrect a cleared hint")
    end
end)

test("same faction addon records never become tracked enemy evidence",function()
    for _,t in ipairs({"SHRD","FBLP","FREC"}) do
        local N=setup("Enemy Player")
        local d=t=="SHRD" and shrd() or t=="FBLP" and position() or kill()
        d.faction="Alliance"; localData(N,t,d)
        no(row(N).reported); eq(next(N.Main.find.known.entries),nil)
    end
end)

test("5000 deterministic hostile frames terminate within budget with bounded memory",function()
    local N=setup("Enemy Player"); confirmed(N)
    local ctx=N.Adapters.warboardContext(); local seed=123456
    local function rand(n) seed=(seed*48271)%2147483647; return seed%n end
    local encoded=wire(N,"SHRD",shrd())
    for i=1,5000 do
        if i%100==0 then ctx.now=ctx.now+60; ctx.wall=ctx.wall+60; h.clock(ctx.now); h.wall(ctx.wall); confirmed(N) end
        local s={}; for _=1,rand(600) do s[#s+1]=string.char(rand(256)) end; s=table.concat(s)
        if i%4==0 then s="WBF1|D|"..s elseif i%4==1 then s="WBF1|F|a|"..rand(70).."|"..rand(70).."|"..s
        elseif i%4==2 then s="WBF1|D|"..encoded:sub(1,rand(#encoded)) end
        local ticks=0
        debug.sethook(function() ticks=ticks+1; if ticks>500 then error("instruction budget") end end,"",10000)
        local ok,err=pcall(N.WarBoard.bnet,N.WarBoard.state,s,71,ctx)
        debug.sethook(); yes(ok,err); yes(N.Safe.count(N.WarBoard.state.parts)<=16)
        yes(#N.WarBoard.state.seenOrder<=512); yes(N.WarBoard.state.seenBytes<=1048576)
    end
    no(N.Main.error); eq(#sends(),0)
end)
