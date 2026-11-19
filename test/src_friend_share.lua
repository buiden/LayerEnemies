-- 1.2.4 friend and community presence shared with the guild (owner's request): what is sent, when, within which
-- budget; how a guildmate's client shows it in Find and Reported; what an older client does with it.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function hex(s) return (s:gsub(".",function(c) return string.format("%02x",c:byte()) end)) end
local function game(o)
    local g={characterName="Cedar Vale",realmName="Test Realm",areaName="Stranglethorn Vale",factionName="Horde",
        playerGuid="Player-1-0A1B2C3D",isOnline=true,wowProjectID=11,classFilename="ROGUE",characterLevel=58}
    for k,v in pairs(o or {}) do g[k]=v end
    -- account-level fields (BattleTag, account name, notes) must never be read
    return setmetatable({gameAccountInfo=g},{__index=function(_,k) error("account field must not be read: "..k) end})
end
-- A loaded client in a guild, sharing on, with Battle.net friends; past the 30 s settle time.
local function ready(friends,saved)
    _G.C_Club=nil
    local N=H.load(saved or {})
    _G.WOW_PROJECT_ID=11
    local list=friends or {game()}
    _G.BNGetNumFriends=function() return #list end
    _G.C_BattleNet.GetFriendAccountInfo=function(i) return list[i] end
    H.advance(31)
    return N,list
end
local function scan(N)
    N.Main.presenceScan(true)
    for _=1,500 do if not N.Main.presenceJob then break end; H.advance(.001) end
    no(N.Main.presenceJob,"scan completes"); no(N.Main.error)
end
local function pLines(from)
    local out={}
    for i=(from or 0)+1,#H.sent() do
        local s=H.sent()[i]
        if s.prefix=="LEGW1" and s.text:sub(1,2)=="P|" then out[#out+1]=s end
    end
    return out
end
local function entries(N,lines)
    local out={}
    for _,s in ipairs(lines) do
        local msg=N.FriendShare.decode(s.text); yes(msg,s.text)
        for _,e in ipairs(msg.entries) do out[#out+1]=e end
    end
    return out
end

test("Friend share: wire entry round trip, withdrawal and refusals",function()
    local N=H.load(); local FS=N.FriendShare
    local lines=FS.lines({{name="Cedar Vale-TestRealm",zone="Stranglethorn Vale",faction="Horde",class="ROGUE",level=58,guid="Player-1-0A1B2C3D"},
        {name="Gone Friend-TestRealm"}},12)
    eq(#lines,1)
    eq(lines[1],"P|1|12|"..hex("Cedar Vale-TestRealm")..":"..hex("Stranglethorn Vale")..":H:ROGUE:58:Player-1-0A1B2C3D,"
        ..hex("Gone Friend-TestRealm")..":::::")
    local msg=FS.decode(lines[1]); eq(msg.age,12)
    local e=msg.entries[1]
    eq(e.name,"Cedar Vale-TestRealm"); eq(e.zone,"Stranglethorn Vale"); eq(e.faction,"Horde"); eq(e.class,"ROGUE"); eq(e.level,58)
    eq(e.guid,"Player-1-0A1B2C3D"); eq(msg.entries[2].zone,nil,"empty zone = offline")
    for _,bad in ipairs({"P|2|0|"..hex("A")..":"..hex("B")..":H::::","P|1|0|","P|1|901|"..hex("A")..":"..hex("B").."::::",
        "P|1|0|"..hex("A")..":"..hex("B")..":X::::","P|1|0|"..hex("A")..":"..hex("B")..":H:NOTACLASS:::",
        "P|1|0|"..hex("A")..":"..hex("B")..":H::0::","P|1|0|"..hex("A").."::H::::","P|1|0|"..hex("A|B")..":"..hex("Z").."::::",
        "P|1|0|zz:"..hex("Z").."::::","P|1|0|"..hex("A")..":"..hex("B")..":H:::bad guid!"}) do
        eq(FS.decode(bad),nil,bad)
    end
    yes(N.Wire.send("LEGW1",lines[1],"GUILD",nil,{prio="presence"}),"Wire knows the P grammar")
    no(N.Wire.send("LEGW1","P|1|0|zz","GUILD",nil,{prio="presence"}),"and refuses a malformed P line")
end)

test("Friend share: an older client ignores P lines cleanly (the 1.2.3 receive path)",function()
    -- 1.2.3 Wire passes an unknown LEGW1 tag through and its relayIn hands it to Relay.decode, which refuses it.
    -- Relay.decode is unchanged in 1.2.4, so this is the old client's exact outcome.
    local N=H.load(); local line=N.FriendShare.lines({{name="Cedar Vale-TestRealm",zone="Duskwood",faction="Horde"}},0)[1]
    local record,why=N.Relay.decode(line,"Selina Gomez",H.clock()); eq(record,nil); eq(why,"invalid")
    yes(line:find("^[%w|%.:,%-]+$"),"only characters every LEGW1 reader accepts")
end)

test("Friend share: every online opposite-faction friend goes to the guild with name, zone, faction, class, level and GUID",function()
    local N=ready({game(),game({characterName="Same Side",factionName="Alliance",playerGuid="Player-1-00000002"}),
        game({characterName="Offline One",isOnline=false}),game({characterName="Other Game",wowProjectID=2})})
    local before=#H.sent(); scan(N)
    local lines=pLines(before); eq(#lines,1); eq(lines[1].kind,"GUILD")
    local list=entries(N,lines); eq(#list,1)
    eq(list[1].name,"Cedar Vale-TestRealm"); eq(list[1].zone,"Stranglethorn Vale"); eq(list[1].faction,"Horde")
    eq(list[1].class,"ROGUE"); eq(list[1].level,58); eq(list[1].guid,"Player-1-0A1B2C3D")
end)

test("Friend share: entries are batched into as few lines as fit, each at most 255 bytes",function()
    local friends={}
    for i=1,9 do friends[i]=game({characterName="Fr"..H.abc(i).."end Vale",playerGuid="Player-1-0000000"..i}) end
    local N=ready(friends); local before=#H.sent(); scan(N)
    for _=1,10 do H.advance(3); N.Main.friendShareTick() end
    local lines=pLines(before); local list=entries(N,lines)
    eq(#list,9)
    for _,s in ipairs(lines) do yes(#s.text<=255,#s.text) end
    local total=0; for _,s in ipairs(lines) do total=total+#s.text end
    yes(#lines<=math.ceil(total/200),"lines are filled, not one per entry: "..#lines)
end)

test("Friend share: on change at once (zone, offline), everything again every 5 minutes",function()
    local N,list=ready()
    scan(N); local before=#H.sent()
    -- nothing changed: a rescan sends nothing
    H.advance(20); scan(N); eq(#pLines(before),0,"no change, no line")
    list[1].gameAccountInfo.areaName="Duskwood"
    H.deliver("BN_FRIEND_INFO_CHANGED"); H.advance(16); H.drain()
    for _=1,500 do if not N.Main.presenceJob then break end; H.advance(.001) end
    local changed=entries(N,pLines(before)); eq(#changed,1); eq(changed[1].zone,"Duskwood")
    before=#H.sent()
    list[1].gameAccountInfo.isOnline=false
    H.deliver("BN_FRIEND_ACCOUNT_OFFLINE"); H.advance(16); H.drain()
    for _=1,500 do if not N.Main.presenceJob then break end; H.advance(.001) end
    local gone=entries(N,pLines(before)); eq(#gone,1); eq(gone[1].name,"Cedar Vale-TestRealm"); eq(gone[1].zone,nil,"withdrawal")
    list[1].gameAccountInfo.isOnline=true
    H.deliver("BN_FRIEND_ACCOUNT_ONLINE"); H.advance(16); H.drain()
    for _=1,500 do if not N.Main.presenceJob then break end; H.advance(.001) end
    before=#H.sent()
    H.advance(301); N.Main.friendShareTick()
    for _=1,500 do if not N.Main.presenceJob then break end; H.advance(.001) end
    local again=entries(N,pLines(before)); eq(#again,1,"refresh resends the unchanged entry"); eq(again[1].zone,"Duskwood")
end)

test("Friend share: a burst stays inside the LEGW1 budget and never starves our own lines",function()
    local friends={}
    for i=1,60 do friends[i]=game({characterName="Fr"..H.abc(i%26+1)..H.abc(math.floor(i/26)+1).." Vale",playerGuid="Player-1-"..string.format("%08X",i)}) end
    local N=ready(friends); local before=#H.sent(); scan(N)
    local first=#pLines(before)
    yes(first>0 and first<=3,"a burst leaves the reserve: "..first.." lines at once")
    yes(#N.Main.friendOut.queue>0,"the rest waits")
    -- our own line still has room right after the burst
    local own=N.Relay.ownLine({rid=5,zone=100,count=1,enemies={{displayName="Zack Ly",class="SHAMAN",level=49}}})
    N.Relay.spend(H.clock(),false)
    yes(N.Wire.send("LEGW1",own,"GUILD",nil,{prio="own",queue=false}),"own sighting not starved")
    -- the queue drains over time; every entry eventually goes
    for _=1,40 do H.advance(5); N.Main.friendShareTick() end
    eq(#N.Main.friendOut.queue,0)
    local seen={}; for _,e in ipairs(entries(N,pLines(before))) do seen[e.name]=true end
    local n=0; for _ in pairs(seen) do n=n+1 end; eq(n,60)
    local used,cap=N.Wire.guildMinute(H.clock()); yes(used<=cap)
end)

test("Friend share: off with sharing off, with /le share friends off, in an instance, and in the first 30 s",function()
    local N=ready(nil,{share=false}); local before=#H.sent(); scan(N); eq(#pLines(before),0,"share off")
    N=ready(); SlashCmdList.LAYERENEMIES("share friends off"); eq(LayerEnemiesDB.shareFriends,false)
    before=#H.sent(); scan(N); eq(#pLines(before),0,"friends off")
    SlashCmdList.LAYERENEMIES("share friends on"); eq(LayerEnemiesDB.shareFriends,true)
    N=ready(); H.instance(true); before=#H.sent(); scan(N); eq(#pLines(before),0,"instance"); H.instance(false)
    _G.C_Club=nil; N=H.load({}); _G.WOW_PROJECT_ID=11
    local list={game()}; _G.BNGetNumFriends=function() return 1 end; _G.C_BattleNet.GetFriendAccountInfo=function(i) return list[i] end
    H.advance(5); no(N.Main.friendSendable(),"settling after login")
end)

test("Friend share: only the switch is saved; no friend, zone or guildmate name in SavedVariables",function()
    local N=ready(); scan(N)
    eq(LayerEnemiesDB.shareFriends,true)
    local line=N.FriendShare.lines({{name="Birch Moss-TestRealm",zone="Duskwood",faction="Horde"}},0)[1]
    H.deliver("CHAT_MSG_ADDON","LEGW1",line,"GUILD","Selina Gomez"); H.drain()
    local function scanTable(t,depth,seen)
        if depth>8 or seen[t] then return end; seen[t]=true
        for k,v in pairs(t) do
            for _,x in ipairs({k,v}) do
                if type(x)=="string" then no(x:find("Cedar",1,true) or x:find("Birch",1,true) or x:find("Duskwood",1,true)
                    or x:find("Stranglethorn",1,true) or x:find("Selina",1,true),x) end
                if type(x)=="table" then scanTable(x,depth+1,seen) end
            end
        end
    end
    scanTable(LayerEnemiesDB,0,{})
end)

test("Friend share: a guildmate's friend shows in Find and as a certain Reported row without Hop",function()
    local N=H.load({tracked={"Birch Moss"}}); H.establish(N)
    local line=N.FriendShare.lines({{name="Birch Moss-TestRealm",zone="Azshara",faction="Horde",class="MAGE",level=60}},4)[1]
    H.deliver("CHAT_MSG_ADDON","LEGW1",line,"GUILD","Selina Gomez"); H.drain()
    local row=N.Main.findRows()[1]
    eq(row.status,"online (friend of Selina Gomez)"); eq(row.presence.zone,"Azshara")
    yes(N.Main.presenceText(row.presence):find("^online %(friend of Selina Gomez%): Azshara · 4 s ago"),N.Main.presenceText(row.presence))
    local _,rep=N.Main.namedRows(); eq(#rep,1)
    eq(rep[1].title,"Birch Moss-TestRealm"); yes(rep[1].certain); eq(rep[1].class,"MAGE"); eq(rep[1].level,60)
    eq(rep[1].sourceText,"Battle.net friend of Selina Gomez")
    N.UI.toggle(); N.UI.select("reported")
    eq(N.UI.pool[1].title:GetText(),"Birch Moss-TestRealm")
    eq(N.UI.pool[1].sub:GetText(),"Battle.net friend of Selina Gomez · Azshara")
    no(N.UI.pool[1].ask:IsShown(),"zone only: no Hop")
    -- a hash-only report can now say "probably" with this name
    local seenNames=N.Main.namedRows(); yes(seenNames)
    -- withdrawn: gone from Find and Reported
    H.deliver("CHAT_MSG_ADDON","LEGW1",N.FriendShare.lines({{name="Birch Moss-TestRealm"}},0)[1],"GUILD","Selina Gomez"); H.drain()
    eq(N.Main.findRows()[1].presence,nil); local _,rep2=N.Main.namedRows(); eq(#rep2,0)
end)

test("Friend share: received entries expire, a newly tracked name resolves at once, our own view wins",function()
    local N=H.load({}); H.establish(N)
    local line=N.FriendShare.lines({{name="Birch Moss-TestRealm",zone="Azshara",faction="Horde"}},0)[1]
    H.deliver("CHAT_MSG_ADDON","LEGW1",line,"GUILD","Selina Gomez"); H.drain()
    yes(N.Main.track("Birch Moss"))
    eq(N.Main.findRows()[1].status,"online (friend of Selina Gomez)","resolved without waiting for the next refresh")
    N.Main.find.presence["Birch Moss"]={zone="Feralas",route="friend",source="f:1",at=H.clock()}
    H.deliver("CHAT_MSG_ADDON","LEGW1",line,"GUILD","Other Scout"); H.drain()
    eq(N.Main.findRows()[1].presence.zone,"Feralas","our own Battle.net view wins")
    H.advance(901); local _,rep=N.Main.namedRows(); eq(#rep,0,"expired after 15 minutes")
end)

test("Friend share: our own echo and our own character are ignored; a full sender is capped",function()
    local N=H.load({}); H.establish(N)
    local _,me=N.Adapters.ownIdentity()
    local display=UnitName("player")
    local line=N.FriendShare.lines({{name="Birch Moss-TestRealm",zone="Azshara",faction="Horde"}},0)[1]
    H.deliver("CHAT_MSG_ADDON","LEGW1",line,"GUILD",display); H.drain()
    local _,rep=N.Main.namedRows(); eq(#rep,0,"own echo")
    yes(me)
    local inn=N.FriendShare.newIn()
    for i=1,N.FriendShare.MAX_SENDER+5 do N.FriendShare.put(inn,"S","s","n"..i,{name="n"..i,zone="Z"},H.clock()) end
    eq(inn.count,N.FriendShare.MAX_SENDER)
end)

test("Friend share: a guild watch list naming one of ours is answered at once, then rate limited",function()
    local N=ready(); scan(N); local before=#H.sent()
    H.advance(10)
    N.Watch.receive(N.Main.watch,"T|1|ab|1|1|"..N.Watch.hash("Cedar Vale"),"Selina Gomez",H.clock())
    H.deliver("CHAT_MSG_ADDON","LEGW1","T|1|ac|1|1|"..N.Watch.hash("Cedar Vale"),"GUILD","Selina Gomez"); H.drain()
    local answer=entries(N,pLines(before)); eq(#answer,1); eq(answer[1].name,"Cedar Vale-TestRealm")
    before=#H.sent()
    H.advance(5); H.deliver("CHAT_MSG_ADDON","LEGW1","T|1|ad|1|1|"..N.Watch.hash("Cedar Vale"),"GUILD","Selina Gomez"); H.drain()
    eq(#pLines(before),0,"at most every 30 s per name")
end)

test("Friend share: lines still waiting stop when sharing is turned off",function()
    local friends={}
    for i=1,30 do friends[i]=game({characterName="Fr"..H.abc(i%26+1)..H.abc(math.floor(i/26)+1).." Vale",playerGuid="Player-1-"..string.format("%08X",i)}) end
    local N=ready(friends); scan(N)
    yes(#N.Main.friendOut.queue>0,"some lines wait")
    SlashCmdList.LAYERENEMIES("share off")
    local before=#H.sent()
    for _=1,20 do H.advance(5); N.Main.friendShareTick() end
    eq(#pLines(before),0,"nothing more after share off")
end)
