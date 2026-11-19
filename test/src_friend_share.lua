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
    eq(lines[1],"P|1|12|Cedar.Vale-TestRealm:Stranglethorn.Vale:H:4:58:1-0A1B2C3D,Gone.Friend-TestRealm:::::")
    local msg=FS.decode(lines[1]); eq(msg.age,12)
    local e=msg.entries[1]
    eq(e.name,"Cedar Vale-TestRealm"); eq(e.zone,"Stranglethorn Vale"); eq(e.faction,"Horde"); eq(e.class,"ROGUE"); eq(e.level,58)
    eq(e.guid,"Player-1-0A1B2C3D"); eq(msg.entries[2].zone,nil,"empty zone = offline")
    -- escapes: apostrophe, colon and non-ASCII names and zones survive the trip
    local odd=FS.lines({{name="Zoë Mal'Ganis-Area 52",zone="Dire Maul: North",faction="Alliance",class="EVOKER",level=70,guid="Player-3676-0ABCDEF0"}},0)[1]
    eq(odd,"P|1|0|Zo/C3/AB.Mal/27Ganis-Area.52:Dire.Maul/3A.North:A:13:70:3676-0ABCDEF0")
    local back=FS.decode(odd).entries[1]
    eq(back.name,"Zoë Mal'Ganis-Area 52"); eq(back.zone,"Dire Maul: North"); eq(back.class,"EVOKER"); eq(back.guid,"Player-3676-0ABCDEF0")
    for _,bad in ipairs({"P|2|0|A:B:H:::","P|1|0|","P|1|901|A:B::::","P|1|0|A:B:X:::","P|1|0|A:B:H:14::",
        "P|1|0|A:B:H:0::","P|1|0|A:B:H:04::","P|1|0|A:B:H::0:","P|1|0|A:B:H::060:","P|1|0|A::H:::","P|1|0|A/7CB:Z::::",
        "P|1|0|A/zz:Z::::","P|1|0|A/4:Z::::","P|1|0|A_B:Z::::","P|1|0|A:B:H:::bad.guid","P|1|0|A:B:H:::Creature-1-AA","P|1|0|A:B:H:::1-ZZ",
        -- invalid UTF-8 (a lone continuation byte, an overlong form, a surrogate) and control bytes, in name or zone
        "P|1|0|B/FF/FE.Zz:Azshara:H:::","P|1|0|Cc:Az/FF/FE:H:::","P|1|0|A:/C0/AF:H:::","P|1|0|A:/ED/A0/80:H:::",
        "P|1|0|A/0A:B:H:::","P|1|0|A:B/00:H:::","P|1|0|A:/7Cc/FF:H:::"}) do
        eq(FS.decode(bad),nil,bad)
    end
    yes(FS.decode("P|1|0|A:B:H:::"),"bare entry")
    yes(N.Wire.send("LEGW1",lines[1],"GUILD",nil,{prio="presence"}),"Wire knows the P grammar")
    no(N.Wire.send("LEGW1","P|1|0|zz","GUILD",nil,{prio="presence"}),"and refuses a malformed P line")
end)

test("Friend share: an older client ignores P lines cleanly (the 1.2.3 receive path)",function()
    -- 1.2.3 Wire passes an unknown LEGW1 tag through and its relayIn hands it to Relay.decode, which refuses it.
    -- Relay.decode is unchanged in 1.2.4, so this is the old client's exact outcome.
    local N=H.load(); local line=N.FriendShare.lines({{name="Cedar Vale-TestRealm",zone="Duskwood",faction="Horde"}},0)[1]
    local record,why=N.Relay.decode(line,"Selina Gomez",H.clock()); eq(record,nil); eq(why,"invalid")
    yes(line:find("^[%w|%.:,%-/]+$"),"only characters every LEGW1 reader accepts")
    local odd=N.FriendShare.lines({{name="Zoë Mal'Ganis-Area 52",zone="Dire Maul: North",faction="Horde"}},0)[1]
    yes(odd:find("^[%w|%.:,%-/]+$"),odd); eq(select(2,N.Relay.decode(odd,"Selina Gomez",H.clock())),"invalid")
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
    yes(N.FriendShare.pending(N.Main.friendOut),"the rest waits")
    -- our own line still has room right after the burst
    local own=N.Relay.ownLine({rid=5,zone=100,count=1,enemies={{displayName="Zack Ly",class="SHAMAN",level=49}}})
    N.Relay.spend(H.clock(),false)
    yes(N.Wire.send("LEGW1",own,"GUILD",nil,{prio="own",queue=false}),"own sighting not starved")
    -- the queue drains over time; every entry eventually goes
    for _=1,40 do H.advance(5); N.Main.friendShareTick() end
    no(N.FriendShare.pending(N.Main.friendOut))
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
    yes(N.FriendShare.pending(N.Main.friendOut),"some lines wait")
    SlashCmdList.LAYERENEMIES("share off")
    local before=#H.sent()
    for _=1,20 do H.advance(5); N.Main.friendShareTick() end
    eq(#pLines(before),0,"nothing more after share off")
    no(N.FriendShare.pending(N.Main.friendOut),"and nothing waits to go out later")
end)

-- Review round 1 (MUST): a refresh never discards what waits, and a big list is sent in full over time.
local function many(n)
    local friends={}
    for i=1,n do
        friends[i]=game({characterName=H.abc(i%26+1):upper()..H.abc(math.floor(i/26)%26+1)..H.abc(i%7+1).."ris Vale",
            playerGuid="Player-1-"..string.format("%08X",i),areaName=(i%3==0) and "Orgrimmar" or "Stranglethorn Vale"})
    end
    return friends
end
local function run(N,seconds,step,onStep)
    local t=0
    while t<seconds do
        H.advance(step); t=t+step
        N.Main.friendShareTick()
        for _=1,500 do if not N.Main.presenceJob then break end; H.advance(.001) end
        if onStep then onStep(t) end
    end
end
local function sendTimes(N,from)
    local at={}
    for i=(from or 0)+1,#H.sent() do
        local s=H.sent()[i]
        if s.prefix=="LEGW1" and s.text:sub(1,2)=="P|" then
            for _,e in ipairs(N.FriendShare.decode(s.text).entries) do
                at[e.name]=at[e.name] or {}; table.insert(at[e.name],s.at or H.clock())
            end
        end
    end
    return at
end

local function bigList(total,minutes)
    local N=ready(many(total)); local before=#H.sent()
    local stamps={}
    local function stamp() for i=#stamps+before+1,#H.sent() do stamps[#stamps+1]=H.clock() end end
    scan(N); stamp()
    run(N,minutes*60,5,stamp)
    -- send time of every line, from the stamps taken as lines appeared
    local at={}
    local lines,times={},{}
    for i=before+1,#H.sent() do
        local s=H.sent()[i]
        if s.prefix=="LEGW1" and s.text:sub(1,2)=="P|" then lines[#lines+1]=s; times[#times+1]=stamps[i-before] end
    end
    local entriesSent=0
    for k,s in ipairs(lines) do
        for _,e in ipairs(N.FriendShare.decode(s.text).entries) do
            at[e.name]=at[e.name] or {}; table.insert(at[e.name],times[k]); entriesSent=entriesSent+1
        end
    end
    local distinct=0; for _ in pairs(at) do distinct=distinct+1 end
    eq(distinct,total,"every one of "..total.." names sent at least once")
    -- capacity: entries sent per 5 minutes; a name waits at most the rounds needed to get through all 200
    local perRefresh=entriesSent/(minutes*60/300)
    local rounds=math.ceil(total/perRefresh)
    local worst=0
    for name,list in pairs(at) do
        for i=2,#list do worst=math.max(worst,list[i]-list[i-1]) end
    end
    print(string.format("OBS "..total.." friends: %d lines, %d entries, %.1f per 5 min, rounds %d, worst gap %d s, %.2f per line",#lines,entriesSent,perRefresh,rounds,worst,entriesSent/#lines))
    yes(worst<=rounds*300+30,"worst gap "..worst.." s, capacity "..perRefresh.." per 5 min, rounds "..rounds)
    yes(entriesSent/#lines>=4,"at least 4 entries per line with typical names: "..string.format("%.2f",entriesSent/#lines))
    local used,cap=N.Wire.guildMinute(H.clock()); yes(used<=cap)
end
test("Friend share: 200 friends over 20 minutes all go out, each again within the refresh rounds the budget needs",function()
    bigList(200,20)
end)

test("Friend share: 400 entries, more than one refresh can carry: each refresh carries on where the last stopped",function()
    -- The client reads at most 200 Battle.net friends; communities can add more. Sender queue alone, budget fixed at
    -- one line per 10 s (30 lines per 5 minutes), a scan every 60 s and a refresh every 300 s, for 40 minutes.
    local N=H.load(); local FS=N.FriendShare; local out=FS.newOut()
    local cur={}
    for i=1,400 do cur[string.format("k%03d",i)]={name=string.format("Name%03d Vale-TestRealm",i),zone="Stranglethorn Vale",faction="Horde"} end
    local at,lines,entries={},0,0
    for t=0,2400,10 do
        if t%60==0 then FS.plan(out,cur,t) end
        local line,keys=FS.nextLine(out,0)
        if line then
            FS.done(out,keys,t); lines=lines+1
            for _,k in ipairs(keys) do at[k]=at[k] or {}; table.insert(at[k],t); entries=entries+1 end
        end
    end
    local distinct,worst=0,0
    for _,list in pairs(at) do distinct=distinct+1; for i=2,#list do worst=math.max(worst,list[i]-list[i-1]) end end
    local perRefresh=entries/(2400/300); local rounds=math.ceil(400/perRefresh)
    print(string.format("OBS 400 entries: %d lines, %.1f entries per 5 min, rounds %d, worst gap %d s",lines,perRefresh,rounds,worst))
    eq(distinct,400,"every entry sent")
    yes(rounds>=2,"the budget really is short of one refresh")
    yes(worst<=rounds*300+60,"each entry again within "..rounds.." refresh rounds: worst "..worst.." s")
    -- the old behaviour, restarting at "A" each refresh, would never reach the tail
    yes(at["k400"] and #at["k400"]>=2,"the tail is sent again, not only once")
end)

test("Friend share: a change for the last name goes out in the next line, ahead of a big backlog, and a refresh keeps it",function()
    local friends=many(200)
    local N=ready(friends); scan(N)
    run(N,60,5)
    yes(N.FriendShare.pending(N.Main.friendOut),"a backlog waits")
    -- the alphabetically last name changes zone
    local last,lastName=nil,nil
    for _,f in ipairs(friends) do local n=f.gameAccountInfo.characterName if not lastName or n>lastName then last,lastName=f,n end end
    last.gameAccountInfo.areaName="Duskwood"
    H.deliver("BN_FRIEND_INFO_CHANGED"); H.advance(16); H.drain()
    for _=1,500 do if not N.Main.presenceJob then break end; H.advance(.001) end
    -- a refresh lands before the budget allows another line: the change must survive it
    N.Main.friendOut.fullAt=H.clock()-301; N.Main.presenceScan(true)
    for _=1,500 do if not N.Main.presenceJob then break end; H.advance(.001) end
    eq(N.Main.friendOut.urgent[1]~=nil,true,"the change still waits at the front after the refresh")
    local before=#H.sent()
    for _=1,10 do if #pLines(before)>0 then break end; H.advance(2); N.Main.friendShareTick() end
    local first=pLines(before)[1]; yes(first,"a line within one budget tick")
    local got
    for _,e in ipairs(N.FriendShare.decode(first.text).entries) do if e.name==lastName.."-TestRealm" then got=e end end
    yes(got,"the changed tail name is in that first line"); eq(got and got.zone,"Duskwood")
end)

test("Friend share: a watch answer jumps the backlog",function()
    local friends=many(200)
    local N=ready(friends); scan(N); run(N,30,5)
    yes(N.FriendShare.pending(N.Main.friendOut))
    local name=friends[199].gameAccountInfo.characterName
    H.advance(10)
    H.deliver("CHAT_MSG_ADDON","LEGW1","T|1|ac|1|1|"..N.Watch.hash(name),"GUILD","Selina Gomez"); H.drain()
    local before=#H.sent()
    for _=1,10 do if #pLines(before)>0 then break end; H.advance(2); N.Main.friendShareTick() end
    -- the answer may already have left with the T line's own tick; look at the lines since the T line
    local found=false
    for _,s in ipairs(pLines(before-3)) do
        for _,e in ipairs(N.FriendShare.decode(s.text).entries) do if e.name==name.."-TestRealm" then found=true end end
    end
    yes(found,"the watched name is answered at once")
end)

test("Friend share: a withdrawal waits through a refresh; nothing waiting is dropped by a new scan",function()
    local N=H.load(); local FS=N.FriendShare; local out=FS.newOut()
    local cur={}
    for i=1,50 do cur["k"..i]={name="N"..i,zone="Z",faction="Horde"} end
    FS.plan(out,cur,100)
    local line,keys=FS.nextLine(out,0); FS.done(out,keys,100)
    -- k1 (sent) goes offline; a refresh scan follows before anything else is sent
    local cur2={}; for k,e in pairs(cur) do if k~="k1" then cur2[k]=e end end
    FS.plan(out,cur2,110); FS.plan(out,cur2,500)
    eq(out.urgent[1],"k1","withdrawal still first")
    line=FS.nextLine(out,0); yes(line:find("N1:::::",1,true),line)
    local waiting=0; for _ in pairs(out.due) do waiting=waiting+1 end
    eq(waiting,49,"the refresh owes every online key once; none is dropped or doubled")
end)

test("Friend share: the newest guildmate evidence wins in Find, which keeps it for 15 minutes",function()
    local N=H.load({tracked={"Birch Moss"}}); H.establish(N)
    local fresh=N.FriendShare.lines({{name="Birch Moss-TestRealm",zone="Azshara",faction="Horde"}},0)[1]
    local old=N.FriendShare.lines({{name="Birch Moss-TestRealm",zone="Duskwood",faction="Horde"}},100)[1]
    H.deliver("CHAT_MSG_ADDON","LEGW1",fresh,"GUILD","Selina Gomez"); H.drain()
    H.deliver("CHAT_MSG_ADDON","LEGW1",old,"GUILD","Other Scout"); H.drain()
    eq(N.Main.findRows()[1].presence.zone,"Azshara","older evidence does not overwrite newer")
    N.Main.friendShareApply()
    eq(N.Main.findRows()[1].presence.zone,"Azshara","nor on re-apply")
    H.advance(661); N.Presence.sweep(N.Main.find,H.clock())
    yes(N.Main.findRows()[1].presence,"still in Find after 661 s")
    H.advance(240); N.Presence.sweep(N.Main.find,H.clock())
    eq(N.Main.findRows()[1].presence,nil,"gone after 15 minutes")
end)

test("Friend share: the cached row list follows every store, withdrawal and expiry",function()
    local N=H.load(); local FS=N.FriendShare; local inn=FS.newIn()
    FS.put(inn,"S","s","a",{name="A",zone="Z"},100)
    local r1=FS.rows(inn,110); eq(#r1,1); yes(FS.rows(inn,120)==r1,"same list while nothing changes")
    FS.put(inn,"S","s","b",{name="B",zone="Z"},115)
    local r2=FS.rows(inn,120); eq(#r2,2); eq(r2[1].name,"B","newest first")
    FS.put(inn,"S","s","a",{name="A"},121); eq(#FS.rows(inn,122),1,"withdrawal")
    eq(#FS.rows(inn,115+FS.TTL-1),1); eq(#FS.rows(inn,115+FS.TTL),0,"expired at TTL")
    FS.put(inn,"S","s","c",{name="C",zone="Z"},2000); eq(#FS.rows(inn,2001),1)
    eq(#FS.rows(inn,1990),0,"a clock that steps back drops what is now in the future")
end)

test("Friend share: a watch answer goes in front of changes already waiting; only a player GUID is sent",function()
    local N=H.load(); local FS=N.FriendShare; local out=FS.newOut()
    local cur={}
    for i=1,30 do cur[string.format("k%02d",i)]={name=string.format("N%02d",i),zone="Z",faction="Horde"} end
    FS.plan(out,cur,100)
    while FS.pending(out) do local _,keys=FS.nextLine(out,0); FS.done(out,keys,100) end
    local cur2={}; for k,e in pairs(cur) do cur2[k]={name=e.name,zone="Duskwood",faction="Horde"} end
    FS.plan(out,cur2,120)
    eq(#out.urgent,30,"thirty changes wait")
    eq(FS.answer(out,{k30=true},121),1)
    local line=FS.nextLine(out,0)
    yes(line:find("^P|1|0|N30:"),"the answer leads the next line: "..line)
    eq(FS.entry({name="A",zone="B",guid="Creature-0-1-2-3-AA"}),"A:B::::","a non-player GUID is not sent")
    eq(FS.entry({name="A",zone="B",guid="Player-1-0A"}),"A:B::::1-0A")
end)

-- Review of PR #45 (MUST): an escaped "." must come back as a "."; the escape is exact for every byte.
test("Friend share: periods survive the wire in names and zones; escape then unescape is exact for every byte",function()
    local N=H.load(); local FS=N.FriendShare
    local line=FS.lines({{name="J.R Cc-TestRealm",zone="Dr. Weavil's Island",faction="Horde"},
        {name="A.B. C-Area 52",zone="St. Mary . Grove.",faction="Alliance"}},0)[1]
    local msg=FS.decode(line); yes(msg,line)
    eq(msg.entries[1].name,"J.R Cc-TestRealm"); eq(msg.entries[1].zone,"Dr. Weavil's Island")
    eq(msg.entries[2].name,"A.B. C-Area 52"); eq(msg.entries[2].zone,"St. Mary . Grove.")
    for b=1,255 do
        local c=string.char(b)
        for _,text in ipairs({c,"a"..c.."b",c..c,". "..c.." ."}) do eq(FS.unesc(FS.esc(text)),text,"byte "..b) end
    end
    math.randomseed(7)
    for _=1,2000 do
        local t={} for i=1,math.random(1,40) do t[i]=string.char(math.random(1,255)) end
        local text=table.concat(t); eq(FS.unesc(FS.esc(text)),text)
    end
    -- valid UTF-8 text survives the whole line round trip
    for _,text in ipairs({"Zoë.Mal'Ganis","Ünter.Wald-Kel'Thuzad","日本.語","x/2E.y"}) do
        local back=FS.decode(FS.lines({{name=text,zone=text,faction="Horde"}},0)[1]).entries[1]
        eq(back.name,text); eq(back.zone,text)
    end
end)

test("Friend share: 39 watched friends and a watch line every 30 s do not starve the refresh (all 200 go out)",function()
    -- the reviewer's case: ticks every second, an own sighting every 20 s, the first 39 names watched
    local friends={}
    for i=1,200 do friends[i]=game({characterName="Fr"..H.abc(i%26+1)..H.abc(math.floor(i/26)+1).." Vale",playerGuid="Player-1-"..string.format("%08X",i)}) end
    local N=ready(friends); local before=#H.sent()
    N.Main.presenceScan(true); for _=1,2000 do if not N.Main.presenceJob then break end; H.advance(.001) end
    local hs={} for i=1,39 do hs[i]=N.Watch.hash(friends[i].gameAccountInfo.characterName) end
    local wire="T|1|ac|1|1|"..table.concat(hs)
    local ownOk=0
    for step=1,1200 do
        H.advance(1); N.Main.friendShareTick()
        for _=1,50 do if not N.Main.presenceJob then break end; H.advance(.001) end
        if step%20==0 then
            local own=N.Relay.ownLine({rid=step,zone=100,count=1,enemies={{displayName="Zack Ly",class="SHAMAN",level=49}}})
            if N.Relay.spend(H.clock(),false) and N.Wire.send("LEGW1",own,"GUILD",nil,{prio="own",queue=false}) then ownOk=ownOk+1 end
        end
        if step%30==0 then N.Main.relayIn(wire,"GUILD","Selina Gomez") end
    end
    local seen,n={},0
    for _,e in ipairs(entries(N,pLines(before))) do if not seen[e.name] then seen[e.name]=true; n=n+1 end end
    eq(n,200,"every friend sent despite the watch traffic")
    eq(ownOk,60,"our own sightings still all go")
end)

test("Friend share: a watch answer comes once per newly watched name, takes at most every other place, and old keys are forgotten",function()
    local N=H.load(); local FS=N.FriendShare; local out=FS.newOut()
    local cur={}
    for i=1,40 do cur[string.format("k%02d",i)]={name=string.format("N%02d",i),zone="Z",faction="Horde"} end
    FS.plan(out,cur,100)
    local keys={}; for i=1,20 do keys[string.format("k%02d",i)]=true end
    eq(FS.answer(out,keys,100),20); eq(FS.answer(out,keys,200),0,"the same names again: no answer, even after the gap")
    local line,sentKeys=FS.nextLine(out,0)
    local answered=0; for _,k in ipairs(sentKeys) do if out.answers[k] then answered=answered+1 end end
    local a,r=0,0; for _,k in ipairs(sentKeys) do if keys[k] then a=a+1 else r=r+1 end end
    yes(a<=r+1 and r>0,"answers "..a..", others "..r)
    keys.k21=true; eq(FS.answer(out,keys,201),1,"a newly named one is answered")
    -- bookkeeping for a key that left and is no longer waiting is dropped at the next refresh
    FS.done(out,sentKeys,201); while FS.pending(out) do local _,k2=FS.nextLine(out,0); FS.done(out,k2,202) end
    eq(next(out.answers),nil,"once sent, an answered key is an ordinary key again")
    local cur2={}; for k,e in pairs(cur) do if k~="k01" then cur2[k]=e end end
    FS.plan(out,cur2,210); while FS.pending(out) do local _,k2=FS.nextLine(out,0); FS.done(out,k2,211) end
    FS.plan(out,cur2,600)
    eq(out.lastAt.k01,nil); eq(out.names.k01,nil); eq(out.answered.k01,nil); eq(out.watched.k01,nil)
    yes(out.lastAt.k02,"online keys keep theirs")
end)
