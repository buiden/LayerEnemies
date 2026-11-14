-- The only file that sends addon messages or invites. Three routes are allowed: LayerSwap-format whispers to one
-- player (a request, or a guild host's "same"/"heard" reply), the LayerEnemies guild relay, and Bulo's one-letter
-- guild question "Q" (at most once per 60 s, from a click). The one party call is Wr.invite, for the guild host.
-- Everything else is refused here, before the client is asked.
local _, N = ...
local S = N.Safe
local Wr = {}
N.Wire = Wr

-- The live allowlist is file-local; Wr.ROUTES is a copy for reading, and changing it changes nothing.
local ROUTES = { LayerSwap = { WHISPER = true }, LEGW1 = { GUILD = true }, LFSw = { GUILD = true } }
Wr.ROUTES = { LayerSwap = { WHISPER = true }, LEGW1 = { GUILD = true }, LFSw = { GUILD = true } }
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

-- Guild relay budget: 5 messages, refilled at one every 2 seconds. The whisper route has none (Hop owns its cooldowns).
local CAP, REFILL = 5, 2
local bucket = { tokens = CAP, at = nil }
function Wr.budget(now)
    now = S.num(now)
    if not now then return false end
    -- a clock that goes backwards refills nothing (the max), and the bucket then counts from the earlier time
    if bucket.at then bucket.tokens = math.min(CAP, bucket.tokens + math.max(0, now - bucket.at) / REFILL) end
    bucket.at = now
    if bucket.tokens < 1 then return false end
    bucket.tokens = bucket.tokens - 1
    return true
end

-- send(prefix, text, kind, target) -> ok, why
-- why: "sent", "blocked route", "bad text", "throttled", "refused" or "error". "sent" means the client took the
-- message, not that it was delivered.
function Wr.send(prefix, text, kind, target)
    if S.secret(prefix) or S.secret(text) or S.secret(kind) or S.secret(target) then return false, "bad text" end
    local route = type(prefix) == "string" and ROUTES[prefix]
    if not (route and type(kind) == "string" and route[kind]) then return false, "blocked route" end
    if type(text) ~= "string" or #text < 1 or #text > 255 then return false, "bad text" end
    if prefix == "LFSw" and text ~= Wr.LFSW_TEXT then return false, "bad text" end
    local control = prefix == "LEGW1" and (text:sub(1, 2) == "F|" or text:sub(1, 2) == "H|") and text:sub(1, 1)
    if control and not (text == "F|1" or text:match("^H|1|%d+|%d+$")) then return false, "bad text" end
    local lsKind = prefix == "LayerSwap" and layerswapText(text)
    if prefix == "LayerSwap" and not lsKind then return false, "bad text" end
    if kind == "WHISPER" then
        local I = N.Invite
        if not (I and I.name and I.name(target)) then return false, "bad text" end
    else
        target = nil
    end
    -- the token is spent before the client is asked: a refused or erroring send still uses it
    if prefix == "LEGW1" and not Wr.budget(S.num(S.call(GetTime))) then return false, "throttled" end
    -- one LFSw question per 60 s, stamped before the client is asked (a refused send still waits)
    if prefix == "LFSw" then
        local now = S.num(S.call(GetTime))
        if not now or (lfswAt and now - lfswAt < Wr.LFSW_EVERY and now >= lfswAt) then return false, "throttled" end
        lfswAt = now
    end
    if control then
        local now, last = S.num(S.call(GetTime)), controlAt[control]
        if not now or (last and now - last < Wr.CONTROL_EVERY and now >= last) then return false, "throttled" end
        controlAt[control] = now
    end
    if lsKind == "reply" then
        local now = S.num(S.call(GetTime))
        if not now or (replyAt and now - replyAt < Wr.REPLY_EVERY and now >= replyAt) then return false, "throttled" end
        replyAt = now
    end
    local CI = _G.C_ChatInfo
    if S.secret(CI) or type(CI) ~= "table" then return false, "error" end
    local okFn, fn = pcall(function() return CI.SendAddonMessage end)
    if not okFn or type(fn) ~= "function" then return false, "error" end
    local ok, result = pcall(fn, prefix, text, kind, target)
    if not ok then return false, "error" end
    if S.secret(result) then return false, "refused" end
    if result == 0 or result == true then return true, "sent" end   -- (true: older clients return a boolean)
    if result == 3 then return false, "throttled" end
    return false, "refused"
end

-- The guild host's invite. Limits of its own, whatever the caller checked, spent before the client is asked:
-- 10 s between calls, at most 6 per 600 s, one per name per 60 s. The name passed is the part before a realm suffix.
Wr.INVITE_EVERY, Wr.INVITE_CAP, Wr.INVITE_WINDOW, Wr.INVITE_NAME = 10, 6, 600, 60
local invite = { at = nil, recent = {}, names = {} }
local function partyCall()
    local P = _G.C_PartyInfo
    if S.secret(P) or type(P) ~= "table" then return nil end
    local ok, fn = pcall(function() return P.InviteUnit end)
    if ok and type(fn) == "function" then return fn end
end
function Wr.canInvite() return partyCall() ~= nil end
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
    local fn = partyCall()
    if not fn then return false, "error" end
    if not pcall(fn, valid) then return false, "error" end
    return true, "invited"
end
