-- Our own sightings out: opposite faction, this zone, at most 45 s old. Only ownAt
-- counts, never the time of a Bulo refresh. Main sends one O per 15 s slot, after
-- a 3 s settle, and acknowledges only the names the encoder fitted and Wire took.
local _, N = ...
local S = N.Safe
local Sh = {}
N.Share = Sh
Sh.SETTLE, Sh.EVERY, Sh.AGAIN, Sh.FRESH = 3, 15, 60, 45
Sh.LINES = 3

function Sh.new() return { shared = {}, names = {}, first = {}, skipped = {}, early = {}, last = nil } end
-- A complete changed list can grant at most four unique-name repeats. Tickets
-- expire with the held own observation, and are consumed only by fitted O names.
function Sh.watch(st,seen,hashes,now,zone)
    local candidates={}
    for _,e in pairs(seen) do
        if e.faction=="opposite" and e.zone==zone and type(e.ownSource)=="string" and e.ownSource:match("^own ")
            and S.num(e.ownAt) and now>=e.ownAt and now-e.ownAt<Sh.FRESH then
            local hash=N.Watch.hash(e.displayName or e.name)
            if hash and hashes[hash] then candidates[#candidates+1]={e=e,hash=hash} end
        end
    end
    table.sort(candidates,function(a,b) return tostring(a.e.key)<tostring(b.e.key) end)
    local picked,n={},0
    for _,v in ipairs(candidates) do
        if not picked[v.hash] and n<4 then
            picked[v.hash]=true; n=n+1; st.early[v.hash]=v.e.ownAt
            if st.burst then st.burst.pending[v.e.key]=true end
        end
    end
end
-- Cancel a snapshot, not the send/name cooldowns. Existing observations cannot
-- reopen it; a later own observation may start a new burst at the normal slot.
function Sh.cancel(st, seen, now)
    if st.we then Sh.cancel(st.we, seen, now) end
    st.burst = nil
    S.clear(st.early)
    S.clear(st.first)
    S.clear(st.skipped)
    for key in pairs(seen) do st.skipped[key] = now end
end
-- pick reserves a slot before Main can call Wire (including a refused attempt).
-- A burst snapshots the eligible keys; newer arrivals wait for the next burst.
function Sh.pick(st, seen, now, zone, watch)
    now = S.num(now)
    if not now or not zone or not S.tab(seen) then return nil end
    for _, stamps in ipairs({st.shared, st.names}) do
        for k, at in pairs(stamps) do if now - at >= Sh.AGAIN then stamps[k] = nil end end
    end
    for k, at in pairs(st.skipped) do if not seen[k] or now - at > Sh.FRESH then st.skipped[k] = nil end end
    for hash,at in pairs(st.early) do if now-at>=Sh.FRESH then st.early[hash]=nil end end
    local recent, since, live, priority, normal = {}, nil, {}, {}, {}
    for key, e in pairs(seen) do
        local own = S.tab(e) and type(e.ownSource) == "string" and e.ownSource:match("^own ") and S.num(e.ownAt)
        if own and e.faction == "opposite" and e.zone == zone and now >= own and now - own <= Sh.FRESH then
            local _, name = N.Relay.ownName(e)
            local at, named = st.shared[key], name and st.names[name]
            local skipped = st.skipped[key]
            local listed,hash=false,nil
            if watch then local ours; listed,ours,hash=N.Watch.match(watch,e.displayName or e.name,now) end
            local early=listed and hash and st.early[hash] and now>=st.early[hash] and now-own<Sh.FRESH
            priority[key]=early and 2 or listed and 1 or 0
            local eligible=(not at or (now >= at and now - at >= Sh.AGAIN))
                and (not named or (now >= named and now - named >= Sh.AGAIN))
                and (not skipped or own > skipped)
            normal[key]=eligible
            if early or eligible then
                recent[#recent + 1] = e
                -- Re-sightings do not restart the first new enemy's settle.
                local f = st.first[key]
                if not f or f > now then f = own; st.first[key] = f end
                live[key] = true
                since = (since and since < f) and since or f
            end
        end
    end
    for k in pairs(st.first) do if not live[k] then st.first[k] = nil end end
    local burst = st.burst
    if burst then
        for k in pairs(burst.pending) do if not live[k] then burst.pending[k] = nil end end
        if not next(burst.pending) then st.burst = nil; burst = nil end
    end
    if not since or now - since < Sh.SETTLE then return nil end
    if st.last and (now < st.last or now - st.last < Sh.EVERY) then return nil end
    table.sort(recent, function(a, b) if priority[a.key] ~= priority[b.key] then return priority[a.key] > priority[b.key] end; if a.ownAt ~= b.ownAt then return a.ownAt > b.ownAt end return tostring(a.key) < tostring(b.key) end)
    if not burst then
        burst = { pending = {}, lines = 0 }
        for _, e in ipairs(recent) do burst.pending[e.key] = true end
        st.burst = burst
    end
    local enemies, public = {}, {}
    for _, e in ipairs(recent) do
        if burst.pending[e.key] then
            enemies[#enemies + 1] = e
            if normal[e.key] then public[#public + 1] = e end
        end
    end
    burst.lines = burst.lines + 1
    st.last = now
    return { enemies = enemies, public = public, count = #enemies, at = enemies[1].ownAt, first = burst.lines == 1, burst = burst }
end
-- fitted is empty when the client refused the line. No queued sends: receipt
-- means client acceptance, not proof of delivery. Failures still use a slot.
function Sh.sent(st, rep, fitted, now)
    for _, e in ipairs(fitted) do
        st.shared[e.key] = now; st.first[e.key] = nil
        local hash=N.Watch and N.Watch.hash(e.displayName or e.name)
        if hash then st.early[hash]=nil end
        local _, name = N.Relay.ownName(e)
        if name then st.names[name] = now end
        rep.burst.pending[e.key] = nil
    end
    if st.burst ~= rep.burst then return end
    if rep.burst.lines >= Sh.LINES or not next(rep.burst.pending) then
        -- At most three attempts (12 short names). Overflow is dropped, NOT
        -- marked shared. Only a new observation after this close can retry it.
        for key in pairs(rep.burst.pending) do st.skipped[key] = now; st.first[key] = nil end
        st.burst = nil
    end
end

-- War Effort has one whole cohort, not the guild's independently paced chunks.
-- Keep its eligibility in a separate lane; reserve every eligible enemy before
-- dispatch, as the original single-report picker did even when a send failed.
-- Cancelling either lane retains its cooldowns, never marking unsent O names.
function Sh.pickWe(st, seen, now, zone)
    if not st.we then st.we = Sh.new() end
    local rep = Sh.pick(st.we, seen, now, zone)
    if rep then Sh.sent(st.we, rep, rep.enemies, now) end
    return rep
end
