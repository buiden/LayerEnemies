local _, N = ...
local S,A,T,L,I=N.Safe,N.Adapters,N.Store,N.Layer,N.Invite
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
    -- A readable zone that differs from the last readable one ends the zone epoch (own raw id and ambiguity);
    -- otherwise only the votes start again. An unreadable map (a loading screen) is no evidence of a zone change.
    -- Nothing of this is saved: /reload starts without the raw id and without the ambiguity window.
    if zone~=nil and M.zoneSeen~=nil and zone~=M.zoneSeen then L.forget(M.npcs) else L.reset(M.npcs) end
    if zone~=nil then M.zoneSeen=zone end
    M.subEpoch=now()
    T.reset(M.store,M.subEpoch,zone,nil,nil)
    N.Reports.clearPending(M.receiver)
    S.clear(M.pendingUnits)
    M.layerSource="unknown"
    if M.find then N.Find.boundary(M.find) end
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
    local snap=A.bulo(M.store.epoch,time,M.store.localSeen)
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
                local name,realm,class,race,level=A.enrich(e.key)
                e.name,e.realm,e.class,e.race,e.level=name,realm,class,race,level
                -- Only separately observed readable unit factions classify players.
                if old then
                    e.name=e.name or old.name; e.realm=e.realm or old.realm; e.class=e.class or old.class
                    e.level=e.level or old.level; e.faction=old.faction
                end
                -- Do not attach today's position to an older Bulo timestamp.
                T.observe(M.store,e,time)
            end
        end
    end
    T.prune(M.store,time); N.Reports.prune(M.receiver,time)
    -- War Effort itself is not needed: its guild and group traffic is read either way.
    M.statusWE=(A.loaded("WarEffortScout") and "installed" or "not installed").." / listening on guild, party and raid (reported, not confirmed)"
    if M.lastHeard then M.statusWE=M.statusWE.." / last heard "..math.floor(time-M.lastHeard).." s ago" end
    M.groupCheck(); M.inviteTick()
    M.findAlerts()
    if N.UI then N.UI.refresh() end
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
    N.Find.own(M.find,e,zone,time)
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
    if prefix~="WEFF1" or type(text)~="string" or #text>255 or not S.str(sender,100) then return end
    local allowed,reason=A.policy(prefix,kind,sender)
    if not allowed then M.lastDrop=reason; return end
    local msg,why=N.Protocol.decode(text)
    if not msg then if why~="ignored" then M.lastDrop="invalid message" end; return end
    if not A.WE_TYPES[kind][msg.type] then M.lastDrop=msg.type.." is not read on "..kind; return end
    local time=now()
    -- Over the per-sender limit: dropped without a note.
    if not N.Reports.allow(M.receiver,sender,msg.type=="G" or msg.type=="X",time) then return end
    local inner,origin=msg.inner or msg,msg.origin or sender
    if msg.origin then
        local me=S.str((S.call(UnitName,"player")))
        if me and N.Peers.key(origin)==N.Peers.key(me) then M.lastDrop="own echo"; return end
        local ignored,whyIgnored=A.ignored(origin)
        if ignored then M.lastDrop=whyIgnored; return end
    end
    M.lastHeard=time
    if inner.type=="H" then N.Peers.hello(M.peers,origin,inner.minor,time); return end
    local record
    record,why=N.Reports.receive(M.receiver,msg,{sender=sender,route=kind,now=time,
        serverNow=S.num(S.call(GetServerTime)),zoneFn=A.zone,peers=M.peers})
    M.lastDrop=why
    if record then
        local stored,whyNot=T.report(M.store,record,time)
        if not stored then M.lastDrop=whyNot end
        N.Find.report(M.find,{sender=record.origin,zone=record.zone,at=record.heard,enemies=record.enemies},M.homeRealm())
        M.findAlerts()
        if N.UI then N.UI.refresh() end
    end
end
local function say(text)
    if S.tab(DEFAULT_CHAT_FRAME) then S.call(DEFAULT_CHAT_FRAME.AddMessage,DEFAULT_CHAT_FRAME,text)
    elseif type(print)=="function" then print(text) end
end
M.say=say
function M.homeRealm()
    return S.str(S.call(GetNormalizedRealmName)) or S.str(S.call(GetRealmName)) or ""
end
function M.zoneName(zone)
    local info=S.tab(C_Map) and S.call(C_Map.GetMapInfo,zone)
    return S.tab(info) and S.str(info.name) or ("zone "..tostring(zone or "unknown"))
end
function M.findRows()
    local lists=A.friendLists()
    return N.Find.rows(M.find,now(),M.store.zone,function(name,zone)
        return zone==M.store.zone and I.sameSpotter(name,{zone=zone,wall=A.wall(),ownKey=L.key(M.store.bulo),bulo=lists.bulo,book=lists.book})
    end)
end
function M.findText(row)
    if not row.at then return row.name.." — "..row.status end
    local detail=" in "..M.zoneName(row.zone)..", "..math.floor(now()-row.at).." s ago ("..(row.class or "Unknown class").." "..tostring(row.level or "?")..")"
    return row.name.." — "..row.status..detail..(row.same and " — already on your layer" or row.travel and (" — travel to "..M.zoneName(row.zone).." first") or "")
end
function M.findAlerts()
    if not M.find or #M.find.names==0 then return end
    for _,row in ipairs(M.findRows()) do
        if N.Find.alert(M.find,row,now()) then
            M.say("LayerEnemies: "..M.findText(row))
            S.call(PlaySound,S.tab(SOUNDKIT) and SOUNDKIT.RAID_WARNING or 8959,"Master")
        end
    end
end
function M.track(name,remove)
    if remove then N.Find.remove(M.find,name)
    elseif name then
        local ok,why=N.Find.add(M.find,name)
        if not ok then M.say("LayerEnemies: "..why); return false end
        for _,e in pairs(M.store.localSeen) do N.Find.own(M.find,e,M.store.zone,e.at) end
        for _,row in pairs(M.store.reports) do
            local r=row.record
            N.Find.report(M.find,{sender=r.origin,zone=r.zone,at=r.heard,enemies=r.enemies},M.homeRealm())
        end
    else N.Find.remove(M.find) end
    LayerEnemiesDB.tracked=M.find.names
    if #M.find.names==0 then M.say("LayerEnemies: tracked names cleared.") end
    for _,row in ipairs(M.findRows()) do M.say("LayerEnemies: "..M.findText(row)) end
    M.findAlerts()
    if N.UI then N.UI.refresh() end
    return true
end
local function ago(seconds)
    seconds=math.floor(math.max(0,seconds))
    return seconds<60 and (seconds.." s") or (math.floor(seconds/60).." min")
end
function M.candidates()
    local time=now()
    local lists=A.friendLists()
    local _,short=I.name((S.call(UnitName,"player")))
    return I.collect({now=time,wall=A.wall(),zone=M.store.zone,ownKey=L.key(M.store.bulo),self=short,
        reporters=T.reporters(M.store,time),bulo=lists.bulo,book=lists.book})
end
-- Puts the line into the chat box one frame later: a slash command runs inside
-- the box's own send, which empties the box afterwards. The user presses Enter.
function M.openChat(line)
    local ok,open=pcall(function() return S.tab(ChatFrameUtil) and S.clean(ChatFrameUtil.OpenChat) or nil end)
    if not ok or type(open)~="function" then open=S.clean(ChatFrame_OpenChat) end
    if type(open)~="function" then return false end
    return after(0,function()
        if not pcall(open,line,S.tab(DEFAULT_CHAT_FRAME) and DEFAULT_CHAT_FRAME or nil) then
            M.say("LayerEnemies: the chat box did not open. Type this line yourself:"); M.say(line)
        end
    end)
end
function M.openWhisper(name,line)
    if not name:find(" ",1,true) then return M.openChat(line) end
    local tell=S.tab(ChatFrameUtil) and S.clean(ChatFrameUtil.SendTell)
    if type(tell)~="function" then return false end
    return after(0,function()
        local ok=pcall(function()
            tell(name)
            local box=S.call(ChatFrameUtil.GetActiveWindow) or (S.tab(DEFAULT_CHAT_FRAME) and DEFAULT_CHAT_FRAME.editBox)
            if not S.tab(box) or type(S.clean(box.Insert))~="function" then error("chat box unavailable") end
            box:Insert(I.MESSAGE)
        end)
        if not ok then
            M.say("LayerEnemies: open a whisper to "..name.." manually, then type:"); M.say(I.MESSAGE)
        end
    end)
end
function M.askInvite(name)
    local wanted,short=I.name(name)
    if not wanted then M.say("LayerEnemies: that player name is not readable."); return false end
    local found
    for _,c in ipairs((M.candidates())) do if c.short==short then found=c; break end end
    if not found then
        for _,row in ipairs(M.findRows()) do
            local _,key=I.name(row.spotter)
            if key==short then
                if row.travel then M.say("LayerEnemies: travel to "..M.zoneName(row.zone).." first."); return false end
                if row.same then M.say("LayerEnemies: already on your layer."); return false end
                if row.canAsk then found={name=row.spotter,short=key}; break end
            end
        end
    end
    if not found then
        M.say("LayerEnemies: "..wanted.." is not a known friendly player on another layer in your zone right now. See /le hosts.")
        return false
    end
    local ok,line=I.ask(M.invite,found,now(),A.grouped(),L.key(M.store.bulo))
    if not ok then M.say("LayerEnemies: "..line); return false end
    if M.openWhisper(found.name,line) then
        M.say("LayerEnemies: a whisper to "..found.name.." is in your chat box - press Enter to send it.")
    else
        if found.name:find(" ",1,true) then
            M.say("LayerEnemies: open a whisper to "..found.name.." manually, then type:"); M.say(I.MESSAGE)
        else M.say("LayerEnemies: type or copy this line to ask "..found.name..":"); M.say(line) end
    end
    return true
end
function M.hosts()
    guarded(M.poll)
    local list,status=M.candidates()
    local names={}
    M.say("LayerEnemies - friendly players on other layers, your zone only. Your layer: "..(L.key(M.store.bulo) or "Unknown"))
    if #list==0 then M.say("No one to ask right now.") end
    for i,c in ipairs(list) do
        names[i]=c.name
        M.say(i..". "..c.name.." | "..(c.layer and ("layer "..c.layer) or "layer unknown - saw reported enemies").." | "..table.concat(c.sources," + ")..(c.host and " | host" or "").." | "..ago(c.age).." ago")
    end
    M.hostList={at=now(),names=names}
    M.say("Bulo: "..status.bulo.." / LayerSwap: "..status.book.." / War Effort reporters: "..status.reports)
    M.say("/le ask <number> puts a whisper in your chat box; you press Enter. Nothing is sent, accepted or left for you.")
end
function M.askIndex(index)
    local list=M.hostList
    if not list or now()-list.at>120 then M.say("LayerEnemies: run /le hosts first, then /le ask <number>."); return false end
    local name=index and list.names[index]
    if not name then M.say("LayerEnemies: no such number in the last /le hosts list."); return false end
    return M.askInvite(name)
end
-- Only notices a join; invites are accepted and groups are left by the user.
function M.groupCheck()
    local grouped=A.grouped()
    if grouped and not M.wasGrouped and I.joined(M.invite,now(),L.key(M.store.bulo),M.store.zone) then
        M.say("LayerEnemies: you joined a group after asking - checking your layer for 60 s.")
        after(I.WATCH+0.5,function() guarded(M.inviteTick) end)
    end
    M.wasGrouped=grouped
end
function M.inviteTick()
    if not M.invite.watch then return end
    local message,note=I.tick(M.invite,now(),L.key(M.store.bulo),M.store.zone)
    if message then M.say("LayerEnemies: "..message) end
    if note then M.say("LayerEnemies: "..note) end
end
function M.text(command)
    guarded(M.poll)
    local id=M.store.bulo or "Unknown"
    say("LayerEnemies - Your layer: "..id.." ("..(M.layerSource or "unknown")..")")
    say("Bulo: "..M.statusBulo); say("War Effort: "..M.statusWE)
    if M.error then say("Runtime status: "..M.error) end
    say("Your server key: "..(L.key(M.store.bulo) or "Unknown")..(M.store.ambiguous(now()) and " (ambiguous: another layer of this zone shares it)" or "")
        .." - zone-scoped; an equal key is not proof of the same layer")
    local kind=command=="reports" and "reported" or command=="unclassified" and "unclassified" or "local"
    say(kind=="reported" and "Reported, not confirmed (War Effort; age as the reporter's clock gives it):" or kind=="unclassified" and "Unclassified / same-faction local observations (not confirmed enemies):" or "Opposite-faction players seen by you:")
    local rows=T.rows(M.store,now(),kind)
    if #rows==0 then say(kind=="reported" and "No live reports for your zone." or "No eligible observations.") end
    for _,e in ipairs(rows) do
        local when=ago(now()-e.at)
        local extra=""
        if e.reporter then
            extra=" | reported by "..e.reporter..(e.age and e.age>0 and (" | claimed "..e.age.." s old") or "").." | "..(e.relation=="same" and "same server key as yours" or e.relation=="other" and ("other server key "..tostring(e.reportLayer)) or "layer unknown")
        end
        say((e.name or "Unknown").." | "..(e.class or "Unknown class").." | "..tostring(e.level or "?").." | zone "..tostring(e.zone).." | "..(e.reporter and "received " or "seen ")..when.." ago | "..e.source.." | "..e.confidence..extra..(e.possible and (" | "..e.possible) or ""))
    end
    if kind=="reported" and #rows>0 then say("To go there, ask a reporter for an invite: /le hosts") end
    if kind=="local" then
        local reported=#T.rows(M.store,now(),"reported")
        if reported>0 then say("Reported, not confirmed: "..reported.." more in /le reports") end
    end
    say("Only players seen by you or reported by War Effort users.")
    say("/le window; /le list; /le reports; /le hosts; /le ask <number>; /le find <name>.")
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
    M.npcs=L.new(); M.store=T.new(now()); M.receiver=N.Reports.new(); M.peers=N.Peers.new()
    M.store.ambiguous=function(time) return L.ambiguous(M.npcs,time) end
    M.invite=I.new(); M.wasGrouped=A.grouped()
    M.layerSource="unknown"; M.store.zone=A.location(); M.zoneSeen=M.store.zone
    if not S.tab(LayerEnemiesDB) then LayerEnemiesDB={} end
    -- Configuration only. Sightings and source identities never enter SavedVariables.
    local saved=LayerEnemiesDB
    M.find=N.Find.new(saved.tracked)
    LayerEnemiesDB={options={},tracked=M.find.names,position=N.UI.position(saved.position)}
    if S.tab(C_ChatInfo) then
        S.call(C_ChatInfo.RegisterAddonMessagePrefix,"WEFF1")
    end
    SlashCmdList=SlashCmdList or {}
    _G.SLASH_LAYERENEMIES1="/le"
    SlashCmdList.LAYERENEMIES=function(command)
        local raw=(S.str(command,110) or ""):match("^%s*(.-)%s*$")
        command=raw:lower()
        if command=="find" then M.track(nil); return end
        if command:match("^find%s+") then M.track(raw:match("^%S+%s+(.+)$")); return end
        local index=command:match("^ask%s+(%d%d?)$")
        if command=="" then guarded(N.UI.toggle)
        elseif command=="hosts" then guarded(M.hosts)
        elseif index or command:match("^ask") then guarded(M.askIndex,tonumber(index))
        else guarded(M.text,command) end
    end
    N.UI.create()
    heartbeat()
end
local frame=CreateFrame("Frame")
M.frame=frame
frame:Hide()
for _,event in ipairs({"ADDON_LOADED","PLAYER_LOGIN","PLAYER_ENTERING_WORLD","ZONE_CHANGED_NEW_AREA","ZONE_CHANGED","SHARD_TRANSFER","PLAYER_TARGET_CHANGED","UPDATE_MOUSEOVER_UNIT","NAME_PLATE_UNIT_ADDED","NAME_PLATE_UNIT_REMOVED","CHAT_MSG_ADDON","GROUP_ROSTER_UPDATE"}) do
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
    elseif event=="NAME_PLATE_UNIT_REMOVED" then M.releaseUnit(...)
    elseif event=="GROUP_ROSTER_UPDATE" then guarded(M.groupCheck); guarded(M.inviteTick) end
end
-- Opens the chat box with a whisper for the user to send; never sends it.
function N.AskInvite(name)
    if not M.started then return false end
    local ok,asked=pcall(M.askInvite,name)
    return ok and asked==true
end
if _G.LE==nil then _G.LE=N end
frame:SetScript("OnEvent",function(...) guarded(dispatch,...) end)
