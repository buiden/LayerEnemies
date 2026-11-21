local _, N = ...
local S,A,T,L,I=N.Safe,N.Adapters,N.Store,N.Layer,N.Invite
local M={statusBulo="not installed",statusWE="not installed",pendingUnits={},staleGUIDs={},staleUnits={}}
N.Main=M
M.GROUP_CHANGE_WINDOW,M.CHURN_WINDOW,M.CHURN_CAP=10,600,3
-- Bounded session-only evidence; PR 2 consumes it, no blind behavior here.
M.keyChanges={}
-- Change-detection history only; expiry must never expose this as current data.
local lastConfirmedKey,lastConfirmedNPC
local function recent(at,time) return at and time>=at and time-at<=M.GROUP_CHANGE_WINDOW end
local function groupTransition()
    local grouped,time=S.call(IsInGroup),S.num(S.call(GetTime))
    if type(grouped)=="boolean" then
        if M.groupState~=nil and grouped~=M.groupState then
            M.groupChangedAt=time; N.Trust.excuse(M.store,M.groupChangedAt)
        end
        if grouped and M.groupState~=true then
            M.groupJoinedAt=time; M.groupMembers={}
        elseif not grouped then M.groupJoinedAt=nil; M.groupMembers={} end
        M.groupState=grouped
    end
    local party=A.party()
    local members={}
    if grouped==true and party then
        for _,name in ipairs(party.members or {}) do
            local who=I.key(name)
            if who then members[who]=(M.groupMembers or {})[who] or time end
        end
    end
    M.groupMembers=members
    return party
end
local function now() return S.num(S.call(GetTime)) or 0 end
local function guarded(fn,...)
    local ok=pcall(fn,...)
    if not ok then
        if M.hopAnyStop then pcall(M.hopAnyStop,"API error") end
        if A.whoEnd then pcall(A.whoEnd,"error") end
        M.error="data unavailable (API error)"
    end
end
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
    for i=1,40 do add("nameplate"..i); add("raid"..i.."target") end
    for i=1,4 do add("party"..i.."target") end
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
function M.boundary(zone,zoneChange)
    M.boundaryAt=now(); M.layerKnown=nil; M.layerReadAt=nil
    local previousKey=lastConfirmedKey
    lastConfirmedKey,lastConfirmedNPC=nil,nil
    N.Trust.excuse(M.store,now())
    local prev={}
    if zoneChange==true and zone~=nil and M.store.zone~=nil and zone~=M.store.zone then prev=T.carry(M.store,now()) end
    N.OwnDeath.cancel()
    N.CallUI.check()
    captureStale()
    M.blockedBulo=previousKey
    -- A readable zone that differs from the last readable one ends the zone epoch (own raw id and ambiguity);
    -- otherwise only the votes start again. An unreadable map (a loading screen) is no evidence of a zone change.
    -- Nothing of this is saved: /reload starts without the raw id and without the ambiguity window.
    if zone~=nil and M.zoneSeen~=nil and zone~=M.zoneSeen then
        if M.hopAnyState then M.hopAnyStop("zone changed") end
        if M.auto and M.auto.group and M.auto.group.any then M.clearAutoGroup() end
        L.forget(M.npcs)
        -- a new zone also drops a pending hop or ask (the layer watch ends itself on the zone change, with a note)
        if M.hop then N.Hop.clear(M.hop) end
        M.hopList=nil                                  -- the numbers /le reports showed belong to the old zone
        M.hostList=nil                                 -- and so do those of /le hosts
        if M.invite then
            M.invite.pending=nil
            -- the layer watch ends here too: a quick out-and-back before the next poll must not read as a move
            if M.invite.watch then M.invite.watch=nil; M.say("LayerEnemies: Zone changed - layer check cancelled.") end
        end
    else L.reset(M.npcs) end
    if zone~=nil then M.zoneSeen=zone end
    M.subEpoch=now()
    if M.share then N.Share.cancel(M.share,M.store.localSeen,M.subEpoch) end
    T.reset(M.store,M.subEpoch,zone,nil,nil)
    M.store.prev=prev
    N.Reports.clearPending(M.receiver)
    S.clear(M.pendingUnits)
    M.layerSource="unknown"
    if M.find then N.Find.boundary(M.find) end
end
-- Both own namespaces can change, even when Bulo currently supplies the server key.
function M.keyChanged(time,key,source)
    groupTransition()
    if recent(M.groupChangedAt,time) then M.boundary(M.store.zone); return true end
    if N.Trust.change(M.store,time,key,source)==false then return false end
    -- First learning after a boundary never calls this. Every later confirmed
    -- change outside the group window counts, even just after that boundary.
    for i=#M.keyChanges,1,-1 do
        if time<M.keyChanges[i] or time-M.keyChanges[i]>=M.CHURN_WINDOW then table.remove(M.keyChanges,i) end
    end
    if #M.keyChanges>=M.CHURN_CAP then table.remove(M.keyChanges,1) end
    M.keyChanges[#M.keyChanges+1]=time
    return false
end
function M.applyLayer(id,source)
    if not L.key(id) then return end
    local time=now()
    groupTransition()
    M.layerReadAt=time
    if id==lastConfirmedKey and M.layerSource~="unknown" then
        N.Trust.read(M.store,time,id,M.npcs.current); M.layerSource=source; return
    end
    local uid=M.npcs.current
    if lastConfirmedKey~=nil and lastConfirmedKey~=id then
        if M.keyChanged(time,id,source) then
            if source=="local NPC server id" then
                -- The confirming readings belong to the new side of this crossing.
                M.npcs.current=uid; M.npcs.last=time
            else uid=nil end
        end
    elseif not M.layerKnown then
        T.learn(M.store,time,id,uid)
        N.Reports.clearPending(M.receiver)
    end
    N.Trust.read(M.store,time,id,uid); M.layerSource=source
    lastConfirmedKey=id
    M.layerKnown=true; M.layerReadAt=time
    if M.auto and M.auto.group then guarded(M.autoTick) end
end
-- An unreadable map is not proof of a crossing. Suspend zone-dependent output
-- while keeping observations; compare the next readable map with the last one.
function M.zoneCheck(zone)
    if zone and zone~=M.zoneSeen then M.boundary(zone,true)
    elseif zone~=M.store.zone then M.store.zone=zone end
end
-- Claims are bounded, guild-only and session-only; never a new wire exchange.
M.trustClaims={}
function M.trustClaim(name,key,zone,time)
    local who=I.key(name)
    if not who or A.guildMember(name)~=true then return end
    if not M.trustClaims[who] and S.count(M.trustClaims)>=N.Hosts.MAX then return end
    M.trustClaims[who]={key=L.key(key),zone=zone,at=time}
    M.trustGroup()
end
function M.trustRefresh(rows)
    if M.hopAnyState and M.hopAnyState.round and not N.Trust.own(M.store,now()) then M.hopAnySafe() end
    local notice=N.Trust.notice(M.store,now())
    if notice then M.say(notice) end
    N.Popup.refresh(rows)
end
function M.trustGroup(deferPopup)
    local party=groupTransition()
    local time=now()
    local peer,claim,claimAt,peerJoinedAt
    if S.call(IsInGroup)==true and A.inInstance()==false and party then
        for _,name in ipairs(party.members or {}) do
            local who=I.key(name); local c=who and M.trustClaims[who]
            local joined=who and M.groupMembers[who]
            if c and M.groupJoinedAt and c.at>M.groupJoinedAt and joined and c.at>joined
                and time>=c.at and time-c.at<N.Trust.EXPIRE and c.zone==M.store.zone
                and A.guildMember(name)==true and c.key and c.key~=L.key(N.Trust.own(M.store,time))
                and (not peer or who<peer) then peer,claim,claimAt,peerJoinedAt=who,c.key,c.at,joined end
        end
    end
    N.Trust.group(M.store,time,peer,claim,peer~=nil,M.groupJoinedAt,claimAt,peerJoinedAt)
    if not deferPopup then M.trustRefresh() end
end
function M.poll()
    if not M.started then return end
    local time=now()
    local zone=A.location()
    M.zoneCheck(zone)
    L.expire(M.npcs,time)
    if not M.npcs.current then M.store.zoneUID=nil end
    if M.layerSource=="local NPC server id" and not M.npcs.current then
        N.Trust.read(M.store,time,nil,nil); M.layerSource="unknown"
    end
    local snap=A.bulo(M.store.epoch,time,M.store.localSeen)
    M.statusBulo=snap.status
    if snap.ns and M.attemptedNS~=snap.ns then
        M.attemptedNS=snap.ns
        M.bus=A.buloSubscribe(snap.ns,function(event)
            if M.attemptedNS~=snap.ns then return end
            -- Donor raw-id notifications alone are not client transfer events.
            M.queuePoll()
        end)
    end
    local id=N.Trust.bulo(snap,M.blockedBulo,M.npcs)
    if id then M.applyLayer(id,"Bulo server id")
    elseif M.layerSource=="Bulo server id" and M.layerReadAt and time-M.layerReadAt>=L.EXPIRE then
        N.Trust.read(M.store,time,nil,nil); M.layerSource="unknown"
    end
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
    M.trustGroup(true)
    T.prune(M.store,time); N.Reports.prune(M.receiver,time)
    -- War Effort itself is not needed: its guild and group traffic is read either way.
    M.statusWE=(A.loaded("WarEffortScout") and "installed" or "not installed").." / listening on guild, party and raid (reported, not confirmed)"
    if M.lastHeard then M.statusWE=M.statusWE.." / last heard "..math.floor(time-M.lastHeard).." s ago" end
    M.groupCheck(true); M.inviteTick(); M.watchTick(); M.friendShareTick(); M.relayTick(); M.autoTick(); M.shareTick(); M.weTick(); M.embassyTick(); M.hhTick()
    N.Directory.sync()
    N.Find.home(M.find,M.homeRealm())
    N.Known.prune(M.find.known,time)
    M.presenceScan()
    N.Overlord.sweep(M.overlord,time)
    N.Overlord.rows(M.overlord,time)
    N.Sources.tick(time)
    local rows=M.findAlerts()
    M.trustRefresh(rows)
    N.CallUI.check()
    if N.UI then N.UI.refresh() end
end
function M.queuePoll()
    if M.pollQueued then return end
    M.pollQueued=true
    if not after(0,function() M.pollQueued=false; guarded(M.poll) end) then M.pollQueued=false; guarded(M.poll) end
end
-- These helpers receive only secret-checked strings. Visibility is of the member,
-- not a promise that a remote target can be read; A.unit still guards every field.
local function groupMember(unit)
    if unit:match("^party[1-4]$") then return unit end
    local index=tonumber(unit:match("^raid([1-9]%d?)$"))
    if index and index<=40 then return unit end
end
local function targetMember(unit)
    local member=unit:match("^(.-)target$")
    return member and groupMember(member)
end
local function groupReadable(member)
    return A.inInstance()==false and S.call(UnitIsVisible,member)==true
        and S.call(UnitExists,member)==true and S.call(UnitIsUnit,member,"player")==false
end
function M.queueGroupTarget(unit)
    unit=S.str(unit,30)
    if unit and groupMember(unit) then M.queueUnit(unit.."target") end
end
function M.observe(unit)
    unit=S.str(unit,30); if not unit then return end
    local member=targetMember(unit)
    if member and not groupReadable(member) then return end
    local time=now()
    local zone,x,y=A.location()
    M.zoneCheck(zone)
    local guid=S.str(S.call(UnitGUID,unit),160)
    if not guid or M.staleGUIDs[guid] then return end
    local npc,_,observedKey=L.npc(guid)
    if (guid:match("^Creature%-") or guid:match("^Vehicle%-")) and S.call(UnitPlayerControlled,unit)==false then
        N.Trust.creature(M.store,npc~=nil)
        if not npc then return end
        local previous=lastConfirmedNPC or lastConfirmedKey
        local value,old,raw=L.observe(M.npcs,guid,time)
        if M.layerSource=="local NPC server id" and M.npcs.current and observedKey==lastConfirmedKey then
            N.Trust.read(M.store,time,lastConfirmedKey,M.npcs.current)
        end
        if value then
            if raw and lastConfirmedKey and M.layerSource~="unknown" and M.layerSource~="local NPC server id" and previous and previous~=raw then
                if M.keyChanged(time,raw,"local NPC server id") then M.npcs.current=value; M.npcs.last=time end
            end
            if raw then lastConfirmedNPC=raw end
            M.store.zoneUID=value
            if raw and (M.layerSource=="unknown" or M.layerSource=="local NPC server id") then M.applyLayer(raw,"local NPC server id") end
        end
        if M.npcs.current and M.npcs.raw==observedKey then N.Trust.npc(M.store,time,observedKey) end
        return
    end
    local e=A.unit(unit)
    if not e then return end
    e.at=time; e.source=member and "own (party target)" or "own "..unit; e.x=x; e.y=y; e.positionKind="approximate observer position"
    T.observe(M.store,e,time)
    N.Find.own(M.find,e,zone,time)
    M.watchNotice(e)
end
function M.queueUnit(unit)
    unit=S.str(unit,30); if not unit then return end
    local member=targetMember(unit)
    if not (unit=="target" or unit=="mouseover" or unit:match("^nameplate%d+$") or member) then return end
    if member and not groupReadable(member) then return end
    if M.staleUnits[unit] and S.str(S.call(UnitGUID,unit),160)~=M.staleUnits[unit] then M.releaseUnit(unit) end
    if S.count(M.pendingUnits)>=86 then return end
    local expected=member and S.str(S.call(UnitGUID,unit),160) or not member
    if not expected then return end
    M.pendingUnits[unit]=expected
    if M.unitsQueued then return end
    M.unitsQueued=true
    local function run()
        M.unitsQueued=false
        for token,expected in pairs(M.pendingUnits) do
            M.pendingUnits[token]=nil
            -- Group tokens can retarget before the queue drains. Only a new event
            -- may replace the queued GUID; all other readability guards run again.
            if expected==true or (S.str(token,30) and S.str(S.call(UnitGUID,token),160)==expected) then guarded(M.observe,token) end
        end
        M.queuePoll()
    end
    if not after(0,run) then run() end
end
-- Our own character, with or without a realm (compared the way the receive policy compares senders).
-- Ourselves, by the one name rule (Invite.name keys: our realm dropped, any other realm is someone else).
function M.isMe(name)
    local _,key=I.name(name)
    local _,me=A.ownIdentity()
    return key~=nil and me~=nil and key==me
end
-- A kill cannot identify its victim or our own character as the killer.
-- Use the same whole-name identity on both direct and guild ingress.
function M.validKill(record)
    local enemy=record.enemies[1]
    local _,killer=I.name(enemy and enemy.name)
    return killer~=nil and killer~=record.okey and not M.isMe(enemy.name)
end
-- Preserve origin age and provenance before the zone-only store can reject a record.
function M.findRecord(record)
    record=N.Trust.record(M.store,record,now())
    if N.Record.isKill(record) then
        if not N.Relay.acceptKill(M.relay,record,now()) then return end
        local _,viaKey=I.name(record.via)
        local indirect=record.src=="guild" or viaKey~=record.okey
        N.Find.report(M.find,{sender=record.origin,zone=record.zone,at=record.at,now=now(),enemies=record.enemies,
            source=record.src=="hh" and "headhunter" or "relayed",kind="claim",relayed=indirect,
            x=record.x,y=record.y,pos="victim",ns="unknown",
            detail="killed "..record.origin.." · victim-reported"..(indirect and " · via relay" or "")
                ..(record.kind=="killi" and " (inferred)" or "")},M.homeRealm())
        return
    end
    local source=record.src=="le" and "guild" or record.kind=="death" and "death"
        or record.hand=="relayed" and "relayed" or record.src=="hh" and "headhunter" or "spy"
    local layer=source=="guild" and record.layer.ns=="server" and record.layer.value or nil
    N.Find.report(M.find,{sender=record.origin,zone=record.zone,at=(record.src=="we" or record.src=="hh") and record.heard or record.at,
        now=now(),enemies=record.enemies,source=source,x=record.x,y=record.y,pos=record.pos,
        layer=layer,ns=layer and "server" or "unknown",relayed=record.hand=="relayed"},M.homeRealm())
end
function M.message(prefix,text,kind,sender,target,zoneChannelID,localID,channelName)
    -- Check every delivered value before comparing/indexing it.
    local args={prefix,text,kind,sender,target,zoneChannelID,localID,channelName}
    for i=1,8 do if S.secret(args[i]) then return end end
    if N.Sources.owns(prefix) then return N.Sources.addon(prefix,text,kind,sender) end
    if prefix=="OverlordF" then return M.overlordIn(text,kind,sender) end
    if prefix=="OpenMapLoc" then return M.openmapIn(text,kind,sender) end
    if prefix=="HeadHunter" then return M.headhunter(text,kind,sender) end
    if prefix=="LayerSwap" then return M.layerswap(text,kind,sender) end
    if prefix=="FLHNET2" then return M.flhIn(text,kind,sender) end
    if prefix=="LFSw" then return M.lfsw(text,kind,sender) end
    if prefix=="LEGW1" then return M.relayIn(text,kind,sender) end
    if N.Spy.SRC[prefix] or N.Incident.SRC[prefix] then return M.spyIn(prefix,text,kind,sender) end
    if prefix~="WEFF1" or type(text)~="string" or #text>255 or not S.str(sender,100) then return end
    local allowed,reason=A.policy(prefix,kind,sender)
    if not allowed then M.lastDrop=reason; return end
    local msg,why=N.Protocol.decode(text)
    if not msg then if why~="ignored" then M.lastDrop="invalid message" end; return end
    if not A.WE_TYPES[kind][msg.type] then M.lastDrop=msg.type.." is not read on "..kind; return end
    local time=now()
    -- Over the per-sender limit: dropped without a note.
    if not N.Reports.allow(M.receiver,sender,msg.type=="G" or msg.type=="X" or msg.type=="W",time) then return end
    -- guildmates heard on the guild (lane A3: who may hold embassies, whose reports may be forwarded)
    if kind=="GUILD" and not M.isMe(sender) then M.weGuildHeard(sender,msg,time) end
    -- a War Effort reader heard on this route (its hello): our C and E may go there for 600 s (lane A1)
    if msg.type=="H" and (kind=="GUILD" or kind=="PARTY" or kind=="RAID") and not M.isMe(sender) then M.weHeard[kind]=time end
    local inner,origin=msg.inner or msg,msg.origin or sender
    if msg.origin then
        if M.isMe(origin) then M.lastDrop="own echo"; return end
        -- a wrapper carries someone else's message; one naming its own sender is refused (as War Effort does)
        -- same name: equal in full, or equal without realm when one of the two carries none
        local function bare(n) return (n:match("^([^%-]+)") or n):lower() end
        local whole=origin:lower()==sender:lower()
        local partial=(not origin:find("-",1,true) or not sender:find("-",1,true)) and bare(origin)==bare(sender)
        if whole or partial then M.lastDrop="wrapped by its own origin"; return end
        local ignored,whyIgnored=A.ignored(origin)
        if ignored then M.lastDrop=whyIgnored; return end
    end
    M.lastHeard=time
    if msg.type=="P" or msg.type=="D" or msg.type=="W" then return M.embassyIn(msg,kind,sender,time) end
    -- a guildmate's own C, E or H on the guild: to our embassy partners (if their hello said public)
    if kind=="GUILD" and not msg.origin and (inner.type=="C" or inner.type=="E" or inner.type=="H") then M.embassyForward(sender,inner,text,time,true) end
    if inner.type=="H" then N.Peers.hello(M.peers,origin,inner.minor,time); return end
    if inner.type=="Q" or inner.type=="Y" or inner.type=="J" then return M.weAsked(inner,kind,sender,time) end
    local record
    record,why=N.Reports.receive(M.receiver,msg,{sender=sender,route=kind,now=time,
        serverNow=S.num(S.call(GetServerTime)),zoneFn=A.zone,peers=M.peers})
    M.lastDrop=why
    if record then
        local stored,whyNot=T.report(M.store,record,time)
        if not stored then M.lastDrop=whyNot end
        if why=="new" then M.offerRelay(record) end
        M.findRecord(record)
        M.findAlerts()
        if N.UI then N.UI.refresh() end
    end
end
-- Presence is never a sighting, reporter, host or outgoing work item.
local function presenceSafe()
    return M.find and (#M.find.names>0 or M.friendSendable()) and not A.inCombat() and A.inInstance()==false
end
local function presenceRefusal(stats,reason)
    if reason=="secret" then stats.refused=stats.refused+1; stats.secret=true
    elseif type(reason)=="number" and reason>0 then stats.refused=stats.refused+reason; stats.secret=true end
end
local function presenceSharedSweep(time)
    for hash,r in pairs(M.presenceShared) do
        local _,_,_,senders=N.Watch.match(M.watch,r.name,time)
        if time-r.at>=N.Presence.TTL or time<r.at or #senders==0 then
            M.presenceShared[hash]=nil
        end
    end
    -- Withdrawal removes names immediately, but cannot re-arm a hash's notice.
    for hash,at in pairs(M.presenceSharedAlerts.presenceAlerts) do
        if time<at or time-at>=600 then M.presenceSharedAlerts.presenceAlerts[hash]=nil end
    end
end
local function presenceMember(job,member,route,source)
    N.Presence.forget(M.find.presence,source)
    N.Presence.forget(M.presenceShared,source)
    if not member then return end
    local sender=member.name
    if route=="friend" or route=="community" then sender=N.OpenMap.bnName(member.name,member.realm) end
    if not sender then return end
    if route=="community" then
        job.stats.resolved=job.stats.resolved+1
        if member.zone then job.stats.zones=job.stats.zones+1 end
    end
    local record=N.Presence.accept(member,route)
    if not record or N.OpenMap.faction(record.faction,S.call(UnitFactionGroup,"player"))~="opposite" then return end
    if route=="community" then job.stats.opposite=job.stats.opposite+1 end
    local _,me=A.ownIdentity()
    local own=S.str(S.call(UnitGUID,"player"),120)
    if job.share and not (own and record.guid==own) then
        local display,key=I.name(sender)
        if key and key~=me then
            job.share[key]={name=display,zone=record.zone,faction=record.faction,class=record.class,level=record.level,guid=record.guid}
        end
    end
    local name=N.OpenMap.match(M.find,sender,me,true)
    local shared
    if not name then
        -- Guild lists carry base-name hashes, not full identities: label these
        -- possible matches, and never promote them into the saved personal list.
        local _,_,hash,senders=N.Watch.match(M.watch,sender,now())
        if not senders or #senders==0 or not N.OpenMap.match({names={sender}},sender,me) then return end
        name,shared=sender,hash
    end
    if own and record.guid==own then return end
    record.source=source
    local alerts,key=M.find,name
    if shared then
        record.name,record.at=name,now()
        M.presenceShared[shared]=record -- one current character per shared hash
        alerts,key=M.presenceSharedAlerts,shared
    else N.Presence.note(M.find,name,record,now()) end
    job.stats.matches=job.stats.matches+1
    if N.Find.alert(alerts,{name=key},now(),true) then
        M.findNotice(name.." — "..M.presenceText({zone=record.zone,route=route,age=0,guildTracked=shared~=nil}))
    end
end
local function presenceStep(job)
    if M.presenceJob~=job then return end
    if not presenceSafe() then M.presenceJob=nil; return end
    local budget=N.Presence.STEP
    while budget>0 and job.clubs[job.club] do
        local club=job.clubs[job.club]
        if not job.ids then
            local ids,why=A.clubMemberIds(club.id)
            presenceRefusal(job.stats,why)
            job.ids=ids or {}; job.member=1
            if ids then job.stats.clubs=job.stats.clubs+1 end
        end
        local id=job.ids[job.member]
        if id==nil then job.ids=nil; job.club=job.club+1
        else
            job.member=job.member+1; budget=budget-1
            local member,why=A.clubMember(club.id,id)
            job.stats.members=job.stats.members+1; presenceRefusal(job.stats,why)
            presenceMember(job,member,"community","c:"..#tostring(club.id)..":"..club.id..":"..id)
        end
    end
    if job.clubs[job.club] then
        if not after(.001,function() presenceStep(job) end) then M.presenceJob=nil end
        return
    end
    local friends,why=A.bnFriends()
    presenceRefusal(job.stats,why)
    for _,member in ipairs(friends or {}) do presenceMember(job,member,"friend","f:"..member.index) end
    M.presenceJob=nil
    -- a complete scan: what we see now goes to the guild (changes, or everything every 5 minutes)
    if job.share then M.friendShareFlush(job.share) end
    if N.UI then N.UI.refresh() end
end
function M.presenceScan(force)
    if not presenceSafe() then M.presenceJob=nil; return end
    if M.presenceJob then return end
    local time=now()
    N.Presence.sweep(M.find,time)
    presenceSharedSweep(time)
    if not force and M.presenceAt and time>=M.presenceAt and time-M.presenceAt<N.Presence.EVERY then return end
    M.presenceAt=time
    local stats={clubs=0,members=0,resolved=0,zones=0,opposite=0,matches=0,refused=0,secret=false}
    M.presenceStats=stats
    local clubs,why=A.clubs(); presenceRefusal(stats,why)
    local job={clubs=clubs or {},club=1,stats=stats,share=M.friendSendable() and {} or nil}
    M.presenceJob=job
    if not after(.001,function() presenceStep(job) end) then M.presenceJob=nil; return end
    return true
end
-- Tab changes and window reopens share one allowance, independent of rendering.
function M.presenceOpen()
    local time=now()
    if M.presenceOpenAt and time-M.presenceOpenAt<N.Presence.OPEN then return end
    if M.presenceScan(true) then M.presenceOpenAt=time end
end
function M.presenceStatus()
    local s=M.presenceStats or {clubs=0,members=0,resolved=0,zones=0,opposite=0,matches=0,refused=0}
    M.say("LayerEnemies presence: clubs read: "..s.clubs..", community members read: "..s.members
        ..", resolved to a character: "..s.resolved..", with a zone: "..s.zones..", opposite faction: "..s.opposite
        ..", matches: "..s.matches.." (all sources), secret: "..(s.secret and "yes" or "no")
        ..", refusals: "..s.refused..".")
end
-- Overlord evidence never enters relay/host paths; C2/C3 own sends are gated below.
local function overlordZone(map)
    if not map then return nil end
    if S.secret(C_Map) then return false end
    if not S.tab(C_Map) then return nil end
    local lookup=C_Map.GetMapInfo
    if S.secret(lookup) then return false end
    if type(lookup)~="function" then return nil end
    local refused,label=false,nil
    -- A.zone deliberately conflates unavailable and secret data. This lane must
    -- distinguish them: unavailable means place unknown, secret means skip row.
    local zone=L.zone(map,function(id)
        local ok,info=pcall(lookup,id)
        if not ok or S.secret(info) then refused=true; return nil end
        if not S.tab(info) then return nil end
        local read,name,kind,parent=pcall(function() return info.name,info.mapType,info.parentMapID end)
        if not read or S.secret(name) or S.secret(kind) or S.secret(parent) then
            refused=true; return nil
        end
        label=S.str(name,120)
        return {mapType=S.num(kind),parentMapID=S.num(parent)}
    end)
    if refused then return false end
    if zone and label then return zone,label end
end
function M.overlordPool()
    return S.call(function()
        local G,E=_G.C_GameRules,_G.Enum
        local hc,rp,pvp
        if S.tab(G) and S.tab(E) and S.tab(E.GameRule) then
            local function read(rule)
                if S.secret(rule) or rule==nil then return nil end
                local value=S.call(G.IsGameRuleActive,rule)
                if type(value)=="boolean" then return value end
            end
            hc=read(E.GameRule.HardcoreRuleset); rp=read(E.GameRule.RPRuleset); pvp=read(E.GameRule.PvPRuleset)
        end
        return N.Overlord.pool(S.call(GetRealmName),hc,rp,pvp)
    end)
end
local overlordSend
function M.overlordContext(time)
    local ok=N.Net.allowed("overlord","public")
    local me=A.ownIdentity()
    local version=S.call(function() return C_AddOns.GetAddOnMetadata("LayerEnemies","Version") end)
    local faction=S.str(S.call(UnitFactionGroup,"player"),16)
    local c={now=time or S.num(S.call(GetTime)),wall=S.num(S.call(GetServerTime)),pool=M.overlordPool(),
        me=me,version=S.str(version,32),faction=faction and faction:sub(1,1),
        allowed=not M.overlordClosing and M.sharing() and N.Net.consent()=="public" and N.Net.switch("overlord")
            and ok==true and not A.inCombat() and A.inInstance()==false,
        own=ok==true,online=N.BNet.who,offer=N.Sources.offer,tracked=function(name)
            local _,_,_,watchers=N.Watch.match(M.watch,name,now())
            return N.Find.tracked(M.find,name) or #(watchers or {})>0
        end}
    c.stopPaused=A.inCombat() or A.inInstance()~=false
    c.stopQueued=function(row) return N.BNet.pending("overlord",row.text) end
    c.stopAllowed=N.Net.SHIP.overlord==true and not A.loaded("Overlord")
        and not c.stopPaused
    if c.allowed and c.pool then
        c.guild=S.call(IsInGuild)==true
        c.group=S.call(IsInRaid)==true and "RAID" or S.call(IsInGroup)==true and "PARTY" or nil
        c.groups=A.groupNames()
        c.guildNames=S.call(IsInGuild)==false and {} or A.guildNames(A.peerIdentity)
        c.friends=N.BNet.peers(c.now)
    end
    c.send=overlordSend -- prepare can cancel from a queued-send guard, not only the tick.
    return c
end
-- Only exact outstanding withdrawal bytes may cross closed privacy switches.
-- Hardware gates and real-Overlord stand-down still apply, at every dispatch.
function M.overlordStopping(text,route,target)
    local st=M.overlordFeed
    if not st then return false end
    local c=M.overlordContext()
    if not c.stopAllowed or not c.pool or not c.me or not c.now then return false end
    for _,s in pairs(st.stops) do
        if s.text==text and s.pool==c.pool and s.me==c.me and c.now>=s.at and s.safeAt and c.now-s.safeAt<=60
            and ((route=="BNET" and s.id==target) or (route=="WHISPER" and s.name==target and not s.id)) then return true end
    end
    return false
end
overlordSend=function(c,text,route,target,prio,job)
    local P=N.OverlordPeer
    local function guard()
        if route=="BNET" and job.name then
            local who=N.BNet.who(target)
            if not who or P.key(who.name)~=P.key(job.name) then return false end
        end
        local live=M.overlordContext()
        if job.kind=="HR" and route=="BNET" then live.friends=N.BNet.peers(live.now) end
        return P.claim(M.overlordPeer,job,live)
    end
    local function sent()
        local live=M.overlordContext()
        if job.kind=="HR" and route=="BNET" then live.friends=N.BNet.peers(live.now) end
        P.sent(M.overlordPeer,job,live)
    end
    if route=="BNET" then return N.BNet.send("overlord",target,"OverlordF",text,prio,nil,nil,function(ok) if ok then sent() end end,guard) end
    local live=M.overlordContext()
    if not P.claim(M.overlordPeer,job,live,true) then return false end
    local ok,_,attempted=N.Wire.send("OverlordF",text,route,target,{net="overlord",prio=prio=="owed" and "owed" or "mesh"})
    if attempted then P.claim(M.overlordPeer,job,live) end
    N.Sources.count("overlord",ok and "sent" or "refused")
    if ok then sent() end
    return ok,attempted
end
function M.overlordCancel()
    if M.overlordFeed then
        local c=M.overlordContext();c.send=overlordSend
        N.OverlordFeed.cancel(M.overlordFeed,M.overlordPeer,c)
    end
end
function M.overlordTick(time)
    if not M.overlordPeer then return end
    local c=M.overlordContext(time);c.send=overlordSend
    if not M.overlordFeed then M.overlordFeed=N.OverlordFeed.new() end
    M.overlordPeer.feed=M.overlordFeed
    if not c.allowed or not c.pool then N.OverlordFeed.cancel(M.overlordFeed,M.overlordPeer,c);return end
    N.OverlordFeed.prepare(M.overlordFeed,M.overlordPeer,c)
    c.guild=S.call(IsInGuild)==true
    c.group=S.call(IsInRaid)==true and "RAID" or S.call(IsInGroup)==true and "PARTY" or nil
    if c.own then c.friends=N.BNet.peers(time);c.directory=N.Directory.members("overlord") end
    N.OverlordPeer.tick(M.overlordPeer,c)
    N.OverlordFeed.tick(M.overlordFeed,M.overlordPeer,c)
end
local function overlordReceive(text,kind,sender,account)
    local Ov=N.Overlord
    if not M.overlord or S.secret(kind) or S.secret(text) or S.secret(sender) then return end
    if kind~="GUILD" and kind~="PARTY" and kind~="RAID" and kind~="WHISPER" and kind~="BNET" then return end
    if not N.Net.switch("overlord") then return end
    local stats=M.overlord.stats; stats.lines=stats.lines+1
    local function refuse() stats.refused=stats.refused+1 end
    if A.inCombat() or A.inInstance()~=false then return refuse() end
    local pool=M.overlordPool()
    if not pool then return refuse() end
    local name,_,canonical=I.name(sender)
    if not name or M.isMe(name) or A.ignored(name) then return refuse() end
    local wall=S.num(S.call(GetServerTime)); local time=S.num(S.call(GetTime))
    if not wall or not time then return refuse() end
    if type(text)~="string" or #text>(kind=="BNET" and 4096 or 255) then return refuse() end
    if not Ov.admit(M.overlord,canonical,time,#text,kind,account) then return refuse() end
    N.Sources.count("overlord","heard")
    local me=A.ownIdentity()
    if not me then return refuse() end
    local p,id
    if text:sub(1,3)=="BF:" then
        local wire
        wire,id=Ov.fragment(M.overlord,text,canonical,time,kind)
        if wire==nil then return end
        if wire==false then return refuse() end
        p=Ov.packet(wire,id,canonical,wall,me)
        if p and p.pool~=pool then return refuse() end
    elseif kind=="BNET" and text:sub(1,3)=="BR:" then
        local wire=text:sub(4);id=wire:match("^[^|]*|([^|]*)|")
        p=Ov.packet(wire,id,canonical,wall,me)
        if p and p.pool~=pool then return refuse() end
    elseif kind=="PARTY" or kind=="RAID" then
        p=Ov.direct(text)
        if p then p.origin=canonical end
    end
    if not p then return refuse() end
    if id then
        local c=M.overlordContext(time);c.send=overlordSend
        if p.kind~="GW" and p.kind~="GD" then
            if Ov.seen(M.overlord,p.origin,id) then return end
            if not M.overlordFeed then M.overlordFeed=N.OverlordFeed.new() end
            M.overlordPeer.feed=M.overlordFeed
            local r=N.OverlordPeer.receive(M.overlordPeer,p,kind,canonical,account,c)
            N.OverlordFeed.observe(M.overlordFeed,M.overlordPeer,p,r,c)
            if p.kind=="HB" or p.kind=="HA" then
                c.friends=N.BNet.peers(time)
                N.OverlordFeed.receive(M.overlordFeed,M.overlordPeer,p,r,c)
            end
            return
        end
        -- Evidence validation below owns dedupe; invalid map reads remain retryable.
        N.OverlordPeer.receive(M.overlordPeer,p,kind,canonical,account,c)
    end
    if p.kind=="GW" then
        local g=Ov.gw(p.payload,wall)
        local own=S.str(S.call(UnitFactionGroup,"player"),20)
        if not g or (own~="Alliance" and own~="Horde") or g.faction==own:sub(1,1) then return refuse() end
        g.zone,g.zoneName=overlordZone(g.map)
        if g.zone==false then return refuse() end
        if id and Ov.seen(M.overlord,p.origin,id) then return end
        if N.Trust.state(M.store,time)=="blind" then g.layer=nil end
        Ov.rampage(M.overlord,g,time,wall)
    else
        local d=p.kind=="GD" and Ov.gd(p.payload) or p.kind=="EK" and Ov.ek(p.payload)
        if d and p.kind=="GD" and d.pool~=pool then return refuse() end
        if not d or M.isMe(d.killer) then return refuse() end
        -- GD carries the General's claim time, not a death timestamp. Keep that
        -- conservative age; the relay envelope is independently limited to 120 s.
        if d.ts-wall>30 or (p.kind=="EK" and wall-d.ts>120) or wall-d.ts>=N.Known.TTL then return refuse() end
        local _,_,_,watchers=N.Watch.match(M.watch,d.killer,time)
        if not N.Find.tracked(M.find,d.killer) and #watchers==0 then return refuse() end
        local zone=overlordZone(d.map)
        if zone==false then return refuse() end
        if id and Ov.seen(M.overlord,p.origin,id) then return end
        N.Find.report(M.find,{sender=p.origin,zone=zone,at=time-math.max(0,wall-d.ts),now=time,
            enemies={{name=d.killer,class=d.class}},source="overlord",kind="claim",relayed=true,
            detail="named as killer (claim)"},M.homeRealm())
    end
    stats.taken=stats.taken+1
    if N.UI then N.UI.refresh() end
end
function M.overlordIn(text,kind,sender)
    -- Optional map/ignore/identity APIs can throw on access as well as on call.
    -- Unlike the general event guard, a refused foreign line never changes runtime status.
    local ok=pcall(overlordReceive,text,kind,sender)
    if not ok and M.overlord then M.overlord.stats.refused=M.overlord.stats.refused+1 end
end
function M.overlordBn(prefix,text,channel,id)
    local ok=pcall(function()
        if not S.str(prefix,16) or prefix~="OverlordF" or S.secret(text) or type(text)~="string" or #text>4096
            or not S.num(id) or id<1 or id%1~=0 or S.secret(channel) then return end
        local pool,side,body=text:match("^R2:Forever_([a-z]+)_([AH]):(.*)$")
        if not pool or pool~=M.overlordPool() then return end
        local who=N.BNet.who(id)
        if not who or who.faction:sub(1,1)~=side then return end
        overlordReceive(body,"BNET",who.name,id)
    end)
    if not ok and M.overlord then M.overlord.stats.refused=M.overlord.stats.refused+1 end
end
function M.overlordText(g)
    return "guild "..g.guild..": "..g.kills.." kills by "..g.members.." in "..(g.zoneName or "place unknown")
        ..(N.Trust.own(M.store,now()) and (", "..(g.layer and ("layer "..g.layer) or "layer unknown")) or "").." (Overlord claim)"
end
-- 1.2.3 names in Reported, display only and computed on every call: nothing here is stored or saved.
-- A guildmate's own LayerEnemies sighting (src "le") carries the real name: it is certain, and when that player is
-- one of our live "Seen by you" rows the report merges into the row ("also reported by"). Donor names (HeadHunter,
-- Spy family) are shown as claimed. A hash-only enemy (War Effort, or a report without a name) is matched against
-- every name known this session; a match is a guess, so it reads "probably <Name>" and never merges.
local NAMES_SHOWN=2
local function classOf(token) return type(token)=="string" and token~="" and token or nil end
local function identityKey(name) local _,key=I.name(name); return key end
-- Find.hashes per (name, home realm) is pure, so it is cached for the session; the window redraws often and the
-- Known store holds up to 300 names. Bounded: the cache is dropped and rebuilt past HASH_CACHE_MAX entries.
local HASH_CACHE_MAX=2000
local hashCache,hashCacheSize={},0
M.hashStats={calls=0,hits=0}
local function cachedHashes(label,home)
    local k=label.."\0"..(home or "")
    local v=hashCache[k]
    if v then M.hashStats.hits=M.hashStats.hits+1; return v end
    if hashCacheSize>=HASH_CACHE_MAX then hashCache,hashCacheSize={},0 end
    M.hashStats.calls=M.hashStats.calls+1
    v=N.Find.hashes(label,home); hashCache[k]=v; hashCacheSize=hashCacheSize+1
    return v
end
-- Display only: a reported or donor name is clamped so a long name cannot blow up the row title. Byte-safe for
-- UTF-8: the cut never lands inside a multibyte character.
local NAME_SHOWN_MAX=48
function M.displayName(label)
    if type(label)~="string" or #label<=NAME_SHOWN_MAX then return label end
    local cut=NAME_SHOWN_MAX-1
    while cut>0 and label:byte(cut+1) and label:byte(cut+1)>=128 and label:byte(cut+1)<192 do cut=cut-1 end
    return label:sub(1,cut).."…"
end
local function knownNames(seen,reports)
    local byHash,byKey={},{}
    local home=M.find and M.find.home or S.str(S.call(GetRealmName))
    local function add(label,class,level,live)
        label=S.str(label,100); if not label then return end
        local key=N.Find.fold(label); if not key or key=="" then return end
        local c=byKey[key]
        if c then
            c.class=c.class or classOf(class); c.level=c.level or S.num(level); c.live=c.live or live
            return
        end
        c={label=label,class=classOf(class),level=S.num(level),live=live}; byKey[key]=c
        for hash in pairs(cachedHashes(label,home)) do
            local bucket=byHash[hash]; if not bucket then bucket={}; byHash[hash]=bucket end
            bucket[#bucket+1]=c
        end
    end
    for _,e in ipairs(seen) do add(e.displayName or e.name,e.class,e.level,true) end
    for _,e in ipairs(T.previous(M.store,now())) do add(e.displayName or e.name,e.class,e.level,false) end
    if M.find then
        for _,name in ipairs(M.find.names or {}) do add(name) end
        for _,p in pairs(M.find.known and M.find.known.entries or {}) do
            for _,slot in ipairs({"own","seen","reported"}) do local e=p[slot]; if S.tab(e) then add(e.name,e.class,e.level,false) end end
        end
    end
    for _,r in ipairs(reports) do if r.named then add(r.name,r.class,r.level,false) end end
    if M.friendIn then for _,r in pairs(M.friendIn.items) do add(r.name,r.class,r.level,false) end end
    return byHash
end
-- Candidates for one hash: a different known class rules a name out; level only breaks a remaining tie.
local function probable(byHash,e)
    local all=byHash[e.hash] or {}
    local out={}
    for _,c in ipairs(all) do if not (e.class and c.class and e.class~=c.class) then out[#out+1]=c end end
    if #out>1 and e.level then
        -- only a known, different level drops a name, and only when some name has the reported level
        local keep,match={},false
        for _,c in ipairs(out) do
            if c.level==e.level then match=true end
            if c.level==nil or c.level==e.level then keep[#keep+1]=c end
        end
        if match then out=keep end
    end
    table.sort(out,function(a,b) if a.live~=b.live then return a.live==true end; return N.Find.fold(a.label)<N.Find.fold(b.label) end)
    return out
end
function M.probablyText(list)
    local names={}
    for i=1,math.min(#list,NAMES_SHOWN) do names[i]=M.displayName(list[i].label) end
    local text="probably "..table.concat(names," or ")
    if #list>NAMES_SHOWN then text=text.." +"..(#list-NAMES_SHOWN) end
    return text
end
-- namedRows(seen) -> seen rows (copies, with alsoReported) and reported rows (titles, probable names, merges done)
function M.namedRows(seen)
    local time=now()
    seen=seen or T.rows(M.store,time,"local")
    local raw=T.rows(M.store,time,"reported")
    local liveByKey,copies={},{}
    for i,e in ipairs(seen) do
        local c={}; for k,v in pairs(e) do c[k]=v end
        copies[i]=c
        local key=identityKey(e.displayName or e.name); if key then liveByKey[key]=c end
    end
    for _,r in ipairs(raw) do
        local rest=type(r.key)=="string" and r.key:sub(-5)==":rest"
        r.named=not rest and r.name~=nil and r.name~="Unknown" and r.record and r.record.src~="guild" or nil
    end
    local byHash=knownNames(seen,raw)
    local out={}
    for _,r in ipairs(raw) do
        local rest=type(r.key)=="string" and r.key:sub(-5)==":rest"
        local merged=false
        if r.named and r.record.src=="le" then
            r.certain=true; r.title=M.displayName(r.name)
            local live=liveByKey[identityKey(r.name)]
            if live then
                live.alsoReported=live.alsoReported or {}
                local list=live.alsoReported
                local dup=false; for _,who in ipairs(list) do if who==r.reporter then dup=true end end
                if not dup then list[#list+1]=r.reporter end
                merged=true
            end
        elseif r.named then
            r.title=M.displayName(r.name) -- as the donor claims it; the source line says which network
        elseif not rest and r.hash then
            local list=probable(byHash,r)
            if #list>0 then
                r.probably=list; r.title=M.probablyText(list)
                if list[1].live and #list==1 then r.probablyNote="probably the "..M.displayName(list[1].label).." you see" end
            end
        end
        if not merged then out[#out+1]=r end
    end
    for _,g in ipairs(N.Overlord.rows(M.overlord,time)) do out[#out+1]=g end
    -- 1.2.4: a guildmate's Battle.net friend or community member is a certain name, zone only, no Hop
    if M.friendIn then
        for _,r in ipairs(N.FriendShare.rows(M.friendIn,time)) do
            out[#out+1]={friendShare=true,certain=true,name=r.name,title=M.displayName(r.name),class=r.class,level=r.level,
                zone=r.zone,reporter=r.sender,at=r.at,guid=r.guid,sourceText="Battle.net friend of "..r.sender}
        end
    end
    return copies,out
end
function M.reportedRows()
    local _,rows=M.namedRows()
    return rows
end
-- OpenMap places are private, session-only Find data: no alerts, reports, peers or outgoing work.
local function openmapPlace(text,kind,sender,faction)
    if not S.str(sender,100) then return end
    local _,me=A.ownIdentity()
    local name=N.OpenMap.match(M.find,sender,me)
    if not name or A.ignored(sender) then return end
    local place=N.OpenMap.decode(text)
    if not place then return end
    if place=="clear" then M.find.places[name]=nil
    else
        place.at,place.route,place.faction=now(),kind,faction
        M.find.places[name]=place
    end
    if N.UI then N.UI.refresh() end
end
function M.openmapIn(text,kind,sender)
    if S.secret(kind) or S.secret(text) or S.secret(sender) then return end
    if kind~="GUILD" and kind~="WHISPER" then return end
    if type(text)~="string" or #text>64 or not M.find or #M.find.names==0 then return end
    pcall(openmapPlace,text,kind,sender)
end
function M.openmapBn(prefix,text,channel,id)
    if S.secret(prefix) or S.secret(text) or S.secret(channel) or not S.num(id) then return end
    if prefix~="OpenMapLoc" or type(text)~="string" or #text>64 or not M.find or #M.find.names==0 then return end
    -- Optional lookup and all foreign fields are protected. Never read account names or retain account data.
    pcall(function()
        local info=S.tab(C_BattleNet) and S.call(C_BattleNet.GetGameAccountInfoByID,id)
        if not S.tab(info) then return end
        local sender=N.OpenMap.bnName(info.characterName,info.realmName)
        if not sender then return end
        local guid=S.str(info.playerGuid,160)
        local own=S.str(S.call(UnitGUID,"player"),160)
        if guid and own and guid==own then return end
        local faction=N.OpenMap.faction(info.factionName,S.call(UnitFactionGroup,"player"))
        openmapPlace(text,"BN",sender,faction)
    end)
end
-- Spy family in (lane C1) and guild incidents in (lane C2): a line is the sender's own sighting of one enemy, or the
-- sender's death to one; 6 lines per sender per 10 s over the six prefixes. Spy-family PARTY/RAID sightings now
-- go to the guild as relayed claims (reverses lane C1). Guild incidents stay local; donor prefixes are never answered.
M.spyRates={rates={},nrates=0}
function M.spyIn(prefix,text,kind,sender)
    if type(text)~="string" or #text>255 or not S.str(sender,100) then return end
    local allowed,reason=A.spyPolicy(prefix,kind,sender)
    if not allowed then M.lastDrop=reason; return end
    local time=now()
    -- the sender in the Spy family's spelling ("First-Last", "First-Last-<realm>") read by the one name rule: the rate
    -- bucket is the folded name, and our own line in any spelling is refused
    local who=N.Spy.name(sender)
    if not who then M.lastDrop="Spy: sender name"; return end
    if M.isMe(who) then M.lastDrop="own echo"; return end
    if not N.Reports.allow(M.spyRates,who,false,time) then return end
    local mod=N.Spy.SRC[prefix] and N.Spy or N.Incident
    local d,why=mod.decode(prefix,text)
    if not d then M.lastDrop="Spy: "..tostring(why); return end
    if M.isMe(d.enemy.name) then M.lastDrop="Spy: names us"; return end
    local zone=d.map and A.zone(d.map) or (d.zoneName and A.zoneByName(d.zoneName))
    if not zone then M.lastDrop="Spy: zone unknown"; return end
    local record
    record,why=mod.record(prefix,d,{sender=mod==N.Spy and who or sender,route=kind,heard=time,zone=zone})
    if not record then M.lastDrop="Spy: "..tostring(why); return end
    M.lastHeard=time
    local ok,_,callAction=pcall(M.callReceive,record,who)
    if not ok then M.error="data unavailable (API error)" end
    local stored,whyNot=T.refresh(M.store,record,time)
    if not stored then M.lastDrop=whyNot end
    M.findRecord(record)
    M.findAlerts(ok and callAction=="show")
    if mod==N.Spy then M.offerRelay(record) end
    if N.UI then N.UI.refresh() end
end
-- HeadHunter P/L and enveloped D: shared read path, regardless of mesh stand-down.
-- PARTY/RAID/WHISPER, own faction only, 6 frames per sender per 10 s.
function M.headhunter(text,kind,sender)
    if type(text)~="string" or #text>255 or not S.str(sender,100) then return end
    local allowed,reason=A.hhPolicy(kind,sender)
    if not allowed then M.lastDrop=reason; return end
    local time=now()
    -- only frames we read (P, L, E, and the mesh's N Q O S H) count against the sender's 6 per 10 s
    local frameType=text:match("^%d[AH](%u):")
    -- (the mesh frames are read by whisper only; on a party or raid they are ignored uncounted)
    local mesh=kind=="WHISPER" and (frameType=="N" or frameType=="Q" or frameType=="O" or frameType=="S" or frameType=="H")
    if frameType~="P" and frameType~="L" and frameType~="E" and not mesh then return end
    if not N.HeadHunter.allow(M.hh,sender,time) then return end
    if kind=="WHISPER" and (mesh or frameType=="E") then guarded(M.hhMesh,text,sender,time) end
    if mesh then return end
    local records,why=N.HeadHunter.decode(text,sender,S.num(S.call(GetServerTime)),S.str((S.call(UnitFactionGroup,"player")),20),
        {heard=time,route=kind,zoneFn=A.zone,stats=M.hh.stats})
    M.lastDrop=why~="ignored" and why or M.lastDrop
    for _,record in ipairs(records) do
        local ignored,whyIgnored=false,nil
        if record.origin~=sender then
            if M.isMe(record.origin) then ignored,whyIgnored=true,"own echo"
            else ignored,whyIgnored=A.ignored(record.origin) end
        end
        if N.Record.isKill(record) and not M.validKill(record) then ignored,whyIgnored=true,"invalid killer" end
        if ignored then M.lastDrop=whyIgnored
        elseif N.Record.isKill(record) then
            -- Find only: no Reported row, reporter/host, count or Call popup.
            M.findRecord(record)
            M.offerRelay(record)
            M.lastDrop="headhunter "..record.kind
        else
            local stored,whyNot=T.report(M.store,record,time)
            M.lastDrop=stored and "headhunter "..record.kind or whyNot
            if whyNot~="duplicate" then
                M.findRecord(record)
                M.offerRelay(record)
            end
        end
    end
    if #records>0 then M.findAlerts() end
    if #records>0 and N.UI then N.UI.refresh() end
end
-- Guild relay out: a first-hand record heard on PARTY, RAID or WHISPER goes to the guild once, after a random wait
-- in which a guildmate's copy makes us stand down.
function M.offerRelay(record)
    if not M.sharing() then return end
    local time=now()
    local ok=N.Relay.offer(M.relay,record,time,M.relayContext())
    if ok then
        local p=M.relay.pending[N.Relay.key(record)]
        if not after(math.max(0,p.due-time)+0.05,function() guarded(M.relayTick) end) then M.relayTick() end
    end
end
function M.relayContext()
    return {inGuild=S.call(IsInGuild)==true,inInstance=A.inInstance(),guild=S.str((S.call(GetGuildInfo,"player")),100),watch=M.watch}
end
function M.relayTick()
    if not M.sharing() then N.Relay.clear(M.relay); return end
    for _,r in ipairs(N.Relay.tick(M.relay,now(),M.relayContext())) do
        M.lastRelay=r.ok and "relayed" or r.why
        if r.ok and r.kill then M.hh.stats.kills.relayed=M.hh.stats.kills.relayed+1 end
    end
end
-- Guild relay in: GUILD only, never from us, stored as src "guild" with the claimed source as its label; never
-- relayed again.
function M.relayIn(text,kind,sender)
    if kind~="GUILD" or not S.str(sender,100) or S.call(IsInGuild)~=true then return end
    if not A.ownIdentity() then M.lastDrop="own identity unavailable"; return end
    if M.isMe(sender) then return end
    if A.ignored(sender) then M.lastDrop="ignored sender"; return end
    local time=now()
    if not N.Relay.allow(M.relay,sender,time) then return end
    if type(text)=="string" and text:sub(1,2)=="K|" then return N.OwnDeath.receive(text,sender,time) end
    if type(text)=="string" and text:sub(1,2)=="G|" then return M.comingIn(text,sender) end
    if type(text)=="string" and text:sub(1,2)=="T|" then
        if not M.guildCheck(true) or M.guildWhy() then return end
        N.Watch.receive(M.watch,text,sender,time)
        M.friendAnswer()
        return
    end
    if type(text)=="string" and text:sub(1,2)=="P|" then
        if not M.guildCheck(true) or M.guildWhy() then return end
        return M.friendShareIn(text,sender)
    end
    local control=N.Relay.control(text)
    if control then return M.hostControl(control,sender,time) end
    local own=type(text)=="string" and text:sub(1,2)=="O|"
    local record,why
    if own then record,why=N.Relay.decodeOwn(text,sender,time) else record,why=N.Relay.decode(text,sender,time) end
    if not record then M.lastDrop="relay "..tostring(why); return end
    if own then M.trustClaim(sender,record.layer.value,record.zone,record.at) end
    if N.Record.isKill(record) and not M.validKill(record) then M.lastDrop="invalid killer"; return end
    if not own then N.Relay.heard(M.relay,record,time) end
    if M.isMe(record.origin) or A.ignored(record.origin) then M.lastDrop="relay origin"; return end
    if N.Record.isKill(record) then
        M.findRecord(record); M.findAlerts()
        M.lastDrop="relayed HeadHunter kill"
        if N.UI then N.UI.refresh() end
        return
    end
    -- Spy identities are stable per observer/enemy, not unique report sequence numbers.
    -- Refresh only strictly newer evidence; another carrier must not rewind the stored sighting.
    local old=M.store.reports[record.id]
    local refresh=record.label=="spy" and (not old or record.at>old.record.at)
    local stored,whyNot
    if refresh then stored,whyNot=T.refresh(M.store,record,time) else stored,whyNot=T.report(M.store,record,time) end
    M.lastDrop=stored and "relayed "..tostring(record.label) or whyNot
    -- a copy of a report already held (first-hand or relayed) adds nothing to Find
    if not stored and whyNot=="duplicate" then return end
    -- a relayed origin was in someone else's group: Find shows the report but never offers to ask them
    M.findRecord(record)
    M.findAlerts()
    if N.UI then N.UI.refresh() end
end
-- LayerSwap prefix: only a reply from the player we asked, on WHISPER, within 120 s. An incoming "inv layer"
-- request and everything else are ignored (answering is not ours to do).
function M.layerswap(text,kind,sender)
    if kind=="GUILD" then return M.layerswapGuild(text,sender) end
    -- a request whispered to us goes to the guild host, and only while hosting is on; it never reaches Hop
    if kind=="WHISPER" and type(text)=="string" and text:sub(1,10)=="inv layer " then
        if M.host and M.host.want and not M.host.on then M.guildRetry() end
        if M.host and M.host.on then M.hostRequest(text,sender) end
        return
    end
    if kind=="WHISPER" and M.hopAnyState and M.hopAnyState.round then
        if not M.hopAnySafe() then return end
        local reply,name,note=N.HopAny.receive(M.hopAnyState,text,sender,A.ownIdentity(),now())
        if reply then N.Hosts.heard(M.heard,name,reply,A.wall()) end
        if note then M.say("LayerEnemies: "..note) end
        return
    end
    if kind~="WHISPER" or type(text)~="string" or not S.str(sender,100) or not M.hop.pending then return end
    local me=A.ownIdentity()
    local time=now()
    local asked=M.hop.pending
    local shown,reply=N.Hop.receive(M.hop,text,sender,me,time,M.store.ambiguous(time))
    if shown and not asked.blind then
        if not N.Trust.own(M.store,time) then shown=asked.name.." answered your invite request." end
        M.say("LayerEnemies: "..shown)
    end
    -- the asked player's own "heard" answer: remembered 12 minutes as a host (or forgotten on "-"); nothing is sent
    if reply and reply.kind=="heard" and asked then N.Hosts.heard(M.heard,asked.name,reply,A.wall()) end
end
-- Guild host. Hosting stays off beside LayerSwap or Bulo (they host already) and without the client's invite call.
M.HOST_DONORS={"LayerSwap","BuloLayerForever"}
M.HOST_HOLD=5
function M.hostBlocked()
    for _,name in ipairs(M.HOST_DONORS) do
        if A.loaded(name) then return "hosting stays off while "..name.." is loaded (it hosts already)." end
    end
    if not N.Wire.canInvite() then return "hosting is not available: this client has no party invite call." end
end
-- guildWhy() -> nil while the guild name is readable and equal to the guild seen this session (r040c 21e: every
-- hosting action checks it, so a switch or a blink nothing has reported yet never keeps the old guild's authority)
function M.guildWhy()
    if S.call(IsInGuild)~=true then return "you are not in a guild." end
    local name=S.str((S.call(GetGuildInfo,"player")),100)
    if not name then return "your guild's name is not readable right now." end
    -- login: the first readable name is our guild
    if M.guildSeen==nil and not M.guildLeft and not M.guildUnknown then M.guildSeen=name end
    if M.guildUnknown or M.guildBlink or name~=M.guildSeen then return "waiting for your guild's roster." end
end
function M.hostWhyNot()
    return M.hostBlocked() or M.guildWhy()
end
-- hostCheck(): an active host whose guild no longer checks out goes inactive (still saved on), with one line
function M.hostCheck()
    if not (M.host and M.host.on) then return true end
    local why=M.hostWhyNot()
    if not why then return true end
    M.host.on=false; M.host.inactive=why
    M.say("LayerEnemies: hosting for your guild is ON but inactive: "..why:gsub("%.$","").." (/le host off to stop).")
    if N.UI then N.UI.refresh() end
    return false
end
-- guildRetry(): a saved-on host left inactive by a guild name that blinked: on a request or an F, the guild is
-- checked again: readable and equal to the guild seen ends the blink and hosting acts again at once; otherwise a
-- roster is asked (askRoster: through the 15 s limit)
function M.guildRetry()
    if M.hostBlocked() or not M.guildWhy() or S.call(IsInGuild)~=true then return end
    local name=S.call(IsInGuild)==true and S.str((S.call(GetGuildInfo,"player")),100)
    if name and M.guildBlink and not M.guildUnknown and name==M.guildSeen then
        M.guildBlink=nil; M.hostResume(false)
    else M.askRoster(now()) end
end
-- askRoster(time): a guild roster now, or (inside the 15 s limit) once the limit has passed; one retry timer
function M.askRoster(time)
    local ok,wait=A.rosterRefresh(time)
    if ok or not wait or M.rosterRetry then return ok end
    M.rosterRetry=true
    if not after(wait+0.05,function() M.rosterRetry=nil; if A.roster.owed then guarded(M.askRoster,now()) end end) then M.rosterRetry=nil end
    return false
end
local function saveHost(want) M.host.want=want; if S.tab(LayerEnemiesDB) then LayerEnemiesDB.guildHost=want end end
function M.setHost(on)
    if on then
        local why=M.hostWhyNot()
        if why then M.say("LayerEnemies: "..why); return false end
        saveHost(true); M.host.on=true; M.host.inactive=nil; A.rosterRefresh(now())
        M.say("LayerEnemies: Hosting for your guild is on. Guild members who ask by LayerSwap request are invited to your layer (10 s apart, at most 6 in 10 minutes, never in combat). Guests are never removed. It stays on after a reload; /le host off stops it.")
        -- before this session's first guild roster the H waits for it (once)
        if not M.announceHost() and not A.rosterAge(now()) then M.host.announceOwed=true end
    else
        saveHost(false); M.host.on=false; M.host.held=nil; M.host.inactive=nil; M.host.announceOwed=nil
        M.say("LayerEnemies: Hosting for your guild is off.")
    end
    if N.UI then N.UI.refresh() end
    return M.host.on
end
-- Saved as on: at login (login=true) one line says ON, or ON but inactive and why; later (a guild roster update)
-- an inactive host becomes active with one line. Nothing is sent here: the H line goes out only from the toggle or
-- in answer to an F.
function M.hostResume(login)
    if not M.host.want or M.host.on then return end
    local why=M.hostWhyNot()
    if why then
        M.host.inactive=why
        if login then M.say("LayerEnemies: hosting for your guild is ON but inactive: "..why:gsub("%.$","").." (/le host off to stop).") end
    else
        M.host.on=true; M.host.inactive=nil; A.rosterRefresh(now())
        M.say(login and "LayerEnemies: hosting for your guild is ON (/le host off to stop)." or "LayerEnemies: hosting for your guild is now active.")
    end
    if N.UI then N.UI.refresh() end
end
function M.hostStatus()
    local time,n=now(),0
    for _,at in ipairs(M.host.invites) do if time-at<N.GuildHost.WINDOW then n=n+1 end end
    local state=M.host.on and ("on (saved) · "..n.." invite"..(n==1 and "" or "s").." in the last 10 minutes")
        or M.host.want and ("on (saved) but inactive: "..(M.hostWhyNot() or M.host.inactive or "not active yet."))
        or "off (saved)"
    M.say("LayerEnemies: Hosting for your guild: "..state)
end
-- An ask of ours still open (120 s): older ones are cleared here, so hosting does not stay busy after a hop.
-- peek: the same answer without clearing an expired ask (for displays that only read)
function M.asking(peek)
    local time=now()
    local function open(p) return S.tab(p) and S.num(p.at) and time>=p.at and time-p.at<=N.Hop.REPLY end
    local hop,invite=M.hop.pending,M.invite.pending
    if hop and not open(hop) then if peek then hop=nil else N.Hop.clear(M.hop); hop=M.hop.pending end end
    if invite and not open(invite) and not (M.auto and M.auto.group) then
        invite=nil; if not peek then M.invite.pending=nil end
    end
    return hop~=nil or invite~=nil or N.FLHMember.pending() or (M.hopAnyState and M.hopAnyState.round~=nil)
end
-- Our own state for GuildHost.decide; member is read only after the early checks pass.
function M.hostOwn()
    local zone=A.location()
    local id=S.str(N.Trust.own(M.store,now()),32)
    local party=A.party()
    local _,self=A.ownIdentity()
    return {self=self,zone=zone and zone==M.store.zone and zone or nil,key=L.key(N.Trust.own(M.store,now())),id=id,
        ambiguous=M.store.ambiguous(now()),blind=N.Trust.state(M.store,now())=="blind",
        inInstance=A.inInstance(),inCombat=A.inCombat(),raid=party and party.raid,leader=party and party.leader,
        members=party and party.members or {},asking=M.asking()}
end
-- LEGW1 control lines. An H from a guildmate is remembered like a LayerSwap "heard ...|h" (12 minutes, layer
-- <key>-0); an F, while we host, gets one H 1 to 6 s later (Wire allows one H per 60 s).
function M.hostControl(c,sender,time)
    if c.kind=="H" then
        M.trustClaim(sender,c.key,c.zone,time)
        N.Hosts.heard(M.heard,sender,{kind="heard",layer=c.key.."-0",zone=c.zone,hosting=true,network="LayerEnemies"},A.wall())
        if N.UI then N.UI.refresh() end
        return
    end
    if M.host and M.host.want and not M.host.on then M.guildRetry() end
    if not (M.host and M.host.on) or M.host.answerDue then return end
    if M.host.announcedAt and time-M.host.announcedAt<N.Wire.CONTROL_EVERY and time>=M.host.announcedAt then return end
    M.host.answerDue=true
    local delay=1+math.random()*5
    -- (announceHost needs a guild roster read this session: an F just before the first roster is answered if the
    -- roster arrives within the 1 to 6 s)
    -- a guild change in the meantime drops this answer (the token moves on)
    local token=M.host.guildToken
    if not after(delay,function()
        if M.host.guildToken~=token then return end
        M.host.answerDue=nil; guarded(M.announceHost)
    end) then M.host.answerDue=nil end
end
-- One H line: only while hosting, after this session's first guild roster (a host resumed at login or turned on
-- early is not yet checked against it), with our key and live zone known, and nothing blocking hosting.
function M.announceHost()
    if not M.sharing() or not (M.host and M.host.on) or not M.hostCheck() or not A.rosterAge(now()) then return false end
    local own=M.hostOwn()
    local line=N.Relay.hostLine(own.key,own.zone)
    if not line then return false end
    N.Relay.spend(now(),false)
    local ok=N.Wire.send("LEGW1",line,"GUILD",nil,{prio="owed"})
    if ok then M.host.announcedAt=now() end
    return ok
end
function M.hostRequest(text,sender,held)
    if M.hostBlocked() or not M.hostCheck() then return end
    if S.secret(sender) or not S.str(sender,100) or M.isMe(sender) or A.ignored(sender) then return end
    local G=N.GuildHost
    local req=G.parse(text)
    if not req then return end
    req.name=sender
    local time=now()
    local own=M.hostOwn()
    if not own.self or not G.early(M.host,req,own,time) then return end
    -- a roster older than 120 s: ask for a new one and decide on its update (5 s, one slot, newest wins)
    local age=A.rosterAge(time)
    if not held and (not age or age>A.ROSTER_FRESH) then
        A.rosterRefresh(time)
        M.host.held={text=text,sender=sender,at=time}
        return
    end
    own.member=A.guildMember(sender)
    local verdict,reply=G.decide(M.host,req,own,time)
    if reply then N.Wire.send("LayerSwap",reply,"WHISPER",sender,{prio="owed"}) end
    if verdict=="invite" then
        local ok=N.Wire.invite(sender,time)
        if ok then M.say("LayerEnemies: invited "..((sender:match("^([^%-]+)%-")) or sender).." to your layer (guild host).") end
    end
    if N.UI then N.UI.refresh() end
end
function M.rosterUpdate()
    local time=now()
    -- a roster counts only in a known guild: never while guildless (or IsInGuild unreadable), and a switch noticed
    -- here (a missed or late guild event) asks for that guild's own roster instead of counting this one
    if not M.guildCheck(true) then M.hostCheck(); return end
    A.rosterSeen(time)
    if M.watch then N.Watch.roster(M.watch,A.guildNames()) end
    if M.host and M.host.want and not M.host.on then M.hostResume(false) end
    if M.host and M.host.announceOwed then M.host.announceOwed=nil; if M.host.on then guarded(M.announceHost) end end
    local held=M.host and M.host.held
    if not held then return end
    M.host.held=nil
    if time-held.at<=M.HOST_HOLD and M.host.on then M.hostRequest(held.text,held.sender,true) end
end
-- After our own guild-chat ask (120 s): LayerSwap users answer on GUILD with "heard <us>|<layer>|<zone>|<h or ->".
-- Read only when the first field is our own name; hosting answers are remembered like a whispered reply. "claim"
-- notes and everything else are ignored, and nothing is ever answered.
function M.layerswapGuild(text,sender)
    local g=M.hop.guildAsk
    if not g or type(text)~="string" or not S.str(sender,100) then return end
    local time=now()
    if time-g.at>N.Hop.REPLY then M.hop.guildAsk=nil; return end
    if M.isMe(sender) or A.ignored(sender) then return end
    -- answers count only once our guild line has gone out (draftSent); the window then runs from the send
    local sent=g.sent
    local me=A.ownIdentity()
    local reply=N.Hop.reply(text,sender,me)
    if reply and reply.kind=="heard" then N.Hosts.heard(M.heard,sender,reply,A.wall()) end
    -- who answered our ask: a hosting heard naming us, or a LayerSwap/Bulo claim naming us (Bulo Host.lua:521);
    -- only these and listed hosts may have their invite accepted for the guild ask
    local claimed=#text<=120 and text:match("^claim (.+)$")
    local _,key=I.name(sender)
    if sent and key and ((reply and reply.kind=="heard" and reply.hosting) or (claimed and me and claimed==me)) then
        g.answered=g.answered or {}; g.answered[key]=true
    end
end
-- Our own drafted line seen going out (CHAT_MSG_WHISPER_INFORM to the asked player, CHAT_MSG_GUILD from us with the
-- drafted text): only then may that ask's invite be accepted automatically; the 120 s count from here.
function M.draftSent(kind,text,who)
    local p=M.invite and M.invite.pending
    if not S.tab(p) or not S.tab(p.arm) or p.arm.kind~=kind or S.secret(text) or text~=p.arm.text then return end
    local time=now()
    if time-p.at>M.AUTO_WINDOW or time<p.at then return end
    if kind=="WHISPER" then local _,key=I.name(who); if not key or key~=p.short then return end
    elseif not M.isMe(who) then return end
    p.arm=nil; p.auto=true; p.at=time
    -- our guild line is out: answers to it count from now (anything heard before is no answer to it)
    local g=M.hop.guildAsk
    if kind=="GUILD" and S.tab(g) then g.sent=true; g.at=time; g.answered=nil end
end
-- A listed Bulo/LayerSwap/LayerEnemies host (guild lines, LayerSwap book, remembered replies and H lines).
local function listedHost(short)
    for _,c in ipairs((M.candidates(true))) do
        -- only with that source's host flag: a Bulo "not hosting" line or a LayerSwap row with host=false is no host
        if c.short==short and S.tab(c.hosts) and (c.hosts.Bulo==true or c.hosts.LayerSwap==true) then return true end
    end
    return false
end
-- Hosts remembered from replies, pruned before they are read.
function M.heardBook()
    local wall=A.wall()
    if wall then N.Hosts.prune(M.heard,wall) end
    return M.heard.heard
end
-- Preserve the reviewed presence reader. F2 handles only bounded WP/CQ debts
-- and locally correlated guest offers; claims never gain generic host authority.
function M.flhIn(text,kind,sender)
    kind=S.str(kind,20)
    if kind~="GUILD" and kind~="PARTY" and kind~="RAID" and kind~="WHISPER" then return end
    if not M.heard or not I.name(sender) then return end
    if not A.ownIdentity() or M.isMe(sender) or A.ignored(sender) then return end
    if A.inInstance()~=false then return end
    local combat=A.inCombat()
    -- In combat read only replies to a live guest click, never new presence.
    if combat and not (kind=="WHISPER" and N.FLHMember.pending()) then return end
    if kind=="GUILD" and S.call(IsInGuild)~=true then return end
    local msg=N.FLH.decode(text)
    if not msg then return end
    N.FLHMember.received(msg,kind,sender)
    if combat or (msg.cmd~="HI" and msg.cmd~="WR" and msg.cmd~="CA") then return end
    local wall=A.wall()
    if not wall then return end
    local claim
    if msg.host==1 and msg.map>0 and msg.key~="" then claim={map=msg.map,key=msg.key} end
    N.Hosts.flh(M.heard,sender,claim,wall)
    if N.UI then N.UI.refresh() end
end
-- LFSw prefix: Bulo guild layer lines, GUILD only, read and never answered.
function M.lfsw(text,kind,sender)
    if kind~="GUILD" or not S.str(sender,100) or S.call(IsInGuild)~=true then return end
    if not A.ownIdentity() then return end
    if M.isMe(sender) then return end
    if A.ignored(sender) then return end
    if not N.HeadHunter.allow(M.lfswRate,sender,now()) then return end
    local wall=A.wall()
    if wall then A.guildLine(M.guildLines,text,sender,wall) end
end
local function say(text)
    if S.tab(DEFAULT_CHAT_FRAME) then S.call(DEFAULT_CHAT_FRAME.AddMessage,DEFAULT_CHAT_FRAME,text)
    elseif type(print)=="function" then print(text) end
end
M.say=say
function M.homeRealm()
    return S.str(S.call(GetNormalizedRealmName)) or S.str(S.call(GetRealmName)) or ""
end
I.home=M.homeRealm
-- 1.2.4 friend and community presence share (FriendShare.lua). Sent to the guild only, never in an instance,
-- only with sharing on and /le share friends on (the default). Low priority: own sightings and hops keep their
-- reserve. Nothing is saved except the switch.
function M.sharingFriends() return not S.tab(LayerEnemiesDB) or LayerEnemiesDB.shareFriends~=false end
-- Not in the first 30 s after login: friend, community and roster data are not settled yet.
M.FRIEND_SETTLE=30
function M.friendSendable()
    local time=now()
    return M.friendStartAt~=nil and time>=M.friendStartAt and time-M.friendStartAt>=M.FRIEND_SETTLE
        and M.sharing() and M.sharingFriends() and S.call(IsInGuild)==true and not M.guildWhy() and A.inInstance()==false
end
function M.friendShareFlush(current)
    if not M.friendOut or not M.friendSendable() then return end
    -- a new scan never drops what waits: changes go first, the refresh carries on with the stalest entries
    N.FriendShare.plan(M.friendOut,current,now())
    M.friendShareTick()
end
-- Sends waiting entries as the LEGW1 budget allows, one packed line at a time; refreshes every 5 minutes even
-- without an event.
function M.friendShareTick()
    local out=M.friendOut
    if not out then return end
    if not M.friendSendable() then N.FriendShare.clear(out); return end
    local time=now()
    while N.FriendShare.pending(out) do
        local line,keys=N.FriendShare.nextLine(out,0)
        if not line then break end
        if not N.Relay.spend(time,true) then out.stats.refused=out.stats.refused+1; break end
        local ok=N.Wire.send("LEGW1",line,"GUILD",nil,{prio="presence",queue=false})
        if not ok then out.stats.refused=out.stats.refused+1; break end
        N.FriendShare.done(out,keys,time); out.stats.lines=out.stats.lines+1
    end
    if (not out.fullAt or time<out.fullAt or time-out.fullAt>=N.FriendShare.REFRESH) and not M.presenceJob then M.presenceScan(true) end
end
-- A friend or community change rescans soon (at most every CHANGE_GAP seconds), so the guild hears it at once.
function M.friendChanged()
    if M.friendChangeDue or not M.friendSendable() then return end
    local time=now()
    local wait=M.presenceAt and time>=M.presenceAt and math.max(0,M.presenceAt+N.FriendShare.CHANGE_GAP-time) or 0
    M.friendChangeDue=true
    local function go() M.friendChangeDue=nil; guarded(M.presenceScan,true) end
    if not after(wait,go) then go() end
end
-- A guild watch list naming one of ours is answered at once (at most every ANSWER_GAP per name).
function M.friendAnswer()
    local out=M.friendOut
    if not out or not M.friendSendable() then return end
    local keys={}
    for key,e in pairs(out.cur) do
        local _,_,_,senders=N.Watch.match(M.watch,e.name,now())
        if senders and #senders>0 then keys[key]=true end
    end
    if N.FriendShare.answer(out,keys,now())>0 then M.friendShareTick() end
end
-- One guildmate's presence (as their client sees it) applied to our Find for names we track.
local function friendApply(r)
    local _,me=A.ownIdentity()
    local name=N.OpenMap.match(M.find,r.name,me,true)
    if not name then return end
    local old=M.find.presence[name]
    -- our own Battle.net view wins over a guildmate's
    local shared=old and type(old.source)=="string" and old.source:sub(1,2)=="g:"
    if old and not shared and now()-old.at<N.Presence.TTL then return end
    -- between guildmates the newest evidence wins
    if shared and old.at and old.at>r.at then return end
    local fresh=not old or old.zone~=r.zone
    N.Presence.note(M.find,name,{zone=r.zone,route="friend of "..r.sender,faction=r.faction,guid=r.guid,source="g:"..r.senderKey},r.at)
    if fresh and N.Find.alert(M.find,{name=name},now(),true) then
        local text=name.." — "..M.presenceText({zone=r.zone,route="friend of "..r.sender,age=now()-r.at})
        M.findNotice(text)
    end
end
function M.friendShareApply()
    for _,r in ipairs(N.FriendShare.rows(M.friendIn,now())) do friendApply(r) end
end
function M.friendShareIn(text,sender)
    local display,senderKey=I.name(sender)
    if not senderKey then return end -- relayIn already dropped our own echo and ignored senders
    local msg,why=N.FriendShare.decode(text)
    if not msg then M.lastDrop="friend share "..tostring(why); return end
    local time=now()
    local _,me=A.ownIdentity()
    for _,e in ipairs(msg.entries) do
        local name,nameKey=I.name(e.name)
        if nameKey and nameKey~=me then
            local r=N.FriendShare.put(M.friendIn,display,senderKey,nameKey,e,time-msg.age)
            if r then r.name=name; friendApply(r)
            else
                -- withdrawn: only this guildmate's projection leaves Find
                for tracked,old in pairs(M.find.presence) do
                    if old.source=="g:"..senderKey and N.OpenMap.match({names={tracked}},name,me) then M.find.presence[tracked]=nil end
                end
            end
        end
    end
    M.lastDrop="friend share"
    if N.UI then N.UI.refresh() end
end
function M.setShareFriends(on)
    if S.tab(LayerEnemiesDB) then LayerEnemiesDB.shareFriends=on==true end
    if not on and M.friendOut then N.FriendShare.clear(M.friendOut) end
    M.say(on and "LayerEnemies: sharing your Battle.net friends and community members (opposite faction, online) with the guild: on."
        or "LayerEnemies: sharing your Battle.net friends and community members with the guild: off.")
    if on then M.friendShareTick() end
end
function M.zoneName(zone)
    local info=S.tab(C_Map) and S.call(C_Map.GetMapInfo,zone)
    return S.tab(info) and S.str(info.name) or ("zone "..tostring(zone or "unknown"))
end
function M.findRows()
    local lists=A.friendLists(M.guildLines,M.heardBook())
    local rows=N.Find.rows(M.find,now(),M.store.zone,function(name,zone)
        return zone==M.store.zone and I.sameSpotter(name,{zone=zone,wall=A.wall(),ownKey=L.key(N.Trust.own(M.store,now())),
            ambiguous=M.store.ambiguous(now()),bulo=lists.bulo,book=lists.book})
    end,N.Trust.own(M.store,now()))
    presenceSharedSweep(now())
    local _,me=A.ownIdentity()
    for _,r in pairs(M.presenceShared) do
        if not N.OpenMap.match(M.find,r.name,me,true) then
            rows[#rows+1]={name=r.name,status="online ("..r.route..")",canAsk=false,guildTracked=true,
                presence={zone=r.zone,route=r.route,age=now()-r.at,guildTracked=true}}
        end
    end
    return rows
end
function M.presenceText(presence)
    return (presence.guildTracked and "possible guild watch match · " or "").."online ("..presence.route.."): "..presence.zone.." · "..math.floor(presence.age).." s ago"
end
function M.placeText(place)
    return "last shared position (OpenMap): "..M.zoneName(place.map).." "..math.floor(place.x*100+.5)..","..math.floor(place.y*100+.5)
        .." · "..math.floor(place.age).." s ago"..(place.faction=="opposite" and " · enemy faction" or place.faction=="same" and " · your faction" or "")
end
local function knownLine(e)
    local seconds=math.floor(math.max(0,now()-e.at))
    local age=seconds<60 and (seconds.." s") or (math.floor(seconds/60).." min")
    local text
    if e.kind=="claim" then
        text="Reported: "..(e.detail or (e.source=="death" and "named as killer" or "possible match, seen in a relayed report"))
    else text="Seen by "..(e.spotter or "unknown") end
    text=text.." in "..M.zoneName(e.zone)..", "..age.." ago"
    if e.kind=="claim" then text=text.." ("..e.source..", claim)"
    elseif e.layer and N.Trust.own(M.store,now()) then text=text..", layer "..e.layer.." ("..(e.own and "your sighting" or "their claim")..")" end
    if e.own then text=text.." · "..e.status:gsub("^last known: ","")
    elseif e.realmUnknown then text=text.." · realm not confirmed" end
    if e.detail=="own (party target)" then text=text.." · "..e.detail end
    if e.x and e.y then text=text.." · "..math.floor(e.x*100+.5)..","..math.floor(e.y*100+.5).." ("..(e.pos or "unknown").." position)" end
    if e.travel then text=text.." · travel to "..M.zoneName(e.zone).." first"
    elseif e.same then text=text.." · already on your layer"
    elseif e.probably then text=text.." · probably on your layer (your server key is ambiguous)" end
    return (e.lastKnown and "last known: " or "")..text
end
local function currentLine(row)
    local text=row.status
    if row.at then
        local detail=" in "..M.zoneName(row.zone)..", "..math.floor(now()-row.at).." s ago ("..(row.class or "Unknown class").." "..tostring(row.level or "?")..")"
        text=text..detail..(row.same and " — already on your layer" or row.probably and " — probably on your layer (your server key is ambiguous)"
            or row.travel and (" — travel to "..M.zoneName(row.zone).." first") or "")
    end
    return text
end
function M.findDetails(row)
    local lines={}
    if row.current then lines[#lines+1]=currentLine(row.current) end
    if row.seen then lines[#lines+1]=knownLine(row.seen) end
    if row.otherSeen then lines[#lines+1]=knownLine(row.otherSeen) end
    if row.reported then lines[#lines+1]=knownLine(row.reported) end
    if row.search then
        if #lines==0 then lines[#lines+1]=currentLine(row) end
        lines[#lines+1]=row.search
    end
    return #lines>0 and table.concat(lines,"\n") or nil
end
function M.findText(row,sightingOnly)
    local details=M.findDetails(row)
    local text=row.name.." — "..(details or currentLine(row))
    if row.place and not sightingOnly then
        text=(row.at and (text.."\n") or (row.name.." — "))..M.placeText(row.place)
    end
    if row.presence and not sightingOnly then
        text=((row.at or row.place) and (text.."\n") or (row.name.." — "))..M.presenceText(row.presence)
    end
    return text
end
function M.calling() return not S.tab(LayerEnemiesDB) or LayerEnemiesDB.call~=false end
function M.setCall(on)
    LayerEnemiesDB.call=on==true
    if not on then
        M.call=N.Call.new()
        N.CallUI.clear()
    end
    M.say(on and "LayerEnemies: Call is on." or "LayerEnemies: Call is off.")
    if N.UI then N.UI.refresh() end
end
function M.setCallArt(on)
    LayerEnemiesDB.callArt=on==true
    N.CallUI.render()
    M.say(on and "LayerEnemies: Call art is on." or "LayerEnemies: Call art is off (Latin headings).")
end
-- showOnMap(zone,x,y): the user waypoint (super-tracked) or, when the map refuses, one chat line with the place.
function M.showOnMap(zone,x,y)
    local placed=false
    if zone and x and y and S.tab(C_Map)
        and S.call(C_Map.CanSetUserWaypointOnMap,zone)==true and type(C_Map.SetUserWaypoint)=="function" then
        local point
        if S.tab(UiMapPoint) then point=S.call(UiMapPoint.CreateFromCoordinates,zone,x,y)
        else
            -- UiMapPoint's convenience constructor loads only on Mainline. The native struct uses a Vector2D.
            local position=S.call(CreateVector2D,x,y)
            if position then point={uiMapID=zone,position=position} end
        end
        if point then
            local ok,result=pcall(C_Map.SetUserWaypoint,point)
            placed=ok and not S.secret(result) and result==true
            if placed and S.tab(C_SuperTrack) then S.call(C_SuperTrack.SetSuperTrackedUserWaypoint,true) end
        end
    end
    if not placed then
        local position=x and y and string.format("%.1f, %.1f",x*100,y*100) or "position unavailable"
        M.say("LayerEnemies: "..N.CallText.clean(M.zoneName(zone)).." - "..position..".")
    end
    return placed
end
-- comingSend(e): one hidden guild line per alert event, from the help click only. Same gates as K1.
function M.comingSend(e)
    if e.coming then return false end
    e.coming=true
    if not (M.sharing() and A.inInstance()==false and S.call(IsInGuild)==true and A.ownIdentity()) then return false end
    local line=N.Coming.line(e.zone,e.victim)
    if not line or not N.Coming.allow(M.coming,now()) then return false end
    return N.Wire.send("LEGW1",line,"GUILD",nil,{prio="click"})==true
end
-- comingIn(text,sender): a guildmate's "on my way"; the victim gets the alert sound too.
-- One line per helper+victim per 60 s, the sound at most once per 10 s; the rest only counts (/le net).
-- Silent with /le call off or inside an instance.
M.COMING_LINE,M.COMING_SOUND=60,10
function M.comingIn(text,sender)
    local d=N.Coming.decode(text)
    if not d then M.lastDrop="coming invalid"; return end
    local c=M.coming; c.heard=(c.heard or 0)+1
    if not M.calling() or A.inInstance()~=false then c.quiet=(c.quiet or 0)+1; return end
    local time=now(); c.lines=c.lines or {}
    for k,at in pairs(c.lines) do if time<at or time-at>=M.COMING_LINE then c.lines[k]=nil end end
    local key=(N.Find.fold(sender) or sender).."|"..(N.Find.fold(d.victim) or d.victim)
    if c.lines[key] or S.count(c.lines)>=64 then c.collapsed=(c.collapsed or 0)+1; return end
    c.lines[key]=time
    local helper=N.CallText.clean(sender)
    if M.isMe(d.victim) then
        M.say("LayerEnemies: COMING: "..helper.." is on the way.")
        if not c.soundAt or time<c.soundAt or time-c.soundAt>=M.COMING_SOUND then c.soundAt=time; M.alertSound() end
    else
        M.say("LayerEnemies: "..helper.." is coming to help "..N.CallText.clean(d.victim).." ("..N.CallText.clean(M.zoneName(d.zone))..").")
    end
end
function M.callHelp(e)
    M.showOnMap(e.zone,e.x,e.y)
    M.comingSend(e)
    if e.full and e.killer then
        local ok,why=N.Find.add(M.find,e.killer)
        if not ok then M.say("LayerEnemies: "..why)
        else
            LayerEnemiesDB.tracked=M.find.names
            M.watchSync()
            if N.UI then N.UI.refresh() end
        end
    end
end
function M.callReceive(record,victim)
    local time=now()
    local _,me=A.ownIdentity()
    local enemy=record.enemies and record.enemies[1]
    local e,action=N.Call.receive(M.call,record,victim,time,{on=M.calling(),instance=A.inInstance(),me=me,
        known=enemy and N.Call.known(M.store,enemy.name,time)})
    if e and (action=="show" or (N.CallUI.frame and N.CallUI.frame:IsShown())) then
        N.CallUI.show(e,action)
        if action=="show" then M.alertSound() end
    end
    return e,action
end
function M.alertSound()
    S.call(PlaySound,S.tab(SOUNDKIT) and SOUNDKIT.RAID_WARNING or 8959,"Master")
end
local function findSummary(st,window)
    if M.find~=st or st.alertWindow~=window then return end
    if window.more>0 then
        M.say("LayerEnemies: "..window.more.." more tracked names located, see Find")
        window.more=0
    end
    st.alertWindow=nil
end
-- Shared three-lines / ten-seconds chat throttle; presence never plays a sound.
function M.findNotice(text)
    local st,time=M.find,now()
    local window=st.alertWindow
    if window and time-window.at>=10 then findSummary(st,window); window=nil end
    if not window then window={at=time,lines=0,more=0}; st.alertWindow=window end
    if window.lines<3 then
        M.say("LayerEnemies: "..text); window.lines=window.lines+1
    else
        window.more=window.more+1
        if not window.pending then
            window.pending=after(math.max(0,10-(time-window.at)),function() findSummary(st,window) end)
        end
    end
end
-- foundPopup(row): one pop-up per tracked name per 120 s, never in instances, /le found off silences it.
M.FOUND_GAP=120
function M.foundPopup(row)
    if not S.tab(LayerEnemiesDB) or LayerEnemiesDB.found==false or A.inInstance()~=false then return false end
    local time=now(); M.foundAt=M.foundAt or {}
    local key=N.Find.fold(row.name) or row.name
    local last=M.foundAt[key]
    if last and time>=last and time-last<M.FOUND_GAP then return false end
    -- Reuse the already projected row until own trust changes; opening alerts must not rescan Find.
    local shownKey,status=N.Trust.own(M.store,time),row.status
    local shown=N.Popup.show("found",{name=row.name,level=row.level,class=row.class,zone=row.zone,
        x=row.x,y=row.y,age=row.age,source=row.status,status=function(rows)
            local key=N.Trust.own(M.store,now())
            if key~=shownKey then
                shownKey,status=key,""
                for _,live in ipairs(rows or M.findRows()) do if live.name==row.name then status=live.status; break end end
            end
            return status
        end})
    if shown then M.foundAt[key]=time end
    return shown
end
function M.setFound(on)
    LayerEnemiesDB.found=on==true
    if not on then N.Popup.close() end
    M.say(on and "LayerEnemies: Found pop-up is on." or "LayerEnemies: Found pop-up is off.")
end
function M.findAlerts(quiet,printed)
    local st,time=M.find,now()
    if not st then return end
    local window=st.alertWindow
    if window and time-window.at>=10 then findSummary(st,window); window=nil end
    if #st.names==0 then return end
    local rows=M.findRows()
    for _,row in ipairs(rows) do
        if N.Find.alert(st,row,time) then
            if row.name~=printed then
                M.findNotice(M.findText(row,true))
            end
            if not pcall(M.foundPopup,row) then M.error="found pop-up error" end
            if not quiet and (not st.soundAt or time-st.soundAt>=10) then
                st.soundAt=time; M.alertSound()
            end
        end
    end
    return rows
end
function M.track(name,remove)
    if remove then N.Find.remove(M.find,name)
    elseif name then
        local ok,why=N.Find.add(M.find,name)
        if not ok then M.say("LayerEnemies: "..why); return false end
        for _,e in pairs(M.store.localSeen) do N.Find.own(M.find,e,M.store.zone,e.at,now()) end
        for _,row in pairs(M.store.reports) do
            local r=row.record
            -- a stored guild relay stays a relay when replayed into Find (never askable)
            M.findRecord(r)
        end
    else N.Find.remove(M.find) end
    M.watchSync()
    if name and not remove and M.friendIn then M.friendShareApply() end
    LayerEnemiesDB.tracked=M.find.names
    if #M.find.names==0 then M.say("LayerEnemies: tracked names cleared.") end
    local printed
    if name and not remove then
        local _,key=N.Find.name(name)
        for _,row in ipairs(M.findRows()) do
            if N.Find.fold(row.name)==key then M.say("LayerEnemies: "..M.findText(row)); printed=row.name; break end
        end
    elseif remove and #M.find.names>0 then M.say("LayerEnemies: tracked name cleared.") end
    M.findAlerts(nil,printed)
    if N.UI then N.UI.refresh() end
    return true
end
local function ago(seconds)
    seconds=math.floor(math.max(0,seconds))
    return seconds<60 and (seconds.." s") or (math.floor(seconds/60).." min")
end
-- Describe both namespaces explicitly; FLH freshness never replaces another source's age.
function M.hostPlace(c)
    if not N.Trust.own(M.store,now()) then return "" end
    local text=c.layer and ("layer "..c.layer) or "layer unknown - saw reported enemies"
    if c.flhKey then
        local key=#c.flhKey>20 and (c.flhKey:sub(1,20).."...") or c.flhKey
        local claim="FLH key "..key.." (claim, "..ago(c.flhAge).." ago)"
        local status=N.FLHMember.detail(c)
        if status then claim=claim.."; "..status end
        text=c.layer and (text.." / "..claim) or claim
    end
    return text
end
-- listed=true: only what Bulo and LayerSwap themselves list (not our remembered replies, which are answers)
function M.candidates(listed)
    local time=now()
    local lists=A.friendLists(M.guildLines,not listed and M.heardBook() or nil)
    local _,short=A.ownIdentity()
    local rows,status=I.collect({now=time,wall=A.wall(),zone=M.store.zone,ownKey=L.key(N.Trust.own(M.store,now())),ambiguous=M.store.ambiguous(time),self=short,
        reporters=T.reporters(M.store,time),bulo=lists.bulo,book=lists.book,flh=not listed and M.heard.flhHosts or nil})
    if N.Trust.state(M.store,time)=="blind" then
        for _,r in ipairs(rows) do r.layer,r.flhKey,r.uid=nil,nil,nil end
    end
    return rows,status
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
    if M.hopAnyBusy() then return false end
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
                if row.probably and row.canAsk then M.say("LayerEnemies: "..row.spotter.." is probably on your layer (your server key is ambiguous); asking anyway.") end
                if row.canAsk then found={name=row.spotter,short=key}; break end
            end
        end
    end
    if not found then
        M.say("LayerEnemies: "..wanted.." is not a known friendly player on another layer in your zone right now. See /le hosts.")
        return false
    end
    if found.unknownOwn then M.say("LayerEnemies: "..I.HINT); return false end
    local ok,line=I.ask(M.invite,found,now(),A.grouped(),L.key(N.Trust.own(M.store,now())))
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
-- A zone who query is made directly in this click stack; only its bounded follow-up uses timers.
function M.hopAnyBusy()
    if N.FLHMember.pending() then
        M.say("LayerEnemies: an FLH hop is still open; /le hop stop first."); return true
    end
    if M.hopAnyState and M.hopAnyState.round then
        M.say("LayerEnemies: a hop-any round is still open; /le hop stop first.")
        return true
    end
    return false
end
M.BLIND_TIP="Layer IDs are unreadable. This asks a host for an invite; the addon cannot say which layer you land on."
M.BLIND_STOP="layer IDs became unreadable; click Hop (blind)"
function M.blindCandidates()
    local lists=A.friendLists(M.guildLines,nil)
    local rows=I.blindCollect({self=select(2,A.ownIdentity()),now=now(),wall=A.wall(),zone=M.store.zone,
        bulo=lists.bulo,book=lists.book,guildLines=M.guildLines,heard=M.heardBook(),
        flh=M.heard.flhHosts,reporters=T.reporters(M.store,now())})
    local out={}
    for _,c in ipairs(rows) do
        if not A.ignored(c.name) and not N.Wire.offlineUntil(c.name,now())
            and (N.Net.consent()=="public" or A.guildMember(c.name)==true) then out[#out+1]=c end
    end
    return out
end
function M.blindPreview()
    local ctx=M.hopContext()
    local rows=M.blindCandidates()
    local c,why=N.HopAny.blindPick(M.hopAnyState,rows,ctx.zone,false)
    local guild=#rows==0
    local reason
    if ctx.grouped then reason="leave your current group first; group state must be readable."
    elseif ctx.instance then reason="not available in an instance or with instance state unreadable."
    elseif not ctx.zone or ctx.zone~=ctx.own.zone then reason="your live zone is not known."
    elseif not A.ownIdentity() then reason="your own name is not readable."
    elseif M.asking(true) or (M.auto and M.auto.group) then reason="an ask or hop is still open; stop it or wait for it to end."
    elseif ctx.invite.lastAsk and ctx.now-ctx.invite.lastAsk<I.GLOBAL_COOLDOWN then reason="one ask every 10 s."
    elseif guild and S.call(IsInGuild)~=true then reason="no known hosts; you are not in a guild."
    elseif (guild or (c and c.addon)) and not N.Hop.lineBlind(ctx.zone,ctx.x,ctx.y) then reason="your map position is not readable; the request could not be built."
    elseif c and c.addon and N.Wire.hopBlocked(ctx.now) then reason="LayerSwap whisper paused." end
    local key=guild and N.Hop.GUILD.short or c and c.short
    local at=key and ctx.invite.asked[key]
    if not reason and at and ctx.now-at<I.NAME_COOLDOWN then reason="that host or guild was asked recently; wait before asking again." end
    return {label="Hop (blind)",detail=M.BLIND_TIP,enabled=not reason,reason=reason,mode=guild and "blind-guild" or "blind",
        candidate=c,rows=rows,exhausted=not guild and not c and why or nil,ctx=ctx}
end
function M.blindSnapshot()
    local rows={}
    local function add(u)
        local guid=S.str(S.call(UnitGUID,u),160)
        if guid then rows[#rows+1]={guid=guid,player=S.clean(S.call(UnitIsPlayer,u))} end
    end
    add("target"); add("mouseover")
    for i=1,40 do add("nameplate"..i) end
    local x,y,z,map=S.call(UnitPosition,"player")
    return N.HopProbe.snapshot(rows,{x=x,y=y,z=z,map=map})
end
function M.blindResult(kind,name)
    M.blindStatus=N.HopProbe.text(kind,name)
    if M.blindStatus then M.say("LayerEnemies: "..M.blindStatus) end
    if N.HopBar then N.HopBar.refresh() end
end
function M.blindExpired(p)
    if p.joinedAt then M.hopDone(); return end
    local kind=p.accepted and "unformed" or p.invited and "unaccepted" or p.auto and "missed"
    if kind then M.blindResult(kind,p.invited or p.name) end
    M.hopDone()
end
function M.blindHop(shown)
    local p=M.blindPreview()
    if not p.enabled then M.say("LayerEnemies: "..p.reason); return false end
    local c,ctx=p.candidate,p.ctx
    if shown and (shown.mode~=p.mode or (shown.candidate==nil)~=(c==nil)
        or (c and (shown.candidate.short~=c.short or shown.candidate.source~=c.source or shown.candidate.addon~=c.addon))) then
        M.say("LayerEnemies: hosts changed, check again."); if N.UI then N.UI.refresh(true) end; return false
    end
    if p.exhausted then
        N.HopAny.blindPick(M.hopAnyState,p.rows,ctx.zone,true)
        M.say("LayerEnemies: "..p.exhausted); return false
    end
    local guild=p.mode=="blind-guild"
    local ok,why=I.reserve(M.invite,guild and N.Hop.GUILD or c,ctx.now)
    if not ok then M.say("LayerEnemies: "..why); return false end
    if c then N.HopAny.blindPick(M.hopAnyState,p.rows,ctx.zone,true) end
    local line=guild and N.Hop.guildBlindLine(ctx.zone,ctx.x,ctx.y)
        or c.addon and N.Hop.lineBlind(ctx.zone,ctx.x,ctx.y) or I.line(c.name)
    local pending={blind=true,name=guild and N.Hop.GUILD.name or c.name,short=c and c.short,
        at=ctx.now,zone=ctx.zone,guild=guild,auto=not guild and c.addon or nil,before=M.blindSnapshot()}
    if guild then pending.arm={kind="GUILD",text=line:sub(4)}; M.hop.guildAsk={at=ctx.now}
    elseif not c.addon then pending.arm={kind="WHISPER",text=I.MESSAGE} end
    M.blindStatus=nil; M.invite.pending=pending; M.blindPending=pending
    if guild then
        if not M.openChat(line) then M.say("LayerEnemies: type this line in guild chat:"); M.say(line) end
    elseif not c.addon then
        if not M.openWhisper(c.name,line) then M.say("LayerEnemies: open a whisper to "..c.name.." manually, then type:"); M.say(I.MESSAGE) end
    else
        ok,why=N.Wire.send("LayerSwap",line,"WHISPER",c.name,{prio="click",hopAny=true,hopKnown=true})
        if not ok then M.hopDone(); M.say("LayerEnemies: whisper not sent; click again later."); return false end
        M.hop.pending={name=c.name,short=c.short,at=ctx.now,blind=true}
    end
    if pending.arm then M.say("LayerEnemies: invite request drafted; press Enter to send it.")
    else M.say("LayerEnemies: asked "..c.name.." ("..c.source..") for an invite.") end
    after(M.AUTO_WINDOW+0.1,function() if M.blindPending==pending then guarded(M.autoTick) end end)
    return true
end
function M.hopAnyPreview()
    if not N.Trust.own(M.store,now()) then return M.blindPreview() end
    if M.hopAnyState and M.hopAnyState.round then return {label="Stop",enabled=true,round=M.hopAnyState.round} end
    local ok,why=N.HopAny.check(M.hopAnyState,M.hopAnyContext())
    return {label="Hop to another layer",enabled=ok,reason=why}
end
function M.hopAnyContext(peek)
    local c=M.hopContext()
    local info=S.tab(C_Map) and S.call(C_Map.GetMapInfo,c.zone)
    c.zoneName=S.tab(info) and S.str(info.name,120) or nil
    c.self=select(2,A.ownIdentity())
    c.guildOnly=N.Net.consent()~="public"
    c.instance=A.inInstance()
    c.asking=M.asking(peek) or (M.auto and M.auto.group~=nil)
    c.term=A.whoTerm(c.zoneName)
    c.line=N.Hop.lineNot(c.zone,c.own.server,c.x,c.y)
    return c
end
function M.hopAny(shown)
    if shown and shown.mode and shown.mode:match("^blind") and N.Trust.own(M.store,now()) then
        M.say("LayerEnemies: layer trust changed; check Hop again."); return false
    end
    if not N.Trust.own(M.store,now()) then return M.blindHop(shown) end
    M.blindStatus=nil
    local c=M.hopAnyContext()
    if N.Wire.hopBlocked(c.now) then M.say("LayerEnemies: LayerSwap whisper paused."); return false end
    local ok,why=N.HopAny.begin(M.hopAnyState,c)
    if not ok then M.say("LayerEnemies: "..why); return false end
    if not A.who(c.term,function() M.hopAnyStop("your who search takes priority") end) then
        N.HopAny.close(M.hopAnyState); M.say("LayerEnemies: the game refused the search.")
        if N.UI then N.UI.refresh(true) end
        return false
    end
    M.hopAnySchedule(M.hopAnyState.round)
    if N.UI then N.UI.refresh(true) end
    M.say("LayerEnemies: searching this zone; up to 49 players will be asked, at most 8 attempts per second.")
    return true
end
function M.hopAnySchedule(r)
    if not r or r.timer then return end
    r.timer=true
    if not after(1,function()
        if M.hopAnyState.round~=r then return end
        r.timer=nil; guarded(M.hopAnyPump)
    end) then M.hopAnyStop("timer unavailable") end
end
function M.hopAnyStop(reason)
    local flh=N.FLHMember.stop(reason)
    if M.blindPending or (M.auto and M.auto.group and M.auto.group.blind) then
        M.clearAutoGroup(); M.hopDone(); M.say("LayerEnemies: blind hop stopped."); flh=true
    end
    local st=M.hopAnyState
    A.whoEnd("stop")
    if not st or not st.round then return flh end
    N.HopAny.close(st,now())
    if M.invite.pending and M.invite.pending.any then M.invite.pending=nil end
    M.say("LayerEnemies: "..(reason==M.BLIND_STOP and reason or ((reason or "search stopped")..". Sent requests cannot be recalled; a late invite may still arrive.")))
    if N.UI then N.UI.refresh(true) end
    return true
end
function M.hopAnySafe()
    local r=M.hopAnyState and M.hopAnyState.round
    if not r then return false end
    if not N.Trust.own(M.store,now()) then M.hopAnyStop(M.BLIND_STOP); return false end
    if N.Net.consent()~="public" then M.hopAnyStop("guild-only mode"); return false end
    if N.Wire.hopBlocked(r.at) then M.hopAnyStop("LayerSwap whisper paused"); return false end
    if A.grouped() or A.inInstance()~=false or A.location()~=r.zone then
        M.hopAnyStop("group, instance or zone changed"); return false
    end
    local _,self=A.ownIdentity()
    if not self then M.hopAnyStop("own name unreadable"); return false end
    return true
end
function M.hopAnyWho()
    local mine=A.whoEvent()
    local st=M.hopAnyState
    if not mine then return end
    if not st or not st.round or st.round.phase~="who" then return end
    if not M.hopAnySafe() then return end
    local note=N.HopAny.expire(st,now())
    if note then M.say("LayerEnemies: "..note); if N.UI then N.UI.refresh(true) end; return end
    local c=M.hopAnyContext()
    c.hosts=N.HopAny.hosts(A.friendLists(M.guildLines,M.heardBook()),st,c.now,A.wall()); c.ignored=A.ignored; c.offline=N.Wire.offlineUntil
    local ok,why=N.HopAny.who(st,A.whoRows(),c)
    if why then M.say("LayerEnemies: "..why); if N.UI then N.UI.refresh(true) end end
    if ok then M.hopAnyPump() end
end
-- The only Wire caller for hop-any requests; HopAny owns all bounded queue work, never Wire.queue.
function M.hopAnyPump()
    local st=M.hopAnyState
    if not M.hopAnySafe() then return end
    local note=N.HopAny.expire(st,now())
    if note then
        A.whoEnd("timeout")
        if M.invite.pending and M.invite.pending.any then M.invite.pending=nil end
        M.say("LayerEnemies: "..note); if N.UI then N.UI.refresh(true) end; return
    end
    local round=st.round
    if round.sending then return end
    for _=1,N.HopAny.CAP do
        if st.round~=round or not M.hopAnySafe() then break end
        local c=N.HopAny.next(st,now())
        if not c then break end
        local r=st.round
        local ignored=A.ignored(c.name)
        if st.round~=r then return end
        local ok,why=false,"ignored"
        if not ignored then
            M.invite.asked[c.short]=now()
            ok,why=N.Wire.send("LayerSwap",c.line or r.line,"WHISPER",c.name,{prio="click",hopAny=true,hopKnown=c.known==true})
        end
        -- A foreign send hook may stop or replace the round before returning.
        if st.round~=r then return end
        local message=N.HopAny.sent(st,c,now(),ok,why)
        if ok and not c.fallback then M.invite.pending={any=true,auto=true,at=r.firstSend,from=r.from,zone=r.zone,asked=r.asked} end
        if message then
            if M.invite.pending and M.invite.pending.any then M.invite.pending=nil end
            M.say("LayerEnemies: "..message)
            if N.UI then N.UI.refresh(true) end
        end
    end
    M.hopAnySchedule(st.round)
end
-- One record, one possible hop: who would be asked, how, and why not.
function M.hopContext()
    local time=now()
    local zone,x,y=A.location()
    local own=T.own(M.store,time)
    if zone~=own.zone then x,y=nil,nil end
    return {now=time,grouped=A.grouped(),instance=A.inInstance()~=false,own=own,zone=zone,invite=M.invite,x=x,y=y,zoneName=M.zoneName}
end
function M.hopPreview(record)
    if not N.Trust.own(M.store,now()) then return M.blindPreview() end
    local ctx=M.hopContext()
    local cand=N.Hop.candidate(record,(M.candidates()))
    local ok,reason=N.Hop.check(record,cand,ctx)
    if ok then
        local _,short=I.name(cand.name)
        local last=short and M.invite.asked[short]
        if last and ctx.now-last<I.NAME_COOLDOWN then ok,reason=false,cand.name.." was asked "..math.floor(ctx.now-last).." s ago." end
        if ok and M.invite.lastAsk and ctx.now-M.invite.lastAsk<I.GLOBAL_COOLDOWN then ok,reason=false,"one ask every "..I.GLOBAL_COOLDOWN.." s." end
    end
    -- nobody known on that layer, everything else fine: a guild-chat request the player sends
    if not ok and reason==N.Hop.NO_ONE then
        local last=M.invite.asked[N.Hop.GUILD.short]
        local g,why=true,nil
        if last and ctx.now-last<I.NAME_COOLDOWN then g,why=false,"the guild was asked "..math.floor(ctx.now-last).." s ago." end
        if g and M.invite.lastAsk and ctx.now-M.invite.lastAsk<I.GLOBAL_COOLDOWN then g,why=false,"one ask every "..I.GLOBAL_COOLDOWN.." s." end
        return {label="Ask guild (chat)",enabled=g,reason=why,mode="guild",
            detail="a prefilled /g LayerSwap request for hosts in your guild on that layer; you press Enter"}
    end
    local how=cand and (cand.addon and ("Hop via "..cand.name) or ("Ask "..cand.name.." (chat)")) or "Hop"
    local detail=cand and (cand.addon and ("one LayerSwap request whispered to "..cand.name.." ("..cand.source..(cand.nonhost and "; not hosting; may not answer" or "")..")")
        or ("a prefilled chat whisper to "..cand.name.." (no host addon known); you press Enter")) or nil
    return {label=how,enabled=ok,reason=reason,detail=detail,candidate=cand}
end
-- shown: the preview the user clicked (button or /le reports). The click acts on that candidate and mode only:
-- if the live pick differs now, nothing is sent and the row is redrawn.
function M.hopTo(record,shown)
    if not N.Trust.own(M.store,now()) then return M.blindHop(shown) end
    if M.hopAnyBusy() then return false end
    local ctx=M.hopContext()
    local cand=N.Hop.candidate(record,(M.candidates()))
    local was=S.tab(shown) and shown.candidate or nil
    if S.tab(shown) and shown.mode=="guild" and cand==nil then return M.guildAsk(record,ctx) end
    if not S.tab(shown) or (shown.mode=="guild") or (cand==nil)~=(was==nil) or (cand and (cand.name~=was.name or cand.addon~=was.addon)) then
        M.say("LayerEnemies: hosts changed, check again.")
        if N.UI then N.UI.refresh() end
        return false
    end
    local ok,result,line=N.Hop.request(M.hop,record,cand,ctx)
    if not ok then M.say("LayerEnemies: "..result); return false end
    if result=="whisper" then
        if M.openWhisper(cand.name,line) then
            M.say("LayerEnemies: no host addon is known for "..cand.name.."; a whisper to them is in your chat box - press Enter to send it.")
        else M.say("LayerEnemies: open a whisper to "..cand.name.." manually, then type:"); M.say(I.MESSAGE) end
        return true
    end
    M.say("LayerEnemies: asked "..cand.name.." ("..cand.source..") for an invite to layer "..N.Layer.key(record.layer.value)
        ..". Accept the invite yourself; nothing else is sent.")
    return true
end
-- The guild-chat request: drafted into the chat box, sent by the player with Enter.
function M.guildAsk(record,ctx)
    if not N.Trust.own(M.store,now()) then return M.blindHop() end
    if M.hopAnyBusy() then return false end
    local ok,line=N.Hop.guildRequest(M.hop,record,ctx)
    if not ok then M.say("LayerEnemies: "..line); return false end
    if M.openChat(line) then
        M.say("LayerEnemies: a guild request is in your chat box - press Enter to send it. Hosts in your guild on that layer may invite you.")
    else
        M.say("LayerEnemies: type or copy this line into guild chat:"); M.say(line)
    end
    return true
end
function M.hopIndex(index)
    local list=M.hopList
    if not list or now()-list.at>120 then M.say("LayerEnemies: run /le reports first, then /le hop <number>."); return false end
    local record=index and list.records[index]
    if not record then M.say("LayerEnemies: no such number in the last /le reports list."); return false end
    return M.hopTo(record,list.shown and list.shown[index])
end
-- A Friendly/hosts row that has a layer from Bulo or LayerSwap: Hop via that host. Same shape and the same
-- "what was shown is what is asked" rule as hopPreview/hopTo. Returns nil for a row without a host record.
function M.hostPreview(c)
    if not N.Trust.own(M.store,now()) then return M.blindPreview() end
    if c.flhKey and not N.Hop.hostCandidate(c) then return N.FLHMember.preview(c) end
    local ctx=M.hopContext()
    local record=N.Hop.hostRecord(c,ctx.own.zone)
    if not record then return nil end
    local cand=N.Hop.hostCandidate(c)
    if not L.key(N.Trust.own(M.store,now())) or c.unknownOwn then
        return {label="Hop via "..c.name,enabled=false,reason=I.HINT,candidate=cand,record=record}
    end
    local ok,reason=N.Hop.check(record,cand,ctx)
    if ok then
        local last=M.invite.asked[cand.short]
        if last and ctx.now-last<I.NAME_COOLDOWN then ok,reason=false,cand.name.." was asked "..math.floor(ctx.now-last).." s ago." end
        if ok and M.invite.lastAsk and ctx.now-M.invite.lastAsk<I.GLOBAL_COOLDOWN then ok,reason=false,"one ask every "..I.GLOBAL_COOLDOWN.." s." end
    end
    return {label="Hop via "..cand.name,enabled=ok,reason=ok and nil or reason,detail="one LayerSwap request whispered to "..cand.name.." ("..cand.source..(cand.nonhost and "; not hosting; may not answer" or "")..")",
        candidate=cand,record=record}
end
-- c: the row as it was shown; shown: the preview the user clicked (nil from /le hop host). One click, one whisper
-- through Hop.request (its preconditions and cooldowns); a row that changed since it was shown sends nothing.
function M.hopHostTo(c,shown)
    if not N.Trust.own(M.store,now()) then return M.blindHop(shown) end
    if c.flhKey and not N.Hop.hostCandidate(c) then return N.FLHMember.hop(c,shown) end
    if M.hopAnyBusy() then return false end
    if not L.key(N.Trust.own(M.store,now())) or c.unknownOwn then M.say("LayerEnemies: "..I.HINT); return false end
    local live
    for _,row in ipairs((M.candidates())) do if row.short==c.short then live=row; break end end
    if not live then
        local why=c.layer and L.same(c.layer,N.Trust.own(M.store,now())) and not M.store.ambiguous(now()) and "that host is on your layer already." or "hosts changed, check again."
        M.say("LayerEnemies: "..why); if N.UI then N.UI.refresh() end
        return false
    end
    local was=N.Hop.hostCandidate(c)
    local cand=N.Hop.hostCandidate(live)
    local shownCand=S.tab(shown) and shown.candidate or was
    -- the host flag and the LayerSwap uid are part of what was shown: a change sends nothing
    if live.layer~=c.layer or live.unknownOwn or (live.host==true)~=(c.host==true) or not cand or not shownCand
        or cand.name~=shownCand.name or cand.source~=shownCand.source or cand.uid~=shownCand.uid then
        M.say("LayerEnemies: hosts changed, check again."); if N.UI then N.UI.refresh() end
        return false
    end
    local ctx=M.hopContext()
    local record=N.Hop.hostRecord(live,ctx.own.zone)
    local ok,result=N.Hop.request(M.hop,record,cand,ctx)
    if not ok then
        M.say("LayerEnemies: "..(result=="that report is on your layer already." and "that host is on your layer already." or result))
        return false
    end
    M.say("LayerEnemies: asked "..cand.name.." ("..cand.source..") for an invite to layer "..live.layer..". Accept the invite yourself; nothing else is sent.")
    return true
end
function M.hopHost(index)
    local list=M.hostList
    if not list or now()-list.at>120 then M.say("LayerEnemies: run /le hosts first, then /le hop host <number>."); return false end
    local row=index and list.rows and list.rows[index]
    if not row then M.say("LayerEnemies: no such number in the last /le hosts list."); return false end
    if not N.Trust.own(M.store,now()) then return M.blindHop() end
    if not L.key(N.Trust.own(M.store,now())) or row.unknownOwn then M.say("LayerEnemies: "..I.HINT); return false end
    if not row.flhKey and not N.Hop.hostRecord(row,M.store.zone) then
        M.say("LayerEnemies: no host addon is known for "..row.name.."; /le ask "..index.." puts a whisper in your chat box instead.")
        return false
    end
    return M.hopHostTo(row,nil)
end
-- The only caller of the guild question: /le hosts find and the Find hosts button.
function M.findHosts()
    local ok,message=N.Hosts.ask(M.heard,now(),S.call(IsInGuild)==true)
    -- the same click asks LayerEnemies hosts with one F|1 (sent only when the Q went out: guild, 60 s)
    if ok then
        N.Relay.spend(now(),false)
        local sentF=N.Wire.send("LEGW1",N.Relay.findLine(),"GUILD",nil,{prio="click"})
        if sentF then message=message.."; LayerEnemies hosts were asked too" end
    end
    M.say("LayerEnemies: "..message)
    if N.UI then N.UI.refresh() end
    return ok
end
function M.hosts()
    guarded(M.poll)
    local list,status=M.candidates()
    local names={}
    M.say("LayerEnemies - friendly players on other layers, your zone only. Your layer: "..(L.key(N.Trust.own(M.store,now())) or "Unknown"))
    if not L.key(N.Trust.own(M.store,now())) then M.say(I.HINT) end
    if #list==0 then M.say("No one to ask right now.") end
    for i,c in ipairs(list) do
        names[i]=c.name
        M.say(i..". "..c.name.." | "..M.hostPlace(c)..(c.probably and " (probably your layer: your key is ambiguous)" or "").." | "..table.concat(c.sources," + ")..(c.host and " | host" or "").." | "..ago(c.age).." ago")
    end
    M.hostList={at=now(),names=names,rows=list}
    M.say("Bulo: "..status.bulo.." / LayerSwap: "..status.book.." / War Effort reporters: "..status.reports.." / Forever Layer Hop: "..status.flh)
    M.say("/le hop host <number> asks that host directly: one LayerSwap whisper per click.")
    M.say("/le hop <number> from /le reports asks one host on that layer directly (one whisper per click).")
    M.say("/le ask <number> puts a whisper in your chat box; you press Enter. Nothing is sent, accepted or left for you.")
    M.say("/le hosts find asks the guild's Bulo users for their layers (one guild message, at most once a minute).")
end
function M.askIndex(index)
    local list=M.hostList
    if not list or now()-list.at>120 then M.say("LayerEnemies: run /le hosts first, then /le ask <number>."); return false end
    local name=index and list.names[index]
    if not name then M.say("LayerEnemies: no such number in the last /le hosts list."); return false end
    -- a row listed while our layer was unknown is checked against the live list: changed, nothing is drafted
    local row=list.rows and list.rows[index]
    if S.tab(row) and row.unknownOwn then
        local live; for _,c in ipairs((M.candidates())) do if c.short==row.short then live=c; break end end
        if not live or not live.unknownOwn or live.layer~=row.layer then
            M.say("LayerEnemies: hosts changed, check again."); return false
        end
    end
    return M.askInvite(name)
end
-- Only notices a join; invites are accepted and groups are left by the user.
-- Auto accept and leave (0.4.0): on by default, saved as LayerEnemiesDB.autoHop.
M.AUTO_WINDOW,M.AUTO_LEAVE,M.AUTO_FAIL,M.AUTO_JOIN=120,3,30,60
M.BLIND_PARTNERS=1
function M.autoHop() return M.auto~=nil and M.auto.on==true end
function M.clearAutoGroup()
    local g=M.auto.group
    -- Only an auto-owned round ends with its group; a player's ask survives auto toggles.
    if g and g.blind and not g.manual then M.hopDone() end
    M.auto.group=nil
end
function M.setAutoHop(on)
    M.auto.on=on==true; if S.tab(LayerEnemiesDB) then LayerEnemiesDB.autoHop=M.auto.on end
    if not M.auto.on then M.clearAutoGroup() end
    M.say(M.auto.on and "LayerEnemies: Auto accept and leave is on: the invite of the host you asked by Hop is accepted, and that group is left once you moved (or after 30 s without a move)."
        or "LayerEnemies: Auto accept and leave is off: invites and groups are left to you.")
    if N.UI then N.UI.refresh() end
end
-- PARTY_INVITE_REQUEST: accept only the host our own hop asked (whole name, as Hop.receive; for the guild ask an
-- online guild member), within 120 s of the ask, while not grouped and not in an instance. Combat is allowed; anything
-- else is left to the player.
function M.partyInvite(name)
    N.FLHMember.checkGuest()
    -- Any readable, not-known-failed inviter ends fan-out; auto-accept below still requires an asked name.
    if M.hopAnyState and M.hopAnyState.round then
        if not M.hopAnySafe() then return end
        if N.HopAny.invite(M.hopAnyState,name,now()) then A.whoEnd("stop") end
    end
    if M.auto.group then return end
    local p=M.invite.pending
    local time=now()
    if not S.tab(p) or not p.auto or not S.num(p.at) or time-p.at>M.AUTO_WINDOW or time<p.at then return end
    if S.secret(name) then return end
    local inviter,short=I.name(name)
    if not inviter then return end
    if p.any then
        if not p.asked[short] then return end
        if A.location()~=p.zone then return end
    elseif p.guild then
        -- an online guildmate who answered our ask or is a listed host (not any guildmate: a dungeon invite would
        -- otherwise be accepted and then left)
        if A.guildMember(inviter)~=true then return end
        local g=M.hop.guildAsk
        if not ((g and g.answered and g.answered[short]) or listedHost(short)) then return end
    elseif short~=p.short then return end
    if p.blind then p.invited=inviter end
    if A.grouped() or A.inInstance()~=false then return end
    if not M.autoHop() then
        if p.blind then
            M.auto.group={host=inviter,short=short,at=time,blind=p,manual=true,zone=p.zone}
        end
        return
    end
    local ok,why=N.Wire.accept(time)
    -- the client refused or threw: the ask is spent all the same (no second try on the next invite)
    if not ok then if p.any or why=="error" then M.invite.pending=nil end; return end
    if p.flh then N.FLHMember.stop() end
    if p.blind then p.accepted=true end
    M.invite.pending=nil   -- one accept per ask: a later invite from the same host is left to the player
    N.Wire.hideInvite()
    after(0,function() N.Wire.hideInvite() end)
    local shown=(inviter:match("^([^%-]+)%-")) or inviter
    M.auto.group={host=shown,short=short,target=p.target,at=time,any=p.any,from=p.from,zone=p.zone,trustBefore=N.Trust.own(M.store,time),blind=p.blind and p or nil}
    M.say("LayerEnemies: accepted "..shown.."'s invite")
end
local function hostLeads(g)
    for i=1,4 do
        local u="party"..i
        if S.call(UnitExists,u)==true then
            local n,realm=S.call(UnitName,u)
            n,realm=S.str(n,60),S.str(realm,60)
            local _,key
            if n then _,key=I.name(realm and realm~="" and (n.."-"..realm) or n) end
            if key and key==g.short then return S.call(UnitIsGroupLeader,u)==true end
        end
    end
    return false
end
-- Leaves only the group joined through that accepted invite: led by the host, not a raid, not led by us. Leaves 3 s
-- after our server key changes to the target (a key learned after joining), or 30 s after joining without a move.
function M.blindLeave(g,time)
    if A.inCombat() then return end
    if M.autoHop() and not g.manual then N.Wire.leave(time) end
    M.clearAutoGroup(); M.hopDone()
end
function M.autoTick()
    local g=M.auto and M.auto.group
    local pending=M.blindPending
    if not g then
        if pending and (now()<pending.at or now()-pending.at>M.AUTO_WINDOW) then
            -- Drafts arm only at the observed send event; silence is not a missed invite.
            M.blindExpired(pending)
        end
        return
    end
    if not M.autoHop() and not g.blind then M.clearAutoGroup(); return end
    local time=now()
    if not g.blind and not N.Trust.own(M.store,time) then
        -- No pre-ask proxy was taken for a known hop. Never invent one.
        g.blind={before=N.HopProbe.snapshot({}),invited=g.host,accepted=true}; g.check=1; g.leaveAt=nil
        if g.joinedAt then
            for _,delay in ipairs(N.HopProbe.CHECKS) do
                after(math.max(0,g.joinedAt+delay-time),function() if M.auto.group==g then guarded(M.autoTick) end end)
            end
        end
    end
    if g.any and (A.location()~=g.zone or M.store.zone~=g.zone) then M.clearAutoGroup(); return end
    local grouped=S.call(IsInGroup)==true
    if not g.joinedAt then
        if not grouped then
            if time-g.at>M.AUTO_JOIN then
                M.clearAutoGroup()
                if g.blind then M.blindExpired(g.blind) end
            end
            return
        end
        g.joinedAt=time; g.joinKey=L.key(N.Trust.own(M.store,now()))
        if g.blind then
            g.check=1
            for _,delay in ipairs(N.HopProbe.CHECKS) do
                after(delay,function() if M.auto.group==g then guarded(M.autoTick) end end)
            end
        else after(M.AUTO_FAIL+0.1,function() guarded(M.autoTick) end) end
    end
    if g.blind then g.blind.joinedAt=g.joinedAt end
    local party=A.party()
    if not grouped or not party or party.raid~=false or party.leader or not hostLeads(g) then
        M.clearAutoGroup(); if g.blind then M.hopDone() end; return
    end
    -- Never inside an instance. Blind hops additionally require a hop-only party.
    if A.inInstance()~=false then M.clearAutoGroup(); if g.blind then M.hopDone() end; return end
    if g.blind then
        if #party.members~=M.BLIND_PARTNERS then M.clearAutoGroup(); M.hopDone(); return end
        if g.leaveAt then
            if time>=g.leaveAt then M.blindLeave(g,time) end
            return
        end
        local due=N.HopProbe.CHECKS[g.check]
        if not due or time-g.joinedAt<due then return end
        local result=N.HopProbe.judge(g.blind.before,M.blindSnapshot(),g.transfer)
        g.check=g.check+1
        local changed=result=="creatures" or result=="players" or result=="transfer"
        if changed or not N.HopProbe.CHECKS[g.check] then
            if changed then N.Find.changed(M.find,g.joinedAt) end
            M.blindResult(result,g.host)
            g.leaveAt=changed and time+M.AUTO_LEAVE or time
            after(changed and M.AUTO_LEAVE or 0,function() if M.auto.group==g then guarded(M.autoTick) end end)
            if not changed then M.blindLeave(g,time) end
        end
        return
    end
    if g.any and (not L.key(N.Trust.own(M.store,now())) or L.same(N.Trust.own(M.store,now()),g.from)) then g.leaveAt=nil end
    if g.leaveAt then
        if time>=g.leaveAt then
            N.Wire.leave(time); M.clearAutoGroup(); M.hopDone()
        end
        return
    end
    local key=L.key(N.Trust.own(M.store,now()))
    local moved=g.any and key and key~=g.from or (not g.any and key and key==L.key(g.target) and key~=g.joinKey)
    if moved then
        N.Trust.hop(M.store,g.short,g.trustBefore,N.Trust.own(M.store,time),true,time,g.joinedAt)
        M.trustRefresh()
        g.leaveAt=time+M.AUTO_LEAVE
        M.say("LayerEnemies: moved to layer "..key..", leaving the group")
        after(M.AUTO_LEAVE+0.05,function() guarded(M.autoTick) end)
        return
    end
    if time-g.joinedAt>=M.AUTO_FAIL then
        N.Trust.hop(M.store,g.short,g.trustBefore,N.Trust.own(M.store,time),true,time,g.joinedAt)
        M.trustRefresh()
        if g.any then N.HopAny.failed(M.hopAnyState,g.short,time) end
        N.Wire.leave(time); M.clearAutoGroup(); M.hopDone()
        M.say("LayerEnemies: hop failed: "..g.host.." could not move you")
    end
end
-- PLAYER_GUILD_UPDATE: out of the guild, or in another one, hosting goes inactive (still saved on), the owed H and
-- a scheduled F answer are dropped, and the roster-seen flag is reset, so an H in a new guild waits for its roster.
-- An update that changes nothing (same guild) keeps everything.
--
-- guildSeen: the guild name known this session; guildLeft: a leave was seen this session; guildUnknown: a switch
-- was seen but the new guild's name is not readable yet (hosting stays inactive until a readable name and then
-- that guild's roster). At login an unreadable name is no change.
local function guildSwitch(name)
    M.guildSeen=name; M.guildUnknown=(name==nil); M.guildBlink=nil
    M.guildReset()
    M.askRoster(now())
end
-- guildCheck(fromRoster) -> true when a roster arriving now may count as our guild's roster
function M.guildCheck(fromRoster)
    local inGuild=S.call(IsInGuild)==true
    if not inGuild then
        if M.watch then N.Watch.reset(M.watch,now()) end
        if not fromRoster then M.guildLeft=true; M.guildSeen=nil; M.guildUnknown=nil; M.guildBlink=nil; M.guildReset() end
        return false
    end
    local name=S.str((S.call(GetGuildInfo,"player")),100)
    if M.guildUnknown then
        if not name then return false end
        -- the first readable name after a switch: ask for that guild's roster
        M.guildSeen=name; M.guildUnknown=nil; M.askRoster(now()); return false
    end
    if name then
        -- the same guild (also after a blink): counted; a blink ends here
        if M.guildSeen==name then M.guildBlink=nil; return true end
        if M.guildSeen==nil and not M.guildLeft then M.guildSeen=name; return true end   -- login
        guildSwitch(name); return false
    end
    -- name unreadable: at login (nothing known, no leave seen) no change; otherwise a switch to an unknown guild
    if M.guildSeen==nil and not M.guildLeft then return true end
    -- a roster while the name blinks: not counted (it could be another guild's), nothing reset; the next one decides
    if fromRoster then return false end
    -- a guild event with the name unreadable: after a leave, an unknown guild (its roster first); in a known guild,
    -- a blink: nothing is dropped, hosting does not act (guildWhy) until a readable name says which guild it is
    if M.guildSeen==nil then guildSwitch(nil) else M.guildBlink=true end
    return false
end
function M.guildChanged()
    local same=M.guildCheck(false)
    if not M.hostCheck() then return end
    -- a readable event naming the guild we know (after a blink): hosting acts again
    if same and M.host and M.host.want and not M.host.on then M.hostResume(false) end
end
function M.guildReset()
    S.clear(M.trustClaims)
    if M.watch then N.Watch.reset(M.watch,now()) end
    if M.share then N.Share.cancel(M.share,M.store.localSeen,now()) end
    N.OwnDeath.cancel()
    if not M.host then return end
    M.host.guildToken=(M.host.guildToken or 0)+1
    M.host.announceOwed=nil; M.host.answerDue=nil; M.host.held=nil
    A.roster.at=nil
    if M.host.on then
        M.host.on=false; M.host.inactive=M.hostWhyNot() or "waiting for the new guild's roster."
        M.say("LayerEnemies: hosting for your guild is ON but inactive: "..M.host.inactive:gsub("%.$","").." (/le host off to stop).")
        if N.UI then N.UI.refresh() end
    end
end
-- Our own sightings out (lane A1). One report id per report, saved, 1 to 65535 and round again (War Effort expects
-- it to keep rising across sessions).
M.WE_READER=600
function M.nextReportId()
    local db=S.tab(LayerEnemiesDB) and LayerEnemiesDB or {}
    local id=S.num(db.weReportId)
    id=(id and id>=1 and id<=65535 and id%1==0) and id%65535+1 or 1
    db.weReportId=id
    return id
end
local function shareLayer(rep, time)
    -- A report has one layer field: every own sighting must have been made under
    -- the current full key, including its zoneUID. Bulo refreshes cannot rebind it.
    local key=not M.store.ambiguous(time) and L.key(N.Trust.own(M.store,now())) or nil
    for _,e in ipairs(rep.enemies) do if e.ownKey~=N.Trust.own(M.store,now()) then key=nil; break end end
    return key
end
function M.shareTick()
    if not M.share or not M.sharing() then return end
    local time=now()
    local zone,x,y=A.location()
    if not zone or zone~=M.store.zone then return end
    local rep=N.Share.pick(M.share,M.store.localSeen,time,zone,M.watch)
    local public=N.Share.pickWe(M.share,M.store.localSeen,time,zone)
    if not rep and not public then return end
    local rid=M.nextReportId()
    local inGuild=S.call(IsInGuild)==true
    if rep then
        -- Only fitted, accepted guild names acquire an O cooldown. Public
        -- eligibility is independent of these chunks and their acceptance.
        local line,fitted=N.Relay.ownLine({rid=rid,zone=zone,x=x,y=y,layer=shareLayer(rep,time),now=time,count=rep.count,
            listedOnly=rep.burst.lines<N.Share.LINES,enemies=rep.enemies})
        local accepted
        if line and #fitted>0 and inGuild then
            N.Relay.spend(time,false)
            accepted=N.Wire.send("LEGW1",line,"GUILD",nil,{prio="own",queue=false})
        end
        N.Share.sent(M.share,rep,accepted and fitted or {},time)
    end
    rep=public
    -- C+E retains its own 60 s per-enemy eligibility, even without a guild O,
    -- and the existing two-enemy, position and recently heard reader guards.
    if not rep or rep.count<2 or not (x and y) then return end
    local key=shareLayer(rep,time)
    local stamp=S.num(S.call(GetServerTime))
    if not stamp then return end
    local function heard(kind) local at=M.weHeard[kind]; return at and time>=at and time-at<M.WE_READER end
    local routes={}
    if inGuild and heard("GUILD") then routes[#routes+1]="GUILD" end
    local raid=S.call(IsInRaid)==true
    if A.grouped() then
        if raid and heard("RAID") then routes[#routes+1]="RAID" elseif not raid and heard("PARTY") then routes[#routes+1]="PARTY" end
    end
    if #routes==0 then return end
    local list={}
    for _,e in ipairs(rep.enemies) do list[#list+1]={hash=N.Hash.player(e.name,e.realm),class=e.class,level=e.level} end
    local c=N.WeOut.cluster(rid,zone,x,y,tonumber(key) or 0,rep.count,stamp)
    local parts=N.WeOut.enemies(rid,list,stamp)
    local any=false
    for _,kind in ipairs(routes) do
        if N.Wire.send("WEFF1",c,kind,nil,{net="we",prio="own"}) then
            any=true
            for _,p in ipairs(parts) do N.Wire.send("WEFF1",p,kind,nil,{net="we",prio="own"}) end
        end
    end
    -- to our embassy partners (lane A3): our C and its first E
    if any then
        local dc=N.Protocol.decode(c); if dc then M.embassyForward(M.weName(),dc,c,time,false) end
        local de=parts[1] and N.Protocol.decode(parts[1]); if de then M.embassyForward(M.weName(),de,parts[1],time,false) end
    end
    -- kept for sync answers (lane A2): only what went to War Effort, dated by the server time it was seen
    if any and M.we then
        -- t: when we saw it (the asked age counts from the sighting, not from our send)
        N.WeNet.keep(M.we,{rid=rid,t=rep.at,server=stamp-math.max(0,math.floor(time-rep.at)),map=zone,x=x,y=y,
            layer=tonumber(key) or 0,count=rep.count,enemies=list})
    end
end
-- War Effort membership (lane A2): hello at login and every 180 s to the guild (and to a group with players outside
-- the guild), Q once at login, answers to a guild Q and Y, K "off" to a J. Never in an instance.
local function weOutsiders()
    if not A.grouped() then return false end
    -- in a raid the raid units (raid1..40, ourselves among them), else party1..4
    local raid=S.call(IsInRaid)==true
    for i=1,raid and 40 or 4 do
        local u=(raid and "raid" or "party")..i
        -- Our raid slot can also have split first/surname returns; do not reinterpret it as a remote name.
        if S.call(UnitExists,u)==true and S.call(UnitIsUnit,u,"player")~=true then
            local n,realm=S.call(UnitName,u)
            n,realm=S.str(n,60),S.str(realm,60)
            local full=n and (realm and realm~="" and (n.."-"..realm) or n)
            if full and not M.isMe(full) and A.guildMember(full)~=true then return true end
        end
    end
    return false
end
function M.weHello(reason)
    local st,time=M.we,now()
    if not st or A.inInstance()~=false then return false end
    local stamp=S.num(S.call(GetServerTime))
    if not stamp then return false end
    local zone=A.location()
    local _,class=S.call(UnitClass,"player")
    local t={map=zone or 0,layer=not M.store.ambiguous(time) and tonumber(L.key(N.Trust.own(M.store,now()))) or nil,
        class=S.str(class,20),level=S.num(S.call(UnitLevel,"player")),public=N.Net.allowed("we","public")==true,
        ambiguous=M.store.ambiguous(time)==true}
    t.stamp=0; local said=N.WeOut.hello(t); t.stamp=stamp; local text=N.WeOut.hello(t)
    local any=false
    if M.sharing() and S.call(IsInGuild)==true then
        local last=st.saidAt.GUILD
        if reason=="request" or said~=st.said.GUILD or not last or time<last or time-last>=N.WeNet.SAME then
            if N.Wire.send("WEFF1",text,"GUILD",nil,{net="we",prio="own"}) then
                st.said.GUILD,st.saidAt.GUILD,any=said,time,true
                local d=N.Protocol.decode(text); if d then M.embassyForward(M.weName(),d,text,time,false) end
            end
        end
    end
    if weOutsiders() then
        local kind=S.call(IsInRaid)==true and "RAID" or "PARTY"
        local last=st.saidAt.group
        if said~=st.said.group or not last or time<last or time-last>=N.WeNet.GROUP_EVERY then
            if N.Wire.send("WEFF1",text,kind,nil,{net="we",prio="own"}) then st.said.group,st.saidAt.group,any=said,time,true end
        end
    end
    return any
end
function M.weTick()
    local st=M.we
    if not st or not N.Net.allowed("we","guild") then return end
    local time=now()
    if time>=st.helloDue and A.inInstance()==false then
        M.weHello("timer")
        st.helloDue=time+N.WeNet.EVERY+math.random()*N.WeNet.JITTER
    end
    if not st.queried and st.queryTries<N.WeNet.QUERY_TRIES and time-st.start>=N.WeNet.QUERY and A.inInstance()==false
        and M.sharing() and S.call(IsInGuild)==true then
        local ok,_,called=N.Wire.send("WEFF1",N.WeOut.query(),"GUILD",nil,{net="we",prio="own"})
        if ok then st.queried=true end
        -- an attempt is a send the client was asked for (Wire's own pause or budget is no attempt)
        if called then st.queryTries=st.queryTries+1 end
    end
    local who,text=N.WeNet.nextAnswer(st,time,not N.Trust.own(M.store,time))
    if who then N.Wire.send("WEFF1",text,"WHISPER",who,{net="we",prio="owed"}) end
end
function M.weAsked(msg,kind,sender,time)
    local st=M.we
    if not st or not N.Net.allowed("we","guild") or M.isMe(sender) then return end
    if msg.type=="Q" and kind=="GUILD" then
        if st.askedAt and time>=st.askedAt and time-st.askedAt<N.WeNet.ASKED then return end
        st.askedAt=time; M.weHello("request")
    elseif msg.type=="Y" and kind=="GUILD" then
        local ok,why=N.WeNet.request(st,sender,msg.continent,msg.maxAge,time,A.continent)
        M.lastDrop=ok and "sync queued" or ("sync: "..tostring(why))
    elseif msg.type=="J" and kind=="WHISPER" then
        if not N.WeNet.join(st,sender,time) then return end
        local stamp=S.num(S.call(GetServerTime))
        if stamp then N.Wire.send("WEFF1",N.WeOut.joinOff(msg.id,stamp),"WHISPER",sender,{net="we",prio="owed"}) end
    end
end
-- War Effort embassy (lane A3): the same full own name used by the receive gates.
function M.weName() return (A.ownIdentity()) end
function M.weGuildId()
    if S.call(IsInGuild)~=true or not S.tab(C_Club) then return nil end
    local id=S.call(C_Club.GetGuildClubId)
    if S.num(id) and id>=0 and id%1==0 then return string.format("%d",id) end
    return S.str(id,20) and tostring(id):match("^%d+$") or nil
end
-- why the embassy does not run (nil: it does)
function M.embassyWhy()
    if not N.Net.allowed("we","guild") then return "the War Effort network is off" end
    if not N.Net.allowed("we","public") then return "public networks are off" end
    if S.call(IsInGuild)~=true then return "not in a guild" end
    if not M.weGuildId() then return "your guild's id is not readable" end
    if not N.Directory.channel("we") then
        local realm=S.str(S.call(GetRealmName),60)
        if realm and realm:match("^%d+$") then return "no War Effort channel on this realm (all-digit realm name)" end
        return "no War Effort channel name (realm or faction unreadable)"
    end
    return nil
end
function M.weGuildHeard(sender,msg,time)
    local key=I.key(sender)
    if not key then return end
    local p=M.weGuild[key]
    if not p then
        local n=0; for k,v in pairs(M.weGuild) do if time-v.at>N.WeEmb.CANDIDATE then M.weGuild[k]=nil else n=n+1 end end
        if n>=256 then return end
        p={}; M.weGuild[key]=p
    end
    p.name,p.at=sender,time
    if msg.type=="H" then p.minor,p.public,p.helloAt=msg.minor,msg.public,time end
end
local function embCtx(time)
    local mine=M.weName()
    return {why=M.embassyWhy(),me=mine and mine:lower() or "?",guild=M.weGuildId(),
        isMe=M.isMe,
        isGuildmate=function(n) local k=I.key(n); return A.guildMember(n)==true or (k~=nil and M.weGuild[k]~=nil) end,
        heardInGuild=function(n) local k=I.key(n); local p=k and M.weGuild[k]; return p~=nil and time-p.at<=N.WeEmb.CANDIDATE end,
        inChannel=function(n)
            local list=N.Directory.members("we"); local k=I.key(n)
            if type(list)~="table" or not k then return false end
            for _,m in ipairs(list) do if I.key(m)==k then return true end end
            return false
        end,
        candidates=(function()
            local out={}
            for _,p in pairs(M.weGuild) do
                if time-p.at<=N.WeEmb.CANDIDATE and (p.minor or 0)>=N.WeEmb.MINOR and p.public~=false then out[#out+1]=p.name end
            end
            return out
        end)()}
end
-- the embassy still runs (a queued P or G is dropped when not)
local function embassyOn() return M.emb~=nil and N.Net.allowed("we","guild") and M.embassyWhy()==nil end
-- a guildmate's public=1 counts for 600 s after their last hello
local function publicMate(origin,time)
    local p=M.weGuild[I.key(origin) or ""]
    return p~=nil and p.public==true and p.helloAt~=nil and time>=p.helloAt and time-p.helloAt<=N.WeEmb.HELLO
end
function M.embassyTick()
    if not M.emb then return end
    local time=now()
    -- the War Effort network off or stood down: links announced are taken back at once (Wire lets that one line go)
    if not N.Net.allowed("we","guild") then
        local st=M.emb
        if M.sharing() and st.announced and st.announced~="D|" and S.call(IsInGuild)==true then
            if N.Wire.send("WEFF1","D|","GUILD",nil,{net="we",prio="own",withdraw=true}) then N.WeEmb.announced(st,"D|",{},time) end
        end
        return
    end
    local ctx=embCtx(time)
    -- an empty or unreadable member list greets nobody
    local m=not ctx.why and N.Directory.members("we") or nil
    ctx.members=(type(m)=="table" and m[1]) and m or nil
    for _,o in ipairs(N.WeEmb.tick(M.emb,time,ctx)) do
        if o.kind=="GUILD" then
            if M.sharing() and N.Wire.send("WEFF1",o.text,"GUILD",nil,{net="we",prio="embassy"}) then N.WeEmb.announced(M.emb,o.text,o.links,time) end
        else N.Wire.send("WEFF1",o.text,"WHISPER",o.target,{net="we",prio="embassy",queue=true,still=embassyOn}) end
    end
end
function M.embassyIn(msg,kind,sender,time)
    local ctx=embCtx(time)
    if msg.type=="P" and kind=="WHISPER" then
        local reply=N.WeEmb.presence(M.emb,msg,sender,time,ctx)
        if reply then N.Wire.send("WEFF1",reply.text,"WHISPER",reply.target,{net="we",prio="embassy",queue=true,still=embassyOn}) end
    elseif msg.type=="D" and kind=="GUILD" then
        N.WeEmb.links(M.emb,msg,sender,time)
    elseif msg.type=="W" and kind=="WHISPER" then
        local g,why=N.WeEmb.bridge(M.emb,msg,sender,time,ctx)
        M.lastDrop=g and "bridged" or ("embassy: "..tostring(why))
        if not g then return end
        local function still() return M.sharing() and embassyOn() end
        if M.sharing() and S.call(IsInGuild)==true then N.Wire.send("WEFF1",g,"GUILD",nil,{net="we",prio="embassy",queue=true,still=still}) end
        -- stored as a relayed public report (never passed on to another partner)
        if msg.inner.type~="H" then
            local record=N.Reports.receive(M.receiver,{type="G",origin=msg.origin,inner=msg.inner},{sender=sender,route="WHISPER",now=time,
                serverNow=S.num(S.call(GetServerTime)),zoneFn=A.zone,peers=M.peers})
            if record then T.report(M.store,record,time) end
        end
    end
end
-- origin's own C, E or H to our partners; a guildmate's only if their hello said public = 1, ours only with public on
function M.embassyForward(origin,msg,text,time,guildmate)
    if not M.emb or not origin then return end
    if guildmate and not publicMate(origin,time) then return end
    local ctx=embCtx(time)
    if ctx.why then return end
    for _,o in ipairs(N.WeEmb.forward(M.emb,origin,msg,text,time,ctx)) do
        -- dropped from the queue when the embassy stops, we lose the seat for that guild, or the origin revokes public
        local key,target=o.key,o.target
        local function still()
            local t=now()
            if guildmate and not publicMate(origin,t) then return false end
            if not guildmate and not M.sharing() then return false end
            return embassyOn() and N.WeEmb.seat(M.emb,key,target,t,embCtx(t)), N.Trust.we(M.store,o.text,t,not guildmate)
        end
        N.Wire.send("WEFF1",o.text,"WHISPER",o.target,{net="we",prio="embassy",queue=true,still=still})
    end
end
-- HeadHunter mesh (lanes B1, B2): all by whisper, all public; nothing while public networks are off.
local function hhSide()
    local f=S.call(UnitFactionGroup,"player")
    return f=="Alliance" and "A" or f=="Horde" and "H" or nil
end
function M.hhWorld()
    local regions={[1]="us",[2]="kr",[3]="eu",[4]="tw",[5]="cn"}
    local region=regions[S.num(S.call(GetCurrentRegion)) or 0] or "?"
    local rules
    local G,E=_G.C_GameRules,_G.Enum
    if S.tab(G) and type(G.IsGameRuleActive)=="function" and S.tab(E) and S.tab(E.GameRule) then
        local function on(rule) if rule==nil then return nil end; local ok,v=pcall(G.IsGameRuleActive,rule); return ok and v==true end
        rules=(on(E.GameRule.HardcoreRuleset) and "hc") or (on(E.GameRule.RPRuleset) and "rp") or (on(E.GameRule.PvPRuleset) and "pvp") or nil
    end
    if not rules then
        local name=S.str(S.call(GetRealmName),60)
        name=name and (" "..name:lower().." ")
        if name then
            if name:find("hardcore",1,true) then rules="hc" elseif name:find("roleplay",1,true) or name:find("[%s%-]rp[%s%-%d]") then rules="rp"
            elseif name:find("pvp",1,true) then rules="pvp" elseif name:find("pve",1,true) or name:find("normal",1,true) then rules="pve" end
        end
    end
    return region.."-"..(rules or "?")
end
local function hhCtx(time)
    local st=M.hhNet
    if st then
        local members,at=N.Directory.members("hh")
        if type(members)=="table" and members~=st.directory then
            N.HhNet.roster(st,members,N.HhNet.compact(M.weName() or "?") or "?",at)
            st.directory=members
        end
        N.HhNet.prune(st,time,N.Directory.FRESH)
        N.HhNet.suppress(st,N.Wire.offlineUntil,time)
    end
    local mine=HN_me and HN_me() or nil
    return {world=M.hhWorld(),serverNow=S.num(S.call(GetServerTime)),me=N.HhNet.compact(M.weName() or "?") or "?",side=hhSide(),
        online=N.Directory.count("hh")}
end
-- every HeadHunter line ranks last (mesh); extra opts: still (a queued forward's age check), catchup (a pull's frame)
local function hhSend(text,target,extra)
    if not (text and target) then return end
    local opts={net="hh",prio="mesh",queue=true}
    for k,v in pairs(extra or {}) do opts[k]=v end
    if opts.candidate then
        local st,check=M.hhNet,opts.still
        opts.still=function()
            local time=now(); hhCtx(time) -- apply even a new empty snapshot before a queue pump can send
            return M.hhNet==st and N.HhNet.candidate(st,target,time,N.Directory.FRESH) and (not check or check())
        end
    end
    N.Wire.send("HeadHunter",text,"WHISPER",target,opts)
end
-- hello replies, one per 2 s: sent now when the pace allows, else on a timer (one at a time)
function M.hhHelloPump()
    local st=M.hhNet
    if not st or not N.Net.allowed("hh","public") then return end
    local time=now()
    local ctx=hhCtx(time)
    if not ctx.side then return end
    local who=N.HhNet.nextHello(st,time,ctx.side)
    -- Never queued: a budget backlog must not turn paced hellos into a burst when it drains.
    if who then
        local ok,why,attempted=N.Wire.send("HeadHunter",N.HhNet.frame(ctx.side,"N",N.HhNet.HELLO),"WHISPER",who,{net="hh",prio="mesh"})
        if not ok then N.HhNet.unsent(st,who,why,attempted,time) end
    end
    local delay=N.HhNet.helloDelay(st,time)
    -- Net.after may discard a callback while switched off. A due timestamp, not a sticky boolean, lets a later
    -- enabled pump recover. Superseded callbacks cannot create a second retry chain.
    if not delay then M.hhHelloTimer=nil
    elseif not M.hhHelloTimer or M.hhHelloTimer<=time then
        local due=time+delay+0.05
        M.hhHelloTimer=due
        if not N.Net.after("hh",delay+0.05,function()
            if M.hhHelloTimer~=due then return end
            M.hhHelloTimer=nil; guarded(M.hhHelloPump)
        end,"public") then M.hhHelloTimer=nil end
    end
end
-- The observer shares correlation with Wire's chat filter; either may run first.
function M.whisperSystem(text,...)
    if N.Wire.system(text,select(10,...)) and M.hhNet then
        N.HhNet.suppress(M.hhNet,N.Wire.offlineUntil,now())
        if not N.HhNet.owed(M.hhNet) then M.hhHelloTimer=nil end
    end
end
function M.hhTick()
    local st=M.hhNet
    if not st or not N.Net.allowed("hh","public") then return end
    local time=now()
    local ctx=hhCtx(time)
    if not ctx.side or not ctx.serverNow then return end
    M.hhHelloPump()
    for _,o in ipairs(N.HhNet.ask(st,time,ctx)) do hhSend(o.text,o.target,{candidate=true}) end
    for _,o in ipairs(N.HhNet.pull(st,time,ctx)) do hhSend(o.text,o.target) end
end
function M.hhMesh(text,sender,time)
    local st=M.hhNet
    if not st or not N.Net.allowed("hh","public") then return end
    local ctx=hhCtx(time)
    if not ctx.side or not ctx.serverNow then return end
    local side,t,body=text:match("^1([AH])(%u):(.+)$")
    if not body then return end
    if t=="N" then
        if N.HhNet.heard(st,sender,side,nil,true,time) then M.hhHelloPump() end
    elseif t=="E" then
        for rec in (body.."~"):gmatch("([^~]*)~") do
            local out=N.HhNet.carry(st,rec,sender,side,time,ctx)
            for _,o in ipairs(out) do
                local check=o.still
                hhSend(o.text,o.target,{candidate=true,still=function() return check(S.num(S.call(GetServerTime))) end})
            end
        end
    elseif t=="Q" then
        local pull=body:sub(1,1)=="p"
        local i=0
        for _,o in ipairs(N.HhNet.query(st,body,sender,time,ctx,side)) do
            local text2,target=o.text,o.target
            -- a pull's frames: about one per 2 s, on the pull's own allowance
            local delay=pull and 2*i or (o.delay or 0)
            local extra=pull and {catchup=true,prio="catchup"} or nil
            i=i+1
            if delay>0 then
                if not N.Net.after("hh",delay,function() hhSend(text2,target,extra) end,"public") then hhSend(text2,target,extra) end
            else hhSend(text2,target,extra) end
        end
    elseif t=="O" then N.HhNet.offer(st,sender,body,time)
    elseif t=="S" then N.HhNet.snapshot(st,sender,body,ctx,side)
    elseif t=="H" then
        local guid=S.str(S.call(UnitGUID,"player"),120)
        local home=guid and tonumber(guid:match("^Player%-(%d+)%-"))
        hhSend(N.HhNet.link(st,sender,time,ctx.side,home),sender)
    end
end
-- The hop is over (moved and left, failed, or 120 s without an invite): no ask is pending any more.
function M.hopDone()
    M.blindPending=nil
    N.Hop.clear(M.hop); M.invite.pending=nil
    if M.hopAnyState and M.hopAnyState.round then
        N.HopAny.close(M.hopAnyState,now())
        if N.UI then N.UI.refresh(true) end
    end
end
function M.groupCheck(deferPopup)
    groupTransition()
    M.trustGroup(deferPopup)
    local grouped=A.grouped()
    if grouped then N.FLHMember.stop("joined a group") end
    if grouped and M.hopAnyState and M.hopAnyState.round then M.hopAnyStop("joined a group") end
    -- the hop group ended (left by hand or otherwise): stop tracking at once
    if not grouped and M.wasGrouped and M.auto and M.auto.group and M.auto.group.joinedAt then
        if M.auto.group.blind then M.hopDone() end
        M.clearAutoGroup()
    end
    if grouped and M.auto and M.auto.group and (not M.wasGrouped or M.auto.group.blind) then
        -- Blind leave guards latch on every roster event, before a third member can leave again.
        guarded(M.autoTick)
    elseif grouped and not M.wasGrouped and I.joined(M.invite,now(),L.key(N.Trust.own(M.store,now())),M.store.zone) then
        M.say("LayerEnemies: you joined a group after asking - checking your layer for 60 s.")
        after(I.WATCH+0.5,function() guarded(M.inviteTick) end)
    end
    M.wasGrouped=grouped
end
function M.inviteTick()
    if not M.invite.watch then return end
    local message,note=I.tick(M.invite,now(),L.key(N.Trust.own(M.store,now())),M.store.zone,M.store.ambiguous(now()))
    if message then M.say("LayerEnemies: "..message) end
    if note then M.say("LayerEnemies: "..note) end
end
-- 1.0 consent/status: public networks by default (owner decision 2026-11-14), /le net, /le share.
M.NET_NOTICE="LayerEnemies: public networks ON (War Effort, HeadHunter…). /le net guild to limit to guild only."
function M.watchSync()
    if M.watch then N.Watch.sync(M.watch,M.find,now()) end
end
function M.watchTick()
    if not M.watch then return end
    M.watchSync()
    local same=M.guildCheck(true)
    local allowed=same and not M.guildWhy() and A.inInstance()==false and M.sharing()
    N.Watch.tick(M.watch,now(),allowed)
end
function M.watchNotice(e)
    if not M.watch then return end
    M.watchSync()
    local text=N.Watch.notice(M.watch,e,now(),LayerEnemiesDB.findNotice~=false,A.inInstance())
    if text then M.say(text) end
end
function M.setFindShare(on)
    LayerEnemiesDB.findShare=on==true
    N.Watch.enable(M.watch,on==true,now()); M.watchTick()
    M.say("LayerEnemies: sharing your Find list with the guild is "..(on and "on." or "off; clearing the shared list when guild sending is available."))
end
function M.setFindNotice(on)
    LayerEnemiesDB.findNotice=on==true
    M.say("LayerEnemies: on-site tracked-name notices are "..(on and "on." or "off."))
end
function M.sharing() return not S.tab(LayerEnemiesDB) or LayerEnemiesDB.share~=false end
function M.setShare(on)
    if not on then N.OwnDeath.cancel(); N.BNet.cancel(nil,nil,true); M.overlordCancel(); if N.WarBoardTrack then N.WarBoardTrack.stop() end; N.FLHMember.stop("share off") end
    if S.tab(LayerEnemiesDB) then LayerEnemiesDB.share=on==true end
    N.Directory.sync()
    -- Off cancels all pending guild relays as well as our sync answers. Queued guild/own embassy lines
    -- are dropped by their still checks. A quick off/on must not revive the cancelled relay timers.
    if not on and M.relay then N.Relay.clear(M.relay) end
    -- Cancel the crowd snapshot too, preserving its send and per-name cooldowns.
    if not on and M.share then N.Share.cancel(M.share,M.store.localSeen,now()) end
    if not on and M.we then N.WeNet.forget(M.we) end
    M.say(on and "LayerEnemies: your sightings are shared again; guild sends and relays are enabled, including K own-death lines."
        or "LayerEnemies: your sightings are no longer shared; all guild sends and relays are off (no O or K own-death line). You still receive everyone else's.")
    if N.UI then N.UI.refresh() end
end
local NET_KEYS={we="we",wareffort="we",hh="hh",headhunter="hh"}
local NET_ORDER={"we","hh"}
local function netLines(out)
    for _,key in ipairs(NET_ORDER) do
        local why=N.Net.why(key)
        out(N.Net.LIST[key].name..": "..(why and ("off ("..why..")") or "on"))
    end
end
function M.setConsent(level)
    if not N.Net.setConsent(level) then return false end
    if level=="guild" then M.hopAnyStop("guild-only mode") end
    M.say(level=="guild" and "LayerEnemies: guild only. War Effort, HeadHunter and the other public networks stay off; your guild and group still get your sightings."
        or M.NET_NOTICE)
    if N.UI then N.UI.refresh() end
    return true
end
function M.setNet(key,on)
    if not N.Net.setSwitch(key,on) then return false end
    M.say("LayerEnemies: "..N.Net.LIST[key].name..(on and " switched on." or " switched off."))
    if N.UI then N.UI.refresh() end
    return true
end
function M.quiet(command)
    local state=command:match("^quiet%s+(%a+)$")
    if command=="quiet" then state=N.Wire.quietMode(LayerEnemiesDB.quietWhispers)
    elseif state~="on" and state~="off" and state~="all" then M.say("LayerEnemies: /le quiet on|off|all"); return
    elseif S.tab(LayerEnemiesDB) then LayerEnemiesDB.quietWhispers=state end
    M.say("LayerEnemies: quiet "..state..(state=="on" and " - hide only LayerEnemies' correlated offline whisper notices."
        or state=="all" and not N.Wire.whisperObserverReady() and " - your own typed-whisper protection unavailable; all behaves like on (LayerEnemies whispers only)."
        or state=="all" and " - hide all localized not-found lines except after your own typed whisper (10 seconds)."
        or " - all offline whisper notices stay visible."))
end
function M.warboardTrack(on)
    N.WarBoardTrack.set(on)
    M.say("WarBoard tracking: "..(on and "on" or "off").." (this session; /le warboard track on|off)")
end
function M.net(command)
    local rest=command:match("^net%s*(.-)%s*$") or ""
    if rest=="" then
        M.say("Networks: "..(N.Net.consent()=="public" and "public" or "guild only"))
        M.say("hidden (LayerEnemies whispers): "..N.Wire.hiddenNotices().."; hidden (other addons): "..N.Wire.hiddenOtherNotices().."; shown (your own whisper or mode): "..N.Wire.shownNotices())
        M.say(N.Wire.whisperObserverReady() and "Typed-whisper protection: secure post-hook active."
            or "Typed-whisper protection unavailable; all behaves like on (LayerEnemies whispers only).")
        local ready,missing=N.Wire.whisperObserverReady()
        if not ready then M.say("Missing typed-whisper hook: "..missing..".") end
        netLines(M.say)
        M.say(N.HeadHunter.summary(M.hh.stats))
        local s=M.overlord.stats
        local pool=M.overlordPool() or "unknown (receiving nothing)"
        local cm=M.coming or {}
        M.say("On my way (session): heard="..(cm.heard or 0).." collapsed="..(cm.collapsed or 0).." quiet="..(cm.quiet or 0))
        M.say("Overlord session: lines="..s.lines.." taken="..s.taken.." refused="..s.refused.." · pool "..pool)
        for _,line in ipairs(N.Sources.lines()) do M.say(line) end
        return
    end
    if rest=="warboard" then
        for _,line in ipairs(N.Sources.lines()) do if line:match("^warboard:") then M.say(line) end end
        M.say("WarBoard tracking: "..(N.WarBoardTrack.on and "on" or "off").." (6/min; 3 tries 6s apart, renew 45s; /le warboard track on|off)")
        return
    end
    if rest=="guild" or rest=="public" then M.setConsent(rest); return end
    if N.Sources.has(rest) then for _,line in ipairs(N.Sources.lines(rest)) do M.say(line) end; return end
    local name,state=rest:match("^(%a+)%s+(%a+)$")
    local key=name and (NET_KEYS[name] or (N.Sources.has(name) and name))
    if key and (state=="on" or state=="off") then M.setNet(key,state=="on"); return end
    M.say("/le net; /le net guild; /le net public; /le net wareffort on|off; /le net headhunter on|off")
end
function M.text(command)
    guarded(M.poll)
    local id=N.Trust.own(M.store,now()) or "Unknown"
    say("LayerEnemies - Your layer: "..id.." ("..(M.layerSource or "unknown")..")")
    say("Bulo: "..M.statusBulo); say("War Effort: "..M.statusWE)
    if M.emb then
        local why=M.embassyWhy()
        if why then say("War Effort embassy: off ("..why..")")
        else local p,l=N.WeEmb.summary(M.emb,now()); say("War Effort embassy: on, "..p.." partner(s), "..l.." link(s)") end
    end
    say(N.Net.consent()=="public" and "Networks: public (/le net guild for guild only)" or "Networks: guild only (/le net public to open)")
    netLines(say)
    say(M.sharing() and "Sharing your sightings: on (/le share off)" or "Sharing your sightings: off (/le share on)")
    say("Sharing Battle.net friends and community members with the guild: "..(M.sharingFriends() and "on (/le share friends off)" or "off (/le share friends on)"))
    say("Hop bar: "..((S.tab(LayerEnemiesDB) and S.tab(LayerEnemiesDB.bar) and LayerEnemiesDB.bar.shown) and "on (/le bar off)" or "off (/le bar on)"))
    if M.error then say("Runtime status: "..M.error) end
    say("Your server key: "..(L.key(N.Trust.own(M.store,now())) or "Unknown")..(M.store.ambiguous(now()) and " (ambiguous: another layer of this zone shares it)" or "")
        .." - zone-scoped; an equal key is not proof of the same layer")
    if not L.key(N.Trust.own(M.store,now())) then say(I.HINT) end
    local kind=command=="reports" and "reported" or command=="unclassified" and "unclassified" or "local"
    say(kind=="reported" and "Reported, not confirmed (War Effort; age as the reporter's clock gives it):" or kind=="unclassified" and "Unclassified / same-faction local observations (not confirmed enemies):" or "Opposite-faction players seen by you:")
    local rows
    if kind=="unclassified" then rows=T.rows(M.store,now(),kind)
    else
        local seen,reports=M.namedRows()
        rows=kind=="reported" and reports or seen
    end
    local previous=kind=="local" and T.previous(M.store,now()) or {}
    if #rows==0 and #previous==0 then say(kind=="reported" and "No live reports for your zone." or "No eligible observations.") end
    local numbers,records,shown={},{},{}
    for _,e in ipairs(rows) do
        local when=ago(now()-e.at)
        if e.guild then say(M.overlordText(e).." | "..when.." ago")
        elseif e.friendShare then
            say(e.title.." | "..(e.class or "Unknown class").." | "..tostring(e.level or "?").." | "..e.zone.." | "..e.sourceText.." | "..when.." ago")
        else
        local extra=""
        if kind=="reported" and e.record and not numbers[e.record] then
            records[#records+1]=e.record; numbers[e.record]=#records
            local p=M.hopPreview(e.record); shown[#records]=p
            say("["..#records.."] "..(p.enabled and ("/le hop "..#records..": "..p.detail) or ("no hop: "..p.reason)))
        end
        if e.reporter then
            extra=" | reported by "..e.reporter..(e.via and " via "..e.via or "")..(e.hand~="first" and " | relayed" or "")..(e.positionKind and (" | "..e.positionKind) or "")..(e.untimed and " | time of receipt (no timestamp)" or "")..(e.age and e.age>0 and (" | claimed "..e.age.." s old") or "").." | "..(e.relation=="same" and "same server key as yours" or e.relation=="other" and ("other server key "..tostring(e.reportLayer)) or "layer unknown")
        end
        if e.alsoReported then extra=extra.." | also reported by "..table.concat(e.alsoReported,", ") end
        if e.probablyNote then extra=extra.." | "..e.probablyNote end
        say((e.title or e.name or "Unknown").." | "..(e.class or "Unknown class").." | "..tostring(e.level or "?").." | zone "..tostring(e.zone).." | "..(e.reporter and "received " or "seen ")..when.." ago | "..e.source.." | "..e.confidence..extra..(e.possible and (" | "..e.possible) or "")..(not e.reporter and e.layer==nil and " | layer unknown when seen" or ""))
        end
    end
    for _,e in ipairs(previous) do
        say((e.displayName or e.name or "Unknown").." | "..(e.class or "Unknown class").." · "..M.zoneName(e.zone).." · previous zone | "..tostring(e.level or "?").." | seen "..ago(now()-e.at).." ago")
    end
    if kind=="reported" then M.hopList={at=now(),records=records,shown=shown} end
    if kind=="reported" and #rows>0 then say("To go there, ask a reporter for an invite: /le hosts") end
    if kind=="local" then
        local _,shownReports=M.namedRows()
        local reported=#shownReports
        if reported>0 then say("Reported, not confirmed: "..reported.." more in /le reports") end
    end
    say("Only players seen by you or reported by other players' addons.")
    say("/le window; /le list; /le reports; /le hop <number>; /le hosts; /le hosts find; /le hop host <number>; /le ask <number>; /le find <name>.")
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
    M.npcs=L.new(); M.store=T.new(now()); M.receiver=N.Reports.new(); M.peers=N.Peers.new(); M.hh=N.HeadHunter.new()
    M.overlord=N.Overlord.new()
    M.overlordPeer=N.OverlordPeer.new()
    M.hopAnyState=N.HopAny.new()
    M.hop=N.Hop.new(); M.heard=N.Hosts.new(); M.guildLines={}; M.lfswRate=N.HeadHunter.new(); M.relay=N.Relay.new()
    M.store.ambiguous=function(time) return L.ambiguous(M.npcs,time) end
    groupTransition()
    M.invite=I.new(); M.wasGrouped=A.grouped(); M.share=N.Share.new(); M.weHeard={}; M.we=N.WeNet.new(now())
    M.emb=N.WeEmb.new(); M.weGuild={}; M.hhNet=N.HhNet.new(); M.hhNet.started=now()
    M.host=N.GuildHost.new()   -- guild-only hosting; the wish (want) is saved as LayerEnemiesDB.guildHost
    M.layerSource="unknown"; M.store.zone=A.location(); M.zoneSeen=M.store.zone
    if not S.tab(LayerEnemiesDB) then LayerEnemiesDB={} end
    -- Configuration plus GUID-only owed withdrawals; never sightings or peer records.
    local saved=LayerEnemiesDB
    M.find=N.Find.new(saved.tracked,M.homeRealm()); M.call=N.Call.new(); M.coming=N.Coming.new()
    M.presenceShared={}; M.presenceSharedAlerts={presenceAlerts={}}
    M.friendOut=N.FriendShare.newOut(); M.friendIn=N.FriendShare.newIn(); M.friendStartAt=now()
    -- guildHost: a boolean setting only (hosting for your guild, owner decision 0.4.0); anything else is off
    LayerEnemiesDB={options={},tracked=M.find.names,position=N.UI.position(saved.position),guildHost=saved.guildHost==true}
    M.host.want=LayerEnemiesDB.guildHost
    -- 1.0 networks: consent ("guild" when the player chose guild only, else nil = public) and one switch per network
    LayerEnemiesDB.consent,LayerEnemiesDB.nets=N.Net.load(saved)
    -- sharing our own sightings (O, War Effort C+E) and deaths (K): only a saved false turns it off
    LayerEnemiesDB.share=saved.share~=false
    LayerEnemiesDB.quietWhispers=N.Wire.quietMode(saved.quietWhispers)
    LayerEnemiesDB.findShare=saved.findShare~=false
    -- 1.2.4: sharing Battle.net friends and community members with the guild; only a saved false turns it off
    LayerEnemiesDB.shareFriends=saved.shareFriends~=false
    LayerEnemiesDB.findNotice=saved.findNotice~=false
    -- 1.2.5 hop bar: shown (default on), one-line mode and position
    LayerEnemiesDB.bar=N.HopBar.load(saved.bar)
    if N.WarBoardTrack then LayerEnemiesDB.warboardOwed=N.WarBoardTrack.load(saved.warboardOwed) end
    M.watch=N.Watch.new(M.find,now(),LayerEnemiesDB.findShare)
    LayerEnemiesDB.call=saved.call~=false
    LayerEnemiesDB.callArt=saved.callArt~=false
    LayerEnemiesDB.found=saved.found~=false
    -- the first-login line, once per character, while some network ships and no guild-only choice was made
    LayerEnemiesDB.netNotice=saved.netNotice==true or nil
    local ships=false; for key in pairs(N.Net.LIST) do if N.Net.SHIP[key]==true then ships=true end end
    if ships and not LayerEnemiesDB.netNotice then
        if N.Net.chosen()~="guild" then M.say(M.NET_NOTICE) end
        LayerEnemiesDB.netNotice=true
    end
    -- autoHop: on by default; only a saved false turns it off
    LayerEnemiesDB.autoHop=saved.autoHop~=false
    -- War Effort report id (lane A1): must keep rising across sessions; anything but 1..65535 starts again at 0
    local rid=S.num(saved.weReportId)
    LayerEnemiesDB.weReportId=(rid and rid>=1 and rid<=65535 and rid%1==0) and rid or nil
    M.auto={on=LayerEnemiesDB.autoHop,group=nil}
    if S.tab(C_ChatInfo) then
        S.call(C_ChatInfo.RegisterAddonMessagePrefix,"WEFF1")
        S.call(C_ChatInfo.RegisterAddonMessagePrefix,"HeadHunter")
        -- replies to our hop request, and Bulo guild layer lines; we answer neither
        S.call(C_ChatInfo.RegisterAddonMessagePrefix,"LayerSwap")
        S.call(C_ChatInfo.RegisterAddonMessagePrefix,"LFSw")
        S.call(C_ChatInfo.RegisterAddonMessagePrefix,"FLHNET2") -- legacy receive owner; F2 sends through Wire
        S.call(C_ChatInfo.RegisterAddonMessagePrefix,"LEGW1")
        -- the Spy family: read only (lane C1)
        S.call(C_ChatInfo.RegisterAddonMessagePrefix,"[Spy]")
        S.call(C_ChatInfo.RegisterAddonMessagePrefix,"ForeverSpy1")
        S.call(C_ChatInfo.RegisterAddonMessagePrefix,"FSENT03")
        -- guild incidents: read only, GUILD (lane C2)
        S.call(C_ChatInfo.RegisterAddonMessagePrefix,"GBOUNTY")
        S.call(C_ChatInfo.RegisterAddonMessagePrefix,"WALLOFSHAME")
        S.call(C_ChatInfo.RegisterAddonMessagePrefix,"FTold1")
        S.call(C_ChatInfo.RegisterAddonMessagePrefix,"OverlordF") -- receive only
        S.call(C_ChatInfo.RegisterAddonMessagePrefix,"OpenMapLoc") -- receive only, including hellos
    end
    N.Wire.registerSystemFilter()
    N.Wire.registerWhisperObserver()
    N.Sources.start()
    _G.SLASH_LAYERENEMIES1="/le"
    SlashCmdList.LAYERENEMIES=function(command)
        local raw=(S.str(command,110) or ""):match("^%s*(.-)%s*$")
        command=raw:lower()
        -- Collapse runs of spaces so "/le find  share off" still reaches the opt-out.
        local words=command:gsub("%s+"," ")
        if words:match("^find share") or words:match("^find notice") then command=words end
        if command=="find share" or command=="find notice" then
            M.say("LayerEnemies: usage: /le "..command.." on|off"); return
        end
        if command=="find share on" or command=="find share off" then guarded(M.setFindShare,command=="find share on"); return end
        if command=="find notice on" or command=="find notice off" then guarded(M.setFindNotice,command=="find notice on"); return end
        if words=="warboard track on" or words=="warboard track off" then guarded(M.warboardTrack,words=="warboard track on"); return end
        if words=="warboard track" then M.say("/le warboard track on|off"); return end
        if command=="presence" then M.presenceStatus(); return end
        if command:match("^blind") then
            if N.Trust.manual(M.store,command:match("^blind (%a+)$")) then
                N.Trust.notice(M.store,now(),true)
                M.say("LayerEnemies: layer trust "..N.Trust.state(M.store,now()).." (session only).")
                M.poll()
            else M.say("LayerEnemies: /le blind on|off|auto") end
            return
        end
        if command=="layer" then
            if not N.Trust.own(M.store,now()) then M.say("layer IDs are not readable on this client")
            else guarded(N.ChehulNet.layer) end
            return
        end
        if command=="find" then M.track(nil); return end
        if command:match("^find%s+") then M.track(raw:match("^%S+%s+(.+)$")); return end
        if command=="hop stop" then guarded(M.hopAnyStop); return end
        if command=="hop any" then guarded(M.hopAny); return end
        if command=="hop flh" then guarded(N.FLHMember.hop); return end
        if command=="hop auto on" then guarded(M.setAutoHop,true); return end
        if command=="net" or command:match("^net%s") then guarded(M.net,command); return end
        if command=="quiet" or command:match("^quiet%s") then guarded(M.quiet,command); return end
        if command=="share on" or command=="share off" then guarded(M.setShare,command=="share on"); return end
        if command=="share friends on" or command=="share friends off" then guarded(M.setShareFriends,command=="share friends on"); return end
        if words=="bar" or words:match("^bar ") then guarded(N.HopBar.command,words:match("^bar (%S+)$")); return end
        if command=="call on" or command=="call off" then guarded(M.setCall,command=="call on"); return end
        if command=="call art on" or command=="call art off" then guarded(M.setCallArt,command=="call art on"); return end
        if command=="found on" or command=="found off" then guarded(M.setFound,command=="found on"); return end
        if command=="hop auto off" then guarded(M.setAutoHop,false); return end
        local index=command:match("^ask%s+(%d%d?)$")
        local host=command:match("^hop%s+host%s+(%d%d?)$")
        if host or command:match("^hop%s+host") then guarded(M.hopHost,tonumber(host)); return end
        local hop=command:match("^hop%s+(%d%d?)$")
        if hop or command=="hop" then guarded(M.hopIndex,tonumber(hop)); return end
        if command=="" then guarded(N.UI.toggle)
        elseif command=="hosts" then guarded(M.hosts)
        elseif command=="hosts find" then guarded(M.findHosts)
        elseif command=="host" then guarded(M.hostStatus)
        elseif command=="host on" then guarded(M.setHost,true)
        elseif command=="host off" then guarded(M.setHost,false)
        elseif index or command:match("^ask") then guarded(M.askIndex,tonumber(index))
        else guarded(M.text,command) end
    end
    N.UI.create()
    guarded(N.HopBar.start)
    if M.host.want then M.hostResume(true) end
    heartbeat()
end
local frame=CreateFrame("Frame")
M.frame=frame
frame:Hide()
for _,event in ipairs({"ADDON_LOADED","PLAYER_LOGIN","PLAYER_LOGOUT","PLAYER_ENTERING_WORLD","ZONE_CHANGED_NEW_AREA","ZONE_CHANGED","SHARD_TRANSFER","PLAYER_TARGET_CHANGED","UNIT_TARGET","UPDATE_MOUSEOVER_UNIT","NAME_PLATE_UNIT_ADDED","NAME_PLATE_UNIT_REMOVED","CHAT_MSG_ADDON","BN_CHAT_MSG_ADDON","BN_FRIEND_LIST_SIZE_CHANGED","BN_FRIEND_INFO_CHANGED","BN_FRIEND_ACCOUNT_ONLINE","BN_FRIEND_ACCOUNT_OFFLINE","CLUB_MEMBER_PRESENCE_UPDATED","WHO_LIST_UPDATE","PLAYER_REGEN_DISABLED","PLAYER_REGEN_ENABLED","GROUP_ROSTER_UPDATE","GUILD_ROSTER_UPDATE","PARTY_INVITE_REQUEST","CHAT_MSG_WHISPER_INFORM","CHAT_MSG_GUILD","PLAYER_GUILD_UPDATE","CHAT_MSG_CHANNEL_NOTICE","CHAT_MSG_SYSTEM","PLAYER_DEAD","PLAYER_ALIVE","PLAYER_UNGHOST"}) do
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
    if event=="PLAYER_LOGOUT" then M.overlordClosing=true;guarded(M.overlordCancel);
        if N.WarBoardTrack then N.WarBoardTrack.stop(true) end
        N.BNet.pump(now());guarded(M.hopAnyStop,"reload or logout"); A.whoEnd("reload")
    elseif event=="CHAT_MSG_ADDON" then guarded(M.message,...)
    elseif event=="BN_CHAT_MSG_ADDON" then
        local prefix,text,channel,id=...
        if not S.secret(prefix) and prefix=="OpenMapLoc" then guarded(M.openmapBn,...)
        elseif not S.secret(prefix) and prefix=="OverlordF" then guarded(M.overlordBn,...)
        elseif not S.secret(channel) then guarded(N.Sources.bnet,prefix,text,id) end
    elseif event=="BN_FRIEND_LIST_SIZE_CHANGED" then
        N.BNet.invalidatePeers();guarded(M.overlordTick,now());N.BNet.pump(now());guarded(M.friendChanged)
    elseif event=="BN_FRIEND_INFO_CHANGED" or event=="BN_FRIEND_ACCOUNT_ONLINE" or event=="BN_FRIEND_ACCOUNT_OFFLINE"
        or event=="CLUB_MEMBER_PRESENCE_UPDATED" then guarded(M.friendChanged)
    elseif event=="WHO_LIST_UPDATE" then guarded(M.hopAnyWho)
    elseif event=="PLAYER_REGEN_DISABLED" then
        if N.WarBoardTrack then N.WarBoardTrack.stop() end
    elseif event=="PLAYER_REGEN_ENABLED" then
        if M.auto and M.auto.group and M.auto.group.blind then guarded(M.autoTick) end
    elseif event=="PLAYER_DEAD" then N.OwnDeath.dead()
    elseif event=="PLAYER_ALIVE" or event=="PLAYER_UNGHOST" then N.OwnDeath.revived()
    elseif event=="CHAT_MSG_SYSTEM" then guarded(M.whisperSystem,...)
    elseif event=="PLAYER_ENTERING_WORLD" or event=="SHARD_TRANSFER" then
        local g=M.auto and M.auto.group
        if event=="SHARD_TRANSFER" and g and g.blind and g.joinedAt then g.transfer=true end
        if event=="PLAYER_ENTERING_WORLD" then N.OwnDeath.seed(...) end
        if N.WarBoardTrack and A.inInstance()~=false then N.WarBoardTrack.stop() end
        guarded(M.hopAnySafe); guarded(M.boundary,A.location()); M.queuePoll()
    elseif event=="ZONE_CHANGED_NEW_AREA" or event=="ZONE_CHANGED" then
        guarded(M.zoneCheck,(A.location()))
        M.queuePoll()
    elseif event=="PLAYER_TARGET_CHANGED" then M.queueUnit("target")
    elseif event=="UNIT_TARGET" then M.queueGroupTarget(...)
    elseif event=="UPDATE_MOUSEOVER_UNIT" then M.queueUnit("mouseover")
    elseif event=="NAME_PLATE_UNIT_ADDED" then M.queueUnit(...)
    elseif event=="NAME_PLATE_UNIT_REMOVED" then M.releaseUnit(...)
    elseif event=="GROUP_ROSTER_UPDATE" then guarded(M.groupCheck); guarded(M.inviteTick)
    elseif event=="GUILD_ROSTER_UPDATE" then guarded(M.rosterUpdate)
    elseif event=="PARTY_INVITE_REQUEST" then guarded(M.partyInvite,(...))
    elseif event=="CHAT_MSG_WHISPER_INFORM" then local text,who=...; guarded(M.draftSent,"WHISPER",text,who)
    elseif event=="CHAT_MSG_GUILD" then
        local text,who=...; guarded(M.draftSent,"GUILD",text,who)
        if N.Trust.state(M.store,now())=="blind" then guarded(M.hostRequest,text,who) end
    elseif event=="PLAYER_GUILD_UPDATE" then guarded(M.guildChanged)
    elseif event=="CHAT_MSG_CHANNEL_NOTICE" then local what,_,_,shown,_,_,_,_,base=...; guarded(N.Directory.notice,what,shown,base) end
end
-- Opens the chat box with a whisper for the user to send; never sends it.
function N.AskInvite(name)
    if not M.started then return false end
    local ok,asked=pcall(M.askInvite,name)
    return ok and asked==true
end
-- Keep the owned export's literal key in its own compiler constant table.
-- The bytecode ownership gate deliberately refuses register-indexed global writes.
local function publishNamespace() if _G.LE==nil then _G.LE=N end end
publishNamespace()
frame:SetScript("OnEvent",function(...) guarded(dispatch,...) end)
