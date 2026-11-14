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
    if zone~=nil and M.zoneSeen~=nil and zone~=M.zoneSeen then
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
    if M.auto and M.auto.group then guarded(M.autoTick) end
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
    M.groupCheck(); M.inviteTick(); M.relayTick(); M.autoTick()
    N.Directory.sync()
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
-- Our own character, with or without a realm (compared the way the receive policy compares senders).
-- Ourselves, by the one name rule (Invite.name keys: our realm dropped, any other realm is someone else).
function M.isMe(name)
    local _,key=I.name(name)
    local _,me=I.name((S.call(UnitName,"player")))
    return key~=nil and me~=nil and key==me
end
function M.message(prefix,text,kind,sender,target,zoneChannelID,localID,channelName)
    -- Check every delivered value before comparing/indexing it.
    local args={prefix,text,kind,sender,target,zoneChannelID,localID,channelName}
    for i=1,8 do if S.secret(args[i]) then return end end
    if prefix=="HeadHunter" then return M.headhunter(text,kind,sender) end
    if prefix=="LayerSwap" then return M.layerswap(text,kind,sender) end
    if prefix=="LFSw" then return M.lfsw(text,kind,sender) end
    if prefix=="LEGW1" then return M.relayIn(text,kind,sender) end
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
    if inner.type=="H" then N.Peers.hello(M.peers,origin,inner.minor,time); return end
    local record
    record,why=N.Reports.receive(M.receiver,msg,{sender=sender,route=kind,now=time,
        serverNow=S.num(S.call(GetServerTime)),zoneFn=A.zone,peers=M.peers})
    M.lastDrop=why
    if record then
        local stored,whyNot=T.report(M.store,record,time)
        if not stored then M.lastDrop=whyNot end
        if why=="new" then M.offerRelay(record) end
        N.Find.report(M.find,{sender=record.origin,zone=record.zone,at=record.heard,enemies=record.enemies},M.homeRealm())
        M.findAlerts()
        if N.UI then N.UI.refresh() end
    end
end
-- HeadHunter P (fight) and L (wanted) records: PARTY/RAID/WHISPER, own faction only, 6 frames per sender per 10 s.
function M.headhunter(text,kind,sender)
    if type(text)~="string" or #text>255 or not S.str(sender,100) then return end
    local allowed,reason=A.hhPolicy(kind,sender)
    if not allowed then M.lastDrop=reason; return end
    local time=now()
    -- only frames we read (P, L, E) count against the sender's 6 per 10 s; the rest are ignored uncounted
    local frameType=text:match("^%d[AH](%u):")
    if frameType~="P" and frameType~="L" and frameType~="E" then return end
    if not N.HeadHunter.allow(M.hh,sender,time) then return end
    local records,why=N.HeadHunter.decode(text,sender,S.num(S.call(GetServerTime)),S.str((S.call(UnitFactionGroup,"player")),20),
        {heard=time,route=kind,zoneFn=A.zone})
    M.lastDrop=why~="ignored" and why or M.lastDrop
    local me=S.str((S.call(UnitName,"player")))
    for _,record in ipairs(records) do
        local ignored,whyIgnored=false,nil
        if record.origin~=sender then
            if M.isMe(record.origin) then ignored,whyIgnored=true,"own echo"
            else ignored,whyIgnored=A.ignored(record.origin) end
        end
        if ignored then M.lastDrop=whyIgnored
        else
            local stored,whyNot=T.report(M.store,record,time)
            M.lastDrop=stored and "headhunter "..record.kind or whyNot
            if whyNot~="duplicate" then
                N.Find.report(M.find,{sender=record.origin,zone=record.zone,at=record.heard,enemies=record.enemies},M.homeRealm())
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
    local time=now()
    local ok=N.Relay.offer(M.relay,record,time,M.relayContext())
    if ok then
        local p=M.relay.pending[N.Relay.key(record)]
        if not after(math.max(0,p.due-time)+0.05,function() guarded(M.relayTick) end) then M.relayTick() end
    end
end
function M.relayContext()
    return {inGuild=S.call(IsInGuild)==true,inInstance=A.inInstance(),guild=S.str((S.call(GetGuildInfo,"player")),100)}
end
function M.relayTick()
    for _,r in ipairs(N.Relay.tick(M.relay,now(),M.relayContext())) do M.lastRelay=r.ok and "relayed" or r.why end
end
-- Guild relay in: GUILD only, never from us, stored as src "guild" with the claimed source as its label; never
-- relayed again.
function M.relayIn(text,kind,sender)
    if kind~="GUILD" or not S.str(sender,100) or S.call(IsInGuild)~=true then return end
    if M.isMe(sender) then return end
    if A.ignored(sender) then M.lastDrop="ignored sender"; return end
    local time=now()
    if not N.Relay.allow(M.relay,sender,time) then return end
    local control=N.Relay.control(text)
    if control then return M.hostControl(control,sender,time) end
    local record,why=N.Relay.decode(text,sender,time)
    if not record then M.lastDrop="relay "..tostring(why); return end
    N.Relay.heard(M.relay,record,time)
    if M.isMe(record.origin) or A.ignored(record.origin) then M.lastDrop="relay origin"; return end
    local stored,whyNot=T.report(M.store,record,time)
    M.lastDrop=stored and "relayed "..tostring(record.label) or whyNot
    -- a copy of a report already held (first-hand or relayed) adds nothing to Find
    if not stored and whyNot=="duplicate" then return end
    -- a relayed origin was in someone else's group: Find shows the report but never offers to ask them
    N.Find.report(M.find,{sender=record.origin,zone=record.zone,at=record.heard,enemies=record.enemies,relayed=true},M.homeRealm())
    M.findAlerts()
    if N.UI then N.UI.refresh() end
end
-- LayerSwap prefix: only a reply from the player we asked, on WHISPER, within 120 s. An incoming "inv layer"
-- request and everything else are ignored (answering is not ours to do).
function M.layerswap(text,kind,sender)
    if kind=="GUILD" then return M.layerswapGuild(text,sender) end
    -- a request whispered to us goes to the guild host, and only while hosting is on; it never reaches Hop
    if kind=="WHISPER" and type(text)=="string" and text:sub(1,10)=="inv layer " then
        if M.host and M.host.on then M.hostRequest(text,sender) end
        return
    end
    if kind~="WHISPER" or type(text)~="string" or not S.str(sender,100) or not M.hop.pending then return end
    local me=S.str((S.call(UnitName,"player")))
    local time=now()
    local asked=M.hop.pending
    local shown,reply=N.Hop.receive(M.hop,text,sender,me,time,M.store.ambiguous(time))
    if shown then M.say("LayerEnemies: "..shown) end
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
function M.hostWhyNot()
    return M.hostBlocked() or (S.call(IsInGuild)~=true and "you are not in a guild.")
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
function M.asking()
    local time=now()
    local function open(p) return S.tab(p) and S.num(p.at) and time>=p.at and time-p.at<=N.Hop.REPLY end
    if M.hop.pending and not open(M.hop.pending) then N.Hop.clear(M.hop) end
    if M.invite.pending and not open(M.invite.pending) and not (M.auto and M.auto.group) then M.invite.pending=nil end
    return M.hop.pending~=nil or M.invite.pending~=nil
end
-- Our own state for GuildHost.decide; member is read only after the early checks pass.
function M.hostOwn()
    local zone=A.location()
    local id=S.str(M.store.bulo,32)
    local party=A.party()
    local me=S.str((S.call(UnitName,"player")))
    local _,self
    if me then _,self=I.name(me) end
    return {self=self,zone=zone and zone==M.store.zone and zone or nil,key=L.key(M.store.bulo),id=id,
        inInstance=A.inInstance(),inCombat=A.inCombat(),raid=party and party.raid,leader=party and party.leader,
        members=party and party.members or {},asking=M.asking()}
end
-- LEGW1 control lines. An H from a guildmate is remembered like a LayerSwap "heard ...|h" (12 minutes, layer
-- <key>-0); an F, while we host, gets one H 1 to 6 s later (Wire allows one H per 60 s).
function M.hostControl(c,sender,time)
    if c.kind=="H" then
        N.Hosts.heard(M.heard,sender,{kind="heard",layer=c.key.."-0",zone=c.zone,hosting=true},A.wall())
        if N.UI then N.UI.refresh() end
        return
    end
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
    if not (M.host and M.host.on) or M.hostWhyNot() or not A.rosterAge(now()) then return false end
    local own=M.hostOwn()
    local line=N.Relay.hostLine(own.key,own.zone)
    if not line then return false end
    local ok=N.Wire.send("LEGW1",line,"GUILD",nil,{prio="owed"})
    if ok then M.host.announcedAt=now() end
    return ok
end
function M.hostRequest(text,sender,held)
    if M.hostBlocked() then return end
    if S.secret(sender) or not S.str(sender,100) or M.isMe(sender) or A.ignored(sender) then return end
    local G=N.GuildHost
    local req=G.parse(text)
    if not req then return end
    req.name=sender
    local time=now()
    local own=M.hostOwn()
    if not G.early(M.host,req,own,time) then return end
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
    A.rosterSeen(time)
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
    local me=S.str((S.call(UnitName,"player")))
    local reply=N.Hop.reply(text,sender,me)
    if reply and reply.kind=="heard" then N.Hosts.heard(M.heard,sender,reply,A.wall()) end
    -- who answered our ask: a hosting heard naming us, or a LayerSwap/Bulo claim naming us (Bulo Host.lua:521);
    -- only these and listed hosts may have their invite accepted for the guild ask
    local claimed=#text<=120 and text:match("^claim (.+)$")
    local _,key=I.name(sender)
    if key and ((reply and reply.kind=="heard" and reply.hosting) or (claimed and me and claimed==me)) then
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
end
-- A listed Bulo/LayerSwap/LayerEnemies host (guild lines, LayerSwap book, remembered replies and H lines).
local function listedHost(short)
    for _,c in ipairs((M.candidates())) do
        if c.short==short then for _,s in ipairs(c.sources or {}) do if s=="Bulo" or s=="LayerSwap" then return true end end end
    end
    return false
end
-- Hosts remembered from replies, pruned before they are read.
function M.heardBook()
    local wall=A.wall()
    if wall then N.Hosts.prune(M.heard,wall) end
    return M.heard.heard
end
-- LFSw prefix: Bulo guild layer lines, GUILD only, read and never answered.
function M.lfsw(text,kind,sender)
    if kind~="GUILD" or not S.str(sender,100) or S.call(IsInGuild)~=true then return end
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
function M.zoneName(zone)
    local info=S.tab(C_Map) and S.call(C_Map.GetMapInfo,zone)
    return S.tab(info) and S.str(info.name) or ("zone "..tostring(zone or "unknown"))
end
function M.findRows()
    local lists=A.friendLists(M.guildLines,M.heardBook())
    return N.Find.rows(M.find,now(),M.store.zone,function(name,zone)
        return zone==M.store.zone and I.sameSpotter(name,{zone=zone,wall=A.wall(),ownKey=L.key(M.store.bulo),
            ambiguous=M.store.ambiguous(now()),bulo=lists.bulo,book=lists.book})
    end)
end
function M.findText(row)
    if not row.at then return row.name.." — "..row.status end
    local detail=" in "..M.zoneName(row.zone)..", "..math.floor(now()-row.at).." s ago ("..(row.class or "Unknown class").." "..tostring(row.level or "?")..")"
    return row.name.." — "..row.status..detail..(row.same and " — already on your layer" or row.probably and " — probably on your layer (your server key is ambiguous)"
        or row.travel and (" — travel to "..M.zoneName(row.zone).." first") or "")
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
            -- a stored guild relay stays a relay when replayed into Find (never askable)
            N.Find.report(M.find,{sender=r.origin,zone=r.zone,at=r.heard,enemies=r.enemies,relayed=r.src=="guild"},M.homeRealm())
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
    local lists=A.friendLists(M.guildLines,M.heardBook())
    local _,short=I.name((S.call(UnitName,"player")))
    return I.collect({now=time,wall=A.wall(),zone=M.store.zone,ownKey=L.key(M.store.bulo),ambiguous=M.store.ambiguous(time),self=short,
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
-- One record, one possible hop: who would be asked, how, and why not.
function M.hopContext()
    local time=now()
    local zone,x,y=A.location()
    local own=T.own(M.store,time)
    if zone~=own.zone then x,y=nil,nil end
    return {now=time,grouped=A.grouped(),own=own,zone=zone,invite=M.invite,x=x,y=y,zoneName=M.zoneName}
end
function M.hopPreview(record)
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
    local ctx=M.hopContext()
    local record=N.Hop.hostRecord(c,ctx.own.zone)
    if not record then return nil end
    local cand=N.Hop.hostCandidate(c)
    if not L.key(M.store.bulo) or c.unknownOwn then
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
    if not L.key(M.store.bulo) or c.unknownOwn then M.say("LayerEnemies: "..I.HINT); return false end
    local live
    for _,row in ipairs((M.candidates())) do if row.short==c.short then live=row; break end end
    if not live then
        local why=c.layer and L.same(c.layer,M.store.bulo) and not M.store.ambiguous(now()) and "that host is on your layer already." or "hosts changed, check again."
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
    if not L.key(M.store.bulo) or row.unknownOwn then M.say("LayerEnemies: "..I.HINT); return false end
    if not N.Hop.hostRecord(row,M.store.zone) then
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
    M.say("LayerEnemies - friendly players on other layers, your zone only. Your layer: "..(L.key(M.store.bulo) or "Unknown"))
    if not L.key(M.store.bulo) then M.say(I.HINT) end
    if #list==0 then M.say("No one to ask right now.") end
    for i,c in ipairs(list) do
        names[i]=c.name
        M.say(i..". "..c.name.." | "..(c.layer and ("layer "..c.layer) or "layer unknown - saw reported enemies")..(c.probably and " (probably your layer: your key is ambiguous)" or "").." | "..table.concat(c.sources," + ")..(c.host and " | host" or "").." | "..ago(c.age).." ago")
    end
    M.hostList={at=now(),names=names,rows=list}
    M.say("Bulo: "..status.bulo.." / LayerSwap: "..status.book.." / War Effort reporters: "..status.reports)
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
function M.autoHop() return M.auto~=nil and M.auto.on==true end
function M.setAutoHop(on)
    M.auto.on=on==true; if S.tab(LayerEnemiesDB) then LayerEnemiesDB.autoHop=M.auto.on end
    if not M.auto.on then M.auto.group=nil end
    M.say(M.auto.on and "LayerEnemies: Auto accept and leave is on: the invite of the host you asked by Hop is accepted, and that group is left once you moved (or after 30 s without a move)."
        or "LayerEnemies: Auto accept and leave is off: invites and groups are left to you.")
    if N.UI then N.UI.refresh() end
end
-- PARTY_INVITE_REQUEST: accept only the host our own hop asked (whole name, as Hop.receive; for the guild ask an
-- online guild member), within 120 s of the ask, while not grouped, not in an instance and not in combat. Anything
-- else is left to the player.
function M.partyInvite(name)
    if not M.autoHop() or M.auto.group then return end
    local p=M.invite.pending
    local time=now()
    if not S.tab(p) or not p.auto or not S.num(p.at) or time-p.at>M.AUTO_WINDOW or time<p.at then return end
    if S.secret(name) then return end
    local inviter,short=I.name(name)
    if not inviter then return end
    if p.guild then
        -- an online guildmate who answered our ask or is a listed host (not any guildmate: a dungeon invite would
        -- otherwise be accepted and then left)
        if A.guildMember(inviter)~=true then return end
        local g=M.hop.guildAsk
        if not ((g and g.answered and g.answered[short]) or listedHost(short)) then return end
    elseif short~=p.short then return end
    if A.grouped() or A.inInstance()~=false or A.inCombat() then return end
    local ok=N.Wire.accept(time)
    if not ok then return end
    M.invite.pending=nil   -- one accept per ask: a later invite from the same host is left to the player
    N.Wire.hideInvite()
    after(0,function() N.Wire.hideInvite() end)
    local shown=(inviter:match("^([^%-]+)%-")) or inviter
    M.auto.group={host=shown,short=short,target=p.target,at=time}
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
function M.autoTick()
    local g=M.auto and M.auto.group
    if not g then return end
    if not M.autoHop() then M.auto.group=nil; return end
    local time=now()
    local grouped=S.call(IsInGroup)==true
    if not g.joinedAt then
        if not grouped then
            if time-g.at>M.AUTO_JOIN then M.auto.group=nil end
            return
        end
        g.joinedAt=time; g.joinKey=L.key(M.store.bulo)
        after(M.AUTO_FAIL+0.1,function() guarded(M.autoTick) end)
    end
    local party=A.party()
    if not grouped or not party or party.raid~=false or party.leader or not hostLeads(g) then M.auto.group=nil; return end
    -- never inside an instance: stop tracking; in combat the leave waits until combat ends
    if A.inInstance()~=false then M.auto.group=nil; return end
    local fighting=A.inCombat()
    if g.leaveAt then
        if time>=g.leaveAt then
            if fighting then after(1,function() guarded(M.autoTick) end); return end
            N.Wire.leave(time); M.auto.group=nil; M.hopDone()
        end
        return
    end
    local key=L.key(M.store.bulo)
    if key and key==L.key(g.target) and key~=g.joinKey then
        g.leaveAt=time+M.AUTO_LEAVE
        M.say("LayerEnemies: moved to layer "..key..", leaving the group")
        after(M.AUTO_LEAVE+0.05,function() guarded(M.autoTick) end)
        return
    end
    if time-g.joinedAt>=M.AUTO_FAIL then
        if fighting then after(1,function() guarded(M.autoTick) end); return end
        N.Wire.leave(time); M.auto.group=nil; M.hopDone()
        M.say("LayerEnemies: hop failed: "..g.host.." could not move you")
    end
end
-- PLAYER_GUILD_UPDATE: out of the guild, or in another one, hosting goes inactive (still saved on), the owed H and
-- a scheduled F answer are dropped, and the roster-seen flag is reset, so an H in a new guild waits for its roster.
-- An update that changes nothing (same guild) keeps everything.
function M.guildChanged()
    local inGuild=S.call(IsInGuild)==true
    local name=inGuild and S.str((S.call(GetGuildInfo,"player")),100) or nil
    -- still in a guild and not known to be another one (its name unread yet, or the same): nothing changed
    if inGuild and (not name or not M.guildSeen or name==M.guildSeen) then M.guildSeen=name or M.guildSeen; return end
    M.guildSeen=name
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
-- The hop is over (moved and left, failed, or 120 s without an invite): no ask is pending any more.
function M.hopDone() N.Hop.clear(M.hop); M.invite.pending=nil end
function M.groupCheck()
    local grouped=A.grouped()
    -- the hop group ended (left by hand or otherwise): stop tracking at once
    if not grouped and M.wasGrouped and M.auto and M.auto.group and M.auto.group.joinedAt then M.auto.group=nil end
    if grouped and not M.wasGrouped and M.auto and M.auto.group then
        -- our auto-accepted hop group: autoTick watches the move and leaves; the manual layer check stays quiet
        guarded(M.autoTick)
    elseif grouped and not M.wasGrouped and I.joined(M.invite,now(),L.key(M.store.bulo),M.store.zone) then
        M.say("LayerEnemies: you joined a group after asking - checking your layer for 60 s.")
        after(I.WATCH+0.5,function() guarded(M.inviteTick) end)
    end
    M.wasGrouped=grouped
end
function M.inviteTick()
    if not M.invite.watch then return end
    local message,note=I.tick(M.invite,now(),L.key(M.store.bulo),M.store.zone,M.store.ambiguous(now()))
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
    if not L.key(M.store.bulo) then say(I.HINT) end
    local kind=command=="reports" and "reported" or command=="unclassified" and "unclassified" or "local"
    say(kind=="reported" and "Reported, not confirmed (War Effort; age as the reporter's clock gives it):" or kind=="unclassified" and "Unclassified / same-faction local observations (not confirmed enemies):" or "Opposite-faction players seen by you:")
    local rows=T.rows(M.store,now(),kind)
    if #rows==0 then say(kind=="reported" and "No live reports for your zone." or "No eligible observations.") end
    local numbers,records,shown={},{},{}
    for _,e in ipairs(rows) do
        local when=ago(now()-e.at)
        local extra=""
        if kind=="reported" and e.record and not numbers[e.record] then
            records[#records+1]=e.record; numbers[e.record]=#records
            local p=M.hopPreview(e.record); shown[#records]=p
            say("["..#records.."] "..(p.enabled and ("/le hop "..#records..": "..p.detail) or ("no hop: "..p.reason)))
        end
        if e.reporter then
            extra=" | reported by "..e.reporter..(e.via and " via "..e.via or "")..(e.hand~="first" and " | relayed" or "")..(e.positionKind and (" | "..e.positionKind) or "")..(e.untimed and " | time of receipt (no timestamp)" or "")..(e.age and e.age>0 and (" | claimed "..e.age.." s old") or "").." | "..(e.relation=="same" and "same server key as yours" or e.relation=="other" and ("other server key "..tostring(e.reportLayer)) or "layer unknown")
        end
        say((e.name or "Unknown").." | "..(e.class or "Unknown class").." | "..tostring(e.level or "?").." | zone "..tostring(e.zone).." | "..(e.reporter and "received " or "seen ")..when.." ago | "..e.source.." | "..e.confidence..extra..(e.possible and (" | "..e.possible) or ""))
    end
    if kind=="reported" then M.hopList={at=now(),records=records,shown=shown} end
    if kind=="reported" and #rows>0 then say("To go there, ask a reporter for an invite: /le hosts") end
    if kind=="local" then
        local reported=#T.rows(M.store,now(),"reported")
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
    M.hop=N.Hop.new(); M.heard=N.Hosts.new(); M.guildLines={}; M.lfswRate=N.HeadHunter.new(); M.relay=N.Relay.new()
    M.store.ambiguous=function(time) return L.ambiguous(M.npcs,time) end
    M.invite=I.new(); M.wasGrouped=A.grouped()
    M.host=N.GuildHost.new()   -- guild-only hosting; the wish (want) is saved as LayerEnemiesDB.guildHost
    M.layerSource="unknown"; M.store.zone=A.location(); M.zoneSeen=M.store.zone
    if not S.tab(LayerEnemiesDB) then LayerEnemiesDB={} end
    -- Configuration only. Sightings and source identities never enter SavedVariables.
    local saved=LayerEnemiesDB
    M.find=N.Find.new(saved.tracked)
    -- guildHost: a boolean setting only (hosting for your guild, owner decision 0.4.0); anything else is off
    LayerEnemiesDB={options={},tracked=M.find.names,position=N.UI.position(saved.position),guildHost=saved.guildHost==true}
    M.host.want=LayerEnemiesDB.guildHost
    -- 1.0 networks: consent ("guild", "public" or not asked yet) and one switch per network
    LayerEnemiesDB.consent,LayerEnemiesDB.nets=N.Net.load(saved)
    -- autoHop: on by default; only a saved false turns it off
    LayerEnemiesDB.autoHop=saved.autoHop~=false
    M.auto={on=LayerEnemiesDB.autoHop,group=nil}
    if S.tab(C_ChatInfo) then
        S.call(C_ChatInfo.RegisterAddonMessagePrefix,"WEFF1")
        S.call(C_ChatInfo.RegisterAddonMessagePrefix,"HeadHunter")
        -- replies to our hop request, and Bulo guild layer lines; we answer neither
        S.call(C_ChatInfo.RegisterAddonMessagePrefix,"LayerSwap")
        S.call(C_ChatInfo.RegisterAddonMessagePrefix,"LFSw")
        S.call(C_ChatInfo.RegisterAddonMessagePrefix,"LEGW1")
    end
    SlashCmdList=SlashCmdList or {}
    _G.SLASH_LAYERENEMIES1="/le"
    SlashCmdList.LAYERENEMIES=function(command)
        local raw=(S.str(command,110) or ""):match("^%s*(.-)%s*$")
        command=raw:lower()
        if command=="find" then M.track(nil); return end
        if command:match("^find%s+") then M.track(raw:match("^%S+%s+(.+)$")); return end
        if command=="hop auto on" then guarded(M.setAutoHop,true); return end
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
    if M.host.want then M.hostResume(true) end
    heartbeat()
end
local frame=CreateFrame("Frame")
M.frame=frame
frame:Hide()
for _,event in ipairs({"ADDON_LOADED","PLAYER_LOGIN","PLAYER_ENTERING_WORLD","ZONE_CHANGED_NEW_AREA","ZONE_CHANGED","SHARD_TRANSFER","PLAYER_TARGET_CHANGED","UPDATE_MOUSEOVER_UNIT","NAME_PLATE_UNIT_ADDED","NAME_PLATE_UNIT_REMOVED","CHAT_MSG_ADDON","GROUP_ROSTER_UPDATE","GUILD_ROSTER_UPDATE","PARTY_INVITE_REQUEST","CHAT_MSG_WHISPER_INFORM","CHAT_MSG_GUILD","PLAYER_GUILD_UPDATE"}) do
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
    elseif event=="GROUP_ROSTER_UPDATE" then guarded(M.groupCheck); guarded(M.inviteTick)
    elseif event=="GUILD_ROSTER_UPDATE" then guarded(M.rosterUpdate)
    elseif event=="PARTY_INVITE_REQUEST" then guarded(M.partyInvite,(...))
    elseif event=="CHAT_MSG_WHISPER_INFORM" then local text,who=...; guarded(M.draftSent,"WHISPER",text,who)
    elseif event=="CHAT_MSG_GUILD" then local text,who=...; guarded(M.draftSent,"GUILD",text,who)
    elseif event=="PLAYER_GUILD_UPDATE" then guarded(M.guildChanged) end
end
-- Opens the chat box with a whisper for the user to send; never sends it.
function N.AskInvite(name)
    if not M.started then return false end
    local ok,asked=pcall(M.askInvite,name)
    return ok and asked==true
end
if _G.LE==nil then _G.LE=N end
frame:SetScript("OnEvent",function(...) guarded(dispatch,...) end)
