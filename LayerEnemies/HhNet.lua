-- HeadHunter 1.1.1 mesh membership (1.0 lanes B1 and B2): the peer table from the HeadHunterSync member list, one
-- honest hello per peer per session ("LayerEnemies", never a HeadHunter version), envelopes carried on unchanged but
-- their hop count, a duplicate ring, and catch-up (asking, pulling from one offer, serving what we hold verbatim).
-- Written from the wire format and the documented numbers; no donor code copied. Pure: Main sends what it returns.
-- We never author P, L or D (or any record): our frames are N, E (forwards only), Q, O, S and H (HN.frame).
local _, N = ...
local S = N.Safe
local HN = {}
N.HhNet = HN
HN.HELLO_EVERY, HN.FANOUT, HN.DISCOVER, HN.MAX_HOPS = 2, 3, 1, 5
HN.LIFETIME, HN.SKEW, HN.RING, HN.PER_TARGET, HN.PEERS = 600, 300, 4000, 6, 500
HN.ASK_AFTER, HN.ASK_PEERS, HN.COLLECT, HN.PULL_WAIT, HN.ANSWERED, HN.OFFER_TARGET = 20, 5, 5, 60, 300, 5
HN.HOLD, HN.LINK_EVERY, HN.SINCE = 300, 600, 3600
HN.SERVE, HN.ASKERS, HN.FRESH = 10, 256, 3600   -- records per pull; requesters remembered; a peer is known if heard this long ago
HN.TOLD_MAX = 2000                               -- peers greeted this session (a rejoining peer is not greeted twice)
HN.HELLO = "LayerEnemies"
HN.HELLO_TRIES, HN.HELLO_DEADLINE, HN.HELLO_BACKOFF = 8, 120, 30
-- carried in envelopes (HeadHunter's list); T is diagnostic and stops here
HN.CARRIED = { D = true, K = true, F = true, X = true, W = true, R = true, Y = true, U = true, J = true, L = true, N = true,
    T = true, P = true, Z = true }
HN.CROSS = { U = true, T = true, N = true }   -- taken from the other faction too
HN.HISTORY = { D = true, K = true, F = true, X = true, W = true, R = true, U = true }   -- kept to serve as S records
local OURS = { N = true, E = true, Q = true, O = true, S = true, H = true }

local B36 = "0123456789abcdefghijklmnopqrstuvwxyz"
function HN.b36(n)
    n = math.floor(tonumber(n) or 0)
    if n < 0 then n = 0 end
    local s = ""
    repeat local r = n % 36; s = B36:sub(r + 1, r + 1) .. s; n = (n - r) / 36 until n == 0
    return s
end
local function unb36(s)
    if type(s) ~= "string" or #s < 1 or #s > 10 or not s:match("^[0-9a-z]+$") then return nil end
    return tonumber(s, 36)
end
HN.unb36 = unb36
-- frame(side, type, body): "1<A|H><type>:<body>", only for our own types
function HN.frame(side, t, body)
    assert(OURS[t], "not a type we send")
    if (side ~= "A" and side ~= "H") or type(body) ~= "string" or body == "" then return nil end
    local s = "1" .. side .. t .. ":" .. body
    return #s <= 255 and s or nil
end
-- HeadHunter's sender comparison: lower case, before the first "-", no white space
function HN.compact(name)
    if type(name) ~= "string" then return nil end
    local base = (name:match("^([^%-]+)") or name):gsub("%s", ""):lower()
    return base ~= "" and base or nil
end
function HN.hash(s)
    local h = 5381
    for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end
    return h
end
function HN.key(author, t, record) return (HN.compact(author) or "?") .. t .. HN.hash(record) end

function HN.new()
    return { peers = {}, n = 0, ring = {}, order = {}, head = 1, count = 0, history = {}, answered = {}, helloAt = nil,
        asked = nil, offers = {}, pulling = nil, links = {}, started = nil, offered = {}, told = {}, ntold = 0, helloLast = nil }
end
-- hold(st, rec, at): a record kept to serve; full, the oldest goes
function HN.hold(st, rec, at)
    st.history[#st.history + 1] = { rec = rec, at = at }
    while #st.history > HN.HOLD do table.remove(st.history, 1) end
end
function HN.remember(st, key)
    if st.ring[key] then return end
    if st.count >= HN.RING then
        local old = st.order[st.head]
        st.ring[old] = nil
        st.order[st.head] = key
        st.head = st.head % HN.RING + 1
    else
        st.count = st.count + 1
        st.order[st.count] = key
    end
    st.ring[key] = true
end
function HN.seen(st, key) return st.ring[key] == true end
function HN.held(st) return #st.history end

local function heardFresh(p, now)
    return p.heardAt and now >= p.heardAt and now - p.heardAt <= HN.FRESH
end
local function live(p, now, ttl)
    return heardFresh(p, now) or (p.directoryAt and now >= p.directoryAt and now - p.directoryAt < ttl)
end
-- A fresh snapshot replaces directory evidence, even when empty. Directly heard peers have their own lifetime.
-- The protocol compact key is not a safe identity: a different realm/surname must never inherit peer state.
function HN.roster(st, names, me, at)
    at = S.num(at) or S.num(S.call(GetTime))
    if type(names) ~= "table" or not at then return end
    local peers, ambiguous, n = {}, {}, 0
    for _, name in ipairs(names) do
        local valid, key = N.Invite.name(name)
        local c = valid and HN.compact(name)
        if c and c ~= me and not ambiguous[c] then
            if peers[c] and peers[c].key ~= key then
                peers[c], ambiguous[c], n = nil, true, n - 1
            elseif not peers[c] and n < HN.PEERS then
                local p = st.peers[c]
                if not p or p.key ~= key then p = { key = key } end
                p.name, p.directoryAt = name, at
                peers[c], n = p, n + 1
            end
        end
    end
    for c, p in pairs(st.peers) do
        if not peers[c] and not ambiguous[c] and heardFresh(p, at) and n < HN.PEERS then
            p.directoryAt = nil; peers[c], n = p, n + 1
        end
    end
    st.peers, st.n = peers, n
end
function HN.prune(st, now, ttl)
    for c, p in pairs(st.peers) do
        if not live(p, now, ttl) then st.peers[c] = nil; st.n = st.n - 1 end
    end
end
-- Rechecked at dequeue: a queued directory-selected line must still name this same, fresh identity.
function HN.candidate(st, name, now, ttl)
    local p = st.peers[HN.compact(name) or "?"]
    return p and p.key == N.Invite.key(name) and not p.unreachable and live(p, now, ttl) or false
end
local function peer(st, name)
    local valid, key = N.Invite.name(name)
    local c = valid and HN.compact(name)
    if not c then return nil end
    local p = st.peers[c]
    if not p or p.key ~= key then
        if not p and st.n >= HN.PEERS then return nil end
        if not p then st.n = st.n + 1 end
        p = { key = key }; st.peers[c] = p
    end
    p.name = name
    return p, key
end
local function told(st, c) return st.told[c] == true end
local function tell(st, c)
    if st.told[c] then return end
    if st.ntold >= HN.TOLD_MAX then st.told, st.ntold = {}, 0 end
    st.told[c], st.ntold = true, st.ntold + 1
end
-- heard(st, sender, faction, world, hello, now) -> true when a hello reply is now owed (sent by nextHello, paced)
function HN.heard(st, sender, faction, world, hello, now)
    local p, c = peer(st, sender)
    if not p then return false end
    p.faction = faction or p.faction
    p.world = world or p.world
    p.modern = p.modern or world ~= nil or hello == true
    p.unreachable = nil
    if now then p.heardAt = now end
    if hello and not told(st, c) then tell(st, c); p.replyOwed = true; return true end
    return false
end
-- Apply Wire's suppression before selecting any mesh work, including an owed hello. Incoming evidence cannot
-- bypass that suppression; an expired one is released, but it does not restart a finished hello.
function HN.suppress(st, offlineUntil, now)
    for _, p in pairs(st.peers) do
        local untilAt = offlineUntil(p.name, now)
        if untilAt then p.unreachable = untilAt; p.replyOwed, p.helloNext = nil, nil
        elseif type(p.unreachable) == "number" and now >= p.unreachable then p.unreachable = nil end
    end
end
local function expireHello(p, now)
    if p.replyOwed and (p.unreachable or (p.helloStart and (now < p.helloStart or now - p.helloStart >= HN.HELLO_DEADLINE))) then
        p.replyOwed, p.helloNext = nil, nil
    end
end
-- nextHello: one per 2 s, with unattempted peers ahead of retries. Fresh owed replies win ties, but a failed
-- alphabetical-first peer cannot monopolize the scheduler. Counts include local (no client call) attempts.
function HN.nextHello(st, now, side)
    if st.helloLast and now - st.helloLast < HN.HELLO_EVERY then return nil end
    local names = {}
    for c, p in pairs(st.peers) do
        expireHello(p, now)
        -- Explicit hello replies may cross faction, as before; spontaneous greetings may not.
        if not p.unreachable and (p.replyOwed or not p.faction or p.faction == side)
            and ((p.replyOwed and (not p.helloNext or now >= p.helloNext)) or not told(st, p.key)) then names[#names + 1] = c end
    end
    table.sort(names, function(a, b)
        local x, y = st.peers[a], st.peers[b]
        local nx, ny = x.helloTries or 0, y.helloTries or 0
        if nx ~= ny then return nx < ny end
        if not not x.replyOwed ~= not not y.replyOwed then return x.replyOwed == true end
        return a < b
    end)
    local c = names[1]
    if not c then return nil end
    local p = st.peers[c]
    p.replyOwed, p.helloNext = nil, nil
    p.helloStart, p.helloTries = p.helloStart or now, (p.helloTries or 0) + 1
    tell(st, p.key); st.helloLast = now
    return p.name
end
-- Only local budget/pause refusals are retried, with exponential backoff and a hard attempt/deadline bound.
-- An actual client refusal (including a client throttle), offline, invalid text or a privacy refusal is terminal.
function HN.unsent(st, name, why, attempted, now)
    local p = st.peers[HN.compact(name) or "?"]
    if not p then return end
    p.replyOwed, p.helloNext = nil, nil
    if attempted or (why ~= "throttled" and why ~= "paused") or not now or not p.helloStart then return end
    if (p.helloTries or 0) >= HN.HELLO_TRIES or now < p.helloStart then return end
    local delay = math.min(HN.HELLO_BACKOFF, 2 ^ (p.helloTries or 1))
    if now + delay - p.helloStart >= HN.HELLO_DEADLINE then return end
    p.replyOwed, p.helloNext = true, now + delay
end
function HN.helloDelay(st, now)
    local due
    for _, p in pairs(st.peers) do
        expireHello(p, now)
        if p.replyOwed then due = math.min(due or math.huge, p.helloNext or now) end
    end
    return due and math.max(HN.HELLO_EVERY, due - now) or nil
end
function HN.owed(st) for _, p in pairs(st.peers) do if p.replyOwed then return true end end return false end
-- sameWorld(a, b): "region-ruleset"; a part one side does not know ("?") does not split it
function HN.sameWorld(a, b)
    if type(a) ~= "string" or type(b) ~= "string" then return false end
    local r1, k1 = a:match("^([^%-]+)%-(.+)$")
    local r2, k2 = b:match("^([^%-]+)%-(.+)$")
    if not r1 or not r2 then return false end
    local function same(x, y) return x == y or x == "?" or y == "?" end
    return same(r1, r2) and same(k1, k2)
end
-- envelope(record) -> { world, author, faction, server (string as sent), hops, at, type, record, raw } or nil
function HN.envelope(rec)
    if type(rec) ~= "string" then return nil end
    local world, author, f, server, hops, at, t, record = rec:match("^([^;]+);([^;]+);([AH]);([0-9a-z]+);([0-9a-z]+);([0-9a-z]+);(%u)(.+)$")
    if not world or #world > 40 or world:find("%c") or #author > 80 or author:find("[%c|:,~]") then return nil end
    local atRaw = at
    hops, at = unb36(hops), unb36(at)
    if not hops or not at or #server > 10 then return nil end
    return { world = world, author = author, faction = f, server = server, hops = hops, at = at, atRaw = atRaw, type = t,
        record = record }
end
-- the envelope as received, with only its hop count changed (faction letter, server and timestamp bytes kept)
local function rebuild(e, hops)
    return table.concat({ e.world, e.author, e.faction, e.server, HN.b36(hops), e.atRaw }, ";") .. ";" .. e.type .. e.record
end
-- pick(st, count, exclude, now, side) -> names: up to count known peers, then max(1, count - known) unknown ones
function HN.pick(st, count, exclude, now, side, world)
    local known, unknown = {}, {}
    for c, p in pairs(st.peers) do
        if not exclude[c] and not p.unreachable and (not p.faction or p.faction == side)
            and (not p.world or HN.sameWorld(p.world, world)) then
            local sentN = 0
            for _, at in ipairs(p.sentAt or {}) do if now - at < 60 and now >= at then sentN = sentN + 1 end end
            -- known: a modern peer heard within 3600 s; anyone else is only a discovery candidate
            local fresh = p.modern and p.heardAt and now >= p.heardAt and now - p.heardAt <= HN.FRESH
            if sentN < HN.PER_TARGET then (fresh and known or unknown)[#(fresh and known or unknown) + 1] = p end
        end
    end
    local function shuffle(l) for i = #l, 2, -1 do local j = math.floor((HN.rand or math.random)() * i) + 1; l[i], l[j] = l[j], l[i] end end
    table.sort(known, function(a, b) return a.name < b.name end); table.sort(unknown, function(a, b) return a.name < b.name end)
    shuffle(known); shuffle(unknown)
    local out = {}
    for i = 1, math.min(count, #known) do out[#out + 1] = known[i] end
    for i = 1, math.min(math.max(HN.DISCOVER, count - #out), #unknown) do out[#out + 1] = unknown[i] end
    local names = {}
    for _, p in ipairs(out) do
        local l = {}
        for _, at in ipairs(p.sentAt or {}) do if now - at < 60 and now >= at then l[#l + 1] = at end end
        l[#l + 1] = now; p.sentAt = l
        names[#names + 1] = p.name
    end
    return names
end
-- carry(st, rec, carrier, side, now, ctx) -> list of { target, text } to forward, and why
--   ctx = { world, serverNow, me (compact), side }
function HN.carry(st, rec, carrier, carrierSide, now, ctx)
    local e = HN.envelope(rec)
    if not e or not HN.CARRIED[e.type] then return {}, "invalid" end
    local fromAuthor = HN.compact(e.author) == HN.compact(carrier)
    if not HN.sameWorld(e.world, ctx.world) or e.hops < 1 or e.hops > HN.MAX_HOPS or e.at > ctx.serverNow + HN.SKEW
        or ctx.serverNow - e.at > HN.LIFETIME or (fromAuthor and e.hops ~= 1) then return {}, "refused" end
    HN.heard(st, carrier, carrierSide, e.world, false, now)
    if HN.compact(e.author) == ctx.me then return {}, "own echo" end
    if e.faction ~= ctx.side and not HN.CROSS[e.type] then return {}, "other faction" end
    local key = HN.key(e.author, e.type, e.record)
    if HN.seen(st, key) then return {}, "duplicate" end
    HN.remember(st, key)
    if HN.HISTORY[e.type] then HN.hold(st, e.type .. e.record, ctx.serverNow) end
    if e.type == "T" or e.hops >= HN.MAX_HOPS then return {}, "kept" end
    local exclude = { [HN.compact(e.author) or "?"] = true, [HN.compact(carrier) or "?"] = true, [ctx.me] = true }
    local out = {}
    -- still(serverNow): a queued forward goes only while the envelope is at most 600 s old
    local at = e.at
    local function still(serverNow) return type(serverNow) == "number" and serverNow - at <= HN.LIFETIME end
    for _, name in ipairs(HN.pick(st, HN.FANOUT, exclude, now, ctx.side, ctx.world)) do
        local text = HN.frame(ctx.side, "E", rebuild(e, e.hops + 1))
        if text then out[#out + 1] = { target = name, text = text, still = still } end
    end
    return out, "forwarded"
end
-- records(st, since) -> the newest records (at most 10, so a pull paced one frame per 2 s ends well inside
-- HeadHunter's 60 s give-up) held since then that fit a frame alone, oldest first
function HN.records(st, since)
    local out = {}
    for i = #st.history, 1, -1 do
        local r = st.history[i]
        if #out >= HN.SERVE then break end
        if r.at >= since and 5 + #r.rec <= 255 then table.insert(out, 1, r.rec) end
    end
    return out
end
-- requester maps: entries older than 300 s go; at most 256 (full: no answer)
local function room(map, now)
    local n = 0
    for k, at in pairs(map) do if now < at or now - at >= HN.ANSWERED then map[k] = nil else n = n + 1 end end
    return n < HN.ASKERS
end
function HN.chance(online) return math.min(1, HN.OFFER_TARGET / math.max(1, (online or 1) - 1)) end
local function answeredLately(st, who, now)
    local at = st.answered[HN.compact(who) or "?"]
    return at ~= nil and now >= at and now - at < HN.ANSWERED
end
-- query(st, body, sender, now, ctx, side) -> { target, text, delay } list; side: the frame's faction letter
function HN.query(st, body, sender, now, ctx, side)
    local kind, since = body:sub(1, 1), unb36(body:sub(2))
    if not since or (kind ~= "h" and kind ~= "p") or answeredLately(st, sender, now) then return {} end
    local who = HN.compact(sender) or "?"
    local recs = HN.records(st, since)
    if kind == "h" then
        if #recs == 0 or (ctx.rand or math.random)() >= HN.chance(ctx.online) then return {} end
        if st.offered[who] and now >= st.offered[who] and now - st.offered[who] < HN.ANSWERED then return {} end
        if not room(st.offered, now) then return {} end
        st.offered[who] = now
        return { { target = sender, text = HN.frame(ctx.side, "O", HN.b36(#recs)), delay = (ctx.rand or math.random)() * 3 } }
    end
    -- a pull is served only to a known peer of our faction, heard within 3600 s
    local p = st.peers[who]
    if not p or (side and side ~= ctx.side) or (p.faction and p.faction ~= ctx.side) then return {} end
    if not (p.heardAt and now >= p.heardAt and now - p.heardAt <= HN.FRESH) then return {} end
    if not room(st.answered, now) then return {} end
    st.answered[who] = now
    recs[#recs + 1] = "E" .. HN.b36(#recs)
    -- packed into frames of at most 255 bytes ("~" between records); a record that cannot fit alone is skipped
    local out, cur = {}, {}
    local function flush() if cur[1] then out[#out + 1] = { target = sender, text = HN.frame(ctx.side, "S", table.concat(cur, "~")) }; cur = {} end end
    for _, r in ipairs(recs) do
        if 5 + #r <= 255 then
            if #cur > 0 and 5 + #table.concat(cur, "~") + 1 + #r > 255 then flush() end
            cur[#cur + 1] = r
        end
    end
    flush()
    return out
end
-- ask(st, now, ctx) -> Q:h frames to up to 5 peers (+1 discovery), once, 20 s after start
function HN.ask(st, now, ctx)
    if st.asked or not st.started or now - st.started < HN.ASK_AFTER then return {} end
    st.asked = now
    local out = {}
    for _, name in ipairs(HN.pick(st, HN.ASK_PEERS, { [ctx.me] = true }, now, ctx.side, ctx.world)) do
        out[#out + 1] = { target = name, text = HN.frame(ctx.side, "Q", "h" .. HN.b36(ctx.serverNow - HN.SINCE)) }
    end
    return out
end
-- offer(st, sender, body, now): an O to our ask
function HN.offer(st, sender, body, now)
    local n = unb36(body)
    if not st.asked or st.pulling or now - st.asked > HN.COLLECT + 30 or not n or n < 1 then return end
    st.offers[HN.compact(sender) or "?"] = { name = sender, n = n, at = now }
end
-- pull(st, now, ctx) -> the Q:p frame to the biggest offer, 5 s after the first offer
function HN.pull(st, now, ctx)
    if st.pulling then
        if now - st.pulling.at > HN.PULL_WAIT then st.pulling.done = true end
        return {}
    end
    local first, best
    for _, o in pairs(st.offers) do
        first = (not first or o.at < first) and o.at or first
        if not best or o.n > best.n or (o.n == best.n and o.name < best.name) then best = o end
    end
    if not best or now - first < HN.COLLECT then return {} end
    st.pulling = { name = best.name, at = now }
    st.offers = {}
    return { { target = best.name, text = HN.frame(ctx.side, "Q", "p" .. HN.b36(ctx.serverNow - HN.SINCE)) } }
end
-- snapshot(st, sender, body, ctx, side): S records from the sender we pull from, kept verbatim until its end marker;
-- from the other faction only the kinds HeadHunter takes across (as for envelopes)
function HN.snapshot(st, sender, body, ctx, side)
    local p = st.pulling
    if not p or p.done or HN.compact(p.name) ~= HN.compact(sender) then return false end
    for rec in (body .. "~"):gmatch("([^~]*)~") do
        local k = rec:sub(1, 1)
        if k == "E" then p.done = true; break end
        if k:match("%u") and #rec >= 2 and not rec:find("[%c|]") and (not side or side == ctx.side or HN.CROSS[k]) then
            HN.hold(st, rec, ctx.serverNow)
        end
    end
    return true
end
-- link(st, sender, now, side, home) -> our H reply, at most once per 600 s per player
function HN.link(st, sender, now, side, home)
    local c = HN.compact(sender)
    if not c then return nil end
    local at = st.links[c]
    if at and now >= at and now - at < HN.LINK_EVERY then return nil end
    local n = 0
    for k, v in pairs(st.links) do if now - v >= HN.LINK_EVERY then st.links[k] = nil else n = n + 1 end end
    if n >= 256 then return nil end
    st.links[c] = now
    return HN.frame(side, "H", HN.b36(home or 0))
end
