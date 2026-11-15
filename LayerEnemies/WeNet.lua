-- War Effort membership state (1.0 lane A2): hello rhythm, the login Q, our own last reports kept to answer a sync
-- request (Y) with, the answer queue, and the per-requester limits for Y and J. Pure: Main sends what it returns.
local _, N = ...
local S = N.Safe
local Wn = {}
N.WeNet = Wn
Wn.FIRST, Wn.QUERY, Wn.EVERY, Wn.JITTER = 10, 15, 180, 10      -- first hello and Q after login; then every 180 to 190 s
Wn.SAME, Wn.ASKED = 30, 10              -- an identical hello not again within 30 s; a Q answered at most once per 10 s
Wn.GROUP_EVERY = 175                    -- a group hello at the same rhythm (a little slack, as War Effort)
Wn.KEEP, Wn.KEEP_AGE = 3, 900           -- our own last reports kept to answer with, and how long
Wn.COOLDOWN, Wn.WAITING, Wn.START, Wn.QUEUED, Wn.GAP = 600, 5, 60, 300, 5
Wn.J_EVERY = 60
Wn.QUERY_TRIES = 2                      -- the login Q: at most two attempts

function Wn.new(now)
    return { start = now, helloDue = now + Wn.FIRST, queried = false, said = {}, saidAt = {}, askedAt = nil,
        kept = {}, answered = {}, waiting = {}, lastSent = nil, joinAt = {}, queryTries = 0 }
end
-- keep(st, rep): our own report as sent (C+E), for sync answers; the newest three
function Wn.keep(st, rep)
    st.kept[#st.kept + 1] = rep
    while #st.kept > Wn.KEEP do table.remove(st.kept, 1) end
end
local function prune(map, now, keep)
    for k, at in pairs(map) do if now < at or now - at >= keep then map[k] = nil end end
end
-- forget(st): sharing off: our kept reports and every answer still waiting go (they carry our own C/E)
function Wn.forget(st) st.kept, st.waiting = {}, {} end
-- request(st, sender, continent, maxAge, now, continentOf, rand) -> true or nil, why
function Wn.request(st, sender, continent, maxAge, now, continentOf, rand)
    local key = N.Invite.key(sender)
    if not key then return nil, "name" end
    prune(st.answered, now, Wn.COOLDOWN)
    if st.answered[key] then return nil, "answered lately" end
    for _, j in ipairs(st.waiting) do if j.key == key then return nil, "already waiting" end end
    if #st.waiting >= Wn.WAITING then return nil, "queue full" end
    local recs = {}
    for _, r in ipairs(st.kept) do
        if now >= r.t and now - r.t <= math.min(maxAge, Wn.KEEP_AGE) and continentOf(r.map) == continent then recs[#recs + 1] = r end
    end
    if not recs[1] then return nil, "nothing to send" end
    st.answered[key] = now
    st.waiting[#st.waiting + 1] = { key = key, name = sender, at = now, startAt = now + (rand or Wn.rand or math.random)() * Wn.START,
        recs = recs, maxAge = math.min(maxAge, Wn.KEEP_AGE), i = 1, part = 0 }
    return true
end
-- nextAnswer(st, now) -> name, text (one message, every 5 s at most) or nil
function Wn.nextAnswer(st, now)
    for i = #st.waiting, 1, -1 do
        local j = st.waiting[i]
        if not j.started and now - j.at > Wn.QUEUED then table.remove(st.waiting, i) end
    end
    -- paced from the last send itself (a clock stepping back counts as just sent)
    if st.lastSent and (now < st.lastSent or now - st.lastSent < Wn.GAP) then return nil end
    local job
    for _, j in ipairs(st.waiting) do if now >= j.startAt then job = j; break end end
    if not job then return nil end
    job.started = true
    while true do
        local r = job.recs[job.i]
        if not r then break end
        if job.part == 0 then
            if now - r.t > job.maxAge then job.i = job.i + 1
            else
                job.parts = N.WeOut.enemies(r.rid, r.enemies, r.server)
                job.part = 1
                st.lastSent = now
                return job.name, N.WeOut.cluster(r.rid, r.map, r.x, r.y, r.layer, r.count, r.server, job.i, #job.recs)
            end
        else
            local e = job.parts[job.part]
            -- each E is checked against the asked age at its own send, like its C
            if e and now - r.t <= job.maxAge then job.part = job.part + 1; st.lastSent = now; return job.name, e end
            job.i, job.part = job.i + 1, 0
        end
    end
    for i, j in ipairs(st.waiting) do if j == job then table.remove(st.waiting, i); break end end
    return Wn.nextAnswer(st, now)
end
-- join(st, sender, now) -> true when this requester may get a K now (one per 60 s)
function Wn.join(st, sender, now)
    local key = N.Invite.key(sender)
    if not key then return false end
    prune(st.joinAt, now, Wn.J_EVERY)
    if st.joinAt[key] then return false end
    local n = 0; for _ in pairs(st.joinAt) do n = n + 1 end
    if n >= 256 then return false end
    st.joinAt[key] = now
    return true
end
