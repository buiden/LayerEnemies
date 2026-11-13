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
    for k,v in pairs(t.reports) do local at=v.record.heard; if now-at>=600 or at<t.epoch then t.reports[k]=nil end end
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
function T.report(t,record,now)
    if not S.tab(record) or type(record.id)~="string" or not S.tab(record.layer) or not S.num(record.heard) then return false,"unreadable" end
    if not t.zone or record.zone~=t.zone then return false,"another zone" end
    -- heard at the boundary instant: it may have been sent before it, like a unit carried across
    if record.heard<=t.epoch then return false,"before observation epoch" end
    if now-record.heard>=600 then return false,"expired" end
    local key=record.id
    if not t.reports[key] and not room(t.reports,key,64) then return false,"report cap" end
    t.reports[key]={record=record,epoch=t.serial,confidence="reported, not confirmed"}
    return true
end
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
                local function add(k,e,name,possible)
                    out[#out+1]={key=k,at=r.heard,zone=r.zone,hash=e.hash,class=e.class,level=e.level,
                        reporter=r.origin,relation=relation,reportLayer=r.layer.value,age=r.age,record=r,
                        name=name,possible=possible,confidence=row.confidence,source="reported (War Effort)",namespace=r.layer.ns,x=r.x,y=r.y,positionKind="reported cluster position"}
                end
                for i,e in ipairs(r.enemies) do add(key..":"..i,e,"Unknown",T.possible(t,e.hash)) end
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
        if row.epoch==t.serial and r.zone==t.zone then
            local cur=bySender[r.origin]
            local match=N.Record.relation(r,own)=="same"
            if not cur or cur.at<r.heard then bySender[r.origin]={name=r.origin,at=r.heard,match=match} end
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
