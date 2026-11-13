-- Run from the project root with Lua 5.1. No external addons loaded by this test.
local passed,failed,checks=0,0,0
local function eq(a,b,msg)
    checks=checks+1
    if a~=b then error((msg or "not equal")..": expected "..tostring(b)..", got "..tostring(a),2) end
end
local function yes(v,msg) eq(not not v,true,msg) end
local function no(v,msg) eq(not not v,false,msg) end
local function test(name,fn)
    local ok,err=pcall(fn)
    if ok then passed=passed+1; print("PASS "..name) else failed=failed+1; print("FAIL "..name..": "..tostring(err)) end
end
local secret=setmetatable({}, {__tostring=function() error("secret stringify") end,__concat=function() error("secret concatenate") end,__lt=function() error("secret compare") end,__index=function() error("secret index") end})
function issecretvalue(v) return rawequal(v,secret) end
local frames,timers,log,units,loaded,metadata
local clock,map,server,channels,inGuild,clientIgnored
local methods={}
function methods:Hide() self.shown=false end
function methods:Show() self.shown=true end
function methods:IsShown() return self.shown end
function methods:RegisterEvent(event) self.events[event]=true end
function methods:SetScript(key,fn)
    if key~="OnEvent" and key~="OnUpdate" then error("unknown script") end
    self.scripts[key]=fn
end
function CreateFrame(kind)
    eq(kind,"Frame")
    local f=setmetatable({shown=true,events={},scripts={}}, {__index=function(_,key) if methods[key] then return methods[key] end; error("unknown frame method: "..key) end})
    frames[#frames+1]=f; return f
end
local function deliver(event,...)
    for _,f in ipairs(frames) do if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f,event,...) end end
end
local function drain()
    for _=1,20 do
        local todo={}
        for i=#timers,1,-1 do if timers[i].at<=clock then todo[#todo+1]=table.remove(timers,i) end end
        if #todo==0 then return end
        for i=#todo,1,-1 do todo[i].fn() end
    end
    error("timer loop")
end
local function advance(n) clock=clock+n; server=server+n; drain() end
local function loadAddon()
    frames,timers,log,units,loaded,metadata={},{},{},{},{},{}
    clock,map,server,channels,inGuild,clientIgnored=10,100,720100,{WarEffortPubA=7},true,false
    _G.BuloLayerForever=nil; _G.WarEffortScoutDB=nil; _G.LayerEnemiesDB=nil
    _G.C_Timer={After=function(delay,fn) timers[#timers+1]={at=clock+delay,fn=fn} end}
    _G.C_Map={
        GetBestMapForUnit=function() return map end,
        GetMapInfo=function(id)
            if id==100 or id==200 then return {mapType=3,parentMapID=1} end
            if id==101 then return {mapType=4,parentMapID=100} end
            if id==1 then return {mapType=2,parentMapID=0} end
        end,
        GetPlayerMapPosition=function() return {GetXY=function() return .25,.75 end} end,
    }
    _G.C_AddOns={IsAddOnLoaded=function(name) return loaded[name]==true end,GetAddOnMetadata=function(name,key) return metadata[name] end}
    _G.C_FriendList={IsIgnored=function() return clientIgnored end}
    _G.C_ChatInfo={RegisterAddonMessagePrefix=function(prefix) yes(prefix=="WEFF1" or prefix=="ZRAD1"); return true end}
    _G.GetTime=function() return clock end
    _G.GetServerTime=function() return server end
    _G.GetRealmName=function() return "Test Realm" end
    _G.IsInGuild=function() return inGuild end
    _G.GetChannelName=function(name) return channels[name] or 0 end
    _G.Ambiguate=function(name) return name:match("^([^%-]+)") end
    _G.UnitExists=function(u) return u=="player" or units[u]~=nil end
    _G.UnitGUID=function(u) return units[u] and units[u].guid end
    _G.UnitIsPlayer=function(u) return units[u] and units[u].player or false end
    _G.UnitIsUnit=function(u,v) return u==v end
    _G.UnitPlayerControlled=function(u) return units[u] and units[u].controlled or false end
    _G.UnitName=function(u) if u=="player" then return "Me","Test Realm" end; local e=units[u]; if e then return e.name,e.realm end end
    _G.UnitClass=function(u) local e=units[u]; return e and e.class,e and e.class end
    _G.UnitLevel=function(u) return units[u] and units[u].level end
    _G.UnitFactionGroup=function(u) if u=="player" then return "Alliance" end; return units[u] and units[u].faction end
    _G.GetPlayerInfoByGUID=nil
    _G.DEFAULT_CHAT_FRAME={AddMessage=function(_,s) log[#log+1]=s end}
    _G.SlashCmdList={}; _G.WorldMapFrame=nil
    _G.SendAddonMessage=function() error("must never send") end
    _G.JoinChannelByName=function() error("must never join") end
    local N={}
    for _,file in ipairs({"Safe","Hash","Layer","Protocol","Store","Reports","Adapters","Main"}) do
        assert(loadfile("LayerEnemies/"..file..".lua"))("LayerEnemies",N)
    end
    deliver("ADDON_LOADED","LayerEnemies"); drain()
    no(N.Main.error,"startup error")
    return N
end
local function fakeBulo(id)
    local callbacks={}
    local b={current=id,Radar={seen={}}}
    function b:On(event,fn) callbacks[event]=callbacks[event] or {}; table.insert(callbacks[event],fn) end
    function b:Fire(event,...) for _,fn in ipairs(callbacks[event] or {}) do fn(...) end end
    BuloLayerForever=b
    return b,callbacks
end
local function warSettings()
    loaded.WarEffortScout=true; metadata.WarEffortScout="0.2.13"
    WarEffortScoutDB={silent=false,guildOnly=false,ignored={}}
end
local function player(name,faction,guid)
    return {guid=guid or "Player-1-123",player=true,name=name,realm="Test Realm",class="MAGE",level=60,faction=faction}
end
local function npc(n,zone,sv) return "Creature-0-"..(sv or "7086").."-0-"..(zone or 7).."-"..n.."-ABCDEF" end
local function establish(N)
    units.target={guid=npc(1),player=false}; deliver("PLAYER_TARGET_CHANGED"); drain(); advance(.1)
    units.mouseover={guid=npc(2),player=false}; deliver("UPDATE_MOUSEOVER_UNIT"); drain(); advance(.1)
    eq(N.Main.store.bulo,"7086-7"); eq(N.Main.store.zoneUID,7)
end
local function reportFixture(N)
    local t=N.Reports.new()
    local function feed(text,sender,evidence,at)
        return N.Reports.receive(t,text,sender or "Reporter",at or 200,720100,function(id) return (id==100 or id==101) and 100 or id end,100,7,0,evidence==false and nil or (evidence or 720100))
    end
    return t,feed
end

test("strict frames start shown, dispatcher hidden, no UI or OnUpdate",function()
    local N=loadAddon()
    eq(#frames,1); no(frames[1]:IsShown()); eq(frames[1].scripts.OnUpdate,nil)
    local f=CreateFrame("Frame"); yes(f:IsShown()); no(pcall(function() f:InventedMethod() end))
    eq(N.Main.statusBulo,"not installed"); eq(N.Main.statusWE,"not installed")
end)
test("neither source: own observation works after local NPC confirmation",function()
    local N=loadAddon(); establish(N)
    units.target=player("Enemy","Horde"); advance(1); deliver("PLAYER_TARGET_CHANGED"); drain()
    local rows=N.Store.rows(N.Main.store,clock,"local")
    eq(#rows,1); eq(rows[1].name,"Enemy"); eq(rows[1].confidence,"seen by you"); eq(rows[1].x,.25)
    SlashCmdList.LAYERENEMIES(""); yes(table.concat(log,"\n"):find("Enemy",1,true)); no(N.Main.error)
end)
test("Bulo present subscribes and copies timestamps without position",function()
    local N=loadAddon(); local b,cb=fakeBulo("7086-7")
    advance(1); N.Main.poll(); yes(cb.LFS_LAYER); yes(cb.LFS_RAW); yes(cb.LFS_TRANSFER)
    advance(1); b.Radar.seen["Player-2-1"]={at=clock,hostile=true,src="target"}
    N.Main.poll(); b.Radar.seen={}
    local row=N.Main.store.localSeen["Player-2-1"]
    yes(row); eq(row.at,clock); eq(row.x,nil); eq(row.faction,"unknown")
    eq(#N.Store.rows(N.Main.store,clock,"local"),0)
    eq(#N.Store.rows(N.Main.store,clock,"unclassified"),1)
    advance(46); yes(N.Main.store.localSeen["Player-2-1"])
    advance(555); eq(N.Main.store.localSeen["Player-2-1"],nil)
end)
test("Bulo shape changes and throwing fields cannot crash",function()
    local N=loadAddon(); BuloLayerForever={current="7086-7",Radar="changed"}; N.Main.poll()
    eq(N.Main.statusBulo,"Bulo data unavailable")
    BuloLayerForever=setmetatable({},{__index=function() error("foreign") end}); N.Main.poll()
    eq(N.Main.statusBulo,"Bulo data unavailable"); no(N.Main.error)
    BuloLayerForever=secret; N.Main.poll(); eq(N.Main.statusBulo,"Bulo data unavailable")
end)
test("Bulo unsafe/no event bus uses polling",function()
    local N=loadAddon(); local b=fakeBulo("7086-7"); b.On=function() error("changed bus") end
    advance(5); no(N.Main.bus); eq(N.Main.store.bulo,"7086-7")
    b.current="7087-9"; advance(5); eq(N.Main.store.bulo,"7087-9"); no(N.Main.error)
end)
test("Bulo layer and raw changes wipe all previous sightings",function()
    local N=loadAddon(); local b=fakeBulo("7086-7"); N.Main.poll(); advance(1)
    b.Radar.seen.a={at=clock,hostile=true,src="target"}; N.Main.poll(); yes(N.Main.store.localSeen.a)
    advance(1); b.current="7086-8"; b:Fire("LFS_RAW",b.current); drain()
    eq(N.Main.store.localSeen.a,nil); eq(N.Main.store.bulo,"7086-8")
    advance(1); b.current="8000-2"; b:Fire("LFS_LAYER",b.current); drain()
    eq(N.Main.store.bulo,"8000-2"); eq(N.Safe.count(N.Main.store.localSeen),0)
end)
test("transfer epoch rejects old Bulo and carried unit observations",function()
    local N=loadAddon(); local b=fakeBulo("7086-7"); N.Main.poll(); advance(1)
    units.target=player("OldEnemy","Horde"); deliver("PLAYER_TARGET_CHANGED"); drain()
    b.Radar.seen[units.target.guid]={at=clock,hostile=true,src="target"}
    advance(1); deliver("SHARD_TRANSFER"); drain()
    eq(N.Safe.count(N.Main.store.localSeen),0); eq(N.Main.store.bulo,nil)
    advance(1); deliver("PLAYER_TARGET_CHANGED"); drain(); eq(N.Safe.count(N.Main.store.localSeen),0)
    advance(1); b.current="9000-8"; b:Fire("LFS_LAYER",b.current); drain()
    eq(N.Main.store.bulo,"9000-8"); eq(N.Safe.count(N.Main.store.localSeen),0)
end)
test("zone and child-map handling reset only real zones",function()
    local N=loadAddon(); establish(N); local epoch=N.Main.store.serial
    map=101; deliver("ZONE_CHANGED"); drain(); eq(N.Main.store.serial,epoch)
    local z,x=N.Adapters.location(); eq(z,100); eq(x,nil)
    map=200; deliver("ZONE_CHANGED_NEW_AREA"); drain()
    eq(N.Main.store.zone,200); eq(N.Main.store.bulo,nil); eq(N.Main.store.zoneUID,nil)
end)
test("missing map API safely disables zone-dependent output",function()
    local N=loadAddon(); C_Map=nil; deliver("ZONE_CHANGED"); drain()
    eq(N.Main.store.zone,nil); eq(#N.Store.mapCandidates(N.Main.store,clock,100),0); no(N.Main.error)
end)
test("hostility does not override same faction or unknown faction",function()
    local N=loadAddon(); establish(N)
    units.target=player("Duelist","Alliance"); advance(1); deliver("PLAYER_TARGET_CHANGED"); drain()
    eq(#N.Store.rows(N.Main.store,clock,"local"),0)
    eq(#N.Store.rows(N.Main.store,clock,"unclassified"),1)
    units.mouseover=player("Hidden","Horde","Player-1-456"); units.mouseover.faction=secret
    advance(1); deliver("UPDATE_MOUSEOVER_UNIT"); drain()
    eq(#N.Store.rows(N.Main.store,clock,"local"),0); eq(#N.Store.rows(N.Main.store,clock,"unclassified"),2)
end)
test("secret names/classes/levels/GUIDs remain unreadable",function()
    local N=loadAddon(); establish(N)
    units.target=player(secret,"Horde"); units.target.class=secret; units.target.level=secret
    advance(1); deliver("PLAYER_TARGET_CHANGED"); drain()
    local row=N.Store.rows(N.Main.store,clock,"local")[1]; yes(row); eq(row.name,nil); eq(row.class,nil); eq(row.level,nil)
    SlashCmdList.LAYERENEMIES(""); yes(table.concat(log,"\n"):find("Unknown",1,true))
    units.target.guid=secret; deliver("PLAYER_TARGET_CHANGED"); drain(); no(N.Main.error)
    eq(N.Safe.str(secret),nil); eq(N.Safe.num(secret),nil)
end)
test("optional GUID enrichment checks each return and missing API",function()
    local N=loadAddon(); eq(N.Adapters.enrich("Player-1-2"),nil)
    GetPlayerInfoByGUID=function() return secret,secret,secret,secret,2,secret,secret end
    local n,r,c,race=N.Adapters.enrich("Player-1-2"); eq(n,nil); eq(r,nil); eq(c,nil); eq(race,nil)
    GetPlayerInfoByGUID=function() return "Mage","MAGE","Human","Human",2,"Named","Realm" end
    n,r,c,race=N.Adapters.enrich("Player-1-2"); eq(n,"Named"); eq(r,"Realm"); eq(c,"MAGE"); eq(race,"Human")
    eq(N.Adapters.enrich("target:Name"),nil)
end)
test("NPC GUID parsing keeps namespaces and requires distinct NPC kinds",function()
    local N=loadAddon(); local t=N.Layer.new()
    eq(N.Layer.npc("Player-1-2"),nil); eq(N.Layer.npc(npc(1,0)),nil)
    eq(N.Layer.observe(t,npc(1),1),nil); eq(N.Layer.observe(t,npc(1),2),nil)
    eq(N.Layer.observe(t,npc(2),3),7)
    local zone,kind,raw=N.Layer.npc(npc(42,13,"8000")); eq(zone,13); eq(kind,42); eq(raw,"8000-13")
    eq(N.Layer.bulo("8000-13"),"8000"); eq(N.Layer.bulo("garbage"),nil)
    N.Layer.reset(t); eq(t.current,nil); eq(N.Safe.count(t.votes),0)
end)
test("mixed servers sharing zoneUID do not confirm a server id",function()
    local N=loadAddon(); local t=N.Layer.new()
    N.Layer.observe(t,npc(1,7,"8000"),1)
    local z,_,raw=N.Layer.observe(t,npc(2,7,"9000"),2)
    eq(z,7); eq(raw,nil)
end)
test("NPC vote memory, TTL, pets, and coalescing bounded",function()
    local N=loadAddon()
    for i=1,500 do N.Layer.observe(N.Main.npcs,npc(i,i),i/100) end
    yes(#N.Main.npcs.votes<=5)
    N.Layer.observe(N.Main.npcs,npc(600),1000); eq(N.Main.npcs.current,nil)
    units.target={guid=npc(1),controlled=true}; deliver("PLAYER_TARGET_CHANGED"); drain(); eq(N.Main.store.zoneUID,nil)
    units.target=player("One","Horde")
    for _=1,100 do deliver("PLAYER_TARGET_CHANGED") end
    eq(N.Safe.count(N.Main.pendingUnits),1); drain(); no(N.Main.error)
end)
test("hash vectors and normalization",function()
    local N=loadAddon()
    eq(N.Hash.nameKey("Name","Test-Re alm"),"name-testrealm")
    eq(N.Hash.hash3("abc"),"LXq") -- independent integer reference: djb2 = 193485963
    eq(N.Hash.player("NAME","Test Realm"),N.Hash.player("name","test-realm"))
    eq(N.Hash.player(secret,"Realm"),nil)
end)
test("strict C E H parsing of documented wire examples",function()
    local N=loadAddon(); local P=N.Protocol
    local c=P.decode("C|1|100|0.250|0.750|7|2|100|45")
    yes(c); eq(c.layer,7); eq(c.count,2); eq(c.spread,45)
    local e=P.decode("E|1|1|1|abc:H:60,XYZ:?:?|100")
    yes(e); eq(e.enemies[1].class,"MAGE"); eq(e.enemies[2].level,nil)
    local h=P.decode("H|0.2.13|100|7|1|8|0|0|100|-|H|60")
    yes(h); eq(h.stamp,100); eq(P.decode("C|1|0|0|0|7|1|100"),nil)
end)
test("decoder rejects hostile malformed and oversized messages",function()
    local N=loadAddon()
    local bad={"",string.rep("A",256),"C|1|100|nan|0|7|1|100","C|1|100|1.01|0|7|1|100","C|0|100|0|0|7|1|100","C|1|100|0|0|7|1|3600","C|1|100|0|0|7|1|100|46","C|1|100|0|0|7|1","C|1|100|0|0|7|1|100|1|extra","E|1|2|1|abc:H:60|100","E|1|1|1|abcd:H:60|100","E|1|1|1|abc:Z:60|100","E|1|1|1|abc:H:0|100","E|1|1|1|abc:H:60,|100","E|1|1|1||100","H|bad|100|7|1|8|0|1|100","C|1|100|0|0|7|1|100\n","T|100|0|0|100"}
    for _,text in ipairs(bad) do eq(N.Protocol.decode(text),nil,text) end
    eq(N.Protocol.decode(secret),nil); eq(N.Protocol.decode({}),nil)
end)
test("reassembly accepts E parts out of order before cluster",function()
    local N=loadAddon(); local t,feed=reportFixture(N)
    eq(feed("E|1|2|2|def:A:40|100"),nil)
    eq(feed("E|1|1|2|abc:H:60|100"),nil)
    local r,why=feed("C|1|101|0.1|0.2|7|2|100")
    yes(r); eq(why,"complete"); eq(#r.enemies,2); eq(r.enemies[1].hash,"abc"); eq(r.zone,100)
    eq(N.Safe.count(t.pending),0); eq(N.Safe.count(t.tombstones),1)
end)
test("reassembly accepts C then E and stamps freshness explicitly",function()
    local N=loadAddon(); local _,feed=reportFixture(N)
    feed("C|1|100|0|1|7|1|100")
    local r=feed("E|1|1|1|abc:H:60|100")
    yes(r); eq(r.freshness,"verified"); eq(r.at,200)
end)
test("fragment inconsistency, duplicate conflict and count checks",function()
    local N=loadAddon()
    local _,feed=reportFixture(N)
    feed("E|1|1|2|abc:H:60|100")
    local r,why=feed("E|1|2|3|def:A:40|100"); eq(r,nil); eq(why,"inconsistent part total")
    _,feed=reportFixture(N); feed("E|1|1|1|abc:H:60|100")
    r,why=feed("E|1|1|1|abc:A:40|100"); eq(r,nil); eq(why,"conflicting fragment")
    _,feed=reportFixture(N); feed("C|1|100|0|0|7|2|100")
    r,why=feed("E|1|1|1|abc:H:60|100"); eq(r,nil); eq(why,"enemy count mismatch")
    _,feed=reportFixture(N); feed("C|1|100|0|0|7|2|100")
    r,why=feed("E|1|1|1|abc:H:60,abc:A:40|100"); eq(r,nil); eq(why,"duplicate enemy hash")
end)
test("identical fragment duplicates are harmless",function()
    local N=loadAddon(); local _,feed=reportFixture(N)
    feed("E|1|1|2|abc:H:60|100")
    local r,why=feed("E|1|1|2|abc:H:60|100"); eq(r,nil); eq(why,"duplicate fragment")
    feed("E|1|2|2|def:A:40|100")
    yes(feed("C|1|100|0|0|7|2|100"))
end)
test("wrong zone, wrong layer and zero layer never match",function()
    local N=loadAddon()
    for _,text in ipairs({"C|1|200|0|0|7|1|100","C|1|100|0|0|8|1|100","C|1|100|0|0|0|1|100"}) do
        local _,feed=reportFixture(N); local r,why=feed(text); eq(r,nil); eq(why,"zone/layer mismatch")
    end
end)
test("stale, future, missing and ambiguous source timestamps rejected",function()
    local N=loadAddon(); local t=N.Reports.new()
    eq(N.Protocol.clockAge(100,720100),0); eq(N.Protocol.clockAge(3599,720000),1)
    eq(N.Protocol.clockAge(101,720100),nil); eq(N.Protocol.clockAge(60,720100),nil)
    local r,why=N.Reports.receive(t,"C|1|100|0|0|7|1|100","Reporter",200,720100,function() return 100 end,100,7,0,nil)
    eq(r,nil); eq(why,"freshness unavailable: hour-relative timestamp"); eq(N.Safe.count(t.pending),0)
    r,why=N.Reports.receive(t,"C|1|100|0|0|7|1|100","Reporter",200,720100,function() return 100 end,100,7,0,716500)
    eq(r,nil); eq(why,"freshness unavailable: hour-relative timestamp")
end)
test("same-id replay rejected even with a new plausible stamp",function()
    local N=loadAddon(); local t,feed=reportFixture(N)
    feed("C|1|100|0|0|7|1|100"); yes(feed("E|1|1|1|abc:H:60|100"))
    local r,why=feed("C|1|100|0|0|7|1|100"); eq(r,nil); eq(why,"replayed report")
    r,why=N.Reports.receive(t,"C|1|100|0|0|7|1|101","Reporter",201,720101,function() return 100 end,100,7,0,720101)
    eq(r,nil); eq(why,"replayed report")
end)
test("sender, rate, pending and tombstone caps",function()
    local N=loadAddon(); local t=N.Reports.new()
    for i=1,1000 do N.Reports.receive(t,"E|1|1|2|abc:H:60|100","Sender"..i,200+i/10,720100,function() return 100 end,100,7,0,720100) end
    yes(N.Safe.count(t.senders)<=64); yes(N.Safe.count(t.pending)<=32)
    for i=1,100 do N.Reports.receive(t,"E|"..i.."|1|2|abc:H:60|100","Sender1",400,720100,function() return 100 end,100,7,0,720100) end
    yes(N.Safe.count(t.pending)<=32); yes(N.Safe.count(t.tombstones)<=512)
    N.Reports.prune(t,5000); eq(N.Safe.count(t.pending),0); eq(N.Safe.count(t.senders),0)
    local u=N.Reports.new()
    for i=1,512 do u.tombstones["s:"..i]=200 end
    local r,why=N.Reports.receive(u,"E|1|1|2|abc:H:60|100","New",201,720100,function() return 100 end,100,7,0,720100)
    eq(r,nil); eq(why,"report cap")
end)
test("timed-out fragments cannot bridge old pending assembly",function()
    local N=loadAddon(); local t,feed=reportFixture(N)
    feed("C|1|100|0|0|7|1|100"); N.Reports.prune(t,216)
    local r,why=feed("E|1|1|1|abc:H:60|100",nil,nil,217)
    eq(r,nil); eq(why,"pending")
end)
test("passive CHAT_MSG_ADDON: own echo and wrong channels ignored",function()
    local N=loadAddon(); warSettings()
    local msg="C|1|100|0|0|7|1|100"
    deliver("CHAT_MSG_ADDON","WEFF1",msg,"GUILD","Me-TestRealm"); eq(N.Main.lastDrop,"own echo")
    deliver("CHAT_MSG_ADDON","WEFF1",msg,"WHISPER","Other"); eq(N.Main.lastDrop,"channel disallowed")
    deliver("CHAT_MSG_ADDON","WEFF1",msg,"CHANNEL","Other",nil,nil,7,"OtherChannel"); eq(N.Main.lastDrop,"wrong channel")
    deliver("CHAT_MSG_ADDON","WEFF1",msg,"CHANNEL","Other",nil,nil,7,"WarEffortPubH"); eq(N.Main.lastDrop,"wrong channel")
    deliver("CHAT_MSG_ADDON",secret,msg,"GUILD","Other"); no(N.Main.error)
end)
test("guild-only, ignored, client ignore, silent and privacy unknown",function()
    local N=loadAddon(); warSettings()
    WarEffortScoutDB.guildOnly=true
    no(N.Adapters.policy("WEFF1","CHANNEL","Other","WarEffortPubA"))
    yes(N.Adapters.policy("WEFF1","GUILD","Other"))
    WarEffortScoutDB.ignored.other="Other"; no(N.Adapters.policy("WEFF1","GUILD","Other"))
    WarEffortScoutDB.ignored={}; clientIgnored=true; no(N.Adapters.policy("WEFF1","GUILD","Other"))
    clientIgnored=false; WarEffortScoutDB.silent=true; no(N.Adapters.policy("WEFF1","GUILD","Other"))
    WarEffortScoutDB.silent=false; WarEffortScoutDB.ignored=secret; no(N.Adapters.policy("WEFF1","GUILD","Other"))
    WarEffortScoutDB.ignored={}; metadata.WarEffortScout="0.3.0"; no(N.Adapters.policy("WEFF1","GUILD","Other"))
    metadata.WarEffortScout="0.2.13"; C_FriendList=nil; no(N.Adapters.policy("WEFF1","GUILD","Other"))
end)
test("approved public context only; legacy settings fail closed",function()
    local N=loadAddon(); warSettings()
    yes(N.Adapters.policy("WEFF1","CHANNEL","Other","WarEffortPubA"))
    channels.WarEffortPubA=nil; no(N.Adapters.policy("WEFF1","CHANNEL","Other","WarEffortPubA"))
    no(N.Adapters.policy("ZRAD1","GUILD","Other"))
    loaded.WarEffortScout=false; no(N.Adapters.policy("WEFF1","GUILD","Other"))
end)
test("live guild C E and H heard but never bypass ambiguous freshness",function()
    local N=loadAddon(); establish(N); warSettings()
    -- Server time advanced with the fixture, keep stamp equal to the current second.
    local stamp=math.floor(server)%3600
    deliver("CHAT_MSG_ADDON","WEFF1","C|1|100|0|0|7|1|"..stamp,"GUILD","Other")
    deliver("CHAT_MSG_ADDON","WEFF1","E|1|1|1|abc:H:60|"..stamp,"GUILD","Other")
    eq(N.Main.lastDrop,"freshness unavailable: hour-relative timestamp"); eq(N.Safe.count(N.Main.store.reports),0)
    eq(N.Safe.count(N.Main.receiver.pending),0); yes(N.Main.lastHeard)
    deliver("CHAT_MSG_ADDON","WEFF1","H|0.2.13|100|7|1|8|0|0|"..stamp.."|-|H|60","GUILD","Other")
    eq(N.Main.lastDrop,"freshness unavailable: hour-relative timestamp")
    SlashCmdList.LAYERENEMIES("reports"); yes(table.concat(log,"\n"):find("freshness unavailable",1,true)); no(N.Main.error)
end)
test("reported reducer output stays separate with possible hash identities",function()
    local N=loadAddon(); local t=N.Store.new(0); t.zone=100; t.bulo="7086-7"; t.zoneUID=7
    yes(N.Store.observe(t,{key="Player-1-1",at=100,name="Enemy",realm="Test Realm",class="MAGE",faction="opposite",source="own target"},100))
    local hash=N.Hash.player("Enemy","Test Realm")
    local report={id=1,sender="Reporter",zone=100,layer=7,at=101,enemies={{hash=hash,class="MAGE",level=60}},freshness="verified",x=.4,y=.5}
    yes(N.Store.report(t,report,101))
    local rows=N.Store.rows(t,101,"reported"); eq(#rows,1); eq(rows[1].name,"Unknown"); yes(rows[1].possible:find("possible identity:",1,true))
    eq(rows[1].confidence,"reported zoneUID match (unverified)"); eq(rows[1].namespace,"war-effort-zoneUID")
    eq(#N.Store.rows(t,101,"local"),1)
    t.identities[hash]["Collision-Realm"]=101
    rows=N.Store.rows(t,101,"reported"); yes(rows[1].possible:find("Collision-Realm",1,true))
    report.freshness=nil; no(N.Store.report(t,report,101))
end)
test("store expiration, epoch, caps and deterministic newest ordering",function()
    local N=loadAddon(); local t=N.Store.new(100); t.zone=100; t.bulo="7086-7"
    no(N.Store.observe(t,{key="old",at=99},200)); no(N.Store.observe(t,{key="equal",at=100},200)); no(N.Store.observe(t,{key="future",at=201},200))
    for i=1,300 do N.Store.observe(t,{key=tostring(i),at=101+i/10,faction="opposite",source="own target"},200) end
    eq(N.Safe.count(t.localSeen),256)
    local rows=N.Store.rows(t,200,"local"); eq(rows[1].key,"256"); eq(rows[#rows].key,"1")
    N.Store.prune(t,800); eq(N.Safe.count(t.localSeen),0)
    N.Store.reset(t,801,200,"8000-9",9); eq(t.zone,200); eq(N.Safe.count(t.identities),0)
end)
test("headless map candidates only for shown zone, never fake enemy coordinates",function()
    local N=loadAddon(); establish(N)
    units.target=player("Enemy","Horde"); advance(1); deliver("PLAYER_TARGET_CHANGED"); drain()
    eq(#N.Store.mapCandidates(N.Main.store,clock,200),0)
    local candidates=N.Store.mapCandidates(N.Main.store,clock,100)
    eq(#candidates,1); eq(candidates[1].x,.25); eq(candidates[1].positionKind,"approximate observer position")
    eq(#frames,1)
end)
test("SavedVariables contain options only; no sightings survive reload",function()
    local N=loadAddon(); establish(N)
    units.target=player("PrivateName","Horde"); advance(1); deliver("PLAYER_TARGET_CHANGED"); drain()
    eq(LayerEnemiesDB.sightings,nil); eq(LayerEnemiesDB.localSeen,nil); yes(LayerEnemiesDB.options)
    N.Main.start(); eq(#frames,1)
    N=loadAddon(); eq(N.Safe.count(N.Main.store.localSeen),0)
end)
test("heartbeat is five seconds idle, two while map shown",function()
    local N=loadAddon()
    local function nextDelay() local d=math.huge; for _,v in ipairs(timers) do d=math.min(d,v.at-clock) end; return d end
    eq(nextDelay(),5)
    WorldMapFrame=CreateFrame("Frame"); advance(5); eq(nextDelay(),2)
    WorldMapFrame:Hide(); advance(2); eq(nextDelay(),5); no(N.Main.error)
end)
test("missing timer and message-registration APIs degrade safely",function()
    local N=loadAddon(); C_Timer=nil; C_ChatInfo=nil
    N.Main.queueUnit("target"); N.Main.queuePoll(); no(N.Main.error)
    advance(5); eq(N.Main.error,"timer unavailable; event-only mode")
end)
test("old units must disappear before reacquisition after a transfer",function()
    local N=loadAddon(); establish(N)
    units.nameplate1=player("Returning","Horde")
    advance(1); deliver("NAME_PLATE_UNIT_ADDED","nameplate1"); drain()
    deliver("SHARD_TRANSFER"); drain(); eq(N.Safe.count(N.Main.store.localSeen),0)
    units.nameplate1=nil; deliver("NAME_PLATE_UNIT_REMOVED","nameplate1"); drain()
    units.target=nil; deliver("PLAYER_TARGET_CHANGED"); drain()
    units.mouseover=nil; deliver("UPDATE_MOUSEOVER_UNIT"); drain()
    establish(N)
    units.nameplate1=player("Returning","Horde")
    advance(1); deliver("NAME_PLATE_UNIT_ADDED","nameplate1"); drain()
    eq(#N.Store.rows(N.Main.store,clock,"local"),1); no(N.Main.error)
end)
test("epoch boundary tombstones incomplete fragments",function()
    local N=loadAddon(); local t,feed=reportFixture(N)
    feed("E|1|1|2|abc:H:60|100"); N.Reports.clearPending(t)
    local r,why=feed("C|1|100|0|0|7|2|100")
    eq(r,nil); eq(why,"replayed report"); eq(N.Safe.count(t.pending),0)
end)
test("foreign field getter failures do not escape game event dispatch",function()
    local N=loadAddon()
    C_Map=setmetatable({},{__index=function() error("API shape changed") end})
    yes(pcall(deliver,"ZONE_CHANGED")); eq(N.Main.error,"data unavailable (API error)")
end)
print(string.format("RESULT: %d tests passed, %d failed, %d assertions",passed,failed,checks))
if failed>0 then os.exit(1) end
