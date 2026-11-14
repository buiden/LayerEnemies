-- Guild-only host: the pure part. parse() reads a LayerSwap-format request; decide() says what a host answers.
-- Nothing here sends, invites or reads the client: the caller passes a snapshot of our own state (own) and acts on
-- the verdict through Wire. Stricter than LayerSwap and Bulo: guild members only, no invite in combat, a request
-- without want or not is refused, 10 s between invites and at most 6 per 600 s.
local _, N = ...
local S = N.Safe
local G = {}
N.GuildHost = G
G.ASKER, G.EVERY, G.CAP, G.WINDOW, G.PENDING = 60, 10, 6, 600, 60
G.MAX_ASKED, G.MAX_NOTS = 128, 8

-- parse(text) -> { zone, want | nots, x, y } or nil. Only the whole line, at most 255 bytes:
--   inv layer <LS <zone> want <d>-<d>[ <x>,<y>]>
--   inv layer <LS <zone> not <d>-<d>[ not <d>-<d>]...[ <x>,<y>]>
function G.parse(text)
    if S.secret(text) or type(text) ~= "string" or #text > 255 then return nil end
    local zone, body = text:match("^inv layer <LS (%d+) ([^<>]+)>$")
    if not zone or #zone > 9 then return nil end
    local out = { zone = tonumber(zone) }
    local rest, x, y = body:match("^(.-) (%d+%.?%d*),(%d+%.?%d*)$")
    if rest then body, out.x, out.y = rest, tonumber(x), tonumber(y) end
    local want = body:match("^want (%d+%-%d+)$")
    if want then out.want = want; return out end
    local nots = {}
    while body ~= "" do
        local key, tail = body:match("^not (%d+%-%d+)(.*)$")
        if not key or #nots >= G.MAX_NOTS then return nil end
        nots[#nots + 1] = key
        if tail == "" then body = "" else body = tail:match("^ (.+)$"); if not body then return nil end end
    end
    if #nots == 0 then return nil end
    out.nots = nots
    return out
end

-- Hosting is off at every login and reload (never saved).
function G.new() return { on = false, asked = {}, pending = {}, hosted = {}, invites = {}, lastInvite = nil, held = nil } end

local function short(name) local _, key = N.Invite.name(name); return key end
-- The asker as our reply names them: without a realm suffix, as their own UnitName reads.
local function replyName(name) return (name:match("^([^%-]+)%-") or name) end
local function heard(name, own, flag)
    local id = S.str(own.id, 32)
    if not (id and id:match("^%d+%-%d+$")) then id = own.key .. "-0" end
    return "heard " .. replyName(name) .. "|" .. id .. "|" .. string.format("%d", own.zone) .. "|" .. flag
end
local function remember(st, key, now)
    if st.asked[key] == nil then
        local n, oldest, okey = 0, nil, nil
        for k, at in pairs(st.asked) do n = n + 1; if not oldest or at < oldest then oldest, okey = at, k end end
        if n >= G.MAX_ASKED then st.asked[okey] = nil end
    end
    st.asked[key] = now
end

-- decide(st, req, own, now) -> verdict, reply
-- req = { name, zone, want | nots }; own = { self, zone, key, id, inInstance, inCombat, raid, leader, members,
-- asking, member }. Verdicts: "drop" (no reply), "same" (reply "same"), "busy" (reply heard ...|-),
-- "invite" (reply heard ...|h; the caller invites once). Every failure before the guild check is silent.
-- early(st, req, own, now) -> name, key, our key | nil: every check before the guild check, nothing recorded.
-- The caller asks for a new roster only for a request that passes these.
function G.early(st, req, own, now)
    if not st.on or not S.tab(req) or not S.tab(own) or not S.num(now) then return nil end
    local name = S.str(req.name, 100)
    local key = name and short(name)
    if not key or key == own.self then return nil end
    local last = st.asked[key]
    if last and now - last < G.ASKER and now >= last then return nil end
    if not own.zone or req.zone ~= own.zone then return nil end
    local mine = N.Layer.key(own.key)
    if not mine then return nil end
    if own.inInstance ~= false or own.inCombat ~= false then return nil end
    return name, key, mine
end
function G.decide(st, req, own, now)
    local name, key, mine = G.early(st, req, own, now)
    if not name then return "drop" end
    -- the request reached the guild check: the 60 s per asker starts here
    remember(st, key, now)
    if own.member ~= true then return "drop" end
    own.key = mine
    if req.want then
        if N.Layer.key(req.want) ~= mine then return "busy", heard(name, own, "-") end
    else
        if not req.nots or N.Layer.key(req.nots[1]) == mine then return "same", "same" end
        for i = 2, #req.nots do if N.Layer.key(req.nots[i]) == mine then return "drop" end end
    end
    if own.raid ~= false then return "busy", heard(name, own, "-") end   -- unreadable counts as a raid
    local members = own.members or {}
    for k, at in pairs(st.pending) do if now - at >= G.PENDING then st.pending[k] = nil end end
    if #members > 0 then
        if own.leader ~= true then return "busy", heard(name, own, "-") end
        for _, m in ipairs(members) do local mk = short(m); if not mk or not st.hosted[mk] then return "busy", heard(name, own, "-") end end
    end
    local pending = 0; for _ in pairs(st.pending) do pending = pending + 1 end
    if 1 + #members + pending >= 5 then return "busy", heard(name, own, "-") end
    if own.asking then return "busy", heard(name, own, "-") end
    if st.lastInvite and now - st.lastInvite < G.EVERY and now >= st.lastInvite then return "busy", heard(name, own, "-") end
    local recent = {}
    for _, at in ipairs(st.invites) do if now - at < G.WINDOW then recent[#recent + 1] = at end end
    st.invites = recent
    if #recent >= G.CAP then return "busy", heard(name, own, "-") end
    st.lastInvite = now; recent[#recent + 1] = now; st.pending[key] = now; st.hosted[key] = true
    return "invite", heard(name, own, "h")
end
