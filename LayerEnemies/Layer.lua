local _, N = ...
local L, S = {}, N.Safe
N.Layer = L
L.EXPIRE = 300
function L.bulo(id)
    id = S.str(id,32)
    if id and id:match("^%d+%-%d+$") and L.key(id) then return L.key(id), id end
end
function L.npc(guid)
    guid = S.str(guid,120)
    if not guid then return nil end
    local kind,server,instance,zone,npc,spawn = guid:match("^(%a+)%-0%-(%d+)%-(%d+)%-(%d+)%-(%d+)%-(%x+)$")
    if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
    if not L.key(server) then return nil end
    zone,npc = tonumber(zone),tonumber(npc)
    if not zone or zone < 1 or zone > 99999999 or not npc or npc < 1 then return nil end
    return zone,npc,server .. "-" .. tostring(zone)
end
-- The one layer comparison for every source. On Forever the layer is the server
-- part of a creature GUID: the digits before "-" in a full id, or a bare key.
function L.key(id)
    id=S.clean(id)
    if type(id)=="number" then
        if id~=id or id<1 or id>=1e15 or id%1~=0 then return nil end
        id=string.format("%.0f",id)
    end
    if type(id)~="string" or #id>32 then return nil end
    local key=id:match("^(%d+)%-%d+$") or id:match("^%d+$")
    return key and tonumber(key)>0 and key or nil
end
function L.same(a,b)
    a,b=L.key(a),L.key(b)
    return a~=nil and a==b
end
function L.new() return { votes={}, current=nil, last=nil, raw=nil, ambigAt=nil } end
-- reset: new votes (a zoneUID transition inside the zone, or 300 s without readings). The confirmed raw id and an
-- ambiguity window stay: they belong to the zone epoch, which only forget() ends (zone change).
function L.reset(t) S.clear(t.votes); t.current=nil; t.last=nil end
function L.forget(t) L.reset(t); t.raw=nil; t.ambigAt=nil end
-- Expiry is not a crossing: keep ambiguity, but never expose an expired raw key.
function L.expire(t,now)
    if t.last and now-t.last>=L.EXPIRE then
        L.reset(t); t.raw=nil
        return true
    end
    return false
end
L.AMBIGUOUS=1800
-- Our own server key: the server part of the last confirmed raw id (two NPC readings agreeing exactly).
function L.server(t)
    if not S.tab(t) then return nil end
    local ok,raw=pcall(function() return t.raw end)
    return ok and L.key(raw) or nil
end
-- True for 1800 s after the confirmed raw id changed its zoneUID part while the server part stayed the same inside
-- one zone epoch: two layers of a zone can share a server, so an equal key is then not even "probably yours".
function L.ambiguous(t,now)
    if not S.tab(t) then return false end
    local ok,at=pcall(function() return t.ambigAt end)
    now=S.num(now)
    return ok and S.num(at)~=nil and now~=nil and now-at<L.AMBIGUOUS or false
end
-- Five recent readings, distinct NPC kinds, never unbounded GUID history.
function L.observe(t,guid,now)
    L.expire(t,now)
    local zone,npc,raw = L.npc(guid)
    if not zone then return nil end
    t.last=now
    for i=#t.votes,1,-1 do
        if t.votes[i].npc==npc or now-t.votes[i].at>15 then table.remove(t.votes,i) end
    end
    if #t.votes>=5 then table.remove(t.votes,1) end
    t.votes[#t.votes+1]={zone=zone,npc=npc,raw=raw,at=now}
    local agree=0
    for _,v in ipairs(t.votes) do if v.zone==zone then agree=agree+1 end end
    if agree>=2 then
        local old=t.current
        local exact=0
        for _,v in ipairs(t.votes) do if v.raw==raw then exact=exact+1 end end
        t.current=zone; t.last=now
        if exact>=2 then
            if t.raw and t.raw~=raw and L.key(t.raw)==L.key(raw) then t.ambigAt=now end
            if t.raw and L.key(t.raw)~=L.key(raw) then t.ambigAt=nil end   -- another server: a new layer, not ambiguous
            t.raw=raw
        end
        return zone,old,exact>=2 and raw or nil
    end
end
function L.zone(mapID, infoFn)
    mapID=S.num(mapID)
    if not mapID or mapID<1 or mapID%1~=0 then return nil end
    local visited={}
    for _=1,12 do
        if visited[mapID] then return nil end
        visited[mapID]=true
        local info=S.call(infoFn,mapID)
        if not S.tab(info) then return nil end
        local kind,parent=S.num(info.mapType),S.num(info.parentMapID)
        if kind==3 then return mapID end
        if not kind or kind<3 or not parent or parent<1 then return nil end
        mapID=parent
    end
end
