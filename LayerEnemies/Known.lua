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
function K.new() return {entries={}} end
function K.prune(st,now)
    for key,p in pairs(st.entries) do
        if not fresh(p.seen,now) then p.seen=nil end
        if not fresh(p.reported,now) then p.reported=nil end
        if not p.seen and not p.reported then st.entries[key]=nil end
    end
end
function K.get(st,name,now)
    K.prune(st,now)
    return st.entries[N.Find.fold(name)]
end
function K.put(st,e,now)
    K.prune(st,now)
    if type(e.name)~="string" or #e.name<2 or #e.name>100 or e.name:find("[%c|]")
        or not sources[e.source] or (e.kind~="seen" and e.kind~="claim")
        or type(e.at)~="number" or not fresh(e,now) then return end
    local key=N.Find.fold(e.name)
    local p=st.entries[key]
    local slot=e.kind=="seen" and e.source~="relayed" and e.source~="death" and "seen" or "reported"
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
            st.entries[oldest]=nil
        end
        p={}; st.entries[key]=p
    end
    local copy={}
    for _,field in ipairs(fields) do copy[field]=e[field] end
    copy.ns=copy.ns or "unknown"
    if copy.source~="own" and copy.source~="guild" then copy.layer=nil; copy.ns="unknown" end
    if slot=="reported" then copy.kind="claim" end
    p[slot]=copy
    return copy
end
