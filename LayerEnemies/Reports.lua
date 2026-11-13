local _, N = ...
local R,S,P = {},N.Safe,N.Protocol
N.Reports=R
function R.new() return { senders={}, pending={}, tombstones={}, rates={}, globalAt=0, globalCount=0 } end
function R.clearPending(t)
    -- An epoch boundary must not allow a queued old fragment to start over.
    for key in pairs(t.pending) do t.tombstones[key]=t.pending[key].first end
    S.clear(t.pending)
end
function R.prune(t,now)
    for k,v in pairs(t.pending) do
        if now-v.first>15 then t.pending[k]=nil; t.tombstones[k]=now end
    end
    -- Tombstones are deliberately not evicted early to admit more senders.
    for k,v in pairs(t.tombstones) do if now-v>3660 then t.tombstones[k]=nil end end
    for k,v in pairs(t.senders) do if now-v>3660 then t.senders[k]=nil; t.rates[k]=nil end end
end
-- freshnessEvidence must be independently trusted absolute send time. A wire stamp
-- or hello cannot supply it. Production has no such evidence and fails closed.
function R.receive(t,text,sender,now,serverNow,zoneFn,currentZone,zoneUID,epoch,freshnessEvidence)
    if not S.str(sender,100) then return nil,"sender" end
    R.prune(t,now)
    if now-t.globalAt>=10 then t.globalAt=now; t.globalCount=0 end
    if t.globalCount>=128 then return nil,"global rate limit" end
    t.globalCount=t.globalCount+1
    if not t.senders[sender] and S.count(t.senders)>=64 then return nil,"sender cap" end
    t.senders[sender]=now
    local rate=t.rates[sender]
    if not rate or now-rate.at>=10 then rate={at=now,n=0}; t.rates[sender]=rate end
    if rate.n>=24 then return nil,"sender rate limit" end
    rate.n=rate.n+1
    local msg=P.decode(text)
    if not msg then return nil,"invalid message" end
    local age=P.clockAge(msg.stamp,serverNow)
    if not age then return nil,"stale or clock unavailable" end
    -- Ambiguous modulo-hour timestamps never unlock live data collection.
    local sent=S.num(freshnessEvidence)
    if not sent or not S.num(serverNow) or sent>serverNow or serverNow-sent>30 or math.floor(sent)%3600~=msg.stamp then
        return nil,"freshness unavailable: hour-relative timestamp"
    end
    local at=now-(serverNow-sent)
    if at<=epoch then return nil,"before observation epoch" end
    if msg.kind=="H" then return nil,"hello" end
    local key=sender..":"..msg.id
    if t.tombstones[key] then return nil,"replayed report" end
    local p=t.pending[key]
    if not p then
        if S.count(t.pending)>=32 or S.count(t.tombstones)+S.count(t.pending)>=512 then return nil,"report cap" end
        local count=0; for _,v in pairs(t.pending) do if v.sender==sender then count=count+1 end end
        if count>=4 then return nil,"sender report cap" end
        p={first=now,parts={},sender=sender,id=msg.id,at=at,stamp=msg.stamp}; t.pending[key]=p
    end
    local function reject(reason)
        t.pending[key]=nil; t.tombstones[key]=now; return nil,reason
    end
    -- Fragments can be stamped a few seconds apart by the send queue, never across
    -- an epoch/hour boundary inferred solely from their receipt.
    if math.abs(p.at-at)>15 then return reject("inconsistent fragment time") end
    if msg.kind=="C" then
        local zone=zoneFn(msg.map)
        if not currentZone or not zoneUID or msg.layer==0 or msg.layer~=zoneUID or zone~=currentZone then return reject("zone/layer mismatch") end
        if p.cluster then
            if p.cluster.raw~=text then return reject("conflicting cluster") end
            return nil,"duplicate fragment"
        end
        p.cluster={raw=text,map=msg.map,zone=zone,x=msg.x,y=msg.y,layer=msg.layer,count=msg.count}; p.at=at
    else
        if p.total and p.total~=msg.total then return reject("inconsistent part total") end
        p.total=msg.total
        if p.parts[msg.part] then
            if p.parts[msg.part].raw~=text then return reject("conflicting fragment") end
            return nil,"duplicate fragment"
        end
        p.parts[msg.part]={raw=text,enemies=msg.enemies}
    end
    if not p.cluster or not p.total then return nil,"pending" end
    local enemies,hashes={},{}
    for i=1,p.total do
        local part=p.parts[i]; if not part then return nil,"pending" end
        for _,e in ipairs(part.enemies) do
            -- Duplicate hashes are ambiguous identities; fail closed instead of merging.
            if hashes[e.hash] then return reject("duplicate enemy hash") end
            hashes[e.hash]=true; enemies[#enemies+1]=e
        end
    end
    if #enemies~=p.cluster.count then return reject("enemy count mismatch") end
    local c=p.cluster
    local result={sender=sender,id=p.id,at=p.at,zone=c.zone,map=c.map,layer=c.layer,x=c.x,y=c.y,enemies=enemies,freshness="verified"}
    t.pending[key]=nil; t.tombstones[key]=now
    return result,"complete"
end
