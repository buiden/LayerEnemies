-- Named session memory: exercise the public receive, boundary, Find and UI paths.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function snapshot(v)
    if type(v)~="table" then return tostring(v) end
    local keys,out={},{}; for k in pairs(v) do keys[#keys+1]=k end; table.sort(keys)
    for _,k in ipairs(keys) do out[#out+1]=tostring(k).."="..snapshot(v[k]) end
    return "{"..table.concat(out,",").."}"
end
H.snapshot=snapshot
local function named(N,name,at,extra)
    local r={sender="Birch Scout",zone=100,at=at,source="spy",enemies={{name=name,class="MAGE",level=40}}}
    for k,v in pairs(extra or {}) do r[k]=v end
    N.Find.report(N.Main.find,r,"Test Realm")
end
local function ownLine(N,name,zone,age)
    return N.Relay.ownLine({rid=7,zone=zone or 100,age=age or 0,layer="7085",count=1,x=.4,y=.5,enemies={{name=name,class="ROGUE",level=47}}})
end
local function guild(N,name,zone,age)
    H.deliver("CHAT_MSG_ADDON","LEGW1",ownLine(N,name,zone,age),"GUILD","Birch Scout")
end
local function row(N) return N.Main.findRows()[1] end
local function dbCheck(N)
    local allowed={options=true,tracked=true,position=true,guildHost=true,consent=true,nets=true,share=true,call=true,callArt=true,
        netNotice=true,autoHop=true,weReportId=true,findShare=true,findNotice=true,quietWhispers=true,warboardOwed=type(LayerEnemiesDB.warboardOwed)=="table" and #LayerEnemiesDB.warboardOwed<=40}
    for k in pairs(LayerEnemiesDB) do yes(allowed[k],"configuration only: "..tostring(k)) end
    local seen={}
    local function walk(t)
        if type(t)~="table" or seen[t] then return end
        seen[t]=true; no(t==N.Main.find.known,"Known cache must not be saved")
        for k,v in pairs(t) do
            no(k=="seen" or k=="reported" or k=="spotter" or k=="known" or k=="locations","no evidence fields in saved configuration")
            if type(v)=="string" then no(v:find("Birch Scout",1,true),"no source identity saved") end
            walk(v)
        end
    end
    walk(LayerEnemiesDB)
end

test("Known 1: named evidence survives zone, layer and world boundaries",function()
    for _,event in ipairs({"ZONE_CHANGED_NEW_AREA","SHARD_TRANSFER","PLAYER_ENTERING_WORLD"}) do
        local N=H.load(); N.Main.track("Cedar Vale"); H.advance(1); guild(N,"Cedar Vale",100)
        yes(row(N).at); H.map(200); H.deliver(event); H.drain()
        local r=row(N); yes(r.at,"boundary must retain the named sighting"); eq(r.zone,100); yes(r.travel); no(r.canAsk)
        yes(N.Main.findText(r):find("travel to Ashenvale first",1,true)); no(N.Main.error)
    end
end)

test("Known 2: at 600 and 601 seconds last known hides actions; at 3600 it expires",function()
    local N=H.load(); N.Main.track("Cedar Vale"); named(N,"Cedar Vale",H.clock())
    yes(row(N).canAsk); N.UI.toggle(); N.UI.select("find"); yes(N.UI.pool[1].ask:IsShown())
    H.advance(599); yes(row(N).canAsk)
    H.advance(1); no(row(N).canAsk); yes(N.Main.findText(row(N)):find("last known",1,true))
    H.advance(1); local r=row(N); yes(r.at); eq(r.age,601); no(r.canAsk)
    N.UI.render(); no(N.UI.pool[1].ask:IsShown()); eq(N.UI.pool[1].hopRecord,false)
    yes(N.UI.pool[1].sub:GetText():find("last known",1,true)); no(N.AskInvite("Birch Scout"))
    H.advance(2998); yes(row(N).at); H.advance(1); eq(row(N).at,nil)
end)

test("Known 3: first-hand and reported slots both show without a relay replacing first-hand",function()
    local N=H.load(); N.Main.track("Cedar Vale"); named(N,"Cedar Vale",H.clock())
    H.advance(1); named(N,"Cedar Vale",H.clock(),{source="relayed",relayed=true,sender="Distant Scout",zone=200})
    local r=row(N); yes(r.seen); yes(r.reported); eq(r.seen.spotter,"Birch Scout"); eq(r.reported.spotter,"Distant Scout")
    eq(r.spotter,"Birch Scout"); yes(r.canAsk); no(r.reported.canAsk); eq(r.reported.kind,"claim")
    local text=N.Main.findText(r); yes(text:find("Seen by Birch Scout",1,true)); yes(text:find("Reported:",1,true))
    N.UI.toggle(); N.UI.select("find"); local ui=N.UI.pool[1]
    yes(ui.sub:GetText():find("Seen by Birch Scout",1,true)); yes(ui.sub:GetText():find("Reported:",1,true))
    eq(ui.spotter,"Birch Scout"); no(N.AskInvite("Distant Scout")); no(N.Main.error)
end)

test("Known 4: add after receipt and a boundary finds old memory without an alert",function()
    local N=H.load(); H.advance(1); guild(N,"Cedar Vale",200)
    eq(#N.Main.findRows(),0,"no general list of untracked names")
    N.Main.boundary(100); H.advance(601)
    local sounds=0; PlaySound=function() sounds=sounds+1 end
    yes(N.Main.track("Cedar Vale")); local r=row(N); yes(r.at); eq(r.zone,200)
    yes(N.Main.findText(r):find("last known",1,true)); eq(sounds,0); eq(next(N.Main.find.alerts),nil)
    eq(#H.sent(),0); dbCheck(N); PlaySound=nil
end)

test("Known 4: add a fresh cached name alerts once and remove does not destroy memory",function()
    local N=H.load(); named(N,"Cedar Vale",H.clock()); local sounds=0; PlaySound=function() sounds=sounds+1 end
    N.Main.track("Cedar Vale"); yes(row(N).at); eq(sounds,1)
    N.Main.track("Cedar Vale",true); eq(#N.Main.findRows(),0)
    H.advance(11); N.Main.track("Cedar Vale"); yes(row(N).at); eq(sounds,2); PlaySound=nil
end)

test("Known A14: both guild death formats cache killer claims in another zone",function()
    for _,case in ipairs({{"GBOUNTY","D|Cedar-Vale|200|42.0|57.0|Road|47|1|ROGUE|Guild"},
        {"WALLOFSHAME","D|60|Durotar|MAGE|9|Cedar-Vale|47|x"}}) do
        local N=H.load(); H.deliver("CHAT_MSG_ADDON",case[1],case[2],"GUILD","Birch-Scout")
        eq(#N.Store.rows(N.Main.store,H.clock(),"reported"),0)
        N.Main.track("Cedar Vale"); local r=row(N); yes(r.reported); eq(r.reported.source,"death"); eq(r.reported.kind,"claim")
        eq(r.zone,200); no(r.canAsk); eq(r.seen,nil)
        yes(N.Main.findText(r):find("Reported: named as killer",1,true)); yes(N.Main.findText(r):find("claim",1,true))
        if case[1]=="GBOUNTY" then eq(r.reported.pos,"victim"); eq(r.reported.x,.42); eq(r.reported.y,.57) end
        eq(#H.sent(),0); eq(next(N.Main.relay.pending),nil); no(N.Main.error)
    end
end)

test("Known guild O: first-hand server claim uses origin age and observer coordinates",function()
    local N=H.load(); H.advance(100); guild(N,"Cedar Vale",100,90); N.Main.track("Cedar Vale")
    local r=row(N); yes(r.seen); eq(r.reported,nil); eq(r.seen.source,"guild"); eq(r.age,90)
    eq(r.seen.kind,"seen"); eq(r.seen.layer,"7085"); eq(r.seen.ns,"server"); eq(r.seen.pos,"observer")
    eq(r.seen.x,.4); eq(r.seen.y,.5); yes(r.canAsk)
    local text=N.Main.findText(r); yes(text:find("layer 7085 (their claim)",1,true)); yes(text:find("observer",1,true)); yes(text:find("40,50",1,true))
end)

test("Known Spy-family: all three named input formats populate memory before tracking",function()
    for _,case in ipairs({{"[Spy]","1.3.8|Cedar-Vale|MAGE|40|Orc|Ashenvale||0.4|0.6||100"},
        {"ForeverSpy1","1\tCedar Vale\tAshenvale"},{"FSENT03","1~Player-7103-00AB13~Cedar Vale~MAGE~40~Ashenvale~0"}}) do
        local N=H.load()
        H.deliver("CHAT_MSG_ADDON",case[1],case[2],"PARTY","Birch-Scout")
        N.Main.boundary(200); N.Main.track("Cedar Vale")
        local r=row(N); yes(r.seen,"named Spy receipt cached: "..case[1]); eq(r.seen.source,"spy"); eq(r.seen.ns,"unknown")
        eq(r.seen.layer,nil); no(N.Main.error)
    end
end)

test("Known own: untracked sighting survives boundaries but never claims today's layer",function()
    local N=H.load(); H.establish(N); H.advance(1)
    H.units().target=H.player("Cedar","Horde"); H.units().target.realm="Vale"
    H.deliver("PLAYER_TARGET_CHANGED"); H.drain(); H.units().target=nil
    N.Main.boundary(200); N.Main.track("Cedar Vale")
    local r=row(N); yes(r.seen); eq(r.source,"own"); eq(r.zone,100); yes(r.travel); no(r.same); no(r.canAsk)
    N.Main.boundary(100); N.Main.applyLayer("7086-7","test"); r=row(N); no(r.same,"same zone again is not proof of the old layer")
    no(N.Main.findText(r):find("is on YOUR layer",1,true)); yes(r.seen.layer); no(N.Main.error)
end)

test("Known A12: hashes stay possible and never populate named memory",function()
    local N=H.load(); N.Main.track("Cedar Vale")
    N.Find.report(N.Main.find,{sender="Scout",zone=100,at=H.clock(),enemies={{hash=N.Hash.player("Cedar Vale","")}}},"Test Realm")
    yes(row(N).possible); eq(N.Safe.count(N.Main.find.known.entries),0)
    H.advance(600); eq(row(N).at,nil)
end)

test("Known A17: OpenMap remains independent and never refreshes either cached slot",function()
    local N=H.load(); N.Main.track("Cedar Vale"); named(N,"Cedar Vale",H.clock())
    local before=H.snapshot(N.Main.find.known)
    H.deliver("CHAT_MSG_ADDON","OpenMapLoc","L1\t200\t0.4200\t0.5700\tMAGE\t60","GUILD","Cedar Vale")
    eq(H.snapshot(N.Main.find.known),before); local r=row(N); yes(r.place); eq(r.zone,100); eq(r.place.layer,nil)
    H.advance(150); eq(row(N).place,nil); yes(row(N).seen)
end)

test("Known 14: bounded 300-name cache evicts oldest evidence, not alphabetical first",function()
    local N=H.load(); local K=N.Known; yes(K,"pure Known module exists"); local st=K.new()
    for i=1,300 do K.put(st,{name="Enemy "..H.abc(i),zone=100,at=i,source="spy",kind="seen"},300) end
    eq(N.Safe.count(st.entries),300)
    K.put(st,{name="Enemy a",zone=200,at=301,source="death",kind="claim"},301)
    K.put(st,{name="Newest",zone=100,at=302,source="guild",kind="seen"},302)
    eq(N.Safe.count(st.entries),300); yes(K.get(st,"ENEMY A",302)); eq(K.get(st,"Enemy b",302),nil)
    local pair=K.get(st,"Enemy a",302); yes(pair.seen); yes(pair.reported)
    K.prune(st,3901); eq(next(st.entries),"newest"); K.prune(st,3902); eq(next(st.entries),nil)
end)

test("Known retention: independent slots, old arrivals, clock rollback and bounded copied fields",function()
    local N=H.load(); local K=N.Known; yes(K); local st=K.new()
    local e={name="Cedar Vale",zone=100,at=100,source="spy",kind="seen",count=99,kills=99,enemies={}}
    K.put(st,e,100); e.zone=999
    K.put(st,{name="CEDAR VALE",zone=200,at=101,source="relayed",kind="claim"},101)
    K.put(st,{name="Cedar Vale",zone=300,at=99,source="spy",kind="seen"},101)
    local pair=K.get(st,"cedar vale",101); eq(pair.seen.zone,100); eq(pair.reported.zone,200); eq(pair.seen.count,nil); eq(pair.seen.kills,nil)
    eq(pair.seen.enemies,nil); K.prune(st,3700); pair=K.get(st,"Cedar Vale",3700); eq(pair.seen,nil); yes(pair.reported)
    K.put(st,{name="Ancient",zone=100,at=0,source="spy",kind="seen"},3700); eq(K.get(st,"Ancient",3700),nil)
    K.put(st,{name="Future",zone=100,at=3800,source="spy",kind="seen"},3700); eq(K.get(st,"Future",3700),nil)
    K.prune(st,50); eq(next(st.entries),nil)
end)

test("Known 14: cache stays out of every saved table and reload starts empty",function()
    local N=H.load(); N.Main.track("Cedar Vale"); named(N,"Cedar Vale",H.clock()); dbCheck(N)
    N.Main.boundary(200); N.Main.poll(); dbCheck(N)
    N.Main.track("Birch Grove"); N.Main.track("Birch Grove",true); dbCheck(N)
    local saved=LayerEnemiesDB; N=H.load(saved); eq(N.Main.find.names[1],"Cedar Vale"); eq(row(N).at,nil)
    yes(N.Main.find.known); eq(next(N.Main.find.known.entries),nil); dbCheck(N)
end)

test("Known retention: idle untracked memory expires on the normal poll",function()
    local N=H.load(); named(N,"Cedar Vale",H.clock()); yes(N.Main.find.known)
    yes(next(N.Main.find.known.entries)); eq(#N.Main.find.names,0)
    H.advance(3600); N.Main.poll(); eq(next(N.Main.find.known.entries),nil)
end)

test("Known source scope: existing HeadHunter P and L keep the legacy Find path",function()
    local N=H.load(); local seenAt=H.clock(); N.Main.track("Cedar Vale")
    -- D now has a claim source; P/L ingestion below still uses the legacy path.
    yes(N.Known.put(N.Known.new(),{name="Cedar Vale",at=seenAt,source="headhunter",kind="claim"},seenAt))
    local r=assert(N.Record.new({src="hh",kind="fight",origin="Birch Scout",via="Birch Scout",route="PARTY",rid="1",
        zone=100,enemies={{name="Cedar Vale",class="MAGE",level=40}},layer={ns="unknown"},heard=seenAt,age=0,share="public"}))
    N.Main.findRecord(r); yes(row(N).at); yes(row(N).seen); no(row(N).seen.cached); yes(row(N).canAsk)
    eq(N.Known.get(N.Main.find.known,"Cedar Vale",seenAt),nil)
    N.Main.boundary(100); eq(row(N).at,nil)
end)

test("Known pure module runs without any WoW globals or SavedVariables",function()
    local N=H.load(); local chunk=loadfile("LayerEnemies/Known.lua"); yes(chunk)
    local env=setmetatable({string=string,table=table,math=math,type=type,pairs=pairs,ipairs=ipairs,tonumber=tonumber},
        {__index=function(_,key) error("non-pure dependency: "..key) end})
    local pure={Find={fold=N.Find.fold}}; setfenv(chunk,env); chunk("LayerEnemies",pure)
    local st=pure.Known.new(); pure.Known.put(st,{name="Cedar",zone=100,at=10,source="spy",kind="seen"},10)
    yes(pure.Known.get(st,"CEDAR",10)); pure.Known.prune(st,3610); eq(next(st.entries),nil)
end)
