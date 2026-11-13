-- The only file that sends addon messages. Two routes are allowed: a LayerSwap-format request whispered to one
-- player, and the LayerEnemies guild relay. Everything else is refused here, before the client is asked.
local _, N = ...
local S = N.Safe
local Wr = {}
N.Wire = Wr

Wr.ROUTES = { LayerSwap = { WHISPER = true }, LEGW1 = { GUILD = true } }

-- Guild relay budget: 5 messages, refilled at one every 2 seconds. The whisper route has none (Hop owns its cooldowns).
local CAP, REFILL = 5, 2
local bucket = { tokens = CAP, at = nil }
function Wr.budget(now)
    now = S.num(now)
    if not now then return false end
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
    local route = type(prefix) == "string" and Wr.ROUTES[prefix]
    if not (route and type(kind) == "string" and route[kind]) then return false, "blocked route" end
    if type(text) ~= "string" or #text < 1 or #text > 255 then return false, "bad text" end
    if kind == "WHISPER" then
        local I = N.Invite
        if not (I and I.name and I.name(target)) then return false, "bad text" end
    else
        target = nil
    end
    if prefix == "LEGW1" and not Wr.budget(S.num(S.call(GetTime))) then return false, "throttled" end
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
