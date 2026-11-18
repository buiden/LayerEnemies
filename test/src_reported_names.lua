-- 1.2.3 names in Reported: certain names from LayerEnemies guild sightings, "probably <Name>" for hash-only
-- reports, merge into "Seen by you" only on a certain identity, no Hop to our own layer, nothing saved.
-- Zaht Lzy, Zobq Lvx and Mibm Lsr share Zack Ly's War Effort code (hash3 of "name-testrealm" = xd7).
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local guids=0
local function hex(s) return (s:gsub(".",function(c) return string.format("%02x",c:byte()) end)) end
local function spot(name,class,level)
    guids=guids+1; H.advance(1)
    local u=H.player(name,"Horde","Player-1-"..string.format("%06d",guids)); u.class=class or "SHAMAN"; u.level=level or 49
    H.units().target=u; H.deliver("PLAYER_TARGET_CHANGED"); H.drain()
end
local function we(id,hash,code,level,layer,sender)
    local stamp=math.floor(GetServerTime())%3600
    -- the War Effort hello first: its layer key is comparable only from a heard sender
    H.deliver("CHAT_MSG_ADDON","WEFF1","H|1.6.6|100|"..(layer or "7090").."|1|19|0|123|"..stamp,"GUILD",sender or "Selina Gomez")
    H.deliver("CHAT_MSG_ADDON","WEFF1","C|"..id.."|100|0.4|0.5|"..(layer or "7090").."|1|"..stamp,"GUILD",sender or "Selina Gomez")
    H.deliver("CHAT_MSG_ADDON","WEFF1","E|"..id.."|1|1|"..hash..":"..(code or "G")..":"..(level or 49).."|"..stamp,"GUILD",sender or "Selina Gomez")
    H.drain()
end
local function own(rid,name,sender)
    H.deliver("CHAT_MSG_ADDON","LEGW1","O|1|"..rid.."|100|0.400|0.500|7086|0|1|"..hex(name)..":SHAMAN:49","GUILD",sender or "Selina Gomez")
    H.drain()
end
local function setup() local N=H.load(); H.establish(N); return N end
local function reported(N) local _,rows=N.Main.namedRows(); return rows end
local function seenRows(N) return (N.Main.namedRows()) end
local function names(N) local out={}; for _,r in ipairs(reported(N)) do out[#out+1]=r.title or "Unknown" end; return out end
local function hashOf(N,name) return N.Hash.player(name,"Test Realm") end

test("Reported names: hash3 fixture names really collide",function()
    local N=H.load(); local h=hashOf(N,"Zack Ly")
    eq(h,"xd7"); eq(hashOf(N,"Zaht Lzy"),h); eq(hashOf(N,"Zobq Lvx"),h); eq(hashOf(N,"Mibm Lsr"),h)
end)

test("Reported names: no send change; the O line already carries the name and the 1.2.2 decoder reads it",function()
    local N=H.load()
    local line=N.Relay.ownLine({rid=5,zone=100,count=1,enemies={{displayName="Zack Ly",class="SHAMAN",level=49}}})
    yes(line:find("|"..hex("Zack Ly")..":SHAMAN:49$"),line)
    local r=N.Relay.decodeOwn(line,"Selina Gomez",100); yes(r); eq(r.enemies[1].name,"Zack Ly")
end)

test("Reported names: a guild LayerEnemies sighting shows its real name, certain",function()
    local N=setup(); own(1,"Other Enemy")
    local rows=reported(N); eq(#rows,1); eq(rows[1].title,"Other Enemy"); yes(rows[1].certain); eq(rows[1].probably,nil)
    N.UI.toggle(); N.UI.select("reported"); eq(N.UI.pool[1].title:GetText(),"Other Enemy")
end)

test("Reported names: a certain report of someone we see merges into the Seen by you row",function()
    local N=setup(); spot("Zack Ly"); own(2,"Zack Ly")
    eq(#reported(N),0,"not listed twice")
    local seen=seenRows(N); eq(#seen,1); eq(seen[1].alsoReported[1],"Selina Gomez")
    N.UI.toggle(); N.UI.select("local")
    yes(N.UI.pool[1].sub:GetText():find("also reported by Selina Gomez",1,true))
    eq(N.Store.rows(N.Main.store,H.clock(),"local")[1].alsoReported,nil,"the stored row is not modified")
    SlashCmdList.LAYERENEMIES("list")
    yes(table.concat(H.log(),"\n"):find("also reported by Selina Gomez",1,true))
end)

test("Reported names: a War Effort hash of someone we see reads probably, never merges",function()
    local N=setup(); spot("Zack Ly"); we(1,"xd7")
    local rows=reported(N); eq(#rows,1); eq(rows[1].title,"probably Zack Ly"); no(rows[1].certain)
    eq(rows[1].probablyNote,"probably the Zack Ly you see"); eq(seenRows(N)[1].alsoReported,nil)
    N.UI.toggle(); N.UI.select("reported")
    eq(N.UI.pool[1].title:GetText(),"probably Zack Ly")
    yes(N.UI.pool[1].sub:GetText():find("probably the Zack Ly you see",1,true))
end)

test("Reported names: colliding known names are all shown, two then +N, never merged",function()
    local N=setup(); spot("Zack Ly"); yes(N.Main.track("Zaht Lzy")); we(1,"xd7")
    local rows=reported(N); eq(#rows,1); eq(rows[1].title,"probably Zack Ly or Zaht Lzy")
    eq(rows[1].probablyNote,nil,"no 'you see' line when it may be someone else"); eq(seenRows(N)[1].alsoReported,nil)
    yes(N.Main.track("Zobq Lvx")); yes(N.Main.track("Mibm Lsr"))
    eq(reported(N)[1].title,"probably Zack Ly or Mibm Lsr +2","the one we see first, then by name")
end)

test("Reported names: class rules a name out, level breaks a tie",function()
    local N=setup(); spot("Zack Ly","SHAMAN",49); spot("Zaht Lzy","MAGE",49); we(1,"xd7","G",49)
    eq(reported(N)[1].title,"probably Zack Ly","the mage cannot be a reported shaman")
    N=setup(); spot("Zack Ly","SHAMAN",49); spot("Zaht Lzy","SHAMAN",60); we(1,"xd7","G",49)
    eq(reported(N)[1].title,"probably Zack Ly","level 49 breaks the tie")
    N=setup(); spot("Zack Ly","SHAMAN",50); spot("Zaht Lzy","SHAMAN",60); we(1,"xd7","G",49)
    eq(reported(N)[1].title,"probably Zack Ly or Zaht Lzy","no level match: both stay")
    N=setup(); spot("Zack Ly","SHAMAN",49); yes(N.Main.track("Zaht Lzy")); we(1,"xd7","G",49)
    eq(reported(N)[1].title,"probably Zack Ly or Zaht Lzy","an unknown level never loses a tie")
end)

test("Reported names: a named report is a known name for later hashes",function()
    local N=setup(); own(1,"Zack Ly"); we(2,"xd7","G",49,"7090","Other Scout")
    local got={}; for _,t in ipairs(names(N)) do got[t]=true end
    yes(got["Zack Ly"]); yes(got["probably Zack Ly"])
end)

test("Reported names: no match stays Unknown <class>",function()
    local N=setup(); we(1,"xd7")
    local rows=reported(N); eq(#rows,1); eq(rows[1].title,nil)
    N.UI.toggle(); N.UI.select("reported"); yes(N.UI.pool[1].title:GetText():find("^Unknown "))
end)

test("Reported names: no Hop for a report on our own layer, Hop kept for another layer",function()
    local N=setup(); we(1,"xd7","G",49,"7086")
    eq(reported(N)[1].relation,"same")
    N.UI.toggle(); N.UI.select("reported"); no(N.UI.pool[1].ask:IsShown()); eq(N.UI.pool[1].hopRecord,false)
    N=setup(); we(1,"xd7","G",49,"7090")
    eq(reported(N)[1].relation,"other")
    N.UI.toggle(); N.UI.select("reported"); yes(N.UI.pool[1].ask:IsShown()); yes(N.UI.pool[1].hopRecord)
end)

test("Reported names: names stay in memory; nothing new is saved and nothing is sent",function()
    local N=setup(); local before=#H.sent()
    spot("Zack Ly"); yes(N.Main.track("Zaht Lzy")); own(1,"Zack Ly"); own(2,"Other Enemy"); we(3,"xd7")
    N.UI.toggle(); N.UI.select("reported"); N.UI.select("local"); SlashCmdList.LAYERENEMIES("reports")
    local function scan(t,depth,seen)
        if depth>8 or seen[t] then return end; seen[t]=true
        for k,v in pairs(t) do
            for _,x in ipairs({k,v}) do
                if type(x)=="string" then no(x:find("Zack",1,true) or x:find("Other Enemy",1,true) or x:find("Selina",1,true),x) end
                if type(x)=="table" then scan(x,depth+1,seen) end
            end
        end
    end
    scan(LayerEnemiesDB,0,{})
    local sends=0; for i=before+1,#H.sent() do if H.sent()[i].prefix=="LEGW1" then sends=sends+1 end end
    eq(sends,0,"displaying names sends nothing")
end)

test("Reported names: one namedRows call per window render",function()
    local N=setup(); spot("Zack Ly"); own(3,"Other Enemy"); we(4,"xd7","G",49)
    N.UI.toggle(); N.UI.select("reported")
    local real,calls=N.Main.namedRows,0
    N.Main.namedRows=function(...) calls=calls+1; return real(...) end
    N.UI.render(); eq(calls,1,"render built the name list once")
    N.UI.render(); eq(calls,2)
    N.Main.namedRows=real
end)

test("Reported names: name hashes are cached across renders with unchanged data",function()
    local N=setup(); spot("Zack Ly"); spot("Zaht Lzy","SHAMAN",49); we(5,"xd7","G",49)
    local K=N.Main.find.known
    for i=1,30 do pcall(N.Known.put,K,{name="Kn"..H.abc(i%26+1)..H.abc(math.floor(i/26)+1).." Yy",zone=100,at=H.clock(),kind="seen",source="own",class="MAGE",level=50},H.clock()) end
    local real,calls=N.Find.hashes,0
    N.Find.hashes=function(...) calls=calls+1; return real(...) end
    N.UI.toggle(); N.UI.select("reported")
    local first=calls; yes(first>0,"first render hashes the known names")
    N.UI.render(); N.UI.render()
    eq(calls,first,"later renders with the same names hash nothing new")
    N.Find.hashes=real
    eq(names(N)[1],"probably Zack Ly or Zaht Lzy","results unchanged by the cache")
end)

test("Reported names: a long reported name is clamped for display only",function()
    local N=setup()
    local long=string.rep("Ab",40).." Cd"
    own(6,long)
    local rows=reported(N); eq(#rows,1)
    yes(#rows[1].title<=50,rows[1].title); yes(rows[1].title:find("…",1,true))
    eq(rows[1].name,long,"the record keeps the name as received")
    eq(N.Main.displayName("Zack Ly"),"Zack Ly")
    local u=string.rep("é",30) -- 60 bytes of two-byte characters
    local d=N.Main.displayName(u); yes(d:sub(1,-4):match("^[\195][\169]") and not d:sub(1,-4):find("[\195]$"),"cut is on a character boundary")
end)
