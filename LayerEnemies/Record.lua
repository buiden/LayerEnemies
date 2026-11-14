-- One record model for every source. A record's layer carries its namespace; layers are only ever compared inside
-- the "server" namespace (the zone-scoped server part of a creature GUID). A zoneUID is private per player and is
-- never compared with anything. Pure: no events, no frames, no sends.
local _, N = ...
local S = N.Safe
local R = {}
N.Record = R

-- 1.0 adds the Spy family (spy, fspy, sent) and the guild incident addons (gb, wos, ft); kinds seen (one enemy) and
-- death (a player died to this enemy).
local SRC = { own = true, we = true, hh = true, guild = true, spy = true, fspy = true, sent = true, gb = true, wos = true, ft = true }
local KIND = { group = true, fight = true, outlaw = true, seen = true, death = true }
local HAND = { first = true, relayed = true }
local POS = { enemy = true, observer = true, victim = true, none = true }
local ROUTE = { GUILD = true, PARTY = true, RAID = true, WHISPER = true, LOCAL = true }
local NS = { server = true, zoneuid = true, unknown = true }
local SHARE = { guild = true, public = true }

local function unit(v) v = S.num(v); return v and v >= 0 and v <= 1 and v or nil end
local function word(v, max)                                       -- a short display value: string or number
    if S.secret(v) then return nil, false end
    if v == nil then return nil, true end
    if type(v) == "number" then return S.num(v), S.num(v) ~= nil end
    if type(v) == "string" and #v >= 1 and #v <= max and not v:find("[%c|]") then return v, true end
    return nil, false
end

-- new(t) -> record | nil, reason. Returns a fresh, validated copy; the input is never kept.
function R.new(t)
    if not S.tab(t) then return nil, "not a table" end
    local ok, out, why = pcall(function()
        local r = {}
        if not SRC[S.clean(t.src)] then return nil, "src" end
        if not KIND[S.clean(t.kind)] then return nil, "kind" end
        local origin = S.str(t.origin, 100)
        if not origin or #origin < 2 then return nil, "origin" end
        local via = t.via
        if via ~= nil then via = S.str(via, 100); if not via then return nil, "via" end end
        if not ROUTE[S.clean(t.route)] then return nil, "route" end
        local rid = S.str(t.rid, 24)
        if not rid then return nil, "rid" end
        local zone = S.num(t.zone)
        if not zone or zone < 1 or zone % 1 ~= 0 then return nil, "zone" end
        local x, y = t.x, t.y
        if x ~= nil or y ~= nil then
            x, y = unit(x), unit(y)
            if not x or not y then return nil, "position" end
        end
        local count = t.count
        if count ~= nil then
            count = S.num(count)
            if not count or count < 0 or count > 80 or count % 1 ~= 0 then return nil, "count" end
        end
        local enemies = {}
        if t.enemies ~= nil then
            if not S.tab(t.enemies) then return nil, "enemies" end
            local n = 0
            for _ in pairs(t.enemies) do n = n + 1; if n > 80 then return nil, "enemies" end end
            for i = 1, n do
                local e = t.enemies[i]
                if not S.tab(e) then return nil, "enemy" end
                local name, okN = word(e.name, 100)
                local hash, okH = word(e.hash, 16)
                local class, okC = word(e.class, 24)
                local level, okL = word(e.level, 4)
                if not (okN and okH and okC and okL) then return nil, "enemy" end
                enemies[i] = { name = name, hash = hash, class = class, level = level }
            end
        end
        local layer = t.layer
        if not S.tab(layer) or not NS[S.clean(layer.ns)] then return nil, "layer" end
        local value, okV = word(layer.value, 32)
        if not okV then return nil, "layer" end
        if layer.ns == "server" then
            value = N.Layer.key(value)
            if not value then return nil, "layer" end
        end
        local heard = S.num(t.heard)
        if not heard then return nil, "heard" end
        local age = t.age
        if age ~= nil then age = S.num(age); if not age or age < 0 then return nil, "age" end end
        if not SHARE[S.clean(t.share)] then return nil, "share" end
        local label = t.label
        if label ~= nil then label = S.str(label, 24); if not label then return nil, "label" end end
        -- hand: first only when the transport sender is the origin and the line is not a wrapper, envelope, guild
        -- relay or sync answer; a claimed "first" never overrides that
        if t.hand ~= nil and not HAND[S.clean(t.hand)] then return nil, "hand" end
        local direct = t.hand ~= "relayed" and not t.wrapped and t.src ~= "guild" and (via == nil or via:lower() == origin:lower())
        local hops = t.hops
        if hops ~= nil then hops = S.num(hops); if not hops or hops < 1 or hops > 16 or hops % 1 ~= 0 then return nil, "hops" end end
        -- pos: whose position the coordinates are; none without coordinates
        if t.pos ~= nil and not POS[S.clean(t.pos)] then return nil, "pos" end
        local pos = x == nil and "none" or t.pos or "enemy"
        -- at: the origin's time (receipt minus the age carried, or given), never later than receipt
        local at = t.at
        if at ~= nil then at = S.num(at); if not at or at > heard then return nil, "at" end else at = heard - (age or 0) end
        r.hand, r.hops, r.pos, r.at = direct and "first" or "relayed", hops, pos, at
        r.src, r.kind, r.origin, r.via, r.route, r.rid = t.src, t.kind, origin, via, t.route, rid
        r.zone, r.x, r.y, r.count, r.enemies = zone, x, y, count, enemies
        r.layer = { ns = layer.ns, value = value }
        r.heard, r.age, r.share, r.label = heard, age, t.share, label
        r.id = r.src .. ":" .. origin:lower() .. ":" .. rid
        return r
    end)
    if not ok then return nil, "unreadable" end
    return out, why
end

-- relation(record, own) -> "same" | "other" | "unknown"; own = {zone, server, ambiguous}.
-- A different server key is another layer for certain; an equal one is only "probably yours" (two layers of a zone
-- can share a server), and nothing is said while our own key is flagged ambiguous.
function R.relation(record, own)
    if not S.tab(record) or not S.tab(own) or not S.tab(record.layer) then return "unknown" end
    if record.layer.ns ~= "server" then return "unknown" end
    -- only War Effort (first-hand) and our own records can carry a server key; HeadHunter never compares
    if record.src ~= "we" and record.src ~= "own" and not (record.src == "guild" and record.label == "we") then return "unknown" end
    local server = N.Layer.key(own.server)
    if not server or own.zone == nil or record.zone ~= own.zone then return "unknown" end
    local value = N.Layer.key(record.layer.value)
    if not value then return "unknown" end
    if value ~= server then return "other" end
    if own.ambiguous then return "unknown" end
    return "same"
end
