-- War Effort report assembly, keyed by the original reporter and report id. A C alone makes a record; E lists enrich
-- it (they may arrive first: held 15 s), never change when it was heard, and may stay incomplete: count is what C
-- said. Every result is "reported, not confirmed": the wire has no absolute time.
local _, N = ...
local R, S, P = {}, N.Safe, N.Protocol
N.Reports = R
R.MAX, R.TTL, R.HOLD, R.HELD, R.ORIGINS, R.ORDER = 64, 600, 15, 200, 512, 3600
R.HELD_ALL = 256                                                 -- held E entries across all origins

function R.new() return { reports = {}, n = 0, latest = {}, held = {}, heldBy = {}, heldAll = 0, rates = {}, nrates = 0 } end
-- Drops one held list and its counts.
local function unhold(st, key)
    local h = st.held[key]
    if not h then return end
    st.heldBy[h.okey] = (st.heldBy[h.okey] or 0) - h.entries
    if st.heldBy[h.okey] <= 0 then st.heldBy[h.okey] = nil end
    st.heldAll = st.heldAll - h.entries
    st.held[key] = nil
end
-- A zone boundary: reports and held lists go; the per-reporter report order stays (an old id stays old).
function R.clearPending(st)
    S.clear(st.reports); st.n = 0; S.clear(st.held); S.clear(st.heldBy); st.heldAll = 0
end
function R.prune(st, now)
    for k, v in pairs(st.reports) do if now - v.at >= R.TTL then st.reports[k] = nil; st.n = st.n - 1 end end
    for k, v in pairs(st.held) do if now - v.at > R.HOLD then unhold(st, k) end end
    for k, v in pairs(st.rates) do if now - v.at >= 10 then st.rates[k] = nil; st.nrates = st.nrates - 1 end end
    for k, v in pairs(st.latest) do if now - v.at >= R.ORDER then st.latest[k] = nil end end
end
-- A report id is newer iff (new - old) % 65536 is below half the id space and the ids differ.
function R.newer(new, old) return new ~= old and (new - old) % 65536 < 32768 end
-- Receive limit per immediate sender: 6 messages per 10 s, 20 for G/X wrappers. Excess is dropped silently.
function R.allow(st, sender, wrapped, now)
    local key = (wrapped and "w:" or "d:") .. tostring(sender):lower()
    local v = st.rates[key]
    if not v or now - v.at >= 10 then
        if not v then
            -- full: clear expired windows first (receive, which also prunes, never runs for a refused sender)
            if st.nrates >= 512 then
                for k, w in pairs(st.rates) do if now - w.at >= 10 then st.rates[k] = nil; st.nrates = st.nrates - 1 end end
            end
            if st.nrates >= 512 then return false end
            st.nrates = st.nrates + 1
        end
        v = { at = now, n = 0 }; st.rates[key] = v
    end
    if v.n >= (wrapped and 20 or 6) then return false end
    v.n = v.n + 1
    return true
end

-- Adds an E list to a report: entries new to it (hash + class) are appended, unless the report would then hold more
-- enemies than its count, in which case the whole list is rejected.
local function enrich(rep, list)
    local add = {}
    for _, e in ipairs(list) do
        local k = e.hash .. ":" .. tostring(e.class)
        if not rep.seen[k] then rep.seen[k] = true; add[#add + 1] = e end
    end
    local r = rep.record
    if #r.enemies + #add > (r.count or 0) then
        for _, e in ipairs(add) do rep.seen[e.hash .. ":" .. tostring(e.class)] = nil end
        return false
    end
    for _, e in ipairs(add) do r.enemies[#r.enemies + 1] = { hash = e.hash, class = e.class, level = e.level } end
    return #add > 0
end

-- receive(st, msg, ctx) -> record | nil, reason. msg from Protocol.decode (C or E, or G/X carrying one);
-- ctx = {sender, route, now, serverNow, zoneFn, peers}.
function R.receive(st, msg, ctx)
    local now = S.num(ctx.now)
    if not now or not S.tab(msg) then return nil, "unreadable" end
    R.prune(st, now)
    local wrapped = msg.type == "G" or msg.type == "X"
    local inner = wrapped and msg.inner or msg
    if inner.type == "H" then return nil, "hello" end
    local origin = wrapped and msg.origin or ctx.sender
    local okey = N.Peers.key(origin)
    if not okey then return nil, "origin" end
    local age = P.age(inner.stamp, ctx.serverNow)
    if not age then return nil, "clock unavailable" end
    if age > P.MAXAGE then return nil, "stale" end
    local key = okey .. ":" .. inner.rid
    local rep = st.reports[key]
    if inner.type == "E" then
        if rep then
            if not enrich(rep, inner.enemies) then
                -- a list that would overfill the report is rejected whole; an all-known one changes nothing
                local over = false
                for _, e in ipairs(inner.enemies) do if not rep.seen[e.hash .. ":" .. tostring(e.class)] then over = true end end
                return nil, over and "more enemies than counted" or "duplicate list"
            end
            return rep.record, "enriched"
        end
        local entries = #inner.enemies
        if (st.heldBy[okey] or 0) + entries > R.HELD then return nil, "held list cap" end
        -- across all origins: the oldest held lists make room
        while st.heldAll + entries > R.HELD_ALL do
            local oldest, ok
            for k, v in pairs(st.held) do if k ~= key and (not oldest or v.at < oldest) then oldest, ok = v.at, k end end
            if not ok then break end
            unhold(st, ok)
        end
        if st.heldAll + entries > R.HELD_ALL then return nil, "held list cap" end
        local h = st.held[key]
        if not h then h = { at = now, okey = okey, lists = {}, entries = 0 }; st.held[key] = h end
        h.lists[#h.lists + 1] = inner.enemies; h.entries = h.entries + entries
        st.heldBy[okey] = (st.heldBy[okey] or 0) + entries
        st.heldAll = st.heldAll + entries
        return nil, "held"
    end
    -- C: only a report newer than the last one heard from this reporter (an hour of memory). A repeat of the same
    -- id, by a relay or after a boundary, is not a new sighting.
    if rep then return nil, "duplicate report" end
    local last = st.latest[okey]
    if last and not R.newer(inner.rid, last.rid) then return nil, "old report" end
    if st.n >= R.MAX then return nil, "report cap" end
    local zone = ctx.zoneFn and ctx.zoneFn(inner.map) or nil
    if not zone then return nil, "zone unknown" end
    local minor = N.Peers.minor(ctx.peers, origin, now)
    local layer
    if N.Peers.layerKnown(minor) and inner.layer > 0 then layer = { ns = "server", value = tostring(inner.layer) }
    else layer = { ns = "unknown", value = inner.layer } end
    local record, why = N.Record.new({ src = "we", kind = "group", origin = origin, via = ctx.sender, route = ctx.route,
        rid = tostring(inner.rid), zone = zone, x = inner.x, y = inner.y, count = inner.count, enemies = {}, layer = layer,
        heard = now, age = age, share = (ctx.route == "GUILD" and not wrapped) and "guild" or "public",
        wrapped = wrapped, hops = wrapped and 1 or nil })
    if not record then return nil, "record: " .. tostring(why) end
    if not last then
        local n, oldest, ok = 0, nil, nil
        for k, v in pairs(st.latest) do n = n + 1; if not oldest or v.at < oldest then oldest, ok = v.at, k end end
        if n >= R.ORIGINS then st.latest[ok] = nil end
    end
    st.latest[okey] = { rid = inner.rid, at = now }
    rep = { record = record, at = now, seen = {} }
    st.reports[key] = rep; st.n = st.n + 1
    local h = st.held[key]
    if h then
        for _, list in ipairs(h.lists) do enrich(rep, list) end
        unhold(st, key)
    end
    return record, "new"
end
