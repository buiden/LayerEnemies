local _, N = ...
local T,S = {},N.Safe
N.Store=T
function T.new(now)
    return { epoch=now, serial=1, zone=nil, bulo=nil, zoneUID=nil, localSeen={}, reports={}, identities={} }
end
function T.reset(t,now,zone,bulo,zoneUID)
    t.epoch=now; t.serial=t.serial+1; t.zone=zone; t.bulo=bulo; t.zoneUID=zoneUID
    S.clear(t.localSeen); S.clear(t.reports); S.clear(t.identities)
end
function T.prune(t,now)
    for k,v in pairs(t.localSeen) do if now-v.at>=600 or v.at<t.epoch then t.localSeen[k]=nil end end
    -- the age counts from the origin's time; the epoch check from receipt
    for k,v in pairs(t.reports) do local r=v.record; if now-(r.at or r.heard)>=T.ttl(r) or r.heard<t.epoch then t.reports[k]=nil end end
    -- Identity candidates expire with observations; never persist names from old epochs.
    for hash,set in pairs(t.identities) do
        for name,at in pairs(set) do if now-at>=600 or at<t.epoch then set[name]=nil end end
        if next(set)==nil then t.identities[hash]=nil end
    end
end
local function room(t,key,max)
    if t[key] then return true end
    return S.count(t)<max
end
function T.observe(t,e,now)
    if not e.key or not S.num(e.at) or e.at<=t.epoch or e.at>now or now-e.at>=600 or not t.zone then return false end
    if not room(t.localSeen,e.key,256) then return false end
    local old=t.localSeen[e.key]
    if old and old.at>e.at then return false end
    if old and old.at==e.at then
        -- A direct unit event can enrich a Bulo copy from this very frame.
        local own=e.source and e.source:match("^own ")
        if not own or (old.source and old.source:match("^own ")) then return false end
    end
    e.zone=t.zone; e.epoch=t.serial; e.layer=t.bulo; e.namespace="bulo-server"; e.confidence="seen by you"
    t.localSeen[e.key]=e
    if e.name and e.realm then
        local hash=N.Hash.player(e.name,e.realm)
        if hash then
            local set=t.identities[hash]
            if not set and S.count(t.identities)<256 then set={}; t.identities[hash]=set end
            local label=e.name.."-"..e.realm
            if set and room(set,label,8) then set[label]=e.at end
        end
    end
    return true
end
function T.possible(t,hash)
    local set=t.identities[hash]; if not set then return nil end
    local names={}; for name in pairs(set) do names[#names+1]=name end
    table.sort(names)
    return #names>0 and ("possible identity: "..table.concat(names,", ")) or nil
end
-- Our side of a layer comparison: zone, own server key, and whether that key is ambiguous right now.
function T.own(t,now)
    local amb=type(t.ambiguous)=="function" and t.ambiguous(now) or false
    return {zone=t.zone,server=N.Layer.key(t.bulo),ambiguous=amb}
end
-- record: from N.Record.new. Any record of our zone is kept, whatever its layer relation: the wire has no absolute
-- time, so every report is "reported, not confirmed", and other-layer reports are the ones a hop needs.
-- Storing the same record again (an enriched report) refreshes its row.
-- Per network, counted from the origin's time: HeadHunter 300 s; War Effort and the Spy family 600 s; the guild
-- incident addons (Guild Bounty, Wall of Shame, Forever Told) 900 s.
local TTL={hh=300,gb=900,wos=900,ft=900}
function T.ttl(record) return TTL[record.src] or (record.label=="hh" and 300) or 600 end
-- the network a record came through: a guild relay counts as the network it relays
local function network(r) return r.src=="guild" and (r.label or "guild") or r.src end
local function named(r) local n=0; for _,e in ipairs(r.enemies or {}) do if e.name then n=n+1 end end; return n end
-- Each source has its own 64 rows, so one cannot crowd out the other.
function T.report(t,record,now)
    if not S.tab(record) or type(record.id)~="string" or not S.tab(record.layer) or not S.num(record.heard) then return false,"unreadable" end
    if not t.zone or record.zone~=t.zone then return false,"another zone" end
    -- heard at the boundary instant: it may have been sent before it, like a unit carried across
    if record.heard<=t.epoch then return false,"before observation epoch" end
    if now-(record.at or record.heard)>=T.ttl(record) then return false,"expired" end
    local key=record.id
    local old=t.reports[key]
    -- the same record again (an enriched report) refreshes its row; another copy of it (a second carrier) does not
    if old and old.record~=record then return false,"duplicate" end
    -- a guild-relayed copy and its first-hand original are one report: the first-hand one wins
    -- keyed like record.id: the folded origin (our realm stripped)
    local rest=":"..(record.okey or record.origin:lower())..":"..record.rid
    if record.src=="guild" then
        if record.label and t.reports[record.label..rest] then return false,"duplicate" end
    elseif t.reports["guild"..rest] then
        t.reports["guild"..rest]=nil
    end
    -- one row per origin, zone and 5 s across networks (one sighting heard twice, e.g. a LayerEnemies O line and its
    -- War Effort C): a first-hand copy wins, then the copy with more names; otherwise the row already held stays.
    -- Two reports of one network are two sightings and both stay.
    for k,row in pairs(t.reports) do
        local rr=row.record
        if k~=key and network(rr)~=network(record) and (rr.okey or rr.origin:lower())==(record.okey or record.origin:lower()) and rr.zone==record.zone
            and math.abs((rr.at or rr.heard)-(record.at or record.heard))<=5 then
            local a,b=named(record),named(rr)
            -- first-hand wins first (a relayed copy can name anyone); then the copy with more names
            local fa,fb=record.hand=="first",rr.hand=="first"
            if (fa and not fb) or (fa==fb and a>b) then t.reports[k]=nil else return false,"duplicate" end
        end
    end
    if not old then
        local n=0; for _,row in pairs(t.reports) do if row.record.src==record.src then n=n+1 end end
        if n>=64 then return false,"report cap" end
    end
    t.reports[key]={record=record,epoch=t.serial,confidence="reported, not confirmed"}
    return true
end
local SOURCE={we="reported (War Effort)",fight="fight (HeadHunter)",outlaw="wanted (HeadHunter)"}
local function source(r)
    if r.src=="guild" then
        local what=r.label=="hh" and (r.kind=="outlaw" and "HeadHunter wanted" or "HeadHunter fight") or "War Effort"
        return "relayed by "..r.via.." ("..what..")"
    end
    return r.src=="hh" and SOURCE[r.kind] or SOURCE.we
end
local POSITION={enemy="reported cluster position",observer="observer's position",victim="victim's position"}
local function newest(a,b) if a.at==b.at then return a.key<b.key end; return a.at>b.at end
function T.rows(t,now,kind)
    T.prune(t,now)
    local out={}
    if kind=="reported" then
        local own=T.own(t,now)
        for key,row in pairs(t.reports) do
            local r=row.record
            local relation=N.Record.relation(r,own)
            if row.epoch==t.serial and r.zone==t.zone then
                local label=source(r)
                local function add(k,e,name,possible)
                    out[#out+1]={key=k,at=r.heard,zone=r.zone,hash=e.hash,class=e.class,level=e.level,
                        reporter=r.origin,via=r.via and r.via:lower()~=r.origin:lower() and r.via or nil,relation=relation,reportLayer=r.layer.value,age=r.age,record=r,
                        name=name,possible=possible,confidence=row.confidence,source=label,namespace=r.layer.ns,x=r.x,y=r.y,
                        hand=r.hand,positionKind=POSITION[r.pos],untimed=r.untimed}
                end
                -- a HeadHunter name is the name as reported (claimed), never matched against our own sightings
                for i,e in ipairs(r.enemies) do add(key..":"..i,e,e.name or "Unknown",e.hash and T.possible(t,e.hash) or nil) end
                -- the list may be partial or missing: the count is what the report said
                local rest=(r.count or 0)-#r.enemies
                if rest>0 then add(key..":rest",{},rest..(#r.enemies>0 and " more" or "").." not listed") end
            end
        end
    else
        for _,e in pairs(t.localSeen) do
            local factionOK=e.faction=="opposite"
            if e.epoch==t.serial and e.zone==t.zone and t.bulo and e.layer==t.bulo and ((kind=="unclassified" and not factionOK) or (kind~="unclassified" and factionOK)) then out[#out+1]=e end
        end
    end
    table.sort(out,newest); return out
end
-- Senders of live receipt-time reports in our zone, newest report per sender.
-- match = their zoneUID equals ours (War Effort would call that our layer).
function T.reporters(t,now)
    T.prune(t,now)
    local bySender,out={},{}
    local own=T.own(t,now)
    for _,row in pairs(t.reports) do
        local r=row.record
        -- War Effort reporters heard first-hand only: a relayed one was in someone else's group and may be a stranger
        if row.epoch==t.serial and r.zone==t.zone and r.src=="we" then
            local k=r.okey or r.origin:lower()
            local cur=bySender[k]
            local match=N.Record.relation(r,own)=="same"
            if not cur or cur.at<r.heard then bySender[k]={name=r.origin,at=r.heard,match=match} end
        end
    end
    for _,v in pairs(bySender) do out[#out+1]=v end
    table.sort(out,function(a,b) if a.at==b.at then return a.name<b.name end; return a.at>b.at end)
    return out
end
-- Data-only eligibility for a FUTURE approved map renderer. No frames or pins.
function T.mapCandidates(t,now,shownZone)
    local out={}
    if shownZone~=t.zone then return out end
    for _,e in ipairs(T.rows(t,now,"local")) do
        if e.x and e.y then out[#out+1]=e end
    end
    return out
end
