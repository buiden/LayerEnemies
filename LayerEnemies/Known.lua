-- Bounded session memory of named evidence. Pure: callers supply clean data and time.
-- No frames, client APIs, saved state, counts per enemy or public enumeration UI.
local _,N=...
local K={TTL=3600,MAX=300}
N.Known=K
local sources={own=true,guild=true,relayed=true,spy=true,death=true,headhunter=true}
local fields={"name","zone","x","y","pos","at","source","spotter","class","level","layer","ns","kind",
    -- Own-source identity and epoch preserve the existing Find matcher and layer-unknown rule.
    "ownName","realm","epoch","detail"}
local function fresh(e,now) return e and now>=e.at and now-e.at<K.TTL end
local function empty(t) for _ in pairs(t) do return false end; return true end
local function unindex(st,key,p)
    for alias in pairs(p.keys or {}) do
        local bucket=st.byName[alias]
        bucket[key]=nil
        if empty(bucket) then st.byName[alias]=nil end
    end
end
local function index(st,key,p)
    unindex(st,key,p)
    p.keys={}
    for _,slot in ipairs({"seen","reported"}) do
        local e=p[slot]
        if e then
            p.keys[N.Find.fold(e.name:match("^([^%-]+)") or e.name)]=true
            if e.source=="own" and e.ownName then p.keys[N.Find.fold(e.ownName)]=true end
        end
    end
    for alias in pairs(p.keys) do
        local bucket=st.byName[alias] or {}; st.byName[alias]=bucket; bucket[key]=p
    end
end
local function remove(st,key,p)
    unindex(st,key,p); st.entries[key]=nil
end
function K.new() return {entries={},byName={},nextExpiry=math.huge} end
function K.prune(st,now)
    -- Polls between expiry deadlines do no cache walk; clock rollback still
    -- invalidates future evidence. Put maintains both aliases and the deadline.
    local forward=not st.time or now>=st.time
    st.time=now
    if forward and now<st.nextExpiry then return end
    st.nextExpiry=math.huge
    for key,p in pairs(st.entries) do
        local seen,reported=p.seen,p.reported
        if not fresh(p.seen,now) then p.seen=nil end
        if not fresh(p.reported,now) then p.reported=nil end
        if not p.seen and not p.reported then remove(st,key,p)
        else
            if p.seen~=seen or p.reported~=reported then index(st,key,p) end
            if p.seen then st.nextExpiry=math.min(st.nextExpiry,p.seen.at+K.TTL) end
            if p.reported then st.nextExpiry=math.min(st.nextExpiry,p.reported.at+K.TTL) end
        end
    end
end
function K.get(st,name,now)
    K.prune(st,now)
    return st.entries[N.Find.fold(name)]
end
function K.put(st,e,now)
    K.prune(st,now)
    -- A.unit joins two Safe.str values (160 bytes each); preserve legacy first-name matches.
    local limit=e.source=="own" and 321 or 100
    if type(e.name)~="string" or #e.name<2 or #e.name>limit or e.name:find("[%c|]")
        or not sources[e.source] or (e.kind~="seen" and e.kind~="claim")
        or type(e.at)~="number" or not fresh(e,now) then return end
    local key=N.Find.fold(e.name)
    local p=st.entries[key]
    local firsthand=e.kind=="seen" and e.source~="relayed" and e.source~="death"
    local slot=firsthand and "seen" or "reported"
    -- Keep two entries: our own sighting, when present, and the newest other
    -- evidence. A guild observation retains kind=seen; it is not a relay claim.
    if firsthand and e.source~="own" and p and p.seen and p.seen.source=="own" then slot="reported" end
    if e.source=="own" and p and p.seen and p.seen.source~="own" then
        if not p.reported or p.seen.at>=p.reported.at then p.reported=p.seen end
        p.seen=nil
    end
    if p and p[slot] and p[slot].at>e.at then return p[slot] end
    if not p then
        local n,oldest,oldAt=0,nil,nil
        for k,v in pairs(st.entries) do
            n=n+1
            local at=math.max(v.seen and v.seen.at or -math.huge,v.reported and v.reported.at or -math.huge)
            if not oldAt or at<oldAt or (at==oldAt and k<oldest) then oldest,oldAt=k,at end
        end
        if n>=K.MAX then
            -- An out-of-order arrival older than the whole cache is itself the oldest.
            if e.at<oldAt then return end
            remove(st,oldest,st.entries[oldest])
        end
        p={}; st.entries[key]=p
    end
    local copy={}
    for _,field in ipairs(fields) do copy[field]=e[field] end
    copy.ns=copy.ns or "unknown"
    if copy.source~="own" and copy.source~="guild" then copy.layer=nil; copy.ns="unknown" end
    if not firsthand then copy.kind="claim" end
    p[slot]=copy
    index(st,key,p)
    st.nextExpiry=math.min(st.nextExpiry,copy.at+K.TTL)
    return copy
end
