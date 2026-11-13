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
local sent,sendResult
-- The two routes the addon may send on (Wire.lua); anything else counts as forbidden.
local ROUTES={LayerSwap={WHISPER=true},LEGW1={GUILD=true}}
-- Prefixes the addon may register. ZRAD1 stays until Task 3 removes the legacy decoder.
local PREFIXES={WEFF1=true,HeadHunter=true,LayerSwap=true,LFSw=true,LEGW1=true,ZRAD1=true}
local methods={}
function methods:Hide() local old=self.shown; self.shown=false; if old and self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:Show() local old=self.shown; self.shown=true; if not old and self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods:IsShown() return self.shown end
function methods:SetShown(v) if v then self:Show() else self:Hide() end end
function methods:SetSize(w,h) self.width,self.height=w,h end
function methods:SetWidth(w) self.width=w end
function methods:SetHeight(h) self.height=h end
function methods:SetPoint(...) self.point={...} end
function methods:GetPoint() local p=self.point or {}; return p[1],p[2],p[3],p[4],p[5] end
function methods:ClearAllPoints() self.point=nil end
function methods:SetAllPoints() end
function methods:SetColorTexture(...) self.color={...} end
function methods:SetFont(...) self.font={...} end
function methods:SetJustifyH() end
function methods:SetJustifyV() end
function methods:SetTextColor(...) self.textColor={...} end
function methods:SetText(text) self.text=text end
function methods:GetText() return self.text or "" end
function methods:SetFrameStrata() end
function methods:SetMovable() end
function methods:SetClampedToScreen() end
function methods:EnableMouse() end
function methods:EnableMouseWheel() end
function methods:RegisterForDrag() end
function methods:StartMoving() self.moving=true end
function methods:StopMovingOrSizing() self.moving=false end
function methods:SetAutoFocus() end
function methods:SetMaxLetters() end
function methods:ClearFocus() self.focused=false end
function methods:Disable() self.disabled=true end
function methods:Enable() self.disabled=false end
function methods:Click() if not self.disabled and self.scripts.OnClick then self.scripts.OnClick(self) end end
local function object(kind)
    return setmetatable({kind=kind,shown=true,disabled=false,events={},scripts={}}, {__index=function(_,key) if methods[key] then return methods[key] end; error("unknown frame method: "..key) end})
end
function methods:CreateTexture() return object("Texture") end
function methods:CreateFontString() return object("FontString") end
function methods:RegisterEvent(event) self.events[event]=true end
function methods:SetScript(key,fn)
    local allowed={OnEvent=true,OnUpdate=true,OnClick=true,OnDragStart=true,OnDragStop=true,OnMouseWheel=true,OnEnterPressed=true,OnEscapePressed=true,OnShow=true,OnHide=true}
    if not allowed[key] then error("unknown script: "..key) end
    self.scripts[key]=fn
end
function CreateFrame(kind)
    yes(kind=="Frame" or kind=="Button" or kind=="EditBox","supported frame type")
    local f=object(kind)
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
    sent,sendResult={},0
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
    _G.C_ChatInfo=setmetatable({
        RegisterAddonMessagePrefix=function(prefix)
            if not PREFIXES[prefix] then forbidden=forbidden+1 end
            return true
        end,
        -- records every call; a route outside the allowlist counts as forbidden
        SendAddonMessage=function(prefix,text,kind,target)
            sent[#sent+1]={prefix=prefix,text=text,kind=kind,target=target}
            if not (ROUTES[prefix] and ROUTES[prefix][kind]) then forbidden=forbidden+1 end
            -- the caller: the first Lua frame above this one (C frames such as pcall are skipped) must be Wire.lua
            local level,caller=2,nil
            while true do
                local info=debug.getinfo(level,"S")
                if not info then break end
                if info.what~="C" then caller=info.source; break end
                level=level+1
            end
            if caller~="@LayerEnemies/Wire.lua" then forbidden=forbidden+1 end
            if type(sendResult)=="function" then return sendResult() end
            return sendResult
        end},
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
    for _,file in ipairs({"Safe","Hash","Layer","Wire","Protocol","Store","Reports","Adapters","Invite","Find","UI","Main"}) do
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
    eq(#frames,11); no(frames[1]:IsShown()); eq(frames[1].scripts.OnUpdate,nil)
    local f=CreateFrame("Frame"); yes(f:IsShown()); no(pcall(function() f:InventedMethod() end))
    eq(N.Main.statusBulo,"not installed"); eq(N.Main.statusWE,"not installed")
end)
test("neither source: own observation works after local NPC confirmation",function()
    local N=loadAddon(); establish(N)
    units.target=player("Enemy","Horde"); advance(1); deliver("PLAYER_TARGET_CHANGED"); drain()
    local rows=N.Store.rows(N.Main.store,clock,"local")
    eq(#rows,1); eq(rows[1].name,"Enemy"); eq(rows[1].confidence,"seen by you"); eq(rows[1].x,.25)
    SlashCmdList.LAYERENEMIES("list"); yes(table.concat(log,"\n"):find("Enemy",1,true)); no(N.Main.error)
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
    SlashCmdList.LAYERENEMIES("list"); yes(table.concat(log,"\n"):find("Unknown",1,true))
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
    eq(#frames,11)
end)
test("SavedVariables contain options only; no sightings survive reload",function()
    local N=loadAddon(); establish(N)
    units.target=player("PrivateName","Horde"); advance(1); deliver("PLAYER_TARGET_CHANGED"); drain()
    eq(LayerEnemiesDB.sightings,nil); eq(LayerEnemiesDB.localSeen,nil); yes(LayerEnemiesDB.options)
    N.Main.start(); eq(#frames,11)
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
    SlashCmdList.LAYERENEMIES("list")
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
        ["Bad  Name"]=there(), ["Bad|Name"]=there(), ["Bad\nName"]=there(), ["/g"]=there(), Digit7=there(), X=there(),
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
        ["Bad  Name"]=page(), ["Bad|Name"]=page(),
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
test("addon never chats, invites, accepts, leaves or joins; sends only through Wire",function()
    local N=loadAddon(); warSettings(); local b=friends(N,{Alice=there(),Bob=there({key="9000"})},{Cora=page()}); chatBox()
    advance(1); report(1,9,"Scout")
    SlashCmdList.LAYERENEMIES("hosts"); SlashCmdList.LAYERENEMIES("ask 1"); drain()
    advance(10); LE.AskInvite("Alice"); drain(); grouped=true; deliver("GROUP_ROSTER_UPDATE")
    b.current="8000-7"; b:Fire("LFS_LAYER",b.current); drain(); advance(70)
    grouped=false; deliver("GROUP_ROSTER_UPDATE"); advance(10); LE.AskInvite("Bob"); drain()
    grouped=true; deliver("GROUP_ROSTER_UPDATE"); advance(70)
    eq(forbidden,0); eq(#opened,3); yes(grouped); no(N.Main.error)
    for _,file in ipairs({"Safe","Hash","Layer","Wire","Protocol","Store","Reports","Adapters","Invite","Find","UI","Main"}) do
        local f=assert(io.open("LayerEnemies/"..file..".lua")); local text=f:read("*a"); f:close()
        for _,word in ipairs({"SendChatMessage","InviteUnit","LeaveParty","AcceptGroup","C_PartyInfo","RunMacroText","JoinChannel"}) do
            eq(text:find(word,1,true),nil,file.." mentions "..word)
        end
        -- SendAddonMessage only in Wire.lua
        if file=="Wire" then yes(text:find("SendAddonMessage",1,true),"Wire sends")
        else eq(text:find("SendAddonMessage",1,true),nil,file.." mentions SendAddonMessage") end
    end
    eq(#sent,0)
    -- the only registered events are passive
    for event in pairs(frames[1].events) do no(event:find("PARTY_INVITE",1,true)) end
    yes(frames[1].events.GROUP_ROSTER_UPDATE); eq(frames[1].scripts.OnUpdate,nil); eq(#frames,11)
    eq(LayerEnemiesDB.asked,nil); eq(LayerEnemiesDB.invite,nil)
end)
test("Find hashes mirror upstream realm, realm-less and Forever surname keys",function()
    local N=loadAddon(); local H=N.Hash
    eq(H.nameKey("Alice","Test Realm"),"alice-testrealm"); eq(H.nameKey("Alice",""),"alice-")
    eq(H.hash3("alice-testrealm"),"Zzm"); eq(H.hash3("alice-"),"YNz")
    local hashes=N.Find.hashes("Alice", "Test Realm")
    yes(hashes[H.player("Alice","Test Realm")]); yes(hashes[H.player("Alice","")])
    hashes=N.Find.hashes("First Surname", "Forever")
    yes(hashes[H.player("First","Surname")]); yes(hashes[H.player("First Surname","")])
end)
test("Find match, no match, collisions, expiry, own sighting and alerts",function()
    local N=loadAddon(); local F=N.Find; local st=F.new({"Alice","Bob"})
    local function feed(hash,at,zone) F.report(st,{sender="Scout",zone=zone or 100,at=at,enemies={{hash=hash,class="MAGE",level=40}}},"Test Realm") end
    feed("xxx",10); no(F.rows(st,10,100)[1].at)
    feed(N.Hash.player("Alice",""),11)
    local r=F.rows(st,11,100)[1]; yes(r.possible); yes(r.canAsk); eq(r.spotter,"Scout"); eq(r.class,"MAGE"); eq(r.level,40)
    yes(F.alert(st,r,11)); no(F.alert(st,r,310)); yes(F.alert(st,r,311))
    feed(N.Hash.player("Alice",""),312,200); r=F.rows(st,312,100)[1]; yes(r.travel); no(r.canAsk); yes(F.alert(st,r,312))
    no(F.rows(st,912,100)[1].at)
    F.own(st,{name="Alice",faction="same",source="own target"},100,913); no(st.locations.Alice)
    F.own(st,{name="Alice",faction="opposite",source="own target"},100,913)
    r=F.rows(st,913,100)[1]; yes(r.own); yes(r.same); no(r.canAsk)
    F.boundary(st); no(st.locations.Alice); eq(#st.names,2)
    -- A genuine three-character collision must remain possible, never confirmed.
    local a,b="PFKMEclrzj","CuhFVPbgzA"
    eq(N.Hash.player(a,""),"Y8Y"); eq(N.Hash.player(b,""),"Y8Y")
    st=F.new({a,b})
    feed(N.Hash.player(a,""),1000)
    local rows=F.rows(st,1000,100); yes(rows[1].possible); yes(rows[2].possible)
end)
test("Find integration: cross-zone privacy gate, same layer and persistence",function()
    local N=loadAddon(); warSettings(); establish(N); chatBox()
    SlashCmdList.LAYERENEMIES("find Alice")
    local hash=N.Hash.player("Alice","")
    advance(1)
    local stamp=math.floor(server)%3600
    deliver("CHAT_MSG_ADDON","WEFF1","C|61|200|0|0|9|1|"..stamp,"GUILD","Scout")
    deliver("CHAT_MSG_ADDON","WEFF1","E|61|1|1|"..hash..":M:40|"..stamp,"GUILD","Scout")
    local row=N.Main.findRows()[1]; yes(row.possible); yes(row.travel)
    no(LE.AskInvite("Scout")); yes(logged("travel to zone 200 first")); eq(#opened,0)
    WarEffortScoutDB.silent=true
    deliver("CHAT_MSG_ADDON","WEFF1","C|62|100|0|0|9|1|"..stamp,"GUILD","Scout")
    deliver("CHAT_MSG_ADDON","WEFF1","E|62|1|1|"..hash..":M:40|"..stamp,"GUILD","Scout")
    eq(N.Main.findRows()[1].zone,200)
    WarEffortScoutDB.silent=false
    advance(1); stamp=math.floor(server)%3600
    deliver("CHAT_MSG_ADDON","WEFF1","C|63|100|0|0|9|1|"..stamp,"GUILD","Scout")
    deliver("CHAT_MSG_ADDON","WEFF1","E|63|1|1|"..hash..":M:40|"..stamp,"GUILD","Scout")
    yes(N.Main.findRows()[1].canAsk); yes(LE.AskInvite("Scout")); drain(); eq(#opened,1)
    friends(N,{Scout=there({key="7086"})})
    yes(N.Main.findRows()[1].same); no(N.Main.findRows()[1].canAsk)
    local saved=LayerEnemiesDB
    N.Main.started=false; N.Main.start(); eq(N.Main.find.names[1],"Alice"); no(N.Main.find.locations.Alice)
    eq(saved.tracked[1],"Alice"); eq(LayerEnemiesDB.sightings,nil)
    SlashCmdList.LAYERENEMIES("find"); eq(#LayerEnemiesDB.tracked,0)
end)
test("Find cap, validation, remove, alert sound and own name with surname",function()
    local N=loadAddon(); local F=N.Find; local st=F.new({"Alice","Alice","Bob"})
    eq(#st.names,2)
    for _,name in ipairs({"Cora","Dave","Ellie"}) do yes(F.add(st,name)) end
    no(F.add(st,"Frank")); no(F.add(st,secret)); no(F.add(st,"Alice|r")); no(F.add(st,"/g inject"))
    F.remove(st,"Bob"); yes(F.add(st,"First Surname"))
    local sounds=0; PlaySound=function() sounds=sounds+1 end
    N.Main.track("First Surname"); advance(1)
    units.target=player("First","Horde"); units.target.realm="Surname"
    deliver("PLAYER_TARGET_CHANGED"); drain()
    yes(N.Main.findRows()[1].own); eq(sounds,1); N.Main.findAlerts(); eq(sounds,1)
    advance(300); N.Main.findAlerts(); eq(sounds,2); PlaySound=nil
end)
test("UI starts hidden, toggles with /le, paints ages only while shown",function()
    local N=loadAddon(); local U=N.UI
    no(U.frame:IsShown()); eq(#U.pool,0)
    for _,f in ipairs(frames) do eq(f.scripts.OnUpdate,nil) end
    advance(20); eq(U.lastPaint,nil); eq(#U.pool,0)
    SlashCmdList.LAYERENEMIES(""); yes(U.frame:IsShown()); eq(U.lastPaint,clock); no(N.Main.error)
    local last=U.lastPaint
    advance(.5); eq(U.lastPaint,last); advance(.5); eq(U.lastPaint,clock)
    SlashCmdList.LAYERENEMIES(""); no(U.frame:IsShown()); last=U.lastPaint
    advance(10); eq(U.lastPaint,last)
    SlashCmdList.LAYERENEMIES("list"); no(U.frame:IsShown()); yes(logged("Only players seen"))
end)
test("UI tabs, scrolling and row pooling never allocate on repeat refresh",function()
    local N=loadAddon(); establish(N); local U=N.UI
    advance(1)
    for i=1,20 do
        N.Store.observe(N.Main.store,{key="Player-1-"..i,name="Enemy",class="MAGE",level=i,at=clock,faction="opposite",source="own target"},clock)
    end
    U.toggle(); eq(#U.pool,6); eq(U.tabs["local"].label.text,"Seen by you (20)")
    local first=U.pool[1]; local count=#frames
    for _=1,20 do U.render() end
    eq(#frames,count); eq(U.pool[1],first)
    U.body.scripts.OnMouseWheel(U.body,-1); eq(U.offset,1)
    U.tabs.reported:Click(); eq(U.tab,"reported"); eq(U.offset,0); yes(U.banner.text:find("not confirmed",1,true)); no(first:IsShown())
    U.tabs.friendly:Click(); eq(U.tab,"friendly")
    U.tabs.find:Click(); eq(U.tab,"find"); yes(U.input:IsShown()); yes(U.add:IsShown())
    U.tabs["local"]:Click(); no(U.input:IsShown()); eq(U.pool[1],first); eq(#frames,count)
end)
test("UI Friendly and Reported buttons dispatch AskInvite and show real cooldown",function()
    local N=loadAddon(); warSettings(); chatBox(); friends(N,{Alice=there()})
    local U=N.UI; U.toggle(); U.select("friendly")
    eq(U.pool[1].title.text,"Alice")
    local original=N.AskInvite; local calls={}
    N.AskInvite=function(name) calls[#calls+1]=name; return original(name) end
    U.pool[1].ask:Click(); drain(); eq(calls[1],"Alice"); eq(#opened,1)
    eq(U.pool[1].ask.label.text,"Asked · 60s"); yes(U.pool[1].ask.disabled)
    U.pool[1].ask:Click(); eq(#calls,1)
    advance(1); eq(U.pool[1].ask.label.text,"Asked · 59s")
    advance(60); no(U.pool[1].ask.disabled)
    report(1,9,"Scout"); U.select("reported"); yes(U.pool[1].ask:IsShown())
    U.pool[1].ask:Click(); drain(); eq(calls[2],"Scout"); eq(#opened,2)
    eq(U.pool[1].ask.label.text,"Asked · 60s"); eq(forbidden,0)
end)
test("UI Find add, status, clear and invite use existing flow",function()
    local N=loadAddon(); chatBox(); local U=N.UI
    U.toggle(); U.tabs.find:Click(); U.input:SetText("Alice"); U.add:Click()
    eq(LayerEnemiesDB.tracked[1],"Alice"); eq(U.input:GetText(),""); eq(U.pool[1].title.text,"Alice")
    yes(U.pool[1].sub.text:find("Not located",1,true)); no(U.pool[1].ask:IsShown())
    N.Find.report(N.Main.find,{sender="Scout",zone=100,at=clock,enemies={{hash=N.Hash.player("Alice",""),class="MAGE",level=40}}},"Test Realm")
    U.render(); yes(U.pool[1].sub.text:find("possible match",1,true)); yes(U.pool[1].ask:IsShown())
    U.pool[1].ask:Click(); drain(); eq(#opened,1); eq(opened[1].text,"/w Scout "..ASK)
    U.pool[1].clear:Click(); eq(#LayerEnemiesDB.tracked,0); no(U.pool[1]:IsShown())
    U.input:SetText("Bad|r"); U.add:Click(); eq(#LayerEnemiesDB.tracked,0)
end)
test("UI dragging saves and restores valid per-character position",function()
    local N=loadAddon(); local U=N.UI
    U.frame:SetPoint("TOPLEFT",UIParent,"TOPLEFT",42,-80)
    U.frame.scripts.OnDragStart(); yes(U.frame.moving)
    U.frame.scripts.OnDragStop(); no(U.frame.moving)
    eq(LayerEnemiesDB.position.x,42); eq(LayerEnemiesDB.position.y,-80)
    U.frame=nil; U.create(); eq(U.frame.point[1],"TOPLEFT"); eq(U.frame.point[4],42)
    LayerEnemiesDB.position={point="garbage",relative="CENTER",x=math.huge,y=0}
    U.frame=nil; U.create(); eq(U.frame.point[1],"CENTER"); eq(U.frame.point[4],0)
    eq(U.position(secret),nil); eq(U.position({point=secret}),nil)
    eq(U.position(setmetatable({},{__index=function() error("corrupt") end})),nil)
    local clean=U.position({point="CENTER",relative="CENTER",x=0,y=0,unwanted="private"})
    eq(clean.unwanted,nil); eq(N.Safe.count(clean),4)
end)
test("Forever surname whisper uses native target API, never malformed slash text",function()
    local N=loadAddon(); friends(N,{["First Surname"]=there()})
    local target,inserted
    ChatFrameUtil={SendTell=function(name) target=name end,GetActiveWindow=function() return {Insert=function(_,text) inserted=text end} end}
    yes(LE.AskInvite("First Surname")); drain(); eq(target,"First Surname"); eq(inserted,ASK); eq(#opened,0)
    advance(60); ChatFrameUtil=nil
    yes(LE.AskInvite("First Surname")); drain(); yes(logged("open a whisper to First Surname manually")); no(logged("/w First Surname")); eq(forbidden,0)
end)
-- Wire.lua: the only sender
test("the send mock counts any caller but Wire.lua as forbidden",function()
    local N=loadAddon()
    -- a direct call, a pcall-wrapped call and a dynamically named call from outside Wire.lua all count
    C_ChatInfo.SendAddonMessage("LayerSwap","x","WHISPER","Alice"); eq(forbidden,1)
    pcall(function() C_ChatInfo["Send".."AddonMessage"]("LayerSwap","x","WHISPER","Alice") end); eq(forbidden,2)
    pcall(C_ChatInfo.SendAddonMessage,"LEGW1","x","GUILD"); eq(forbidden,3)
    -- the same routes through Wire.lua do not
    forbidden=0; yes(N.Wire.send("LayerSwap","x","WHISPER","Alice")); yes(N.Wire.send("LEGW1","x","GUILD")); eq(forbidden,0); eq(#sent,5)
end)
test("wire routes cannot be opened from outside",function()
    local N=loadAddon(); local Wr=N.Wire
    if type(Wr.ROUTES)=="table" then
        Wr.ROUTES.WEFF1={GUILD=true}; if type(Wr.ROUTES.LayerSwap)=="table" then Wr.ROUTES.LayerSwap.GUILD=true end
        if type(Wr.ROUTES.LEGW1)=="table" then Wr.ROUTES.LEGW1.WHISPER=true end
    end
    Wr.ROUTES={WEFF1={GUILD=true},LayerSwap={GUILD=true,CHANNEL=true}}
    for _,c in ipairs({{"WEFF1","x","GUILD"},{"LayerSwap","x","GUILD"},{"LEGW1","x","WHISPER","Bob"}}) do
        local ok,why=Wr.send(c[1],c[2],c[3],c[4]); no(ok); eq(why,"blocked route")
    end
    eq(#sent,0); yes(Wr.send("LayerSwap","x","WHISPER","Alice")); eq(#sent,1)
end)
test("wire sends only on the two allowed routes",function()
    local N=loadAddon(); local Wr=N.Wire
    local function blocked(...) local ok,why=Wr.send(...); no(ok); eq(why,"blocked route") end
    blocked("WEFF1","x","GUILD"); blocked("LayerSwap","x","GUILD"); blocked("LEGW1","x","WHISPER","Bob")
    blocked("LayerSwap","x","CHANNEL","5"); blocked("HeadHunter","x","WHISPER","Bob"); blocked("LFSw","x","GUILD")
    eq(#sent,0)
    eq(Wr.ROUTES.LayerSwap.WHISPER,true); eq(Wr.ROUTES.LEGW1.GUILD,true)
    local ok,why=Wr.send("LayerSwap","inv layer <LS 1429 want 7086-0 48.2,42.5>","WHISPER","Alice"); yes(ok); eq(why,"sent")
    ok,why=Wr.send("LEGW1","R|1","GUILD"); yes(ok); eq(why,"sent")
    eq(#sent,2); eq(sent[1].prefix,"LayerSwap"); eq(sent[1].kind,"WHISPER"); eq(sent[1].target,"Alice")
    eq(sent[2].prefix,"LEGW1"); eq(sent[2].kind,"GUILD"); eq(sent[2].target,nil); eq(forbidden,0)
end)
test("wire rejects oversize and secret text",function()
    local N=loadAddon(); local Wr=N.Wire
    local function bad(...) local ok,why=Wr.send(...); no(ok); eq(why,"bad text") end
    bad("LEGW1",string.rep("a",256),"GUILD"); bad("LEGW1","","GUILD"); bad("LEGW1",secret,"GUILD"); bad("LEGW1",42,"GUILD")
    bad("LayerSwap","x","WHISPER",secret); bad("LayerSwap","x","WHISPER","B"); bad("LayerSwap","x","WHISPER",nil)
    bad("LayerSwap","x","WHISPER","Bad|Name")
    local ok,why=Wr.send(secret,"x","GUILD"); no(ok); eq(why,"bad text")
    ok,why=Wr.send("LEGW1","x",secret); no(ok); eq(why,"bad text")
    eq(#sent,0)
    ok=Wr.send("LEGW1",string.rep("a",255),"GUILD"); yes(ok); eq(#sent,1)
    ok=Wr.send("LayerSwap","x","WHISPER","First Surname"); yes(ok); eq(#sent,2)
end)
test("wire maps client results",function()
    local N=loadAddon(); local Wr=N.Wire
    local function try(r,want) sendResult=r; local ok,why=Wr.send("LayerSwap","x","WHISPER","Alice"); eq(why,want); eq(ok,want=="sent") end
    try(0,"sent"); try(3,"throttled"); try(8,"refused"); try(1,"refused")
    try(function() error("boom") end,"error")
    eq(#sent,5); no(N.Main.error); eq(forbidden,0)
    C_ChatInfo=nil; local ok,why=Wr.send("LayerSwap","x","WHISPER","Alice"); no(ok); eq(why,"error")
end)
test("wire guild bucket",function()
    local N=loadAddon(); local Wr=N.Wire
    local got={}
    for i=1,6 do local ok,why=Wr.send("LEGW1","m"..i,"GUILD"); got[#got+1]=why end
    eq(table.concat(got,","),"sent,sent,sent,sent,sent,throttled"); eq(#sent,5)
    advance(1); local ok,why=Wr.send("LEGW1","m7","GUILD"); no(ok); eq(why,"throttled"); eq(#sent,5)
    advance(1); ok,why=Wr.send("LEGW1","m8","GUILD"); yes(ok); eq(why,"sent"); eq(#sent,6)
    -- the whisper route has no bucket
    for i=1,8 do yes((Wr.send("LayerSwap","x","WHISPER","Alice"))) end
    eq(#sent,14)
    -- refill caps at 5
    advance(100); for i=1,6 do Wr.send("LEGW1","r"..i,"GUILD") end; eq(#sent,19)
end)
print(string.format("RESULT: %d tests passed, %d failed, %d assertions",passed,failed,checks))
if failed>0 then os.exit(1) end
