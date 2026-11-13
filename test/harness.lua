-- Run from the project root with Lua 5.1. No external addons loaded by this test.
local passed,failed,checks=0,0,0
local function eq(a,b,msg)
    checks=checks+1
    if a~=b then error((msg or "not equal")..": expected "..tostring(b)..", got "..tostring(a),2) end
end
local function yes(v,msg) eq(not not v,true,msg) end
local function no(v,msg) eq(not not v,false,msg) end
local forbidden
local function test(name,fn)
    local ok,err=pcall(fn)
    -- No test may reach an API that sends, invites, accepts or leaves.
    if ok and (forbidden or 0)>0 then ok,err=false,"forbidden API reached "..forbidden.." time(s)" end
    if ok then passed=passed+1; print("PASS "..name) else failed=failed+1; print("FAIL "..name..": "..tostring(err)) end
end
local secret=setmetatable({}, {__tostring=function() error("secret stringify") end,__concat=function() error("secret concatenate") end,__lt=function() error("secret compare") end,__index=function() error("secret index") end})
function issecretvalue(v) return rawequal(v,secret) end
local frames,timers,log,units,loaded,metadata
local clock,map,server,channels,inGuild,clientIgnored
local wall,grouped,opened
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
local function advance(n) clock=clock+n; server=server+n; wall=wall+n; drain() end
local function loadAddon()
    frames,timers,log,units,loaded,metadata={},{},{},{},{},{}
    clock,map,server,channels,inGuild,clientIgnored=10,100,720100,{WarEffortPubA=7},true,false
    wall,grouped,opened,forbidden=1800000000,false,{},0
    _G.BuloLayerForever=nil; _G.WarEffortScoutDB=nil; _G.LayerEnemiesDB=nil
    _G.LayerSwapDB=nil; _G.LE=nil; _G.ChatFrameUtil=nil; _G.ChatFrame_OpenChat=nil
    _G.time=function() return wall end
    _G.IsInGroup=function() return grouped end
    -- Anything that would act for the user counts as a failure, even under pcall.
    for _,name in ipairs({"SendChatMessage","InviteUnit","LeaveParty","AcceptGroup","DeclineGroup","RunMacroText"}) do
        _G[name]=function() forbidden=forbidden+1; error("must never call "..name) end
    end
    _G.C_PartyInfo=setmetatable({},{__index=function(_,key) forbidden=forbidden+1; error("must never use C_PartyInfo."..tostring(key)) end})
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
    _G.C_ChatInfo=setmetatable({RegisterAddonMessagePrefix=function(prefix) yes(prefix=="WEFF1" or prefix=="ZRAD1"); return true end},
        {__index=function(_,key) forbidden=forbidden+1; error("must never use C_ChatInfo."..tostring(key)) end})
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
    _G.SendAddonMessage=function() forbidden=forbidden+1; error("must never send") end
    _G.JoinChannelByName=function() forbidden=forbidden+1; error("must never join") end
    local N={}
    for _,file in ipairs({"Safe","Hash","Layer","Protocol","Store","Reports","Adapters","Invite","Main"}) do
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
    GetPlayerInfoByGUID=function() return "Mage","MAGE","Human","Human",2,"Named","Realm",60 end
    local level
    n,r,c,race,level=N.Adapters.enrich("Player-1-2"); eq(n,"Named"); eq(r,"Realm"); eq(c,"MAGE"); eq(race,"Human"); eq(level,60)
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
    eq(r,nil); eq(why,"replayed report")
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
test("live guild C E accepted by time of receipt, hello ignored",function()
    local N=loadAddon(); establish(N); warSettings()
    local stamp=math.floor(server)%3600
    deliver("CHAT_MSG_ADDON","WEFF1","C|1|100|0|0|7|1|"..stamp,"GUILD","Other")
    eq(N.Main.lastDrop,"pending"); eq(N.Safe.count(N.Main.store.reports),0)
    deliver("CHAT_MSG_ADDON","WEFF1","E|1|1|1|abc:H:60|"..stamp,"GUILD","Other")
    eq(N.Main.lastDrop,"complete"); eq(N.Safe.count(N.Main.store.reports),1)
    eq(N.Safe.count(N.Main.receiver.pending),0); yes(N.Main.lastHeard)
    deliver("CHAT_MSG_ADDON","WEFF1","H|0.2.13|100|7|1|8|0|0|"..stamp.."|-|H|60","GUILD","Other")
    eq(N.Main.lastDrop,"hello"); eq(N.Safe.count(N.Main.store.reports),1)
    SlashCmdList.LAYERENEMIES("reports"); yes(table.concat(log,"\n"):find("Reported, not confirmed",1,true)); no(N.Main.error)
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
test("unchanged Bulo timestamps allocate no duplicate observations",function()
    local N=loadAddon(); local b=fakeBulo("7086-7"); N.Main.poll(); advance(1)
    b.Radar.seen.a={at=clock,hostile=true,src="target"}; N.Main.poll()
    local first=N.Main.store.localSeen.a
    local snap=N.Adapters.bulo(N.Main.store.epoch,clock,N.Main.store.localSeen)
    eq(#snap.observations,0); N.Main.poll(); eq(N.Main.store.localSeen.a,first)
    advance(1); b.Radar.seen.a.at=clock; N.Main.poll()
    yes(N.Main.store.localSeen.a~=first); eq(first.at,clock-1)
end)
test("deterministic decoder fuzz never crashes or accepts oversized input",function()
    local N=loadAddon(); math.randomseed(1337)
    local alphabet="CEH|0123456789abcdef:?-,. \n"
    for _=1,5000 do
        local n=math.random(0,300); local s={}
        for i=1,n do local pos=math.random(#alphabet); s[i]=alphabet:sub(pos,pos) end
        local ok,msg=pcall(N.Protocol.decode,table.concat(s))
        yes(ok); if n>255 then eq(msg,nil) end
    end
end)
test("same-frame own unit data can classify a Bulo copy without restamping",function()
    local N=loadAddon(); local b=fakeBulo("7086-7"); N.Main.poll(); advance(1)
    units.target=player("Verified","Horde")
    b.Radar.seen[units.target.guid]={at=clock,hostile=true,src="target"}; N.Main.poll()
    eq(#N.Store.rows(N.Main.store,clock,"local"),0)
    deliver("PLAYER_TARGET_CHANGED"); drain()
    local rows=N.Store.rows(N.Main.store,clock,"local")
    eq(#rows,1); eq(rows[1].at,clock); eq(rows[1].source,"own target"); eq(rows[1].x,.25)
end)
test("loaded Bulo with missing namespace reports unavailable rather than absent",function()
    local N=loadAddon(); loaded.BuloLayerForever=true; N.Main.poll()
    eq(N.Main.statusBulo,"Bulo data unavailable"); no(N.Main.error)
end)
-- ---------------------------------------------------------------------------
-- War Effort reports dated by time of receipt, and the ask-for-invite flow.
local ASK="Hi! Could you invite me to your layer please? I'll leave right after."
local function logged(text) return table.concat(log,"\n"):find(text,1,true)~=nil end
local function lines(text) local n=0; for _,l in ipairs(log) do if l:find(text,1,true) then n=n+1 end end; return n end
local function names(list) local out={}; for i,c in ipairs(list) do out[i]=c.name end; return table.concat(out,",") end
local function chatBox() ChatFrameUtil={OpenChat=function(text,frame) opened[#opened+1]={text=text,frame=frame} end} end
local function friends(N,list,book)
    local b=fakeBulo("7086-7"); b.Guild={list=list or {}}
    if book then LayerSwapDB={book=book} end
    N.Main.poll(); eq(N.Main.store.bulo,"7086-7")
    return b
end
local function there(extra)
    local e={key="8000",zone="100",host=false,at=wall}
    for k,v in pairs(extra or {}) do e[k]=v end
    return e
end
local function page(extra)
    local e={layer="8000-13",zone="100",at=wall}
    for k,v in pairs(extra or {}) do e[k]=v end
    return e
end
local function report(id,layer,sender,map)
    local stamp=math.floor(server)%3600
    deliver("CHAT_MSG_ADDON","WEFF1","C|"..id.."|"..(map or 100).."|0.4|0.5|"..layer.."|1|"..stamp,"GUILD",sender or "Other")
    deliver("CHAT_MSG_ADDON","WEFF1","E|"..id.."|1|1|abc:H:40|"..stamp,"GUILD",sender or "Other")
end
test("one layer key helper compares the server part only",function()
    local N=loadAddon(); local L=N.Layer
    eq(L.key("7086-7"),"7086"); eq(L.key("7086"),"7086"); eq(L.key(7086),"7086")
    for _,bad in ipairs({"","x","7086-","-7","7086-7-1","70 86",0,-1,1.5,1e15,0/0,{},true,string.rep("1",33)}) do eq(L.key(bad),nil) end
    eq(L.key(secret),nil); eq(L.key(nil),nil)
    yes(L.same("7086-7","7086-99")); yes(L.same("7086","7086-1")); yes(L.same(7086,"7086"))
    no(L.same("7086-7","7087-7")); no(L.same(nil,nil)); no(L.same(secret,secret)); no(L.same("7086",nil))
end)
test("receipt time dates a report; it stays reported, not confirmed",function()
    local N=loadAddon(); establish(N); warSettings()
    advance(1); local at=clock; report(1,7)
    eq(N.Main.lastDrop,"complete")
    local rows=N.Store.rows(N.Main.store,clock,"reported")
    eq(#rows,1); eq(rows[1].at,at); eq(rows[1].name,"Unknown"); eq(rows[1].class,"MAGE"); eq(rows[1].level,40)
    eq(rows[1].confidence,"reported, not confirmed"); eq(rows[1].reporter,"Other"); eq(rows[1].relation,"same"); yes(rows[1].receipt)
    eq(rows[1].namespace,"war-effort-zoneUID")
    eq(#N.Store.rows(N.Main.store,clock,"local"),0); eq(#N.Store.rows(N.Main.store,clock,"unclassified"),0)
    eq(#N.Store.mapCandidates(N.Main.store,clock,100),0)
    SlashCmdList.LAYERENEMIES("")
    yes(logged("Reported, not confirmed: 1 more in /le reports")); no(logged("Unknown | MAGE"))
    SlashCmdList.LAYERENEMIES("reports")
    yes(logged("Reported, not confirmed (War Effort, dated by time of receipt):"))
    yes(logged("Unknown | MAGE | 40 | zone 100 | received 0 s ago | reported (War Effort) | reported, not confirmed | reported by Other | same zoneUID as yours"))
    yes(logged("Only players seen by you or reported by War Effort users.")); no(N.Main.error)
end)
test("receipt-time reports expire ten minutes after receipt",function()
    local N=loadAddon(); establish(N); warSettings(); advance(1); report(1,7)
    advance(598); eq(#N.Store.rows(N.Main.store,clock,"reported"),1); eq(#N.Store.reporters(N.Main.store,clock),1)
    advance(3); eq(#N.Store.rows(N.Main.store,clock,"reported"),0); eq(N.Safe.count(N.Main.store.reports),0)
    eq(#N.Store.reporters(N.Main.store,clock),0)
end)
test("receipt mode: replay tombstones hold for an hour, then the documented limit",function()
    local N=loadAddon(); establish(N); warSettings(); advance(1); report(1,7)
    report(1,7); eq(N.Main.lastDrop,"replayed report"); eq(N.Safe.count(N.Main.store.reports),1)
    advance(20); report(1,7); eq(N.Main.lastDrop,"replayed report")
    -- One hour later the second-of-hour stamp matches again: still tombstoned.
    advance(3580); eq(N.Safe.count(N.Main.store.reports),0)
    report(1,7); eq(N.Main.lastDrop,"replayed report"); eq(N.Safe.count(N.Main.store.reports),0)
    -- KNOWN LIMIT: two hours later the tombstone is gone and the stamp matches,
    -- so a replayed old packet is shown as a fresh unconfirmed report.
    advance(3600); report(1,7); eq(N.Main.lastDrop,"complete"); eq(N.Safe.count(N.Main.store.reports),1)
    eq(N.Store.rows(N.Main.store,clock,"reported")[1].confidence,"reported, not confirmed")
end)
test("receipt mode: stamp window, duplicates and conflicts still enforced",function()
    local N=loadAddon(); establish(N); warSettings(); advance(1)
    local stamp=math.floor(server)%3600
    local function send(text,who) deliver("CHAT_MSG_ADDON","WEFF1",text,"GUILD",who or "Other") end
    send("C|1|100|0|0|7|1|"..(stamp-31)%3600); eq(N.Main.lastDrop,"stale or clock unavailable")
    send("C|1|100|0|0|7|1|"..(stamp+6)%3600); eq(N.Main.lastDrop,"stale or clock unavailable")
    send("C|1|100|0|0|7|1|"..(stamp+1800)%3600); eq(N.Main.lastDrop,"stale or clock unavailable")
    eq(N.Safe.count(N.Main.receiver.pending),0)
    send("C|2|100|0|0|7|1|"..(stamp+5)%3600); eq(N.Main.lastDrop,"pending")
    send("C|3|100|0|0|7|1|"..(stamp-30)%3600); eq(N.Main.lastDrop,"pending")
    send("E|4|1|1|abc:H:60|"..stamp); send("E|4|1|1|abc:H:60|"..stamp); eq(N.Main.lastDrop,"duplicate fragment")
    send("E|4|1|1|abc:A:40|"..stamp); eq(N.Main.lastDrop,"conflicting fragment")
    send("C|4|100|0|0|7|1|"..stamp); eq(N.Main.lastDrop,"replayed report")
    send("C|5|100|0|0|7|2|"..stamp); send("E|5|1|1|abc:H:60|"..stamp); eq(N.Main.lastDrop,"enemy count mismatch")
    send("C|6|100|0|0|0|1|"..stamp); eq(N.Main.lastDrop,"zone/layer mismatch")
    send("C|7|200|0|0|7|1|"..stamp); eq(N.Main.lastDrop,"zone/layer mismatch")
    eq(N.Safe.count(N.Main.store.reports),0)
    GetServerTime=function() return secret end
    send("C|8|100|0|0|7|1|"..stamp); eq(N.Main.lastDrop,"stale or clock unavailable"); no(N.Main.error)
end)
test("receipt mode keeps privacy gates and caps",function()
    local N=loadAddon(); establish(N); warSettings(); advance(1)
    WarEffortScoutDB.silent=true; report(1,7); eq(N.Main.lastDrop,"unavailable: War Effort silent mode")
    WarEffortScoutDB.silent=false; WarEffortScoutDB.ignored.other="Other"; report(1,7); eq(N.Main.lastDrop,"ignored sender")
    WarEffortScoutDB.ignored={}; clientIgnored=true; report(1,7); eq(N.Main.lastDrop,"ignored sender")
    clientIgnored=false; C_FriendList=nil; report(1,7); eq(N.Main.lastDrop,"client ignore policy unavailable")
    C_FriendList={IsIgnored=function() return false end}
    WarEffortScoutDB.guildOnly=true
    local stamp=math.floor(server)%3600
    deliver("CHAT_MSG_ADDON","WEFF1","C|1|100|0|0|7|1|"..stamp,"CHANNEL","Other",nil,nil,7,"WarEffortPubA"); eq(N.Main.lastDrop,"channel disallowed")
    deliver("CHAT_MSG_ADDON","ZRAD1","C|1|100|0|0|7|1|"..stamp,"GUILD","Other"); eq(N.Main.lastDrop,"legacy privacy unavailable")
    loaded.WarEffortScout=false; report(1,7); eq(N.Main.lastDrop,"not installed")
    eq(N.Safe.count(N.Main.store.reports),0); eq(N.Safe.count(N.Main.receiver.pending),0)
    eq(#N.Main.candidates(),0)
    loaded.WarEffortScout=true; WarEffortScoutDB.guildOnly=false
    for i=1,400 do advance(.2); report(i%7+1,9,"Sender"..i) end
    yes(N.Safe.count(N.Main.store.reports)<=64); yes(N.Safe.count(N.Main.store.reports)>0)
    yes(N.Safe.count(N.Main.receiver.senders)<=64); yes(N.Safe.count(N.Main.receiver.pending)<=32)
    yes(N.Safe.count(N.Main.receiver.tombstones)<=512); yes(#N.Main.candidates()<=40); no(N.Main.error)
end)
test("reports from another zoneUID in our zone are kept apart and labelled",function()
    local N=loadAddon(); establish(N); warSettings(); advance(1)
    report(1,9,"Scout-TestRealm"); eq(N.Main.lastDrop,"complete")
    local rows=N.Store.rows(N.Main.store,clock,"reported")
    eq(#rows,1); eq(rows[1].relation,"other"); eq(rows[1].reportLayer,9); eq(rows[1].confidence,"reported, not confirmed")
    deliver("CHAT_MSG_ADDON","WEFF1","C|2|200|0|0|9|1|"..math.floor(server)%3600,"GUILD","Elsewhere"); eq(N.Main.lastDrop,"zone/layer mismatch")
    report(2,9,"Elsewhere",200); eq(N.Main.lastDrop,"replayed report"); eq(N.Safe.count(N.Main.store.reports),1)
    eq(#N.Store.reporters(N.Main.store,clock),1)
    SlashCmdList.LAYERENEMIES("reports"); yes(logged("other zoneUID 9")); yes(logged("ask a reporter for an invite: /le hosts"))
    -- Before our own zoneUID is known the relation is unknown, never "same".
    N=loadAddon(); warSettings(); advance(1); report(1,7)
    eq(N.Store.rows(N.Main.store,clock,"reported")[1].relation,"unknown")
    -- A transfer wipes reports and reporters.
    deliver("SHARD_TRANSFER"); drain(); eq(N.Safe.count(N.Main.store.reports),0); eq(#N.Store.reporters(N.Main.store,clock),0)
    -- Same instant as the boundary: nothing is accepted. Later: still tombstoned.
    report(2,7); eq(N.Main.lastDrop,"before observation epoch")
    advance(1); report(1,7); eq(N.Main.lastDrop,"replayed report"); eq(N.Safe.count(N.Main.store.reports),0)
end)
test("candidates: every source absent",function()
    local N=loadAddon(); establish(N)
    local list,status=N.Main.candidates()
    eq(#list,0); eq(status.bulo,"not installed"); eq(status.book,"not installed"); eq(status.reports,"0 on another zoneUID")
    SlashCmdList.LAYERENEMIES("hosts"); yes(logged("No one to ask right now.")); yes(logged("Your layer: 7086"))
    no(LE.AskInvite("Alice")); yes(logged("not a known friendly player")); eq(#opened,0); no(N.Main.error)
end)
test("candidates: Bulo guild list in wrong shapes is ignored whole",function()
    local N=loadAddon(); local b=friends(N)
    local function status() local list,st=N.Main.candidates(); eq(#list,0); return st.bulo end
    eq(status(),"0 fresh in this zone")
    b.Guild=nil; eq(status(),"data unavailable")
    b.Guild="changed"; eq(status(),"data unavailable")
    b.Guild={}; eq(status(),"data unavailable")
    b.Guild={list="changed"}; eq(status(),"data unavailable")
    b.Guild={list=secret}; eq(status(),"data unavailable")
    b.Guild=secret; eq(status(),"data unavailable")
    b.Guild=setmetatable({},{__index=function() error("foreign") end}); eq(status(),"data unavailable")
    b.Guild={list={Alice=there(),Broken=setmetatable({},{__index=function() error("foreign field") end})}}
    eq(status(),"data unavailable")
    b.Guild={list={Alice="8000",Bob=42,Carl=true,Dora=secret,[7]=there(),[true]=there(),[{}]=there()}}
    eq(status(),"0 fresh in this zone")
    b.Guild={list={Alice={},Bob={key="8000"},Carl={key="8000",zone="100"},Dora={zone="100",at=wall},Erin={key="x",zone="100",at=wall},
        Finn={key="8000",zone="100",at="now"},Gwen={key={},zone={},at={}},Hugo={key="8000-1-2",zone="100",at=wall},Ivan={key="8000",zone="",at=wall}}}
    eq(status(),"0 fresh in this zone")
    BuloLayerForever=secret; local _,st=N.Main.candidates(); eq(st.bulo,"data unavailable")
    BuloLayerForever="changed"; _,st=N.Main.candidates(); eq(st.bulo,"data unavailable"); no(N.Main.error)
end)
test("candidates: Bulo secret, stale, other zone, same layer and self excluded",function()
    local N=loadAddon()
    friends(N,{
        Good=there({at=wall-60}), Edge=there({at=wall-719}), Other=there({other=true,at=wall-30}),
        Stale=there({at=wall-720}), Older=there({at=wall-86400}), Future=there({at=wall+60}),
        Away=there({zone="200"}), ZoneName=there({zone="Elwynn Forest"}), NoZone=there({zone=false}),
        Same=there({key="7086"}), SameFull=there({key="7086-99"}),
        Me=there(), me=there(),
        [secret]=there(), SecretKey=there({key=secret}), SecretZone=there({zone=secret}), SecretAt=there({at=secret}),
        ["Bad Name"]=there(), ["Bad|Name"]=there(), ["Bad\nName"]=there(), ["/g"]=there(), Digit7=there(), X=there(),
        [string.rep("a",61)]=there(), ["Name-Realm-Extra"]=there(), ["Name-"]=there(),
    })
    local list,status=N.Main.candidates()
    eq(names(list),"Other,Good,Edge"); eq(status.bulo,"5 fresh in this zone")
    eq(list[1].layer,"8000"); eq(list[1].age,30); eq(list[1].sources[1],"Bulo"); eq(#list[1].sources,1); no(list[1].host)
    eq(list[3].age,719); no(N.Main.error)
    -- Without a known own layer nobody can be called "another layer".
    N=loadAddon(); local b=fakeBulo(nil); b.Guild={list={Good=there()}}; N.Main.poll()
    list,status=N.Main.candidates(); eq(#list,0); eq(status.bulo,"your layer is not known yet")
    -- Unknown own zone or own name: same.
    N=loadAddon(); friends(N,{Good=there()}); eq(#N.Main.candidates(),1)
    UnitName=function() return secret end; list,status=N.Main.candidates(); eq(#list,0); eq(status.bulo,"own name unreadable")
    UnitName=function() return "Me","Test Realm" end; time=function() return secret end
    list,status=N.Main.candidates(); eq(#list,0); eq(status.bulo,"clock or zone unavailable")
    time=nil; eq(#N.Main.candidates(),0); no(N.Main.error)
end)
test("candidates: LayerSwap book absent, wrong shape, stale, gone, zone, same layer",function()
    local N=loadAddon(); establish(N)
    local function status() local list,st=N.Main.candidates(); eq(#list,0); return st.book end
    eq(status(),"not installed")
    LayerSwapDB="changed"; eq(status(),"data unavailable")
    LayerSwapDB=secret; eq(status(),"data unavailable")
    LayerSwapDB={}; eq(status(),"0 fresh in this zone")
    LayerSwapDB={book="changed"}; eq(status(),"data unavailable")
    LayerSwapDB={book=secret}; eq(status(),"data unavailable")
    LayerSwapDB=setmetatable({},{__index=function() error("foreign") end}); eq(status(),"data unavailable")
    LayerSwapDB={book={Alice=page(),Broken=setmetatable({},{__index=function() error("foreign field") end})}}
    eq(status(),"data unavailable")
    LayerSwapDB={book={Alice="8000-13",Bob=1,[1]=page(),Carl={},Dora={layer="8000-13"},Erin={layer="8000-13",zone="100"},Finn={layer="garbage",zone="100",at=wall}}}
    eq(status(),"0 fresh in this zone")
    LayerSwapDB={book={
        Fresh=page({at=wall-100}), Host=page({host=true,at=wall-600}), Edge=page({at=wall-899}), Numeric=page({zone=100,layer="9000-4",at=wall-200}),
        Stale=page({at=wall-900}), Week=page({at=wall-6*86400,host=true}), Future=page({at=wall+30}),
        Gone=page({gone=wall-5}), GoneSecret=page({gone=secret}), Away=page({zone="200"}), NoZone=page({zone=false}),
        Same=page({layer="7086-7"}), SameOtherZone=page({layer="7086-55"}), Me=page(),
        [secret]=page(), SecretLayer=page({layer=secret}), SecretAt=page({at=secret}), SecretZone=page({zone=secret}),
        ["Bad Name"]=page(), ["Bad|Name"]=page(),
    }}
    local list,st=N.Main.candidates()
    -- hosts first, then newest
    eq(names(list),"Host,Fresh,Numeric,Edge"); eq(st.book,"6 fresh in this zone")
    yes(list[1].host); eq(list[1].layer,"8000"); eq(list[1].sources[1],"LayerSwap"); eq(list[3].layer,"9000"); eq(list[4].age,899)
    -- nothing was written to the foreign table
    eq(N.Safe.count(LayerSwapDB.book),20); eq(LayerSwapDB.book.Stale.at,wall-900); eq(LayerSwapDB.book.Gone.gone,wall-5); no(N.Main.error)
end)
test("candidates: host preference and one row per name across sources",function()
    local N=loadAddon(); warSettings()
    friends(N,{
        Alice=there({at=wall-100}),                 -- same claim in both lists
        Bob=there({at=wall-300}),                   -- LayerSwap has a fresher, different claim
        Carl=there({at=wall-300}),                  -- LayerSwap says: now on our layer
        Dora=there({key="7086",at=wall-10}),        -- Bulo says: on our layer, fresher than the book
        Erin=there({host=true,at=wall-500}),
        Finn=there({at=wall-5}),
    },{
        Alice=page({layer="8000-3",host=true,at=wall-50}),
        Bob=page({layer="9000-1",at=wall-20}),
        Carl=page({layer="7086-7",at=wall-10}),
        Dora=page({layer="8000-3",at=wall-300}),
        alice=page({layer="8000-3",at=wall-700}),   -- same player, other capitalisation
    })
    local list=N.Main.candidates()
    eq(names(list),"Alice,Erin,Finn,Bob")
    -- freshest source first
    eq(list[1].age,50); yes(list[1].host); eq(table.concat(list[1].sources,"+"),"LayerSwap+Bulo")
    eq(list[4].layer,"9000"); eq(table.concat(list[4].sources,"+"),"LayerSwap"); eq(list[4].age,20)
    -- A War Effort reporter on another zoneUID goes first and merges by name.
    units.target={guid=npc(1),player=false}; deliver("PLAYER_TARGET_CHANGED"); drain(); advance(.1)
    units.mouseover={guid=npc(2),player=false}; deliver("UPDATE_MOUSEOVER_UNIT"); drain(); advance(.1)
    eq(N.Main.store.zoneUID,7)
    report(1,9,"Bob-TestRealm"); report(2,9,"Zed-TestRealm"); report(3,7,"Sam"); report(4,9,"Carl"); report(5,9,"Me-TestRealm")
    advance(2); report(6,9,"Zed-TestRealm")
    list=N.Main.candidates()
    eq(names(list),"Zed-TestRealm,Bob,Alice,Erin,Finn")
    yes(list[1].reporter); eq(list[1].layer,nil); eq(table.concat(list[1].sources,"+"),"War Effort"); eq(list[1].age,0)
    yes(list[2].reporter); eq(list[2].layer,"9000"); eq(table.concat(list[2].sources,"+"),"LayerSwap+War Effort")
    no(list[3].reporter)
end)
test("candidates: huge foreign lists stay bounded",function()
    local N=loadAddon(); local list={}
    local letters="abcdefghijklmnopqrstuvwxyz"
    for i=1,3000 do
        local a,b,c=i%26+1,math.floor(i/26)%26+1,math.floor(i/676)%26+1
        list["P"..letters:sub(a,a)..letters:sub(b,b)..letters:sub(c,c)]=there({at=wall-(i%700)})
    end
    friends(N,list)
    local out=N.Main.candidates(); yes(#out<=40); yes(#out>0); no(N.Main.error)
end)
test("ask: chat box opened one frame later with the exact line, never sent",function()
    local N=loadAddon(); friends(N,{Alice=there({host=true})}); chatBox()
    yes(LE==N); yes(LE.AskInvite("Alice")); eq(#opened,0)
    drain(); eq(#opened,1)
    eq(opened[1].text,"/w Alice Hi! Could you invite me to your layer please? I'll leave right after.")
    eq(opened[1].text,"/w Alice "..ASK); eq(opened[1].frame,DEFAULT_CHAT_FRAME)
    yes(logged("a whisper to Alice is in your chat box - press Enter to send it.")); eq(forbidden,0)
    -- case-insensitive lookup still whispers the listed spelling
    advance(60); yes(LE.AskInvite("alice")); drain(); eq(opened[2].text,"/w Alice "..ASK)
end)
test("ask: ChatFrame_OpenChat route and every print fallback",function()
    local N=loadAddon(); friends(N,{Alice=there(),Bob=there(),Carl=there(),Dora=there(),Erin=there()})
    ChatFrame_OpenChat=function(text,frame) opened[#opened+1]={text=text,frame=frame,legacy=true} end
    yes(LE.AskInvite("Alice")); drain(); eq(#opened,1); yes(opened[1].legacy); eq(opened[1].text,"/w Alice "..ASK)
    -- unusable ChatFrameUtil falls through to the legacy global
    advance(10); ChatFrameUtil=setmetatable({},{__index=function() error("changed") end})
    yes(LE.AskInvite("Bob")); drain(); eq(#opened,2); eq(opened[2].text,"/w Bob "..ASK)
    advance(10); ChatFrameUtil={OpenChat=secret}
    yes(LE.AskInvite("Carl")); drain(); eq(#opened,3)
    -- neither function: the line is printed to copy
    advance(10); ChatFrameUtil=nil; ChatFrame_OpenChat=nil
    yes(LE.AskInvite("Dora")); drain(); eq(#opened,3)
    yes(logged("type or copy this line to ask Dora:")); eq(log[#log],"/w Dora "..ASK)
    -- the open call throws: printed afterwards
    advance(10); ChatFrameUtil={OpenChat=function() error("blocked") end}
    yes(LE.AskInvite("Erin")); drain(); yes(logged("the chat box did not open")); eq(log[#log],"/w Erin "..ASK)
    -- no timer: printed at once
    advance(60); C_Timer=nil; chatBox()
    yes(LE.AskInvite("Alice")); eq(#opened,3); eq(log[#log],"/w Alice "..ASK); eq(forbidden,0)
end)
test("ask: 60 s per name and one ask per 10 s overall",function()
    local N=loadAddon(); friends(N,{Alice=there(),Bob=there(),Carl=there()}); chatBox()
    yes(LE.AskInvite("Alice")); drain(); eq(#opened,1)
    no(LE.AskInvite("Alice")); yes(logged("Alice was asked 0 s ago; wait 60 s."))
    no(LE.AskInvite("Bob")); yes(logged("one ask every 10 s; wait 10 s."))
    advance(9.5); no(LE.AskInvite("Bob")); drain(); eq(#opened,1)
    advance(.5); yes(LE.AskInvite("Bob")); drain(); eq(#opened,2)
    advance(49.5); no(LE.AskInvite("Alice")); yes(logged("Alice was asked 59 s ago; wait 1 s."))
    advance(.5); yes(LE.AskInvite("Alice")); drain(); eq(#opened,3)
    no(LE.AskInvite("Bob")); yes(logged("Bob was asked 50 s ago; wait 10 s."))
    no(LE.AskInvite("Carl")); eq(lines("one ask every 10 s"),3)
    advance(10); yes(LE.AskInvite("Carl")); drain(); eq(#opened,4)
    -- a refused ask reserves nothing, and expired names are dropped
    eq(N.Safe.count(N.Main.invite.asked),2); eq(N.Main.invite.asked.bob,nil); eq(forbidden,0)
end)
test("ask: only listed, readable, ungrouped targets",function()
    local N=loadAddon(); friends(N,{Alice=there(),Same=there({key="7086"}),Away=there({zone="200"})}); chatBox()
    for _,bad in ipairs({"Nobody","Same","Away","Me","","Alice Smith","Alice|r","Alice\n/g hi","/g hi",42,{},true}) do no(LE.AskInvite(bad)) end
    no(LE.AskInvite(secret)); no(LE.AskInvite(nil)); yes(logged("that player name is not readable."))
    grouped=true; no(LE.AskInvite("Alice")); yes(logged("leave your current group first"))
    IsInGroup=function() return secret end; yes(LE.AskInvite("Alice"))
    drain(); eq(#opened,1); eq(N.Safe.count(N.Main.invite.asked),1); no(N.Main.error); eq(forbidden,0)
end)
test("/le hosts numbers the candidates and /le ask <n> asks one",function()
    local N=loadAddon(); warSettings()
    friends(N,{Alice=there({at=wall-90}),Bob=there({host=true,at=wall-200})},{Cora=page({layer="9000-2",at=wall-30})})
    chatBox()
    SlashCmdList.LAYERENEMIES("ask 1"); yes(logged("run /le hosts first")); eq(#opened,0)
    advance(1); report(1,9,"Scout")
    SlashCmdList.LAYERENEMIES("hosts")
    yes(logged("1. Scout | layer unknown - saw reported enemies | War Effort | 0 s ago"))
    yes(logged("2. Bob | layer 8000 | Bulo | host | 3 min ago"))
    yes(logged("3. Cora | layer 9000 | LayerSwap | 31 s ago"))
    yes(logged("4. Alice | layer 8000 | Bulo | 1 min ago"))
    yes(logged("Bulo: 2 fresh in this zone / LayerSwap: 1 fresh in this zone / War Effort reporters: 1 on another zoneUID"))
    SlashCmdList.LAYERENEMIES("ask 9"); yes(logged("no such number")); SlashCmdList.LAYERENEMIES("ask"); SlashCmdList.LAYERENEMIES("ask x")
    drain(); eq(#opened,0)
    SlashCmdList.LAYERENEMIES(" ASK 2 "); drain(); eq(#opened,1); eq(opened[1].text,"/w Bob "..ASK)
    advance(10); SlashCmdList.LAYERENEMIES("ask 1"); drain(); eq(opened[2].text,"/w Scout "..ASK)
    advance(121); SlashCmdList.LAYERENEMIES("ask 3"); drain(); eq(#opened,2); eq(lines("run /le hosts first"),2)
    no(N.Main.error); eq(forbidden,0)
end)
test("after join: confirmed layer change is announced once (Bulo)",function()
    local N=loadAddon(); local b=friends(N,{Alice=there({host=true})}); chatBox()
    yes(LE.AskInvite("Alice")); drain()
    deliver("GROUP_ROSTER_UPDATE"); eq(N.Main.invite.watch,nil)       -- not grouped yet
    advance(20); grouped=true; deliver("GROUP_ROSTER_UPDATE")
    yes(logged("you joined a group after asking - checking your layer for 60 s.")); yes(N.Main.invite.watch)
    advance(5); no(logged("Moved to layer"))
    b.current="8000-7"; b:Fire("LFS_LAYER",b.current); drain()
    yes(logged("LayerEnemies: Moved to layer 8000 - safe to leave the group.")); eq(N.Main.invite.watch,nil)
    advance(120); deliver("GROUP_ROSTER_UPDATE")
    eq(lines("Moved to layer"),1); eq(lines("Still on your layer"),0); no(logged("was listed on layer"))
    yes(grouped); eq(forbidden,0); no(N.Main.error)
end)
test("after join: change confirmed by two NPC kinds; other layer than listed is said",function()
    local N=loadAddon(); establish(N); LayerSwapDB={book={Alice=page({host=true})}}; chatBox()
    yes(LE.AskInvite("Alice")); drain(); grouped=true; deliver("GROUP_ROSTER_UPDATE"); yes(N.Main.invite.watch)
    deliver("SHARD_TRANSFER"); drain(); eq(N.Main.store.bulo,nil)
    units.target={guid=npc(3,9,"9000"),player=false}; advance(1); deliver("PLAYER_TARGET_CHANGED"); drain()
    no(logged("Moved to layer"))                                      -- one NPC is not confirmation
    units.mouseover={guid=npc(4,9,"9000"),player=false}; advance(1); deliver("UPDATE_MOUSEOVER_UNIT"); drain(); advance(.1)
    eq(N.Main.store.bulo,"9000-9")
    yes(logged("LayerEnemies: Moved to layer 9000 - safe to leave the group."))
    yes(logged("LayerEnemies: Alice was listed on layer 8000, not 9000.")); eq(forbidden,0)
end)
test("after join: unchanged after 60 s says so once; nothing is left for the user",function()
    local N=loadAddon(); friends(N,{Alice=there()}); chatBox()
    yes(LE.AskInvite("Alice")); drain(); advance(3); grouped=true; deliver("GROUP_ROSTER_UPDATE")
    advance(59); eq(lines("Still on your layer"),0)
    advance(2); yes(logged("LayerEnemies: Still on your layer - leave, wait a minute, try again."))
    advance(300); deliver("GROUP_ROSTER_UPDATE"); eq(lines("Still on your layer"),1); eq(lines("Moved to layer"),0)
    yes(grouped); eq(forbidden,0); eq(N.Main.invite.watch,nil)
    -- same key with another zone suffix is still the same layer
    N=loadAddon(); local b=friends(N,{Alice=there()}); yes(LE.AskInvite("Alice")); grouped=true; deliver("GROUP_ROSTER_UPDATE")
    b.current="7086-55"; b:Fire("LFS_RAW",b.current); drain(); advance(61)
    eq(lines("Moved to layer"),0); eq(lines("Still on your layer"),1)
end)
test("after join: no ask, late join, unknown layer and zone change",function()
    local N=loadAddon(); friends(N,{Alice=there()}); chatBox()
    grouped=true; deliver("GROUP_ROSTER_UPDATE"); advance(70); eq(N.Main.invite.watch,nil); eq(lines("Still on your layer"),0)
    grouped=false; deliver("GROUP_ROSTER_UPDATE")
    yes(LE.AskInvite("Alice")); advance(301); grouped=true; deliver("GROUP_ROSTER_UPDATE")
    eq(N.Main.invite.watch,nil); eq(N.Main.invite.pending,nil); advance(70); eq(lines("Still on your layer"),0)
    -- layer never confirmed again: one hint, then the check ends without a claim
    N=loadAddon(); establish(N); LayerSwapDB={book={Alice=page()}}
    yes(LE.AskInvite("Alice")); grouped=true; deliver("GROUP_ROSTER_UPDATE"); deliver("SHARD_TRANSFER"); drain()
    advance(61); eq(lines("Layer not confirmed yet - target or mouse over two different NPCs."),1)
    advance(60); eq(lines("Layer not confirmed yet"),1); advance(65); eq(lines("Layer check ended - your layer could not be confirmed."),1)
    eq(lines("Moved to layer"),0); eq(lines("Still on your layer"),0); eq(N.Main.invite.watch,nil)
    -- zone change cancels
    N=loadAddon(); friends(N,{Alice=there()}); yes(LE.AskInvite("Alice")); grouped=true; deliver("GROUP_ROSTER_UPDATE")
    map=200; deliver("ZONE_CHANGED_NEW_AREA"); drain(); advance(61)
    eq(lines("Zone changed - layer check cancelled."),1); eq(lines("Moved to layer"),0); eq(lines("Still on your layer"),0); eq(forbidden,0)
end)
test("ask from a War Effort report: reporter is the target, own layer unknown",function()
    local N=loadAddon(); warSettings(); chatBox(); advance(1)
    report(1,9,"Scout-TestRealm")
    local list=N.Main.candidates(); eq(names(list),"Scout-TestRealm"); yes(list[1].reporter)
    yes(LE.AskInvite("Scout-TestRealm")); drain(); eq(opened[1].text,"/w Scout-TestRealm "..ASK)
    grouped=true; deliver("GROUP_ROSTER_UPDATE"); yes(N.Main.invite.watch)
    units.target={guid=npc(1,9,"8000"),player=false}; advance(1); deliver("PLAYER_TARGET_CHANGED"); drain()
    units.mouseover={guid=npc(2,9,"8000"),player=false}; advance(1); deliver("UPDATE_MOUSEOVER_UNIT"); drain(); advance(.1)
    yes(logged("Now on layer 8000 - your earlier layer was not known, so a move is not confirmed."))
    eq(lines("Moved to layer"),0); eq(forbidden,0)
    -- an ignored reporter is never offered
    N=loadAddon(); warSettings(); WarEffortScoutDB.ignored.scout="Scout"; advance(1); report(1,9,"Scout-TestRealm")
    eq(#N.Main.candidates(),0)
end)
test("addon never sends, invites, accepts or leaves (source and runtime)",function()
    local N=loadAddon(); warSettings(); local b=friends(N,{Alice=there(),Bob=there({key="9000"})},{Cora=page()}); chatBox()
    advance(1); report(1,9,"Scout")
    SlashCmdList.LAYERENEMIES("hosts"); SlashCmdList.LAYERENEMIES("ask 1"); drain()
    advance(10); LE.AskInvite("Alice"); drain(); grouped=true; deliver("GROUP_ROSTER_UPDATE")
    b.current="8000-7"; b:Fire("LFS_LAYER",b.current); drain(); advance(70)
    grouped=false; deliver("GROUP_ROSTER_UPDATE"); advance(10); LE.AskInvite("Bob"); drain()
    grouped=true; deliver("GROUP_ROSTER_UPDATE"); advance(70)
    eq(forbidden,0); eq(#opened,3); yes(grouped); no(N.Main.error)
    for _,file in ipairs({"Safe","Hash","Layer","Protocol","Store","Reports","Adapters","Invite","Main"}) do
        local f=assert(io.open("LayerEnemies/"..file..".lua")); local text=f:read("*a"); f:close()
        for _,word in ipairs({"SendChatMessage","SendAddonMessage","InviteUnit","LeaveParty","AcceptGroup","C_PartyInfo","RunMacroText","SetText","JoinChannel"}) do
            eq(text:find(word,1,true),nil,file.." mentions "..word)
        end
    end
    -- the only registered events are passive
    for event in pairs(frames[1].events) do no(event:find("PARTY_INVITE",1,true)) end
    yes(frames[1].events.GROUP_ROSTER_UPDATE); eq(frames[1].scripts.OnUpdate,nil); eq(#frames,1)
    eq(LayerEnemiesDB.asked,nil); eq(LayerEnemiesDB.invite,nil)
end)
print(string.format("RESULT: %d tests passed, %d failed, %d assertions",passed,failed,checks))
if failed>0 then os.exit(1) end
