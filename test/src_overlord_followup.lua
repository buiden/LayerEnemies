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
    C_AddOns.GetAddOnMetadata=function() return "1.1.0" end
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
