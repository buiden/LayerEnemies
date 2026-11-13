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
    for k,v in pairs(t.reports) do if now-v.at>=600 or v.at<t.epoch then t.reports[k]=nil end end
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
function T.report(t,report,now)
    -- Only the reducer can supply a freshness-verified complete report.
    if report.freshness~="verified" or not t.zoneUID or report.layer~=t.zoneUID or report.zone~=t.zone or report.at<t.epoch or now-report.at>=600 then return false end
    local key=report.sender..":"..report.id
    if not room(t.reports,key,64) then return false end
    report.epoch=t.serial; report.namespace="war-effort-zoneUID"
    report.confidence="reported zoneUID match (unverified)"
    t.reports[key]=report
    return true
end
local function newest(a,b) if a.at==b.at then return a.key<b.key end; return a.at>b.at end
function T.rows(t,now,kind)
    T.prune(t,now)
    local out={}
    if kind=="reported" then
        for key,r in pairs(t.reports) do
            if r.epoch==t.serial and r.zone==t.zone and r.layer==t.zoneUID then
                for i,e in ipairs(r.enemies) do
                    out[#out+1]={key=key..":"..i,at=r.at,zone=r.zone,hash=e.hash,class=e.class,level=e.level,
                        name="Unknown",possible=T.possible(t,e.hash),confidence=r.confidence,source="reported (War Effort)",namespace=r.namespace,x=r.x,y=r.y,positionKind="reported cluster position"}
                end
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
-- Data-only eligibility for a FUTURE approved map renderer. No frames or pins.
function T.mapCandidates(t,now,shownZone)
    local out={}
    if shownZone~=t.zone then return out end
    for _,e in ipairs(T.rows(t,now,"local")) do
        if e.x and e.y then out[#out+1]=e end
    end
    return out
end
