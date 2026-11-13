local _, N = ...
local S,A,T,L=N.Safe,N.Adapters,N.Store,N.Layer
local M={statusBulo="not installed",statusWE="not installed",pendingUnits={},staleGUIDs={},staleUnits={}}
N.Main=M
local function now() return S.num(S.call(GetTime)) or 0 end
local function guarded(fn,...) local ok=pcall(fn,...); if not ok then M.error="data unavailable (API error)" end end
local function after(delay,fn)
    if S.tab(C_Timer) and type(C_Timer.After)=="function" then return pcall(C_Timer.After,delay,fn) end
    return false
end
local function captureStale()
    S.clear(M.staleGUIDs); S.clear(M.staleUnits)
    local function add(u)
        local g=S.str(S.call(UnitGUID,u),160)
        if g then M.staleGUIDs[g]=true; M.staleUnits[u]=g end
    end
    add("target"); add("mouseover")
    for i=1,40 do add("nameplate"..i) end
end
function M.releaseUnit(unit)
    if not S.str(unit,30) then return end
    local guid=M.staleUnits[unit]
    M.staleUnits[unit]=nil
    if guid then
        for _,other in pairs(M.staleUnits) do if other==guid then return end end
        M.staleGUIDs[guid]=nil
    end
end
function M.boundary(zone)
    captureStale()
    M.blockedBulo=M.store.bulo
    M.subEpoch=now(); L.reset(M.npcs)
    T.reset(M.store,M.subEpoch,zone,nil,nil)
    N.Reports.clearPending(M.receiver)
    S.clear(M.pendingUnits)
    M.layerSource="unknown"
end
function M.applyLayer(id,source)
    if id==M.store.bulo then M.layerSource=source; return end
    if M.store.bulo~=nil then
        M.boundary(M.store.zone)
    else
        T.reset(M.store,now(),M.store.zone,id,M.npcs.current)
        N.Reports.clearPending(M.receiver)
    end
    M.store.bulo=id; M.store.zoneUID=M.npcs.current; M.layerSource=source
end
function M.poll()
    if not M.started then return end
    local time=now()
    local zone=A.location()
    if zone~=M.store.zone then M.boundary(zone) end
    local snap=A.bulo(M.store.epoch,time)
    M.statusBulo=snap.status
    if snap.ns and M.attemptedNS~=snap.ns then
        M.attemptedNS=snap.ns
        M.bus=A.buloSubscribe(snap.ns,function(event)
            if M.attemptedNS~=snap.ns then return end
            if event=="LFS_TRANSFER" then M.boundary(A.location()) end
            M.queuePoll()
        end)
    end
    local id=snap.current
    if id==M.blockedBulo and not M.npcs.current then id=nil end
    if id then M.applyLayer(id,"Bulo server id")
    elseif M.layerSource=="Bulo server id" and M.store.bulo then M.boundary(zone) end
    for _,e in ipairs(snap.observations or {}) do
        if not M.staleGUIDs[e.key] then
            local old=M.store.localSeen[e.key]
            if not old or old.at<e.at then
                local name,realm,class,race=A.enrich(e.key)
                e.name,e.realm,e.class,e.race=name,realm,class,race
                -- Only separately observed readable unit factions classify players.
                if old then
                    e.name=e.name or old.name; e.realm=e.realm or old.realm; e.class=e.class or old.class
                    e.level=old.level; e.faction=old.faction
                end
                -- Do not attach today's position to an older Bulo timestamp.
                T.observe(M.store,e,time)
            end
        end
    end
    T.prune(M.store,time); N.Reports.prune(M.receiver,time)
    if not A.loaded("WarEffortScout") then
        M.statusWE="not installed"
    else
        local ok,reason=A.policy("WEFF1","GUILD","LayerEnemiesPolicyProbe",nil)
        M.statusWE=ok and "installed / freshness unavailable (hour-relative timestamps)" or ("installed / "..reason)
    end
    if M.lastHeard then M.statusWE=M.statusWE.." / last heard "..math.floor(time-M.lastHeard).." s ago" end
end
function M.queuePoll()
    if M.pollQueued then return end
    M.pollQueued=true
    if not after(0,function() M.pollQueued=false; guarded(M.poll) end) then M.pollQueued=false; guarded(M.poll) end
end
function M.observe(unit)
    local time=now()
    local zone,x,y=A.location()
    if zone~=M.store.zone then M.boundary(zone) end
    local guid=S.str(S.call(UnitGUID,unit),160)
    if not guid or M.staleGUIDs[guid] then return end
    local npc=L.npc(guid)
    if npc and S.call(UnitPlayerControlled,unit)==false then
        local value,old,raw=L.observe(M.npcs,guid,time)
        if value then
            if old and old~=value then
                -- An NPC zoneUID transition is a conservative epoch boundary,
                -- NOT proof that the Bulo server-layer changed.
                M.boundary(zone)
                return
            end
            M.store.zoneUID=value
            if raw and (not M.store.bulo or M.layerSource=="local NPC server id") then M.applyLayer(raw,"local NPC server id") end
        end
        return
    end
    local e=A.unit(unit)
    if not e then return end
    e.at=time; e.source="own "..unit; e.x=x; e.y=y; e.positionKind="approximate observer position"
    T.observe(M.store,e,time)
end
function M.queueUnit(unit)
    if not S.str(unit,30) or not (unit=="target" or unit=="mouseover" or unit:match("^nameplate%d+$")) then return end
    if M.staleUnits[unit] and S.str(S.call(UnitGUID,unit),160)~=M.staleUnits[unit] then M.releaseUnit(unit) end
    if S.count(M.pendingUnits)>=42 then return end
    M.pendingUnits[unit]=true
    if M.unitsQueued then return end
    M.unitsQueued=true
    local function run()
        M.unitsQueued=false
        for token in pairs(M.pendingUnits) do M.pendingUnits[token]=nil; guarded(M.observe,token) end
        M.queuePoll()
    end
    if not after(0,run) then run() end
end
function M.message(prefix,text,kind,sender,target,zoneChannelID,localID,channelName)
    -- Check every delivered value before comparing/indexing it.
    local args={prefix,text,kind,sender,target,zoneChannelID,localID,channelName}
    for i=1,8 do if S.secret(args[i]) then return end end
    if (prefix~="WEFF1" and prefix~="ZRAD1") or type(text)~="string" or #text>255 or not S.str(sender,100) then return end
    local allowed,reason=A.policy(prefix,kind,sender,channelName)
    if not allowed then M.lastDrop=reason; return end
    local msg=N.Protocol.decode(text)
    if not msg then M.lastDrop="invalid message"; return end
    local server=S.num(S.call(GetServerTime))
    if not N.Protocol.clockAge(msg.stamp,server) then M.lastDrop="stale or clock unavailable"; return end
    M.lastHeard=now()
    -- There is no authenticated absolute send time in either installed protocol.
    -- Never infer freshness merely from arrival, hello, or the modulo clock.
    local report,why=N.Reports.receive(M.receiver,text,sender,now(),server,A.zone,M.store.zone,M.store.zoneUID,M.store.epoch,nil)
    M.lastDrop=why
    if report then T.report(M.store,report,now()) end
end
local function say(text)
    if S.tab(DEFAULT_CHAT_FRAME) then S.call(DEFAULT_CHAT_FRAME.AddMessage,DEFAULT_CHAT_FRAME,text)
    elseif type(print)=="function" then print(text) end
end
function M.text(command)
    guarded(M.poll)
    local id=M.store.bulo or "Unknown"
    say("LayerEnemies - Your layer: "..id.." ("..(M.layerSource or "unknown")..")")
    say("Bulo: "..M.statusBulo); say("War Effort: "..M.statusWE)
    say("War Effort zoneUID: "..tostring(M.store.zoneUID or "Unknown").." (separate namespace, not layer membership proof)")
    local kind=command=="reports" and "reported" or command=="unclassified" and "unclassified" or "local"
    say(kind=="reported" and "Reported zoneUID matches (unverified):" or kind=="unclassified" and "Unclassified / same-faction local observations (not confirmed enemies):" or "Opposite-faction players seen by you:")
    local rows=T.rows(M.store,now(),kind)
    if #rows==0 then say("No eligible observations.") end
    for _,e in ipairs(rows) do
        local age=math.floor(math.max(0,now()-e.at))
        local when=age<60 and (age.." s") or (math.floor(age/60).." min")
        say((e.name or "Unknown").." | "..(e.class or "Unknown class").." | "..tostring(e.level or "?").." | zone "..tostring(e.zone).." | seen "..when.." ago | "..e.source.." | "..e.confidence..(e.possible and (" | "..e.possible) or ""))
    end
    say("Only players seen by you or reported by War Effort users.")
    say("Headless build: /le, /le unclassified, /le reports. Window and map layout await approval.")
    if M.lastDrop and command=="reports" then say("Last report rejected: "..M.lastDrop) end
end
local function heartbeat()
    guarded(M.poll)
    local visible=false
    if S.tab(WorldMapFrame) then visible=S.call(WorldMapFrame.IsShown,WorldMapFrame)==true end
    if not after(visible and 2 or 5,heartbeat) then M.error="timer unavailable; event-only mode" end
end
function M.start()
    if M.started then return end
    M.started=true
    M.npcs=L.new(); M.store=T.new(now()); M.receiver=N.Reports.new()
    M.layerSource="unknown"; M.store.zone=A.location()
    if not S.tab(LayerEnemiesDB) then LayerEnemiesDB={} end
    -- Configuration only. Sightings and source identities never enter SavedVariables.
    LayerEnemiesDB={options=S.tab(LayerEnemiesDB.options) and {enabled=LayerEnemiesDB.options.enabled~=false} or {enabled=true}}
    if S.tab(C_ChatInfo) then
        S.call(C_ChatInfo.RegisterAddonMessagePrefix,"WEFF1")
        S.call(C_ChatInfo.RegisterAddonMessagePrefix,"ZRAD1")
    end
    SlashCmdList=SlashCmdList or {}
    _G.SLASH_LAYERENEMIES1="/le"
    SlashCmdList.LAYERENEMIES=function(command) guarded(M.text,S.str(command,30) or "") end
    heartbeat()
end
local frame=CreateFrame("Frame")
M.frame=frame
frame:Hide()
for _,event in ipairs({"ADDON_LOADED","PLAYER_LOGIN","PLAYER_ENTERING_WORLD","ZONE_CHANGED_NEW_AREA","ZONE_CHANGED","SHARD_TRANSFER","PLAYER_TARGET_CHANGED","UPDATE_MOUSEOVER_UNIT","NAME_PLATE_UNIT_ADDED","NAME_PLATE_UNIT_REMOVED","CHAT_MSG_ADDON"}) do
    pcall(frame.RegisterEvent,frame,event)
end
local function dispatch(_,event,...)
    if not S.str(event,50) then return end
    if event=="ADDON_LOADED" then
        local name=S.str((...),80)
        if name=="LayerEnemies" then guarded(M.start) elseif M.started then M.queuePoll() end
        return
    end
    if event=="PLAYER_LOGIN" then guarded(M.start); return end
    if not M.started then return end
    if event=="CHAT_MSG_ADDON" then guarded(M.message,...)
    elseif event=="PLAYER_ENTERING_WORLD" or event=="SHARD_TRANSFER" then guarded(M.boundary,A.location()); M.queuePoll()
    elseif event=="ZONE_CHANGED_NEW_AREA" or event=="ZONE_CHANGED" then
        if A.location()~=M.store.zone then guarded(M.boundary,A.location()) end
        M.queuePoll()
    elseif event=="PLAYER_TARGET_CHANGED" then M.queueUnit("target")
    elseif event=="UPDATE_MOUSEOVER_UNIT" then M.queueUnit("mouseover")
    elseif event=="NAME_PLATE_UNIT_ADDED" then M.queueUnit(...)
    elseif event=="NAME_PLATE_UNIT_REMOVED" then M.releaseUnit(...) end
end
frame:SetScript("OnEvent",function(...) guarded(dispatch,...) end)
