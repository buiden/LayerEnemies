-- The only file that sends addon messages or makes party calls. Routes: LayerSwap-format whispers to one player (a
-- request, or a guild host's "same"/"heard" reply), the LayerEnemies guild relay, Bulo's one-letter guild question
-- "Q" (at most once per 60 s, from a click), and from 1.0 the War Effort and HeadHunter networks behind Net. The
-- party calls are Wr.invite (guild host), Wr.accept and Wr.leave (auto accept and leave after our own hop).
-- Everything else is refused here, before the client is asked. All budgets live here.
local _, N = ...
local S = N.Safe
local Wr = {}
N.Wire = Wr

-- Routes: kinds allowed and a text check per prefix. The live table is file-local; Wr.ROUTES is a copy of the kinds
-- for reading, and changing it changes nothing. A route with a net is also gated by Net (ship constant, switch,
-- consent, stand-down).
-- LFSw carries only the literal question; our own "L" line is never sent.
Wr.LFSW_TEXT, Wr.LFSW_EVERY = "Q", 60
local lfswAt = nil
-- LayerSwap whispers: the request line (GuildHost.parse grammar), "same", or "heard <name>|<d>-<d>|<d>|<h or ->".
-- Replies are limited to one per 6 s overall, stamped before the client is asked.
Wr.REPLY_EVERY = 6
local replyAt = nil
-- LEGW1 control lines (Relay.control): "F|1" and "H|1|<d>|<d>" only, each at most once per 60 s
Wr.CONTROL_EVERY = 60
local controlAt = {}
local function layerswapText(text)
    if text == "same" then return "reply" end
    local name = text:match("^heard ([^|]+)|%d+%-%d+|%d+|[h%-]$")
    if name then return N.Invite.name(name) and "reply" or nil end
    local G = N.GuildHost
    if text:sub(1, 10) == "inv layer " and G and G.parse(text) then return "request" end
    return nil
end
local function legw1Text(text)
    local c = (text:sub(1, 2) == "F|" or text:sub(1, 2) == "H|") and text:sub(1, 1)
    if c and not (text == "F|1" or text:match("^H|1|%d+|%d+$")) then return nil end
    return c or "line"
end
-- War Effort (WEFF1): the type letter, then "|" or the end. Types per kind, from the 1.0 plan section 7; each lane
-- narrows its own grammar further.
local WE_TYPES = { GUILD = "HQCEKDG", PARTY = "HQCEK", RAID = "HQCEK", WHISPER = "PW" }
local function weText(text, kind)
    local t = text:match("^(%u)|") or text:match("^(%u)$")
    return t and WE_TYPES[kind] and WE_TYPES[kind]:find(t, 1, true) and t or nil
end
-- HeadHunter: "1" (protocol version), our faction A or H, a type we may send, ":" and a nonempty body. We never
-- author P, L or D.
local function hhText(text)
    return text:match("^1[AH]([NEQOSH]):.+$")
end
local ROUTES = {
    LayerSwap = { kinds = { WHISPER = true }, check = layerswapText },
    LEGW1 = { kinds = { GUILD = true }, check = legw1Text },
    LFSw = { kinds = { GUILD = true }, check = function(text) return text == Wr.LFSW_TEXT and "q" or nil end },
    WEFF1 = { kinds = { GUILD = true, PARTY = true, RAID = true, WHISPER = true }, check = weText, net = "we" },
    HeadHunter = { kinds = { WHISPER = true }, check = hhText, net = "hh" },
}
Wr.ROUTES = {}
for prefix, r in pairs(ROUTES) do Wr.ROUTES[prefix] = {}; for k in pairs(r.kinds) do Wr.ROUTES[prefix][k] = true end end

-- Budgets (1.0 plan 4.3), all spent before the client is asked:
--   each prefix 5 at once, then 1 per 2 s; all sends 8 at once, then 1 per 1.5 s and never more than 40 in 60 s;
--   GUILD 20 in 60 s over all prefixes; public whispers 20 in 60 s in total and 4 in 60 s to one player.
--   In combat a send costs double. In an instance only clicks go. A client throttle (3 or 8) pauses that prefix
--   30 s and the line is dropped; an offline target (12) is skipped for an hour.
Wr.PRIO = { click = 1, own = 2, owed = 3, forward = 4 }
Wr.QUEUE_MAX, Wr.PAUSE, Wr.OFFLINE = 40, 30, 3600
local PREFIX_CAP, PREFIX_REFILL, ALL_CAP, ALL_REFILL, ALL_MINUTE = 5, 2, 8, 1.5, 40
local GUILD_MINUTE, PUBLIC_MINUTE, PUBLIC_ONE = 20, 20, 4
local buckets, all = {}, { tokens = ALL_CAP, at = nil }
local allTimes, guildTimes, publicTimes, publicTo = {}, {}, {}, {}
local paused, offline = {}, {}
local queue, seq, pumping = {}, 0, false

local function refill(b, cap, every, now)
    -- a clock that goes backwards refills nothing, and the bucket then counts from the earlier time
    if b.at then b.tokens = math.min(cap, b.tokens + math.max(0, now - b.at) / every) end
    b.at = now
end
local function recent(list, now)
    local out = {}
    for _, at in ipairs(list) do if now - at < 60 and now >= at then out[#out + 1] = at end end
    return out
end
local function inCombat()
    local a, b = S.call(InCombatLockdown), S.call(UnitAffectingCombat, "player")
    return a == true or b == true
end
-- room(prefix, kind, target, public, now) -> ok: every budget has room for one send
local function room(prefix, kind, target, public, now, cost)
    local b = buckets[prefix] or { tokens = PREFIX_CAP, at = nil }
    buckets[prefix] = b
    refill(b, PREFIX_CAP, PREFIX_REFILL, now); refill(all, ALL_CAP, ALL_REFILL, now)
    if b.tokens < cost or all.tokens < cost then return false end
    allTimes = recent(allTimes, now)
    if #allTimes >= ALL_MINUTE then return false end
    if kind == "GUILD" then guildTimes = recent(guildTimes, now); if #guildTimes >= GUILD_MINUTE then return false end end
    if public then
        publicTimes = recent(publicTimes, now)
        if #publicTimes >= PUBLIC_MINUTE then return false end
        publicTo[target] = recent(publicTo[target] or {}, now)
        if #publicTo[target] >= PUBLIC_ONE then return false end
    end
    return true
end
local function spend(prefix, kind, target, public, now, cost)
    buckets[prefix].tokens = buckets[prefix].tokens - cost
    all.tokens = all.tokens - cost
    allTimes[#allTimes + 1] = now
    if kind == "GUILD" then guildTimes[#guildTimes + 1] = now end
    if public then publicTimes[#publicTimes + 1] = now; local l = publicTo[target]; l[#l + 1] = now end
end

local enqueue
-- check(prefix, text, kind, target, opts) -> route, extras | nil, why: everything but budgets and the client
local function check(prefix, text, kind, target, opts)
    if S.secret(prefix) or S.secret(text) or S.secret(kind) or S.secret(target) then return nil, "bad text" end
    local route = type(prefix) == "string" and ROUTES[prefix]
    if not (route and type(kind) == "string" and route.kinds[kind]) then return nil, "blocked route" end
    if type(text) ~= "string" or #text < 1 or #text > 255 then return nil, "bad text" end
    local tag = route.check(text, kind)
    if not tag then return nil, "bad text" end
    if kind == "WHISPER" then
        local I = N.Invite
        if not (I and I.name and I.name(target)) then return nil, "bad text" end
    else
        target = nil
    end
    opts = S.tab(opts) and opts or {}
    if route.net then
        if opts.net ~= route.net then return nil, "network off" end
        local ok, why = N.Net.allowed(route.net, opts.scope)
        if not ok then return nil, why end
    end
    return route, tag, target, opts
end
-- the client call and its result
local function deliver(prefix, text, kind, target, now)
    local CI = _G.C_ChatInfo
    if S.secret(CI) or type(CI) ~= "table" then return false, "error" end
    local okFn, fn = pcall(function() return CI.SendAddonMessage end)
    if not okFn or type(fn) ~= "function" then return false, "error" end
    local ok, result = pcall(fn, prefix, text, kind, target)
    if not ok then return false, "error" end
    if S.secret(result) then return false, "refused" end
    if result == 0 or result == true then return true, "sent" end   -- (true: older clients return a boolean)
    if result == 3 or result == 8 then if now then paused[prefix] = now + Wr.PAUSE end; return false, "throttled" end
    if result == 12 and target and now then offline[target] = now; return false, "offline" end
    return false, "refused"
end

-- send(prefix, text, kind, target[, opts]) -> ok, why
-- opts: net (required on a network route), scope ("guild" or "public"), prio ("click", "own", "owed", "forward";
-- default "forward"), queue (wait for budget instead of refusing).
-- why: "sent", "queued", "blocked route", "bad text", "network off", "stand down", "no consent", "instance",
-- "paused", "offline", "throttled", "queue full", "refused" or "error". "sent" means the client took the message,
-- not that it was delivered.
local function sendNow(prefix, text, kind, target, opts, fromQueue)
    local route, tag
    route, tag, target, opts = check(prefix, text, kind, target, opts)
    if not route then return false, tag end
    local now = S.num(S.call(GetTime))
    if not now then return false, "error" end
    local prio = Wr.PRIO[opts.prio] or Wr.PRIO.forward
    if S.call(IsInInstance) ~= false and prio ~= Wr.PRIO.click then return false, "instance" end
    if paused[prefix] and now < paused[prefix] then return false, "paused" end
    if target and offline[target] and now - offline[target] < Wr.OFFLINE and now >= offline[target] then return false, "offline" end
    local public = kind == "WHISPER" and opts.scope == "public"
    local cost = inCombat() and 2 or 1
    if not room(prefix, kind, target, public, now, cost) then
        if opts.queue and not fromQueue then return enqueue(prefix, text, kind, target, opts, prio) end
        return false, "throttled"
    end
    -- route limits, stamped before the client is asked (a refused send still waits)
    if prefix == "LFSw" then
        if lfswAt and now - lfswAt < Wr.LFSW_EVERY and now >= lfswAt then return false, "throttled" end
        lfswAt = now
    end
    if prefix == "LEGW1" and (tag == "F" or tag == "H") then
        local last = controlAt[tag]
        if last and now - last < Wr.CONTROL_EVERY and now >= last then return false, "throttled" end
        controlAt[tag] = now
    end
    if prefix == "LayerSwap" and tag == "reply" then
        if replyAt and now - replyAt < Wr.REPLY_EVERY and now >= replyAt then return false, "throttled" end
        replyAt = now
    end
    spend(prefix, kind, target, public, now, cost)
    return deliver(prefix, text, kind, target, now)
end
function Wr.send(prefix, text, kind, target, opts) return sendNow(prefix, text, kind, target, opts, false) end

-- The queue: at most 40 lines, sent in priority order (then oldest first) as budget allows. Full: the oldest forward
-- makes room for a newer line; with no forward queued, the new line is refused.
local pump
enqueue = function(prefix, text, kind, target, opts, prio)
    if #queue >= Wr.QUEUE_MAX then
        local drop
        for i, q in ipairs(queue) do
            if q.prio == Wr.PRIO.forward and (not drop or q.seq < queue[drop].seq) then drop = i end
        end
        if not drop then return false, "queue full" end
        table.remove(queue, drop)
    end
    seq = seq + 1
    queue[#queue + 1] = { prefix = prefix, text = text, kind = kind, target = target, opts = opts, prio = prio, seq = seq }
    if not pumping then
        local T = _G.C_Timer
        if S.tab(T) and type(T.After) == "function" then pumping = pcall(T.After, 0.5, pump) == true end
    end
    return true, "queued"
end
pump = function()
    pumping = false
    table.sort(queue, function(a, b) if a.prio ~= b.prio then return a.prio < b.prio end return a.seq < b.seq end)
    while queue[1] do
        local q = queue[1]
        local ok, why = sendNow(q.prefix, q.text, q.kind, q.target, q.opts, true)
        if not ok and why == "throttled" and not paused[q.prefix] then break end   -- no room yet: wait
        table.remove(queue, 1)                                                     -- sent, or refused for good
    end
    if queue[1] then
        local T = _G.C_Timer
        if S.tab(T) and type(T.After) == "function" then pumping = pcall(T.After, 0.5, pump) == true end
    end
end
function Wr.queued() return #queue end
function Wr.isQueued(text) for _, q in ipairs(queue) do if q.text == text then return true end end return false end

-- The guild host's invite. Limits of its own, whatever the caller checked, spent before the client is asked:
-- 10 s between calls, at most 6 per 600 s, one per name per 60 s. The name passed is the part before a realm suffix.
Wr.INVITE_EVERY, Wr.INVITE_CAP, Wr.INVITE_WINDOW, Wr.INVITE_NAME = 10, 6, 600, 60
local invite = { at = nil, recent = {}, names = {} }
local INVITE, LEAVE = "InviteUnit", "LeaveParty"
local function partyCall(name)
    local P = _G.C_PartyInfo
    if S.secret(P) or type(P) ~= "table" then return nil end
    local ok, fn = pcall(function() return P[name] end)
    if ok and type(fn) == "function" then return fn end
end
function Wr.canInvite() return partyCall(INVITE) ~= nil end
-- invite(name, now) -> ok, why: "invited", "bad name", "throttled" or "error"
function Wr.invite(name, now)
    if S.secret(name) or S.secret(now) then return false, "bad name" end
    local I = N.Invite
    name = S.str(name, 100)
    local short = name and (name:match("^([^%-]+)%-") or name)
    local valid, key = nil, nil
    if short then valid, key = I.name(short) end
    if not valid then return false, "bad name" end
    now = S.num(now)
    if not now then return false, "throttled" end
    if invite.at and now - invite.at < Wr.INVITE_EVERY and now >= invite.at then return false, "throttled" end
    local last = invite.names[key]
    if last and now - last < Wr.INVITE_NAME and now >= last then return false, "throttled" end
    local recent = {}
    for _, at in ipairs(invite.recent) do if now - at < Wr.INVITE_WINDOW and now >= at then recent[#recent + 1] = at end end
    invite.recent = recent
    if #recent >= Wr.INVITE_CAP then return false, "throttled" end
    for k, at in pairs(invite.names) do if now - at >= Wr.INVITE_NAME then invite.names[k] = nil end end
    invite.at, invite.names[key] = now, now
    recent[#recent + 1] = now
    local fn = partyCall(INVITE)
    if not fn then return false, "error" end
    if not pcall(fn, valid) then return false, "error" end
    return true, "invited"
end

-- Auto accept and leave (Main.partyInvite / Main.autoTick decide who and when). Each at most once per 10 s here,
-- stamped before the client is asked.
Wr.PARTY_EVERY = 10
local acceptAt, leaveAt = nil, nil
local function spaced(last, now) return last and now - last < Wr.PARTY_EVERY and now >= last end
-- accept(now) -> ok, why
function Wr.accept(now)
    now = S.num(now)
    if not now or spaced(acceptAt, now) then return false, "throttled" end
    acceptAt = now
    local fn = _G.AcceptGroup
    if S.secret(fn) or type(fn) ~= "function" or not pcall(fn) then return false, "error" end
    return true, "accepted"
end
-- The client's PARTY_INVITE popup declines in its OnHide unless inviteAccepted is set: mark it, then hide it. Never
-- hides a popup it could not mark.
function Wr.hideInvite()
    local find, hide = _G.StaticPopup_FindVisible, _G.StaticPopup_Hide
    if type(find) ~= "function" or type(hide) ~= "function" then return false end
    local ok, dialog = pcall(find, "PARTY_INVITE")
    if not ok or S.secret(dialog) or type(dialog) ~= "table" then return false end
    if not pcall(function() dialog.inviteAccepted = 1 end) then return false end
    return pcall(hide, "PARTY_INVITE") == true
end
-- leave(now) -> ok, why
function Wr.leave(now)
    now = S.num(now)
    if not now or spaced(leaveAt, now) then return false, "throttled" end
    leaveAt = now
    local fn = partyCall(LEAVE)
    if not fn or not pcall(fn) then return false, "error" end
    return true, "left"
end
