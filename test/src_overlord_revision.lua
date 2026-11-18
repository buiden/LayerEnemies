-- PLAN 6.5.1: real Main/queue/client boundary, no donor executed.
local H=...
local eq,yes,no=H.eq,H.yes,H.no
local function test(n,f) H.test("Overlord revision: "..n,f) end
local serial=0
local function fixture(name,mode)
    name=name or "Birch Scout"
    local N=H.load();N.Net.SHIP.overlord=true
    Enum.GameRule={HardcoreRuleset=1,RPRuleset=2,PvPRuleset=3}
    C_GameRules={IsGameRuleActive=function(i) return i==3 end}
    C_AddOns.GetAddOnMetadata=function() return "1.1.0" end
    GetNumDisplayChannels=function() return 0 end
    local member=mode=="group" or mode=="qualified" or mode=="dual" or mode=="unreadable"
    local guild=mode=="guild" or mode=="badguild"
    IsInGroup=function() return member end;IsInRaid=function() return false end
    IsInGuild=function() return guild end
    UnitExists=function(u) return u=="player" or member and mode~="unreadable" and u=="party1" end
    GetNumGroupMembers=function() return member and 2 or 0 end
    UnitName=function(u)
        if u=="party1" then return mode=="qualified" and name.."-TestRealm" or name end
        return "Alice Vale","Test Realm"
    end
    UnitFactionGroup=function() return "Alliance" end
    GetNumGuildMembers=function() return guild and 1 or 0 end
    GetGuildRosterInfo=function()
        if mode=="badguild" then return nil end
        return name.."-TestRealm",nil,nil,nil,nil,nil,nil,nil,true
    end
    local online=true
    local spelling=(mode=="dual" or mode=="alias") and N.Find.fold(name).."-TestRealm" or name
    N.BNet.peers=function() return {{id=71,name=spelling,faction="Horde",friend=true,realm="Test Realm"}} end
    N.BNet.who=function(id) return online and id==71 and {name=spelling,faction="Horde",realm="Test Realm"} or nil end
    local e=GetServerTime()-100
    local function hear(kind,body,route,pool)
        serial=serial+1;local id="revision"..serial
        local packet=table.concat({pool or "global",id,math.floor(GetServerTime()),"Alice Vale",name,kind,body},"|")
        if route=="WHISPER" then H.deliver("CHAT_MSG_ADDON","OverlordF","BF:"..id..":1:1:"..packet,route,name)
        else H.deliver("BN_CHAT_MSG_ADDON","OverlordF","R2:Forever_"..(pool or "global").."_H:BR:"..packet,nil,71) end
    end
    local function refresh(route,pool)
        hear("NH","2.5.4~ld~lr~lp6",route,pool)
        hear("K",name..":#1434:21:WARRIOR:Horde:"..e.."::en:0:Orc:2:B"..e..":60",route,pool)
    end
    return N,refresh,hear,e,function(v) online=v end
end
local function sends(op)
    local out={}
    for _,s in ipairs(H.sent()) do
        if s.prefix=="OverlordF" and s.text:find(op,1,true) then out[#out+1]=s end
    end
    return out
end
H.overlordRevision={fixture=fixture,sends=sends}
for _,row in ipairs({{"Élan Scout","guild"},{"Ølaf Scout","guild"},{"Борис Скаут","guild"},
    {"Birch Scout","unreadable"},{"Birch Scout","qualified"},{"Birch Scout","dual"},{"Birch Scout","group"},{"Birch Scout","badguild"}}) do
    test("M excludes audible friend "..row[1].." "..row[2],function()
        local N,refresh=fixture(row[1],row[2]);local selected,leaks=0,0
        local route=row[2]=="dual" and "WHISPER" or nil
        refresh(route)
        local seen=0
        for second=1,900 do
            if second%120==0 then refresh(route) end
            H.advance(1)
            local st=N.Main.overlordFeed
            local live=st and next(st.sources)~=nil
            if live then selected=selected+1 end
            for i=seen+1,#H.sent() do local s=H.sent()[i]
                if live and s.prefix=="OverlordF" and s.text:find("|NH|",1,true) then
                    if s.target==71 or s.kind=="GUILD" and row[2]=="guild" or s.kind=="PARTY" and row[2]~="guild" then leaks=leaks+1 end
                end
            end
            seen=#H.sent()
        end
        local lane=row[2]=="guild" or row[2]=="badguild";local nh=0
        for _,s in ipairs(sends("|NH|")) do if s.kind==(lane and "GUILD" or "PARTY") then nh=nh+1 end end
        print("PROBE isolation "..row[1].." "..row[2]..": selectedTicks="..selected.." sourceNH="..leaks.." laneNH="..nh)
        eq(leaks,0,"no NH to any selected source over 900 seconds")
        eq(selected,0,"audible or possibly audible friends are not feed sources")
        yes(nh>0,"C2 broadcast lane remains active")
        eq(#sends("|HR|8:V:"),0)
    end)
end

test("M group-only peer stays C2 and is never asked",function()
    local N,refresh=fixture("Birch Scout","group");N.BNet.peers=function() return {} end
    refresh("WHISPER")
    for i=1,900 do if i%120==0 then refresh("WHISPER") end;H.advance(1) end
    eq(next(N.Main.overlordFeed.sources),nil);eq(#sends("|HR|8:V:"),0)
    yes(#sends("|NH|")>0)
end)

test("M Unicode realm BNet alias is silent while selected",function()
    local N,refresh=fixture("Élan Scout","alias");refresh()
    for i=1,900 do if i%120==0 then refresh() end;H.advance(1) end
    yes(next(N.Main.overlordFeed.sources),"positive eligible source")
    eq(#sends("|NH|"),0);yes(#sends("|HR|8:V:")>0)
end)

test("clock never-sent account starts without artificial wait",function()
    local N,refresh=fixture();refresh();N.Main.overlordTick(H.clock());H.advance(1)
    eq(#sends("|HR|8:V:"),1,"never sent NH: immediate first request")
    eq(#sends("|NH|"),0)
end)

test("clock retains first-hand friend through sparse 600-second hearing",function()
    local N,refresh=fixture()
    N.Main.overlordTick(H.clock());H.advance(1) -- actual C2 NH before learning the source
    eq(#sends("|NH|"),1);local at=H.clock()
    refresh()
    for i=1,300 do H.advance(1) end
    eq(#sends("|HR|8:V:"),0,"strict >300, not >=300")
    H.advance(1);H.advance(1)
    local req=sends("|HR|8:V:");eq(#req,1,"hearing older than 300 remains eligible")
    yes(req[1].at-at>300)
    for i=1,300 do H.advance(1) end
    refresh();yes(next(N.Main.overlordFeed.sources),"session hearing retained until next sparse probe")
end)

for _,route in ipairs({"BNET","WHISPER","GUILD","PARTY"}) do
    test("clock actual NH restarts quiet on "..route,function()
        local N,refresh=fixture()
        refresh()
        for i=1,320 do if i%120==0 then refresh() end;H.advance(1) end
        yes(#sends("|HR|8:V:")>0,"source was actually requested")
        local c=N.Main.overlordContext()
        c.guildNames={["birch scout"]=true};c.groups={["birch scout"]="A"}
        -- Defence-in-depth: model a completed NH despite admission suppression.
        N.OverlordPeer.sent(N.Main.overlordPeer,{kind="NH",route=route,id=route=="BNET" and 71 or nil,
            name=(route=="BNET" or route=="WHISPER") and "birch scout-TestRealm" or nil,
            pool=c.pool,me=c.me},c)
        local count=#sends("|HR|8:V:")
        for i=1,300 do if i%120==0 then refresh() end;H.advance(1) end
        eq(#sends("|HR|8:V:"),count,"no request during the restarted >300-second quiet clock")
        H.advance(1);H.advance(1);eq(#sends("|HR|8:V:"),count+1)
    end)
end

for _,route in ipairs({"BNET","WHISPER"}) do
    for _,mode in ipairs({"twice","three","switch","consent"}) do
        test("S1 exactly one stop "..route.." "..mode,function()
            local N,refresh=fixture();refresh()
            for i=1,320 do if i%120==0 then refresh() end;H.advance(1) end
            local s=N.Main.overlordFeed.sessions["birch scout"]
            yes(s and s.opened,"actual request opened the session")
            if route=="WHISPER" then
                -- Legacy route cleanup only: no new group/whisper source selection.
                s.route="WHISPER";s.id=nil
            end
            N.Main.setShare(false)
            local stop=N.Main.overlordFeed.stops["birch scout"]
            local text=stop and stop.text
            if mode=="switch" then N.Net.setSwitch("overlord",false)
            elseif mode=="consent" then N.Net.setConsent("guild")
            else N.Main.setShare(false);if mode=="three" then N.Main.setShare(false) end end
            if route=="BNET" then
                eq(N.Main.overlordFeed.stops["birch scout"].text,text,"preserve the exact queued withdrawal through repeated off")
            end
            for i=1,5 do H.advance(1) end
            local stops=sends("|HR|8:X:")
            print("PROBE stop "..route.." "..mode..": X="..#stops)
            eq(#stops,1,"same-tick cancellation preserves exactly one owed stop")
            eq(stops[1].kind,route=="BNET" and "BN" or "WHISPER")
            for i=1,70 do H.advance(1) end
            eq(#sends("|HR|8:X:"),1,"never retry a completed stop")
        end)
    end
end

test("S2 silent source backs off to 1800 seconds",function()
    local N,refresh=fixture();refresh()
    for i=1,7000 do if i%120==0 then refresh() end;H.advance(1) end
    local out=sends("|HR|8:V:");local gaps={}
    for i=2,#out do gaps[#gaps+1]=out[i].at-out[i-1].at end
    print("PROBE backoff: requests="..#out.." gaps="..table.concat(gaps,","))
    yes(#out>=6 and #out<=8,"bounded requests with cap reached")
    for i,gap in ipairs(gaps) do eq(gap,math.min(1800,200*2^(i-1)),"silent-source exponential backoff") end
end)
for _,reply in ipairs({"R","S","P","HB"}) do
    test("S2 any valid reply resets backoff "..reply,function()
        local N,refresh,hear,e=fixture();refresh()
        for i=1,800 do if i%120==0 then refresh() end;H.advance(1) end
        local s=N.Main.overlordFeed.sessions["birch scout"];yes(s and s.asked)
        local n=#sends("|HR|8:V:")+ #sends("|HR|8:K:")
        if reply=="HB" then hear("HB","8:U:"..e..":")
        else
            local tail=reply=="S" and ":LK:0:0" or reply=="P" and ":V:0:64:0:-:1:LK" or ""
            hear("HA","8:"..reply..":"..e..":"..s.nonce..":1"..tail)
        end
        for i=1,3 do H.advance(1) end
        eq(#sends("|HR|8:V:")+ #sends("|HR|8:K:"),n+1,"reply restores the base 200-second interval")
        eq(s.delay,200,"reply reset is explicit")
    end)
end

test("memory remembered friends do not bypass C2 route ceilings",function()
    local N=H.load();local P,Q=N.OverlordPeer,N.OverlordFeed
    local peer=P.new();peer.feed=Q.new()
    local c={now=100,wall=1800000000,me="Alice Vale",version="1.1.0",pool="global",faction="A",allowed=true,own=true,
        groups={},guildNames={},friends={},send=function() return true end}
    local function hear(i)
        local name="Peer"..H.abc(i).." Scout"
        P.receive(peer,{origin=name,pool=c.pool,target=c.me,hops=0,kind="NH",payload="2.5.4"},"BNET",name,i,c)
    end
    for i=1,201 do c.now=c.now+301;hear(i) end
    eq(N.Safe.count(peer.feed.heard),200,"bounded session evidence")
    peer.routes={}
    for i=1,200 do hear(i) end
    eq(N.Safe.count(peer.routes),96,"cached metadata cannot bypass the public route ceiling")
end)
test("clock exact 300-second client dispatch is refused",function()
    local N,refresh=fixture();refresh()
    local P,Q=N.OverlordPeer,N.OverlordFeed
    local peer,st=N.Main.overlordPeer,N.Main.overlordFeed
    local c=N.Main.overlordContext();local sent=0
    P.sent(peer,{kind="NH",route="BNET",id=71,name="Birch Scout",pool=c.pool,me=c.me},c)
    c.send=function(_,text,route,target,prio,job)
        if not P.claim(peer,job,c) then return false end
        sent=sent+1;P.sent(peer,job,c);return true
    end
    c.now=c.now+300;Q.tick(st,peer,c);eq(sent,0,"donor retains NH capability at age 300")
    c.now=c.now+.001;Q.tick(st,peer,c);eq(sent,1,"strictly past 300 is eligible")
end)
test("clock once-heard online friend stays selected for 7000 seconds",function()
    local N,refresh=fixture();refresh()
    for i=1,7000 do H.advance(1) end
    eq(#sends("|NH|"),0);eq(#sends("|HR|8:V:"),7)
    yes(N.Main.overlordFeed.sources["birch scout"])
end)
test("M queued request loses eligibility when source joins party",function()
    local N,refresh=fixture();refresh();N.Main.overlordTick(H.clock())
    eq(N.BNet.queued(),1)
    IsInGroup=function() return true end
    GetNumGroupMembers=function() return 2 end
    UnitExists=function(u) return u=="player" or u=="party1" end
    UnitName=function(u) return u=="party1" and "Birch Scout-TestRealm" or "Alice Vale","Test Realm" end
    H.advance(1);H.advance(1)
    eq(#sends("|HR|8:V:"),0);eq(next(N.Main.overlordFeed.sources),nil)
    local party=0;for _,s in ipairs(sends("|NH|")) do if s.kind=="PARTY" then party=party+1 end end
    eq(party,1,"C2 party presence is not suppressed")
end)

test("S3 only HR V gets a bounded busy HA",function()
    for _,op in ipairs({"V","F","K","X","T"}) do
        local N=H.load();local P=N.OverlordPeer;local peer=P.new();local out={}
        local c={now=100,wall=1800000000,me="Alice Vale",version="1.1.0",pool="global",faction="A",allowed=true,own=true,
            send=function(_,text) out[#out+1]=text;return true end}
        local body="8:"..op..":1799999900:123n4n5f:1:LK:0:0:H"
        if op=="K" or op=="X" then body="8:"..op..":1799999900" end
        P.receive(peer,{kind="HR",payload=body,origin="Birch Scout",target=c.me,hops=0},"WHISPER","Birch Scout",nil,c)
        eq(#out,op=="V" and 1 or 0,op.." reply policy")
        if op=="V" then yes(out[1]:find("|HA|8:R:",1,true)) end
    end
end)
test("S3 README states Battle.net scope reply kinds and backoff",function()
    local f=assert(io.open("README.md","r"));local text=f:read("*a");f:close()
    no(text:find("All incoming HR asks",1,true),"do not promise answers to every HR")
    yes(text:find("Only addressed HR V requests get a bounded busy HA",1,true))
    yes(text:find("HR F, K and X get no reply",1,true))
    yes(text:find("Feed sources are Battle.net friends only",1,true))
    yes(text:find("200, 400, 800, 1600, then 1800 s",1,true))
    no(text:find("**Presence trade-off:**",1,true),"no whole-lane presence sacrifice")
end)

test("M club-only account is never a source",function()
    local N,refresh=fixture()
    N.BNet.peers=function() return {{id=71,name="Birch Scout",faction="Horde",friend=false,club=4,realm="Test Realm"}} end
    refresh()
    for i=1,900 do if i%120==0 then refresh() end;H.advance(1) end
    eq(next(N.Main.overlordFeed.sources),nil,"online club members are not Battle.net friends")
    eq(#sends("|HR|8:V:"),0)
end)

test("M same-faction Battle.net friend is an eligible NH-free source",function()
    local N=fixture()
    N.BNet.peers=function() return {{id=71,name="Birch Scout",faction="Alliance",friend=true,realm="Test Realm"}} end
    N.BNet.who=function(id) return id==71 and {name="Birch Scout",faction="Alliance",realm="Test Realm"} or nil end
    local e=GetServerTime()-100
    local function hear()
        serial=serial+1;local id="samefriend"..serial
        local body="Birch Scout:#1434:21:WARRIOR:Alliance:"..e.."::en:0:Human:2:B"..e..":60"
        local packet=table.concat({"global",id,math.floor(GetServerTime()),"Alice Vale","Birch Scout","K",body},"|")
        H.deliver("BN_CHAT_MSG_ADDON","OverlordF","R2:Forever_global_A:BR:"..packet,nil,71)
    end
    hear();N.Main.overlordTick(H.clock());H.advance(1)
    eq(#sends("|HR|8:V:"),1,"same-faction direct K is sufficient first-hand evidence")
    for i=1,900 do if i%120==0 then hear() end;H.advance(1) end
    yes(N.Main.overlordFeed.sources["birch scout"])
    eq(#sends("|NH|"),0)
end)

test("clock ignores unselected account NH and rejects offline or foreign-pool friends",function()
    local N,refresh,hear,e,online=fixture()
    refresh(nil,"pve");N.Main.overlordTick(H.clock());H.advance(1)
    eq(#sends("|HR|8:V:"),0)
    refresh();online(false)
    N.Main.overlordTick(H.clock())
    eq(next(N.Main.overlordFeed.sources),nil,"offline account is not a selected source even before queue dispatch")
    for i=1,400 do H.advance(1) end
    eq(#sends("|HR|8:V:"),0,"cached friend list is not live game-account presence")
end)
