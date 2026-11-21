-- Reviewer p9 scenarios promoted to assertions at the real Main/client seam.
local H=...
local eq,yes,no=H.eq,H.yes,H.no
local function test(n,f) H.test("Overlord followup: "..n,f) end
local serial=0
local function fixture(o)
    o=o or {}
    local N=H.load();N.Net.SHIP.overlord=true;WOW_PROJECT_ID=42
    Enum.GameRule={HardcoreRuleset=1,RPRuleset=2,PvPRuleset=3}
    C_GameRules={IsGameRuleActive=function(i) return i==3 end}
    C_AddOns.GetAddOnMetadata=function() return "1.3.1" end
    GetNumDisplayChannels=function() return 0 end
    local state={friend=true,party=o.party,guild=o.guild,realm=o.realm or "Test Realm",me="Alice Vale"}
    IsInGroup=function() return state.party~=nil end;IsInRaid=function() return false end
    IsInGuild=function() return state.guild~=nil end
    UnitExists=function(u) return u=="player" or u=="party1" and state.party~=nil end
    GetNumGroupMembers=function() return state.party and 2 or 0 end
    UnitName=function(u)
        if u=="party1" then return state.party[1],state.party[2] end
        return state.me,"Test Realm"
    end
    UnitFactionGroup=function() return "Alliance" end
    GetNumGuildMembers=function() return state.guild and #state.guild or 0 end
    GetGuildRosterInfo=function(i) return state.guild[i],nil,nil,nil,nil,nil,nil,nil,true end
    local function game(id)
        if id~=71 and not (o.two and id==72) then return nil end
        local realm="Test Realm"
        if id==71 then realm=not state.noRealm and state.realm or nil end
        return {gameAccountID=id,characterName=id==71 and "Birch Scout" or "Cedar Scout",
            realmName=realm,
            factionName="Alliance",isOnline=true,clientProgram="WoW",wowProjectID=WOW_PROJECT_ID,isInCurrentRegion=true}
    end
    BNGetNumFriends=function() return (state.friend and 1 or 0)+(o.two and 1 or 0) end
    C_BattleNet.GetFriendNumGameAccounts=function() return 1 end
    C_BattleNet.GetFriendGameAccountInfo=function(i) return game(state.friend and i==1 and 71 or 72) end
    C_BattleNet.GetGameAccountInfoByID=game
    local e=GetServerTime()-100
    local function hear(kind,body)
        serial=serial+1;local id="followup"..serial
        local text=table.concat({N.Main.overlordPool(),id,math.floor(GetServerTime()),state.me,"Birch Scout",kind,body},"|")
        H.deliver("BN_CHAT_MSG_ADDON","OverlordF","R2:Forever_"..N.Main.overlordPool().."_A:BR:"..text,nil,71)
    end
    local function refresh()
        hear("NH","2.5.4~ld~lr~lp6")
        hear("K","Birch Scout:#1434:21:WARRIOR:Alliance:"..e.."::en:0:Human:2:B"..e..":60")
    end
    return N,state,refresh,hear
end
local function sends(op)
    local out={}
    for _,s in ipairs(H.sent()) do
        if s.prefix=="OverlordF" and s.text:find(op,1,true) then out[#out+1]=s end
    end
    return out
end
local function advance(n) for _=1,n do H.advance(1) end end

for version=5,9 do
    test("n3 busy HA version "..version,function()
        local N=H.load();local P=N.OverlordPeer;local peer=P.new();local out={}
        local c={now=100,wall=1800000000,me="Alice Vale",version="1.3.1",pool="global",faction="A",allowed=true,own=true,
            send=function(_,text) out[#out+1]=text;return true end}
        P.receive(peer,{origin="Birch Scout",hops=0,target=c.me,kind="HR",
            payload=version..":V:1799999900:123n4n5f:1:LK:0:0:H"},"WHISPER","Birch Scout",nil,c)
        eq(#out,version==8 and 1 or 0,"only protocol 8 gets a busy answer")
        if version==8 then yes(out[1]:find("|HA|8:R:",1,true)) end
    end)
end

for _,changed in ipairs({"pool","character"}) do
    test("n2 NH clock survives "..changed.." round trip",function()
        local N,state,refresh=fixture({two=true})
        N.Main.overlordTick(H.clock());advance(1)
        local out=sends("|NH|");yes(#out>0);eq(out[1].target,71)
        local announced=out[1].at
        if changed=="pool" then C_GameRules.IsGameRuleActive=function(i) return i==2 end
        else state.me="Other Hero" end
        advance(1) -- second queued NH must not acquire the new context
        -- Send an unrelated presence under the changed context, exercising the
        -- previous destructive reset in P.sent as well as quiet's scope check.
        local c=N.Main.overlordContext()
        N.OverlordPeer.sent(N.Main.overlordPeer,{kind="NH",route="BNET",id=72,name="Cedar Scout",pool=c.pool,me=c.me},c)
        if changed=="pool" then C_GameRules.IsGameRuleActive=function(i) return i==3 end
        else state.me="Alice Vale" end
        refresh();advance(298)
        eq(#sends("|HR|8:V:"),0,"round trip cannot forget the source's actual NH")
        advance(4)
        out=sends("|HR|8:V:");eq(#out,1);yes(out[1].at-announced>300)
    end)
end

for _,mode in ipairs({"combat","instance"}) do
    for _,queued in ipairs({false,true}) do
        for _,duration in ipairs({1,90}) do
            test("n1 deferred stop "..mode.." queued="..tostring(queued).." duration="..duration,function()
                local N,state,refresh=fixture();refresh();advance(2)
                eq(#sends("|HR|8:V:"),1)
                if queued then N.Main.setShare(false);eq(N.BNet.queued(),1) end
                if mode=="combat" then H.combat(true) else H.instance(true) end
                N.Main.setShare(false);N.Main.setShare(false)
                advance(duration);eq(#sends("|HR|8:X:"),0,"unsafe stop remains silent")
                if mode=="combat" then H.combat(false) else H.instance(false) end
                local ended=H.clock();advance(60)
                local out=sends("|HR|8:X:");eq(#out,1,"exactly one after safety resumes")
                yes(out[1].at-ended<=60);advance(90);eq(#sends("|HR|8:X:"),1)
                eq(next(N.Main.overlordFeed.stops),nil)
            end)
        end
    end
end

for _,active in ipairs({false,true}) do
    test("S2 removal invalidates cached friend active="..tostring(active),function()
        local N,state,refresh=fixture()
        eq(#N.BNet.peers(H.clock()),1,"cache is warm")
        if active then refresh();advance(2);eq(#sends("|HR|8:V:"),1) end
        state.friend=false
        H.deliver("BN_FRIEND_LIST_SIZE_CHANGED")
        eq(#N.BNet.peers(H.clock()),0,"event invalidates eligibility immediately")
        if not active then refresh() end
        N.BNet.pump(H.clock());advance(1)
        eq(next(N.Main.overlordFeed.sources),nil)
        eq(#sends("|HR|8:V:"),active and 1 or 0)
        eq(#sends("|HR|8:X:"),active and 1 or 0,"active removal stops without cache expiry")
        advance(75);eq(#sends("|HR|8:X:"),active and 1 or 0)
    end)
end

test("S1 cancellation from a fresh dispatch context queues the stop now",function()
    local N,state,refresh=fixture({two=true});refresh();advance(3)
    eq(#sends("|HR|8:V:"),1);eq(N.BNet.queued(),0)
    state.party={"Birch Scout","Test Realm"}
    local c=N.Main.overlordContext()
    N.OverlordFeed.prepare(N.Main.overlordFeed,N.Main.overlordPeer,c)
    eq(N.BNet.queued(),1,"dispatch-time stop is queued, not waiting for a heartbeat")
    advance(1);eq(#sends("|HR|8:X:"),1)
end)

for offset=100,130 do
    test("S1 senderless cancellation offset "..offset,function()
        local N,state,refresh=fixture({two=true});refresh()
        advance(offset)
        eq(#sends("|HR|8:V:"),1,"actual request before party join")
        state.party={"Birch Scout","Test Realm"}
        advance(75)
        eq(#sends("|HR|8:X:"),1,"one stop at every queue/heartbeat phase")
        advance(130)
        eq(#sends("|HR|8:X:"),1,"no duplicate stop")
        eq(N.Main.error,nil)
    end)
end

for _,case in ipairs({
    {"foreign guild",{realm="Other Realm",guild={"Birch Scout-OtherRealm","Other Guy"}},false},
    {"same guild",{guild={"Birch Scout","Other Guy"}},false},
    {"foreign split party",{realm="Other Realm",party={"Birch Scout","OtherRealm"}},false},
    {"foreign joined party",{realm="Other Realm",party={"Birch Scout-OtherRealm"}},false},
    {"isolated foreign friend",{realm="Other Realm"},true},
    {"different realm namesake guild",{realm="Other Realm",guild={"Birch Scout-TestRealm"}},true},
    {"different realm namesake party",{realm="Other Realm",party={"Birch Scout","Test Realm"}},true},
}) do
    test("M "..case[1],function()
        local N,state,refresh=fixture(case[2]);local selected,leaks=0,0
        local seen=0
        for second=1,1800 do
            if second%100==1 then refresh() end
            H.advance(1)
            local live=N.Main.overlordFeed and next(N.Main.overlordFeed.sources)~=nil
            if live then selected=selected+1 end
            for i=seen+1,#H.sent() do local s=H.sent()[i]
                local audible=s.target==71 or not case[3] and (s.kind=="GUILD" or s.kind=="PARTY")
                if live and audible and s.prefix=="OverlordF" and s.text:find("|NH|",1,true) then leaks=leaks+1 end
            end
            seen=#H.sent()
        end
        eq(leaks,0,"no NH reaches a selected source")
        eq(selected>0,case[3],"realm-aware selection")
        eq(#sends("|HR|8:V:")>0,case[3])
        if case[2].guild or case[2].party then yes(#sends("|NH|")>0,"ordinary C2 lane stays active") end
        eq(N.Main.error,nil)
    end)
end
test("M foreign source hears no qualified whisper NH",function()
    local N,state,refresh=fixture({realm="Other Realm"});refresh();advance(2)
    eq(#sends("|HR|8:V:"),1)
    local id="foreignwhisper";local name="Birch Scout-OtherRealm"
    local wire=table.concat({"global",id,math.floor(GetServerTime()),"Alice Vale",name,"NH","2.5.4~ld~lr~lp6"},"|")
    H.deliver("CHAT_MSG_ADDON","OverlordF","BF:"..id..":1:1:"..wire,"WHISPER",name)
    eq(#sends("|NH|"),0,"full foreign identity matches selected BNet source")
end)

test("M same-name account realm change invalidates old hearing",function()
    local N,state,refresh=fixture({realm="Other Realm"});refresh();advance(2)
    eq(#sends("|HR|8:V:"),1)
    state.realm="Third Realm";H.deliver("BN_FRIEND_LIST_SIZE_CHANGED")
    eq(next(N.Main.overlordFeed.sources),nil,"old character identity is not new first-hand hearing")
    advance(1);eq(#sends("|HR|8:X:"),1)
end)

for _,side in ipairs({"friend","roster"}) do
    test("M unknown realm "..side.." fails closed",function()
        local N,state,refresh=fixture({guild={"Birch Scout-OtherRealm"},realm="Other Realm"})
        if side=="friend" then state.noRealm=true else
            state.guild={"Birch Scout"};GetRealmName=function() return nil end
        end
        refresh();advance(5)
        eq(next(N.Main.overlordFeed.sources),nil);eq(#sends("|HR|8:V:"),0)
    end)
end
