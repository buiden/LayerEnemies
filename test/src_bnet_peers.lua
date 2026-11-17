local h=...
local test,eq,yes,no=h.test,h.eq,h.yes,h.no
local function game(id)
    return {gameAccountID=id,characterName="Other Player",realmName="Other Realm",factionName="Horde",clientProgram="WoW",
        isOnline=true,wowProjectID=42,isInCurrentRegion=true}
end
local function client()
    local N=h.load(); _G.WOW_PROJECT_ID=42
    local games={[71]=game(71),[72]=game(72)}
    C_BattleNet.GetGameAccountInfoByID=function(id) return games[id] end
    C_BattleNet.GetAccountInfoByID=function(id) return {gameAccountInfo=games[id-100]} end
    _G.BNGetNumFriends=function() return 1 end
    C_BattleNet.GetFriendAccountInfo=function() return {gameAccountInfo=games[71]} end
    _G.C_Club={GetSubscribedClubs=function() return {{clubId=5,clubType=0}} end,
        GetClubMembers=function() return {1,2} end,
        GetMemberInfo=function(_,id) return {bnetAccountId=id+170} end}
    return N,games
end

test("BNet: independent peer readers need no presence zone and read no account names",function()
    local N,games=client(); yes(type(N.Adapters.clubPeer)=="function","club peer reader exists")
    local touched={}
    C_Club.GetMemberInfo=function() return setmetatable({bnetAccountId=171},{__index=function(_,k) touched[k]=true; error(k) end}) end
    eq(N.Adapters.clubPeer(5,1),171); eq(next(touched),nil)
    local r=N.Adapters.bnFriendGames(); eq(#r,1); eq(r[1].id,71); eq(r[1].name,"Other Player"); eq(r[1].zone,nil)
    eq(N.Adapters.bnGame(71).id,71); eq(N.Adapters.bnAccount(171).id,71)
    eq(N.Adapters.clubMember(5,1),nil); eq(#N.Adapters.bnFriends(),0,"built presence reader still requires zone")
end)

test("BNet: peers are friends first deduplicated and cached thirty seconds",function()
    local N=client(); yes(N.BNet,"BNet seam exists")
    local count=0; local original=C_Club.GetMemberInfo
    C_Club.GetMemberInfo=function(...) count=count+1; return original(...) end
    local rows=N.BNet.peers(h.clock()); eq(#rows,2); eq(rows[1].id,71); eq(rows[1].friend,true)
    eq(rows[2].id,72); eq(rows[2].friend,false); eq(rows[2].club,5); eq(rows[1].realm,"Other Realm")
    rows[1].id=900; eq(N.BNet.peers(h.clock()+29)[1].id,71); eq(count,2)
    N.BNet.peers(h.clock()+30); eq(count,4); N.BNet.peers(h.clock()-1); eq(count,6)
    local who=N.BNet.who(72); eq(who.name,"Other Player"); eq(who.realm,"Other Realm"); eq(who.faction,"Horde")
end)

test("BNet: live identity rejects offline wrong client project region and conflicting realms",function()
    local N,games=client(); yes(N.BNet)
    for _,pair in ipairs({{"isOnline",false},{"clientProgram","App"},{"wowProjectID",41},{"isInCurrentRegion",false},
        {"characterName","Other Player-WrongRealm"},{"gameAccountID",72}}) do
        games[71]=game(71); games[71][pair[1]]=pair[2]; eq(N.BNet.who(71),nil,pair[1])
    end
    for _,key in ipairs({"gameAccountID","isOnline","clientProgram","wowProjectID","isInCurrentRegion","characterName","realmName","factionName"}) do
        games[71]=game(71); games[71][key]=h.secret; eq(N.BNet.who(71),nil,key)
        games[71]=game(71); games[71][key]=nil; eq(N.BNet.who(71),nil,key.." missing")
    end
    games[71]=setmetatable({},{__index=function() error("bad field") end}); eq(N.BNet.who(71),nil)
    eq(N.BNet.who(h.secret),nil); no(N.Main.error)
end)

test("BNet: nil secret and unavailable readers fail closed without scans in combat instance",function()
    local N=client(); yes(N.BNet)
    _G.C_BattleNet=nil; _G.C_Club=nil; _G.BNGetNumFriends=nil
    eq(#N.BNet.peers(h.clock()),0); eq(N.BNet.who(71),nil)
    eq(N.Adapters.clubPeer(5,1),nil); eq(N.Adapters.bnAccount(171),nil); eq(N.Adapters.bnFriendGames(),nil)
    N=client(); local count=0; BNGetNumFriends=function() count=count+1; return 1 end
    h.combat(true); eq(#N.BNet.peers(h.clock()),0); eq(N.BNet.who(71),nil); eq(count,0)
    h.combat(false); h.instance(true); eq(#N.BNet.peers(h.clock()),0); eq(count,0)
    h.instance(false); C_Club.GetMemberInfo=function() return {bnetAccountId=h.secret} end
    local row,why=N.Adapters.clubPeer(5,1); eq(row,nil); eq(why,"secret")
end)

test("BNet: thousand member club bounded and friend game enumeration capped",function()
    local N=client(); yes(N.BNet)
    local count=0
    C_Club.GetClubMembers=function() local t={}; for i=1,1001 do t[i]=i end; return t end
    C_Club.GetMemberInfo=function(_,id) count=count+1; return {bnetAccountId=1000+id} end
    C_BattleNet.GetAccountInfoByID=function(id) return {gameAccountInfo=game(id)} end
    local r=N.BNet.peers(h.clock()); eq(count,1000); eq(#r,1001)
    local nf,ng=0,0
    BNGetNumFriends=function() return 201 end
    C_BattleNet.GetFriendNumGameAccounts=function() nf=nf+1; return 11 end
    C_BattleNet.GetFriendGameAccountInfo=function(i,j) ng=ng+1; return game(i*100+j) end
    r=N.Adapters.bnFriendGames(); eq(nf,200); eq(ng,2000); eq(#r,2000)
end)
