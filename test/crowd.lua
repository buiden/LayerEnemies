-- Guild-intel crowd regressions. Loaded by harness.lua; real Store/Main/Relay/Wire,
-- with only the harness's client APIs and clock mocked.
local H = ...
local test, eq, yes, no = H.test, H.eq, H.yes, H.no
local function ready()
    local N = H.load()
    H.establish(N)
    H.time(100)
    return N
end
local function see(N, i, at, name)
    local e = {key="Player-1-crowd"..string.format("%03d", i), name=name or ("Crowd "..H.abc(i)),
        class="MAGE", level=60, realm="Test Realm", faction="opposite", source="own target", at=at or H.time()}
    yes(N.Store.observe(N.Main.store, e, H.time()), "fixture admitted")
    return e
end
local function crowd(N, n, at)
    local entries = {}
    for i=1,n do entries[i]=see(N,i,at) end
    return entries
end
local function tick(N, at)
    H.time(at)
    N.Main.shareTick()
    no(N.Main.error)
end
local function decoded(N)
    local out = {}
    for _,m in ipairs(H.sent()) do
        if m.prefix=="LEGW1" and m.text:sub(1,2)=="O|" then
            eq(m.kind,"GUILD"); eq(m.target,nil); yes(#m.text<=255)
            local r=N.Relay.decodeOwn(m.text,"Birch Scout",m.at)
            yes(r,"unchanged receiver accepts O|1"); r.sentAt=m.at
            out[#out+1]=r
        end
    end
    return out
end
local function unique(rows)
    local names, count = {}, 0
    for i,r in ipairs(rows) do
        if i>1 then yes(r.sentAt-rows[i-1].sentAt>=15,"O lines at least 15 s apart") end
        for _,e in ipairs(r.enemies) do
            local old=names[e.name]
            yes(not old or r.sentAt-old>=60,"name not repeated inside 60 s: "..e.name)
            if not old then count=count+1 end
            names[e.name]=r.sentAt
        end
    end
    return count,names
end

test("crowd 5: nine enemies use consecutive 4,4,1 slots without repeats",function()
    local N=ready(); crowd(N,9)
    tick(N,100); eq(#decoded(N),0,"three-second settle")
    tick(N,103); local rows=decoded(N); eq(#rows,1); eq(#rows[1].enemies,4)
    eq(N.Safe.count(N.Main.share.shared),4,"only fitted names marked shared")
    tick(N,118); rows=decoded(N); eq(#rows,2); eq(#rows[2].enemies,4)
    tick(N,133); rows=decoded(N); eq(#rows,3); eq(#rows[3].enemies,1)
    eq(unique(rows),9)
    eq(rows[1].sentAt,103); eq(rows[2].sentAt,118); eq(rows[3].sentAt,133)
    eq(rows[1].age,3); eq(rows[2].age,18); eq(rows[3].age,33)
end)

test("crowd 6: a sighting waiting 30 seconds keeps its real age",function()
    local N=ready(); see(N,1,97); tick(N,100); eq(#decoded(N),1)
    see(N,2,100); tick(N,114); eq(#decoded(N),1,"slot closed")
    tick(N,130); local rows=decoded(N); eq(#rows,2)
    eq(#rows[2].enemies,1); eq(rows[2].enemies[1].name,"Crowd b")
    eq(rows[2].age,30); eq(rows[2].at,100)
end)

test("crowd rate: duplicate and fractional pumps never open an early slot",function()
    local N=ready(); crowd(N,9); tick(N,103)
    for _,at in ipairs({103,103.01,104,110,117.999}) do tick(N,at); eq(#decoded(N),1) end
    tick(N,118); eq(#decoded(N),2)
    for _,at in ipairs({118,118.01,125,132.999}) do tick(N,at); eq(#decoded(N),2) end
    tick(N,133); eq(#decoded(N),3); eq(unique(decoded(N)),9)
end)

test("crowd cap: no fourth line for a 13-plus snapshot even at age 45",function()
    for _,n in ipairs({13,25}) do
        local N=ready(); crowd(N,n); tick(N,100)
        -- Re-sighting during settle puts a hypothetical fourth slot exactly at
        -- age 45. Freshness alone therefore cannot enforce the three-line cap.
        H.time(103); crowd(N,n); tick(N,103); tick(N,118); tick(N,133)
        local rows=decoded(N); eq(#rows,3); eq(unique(rows),12)
        tick(N,148); eq(#decoded(N),3,"no fourth line from this snapshot")
        eq(N.Safe.count(N.Main.share.shared),12,"overflow is not marked shared")
        -- Overflow was dropped, not a hidden fourth line. New own evidence may
        -- begin a new burst, at the normal slot and with its own settle.
        H.time(149); see(N,13); tick(N,149); eq(#decoded(N),3)
        tick(N,152); rows=decoded(N); eq(#rows,4)
        eq(#rows[4].enemies,1); eq(rows[4].enemies[1].name,"Crowd m")
    end
end)

test("crowd packing: byte-trimmed names wait for the next slot",function()
    local N=ready()
    for i=1,3 do see(N,i,100,string.rep(string.char(64+i),36).." "..string.rep("b",36)) end
    tick(N,103); local rows=decoded(N); eq(#rows,1); eq(#rows[1].enemies,1)
    eq(N.Safe.count(N.Main.share.shared),1,"byte-trimmed entries are unsent")
    tick(N,118); rows=decoded(N); eq(#rows,2); eq(#rows[2].enemies,1)
    tick(N,133); rows=decoded(N); eq(#rows,3); eq(#rows[3].enemies,1)
    eq(unique(rows),3)
end)

test("crowd encoder: fitted receipt matches unchanged O bytes",function()
    local N=ready(); local entries=crowd(N,5)
    local line,fitted=N.Relay.ownLine({rid=7,zone=100,x=.25,y=.75,layer="7086",age=30,count=5,enemies=entries})
    eq(line,"O|1|7|100|0.250|0.750|7086|30|5|43726f77642061:MAGE:60,43726f77642062:MAGE:60,43726f77642063:MAGE:60,43726f77642064:MAGE:60")
    yes(fitted,"encoder returns the entries actually fitted"); eq(#fitted,4)
    for i=1,4 do eq(fitted[i],entries[i]) end
    entries[1].displayName="bad|name"
    line,fitted=N.Relay.ownLine({rid=7,zone=100,age=30,count=5,enemies=entries})
    local r=N.Relay.decodeOwn(line,"Birch Scout",130); eq(#r.enemies,4); eq(#fitted,4)
    eq(fitted[1],entries[2]); eq(fitted[4],entries[5])
end)

test("crowd repeat: a new arrival never pulls a recently sent name along",function()
    local N=ready(); see(N,1); tick(N,103)
    H.time(110); see(N,1); see(N,2); tick(N,118)
    local rows=decoded(N); eq(#rows,2); eq(#rows[2].enemies,1); eq(unique(rows),2)
    H.time(130); see(N,1); tick(N,133); eq(#decoded(N),2)
    H.time(160); see(N,1); tick(N,162.999); eq(#decoded(N),2)
    tick(N,163); rows=decoded(N); eq(#rows,3); eq(rows[3].enemies[1].name,"Crowd a")
    eq(unique(rows),2,"exact 60-second repeat is allowed")
end)

test("crowd repeat identity: duplicate observed names do not bypass 60 seconds",function()
    local N=ready(); see(N,1,100,"Cedar Vale"); see(N,2,100,"Cedar Vale"); tick(N,103)
    local rows=decoded(N); eq(#rows,1); eq(#rows[1].enemies,1)
    H.time(110); see(N,3,110,"Cedar Vale"); see(N,4); tick(N,118)
    rows=decoded(N); eq(#rows,2); eq(#rows[2].enemies,1); eq(unique(rows),2)
end)

test("crowd freshness: age 45 is allowed but a waiting name past 45 is dropped",function()
    local N=ready(); crowd(N,9); tick(N,130)
    local rows=decoded(N); eq(#rows,1); eq(#rows[1].enemies,4); eq(rows[1].age,30)
    tick(N,145); rows=decoded(N); eq(#rows,2); eq(#rows[2].enemies,4); eq(rows[2].age,45)
    tick(N,160); eq(#decoded(N),2,"remaining enemy is now stale")
    eq(N.Safe.count(N.Main.share.shared),8,"stale enemy was never marked shared")
end)

test("crowd age: omitted newer names cannot rejuvenate the fitted sightings",function()
    local N=ready(); see(N,1,80); see(N,2,90)
    local invalid=see(N,3,100); invalid.displayName="bad|name"
    tick(N,103); local rows=decoded(N); eq(#rows,1); eq(#rows[1].enemies,2)
    eq(rows[1].age,23,"one age field conservatively dates the oldest fitted sighting")
    eq(N.Safe.count(N.Main.share.shared),2,"invalid identity is not marked shared")
end)

test("crowd switch: share off cancels the remaining snapshot without resetting pace",function()
    local N=ready(); crowd(N,9); tick(N,103); eq(#decoded(N),1)
    H.time(104); N.Main.setShare(false)
    tick(N,118); tick(N,133); eq(#decoded(N),1)
    N.Main.setShare(true); tick(N,133); eq(#decoded(N),1,"old snapshot stays cancelled")
    H.time(134); see(N,9); tick(N,137); eq(#decoded(N),2,"new observation can start again")
end)

test("crowd boundaries: zone and world resets discard the pending old sightings",function()
    for _,event in ipairs({"ZONE_CHANGED_NEW_AREA","PLAYER_ENTERING_WORLD","SHARD_TRANSFER"}) do
        local N=ready(); crowd(N,9); tick(N,103); eq(#decoded(N),1)
        H.time(104); if event=="ZONE_CHANGED_NEW_AREA" then H.map(200) end
        H.deliver(event); H.drain(); tick(N,118); tick(N,133); eq(#decoded(N),1,event)
        H.time(134); see(N,20); tick(N,137); local rows=decoded(N); eq(#rows,2)
        eq(rows[2].zone,event=="ZONE_CHANGED_NEW_AREA" and 200 or 100)
        eq(#rows[2].enemies,1); eq(rows[2].enemies[1].name,"Crowd t")
    end
end)

test("crowd guild: a leave or readable switch cancels old-guild remaining lines",function()
    for _,event in ipairs({"PLAYER_GUILD_UPDATE","GUILD_ROSTER_UPDATE","leave"}) do
        local N=ready(); H.deliver("GUILD_ROSTER_UPDATE",true)
        crowd(N,9); tick(N,103); eq(#decoded(N),1)
        H.time(104)
        if event=="leave" then H.guild(false); H.deliver("PLAYER_GUILD_UPDATE","player")
        else H.guild(true,"Next Guild"); H.deliver(event,"player") end
        H.drain(); tick(N,118); eq(#decoded(N),1,event)
        if event=="leave" then H.guild(true,"Test Guild"); H.deliver("PLAYER_GUILD_UPDATE","player") end
        H.deliver("GUILD_ROSTER_UPDATE",true); tick(N,133); eq(#decoded(N),1,"cancelled, not transferred to the new guild")
        H.time(134); see(N,9); tick(N,137); eq(#decoded(N),2,"new own evidence may be shared")
    end
end)

test("crowd refusal: no shared stamp on a refused send and retry still waits 15 seconds",function()
    local N=ready(); crowd(N,9); H.result(1); tick(N,103)
    eq(#decoded(N),1,"one client attempt"); eq(N.Safe.count(N.Main.share.shared),0,"not accepted")
    H.result(0); tick(N,117.999); eq(#decoded(N),1)
    tick(N,118); local rows=decoded(N); eq(#rows,2); eq(#rows[2].enemies,4)
    eq(N.Safe.count(N.Main.share.shared),4); eq(rows[2].age,18)
    for i=1,4 do eq(rows[2].enemies[i].name,rows[1].enemies[i].name) end
end)

test("crowd cancel pace: a quick off-on cycle preserves both cooldowns",function()
    local N=ready(); crowd(N,9); tick(N,103); eq(#decoded(N),1)
    H.time(104); N.Main.setShare(false)
    H.time(105); N.Main.setShare(true); see(N,1); see(N,9)
    tick(N,108); tick(N,117.999); eq(#decoded(N),1,"off-on cannot reset the slot")
    tick(N,118); local rows=decoded(N); eq(#rows,2); eq(#rows[2].enemies,1)
    eq(rows[2].enemies[1].name,"Crowd i"); eq(unique(rows),5)
end)

test("crowd guild blink: same or unreadable guild events retain the existing burst",function()
    local N=ready(); H.deliver("GUILD_ROSTER_UPDATE",true); crowd(N,9); tick(N,103)
    H.time(104); H.deliver("PLAYER_GUILD_UPDATE","player")
    local read=GetGuildInfo; GetGuildInfo=function() return nil end
    H.deliver("PLAYER_GUILD_UPDATE","player"); H.deliver("GUILD_ROSTER_UPDATE",true)
    GetGuildInfo=read; H.deliver("GUILD_ROSTER_UPDATE",true)
    tick(N,118); tick(N,133); local rows=decoded(N); eq(#rows,3); eq(unique(rows),9)
end)

test("crowd boundary cooldown: new-zone observations cannot repeat a name inside 60 seconds",function()
    local N=ready(); see(N,1,100,"Cedar Vale"); tick(N,103)
    H.time(104); H.map(200); H.deliver("ZONE_CHANGED_NEW_AREA"); H.drain()
    H.time(105); see(N,2,105,"Cedar Vale"); see(N,3)
    tick(N,108); eq(#decoded(N),1)
    tick(N,118); local rows=decoded(N); eq(#rows,2); eq(#rows[2].enemies,1)
    eq(rows[2].enemies[1].name,"Crowd c"); eq(rows[2].zone,200); eq(unique(rows),2)
end)

test("crowd cancel memory: repeated boundaries keep skipped keys bounded to the current store",function()
    local N=ready(); local st=N.Share.new()
    for turn=1,4 do
        local seen={}
        for i=1,256 do seen["snapshot"..turn..":"..i]={} end
        N.Share.cancel(st,seen,100+turn)
        eq(N.Safe.count(st.skipped),256,"cancel cannot accumulate former stores while sharing is off")
    end
end)

-- Deliver the actual outgoing bytes to a second client, including the Store's
-- anonymous "N more not listed" rows. Decoding names alone misses inflation.
local function receivedTotal(lines, at)
    local R=ready()
    for _,m in ipairs(lines) do
        if m.prefix=="LEGW1" and m.text:sub(1,2)=="O|" then
            H.time(m.at); H.deliver("CHAT_MSG_ADDON","LEGW1",m.text,"GUILD","Birch Scout")
        end
    end
    H.time(at)
    local total,named=0,0
    for _,r in ipairs(R.Store.rows(R.Main.store,at,"reported")) do
        local rest=tonumber(r.name:match("^(%d+) more not listed"))
        total=total+(rest or 1)
        if not rest then named=named+1 end
    end
    return total,named
end

for _,n in ipairs({5,9,13,30}) do
    test("crowd receiver: "..n.." enemies keep their exact displayed total",function()
        local N=ready(); crowd(N,n); tick(N,103); tick(N,118); tick(N,133)
        local rows=decoded(N); eq(unique(rows),math.min(n,12))
        local total,named=receivedTotal(H.sent(),134)
        eq(total,n,"named plus anonymous counts at the receiving client")
        eq(named,math.min(n,12))
    end)
end

test("crowd receiver: byte-trimmed lines count only their own names",function()
    local N=ready()
    for i=1,5 do see(N,i,100,string.rep(string.char(64+i),36).." "..string.rep("b",36)) end
    tick(N,103); tick(N,118); tick(N,133)
    local rows=decoded(N); eq(#rows,3); eq(unique(rows),3)
    local total,named=receivedTotal(H.sent(),134)
    eq(total,5); eq(named,3)
end)

local function noWarRepeats(N)
    local last={}
    for _,m in ipairs(H.weSent("E")) do
        for _,e in ipairs(N.Protocol.decode(m.text).enemies) do
            yes(not last[e.hash] or m.at-last[e.hash]>=60,"public enemy not repeated inside 60 seconds")
            last[e.hash]=m.at
        end
    end
end

for _,n in ipairs({6,13}) do
    test("crowd War Effort fight: "..n.." enemies produce five pairs in five minutes",function()
        local N=ready(); H.netOn(N,"we"); H.hello("Wes",19)
        for at=100,400 do H.time(at); crowd(N,n); tick(N,at) end
        eq(#H.weSent("C"),5,"same pair budget as main")
        eq(#H.weSent("E"),5)
        for _,m in ipairs(H.weSent("C")) do eq(N.Protocol.decode(m.text).count,n) end
        for _,m in ipairs(H.weSent("E")) do eq(#N.Protocol.decode(m.text).enemies,n) end
        noWarRepeats(N); unique(decoded(N)); eq(N.Wire.queued(),0)
    end)
end

for _,mode in ipairs({"unguilded","guild line refused","share off/on"}) do
    test("crowd War Effort cooldown: "..mode.." keeps enemy dedupe",function()
        local N=ready(); H.netOn(N,"we"); IsInGroup=function() return true end
        if mode~="guild line refused" then H.guild(false) end
        H.hello("Wes",19,"PARTY")
        if mode=="guild line refused" then
            H.result(function() local messages=H.sent(); return messages[#messages].prefix=="LEGW1" and 1 or 0 end)
        end
        crowd(N,4); tick(N,103); eq(#H.weSent("C"),1); eq(#H.weSent("E"),1)
        eq(N.Safe.count(N.Main.share.shared),0,"public send cannot mark unsent guild names")
        if mode=="share off/on" then
            H.time(104); N.Main.setShare(false); H.time(105); N.Main.setShare(true); crowd(N,4)
            tick(N,118)
        else
            tick(N,118); tick(N,133); H.time(134); crowd(N,4); tick(N,148)
        end
        eq(#H.weSent("C"),1,"same enemies stay suppressed across O transitions")
        eq(#H.weSent("E"),1); noWarRepeats(N)
        H.time(160); crowd(N,4); tick(N,162.999); eq(#H.weSent("C"),1)
        tick(N,163); eq(#H.weSent("C"),2,"exact 60-second repeat is allowed")
        eq(#H.weSent("E"),2); noWarRepeats(N); eq(N.Wire.queued(),0)
    end)
end

test("crowd War Effort new arrivals: cooldown is per enemy, not global",function()
    local N=ready(); H.netOn(N,"we"); H.hello("Wes",19); crowd(N,4); tick(N,103)
    H.time(110); crowd(N,6); tick(N,118)
    local clusters,enemies=H.weSent("C"),H.weSent("E")
    eq(#clusters,2); eq(#enemies,2)
    eq(N.Protocol.decode(clusters[2].text).count,2)
    eq(#N.Protocol.decode(enemies[2].text).enemies,2); noWarRepeats(N)
end)

test("crowd War Effort: O follow-up slots do not multiply the public report",function()
    local N=ready(); H.netOn(N,"we"); H.hello("Wes",19); crowd(N,9)
    tick(N,103); eq(#H.weSent("C"),1); local first=H.weSent("E")
    eq(#first,1); eq(#N.Protocol.decode(first[1].text).enemies,9)
    tick(N,118); tick(N,133); eq(#decoded(N),3)
    eq(#H.weSent("C"),1); eq(#H.weSent("E"),1,"O chunks do not become extra C+E reports")
end)
