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
-- letters-only suffix for generated player names (names never carry digits; 1.0 T2 name rule)
local function abc(i) local s=""; repeat local r=(i-1)%26; s=string.char(97+r)..s; i=math.floor((i-1)/26) until i==0; return s end
local secret=setmetatable({}, {__tostring=function() error("secret stringify") end,__concat=function() error("secret concatenate") end,__lt=function() error("secret compare") end,__index=function() error("secret index") end})
function issecretvalue(v) return rawequal(v,secret) end
local frames,timers,log,units,loaded,metadata
local clock,map,server,channels,inGuild,clientIgnored,inInstance
local guildName="Test Guild"
local wall,grouped,opened
local sent,sendResult
local roster,rosterCalls,combat,raid,leader,invites,accepts,leaves,popupHidden,popup
-- 1.0 T3: chat channels (display list, members), joins, leaves and roster selections; channel calls only from Directory.lua
local joined,leftCh,selected,chanList,chanMembers,joinNotice,joinReturn
-- The routes the addon may send on (Wire.lua); anything else counts as forbidden. LFSw/GUILD carries only "Q".
-- the routes the mock accepts without counting a forbidden send; WEFF1 and HeadHunter are open from 1.0 T1 (behind
-- Net: ship constant, switch, consent, stand-down)
local ROUTES={LayerSwap={WHISPER=true},LEGW1={GUILD=true},LFSw={GUILD=true},
    WEFF1={GUILD=true,PARTY=true,RAID=true,WHISPER=true},HeadHunter={WHISPER=true}}
-- Prefixes the addon may register.
local PREFIXES={WEFF1=true,HeadHunter=true,LayerSwap=true,LFSw=true,LEGW1=true,["[Spy]"]=true,ForeverSpy1=true,FSENT03=true,GBOUNTY=true,WALLOFSHAME=true,FTold1=true}
-- The addon's source files, in load order, as the TOC lists them.
local function addonFiles()
    local out={}
    for line in io.lines("LayerEnemies/LayerEnemies.toc") do
        local name=line:match("^(%w+)%.lua%s*$")
        if name then out[#out+1]=name end
    end
    assert(#out>0,"no files in the TOC")
    return out
end
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
    local allowed={OnEvent=true,OnUpdate=true,OnClick=true,OnDragStart=true,OnDragStop=true,OnMouseWheel=true,OnEnterPressed=true,OnEscapePressed=true,OnShow=true,OnHide=true,OnEnter=true,OnLeave=true}
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
    clock,map,server,channels,inGuild,clientIgnored,inInstance=10,100,720100,{WarEffortPubA=7},true,false,false; guildName="Test Guild"
    wall,grouped,opened,forbidden=1800000000,false,{},0
    sent,sendResult={},0
    -- guild roster: {name, online}; combat, party and raid state for the guild host
    roster,rosterCalls,combat,raid,leader={},0,false,false,false
    _G.GetNumGuildMembers=function() return #roster end
    _G.GetGuildRosterInfo=function(i) local e=roster[i]; if e then return e[1],nil,nil,nil,nil,nil,nil,nil,e[2] end end
    _G.C_GuildInfo={GuildRoster=function() rosterCalls=rosterCalls+1 end}
    _G.InCombatLockdown=function() return combat end
    _G.UnitAffectingCombat=function(u) return u=="player" and combat or false end
    _G.IsInRaid=function() return raid end
    _G.UnitIsGroupLeader=function(u) if u=="player" then return leader end; return units[u]~=nil and units[u].leader==true end
    _G.GetNumGroupMembers=function() local n=0; for i=1,4 do if units["party"..i] then n=n+1 end end; return n>0 and n+1 or 0 end
    _G.BuloLayerForever=nil; _G.WarEffortScoutDB=nil; _G.LayerEnemiesDB=nil
    _G.LayerSwapDB=nil; _G.LE=nil; _G.ChatFrameUtil=nil; _G.ChatFrame_OpenChat=nil
    _G.time=function() return wall end
    _G.IsInGroup=function() return grouped end
    -- Anything that would act for the user counts as a failure, even under pcall.
    for _,name in ipairs({"SendChatMessage","InviteUnit","LeaveParty","DeclineGroup","RunMacroText"}) do
        _G[name]=function() forbidden=forbidden+1; error("must never call "..name) end
    end
    -- the caller of a party call must be Wire.lua (C frames such as pcall are skipped)
    local function fromWire()
        local level=3
        while true do
            local info=debug.getinfo(level,"S")
            if not info then return false end
            if info.what~="C" then return info.source=="@LayerEnemies/Wire.lua" end
            level=level+1
        end
    end
    -- AcceptGroup (0.4.0 auto-accept): allowed from Wire.lua only; the PARTY_INVITE popup is modelled with Blizzard's
    -- OnHide rule (hiding it without inviteAccepted declines)
    accepts,leaves,popupHidden={},{},0
    popup={which="PARTY_INVITE",shown=false,inviteAccepted=nil}
    _G.AcceptGroup=function() accepts[#accepts+1]=clock; if not fromWire() then forbidden=forbidden+1 end end
    _G.StaticPopup_FindVisible=function(which) if which=="PARTY_INVITE" and popup.shown then return popup end end
    _G.StaticPopup_Hide=function(which)
        if which~="PARTY_INVITE" or not popup.shown then return end
        popup.shown=false; popupHidden=popupHidden+1
        if not popup.inviteAccepted then forbidden=forbidden+1 end   -- Blizzard would call DeclineGroup here
    end
    -- the one allowed party call: C_PartyInfo.InviteUnit, from Wire.lua only (0.4.0 guild host); every other member
    -- counts as forbidden
    invites={}
    _G.C_PartyInfo=setmetatable({LeaveParty=function(category)
            leaves[#leaves+1]=clock; if category~=nil then forbidden=forbidden+1 end
            local level,caller=2,nil
            while true do
                local info=debug.getinfo(level,"S")
                if not info then break end
                if info.what~="C" then caller=info.source; break end
                level=level+1
            end
            if caller~="@LayerEnemies/Wire.lua" then forbidden=forbidden+1 end
            grouped=false
        end,
        InviteUnit=function(name)
            invites[#invites+1]=name
            local level,caller=2,nil
            while true do
                local info=debug.getinfo(level,"S")
                if not info then break end
                if info.what~="C" then caller=info.source; break end
                level=level+1
            end
            if caller~="@LayerEnemies/Wire.lua" then forbidden=forbidden+1 end
        end},
        {__index=function(_,key) forbidden=forbidden+1; error("must never use C_PartyInfo."..tostring(key)) end})
    _G.C_Timer={After=function(delay,fn) timers[#timers+1]={at=clock+delay,fn=fn} end}
    _G.C_Map={
        GetBestMapForUnit=function() return map end,
        GetMapInfo=function(id)
            if id==100 then return {mapType=3,parentMapID=1,name="Ashenvale"} end
            if id==200 then return {mapType=3,parentMapID=1,name="Durotar"} end
            if id==101 then return {mapType=4,parentMapID=100,name="Astranaar"} end
            if id==1 then return {mapType=2,parentMapID=0,name="Kalimdor"} end
        end,
        GetMapChildrenInfo=function(id,kind,all)
            if (id==1 or id==947) and kind==3 then return {{mapID=100,name="Ashenvale",mapType=3},{mapID=200,name="Durotar",mapType=3}} end
            return {}
        end,
        GetPlayerMapPosition=function() return {GetXY=function() return .25,.75 end} end,
    }
    _G.C_AddOns={IsAddOnLoaded=function(name) return loaded[name]==true end,GetAddOnMetadata=function(name,key) return metadata[name] end}
    _G.C_FriendList={IsIgnored=function() return clientIgnored end}
    _G.C_ChatInfo=setmetatable({
        GetChannelRosterInfo=function(index,r) local n=chanList[index]; local m=n and chanMembers[n] and chanMembers[n][r]; if m then return m,false,false,"Player-1-"..r end end,
        RegisterAddonMessagePrefix=function(prefix)
            if not PREFIXES[prefix] then forbidden=forbidden+1 end
            return true
        end,
        -- records every call; a route outside the allowlist counts as forbidden
        SendAddonMessage=function(prefix,text,kind,target)
            sent[#sent+1]={prefix=prefix,text=text,kind=kind,target=target,at=clock}
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
    _G.IsInInstance=function() return inInstance end
    _G.GetGuildInfo=function() if inGuild then return guildName end end
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
    local function fromDirectory()
        local level=3
        while true do
            local info=debug.getinfo(level,"S")
            if not info then return false end
            if info.what~="C" then return info.source=="@LayerEnemies/Directory.lua" end
            level=level+1
        end
    end
    joined,leftCh,selected,chanList,chanMembers,joinNotice,joinReturn={},{},{},{"General"},{},true,nil
    local function notice(what,name) for i,c in ipairs(chanList) do if c==name or what=="YOU_LEFT" then
        deliver("CHAT_MSG_CHANNEL_NOTICE",what,"","",(i..". "..name),"",0,0,i,name); return end end end
    _G.JoinChannelByName=function(name) if not fromDirectory() then forbidden=forbidden+1 end; joined[#joined+1]=name
        local found=false; for _,c in ipairs(chanList) do if c==name then found=true end end; if not found then chanList[#chanList+1]=name end
        if joinNotice then notice("YOU_JOINED",name) end
        if joinReturn~=nil then return joinReturn end
        return 1,name end
    _G.LeaveChannelByName=function(name) if not fromDirectory() then forbidden=forbidden+1 end; leftCh[#leftCh+1]=name
        for i,c in ipairs(chanList) do if c==name then table.remove(chanList,i); break end end; notice("YOU_LEFT",name) end
    _G.SetSelectedDisplayChannel=function(i) if not fromDirectory() then forbidden=forbidden+1 end; selected[#selected+1]=chanList[i] or i end
    _G.GetNumDisplayChannels=function() return #chanList end
    _G.GetChannelDisplayInfo=function(i) local n=chanList[i]; if n then return i..". "..n,false,nil,i,#(chanMembers[n] or {}),true end end
    _G.ChannelFrame=nil
    local N={}
    for _,file in ipairs(addonFiles()) do
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
-- War Effort 1.6.6 vectors (study/wareffort-vectors.json, copied as literals). Server time 720100 -> stamp 100.
local VH="H|1.6.6|100|7086|1|19|0|123|100|456|H|60|1|42|1"
local VC="C|42|100|0.400|0.500|7086|4|100|12||4f4c594d505553:4"
local VE="E|42|1|1|Zzm:H:60,AbC:A:-1,def:?:?,xyz:D:59|100|aaaa"
local SCOUT="53636f7574204f6e65"   -- "Scout One"
local VX="X|"..SCOUT.."|123|C|42|100|0.400|0.500|7086|4|100|12||4f4c594d505553:4"
local VG="G|"..SCOUT.."|123|C|42|100|0.400|0.500|7086|4|100|12||4f4c594d505553:4"
-- Reports.receive over decoded text; zone 100 for maps 100/101, unknown otherwise.
local function reportFixture(N)
    local t,peers=N.Reports.new(),N.Peers.new()
    local function feed(text,sender,at,route,serverNow)
        local msg,why=N.Protocol.decode(text)
        if not msg then return nil,why end
        return N.Reports.receive(t,msg,{sender=sender or "Reporter",route=route or "GUILD",now=at or 200,serverNow=serverNow or 720100,
            zoneFn=function(id) return (id==100 or id==101) and 100 or nil end,peers=peers})
    end
    return t,feed,peers
end

test("strict frames start shown, dispatcher hidden, no UI or OnUpdate",function()
    local N=loadAddon()
    eq(#frames,18); no(frames[1]:IsShown()); eq(frames[1].scripts.OnUpdate,nil) -- 14 from 0.4.0: the Find hosts, Host and Auto buttons; 18 from 1.0: the Share, Guild only and two network switches
    local f=CreateFrame("Frame"); yes(f:IsShown()); no(pcall(function() f:InventedMethod() end))
    eq(N.Main.statusBulo,"not installed"); eq(N.Main.statusWE,"not installed / listening on guild, party and raid (reported, not confirmed)")
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
test("we decodes C/E/H 1.6.6 vectors",function()
    local N=loadAddon(); local P=N.Protocol
    local c=P.decode(VC)
    yes(c); eq(c.type,"C"); eq(c.rid,42); eq(c.map,100); eq(c.x,.4); eq(c.y,.5); eq(c.layer,7086); eq(c.count,4)
    eq(c.stamp,100); eq(c.spread,12); eq(c.sync,false)
    local e=P.decode(VE)
    yes(e); eq(e.type,"E"); eq(e.rid,42); eq(e.part,1); eq(e.total,1); eq(#e.enemies,4); eq(e.stamp,100)
    eq(e.enemies[1].hash,"Zzm"); eq(e.enemies[1].class,"MAGE"); eq(e.enemies[1].level,60)
    eq(e.enemies[2].class,"WARRIOR"); eq(e.enemies[2].level,-1); eq(e.enemies[3].class,nil); eq(e.enemies[3].level,nil)
    eq(e.enemies[4].class,"ROGUE"); eq(e.enemies[4].level,59)
    local h=P.decode(VH)
    yes(h); eq(h.type,"H"); eq(h.version,"1.6.6"); eq(h.layer,7086); eq(h.minor,19); eq(h.stamp,100)
    eq(P.decode("H|1.6.6|100|7086|1").minor,0)                    -- absent minor is 0
    eq(P.decode("H|1.6.6|100|7086|1|x9").minor,nil)               -- unreadable minor is unknown
    -- other well-formed types are ignored, not errors
    -- (Q, Y and J are read since lane A2; P, D and W since A3)
    eq(P.decode("Q").type,"Q"); eq(P.decode("J|7|100|7086|0.400|0.500|100").type,"J"); eq(P.decode("Y|12|100|a:480").maxAge,480)
    eq(P.decode("P|19|456|0|a").type,"P"); eq(P.decode("D|g789").type,"D"); eq(P.decode("W|"..SCOUT.."|123|"..VC:sub(1)).type,"W")
    for _,text in ipairs({"T|100|0.400|0.500|100","K|7|3|100|4","S|1234|20|100|2|1|0|4|3|100",
        "R|anything","L|1|100"}) do
        local m,why=P.decode(text); eq(m,nil,text); eq(why,"ignored",text)
    end
end)
test("decoder rejects hostile malformed and oversized messages",function()
    local N=loadAddon()
    local many={}; for i=1,19 do many[i]="abc:H:60" end
    local bad={"",string.rep("A",256),"C|1|100|nan|0|7|1|100","C|1|100|1.01|0|7|1|100","C|0|100|0|0|7|1|100","C|1|100|0|0|7|201|100",
        "C|1|0|0|0|7|1|100","C|1|100|0|0|-1|1|100","C|1|100|0|0|7","E|1|2|1|abc:H:60|100","E|1|1|1|abcd:H:60|100","E|1|1|1|abc:Z:60|100",
        "E|1|1|1|abc:H:0|100","E|1|1|1|abc:H:60,|100","E|1|1|1||100","E|1|1|1","E|1|1|1|"..table.concat(many,",").."|100",
        "H|bad|100|7|1","H|1.6.6|100|7","C|1|100|0|0|7|1|100\n","C|1|100|0|0|7|1|100 ","C|1|100|0|0|7|1|1\0001"}
    for _,text in ipairs(bad) do local m,why=N.Protocol.decode(text); eq(m,nil,text); eq(why,"invalid",text) end
    eq(N.Protocol.decode(secret),nil); eq(N.Protocol.decode({}),nil)
    -- optional fields that are unreadable become unknown instead of failing the message
    local c=N.Protocol.decode("C|1|100|0|0|7|1|3600|46|4:2"); yes(c); eq(c.stamp,nil); eq(c.spread,nil); eq(c.sync,false)
end)
test("we accepts trailing unknown fields",function()
    local N=loadAddon(); local P=N.Protocol
    local c=P.decode("C|42|100|0.400|0.500|7086|4|100|12||4f4c594d505553:4|x|y|z|1|2|3|4|5|6"); yes(c); eq(c.count,4); eq(c.stamp,100)
    local e=P.decode(VE.."|more|fields"); yes(e); eq(#e.enemies,4)
    local h=P.decode(VH.."|extra|9"); yes(h); eq(h.minor,19)
    yes(P.decode("C|42|100|0.400|0.500|7086|4"))                    -- minimum 7 fields, no stamp
end)
test("we G and X unwrap one level and reject nesting",function()
    local N=loadAddon(); local P=N.Protocol
    for _,text in ipairs({VX,VG}) do
        local m=P.decode(text); yes(m); eq(m.origin,"Scout One"); eq(m.realm,123); eq(m.inner.type,"C"); eq(m.inner.rid,42); eq(m.inner.stamp,100)
    end
    eq(P.decode(VX).type,"X"); eq(P.decode(VG).type,"G")
    local g=P.decode("G|"..SCOUT.."||"..VH); yes(g); eq(g.realm,nil); eq(g.inner.minor,19)
    yes(P.decode("X|"..SCOUT.."|123|"..VE))
    local bad={"G|"..SCOUT.."|123|"..VG,"X|"..SCOUT.."|123|"..VX,"G|"..SCOUT.."|123|X|"..SCOUT.."|123|"..VC,
        "X|"..SCOUT.."|123|C|42|100|0.400|0.500|7086|4|0|12|1:2",   -- sync C never travels wrapped
        "G|"..SCOUT.."|123|Q","G|"..SCOUT.."|123|"..VC:sub(1,8),"G|536|123|"..VC,"G|41|123|"..VC,"G|0a41|123|"..VC,"G|7c41|123|"..VC,
        "G|"..SCOUT.."|0|"..VC,"G|"..SCOUT.."|x|"..VC,"G|"..SCOUT.."|123","G|zz41|123|"..VC}
    for _,text in ipairs(bad) do local m,why=P.decode(text); eq(m,nil,text); eq(why,"invalid",text) end
end)
test("we stamp ages",function()
    local N=loadAddon(); local P=N.Protocol
    for _,v in ipairs({{100,720100,0},{99,720100,1},{101,720100,0},{3599,720001,2},{1900,720100,1800},{1899,720100,0}}) do
        eq(P.age(v[1],v[2]),v[3],v[1].."@"..v[2])
    end
    eq(P.age(nil,720100),0); eq(P.age(100,secret),nil); eq(P.age(100,nil),nil)
    -- C and E older than 900 s are dropped; 900 is kept
    local _,feed=reportFixture(N)
    local r,why=feed("C|1|100|0|0|7|1|"..(100-901)%3600); eq(r,nil); eq(why,"stale")
    r=feed("C|2|100|0|0|7|1|"..(100-900)%3600); yes(r); eq(r.age,900)
    r,why=feed("E|3|1|1|abc:H:60|"..(100-901)%3600); eq(r,nil); eq(why,"stale")
    r,why=feed("C|4|100|0|0|7|1|100",nil,nil,nil,secret); eq(r,nil); eq(why,"clock unavailable")
end)
test("we C alone is a record",function()
    local N=loadAddon(); local t,feed=reportFixture(N)
    local r,why=feed(VC,"Scout-Realm",200)
    yes(r); eq(why,"new"); eq(r.src,"we"); eq(r.kind,"group"); eq(r.origin,"Scout-Realm"); eq(r.via,"Scout-Realm"); eq(r.route,"GUILD")
    eq(r.rid,"42"); eq(r.zone,100); eq(r.count,4); eq(#r.enemies,0); eq(r.heard,200); eq(r.age,0); eq(r.share,"guild"); eq(r.x,.4)
    eq(r.layer.ns,"unknown"); eq(r.layer.value,7086)
    -- the E list enriches the same record without changing when it was heard
    local r2,why2=feed(VE,"Scout-Realm",205); eq(r2,r); eq(why2,"enriched"); eq(#r.enemies,4); eq(r.heard,200)
    local _,why3=feed(VE,"Scout-Realm",206); eq(why3,"duplicate list")
    -- a zone we cannot resolve makes no record
    local _,why4=feed("C|43|555|0|0|7|1|100","Scout-Realm"); eq(why4,"zone unknown")
    -- in the store the record shows with its count while no list has arrived
    local s=N.Store.new(0); s.zone=100; s.bulo="7086-7"
    local c=feed("C|50|100|0|0|7|3|100","Other",300); yes(N.Store.report(s,c,300))
    local rows=N.Store.rows(s,300,"reported"); eq(#rows,1); eq(rows[1].name,"3 not listed"); eq(rows[1].reporter,"Other")
end)
test("we E before C attaches within 15 s and expires after",function()
    local N=loadAddon(); local t,feed=reportFixture(N)
    local r,why=feed("E|1|1|1|abc:H:60|100","Scout",200); eq(r,nil); eq(why,"held")
    r=feed("C|1|100|0|0|7|2|100","Scout",215); yes(r); eq(#r.enemies,1); eq(r.enemies[1].hash,"abc"); eq(r.heard,215)
    eq(N.Safe.count(t.held),0); eq(t.heldBy.scout,nil)
    feed("E|2|1|1|abc:H:60|100","Scout",300)
    r=feed("C|2|100|0|0|7|2|100","Scout",316); yes(r); eq(#r.enemies,0)
    eq(N.Safe.count(t.held),0)
    -- at most 200 held entries per reporter
    for i=1,11 do local list={}; for j=1,18 do list[j]=string.char(64+i)..string.format("%02d",j)..":H:60" end
        eq(select(2,feed("E|"..(10+i).."|1|1|"..table.concat(list,",").."|100","Flood",400)),"held") end
    eq(t.heldBy.flood,198); eq(select(2,feed("E|30|1|1|abc:H:60,abd:H:60,abe:H:60|100","Flood",400)),"held list cap")
    eq(select(2,feed("E|30|1|1|abc:H:60|100","Other",400)),"held")
end)
test("we lost middle E still shows count",function()
    local N=loadAddon(); local t,feed=reportFixture(N)
    local r=feed("C|7|100|0.1|0.2|7|5|100","Scout",200)
    feed("E|7|1|3|aaa:H:60,bbb:A:40|100","Scout",201)
    feed("E|7|3|3|ccc:D:60,ddd:E:40|100","Scout",202)
    eq(#r.enemies,4); eq(r.count,5); eq(r.heard,200)
    -- a list whose new entries would exceed the count is rejected whole
    local _,why=feed("E|7|2|3|eee:H:60,fff:H:60|100","Scout",203); eq(why,"more enemies than counted"); eq(#r.enemies,4)
    _,why=feed("E|7|2|3|aaa:H:60,eee:H:60|100","Scout",204); eq(why,"enriched"); eq(#r.enemies,5)
    local s=N.Store.new(0); s.zone=100; s.bulo="7086-7"
    feed("C|8|100|0|0|7|3|100","Scout",205); local r8=feed("E|8|1|2|aaa:H:60|100","Scout",205)
    yes(N.Store.report(s,r8,206)); yes(N.Store.report(s,r,206))
    local rows=N.Store.rows(s,206,"reported"); eq(#rows,7)
    local names={}; for _,row in ipairs(rows) do names[row.name]=(names[row.name] or 0)+1 end
    eq(names["2 more not listed"],1); eq(names.Unknown,6)
end)
test("we report ids: newer only, caps",function()
    local N=loadAddon(); local t,feed=reportFixture(N)
    yes(feed("C|10|100|0|0|7|1|100","Scout",200))
    eq(select(2,feed("C|10|100|0|0|7|1|100","Scout",201)),"duplicate report")
    eq(select(2,feed("C|9|100|0|0|7|1|100","Scout",202)),"old report")
    yes(feed("C|11|100|0|0|7|1|100","Scout",203))
    -- wrap-around: 65535 then 1 is newer
    yes(feed("C|65535|100|0|0|7|1|100","Wrap",200)); yes(feed("C|1|100|0|0|7|1|100","Wrap",201))
    eq(select(2,feed("C|65534|100|0|0|7|1|100","Wrap",202)),"old report")
    -- after the 600 s TTL the record is gone, but the id order holds for an hour
    N.Reports.prune(t,900); eq(t.reports["scout:10"],nil)
    eq(select(2,feed("C|11|100|0|0|7|1|100","Scout",900)),"old report")
    -- names compare whole and without case: another realm is another reporter (مانع T3 F1)
    eq(select(2,feed("C|11|100|0|0|7|1|100","SCOUT",901)),"old report")
    eq(select(2,feed("C|11|100|0|0|7|1|100","scout-OtherRealm",901)),"new")
    -- 64 live reports at most
    local u,feed2=reportFixture(N)
    for i=1,64 do yes(feed2("C|1|100|0|0|7|1|100","Ess"..abc(i),200)) end
    eq(select(2,feed2("C|1|100|0|0|7|1|100","Ess"..abc(65),200)),"report cap"); eq(u.n,64)
    -- 512 reporters' id order at most: the oldest is forgotten
    local v,feed3=reportFixture(N)
    for i=1,600 do feed3("C|1|100|0|0|7|1|100","Arr"..abc(i),200+i); N.Reports.prune(v,200+i); v.reports={}; v.n=0 end
    eq(N.Safe.count(v.latest),512)
end)
test("reported reducer output stays separate with possible hash identities",function()
    local N=loadAddon(); local t=N.Store.new(0); t.zone=100; t.bulo="7086-7"; t.zoneUID=7
    yes(N.Store.observe(t,{key="Player-1-1",at=100,name="Enemy",realm="Test Realm",class="MAGE",faction="opposite",source="own target"},100))
    local hash=N.Hash.player("Enemy","Test Realm")
    local report=N.Record.new({src="we",kind="group",origin="Reporter",via="Reporter",route="GUILD",rid="1",zone=100,x=.4,y=.5,count=1,
        enemies={{hash=hash,class="MAGE",level=60}},layer={ns="server",value="7086"},heard=101,age=0,share="guild"})
    yes(N.Store.report(t,report,101))
    local rows=N.Store.rows(t,101,"reported"); eq(#rows,1); eq(rows[1].name,"Unknown"); yes(rows[1].possible:find("possible identity:",1,true))
    eq(rows[1].confidence,"reported, not confirmed"); eq(rows[1].namespace,"server"); eq(rows[1].relation,"same"); eq(rows[1].record,report)
    eq(#N.Store.rows(t,101,"local"),1)
    t.identities[hash]["Collision-Realm"]=101
    rows=N.Store.rows(t,101,"reported"); yes(rows[1].possible:find("Collision-Realm",1,true))
    -- every record of our zone is kept and labelled with its relation; another zone or the boundary instant is not
    yes(N.Store.report(t,N.Record.new({src="we",kind="group",origin="Other",route="GUILD",rid="2",zone=100,count=1,layer={ns="server",value="7087"},heard=101,age=0,share="guild"}),101))
    yes(N.Store.report(t,N.Record.new({src="we",kind="group",origin="Third",route="GUILD",rid="3",zone=100,count=1,layer={ns="zoneuid",value=7},heard=101,age=0,share="guild"}),101))
    local rel={}; for _,row in ipairs(N.Store.rows(t,101,"reported")) do rel[row.reporter]=row.relation end
    eq(rel.Other,"other"); eq(rel.Third,"unknown"); eq(rel.Reporter,"same")
    local ok,why=N.Store.report(t,N.Record.new({src="we",kind="group",origin="Far",route="GUILD",rid="4",zone=200,layer={ns="server",value="7086"},heard=101,share="guild"}),101)
    no(ok); eq(why,"another zone")
    ok,why=N.Store.report(t,N.Record.new({src="we",kind="group",origin="Early",route="GUILD",rid="5",zone=100,layer={ns="server",value="7086"},heard=0,share="guild"}),101)
    no(ok); eq(why,"before observation epoch")
    no(N.Store.report(t,{id="x"},101))
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
    eq(#frames,18)
end)
test("SavedVariables contain options only; no sightings survive reload",function()
    local N=loadAddon(); establish(N)
    units.target=player("PrivateName","Horde"); advance(1); deliver("PLAYER_TARGET_CHANGED"); drain()
    eq(LayerEnemiesDB.sightings,nil); eq(LayerEnemiesDB.localSeen,nil); yes(LayerEnemiesDB.options)
    N.Main.start(); eq(#frames,18)
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
test("a zone boundary drops held lists and reports, not the report order",function()
    local N=loadAddon(); local t,feed=reportFixture(N)
    feed("E|1|1|2|abc:H:60|100","Scout",200); feed("C|2|100|0|0|7|1|100","Scout",200)
    N.Reports.clearPending(t); eq(N.Safe.count(t.held),0); eq(N.Safe.count(t.reports),0); eq(t.n,0)
    local r=feed("C|1|100|0|0|7|2|100","Scout",201); eq(r,nil)          -- older than 2: not a new sighting
    r=feed("C|3|100|0|0|7|2|100","Scout",201); yes(r); eq(#r.enemies,0)
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
local ASK="Hi! Could you invite me to your layer please?"
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
local function report(id,layer,sender,map,route)
    local stamp=math.floor(server)%3600
    deliver("CHAT_MSG_ADDON","WEFF1","C|"..id.."|"..(map or 100).."|0.4|0.5|"..layer.."|1|"..stamp,route or "GUILD",sender or "Other")
    deliver("CHAT_MSG_ADDON","WEFF1","E|"..id.."|1|1|abc:H:40|"..stamp,route or "GUILD",sender or "Other")
end
local function hello(sender,minor,route)
    deliver("CHAT_MSG_ADDON","WEFF1","H|1.6.6|100|7086|1|"..minor.."|0|123|"..math.floor(server)%3600,route or "GUILD",sender)
end
test("one layer key helper compares the server part only",function()
    local N=loadAddon(); local L=N.Layer
    eq(L.key("7086-7"),"7086"); eq(L.key("7086"),"7086"); eq(L.key(7086),"7086")
    for _,bad in ipairs({"","x","7086-","-7","7086-7-1","70 86",0,-1,1.5,1e15,0/0,{},true,string.rep("1",33)}) do eq(L.key(bad),nil) end
    eq(L.key(secret),nil); eq(L.key(nil),nil)
    yes(L.same("7086-7","7086-99")); yes(L.same("7086","7086-1")); yes(L.same(7086,"7086"))
    no(L.same("7086-7","7087-7")); no(L.same(nil,nil)); no(L.same(secret,secret)); no(L.same("7086",nil))
end)
test("a War Effort report shows as reported, not confirmed",function()
    local N=loadAddon(); establish(N)
    advance(1); local at=clock; report(1,7)
    eq(N.Main.lastDrop,"enriched")
    local rows=N.Store.rows(N.Main.store,clock,"reported")
    eq(#rows,1); eq(rows[1].at,at); eq(rows[1].name,"Unknown"); eq(rows[1].class,"MAGE"); eq(rows[1].level,40)
    eq(rows[1].confidence,"reported, not confirmed"); eq(rows[1].reporter,"Other"); eq(rows[1].relation,"unknown")
    eq(rows[1].namespace,"unknown"); eq(rows[1].age,0)
    eq(#N.Store.rows(N.Main.store,clock,"local"),0); eq(#N.Store.rows(N.Main.store,clock,"unclassified"),0)
    eq(#N.Store.mapCandidates(N.Main.store,clock,100),0)
    SlashCmdList.LAYERENEMIES("list")
    yes(logged("Reported, not confirmed: 1 more in /le reports")); no(logged("Unknown | MAGE"))
    SlashCmdList.LAYERENEMIES("reports")
    yes(logged("Reported, not confirmed (War Effort; age as the reporter's clock gives it):"))
    yes(logged("Unknown | MAGE | 40 | zone 100 | received 0 s ago | reported (War Effort) | reported, not confirmed | reported by Other | reported cluster position | layer unknown"))
    yes(logged("Only players seen by you or reported by other players' addons.")); no(N.Main.error)
    -- a claimed age is shown
    local stamp=(math.floor(server)-120)%3600
    deliver("CHAT_MSG_ADDON","WEFF1","C|2|100|0.4|0.5|7|1|"..stamp,"GUILD","Older")
    SlashCmdList.LAYERENEMIES("reports"); yes(logged("1 not listed | Unknown class | ? | zone 100 | received 0 s ago | reported (War Effort) | reported, not confirmed | reported by Older | reported cluster position | claimed 120 s old | layer unknown"))
end)
test("receipt-time reports expire ten minutes after receipt",function()
    local N=loadAddon(); establish(N); advance(1); report(1,7)
    advance(598); eq(#N.Store.rows(N.Main.store,clock,"reported"),1); eq(#N.Store.reporters(N.Main.store,clock),1)
    advance(3); eq(#N.Store.rows(N.Main.store,clock,"reported"),0); eq(N.Safe.count(N.Main.store.reports),0)
    eq(#N.Store.reporters(N.Main.store,clock),0)
end)
test("a repeated report id is not a new sighting; an hour later it is (documented limit)",function()
    local N=loadAddon(); establish(N); advance(1); report(1,7)
    report(1,7); eq(N.Main.lastDrop,"duplicate list"); eq(N.Safe.count(N.Main.store.reports),1)
    advance(20); deliver("CHAT_MSG_ADDON","WEFF1","C|1|100|0.4|0.5|7|1|"..math.floor(server)%3600,"GUILD","Other"); eq(N.Main.lastDrop,"duplicate report")
    advance(600); eq(N.Safe.count(N.Main.store.reports),0)
    deliver("CHAT_MSG_ADDON","WEFF1","C|1|100|0.4|0.5|7|1|"..math.floor(server)%3600,"GUILD","Other"); eq(N.Main.lastDrop,"old report")
    -- KNOWN LIMIT: the stamp has no hour and the id order is kept for an hour, so an old packet replayed later is
    -- shown again as a fresh unconfirmed report.
    advance(3600); report(1,7); eq(N.Main.lastDrop,"enriched"); eq(N.Safe.count(N.Main.store.reports),1)
    eq(N.Store.rows(N.Main.store,clock,"reported")[1].confidence,"reported, not confirmed")
end)
test("we drops whisper and channel, and types a route does not carry",function()
    local N=loadAddon(); establish(N); advance(1)
    local stamp=math.floor(server)%3600; local c="C|1|100|0|0|7|1|"..stamp
    deliver("CHAT_MSG_ADDON","WEFF1",c,"WHISPER","Other"); eq(N.Main.lastDrop,"C is not read on WHISPER","(only J by whisper, lane A2)")
    deliver("CHAT_MSG_ADDON","WEFF1",c,"CHANNEL","Other",nil,nil,7,"WarEffortPubA"); eq(N.Main.lastDrop,"route")
    deliver("CHAT_MSG_ADDON","WEFF1",VX,"GUILD","Relay"); eq(N.Main.lastDrop,"X is not read on GUILD")
    deliver("CHAT_MSG_ADDON","WEFF1",VG,"PARTY","Relay"); eq(N.Main.lastDrop,"G is not read on PARTY")
    deliver("CHAT_MSG_ADDON","WEFF1",VG,"RAID","Relay"); eq(N.Main.lastDrop,"G is not read on RAID")
    eq(N.Safe.count(N.Main.store.reports),0)
    deliver("CHAT_MSG_ADDON","WEFF1",c,"PARTY","Friend"); eq(N.Main.lastDrop,"new")
    deliver("CHAT_MSG_ADDON","WEFF1","C|2|100|0|0|7|1|"..stamp,"RAID","Friend"); eq(N.Main.lastDrop,"new")
    local r=N.Store.rows(N.Main.store,clock,"reported")[1].record; eq(r.share,"public"); eq(r.route=="PARTY" or r.route=="RAID",true)
    -- nothing about another addon's prefix, and an ignored type leaves no note
    N.Main.lastDrop=nil; deliver("CHAT_MSG_ADDON","WEFF1","Q","GUILD","Other"); eq(N.Main.lastDrop,nil)
    deliver("CHAT_MSG_ADDON","ZRAD1",c,"GUILD","Other"); eq(N.Main.lastDrop,nil)
    eq(N.Safe.count(N.Main.store.reports),2); no(N.Main.error); eq(forbidden,0)
end)
test("we own echo, ignore list for sender and origin, guild membership",function()
    local N=loadAddon(); establish(N); advance(1)
    local c="C|1|100|0|0|7|1|"..math.floor(server)%3600
    deliver("CHAT_MSG_ADDON","WEFF1",c,"GUILD","Me-TestRealm"); eq(N.Main.lastDrop,"own echo")
    deliver("CHAT_MSG_ADDON","WEFF1","G|"..("Me"):gsub(".",function(ch) return string.format("%02x",ch:byte()) end).."||"..c,"GUILD","Relay"); eq(N.Main.lastDrop,"own echo")
    clientIgnored=true; deliver("CHAT_MSG_ADDON","WEFF1",c,"GUILD","Other"); eq(N.Main.lastDrop,"ignored sender")
    -- the ignore list also applies to a wrapper's origin
    local old=C_FriendList.IsIgnored
    C_FriendList.IsIgnored=function(name) return name=="Scout One" end
    deliver("CHAT_MSG_ADDON","WEFF1",VG,"GUILD","Relay"); eq(N.Main.lastDrop,"ignored sender")
    C_FriendList.IsIgnored=function() return nil end
    deliver("CHAT_MSG_ADDON","WEFF1",c,"GUILD","Other"); eq(N.Main.lastDrop,"client ignore policy unavailable")
    C_FriendList=nil; deliver("CHAT_MSG_ADDON","WEFF1",c,"GUILD","Other"); eq(N.Main.lastDrop,"client ignore policy unavailable")
    C_FriendList={IsIgnored=function() return false end}; clientIgnored=false
    inGuild=false; deliver("CHAT_MSG_ADDON","WEFF1",c,"GUILD","Other"); eq(N.Main.lastDrop,"guild unavailable")
    eq(N.Safe.count(N.Main.store.reports),0)
    inGuild=true; deliver("CHAT_MSG_ADDON","WEFF1",c,"GUILD","Other"); eq(N.Main.lastDrop,"new")
    eq(N.Safe.count(N.Main.store.reports),1); no(N.Main.error)
end)
test("we rate limit 6 per 10 s",function()
    local N=loadAddon(); establish(N); advance(1)
    local function c(id,who,route) deliver("CHAT_MSG_ADDON","WEFF1","C|"..id.."|100|0|0|7|1|"..math.floor(server)%3600,route or "GUILD",who) end
    for i=1,7 do c(i,"Busy") end
    eq(N.Safe.count(N.Main.store.reports),6); eq(N.Main.lastDrop,"new")       -- the 7th leaves no note
    c(20,"Calm"); eq(N.Safe.count(N.Main.store.reports),7)                    -- per sender
    advance(10); c(8,"Busy"); eq(N.Safe.count(N.Main.store.reports),8)
    -- G wrappers: 20 per relayer per 10 s, counted apart from its own messages
    local function hex(name) return (name:gsub(".",function(ch) return string.format("%02x",ch:byte()) end)) end
    for i=1,21 do deliver("CHAT_MSG_ADDON","WEFF1","G|"..hex("Origin"..abc(i)).."||C|1|100|0|0|7|1|"..math.floor(server)%3600,"GUILD","Relay") end
    eq(N.Safe.count(N.Main.store.reports),28)
    c(1,"Relay"); eq(N.Safe.count(N.Main.store.reports),29)
end)
test("we works with no War Effort installed",function()
    local N=loadAddon(); establish(N); advance(1)
    loaded.WarEffortScout=false; WarEffortScoutDB=nil
    hello("Scout",19); report(1,7086,"Scout")
    eq(N.Main.lastDrop,"enriched"); eq(N.Safe.count(N.Main.store.reports),1)
    N.Main.poll(); eq(N.Main.statusWE:sub(1,48),"not installed / listening on guild, party and ra")
    -- an installed War Effort changes nothing: its settings are not read
    loaded.WarEffortScout=true; WarEffortScoutDB={silent=true,guildOnly=true,ignored={scout=true}}
    report(2,7086,"Scout"); eq(N.Main.lastDrop,"enriched"); eq(N.Safe.count(N.Main.store.reports),2)
    no(N.Main.error); eq(forbidden,0)
end)
test("we layer is unknown without a hello, below 13 and above 19",function()
    local N=loadAddon(); establish(N); advance(1)
    hello("Low",12); hello("High",20)
    report(1,7086,"None"); report(1,7086,"Low"); report(1,7086,"High")
    local rows=N.Store.rows(N.Main.store,clock,"reported"); eq(#rows,3)
    for _,row in ipairs(rows) do eq(row.relation,"unknown",row.reporter); eq(row.namespace,"unknown"); eq(row.reportLayer,7086) end
    -- a hello expires after 900 s
    hello("Late",19); advance(901); report(1,7086,"Late")
    local late; for _,row in ipairs(N.Store.rows(N.Main.store,clock,"reported")) do if row.reporter=="Late" then late=row end end
    eq(late.namespace,"unknown")
end)
test("we layer is server after hello minor 19",function()
    local N=loadAddon(); establish(N); advance(1)
    hello("Here",19); hello("There",19); hello("Lowest",13)
    report(1,7086,"Here"); report(1,9000,"There"); report(1,7086,"Lowest")
    local rel={}; for _,row in ipairs(N.Store.rows(N.Main.store,clock,"reported")) do rel[row.reporter]=row.relation.."/"..row.namespace end
    eq(rel.Here,"same/server"); eq(rel.There,"other/server"); eq(rel.Lowest,"same/server")
    SlashCmdList.LAYERENEMIES("reports"); yes(logged("| other server key 9000")); yes(logged("| same server key as yours"))
    -- the relayer's hello does not count for the origin of a G
    hello("Relay",19)
    deliver("CHAT_MSG_ADDON","WEFF1",VG,"GUILD","Relay")
    local g; for _,row in ipairs(N.Store.rows(N.Main.store,clock,"reported")) do if row.reporter=="Scout One" then g=row end end
    eq(g.namespace,"unknown"); eq(g.record.via,"Relay"); eq(g.record.share,"public"); eq(g.name,"4 not listed")
    -- the origin's own hello, wrapped, does
    local h="H|1.6.6|100|7086|1|19|0|123|"..math.floor(server)%3600
    deliver("CHAT_MSG_ADDON","WEFF1","G|"..SCOUT.."|123|"..h,"GUILD","Relay")
    deliver("CHAT_MSG_ADDON","WEFF1","G|"..SCOUT.."|123|C|43|100|0.4|0.5|7086|1|"..math.floor(server)%3600,"GUILD","Relay")
    local found=false
    for _,row in ipairs(N.Store.rows(N.Main.store,clock,"reported")) do
        if row.reporter=="Scout One" and row.record.rid=="43" then found=true; eq(row.relation,"same"); eq(row.namespace,"server") end
    end
    yes(found)
end)
test("we repeated G of one report is one record",function()
    local N=loadAddon(); establish(N); advance(1)
    local stamp=math.floor(server)%3600
    local g="G|"..SCOUT.."|123|C|42|100|0.400|0.500|7086|4|"..stamp
    deliver("CHAT_MSG_ADDON","WEFF1",g,"GUILD","RelayOne"); eq(N.Main.lastDrop,"new")
    deliver("CHAT_MSG_ADDON","WEFF1",g,"GUILD","RelayTwo"); eq(N.Main.lastDrop,"duplicate report")
    deliver("CHAT_MSG_ADDON","WEFF1",g,"GUILD","RelayOne"); eq(N.Main.lastDrop,"duplicate report")
    eq(N.Safe.count(N.Main.store.reports),1); eq(#N.Store.reporters(N.Main.store,clock),1)
    -- the E list relayed by another guildmate enriches the same record
    deliver("CHAT_MSG_ADDON","WEFF1","G|"..SCOUT.."|123|E|42|1|1|Zzm:H:60,AbC:A:-1|"..stamp,"GUILD","RelayTwo"); eq(N.Main.lastDrop,"enriched")
    local rows=N.Store.rows(N.Main.store,clock,"reported"); eq(#rows,3); eq(N.Safe.count(N.Main.store.reports),1)
end)
test("we zone, layer zero and clock",function()
    local N=loadAddon(); establish(N); advance(1)
    local stamp=math.floor(server)%3600
    local function send(text,who) deliver("CHAT_MSG_ADDON","WEFF1",text,"GUILD",who or "Other") end
    send("C|1|100|0|0|7|1|"..(stamp-901)%3600); eq(N.Main.lastDrop,"stale")
    send("C|2|100|0|0|7|1|"..(stamp+1800)%3600); eq(N.Main.lastDrop,"stale")      -- age 1800 is not "now"
    send("C|3|100|0|0|7|1|"..(stamp+5)%3600); eq(N.Main.lastDrop,"new")          -- ahead of our clock: age 0
    send("C|4|200|0|0|7|1|"..stamp); eq(N.Main.lastDrop,"another zone")
    send("C|5|100|0|0|0|1|"..stamp,"Zero"); eq(N.Main.lastDrop,"new")
    hello("Zero",19); send("C|6|100|0|0|0|1|"..stamp,"Zero")
    local z; for _,row in ipairs(N.Store.rows(N.Main.store,clock,"reported")) do if row.record.rid=="6" then z=row end end
    eq(z.namespace,"unknown")                                                    -- layer 0 is unknown even at minor 19
    GetServerTime=function() return secret end
    send("C|8|100|0|0|7|1|"..stamp); eq(N.Main.lastDrop,"clock unavailable"); no(N.Main.error)
end)
test("we caps hold under a flood",function()
    local N=loadAddon(); establish(N); advance(1)
    for i=1,400 do advance(.2); report(i%7+1,9,"Sender"..abc(i)) end
    yes(N.Safe.count(N.Main.store.reports)<=64); yes(N.Safe.count(N.Main.store.reports)>0)
    yes(N.Main.receiver.n<=64); yes(N.Safe.count(N.Main.receiver.latest)<=512); yes(N.Main.receiver.nrates<=512)
    yes(#N.Main.candidates()<=40); no(N.Main.error)
end)
test("reports from another server key in our zone are kept apart and labelled",function()
    local N=loadAddon(); establish(N); advance(1)
    hello("Scout-TestRealm",19); report(1,9000,"Scout-TestRealm"); eq(N.Main.lastDrop,"enriched")
    local rows=N.Store.rows(N.Main.store,clock,"reported")
    eq(#rows,1); eq(rows[1].relation,"other"); eq(rows[1].reportLayer,"9000"); eq(rows[1].confidence,"reported, not confirmed")
    report(2,9,"Elsewhere",200); eq(N.Main.lastDrop,"another zone"); eq(N.Safe.count(N.Main.store.reports),1)
    eq(#N.Store.reporters(N.Main.store,clock),1)
    SlashCmdList.LAYERENEMIES("reports"); yes(logged("| other server key 9000")); no(logged("zoneUID")); yes(logged("ask a reporter for an invite: /le hosts"))
    -- before our own server key is known the relation is unknown, never "same"
    N=loadAddon(); advance(1); hello("Other",19); report(1,7086)
    eq(N.Store.rows(N.Main.store,clock,"reported")[1].relation,"unknown")
    -- a transfer wipes reports and reporters
    deliver("SHARD_TRANSFER"); drain(); eq(N.Safe.count(N.Main.store.reports),0); eq(#N.Store.reporters(N.Main.store,clock),0)
    -- same instant as the boundary: nothing is stored; later the id is not new any more
    report(2,7); eq(N.Main.lastDrop,"before observation epoch")
    advance(10); report(2,7); eq(N.Main.lastDrop,"duplicate list"); eq(N.Safe.count(N.Main.store.reports),0)
end)
local function hexOf(s) return (s:gsub(".",function(c) return string.format("%02x",c:byte()) end)) end
test("we a hello from one realm never vouches for a namesake on another (مانع T3 F1)",function()
    local N=loadAddon(); establish(N); advance(1)
    local stamp=math.floor(server)%3600
    local function wrapped(origin,rid) return "G|"..hexOf(origin).."||C|"..rid.."|100|0.4|0.5|7086|4|"..stamp end
    -- Astra's RELAYER_REALM_COLLISION: Scout-RealmA says hello 19, then relays a C whose origin is Scout-RealmB
    hello("Scout-RealmA",19); deliver("CHAT_MSG_ADDON","WEFF1",wrapped("Scout-RealmB",42),"GUILD","Scout-RealmA")
    local rows=N.Store.rows(N.Main.store,clock,"reported"); eq(#rows,1)
    eq(rows[1].reporter,"Scout-RealmB"); eq(rows[1].namespace,"unknown"); eq(rows[1].relation,"unknown")
    eq(N.Peers.minor(N.Main.peers,"Scout-RealmB",clock),nil); eq(N.Peers.minor(N.Main.peers,"Scout-RealmA",clock),19)
    -- and the same id from the namesake on realm A is its own report: two rows
    hello("Scout-RealmA",19); report(42,7086,"Scout-RealmA")
    rows=N.Store.rows(N.Main.store,clock,"reported"); local seen={}
    for _,row in ipairs(rows) do seen[row.reporter]=(row.relation) end
    eq(seen["Scout-RealmB"],"unknown"); eq(seen["Scout-RealmA"],"same"); eq(N.Safe.count(N.Main.store.reports),2)
    -- case does not split a reporter
    eq(N.Peers.key("SCOUT-RealmA"),N.Peers.key("scout-realma"))
end)
test("we a wrapper naming its own sender, or us, is refused",function()
    local N=loadAddon(); establish(N); advance(1)
    local c="C|1|100|0.4|0.5|7086|1|"..math.floor(server)%3600
    deliver("CHAT_MSG_ADDON","WEFF1","G|"..hexOf("Scout").."||"..c,"GUILD","Scout"); eq(N.Main.lastDrop,"wrapped by its own origin")
    deliver("CHAT_MSG_ADDON","WEFF1","G|"..hexOf("Scout").."||"..c,"GUILD","Scout-TestRealm"); eq(N.Main.lastDrop,"wrapped by its own origin")
    deliver("CHAT_MSG_ADDON","WEFF1","X|"..hexOf("Pal").."|1|"..c,"PARTY","pal"); eq(N.Main.lastDrop,"wrapped by its own origin")
    deliver("CHAT_MSG_ADDON","WEFF1","G|"..hexOf("Me-TestRealm").."||"..c,"GUILD","Relay"); eq(N.Main.lastDrop,"own echo")
    deliver("CHAT_MSG_ADDON","WEFF1","G|"..hexOf("Me").."||"..c,"GUILD","Relay"); eq(N.Main.lastDrop,"own echo")
    eq(N.Safe.count(N.Main.store.reports),0)
    -- a namesake on another realm is not us
    deliver("CHAT_MSG_ADDON","WEFF1","G|"..hexOf("Me-FarRealm").."||"..c,"GUILD","Relay"); eq(N.Main.lastDrop,"new")
end)
test("we E, then a boundary, then C of the same id is a new report (مانع T3 S1, accepted)",function()
    local N=loadAddon(); local t,feed=reportFixture(N)
    eq(select(2,feed("E|5|1|1|abc:H:60|100","Scout",200)),"held")
    N.Reports.clearPending(t)
    local r,why=feed("C|5|100|0|0|7|1|100","Scout",201); eq(why,"new"); eq(#r.enemies,0); eq(r.heard,201)
    -- through the addon: the E heard before a same-zone transfer does not attach; the C after it is a new row
    N=loadAddon(); establish(N); advance(1); local stamp=math.floor(server)%3600
    deliver("CHAT_MSG_ADDON","WEFF1","E|9|1|1|abc:H:60|"..stamp,"GUILD","Scout"); eq(N.Main.lastDrop,"held")
    deliver("SHARD_TRANSFER"); drain(); advance(1)
    deliver("CHAT_MSG_ADDON","WEFF1","C|9|100|0|0|7|1|"..math.floor(server)%3600,"GUILD","Scout"); eq(N.Main.lastDrop,"new")
    local rows=N.Store.rows(N.Main.store,clock,"reported"); eq(#rows,1); eq(rows[1].name,"1 not listed")
end)
test("we secret values in any message argument stop the message (مانع T3 S2)",function()
    local stamp
    for i=1,4 do
        local N=loadAddon(); establish(N); advance(1); stamp=math.floor(server)%3600
        local args={"WEFF1","C|1|100|0|0|7|1|"..stamp,"GUILD","Other"}
        args[i]=secret
        N.Main.lastDrop="untouched"; N.Main.lastHeard=nil
        deliver("CHAT_MSG_ADDON",args[1],args[2],args[3],args[4])
        eq(N.Main.lastDrop,"untouched",i); eq(N.Main.lastHeard,nil,i); eq(N.Safe.count(N.Main.store.reports),0,i); no(N.Main.error,i)
        eq(N.Main.receiver.nrates,0,i)
    end
    -- the same message without a secret is read
    local N=loadAddon(); establish(N); advance(1)
    deliver("CHAT_MSG_ADDON","WEFF1","C|1|100|0|0|7|1|"..math.floor(server)%3600,"GUILD","Other"); eq(N.Main.lastDrop,"new")
end)
test("we held lists are capped across origins, rate table too (مانع T3 S3)",function()
    local N=loadAddon(); local t,feed=reportFixture(N)
    local function list(tag,n) local out={}; for j=1,n do out[j]=tag..string.format("%02d",j)..":H:60" end; return table.concat(out,",") end
    -- 18 origins x 18 entries = 324 > 256: the oldest lists make room
    for i=1,18 do eq(select(2,feed("E|1|1|1|"..list(string.char(64+i),18).."|100","Origin"..abc(i),200+i/100)),"held") end
    yes(t.heldAll<=256); eq(t.heldAll,252)
    eq(t.held["origina:1"],nil); eq(t.held["origind:1"],nil); yes(t.held["origine:1"]); yes(t.held["originr:1"])
    local sum=0; for _,h in pairs(t.held) do sum=sum+h.entries end; eq(sum,t.heldAll)
    -- a kept list still attaches; a dropped one does not
    local r=feed("C|1|100|0|0|7|18|100","Originr",202); eq(#r.enemies,18)
    r=feed("C|1|100|0|0|7|18|100","Origina",202); eq(#r.enemies,0)
    eq(t.heldAll,234)
    N.Reports.prune(t,300); eq(t.heldAll,0); eq(next(t.held),nil)
    -- the receive-rate table holds 512 senders at most; the 513th is refused until the window passes
    local u=N.Reports.new()
    for i=1,512 do yes(N.Reports.allow(u,"S"..i,false,0)) end
    no(N.Reports.allow(u,"S513",false,1)); eq(u.nrates,512)
    yes(N.Reports.allow(u,"S513",false,10)); yes(u.nrates<=512)
end)
test("we reports never enter LayerEnemiesDB (مانع T3 S4)",function()
    local N=loadAddon(); establish(N); advance(1)
    hello("Scout",19); report(1,7086,"Scout"); report(2,9000,"Scout"); hello("Relay",19)
    deliver("CHAT_MSG_ADDON","WEFF1",VG,"GUILD","Relay"); deliver("CHAT_MSG_ADDON","WEFF1","E|9|1|1|abc:H:60|100","GUILD","Late")
    SlashCmdList.LAYERENEMIES("find Alice"); SlashCmdList.LAYERENEMIES("reports")
    yes(N.Safe.count(N.Main.store.reports)>=2)
    local bad={rid=1,origin=1,via=1,enemies=1,layer=1,heard=1,hash=1,reports=1,peers=1,zone=1,count=1,record=1}
    local function scan(v,path,depth)
        if type(v)=="table" then
            for k,x in pairs(v) do
                no(bad[k],path.."."..tostring(k))
                scan(x,path.."."..tostring(k),depth+1)
            end
        elseif type(v)=="string" then
            no(v:find("Scout",1,true),path); no(v:find("Relay",1,true),path); no(v:find("7086",1,true),path); no(v=="abc",path)
        end
    end
    scan(LayerEnemiesDB,"LayerEnemiesDB",0)
    for k in pairs(LayerEnemiesDB) do yes(k=="options" or k=="tracked" or k=="position" or k=="guildHost" or k=="autoHop" or k=="consent" or k=="nets" or k=="share" or k=="netNotice",k) end; eq(type(LayerEnemiesDB.guildHost),"boolean")
end)
test("candidates: every source absent",function()
    local N=loadAddon(); establish(N)
    local list,status=N.Main.candidates()
    eq(#list,0); eq(status.bulo,"not installed"); eq(status.book,"not installed"); eq(status.reports,"0 not on your server key")
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
    -- Without a known own layer (0.3.1): the host is listed, marked, so a player without a layer addon sees it;
    -- no hop or ask goes through such a row (the 0.3.1 T3 tests).
    N=loadAddon(); local b=fakeBulo(nil); b.Guild={list={Good=there()}}; N.Main.poll()
    list,status=N.Main.candidates(); eq(names(list),"Good"); yes(list[1].unknownOwn); eq(status.bulo,"1 fresh in this zone (your layer is not known yet)")
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
    -- A War Effort reporter on another server key goes first and merges by name.
    units.target={guid=npc(1),player=false}; deliver("PLAYER_TARGET_CHANGED"); drain(); advance(.1)
    units.mouseover={guid=npc(2),player=false}; deliver("UPDATE_MOUSEOVER_UNIT"); drain(); advance(.1)
    eq(N.Main.store.zoneUID,7)
    for _,who in ipairs({"Bob-TestRealm","Zed-TestRealm","Sam","Carl"}) do hello(who,19) end
    report(1,9,"Bob-TestRealm"); report(2,9,"Zed-TestRealm"); report(3,7086,"Sam"); report(4,9,"Carl"); report(5,9,"Me-TestRealm")
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
    eq(opened[1].text,"/w Alice Hi! Could you invite me to your layer please?")
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
    -- an unreadable group state counts as grouped (مانع T5 S1)
    IsInGroup=function() return secret end; no(LE.AskInvite("Alice")); yes(logged("leave your current group first"))
    drain(); eq(#opened,0); eq(N.Safe.count(N.Main.invite.asked),0); no(N.Main.error); eq(forbidden,0)
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
    yes(logged("Bulo: 2 fresh in this zone / LayerSwap: 1 fresh in this zone / War Effort reporters: 1 not on your server key"))
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
    yes(logged("LayerEnemies: Moved to layer 8000. Whether leaving the group keeps you there is not confirmed - stay grouped if unsure.")); eq(N.Main.invite.watch,nil)
    eq(lines("safe to leave"),0)
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
    yes(logged("LayerEnemies: Moved to layer 9000. Whether leaving the group keeps you there is not confirmed - stay grouped if unsure."))
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
    advance(61); eq(lines("Layer not confirmed yet - target or mouse over two different kinds of NPC."),1)
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
    N=loadAddon(); clientIgnored=true; advance(1); report(1,9,"Scout-TestRealm")
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
    for _,file in ipairs(addonFiles()) do
        local f=assert(io.open("LayerEnemies/"..file..".lua")); local text=f:read("*a"); f:close()
        for _,word in ipairs({"SendChatMessage","RunMacroText","JoinChannel","UninviteUnit","ConfirmInviteUnit","ConvertToRaid","DeclineGroup","RequestInviteFromUnit","ConfirmLeaveParty"}) do
            -- 1.0 T3: Directory.lua joins its two channels (checked in the T3 tests)
            if not (file=="Directory" and word=="JoinChannel") then eq(text:find(word,1,true),nil,file.." mentions "..word) end
        end
        -- InviteUnit and C_PartyInfo: exactly once each, in Wire.lua only
        local function count(word) local n=0; for _ in text:gmatch("%f[%w_]"..word.."%f[^%w_]") do n=n+1 end; return n end
        eq(count("InviteUnit"),file=="Wire" and 1 or 0,file.." InviteUnit count"); eq(count("AcceptGroup"),file=="Wire" and 1 or 0,file.." AcceptGroup count"); eq(count("LeaveParty"),file=="Wire" and 1 or 0,file.." LeaveParty count"); eq(count("C_PartyInfo"),file=="Wire" and 1 or 0,file.." C_PartyInfo count")
        -- SendAddonMessage only in Wire.lua
        if file=="Wire" then yes(text:find("SendAddonMessage",1,true),"Wire sends")
        else eq(text:find("SendAddonMessage",1,true),nil,file.." mentions SendAddonMessage") end
    end
    eq(#sent,0)
    -- the only registered events are passive
    -- 0.4.0 Task 8: PARTY_INVITE_REQUEST is read (auto-accept of the asked host only); no other invite event
    for event in pairs(frames[1].events) do no(event:find("PARTY_INVITE",1,true) and event~="PARTY_INVITE_REQUEST",event) end
    yes(frames[1].events.GROUP_ROSTER_UPDATE); eq(frames[1].scripts.OnUpdate,nil); eq(#frames,18)
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
    no(LE.AskInvite("Scout")); yes(logged("travel to Durotar first")); eq(#opened,0)
    clientIgnored=true
    deliver("CHAT_MSG_ADDON","WEFF1","C|62|100|0|0|9|1|"..stamp,"GUILD","Scout")
    deliver("CHAT_MSG_ADDON","WEFF1","E|62|1|1|"..hash..":M:40|"..stamp,"GUILD","Scout")
    eq(N.Main.findRows()[1].zone,200)
    clientIgnored=false
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
    local N=loadAddon(); warSettings(); chatBox(); friends(N,{})
    -- 0.3.1: a row with a Bulo or LayerSwap layer gets "Hop via"; a War Effort reporter row keeps the chat ask
    advance(1); hello("Alice",19); report(7,9,"Alice")
    local U=N.UI; U.toggle(); U.select("friendly")
    eq(U.pool[1].title.text,"Alice"); eq(U.pool[1].ask.label.text,"Ask for invite")
    local original=N.AskInvite; local calls={}
    N.AskInvite=function(name) calls[#calls+1]=name; return original(name) end
    U.pool[1].ask:Click(); drain(); eq(calls[1],"Alice"); eq(#opened,1)
    eq(U.pool[1].ask.label.text,"Asked · 60s"); yes(U.pool[1].ask.disabled)
    U.pool[1].ask:Click(); eq(#calls,1)
    advance(1); eq(U.pool[1].ask.label.text,"Asked · 59s")
    advance(60); no(U.pool[1].ask.disabled)
    -- a report row: Hop. Its label says who is asked and how before the click; a reporter with no host addon
    -- known gets the prefilled chat whisper, nothing is sent
    hello("Scout",19); report(1,9,"Scout"); U.select("reported"); yes(U.pool[1].ask:IsShown())
    eq(U.pool[1].ask.label.text,"Ask Scout (chat)"); no(U.pool[1].ask.disabled)
    yes(U.pool[1].ask.reason:find("prefilled chat whisper to Scout",1,true))
    U.pool[1].ask:Click(); drain(); eq(#calls,1); eq(#opened,2); eq(opened[2].text,"/w Scout "..ASK); eq(#sent,0)
    U.render(); yes(U.pool[1].ask.disabled); yes(U.pool[1].ask.reason:find("Scout was asked",1,true))
    -- a report whose layer cannot be compared: disabled, with the reason
    report(2,7086,"Other"); U.render()
    local other; for _,row in ipairs(U.pool) do if row:IsShown() and row.sub.text=="reported by Other" then other=row end end
    yes(other); yes(other.ask.disabled); eq(other.ask.reason,"this report's layer cannot be compared with yours.")
    eq(forbidden,0)
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
-- Record model and layer namespaces (Task 2)
local function rec(N,over)
    local t={src="we",kind="group",origin="Scout-TestRealm",via="Scout-TestRealm",route="GUILD",rid="1",zone=100,x=.4,y=.5,count=1,
        enemies={{hash="abc",class="HUNTER",level=40}},layer={ns="server",value="7086"},heard=10,share="guild"}
    for k,v in pairs(over or {}) do t[k]=v end
    return N.Record.new(t)
end
test("relation never crosses namespaces",function()
    local N=loadAddon(); local R=N.Record; local own={zone=100,server="7086"}
    local r=rec(N); yes(r); eq(r.id,"we:scout:1"); eq(R.relation(r,own),"same")
    eq(R.relation(rec(N,{layer={ns="zoneuid",value="7086"}}),own),"unknown")
    eq(R.relation(rec(N,{layer={ns="zoneuid",value=7086}}),own),"unknown")
    eq(R.relation(rec(N,{layer={ns="unknown",value="7086"}}),own),"unknown")
    eq(R.relation(rec(N,{layer={ns="server",value="7087"}}),own),"other")
end)
test("relation is zone scoped",function()
    local N=loadAddon(); local R=N.Record; local r=rec(N)
    eq(R.relation(r,{zone=200,server="7086"}),"unknown"); eq(R.relation(r,{zone=200,server="7087"}),"unknown")
    eq(R.relation(r,{zone=100,server=nil}),"unknown"); eq(R.relation(r,{server="7086"}),"unknown")
    eq(R.relation(nil,{zone=100,server="7086"}),"unknown"); eq(R.relation(r,nil),"unknown")
end)
test("equal server is unknown while ambiguous",function()
    local N=loadAddon(); local R=N.Record
    eq(R.relation(rec(N),{zone=100,server="7086",ambiguous=true}),"unknown")
    eq(R.relation(rec(N,{layer={ns="server",value="7087"}}),{zone=100,server="7086",ambiguous=true}),"other")
end)
test("own server key without Bulo",function()
    local N=loadAddon(); eq(N.Layer.server(N.Main.npcs),nil)
    units.target={guid=npc(1,4),player=false}; deliver("PLAYER_TARGET_CHANGED"); drain(); advance(.1)
    eq(N.Layer.server(N.Main.npcs),nil)
    units.mouseover={guid=npc(2,4),player=false}; deliver("UPDATE_MOUSEOVER_UNIT"); drain(); advance(.1)
    eq(N.Layer.server(N.Main.npcs),"7086"); eq(N.Main.store.bulo,"7086-4")
    eq(N.Layer.server({}),nil); eq(N.Layer.server(nil),nil); eq(N.Layer.server(secret),nil)
end)
test("ambiguity lasts 1800 s",function()
    local N=loadAddon(); local L=N.Layer; local st=L.new()
    L.observe(st,npc(1,4),1); L.observe(st,npc(2,4),2); eq(L.server(st),"7086"); no(L.ambiguous(st,2))
    L.observe(st,npc(3,9),10); local z,old,raw=L.observe(st,npc(4,9),11); eq(raw,"7086-9")
    yes(L.ambiguous(st,11)); yes(L.ambiguous(st,11+1799)); no(L.ambiguous(st,11+1801))
    -- the same-zone reset Main does on a zoneUID transition keeps it; a zone change ends it
    L.reset(st); yes(L.ambiguous(st,100)); eq(L.server(st),"7086")
    L.forget(st); no(L.ambiguous(st,100)); eq(L.server(st),nil)
    -- a changed server part is another layer, not an ambiguity
    st=L.new(); L.observe(st,npc(1,4),1); L.observe(st,npc(2,4),2)
    L.observe(st,npc(3,9,"7087"),10); L.observe(st,npc(4,9,"7087"),11); eq(L.server(st),"7087"); no(L.ambiguous(st,12))
    -- through the addon: zoneUID 4 -> 9 on one server in one zone, then a zone change
    N=loadAddon()
    units.target={guid=npc(1,4),player=false}; deliver("PLAYER_TARGET_CHANGED"); drain(); advance(.1)
    units.mouseover={guid=npc(2,4),player=false}; deliver("UPDATE_MOUSEOVER_UNIT"); drain(); advance(1)
    units.target={guid=npc(3,9),player=false}; deliver("PLAYER_TARGET_CHANGED"); drain(); advance(.1)
    units.mouseover={guid=npc(4,9),player=false}; deliver("UPDATE_MOUSEOVER_UNIT"); drain(); advance(.1)
    yes(L.ambiguous(N.Main.npcs,clock)); yes(N.Main.store.ambiguous and N.Main.store.ambiguous(clock))
    map=200; units.target={guid=npc(5,9),player=false}; deliver("PLAYER_TARGET_CHANGED"); drain()
    no(L.ambiguous(N.Main.npcs,clock))
end)
test("an unreadable map does not end the zone epoch",function()
    local function see(id,uid) units.target={guid=npc(id,uid),player=false}; deliver("PLAYER_TARGET_CHANGED"); drain(); advance(.1) end
    local function ambiguousAddon()
        local N=loadAddon(); establish(N); see(3,9); see(4,9)
        yes(N.Layer.ambiguous(N.Main.npcs,clock)); eq(N.Layer.server(N.Main.npcs),"7086")
        return N
    end
    -- same zone -> loading screen without a map -> same zone: raw id and ambiguity survive
    local N=ambiguousAddon()
    map=nil; deliver("PLAYER_ENTERING_WORLD"); drain(); eq(N.Main.store.zone,nil)
    yes(N.Layer.ambiguous(N.Main.npcs,clock)); eq(N.Layer.server(N.Main.npcs),"7086")
    map=100; deliver("ZONE_CHANGED_NEW_AREA"); drain(); eq(N.Main.store.zone,100)
    yes(N.Layer.ambiguous(N.Main.npcs,clock)); eq(N.Layer.server(N.Main.npcs),"7086"); yes(N.Main.store.ambiguous(clock))
    -- twice in a row changes nothing either
    map=nil; deliver("PLAYER_ENTERING_WORLD"); drain(); deliver("SHARD_TRANSFER"); drain(); map=100; N.Main.poll()
    yes(N.Layer.ambiguous(N.Main.npcs,clock))
    -- zone A -> no map -> zone B: forgotten
    N=ambiguousAddon()
    map=nil; deliver("PLAYER_ENTERING_WORLD"); drain(); yes(N.Layer.ambiguous(N.Main.npcs,clock))
    map=200; deliver("ZONE_CHANGED_NEW_AREA"); drain()
    no(N.Layer.ambiguous(N.Main.npcs,clock)); eq(N.Layer.server(N.Main.npcs),nil)
    -- zone A -> zone B (layer confirmed there) -> zone A: B's raw id is forgotten on the way back
    N=ambiguousAddon(); map=200; deliver("ZONE_CHANGED_NEW_AREA"); drain(); eq(N.Layer.server(N.Main.npcs),nil)
    units.target={guid=npc(21,5,"8000"),player=false}; deliver("PLAYER_TARGET_CHANGED"); drain(); advance(.1)
    units.mouseover={guid=npc(22,5,"8000"),player=false}; deliver("UPDATE_MOUSEOVER_UNIT"); drain(); advance(.1)
    eq(N.Layer.server(N.Main.npcs),"8000")
    map=100; deliver("ZONE_CHANGED_NEW_AREA"); drain()
    no(N.Layer.ambiguous(N.Main.npcs,clock)); eq(N.Layer.server(N.Main.npcs),nil); no(N.Main.error)
    -- the very first zone change after login, with no boundary before it, still ends the epoch
    N=loadAddon(); establish(N); eq(N.Layer.server(N.Main.npcs),"7086")
    map=200; deliver("ZONE_CHANGED_NEW_AREA"); drain(); eq(N.Layer.server(N.Main.npcs),nil)
end)
test("record rejects bad fields",function()
    local N=loadAddon()
    local function bad(over,why) local r,reason=rec(N,over); eq(r,nil,why); yes(reason,why) end
    bad({count=201},"count 201 (War Effort's maximum is 200)"); local many={}; for i=1,81 do many[i]={hash="abc"} end; bad({enemies=many},"81 enemies")
    bad({layer={ns="bulo",value="7086"}},"unknown ns"); bad({layer=false},"no layer"); bad({origin="A"},"1-byte origin")
    bad({origin=string.rep("a",101)},"origin 101"); bad({src="xx"},"src"); bad({kind="raid"},"kind"); bad({route="CHANNEL"},"route")
    bad({rid=string.rep("1",25)},"rid 25"); bad({x=1.5},"x"); bad({zone=0},"zone"); bad({share="all"},"share"); bad({heard=secret},"secret heard")
    bad({origin=secret},"secret origin"); bad({enemies={{level=secret}}},"secret enemy")
    eq(N.Record.new(nil),nil); eq(N.Record.new(secret),nil)
    -- 80 enemies and count 80 are fine; a server value must be a server key
    for i=1,80 do many[i]={hash="abc"} end; many[81]=nil; yes(rec(N,{enemies=many,count=80}))
    bad({layer={ns="server",value="x7"}},"server value")
    local r=rec(N,{label="War Effort",age=5}); eq(r.label,"War Effort"); eq(r.age,5); eq(r.layer.ns,"server")
end)
test("store relation uses the record",function()
    local N=loadAddon(); establish(N); advance(1)
    report(1,7); local rows=N.Store.rows(N.Main.store,clock,"reported")
    eq(#rows,1); eq(rows[1].relation,"unknown"); eq(rows[1].record.layer.ns,"unknown"); eq(rows[1].record.src,"we")
    eq(rows[1].record.origin,"Other"); eq(rows[1].record.share,"guild")
    SlashCmdList.LAYERENEMIES("list"); yes(logged("Your server key: 7086")); no(logged("War Effort zoneUID"))
end)
test("tracking a name looks through reports already stored (records)",function()
    local N=loadAddon(); establish(N); warSettings(); advance(1)
    local hash=N.Hash.player("Alice","Test Realm"); local stamp=math.floor(server)%3600
    deliver("CHAT_MSG_ADDON","WEFF1","C|1|100|0.4|0.5|7|1|"..stamp,"GUILD","Scout")
    deliver("CHAT_MSG_ADDON","WEFF1","E|1|1|1|"..hash..":H:40|"..stamp,"GUILD","Scout")
    eq(N.Main.lastDrop,"enriched"); no(N.Main.find.locations.Alice)
    N.Main.track("Alice"); local loc=N.Main.find.locations.Alice
    yes(loc); eq(loc.spotter,"Scout"); eq(loc.zone,100); eq(loc.level,40); no(N.Main.error)
end)
-- Task 5: one-click hop
-- a hop as the user makes it: preview, then click on what was shown
local function hopNow(N,record) return N.Main.hopTo(record,N.Main.hopPreview(record)) end
local function hopReport(id,key,who) hello(who or "Scout",19); report(id,key,who or "Scout") end
local function rec(N,over)
    local t={src="we",kind="group",origin="Scout",via="Scout",route="GUILD",rid="1",zone=100,count=1,layer={ns="server",value="8000"},heard=clock,share="guild"}
    for k,v in pairs(over or {}) do t[k]=v end
    return assert(N.Record.new(t))
end
test("hop line matches the LayerSwap grammar",function()
    local N=loadAddon(); local H=N.Hop
    eq(H.line(1429,"7086",nil,.482,.425),"inv layer <LS 1429 want 7086-0 48.2,42.5>")
    eq(H.line(1429,"7086",12,.482,.425),"inv layer <LS 1429 want 7086-12 48.2,42.5>")
    eq(H.line(1429,"7091",3),"inv layer <LS 1429 want 7091-3>")
    eq(H.line(1429,"7091",0,1,0),"inv layer <LS 1429 want 7091-0 100.0,0.0>")
    eq(H.line(1429,"7091",0,1.2,.5),"inv layer <LS 1429 want 7091-0>")
    eq(H.line(nil,"7086"),nil); eq(H.line(1429,"x7"),nil); eq(H.line(1429,"7086-4"),"inv layer <LS 1429 want 7086-0>"); eq(H.line(1429,"7086",-1),nil); eq(H.line(14.5,"7086"),nil)
    -- what LayerSwap and Bulo parse out of it (study: first <LS...>, zone, want id, trailing pair within 0..100)
    local body=H.line(1429,"7086",12,.482,.425):match("^inv layer <LS([^<>]*)>$")
    eq(body:match("^%s*(%d+)"),"1429"); eq(body:match("want%s+(%d+%-%d+)"),"7086-12"); eq(body:match("(%d+%.?%d*),(%d+%.?%d*)%s*$"),"48.2")
end)
test("hop sends exactly one whisper per click",function()
    local N=loadAddon(); friends(N,{Bob=there({host=true}),Alice=there()},{Cora=page()}); advance(1)
    hopReport(1,8000)
    SlashCmdList.LAYERENEMIES("reports")
    yes(logged("[1] /le hop 1: one LayerSwap request whispered to Bob (Bulo)"))
    SlashCmdList.LAYERENEMIES("hop 1"); drain()
    eq(#sent,1); eq(sent[1].prefix,"LayerSwap"); eq(sent[1].kind,"WHISPER"); eq(sent[1].target,"Bob")
    eq(sent[1].text,"inv layer <LS 100 want 8000-0 25.0,75.0>"); eq(#opened,0); eq(forbidden,0)
    yes(logged("asked Bob (Bulo) for an invite to layer 8000. Accept the invite yourself; nothing else is sent."))
    eq(N.Main.invite.pending.name,"Bob"); eq(N.Main.hop.pending.name,"Bob")
    -- a LayerSwap book entry comes with the host's zoneUID; it goes before a Bulo line without the host flag
    N=loadAddon(); friends(N,{Alice=there()},{Cora=page({layer="8000-13"})}); advance(1); hopReport(1,8000)
    SlashCmdList.LAYERENEMIES("reports"); SlashCmdList.LAYERENEMIES("hop 1"); drain()
    eq(#sent,1); eq(sent[1].target,"Cora"); eq(sent[1].text,"inv layer <LS 100 want 8000-13 25.0,75.0>")
    -- no position on a child map: the line goes without it
    N=loadAddon(); friends(N,{Bob=there({host=true})}); advance(1); hopReport(1,8000)
    map=101; yes(hopNow(N,N.Store.rows(N.Main.store,clock,"reported")[1].record)); eq(#sent,1); eq(sent[1].text,"inv layer <LS 100 want 8000-0>")
    -- the map already shows another zone (no event yet): the live zone decides, so nothing is sent (مانع T5 S1)
    advance(61); map=200; no(hopNow(N,N.Store.rows(N.Main.store,clock,"reported")[1].record)); eq(#sent,1); yes(log[#log]:find("travel to",1,true))
end)
test("hop refuses when grouped, other zone, zoneuid layer, same layer, no candidate",function()
    local N=loadAddon(); friends(N,{Bob=there({host=true})}); advance(1)
    local function refused(record,text)
        local before=#log
        no(hopNow(N,record)); eq(#sent,0); yes(log[#log]:find(text,1,true),text); yes(#log>before)
    end
    grouped=true; refused(rec(N),"leave your current group first"); grouped=false
    refused(rec(N,{zone=200}),"travel to "); refused(rec(N,{layer={ns="zoneuid",value=8000}}),"cannot be compared")
    refused(rec(N,{layer={ns="unknown",value=8000}}),"cannot be compared")
    refused(rec(N,{layer={ns="server",value="7086"}}),"on your layer already")
    -- no one known on that layer: since 0.4.0 the guild-chat request is drafted instead (no chat box here: the line
    -- is printed to type); no addon message either way
    yes(hopNow(N,rec(N,{src="guild",layer={ns="server",value="9500"}}))); eq(#sent,0); yes(logged("/g inv layer <LS 100 want 9500-0"))
    -- unknown own zone
    N.Main.store.zone=nil; refused(rec(N),"your zone is not known"); eq(#opened,0); eq(forbidden,0)
end)
test("hop cooldown blocks a second click",function()
    local N=loadAddon(); friends(N,{Bob=there({host=true}),Dan=there({key="9000",host=true})}); advance(1)
    yes(hopNow(N,rec(N))); eq(#sent,1)
    no(hopNow(N,rec(N))); eq(#sent,1); yes(log[#log]:find("Bob was asked 0 s ago",1,true))
    advance(5); no(hopNow(N,rec(N,{rid="2",layer={ns="server",value="9000"}}))); eq(#sent,1); yes(log[#log]:find("one ask every 10 s",1,true))
    advance(5); yes(hopNow(N,rec(N,{rid="2",layer={ns="server",value="9000"}}))); eq(#sent,2); eq(sent[2].target,"Dan")
    advance(10); no(hopNow(N,rec(N))); eq(#sent,2)
    advance(41); yes(hopNow(N,rec(N))); eq(#sent,3)
end)
test("hop does not retry on throttle",function()
    local N=loadAddon(); friends(N,{Bob=there({host=true})}); advance(1)
    sendResult=3; no(hopNow(N,rec(N))); eq(#sent,1); yes(log[#log]:find("throttling whispers; not sent",1,true))
    eq(N.Main.hop.pending,nil); eq(N.Main.invite.pending,nil)
    advance(300); eq(#sent,1)
    -- 1.0 T1: a channel throttle (8) is a throttle too (the prefix pauses 30 s); another refusal (1) is "refused"
    sendResult=8; advance(61); no(hopNow(N,rec(N))); eq(#sent,2); yes(log[#log]:find("throttling whispers; not sent",1,true))
    sendResult=1; advance(61); no(hopNow(N,rec(N))); eq(#sent,3); yes(log[#log]:find("refused the whisper",1,true))
    sendResult=function() error("boom") end; advance(61); no(hopNow(N,rec(N))); eq(#sent,4); yes(log[#log]:find("could not be sent",1,true))
    advance(300); eq(#sent,4); eq(forbidden,0)
end)
test("hop parses heard for me and ignores heard for others",function()
    local N=loadAddon(); local H=N.Hop
    local r=H.reply("heard Tam Reed|7091-3|1429|h","Bob","Tam Reed"); eq(r.kind,"heard"); eq(r.layer,"7091-3"); eq(r.zone,1429); yes(r.hosting)
    r=H.reply("heard Tam Reed|-|1429|-","Bob","Tam Reed"); eq(r.layer,nil); no(r.hosting)
    -- malformed fields make the reply unreadable (مانع T5 S2)
    eq(H.reply("heard Tam Reed|7091-3|1429|x","Bob","Tam Reed"),nil); eq(H.reply("heard Tam Reed|7091-3|1429|","Bob","Tam Reed"),nil)
    eq(H.reply("heard Tam Reed|7091|1429|h","Bob","Tam Reed"),nil); eq(H.reply("heard Tam Reed|7091-3|14x|h","Bob","Tam Reed"),nil)
    eq(H.reply("heard Tam Reed|7091-3||h","Bob","Tam Reed"),nil); eq(H.reply("heard Tam Reed|7091-3|1429|h\1","Bob","Tam Reed"),nil)
    eq(H.reply("heard Tam Reed|-|-|-","Bob","Tam Reed").zone,nil)
    eq(H.reply("heard Aya Stone|7091-3|1429|h","Bob","Tam Reed"),nil); eq(H.reply("heard Tam Reed|7091-3|1429","Bob","Tam Reed"),nil)
    eq(H.reply(secret,"Bob","Me"),nil)
    friends(N,{Bob=there({host=true})}); advance(1); yes(hopNow(N,rec(N)))
    local function reply(text,from) deliver("CHAT_MSG_ADDON","LayerSwap",text,"WHISPER",from or "Bob"); drain() end
    reply("heard Someone Else|8000-13|100|h"); eq(lines("heard you"),0)
    reply("heard Me|8000-13|100|h","Cora"); eq(lines("heard you"),0)
    deliver("CHAT_MSG_ADDON","LayerSwap","heard Me|8000-13|100|h","GUILD","Bob"); eq(lines("heard you"),0)
    reply("heard Me|8000-13|100|h"); yes(logged("LayerEnemies: Bob heard you (layer 8000-13, hosting: yes)."))
    reply("heard Me|-|100|-","Bob-TestRealm"); yes(logged("LayerEnemies: Bob heard you (layer unknown, hosting: no)."))
    advance(121); reply("heard Me|8000-13|100|h"); eq(lines("heard you"),2); eq(#sent,1)
end)
test("hop parses same",function()
    local N=loadAddon(); eq(N.Hop.reply("same","Bob","Me").kind,"same"); eq(N.Hop.reply("same ","Bob","Me"),nil); eq(N.Hop.reply("SAME","Bob","Me"),nil)
    friends(N,{Bob=there({host=true})}); advance(1)
    deliver("CHAT_MSG_ADDON","LayerSwap","same","WHISPER","Bob"); eq(lines("on their layer"),0)   -- nothing asked yet
    yes(hopNow(N,rec(N)))
    deliver("CHAT_MSG_ADDON","LayerSwap","same","WHISPER","Bob"); yes(logged("LayerEnemies: Bob says you're on their layer."))
end)
test("hop ignores inv layer requests and sends no heard",function()
    local N=loadAddon(); establish(N); friends(N,{Bob=there({host=true})}); advance(1)
    local before=#log
    for _,kind in ipairs({"WHISPER","GUILD","PARTY"}) do
        deliver("CHAT_MSG_ADDON","LayerSwap","inv layer <LS 100 want 7086-7 50.0,50.0>",kind,"Stranger")
        deliver("CHAT_MSG_ADDON","LayerSwap","inv layer <LS 100 not 8000-1 50.0,50.0>",kind,"Bob")
        deliver("CHAT_MSG_ADDON","LayerSwap","claim Me",kind,"Bob")
        deliver("CHAT_MSG_ADDON","LayerSwap","want 7086-7",kind,"Bob")
    end
    yes(hopNow(N,rec(N))); eq(#sent,1)
    deliver("CHAT_MSG_ADDON","LayerSwap","inv layer <LS 100 want 7086-7 50.0,50.0>","WHISPER","Bob")
    eq(#sent,1); eq(#log,before+1); eq(forbidden,0); no(N.Main.error)
end)
test("hop works while LayerSwap and Bulo are loaded",function()
    local N=loadAddon(); loaded.LayerSwap=true; loaded.BuloLayerForever=true
    local b=friends(N,{Bob=there({host=true})},{Cora=page({layer="8000-13"})}); advance(1)
    local function snapshot(t,depth)
        local out={}; for k,v in pairs(t) do out[#out+1]=tostring(k).."="..(type(v)=="table" and depth<3 and "{"..snapshot(v,depth+1).."}" or tostring(v)) end
        table.sort(out); return table.concat(out,",")
    end
    local bulo,book=snapshot(b.Guild,0),snapshot(LayerSwapDB,0)
    hopReport(1,8000); SlashCmdList.LAYERENEMIES("reports"); SlashCmdList.LAYERENEMIES("hop 1"); drain()
    eq(#sent,1); eq(sent[1].target,"Bob")
    deliver("CHAT_MSG_ADDON","LayerSwap","heard Me|8000-13|100|h","WHISPER","Bob"); yes(logged("Bob heard you (layer 8000-13, hosting: yes)."))
    deliver("CHAT_MSG_ADDON","LayerSwap","same","WHISPER","Bob"); yes(logged("Bob says you're on their layer."))
    deliver("CHAT_MSG_ADDON","LFSw","L 8000|100|h","GUILD","Bob"); deliver("CHAT_MSG_ADDON","LFSw","v 3.0.25","WHISPER","Bob")
    -- their saved data and live tables are only read
    eq(snapshot(b.Guild,0),bulo); eq(snapshot(LayerSwapDB,0),book); eq(#sent,1); eq(forbidden,0); no(N.Main.error)
end)
test("hop state clears on zone change and reload",function()
    local N=loadAddon(); friends(N,{Bob=there({host=true})}); advance(1)
    yes(hopNow(N,rec(N))); yes(N.Main.hop.pending); yes(N.Main.invite.pending)
    -- a same-zone transfer is what a hop causes: kept
    deliver("SHARD_TRANSFER"); drain(); yes(N.Main.hop.pending); yes(N.Main.invite.pending)
    map=nil; deliver("PLAYER_ENTERING_WORLD"); drain(); map=100; deliver("ZONE_CHANGED_NEW_AREA"); drain(); yes(N.Main.hop.pending)
    map=200; deliver("ZONE_CHANGED_NEW_AREA"); drain()
    eq(N.Main.hop.pending,nil); eq(N.Main.invite.pending,nil)
    deliver("CHAT_MSG_ADDON","LayerSwap","heard Me|8000-13|100|h","WHISPER","Bob"); eq(lines("heard you"),0)
    grouped=true; deliver("GROUP_ROSTER_UPDATE"); eq(N.Main.invite.watch,nil); advance(70); eq(lines("Moved to layer"),0)
    -- reload: nothing of a hop survives
    grouped=false; N=loadAddon(); friends(N,{Bob=there({host=true})}); advance(1); yes(hopNow(N,rec(N)))
    N=loadAddon(); eq(N.Main.hop.pending,nil); eq(N.Main.invite.pending,nil)
    deliver("CHAT_MSG_ADDON","LayerSwap","same","WHISPER","Bob"); eq(lines("on their layer"),0)
    for k in pairs(LayerEnemiesDB) do yes(k=="options" or k=="tracked" or k=="position" or k=="guildHost" or k=="autoHop" or k=="consent" or k=="nets" or k=="share" or k=="netNotice",k) end; eq(type(LayerEnemiesDB.guildHost),"boolean")
end)
test("hop acts on the shown candidate only (مانع T5 F1)",function()
    -- shown "Ask Scout (chat)"; an LFSw host line arrives before the click: nothing is sent, nothing drafted
    local N=loadAddon(); chatBox(); establish(N); advance(1); local r=rec(N)
    local shown=N.Main.hopPreview(r); eq(shown.label,"Ask Scout (chat)"); yes(shown.enabled)
    deliver("CHAT_MSG_ADDON","LFSw","L 8000|100|h","GUILD","Mallory")
    eq(N.Main.hopPreview(r).label,"Hop via Mallory")
    no(N.Main.hopTo(r,shown)); drain(); eq(#sent,0); eq(#opened,0); yes(logged("LayerEnemies: hosts changed, check again."))
    eq(N.Safe.count(N.Main.invite.asked),0); eq(N.Main.hop.pending,nil)
    -- no preview at all is refused the same way
    no(N.Main.hopTo(r)); eq(#sent,0)
    -- the new preview is what a second click acts on
    yes(N.Main.hopTo(r,N.Main.hopPreview(r))); eq(#sent,1); eq(sent[1].target,"Mallory")
    -- the same through /le reports + /le hop and through the window button
    N=loadAddon(); chatBox(); establish(N); advance(1); hopReport(1,8000)
    SlashCmdList.LAYERENEMIES("reports"); yes(logged("a prefilled chat whisper to Scout"))
    deliver("CHAT_MSG_ADDON","LFSw","L 8000|100|h","GUILD","Mallory")
    SlashCmdList.LAYERENEMIES("hop 1"); drain(); eq(#sent,0); eq(#opened,0); yes(logged("hosts changed, check again."))
    N=loadAddon(); chatBox(); establish(N); advance(1); hopReport(1,8000); local U=N.UI
    U.toggle(); U.select("reported"); eq(U.pool[1].ask.label.text,"Ask Scout (chat)")
    N.Main.guildLines["Mallory"]={key="8000",zone=100,host=true,at=wall}
    U.pool[1].ask:Click(); drain(); eq(#sent,0); eq(#opened,0)
    eq(U.pool[1].ask.label.text,"Hop via Mallory")                        -- redrawn
    U.pool[1].ask:Click(); drain(); eq(#sent,1); eq(sent[1].target,"Mallory"); eq(#opened,0); eq(forbidden,0)
    -- the same player changing mode (reporter to LFSw host) is a change too
    N=loadAddon(); chatBox(); establish(N); advance(1); r=rec(N); shown=N.Main.hopPreview(r); eq(shown.label,"Ask Scout (chat)")
    deliver("CHAT_MSG_ADDON","LFSw","L 8000|100|h","GUILD","Scout"); eq(N.Main.hopPreview(r).label,"Hop via Scout")
    no(N.Main.hopTo(r,shown)); drain(); eq(#sent,0); eq(#opened,0)
end)
test("hop replies: same wording, ambiguity, full-name sender, route (مانع T5 F2, S2)",function()
    local N=loadAddon(); friends(N,{Bob=there({host=true})}); advance(1)
    yes(hopNow(N,rec(N)))
    -- PARTY, another realm's Bob, and a lookalike are ignored
    deliver("CHAT_MSG_ADDON","LayerSwap","same","PARTY","Bob"); deliver("CHAT_MSG_ADDON","LayerSwap","same","WHISPER","Bob-EvilRealm")
    deliver("CHAT_MSG_ADDON","LayerSwap","same","WHISPER","Bobb"); eq(lines("on their layer"),0)
    -- our own realm written out is still Bob
    N.Main.store.ambiguous=function() return true end
    deliver("CHAT_MSG_ADDON","LayerSwap","same","WHISPER","Bob-TestRealm")
    yes(logged("LayerEnemies: Bob says you're on their layer (probably: your key is ambiguous)."))
    eq(N.Hop.receive({pending={name="Al",short="al",at=0}},"same","Al","Me",1,false),"Al says you're on their layer.")
end)
test("hop: grouping, live zone and per-source host rank (مانع T5 S1, S3)",function()
    -- unreadable IsInGroup refuses
    local N=loadAddon(); friends(N,{Bob=there({host=true})}); advance(1)
    IsInGroup=function() return secret end; no(hopNow(N,rec(N))); yes(log[#log]:find("leave your current group first",1,true))
    IsInGroup=function() error("boom") end; no(hopNow(N,rec(N))); IsInGroup=nil; no(hopNow(N,rec(N))); eq(#sent,0)
    IsInGroup=function() return grouped end
    -- unreadable live map refuses
    map=nil; no(hopNow(N,rec(N))); yes(log[#log]:find("your zone is not known",1,true)); map=100
    yes(hopNow(N,rec(N))); eq(#sent,1)
    -- a Bulo host beats a Bulo non-host who is also a LayerSwap host
    N=loadAddon(); friends(N,{Bob=there({host=true,at=wall-30}),Alice=there({at=wall-1})},{Alice=page({host=true,at=wall-1})}); advance(1)
    local list=N.Main.candidates(); local alice; for _,c in ipairs(list) do if c.name=="Alice" then alice=c end end
    yes(alice.host); eq(alice.hosts.Bulo,false); eq(alice.hosts.LayerSwap,true)
    local c=N.Hop.candidate(rec(N),list); eq(c.name,"Bob"); eq(c.source,"Bulo")
    yes(hopNow(N,rec(N))); eq(sent[#sent].target,"Bob")
    -- without the Bulo host, Alice is asked as a LayerSwap host
    N=loadAddon(); friends(N,{Alice=there({at=wall-1})},{Alice=page({host=true,at=wall-1})}); advance(1)
    c=N.Hop.candidate(rec(N),N.Main.candidates()); eq(c.name,"Alice"); eq(c.source,"LayerSwap")
end)
test("hop: two zone boundaries before a poll end the layer watch (مانع T5 S4)",function()
    local N=loadAddon(); friends(N,{Bob=there({host=true})}); advance(1)
    yes(hopNow(N,rec(N))); grouped=true; deliver("GROUP_ROSTER_UPDATE"); yes(N.Main.invite.watch)
    map=200; deliver("ZONE_CHANGED_NEW_AREA"); map=100; deliver("ZONE_CHANGED_NEW_AREA")
    eq(N.Main.invite.watch,nil); yes(logged("Zone changed - layer check cancelled."))
    drain(); advance(70); eq(lines("Moved to layer"),0); eq(lines("Still on your layer"),0); grouped=false
end)
test("hop: a failed send keeps the cooldown",function()
    local N=loadAddon(); friends(N,{Bob=there({host=true})}); advance(1)
    sendResult=3; no(hopNow(N,rec(N))); eq(#sent,1)
    sendResult=nil; no(hopNow(N,rec(N))); eq(#sent,1); yes(log[#log]:find("Bob was asked 0 s ago",1,true))
    advance(5); no(hopNow(N,rec(N,{rid="2",layer={ns="server",value="9000"}}))); eq(#sent,1); yes(log[#log]:find("one ask every 10 s",1,true))
end)
test("claims are keyed by full name; HeadHunter never compares (T3/T4 leftovers)",function()
    local N=loadAddon()
    local env={ownKey="8000",wall=1000,zone=100,bulo={["Scout-RealmA"]={key="8000",zone=100,host=false,at=990}}}
    eq(N.Invite.sameSpotter("Scout-RealmA",env),true); eq(N.Invite.sameSpotter("Scout-RealmB",env),false); eq(N.Invite.sameSpotter("Scout",env),false)
    local _,a=N.Invite.name("Scout-RealmA"); local _,b=N.Invite.name("Scout-RealmB"); yes(a~=b)
    local _,c=N.Invite.name("Bob"); local _,d=N.Invite.name("Bob-TestRealm"); eq(c,d)
    -- a hand-built HeadHunter record with a server layer is still not comparable
    local own={zone=100,server="8000"}
    eq(N.Record.relation(rec(N,{src="hh",kind="fight",share="public"}),own),"unknown")
    eq(N.Record.relation(rec(N,{src="hh",kind="fight",share="public",layer={ns="server",value="9000"}}),own),"unknown")
    eq(N.Record.relation(rec(N),own),"same"); eq(N.Record.relation(rec(N,{layer={ns="server",value="9000"}}),own),"other")
end)
test("/le hop numbers do not survive a zone change (r2)",function()
    local N=loadAddon(); friends(N,{Bob=there({host=true})}); advance(1); hopReport(1,8000)
    SlashCmdList.LAYERENEMIES("reports"); yes(N.Main.hopList)
    map=200; deliver("ZONE_CHANGED_NEW_AREA"); map=100; deliver("ZONE_CHANGED_NEW_AREA"); drain()
    eq(N.Main.hopList,nil)
    SlashCmdList.LAYERENEMIES("hop 1"); drain(); eq(#sent,0); yes(logged("run /le reports first"))
    -- a same-zone transfer (an unreadable map) keeps them
    N=loadAddon(); friends(N,{Bob=there({host=true})}); advance(1); hopReport(1,8000)
    SlashCmdList.LAYERENEMIES("reports"); deliver("SHARD_TRANSFER"); drain(); yes(N.Main.hopList)
end)
test("guild L line without Bulo fills the host list",function()
    local N=loadAddon(); establish(N); advance(1)
    local function line(text,from,kind) deliver("CHAT_MSG_ADDON","LFSw",text,kind or "GUILD",from) end
    line("L 8000|100|h","Bob"); line("L 9000|100|-","Dan Lee-OtherRealm"); line("L 8000|100|-","Me"); line("L 8000|100|-","Me-TestRealm")
    eq(N.Main.guildLines["Me"],nil); eq(N.Main.guildLines["Me-TestRealm"],nil); yes(N.Main.guildLines["Bob"])
    for _,bad in ipairs({"L 8000-3|100|h","L 8000|100|x","L 8000|100|h|x","L |100|h","L 8000|1a|h","Q","v 3.0.25"}) do line(bad,"Eve") end
    line("L 8000|100|h","Wes","WHISPER"); line("L 8000|100|h","Pat","PARTY")
    -- (0.4.0 review S2/M1: one name rule; another realm stays in the name, also for a spaced name)
    local list=N.Main.candidates(); eq(names(list),"Bob,Dan Lee-OtherRealm")
    eq(list[1].layer,"8000"); yes(list[1].host); eq(table.concat(list[1].sources,"+"),"Bulo")
    yes(hopNow(N,rec(N))); eq(sent[1].target,"Bob"); eq(sent[1].text,"inv layer <LS 100 want 8000-0 25.0,75.0>"); eq(#sent,1)
    -- not in a guild, or ignored: not read
    inGuild=false; line("L 7000|100|h","Gus"); inGuild=true
    clientIgnored=true; line("L 7000|100|h","Ivy"); clientIgnored=false
    eq(#N.Main.candidates(),2)
    -- 720 s freshness
    advance(720); line("L 9500|100|h","Fay"); eq(names(N.Main.candidates()),"Fay"); eq(N.Safe.count(N.Main.guildLines),1)
    -- 256 lines at most
    local many={}; for i=1,300 do N.Adapters.guildLine(many,"L 8000|100|h","Name"..string.char(97+i%26)..string.char(97+math.floor(i/26)%26),1000+i) end
    yes(N.Safe.count(many)<=256)
    eq(forbidden,0); no(N.Main.error)
end)
test("hop: own layer is the confirmed one, never a stale server key (مانع T2 S2)",function()
    local N=loadAddon(); establish(N); friends(N,{Bob=there({key="7086",host=true})}); advance(1)
    deliver("SHARD_TRANSFER"); drain()
    eq(N.Main.store.bulo,nil); eq(N.Layer.server(N.Main.npcs),"7086")      -- the raw id is kept for the ambiguity window
    eq(N.Store.own(N.Main.store,clock).server,nil)
    -- a report on 7086 is not "on your layer": our layer is not known after the transfer. (Bulo/LayerSwap lists
    -- need our own key, so the War Effort reporter is the one asked, by chat whisper.) The 0.3.1 S1 refusal covers
    -- only a reporter that is a Bulo/LayerSwap row seen while our layer is unknown; Scout is none.
    chatBox()
    local r=rec(N,{layer={ns="server",value="7086"}}); eq(N.Record.relation(r,N.Store.own(N.Main.store,clock)),"unknown")
    yes(hopNow(N,r)); drain(); eq(#sent,0); eq(#opened,1); eq(opened[1].text,"/w Scout "..ASK); eq(lines("on your layer already"),0)
    SlashCmdList.LAYERENEMIES("list"); yes(logged("Your server key: Unknown")); yes(logged("Your layer: Unknown"))
end)
test("hop: an ambiguous own key is never a certain same layer (مانع T2 S3)",function()
    local function see(N,u,id,uid) units[u]={guid=npc(id,uid),player=false}; deliver(u=="target" and "PLAYER_TARGET_CHANGED" or "UPDATE_MOUSEOVER_UNIT"); drain(); advance(.1) end
    local N=loadAddon(); establish(N); see(N,"target",3,9); see(N,"mouseover",4,9); see(N,"target",5,9); see(N,"mouseover",6,9)
    yes(N.Main.store.ambiguous(clock)); eq(N.Main.store.bulo,"7086-9")
    -- candidate filtering: an equal key stays listed, marked probably
    b=fakeBulo("7086-9"); b.Guild={list={Dora=there({key="7086"}),Bob=there()}}; N.Main.poll()
    local list=N.Main.candidates(); eq(names(list),"Bob,Dora"); yes(list[2].probably); no(list[1].probably)
    SlashCmdList.LAYERENEMIES("hosts"); yes(logged("Dora | layer 7086 (probably your layer: your key is ambiguous)"))
    -- /le find: "probably on your layer", and the ask stays possible
    chatBox(); SlashCmdList.LAYERENEMIES("find Alice")
    local hash=N.Hash.player("Alice",""); local stamp=math.floor(server)%3600
    deliver("CHAT_MSG_ADDON","WEFF1","C|70|100|0|0|9|1|"..stamp,"GUILD","Dora")
    deliver("CHAT_MSG_ADDON","WEFF1","E|70|1|1|"..hash..":M:40|"..stamp,"GUILD","Dora")
    local row=N.Main.findRows()[1]; no(row.same); yes(row.probably); yes(row.canAsk)
    yes(N.Main.findText(row):find("probably on your layer (your server key is ambiguous)",1,true)); no(N.Main.findText(row):find("already on your layer",1,true))
    -- a report on our key: relation unknown, so a hop is not refused as "on your layer"
    eq(N.Record.relation(rec(N,{layer={ns="server",value="7086"}}),N.Store.own(N.Main.store,clock)),"unknown")
    -- the deadline line: "probably" still on your layer
    advance(11); yes(LE.AskInvite("Bob")); grouped=true; deliver("GROUP_ROSTER_UPDATE"); advance(61)
    yes(logged("Probably still on your layer (your server key is ambiguous) - leave, wait a minute, try again."))
    eq(lines("Still on your layer - leave"),0)
    -- once the window is over the old wording comes back
    N=loadAddon(); establish(N); friends(N,{Bob=there()}); yes(LE.AskInvite("Bob")); grouped=true; deliver("GROUP_ROSTER_UPDATE"); advance(61)
    yes(logged("Still on your layer - leave, wait a minute, try again.")); eq(lines("Probably still"),0)
end)
test("ask texts: no promise about leaving, server-key wording",function()
    local N=loadAddon()
    eq(N.Invite.MESSAGE,"Hi! Could you invite me to your layer please?"); no(N.Invite.MESSAGE:find("leave",1,true))
    establish(N); local _,status=N.Main.candidates(); eq(status.reports,"0 not on your server key")
    for _,file in ipairs({"Invite","Main","UI"}) do
        local f=io.open("LayerEnemies/"..file..".lua"); local src=f:read("*a"); f:close()
        no(src:find("on another zoneUID",1,true),file); no(src:find("leave right after",1,true),file)
    end
end)
-- HeadHunter 1.1.1 (study/headhunter.md §3.3 fixtures: map 1424 = "13k", t 1800000000 = "tro8w0", .5 = "dw", .25 = "6y")
local HHT=1800000000
local HHP="1AP:13k;tro8w0;dw;6y;0000002A,0000002B,+00000001;Kora Reed/P/31;4"
local HHE="1AE:eu-pvp;Mira Vale;A;5cy;1;tro8w0;P13k;tro8w0;dw;6y;0000002A,0000002B,+00000001;Kora Reed/P/31;4"
local function b36(n) local d,s="0123456789abcdefghijklmnopqrstuvwxyz",""; repeat local r=n%36; s=d:sub(r+1,r+1)..s; n=(n-r)/36 until n==0; return s end
local function hh(N,text,sender,at,faction) return N.HeadHunter.decode(text,sender or "Fighter",at or HHT,faction or "Alliance",{heard=50,route="WHISPER"}) end
test("hh decodes a 7-field P with names and layer",function()
    local N=loadAddon(); local list,why=hh(N,HHP)
    eq(#list,1); eq(why,"ok"); local r=list[1]
    eq(r.src,"hh"); eq(r.kind,"fight"); eq(r.origin,"Fighter"); eq(r.via,"Fighter"); eq(r.route,"WHISPER"); eq(r.zone,1424)
    eq(r.x,.5); eq(r.y,.25); eq(r.count,2); eq(#r.enemies,1); eq(r.enemies[1].name,"Kora Reed"); eq(r.enemies[1].class,"PALADIN")
    eq(r.enemies[1].level,31); eq(r.layer.ns,"zoneuid"); eq(r.layer.value,4); eq(r.rid,"1800000000"); eq(r.share,"public"); eq(r.age,0); eq(r.heard,50)
    -- skull level, unknown class and level, empty coordinates and layer, three names
    r=hh(N,"1AP:13k;tro8w0;;;a1,b2,c3;Ann Lee//s,Bo Ray/M/60,Cy Fox/W/;")[1]
    yes(r); eq(r.count,3); eq(r.enemies[1].level,-1); eq(r.enemies[1].class,nil); eq(r.enemies[2].class,"MAGE"); eq(r.enemies[3].level,nil)
    eq(r.x,nil); eq(r.y,nil); eq(r.layer.ns,"unknown")
    -- 12 enemy ids and 12 allies are the limit; 1000 would be 1.0 and is refused, 999 is .999
    local ids={}; for i=1,12 do ids[#ids+1]="e"..i; ids[#ids+1]="+a"..i end
    eq(hh(N,"1AP:13k;tro8w0;rr;0;"..table.concat(ids,","))[1].count,12); eq(hh(N,"1AP:13k;tro8w0;rr;0;a1")[1].x,.999)
end)
test("hh decodes a 5-field P",function()
    local N=loadAddon()
    local r=hh(N,"1AP:13k;tro8w0;dw;6y;0000002A,+00000001")[1]
    yes(r); eq(r.count,1); eq(#r.enemies,0); eq(r.layer.ns,"unknown"); eq(r.kind,"fight")
    local list=hh(N,"1AP:13k;tro8w0;dw;6y;a1~13k;tro8w1;dw;6y;b2"); eq(#list,2); eq(list[2].rid,"1800000001")
end)
test("hh rejects 6-field P and version 2",function()
    local N=loadAddon()
    local list,why=hh(N,"1AP:13k;tro8w0;dw;6y;a1;Kora Reed/P/31"); eq(#list,0); eq(why,"invalid")
    list,why=hh(N,"2AP:13k;tro8w0;dw;6y;0000002A,0000002B,+00000001;Kora Reed/P/31;4"); eq(#list,0); eq(why,"version")
    local ids={}; for i=1,13 do ids[i]="e"..i end
    local bad={"1AP:13k;tro8w0;dw;6y;a1;Kora/P/31;4;x","1AP:13k;tro8w0;dw;6y","1AP:13K;tro8w0;dw;6y;a1","1AP:13k;tro8w0zzzzz;dw;6y;a1",
        "1AP:13k;tro8w0;rs;6y;a1","1AP:13k;tro8w0;dw;6y;"..table.concat(ids,","),"1AP:13k;tro8w0;dw;6y;a1;A b/P/1,B c/P/1,C d/P/1,D e/P/1;4",
        "1AP:13k;tro8w0;dw;6y;a1;Ko|ra/P/31;4","1AP:13k;tro8w0;dw;6y;a1;Kora/P/101;4","1AP:13k;tro8w0;dw;6y;a1;Kora/P/1a;4","1AP:13k;tro8w0;dw;6y;a1;Kora/Z/31;4",
        "1AP:13k;tro8w0;dw;6y;a1;Kora/P;4","1AP:13k;tro8w0;dw;6y;a1;;0","1AP:0;tro8w0;dw;6y;a1","1AP:13k;tro8w0;dw;6y;a-1","1XP:13k;tro8w0;dw;6y;a1",
        "1AP:","1AP13k;tro8w0;dw;6y;a1","1aP:13k;tro8w0;dw;6y;a1","1AP:13k;tro8w0;dw;6y;a1"..string.rep("~",250)}
    for _,text in ipairs(bad) do eq(#hh(N,text),0,text) end
    eq(#hh(N,"1AP:13k;tro8w0;dw;6y;a1"..string.rep(",b",120)),0); eq(#hh(N,secret),0); eq(#hh(N,{}),0)
end)
test("hh unwraps E and keeps author as origin",function()
    local N=loadAddon()
    local list=hh(N,HHE,"Carrier"); eq(#list,1); local r=list[1]
    eq(r.origin,"Mira Vale"); eq(r.via,"Carrier"); eq(r.layer.value,4); eq(r.count,2); eq(r.enemies[1].name,"Kora Reed")
    -- the enveloped P and the author's own direct P are one record
    eq(r.id,hh(N,HHP,"Mira Vale")[1].id)
    yes(hh(N,"1AE:eu-pvp;Mira Vale;A;5cy;1;tro8w0;LKora Reed;13k;tro8w0;dw;6y","Carrier")[1])
    -- several envelopes in one frame
    eq(#hh(N,HHE.."~eu-pvp;Ann Lee;A;5cy;2;tro8w0;P13k;tro8w0;dw;6y;a1","Carrier"),2)
    for _,text in ipairs({"1AE:eu-pvp;Mira Vale;A;5cy;1;tro8w0;Dtro8w0;Mira Vale;u;M;H;13k;dw;6y;i;4;Kora",
        "1AE:eu-pvp;Mira Vale;A;5cy;1;tro8w0;Eeu-pvp;Ann Lee;A;5cy;1;tro8w0;P13k;tro8w0;dw;6y;a1",
        "1AE:eu-pvp;M;A;5cy;1;tro8w0;P13k;tro8w0;dw;6y;a1","1AE:eu-pvp;Mira Vale;X;5cy;1;tro8w0;P13k;tro8w0;dw;6y;a1",
        "1AE:eu-pvp;Mira Vale;A;5cy;1;tro8w0","1AE:eu-pvp;Mira Vale;A;5cy;1;tro8w0;P13k;tro8w0;dw;6y"}) do
        eq(#hh(N,text,"Carrier"),0,text)
    end
end)
test("hh drops other faction",function()
    local N=loadAddon()
    local list,why=hh(N,HHP,nil,nil,"Horde"); eq(#list,0); eq(why,"other faction")
    eq(#hh(N,"1HP:13k;tro8w0;dw;6y;a1",nil,nil,"Horde"),1)
    -- inside E the author's faction counts, not the carrier's header
    eq(#hh(N,"1HE:eu-pvp;Mira Vale;A;5cy;1;tro8w0;P13k;tro8w0;dw;6y;a1","Carrier",nil,"Alliance"),1)
    eq(#hh(N,"1AE:eu-pvp;Mira Vale;H;5cy;1;tro8w0;P13k;tro8w0;dw;6y;a1","Carrier",nil,"Alliance"),0)
    list,why=hh(N,HHP,nil,nil,"Neutral"); eq(#list,0); eq(why,"unavailable")
end)
test("hh L becomes an outlaw record with unknown layer",function()
    local N=loadAddon()
    local r=hh(N,"1AL:Kora Reed;13k;tro8w0;dw;6y","Spotter")[1]
    yes(r); eq(r.kind,"outlaw"); eq(r.src,"hh"); eq(r.layer.ns,"unknown"); eq(r.count,1); eq(#r.enemies,1); eq(r.enemies[1].name,"Kora Reed")
    eq(r.origin,"Spotter"); eq(r.rid,N.Hash.hash3("kora reed")..":1800000000"); eq(r.x,.5); eq(r.share,"public")
    local g=hh(N,"1AL:guid:Player-7091-0000002A;13k;tro8w0;dw;6y")[1]; yes(g); eq(#g.enemies,0); eq(g.count,1)
    eq(#hh(N,"1AL:Kora Reed;13k;tro8w0;dw;6y;4"),0); eq(#hh(N,"1AL:Kora Reed;13k;tro8w0;dw"),0); eq(#hh(N,"1AL:K;13k;tro8w0;dw;6y"),0)
    -- in the window: "wanted (HeadHunter)", the name as reported
    N=loadAddon(); establish(N); advance(1); server=HHT
    deliver("CHAT_MSG_ADDON","HeadHunter","1AL:Kora Reed;2s;"..b36(server)..";dw;6y","WHISPER","Spotter")
    eq(N.Main.lastDrop,"headhunter outlaw")
    local rows=N.Store.rows(N.Main.store,clock,"reported"); eq(#rows,1); eq(rows[1].name,"Kora Reed"); eq(rows[1].source,"wanted (HeadHunter)")
    eq(rows[1].relation,"unknown"); eq(rows[1].positionKind,"observer's position")
    SlashCmdList.LAYERENEMIES("reports"); yes(table.concat(log,"\n"):find("Kora Reed | Unknown class | ? | zone 100 | received 0 s ago | wanted (HeadHunter) | reported, not confirmed | reported by Spotter | observer's position | layer unknown",1,true))
end)
test("hh layer is never comparable",function()
    local N=loadAddon()
    local r=hh(N,"1AP:13k;tro8w0;dw;6y;a1;;"..b36(7086))[1]; eq(r.layer.ns,"zoneuid"); eq(r.layer.value,7086)
    eq(N.Record.relation(r,{zone=1424,server="7086",ambiguous=false}),"unknown")
    eq(N.Record.relation(hh(N,HHP)[1],{zone=1424,server="4",ambiguous=false}),"unknown")
    N=loadAddon(); establish(N); advance(1); server=HHT
    deliver("CHAT_MSG_ADDON","HeadHunter","1AP:2s;"..b36(server)..";dw;6y;a1;;"..b36(7086),"PARTY","Fighter")
    local rows=N.Store.rows(N.Main.store,clock,"reported"); eq(#rows,1); eq(rows[1].relation,"unknown"); eq(rows[1].namespace,"zoneuid")
    eq(rows[1].source,"fight (HeadHunter)"); eq(rows[1].name,"1 not listed"); eq(#N.Store.reporters(N.Main.store,clock),0)
    eq(rows[1].record.share,"public"); eq(rows[1].record.route,"PARTY")
end)
test("hh age window ±300 s",function()
    local N=loadAddon()
    local function at(t) return hh(N,"1AP:13k;"..b36(t)..";dw;6y;a1")[1] end
    yes(at(HHT-300)); eq(at(HHT-300).age,300); yes(at(HHT+300)); eq(at(HHT+300).age,0)
    eq(at(HHT-301),nil); eq(at(HHT+301),nil)
    local _,why=hh(N,"1AP:13k;"..b36(HHT-301)..";dw;6y;a1"); eq(why,"stale")
    eq(#N.HeadHunter.decode(HHP,"Fighter",secret,"Alliance",{heard=1,route="PARTY"}),0)
end)
test("hh ignores N, Q, O, S and sends nothing",function()
    local N=loadAddon(); establish(N); advance(1); server=HHT
    for _,text in ipairs({"1AN:1.1.1","1AQ:h0","1AQ:p0","1AO:5","1AS:E3","1ASY:Kora Reed;2s;tro8w0;dw;6y;Me","1AT:hello",
        "1AD:tro8w0;Mira Vale;u;M;H;2s;dw;6y;i;4;Kora","1AH:5cy","1AJ:Kora Reed;2s;tro8w0;4"}) do
        local sender=text:sub(3,3)=="N" and "Peer" or "Other"
        deliver("CHAT_MSG_ADDON","HeadHunter",text,"WHISPER",sender)
        deliver("CHAT_MSG_ADDON","HeadHunter",text,"PARTY",sender)
    end
    eq(N.Safe.count(N.Main.store.reports),0); eq(#sent,0); eq(forbidden,0); no(N.Main.error)
end)
test("hh routes, duplicates, ignore, rate, ttl and caps in the window",function()
    local N=loadAddon(); establish(N); advance(1); server=HHT
    local function p(who,route,t,extra) deliver("CHAT_MSG_ADDON","HeadHunter","1AP:2s;"..b36(t or server)..";dw;6y;a1"..(extra or ""),route or "PARTY",who) end
    p("Guildie","GUILD"); eq(N.Main.lastDrop,"route")
    deliver("CHAT_MSG_ADDON","HeadHunter","1AP:2s;"..b36(server)..";dw;6y;a1","CHANNEL","Other",nil,nil,7,"HeadHunterSync"); eq(N.Main.lastDrop,"route")
    p("Me-TestRealm","WHISPER"); eq(N.Main.lastDrop,"own echo")
    p("Mira Vale","RAID"); eq(N.Main.lastDrop,"headhunter fight"); eq(N.Safe.count(N.Main.store.reports),1)
    -- the same P carried in an envelope by someone else is one record
    deliver("CHAT_MSG_ADDON","HeadHunter","1AE:eu-pvp;Mira Vale;A;5cy;1;"..b36(server)..";P2s;"..b36(server)..";dw;6y;a1","WHISPER","Carrier")
    eq(N.Main.lastDrop,"duplicate"); eq(N.Safe.count(N.Main.store.reports),1)
    eq(N.Store.rows(N.Main.store,clock,"reported")[1].record.via,"Mira Vale")
    eq(N.Store.rows(N.Main.store,clock,"reported")[1].record.share,"public"); eq(N.Store.rows(N.Main.store,clock,"reported")[1].record.route,"RAID")
    -- an envelope whose author is ignored, or is us
    local old=C_FriendList.IsIgnored; C_FriendList.IsIgnored=function(name) return name=="Bad Guy" end
    deliver("CHAT_MSG_ADDON","HeadHunter","1AE:eu-pvp;Bad Guy;A;5cy;1;"..b36(server)..";P2s;"..b36(server)..";dw;6y;a1","WHISPER","Carrier")
    eq(N.Main.lastDrop,"ignored sender"); C_FriendList.IsIgnored=old
    deliver("CHAT_MSG_ADDON","HeadHunter","1AE:eu-pvp;Me;A;5cy;1;"..b36(server)..";P2s;"..b36(server)..";dw;6y;a1","WHISPER","Carrier")
    eq(N.Main.lastDrop,"own echo"); eq(N.Safe.count(N.Main.store.reports),1)
    deliver("CHAT_MSG_ADDON","HeadHunter","1AE:eu-pvp;Me-TestRealm;A;5cy;1;"..b36(server)..";P2s;"..b36(server)..";dw;6y;a1","WHISPER","Carriertwo")
    eq(N.Main.lastDrop,"own echo"); eq(N.Safe.count(N.Main.store.reports),1)
    -- 6 frames per sender per 10 s; the 7th leaves no trace
    for i=1,7 do p("Busy","PARTY",server-i) end
    eq(N.Safe.count(N.Main.store.reports),7)
    advance(10); p("Busy","PARTY",server); eq(N.Safe.count(N.Main.store.reports),8)
    -- a HeadHunter row lives 300 s
    -- a HeadHunter row lives 300 s from its origin's time (1.0 T2): the batch was 1 to 7 s old when it arrived
    -- (the six accepted batch rows were 1 to 6 s old on arrival, so they leave one per second, oldest first)
    advance(283); N.Store.prune(N.Main.store,clock); eq(N.Safe.count(N.Main.store.reports),8)
    advance(1); N.Store.prune(N.Main.store,clock); eq(N.Safe.count(N.Main.store.reports),7)
    advance(6); N.Store.prune(N.Main.store,clock); eq(N.Safe.count(N.Main.store.reports),1)
    advance(10); N.Store.prune(N.Main.store,clock); eq(N.Safe.count(N.Main.store.reports),0)
    -- 64 HeadHunter rows at most, and they never crowd out War Effort reports
    for i=1,70 do p("Fighter"..abc(i),"PARTY") end
    eq(N.Safe.count(N.Main.store.reports),64); eq(N.Main.lastDrop,"report cap")
    report(1,7,"Scout"); eq(N.Main.lastDrop,"enriched"); eq(N.Safe.count(N.Main.store.reports),65)
    -- party/raid pings go on to the guild (Task 6); nothing on any other prefix or route
    yes(#sent>0); for _,m in ipairs(sent) do eq(m.prefix,"LEGW1"); eq(m.kind,"GUILD") end
    eq(forbidden,0); no(N.Main.error)
end)
-- Task 6: guild relay (LEGW1)
local function hx(s) return (s:gsub(".",function(c) return string.format("%02x",c:byte()) end)) end
local function weRec(N,over)
    local t={src="we",kind="group",origin="Scout",via="Scout",route="PARTY",rid="1",zone=100,x=.4,y=.5,count=2,
        enemies={{hash="abc",class="MAGE",level=40},{hash="def"}},layer={ns="server",value="8000"},heard=100,age=5,share="public"}
    for k,v in pairs(over or {}) do t[k]=v end
    return assert(N.Record.new(t))
end
local function relayed(N) local out={}; for _,m in ipairs(sent) do if m.prefix=="LEGW1" then out[#out+1]=m end end; return out end
test("relay round-trips a we record and an hh record",function()
    local N=loadAddon(); local R=N.Relay
    local text=R.encode(weRec(N),110)
    eq(text,"R|1|we|group|"..hx("Scout").."|1|100|400|500|2|s|8000|15|abc:MAGE:40,def::")
    local r=R.decode(text,"Relayer",200)
    yes(r); eq(r.src,"guild"); eq(r.label,"we"); eq(r.kind,"group"); eq(r.origin,"Scout"); eq(r.via,"Relayer"); eq(r.route,"GUILD")
    eq(r.rid,"1"); eq(r.zone,100); eq(r.x,.4); eq(r.y,.5); eq(r.count,2); eq(r.layer.ns,"server"); eq(r.layer.value,"8000")
    eq(r.heard,185); eq(r.share,"guild"); eq(#r.enemies,2); eq(r.enemies[1].hash,"abc"); eq(r.enemies[1].class,"MAGE"); eq(r.enemies[1].level,40)
    eq(r.enemies[2].hash,"def"); eq(r.enemies[2].class,nil); eq(r.id,"guild:scout:1"); eq(R.key(r),"we:scout:1")
    -- an edge coordinate of 1.0 goes as 999 (.999), like HeadHunter's own encoding
    local edge=R.encode(weRec(N,{x=1,y=0}),100); yes(edge:find("|100|999|0|",1,true)); eq(R.decode(edge,"Gee",100).x,.999)
    -- HeadHunter fight with names, a zoneUID layer, no position; and an outlaw
    local hh=assert(N.Record.new({src="hh",kind="fight",origin="Mira Vale",via="Carrier",route="WHISPER",rid="1800000000",zone=100,count=2,
        enemies={{name="Kora Reed",class="PALADIN",level=31},{name="Ann Lee",level=-1}},layer={ns="zoneuid",value=4},heard=100,age=0,share="public"}))
    r=R.decode(R.encode(hh,100),"Relayer",100)
    -- its zoneUID layer is not sent: a relayed HeadHunter record has no layer (r2)
    yes(r); eq(r.label,"hh"); eq(r.kind,"fight"); eq(r.origin,"Mira Vale"); eq(r.x,nil); eq(r.layer.ns,"unknown"); eq(r.layer.value,nil)
    eq(r.enemies[1].name,"Kora Reed"); eq(r.enemies[1].class,"PALADIN"); eq(r.enemies[1].level,31); eq(r.enemies[2].name,"Ann Lee"); eq(r.enemies[2].level,-1)
    local outlaw=assert(N.Record.new({src="hh",kind="outlaw",origin="Spotter",route="PARTY",rid="abc:1800000000",zone=100,count=1,
        enemies={{name="Kora Reed"}},layer={ns="unknown"},heard=100,age=0,share="public"}))
    r=R.decode(R.encode(outlaw,100),"Relayer",100); yes(r); eq(r.kind,"outlaw"); eq(r.rid,"abc:1800000000"); eq(r.layer.ns,"unknown")
    -- end to end: a party report goes to the guild once, after the wait
    N=loadAddon(); establish(N); N.Relay.rand=function() return 2 end; advance(1)
    hello("Scout",19,"PARTY"); report(1,8000,"Scout",nil,"PARTY")
    eq(#relayed(N),0); advance(1); eq(#relayed(N),0); advance(1.1)
    local out=relayed(N); eq(#out,1); eq(out[1].kind,"GUILD"); eq(out[1].target,nil)
    local back=R.decode(out[1].text,"Exx",clock); eq(back.origin,"Scout"); eq(back.layer.value,"8000"); eq(#back.enemies,1); eq(back.enemies[1].hash,"abc")
    advance(200); eq(#relayed(N),1); eq(forbidden,0)
end)
test("relay skips records heard on GUILD",function()
    local N=loadAddon(); establish(N); advance(1)
    hello("Scout",19); report(1,8000,"Scout"); advance(5); eq(#sent,0)
    no(N.Relay.offer(N.Main.relay,weRec(N,{route="GUILD",share="guild"}),clock,{inGuild=true,inInstance=false,guild="Test Guild"}))
    no(N.Relay.offer(N.Main.relay,weRec(N,{share="guild"}),clock,{inGuild=true,inInstance=false,guild="Test Guild"}))
    -- a relayed G from War Effort's own guild path is guild traffic too
    deliver("CHAT_MSG_ADDON","WEFF1",VG,"GUILD","Relay"); advance(5); eq(#sent,0)
end)
test("relay never re-relays a guild record",function()
    local N=loadAddon(); establish(N); advance(1)
    deliver("CHAT_MSG_ADDON","LEGW1",N.Relay.encode(weRec(N,{heard=clock,age=0}),clock),"GUILD","Guildie")
    eq(N.Main.lastDrop,"relayed we"); eq(N.Safe.count(N.Main.store.reports),1)
    advance(5); eq(#sent,0)
    local stored=N.Store.rows(N.Main.store,clock,"reported")[1].record
    no(N.Relay.offer(N.Main.relay,stored,clock,{inGuild=true,inInstance=false,guild="Test Guild"}))
    -- a relay never claims to be first-hand: own/guild/anything but we and hh is refused
    for _,src in ipairs({"own","guild","LEGW1",""}) do
        eq(N.Relay.decode("R|1|"..src.."|group|"..hx("Scout").."|9|100|||1|u||0|","Guildie",clock),nil,src)
    end
end)
test("relay stands down when another guildmate sends first",function()
    local N=loadAddon(); establish(N); N.Relay.rand=function() return 2 end; advance(1)
    hello("Scout",19,"PARTY"); report(1,8000,"Scout",nil,"PARTY")
    yes(N.Main.relay.pending["we:scout:1"])
    advance(1)
    local copy=N.Relay.encode(N.Main.relay.pending["we:scout:1"].record,clock)
    deliver("CHAT_MSG_ADDON","LEGW1",copy,"GUILD","Quick")
    eq(N.Main.relay.pending["we:scout:1"],nil); advance(5); eq(#relayed(N),0)
    -- the guildmate's copy and our first-hand record are one report and one reporter
    eq(N.Safe.count(N.Main.store.reports),1); eq(N.Store.rows(N.Main.store,clock,"reported")[1].record.src,"we")
    eq(#N.Store.reporters(N.Main.store,clock),1)
end)
test("relay sends each id once in 120 s",function()
    local N=loadAddon(); local R=N.Relay; local st=R.new(); local ctx={inGuild=true,inInstance=false,guild="Test Guild"}
    R.rand=function() return .5 end
    local rec=weRec(N); yes(R.offer(st,rec,100,ctx)); eq(#R.tick(st,100.4),0); eq(#R.tick(st,100.5),1)
    no(R.offer(st,rec,160,ctx)); no(R.offer(st,weRec(N,{route="RAID"}),219,ctx))
    yes(R.offer(st,rec,220,ctx))
    -- two guildmates relaying the same report: the guild sees it once
    N=loadAddon(); establish(N); advance(1)
    local text=R.encode(weRec(N,{heard=clock,age=0}),clock)
    deliver("CHAT_MSG_ADDON","LEGW1",text,"GUILD","One"); deliver("CHAT_MSG_ADDON","LEGW1",text,"GUILD","Two")
    eq(N.Main.lastDrop,"duplicate"); eq(N.Safe.count(N.Main.store.reports),1); eq(#N.Store.reporters(N.Main.store,clock),0)
    -- 256 remembered ids at most
    st=R.new(); for i=1,300 do R.offer(st,weRec(N,{rid=tostring(i)}),100,ctx); R.clear(st) end; eq(st.n,256)
end)
test("relay drops instead of queueing when the bucket is empty",function()
    local N=loadAddon(); establish(N); N.Relay.rand=function() return .5 end; advance(1)
    for i=1,7 do N.Main.offerRelay(weRec(N,{origin="Scout"..string.char(96+i),heard=clock})) end
    advance(1); eq(#relayed(N),5); eq(N.Main.lastRelay,"throttled")
    eq(next(N.Main.relay.pending),nil)
    advance(30); eq(#relayed(N),5)
    -- the bucket refills: a new record goes
    N.Main.offerRelay(weRec(N,{origin="Later",heard=clock})); advance(1); eq(#relayed(N),6)
end)
test("relayed record is labelled and not first-hand",function()
    local N=loadAddon(); establish(N); advance(20)
    deliver("CHAT_MSG_ADDON","LEGW1",N.Relay.encode(weRec(N,{heard=clock-10,age=0}),clock),"GUILD","Guildie")
    local rows=N.Store.rows(N.Main.store,clock,"reported"); eq(#rows,2)
    local r=rows[1].record; eq(r.src,"guild"); eq(r.label,"we"); eq(r.via,"Guildie"); eq(r.origin,"Scout"); eq(r.heard,clock-10)
    eq(rows[1].source,"relayed by Guildie (War Effort)"); eq(rows[1].confidence,"reported, not confirmed")
    eq(rows[1].relation,"other")
    -- a relayed reporter was in someone else's group: not an invite candidate
    eq(#N.Store.reporters(N.Main.store,clock),0)
    -- no hop through the War Effort chat fallback for a relayed record: the origin was in someone else's group
    eq(N.Hop.candidate(r,{}),nil)
    -- the first-hand report of the same id replaces the relayed copy
    hello("Scout",19,"PARTY"); report(1,8000,"Scout",nil,"PARTY")
    rows=N.Store.rows(N.Main.store,clock,"reported"); eq(rows[1].record.src,"we"); eq(N.Safe.count(N.Main.store.reports),1)
    -- a HeadHunter relay: label and a tracked name found by name
    SlashCmdList.LAYERENEMIES("find Kora Reed")
    local hh=assert(N.Record.new({src="hh",kind="fight",origin="Mira Vale",route="WHISPER",rid="5",zone=100,count=1,
        enemies={{name="Kora Reed",class="PALADIN",level=31}},layer={ns="zoneuid",value=4},heard=clock,share="public"}))
    deliver("CHAT_MSG_ADDON","LEGW1",N.Relay.encode(hh,clock),"GUILD","Guildie")
    local hrow; for _,row in ipairs(N.Store.rows(N.Main.store,clock,"reported")) do if row.record.label=="hh" then hrow=row end end
    eq(hrow.source,"relayed by Guildie (HeadHunter fight)"); eq(hrow.name,"Kora Reed"); eq(hrow.relation,"unknown")
    local loc=N.Main.find.locations["Kora Reed"]; yes(loc); eq(loc.spotter,"Mira Vale"); eq(loc.zone,100)
    -- origin is us, or ignored: dropped
    deliver("CHAT_MSG_ADDON","LEGW1",N.Relay.encode(weRec(N,{origin="Me",rid="7",heard=clock,age=0}),clock),"GUILD","Guildie"); eq(N.Main.lastDrop,"relay origin")
    deliver("CHAT_MSG_ADDON","LEGW1",N.Relay.encode(weRec(N,{origin="Me-TestRealm",rid="17",heard=clock,age=0}),clock),"GUILD","Guildie"); eq(N.Main.lastDrop,"relay origin")
    local old=C_FriendList.IsIgnored; C_FriendList.IsIgnored=function(n) return n=="Bad Guy" end
    deliver("CHAT_MSG_ADDON","LEGW1",N.Relay.encode(weRec(N,{origin="Bad Guy",rid="8",heard=clock,age=0}),clock),"GUILD","Guildie"); eq(N.Main.lastDrop,"relay origin")
    deliver("CHAT_MSG_ADDON","LEGW1",N.Relay.encode(weRec(N,{origin="Fine",rid="9",heard=clock,age=0}),clock),"GUILD","Bad Guy"); eq(N.Main.lastDrop,"ignored sender")
    C_FriendList.IsIgnored=old; eq(#sent,0)
end)
test("relay rejects format version 2 and oversize",function()
    local N=loadAddon(); local R=N.Relay
    local good=R.encode(weRec(N),100)
    local v2=good:gsub("^R|1|","R|2|"); local r,why=R.decode(v2,"Gee",100); eq(r,nil); eq(why,"version")
    eq(R.decode(good..string.rep(",",256-#good),"Gee",100),nil); eq(R.decode(string.rep("R",256),"Gee",100),nil)
    local bad={good:gsub("|abc:MAGE:40,def::$",""),good.."|x",good:gsub("|100|400|","|100|1000|"),good:gsub("|2|s|","|81|s|"),
        good:gsub("|5|abc","|901|abc"),good:gsub("|s|","|q|"),good.." ",good:gsub("^R","Q"),good:gsub(hx("Scout"),"5"),good:gsub("abc:MAGE:40","abc:MAGE:101"),
        good:gsub("abc:MAGE:40","abcde:MAGE:40"),good:gsub("abc:MAGE:40","abzz:MAGE:40"),good:gsub("abc:MAGE:40","ab:MAGE:40"),
        good:gsub("abc:MAGE:40","0a41:MAGE:40")}
    for _,text in ipairs(bad) do eq(R.decode(text,"Gee",100),nil,text) end
    -- too many enemies: as many as fit go, the rest is dropped
    local many={}; for i=1,80 do many[i]={hash=string.format("%03d",i),class="WARRIOR",level=60} end
    local big=R.encode(weRec(N,{count=80,enemies=many}),100); yes(#big<=255); local back=R.decode(big,"Gee",100); yes(back); yes(#back.enemies>5 and #back.enemies<80)
    -- a record that does not fit even without enemies, or is too old, is not sent
    yes(#R.encode(weRec(N,{origin=string.rep("a",36).." "..string.rep("b",36).."-"..string.rep("c",26)}),100)<=255)
    eq(R.encode(weRec(N,{origin=string.rep("a",36).." "..string.rep("b",36).."-"..string.rep("c",26),rid=string.rep("9",24),layer={ns="unknown",value=string.rep("7",32)}}),100),nil)
    eq(R.encode(weRec(N,{heard=0,age=0}),901),nil)
end)
test("relay silent outside a guild",function()
    local N=loadAddon(); establish(N); N.Relay.rand=function() return .5 end; advance(1)
    inGuild=false; hello("Scout",19,"PARTY"); report(1,8000,"Scout",nil,"PARTY"); advance(5); eq(#sent,0)
    deliver("CHAT_MSG_ADDON","LEGW1",N.Relay.encode(weRec(N,{rid="2",heard=clock,age=0}),clock),"GUILD","Guildie"); eq(N.Safe.count(N.Main.store.reports),1)
    inGuild=true; inInstance=true; report(3,8000,"Scout",nil,"PARTY"); advance(5); eq(#sent,0)
    IsInInstance=function() return nil end; advance(10); report(4,8000,"Scout",nil,"PARTY"); advance(5); eq(#sent,0)
    IsInInstance=function() return false end; advance(10); report(5,8000,"Scout",nil,"PARTY"); advance(5); eq(#relayed(N),1)
    -- only GUILD carries LEGW1, and our own echo is not read
    local text=N.Relay.encode(weRec(N,{rid="6",heard=clock,age=0}),clock)
    for _,kind in ipairs({"PARTY","RAID","WHISPER"}) do deliver("CHAT_MSG_ADDON","LEGW1",text,kind,"Guildie") end
    deliver("CHAT_MSG_ADDON","LEGW1",text,"GUILD","Me-TestRealm")
    local n=0; for _,row in pairs(N.Main.store.reports) do if row.record.rid=="6" then n=n+1 end end; eq(n,0); eq(forbidden,0)
end)
test("hh only P, L and E frames count against the rate (مانع T4 S1)",function()
    local N=loadAddon(); establish(N); advance(1); server=HHT
    local function P() return "1AP:2s;"..b36(server)..";dw;6y;a1;Kora Reed/P/31;4" end
    -- مانع's probe: six N frames from a party member, then a real P
    for i=1,6 do deliver("CHAT_MSG_ADDON","HeadHunter","1AN:1.1.1;x"..i,"PARTY","Mira Vale") end
    for i=1,6 do deliver("CHAT_MSG_ADDON","HeadHunter","garbage "..i,"PARTY","Mira Vale") end
    deliver("CHAT_MSG_ADDON","HeadHunter",P(),"PARTY","Mira Vale")
    eq(#N.Store.rows(N.Main.store,clock,"reported"),1); eq(N.Main.lastDrop,"headhunter fight")
    -- P, L and E frames still count: five more, then the 7th is dropped
    for i=1,5 do deliver("CHAT_MSG_ADDON","HeadHunter","1AL:Ann Lee"..string.char(96+i)..";2s;"..b36(server)..";dw;6y","PARTY","Mira Vale") end
    eq(N.Safe.count(N.Main.store.reports),6)
    deliver("CHAT_MSG_ADDON","HeadHunter","1AL:Bo Ray;2s;"..b36(server)..";dw;6y","PARTY","Mira Vale"); eq(N.Safe.count(N.Main.store.reports),6)
    eq(#sent,0); no(N.Main.error)
end)
test("hh E envelope fields are checked (مانع T4 S2)",function()
    local N=loadAddon()
    local function env(world,server,hops,first) return "1AE:"..world..";Mira Vale;A;"..server..";"..hops..";"..first..";P13k;tro8w0;dw;6y;a1" end
    eq(#hh(N,env("eu-pvp","5cy","1","tro8w0"),"Carrier"),1)
    eq(#hh(N,env(string.rep("w",40),"0","5","0"),"Carrier"),1)                       -- limits that pass
    eq(#hh(N,env("eu-pvp","0123456789","1","tro8w0"),"Carrier"),1)
    for _,bad in ipairs({
        env("","5cy","1","tro8w0"), env(string.rep("w",41),"5cy","1","tro8w0"), env("eu\1pvp","5cy","1","tro8w0"), env("eu\npvp","5cy","1","tro8w0"),
        env("eu-pvp","5CY","1","tro8w0"), env("eu-pvp","","1","tro8w0"), env("eu-pvp","5c-y","1","tro8w0"), env("eu-pvp","0123456789a","1","tro8w0"),
        env("eu-pvp","5cy","0","tro8w0"), env("eu-pvp","5cy","6","tro8w0"), env("eu-pvp","5cy","10","tro8w0"), env("eu-pvp","5cy","","tro8w0"), env("eu-pvp","5cy","A","tro8w0"),
        env("eu-pvp","5cy","1",""), env("eu-pvp","5cy","1","00000tro8w0"), env("eu-pvp","5cy","1","TRO8W0") }) do
        eq(#hh(N,bad,"Carrier"),0,bad)
    end
    -- through the addon, a bad envelope leaves no row
    N=loadAddon(); establish(N); advance(1); server=HHT
    deliver("CHAT_MSG_ADDON","HeadHunter","1AE:eu-pvp;Mira Vale;A;5CY;1;"..b36(server)..";P2s;"..b36(server)..";dw;6y;a1","WHISPER","Carrier")
    eq(N.Safe.count(N.Main.store.reports),0); eq(N.Main.lastDrop,"invalid")
end)
test("hh bounds: base36 digits, allies, frame size, rate table (مانع T4 S3)",function()
    local N=loadAddon()
    eq(#hh(N,"1AP:13k;0000tro8w0;dw;6y;a1"),1); eq(#hh(N,"1AP:13k;00000tro8w0;dw;6y;a1"),0)      -- 10 digits pass, 11 fail
    local ids={}; for i=1,12 do ids[#ids+1]="+a"..i end
    eq(#hh(N,"1AP:13k;tro8w0;dw;6y;e1,"..table.concat(ids,",")),1)
    eq(#hh(N,"1AP:13k;tro8w0;dw;6y;e1,"..table.concat(ids,",")..",+a13"),0)                    -- 13 allies
    -- a 255-byte frame is read, 256 is not (decoder and addon): 12 long enemy ids, then a name padded to size
    local function frame(n,map,t) local ids={}; for i=1,12 do ids[i]=string.format("e%015d",i) end
        local head="1AP:"..map..";"..t..";dw;6y;"..table.concat(ids,",")..";"
        local f=head..string.rep("k",n-#head-4).."//;4"; eq(#f,n); return f end
    yes(hh(N,frame(255,"13k","tro8w0"))[1]); eq(#hh(N,frame(256,"13k","tro8w0")),0)
    N=loadAddon(); establish(N); advance(1); server=HHT
    deliver("CHAT_MSG_ADDON","HeadHunter",frame(255,"2s",b36(server)),"PARTY","Mira Vale"); eq(N.Safe.count(N.Main.store.reports),1)
    deliver("CHAT_MSG_ADDON","HeadHunter",frame(256,"2s",b36(server)),"PARTY","Ann Lee"); eq(N.Safe.count(N.Main.store.reports),1)
    -- the rate table holds 512 senders; the 513th waits for the window
    local st=N.HeadHunter.new()
    for i=1,512 do yes(N.HeadHunter.allow(st,"S"..i,0)) end
    no(N.HeadHunter.allow(st,"S513",5)); eq(st.n,512); yes(N.HeadHunter.allow(st,"S513",10))
end)
test("hh carrier ignore and secrets on every event argument (مانع T4 S3)",function()
    local N=loadAddon(); establish(N); advance(1); server=HHT
    local E="1AE:eu-pvp;Mira Vale;A;5cy;1;"..b36(server)..";P2s;"..b36(server)..";dw;6y;a1"
    local old=C_FriendList.IsIgnored; C_FriendList.IsIgnored=function(name) return name=="Carrier" end
    deliver("CHAT_MSG_ADDON","HeadHunter",E,"WHISPER","Carrier"); eq(N.Main.lastDrop,"ignored sender"); eq(N.Safe.count(N.Main.store.reports),0)
    C_FriendList.IsIgnored=old
    for i=1,8 do
        N=loadAddon(); establish(N); advance(1); server=HHT
        local args={"HeadHunter","1AP:2s;"..b36(server)..";dw;6y;a1","PARTY","Mira Vale","Me",0,0,""}
        args[i]=secret; N.Main.lastDrop="untouched"
        deliver("CHAT_MSG_ADDON",args[1],args[2],args[3],args[4],args[5],args[6],args[7],args[8])
        eq(N.Safe.count(N.Main.store.reports),0,i); eq(N.Main.lastDrop,"untouched",i); no(N.Main.error,i)
    end
    N=loadAddon(); establish(N); advance(1); server=HHT
    deliver("CHAT_MSG_ADDON","HeadHunter","1AP:2s;"..b36(server)..";dw;6y;a1","PARTY","Mira Vale","Me",0,0,""); eq(N.Safe.count(N.Main.store.reports),1)
end)
test("hh count is the number of enemy ids; rows show via <carrier>",function()
    local N=loadAddon()
    local r=hh(N,"1AP:13k;tro8w0;dw;6y;;Kora Reed/P/31;4")[1]; yes(r); eq(r.count,0); eq(#r.enemies,1)
    eq(hh(N,"1AP:13k;tro8w0;dw;6y;a1,+b2,+c3;Ann Lee//,Bo Ray//;4")[1].count,1)
    N=loadAddon(); establish(N); advance(1); server=HHT
    deliver("CHAT_MSG_ADDON","HeadHunter","1AE:eu-pvp;Mira Vale;A;5cy;1;"..b36(server)..";P2s;"..b36(server)..";dw;6y;a1","WHISPER","Carrier")
    deliver("CHAT_MSG_ADDON","HeadHunter","1AP:2s;"..b36(server-1)..";dw;6y;b2","PARTY","Ann Lee")
    local rows=N.Store.rows(N.Main.store,clock,"reported"); local via={}
    for _,row in ipairs(rows) do via[row.reporter]=row.via or "none" end
    eq(via["Mira Vale"],"Carrier"); eq(via["Ann Lee"],"none")
    SlashCmdList.LAYERENEMIES("reports"); yes(table.concat(log,"\n"):find("reported by Mira Vale via Carrier",1,true)); no(table.concat(log,"\n"):find("Ann Lee via",1,true))
    -- War Effort G: the relaying guildmate is the carrier
    N=loadAddon(); establish(N); advance(1)
    local stamp=math.floor(server)%3600
    deliver("CHAT_MSG_ADDON","WEFF1","G|"..hexOf("Scout").."||C|42|100|0.4|0.5|7086|4|"..stamp,"GUILD","Relay")
    rows=N.Store.rows(N.Main.store,clock,"reported"); eq(#rows,1); eq(rows[1].reporter,"Scout"); eq(rows[1].via,"Relay")
    -- the window line too
    N.UI.toggle(); N.UI.select("reported"); eq(N.UI.pool[1].sub.text,"reported by Scout via Relay · relayed")
end)
test("relayed origins never become Find spotters (مانع T6 F1)",function()
    local N=loadAddon(); chatBox(); establish(N); advance(20); local U=N.UI
    SlashCmdList.LAYERENEMIES("find Kora Reed")
    local hhRec=weRec(N,{src="hh",kind="fight",origin="Stranger",share="public",layer={ns="unknown"},count=1,heard=clock,age=0,
        enemies={{name="Kora Reed",class="PALADIN",level=31}}})
    deliver("CHAT_MSG_ADDON","LEGW1",N.Relay.encode(hhRec,clock),"GUILD","Guildie"); eq(N.Main.lastDrop,"relayed hh")
    U.toggle(); U.tabs.find:Click()
    eq(U.pool[1].title.text,"Kora Reed"); yes(U.pool[1].sub.text:find("seen in a relayed report",1,true)); no(U.pool[1].sub.text:find("Stranger",1,true))
    no(U.pool[1].ask:IsShown())
    no(LE.AskInvite("Stranger")); drain(); eq(#opened,0); eq(#sent,0)
    -- the same name reported first-hand afterwards can be asked again
    deliver("CHAT_MSG_ADDON","HeadHunter","1AP:2s;"..b36(server)..";dw;6y;a1;Kora Reed/P/31;4","PARTY","Mira Vale")
    U.render(); yes(U.pool[1].sub.text:find("seen by Mira Vale",1,true)); yes(U.pool[1].ask:IsShown())
end)
test("relay rechecks guild and instance at send time (مانع T6 S1)",function()
    local N=loadAddon(); establish(N); N.Relay.rand=function() return .5 end; advance(1)
    local function try(change) N=loadAddon(); establish(N); N.Relay.rand=function() return .5 end; advance(1)
        N.Main.offerRelay(weRec(N,{heard=clock})); yes(next(N.Main.relay.pending)); change(); advance(1); local n=#relayed(N); inGuild,inInstance,guildName=true,false,"Test Guild"; return n end
    eq(try(function() end),1)
    eq(try(function() guildName="Other Guild" end),0)
    eq(try(function() inGuild=false end),0)
    eq(try(function() inInstance=true end),0)
    eq(try(function() inInstance=nil end),0)
    eq(try(function() guildName=nil end),0)
    -- no readable guild name: nothing is offered
    N=loadAddon(); establish(N); advance(1); guildName=nil
    no(N.Relay.offer(N.Main.relay,weRec(N),clock,N.Main.relayContext())); guildName="Test Guild"
end)
test("relayed HeadHunter lives 300 s from origin time (مانع T6 S2)",function()
    local N=loadAddon(); establish(N); advance(250); local R=N.Relay
    local function hhAt(age,rid) return weRec(N,{src="hh",kind="fight",rid=rid,share="public",layer={ns="unknown"},count=1,heard=clock,age=age,enemies={}}) end
    eq(select(2,R.decode(R.encode(hhAt(300,"1"),clock),"Guildie",clock)),"too old")
    yes(R.decode(R.encode(hhAt(299,"2"),clock),"Guildie",clock))
    -- War Effort copies: 600 s
    eq(select(2,R.decode(R.encode(weRec(N,{heard=clock,age=600}),clock),"Guildie",clock)),"too old")
    yes(R.decode(R.encode(weRec(N,{heard=clock,age=599}),clock),"Guildie",clock))
    -- stored: a 200 s old relayed fight goes after 100 more seconds
    deliver("CHAT_MSG_ADDON","LEGW1",R.encode(hhAt(200,"3"),clock),"GUILD","Guildie"); eq(N.Safe.count(N.Main.store.reports),1)
    advance(99); N.Store.prune(N.Main.store,clock); eq(N.Safe.count(N.Main.store.reports),1)
    advance(1); N.Store.prune(N.Main.store,clock); eq(N.Safe.count(N.Main.store.reports),0)
end)
test("relay rejects bad levels, self-relays, and caps pending offers (مانع T6 S3, S4)",function()
    local N=loadAddon(); establish(N); advance(20); local R=N.Relay
    local good=R.encode(weRec(N,{heard=clock,age=0}),clock); yes(R.decode(good,"Guildie",clock))
    for _,lvl in ipairs({"-","--1","1-","-0-","1-2"}) do eq(R.decode(good:gsub("abc:MAGE:40","abc:MAGE:"..lvl),"Guildie",clock),nil,lvl) end
    yes(R.decode(good:gsub("abc:MAGE:40","abc:MAGE:-1"),"Guildie",clock)); yes(R.decode(good:gsub("abc:MAGE:40","abc:MAGE:"),"Guildie",clock))
    -- origin Scout sent by Scout (any realm form) is not a relay
    eq(select(2,R.decode(good,"Scout",clock)),"origin is sender"); eq(select(2,R.decode(good,"scout-TestRealm",clock)),"origin is sender")
    yes(R.decode(good,"Scout-OtherRealm",clock)==nil)
    yes(R.decode(R.encode(weRec(N,{origin="Scout-RealmA",heard=clock,age=0}),clock),"Scout-RealmB",clock))
    deliver("CHAT_MSG_ADDON","LEGW1",good,"GUILD","Scout"); eq(N.Main.lastDrop,"relay origin is sender"); eq(N.Safe.count(N.Main.store.reports),0)
    -- a relayed HeadHunter copy claiming a server layer is still not comparable; a relayed War Effort one is
    -- a relayed HeadHunter copy claiming any layer is refused (r2); a relayed War Effort one compares
    local crafted=good:gsub("|we|group|","|hh|fight|",1)
    eq(select(2,R.decode(crafted,"Guildie",clock)),"invalid")
    eq(select(2,R.decode(crafted:gsub("|s|8000|","|z|4|",1),"Guildie",clock)),"invalid")
    yes(R.decode(crafted:gsub("|s|8000|","|u||",1),"Guildie",clock))
    eq(N.Record.relation(R.decode(good,"Guildie",clock),{zone=100,server="7000"}),"other")
    -- 128 pending offers at most
    local st=R.new(); local ctx={inGuild=true,inInstance=false,guild="Test Guild"}
    for i=1,130 do R.offer(st,weRec(N,{rid=tostring(i)}),100,ctx) end
    local n=0; for _ in pairs(st.pending) do n=n+1 end; eq(n,128); no(R.offer(st,weRec(N,{rid="999"}),100,ctx))
end)
test("a stored relay replayed into Find stays unaskable (r2)",function()
    for _,src in ipairs({"hh","we"}) do
        for _,mode in ipairs({"slash","button","unrelated"}) do
            local N=loadAddon(); chatBox(); establish(N); advance(2); local U=N.UI
            local name=src=="hh" and "Kora Reed" or "Alice"
            local enemy=src=="hh" and {name=name,class="PALADIN",level=31} or {hash=N.Hash.player(name,""),class="PALADIN",level=31}
            local rec=assert(N.Record.new({src=src,kind=src=="hh" and "fight" or "group",origin="Stranger",route="PARTY",rid="1",zone=100,count=1,
                enemies={enemy},layer={ns="unknown"},heard=clock,share="public"}))
            if mode=="unrelated" then SlashCmdList.LAYERENEMIES("find "..name) end
            deliver("CHAT_MSG_ADDON","LEGW1",N.Relay.encode(rec,clock),"GUILD","Guildie"); eq(N.Main.lastDrop,"relayed "..src,src..mode)
            U.toggle(); U.tabs.find:Click()
            if mode=="button" then U.input:SetText(name); U.add:Click()
            else SlashCmdList.LAYERENEMIES("find "..(mode=="unrelated" and "Otherenemy" or name)); U.render() end
            local row; for _,r in ipairs(N.Main.findRows()) do if r.name==name then row=r end end
            yes(row and row.spotter,src..mode); no(row.canAsk,src..mode)
            local i; for k,r in ipairs(U.pool) do if r.title.text==name then i=k end end
            no(U.pool[i].ask:IsShown(),src..mode); U.pool[i].ask:Click(); no(LE.AskInvite("Stranger"),src..mode); drain(); eq(#opened,0,src..mode)
        end
    end
end)
test("a duplicate relay does not make a first-hand Find row unaskable (r2)",function()
    local N=loadAddon(); chatBox(); establish(N); advance(2)
    SlashCmdList.LAYERENEMIES("find Kora Reed")
    deliver("CHAT_MSG_ADDON","HeadHunter","1AP:2s;"..b36(server)..";dw;6y;a1;Kora Reed/P/31;4","PARTY","Mira Vale")
    local function row() for _,r in ipairs(N.Main.findRows()) do if r.name=="Kora Reed" then return r end end end
    yes(row().canAsk); eq(row().spotter,"Mira Vale")
    -- a guildmate relays the same fight back to us: a duplicate, Find unchanged
    local rec=assert(N.Record.new({src="hh",kind="fight",origin="Mira Vale",route="PARTY",rid=tostring(math.floor(server)),zone=100,count=1,
        enemies={{name="Kora Reed",class="PALADIN",level=31}},layer={ns="unknown"},heard=clock,share="public"}))
    advance(1); deliver("CHAT_MSG_ADDON","LEGW1",N.Relay.encode(rec,clock),"GUILD","Guildie"); eq(N.Main.lastDrop,"duplicate")
    yes(row().canAsk); eq(row().spotter,"Mira Vale")
    -- another relayed fight with the name, newer: still the first-hand row while it is fresh
    rec=assert(N.Record.new({src="hh",kind="fight",origin="Stranger",route="PARTY",rid="77",zone=100,count=1,
        enemies={{name="Kora Reed"}},layer={ns="unknown"},heard=clock,share="public"}))
    advance(1); deliver("CHAT_MSG_ADDON","LEGW1",N.Relay.encode(rec,clock),"GUILD","Guildie"); eq(N.Main.lastDrop,"relayed hh")
    yes(row().canAsk); eq(row().spotter,"Mira Vale")
    -- tracking again replays the store: the first-hand row still wins
    SlashCmdList.LAYERENEMIES("find Other Name"); yes(row().canAsk); eq(row().spotter,"Mira Vale")
end)
test("relayed reporters are never invite candidates",function()
    local N=loadAddon(); establish(N); advance(20)
    deliver("CHAT_MSG_ADDON","LEGW1",N.Relay.encode(weRec(N,{origin="Stranger",heard=clock,age=0}),clock),"GUILD","Guildie")
    eq(N.Main.lastDrop,"relayed we"); eq(#N.Store.rows(N.Main.store,clock,"reported"),2)
    eq(#N.Store.reporters(N.Main.store,clock),0); eq(#N.Main.candidates(),0)
    SlashCmdList.LAYERENEMIES("hosts"); yes(logged("No one to ask right now.")); no(logged("Stranger"))
    no(LE.AskInvite("Stranger")); eq(#sent,0)
    -- the same origin heard first-hand is a candidate again
    hello("Stranger",19,"PARTY"); report(1,8000,"Stranger",nil,"PARTY")
    eq(#N.Store.reporters(N.Main.store,clock),1); eq(N.Main.candidates()[1].name,"Stranger")
end)
test("relay receive limit: 12 per 10 s per sender",function()
    local N=loadAddon(); establish(N); advance(20)
    local function from(who,rid) deliver("CHAT_MSG_ADDON","LEGW1",N.Relay.encode(weRec(N,{origin="O"..who..abc(rid),rid=tostring(rid),heard=clock,age=0}),clock),"GUILD",who) end
    for i=1,13 do from("Busy",i) end
    eq(N.Safe.count(N.Main.store.reports),12)
    N.Main.lastDrop="before"; from("Busy",14); eq(N.Main.lastDrop,"before")    -- dropped silently
    from("Calm",1); eq(N.Safe.count(N.Main.store.reports),13)                 -- per sender
    advance(10); from("Busy",15); eq(N.Safe.count(N.Main.store.reports),14)
    -- the limit table is bounded too
    local st=N.Relay.new(); for i=1,600 do N.Relay.allow(st,"S"..i,0) end; yes(st.nrates<=512)
end)
-- Wire.lua: the only sender
local LSX="inv layer <LS 1429 want 7086-0>"
test("the send mock counts any caller but Wire.lua as forbidden",function()
    local N=loadAddon()
    -- a direct call, a pcall-wrapped call and a dynamically named call from outside Wire.lua all count
    C_ChatInfo.SendAddonMessage("LayerSwap","x","WHISPER","Alice"); eq(forbidden,1)
    pcall(function() C_ChatInfo["Send".."AddonMessage"]("LayerSwap","x","WHISPER","Alice") end); eq(forbidden,2)
    pcall(C_ChatInfo.SendAddonMessage,"LEGW1","x","GUILD"); eq(forbidden,3)
    -- the same routes through Wire.lua do not
    forbidden=0; yes(N.Wire.send("LayerSwap",LSX,"WHISPER","Alice")); yes(N.Wire.send("LEGW1","x","GUILD")); eq(forbidden,0); eq(#sent,5)
end)
test("wire routes cannot be opened from outside",function()
    local N=loadAddon(); local Wr=N.Wire
    if type(Wr.ROUTES)=="table" then
        Wr.ROUTES.WEFF1={GUILD=true}; if type(Wr.ROUTES.LayerSwap)=="table" then Wr.ROUTES.LayerSwap.GUILD=true end
        if type(Wr.ROUTES.LEGW1)=="table" then Wr.ROUTES.LEGW1.WHISPER=true end
    end
    Wr.ROUTES={WEFF1={GUILD=true},LayerSwap={GUILD=true,CHANNEL=true}}
    for _,c in ipairs({{"WEFF1","x","CHANNEL","5"},{"LayerSwap","x","GUILD"},{"LEGW1","x","WHISPER","Bob"}}) do
        local ok,why=Wr.send(c[1],c[2],c[3],c[4]); no(ok); eq(why,"blocked route")
    end
    eq(#sent,0); yes(Wr.send("LayerSwap",LSX,"WHISPER","Alice")); eq(#sent,1)
end)
test("wire sends only on the allowed routes",function()
    local N=loadAddon(); local Wr=N.Wire
    local function blocked(...) local ok,why=Wr.send(...); no(ok); eq(why,"blocked route") end
    blocked("WEFF1","x","CHANNEL","5"); blocked("LayerSwap","x","GUILD"); blocked("LEGW1","x","WHISPER","Bob")
    blocked("LayerSwap","x","CHANNEL","5"); blocked("HeadHunter","1AN:x","GUILD"); blocked("LFSw","Q","WHISPER","Bob")
    blocked("ForeverSpy1","x","PARTY"); blocked("GBOUNTY","D|x","GUILD")
    -- WEFF1 and HeadHunter routes exist from 1.0 T1, but text outside their types fails, and their networks ship off
    local ok0,why0=Wr.send("WEFF1","x","GUILD"); no(ok0); eq(why0,"bad text")
    ok0,why0=Wr.send("WEFF1","H|0.1.0","GUILD"); no(ok0); eq(why0,"network off")
    ok0,why0=Wr.send("HeadHunter","1AP:x","WHISPER","Bob"); no(ok0); eq(why0,"bad text")
    local ok,why=Wr.send("LFSw","x","GUILD"); no(ok); eq(why,"bad text")
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
    bad("LayerSwap",LSX,"WHISPER",secret); bad("LayerSwap",LSX,"WHISPER","B"); bad("LayerSwap",LSX,"WHISPER",nil)
    bad("LayerSwap",LSX,"WHISPER","Bad|Name")
    local ok,why=Wr.send(secret,"x","GUILD"); no(ok); eq(why,"bad text")
    ok,why=Wr.send("LEGW1","x",secret); no(ok); eq(why,"bad text")
    eq(#sent,0)
    ok=Wr.send("LEGW1",string.rep("a",255),"GUILD"); yes(ok); eq(#sent,1)
    ok=Wr.send("LayerSwap",LSX,"WHISPER","First Surname"); yes(ok); eq(#sent,2)
end)
test("wire maps client results",function()
    local N=loadAddon(); local Wr=N.Wire
    local function try(r,want) sendResult=r; local ok,why=Wr.send("LayerSwap",LSX,"WHISPER","Alice"); eq(why,want); eq(ok,want=="sent") end
    -- 1.0 T1: 3 and 8 are throttles and pause the prefix 30 s (the next send there is "paused" without asking)
    try(0,"sent"); try(3,"throttled"); try(0,"paused"); advance(31); try(8,"throttled"); advance(31); try(1,"refused")
    advance(3); try(function() error("boom") end,"error")
    eq(#sent,5); no(N.Main.error); eq(forbidden,0)
    C_ChatInfo=nil; local ok,why=Wr.send("LayerSwap",LSX,"WHISPER","Alice"); no(ok); eq(why,"error")
end)
test("wire guild bucket",function()
    local N=loadAddon(); local Wr=N.Wire
    local got={}
    for i=1,6 do local ok,why=Wr.send("LEGW1","m"..i,"GUILD"); got[#got+1]=why end
    eq(table.concat(got,","),"sent,sent,sent,sent,sent,throttled"); eq(#sent,5)
    advance(1); local ok,why=Wr.send("LEGW1","m7","GUILD"); no(ok); eq(why,"throttled"); eq(#sent,5)
    advance(1); ok,why=Wr.send("LEGW1","m8","GUILD"); yes(ok); eq(why,"sent"); eq(#sent,6)
    -- 1.0 T1: every prefix has its own bucket of 5, and all sends share 8 at once (6 spent here, 1.3 refilled)
    local okW=0; for i=1,8 do if Wr.send("LayerSwap",LSX,"WHISPER","Alice") then okW=okW+1 end end
    eq(okW,3,"the shared bucket"); eq(#sent,9)
    advance(100); okW=0; for i=1,8 do if Wr.send("LayerSwap",LSX,"WHISPER","Alice") then okW=okW+1 end end; eq(okW,5,"the prefix bucket")
    -- refill caps at 5
    advance(100); for i=1,6 do Wr.send("LEGW1","r"..i,"GUILD") end; eq(#sent,19)
end)

-- 0.3.1 core: hosts while our own layer is unknown, hop to a host, remembered LayerSwap replies.
local HINT="Your layer is not known yet: target or mouse over two different kinds of NPC within 15 seconds."
local function guildLine(text,from) deliver("CHAT_MSG_ADDON","LFSw",text,"GUILD",from) end
local function slash(text) SlashCmdList.LAYERENEMIES(text); drain() end
test("0.3.1 T3: hosts are listed while our own layer is unknown; nothing is sent or drafted",function()
    local N=loadAddon(); chatBox(); guildLine("L 8000|100|h","Bob")
    eq(N.Main.store.bulo,nil,"own layer unknown")
    slash("hosts")
    yes(logged("1. Bob | layer 8000 | Bulo | host"),"host listed"); yes(logged(HINT),"hint in /le hosts")
    eq(#log>0 and log[#log]:find("mouse over",1,true),nil)
    local before=#log
    slash("hop host 1"); eq(#sent,0); eq(#opened,0); yes(log[#log]:find(HINT,1,true),"hop host refuses with the hint"); yes(#log>before)
    slash("ask 1"); eq(#sent,0); eq(#opened,0); yes(log[#log]:find(HINT,1,true),"ask refuses with the hint")
    -- the shared path (window button and /le hop host) refuses on its own too
    local row=N.Main.candidates()[1]; no(N.Main.hopHostTo(row,nil)); eq(#sent,0); yes(log[#log]:find(HINT,1,true))
    row.unknownOwn=nil; no(N.Main.hopHostTo(row,nil)); eq(#sent,0); yes(log[#log]:find(HINT,1,true),"own key unknown alone refuses")
    -- /le list shows the hint too
    log={}; slash("list"); yes(logged(HINT),"hint in /le list")
    -- two NPC readings: the same row becomes hoppable, the hint goes
    establish(N); log={}; slash("list"); no(logged(HINT),"no hint once known")
    log={}; slash("hosts"); no(logged(HINT)); yes(logged("1. Bob | layer 8000 | Bulo | host"))
    slash("hop host 1"); eq(#sent,1); eq(sent[1].prefix,"LayerSwap"); eq(sent[1].kind,"WHISPER"); eq(sent[1].target,"Bob")
    eq(sent[1].text,"inv layer <LS 100 want 8000-0 25.0,75.0>"); eq(forbidden,0)
end)
test("0.3.1 T3: Invite.collect marks rows while unknown; a report hop never picks them",function()
    local N=loadAddon(); guildLine("L 8000|100|h","Bob")
    local list,status=N.Main.candidates()
    eq(#list,1); eq(list[1].name,"Bob"); yes(list[1].unknownOwn); no(list[1].same)
    yes(status.bulo:find("your layer is not known yet",1,true),status.bulo)
    eq(N.Invite.HINT,HINT)
    -- a report on 8000 while our layer is unknown: the hop does not go through the unknown-layer row (0.3.0 behaviour)
    -- (the War Effort origin of the record stays the 0.3.0 fallback: a chat whisper, no addon)
    local c=N.Hop.candidate(rec(N),(N.Main.candidates())); yes(c); eq(c.name,"Scout"); no(c.addon)
    establish(N); list=N.Main.candidates(); no(list[1].unknownOwn)
end)
test("0.3.1 T3: the window shows the hint and disables the row button while unknown",function()
    local N=loadAddon(); chatBox(); guildLine("L 8000|100|h","Bob")
    local U=N.UI; U.toggle(); U.select("friendly")
    eq(U.pool[1].title.text,"Bob"); yes(U.pool[1].ask.disabled,"disabled"); eq(U.pool[1].ask.reason,HINT)
    eq(U.banner.text,HINT); yes(U.meta.text:find("mouse over or target two different kinds of NPC within 15 s",1,true),U.meta.text)
    U.pool[1].ask:Click(); drain(); eq(#sent,0); eq(#opened,0)
    establish(N); U.render(); no(U.pool[1].ask.disabled); eq(U.banner.text,"")
end)
test("0.3.1 T2: /le hop host sends one LayerSwap whisper through Hop.request, with its cooldowns",function()
    local N=loadAddon(); establish(N); guildLine("L 8000|100|h","Bob"); guildLine("L 9000|100|-","Dan")
    slash("hosts"); yes(logged("/le hop host <number>"),"names the command")
    slash("hop host 1"); eq(#sent,1); eq(sent[1].target,"Bob"); eq(sent[1].text,"inv layer <LS 100 want 8000-0 25.0,75.0>")
    yes(logged("asked Bob (Bulo) for an invite to layer 8000. Accept the invite yourself; nothing else is sent."))
    eq(N.Main.hop.pending.name,"Bob"); eq(N.Main.invite.pending.target,"8000")
    slash("hop host 1"); eq(#sent,1); yes(log[#log]:find("Bob was asked 0 s ago",1,true),log[#log])
    slash("hop host 2"); eq(#sent,1); yes(log[#log]:find("one ask every 10 s",1,true),log[#log])
    advance(10); slash("hosts"); slash("hop host 2"); eq(#sent,2); eq(sent[2].target,"Dan"); eq(sent[2].text,"inv layer <LS 100 want 9000-0 25.0,75.0>")
    grouped=true; advance(60); slash("hosts"); slash("hop host 1"); eq(#sent,2); yes(log[#log]:find("leave your current group first",1,true))
    eq(forbidden,0)
end)
test("0.3.1 T2: hop host refuses stale lists, bad numbers, changed rows, reporters and our own layer",function()
    local N=loadAddon(); establish(N); chatBox(); guildLine("L 8000|100|h","Bob")
    slash("hop host 1"); eq(#sent,0); yes(log[#log]:find("run /le hosts first",1,true))
    slash("hosts"); slash("hop host 9"); eq(#sent,0); yes(log[#log]:find("no such number in the last /le hosts list",1,true))
    advance(121); slash("hop host 1"); eq(#sent,0); yes(log[#log]:find("run /le hosts first",1,true))
    -- the row changed after the list
    slash("hosts"); guildLine("L 9000|100|h","Bob"); slash("hop host 1"); eq(#sent,0); yes(log[#log]:find("hosts changed, check again",1,true))
    -- our own layer moved onto the host's key after the list (not ambiguous)
    slash("hosts")
    units.target={guid=npc(3,7,"9000"),player=false}; deliver("PLAYER_TARGET_CHANGED"); drain(); advance(.1)
    units.mouseover={guid=npc(4,7,"9000"),player=false}; deliver("UPDATE_MOUSEOVER_UNIT"); drain(); advance(.1)
    eq(N.Main.store.bulo,"9000-7")
    slash("hop host 1"); eq(#sent,0); yes(log[#log]:find("on your layer already",1,true),log[#log])
    -- a War Effort reporter row has no layer: no hop, pointed to /le ask
    N=loadAddon(); establish(N); chatBox(); hopReport(1,8000)
    slash("hosts"); yes(logged("1. Scout | layer unknown"))
    slash("hop host 1"); eq(#sent,0); eq(#opened,0); yes(log[#log]:find("/le ask 1",1,true),log[#log]); eq(forbidden,0)
end)
test("0.3.1 T2: the Friendly button hops via the host, one message per click",function()
    local N=loadAddon(); establish(N); chatBox(); guildLine("L 8000|100|h","Bob")
    local U=N.UI; U.toggle(); U.select("friendly")
    local r=U.pool[1]; eq(r.title.text,"Bob"); eq(r.ask.label.text,"Hop via Bob"); eq(r.ask.reason,"one LayerSwap request whispered to Bob (Bulo)")
    no(r.ask.disabled)
    r.ask:Click(); drain(); eq(#sent,1); eq(sent[1].target,"Bob"); eq(#opened,0)
    U.render(); yes(r.ask.disabled,"cooldown after the click"); r.ask:Click(); drain(); eq(#sent,1)
    -- a reporter row keeps "Ask for invite" (chat box)
    N=loadAddon(); establish(N); chatBox(); hopReport(1,8000); U=N.UI; U.toggle(); U.select("friendly")
    eq(U.pool[1].ask.label.text,"Ask for invite"); U.pool[1].ask:Click(); drain(); eq(#sent,0); eq(#opened,1)
end)
test("0.3.1 T4: a heard|h reply from the asked player is remembered for 12 minutes, read-only",function()
    local N=loadAddon(); establish(N); guildLine("L 8000|100|h","Bob")
    slash("hosts"); slash("hop host 1"); eq(#sent,1)
    local function reply(text,from,kind) deliver("CHAT_MSG_ADDON","LayerSwap",text,kind or "WHISPER",from or "Bob"); drain() end
    reply("heard Me|8000-12|100|h"); eq(#sent,1,"storing sends nothing")
    yes(N.Main.heard.heard.Bob); eq(N.Main.heard.heard.Bob.layer,"8000-12"); eq(N.Main.heard.heard.Bob.zone,100)
    -- the Bulo line goes; Bob stays a LayerSwap host with uid 12
    N.Main.guildLines.Bob=nil
    local list=N.Main.candidates(); eq(#list,1); eq(list[1].name,"Bob"); eq(list[1].uid,12); eq(table.concat(list[1].sources,"+"),"LayerSwap")
    advance(60); slash("hosts"); slash("hop host 1"); eq(#sent,2); eq(sent[2].text,"inv layer <LS 100 want 8000-12 25.0,75.0>")
    -- a "-" reply removes him
    reply("heard Me|8000-12|100|-"); eq(N.Main.heard.heard.Bob,nil); eq(#N.Main.candidates(),0)
    -- 12 minutes later the entry is gone
    advance(61); guildLine("L 8000|100|h","Bob"); slash("hosts"); slash("hop host 1"); eq(#sent,3)
    reply("heard Me|8000-12|100|h"); N.Main.guildLines.Bob=nil; eq(#N.Main.candidates(),1)
    advance(719); eq(#N.Main.candidates(),1); advance(2); eq(#N.Main.candidates(),0); eq(N.Main.heard.heard.Bob,nil)
    eq(forbidden,0)
end)
test("0.3.1 T4: replies not from the asked player, not on WHISPER, late or for someone else are not stored",function()
    local N=loadAddon(); establish(N); guildLine("L 8000|100|h","Bob")
    local function reply(text,from,kind) deliver("CHAT_MSG_ADDON","LayerSwap",text,kind or "WHISPER",from or "Bob"); drain() end
    reply("heard Me|8000-12|100|h"); eq(next(N.Main.heard.heard),nil,"nothing asked yet")
    slash("hosts"); slash("hop host 1"); eq(#sent,1)
    reply("heard Me|8000-12|100|h","Cora"); reply("heard Me|8000-12|100|h","Bob","GUILD")
    reply("heard Someone|8000-12|100|h"); reply("heard Me|8000|100|h")
    eq(next(N.Main.heard.heard),nil)
    advance(121); reply("heard Me|8000-12|100|h"); eq(next(N.Main.heard.heard),nil,"after 120 s")
    eq(#sent,1)
end)
test("0.3.1 T4: with LayerSwap installed its own book is used and ours is ignored; the store is capped",function()
    local N=loadAddon(); establish(N); guildLine("L 8000|100|h","Bob")
    slash("hosts"); slash("hop host 1")
    deliver("CHAT_MSG_ADDON","LayerSwap","heard Me|8000-12|100|h","WHISPER","Bob"); drain(); yes(N.Main.heard.heard.Bob)
    N.Main.guildLines.Bob=nil; LayerSwapDB={book={}}
    eq(#N.Main.candidates(),0,"LayerSwap's own (empty) book wins")
    LayerSwapDB=nil; eq(#N.Main.candidates(),1)
    -- at most 64 names, the oldest dropped; entries older than 720 s pruned
    local Hs=N.Hosts; local st=Hs.new()
    for i=1,70 do Hs.heard(st,"Name"..string.char(96+math.ceil(i/26))..string.char(96+(i-1)%26+1),{kind="heard",layer="8000-1",zone=100,hosting=true},1000+i) end
    eq(N.Safe.count(st.heard),64); eq(st.heard.Nameaa,nil); yes(st.heard.Namecr)
    Hs.prune(st,1007+719); eq(N.Safe.count(st.heard),64); Hs.prune(st,1007+720); eq(N.Safe.count(st.heard),63)
    -- a reply without layer or zone stores nothing
    local s2=Hs.new(); Hs.heard(s2,"Bob",{kind="heard",zone=100,hosting=true},1); Hs.heard(s2,"Cy",{kind="heard",layer="8000-1",hosting=true},1)
    Hs.heard(s2,"Di",{kind="same"},1); eq(next(s2.heard),nil)
end)
test("0.3.1 guardrails: 20 idle minutes with the new paths send nothing",function()
    local N=loadAddon(); chatBox()
    local U=N.UI; U.toggle(); U.select("friendly")
    for i=1,240 do
        guildLine("L 8000|100|h","Bob"); guildLine("Q","Bob"); guildLine("v 3.0.25","Bob")
        deliver("CHAT_MSG_ADDON","LayerSwap","heard Me|8000-12|100|h","WHISPER","Bob")
        deliver("CHAT_MSG_ADDON","LayerSwap","inv layer <LS 100 want 7086-0>","WHISPER","Bob")
        if i==60 then establish(N) end
        if i==120 then map=200; deliver("ZONE_CHANGED_NEW_AREA") end
        if i==180 then map=100; deliver("ZONE_CHANGED_NEW_AREA") end
        U.render(); advance(5)
    end
    eq(#sent,0); eq(#opened,0); eq(forbidden,0); no(N.Main.error)
end)

-- 0.4.0 Task 1: one LFSw "Q" on GUILD from a click, 60 s apart, never on its own.
local ASKED="asked the guild's Bulo users for their layers; answers take up to 6 s"
local function lfswSent() local n={}; for _,m in ipairs(sent) do if m.prefix=="LFSw" then n[#n+1]=m end end; return n end
test("0.4 T1: /le hosts find sends exactly one LFSw Q on GUILD, then waits 60 s",function()
    local N=loadAddon(); establish(N)
    slash("hosts"); yes(log[#log]:find("/le hosts find",1,true),"the hosts list ends naming /le hosts find")
    eq(#sent,0,"/le hosts alone sends nothing")
    -- (0.4.0 Task 7.4: the same click also sends one LEGW1 "F|1"; only the LFSw messages are counted here)
    slash("hosts find"); local q=lfswSent(); eq(#q,1); eq(q[1].text,"Q"); eq(q[1].kind,"GUILD"); eq(q[1].target,nil)
    yes(logged(ASKED))
    advance(59); slash("hosts find"); eq(#lfswSent(),1); yes(log[#log]:find("wait 1 s",1,true),log[#log])
    advance(1); slash("hosts find"); eq(#lfswSent(),2); eq(forbidden,0)
end)
test("0.4 T1: the 60 s limit is in Wire itself, and Wire takes only the literal Q",function()
    local N=loadAddon(); local Wr=N.Wire
    yes(Wr.send("LFSw","Q","GUILD")); local ok,why=Wr.send("LFSw","Q","GUILD"); no(ok); eq(why,"throttled"); eq(#sent,1)
    advance(59); ok,why=Wr.send("LFSw","Q","GUILD"); eq(why,"throttled"); advance(1); yes(Wr.send("LFSw","Q","GUILD")); eq(#sent,2)
    for _,x in ipairs({"L 8000|100|h","L 8000|100|-","v 3.0.25","QQ","q"," Q",""}) do ok,why=Wr.send("LFSw",x,"GUILD"); no(ok); eq(why,"bad text",x) end
    for _,k in ipairs({"WHISPER","PARTY","CHANNEL","RAID"}) do ok,why=Wr.send("LFSw","Q",k,"Bob"); no(ok); eq(why,"blocked route",k) end
    eq(#sent,2)
    -- the stamp is set before the client is asked: a client throttle does not allow a quick retry
    N=loadAddon(); Wr=N.Wire; sendResult=3; ok,why=Wr.send("LFSw","Q","GUILD"); eq(why,"throttled"); eq(#sent,1)
    sendResult=0; ok,why=Wr.send("LFSw","Q","GUILD"); no(ok); eq(why,"paused","1.0: the prefix pauses 30 s"); eq(#sent,1)
    advance(31); ok,why=Wr.send("LFSw","Q","GUILD"); eq(why,"throttled","then the 60 s"); eq(#sent,1); eq(forbidden,0)
end)
test("0.4 T1: not in a guild, nothing is sent; an incoming Q is never answered",function()
    local N=loadAddon(); establish(N); inGuild=false
    slash("hosts find"); eq(#sent,0); yes(log[#log]:find("not in a guild",1,true),log[#log])
    inGuild=true
    for i=1,20 do guildLine("Q","Bob"..string.char(96+i)); advance(1) end
    deliver("CHAT_MSG_ADDON","LFSw","Q","WHISPER","Bob"); drain()
    eq(#sent,0)
end)
test("0.4 T1: the Find hosts button on the Friendly tab, one Q per click",function()
    local N=loadAddon(); establish(N); local U=N.UI; U.toggle(); U.select("friendly")
    yes(U.findHosts:IsShown()); eq(U.findHosts.label.text,"Find hosts")
    U.findHosts:Click(); drain(); eq(#lfswSent(),1); eq(sent[1].prefix,"LFSw")
    U.render(); yes(U.findHosts.disabled,"disabled while the 60 s run"); U.findHosts:Click(); eq(#lfswSent(),1)
    advance(60); U.render(); no(U.findHosts.disabled)
    U.select("reported"); no(U.findHosts:IsShown())
end)

-- 0.3.1 review fixes (S1-S3)
test("0.3.1 fix S1: own layer unknown, a report hop refuses with the hint, no draft even via the reporter",function()
    local N=loadAddon(); chatBox(); advance(1)
    guildLine("L 8000|100|h","Alpha"); hopReport(301,8000,"Alpha")
    local list=N.Main.candidates(); eq(#list,1); yes(list[1].unknownOwn)
    slash("reports"); eq(#N.Main.hopList.records,1)
    local r=N.Main.hopList.records[1]; local p=N.Main.hopPreview(r)
    no(p.enabled); eq(p.reason,N.Invite.HINT)
    slash("hop 1"); eq(#opened,0); eq(#sent,0); yes(logged(N.Invite.HINT))
    no(N.Main.hopTo(r,p)); eq(#opened,0); eq(#sent,0)
    -- the Reported row button is disabled with the hint
    local U=N.UI; U.toggle(); U.select("reported")
    local row; for _,x in ipairs(U.pool) do if x:IsShown() and x.hopRecord then row=x end end
    yes(row); yes(row.ask.disabled); eq(row.ask.reason,N.Invite.HINT)
    -- Hop.check refuses a candidate that is such a row; a plain reporter candidate passes (0.3.0)
    local ctx={grouped=false,zone=100,own={zone=100,server=nil}}
    local ok,why=N.Hop.check(r,{name="Alpha",short="alpha",addon=true,unknownOwn=true},ctx); no(ok); eq(why,N.Invite.HINT)
    yes(N.Hop.check(r,{name="Scout",short="scout",addon=false},ctx))
    -- the guild ask still needs our own key
    ok,why=N.Hop.guildRequest(N.Main.hop,r,{grouped=false,zone=100,own={zone=100,server=nil},invite=N.Main.invite,now=clock}); no(ok); eq(why,N.Invite.HINT)
end)
test("0.3.1 fix S2: hop host refuses when the host flag or the LayerSwap uid changed since the preview",function()
    local N=loadAddon(); establish(N); guildLine("L 8000|100|h","Alpha"); slash("hosts")
    local c=N.Main.hostList.rows[1]; local p=N.Main.hostPreview(c); yes(c.host); yes(p.enabled)
    guildLine("L 8000|100|-","Alpha")
    no(N.Main.hopHostTo(c,p)); eq(#sent,0); yes(logged("hosts changed, check again."))
    N=loadAddon(); establish(N); LayerSwapDB={book={Alpha=page({host=true,layer="8000-12"})}}; slash("hosts")
    c=N.Main.hostList.rows[1]; p=N.Main.hostPreview(c); eq(p.candidate.uid,12); yes(p.enabled)
    LayerSwapDB.book.Alpha.layer="8000-13"
    no(N.Main.hopHostTo(c,p)); eq(#sent,0); yes(logged("hosts changed, check again."))
    -- unchanged: one whisper with the shown uid
    LayerSwapDB.book.Alpha.layer="8000-12"; slash("hosts"); c=N.Main.hostList.rows[1]; p=N.Main.hostPreview(c)
    yes(N.Main.hopHostTo(c,p)); eq(#sent,1); yes(sent[1].text:find("want 8000-12",1,true),sent[1].text)
    -- a LayerSwap page whose host flag drops (same source, same uid): refused too
    N=loadAddon(); establish(N); LayerSwapDB={book={Alpha=page({host=true,layer="8000-12"})}}; slash("hosts")
    c=N.Main.hostList.rows[1]; p=N.Main.hostPreview(c); yes(c.host)
    LayerSwapDB.book.Alpha.host=false; no(N.Main.candidates()[1].host)
    no(N.Main.hopHostTo(c,p)); eq(#sent,0); yes(logged("hosts changed, check again."))
    -- /le hop host N compares against the listed row the same way
    N=loadAddon(); establish(N); LayerSwapDB={book={Alpha=page({host=true,layer="8000-12"})}}; slash("hosts")
    LayerSwapDB.book.Alpha.layer="8000-13"; slash("hop host 1"); eq(#sent,0); yes(logged("hosts changed, check again."))
end)
test("0.3.1 fix S3 and note: the hint names two different kinds of NPC; a non-host Bulo row says it may not answer",function()
    local N=loadAddon(); chatBox()
    eq(N.Invite.HINT,"Your layer is not known yet: target or mouse over two different kinds of NPC within 15 seconds.")
    local U=N.UI; U.toggle(); yes(U.meta.text:find("two different kinds of NPC within 15 s",1,true),U.meta.text)
    establish(N); guildLine("L 8000|100|-","Bravo"); slash("hosts")
    local p=N.Main.hostPreview(N.Main.hostList.rows[1]); yes(p.enabled)
    yes(p.detail:find("not hosting; may not answer",1,true),p.detail)
    local r=rec(N); local q=N.Main.hopPreview(r); eq(q.label,"Hop via Bravo"); yes(q.detail:find("not hosting; may not answer",1,true),q.detail)
    guildLine("L 8000|100|h","Bravo"); slash("hosts"); p=N.Main.hostPreview(N.Main.hostList.rows[1]); no(p.detail:find("may not answer",1,true))
end)
-- 0.4.0 Task 5: a prefilled guild-chat LayerSwap request; the player sends it with Enter, the addon sends nothing.
local GLINE="/g inv layer <LS 100 want 9500-0 25.0,75.0>"
local function guildRec(N,over) local o={src="guild",layer={ns="server",value="9500"}}; for k,v in pairs(over or {}) do o[k]=v end; return rec(N,o) end
test("0.4 T5: no one known on the layer: Ask guild (chat) drafts the exact /g line and sends nothing",function()
    local N=loadAddon(); establish(N); chatBox()
    local r=guildRec(N); local p=N.Main.hopPreview(r)
    eq(p.label,"Ask guild (chat)"); yes(p.enabled); eq(p.mode,"guild")
    yes(p.detail:find("you press Enter",1,true),p.detail)
    yes(N.Main.hopTo(r,p)); drain()
    eq(#sent,0,"the addon sends nothing"); eq(#opened,1); eq(opened[1].text,GLINE); eq(forbidden,0)
    yes(log[#log]:find("press Enter",1,true),log[#log])
    -- a second ask within 60 s drafts nothing; the 10 s overall limit applies to it as to any ask
    advance(30); no(N.Main.hopTo(r,N.Main.hopPreview(r))); drain(); eq(#opened,1); yes(log[#log]:find("wait 30 s",1,true),log[#log])
    advance(30); yes(N.Main.hopTo(r,N.Main.hopPreview(r))); drain(); eq(#opened,2)
    advance(61); guildLine("L 8000|100|h","Bob"); yes(hopNow(N,rec(N))); eq(#sent,1)
    no(N.Main.hopTo(r,N.Main.hopPreview(r))); drain(); eq(#opened,2); yes(log[#log]:find("one ask every 10 s",1,true),log[#log])
end)
test("0.4 T5: a known host or another precondition means no guild ask",function()
    local N=loadAddon(); establish(N); chatBox(); guildLine("L 9500|100|h","Bob")
    local p=N.Main.hopPreview(guildRec(N)); eq(p.label,"Hop via Bob"); no(p.mode=="guild")
    N=loadAddon(); establish(N); chatBox()
    grouped=true; p=N.Main.hopPreview(guildRec(N)); no(p.enabled); no(p.mode=="guild"); yes(p.reason:find("leave your current group",1,true)); grouped=false
    p=N.Main.hopPreview(guildRec(N,{zone=200})); no(p.mode=="guild"); yes(p.reason:find("travel to",1,true))
    p=N.Main.hopPreview(guildRec(N,{layer={ns="server",value="7086"},src="own"})); no(p.mode=="guild")
    -- shown as a guild ask, but a host appears before the click: nothing drafted, nothing sent
    local r=guildRec(N); p=N.Main.hopPreview(r); eq(p.mode,"guild")
    guildLine("L 9500|100|h","Mallory"); no(N.Main.hopTo(r,p)); drain(); eq(#opened,0); eq(#sent,0); yes(logged("hosts changed, check again."))
    -- shown as a guild ask, then grouped or the map shows another zone before the click: nothing drafted
    N=loadAddon(); establish(N); chatBox(); r=guildRec(N); p=N.Main.hopPreview(r); eq(p.mode,"guild")
    grouped=true; no(N.Main.hopTo(r,p)); drain(); eq(#opened,0); yes(log[#log]:find("leave your current group",1,true)); grouped=false
    map=200; no(N.Main.hopTo(r,p)); drain(); eq(#opened,0); yes(log[#log]:find("travel to",1,true)); map=100
end)
test("0.4 T5: GUILD heard replies are read for 120 s after our own guild ask, naming us, and stored as hosts",function()
    local N=loadAddon(); establish(N); chatBox()
    local function gheard(text,from) deliver("CHAT_MSG_ADDON","LayerSwap",text,"GUILD",from); drain() end
    gheard("heard Me|9500-4|100|h","Bob"); eq(next(N.Main.heard.heard),nil,"no guild ask yet")
    local r=guildRec(N); yes(N.Main.hopTo(r,N.Main.hopPreview(r))); drain()
    gheard("heard Someone|9500-4|100|h","Bob"); gheard("claim Me","Bob"); gheard("heard Me|9500|100|h","Bob"); eq(next(N.Main.heard.heard),nil)
    gheard("heard Me|9500-4|100|h","Bob"); yes(N.Main.heard.heard.Bob); eq(N.Main.heard.heard.Bob.layer,"9500-4")
    local list=N.Main.candidates(); eq(list[1].name,"Bob"); eq(list[1].uid,4)
    gheard("heard Me|9500-5|100|-","Cy"); eq(N.Main.heard.heard.Cy,nil)
    advance(121); gheard("heard Me|9500-6|100|h","Dee"); eq(N.Main.heard.heard.Dee,nil,"after 120 s")
    eq(#sent,0); eq(forbidden,0)
end)
test("0.4 T5: the Reported row button drafts the guild line",function()
    local N=loadAddon(); establish(N); chatBox()
    local r=guildRec(N); N.Store.report(N.Main.store,r,clock)
    local U=N.UI; U.toggle(); U.select("reported")
    local row; for _,x in ipairs(U.pool) do if x:IsShown() then row=x end end
    yes(row); eq(row.ask.label.text,"Ask guild (chat)"); no(row.ask.disabled)
    row.ask:Click(); drain(); eq(#opened,1); eq(opened[1].text,GLINE); eq(#sent,0)
end)

local N_G
-- 0.4.0 Task 7.1: guild-only host, pure parser and decision (GuildHost.lua). Nothing is sent or invited here.
local function gh(N) return N.GuildHost end
local function ownState(over)
    local o={self="me",zone=100,key="8000",id="8000-7",inInstance=false,inCombat=false,raid=false,leader=false,members={},asking=false,member=true}
    for k,v in pairs(over or {}) do o[k]=v end
    return o
end
local function req(text,name) local r=assert(N_G.parse(text),text); r.name=name or "Bob"; return r end
test("0.4 T7.1: parse accepts only the full want/not grammar",function()
    local N=loadAddon(); local G=gh(N); N_G=G
    local r=G.parse("inv layer <LS 100 want 8000-12 25.0,75.0>"); eq(r.zone,100); eq(r.want,"8000-12"); eq(r.x,25); eq(r.y,75); eq(r.nots,nil)
    r=G.parse("inv layer <LS 1429 want 7086-0>"); eq(r.zone,1429); eq(r.want,"7086-0"); eq(r.x,nil)
    r=G.parse("inv layer <LS 100 not 7086-3>"); eq(r.want,nil); eq(#r.nots,1); eq(r.nots[1],"7086-3")
    r=G.parse("inv layer <LS 100 not 7086-3 not 8000-1 not 9000-2 48.2,42.5>"); eq(#r.nots,3); eq(r.nots[3],"9000-2"); eq(r.x,48.2)
    for _,bad in ipairs({"inv layer <LS 100>","inv layer <LS 100 25.0,75.0>","inv layer <LS 100 want 8000-12> extra","x inv layer <LS 100 want 8000-1>",
        "inv layer <LS 100 want 8000>","inv layer <LS 100 want 8000-1 not 7000-1>","inv layer <LS 100 not 7000-1 want 8000-1>",
        "inv layer <LS abc want 8000-1>","inv layer <LS 100  want 8000-1>","inv layer <LS 100 want 8000-1 25.0>","inv layer <LS 100 want 8000-1 a,b>",
        "inv layer <LS 1234567890 want 8000-1>","inv layer <LS 100 want 8000-1>"..string.rep(" ",200),"",5,nil,secret,
        "INV LAYER <LS 100 want 8000-1>","inv layer <LS 100 want 8000-1-2>"}) do
        eq(G.parse(bad),nil,tostring(type(bad)=="string" and bad or type(bad)))
    end
    eq(G.parse("inv layer <LS 100 want "..string.rep("1",230).."-1>"),nil,"over 255 bytes")
end)
test("0.4 T7.1: decide order: hosting, name, 60 s per asker, zone, key, instance, combat, guild",function()
    local N=loadAddon(); local G=gh(N); N_G=G
    local st=G.new(); local R=req("inv layer <LS 100 want 8000-12 25.0,75.0>")
    eq((G.decide(st,R,ownState(),100)),"drop","hosting off")
    st.on=true
    eq((G.decide(st,req("inv layer <LS 100 want 8000-1>","Me"),ownState(),100)),"drop","our own name")
    eq((G.decide(st,req("inv layer <LS 100 want 8000-1>","Bad|Name"),ownState(),100)),"drop","bad name")
    for _,c in ipairs({{zone=200},{zone=false},{key=false},{inInstance=true},{inInstance="?"},{inCombat=true},{member=false},{member="?"}}) do
        local o=ownState(); for k,v in pairs(c) do if v==false and (k=="zone" or k=="key") then o[k]=nil else o[k]=v end end
        local s=G.new(); s.on=true
        local v,reply=G.decide(s,R,o,100); eq(v,"drop"); eq(reply,nil)
    end
    -- combat unreadable counts as in combat
    local s=G.new(); s.on=true; local o=ownState(); o.inCombat=nil; eq((G.decide(s,R,o,100)),"drop")
    -- guild membership unreadable (nil) is no
    s=G.new(); s.on=true; o=ownState(); o.member=nil; eq((G.decide(s,R,o,100)),"drop")
    -- instance unreadable (nil) is no
    s=G.new(); s.on=true; o=ownState(); o.inInstance=nil; eq((G.decide(s,R,o,100)),"drop")
    -- request zone other than ours
    s=G.new(); s.on=true; eq((G.decide(s,req("inv layer <LS 101 want 8000-1>"),ownState(),100)),"drop")
end)
test("0.4 T7.1: want and not rules with their replies",function()
    local N=loadAddon(); local G=gh(N); N_G=G
    local function fresh() local s=G.new(); s.on=true; return s end
    local v,reply=G.decide(fresh(),req("inv layer <LS 100 want 8000-12 25.0,75.0>"),ownState(),100); eq(v,"invite"); eq(reply,"heard Bob|8000-7|100|h")
    v,reply=G.decide(fresh(),req("inv layer <LS 100 want 9000-0>"),ownState(),100); eq(v,"busy"); eq(reply,"heard Bob|8000-7|100|-","carries our real layer")
    v,reply=G.decide(fresh(),req("inv layer <LS 100 not 8000-3>"),ownState(),100); eq(v,"same"); eq(reply,"same")
    v,reply=G.decide(fresh(),req("inv layer <LS 100 not 9000-3>"),ownState(),100); eq(v,"invite"); eq(reply,"heard Bob|8000-7|100|h")
    v,reply=G.decide(fresh(),req("inv layer <LS 100 not 9000-3 not 8000-1>"),ownState(),100); eq(v,"drop"); eq(reply,nil)
    -- without a zoneUID we answer with uid 0; a realm suffix on the asker is dropped from the reply
    v,reply=G.decide(fresh(),req("inv layer <LS 100 want 8000-1>","Bob-OtherRealm"),ownState({id=false}),100); eq(v,"invite"); eq(reply,"heard Bob|8000-0|100|h")
    v,reply=G.decide(fresh(),req("inv layer <LS 100 want 8000-1>","Tam Reed"),ownState(),100); eq(reply,"heard Tam Reed|8000-7|100|h")
end)
test("0.4 T7.1: group rule, own request, 10 s overall and 6 per 600 s give busy",function()
    local N=loadAddon(); local G=gh(N); N_G=G
    local R=function(n) return req("inv layer <LS 100 want 8000-1>",n or "Bob") end
    local function fresh() local s=G.new(); s.on=true; return s end
    for _,o in ipairs({ownState({raid=true}),ownState({members={"Cy"},leader=false}),ownState({members={"Cy"},leader=true}),ownState({asking=true})}) do
        local v,reply=G.decide(fresh(),R(),o,100); eq(v,"busy"); eq(reply,"heard Bob|8000-7|100|-")
    end
    -- a party whose members we all invited but that we do not lead: busy
    local s0=fresh(); s0.hosted.cy=true; eq((G.decide(s0,R(),ownState({members={"Cy"},leader=false}),100)),"busy","not the leader")
    -- a party we lead whose members we all invited, under five with pending: invite
    local s=fresh(); s.hosted.cy=true; local v=G.decide(s,R(),ownState({members={"Cy"},leader=true}),100); eq(v,"invite")
    -- four members, or three plus one pending: busy
    s=fresh(); for _,m in ipairs({"aa","bb","cc"}) do s.hosted[m]=true end; v=G.decide(s,R(),ownState({members={"Aa","Bb","Cc"},leader=true}),100); eq(v,"invite")
    s=fresh(); for _,m in ipairs({"aa","bb","cc","dd"}) do s.hosted[m]=true end; v=G.decide(s,R(),ownState({members={"Aa","Bb","Cc","Dd"},leader=true}),100); eq(v,"busy")
    s=fresh(); for _,m in ipairs({"aa","bb","cc"}) do s.hosted[m]=true end; s.pending.zz=100
    v=G.decide(s,R(),ownState({members={"Aa","Bb","Cc"},leader=true}),110); eq(v,"busy","three members plus one pending")
    -- 60 s per asker, 10 s overall, 6 per 600 s
    s=fresh(); eq((G.decide(s,R("Bob"),ownState(),1000)),"invite")
    eq((G.decide(s,R("Bob"),ownState(),1059)),"drop","same asker at 59 s")
    eq((G.decide(s,R("Cy"),ownState(),1009)),"busy","second asker at 9 s")
    s=fresh(); local t0=2000; local names={"Aa","Bb","Cc","Dd","Ee","Ff","Gg"}
    -- 61 s apart: a pending invite counts 60 s toward the group size
    for i=1,6 do eq((G.decide(s,R(names[i]),ownState(),t0+(i-1)*61)),"invite",names[i]) end
    eq((G.decide(s,R("Gg"),ownState(),t0+366)),"busy","seventh inside 600 s")
    eq((G.decide(s,R("Hh"),ownState(),t0+600)),"invite","the first has aged out")
end)
test("0.4 T7.1: the asker table is capped at 128 and the 60 s counts from the guild check",function()
    local N=loadAddon(); local G=gh(N); N_G=G
    local s=G.new(); s.on=true
    for i=1,140 do G.decide(s,req("inv layer <LS 100 want 9000-1>","N"..string.char(96+math.ceil(i/26))..string.char(96+(i-1)%26+1)),ownState(),i) end
    eq(N.Safe.count(s.asked),128)
    -- a drop before the guild check (other zone) does not start the 60 s
    s=G.new(); s.on=true
    eq((G.decide(s,req("inv layer <LS 101 want 8000-1>"),ownState(),10)),"drop"); eq((G.decide(s,req("inv layer <LS 100 want 8000-1>"),ownState(),11)),"invite")
    -- a non-member reached the guild check: 60 s
    s=G.new(); s.on=true
    eq((G.decide(s,req("inv layer <LS 100 want 8000-1>"),ownState({member=false}),10)),"drop")
    eq((G.decide(s,req("inv layer <LS 100 want 8000-1>"),ownState(),40)),"drop","within 60 s of the guild check")
end)

-- 0.4.0 Task 7.2: state adapters for the guild host (read only).
test("0.4 T7.2: guild membership: one online roster entry, exact name first, bare name only when unique",function()
    local N=loadAddon(); local A=N.Adapters
    roster={{"Bob-TestRealm",true},{"Tam Reed-TestRealm",true},{"Off-TestRealm",false},{"Two-RealmA",true},{"Two-RealmB",true}}
    eq(A.guildMember("Bob-TestRealm"),true); eq(A.guildMember("Bob"),true); eq(A.guildMember("Tam Reed"),true); eq(A.guildMember("Tam Reed-TestRealm"),true)
    eq(A.guildMember("Off"),false,"offline"); eq(A.guildMember("Off-TestRealm"),false,"offline, exact name"); eq(A.guildMember("Nobody"),false); eq(A.guildMember("Bob-OtherRealm"),false,"a different realm")
    eq(A.guildMember("Two"),false,"two entries with that bare name"); eq(A.guildMember("Two-RealmA"),true,"the exact name is unique")
    roster={{"Bob",true}}; eq(A.guildMember("Bob-TestRealm"),true,"roster without the realm")
    roster={{"Bob",true},{"Bob",true}}; eq(A.guildMember("Bob"),false,"duplicated exact name")
    -- unreadable is nil
    inGuild=false; roster={{"Bob",true}}; eq(A.guildMember("Bob"),nil); inGuild=true
    roster={}; eq(A.guildMember("Bob"),nil,"count 0")
    GetNumGuildMembers=function() return secret end; eq(A.guildMember("Bob"),nil)
    GetNumGuildMembers=function() return 1 end; GetGuildRosterInfo=function() error("x") end; eq(A.guildMember("Bob"),nil)
    GetGuildRosterInfo=function() return secret end; eq(A.guildMember("Bob"),nil)
    GetGuildRosterInfo=function() return "Bob",nil,nil,nil,nil,nil,nil,nil,secret end; eq(A.guildMember("Bob"),nil)
    eq(A.guildMember(secret),nil); eq(A.guildMember("Bad|Name"),nil)
    GetNumGuildMembers=nil; eq(A.guildMember("Bob"),nil)
end)
test("0.4 T7.2: roster age from GUILD_ROSTER_UPDATE, refresh at most every 15 s",function()
    local N=loadAddon(); local A=N.Adapters
    eq(A.rosterAge(clock),nil)
    deliver("GUILD_ROSTER_UPDATE",true); drain(); eq(A.rosterAge(clock),0); advance(30); eq(A.rosterAge(clock),30)
    yes(A.rosterRefresh(clock)); eq(rosterCalls,1)
    advance(14); no(A.rosterRefresh(clock)); eq(rosterCalls,1); advance(1); yes(A.rosterRefresh(clock)); eq(rosterCalls,2)
    C_GuildInfo=nil; advance(20); no(A.rosterRefresh(clock)); eq(rosterCalls,2)
    eq(#sent,0)
end)
test("0.4 T7.2: combat and party state; unreadable combat is in combat, unreadable party is nil",function()
    local N=loadAddon(); local A=N.Adapters
    eq(A.inCombat(),false); combat=true; eq(A.inCombat(),true); combat=false
    UnitAffectingCombat=function() return true end; eq(A.inCombat(),true); UnitAffectingCombat=function() return false end
    InCombatLockdown=function() return secret end; eq(A.inCombat(),true); InCombatLockdown=nil; eq(A.inCombat(),true)
    local p=A.party(); eq(p.raid,false); eq(p.leader,false); eq(#p.members,0)
    units.party1={name="Cy",realm=nil}; units.party2={name="Di",realm="OtherRealm"}; leader=true
    p=A.party(); eq(p.leader,true); eq(#p.members,2); eq(p.members[1],"Cy"); eq(p.members[2],"Di-OtherRealm")
    raid=true; p=A.party(); eq(p.raid,true); raid=false
    IsInRaid=function() return secret end; eq(A.party(),nil)
    IsInRaid=function() return false end; GetNumGroupMembers=function() error("x") end; eq(A.party(),nil)
end)

-- 0.4.0 Task 7.3: the invite (Wire.invite, the only party call) and the guild host wiring.
local function lsw(text,from) deliver("CHAT_MSG_ADDON","LayerSwap",text,"WHISPER",from or "Bob"); drain() end
local function hostReady(N,names)
    establish(N); roster={}
    for _,n in ipairs(names or {"Bob"}) do roster[#roster+1]={n.."-TestRealm",true} end
    slash("host on"); deliver("GUILD_ROSTER_UPDATE",true); drain()
    yes(N.Main.host.on,"hosting on"); sent={}
end
test("0.4 T7.3: Wire.invite keeps its own limits: 10 s, 60 s per name, 6 per 600 s; our realm dropped",function()
    local N=loadAddon(); local Wr=N.Wire
    yes(Wr.canInvite()); eq(#invites,0)
    -- (0.4.0 review M1: only our own realm is dropped; another realm stays in the invite)
    local ok,why=Wr.invite("Bob-TestRealm",clock); yes(ok); eq(why,"invited"); eq(invites[1],"Bob")
    ok,why=Wr.invite("Cy",clock+9); no(ok); eq(why,"throttled")
    ok,why=Wr.invite("Bob",clock+11); no(ok); eq(why,"throttled","same name inside 60 s")
    yes(Wr.invite("Cy",clock+12)); eq(invites[2],"Cy")
    yes(Wr.invite("Tam Reed",clock+60)); eq(invites[3],"Tam Reed")
    yes(Wr.invite("Bob",clock+120)); yes(Wr.invite("Di",clock+180)); yes(Wr.invite("Ed",clock+240))
    ok,why=Wr.invite("Fy",clock+300); no(ok); eq(why,"throttled","seventh inside 600 s"); eq(#invites,6)
    yes(Wr.invite("Fy",clock+611))
    for _,bad in ipairs({secret,"Bad|Name","B","",5}) do local o,w=Wr.invite(bad,clock+1000); no(o); eq(w,"bad name") end
    no(Wr.invite("Gy",secret))
    eq(forbidden,0)
    -- a client without the call: no invite, and canInvite says so
    N=loadAddon(); C_PartyInfo=nil; no(N.Wire.canInvite()); ok,why=N.Wire.invite("Bob",clock); no(ok); eq(why,"error")
    N=loadAddon(); C_PartyInfo={InviteUnit=function() error("x") end}; ok,why=N.Wire.invite("Bob",clock); no(ok); eq(why,"error")
    no(N.Wire.invite("Cy",clock+1),"the limit was spent before the client was asked")
end)
test("0.4 T7.3: LayerSwap whispers carry only the request, same or heard; replies one per 6 s",function()
    local N=loadAddon(); local Wr=N.Wire
    yes(Wr.send("LayerSwap","inv layer <LS 1429 want 7086-0 48.2,42.5>","WHISPER","Alice"))
    yes(Wr.send("LayerSwap","inv layer <LS 1429 not 7086-3>","WHISPER","Alice"))
    yes(Wr.send("LayerSwap","same","WHISPER","Alice"))
    local ok,why=Wr.send("LayerSwap","heard Alice|7086-7|100|h","WHISPER","Alice"); no(ok); eq(why,"throttled")
    advance(6); yes(Wr.send("LayerSwap","heard Tam Reed|7086-7|100|-","WHISPER","Tam Reed"))
    advance(6)
    for _,bad in ipairs({"x","hello","heard Alice|7086|100|h","heard Alice|7086-7|100|x","heard |7086-7|100|h","heard x|7086-7|100|h","heard Bad1|7086-7|100|h","same ","claim Alice",
        "inv layer <LS 1429>","inv layer <LS 1429 want 7086-0> x"}) do
        ok,why=Wr.send("LayerSwap",bad,"WHISPER","Alice"); no(ok,bad); eq(why,"bad text",bad)
    end
    yes(Wr.send("LayerSwap","heard Alice|7086-7|100|h","WHISPER","Alice"))
    -- requests are not part of the reply limit
    yes(Wr.send("LayerSwap","inv layer <LS 1429 want 7086-0>","WHISPER","Alice"))
    eq(forbidden,0)
end)
test("0.4 T7.3: hosting: off at load, on refused beside LayerSwap or Bulo or without the invite call",function()
    local N=loadAddon(); eq(N.Main.host.on,false)
    slash("host"); yes(logged("Hosting for your guild: off (saved)"))
    slash("host on"); yes(N.Main.host.on); eq(rosterCalls,1); yes(logged("Hosting for your guild is on"))
    slash("host"); yes(logged("Hosting for your guild: on (saved) · 0 invites in the last 10 minutes"))
    slash("host off"); no(N.Main.host.on); yes(logged("Hosting for your guild is off."))
    slash("host on"); N=loadAddon(); eq(N.Main.host.on,false,"a fresh profile (no saved setting) starts off")
    loaded.LayerSwap=true; slash("host on"); no(N.Main.host.on); yes(logged("LayerSwap")); loaded.LayerSwap=nil
    loaded.BuloLayerForever=true; slash("host on"); no(N.Main.host.on); yes(logged("BuloLayerForever")); loaded.BuloLayerForever=nil
    inGuild=false; slash("host on"); no(N.Main.host.on); yes(logged("not in a guild")); inGuild=true
    C_PartyInfo=nil; slash("host on"); no(N.Main.host.on); yes(logged("no party invite")); eq(#sent,0)
end)
test("0.4 T7.3: a guild member's request: one reply, at most one invite, one line",function()
    local N=loadAddon(); hostReady(N,{"Bob","Cy","Di","Ed"})
    lsw("inv layer <LS 100 want 7086-0 25.0,75.0>","Bob")
    eq(#sent,1); eq(sent[1].prefix,"LayerSwap"); eq(sent[1].kind,"WHISPER"); eq(sent[1].target,"Bob"); eq(sent[1].text,"heard Bob|7086-7|100|h")
    eq(#invites,1); eq(invites[1],"Bob"); yes(logged("LayerEnemies: invited Bob to your layer (guild host)."))
    advance(11); lsw("inv layer <LS 100 want 9000-0>","Cy"); eq(#sent,2); eq(sent[2].text,"heard Cy|7086-7|100|-"); eq(#invites,1)
    advance(11); lsw("inv layer <LS 100 not 7086-3>","Di"); eq(#sent,3); eq(sent[3].text,"same"); eq(#invites,1)
    -- not a member, offline, a request on GUILD or PARTY, a guild-chat line: nothing
    advance(11); lsw("inv layer <LS 100 want 7086-0>","Zed"); eq(#sent,3)
    roster[4][2]=false; lsw("inv layer <LS 100 want 7086-0>","Ed"); eq(#sent,3)
    for _,k in ipairs({"GUILD","PARTY","CHANNEL"}) do deliver("CHAT_MSG_ADDON","LayerSwap","inv layer <LS 100 want 7086-0>",k,"Bob") end
    guildLine("inv layer <LS 100 want 7086-0>","Bob"); drain(); eq(#sent,3); eq(#invites,1)
    -- hosting off, or LayerSwap loaded while on: nothing
    advance(61); slash("host off"); lsw("inv layer <LS 100 want 7086-0>","Bob"); eq(#sent,3)
    -- turning hosting on again announces one LEGW1 H (Task 7.4); the request beside LayerSwap gets nothing
    slash("host on"); eq(#sent,4); eq(sent[4].text,"H|1|7086|100"); deliver("GUILD_ROSTER_UPDATE",true); loaded.LayerSwap=true; lsw("inv layer <LS 100 want 7086-0>","Bob"); eq(#sent,4); eq(#invites,1)
    loaded.LayerSwap=nil; lsw("inv layer <LS 100 want 7086-0>","Bob"); eq(#invites,2)
    slash("host"); yes(logged("2 invites in the last 10 minutes"))
    -- a bad line or a secret sender: nothing
    advance(61); lsw("inv layer <LS 100>","Cy"); lsw("inv layer <LS 100 want 7086-0>",secret); eq(#invites,2)
    eq(forbidden,0)
end)
test("0.4 T7.3: unreadable party, combat or own layer fails closed",function()
    local N=loadAddon(); hostReady(N,{"Bob"})
    IsInRaid=function() return secret end; lsw("inv layer <LS 100 want 7086-0>","Bob"); eq(#invites,0); IsInRaid=function() return false end
    advance(61); combat=true; lsw("inv layer <LS 100 want 7086-0>","Bob"); eq(#invites,0); eq(#sent,1,"busy reply for the unreadable party only"); combat=false
    -- the map shows another zone than the store (no zone event yet): our zone is unknown, nothing (fresh roster)
    advance(61); deliver("GUILD_ROSTER_UPDATE",true); map=200; lsw("inv layer <LS 100 want 7086-0>","Bob"); eq(#invites,0); eq(#sent,1); map=100
    -- everything readable again, roster 61 s old: one invite
    advance(61); lsw("inv layer <LS 100 want 7086-0>","Bob"); eq(#invites,1)
end)
test("0.4 T7.3: a stale roster: one refresh, the request held in one slot for 5 s",function()
    local N=loadAddon(); establish(N); roster={{"Bob",true},{"Cy",true},{"Di",true}}
    slash("host on"); eq(rosterCalls,1); sent={}
    -- no roster yet: held, no reply and no invite; the update decides it
    lsw("inv layer <LS 100 want 7086-0>","Bob"); eq(#sent,0); eq(#invites,0); eq(rosterCalls,1,"15 s since the last refresh")
    advance(3); deliver("GUILD_ROSTER_UPDATE",true); drain(); eq(#invites,1); eq(invites[1],"Bob")
    -- 121 s later the roster is stale again: one refresh; a newer request replaces the held one
    advance(121); lsw("inv layer <LS 100 want 7086-0>","Cy"); eq(rosterCalls,2); lsw("inv layer <LS 100 want 7086-0>","Di"); eq(rosterCalls,2)
    advance(2); deliver("GUILD_ROSTER_UPDATE",true); drain(); eq(#invites,2); eq(invites[2],"Di")
    -- no update within 5 s: nothing
    advance(121); lsw("inv layer <LS 100 want 7086-0>","Cy"); advance(6); deliver("GUILD_ROSTER_UPDATE",true); drain(); eq(#invites,2)
    -- a request failing an early check never asks for the roster
    advance(121); local calls=rosterCalls; lsw("inv layer <LS 101 want 7086-0>","Cy"); eq(rosterCalls,calls)
    eq(forbidden,0)
end)
test("0.4 T7.3: 20 idle minutes with hosting on: nothing sent, nothing invited",function()
    local N=loadAddon(); hostReady(N,{"Bob"})
    for i=1,120 do
        advance(10)
        if i%10==0 then deliver("GUILD_ROSTER_UPDATE",true) end
        if i%30==0 then map=(map==100) and 101 or 100; deliver("ZONE_CHANGED_NEW_AREA") end
        if i%45==0 then deliver("GROUP_ROSTER_UPDATE") end
        drain()
    end
    eq(#sent,0); eq(#invites,0); eq(forbidden,0)
end)
test("0.4 T7.3: the window toggle and the hosting line",function()
    local N=loadAddon(); establish(N); local U=N.UI; U.toggle(); U.select("friendly")
    yes(U.host:IsShown()); eq(U.host.label.text,"Host: off"); no(U.hosting:IsShown())
    deliver("GUILD_ROSTER_UPDATE",true); drain()   -- an H needs a guild roster read this session (review 6c)
    U.host:Click(); drain(); yes(N.Main.host.on); eq(U.host.label.text,"Host: on"); yes(U.hosting:IsShown()); eq(U.hosting.text,"Hosting for your guild (stays on after reload)")
    U.select("reported"); no(U.host:IsShown()); yes(U.hosting:IsShown(),"the line stays visible while on")
    U.select("friendly"); U.host:Click(); drain(); no(N.Main.host.on); no(U.hosting:IsShown())
    -- the only message: the H from turning hosting on (Task 7.4); the refused click beside LayerSwap sends nothing
    loaded.LayerSwap=true; U.host:Click(); drain(); no(N.Main.host.on); eq(#sent,1); eq(sent[1].text,"H|1|7086|100")
end)

-- 0.4.0 Task 7.4: finding a LayerEnemies host: "F|1" from the Find hosts click, "H|1|<key>|<zone>" from a host.
local function legw(text,from,kind) deliver("CHAT_MSG_ADDON","LEGW1",text,kind or "GUILD",from or "Bob"); drain() end
local function legwSent(prefix) local out={}; for _,m in ipairs(sent) do if m.prefix=="LEGW1" and m.text:sub(1,#prefix)==prefix then out[#out+1]=m end end; return out end
test("0.4 T7.4: a 0.3.1 decoder rejects F and H lines as invalid; Relay builds and reads them strictly",function()
    local N=loadAddon(); local R=N.Relay
    for _,s in ipairs({"F|1","H|1|8000|100"}) do local rec,why=R.decode(s,"Bob",clock); eq(rec,nil); eq(why,"invalid") end
    eq(R.findLine(),"F|1"); eq(R.hostLine("8000",100),"H|1|8000|100"); eq(R.hostLine(nil,100),nil); eq(R.hostLine("8000",nil),nil)
    local c=R.control("F|1"); eq(c.kind,"F"); c=R.control("H|1|8000|100"); eq(c.kind,"H"); eq(c.key,"8000"); eq(c.zone,100)
    for _,bad in ipairs({"F|2","F|1|x","F","H|1|8000","H|1|8000|100|x","H|2|8000|100","H|1|abc|100","H|1|8000|0","H|1|8000|abc","H|1|-1|100",
        "R|1|x",secret,5,"H|1|"..string.rep("9",40).."|100","H|1|1234567890123456|100"}) do eq(R.control(bad),nil,tostring(type(bad)=="string" and bad or type(bad))) end
end)
test("0.4 T7.4: Find hosts sends one Q and one F|1, once per 60 s; outside a guild neither",function()
    local N=loadAddon(); establish(N)
    slash("hosts find"); eq(#sent,2); eq(sent[1].prefix,"LFSw"); eq(sent[2].prefix,"LEGW1"); eq(sent[2].text,"F|1"); eq(sent[2].kind,"GUILD")
    advance(30); slash("hosts find"); eq(#sent,2)
    advance(31); slash("hosts find"); eq(#sent,4)
    -- the F limit is in Wire too
    local ok,why=N.Wire.send("LEGW1","F|1","GUILD"); no(ok); eq(why,"throttled")
    no(N.Wire.send("LEGW1","F|2","GUILD")); no(N.Wire.send("LEGW1","H|1|8000","GUILD"))
    N=loadAddon(); inGuild=false; slash("hosts find"); eq(#sent,0); inGuild=true
    eq(forbidden,0)
end)
test("0.4 T7.4: turning hosting on announces H once; an F gets one H 1 to 6 s later, at most once per 60 s",function()
    local N=loadAddon(); establish(N); roster={{"Bob-TestRealm",true}}
    deliver("GUILD_ROSTER_UPDATE",true); drain()   -- an H needs a guild roster read this session (review 6c)
    slash("host on"); local h=legwSent("H|"); eq(#h,1); eq(h[1].text,"H|1|7086|100"); eq(h[1].kind,"GUILD")
    advance(61); legw("F|1","Bob"); eq(#legwSent("H|"),1,"not at once"); advance(7); drain(); eq(#legwSent("H|"),2)
    advance(10); legw("F|1","Cy"); advance(7); drain(); eq(#legwSent("H|"),2,"second F inside 60 s")
    advance(50); legw("F|1","Cy"); legw("F|1","Di"); advance(7); drain(); eq(#legwSent("H|"),3,"two F, one H")
    -- our own F, an F on PARTY or WHISPER: nothing
    advance(61); legw("F|1","Me"); legw("F|1","Bob","PARTY"); legw("F|1","Bob","WHISPER"); advance(7); drain(); eq(#legwSent("H|"),3)
    -- the H limit is in Wire too
    local ok,why=N.Wire.send("LEGW1","H|1|7086|100","GUILD"); yes(ok); ok,why=N.Wire.send("LEGW1","H|1|7086|100","GUILD"); no(ok); eq(why,"throttled")
    eq(#invites,0); eq(forbidden,0)
end)
test("0.4 T7.4: no H when hosting is off, our layer or zone unknown, or LayerSwap loaded",function()
    local N=loadAddon(); establish(N)
    legw("F|1","Bob"); advance(7); drain(); eq(#sent,0,"hosting off")
    N=loadAddon(); slash("host on"); eq(#legwSent("H|"),0,"own layer unknown: no announcement"); yes(N.Main.host.on)
    legw("F|1","Bob"); advance(7); drain(); eq(#legwSent("H|"),0)
    N=loadAddon(); establish(N); deliver("GUILD_ROSTER_UPDATE",true); drain(); slash("host on"); eq(#legwSent("H|"),1); advance(61)
    loaded.LayerSwap=true; legw("F|1","Bob"); advance(7); drain(); eq(#legwSent("H|"),1); loaded.LayerSwap=nil
    -- hosting turned off while the answer waits: nothing
    advance(61); legw("F|1","Bob"); slash("host off"); advance(7); drain(); eq(#legwSent("H|"),1)
end)
test("0.4 T7.4: a guild H is remembered 12 minutes as a host on <key>-0; /le hop host asks it",function()
    local N=loadAddon(); establish(N)
    legw("H|1|8000|100","Bob")
    local list=N.Main.candidates(); eq(#list,1); eq(list[1].name,"Bob"); eq(list[1].layer,"8000"); yes(list[1].host)
    slash("hosts"); slash("hop host 1"); eq(#sent,1); eq(sent[1].prefix,"LayerSwap"); eq(sent[1].target,"Bob"); yes(sent[1].text:find("want 8000-0",1,true),sent[1].text)
    -- from us, ignored, not GUILD, malformed: not stored
    N=loadAddon(); establish(N)
    legw("H|1|8000|100","Me"); legw("H|1|8000|100","Bob","PARTY"); legw("H|1|8000|100","Bob","WHISPER"); legw("H|1|abc|100","Bob")
    clientIgnored=true; legw("H|1|8000|100","Cy"); clientIgnored=false
    eq(#N.Main.candidates(),0); eq(next(N.Main.heard.heard),nil,"nothing stored")
    legw("H|1|8000|100","Dee"); eq(#N.Main.candidates(),1); advance(721); wall=wall+721; eq(#N.Main.candidates(),0,"12 minutes")
    eq(#sent,0); eq(forbidden,0)
end)
-- 0.4.0 (owner decision): the hosting toggle is saved, a boolean setting only (LayerEnemiesDB.guildHost).
local function reload(N) N.Main.started=false; N.Main.start(); drain() end
local ONLINE="LayerEnemies: hosting for your guild is ON (/le host off to stop)."
test("0.4 host saved: on survives a reload and is active; one login line; no H at login",function()
    local N=loadAddon(); establish(N); roster={{"Bob-TestRealm",true}}
    deliver("GUILD_ROSTER_UPDATE",true); drain()   -- an H needs a guild roster read this session (review 6c)
    slash("host on"); eq(LayerEnemiesDB.guildHost,true); eq(#sent,1,"the H from turning it on")
    advance(16); reload(N); yes(N.Main.host.on); eq(lines(ONLINE),1); eq(LayerEnemiesDB.guildHost,true)
    eq(#sent,1,"nothing sent at login"); eq(rosterCalls,2,"one roster request at login")
    -- after a reload our layer is learned again from NPCs before a request can be answered
    lsw("inv layer <LS 100 want 7086-0>","Bob"); eq(#invites,0); eq(#sent,1)
    establish(N); deliver("GUILD_ROSTER_UPDATE",true); drain(); advance(61); lsw("inv layer <LS 100 want 7086-0>","Bob"); eq(#invites,1)
    slash("host"); yes(logged("Hosting for your guild: on (saved) · 1 invite in the last 10 minutes"))
    for k,v in pairs(LayerEnemiesDB) do yes(k=="options" or k=="tracked" or k=="position" or k=="guildHost" or k=="autoHop" or k=="consent" or k=="nets" or k=="share" or k=="netNotice",k) end
    eq(type(LayerEnemiesDB.guildHost),"boolean")
end)
test("0.4 host saved: off persists; a bad saved value is off",function()
    local N=loadAddon(); establish(N)
    slash("host on"); slash("host off"); eq(LayerEnemiesDB.guildHost,false)
    reload(N); no(N.Main.host.on); eq(lines("hosting for your guild is ON"),0); eq(LayerEnemiesDB.guildHost,false)
    slash("host"); yes(logged("Hosting for your guild: off (saved)"))
    LayerEnemiesDB.guildHost="yes"; reload(N); no(N.Main.host.on); eq(LayerEnemiesDB.guildHost,false)
    LayerEnemiesDB=nil; reload(N); no(N.Main.host.on); eq(LayerEnemiesDB.guildHost,false)
end)
test("0.4 host saved: on but inactive at login says why, answers nothing, stays saved",function()
    local cases={
        {function() loaded.LayerSwap=true end,function() loaded.LayerSwap=nil end,"LayerSwap is loaded"},
        {function() loaded.BuloLayerForever=true end,function() loaded.BuloLayerForever=nil end,"BuloLayerForever is loaded"},
        {function() C_PartyInfo=nil end,nil,"no party invite call"},
        {function() inGuild=false end,function() inGuild=true end,"not in a guild"},
    }
    for _,c in ipairs(cases) do
        local N=loadAddon(); establish(N); roster={{"Bob-TestRealm",true}}; slash("host on"); sent={}
        c[1](); reload(N)
        no(N.Main.host.on,c[3]); yes(N.Main.host.want); eq(LayerEnemiesDB.guildHost,true)
        yes(logged("LayerEnemies: hosting for your guild is ON but inactive: "),c[3]); yes(log[#log]:find(c[3],1,true),log[#log])
        yes(log[#log]:find("(/le host off to stop)",1,true))
        slash("host"); yes(logged("Hosting for your guild: on (saved) but inactive: "))
        deliver("GUILD_ROSTER_UPDATE",true); drain(); lsw("inv layer <LS 100 want 7086-0>","Bob"); eq(#sent,0); eq(#invites,0)
        eq(lines("hosting for your guild is ON but inactive"),1,"the inactive line only at login")
        if c[2] then c[2]() end
    end
    -- not in a guild at login (guild data late): it becomes active on the guild roster update, with one line
    local N=loadAddon(); establish(N); roster={{"Bob-TestRealm",true}}; slash("host on")
    inGuild=false; reload(N); no(N.Main.host.on); inGuild=true
    deliver("GUILD_ROSTER_UPDATE",true); drain(); yes(N.Main.host.on); eq(lines("LayerEnemies: hosting for your guild is now active."),1)
    deliver("GUILD_ROSTER_UPDATE",true); drain(); eq(lines("LayerEnemies: hosting for your guild is now active."),1)
    -- /le host off while inactive: off and saved off
    loaded.LayerSwap=true; reload(N); no(N.Main.host.on); slash("host off"); eq(LayerEnemiesDB.guildHost,false); no(N.Main.host.want); loaded.LayerSwap=nil
end)
test("0.4 host saved: the window line and toggle",function()
    local N=loadAddon(); establish(N); local U=N.UI; U.toggle(); U.select("friendly")
    slash("host on"); yes(logged("It stays on after a reload; /le host off stops it.")); U.render()
    eq(U.hosting.text,"Hosting for your guild (stays on after reload)"); eq(U.host.label.text,"Host: on")
    loaded.LayerSwap=true; reload(N); U.render(); yes(U.hosting:IsShown()); eq(U.host.label.text,"Host: on")
    yes(U.hosting.text:find("Hosting is on but inactive: ",1,true),U.hosting.text)
    U.host:Click(); drain(); no(N.Main.host.want); eq(LayerEnemiesDB.guildHost,false); no(U.hosting:IsShown()); eq(U.host.label.text,"Host: off")
end)

-- 0.4.0 Task 8: hiccup-free hop. Accept only the asked host's invite, leave only that group, after the move.
local function inviteFrom(name) popup.shown=true; popup.inviteAccepted=nil; deliver("PARTY_INVITE_REQUEST",name,false,false,false,true,false,false,"Player-1-0001",false); drain() end
local function joinParty(name) grouped=true; units.party1={name=name,leader=true}; deliver("GROUP_ROSTER_UPDATE"); drain() end
-- with Bulo installed (askBob) its layer moves; without it, two rounds of two NPC kinds (the zoneUID change resets
-- the votes, the second round confirms the new layer)
local BULO
local function moveTo(key,uid)
    if BULO then BULO.current=key.."-"..(uid or 9); BULO:Fire("LFS_LAYER",BULO.current); drain(); return end
    for r=0,1 do
        units.target={guid=npc(11+2*r,uid or 9,key),player=false}; deliver("PLAYER_TARGET_CHANGED"); drain(); advance(.1)
        units.mouseover={guid=npc(12+2*r,uid or 9,key),player=false}; deliver("UPDATE_MOUSEOVER_UNIT"); drain(); advance(.1)
    end
end
local function askBob(N) BULO=friends(N,{Bob=there({key="8000",host=true})}); advance(1); yes(hopNow(N,rec(N))); eq(sent[#sent].target,"Bob") end
test("0.4 T8: the asked host's invite is accepted, the popup hidden as accepted; the move then leaves after 3 s",function()
    local N=loadAddon(); BULO=nil; establish(N); askBob(N)
    advance(5); inviteFrom("Bob")
    eq(#accepts,1); no(popup.shown); eq(popup.inviteAccepted,1); yes(logged("LayerEnemies: accepted Bob's invite"))
    joinParty("Bob"); moveTo("8000")
    eq(N.Main.store.bulo,"8000-9"); yes(logged("LayerEnemies: moved to layer 8000, leaving the group"))
    eq(#leaves,0,"not before 3 s"); advance(3.1); drain(); eq(#leaves,1); no(grouped)
    advance(60); drain(); eq(#leaves,1,"once"); eq(forbidden,0)
    -- the ask is spent: a second invite from Bob afterwards is left to the player
    inviteFrom("Bob"); eq(#accepts,1); yes(popup.shown)
end)
test("0.4 T8: Wire keeps its own limits on accept and leave (10 s each)",function()
    local N=loadAddon(); local Wr=N.Wire
    yes(Wr.accept(clock)); local ok,why=Wr.accept(clock+9); no(ok); eq(why,"throttled"); yes(Wr.accept(clock+10)); eq(#accepts,2)
    grouped=true; yes(Wr.leave(clock)); ok,why=Wr.leave(clock+5); no(ok); eq(why,"throttled"); eq(#leaves,1)
    AcceptGroup=nil; ok,why=Wr.accept(clock+30); no(ok); eq(why,"error")
    C_PartyInfo=nil; ok,why=Wr.leave(clock+30); no(ok); eq(why,"error")
    -- a popup that cannot be found is never hidden
    popup.shown=false; no(Wr.hideInvite()); eq(popupHidden,0); eq(forbidden,0)
end)
test("0.4 T8: no move within 30 s of joining: leave and say the hop failed",function()
    local N=loadAddon(); BULO=nil; establish(N); askBob(N); inviteFrom("Bob"); joinParty("Bob")
    advance(29); drain(); eq(#leaves,0); advance(1.2); drain(); eq(#leaves,1)
    yes(logged("LayerEnemies: hop failed: Bob could not move you")); eq(forbidden,0)
end)
test("0.4 T8: another inviter, a late invite, grouped, instance or combat: nothing is accepted",function()
    local N=loadAddon(); BULO=nil; establish(N); askBob(N)
    inviteFrom("Mallory"); inviteFrom("Bob-OtherRealm"); inviteFrom("bobby"); eq(#accepts,0); yes(popup.shown,"left to the player")
    N=loadAddon(); BULO=nil; establish(N); askBob(N); advance(121); inviteFrom("Bob"); eq(#accepts,0)
    N=loadAddon(); BULO=nil; establish(N); askBob(N); grouped=true; inviteFrom("Bob"); eq(#accepts,0); grouped=false
    N=loadAddon(); BULO=nil; establish(N); askBob(N); inInstance=true; inviteFrom("Bob"); eq(#accepts,0); inInstance=false
    N=loadAddon(); BULO=nil; establish(N); askBob(N); combat=true; inviteFrom("Bob"); eq(#accepts,0); combat=false
    N=loadAddon(); BULO=nil; establish(N); askBob(N); InCombatLockdown=function() return secret end; inviteFrom("Bob"); eq(#accepts,0)
    -- no ask at all, or a manual /le ask whisper: nothing
    N=loadAddon(); BULO=nil; establish(N); inviteFrom("Bob"); eq(#accepts,0)
    N=loadAddon(); BULO=nil; establish(N); friends(N,{Bob=there({key="8000"})}); chatBox(); advance(1); yes(LE.AskInvite("Bob")); inviteFrom("Bob"); eq(#accepts,0)
    -- the same invite twice: one accept
    N=loadAddon(); BULO=nil; establish(N); askBob(N); inviteFrom("Bob"); inviteFrom("Bob"); eq(#accepts,1)
    eq(#leaves,0); eq(forbidden,0)
end)
test("0.4 T8: a group not joined through our hop is never left; leader changes, raid or our lead stop the leave",function()
    -- a group joined by hand (no ask)
    local N=loadAddon(); BULO=nil; establish(N); joinParty("Cy"); moveTo("8000"); advance(40); drain(); eq(#leaves,0)
    -- accepted Bob, but the group's leader is someone else
    N=loadAddon(); BULO=nil; establish(N); askBob(N); inviteFrom("Bob"); grouped=true; units.party1={name="Cy",leader=true}; deliver("GROUP_ROSTER_UPDATE"); drain()
    moveTo("8000"); advance(40); drain(); eq(#leaves,0)
    -- the group became a raid, or we became leader, after joining
    N=loadAddon(); BULO=nil; establish(N); askBob(N); inviteFrom("Bob"); joinParty("Bob"); raid=true; moveTo("8000"); advance(40); drain(); eq(#leaves,0); raid=false
    N=loadAddon(); BULO=nil; establish(N); askBob(N); inviteFrom("Bob"); joinParty("Bob"); units.party1.leader=false; leader=true; moveTo("8000"); advance(40); drain(); eq(#leaves,0); leader=false
    -- moved to a layer that is not the target: no "moved" leave; the 30 s failure leave still applies to our hop group
    N=loadAddon(); BULO=nil; establish(N); askBob(N); inviteFrom("Bob"); joinParty("Bob"); moveTo("9000"); advance(3.5); drain(); eq(#leaves,0)
    advance(30); drain(); eq(#leaves,1); yes(logged("hop failed: Bob could not move you"))
    -- we left by ourselves before the move: nothing left later
    N=loadAddon(); BULO=nil; establish(N); askBob(N); inviteFrom("Bob"); joinParty("Bob"); grouped=false; units.party1=nil; deliver("GROUP_ROSTER_UPDATE"); drain()
    advance(40); drain(); eq(#leaves,0); eq(forbidden,0)
end)
test("0.4 T8: the guild ask accepts an online guild member's invite only",function()
    local N=loadAddon(); BULO=nil; establish(N); chatBox(); roster={{"Bob-TestRealm",true},{"Off-TestRealm",false}}
    local r=rec(N,{src="guild",layer={ns="server",value="9500"}}); yes(N.Main.hopTo(r,N.Main.hopPreview(r))); drain(); eq(#opened,1)
    -- (round 2: armed when our /g line goes out; Bob, Off and Zed answered, so only the guild check decides here)
    deliver("CHAT_MSG_GUILD",GLINE:sub(4),"Me"); drain()
    for _,who in ipairs({"Bob","Off","Zed"}) do deliver("CHAT_MSG_ADDON","LayerSwap","heard Me|9500-3|100|h","GUILD",who) end; drain()
    inviteFrom("Zed"); inviteFrom("Off"); eq(#accepts,0)
    -- roster unreadable: no
    local count=GetNumGuildMembers; GetNumGuildMembers=function() return secret end; inviteFrom("Bob"); eq(#accepts,0); GetNumGuildMembers=count
    inviteFrom("Bob"); eq(#accepts,1); yes(logged("accepted Bob's invite"))
    joinParty("Bob"); moveTo("9500"); advance(3.1); drain(); eq(#leaves,1)
end)
test("0.4 T8: hostOwn carries our own name key (it was dropped by an and-expression in 7.3)",function()
    local N=loadAddon(); establish(N); eq(N.Main.hostOwn().self,"me")
end)
test("0.4 T8: Auto accept and leave: on by default, saved, /le hop auto and the toggle; off means manual",function()
    local N=loadAddon(); BULO=nil; establish(N); yes(N.Main.autoHop()); eq(LayerEnemiesDB.autoHop,true)
    slash("hop auto off"); no(N.Main.autoHop()); eq(LayerEnemiesDB.autoHop,false); yes(logged("Auto accept and leave is off"))
    askBob(N); inviteFrom("Bob"); eq(#accepts,0); yes(popup.shown)
    N.Main.started=false; N.Main.start(); drain(); no(N.Main.autoHop(),"saved off")
    slash("hop auto on"); yes(N.Main.autoHop()); eq(LayerEnemiesDB.autoHop,true); yes(logged("Auto accept and leave is on"))
    LayerEnemiesDB.autoHop="x"; N.Main.started=false; N.Main.start(); drain(); yes(N.Main.autoHop(),"a bad value is the default, on")
    -- turned off after accepting: the group is not left
    N=loadAddon(); BULO=nil; establish(N); askBob(N); inviteFrom("Bob"); joinParty("Bob"); slash("hop auto off"); moveTo("8000"); advance(40); drain(); eq(#leaves,0)
    -- the window toggle
    N=loadAddon(); BULO=nil; establish(N); local U=N.UI; U.toggle(); U.select("friendly")
    yes(U.auto:IsShown()); eq(U.auto.label.text,"Auto: on"); U.auto:Click(); drain(); no(N.Main.autoHop()); eq(U.auto.label.text,"Auto: off")
    U.select("reported"); no(U.auto:IsShown())
    for k in pairs(LayerEnemiesDB) do yes(k=="options" or k=="tracked" or k=="position" or k=="guildHost" or k=="autoHop" or k=="consent" or k=="nets" or k=="share" or k=="netNotice",k) end
    eq(forbidden,0)
end)

-- 1.0 T1: Wire routes with a text check each, budgets, queue and priority, offline skip; Net switches and consent.
local function netOn(N,...) for _,k in ipairs({...}) do N.Net.SHIP[k]=true end end
local GOOD_WE="H|0.1.0|1|100|7086|0|0|0"
test("1.0 T1: each route's text check: WEFF1 and HeadHunter carry only their planned types",function()
    local N=loadAddon(); local Wr=N.Wire; netOn(N,"we","hh"); N.Net.setConsent("public")
    local function t(prefix,text,kind,target,opts,want) local ok,why=Wr.send(prefix,text,kind,target,opts); eq(why,want,prefix.." "..tostring(text).." "..kind) end
    t("WEFF1",GOOD_WE,"GUILD",nil,{net="we"},"sent")
    t("WEFF1","Z|1","GUILD",nil,{net="we"},"bad text"); t("WEFF1","H|1","WHISPER","Bob",{net="we",scope="public"},"bad text")
    t("WEFF1","D|x","PARTY",nil,{net="we"},"bad text"); t("WEFF1","h|1","GUILD",nil,{net="we"},"bad text")
    t("WEFF1","P|x","WHISPER","Bob",{net="we",scope="public"},"sent")
    advance(10)
    for _,ty in ipairs({"P","L","D","T","U","V","X"}) do t("HeadHunter","1A"..ty..":x","WHISPER","Bob",{net="hh",scope="public"},"bad text") end
    t("HeadHunter","1AN:","WHISPER","Bob",{net="hh",scope="public"},"bad text"); t("HeadHunter","2AN:x","WHISPER","Bob",{net="hh",scope="public"},"bad text")
    t("HeadHunter","1AN:LayerEnemies","WHISPER","Bob",{net="hh",scope="public"},"sent")
    -- a network route without its net named in opts is refused
    t("WEFF1",GOOD_WE,"GUILD",nil,nil,"network off")
    eq(forbidden,0)
end)
test("1.0 T1: global budget: 8 at once, 1 per 1.5 s, never more than 40 in 60 s",function()
    local N=loadAddon(); local Wr=N.Wire
    local sentN=0
    local function try() local ok,why=Wr.send("LEGW1","R|1","GUILD",nil,{prio="own"}); if ok then sentN=sentN+1 end; return ok,why end
    netOn(N,"we")
    for i=1,8 do if i%2==0 then yes((try())) else yes((Wr.send("WEFF1",GOOD_WE,"GUILD",nil,{net="we",prio="own"}))) end end
    local ok,why=try(); no(ok); eq(why,"throttled")
    -- a different prefix shares the global budget
    ok,why=Wr.send("LFSw","Q","GUILD"); no(ok); eq(why,"throttled")
    -- 60 s of steady sends: the cap of 40 in any 60 s holds (8 + one per 1.5 s would be 48)
    N=loadAddon(); Wr=N.Wire; sentN=0
    local prefixes={"LEGW1","WEFF1"}; netOn(N,"we")
    for i=1,120 do
        Wr.send("LEGW1","R|"..i,"GUILD",nil,{prio="own"}); Wr.send("WEFF1",GOOD_WE,"PARTY",nil,{net="we",prio="own"})
        advance(0.5)
    end
    local inWindow=0; for _,m in ipairs(sent) do if m.at and m.at>clock-60 then inWindow=inWindow+1 end end
    -- the per-minute cap, checked on the send times
    local times={}; for _,m in ipairs(sent) do times[#times+1]=m.at end
    for i=1,#times do local n=0; for j=i,#times do if times[j]-times[i]<60 then n=n+1 end end; yes(n<=40,"window from "..i..": "..n) end
end)
test("1.0 T1: whispers outside guild and group: 4 a minute to one player, 20 a minute in total; consent guild sends none",function()
    local N=loadAddon(); local Wr=N.Wire; netOn(N,"hh"); N.Net.setConsent("public")
    local function hh(target) return Wr.send("HeadHunter","1AN:LayerEnemies","WHISPER",target,{net="hh",scope="public",prio="owed"}) end
    for i=1,4 do yes((hh("Bob"))); advance(2.1) end
    local ok,why=hh("Bob"); no(ok); eq(why,"throttled","5th to one player in a minute")
    advance(60); yes((hh("Bob")))
    N=loadAddon(); Wr=N.Wire; netOn(N,"hh"); N.Net.setConsent("public")
    local names={}; for i=1,26 do names[i]="Peer"..string.char(96+i) end
    local okN=0; for i=1,26 do if hh(names[i]) then okN=okN+1 end; advance(2.1) end
    eq(okN,20,"20 public whispers a minute")
    -- consent guild: no public whisper, guild scope still allowed
    N=loadAddon(); Wr=N.Wire; netOn(N,"hh","we"); N.Net.setConsent("guild")
    ok,why=hh("Bob"); no(ok); eq(why,"no consent")
    yes(Wr.send("WEFF1",GOOD_WE,"GUILD",nil,{net="we",scope="guild"}))
    -- no choice made: public (owner decision 2026-11-14)
    N=loadAddon(); Wr=N.Wire; netOn(N,"hh"); yes((hh("Bob")))
    eq(forbidden,0)
end)
test("1.0 T1: guild budget: 20 a minute over all prefixes",function()
    local N=loadAddon(); N.Main.we=nil; local Wr=N.Wire; netOn(N,"we")
    local okN=0
    for i=1,30 do
        if Wr.send(i%2==0 and "LEGW1" or "WEFF1",i%2==0 and "R|"..i or GOOD_WE,"GUILD",nil,{net="we",prio="own"}) then okN=okN+1 end
        advance(2.01)
    end
    eq(okN,20)
end)
test("1.0 T1: throttled by the client: dropped, never retried, that prefix pauses 30 s; offline target skipped 1 h",function()
    local N=loadAddon(); local Wr=N.Wire; netOn(N,"hh"); N.Net.setConsent("public")
    sendResult=3; local ok,why=Wr.send("LEGW1","R|1","GUILD",nil,{prio="own",queue=true}); no(ok); eq(why,"throttled"); sendResult=0
    advance(5); drain(); eq(#sent,1,"not retried")
    ok,why=Wr.send("LEGW1","R|2","GUILD",nil,{prio="own"}); no(ok); eq(why,"paused")
    yes(Wr.send("LFSw","Q","GUILD"),"other prefixes go on")
    advance(26); yes(Wr.send("LEGW1","R|3","GUILD",nil,{prio="own"}))
    sendResult=8; no(Wr.send("LEGW1","R|4","GUILD",nil,{prio="own"})); sendResult=0; advance(2.1); eq(select(2,Wr.send("LEGW1","R|5","GUILD")),"paused")
    -- offline
    sendResult=12; ok,why=Wr.send("HeadHunter","1AN:LayerEnemies","WHISPER","Gone",{net="hh",scope="public"}); no(ok); eq(why,"offline"); sendResult=0
    advance(10); ok,why=Wr.send("HeadHunter","1AN:LayerEnemies","WHISPER","Gone",{net="hh",scope="public"}); no(ok); eq(why,"offline")
    advance(3600); yes(Wr.send("HeadHunter","1AN:LayerEnemies","WHISPER","Gone",{net="hh",scope="public"}))
end)
test("1.0 T1: the queue: over budget a queued line waits; full, the oldest forward goes and a click stays; priority order",function()
    local N=loadAddon(); local Wr=N.Wire; netOn(N,"we")
    for i=1,8 do Wr.send("LEGW1","R|"..i,"GUILD",nil,{prio="own"}) end; eq(#sent,5,"LEGW1 bucket 5")
    for i=1,3 do Wr.send("WEFF1",GOOD_WE,"PARTY",nil,{net="we",prio="own"}) end; eq(#sent,8,"all 8 spent")
    local ok,why=Wr.send("LEGW1","R|f1","GUILD",nil,{prio="forward",queue=true}); yes(ok); eq(why,"queued")
    for i=2,39 do Wr.send("LEGW1","R|f"..i,"GUILD",nil,{prio="forward",queue=true}) end
    eq(Wr.queued(),39)
    yes(Wr.send("LEGW1","R|own","GUILD",nil,{prio="own",queue=true})); eq(Wr.queued(),40)
    -- full: a click goes in, the oldest forward goes out
    ok,why=Wr.send("LayerSwap","inv layer <LS 1429 want 7086-0>","WHISPER","Alice",{prio="click",queue=true}); yes(ok); eq(why,"queued")
    eq(Wr.queued(),40); no(Wr.isQueued("R|f1")); yes(Wr.isQueued("R|f2"))
    -- full of non-forwards, a forward is refused
    N=loadAddon(); Wr=N.Wire
    for i=1,8 do Wr.send("LEGW1","R|"..i,"GUILD",nil,{prio="own"}) end
    for i=1,40 do Wr.send("LEGW1","R|o"..i,"GUILD",nil,{prio="own",queue=true}) end
    ok,why=Wr.send("LEGW1","R|fx","GUILD",nil,{prio="forward",queue=true}); no(ok); eq(why,"queue full")
    -- order: the click first, then own, then owed, then forward
    N=loadAddon(); Wr=N.Wire
    for i=1,8 do Wr.send("LEGW1","R|"..i,"GUILD",nil,{prio="own"}) end
    Wr.send("LEGW1","R|F","GUILD",nil,{prio="forward",queue=true}); Wr.send("LEGW1","R|W","GUILD",nil,{prio="owed",queue=true})
    Wr.send("LEGW1","R|O","GUILD",nil,{prio="own",queue=true}); Wr.send("LEGW1","R|C","GUILD",nil,{prio="click",queue=true})
    local before=#sent
    for _=1,20 do advance(2.1); drain() end
    local order={}; for i=before+1,#sent do order[#order+1]=sent[i].text end
    eq(table.concat(order,","),"R|C,R|O,R|W,R|F")
    eq(Wr.queued(),0)
end)
test("1.0 T1: in combat every rate halves; in an instance only clicks go",function()
    local N=loadAddon(); local Wr=N.Wire; combat=true
    local okN=0; for i=1,8 do if Wr.send("LEGW1","R|"..i,"GUILD",nil,{prio="own"}) then okN=okN+1 end end
    eq(okN,2,"LEGW1 bucket 5 at half cost: 2"); combat=false
    N=loadAddon(); Wr=N.Wire; inInstance=true
    local ok,why=Wr.send("LEGW1","R|1","GUILD",nil,{prio="own"}); no(ok); eq(why,"instance")
    yes(Wr.send("LFSw","Q","GUILD",nil,{prio="click"}))
    ok,why=Wr.send("LEGW1","R|2","GUILD"); no(ok); eq(why,"instance","no opts counts as a forward")
end)
test("1.0 T1: network off sends nothing and registers no timer; the real addon loaded stands its prefix down",function()
    local N=loadAddon(); local Wr=N.Wire; local Net=N.Net
    local ok,why=Wr.send("WEFF1",GOOD_WE,"GUILD",nil,{net="we"}); no(ok); eq(why,"network off")
    local before=#timers; local ran=false
    no(Net.after("we",5,function() ran=true end)); eq(#timers,before,"no timer while shipped off")
    netOn(N,"we"); yes(Net.after("we",5,function() ran=true end)); eq(#timers,before+1); advance(5); drain(); yes(ran)
    -- the player's switch
    Net.setSwitch("we",false); eq(LayerEnemiesDB.nets.we,false); ok,why=Wr.send("WEFF1",GOOD_WE,"GUILD",nil,{net="we"}); no(ok); eq(why,"network off")
    ran=false; no(Net.after("we",5,function() ran=true end)); advance(6); drain(); no(ran)
    -- a timer registered while on does nothing once the network is off
    Net.setSwitch("we",true); yes(Net.after("we",5,function() ran=true end)); Net.setSwitch("we",false); advance(6); drain(); no(ran)
    Net.setSwitch("we",true)
    -- stand-down
    loaded.WarEffortScout=true; ok,why=Wr.send("WEFF1",GOOD_WE,"GUILD",nil,{net="we"}); no(ok); eq(why,"stand down")
    no(Net.after("we",5,function() end)); loaded.WarEffortScout=nil
    netOn(N,"hh"); Net.setConsent("public"); loaded.HeadHunter=true
    ok,why=Wr.send("HeadHunter","1AN:LayerEnemies","WHISPER","Bob",{net="hh",scope="public"}); no(ok); eq(why,"stand down"); loaded.HeadHunter=nil
    -- consent and switches are saved; anything odd reads as no consent / default on
    eq(LayerEnemiesDB.consent,"public"); LayerEnemiesDB.consent="all"; LayerEnemiesDB.nets={we="x",hh=false}
    N.Main.started=false; N.Main.start(); drain()
    eq(N.Net.chosen(),nil); eq(LayerEnemiesDB.consent,nil); eq(LayerEnemiesDB.nets.we,true); eq(LayerEnemiesDB.nets.hh,false)
    eq(sent and #sent or 0,0); eq(forbidden,0)
end)

test("1.0 T1: callers carry their priority: a hop click and Find hosts go in an instance, host and relay lines do not",function()
    local N=loadAddon(); establish(N); friends(N,{Bob=there({key="8000",host=true})}); advance(1); inInstance=true
    yes(hopNow(N,rec(N))); eq(#sent,1); eq(sent[1].prefix,"LayerSwap")
    slash("hosts find"); eq(#sent,3,"Q and F|1 are clicks")
    eq(select(2,N.Wire.send("LEGW1","R|1","GUILD",nil,{prio="forward"})),"instance")
end)

-- 1.0 T2: one record for every network: hand, hops, pos and the origin's time; one row per origin, zone and 5 s.
local function base(over) local o={src="we",kind="group",origin="Scout",via="Scout",route="GUILD",rid="1",zone=100,count=1,
    layer={ns="server",value="8000"},heard=500,share="guild"}; for k,v in pairs(over or {}) do o[k]=v end; return o end
test("1.0 T2: a wrapped, enveloped, relayed or synced record is never first-hand",function()
    local N=loadAddon(); local R=N.Record
    eq(R.new(base()).hand,"first")
    eq(R.new(base({via="Other"})).hand,"relayed","another carrier")
    eq(R.new(base({wrapped=true})).hand,"relayed"); eq(R.new(base({wrapped=true,hand="first"})).hand,"relayed","a claim of first is not enough")
    eq(R.new(base({hand="relayed"})).hand,"relayed")
    eq(R.new(base({src="guild",label="we"})).hand,"relayed","a guild relay")
    eq(R.new(base({via="scout"})).hand,"first","same name, other case")
    eq(R.new(base({hops=3})).hops,3); eq(R.new(base({hops=0})),nil); eq(R.new(base({hops=17})),nil); eq(R.new(base({hops="x"})),nil)
    eq(R.new(base({hand="maybe"})),nil)
    -- decoders: a War Effort G wrapper and a HeadHunter envelope are relayed; a direct P is first-hand
    local _,feed=reportFixture(N)
    local r=feed(VG,"Carrier"); yes(r); eq(r.hand,"relayed"); eq(r.hops,1)
    r=feed(VC,"Reporter"); yes(r); eq(r.hand,"first")
    local e=hh(N,HHE,"Carrier")[1]; yes(e); eq(e.hand,"relayed"); eq(e.hops,1)
    local p=hh(N,HHP,"Fighter")[1]; yes(p); eq(p.hand,"first"); eq(p.hops,nil)
    -- an envelope sent by its own author is still an envelope; a War Effort wrapper naming its carrier as origin too
    local own=hh(N,HHE,"Mira Vale")[1]; yes(own); eq(own.hand,"relayed")
    eq(feed(VG,"Scout One"),nil,"a wrapper carried by its own origin is refused before it becomes a record")
end)
test("1.0 T2: at is the origin's time, never the time we heard it",function()
    local N=loadAddon(); local R=N.Record
    eq(R.new(base({heard=500,age=40})).at,460); eq(R.new(base({heard=500})).at,500)
    eq(R.new(base({heard=500,at=470})).at,470); eq(R.new(base({heard=500,at=501})),nil,"after receipt")
    local _,feed=reportFixture(N)
    local r=feed(VC,"Reporter",200,"GUILD",720140); yes(r); eq(r.heard,200); eq(r.age,40); eq(r.at,160)
    local h=hh(N,"1AP:13k;"..b36(HHT-30)..";dw;6y;a1;;",nil,HHT)[1]; yes(h); eq(h.at,50-30)
end)
test("1.0 T2: positions are labelled: enemy, observer, victim or none",function()
    local N=loadAddon(); local R=N.Record
    eq(R.new(base({x=.5,y=.5})).pos,"enemy"); eq(R.new(base()).pos,"none","no coordinates")
    eq(R.new(base({x=.5,y=.5,pos="observer"})).pos,"observer"); eq(R.new(base({src="gb",kind="death",x=.5,y=.5,pos="victim"})).pos,"victim")
    eq(R.new(base({pos="victim"})).pos,"none","no coordinates: none whatever is claimed"); eq(R.new(base({x=.5,y=.5,pos="there"})),nil)
    eq(hh(N,HHP)[1].pos,"observer","HeadHunter positions are the reporter's")
    for _,s in ipairs({"spy","fspy","sent","gb","wos","ft"}) do yes(R.new(base({src=s,kind="seen"})),s) end
    yes(R.new(base({kind="death",src="wos"}))); eq(R.new(base({src="xx"})),nil)
    -- the window and /le reports say whose position it is and that a row was relayed
    establish(N); local T=N.Store
    yes(T.report(N.Main.store,R.new(base({heard=clock,x=.5,y=.5,pos="observer",via="Carrier",rid="7"})),clock))
    local rows=T.rows(N.Main.store,clock,"reported"); eq(#rows,1); eq(rows[1].hand,"relayed"); eq(rows[1].positionKind,"observer's position")
    slash("reports"); yes(logged("relayed"))
    local U=N.UI; U.toggle(); U.select("reported")
    local found=false; for _,x in ipairs(U.pool) do if x:IsShown() and x.sub.text and x.sub.text:find("relayed",1,true) then found=true end end; yes(found)
end)
test("1.0 T2: a record older than its network's limit is dropped, counted from the origin's time",function()
    local N=loadAddon(); establish(N); local T,R,st=N.Store,N.Record,N.Main.store
    local ok,why=T.report(st,R.new(base({heard=clock,age=600,rid="a"})),clock); no(ok); eq(why,"expired")
    yes(T.report(st,R.new(base({heard=clock,age=590,rid="b"})),clock))
    advance(10); eq(#T.rows(st,clock,"reported"),0,"gone 600 s after the origin's time")
    ok,why=T.report(st,R.new(base({src="hh",kind="fight",heard=clock,age=300,rid="c",layer={ns="unknown"}})),clock); eq(why,"expired")
    for _,s in ipairs({"spy","fspy","sent"}) do eq(T.ttl({src=s}),600,s) end
    for _,s in ipairs({"gb","wos","ft"}) do eq(T.ttl({src=s}),900,s) end
end)
test("1.0 T2: one row per origin, zone and 5 s; first-hand first, then the copy with names",function()
    -- (round 2, T2-1: a first-hand copy wins before the name count; the guild relay's copy is relayed)
    local N=loadAddon(); establish(N); local T,R,st=N.Store,N.Record,N.Main.store
    local hashOnly=R.new(base({heard=clock,rid="10",enemies={{hash="abc"}},count=2}))
    local named=R.new(base({src="guild",label="own",via="Scout",heard=clock,rid="O1",enemies={{name="Kora Reed"},{name="Ann Lee"}},count=2}))
    yes(T.report(st,hashOnly,clock)); local ok,why=T.report(st,named,clock); no(ok); eq(why,"duplicate")
    local rows=T.rows(st,clock,"reported"); for _,row in ipairs(rows) do eq(row.record,hashOnly) end
    -- the other way round: the first-hand copy replaces the relayed named one
    N=loadAddon(); establish(N); T,R,st=N.Store,N.Record,N.Main.store
    yes(T.report(st,R.new(base({src="guild",label="own",heard=clock,rid="O2",enemies={{name="Kora Reed"}}})),clock))
    yes(T.report(st,R.new(base({heard=clock+3,rid="11",enemies={{hash="abc"}}})),clock+3))
    -- 6 s apart, another zone or another origin: separate rows
    yes(T.report(st,R.new(base({heard=clock+6,rid="12"})),clock+6))
    -- two reports of one network within 5 s are two sightings
    yes(T.report(st,R.new(base({heard=clock+6,rid="14"})),clock+6))
    yes(T.report(st,R.new(base({origin="Other",via="Other",heard=clock,rid="13"})),clock))
    -- both first-hand on two networks: the one with names wins
    N=loadAddon(); establish(N); T,R,st=N.Store,N.Record,N.Main.store
    yes(T.report(st,R.new(base({heard=clock,rid="20",enemies={{hash="abc"}}})),clock))
    local p=R.new(base({src="hh",kind="fight",heard=clock,rid="21",layer={ns="unknown"},enemies={{name="Kora Reed"}}}))
    yes(T.report(st,p,clock)); rows=T.rows(st,clock,"reported"); eq(#rows,1); eq(rows[1].record,p)
    local ok2,why2=T.report(st,R.new(base({heard=clock+3,rid="22",src="hh",kind="fight",layer={ns="unknown"},enemies={{hash="abc"}}})),clock+3); yes(ok2,"same network: its own row")
end)

-- 1.0 T3: Directory: the two named channels, joined only at consent "public", read only when safe, never sent to.
local function dirReady(N) netOn(N,"we","hh"); N.Net.setConsent("public") end
test("1.0 T3: the War Effort channel name follows the realm's ruleset; HeadHunter's is fixed",function()
    local N=loadAddon(); local D=N.Directory
    local cases={["Forever RP-PvP2"]="RPPvP",ForeverPvE="PvE",["Forever PvP"]="PvP",["Warp PvE"]="PvE",["Role Play"]="RP",["RP2"]="RP",
        ["Sharpvale"]="sharpvale",["Forever Legends 2"]="foreverleg",["Normal"]="PvE",["ForeverRP-PvP"]="RPPvP",["R.P. Land"]="RP",["Test Realm"]="testrealm"}
    for realm,tag in pairs(cases) do eq(D.rulesetTag(realm),tag,realm) end
    eq(D.rulesetTag(""),nil); eq(D.rulesetTag(secret),nil); eq(D.rulesetTag(nil),nil); eq(D.rulesetTag("Ab 2"),"ab")
    local was=issecretvalue; issecretvalue=function(v) return v=="Hidden PvP" or (was and was(v)) end
    eq(D.rulesetTag("Hidden PvP"),nil,"a secret realm name is never read"); issecretvalue=was
    eq(D.channel("we"),"WarEfforttestrealmA"); eq(D.channel("hh"),"HeadHunterSync")
    UnitFactionGroup=function() return "Neutral" end; eq(D.channel("we"),nil,"no faction letter: no channel")
end)
test("1.0 T3: no join at consent guild; joins at public; leaves on switch-off or consent guild",function()
    local N=loadAddon(); local D=N.Directory; netOn(N,"we","hh")
    N.Net.setConsent("guild"); D.sync(); eq(#joined,0,"guild only")
    N.Net.setConsent("public"); eq(#joined,2,"setting consent syncs"); eq(table.concat(joined,","),"HeadHunterSync,WarEfforttestrealmA")
    D.sync(); eq(#joined,2,"no second join")
    N.Net.setSwitch("hh",false); eq(leftCh[#leftCh],"HeadHunterSync")
    N.Net.setConsent("guild"); eq(leftCh[#leftCh],"WarEfforttestrealmA")
    -- a network shipped off never joins, and the real addon loaded joins nothing for us
    N=loadAddon(); D=N.Directory; N.Net.setConsent("public"); D.sync(); eq(#joined,0)
    N=loadAddon(); D=N.Directory; loaded.HeadHunter=true; dirReady(N); eq(table.concat(joined,","),"WarEfforttestrealmA")
    -- an instance or combat at the time: no join now
    N=loadAddon(); D=N.Directory; inInstance=true; dirReady(N); eq(#joined,0); inInstance=false
    combat=true; D.sync(); eq(#joined,0); combat=false; D.sync(); eq(#joined,2)
    eq(forbidden,0)
end)
test("1.0 T3: the member list is read after selecting the channel, never with the Channels window open, in combat or an instance",function()
    local N=loadAddon(); local D=N.Directory; dirReady(N)
    chanMembers.HeadHunterSync={"Me","Peer One","Peer Two-Other","Me-TestRealm","Bad|Name","Me-OtherRealm"}
    yes(D.refresh("hh")); eq(#selected,1); eq(D.members("hh"),nil,"read 3 s later")
    advance(2.9); eq(D.members("hh"),nil)
    -- ourselves (our realm or none) and unreadable names are skipped; our namesake on another realm is someone else
    advance(0.2); local m=D.members("hh"); eq(#m,3); eq(m[1],"Peer One"); eq(m[2],"Peer Two-Other"); eq(m[3],"Me-OtherRealm"); eq(D.count("hh"),3)
    ChannelFrame={IsShown=function() return true end}; no(D.refresh("hh")); eq(#selected,1); ChannelFrame=nil
    combat=true; no(D.refresh("hh")); combat=false
    inInstance=true; no(D.refresh("hh")); inInstance=false
    -- unreadable names are skipped; at most 500 read
    chanMembers.HeadHunterSync={}; for i=1,600 do chanMembers.HeadHunterSync[i]="Peer"..string.char(97+i%26)..string.char(97+math.floor(i/26)%26) end
    yes(D.refresh("hh")); advance(3.1); drain(); eq(#D.members("hh"),500)
    -- the first read 10 s after joining, then every 300 s while public; none after switching off
    local function hhSel() local n=0; for _,c in ipairs(selected) do if c=="HeadHunterSync" then n=n+1 end end; return n end
    local before=hhSel(); advance(4); eq(hhSel(),before+1,"10 s after joining")
    advance(299); eq(hhSel(),before+1); advance(1); eq(hhSel(),before+2,"the 300 s refresh")
    N.Net.setSwitch("hh",false); advance(600); eq(hhSel(),before+2); eq(D.members("hh"),nil,"forgotten on switch-off")
    eq(forbidden,0)
end)
test("1.0 T3: nothing is ever sent to a channel; channel calls only from Directory.lua",function()
    local N=loadAddon(); for prefix,kinds in pairs(N.Wire.ROUTES) do eq(kinds.CHANNEL,nil,prefix) end
    JoinChannelByName("x"); LeaveChannelByName("x"); SetSelectedDisplayChannel(1); eq(forbidden,3)
    forbidden=0
    for _,file in ipairs(addonFiles()) do
        local text=assert(io.open("LayerEnemies/"..file..".lua")):read("*a")
        for _,word in ipairs({"JoinChannelByName","LeaveChannelByName","SetSelectedDisplayChannel","JoinTemporaryChannel","JoinPermanentChannel"}) do
            local n=0; for _ in text:gmatch("%f[%w_]"..word.."%f[^%w_]") do n=n+1 end
            if file~="Directory" or word:find("Temporary") or word:find("Permanent") then eq(n,0,file.." "..word) else yes(n==1,file.." "..word.." "..n) end
        end
    end
end)

-- 0.3.1 S1 narrowed and three of Astra's extras (hermes)
test("0.3.1 S1 narrowed: only a reporter who is himself a Bulo/LayerSwap row seen while unknown is refused",function()
    -- the reporter is a Bulo row listed on another layer: still refused (the row says nothing reliable while unknown)
    local N=loadAddon(); chatBox(); advance(1)
    guildLine("L 9000|100|h","Alpha"); hopReport(301,8000,"Alpha")
    slash("reports"); local r=N.Main.hopList.records[1]; yes(r)
    local p=N.Main.hopPreview(r); no(p.enabled); eq(p.reason,N.Invite.HINT)
    slash("hop 1"); eq(#opened,0); eq(#sent,0)
    -- a LayerSwap book row as the reporter: refused too
    N=loadAddon(); chatBox(); advance(1); LayerSwapDB={book={Alpha=page({layer="8000-3"})}}; hopReport(301,8000,"Alpha")
    slash("reports"); r=N.Main.hopList.records[1]; p=N.Main.hopPreview(r); no(p.enabled); eq(p.reason,N.Invite.HINT); LayerSwapDB=nil
    -- another Bulo row on that layer and a plain reporter: the reporter draft of 0.3.0
    N=loadAddon(); chatBox(); advance(1); guildLine("L 8000|100|h","Alpha"); hopReport(301,8000,"Scout")
    slash("reports"); r=N.Main.hopList.records[1]; p=N.Main.hopPreview(r); yes(p.enabled); eq(p.label,"Ask Scout (chat)")
    slash("hop 1"); eq(#opened,1); eq(opened[1].text,"/w Scout "..ASK); eq(#sent,0)
end)
test("0.3.1 extra: a readable zone change clears the /le hosts numbers",function()
    local N=loadAddon(); establish(N); chatBox(); guildLine("L 8000|100|h","Alpha"); slash("hosts"); yes(N.Main.hostList)
    deliver("ZONE_CHANGED"); drain(); yes(N.Main.hostList,"same zone keeps them")
    map=nil; deliver("ZONE_CHANGED_NEW_AREA"); drain(); yes(N.Main.hostList,"an unreadable map is no zone change"); map=100
    map=200; deliver("ZONE_CHANGED_NEW_AREA"); drain(); eq(N.Main.hostList,nil)
    slash("ask 1"); eq(#opened,0); yes(logged("run /le hosts first")); slash("hop host 1"); eq(#sent,0)
end)
test("0.3.1 extra: /le ask from a list taken while our layer was unknown re-checks before drafting",function()
    local N=loadAddon(); chatBox(); guildLine("L 8000|100|h","Alpha"); slash("hosts"); yes(N.Main.hostList.rows[1].unknownOwn)
    establish(N); slash("ask 1"); eq(#opened,0); yes(logged("hosts changed, check again."))
    slash("hosts"); slash("ask 1"); eq(#opened,1); eq(opened[1].text,"/w Alpha "..ASK)
    -- a list taken with our layer known and still known drafts as before
    N=loadAddon(); establish(N); chatBox(); guildLine("L 8000|100|h","Bravo"); slash("hosts"); slash("ask 1"); eq(#opened,1)
end)
test("0.3.1 extra: with LayerSwap loaded our remembered replies are never used, even while its saved table is missing",function()
    local N=loadAddon(); establish(N); guildLine("L 8000|100|h","Bob")
    slash("hosts"); slash("hop host 1")
    deliver("CHAT_MSG_ADDON","LayerSwap","heard Me|8000-12|100|h","WHISPER","Bob"); drain(); yes(N.Main.heard.heard.Bob)
    N.Main.guildLines.Bob=nil; LayerSwapDB=nil
    eq(#N.Main.candidates(),1,"not loaded: ours stands in")
    loaded.LayerSwap=true; eq(#N.Main.candidates(),0,"loaded, no table yet: its book is empty")
    loaded.LayerSwap=nil; eq(#N.Main.candidates(),1)
end)

-- 0.4.0 review round 1 (مانع): M1 identity, S1 party, S2 spaced names, S3 guests
test("0.4 fix M1: the player checked is the player invited; realms are kept unless they are ours",function()
    local N=loadAddon(); local A,I=N.Adapters,N.Invite
    -- one name rule: key and invite target, our realm dropped, any other kept
    local n,k,tgt=I.name("Alpha-OtherRealm"); eq(k,"alpha-otherrealm"); eq(tgt,"Alpha-OtherRealm")
    n,k,tgt=I.name("Alpha-TestRealm"); eq(k,"alpha"); eq(tgt,"Alpha")
    n,k,tgt=I.name("Alpha"); eq(k,"alpha"); eq(tgt,"Alpha")
    -- a foreign-realm sender never matches a bare roster entry or one of our realm
    roster={{"Alpha",true}}; eq(A.guildMember("Alpha-OtherRealm"),false)
    roster={{"Alpha-TestRealm",true}}; eq(A.guildMember("Alpha-OtherRealm"),false)
    roster={{"Alpha-OtherRealm",true}}; eq(A.guildMember("Alpha-OtherRealm"),true)
    roster={{"Alpha-TestRealm",true}}; eq(A.guildMember("alpha"),false,"spelled differently")
    -- a bare (our realm) sender does not win while a namesake from another realm is in the roster
    roster={{"Alpha",true},{"Alpha-OtherRealm",true}}; eq(A.guildMember("Alpha"),false); eq(A.guildMember("Alpha-OtherRealm"),true)
    roster={{"Alpha-TestRealm",true},{"Alpha-OtherRealm",true}}; eq(A.guildMember("Alpha"),false)
    -- end to end: a qualified guild member is invited by his whole name
    hostReady(N,{}); roster={{"Alpha-OtherRealm",true}}
    lsw("inv layer <LS 100 want 7086-7>","Alpha-OtherRealm"); eq(#invites,1); eq(invites[1],"Alpha-OtherRealm")
    -- the same request from a foreign Alpha with only our Alpha in the roster: nothing
    N=loadAddon(); hostReady(N,{"Alpha"}); lsw("inv layer <LS 100 want 7086-7>","Alpha-OtherRealm"); eq(#invites,0)
    -- our own Alpha: invited by the bare name
    lsw("inv layer <LS 100 want 7086-7>","Alpha"); eq(#invites,1); eq(invites[1],"Alpha")
    -- Wire keeps a foreign realm and drops ours
    N=loadAddon(); yes(N.Wire.invite("Cara-OtherRealm",clock)); eq(invites[#invites],"Cara-OtherRealm")
    advance(11); yes(N.Wire.invite("Dana-TestRealm",clock)); eq(invites[#invites],"Dana")
end)
test("0.4 fix S1: the party is unreadable (busy) when the count and the party units disagree or a unit read fails",function()
    local N=loadAddon(); local A=N.Adapters
    units.party1={name="Cy"}; leader=true; local p=A.party(); yes(p); eq(#p.members,1)
    GetNumGroupMembers=function() return 5 end; eq(A.party(),nil,"5 counted, 1 listed")
    GetNumGroupMembers=function() return 0 end; eq(A.party(),nil,"none counted, 1 listed")
    GetNumGroupMembers=function() local n=0; for i=1,4 do if units["party"..i] then n=n+1 end end; return n>0 and n+1 or 0 end
    local was=UnitExists
    UnitExists=function(u) if u:find("party") then return nil end; return true end; eq(A.party(),nil,"nil exists")
    UnitExists=function(u) if u:find("party") then return secret end; return true end; eq(A.party(),nil,"secret exists")
    UnitExists=function(u) if u:find("party") then error("x") end; return true end; eq(A.party(),nil,"throws")
    UnitExists=nil; eq(A.party(),nil,"missing"); UnitExists=was
    -- one unreadable slot hidden by a matching count: party1 unreadable, party2 listed, count 2
    units.party1=nil; units.party2={name="Di"}
    UnitExists=function(u) if u=="party1" then return nil end; return was(u) end; eq(A.party(),nil,"one slot unreadable"); UnitExists=was
    units.party1={name="Cy"}; units.party2=nil
    UnitIsGroupLeader=function() return secret end; eq(A.party(),nil,"unreadable leader")
    -- the guild host answers busy, no invite
    N=loadAddon(); hostReady(N); GetNumGroupMembers=function() return 5 end
    lsw("inv layer <LS 100 want 7086-7>","Bob"); eq(#invites,0); yes(sent[1] and sent[1].text:find("|-$"),"busy reply")
end)
test("0.4 fix S2: a spaced name with a realm is one rule everywhere: guild check, host and Wire",function()
    local N=loadAddon(); local I=N.Invite
    local n,k,tgt=I.name("Tam Reed-OtherRealm"); eq(n,"Tam Reed-OtherRealm"); eq(k,"tam reed-otherrealm"); eq(tgt,"Tam Reed-OtherRealm")
    n,k,tgt=I.name("Tam Reed-TestRealm"); eq(k,"tam reed"); eq(tgt,"Tam Reed")
    for _,bad in ipairs({"Tam Reed Lee","Tam  Reed","Tam Reed-","Tam Reed-Other Realm","T Reed","Tam-Reed-Other","Tam Reed-Real|m"}) do eq(I.name(bad),nil,bad) end
    hostReady(N,{}); roster={{"Tam Reed-OtherRealm",true}}
    lsw("inv layer <LS 100 want 7086-7>","Tam Reed-OtherRealm"); eq(#invites,1); eq(invites[1],"Tam Reed-OtherRealm")
    N=loadAddon(); hostReady(N,{}); roster={{"Tam Reed-TestRealm",true}}
    lsw("inv layer <LS 100 want 7086-7>","Tam Reed"); eq(#invites,1); eq(invites[1],"Tam Reed")
end)
test("0.4 fix S3: an asker already in our party gets same; a guest who joined frees the pending slot at once",function()
    local N=loadAddon(); hostReady(N,{"Bob","Cy","Di","Ed","Fay"})
    lsw("inv layer <LS 100 want 7086-7>","Bob"); eq(#invites,1)
    units.party1={name="Bob"}; leader=true; grouped=true; deliver("GROUP_ROSTER_UPDATE"); drain()
    advance(61); sent={}; lsw("inv layer <LS 100 want 7086-7>","Bob"); eq(#invites,1,"no second invite"); eq(sent[1].text,"same")
    -- Bob joined: his slot is not counted twice. Cy, Di and Ed get invites (Bob + 3 pending + us = 5)
    advance(10); lsw("inv layer <LS 100 want 7086-7>","Cy"); eq(#invites,2)
    advance(10); lsw("inv layer <LS 100 want 7086-7>","Di"); eq(#invites,3)
    advance(10); lsw("inv layer <LS 100 want 7086-7>","Ed"); eq(#invites,4)
    advance(10); lsw("inv layer <LS 100 want 7086-7>","Fay"); eq(#invites,4,"now full")
    local G=N.GuildHost; local s=G.new(); s.on=true; s.pending.bob=clock; s.hosted.bob=true
    local own={self="me",zone=100,key="7086",inInstance=false,inCombat=false,raid=false,leader=true,members={"Bob"},member=true}
    eq((G.decide(s,{name="Cy",zone=100,want="7086-1"},own,clock)),"invite"); eq(s.pending.bob,nil,"cleared on join")
end)

test("0.4 host saved (review 6c): a host resumed at login answers no F before the first guild roster",function()
    local normal=deliver
    deliver=function(event,...) if event=="ADDON_LOADED" and (...)=="LayerEnemies" then return end; return normal(event,...) end
    local N=loadAddon(); deliver=normal
    LayerEnemiesDB={guildHost=true}; roster={{"Peer-TestRealm",true}}
    deliver("ADDON_LOADED","LayerEnemies"); deliver("PLAYER_LOGIN"); deliver("PLAYER_ENTERING_WORLD"); drain()
    establish(N); yes(N.Main.host.on); eq(N.Adapters.roster.at,nil)
    deliver("CHAT_MSG_ADDON","LEGW1","F|1","GUILD","Peer"); drain(); advance(7)
    eq(#sent,0,"no H before the first roster")
    deliver("GUILD_ROSTER_UPDATE",true); drain(); eq(#sent,0,"the roster alone sends nothing")
    advance(61); deliver("CHAT_MSG_ADDON","LEGW1","F|1","GUILD","Peer"); drain(); advance(7)
    eq(#sent,1); eq(sent[1].text,"H|1|7086|100")
end)

-- Forever names are "First Last"; realms are numeric (owner facts): one name rule everywhere (0.4.0 review S2, must)
local function numericHome() GetRealmName=function() return "7102" end; UnitName=(function(old) return function(u) if u=="player" then return "Me Self","7102" end; return old(u) end end)(UnitName) end
test("0.4 fix S2 (must): First Last, numeric realms; double, leading and trailing spaces and three words refused",function()
    local N=loadAddon(); numericHome(); local I=N.Invite
    local n,k,t=I.name("First Last"); eq(n,"First Last"); eq(k,"first last"); eq(t,"First Last")
    n,k,t=I.name("First Last-7102"); eq(k,"first last"); eq(t,"First Last","our numeric realm dropped")
    n,k,t=I.name("First Last-7105"); eq(k,"first last-7105"); eq(t,"First Last-7105","another numeric realm kept")
    n,k,t=I.name("First Last-OtherRealm"); eq(k,"first last-otherrealm"); eq(t,"First Last-OtherRealm")
    for _,bad in ipairs({"First  Last"," First Last","First Last ","One Two Three","First Last-","First Last-71 02","First|Last","First%Last",
        "First Last-7102-1","First\tLast","Fi.rst Last","First Last-[x]",string.rep("a",37).." Last"}) do eq(I.name(bad),nil,bad) end
    -- the guild check and the invite on numeric realms
    local A=N.Adapters
    roster={{"Alpha Beta-7102",true}}; eq(A.guildMember("Alpha Beta"),true); eq(A.guildMember("Alpha Beta-7102"),true); eq(A.guildMember("Alpha Beta-7105"),false)
    roster={{"Alpha Beta",true},{"Alpha Beta-7105",true}}
    eq(A.guildMember("Alpha Beta"),false,"bare namesake while 7105 is listed"); eq(A.guildMember("Alpha Beta-7102"),false); eq(A.guildMember("Alpha Beta-7105"),true)
    hostReady(N,{}); roster={{"Alpha Beta-7105",true}}
    lsw("inv layer <LS 100 want 7086-7>","Alpha Beta-7105"); eq(#invites,1); eq(invites[1],"Alpha Beta-7105")
    eq(sent[1].text,"heard Alpha Beta|7086-7|100|h","the reply names the asker as his own UnitName reads")
    N=loadAddon(); numericHome(); hostReady(N,{}); roster={{"Cara Dune-7102",true}}
    lsw("inv layer <LS 100 want 7086-7>","Cara Dune"); eq(#invites,1); eq(invites[1],"Cara Dune")
end)
test("0.4 fix S2 (must): the LayerSwap reply grammar takes the spaced name and nothing looser",function()
    local N=loadAddon(); local Wr=N.Wire
    for _,ok in ipairs({"heard First Last|7086-7|100|h","heard First Last-7105|7086-7|100|-","heard Bob|7086-7|100|h"}) do
        local r,why=Wr.send("LayerSwap",ok,"WHISPER","First Last"); yes(r,ok.." "..tostring(why)); advance(7) end
    for _,bad in ipairs({"heard First  Last|7086-7|100|h","heard First Last Third|7086-7|100|h","heard  First Last|7086-7|100|h",
        "heard First Last |7086-7|100|h","heard First%Last|7086-7|100|h"}) do
        local r,why=Wr.send("LayerSwap",bad,"WHISPER","First Last"); no(r,bad); eq(why,"bad text"); advance(7) end
    -- a heard reply naming us by our spaced name is read (Hop.reply compares the whole name)
    local rep=N.Hop.reply("heard Me Self|7086-7|100|h","First Last","Me Self"); yes(rep); eq(rep.layer,"7086-7")
end)
test("0.3.x name paths: a Bulo guild line from First Last-OtherRealm keeps the realm; ours is dropped",function()
    local N=loadAddon(); numericHome(); local A=N.Adapters; local list={}
    yes(A.guildLine(list,"L 8000|100|h","Alpha Beta-7105",1000)); yes(list["Alpha Beta-7105"]); eq(list["Alpha Beta"],nil)
    yes(A.guildLine(list,"L 8000|100|h","Cara Dune-7102",1000)); yes(list["Cara Dune"])
    yes(A.guildLine(list,"L 8000|100|h","Dana-7105",1000)); yes(list["Dana-7105"])
    no(A.guildLine(list,"L 8000|100|h","Eli  Fox",1000)); no(A.guildLine(list,"L 8000|100|h","One Two Three",1000))
end)

test("0.4 host (review 6c): no H before this session's first guild roster; turning hosting on then announces once on it",function()
    local N=loadAddon(); establish(N); roster={{"Bob-TestRealm",true}}; eq(N.Adapters.roster.at,nil)
    slash("host on"); yes(N.Main.host.on); eq(#legwSent("H|"),0,"no roster read yet")
    deliver("GUILD_ROSTER_UPDATE",true); drain(); eq(#legwSent("H|"),1,"the owed H on the first roster"); eq(legwSent("H|")[1].text,"H|1|7086|100")
    deliver("GUILD_ROSTER_UPDATE",true); drain(); eq(#legwSent("H|"),1,"once")
    -- turned off before the roster: nothing owed
    N=loadAddon(); establish(N); slash("host on"); slash("host off"); deliver("GUILD_ROSTER_UPDATE",true); drain(); eq(#legwSent("H|"),0)
    -- a roster already read: the H goes at once, as before
    N=loadAddon(); establish(N); deliver("GUILD_ROSTER_UPDATE",true); drain(); slash("host on"); eq(#legwSent("H|"),1)
    -- announceHost itself refuses before a roster
    N=loadAddon(); establish(N); N.Main.host.on=true; no(N.Main.announceHost()); eq(#sent,0)
end)

test("1.0 T2 names: every network's sender and origin pass the one name rule (First Last, numeric realms)",function()
    local N=loadAddon(); numericHome(); local R=N.Record
    local function mk(over) local o={src="we",kind="group",origin="Scout",via="Scout",route="GUILD",rid="1",zone=100,count=1,
        layer={ns="server",value="8000"},heard=500,share="guild"}; for k,v in pairs(over or {}) do o[k]=v end; return R.new(o) end
    yes(mk({origin="First Last",via="First Last"})); yes(mk({origin="First Last-7105",via="Carrier Two"}))
    for _,bad in ipairs({"First  Last"," First Last","One Two Three","Bad|Name","First Last-","x"}) do
        eq(mk({origin=bad,via=bad}),nil,"origin "..bad); eq(mk({via=bad}),nil,"via "..bad) end
    -- our realm is the same player: first-hand, one key
    local r=mk({origin="Scout",via="Scout-7102"}); eq(r.hand,"first"); eq(r.id,"we:scout:1")
    eq(mk({origin="Scout-7102",via="Scout"}).id,"we:scout:1")
    eq(mk({origin="Scout-7105",via="Scout"}).hand,"relayed","another realm is another player")
    -- the store's one-row-per-origin rule uses the same key
    establish(N); local T,st=N.Store,N.Main.store
    yes(T.report(st,mk({src="hh",kind="fight",origin="Scout",via="Scout",heard=clock,rid="O1",layer={ns="unknown"},enemies={{name="Kora Reed"}}}),clock))
    local ok,why=T.report(st,mk({origin="Scout-7102",via="Scout-7102",heard=clock,rid="9",enemies={{hash="abc"}}}),clock); no(ok); eq(why,"duplicate","one origin key across networks")
    -- the decoders: War Effort and HeadHunter reporters with spaced names come through; malformed ones do not
    local _,feed=reportFixture(N); yes(feed(VC,"Reporter Two")); eq(feed(VC,"Reporter  Two"),nil)
end)

-- 0.4.0 round 2 (مانع r040b) Task 8: arm only on a real send; guild ask from answerers or listed hosts; group end,
-- instance and combat
test("0.4 T8 B1: a drafted whisper arms auto-accept only once we see it go out to that host",function()
    local N=loadAddon(); BULO=nil; establish(N); chatBox(); advance(1)
    local r=rec(N); yes(hopNow(N,r)); drain(); eq(#opened,1); eq(#sent,0)
    inviteFrom("Scout"); eq(#accepts,0,"the draft was never sent"); popup.shown=false
    deliver("CHAT_MSG_WHISPER_INFORM",N.Invite.MESSAGE,"Other"); deliver("CHAT_MSG_WHISPER_INFORM","hello","Scout"); drain()
    inviteFrom("Scout"); eq(#accepts,0,"another target or another text"); popup.shown=false
    deliver("CHAT_MSG_WHISPER_INFORM",N.Invite.MESSAGE,"Scout-TestRealm"); drain()
    inviteFrom("Scout"); eq(#accepts,1,"sent: armed")
end)
test("0.4 T8 B1: the guild ask arms on our own /g line; then only an answerer or a listed host is accepted",function()
    local N=loadAddon(); BULO=nil; establish(N); chatBox()
    roster={{"Bob-TestRealm",true},{"Cy-TestRealm",true},{"Dee-TestRealm",true},{"Eve-TestRealm",true}}
    local r=rec(N,{src="guild",layer={ns="server",value="9500"}}); yes(N.Main.hopTo(r,N.Main.hopPreview(r))); drain(); eq(opened[1].text,GLINE)
    deliver("CHAT_MSG_ADDON","LayerSwap","heard Me|9500-3|100|h","GUILD","Bob"); drain()
    inviteFrom("Bob"); eq(#accepts,0,"our line has not gone out"); popup.shown=false
    deliver("CHAT_MSG_GUILD",GLINE:sub(4).." x","Me"); deliver("CHAT_MSG_GUILD",GLINE:sub(4),"Other"); drain()
    inviteFrom("Bob"); eq(#accepts,0,"other text or another sender"); popup.shown=false
    deliver("CHAT_MSG_GUILD",GLINE:sub(4),"Me-TestRealm"); drain()
    inviteFrom("Bob"); eq(#accepts,0,"answered before the line went out (r040c G2)"); popup.shown=false
    deliver("CHAT_MSG_ADDON","LayerSwap","heard Me|9500-3|100|h","GUILD","Bob"); drain()
    inviteFrom("Dee"); eq(#accepts,0,"a guildmate who neither answered nor is a listed host"); popup.shown=false
    -- a claim for someone else, or a busy heard, is no answer
    deliver("CHAT_MSG_ADDON","LayerSwap","claim Someone Else","GUILD","Cy"); deliver("CHAT_MSG_ADDON","LayerSwap","heard Me|9500-3|100|-","GUILD","Eve"); drain()
    inviteFrom("Cy"); inviteFrom("Eve"); eq(#accepts,0,"claim for another, busy heard"); popup.shown=false
    inviteFrom("Bob"); eq(#accepts,1,"answered heard|h")
    -- a LayerSwap claim naming us, and a listed Bulo host on that layer
    for _,who in ipairs({"Cy","Eve"}) do
        N=loadAddon(); BULO=nil; establish(N); chatBox(); roster={{who.."-TestRealm",true}}
        r=rec(N,{src="guild",layer={ns="server",value="9500"}}); yes(N.Main.hopTo(r,N.Main.hopPreview(r))); drain()
        deliver("CHAT_MSG_GUILD",GLINE:sub(4),"Me"); drain()
        if who=="Cy" then deliver("CHAT_MSG_ADDON","LayerSwap","claim Me","GUILD","Cy")
        else deliver("CHAT_MSG_ADDON","LFSw","L 9500|100|h","GUILD","Eve") end; drain()
        inviteFrom(who); eq(#accepts,1,who)
    end
end)
test("0.4 T8 B1: a request whose line cannot be built leaves nothing armed",function()
    local N=loadAddon(); establish(N); local Hp=N.Hop; local inv=N.Invite.new()
    local r=rec(N); local cand={name="Bob",short="bob",addon=true,uid=1.5,source="LayerSwap"}
    local ctx={grouped=false,zone=100,own={zone=100,server="7086"},invite=inv,now=clock,x=.25,y=.75}
    local ok,why=Hp.request(N.Main.hop,r,cand,ctx); no(ok); eq(why,"the request could not be built."); eq(inv.pending,nil); eq(#sent,0)
end)
test("0.4 T8 B2: the hop group ends: tracking stops at once; a later group of the same host is never left",function()
    local N=loadAddon(); BULO=nil; establish(N); askBob(N); inviteFrom("Bob"); joinParty("Bob"); yes(N.Main.auto.group)
    grouped=false; units.party1=nil; deliver("GROUP_ROSTER_UPDATE"); drain(); eq(N.Main.auto.group,nil)
    advance(2); joinParty("Bob"); advance(40); drain(); eq(#leaves,0)
end)
test("0.4 T8: never auto-leave inside an instance; in combat the leave waits for combat to end",function()
    local N=loadAddon(); BULO=nil; establish(N); askBob(N); inviteFrom("Bob"); joinParty("Bob")
    inInstance=true; advance(31); drain(); eq(#leaves,0); eq(N.Main.auto.group,nil,"tracking stopped"); inInstance=false
    advance(30); drain(); eq(#leaves,0)
    N=loadAddon(); BULO=nil; establish(N); askBob(N); inviteFrom("Bob"); joinParty("Bob"); moveTo("8000")
    combat=true; advance(3.1); drain(); eq(#leaves,0,"in combat"); advance(20); drain(); eq(#leaves,0)
    combat=false; advance(1.1); drain(); eq(#leaves,1,"after combat")
    -- the 30 s failure also waits
    N=loadAddon(); BULO=nil; establish(N); askBob(N); inviteFrom("Bob"); joinParty("Bob")
    combat=true; advance(31); drain(); eq(#leaves,0); combat=false; advance(1.1); drain(); eq(#leaves,1); yes(logged("hop failed"))
end)
test("0.4 L2: a finished or expired hop no longer counts as asking for the guild host",function()
    local N=loadAddon(); BULO=nil; establish(N); askBob(N); yes(N.Main.hostOwn().asking)
    advance(121); no(N.Main.hostOwn().asking,"120 s without an invite"); eq(N.Main.hop.pending,nil)
    N=loadAddon(); BULO=nil; establish(N); askBob(N); inviteFrom("Bob"); joinParty("Bob"); moveTo("8000"); advance(3.1); drain(); eq(#leaves,1)
    grouped=false; units.party1=nil; deliver("GROUP_ROSTER_UPDATE"); drain()
    no(N.Main.hostOwn().asking,"moved and left"); eq(N.Main.hop.pending,nil)
    N=loadAddon(); BULO=nil; establish(N); askBob(N); inviteFrom("Bob"); joinParty("Bob"); advance(31); drain(); eq(#leaves,1)
    no(N.Main.hostOwn().asking,"failed"); eq(N.Main.hop.pending,nil)
end)

test("0.4 L1: isMe uses the one name rule; letters refuse a no-break space, zero-width and invalid bytes",function()
    local N=loadAddon(); local M,I=N.Main,N.Invite
    yes(M.isMe("Me")); yes(M.isMe("Me-TestRealm")); yes(M.isMe("me")); no(M.isMe("Me-OtherRealm")); no(M.isMe("Me  ")); no(M.isMe("Mee"))
    numericHome(); yes(M.isMe("Me Self")); yes(M.isMe("Me Self-7102")); no(M.isMe("Me Self-7105")); no(M.isMe("Me  Self")); no(M.isMe("Me"))
    -- letters: UTF-8 letters pass, no-break space, zero-width, soft hyphen, BOM, punctuation and broken bytes do not
    yes(I.name("Zo\195\171 \195\133ngstr\195\182m")); yes(I.name("\208\148\208\176\209\128"))
    for _,bad in ipairs({"First\194\160Last","Fi\226\128\139rst Last","Fi\194\173rst","\239\187\191Bob","Bo\195","\255Bob","Bo\128b",
        "Bob\226\128\168","Bo\194\183b","Bo\195\151b","Bob-Re\194\160alm","Bob-\226\128\139x"}) do eq(I.name(bad),nil,bad) end
end)

-- 1.0 review round 2 (مانع r040b part C): T1
local function sentCount(prefix,kind) local n=0; for _,m in ipairs(sent) do if m.prefix==prefix and (not kind or m.kind==kind) then n=n+1 end end; return n end
test("1.0 T1-1: in combat the minute caps halve too: GUILD 10, public 10, one player 2, all 20",function()
    local N=loadAddon(); local Wr=N.Wire; combat=true
    for i=1,15 do Wr.send("LEGW1","R|"..i,"GUILD",nil,{prio="own"}); advance(4.1) end
    eq(sentCount("LEGW1"),10,"GUILD 10 per minute in combat")
    N=loadAddon(); Wr=N.Wire; netOn(N,"we"); N.Net.setConsent("public"); combat=true
    for i=1,4 do Wr.send("WEFF1","P|"..i,"WHISPER","Stranger",{net="we",prio="own"}); advance(5) end
    eq(sentCount("WEFF1","WHISPER"),2,"one player 2 per minute in combat")
    N=loadAddon(); Wr=N.Wire; netOn(N,"we"); N.Net.setConsent("public"); combat=true
    for i=1,15 do Wr.send("WEFF1","P|"..i,"WHISPER","Strang"..abc(i),{net="we",prio="own"}); advance(4.1) end
    eq(sentCount("WEFF1","WHISPER"),10,"public 10 per minute in combat")
    N=loadAddon(); Wr=N.Wire; combat=true
    for i=1,30 do Wr.send(i%2==0 and "LEGW1" or "LayerSwap",i%2==0 and ("R|"..i) or LSX,i%2==0 and "PARTY" or "WHISPER",i%2==0 and nil or "Bob",{prio="own"}); advance(2.05) end
    yes(#sent<=20,"all 20 per minute in combat: "..#sent)
end)
test("1.0 T1-2: a network whisper is public unless the target is a checked online guildmate; opts.scope is not trusted",function()
    local N=loadAddon(); local Wr=N.Wire; netOn(N,"we"); N.Net.setConsent("guild"); roster={{"Bob-TestRealm",true},{"Off-TestRealm",false}}
    local ok,why=Wr.send("WEFF1","P|1","WHISPER","Stranger",{net="we",scope="guild"}); no(ok); eq(why,"no consent")
    ok,why=Wr.send("WEFF1","P|1","WHISPER","Off",{net="we"}); no(ok); eq(why,"no consent","an offline guildmate is not checked online")
    ok,why=Wr.send("WEFF1","P|1","WHISPER","Bob",{net="we",scope="public"}); yes(ok,why)
    -- a guildmate does not spend the public budget
    N=loadAddon(); Wr=N.Wire; netOn(N,"we"); N.Net.setConsent("public"); roster={{"Bob-TestRealm",true}}
    for i=1,6 do Wr.send("WEFF1","P|"..i,"WHISPER","Bob",{net="we",prio="own"}); advance(5) end; eq(sentCount("WEFF1","WHISPER"),6)
end)
test("1.0 T1-3: a clock stepping back counts as just sent; the limits hold",function()
    local N=loadAddon(); local Wr=N.Wire; establish(N)
    for i=1,100 do clock=clock+(i%2==0 and 50 or -50); Wr.send("LEGW1","R|"..i,"GUILD",nil,{prio="own"}) end
    yes(sentCount("LEGW1")<=6,"an oscillating clock gets no extra budget: "..sentCount("LEGW1"))
    -- the GUILD minute: 20 lines, then the clock steps back 30 s; the window still holds all 20
    N=loadAddon(); Wr=N.Wire
    for i=1,20 do yes(Wr.send("LEGW1","R|"..i,"GUILD",nil,{prio="own"}),i); advance(2.05) end
    clock=clock-30; local okg,whyg=Wr.send("LEGW1","R|x","GUILD",nil,{prio="own"}); no(okg); eq(whyg,"throttled")
    N=loadAddon(); Wr=N.Wire; yes(Wr.send("LFSw","Q","GUILD",nil,{prio="click"})); clock=clock-1
    local ok,why=Wr.send("LFSw","Q","GUILD",nil,{prio="click"}); no(ok); eq(why,"throttled")
    yes(Wr.send("LEGW1","F|1","GUILD",nil,{prio="click"})); clock=clock-5; ok,why=Wr.send("LEGW1","F|1","GUILD",nil,{prio="click"}); no(ok); eq(why,"throttled")
    -- invites and party calls too
    N=loadAddon(); Wr=N.Wire; yes(Wr.invite("Cara",clock)); ok,why=Wr.invite("Dana",clock-3); no(ok); eq(why,"throttled")
    -- six invites, then the clock steps back 300 s: the 600 s window still holds all six
    N=loadAddon(); Wr=N.Wire; for i=1,6 do yes(Wr.invite("Guest"..abc(i),clock+11*i)) end
    ok,why=Wr.invite("Guestz",clock+11*7-300); no(ok); eq(why,"throttled")
    yes(Wr.accept(clock)); ok,why=Wr.accept(clock-1); no(ok); eq(why,"throttled")
end)
test("1.0 T1: one player is one key for the per-player limit; the target tables are pruned",function()
    local N=loadAddon(); N.Main.we=nil; local Wr=N.Wire; netOn(N,"we"); N.Net.setConsent("public")
    for i,name in ipairs({"Stranger","stranger","Stranger-TestRealm","STRANGER","Stranger"}) do Wr.send("WEFF1","P|"..i,"WHISPER",name,{net="we",prio="own"}); advance(3) end
    eq(sentCount("WEFF1"),4,"spellings of one player share the 4 per minute")
    for i=1,30 do Wr.send("WEFF1","P|"..i,"WHISPER","Other"..abc(i),{net="we",prio="own"}); advance(3.1) end
    advance(61); Wr.send("WEFF1","P|x","WHISPER","Last",{net="we",prio="own"})
    local targets,offline=Wr.sizes(); yes(targets<=2,"stale players pruned: "..targets)
    sendResult=12; for i=1,300 do Wr.send("WEFF1","P|"..i,"WHISPER","Gone"..abc(i),{net="we",prio="click"}); advance(3.1) end; sendResult=0
    targets,offline=Wr.sizes(); yes(offline<=256,"offline skips capped: "..offline)
end)

-- 1.0 review round 2: T2
local function t2rec(N,over) local o={src="we",kind="group",origin="Scout",via="Scout",route="GUILD",rid="1",zone=100,count=1,
    layer={ns="server",value="8000"},heard=clock,share="guild"}; for k,v in pairs(over or {}) do o[k]=v end; return N.Record.new(o) end
test("1.0 T2-1: across networks a first-hand copy wins before the name count",function()
    local N=loadAddon(); establish(N); local T,st=N.Store,N.Main.store
    yes(T.report(st,t2rec(N,{rid="1",enemies={{hash="abc"}}}),clock))                              -- first-hand War Effort
    local forged=t2rec(N,{src="hh",kind="fight",via="Carrier",wrapped=true,hops=1,rid="9",enemies={{name="Kora Reed"},{name="Ann Lee"}},layer={ns="unknown"}})
    local ok,why=T.report(st,forged,clock); no(ok); eq(why,"duplicate","a relayed copy with more names does not replace a first-hand row")
    local rows=T.rows(st,clock,"reported"); eq(#rows,1); eq(rows[1].hand,"first")
    -- reverse order: the first-hand copy replaces the relayed one
    N=loadAddon(); establish(N); T,st=N.Store,N.Main.store
    yes(T.report(st,t2rec(N,{src="hh",kind="fight",via="Carrier",wrapped=true,hops=1,rid="9",enemies={{name="Kora Reed"}},layer={ns="unknown"}}),clock))
    yes(T.report(st,t2rec(N,{rid="1",enemies={{hash="abc"}}}),clock)); rows=T.rows(st,clock,"reported"); eq(#rows,1); eq(rows[1].hand,"first")

end)
test("1.0 T2: a War Effort sync answer is not first-hand",function()
    local N=loadAddon(); establish(N); advance(1)
    deliver("CHAT_MSG_ADDON","WEFF1","C|1|100|0.4|0.5|7086|1|"..(server%3600).."|12|1:2","GUILD","Origin"); drain()
    local hand; for _,row in pairs(N.Main.store.reports) do hand=row.record.hand end; eq(hand,"relayed")
    N=loadAddon(); establish(N); advance(1)
    deliver("CHAT_MSG_ADDON","WEFF1","C|1|100|0.4|0.5|7086|1|"..(server%3600),"GUILD","Origin"); drain()
    for _,row in pairs(N.Main.store.reports) do hand=row.record.hand end; eq(hand,"first","a live C")
end)
test("1.0 T2: a relayed HeadHunter record keeps its observer position and a hop count; the relay codes the origin's time",function()
    local N=loadAddon(); local R=N.Relay
    local hh=t2rec(N,{src="hh",kind="fight",origin="Mira Vale",via="Carrier",route="WHISPER",rid="1800000000",x=.5,y=.2,pos="observer",
        wrapped=true,hops=2,heard=100,layer={ns="unknown"},enemies={{name="Kora Reed",class="MAGE",level=60}},share="public"})
    local back=R.decode(R.encode(hh,100),"Relayer",100); yes(back); eq(back.pos,"observer"); yes(back.hops and back.hops>=1,"a hop count")
    local first=t2rec(N,{src="hh",kind="fight",origin="Mira Vale",via="Mira Vale",route="WHISPER",rid="1800000001",x=.5,y=.2,pos="observer",
        heard=100,layer={ns="unknown"},share="public"})
    back=R.decode(R.encode(first,100),"Relayer",100); eq(back.pos,"observer"); eq(back.hops,1,"one guild hop from a first-hand record")
    -- an explicit origin time is what the relay carries
    local timed=t2rec(N,{heard=100,at=40}); back=R.decode(R.encode(timed,100),"Relayer",100); eq(back.at,40)
end)
test("1.0 T2: a record with no timestamp uses receipt time and says so",function()
    local N=loadAddon(); establish(N); advance(1)
    hello("Scout",19); deliver("CHAT_MSG_ADDON","WEFF1","C|7|100|0.4|0.5|8000|1","GUILD","Scout"); drain()
    local row; for _,v in pairs(N.Main.store.reports) do row=v.record end; yes(row); yes(row.untimed); eq(row.at,row.heard)
    slash("reports"); yes(logged("time of receipt (no timestamp)"))
    -- a stamp in the future half of the hour is no usable stamp either
    N=loadAddon(); establish(N); advance(1); hello("Scout",19)
    deliver("CHAT_MSG_ADDON","WEFF1","C|9|100|0.4|0.5|8000|1|"..((math.floor(server)+100)%3600),"GUILD","Scout"); drain()
    for _,v in pairs(N.Main.store.reports) do row=v.record end; yes(row and row.untimed,"future stamp")
    -- a stamped report is not labelled
    N=loadAddon(); establish(N); advance(1); hello("Scout",19); report(8,8000,"Scout")
    for _,v in pairs(N.Main.store.reports) do row=v.record end; no(row.untimed)
end)

-- 1.0 review round 2: T3
test("1.0 T3-1: a channel we were already in is read but never joined or left by us",function()
    local N=loadAddon(); local D=N.Directory; chanList[1]="HeadHunterSync"; chanMembers.HeadHunterSync={"Peer One"}
    dirReady(N); eq(table.concat(joined,","),"WarEfforttestrealmA","only the channel we did not have"); eq(D.joined("hh"),"HeadHunterSync")
    advance(10); advance(3.1); eq(#D.members("hh"),1,"still read")
    N.Net.setConsent("guild"); eq(table.concat(leftCh,","),"WarEfforttestrealmA","only the channel we added is left")
    eq(chanList[1],"HeadHunterSync"); eq(D.joined("hh"),nil); eq(D.members("hh"),nil)
end)
test("1.0 T3-2: the delayed read rechecks combat, instance and the Channels window; an unreadable count forgets",function()
    local N=loadAddon(); local D=N.Directory; dirReady(N); chanMembers.HeadHunterSync={"Peer One"}
    for _,c in ipairs({"combat","instance","window"}) do
        yes(D.refresh("hh"),c)
        if c=="combat" then combat=true elseif c=="instance" then inInstance=true else ChannelFrame={IsShown=function() return true end} end
        advance(3.1); eq(D.members("hh"),nil,c)
        combat=false; inInstance=false; ChannelFrame=nil
    end
    yes(D.refresh("hh")); advance(3.1); eq(#D.members("hh"),1)
    local was=GetChannelDisplayInfo; GetChannelDisplayInfo=function(i) local n=chanList[i]; if n then return i..". "..n,false,nil,i,nil,true end end
    yes(D.refresh("hh")); advance(3.1); eq(D.members("hh"),nil,"unreadable count"); GetChannelDisplayInfo=was
end)
test("1.0 T3-2: a join that fails is not marked joined; toggling never stacks timers",function()
    local N=loadAddon(); local D=N.Directory; local real=JoinChannelByName
    JoinChannelByName=function(name) real(name); for i,c in ipairs(chanList) do if c==name then table.remove(chanList,i) end end; return false end
    dirReady(N); eq(D.joined("hh"),nil); eq(D.joined("we"),nil); JoinChannelByName=real
    N=loadAddon(); D=N.Directory; dirReady(N); local base=#timers
    for i=1,50 do N.Net.setSwitch("hh",false); N.Net.setSwitch("hh",true) end
    yes(#timers<=base+4,"timers "..#timers.." from "..base)
    advance(10); advance(3.1); local before=0; for _,c in ipairs(selected) do if c=="HeadHunterSync" then before=before+1 end end
    eq(before,1,"one loop for hh after the toggles")
    -- off long enough for its timer to fire unheard, then on again: reading resumes
    N.Net.setSwitch("hh",false); advance(400); N.Net.setSwitch("hh",true); advance(10); advance(3.1)
    local after=0; for _,c in ipairs(selected) do if c=="HeadHunterSync" then after=after+1 end end
    eq(after,before+1,"resumed after a timer fired while off")
end)

test("names end to end: a foreign spaced host First Last-7103 on realm 7102: line, hop, whisper, auto-accept",function()
    local N=loadAddon(); BULO=nil; numericHome(); establish(N); advance(1)
    deliver("CHAT_MSG_ADDON","LFSw","L 8000|100|h","GUILD","First Last-7103"); drain()
    local list=N.Main.candidates(); eq(#list,1); eq(list[1].name,"First Last-7103")
    local r=rec(N); local p=N.Main.hopPreview(r); eq(p.label,"Hop via First Last-7103")
    yes(N.Main.hopTo(r,p)); eq(#sent,1); eq(sent[1].target,"First Last-7103"); eq(sent[1].prefix,"LayerSwap")
    -- a local namesake's invite is not the asked host's
    inviteFrom("First Last"); eq(#accepts,0); popup.shown=false
    for _,other in ipairs({"First Last-7105","First Last-7104","First Last-7102","First Lasts-7103","First-7103"}) do
        inviteFrom(other); eq(#accepts,0,other); popup.shown=false end
    inviteFrom("First Last-7103"); eq(#accepts,1); yes(logged("accepted First Last's invite"))
    eq(N.Main.auto.group.short,"first last-7103","the group tracked is the asked host's")
end)

-- a732c39 review (مانع r040b/a7): guild changes
local function hReady(N) establish(N); roster={{"Bob-TestRealm",true}}; deliver("GUILD_ROSTER_UPDATE",true); drain(); slash("host on"); sent={} end
test("a7: leaving the guild makes hosting inactive; a new guild's H waits for that guild's roster",function()
    local N=loadAddon(); hReady(N); yes(N.Main.host.on)
    inGuild=false; deliver("PLAYER_GUILD_UPDATE","player"); drain()
    no(N.Main.host.on,"inactive"); yes(N.Main.host.want,"still saved on"); yes(logged("not in a guild"))
    eq(N.Adapters.roster.at,nil,"roster flag reset")
    -- joining another guild: nothing before that guild's roster
    inGuild=true; guildName="Other Guild"; deliver("PLAYER_GUILD_UPDATE","player"); drain(); no(N.Main.host.on)
    advance(61); legw("F|1","Cy"); advance(7); drain(); eq(#legwSent("H|"),0,"no H before the new roster")
    deliver("GUILD_ROSTER_UPDATE",true); drain(); yes(N.Main.host.on,"active on the new roster"); eq(#legwSent("H|"),0,"activation sends nothing")
    advance(61); legw("F|1","Cy"); advance(7); drain(); eq(#legwSent("H|"),1)
    -- announceHost itself refuses while not in a guild
    -- (r040c 1f: through events) out of the guild without the event seen yet: an F gets no H
    inGuild=false; advance(61); legw("F|1","Cy"); advance(7); drain(); eq(#legwSent("H|"),1); inGuild=true
end)
test("a7: leaving the guild drops a scheduled F answer and an owed H",function()
    local N=loadAddon(); hReady(N); advance(61)
    legw("F|1","Cy"); eq(#legwSent("H|"),0)                         -- answer scheduled 1 to 6 s out
    inGuild=false; deliver("PLAYER_GUILD_UPDATE","player"); drain()
    inGuild=true; deliver("PLAYER_GUILD_UPDATE","player"); deliver("GUILD_ROSTER_UPDATE",true); drain()
    advance(7); drain(); eq(#legwSent("H|"),0,"the scheduled answer was dropped")
    -- owed H (turned on before any roster), then out of the guild and back: never sent
    N=loadAddon(); establish(N); slash("host on"); yes(N.Main.host.announceOwed)
    inGuild=false; deliver("PLAYER_GUILD_UPDATE","player"); drain(); eq(N.Main.host.announceOwed,nil)
    inGuild=true; deliver("PLAYER_GUILD_UPDATE","player"); deliver("GUILD_ROSTER_UPDATE",true); drain(); eq(#legwSent("H|"),0)
    -- a guild update that changes nothing (same guild, still in it) keeps everything, also the first one
    N=loadAddon(); hReady(N); deliver("PLAYER_GUILD_UPDATE","player"); drain(); yes(N.Main.host.on); yes(N.Adapters.roster.at)
    deliver("PLAYER_GUILD_UPDATE","player"); drain(); yes(N.Main.host.on)
    -- (r040c 1f) a guild name unreadable on a guild event is "unknown": inactive until a readable name and its roster
    -- (r040c 21e: a blink in a known guild drops nothing; the next readable roster or event of that guild restores)
    guildName=nil; deliver("PLAYER_GUILD_UPDATE","player"); drain(); no(N.Main.host.on); guildName="Test Guild"
    deliver("GUILD_ROSTER_UPDATE",true); drain(); yes(N.Main.host.on)
    -- another guild without leaving in between: a change
    guildName="Third Guild"; deliver("PLAYER_GUILD_UPDATE","player"); drain(); no(N.Main.host.on); eq(N.Adapters.roster.at,nil)
end)

-- 1.0 lane A1: own sightings out (O on LEGW1; C+E on WEFF1 for two or more, where a War Effort reader was heard)
local function foe(N,i,over) local e={key="Player-1-9"..i,name=({"Kora Reed","Ann Lee","Bo Dyl","Cy Fen","Di Gar","Ed Hol"})[i],realm="Test Realm",
    class="MAGE",level=60,at=clock,faction="opposite",source="own target",x=.25,y=.75}; for k,v in pairs(over or {}) do e[k]=v end
    return N.Store.observe(N.Main.store,e,clock) end
local function weSent(t) local out={}; for _,m in ipairs(sent) do if m.prefix=="WEFF1" and (not t or m.text:sub(1,1)==t) then out[#out+1]=m end end; return out end
local function oLines() return legwSent("O|") end
test("1.0 A1: WeOut encodes C and E as War Effort does; they decode back to the same values",function()
    local N=loadAddon(); local W,P=N.WeOut,N.Protocol
    eq(W.cluster(42,100,.4,.5,7086,4,100),"C|42|100|0.400|0.500|7086|4|100")
    local vec="C|42|100|0.400|0.500|7086|4|100|12||4f4c594d505553:4"            -- study vector (spread, guild: not sent by us)
    eq(vec:sub(1,#W.cluster(42,100,.4,.5,7086,4,100)),W.cluster(42,100,.4,.5,7086,4,100))
    local e=W.enemies(42,{{hash="Zzm",class="MAGE",level=60},{hash="AbC",class="WARRIOR",level=-1},{hash="def"},{hash="xyz",class="ROGUE",level=59}},100)
    eq(#e,1); eq(e[1],"E|42|1|1|Zzm:H:60,AbC:A:-1,def:?:?,xyz:D:59|100")
    local c=P.decode(W.cluster(65535,1429,1,0,0,200,3599)); eq(c.rid,65535); eq(c.map,1429); eq(c.x,1); eq(c.y,0); eq(c.layer,0); eq(c.count,200); eq(c.stamp,3599)
    local many={}; for i=1,40 do many[i]={hash=string.format("%03d",i),class="PRIEST",level=i} end
    local parts=W.enemies(7,many,5); eq(#parts,3); for i,p in ipairs(parts) do local d=P.decode(p); yes(d,p); eq(d.part,i); eq(d.total,3); yes(#p<=255) end
    eq(#P.decode(parts[1]).enemies,18); eq(P.decode(parts[3]).enemies[4].level,40)
    eq(W.cluster(1,100,1.7,-3,7086,999,0),"C|1|100|1.000|0.000|7086|200|0","clamped")
end)
test("1.0 A1: an O line to the guild: 3 s settle, one per 15 s, the same enemy again only after 60 s",function()
    local N=loadAddon(); establish(N); local M=N.Main
    foe(N,1); M.shareTick(); eq(#oLines(),0,"settling"); advance(3); M.shareTick(); eq(#oLines(),1)
    local o=oLines()[1].text; yes(o:find("^O|1|1|100|0.250|0.750|7086|%d+|1|"),o)
    advance(1); foe(N,2); advance(3); M.shareTick(); eq(#oLines(),1,"inside 15 s")
    advance(12); M.shareTick(); eq(#oLines(),2,"after 15 s, the new enemy")
    advance(16); foe(N,1); foe(N,2); advance(3); M.shareTick(); eq(#oLines(),2,"both shared within 60 s")
    advance(41); foe(N,1); advance(3); M.shareTick(); eq(#oLines(),3,"60 s later")
    -- same faction, unknown faction, other zone: never shared
    N=loadAddon(); establish(N); foe(N,1,{faction="same"}); foe(N,2,{faction="unknown"}); advance(3); N.Main.shareTick(); advance(3); N.Main.shareTick(); eq(#oLines(),0)
    -- not in a guild: no O line
    N=loadAddon(); establish(N); inGuild=false; foe(N,1); advance(3); N.Main.shareTick(); eq(#oLines(),0); inGuild=true
end)
test("1.0 A1: a guildmate's O line is a first-hand row with names; our own is not stored",function()
    local N=loadAddon(); establish(N); local R=N.Relay
    local line=R.ownLine({rid=7,zone=100,x=.25,y=.75,layer="7086",age=2,count=3,enemies={{name="Kora Reed",class="MAGE",level=60},{name="Ann Lee"}}})
    legw(line,"Scout"); local rows=N.Store.rows(N.Main.store,clock,"reported"); yes(#rows>=1)
    local r=rows[1].record; eq(r.src,"le"); eq(r.hand,"first"); eq(r.origin,"Scout"); eq(r.enemies[1].name,"Kora Reed"); eq(r.count,3); eq(r.pos,"observer")
    eq(rows[1].positionKind,"observer's position","the O line carries where the sender stood")
    eq(r.layer.ns,"server"); eq(r.layer.value,"7086"); eq(r.at,clock-2)
    local n=N.Safe.count(N.Main.store.reports); legw(line,"Me"); eq(N.Safe.count(N.Main.store.reports),n,"own echo")
    local five={}; for i=1,5 do five[i]="4b6f7261"..string.format("%02x",96+i)..":MAGE:60" end
    for i,bad in ipairs({"O|2|8|100|0.250|0.750|7086|2|3|","O|1|x|100|0.250|0.750|7086|2|3|","O|1|9|100|2.0|0.750|7086|2|3|",
        "O|1|10|100|0.250|0.750|7086|2|3|zz:MAGE:60","O|1|11|100|0.250|0.750|7086|2|5|"..table.concat(five,",")}) do
        legw(bad,"Scout"..abc(i)); end
    eq(N.Safe.count(N.Main.store.reports),n)
    -- Wire carries only the O grammar
    local Wr=N.Wire; yes(Wr.send("LEGW1",line,"GUILD",nil,{prio="own"}))
    for _,bad in ipairs({"O|1|7|100|0.250|0.750|7086|2|3|x y","O|2","O|1|7|100|a|b|7086|2|3|"}) do local ok,why=Wr.send("LEGW1",bad,"GUILD",nil,{prio="own"}); no(ok,bad); eq(why,"bad text") end
end)
test("1.0 A1: C and E for two or more enemies, only where a War Effort reader was heard; the id rises and is saved",function()
    local N=loadAddon(); netOn(N,"we"); establish(N); local M=N.Main
    foe(N,1); foe(N,2); advance(3); M.shareTick(); eq(#oLines(),1); eq(#weSent(),0,"no War Effort reader heard")
    hello("Wes",19); advance(16); foe(N,3); foe(N,4); advance(3); M.shareTick()
    -- (foes 1 and 2 are 19 s old by now: the report is foes 3 and 4)
    local c,e=weSent("C"),weSent("E"); eq(#c,1); eq(#e,1); eq(c[1].kind,"GUILD"); yes(c[1].text:find("^C|2|100|0.250|0.750|7086|2|%d+$"),c[1].text)
    local d=N.Protocol.decode(e[1].text); eq(#d.enemies,2); eq(d.enemies[1].hash,N.Hash.player("Bo Dyl","Test Realm")); eq(d.enemies[1].class,"MAGE"); eq(d.enemies[1].level,60)
    eq(c[1].text:match("|(%d+)$"),tostring(math.floor(server)%3600),"the stamp is server time % 3600")
    eq(LayerEnemiesDB.weReportId,2)
    -- a C from a War Effort user is no hello: it does not open a route
    N.Main.weHeard={}; report(1,9000,"Wes"); advance(16); foe(N,5); foe(N,6); advance(3); M.shareTick(); eq(#oLines(),3); eq(#weSent("C"),1,"no reader")
    hello("Wes",19)
    -- one enemy alone: an O line, no C
    advance(61); foe(N,5); advance(3); M.shareTick(); eq(#weSent("C"),1); eq(#oLines(),4)
    -- the reader's 600 s run out
    advance(600); foe(N,1); foe(N,2); advance(3); M.shareTick(); eq(#weSent("C"),1)
    -- saved across a reload, and 65535 wraps to 1
    LayerEnemiesDB.weReportId=300; local saved=LayerEnemiesDB
    N=loadAddon(); LayerEnemiesDB=saved; reload(N); netOn(N,"we"); establish(N); hello("Wes",19); foe(N,1); foe(N,2); advance(3); N.Main.shareTick()
    yes(weSent("C")[1].text:find("^C|301|"),weSent("C")[1].text)
    for i,v in ipairs({0,65536,1.5,"7",secret}) do LayerEnemiesDB.weReportId=v; reload(N); eq(LayerEnemiesDB.weReportId,nil,"bad saved id "..i) end
    LayerEnemiesDB.weReportId=65535; saved=LayerEnemiesDB
    N=loadAddon(); LayerEnemiesDB=saved; reload(N); netOn(N,"we"); establish(N); hello("Wes",19); foe(N,1); foe(N,2); advance(3); N.Main.shareTick()
    yes(weSent("C")[1].text:find("^C|1|"),weSent("C")[1].text); eq(LayerEnemiesDB.weReportId,1)
end)
test("1.0 A1: no C or E with the network off, War Effort loaded, in an instance, without a position; groups get them too",function()
    local function run(setup) local N=loadAddon(); netOn(N,"we"); establish(N); hello("Wes",19); setup(N); foe(N,1); foe(N,2); advance(3); N.Main.shareTick(); return N end
    run(function(N) N.Net.SHIP.we=false end); eq(#weSent(),0,"ship constant")
    run(function(N) N.Net.setSwitch("we",false) end); eq(#weSent(),0,"switch")
    run(function() loaded.WarEffortScout=true end); eq(#weSent(),0,"War Effort loaded"); loaded.WarEffortScout=nil
    local N=run(function() inInstance=true end); eq(#weSent(),0,"instance"); inInstance=false
    local was=C_Map.GetPlayerMapPosition; N=run(function() C_Map.GetPlayerMapPosition=function() return nil end end); C_Map.GetPlayerMapPosition=was
    eq(#weSent(),0,"no position"); eq(#oLines(),1,"the O line goes without coordinates")
    -- a War Effort reader in our party: the party gets C+E too
    N=loadAddon(); netOn(N,"we"); establish(N); grouped=true; hello("Pam",19,"PARTY"); foe(N,1); foe(N,2); advance(3); N.Main.shareTick()
    local kinds={}; for _,m in ipairs(weSent("C")) do kinds[#kinds+1]=m.kind end; eq(table.concat(kinds,","),"PARTY")
end)

-- مانع on e4f27f0 (r040b/e4): one player, one key; through the real CHAT_MSG_ADDON path
test("e4 M1: an own-realm suffixed origin heard first-hand and through the guild relay is one row, in both orders",function()
    local N=loadAddon(); establish(N); N.Relay.rand=function() return 2 end; advance(1)
    hello("Scout-TestRealm",19,"PARTY"); report(1,8000,"Scout-TestRealm",nil,"PARTY")
    eq(N.Safe.count(N.Main.store.reports),1)
    local first=N.Store.rows(N.Main.store,clock,"reported")[1].record; eq(first.src,"we"); eq(first.origin,"Scout-TestRealm")
    local copy=N.Relay.encode(first,clock); yes(copy)
    deliver("CHAT_MSG_ADDON","LEGW1",copy,"GUILD","Quick"); drain()
    eq(N.Safe.count(N.Main.store.reports),1,"direct then relay"); eq(N.Store.rows(N.Main.store,clock,"reported")[1].record.src,"we")
    eq(N.Main.relay.pending["we:scout:1"],nil,"our pending relay stood down")
    -- relay first, then the first-hand report: the first-hand one replaces the copy
    N=loadAddon(); establish(N); advance(1)
    deliver("CHAT_MSG_ADDON","LEGW1",copy,"GUILD","Quick"); drain(); eq(N.Safe.count(N.Main.store.reports),1)
    eq(N.Store.rows(N.Main.store,clock,"reported")[1].record.src,"guild")
    hello("Scout-TestRealm",19,"PARTY"); report(1,8000,"Scout-TestRealm",nil,"PARTY")
    eq(N.Safe.count(N.Main.store.reports),1,"relay then direct"); eq(N.Store.rows(N.Main.store,clock,"reported")[1].record.src,"we")
    -- the bare spelling is the same player too
    N=loadAddon(); establish(N); advance(1)
    deliver("CHAT_MSG_ADDON","LEGW1",copy,"GUILD","Quick"); drain(); hello("Scout",19,"PARTY"); report(1,8000,"Scout",nil,"PARTY")
    eq(N.Safe.count(N.Main.store.reports),1); eq(N.Store.rows(N.Main.store,clock,"reported")[1].record.src,"we")
    -- another realm is another player: two rows
    N=loadAddon(); establish(N); advance(1)
    deliver("CHAT_MSG_ADDON","LEGW1",copy,"GUILD","Quick"); drain(); hello("Scout-OtherRealm",19,"PARTY"); report(1,8000,"Scout-OtherRealm",nil,"PARTY")
    eq(N.Safe.count(N.Main.store.reports),2)
end)
test("e4 S1: the folded key everywhere a player is keyed (peers, report order, rates, relay ids, reporters)",function()
    -- Peers: a hello as "Scout-TestRealm" vouches for "Scout"
    local N=loadAddon(); establish(N); advance(1)
    hello("Scout-TestRealm",19,"PARTY"); report(1,8000,"Scout",nil,"PARTY")
    local r=N.Store.rows(N.Main.store,clock,"reported")[1].record; eq(r.layer.ns,"server"); eq(r.layer.value,"8000")
    -- report order: the same id from the other spelling is not a new report; one reporter
    report(1,8000,"Scout-TestRealm",nil,"PARTY"); eq(N.Safe.count(N.Main.store.reports),1); eq(#N.Store.reporters(N.Main.store,clock),1)
    report(2,8000,"Scout-TestRealm",nil,"PARTY"); eq(#N.Store.reporters(N.Main.store,clock),1,"two reports, one reporter")
    -- receive limits share one slot per player
    local st=N.Reports.new(); for i=1,6 do yes(N.Reports.allow(st,i%2==0 and "Scout" or "Scout-TestRealm",false,0)) end
    no(N.Reports.allow(st,"SCOUT",false,1)); yes(N.Reports.allow(st,"Scout-OtherRealm",false,1))
    st=N.Relay.new(); for i=1,12 do yes(N.Relay.allow(st,i%2==0 and "Bob" or "Bob-TestRealm",0)) end; no(N.Relay.allow(st,"bob",1))
    st=N.HeadHunter.new(); for i=1,6 do yes(N.HeadHunter.allow(st,i%2==0 and "Fighter" or "Fighter-TestRealm",0)) end; no(N.HeadHunter.allow(st,"Fighter",1))
    -- relay ids
    eq(N.Relay.key({src="we",origin="Scout-TestRealm",okey="scout",rid="1"}),"we:scout:1")
    eq(N.Peers.key("Scout-TestRealm"),N.Peers.key("scout")); eq(N.Peers.key("Bad|Name"),nil)
end)
test("e4 S3: decoders through CHAT_MSG_ADDON with spaced and suffixed names (War Effort, HeadHunter, guild relay)",function()
    local N=loadAddon(); establish(N); advance(1); server=HHT
    -- HeadHunter whisper from an own-realm suffixed spaced name, then the bare one: one sighting, one origin key
    deliver("CHAT_MSG_ADDON","HeadHunter","1AL:Kora Reed;2s;"..b36(server)..";dw;6y","WHISPER","First Last-TestRealm"); drain()
    local rows=N.Store.rows(N.Main.store,clock,"reported"); eq(#rows,1); eq(rows[1].record.okey,"first last"); eq(rows[1].record.origin,"First Last-TestRealm")
    deliver("CHAT_MSG_ADDON","HeadHunter","1AL:Kora Reed;2s;"..b36(server)..";dw;6y","WHISPER","First Last"); drain()
    eq(#N.Store.rows(N.Main.store,clock,"reported"),1,"the same report from the same player")
    -- a foreign spaced name is its own reporter; malformed names are dropped
    deliver("CHAT_MSG_ADDON","HeadHunter","1AL:Ann Lee;2s;"..b36(server)..";dw;6y","WHISPER","First Last-7105"); drain()
    eq(#N.Store.rows(N.Main.store,clock,"reported"),2)
    for i,bad in ipairs({"First  Last","One Two Three","First Last-","Bad|Name"}) do
        deliver("CHAT_MSG_ADDON","HeadHunter","1AL:Bo Dyl;2s;"..b36(server)..";dw;6y","WHISPER",bad); drain() end
    eq(#N.Store.rows(N.Main.store,clock,"reported"),2,"malformed HeadHunter senders")
    -- War Effort on GUILD from a spaced guildmate, and from malformed names
    N=loadAddon(); establish(N); advance(1)
    hello("First Last",19); report(5,8000,"First Last"); local w=N.Store.rows(N.Main.store,clock,"reported"); eq(#w,1); eq(w[1].record.okey,"first last")
    for i,bad in ipairs({"First  Last"," First Last","One Two Three"}) do report(5+i,8000,bad) end
    eq(#N.Store.rows(N.Main.store,clock,"reported"),1,"malformed War Effort senders")
    -- a guild relay from a suffixed guildmate naming a spaced foreign origin
    local rec=weRec(N,{origin="Cy Fen-7105",via="Cy Fen-7105",heard=clock,age=0}); yes(rec)
    deliver("CHAT_MSG_ADDON","LEGW1",N.Relay.encode(rec,clock),"GUILD","Bob-TestRealm"); drain()
    local g; for _,row in ipairs(N.Store.rows(N.Main.store,clock,"reported")) do if row.record.src=="guild" then g=row.record end end
    yes(g); eq(g.origin,"Cy Fen-7105"); eq(g.okey,"cy fen-7105"); eq(g.hand,"relayed")
    -- our own suffixed name relayed back is our echo
    deliver("CHAT_MSG_ADDON","LEGW1",N.Relay.encode(weRec(N,{origin="Me-TestRealm",via="Me-TestRealm",rid="9",heard=clock,age=0}),clock),"GUILD","Bob"); drain()
    eq(N.Main.lastDrop,"relay origin")
end)

test("e4 S1b: one key in the remembered hosts and the offline skip ('Gone' and 'Gone-TestRealm' are one player)",function()
    local N=loadAddon(); local Hs=N.Hosts; local st=Hs.new()
    yes(Hs.heard(st,"First Last-TestRealm",{kind="heard",layer="8000-1",zone=100,hosting=true},10))
    yes(Hs.heard(st,"First Last",{kind="heard",layer="8001-1",zone=100,hosting=true},11))
    eq(N.Safe.count(st.heard),1,"one entry"); local k,e=next(st.heard); eq(e.layer,"8001-1"); eq(k,"First Last","the latest spelling is kept to whisper")
    Hs.heard(st,"FIRST LAST-TestRealm",{kind="heard",hosting=false},12); eq(next(st.heard),nil,"not hosting removes it under any spelling")
    yes(Hs.heard(st,"First Last-7105",{kind="heard",layer="8000-1",zone=100,hosting=true},13)); yes(Hs.heard(st,"First Last",{kind="heard",layer="8000-1",zone=100,hosting=true},13))
    eq(N.Safe.count(st.heard),2,"another realm is another host")
    for _,bad in ipairs({"Bad|Name","First  Last","One Two Three"}) do no(Hs.heard(st,bad,{kind="heard",layer="8000-1",zone=100,hosting=true},14),bad) end
    eq(N.Safe.count(st.heard),2)
    -- the friendly list shows the spelling heard
    N=loadAddon(); establish(N); N.Hosts.heard(N.Main.heard,"Cy Fen-TestRealm",{kind="heard",layer="8000-1",zone=100,hosting=true},N.Adapters.wall())
    local names={}; for _,c in ipairs((N.Main.candidates())) do names[#names+1]=c.name end; yes(table.concat(names,","):find("Cy Fen-TestRealm",1,true),table.concat(names,","))
    -- Wire: an offline result under one spelling skips the other
    N=loadAddon(); local Wr=N.Wire; netOn(N,"hh"); N.Net.setConsent("public")
    sendResult=12; local ok,why=Wr.send("HeadHunter","1AN:LayerEnemies","WHISPER","Gone-TestRealm",{net="hh",scope="public"}); no(ok); eq(why,"offline"); sendResult=0
    ok,why=Wr.send("HeadHunter","1AN:LayerEnemies","WHISPER","gone",{net="hh",scope="public"}); no(ok); eq(why,"offline")
    ok,why=Wr.send("HeadHunter","1AN:LayerEnemies","WHISPER","Gone-OtherRealm",{net="hh",scope="public"}); yes(ok,why)
end)

-- مانع's closing round for B and C (r040c)
test("r040c G1: a listed Bulo or LayerSwap row counts as a host only with its host flag",function()
    for _,c in ipairs({{"LFSw","L 9500|100|-"},{"LFSw","L 9500|100|h"}}) do
        local N=loadAddon(); BULO=nil; establish(N); chatBox(); roster={{"Eve-TestRealm",true}}
        local r=rec(N,{src="guild",layer={ns="server",value="9500"}}); yes(N.Main.hopTo(r,N.Main.hopPreview(r))); drain()
        deliver("CHAT_MSG_GUILD",GLINE:sub(4),"Me"); drain()
        deliver("CHAT_MSG_ADDON",c[1],c[2],"GUILD","Eve"); drain()
        inviteFrom("Eve"); eq(#accepts,c[2]:sub(-1)=="h" and 1 or 0,c[2])
    end
    -- a LayerSwap book row with host=false
    local N=loadAddon(); BULO=nil; establish(N); chatBox(); roster={{"Eve-TestRealm",true}}
    -- (on another layer than the hop's, so the hop is the guild ask and not a direct request to Eve)
    LayerSwapDB={book={Eve={layer="9600-1",zone=100,at=N.Adapters.wall(),host=false}}}; loaded.LayerSwap=true
    local r=rec(N,{src="guild",layer={ns="server",value="9500"}}); yes(N.Main.hopTo(r,N.Main.hopPreview(r))); drain(); eq(opened[#opened].text,GLINE)
    deliver("CHAT_MSG_GUILD",GLINE:sub(4),"Me"); drain(); inviteFrom("Eve"); eq(#accepts,0,"LayerSwap host=false")
    popup.shown=false; LayerSwapDB.book.Eve.host=true; advance(11); inviteFrom("Eve"); eq(#accepts,1,"LayerSwap host=true")
    LayerSwapDB=nil; loaded.LayerSwap=nil
end)
test("r040c G2/G3: an answer before our guild line goes out does not count; the window runs from the send",function()
    local N=loadAddon(); BULO=nil; establish(N); chatBox(); roster={{"Cy-TestRealm",true},{"Bob-TestRealm",true}}
    local r=rec(N,{src="guild",layer={ns="server",value="9500"}}); yes(N.Main.hopTo(r,N.Main.hopPreview(r))); drain()
    deliver("CHAT_MSG_ADDON","LayerSwap","claim Me","GUILD","Cy"); deliver("CHAT_MSG_ADDON","LayerSwap","heard Me|9500-3|100|h","GUILD","Bob"); drain()
    advance(100); deliver("CHAT_MSG_GUILD",GLINE:sub(4),"Me"); drain()
    inviteFrom("Cy"); inviteFrom("Bob"); eq(#accepts,0,"answers seen before the send")
    -- 100 s after the draft, 30 s after the send: still in the window
    advance(30); deliver("CHAT_MSG_ADDON","LayerSwap","claim Me","GUILD","Cy"); drain(); inviteFrom("Cy"); eq(#accepts,1,"30 s after a late send")
    -- and an answer more than 120 s after the send is late
    N=loadAddon(); BULO=nil; establish(N); chatBox(); roster={{"Cy-TestRealm",true}}
    r=rec(N,{src="guild",layer={ns="server",value="9500"}}); yes(N.Main.hopTo(r,N.Main.hopPreview(r))); drain()
    deliver("CHAT_MSG_GUILD",GLINE:sub(4),"Me"); drain(); advance(121)
    deliver("CHAT_MSG_ADDON","LayerSwap","claim Me","GUILD","Cy"); drain(); inviteFrom("Cy"); eq(#accepts,0,"after the window")
end)
test("r040c: an AcceptGroup that throws spends the ask",function()
    local N=loadAddon(); BULO=nil; establish(N); askBob(N)
    local was=AcceptGroup; AcceptGroup=function() error("blocked") end
    inviteFrom("Bob"); eq(N.Main.invite.pending,nil,"the ask is spent"); eq(N.Main.auto.group,nil); AcceptGroup=was
    advance(11); popup.shown=false; inviteFrom("Bob"); eq(#accepts,0,"no second try")
end)
test("r040c D1: no join while the channel display list is unreadable or empty",function()
    local N=loadAddon(); local D=N.Directory; chanList={}
    dirReady(N); eq(#joined,0,"empty list (still loading)")
    local was=GetNumDisplayChannels; GetNumDisplayChannels=function() return nil end; chanList={"General"}
    D.sync(); eq(#joined,0,"unreadable count"); GetNumDisplayChannels=was
    D.sync(); eq(#joined,2,"filled: joins")
end)
test("r040c D2: ours only by our own join notice; a hand leave and rejoin is the player's; a nil or empty return is no join",function()
    -- nil and "" returns: not joined
    for _,ret in ipairs({false,""}) do
        local N=loadAddon(); local D=N.Directory; joinReturn=ret; joinNotice=false; dirReady(N); eq(D.joined("hh"),nil,tostring(ret)); joinReturn=nil; joinNotice=true
    end
    local N=loadAddon(); local D=N.Directory; local real=JoinChannelByName
    JoinChannelByName=function(name) real(name); return nil end; dirReady(N); eq(D.joined("hh"),nil,"nil return"); JoinChannelByName=real
    -- joined but no notice of ours: we read it and never leave it
    N=loadAddon(); D=N.Directory; joinNotice=false; dirReady(N); joinNotice=true; yes(D.joined("hh"))
    N.Net.setSwitch("hh",false); eq(#leftCh,0,"never ours: not left")
    -- the notice arriving a moment later counts
    N=loadAddon(); D=N.Directory; joinNotice=false; dirReady(N); joinNotice=true
    for i,c in ipairs(chanList) do if c=="HeadHunterSync" then deliver("CHAT_MSG_CHANNEL_NOTICE","YOU_CHANGED","","",i..". "..c,"",0,0,i,c) end end
    N.Net.setSwitch("hh",false); eq(table.concat(leftCh,","),"HeadHunterSync")
    -- ours, then the player leaves by hand: not rejoined this session; rejoined by hand: theirs, never left by us
    N=loadAddon(); D=N.Directory; dirReady(N); eq(#joined,2)
    for i,c in ipairs(chanList) do if c=="HeadHunterSync" then table.remove(chanList,i); deliver("CHAT_MSG_CHANNEL_NOTICE","YOU_LEFT","","",i..". "..c,"",0,0,i,c) end end
    eq(D.joined("hh"),nil); D.sync(); advance(5); eq(#joined,2,"not rejoined after a hand leave")
    chanList[#chanList+1]="HeadHunterSync"; deliver("CHAT_MSG_CHANNEL_NOTICE","YOU_JOINED","","",#chanList..". HeadHunterSync","",0,0,#chanList,"HeadHunterSync")
    D.sync(); eq(D.joined("hh"),"HeadHunterSync","read again"); eq(#joined,2)
    N.Net.setSwitch("hh",false); eq(#leftCh,0,"the player's channel is never left by us")
    -- a notice for another channel, or one we did not ask for, makes nothing ours
    N=loadAddon(); D=N.Directory; chanList={"General","HeadHunterSync"}
    deliver("CHAT_MSG_CHANNEL_NOTICE","YOU_JOINED","","","2. HeadHunterSync","",0,0,2,"HeadHunterSync"); dirReady(N)
    N.Net.setSwitch("hh",false); eq(#leftCh,0)
end)

test("cc: Directory lists nobody while our own name or home realm is unreadable; one entry per player",function()
    local N=loadAddon(); local D=N.Directory; numericHome(); dirReady(N)
    chanMembers.HeadHunterSync={"Peer One","Peer One-7102","peer one","Me Self-7102","Me Self","Peer Two-7105","Peer Two"}
    advance(10); advance(3.1); local m=D.members("hh")
    eq(#m,3,table.concat(m,",")); eq(D.count("hh"),3); eq(m[1],"Peer One"); eq(m[2],"Peer Two-7105"); eq(m[3],"Peer Two")
    -- home realm unreadable: our "-7102" entries cannot be told from peers, so no list at all
    GetRealmName=function() return nil end; GetNormalizedRealmName=function() return nil end
    yes(D.refresh("hh")); advance(3.1); eq(D.members("hh"),nil,"home realm unreadable"); eq(D.count("hh"),nil)
    numericHome(); yes(D.refresh("hh")); advance(3.1); eq(#D.members("hh"),3)
    -- our own name unreadable
    local was=UnitName; UnitName=function(u) if u=="player" then return nil end; return was(u) end
    yes(D.refresh("hh")); advance(3.1); eq(D.members("hh"),nil,"own name unreadable"); UnitName=was
end)

-- مانع on 1f7cd69 (r040c/1f): guild changes through events, in every order
local function hostF() legw("F|1","Cy"); advance(7); drain(); return #legwSent("H|") end
test("1f M2: leave, a roster while guildless, join: no H until the new guild's roster",function()
    local N=loadAddon(); hReady(N); advance(61)
    inGuild=false; deliver("PLAYER_GUILD_UPDATE","player"); drain(); no(N.Main.host.on)
    deliver("GUILD_ROSTER_UPDATE",true); drain(); eq(N.Adapters.roster.at,nil,"a guildless roster is no roster"); no(N.Main.host.on)
    local calls=rosterCalls; advance(16)
    inGuild=true; guildName="Guild B"; deliver("PLAYER_GUILD_UPDATE","player"); drain()
    eq(rosterCalls,calls+1,"the new guild's roster is asked for"); no(N.Main.host.on); advance(61); eq(hostF(),0,"no H before B's roster")
    deliver("GUILD_ROSTER_UPDATE",true); drain(); yes(N.Main.host.on); advance(61); eq(hostF(),1)
    -- a guildless login: a roster then joining and turning hosting on sends no H before B's roster
    N=loadAddon(); inGuild=false; establish(N); deliver("GUILD_ROSTER_UPDATE",true); drain(); eq(N.Adapters.roster.at,nil)
    inGuild=true; guildName="Guild B"; deliver("PLAYER_GUILD_UPDATE","player"); drain(); slash("host on"); eq(#legwSent("H|"),0)
    advance(61); eq(hostF(),0); deliver("GUILD_ROSTER_UPDATE",true); drain(); eq(#legwSent("H|"),1,"the owed H on B's roster")
end)
test("1f: joining B with no leave seen is a switch, by the guild event or by a roster alone",function()
    local N=loadAddon(); hReady(N); advance(61); guildName="Guild B"; deliver("PLAYER_GUILD_UPDATE","player"); drain()
    no(N.Main.host.on); eq(N.Adapters.roster.at,nil); eq(hostF(),0)
    deliver("GUILD_ROSTER_UPDATE",true); drain(); yes(N.Main.host.on)
    -- the event missed: a roster arriving under B's name is noticed as the switch (and not counted as B's roster)
    N=loadAddon(); hReady(N); advance(61); local calls=rosterCalls; advance(16); guildName="Guild B"
    deliver("GUILD_ROSTER_UPDATE",true); drain(); no(N.Main.host.on,"switch noticed on the roster"); eq(rosterCalls,calls+1,"a fresh roster asked for")
    eq(hostF(),0); deliver("GUILD_ROSTER_UPDATE",true); drain(); yes(N.Main.host.on); advance(61); eq(hostF(),1)
end)
test("1f: B's roster before the guild event: the switch asks for a roster; the late event changes nothing more",function()
    local N=loadAddon(); hReady(N); advance(61); local calls=rosterCalls; advance(16)
    guildName="Guild B"; deliver("GUILD_ROSTER_UPDATE",true); drain(); eq(rosterCalls,calls+1); no(N.Main.host.on)
    deliver("PLAYER_GUILD_UPDATE","player"); drain(); eq(rosterCalls,calls+1,"no second request inside 15 s")
    deliver("GUILD_ROSTER_UPDATE",true); drain(); yes(N.Main.host.on,"the asked-for roster restores hosting")
end)
test("1f: an unreadable guild name in a switch keeps nothing of the old guild",function()
    local N=loadAddon(); hReady(N); advance(61)
    inGuild=false; deliver("PLAYER_GUILD_UPDATE","player"); drain()
    inGuild=true; guildName=nil; deliver("PLAYER_GUILD_UPDATE","player"); drain(); deliver("GUILD_ROSTER_UPDATE",true); drain()
    no(N.Main.host.on,"name unknown"); eq(hostF(),0)
    guildName="Guild B"; deliver("GUILD_ROSTER_UPDATE",true); drain(); no(N.Main.host.on,"first readable name: its roster is asked for")
    deliver("GUILD_ROSTER_UPDATE",true); drain(); yes(N.Main.host.on)
    -- at login an unreadable name: hosting does not act until the name is readable (r040c 21e)
    N=loadAddon(); hReady(N); guildName=nil; N.Main.started=false; N.Main.start(); drain(); N.Main.guildSeen=nil
    no(N.Main.host.on); yes(N.Main.host.want); yes(logged("ON but inactive: your guild's name is not readable right now")); guildName="Test Guild"
    deliver("GUILD_ROSTER_UPDATE",true); drain(); yes(N.Main.host.on)
    -- known guild, then a roster while its name blinks: not counted, hosting inactive (r040c 21e), nothing dropped
    N=loadAddon(); hReady(N); local at=N.Adapters.roster.at; advance(5); guildName=nil; deliver("GUILD_ROSTER_UPDATE",true); drain()
    eq(N.Adapters.roster.at,at,"not counted"); no(N.Main.host.on,"inactive"); yes(N.Main.host.want); guildName="Test Guild"
    guildName="Test Guild"; deliver("PLAYER_GUILD_UPDATE","player"); deliver("GUILD_ROSTER_UPDATE",true); drain(); yes(N.Main.host.on)
end)
test("1f: a request held for the roster is dropped by a guild switch, even if the requester is in the new guild",function()
    local N=loadAddon(); establish(N); roster={{"Bob",true}}; deliver("GUILD_ROSTER_UPDATE",true); drain(); slash("host on"); sent={}
    advance(121); lsw("inv layer <LS 100 want 7086-0>","Bob"); eq(#invites,0); yes(N.Main.host.held)
    guildName="Guild B"; deliver("PLAYER_GUILD_UPDATE","player"); drain(); eq(N.Main.host.held,nil)
    deliver("GUILD_ROSTER_UPDATE",true); drain(); yes(N.Main.host.on); eq(#invites,0,"the old guild's request is not served")
    -- same with the switch noticed on the roster itself
    N=loadAddon(); establish(N); roster={{"Bob",true}}; deliver("GUILD_ROSTER_UPDATE",true); drain(); slash("host on")
    advance(121); lsw("inv layer <LS 100 want 7086-0>","Bob"); guildName="Guild B"; advance(1); deliver("GUILD_ROSTER_UPDATE",true); drain()
    deliver("GUILD_ROSTER_UPDATE",true); drain(); eq(#invites,0)
end)

-- مانع on ded1bee (r040c/e4c), through events
local function seeFoe(name,guid) units.target=player(name,"Horde",guid); deliver("PLAYER_TARGET_CHANGED"); drain() end
test("e4c: an enemy re-seen every second is reported 3 s after its first sighting",function()
    local N=loadAddon(); establish(N); advance(1)
    for i=1,9 do seeFoe("Kora Reed","Player-1-901"); advance(1) end
    eq(#oLines(),1,"reported while still being seen")
    -- an enemy that left view before settling starts again on its next sighting
    -- (r040c 21e: Share reads the row's own-sighting fields, ownAt and ownSource)
    local Sh=N.Share; local st=Sh.new(); local e={key="k",faction="opposite",zone=100,source="own target",at=0,ownSource="own target",ownAt=0}
    eq(Sh.pick(st,{k=e},1,100),nil); eq(Sh.pick(st,{k=e},20,100),nil,"gone")
    e.at=40; e.ownAt=40; eq(Sh.pick(st,{k=e},40,100),nil,"settles again"); yes(Sh.pick(st,{k=e},43,100)); yes(oLines()[1].text:find("^O|1|%d+|100|"),oLines()[1].text)
end)
test("e4c: only our own unit sightings are shared, never a Bulo copy (also not one refreshing our own row)",function()
    local N=loadAddon(); local b=fakeBulo("7086-7"); establish(N); advance(1)
    seeFoe("Kora Reed","Player-1-901"); units.target=nil; advance(10); eq(#oLines(),1)
    -- 61 s later Bulo reports the same player (keeps our classification): not ours to share
    advance(61); b.Radar.seen["Player-1-901"]={at=clock,hostile=true,src="target"}; N.Main.poll(); b.Radar.seen={}
    yes(N.Main.store.localSeen["Player-1-901"].source:find("^Bulo")); advance(10); eq(#oLines(),1,"Bulo copy not shared")
    -- a Bulo-only player, and reports received from guildmates or War Effort, are never shared as ours
    b.Radar.seen["Player-2-5"]={at=clock,hostile=true,src="target"}; N.Main.poll(); b.Radar.seen={}
    hello("Wes",19); report(3,8000,"Wes"); legw(N.Relay.ownLine({rid=9,zone=100,x=.2,y=.2,layer="7086",age=0,count=2,enemies={{name="Ann Lee"}}}),"Scout")
    advance(30); eq(#oLines(),1)
end)
test("e4c: an unknown or just-changed layer is sent as unknown, never a guessed key",function()
    local N=loadAddon(); establish(N); advance(1)
    deliver("SHARD_TRANSFER"); drain(); advance(1); eq(N.Main.store.bulo,nil,"layer not known again yet")
    seeFoe("Kora Reed","Player-1-901"); units.target=nil; advance(10)
    local o=oLines()[1]; yes(o,"sent anyway"); yes(o.text:find("^O|1|%d+|100|0.250|0.750||"),o.text)
    -- the receiver shows it as layer unknown
    local M=loadAddon(); establish(M); legw(o.text,"Scout"); local rows=M.Store.rows(M.Main.store,clock,"reported")
    eq(rows[1].record.layer.ns,"unknown")
    -- mixed servers sharing the zone (ambiguous): unknown too
    N=loadAddon(); establish(N); advance(1); N.Main.store.ambiguous=function() return true end
    seeFoe("Kora Reed","Player-1-901"); units.target=nil; advance(10); yes(oLines()[1].text:find("^O|1|%d+|100|0.250|0.750||"),oLines()[1].text)
end)

-- 1.0 lane A2: War Effort hello, Q, guild Q answers, Y answers from our own reports, K (off) to J
local function weGuild(t) local out={}; for _,m in ipairs(sent) do if m.prefix=="WEFF1" and m.kind=="GUILD" and (not t or m.text:sub(1,#t)==t) then out[#out+1]=m end end; return out end
local function weTo(who) local out={}; for _,m in ipairs(sent) do if m.prefix=="WEFF1" and m.kind=="WHISPER" and m.target==who then out[#out+1]=m end end; return out end
local function we(text,kind,from) deliver("CHAT_MSG_ADDON","WEFF1",text,kind or "GUILD",from or "Wes"); drain() end
local function weReady(N) netOn(N,"we"); units.player={name="Me",class="MAGE",level=60}; establish(N) end
local function steps(n) for _=1,n do advance(1) end end   -- (advance jumps the clock before due timers run)
test("1.0 A2: WeOut builds H, Q, K and sync-marked C; our decoder reads them back",function()
    local N=loadAddon(); local W,P=N.WeOut,N.Protocol
    local h=W.hello({map=100,layer=7086,class="MAGE",level=60,public=true,stamp=720100})
    eq(h,"H|"..W.VERSION.."|100|7086|1|19|0|0|"..(720100%3600).."||H|60|1")
    local d=P.decode(h); eq(d.type,"H"); eq(d.minor,19); eq(d.layer,7086); eq(d.map,100); eq(d.stamp,720100%3600)
    eq(W.hello({map=100,layer=nil,public=false,ambiguous=true,stamp=5}),"H|"..W.VERSION.."|100|0|1|19|0|0|5||-|0|0|0|1")
    eq(W.query(),"Q"); eq(W.joinOff(77,3605),"K|77|2|5")
    local c=W.cluster(9,100,.25,.75,7086,2,100,2,3); eq(c,"C|9|100|0.250|0.750|7086|2|100||2:3")
    local dc=P.decode(c); yes(dc.sync); eq(dc.rid,9)
    eq(P.decode("Q").type,"Q"); eq(P.decode("Q|x").type,"Q")
    local y=P.decode("Y|1||a:600"); eq(y.type,"Y"); eq(y.continent,1); eq(y.maxAge,600)
    eq(P.decode("Y|1").maxAge,900); eq(P.decode("Y|1||a:5").maxAge,60); eq(P.decode("Y|1||a:99999").maxAge,900); eq(P.decode("Y|x"),nil)
    local j=P.decode("J|5|100|7086|0.5|0.5|12"); eq(j.type,"J"); eq(j.id,5); eq(P.decode("J|0|100|7086|0.5|0.5"),nil); eq(P.decode("J|5|100|7086|0.5"),nil)
    -- Wire: on WHISPER only a sync-marked C, an E, or a K saying "off"
    local Wr=N.Wire; netOn(N,"we"); N.Net.setConsent("public")
    yes(Wr.send("WEFF1",c,"WHISPER","Bob",{net="we"})); yes(Wr.send("WEFF1","K|77|2|5","WHISPER","Bob",{net="we"}))
    for _,bad in ipairs({"C|9|100|0.250|0.750|7086|2|100","K|77|1|5","K|77|2|5|x","H|1","Q","C|9|100|0.250|0.750|7086|2|100||4:3"}) do
        local ok,why=Wr.send("WEFF1",bad,"WHISPER","Bob",{net="we"}); no(ok,bad); eq(why,"bad text") end
    local ok,why=Wr.send("WEFF1","Q|1","GUILD",nil,{net="we"}); no(ok); eq(why,"bad text","Q is bare")
end)
test("1.0 A2: hello at login and every 180 s to the guild; not in an instance; an identical one not within 30 s",function()
    local N=loadAddon(); weReady(N); advance(12)
    local h=weGuild("H|"); eq(#h,1,"login hello"); local d=N.Protocol.decode(h[1].text); eq(d.minor,19); eq(d.layer,7086); eq(d.map,100)
    advance(170); eq(#weGuild("H|"),1); advance(25); eq(#weGuild("H|"),2,"about 180 s later")
    -- a guild Q is answered with a hello at once (not again within 10 s); the timer then skips an identical one within 30 s
    -- (the next timer hello is due 180 to 190 s after the last one)
    local due=N.Main.we.helloDue; sent={}; steps(math.floor(due-clock)-5)
    we("Q"); eq(#weGuild("H|"),1,"Q answered"); we("Q","GUILD","Wesb"); eq(#weGuild("H|"),1,"one answer per 10 s")
    steps(10); eq(#weGuild("H|"),1,"the timer skips an identical hello within 30 s")
    steps(200); eq(#weGuild("H|"),2,"and sends the next")
    -- a Q on PARTY or from ourselves is not answered
    sent={}; grouped=true; we("Q","PARTY","Pam"); we("Q","GUILD","Me"); eq(#weGuild("H|"),0); grouped=false
    -- no hello in an instance; it goes once outside again
    N=loadAddon(); weReady(N); inInstance=true; advance(30); eq(#weGuild("H|"),0); inInstance=false; advance(6); eq(#weGuild("H|"),1)
    -- shipped off, switched off, War Effort loaded, not in a guild: nothing
    for _,c in ipairs({"ship","switch","loaded","guild"}) do
        N=loadAddon(); netOn(N,"we"); establish(N)
        if c=="ship" then N.Net.SHIP.we=false elseif c=="switch" then N.Net.setSwitch("we",false) elseif c=="loaded" then loaded.WarEffortScout=true else inGuild=false end
        advance(200); eq(#weGuild(),0,c); loaded.WarEffortScout=nil; inGuild=true
    end
end)
test("1.0 A2: a group with players outside the guild gets a hello too",function()
    local N=loadAddon(); weReady(N); roster={{"Bob-TestRealm",true}}; deliver("GUILD_ROSTER_UPDATE",true); drain()
    grouped=true; units.party1={name="Bob"}; advance(12)
    local function party() local n=0; for _,m in ipairs(sent) do if m.prefix=="WEFF1" and m.kind=="PARTY" then n=n+1 end end; return n end
    eq(party(),0,"only guildmates in the group"); units.party1={name="Stranger"}; steps(200); eq(party(),1)
end)
test("1.0 A2: Q once at login, to the guild",function()
    local N=loadAddon(); weReady(N); advance(16); eq(#weGuild("Q"),1); eq(weGuild("Q")[1].text,"Q"); advance(1200); eq(#weGuild("Q"),1)
    N=loadAddon(); inGuild=false; weReady(N); advance(30); eq(#weGuild("Q"),0)
end)
test("1.0 A2: a guild Y is answered by whisper from our own last three reports, slowly, once per 600 s",function()
    local N=loadAddon(); weReady(N); roster={{"Wes-TestRealm",true},{"Wesb-TestRealm",true},{"Wesc-TestRealm",true},{"Wesd-TestRealm",true},{"Wese-TestRealm",true}}
    deliver("GUILD_ROSTER_UPDATE",true); drain()
    -- a report before any War Effort reader was heard: not sent to War Effort, so never in an answer
    foe(N,1,{key="Player-1-701",name="Ee Ff"}); foe(N,2,{key="Player-1-702",name="Gg Hh"}); steps(20); eq(#weSent("C"),0)
    hello("Wes",19)
    -- a report the client refused (throttled) is not kept either
    sendResult=3; foe(N,1,{key="Player-1-703",name="Ii Jj"}); foe(N,2,{key="Player-1-704",name="Kk Ll"}); steps(20); sendResult=0
    we("Y|1","GUILD","Wese"); steps(100); eq(#weTo("Wese"),0,"unsent reports are not ours to answer with")
    advance(20)
    -- four reports of our own, each with two new enemies; a received report too
    for i=0,3 do units.target=nil; foe(N,1,{key="Player-1-8"..i.."1",name="Aa Bb"..string.char(97+i)}); foe(N,2,{key="Player-1-8"..i.."2",name="Cc Dd"..string.char(97+i)}); steps(20) end
    report(9,9000,"Scout")
    local mine=weSent("C"); yes(#mine>=4,#mine)
    sent={}; N.WeNet.rand=function() return .5 end; WorldMapFrame={IsShown=function() return true end}   -- (2 s heartbeat)
    we("Y|1||a:900"); steps(25); eq(#weTo("Wes"),0,"a random start, here 30 s")
    local times={}; for _=1,100 do advance(1); local n=#weTo("Wes"); if n>#times then times[#times+1]=clock end end
    WorldMapFrame=nil
    for i=2,#times do yes(times[i]-times[i-1]>=4.9,"paced "..(times[i]-times[i-1])) end
    local out=weTo("Wes"); local cs={}
    for _,m in ipairs(out) do if m.text:sub(1,2)=="C|" then cs[#cs+1]=m.text end end
    eq(#cs,3,"three reports"); for i,c in ipairs(cs) do yes(c:find("|"..i..":3$"),c); no(c:find("^C|9|"),"never a received report") end
    eq(#out,6,"each C followed by its E")
    -- the asked age is kept: our reports are older than 60 s now
    we("Y|1||a:60","GUILD","Wesd"); steps(120); eq(#weTo("Wesd"),0,"all older than the asked age")
    N.WeNet.rand=nil
    -- paced: never two within 5 s
    -- (the heartbeat sends one per tick)
    advance(100); we("Y|1||a:900"); advance(120); eq(#weTo("Wes"),6,"once per 600 s")
    -- another continent, a too-short age, a Y on PARTY, a Y from ourselves: nothing
    sent={}; we("Y|999","GUILD","Wesb"); grouped=true; we("Y|1","PARTY","Pam"); grouped=false; we("Y|1","GUILD","Me"); advance(120)
    eq(#weTo("Wesb"),0); eq(#weTo("Pam"),0); eq(#weTo("Me"),0)
    advance(500); we("Y|1||a:60","GUILD","Wesc"); advance(120); eq(#weTo("Wesc"),0,"all older than the asked age")
end)
test("1.0 A2: WeNet: a report that grows older than the asked age while queued is skipped",function()
    local N=loadAddon(); local Wn=N.WeNet; local st=Wn.new(0); local cont=function() return 1 end
    Wn.keep(st,{rid=1,t=100,server=1000,map=100,x=.5,y=.5,layer=0,count=2,enemies={{hash="abc"}}})
    yes(Wn.request(st,"Wes",1,60,130,cont,function() return 1 end))           -- 30 s old when asked, starts at 190
    eq(Wn.nextAnswer(st,189),nil); eq(Wn.nextAnswer(st,190),nil,"90 s old by then: skipped")
    st=Wn.new(0); Wn.keep(st,{rid=1,t=100,server=1000,map=100,x=.5,y=.5,layer=0,count=2,enemies={{hash="abc"}}})
    yes(Wn.request(st,"Wes",1,60,130,cont,function() return .2 end)); local who,c=Wn.nextAnswer(st,142); eq(who,"Wes"); yes(c:find("|1:1$"))
end)
test("1.0 A2: a J gets one K saying off (status 2) per 60 s, by whisper, and never an invite",function()
    local N=loadAddon(); weReady(N); N.Net.setConsent("public"); advance(1)
    we("J|5|100|7086|0.5|0.5|"..math.floor(server)%3600,"WHISPER","Stranger")
    local k=weTo("Stranger"); eq(#k,1); yes(k[1].text:find("^K|5|2|%d+$"),k[1].text)
    we("J|6|100|7086|0.5|0.5","WHISPER","Stranger"); eq(#weTo("Stranger"),1,"one per 60 s")
    advance(61); we("J|7|100|7086|0.5|0.5","WHISPER","Stranger"); eq(#weTo("Stranger"),2)
    eq(#invites,0)
    -- a malformed J, a J on GUILD, and anything else by whisper: nothing
    we("J|x","WHISPER","Other"); we("J|8|100|7086|0.5|0.5","GUILD","Other"); we("C|1|100|0|0|7|1|1","WHISPER","Other"); eq(#weTo("Other"),0)
    -- guild-only consent: a stranger's J gets no answer (public whisper)
    N=loadAddon(); weReady(N); N.Net.setConsent("guild"); advance(1); we("J|5|100|7086|0.5|0.5","WHISPER","Stranger"); eq(#weTo("Stranger"),0)
end)

-- 1.0 lane A3: War Effort embassy (P presence, partners, elections, D links, W out, W in as G)
local WECH="WarEfforttestrealmA"
local function embReady(N,members)
    netOn(N,"we"); N.Net.setConsent("public"); units.player={name="Me",class="MAGE",level=60}
    C_Club={GetGuildClubId=function() return 789 end}
    roster={{"Wes-TestRealm",true},{"Bob-TestRealm",true}}; chanMembers[WECH]=members
    establish(N); deliver("GUILD_ROSTER_UPDATE",true); drain()
end
local function wh(t,who) local out={}; for _,m in ipairs(sent) do if m.prefix=="WEFF1" and m.kind=="WHISPER" and (not who or m.target==who) and m.text:sub(1,#t)==t then out[#out+1]=m end end; return out end
local function gHello(who,public) deliver("CHAT_MSG_ADDON","WEFF1","H|1.6.6|100|7086|1|19|0|0|"..math.floor(server)%3600 .."|789|H|60|"..(public and "1" or "0"),"GUILD",who); drain() end
test("1.0 A3: the election score is War Effort's (DJB2, highest wins, lower name on ties)",function()
    local N=loadAddon(); local E=N.WeEmb
    eq(E.score("me","greet|kora reed"),52895520); eq(E.score("wes","greet|kora reed"),582354751)
    eq(E.score("me","fwd|g456"),1818921933); eq(E.score("wes","fwd|g456"),887266629)
    eq(E.score("kora reed","pair|g456"),1166973082); eq(E.score("ann lee","pair|g456"),2027833503)
    no(E.first("me",{"Wes"},"greet|kora reed")); yes(E.first("me",{"Wes"},"greet|ann lee")); yes(E.first("me",{},"x"))
    yes(E.first("me",{"Wes"},"fwd|g456")); yes(E.first("me",{"me"},"x"),"ourselves are skipped")
    -- P, W, D read and built as War Effort's
    local P=N.Protocol
    local p=P.decode("P|19|789|0|"); eq(p.type,"P"); eq(p.minor,19); eq(p.guild,"789"); eq(p.ask,false)
    eq(P.decode("P|19|-|0|a").guild,false); eq(P.decode("P|19|-|0|a").ask,true); eq(P.decode("P|19|x|0|"),nil); eq(P.decode("P|19|789"),nil)
    eq(N.WeOut.presence("789",false),"P|19|789|0|"); eq(N.WeOut.presence(nil,true),"P|19|-|0|a")
    local d=P.decode("D|g456,n4b6f7261"); eq(#d.links,2); eq(d.links[1],"g456"); eq(#P.decode("D|").links,0); eq(P.decode("D|g1,g2,g3,g4"),nil); eq(P.decode("D|x9"),nil)
    eq(N.WeOut.links({"g456"}),"D|g456"); eq(N.WeOut.links({}),"D|")
    local w=P.decode("W|"..hx("Kora Reed").."||C|5|100|0.4|0.5|7086|2|100"); eq(w.type,"W"); eq(w.origin,"Kora Reed"); eq(w.inner.type,"C")
    eq(P.decode("W|"..hx("Kora Reed").."||C|5|100|0.4|0.5|7086|2|100||1:1"),nil,"a sync answer never travels wrapped")
    eq(N.WeOut.wrap("W","Kora Reed",nil,"C|5|100|0.4|0.5|7086|2|100"),"W|"..hx("Kora Reed").."||C|5|100|0.4|0.5|7086|2|100")
end)
test("1.0 A3: the embassy stays off with a reason; an empty or missing member list greets nobody",function()
    local N=loadAddon(); embReady(N,nil); steps(300); eq(#wh("P|"),0,"no member list")
    N=loadAddon(); embReady(N,{}); steps(300); eq(#wh("P|"),0,"an empty list")
    eq(N.Main.embassyWhy(),nil,"(otherwise on)")
    -- guild-only consent, no guild, no guild id, an all-digit realm (no War Effort channel)
    N=loadAddon(); embReady(N,{"Ann Lee"}); N.Net.setConsent("guild"); eq(N.Main.embassyWhy(),"public networks are off"); steps(120); eq(#wh("P|"),0)
    N=loadAddon(); embReady(N,{"Ann Lee"}); C_Club=nil; eq(N.Main.embassyWhy(),"your guild's id is not readable"); steps(120); eq(#wh("P|"),0)
    N=loadAddon(); embReady(N,{"Ann Lee"}); inGuild=false; eq(N.Main.embassyWhy(),"not in a guild"); inGuild=true
    N=loadAddon(); embReady(N,{"Ann Lee"}); GetRealmName=function() return "7102" end; GetNormalizedRealmName=function() return "7102" end
    eq(N.Main.embassyWhy(),"no War Effort channel on this realm (all-digit realm name)"); steps(120); eq(#wh("P|"),0)
    log={}; SlashCmdList.LAYERENEMIES("status"); yes(logged("War Effort embassy: off (no War Effort channel on this realm (all-digit realm name))"))
    N=loadAddon(); embReady(N,{"Ann Lee"}); log={}; SlashCmdList.LAYERENEMIES("status"); yes(logged("War Effort embassy: on"))
end)
test("1.0 A3: we greet only our share, one a minute; an answer makes a partner; no answer leaves them alone 1800 s",function()
    local N=loadAddon(); embReady(N,{"Kora Reed","Ann Lee","Bo Dyl","Wes"}); gHello("Wes",true)
    local tg; for _=1,40 do advance(1); if not tg and #wh("P|")>0 then tg=clock end end
    local p=wh("P|"); eq(#p,1); eq(p[1].text,"P|19|789|0|a"); yes(p[1].target=="Ann Lee" or p[1].target=="Bo Dyl",p[1].target)
    local first=p[1].target; eq(#wh("P|","Kora Reed"),0,"Kora Reed is Wes's share"); eq(#wh("P|","Wes"),0,"never a guildmate")
    while clock<tg+59 do advance(1) end; eq(#wh("P|"),1,"one greeting a minute at most")
    local t1=clock; deliver("CHAT_MSG_ADDON","WEFF1","P|19|456|0|","WHISPER",first); drain(); yes(N.WeEmb.partner(N.Main.emb,first,clock))
    steps(100); local other=first=="Ann Lee" and "Bo Dyl" or "Ann Lee"; eq(#wh("P|",other),1,"the next of our share")
    steps(40); no(N.WeEmb.partner(N.Main.emb,other,clock)); steps(1700); eq(#wh("P|"..""..""),#wh("P|"),"(count)")
    -- the unanswered one is left alone: not greeted again for 1800 s
    eq(#wh("P|19|789|0|a",other),1)
end)
test("1.0 A3: a greeting is answered at most 6 times a minute over all players; a guildmate's P makes no partner",function()
    local N=loadAddon(); embReady(N,{}); advance(1)
    for i=1,8 do deliver("CHAT_MSG_ADDON","WEFF1","P|19|456|0|a","WHISPER","Strang"..abc(i)); drain() end
    steps(5); eq(#wh("P|19|789|0|"),6,"6 replies a minute"); eq(#wh("P|","Strangg"),0)
    for i=1,8 do yes(N.WeEmb.partner(N.Main.emb,"Strang"..abc(i),clock)) end
    steps(61); deliver("CHAT_MSG_ADDON","WEFF1","P|19|456|0|a","WHISPER","Strangx"); drain(); steps(3); eq(#wh("P|","Strangx"),1)
    eq(#wh("P|","Strangg"),0,"(the partner we hold gets keepalives; Strangg is not it)")
    deliver("CHAT_MSG_ADDON","WEFF1","P|19|789|0|a","WHISPER","Gilda"); drain(); no(N.WeEmb.partner(N.Main.emb,"Gilda",clock),"our guild's id")
    deliver("CHAT_MSG_ADDON","WEFF1","P|18|456|0|a","WHISPER","Olda"); drain(); no(N.WeEmb.partner(N.Main.emb,"Olda",clock),"minor 18")
end)
test("1.0 A3: D lists only links we serve; withdrawn with D| when public networks go off",function()
    local N=loadAddon(); embReady(N,{}); advance(1); eq(#weGuild("D|"),0,"nothing held, nothing said")
    deliver("CHAT_MSG_ADDON","WEFF1","P|19|456|0|a","WHISPER","Ann Lee"); drain(); steps(25)
    local d=weGuild("D|"); eq(#d,1); eq(d[1].text,"D|g456")
    local function annP() deliver("CHAT_MSG_ADDON","WEFF1","P|19|456|0|","WHISPER","Ann Lee"); drain() end
    steps(130); eq(#weGuild("D|"),1,"unchanged: again only after 600 s"); annP(); steps(240); annP(); steps(240); annP(); eq(#weGuild("D|"),2)
    eq(weGuild("D|")[2].text,"D|g456","repeated while held")
    N.Net.setConsent("guild"); steps(130); local d2=weGuild("D|"); eq(d2[#d2].text,"D|","withdrawn although the partner is alive")
    steps(700); eq(weGuild("D|")[#weGuild("D|")].text,"D|"); local n=#weGuild("D|"); steps(700); eq(#weGuild("D|"),n,"said once")
end)
test("1.0 A3: forwarding: a guildmate's own report only if their hello said public; ours; H once per 600 s; never a wrapped one",function()
    local N=loadAddon(); embReady(N,{}); advance(1)
    local function from(who) local n=0; for _,m in ipairs(wh("W|","Ann Lee")) do local d=N.Protocol.decode(m.text); if d and d.origin==who then n=n+1 end end; return n end
    deliver("CHAT_MSG_ADDON","WEFF1","P|19|456|0|a","WHISPER","Ann Lee"); drain(); steps(25)
    local st=math.floor(server)%3600
    gHello("Wes",true); gHello("Bob",false)
    steps(3); eq(from("Wes"),1,"Wes's hello forwarded")
    deliver("CHAT_MSG_ADDON","WEFF1","C|5|100|0.4|0.5|7086|2|"..st,"GUILD","Wes"); deliver("CHAT_MSG_ADDON","WEFF1","E|5|1|1|abc:H:60|"..st,"GUILD","Wes"); drain(); steps(61)
    eq(from("Wes"),3,"C and its first E (Wire's 4 public whispers a minute to one player: the E waits in the queue)")
    deliver("CHAT_MSG_ADDON","WEFF1","E|5|1|1|abd:H:60|"..st,"GUILD","Wes"); drain(); eq(from("Wes"),3,"only the first E")
    deliver("CHAT_MSG_ADDON","WEFF1","C|6|100|0.4|0.5|7086|2|"..st,"GUILD","Bob"); drain(); eq(from("Bob"),0,"Bob said public 0")
    deliver("CHAT_MSG_ADDON","WEFF1","C|7|100|0.4|0.5|7086|2|"..st,"GUILD","Cyd"); drain(); steps(5); eq(from("Cyd"),0,"no hello heard: unknown")
    local raw=#wh("W|","Ann Lee"); deliver("CHAT_MSG_ADDON","WEFF1",VG,"GUILD","Wes"); drain(); steps(61); eq(#wh("W|","Ann Lee"),raw,"never a G")
    gHello("Wes",true); eq(from("Wes"),3,"a hello once per 600 s")
    -- our own report goes too
    hello("Wes",19); foe(N,1); foe(N,2); steps(20); local ws=wh("W|","Ann Lee"); local mine=0
    for _,m in ipairs(ws) do local d=N.Protocol.decode(m.text); if d and d.origin=="Me" and d.inner.type~="H" then mine=mine+1 end end; eq(mine,2,"our C and E")
end)
test("1.0 A3: only the top-scored holder of a guild forwards to it",function()
    local N=loadAddon(); embReady(N,{}); advance(1)
    deliver("CHAT_MSG_ADDON","WEFF1","P|19|457|0|a","WHISPER","Ann Lee"); drain(); steps(25)
    gHello("Wes",true); deliver("CHAT_MSG_ADDON","WEFF1","D|g457","GUILD","Wes"); drain()
    local st=math.floor(server)%3600; local n=#wh("W|")
    deliver("CHAT_MSG_ADDON","WEFF1","C|5|100|0.4|0.5|7086|2|"..st,"GUILD","Bob"); gHello("Bob",true)
    deliver("CHAT_MSG_ADDON","WEFF1","C|8|100|0.4|0.5|7086|2|"..st,"GUILD","Bob"); drain()
    yes(#wh("W|")>n,"we rank first for g457 (1824785540 > 1080776665)")
    -- g450: Wes ranks first (1873690060 > 1783740291): we hold it but stand by
    N=loadAddon(); embReady(N,{}); advance(1)
    deliver("CHAT_MSG_ADDON","WEFF1","P|19|450|0|a","WHISPER","Ann Lee"); drain(); steps(25)
    gHello("Wes",true); gHello("Bob",true); deliver("CHAT_MSG_ADDON","WEFF1","D|g450","GUILD","Wes"); drain(); steps(61); n=#wh("W|")
    deliver("CHAT_MSG_ADDON","WEFF1","C|9|100|0.4|0.5|7086|2|"..math.floor(server)%3600,"GUILD","Bob"); drain(); steps(61); eq(#wh("W|"),n,"Wes forwards to g450, not us")
end)
test("1.0 A3: a W from a live partner of another guild goes into the guild as G and is stored as relayed; from others it is dropped",function()
    local N=loadAddon(); embReady(N,{}); advance(1)
    deliver("CHAT_MSG_ADDON","WEFF1","P|19|456|0|a","WHISPER","Ann Lee"); drain(); hello("Kora Reed",19,"WHISPER")
    local st=math.floor(server)%3600; local inner="C|5|100|0.4|0.5|7086|2|"..st
    deliver("CHAT_MSG_ADDON","WEFF1","W|"..hx("Kora Reed").."||"..inner,"WHISPER","Ann Lee"); drain()
    local g=weGuild("G|"); eq(#g,1); eq(g[1].text,"G|"..hx("Kora Reed").."||"..inner)
    local rows=N.Store.rows(N.Main.store,clock,"reported"); eq(#rows,1); eq(rows[1].record.hand,"relayed"); eq(rows[1].record.share,"public")
    -- the same report again: not bridged twice; a W from a stranger or a guildmate: dropped
    deliver("CHAT_MSG_ADDON","WEFF1","W|"..hx("Kora Reed").."||"..inner,"WHISPER","Ann Lee"); drain(); eq(#weGuild("G|"),1)
    deliver("CHAT_MSG_ADDON","WEFF1","W|"..hx("Kora Reed").."||C|6|100|0.4|0.5|7086|2|"..st,"WHISPER","Stranger"); drain(); eq(#weGuild("G|"),1)
    deliver("CHAT_MSG_ADDON","WEFF1","W|"..hx("Kora Reed").."||C|7|100|0.4|0.5|7086|2|"..st,"WHISPER","Wes"); drain(); eq(#weGuild("G|"),1)
    -- a W naming ourselves, or naming its own sender, is refused; at most 10 bridged sightings a minute
    deliver("CHAT_MSG_ADDON","WEFF1","W|"..hx("Me").."||C|8|100|0.4|0.5|7086|2|"..st,"WHISPER","Ann Lee"); drain(); steps(5); eq(#weGuild("G|"),1,"naming us")
    for i=1,12 do deliver("CHAT_MSG_ADDON","WEFF1","W|"..hx("Scout"..abc(i)).."||C|9|100|0.4|0.5|7086|2|"..st,"WHISPER","Ann Lee"); drain() end
    steps(40); eq(#weGuild("G|"),10,"10 a minute (the first included)")
    -- a W we got is never forwarded to another partner
    eq(#wh("W|"),0)
    -- a partner gone quiet (no presence for 600 s) is no partner
    N=loadAddon(); embReady(N,{}); advance(1); deliver("CHAT_MSG_ADDON","WEFF1","P|19|456|0|a","WHISPER","Ann Lee"); drain(); steps(605)
    deliver("CHAT_MSG_ADDON","WEFF1","W|"..hx("Kora Reed").."||C|5|100|0.4|0.5|7086|2|"..math.floor(server)%3600,"WHISPER","Ann Lee"); drain(); steps(5)
    eq(#weGuild("G|"),0,"expired partner")
end)

-- 1.0 lane B: HeadHunter mesh (B1) and catch-up (B2)
local function hhReady(N,members)
    netOn(N,"hh"); N.Net.setConsent("public"); units.player={name="Me",class="MAGE",level=60,guid="Player-7091-00000001"}
    GetCurrentRegion=function() return 3 end; chanMembers.HeadHunterSync=members; establish(N); server=HHT
end
local function hw(t,who) local out={}; for _,m in ipairs(sent) do if m.prefix=="HeadHunter" and m.kind=="WHISPER" and (not who or m.target==who) and m.text:sub(1,#t)==t then out[#out+1]=m end end; return out end
local function hhIn(text,from) deliver("CHAT_MSG_ADDON","HeadHunter",text,"WHISPER",from); drain() end
local function env(author,hops,t,inner,world,f) return "1AE:"..(world or "eu-pvp")..";"..author..";"..(f or "A")..";5cy;"..b36(hops)..";"..b36(t or HHT)..";"..inner end
test("1.0 B1: hello is exactly LayerEnemies, once per peer per session, one per tick at most; an N is answered once",function()
    local N=loadAddon(); hhReady(N,{"Peer One","Peer Two","Peer Three","Me"}); steps(30)
    local h=hw("1AN:"); eq(#h,3); for _,m in ipairs(h) do eq(m.text,"1AN:LayerEnemies") end
    local seen={}; for _,m in ipairs(h) do no(seen[m.target],m.target); seen[m.target]=true end; no(seen.Me,"never ourselves")
    steps(600); eq(#hw("1AN:"),3,"once per peer per session")
    -- paced: never two hellos in the same 2 s
    local times={}; N=loadAddon(); hhReady(N,{"Ann Lee","Bo Dyl","Cy Fen","Di Gar"}); for _=1,40 do advance(1); times[#times+1]=#hw("1AN:") end
    for i=3,#times do yes(times[i]-times[i-2]<=1,"one per 2 s") end
    -- an N from a new peer gets ours once
    N=loadAddon(); hhReady(N,{}); advance(1); hhIn("1AN:HeadHunter 1.1.1","Kora Reed"); eq(#hw("1AN:","Kora Reed"),1)
    hhIn("1AN:HeadHunter 1.1.1","Kora Reed"); steps(10); eq(#hw("1AN:","Kora Reed"),1)
end)
test("1.0 B1: an envelope is forwarded unchanged but its hops, to peers that are neither author nor carrier",function()
    local N=loadAddon(); hhReady(N,{"Peer One","Peer Two","Peer Three","Peer Four","Peer Five","Mira Vale","Sera Dawn"}); steps(30); sent={}
    local e=env("Mira Vale",1,HHT,"LKora Reed;13k;"..b36(HHT)..";dw;6y")
    hhIn(e,"Mira Vale"); steps(5)
    local f=hw("1AE:"); yes(#f>=1 and #f<=4,#f)
    for _,m in ipairs(f) do eq(m.text,env("Mira Vale",2,HHT,"LKora Reed;13k;"..b36(HHT)..";dw;6y")); yes(m.target~="Mira Vale" and m.target~="Me") end
    -- the same envelope again (another carrier): not forwarded again
    local n=#hw("1AE:"); hhIn(env("Mira Vale",2,HHT,"LKora Reed;13k;"..b36(HHT)..";dw;6y"),"Sera Dawn"); steps(5); eq(#hw("1AE:"),n)
    -- a carried one: never back to its carrier or author
    sent={}; hhIn(env("Mira Vale",3,HHT,"DKora Reed;x"),"Sera Dawn"); steps(5)
    for _,m in ipairs(hw("1AE:")) do yes(m.target~="Sera Dawn" and m.target~="Mira Vale",m.target); yes(m.text:find(";4;",1,true)) end
end)
test("1.0 B1: hops 5, too old, from the future, another world, our own, author-carried after hop 1, T: not forwarded",function()
    local N=loadAddon(); hhReady(N,{"Peer One","Peer Two","Peer Three","Mira Vale","Sera Dawn"}); steps(30); sent={}
    local L="LKora Reed;13k;"..b36(HHT)..";dw;6y"
    hhIn(env("Mira Vale",5,HHT,L),"Sera Dawn"); hhIn(env("Mira Vale",6,HHT,"DAa Bb;1"),"Sera Dawn")
    hhIn(env("Mira Vale",1,server-601,"DAa Bb;2"),"Mira Vale"); hhIn(env("Mira Vale",1,server+301,"DAa Bb;3"),"Mira Vale")
    hhIn(env("Mira Vale",1,HHT,"DAa Bb;4","us-pvp"),"Mira Vale"); hhIn(env("Me",1,HHT,"DAa Bb;5"),"Sera Dawn")
    hhIn(env("Mira Vale",2,HHT,"DAa Bb;6"),"Mira Vale"); hhIn(env("Mira Vale",1,HHT,"Thello"),"Mira Vale")
    hhIn(env("Mira Vale",1,HHT,"Fx;y","eu-pvp","H"),"Mira Vale")
    steps(5); eq(#hw("1AE:"),0)
    eq(N.HhNet.held(N.Main.hhNet),0,"none of them stored for catch-up")
    -- (another author and carrier: Mira Vale has used up her 6 frames in 10 s)
    hhIn(env("Kora Reed",1,server,"DAa Bb;7","eu-?"),"Kora Reed"); steps(5); yes(#hw("1AE:")>=1,"a world part unknown on one side does not split it")
end)
test("1.0 B1: the duplicate ring holds 4000 keys",function()
    local N=loadAddon(); local HN=N.HhNet; local st=HN.new()
    for i=1,4000 do HN.remember(st,"k"..i) end; yes(HN.seen(st,"k1")); HN.remember(st,"k4001"); no(HN.seen(st,"k1")); yes(HN.seen(st,"k2")); yes(HN.seen(st,"k4001"))
    eq(HN.key("Mira Vale","L","x"),"miravaleL"..(N.HhNet.hash("x")))
    eq(HN.hash("abc"),193485963); eq(HN.compact("Mira Vale-7102"),"miravale")
    -- offers are collected 5 s from the first one
    st=HN.new(); st.asked=0; local ctx={side="A",serverNow=HHT}
    HN.offer(st,"Peer One","3",1); eq(#HN.pull(st,3,ctx),0); eq(#HN.pull(st,5.9,ctx),0); local p=HN.pull(st,6,ctx); eq(p[1].target,"Peer One")
end)
test("1.0 B2: catch-up: Q:h after login, offers collected, pulled from one, S taken only from that sender",function()
    local N=loadAddon(); hhReady(N,{"Peer One","Peer Two","Peer Three"}); steps(25)
    local q=hw("1AQ:h"); yes(#q>=1 and #q<=6,#q)
    hhIn("1AO:3","Peer One"); steps(3); eq(#hw("1AQ:p"),0,"collecting for 5 s"); hhIn("1AO:5","Peer Two"); steps(4)
    local p=hw("1AQ:p"); eq(#p,1); eq(p[1].target,"Peer Two","the biggest offer")
    hhIn("1AS:DAa Bb;1~KCc;2","Peer One"); eq(N.HhNet.held(N.Main.hhNet),0,"not the pulled sender")
    hhIn("1AS:DAa Bb;1~KCc;2","Peer Two"); hhIn("1AS:E2","Peer Two"); eq(N.HhNet.held(N.Main.hhNet),2)
    hhIn("1AS:DDd;3","Peer Two"); eq(N.HhNet.held(N.Main.hhNet),2,"after its end marker")
end)
test("1.0 B2: serving: no O with an empty store; O counts what a pull then sends, byte-equal; E0; once per requester per 300 s",function()
    local N=loadAddon(); hhReady(N,{}); steps(25); N.HhNet.chance=function() return 1 end
    hhIn("1AQ:h"..b36(HHT-600),"Asker One"); steps(5); eq(#hw("1AO:"),0,"empty store: no offer")
    hhIn("1AQ:p"..b36(HHT-600),"Asker One"); steps(5); local e=hw("1AS:","Asker One"); eq(#e,1); eq(e[1].text,"1AS:E0")
    -- records carried in envelopes are held and served byte for byte
    hhIn(env("Mira Vale",1,server,"DAa Bb;1;x"),"Mira Vale"); hhIn(env("Sera Dawn",1,server,"KCc Dd;2"),"Sera Dawn"); hhIn(env("Sera Dawn",1,server,"LKora Reed;13k;"..b36(server)..";dw;6y"),"Sera Dawn")
    eq(N.HhNet.held(N.Main.hhNet),2,"D and K are history; L is not")
    hhIn("1AQ:h"..b36(HHT-600),"Asker Two"); steps(5); local o=hw("1AO:","Asker Two"); eq(#o,1); eq(o[1].text,"1AO:2")
    hhIn("1AQ:p"..b36(HHT-600),"Asker Two"); steps(5)
    local body={}; for _,m in ipairs(hw("1AS:","Asker Two")) do body[#body+1]=m.text:sub(5) end
    local all=table.concat(body,"~"); yes(all:find("DAa Bb;1;x",1,true)); yes(all:find("KCc Dd;2",1,true)); yes(all:find("E2$"),all)
    local n=#hw("1AS:","Asker Two"); hhIn("1AQ:p"..b36(HHT-600),"Asker Two"); steps(5); eq(#hw("1AS:","Asker Two"),n,"once per 300 s")
    -- Q:h answered at most once per requester per 300 s too
    hhIn("1AQ:h"..b36(HHT-600),"Asker Three"); hhIn("1AQ:h"..b36(HHT-600),"Asker Three"); steps(5); eq(#hw("1AO:","Asker Three"),1)
end)
test("1.0 B2: a link H is answered with our home server, once per 600 s",function()
    local N=loadAddon(); hhReady(N,{}); advance(1)
    hhIn("1AH:5cy","Kora Reed"); local h=hw("1AH:","Kora Reed"); eq(#h,1); eq(h[1].text,"1AH:"..b36(7091))
    hhIn("1AH:5cy","Kora Reed"); steps(10); eq(#hw("1AH:","Kora Reed"),1)
end)
test("1.0 B: off, guild-only, HeadHunter loaded or in an instance: nothing on HeadHunter",function()
    for _,c in ipairs({"ship","consent","loaded","instance"}) do
        local N=loadAddon(); hhReady(N,{"Peer One"})
        if c=="ship" then N.Net.SHIP.hh=false elseif c=="consent" then N.Net.setConsent("guild") elseif c=="loaded" then loaded.HeadHunter=true else inInstance=true end
        hhIn("1AN:HeadHunter 1.1.1","Kora Reed"); steps(40); eq(#hw(""),0,c); loaded.HeadHunter=nil; inInstance=false
    end
end)

-- 1.0 lane C1: the Spy family in ([Spy], ForeverSpy1, FSENT03), receive only
local function spyRows(N,src) local out={}; for _,r in ipairs(N.Store.rows(N.Main.store,clock,"reported")) do if r.record.src==src then out[#out+1]=r end end; return out end
local function spyIn(prefix,text,kind,from) deliver("CHAT_MSG_ADDON",prefix,text,kind,from); drain() end
test("1.0 C1: a [Spy] line: the enemy as First Last, observer position, map to zone, class and level checked",function()
    local N=loadAddon(); establish(N)
    spyIn("[Spy]","1.3.8|Kora-Reed|ROGUE|60|Orc|Ashenvale||0.42|0.61|Some Guild|101","GUILD","Spyuser")
    local rows=spyRows(N,"spy"); eq(#rows,1); local r=rows[1].record
    eq(r.kind,"seen"); eq(r.origin,"Spyuser"); eq(r.hand,"first"); eq(r.at,clock,"Spy carries no age: heard now"); eq(r.zone,100); eq(r.pos,"observer"); eq(r.x,.42); eq(r.y,.61)
    eq(r.enemies[1].name,"Kora Reed"); eq(r.enemies[1].class,"ROGUE"); eq(r.enemies[1].level,60); eq(r.count,1)
    eq(rows[1].positionKind,"observer's position"); eq(rows[1].source,"seen (Spy)"); eq(r.layer.ns,"unknown")
    -- numeric realm kept, our own stripped; one word alone; no coordinates
    spyIn("[Spy]","1.3.8|Ann-Lee-7103|MAGE||Human|Ashenvale|||||100","PARTY","Spyuser")
    spyIn("[Spy]","1.3.8|Bo-Dyl-7102|||||||||100","RAID","Spyuser")
    spyIn("[Spy]","1.3.8|Cyra|||||||||100","GUILD","Spyuser")
    local names={}; for _,row in ipairs(spyRows(N,"spy")) do names[row.record.enemies[1].name]=row.record end
    yes(names["Ann Lee-7103"]); eq(names["Ann Lee-7103"].pos,"none"); eq(names["Ann Lee-7103"].enemies[1].level,nil); yes(names["Bo Dyl-7102"]); eq(N.Invite.key("Bo Dyl-7102"),"bo dyl","our realm folds away in the key"); yes(names["Cyra"])
end)
test("1.0 C1: [Spy] refusals: multi-part, field count, class, level, coordinates, guild, name, map, route, own",function()
    local N=loadAddon(); establish(N)
    local bad={"\0011.3.8|Kora-Reed|ROGUE|60|Orc|Ashenvale||0.4|0.6||100","\0021.3.8|x","\0031.3.8|x",
        "1.3.8|Kora-Reed|ROGUE|60|Orc|Ashenvale||0.4|0.6|","1.3.8|Kora-Reed|ROGUE|60|Orc|Ashenvale||0.4|0.6||100|x",
        "1.3.8|Kora-Reed|BADCLASS|60|Orc|Ashenvale||0.4|0.6||100","1.3.8|Kora-Reed|ROGUE|0|Orc|Ashenvale||0.4|0.6||100",
        "1.3.8|Kora-Reed|ROGUE|61.5|Orc|Ashenvale||0.4|0.6||100","1.3.8|Kora-Reed|ROGUE|101|Orc|Ashenvale||0.4|0.6||100",
        "1.3.8|Kora-Reed|ROGUE|60|Orc|Ashenvale||1.5|0.6||100","1.3.8|Kora-Reed|ROGUE|60|Orc|Ashenvale||0.4|||100",
        "1.3.8|Kora-Reed|ROGUE|60|Orc|Ashenvale||0.4|0.6|"..string.rep("g",25).."|100",
        "1.3.8|Kora2-Reed|ROGUE|60|Orc|Ashenvale||0.4|0.6||100","1.3.8|Kora-Reed-Lee|ROGUE|60|Orc|Ashenvale||0.4|0.6||100",
        "1.3.8|Kora Reed|ROGUE|60|Orc|Ashenvale||0.4|0.6||100x","1.3.8||ROGUE|60|Orc|Ashenvale||0.4|0.6||100",
        "1.3.8|Kora-Reed|ROGUE|60|Orc|Ashenvale||0.4|0.6||","1.3.8|Kora-Reed|ROGUE|60|Orc|Ashenvale||0.4|0.6||5"}
    for i,t in ipairs(bad) do spyIn("[Spy]",t,"GUILD","Spyuser"..abc(i)) end
    spyIn("[Spy]","1.3.8|Kora-Reed|ROGUE|60|Orc|Ashenvale||0.4|0.6||100","WHISPER","Spyw")
    spyIn("[Spy]","1.3.8|Kora-Reed|ROGUE|60|Orc|Ashenvale||0.4|0.6||100","GUILD","Me")
    spyIn("[Spy]","1.3.8|Me|ROGUE|60|Orc|Ashenvale||0.4|0.6||100","GUILD","Spyz")
    eq(#spyRows(N,"spy"),0)
end)
test("1.0 C1: ForeverSpy1 on a group: name and zone name; FSENT03: GUID, age, level",function()
    local N=loadAddon(); establish(N)
    spyIn("ForeverSpy1","1\tKora Reed\tAshenvale","PARTY","Fsuser")
    local rows=spyRows(N,"fspy"); eq(#rows,1); local r=rows[1].record
    eq(r.enemies[1].name,"Kora Reed"); eq(r.zone,100); eq(r.pos,"none"); eq(r.x,nil); eq(rows[1].source,"seen (Forever Spy)")
    for i,t in ipairs({"2\tKora Reed\tAshenvale","1\tKora Reed\tNowhere","1\t[Kora]\tAshenvale","1\t Kora\tAshenvale","1\tKora Reed\tAshenvale\tx",
        "1\tKora-Reed\tAshenvale"}) do spyIn("ForeverSpy1",t,"PARTY","Fsb"..abc(i)) end
    spyIn("ForeverSpy1","1\tAnn Lee\tAshenvale","GUILD","Fsc")
    eq(#spyRows(N,"fspy"),1)
    spyIn("FSENT03","1~Player-7103-00AB12~Kora-Reed~MAGE~60~Ashenvale~5","RAID","Seuser")
    rows=spyRows(N,"sent"); eq(#rows,1); r=rows[1].record
    eq(r.enemies[1].name,"Kora Reed"); eq(r.enemies[1].class,"MAGE"); eq(r.at,clock-5); eq(r.age,5); eq(rows[1].source,"seen (Sentinel)")
    spyIn("FSENT03","1~Player-7103-00AB13~Ann Lee~~-1~Ashenvale~0","PARTY","Seuser"); eq(#spyRows(N,"sent"),2)
    for i,t in ipairs({"1~Player-7103-00AB14~Bo Dyl~MAGE~60~Ashenvale~121","1~Creature-0-1~Bo Dyl~MAGE~60~Ashenvale~1",
        "2~Player-7103-00AB15~Bo Dyl~MAGE~60~Ashenvale~1","1~Player-7103-00AB16~Bo Dyl~MAGE~60~Ashenvale~1~x",
        "1~Player-7103-00AB17~Bo Dyl~NOPE~60~Ashenvale~1","1~Player-7103-00AB18~Bo Dyl~MAGE~1001~Ashenvale~1",
        "1~Player-7103-00AB19~Bo Dyl~MAGE~60~Ashenvale~1.5"}) do spyIn("FSENT03",t,"RAID","Seb"..abc(i)) end
    spyIn("FSENT03","1~Player-7103-00AB20~Bo Dyl~MAGE~60~Ashenvale~1","GUILD","Sec")
    eq(#spyRows(N,"sent"),2)
end)
test("1.0 C1: the same enemy again from one observer is one row; 6 lines per sender per 10 s; nothing is ever sent",function()
    local N=loadAddon(); establish(N)
    spyIn("[Spy]","1.3.8|Kora-Reed|ROGUE|60|Orc|Ashenvale||0.4|0.6||100","GUILD","Spyuser"); advance(2)
    spyIn("[Spy]","1.3.8|Kora-Reed|ROGUE|60|Orc|Ashenvale||0.5|0.6||100","GUILD","Spyuser"); eq(#spyRows(N,"spy"),1)
    eq(spyRows(N,"spy")[1].x,.5,"the newer sighting replaces the row"); eq(spyRows(N,"spy")[1].at,clock)
    -- a refused newer line keeps the old row
    spyIn("[Spy]","1.3.8|Kora-Reed|ROGUE|60|Orc|Ashenvale||0.6|0.6||200","GUILD","Spyuser"); eq(#spyRows(N,"spy"),1); eq(spyRows(N,"spy")[1].x,.5)
    -- a zone name two zones share is no answer
    N=loadAddon(); establish(N)
    C_Map.GetMapChildrenInfo=function() return {{mapID=200,name="Twin"},{mapID=100,name="Twin"},{mapID=100,name="Ashenvale"}} end
    spyIn("ForeverSpy1","1\tKora Reed\tTwin","PARTY","Fsx"); eq(#spyRows(N,"fspy"),0)
    spyIn("ForeverSpy1","1\tKora Reed\tAshenvale","PARTY","Fsx"); eq(#spyRows(N,"fspy"),1)
    local who={"Ann Lee","Bo Dyl","Cy Fen","Di Gar","Ed Hal","Fa Ivo","Gu Jem"}
    for i=1,7 do spyIn("ForeverSpy1","1\t"..who[i].."\tAshenvale","PARTY","Flood") end
    local function flood() local n=0; for _,r in ipairs(spyRows(N,"fspy")) do if r.reporter=="Flood" then n=n+1 end end; return n end
    eq(flood(),6,"the seventh in 10 s dropped")
    advance(11); spyIn("ForeverSpy1","1\tGu Jem\tAshenvale","PARTY","Flood"); eq(flood(),7)
    for _,m in ipairs(sent) do no(m.prefix=="[Spy]" or m.prefix=="ForeverSpy1" or m.prefix=="FSENT03",m.prefix) end
end)

-- 1.0 lane C2: guild incidents in (GBOUNTY, WALLOFSHAME, FTold1), GUILD only, receive only
test("1.0 C2: a Guild Bounty death: the killer as enemy, the victim's position (zone map only), class and level",function()
    local N=loadAddon(); establish(N)
    spyIn("GBOUNTY","D|Kora-Reed|100|42.5|61.0|Raynewood|60|2|ROGUE|Some Guild","GUILD","Victim")
    local rows=spyRows(N,"gb"); eq(#rows,1); local r=rows[1].record
    eq(r.kind,"death"); eq(r.origin,"Victim"); eq(r.zone,100); eq(r.pos,"victim"); eq(r.x,.425); eq(r.y,.61)
    eq(r.enemies[1].name,"Kora Reed"); eq(r.enemies[1].class,"ROGUE"); eq(r.enemies[1].level,60)
    eq(rows[1].positionKind,"victim's position"); eq(rows[1].source,"death (Guild Bounty)")
    -- a child map: the zone, without coordinates (they are the child map's)
    spyIn("GBOUNTY","D|Ann Lee|101|10.0|20.0||||MAGE|","GUILD","Victimb"); r=spyRows(N,"gb")[1].record
    for _,row in ipairs(spyRows(N,"gb")) do if row.record.origin=="Victimb" then r=row.record end end
    eq(r.zone,100); eq(r.x,nil); eq(r.pos,"none"); eq(r.enemies[1].name,"Ann Lee")
    for i,t in ipairs({"D|Kora-Reed|100|42.5|61.0|Raynewood|60|2|ROGUE","D|Kora-Reed|100|42.5|61.0|Raynewood|60|2|ROGUE|g|x",
        "D||100|42.5|61.0||60|2|ROGUE|","D|Kora-Reed|100|142.5|61.0||60|2|ROGUE|","D|Kora-Reed|100|42.5|||60|2|ROGUE|",
        "D|Kora-Reed|100|42.5|61.0||61.5|2|ROGUE|","D|Kora-Reed|100|42.5|61.0||60|2|NOPE|","D|Kora-Reed||42.5|61.0||60|2|ROGUE|",
        "K|Kora-Reed|2|20|Victim|T","A|Hunter|20|why","X|Kora-Reed|100|42.5|61.0|Raynewood|60|2|ROGUE|g","D|Kora2|100|42.5|61.0||60|2|ROGUE|"}) do spyIn("GBOUNTY",t,"GUILD","Gb"..abc(i)) end
    spyIn("GBOUNTY","D|Bo Dyl|100|42.5|61.0||60|2|ROGUE|","PARTY","Gbp"); spyIn("GBOUNTY","D|Bo Dyl|100|42.5|61.0||60|2|ROGUE|","WHISPER","Gbw")
    eq(#spyRows(N,"gb"),2)
end)
test("1.0 C2: a Wall of Shame death names its killer by zone name; Forever Told S is a wanted player seen",function()
    local N=loadAddon(); establish(N)
    spyIn("WALLOFSHAME","D|60|Ashenvale|MAGE|4|Kora Reed|60|","GUILD","Victim")
    local rows=spyRows(N,"wos"); eq(#rows,1); local r=rows[1].record
    eq(r.kind,"death"); eq(r.zone,100); eq(r.pos,"none"); eq(r.enemies[1].name,"Kora Reed"); eq(r.enemies[1].level,60); eq(r.enemies[1].class,nil)
    eq(rows[1].source,"death (Wall of Shame)")
    for i,t in ipairs({"D|60|Ashenvale|MAGE|4||60|","D|60|Ashenvale|MAGE|4|FALLING||","D|60|Nowhere|MAGE|4|Ann Lee|60|",
        "D|60|Ashenvale|MAGE|4|Ann Lee|60","S|60|Ashenvale|MAGE|3","P|1413|0.5000|0.6000|Ashenvale","D|60|Ashenvale|MAGE|4|Ann Lee|x|",
        "D|60|Ashenvale|MAGE|4|Me|60|"}) do spyIn("WALLOFSHAME",t,"GUILD","Wos"..abc(i)) end
    spyIn("WALLOFSHAME","D|60|Ashenvale|MAGE|4|Bo Dyl|60|","PARTY","Wosp")
    eq(#spyRows(N,"wos"),1)
    spyIn("FTold1","S~Kora-Reed~Astranaar, Ashenvale","GUILD","Teller"); spyIn("FTold1","S~Ann Lee~Ashenvale","GUILD","Tellerb")
    rows=spyRows(N,"ft"); eq(#rows,2); for _,row in ipairs(rows) do eq(row.record.kind,"seen"); eq(row.record.zone,100); eq(row.source,"wanted, seen (Forever Told)") end
    for i,t in ipairs({"S~Kora-Reed","S~Kora-Reed~Astranaar, Nowhere","S~~Ashenvale","C~Kora-Reed","P~Kora-Reed~1~1~MAGE~Mage~60~Ashenvale~5",
        "S~Kora-Reed~Ashenvale~x","X~Kora-Reed~Ashenvale"}) do spyIn("FTold1",t,"GUILD","Ft"..abc(i)) end
    spyIn("FTold1","S~Bo Dyl~Ashenvale","RAID","Ftr")
    eq(#spyRows(N,"ft"),2)
    for _,m in ipairs(sent) do no(m.prefix=="GBOUNTY" or m.prefix=="WALLOFSHAME" or m.prefix=="FTold1",m.prefix) end
end)

-- 1.0 consent/status (owner decisions 2026-11-14 and on ded1bee): public by default, one first-login line, /le net,
-- per-network switches, a Guild-only switch, /le share and its window switch
local NOTICE="LayerEnemies: public networks ON (War Effort, HeadHunter…). /le net guild to limit to guild only."
local function restart(N) N.Main.started=false; N.Main.start(); drain() end
local function slash(cmd) SlashCmdList.LAYERENEMIES(cmd); drain() end
test("1.0 consent: no choice saved reads as public: public whispers and channel joins run; guild only when chosen",function()
    local N=loadAddon(); local Wr=N.Wire; netOn(N,"hh","we")
    eq(N.Net.consent(),"public"); eq(N.Net.chosen(),nil)
    local ok=Wr.send("HeadHunter","1AN:LayerEnemies","WHISPER","Bob",{net="hh",scope="public",prio="owed"}); yes(ok)
    dirReady(N); eq(table.concat(joined,","),"HeadHunterSync,WarEfforttestrealmA")
    N.Net.setConsent("guild"); eq(N.Net.consent(),"guild"); eq(N.Net.chosen(),"guild"); eq(LayerEnemiesDB.consent,"guild")
    local why; ok,why=Wr.send("HeadHunter","1AN:LayerEnemies","WHISPER","Ann Lee",{net="hh",scope="public",prio="owed"}); no(ok); eq(why,"no consent")
    restart(N); eq(N.Net.consent(),"guild","kept across a reload")
    LayerEnemiesDB.consent="all"; restart(N); eq(N.Net.consent(),"public"); eq(LayerEnemiesDB.consent,nil,"an odd value is no choice")
end)
test("1.0 consent: the first-login line, once, only while a network ships; not after a guild choice",function()
    local N=loadAddon(); eq(#log>0 and logged(NOTICE) or false,false,"nothing ships: no line"); eq(LayerEnemiesDB.netNotice,nil)
    N.Net.SHIP.we=true; restart(N); yes(logged(NOTICE)); eq(LayerEnemiesDB.netNotice,true)
    local n=0; for _,l in ipairs(log) do if l==NOTICE then n=n+1 end end; eq(n,1)
    restart(N); n=0; for _,l in ipairs(log) do if l==NOTICE then n=n+1 end end; eq(n,1,"once per character")
    N=loadAddon(); LayerEnemiesDB.consent="guild"; N.Net.SHIP.hh=true; restart(N); no(logged(NOTICE),"the player already chose guild only")
end)
test("1.0 consent: /le net shows and sets the level and each network's switch",function()
    local N=loadAddon(); netOn(N,"we")
    slash("net"); yes(logged("Networks: public")); yes(logged("War Effort: on")); yes(logged("HeadHunter: off (not in this version)"))
    slash("net guild"); eq(N.Net.consent(),"guild"); yes(logged("LayerEnemies: guild only. War Effort, HeadHunter and the other public networks stay off; your guild and group still get your sightings."))
    log={}; slash("net"); yes(logged("Networks: guild only")); yes(logged("War Effort: off (guild only)"))
    slash("net public"); eq(N.Net.consent(),"public"); yes(logged("LayerEnemies: public networks ON"))
    slash("net wareffort off"); no(N.Net.switch("we")); eq(LayerEnemiesDB.nets.we,false); log={}; slash("net"); yes(logged("War Effort: off (switched off)"))
    slash("net we on"); yes(N.Net.switch("we")); slash("net headhunter off"); no(N.Net.switch("hh")); slash("net hh on"); yes(N.Net.switch("hh"))
    loaded.WarEffortScout=true; log={}; slash("net"); yes(logged("War Effort: off (War Effort is loaded: it sends, we only read)")); loaded.WarEffortScout=nil
    slash("net hh maybe"); yes(N.Net.switch("hh"),"neither on nor off: no change"); yes(logged("/le net; /le net guild"))
    log={}; slash("net bogus"); yes(logged("/le net; /le net guild; /le net public; /le net wareffort on|off; /le net headhunter on|off"))
    eq(forbidden,0)
end)
test("1.0 consent: /le share off stops every own-sighting send (O, C+E); saved; on again restores",function()
    local N=loadAddon(); netOn(N,"we"); establish(N); local M=N.Main
    eq(M.sharing(),true,"on by default"); hello("Wes",19)
    slash("share off"); eq(LayerEnemiesDB.share,false); yes(logged("LayerEnemies: your sightings are no longer shared"))
    foe(N,1); foe(N,2); advance(3); M.shareTick(); advance(3); M.shareTick(); eq(#oLines(),0); eq(#weSent("C"),0)
    restart(N); eq(M.sharing(),false,"kept across a reload")
    slash("share on"); eq(LayerEnemiesDB.share,true); hello("Wes",19); advance(16); foe(N,3); foe(N,4); advance(3); M.shareTick(); eq(#oLines(),1); eq(#weSent("C"),1)
    LayerEnemiesDB.share="x"; restart(N); eq(M.sharing(),true,"only a saved false turns it off")
end)
test("1.0 consent: window switches for sharing, guild only and each network",function()
    local N=loadAddon(); netOn(N,"we","hh"); local U=N.UI; U.toggle(); U.select("reported")
    yes(U.share:IsShown()); eq(U.share.label.text,"Share: on"); U.share:Click(); drain(); eq(N.Main.sharing(),false); eq(U.share.label.text,"Share: off")
    eq(U.guildOnly.label.text,"Guild only: off"); U.guildOnly:Click(); drain(); eq(N.Net.consent(),"guild"); eq(U.guildOnly.label.text,"Guild only: on")
    U.guildOnly:Click(); drain(); eq(N.Net.consent(),"public","a second click opens again"); U.guildOnly:Click(); drain()
    eq(U.netWe.label.text,"War Effort: on"); U.netWe:Click(); drain(); no(N.Net.switch("we")); eq(U.netWe.label.text,"War Effort: off")
    eq(U.netHh.label.text,"HeadHunter: on"); U.netHh:Click(); drain(); no(N.Net.switch("hh"))
    N.Net.SHIP.hh=false; U.render(); eq(U.netHh.label.text,"HeadHunter: n/a")
    U.select("local"); yes(U.share:IsShown(),"on every tab")
end)
test("1.0 consent: /le status names the network level, sharing and each network",function()
    local N=loadAddon(); netOn(N,"we"); establish(N); log={}; slash("status")
    yes(logged("Networks: public (/le net guild for guild only)")); yes(logged("Sharing your sightings: on (/le share off)"))
    yes(logged("War Effort: on")); N.Net.setConsent("guild"); slash("share off"); log={}; slash("status")
    yes(logged("Networks: guild only (/le net public to open)")); yes(logged("Sharing your sightings: off (/le share on)"))
end)

-- مانع on fab7253 (r040c/21e): guild identity checked at every hosting action; the roster request retried; a blink
test("21e fab7253: hosting acts only while the guild name is readable and equal to the guild seen",function()
    -- a switch noticed by nothing yet (no event, no roster): a request is refused and hosting goes inactive
    local N=loadAddon(); hReady(N); roster={{"Bob",true}}; deliver("GUILD_ROSTER_UPDATE",true); drain(); advance(61); guildName="Guild B"
    lsw("inv layer <LS 100 want 7086-0>","Bob"); eq(#invites,0,"no invite for the old guild's member"); no(N.Main.host.on)
    yes(N.Main.host.want); eq(hostF(),0,"no H either")
    -- a roster while the name is unreadable: hosting goes inactive, nothing acts
    N=loadAddon(); hReady(N); advance(61); guildName=nil; deliver("GUILD_ROSTER_UPDATE",true); drain(); no(N.Main.host.on)
    lsw("inv layer <LS 100 want 7086-0>","Bob"); eq(#invites,0); eq(hostF(),0)
    -- readable and equal again: the next roster brings it back, and it acts
    roster={{"Bob",true}}; guildName="Test Guild"; deliver("GUILD_ROSTER_UPDATE",true); drain(); yes(N.Main.host.on); advance(61); lsw("inv layer <LS 100 want 7086-0>","Bob"); eq(#invites,1)
    -- unreadable at the moment of an F answer: no H
    N=loadAddon(); hReady(N); advance(61); legw("F|1","Cy"); guildName=nil; advance(7); drain(); eq(#legwSent("H|"),0); guildName="Test Guild"
    -- /le host on while the name is unreadable: refused with the reason
    N=loadAddon(); establish(N); guildName=nil; slash("host on"); no(N.Main.host.on); yes(logged("your guild's name is not readable")); guildName="Test Guild"
end)
test("21e fab7253: the post-switch roster request is retried once the 15 s limit has passed",function()
    local N=loadAddon(); hReady(N); local calls=rosterCalls                      -- host on asked for a roster just now
    advance(2); guildName="Guild B"; deliver("PLAYER_GUILD_UPDATE","player"); drain(); eq(rosterCalls,calls,"inside 15 s: not asked yet")
    advance(14); eq(rosterCalls,calls+1,"asked once the limit passed"); advance(30); eq(rosterCalls,calls+1,"once")
    deliver("GUILD_ROSTER_UPDATE",true); drain(); yes(N.Main.host.on)
end)
test("21e fab7253: a guild name that blinks unreadable on a guild event comes back on the next readable event or roster",function()
    local N=loadAddon(); hReady(N); advance(61)
    guildName=nil; deliver("PLAYER_GUILD_UPDATE","player"); drain(); no(N.Main.host.on)
    guildName="Test Guild"; deliver("PLAYER_GUILD_UPDATE","player"); drain(); yes(N.Main.host.on,"the readable event alone")
    eq(hostF(),1,"and it acts")
    N=loadAddon(); hReady(N); advance(61)
    guildName=nil; deliver("PLAYER_GUILD_UPDATE","player"); drain(); no(N.Main.host.on)
    guildName="Test Guild"; deliver("GUILD_ROSTER_UPDATE",true); drain(); yes(N.Main.host.on,"the readable roster alone")
    -- the blink ends in another guild: a switch, that guild's roster first
    N=loadAddon(); hReady(N); advance(61); guildName=nil; deliver("PLAYER_GUILD_UPDATE","player"); drain()
    guildName="Guild B"; deliver("PLAYER_GUILD_UPDATE","player"); drain(); no(N.Main.host.on); eq(N.Adapters.roster.at,nil)
    deliver("GUILD_ROSTER_UPDATE",true); drain(); yes(N.Main.host.on)
end)

-- مانع on 56dbb3c (r040c/21e C2): our own sighting keeps its own time and origin under Bulo refreshes
test("21e 56dbb3c: with Bulo refreshing every second, our own sightings still go out",function()
    local N=loadAddon(); local b=fakeBulo("7086-7"); establish(N); advance(1)
    -- one own sighting, then Bulo refreshes the same player every second
    seeFoe("Kora Reed","Player-1-901"); units.target=nil
    for i=1,10 do advance(1); b.Radar.seen["Player-1-901"]={at=clock,hostile=true,src="target"}; N.Main.poll() end
    eq(#oLines(),1,"the own sighting is shared although Bulo refreshed its row")
    local row=N.Main.store.localSeen["Player-1-901"]; yes(row.source:find("^Bulo")); eq(row.ownSource,"own target"); eq(row.ownAt,clock-10)
    -- own sightings every 5 s among Bulo refreshes every second: shared again once 60 s have passed
    for i=1,70 do advance(1); if i%5==0 then seeFoe("Kora Reed","Player-1-901"); units.target=nil end
        b.Radar.seen["Player-1-901"]={at=clock,hostile=true,src="target"}; N.Main.poll() end
    eq(#oLines(),2,"a re-share after 60 s")
    -- Bulo refreshes alone never make a sighting ours again: 120 s with no own event, no new line
    for i=1,120 do advance(1); b.Radar.seen["Player-1-901"]={at=clock,hostile=true,src="target"}; N.Main.poll() end
    eq(#oLines(),2)
    -- the settle runs from our own sighting, not from a Bulo refresh: out 3 s after it
    N=loadAddon(); b=fakeBulo("7086-7"); establish(N); advance(1); local ts=clock; seeFoe("Cy Fen","Player-1-903"); units.target=nil
    local sentAt; for i=1,6 do advance(1); b.Radar.seen["Player-1-903"]={at=clock,hostile=true,src="target"}; N.Main.poll(); if not sentAt and #oLines()>0 then sentAt=clock end end
    eq(sentAt,ts+3)
    local Sh=N.Share; local sh=Sh.new(); local r={key="r",faction="opposite",zone=100,source="Bulo target",at=1,ownSource="own target",ownAt=0}
    eq(Sh.pick(sh,{r=r},1,100),nil); yes(Sh.pick(sh,{r=r},3,100),"settled 3 s after the own sighting, though first picked after a refresh")
    -- an own sighting from before a layer boundary is not carried onto a later Bulo copy
    local T=N.Store; local st=N.Main.store
    st.localSeen.k={key="k",at=clock-1,epoch=st.serial-1,ownAt=clock-1,ownSource="own target",faction="opposite"}
    T.observe(st,{key="k",at=clock,source="Bulo target",faction="opposite"},clock); eq(st.localSeen.k.ownAt,nil)
    -- the O line's age is our own sighting's
    N=loadAddon(); b=fakeBulo("7086-7"); establish(N); advance(1); local t0=clock; seeFoe("Ann Lee","Player-1-902"); units.target=nil
    advance(1); b.Radar.seen["Player-1-902"]={at=clock,hostile=true,src="target"}; N.Main.poll(); advance(3); N.Main.shareTick()
    local o=oLines()[1]; yes(o); eq(tonumber(o.text:match("^O|1|%d+|%d+|[^|]*|[^|]*|[^|]*|(%d+)|")),math.floor(o.at-t0),"age from our own sighting")
end)

-- مانع on 21eacaf (r040c/21e astra-a2)
test("21e 21eacaf: answer pacing compares against the last send time (no float edge: two sends at one timestamp)",function()
    local N=loadAddon(); local Wn=N.WeNet; local st=Wn.new(0); local cont=function() return 1 end
    Wn.keep(st,{rid=1,t=50,server=1000,map=100,x=.5,y=.5,layer=0,count=2,enemies={{hash="abc"}}})
    yes(Wn.request(st,"Wes",1,900,55,cont,function() return 0 end)); yes(Wn.request(st,"Wesb",1,900,55,cont,function() return 0 end))
    local who=Wn.nextAnswer(st,61.9); eq(who,"Wes"); eq(Wn.nextAnswer(st,61.9),nil,"not twice at 61.9 (61.9+5-5 < 61.9 in floating point)")
    eq(Wn.nextAnswer(st,66.8),nil); yes(Wn.nextAnswer(st,66.9))
end)
test("21e 21eacaf: the answer queue holds five requesters; the sixth is refused",function()
    local N=loadAddon(); local Wn=N.WeNet; local st=Wn.new(0); local cont=function() return 1 end
    Wn.keep(st,{rid=1,t=50,server=1000,map=100,x=.5,y=.5,layer=0,count=2,enemies={{hash="abc"}}})
    for _,n in ipairs({"Wes","Wesb","Wesc","Wesd","Wese"}) do yes(Wn.request(st,n,1,900,55,cont,function() return .9 end)) end
    local ok,why=Wn.request(st,"Wesf",1,900,55,cont,function() return .9 end); no(ok); eq(why,"queue full")
end)
test("21e 21eacaf: a War Effort C or E whisper to a non-guildmate needs public consent like any other",function()
    local N=loadAddon(); local Wr=N.Wire; netOn(N,"we"); N.Net.setConsent("guild"); roster={{"Wes",true}}; deliver("GUILD_ROSTER_UPDATE",true); drain()
    local c=N.WeOut.cluster(5,100,.5,.5,7086,2,100,1,1); local e=N.WeOut.enemies(5,{{hash="abc",class="MAGE",level=60}},100)[1]
    for _,t in ipairs({c,e}) do
        local ok,why=Wr.send("WEFF1",t,"WHISPER","Stranger",{net="we",prio="owed"}); no(ok,t); eq(why,"no consent")
        yes((Wr.send("WEFF1",t,"WHISPER","Wes",{net="we",prio="owed"})),"a guildmate needs none")
    end
end)
test("21e 21eacaf: a raid with players outside the guild (raid units only) gets a raid hello",function()
    local N=loadAddon(); weReady(N); roster={{"Bob",true}}; deliver("GUILD_ROSTER_UPDATE",true); drain()
    grouped=true; raid=true; units.raid1={name="Me"}; units.raid2={name="Bob"}; advance(12)
    local function raidN() local n=0; for _,m in ipairs(sent) do if m.prefix=="WEFF1" and m.kind=="RAID" then n=n+1 end end; return n end
    eq(raidN(),0,"only guildmates"); units.raid3={name="Stranger"}; steps(200); eq(raidN(),1)
    raid=false; grouped=false; units.raid1=nil; units.raid2=nil; units.raid3=nil
end)
test("21e 21eacaf: the login Q is tried at most twice",function()
    local N=loadAddon(); weReady(N); sendResult=3; steps(200); local n=#weGuild("Q"); yes(n>=1 and n<=2,n)
    sendResult=0; steps(200); eq(#weGuild("Q"),2,"no third attempt")
    N=loadAddon(); weReady(N); steps(200); eq(#weGuild("Q"),1,"sent the first time: once")
end)
test("21e 21eacaf: answer ages are the observation's, rechecked at each send (C and E)",function()
    local N=loadAddon(); local Wn=N.WeNet; local st=Wn.new(0); local cont=function() return 1 end
    Wn.keep(st,{rid=1,t=100,server=1000,map=100,x=.5,y=.5,layer=0,count=2,enemies={{hash="abc"}}})
    yes(Wn.request(st,"Wes",1,60,155,cont,function() return 0 end))
    local who,c=Wn.nextAnswer(st,155); yes(c and c:sub(1,2)=="C|"); eq(Wn.nextAnswer(st,160.5),nil,"the E would be 60.5 s old: not sent")
    -- Main keeps a report dated by its own sighting, not by the send
    N=loadAddon(); netOn(N,"we"); establish(N); hello("Wes",19); local t0=clock; foe(N,1); foe(N,2); advance(3); N.Main.shareTick()
    eq(#weSent("C"),1); eq(N.Main.we.kept[1].t,t0)
end)
print(string.format("RESULT: %d tests passed, %d failed, %d assertions",passed,failed,checks))
if failed>0 then os.exit(1) end
