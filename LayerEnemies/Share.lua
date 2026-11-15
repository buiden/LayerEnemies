-- Our own sightings out (1.0 plan section 3): from the enemies our client saw (Store.localSeen, opposite faction,
-- this zone, the last 15 s, seen by our own client: units, never a Bulo copy; a row a Bulo copy refreshed keeps our
-- own sighting's time as ownAt, and only that counts) at most one report per 15 s, 3 s after
-- the first sighting of the first new enemy (an enemy re-seen every second still settles); an enemy counts as new again
-- only 60 s after it was last shared. Pure: Main sends what pick() returns.
local _, N = ...
local S = N.Safe
local Sh = {}
N.Share = Sh
Sh.SETTLE, Sh.EVERY, Sh.AGAIN, Sh.FRESH = 3, 15, 60, 15

function Sh.new() return { shared = {}, first = {}, last = nil } end
-- pick(st, seen, now, zone) -> { enemies (newest first), count, at } or nil
function Sh.pick(st, seen, now, zone)
    now = S.num(now)
    if not now or not zone or not S.tab(seen) then return nil end
    local recent, since, live = {}, nil, {}
    for key, e in pairs(seen) do
        local own = S.tab(e) and type(e.ownSource) == "string" and e.ownSource:match("^own ") and S.num(e.ownAt)
        if own and e.faction == "opposite" and e.zone == zone and now >= own and now - own <= Sh.FRESH then
            recent[#recent + 1] = e
            local at = st.shared[key]
            if not at or (now >= at and now - at >= Sh.AGAIN) then
                -- first sighting while new: kept across re-sightings (a clock stepping back starts it again)
                local f = st.first[key]
                if not f or f > now then f = own; st.first[key] = f end
                live[key] = true
                since = (since and since < f) and since or f
            end
        end
    end
    for k in pairs(st.first) do if not live[k] then st.first[k] = nil end end
    -- the settle runs from the first new enemy's own sighting; a clock that steps back counts as just sent
    if not since or now - since < Sh.SETTLE then return nil end
    if st.last and (now < st.last or now - st.last < Sh.EVERY) then return nil end
    table.sort(recent, function(a, b) if a.ownAt ~= b.ownAt then return a.ownAt > b.ownAt end return tostring(a.key) < tostring(b.key) end)
    for k, at in pairs(st.shared) do if now - at >= Sh.AGAIN then st.shared[k] = nil end end
    for _, e in ipairs(recent) do st.shared[e.key] = now; st.first[e.key] = nil end
    st.last = now
    return { enemies = recent, count = #recent, at = recent[1].ownAt }
end
