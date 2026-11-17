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
-- Own-death K1 lines: one per 120 s and at most five per rolling 30 minutes, including client refusals.
local K_EVERY, K_CAP, K_WINDOW = 120, 5, 1800
local deathAt, deathTimes = nil, {}
local function layerswapText(text)
    if text == "same" then return "reply" end
    local name = text:match("^heard ([^|]+)|%d+%-%d+|%d+|[h%-]$")
    if name then return N.Invite.name(name) and "reply" or nil end
    -- Unconstrained requests are only the hop-any unknown-host fallback, not a new GuildHost input grammar.
    local zone, x, y = text:match("^inv layer <LS (%d+) (%d+%.%d),(%d+%.%d)>$")
    if zone and #zone <= 9 and tonumber(zone) > 0 and tonumber(x) <= 100 and tonumber(y) <= 100 then return "fallback" end
    local G = N.GuildHost
    if text:sub(1, 10) == "inv layer " and G and G.parse(text) then return "request" end
    return nil
end
local function legw1Text(text)
    if text:sub(1, 2) == "K|" then return N.OwnDeath.decode(text) and "K" or nil end
    -- our own sighting line (lane A1): its whole grammar, nothing else after "O|"
    if text:sub(1, 2) == "O|" then
        return text:match("^O|1|%d+|%d+|[01]?%.?%d*|[01]?%.?%d*|%d*|%d+|%d+|[%x:%u%d,%-]*$") and "O" or nil
    end
    local c = (text:sub(1, 2) == "F|" or text:sub(1, 2) == "H|") and text:sub(1, 1)
    if c and not (text == "F|1" or text:match("^H|1|%d+|%d+$")) then return nil end
    return c or "line"
end
-- War Effort (WEFF1): the type letter, then "|" or the end. Types per kind, from the 1.0 plan section 7; each lane
-- narrows its own grammar further.
local WE_TYPES = { GUILD = "HQCEKDG", PARTY = "HQCEK", RAID = "HQCEK", WHISPER = "PWCEK" }
local function weText(text, kind)
    local t = text:match("^(%u)|") or text:match("^(%u)$")
    if not (t and WE_TYPES[kind] and WE_TYPES[kind]:find(t, 1, true)) then return nil end
    -- Q is bare; by whisper (lane A2) a C only as a sync answer (marker i:n, n at most 3) and a K only saying "off"
    if t == "Q" then return text == "Q" and t or nil end
    if kind == "WHISPER" then
        if t == "K" then return text:match("^K|%d+|2|%d+$") and t or nil end
        if t == "C" then
            local i, n = text:match("^C|[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|[^|]*|([1-3]):([1-3])$")
            return i and tonumber(i) <= tonumber(n) and t or nil
        end
    end
    return t
end
-- HeadHunter: "1" (protocol version), our faction A or H, a type we may send, ":" and a nonempty body. We never
-- author P, L or D.
local function hhText(text)
    return text:match("^1[AH]([NEQOSH]):.+$")
end
local function flhText(text,kind)
    local m=N.FLH.decode(text)
    if not m then return nil end
    if m.cmd=="HI" then return kind~="WHISPER" and m.host==0 and m.cmd or nil end
    return kind=="WHISPER" and (m.cmd=="WR" or m.cmd=="CA" or m.cmd=="WP" or m.cmd=="LQ" or m.cmd=="LR")
        and (m.host==nil or m.host==0) and m.cmd or nil
end
local ROUTES = {
    FLHNET2 = { kinds = { GUILD = true, PARTY = true, RAID = true, WHISPER = true }, check = flhText },
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
--   In combat a send costs double and every minute cap is halved. In an instance only clicks go. A clock that steps
--   back counts as "just sent": nothing refills and nothing leaves a window. A client throttle (3 or 8) pauses that prefix
--   30 s and the line is dropped; an offline target (12) is skipped for an hour.
-- click > own (our sightings, hello) > owed (host H, answers) > embassy and guild relay (forward) > mesh (HeadHunter
-- forwards, hellos and catch-up), last. Lines from embassy down may not spend the reserve: they leave at least
-- RESERVE_TOKENS in the shared bucket and RESERVE_MINUTE (GUILD: RESERVE_GUILD) of each minute cap (halved in combat),
-- so our own lines are never starved by a busy mesh.
Wr.PRIO = { click = 1, own = 2, owed = 3, embassy = 4, forward = 4, catchup = 5, mesh = 6 }
Wr.RESERVE_TOKENS, Wr.RESERVE_MINUTE, Wr.RESERVE_GUILD = 2, 10, 5
-- a catch-up pull's frames (opts.catchup) have their own allowance per requester instead of the 4 a minute: 16
-- frames per 300 s, still inside the public budget
Wr.CATCHUP_FRAMES, Wr.CATCHUP_WINDOW = 16, 300
local catchupTo = {}
Wr.QUEUE_MAX, Wr.PAUSE, Wr.OFFLINE = 40, 30, 3600
local PREFIX_CAP, PREFIX_REFILL, ALL_CAP, ALL_REFILL, ALL_MINUTE = 5, 2, 8, 1.5, 40
local GUILD_MINUTE, PUBLIC_MINUTE, PUBLIC_ONE = 20, 20, 4
local buckets, all = {}, { tokens = ALL_CAP, at = nil }
local allTimes, guildTimes, publicTimes, publicTo = {}, {}, {}, {}
local paused, offline = {}, {}
local queue, seq, pumping = {}, 0, false
-- Explicit hop-any requests alone use a separate bucket; named hops/replies and every other prefix keep
-- all their existing caps. No Wire queue: HopAny owns cancellation and retries at its next round.
Wr.HOP_CAP, Wr.HOP_REFILL, Wr.HOP_MINUTE, Wr.HOP_ONE, Wr.HOP_PAUSE = 8, 1, 60, 4, 1
local hopBucket, hopTimes, hopTo, hopPause = { tokens = Wr.HOP_CAP }, {}, {}, nil
-- A non-hop LayerSwap throttle ends every click begun before its pause expires.
-- Retain the boundary so a delayed pump cannot resume that click after 30 s.
local hopStop
function Wr.hopBlocked(at)
    at = S.num(at)
    return at and hopStop and at < hopStop or false
end

local function refill(b, cap, every, now)
    -- a clock that goes backwards refills nothing, and the bucket keeps counting from the later time
    if b.at and now <= b.at then return end
    if b.at then b.tokens = math.min(cap, b.tokens + (now - b.at) / every) end
    b.at = now
end
-- the stamps of the last 60 s; a stamp later than now (the clock stepped back) still counts
local function recent(list, now)
    local out = {}
    for _, at in ipairs(list) do if now - at < 60 then out[#out + 1] = at end end
    return out
end
-- one player, one key (Invite.name: case, and our realm, do not make another player)
local function who(target) local _, key = N.Invite.name(target); return key end
-- Correlation is session-only, metadata-only and bounded. A local refusal/queued line is NOT an actual whisper.
Wr.RECENT_WINDOW, Wr.RECENT_MAX = 30, 64
local whispers = {}
local function pruneWhispers(now)
    local keep = {}
    for _, r in ipairs(whispers) do
        if now >= r.at and now - r.at < Wr.RECENT_WINDOW then keep[#keep + 1] = r end
    end
    whispers = keep
end
local function rememberWhisper(target, key, now)
    if not key then return end
    pruneWhispers(now)
    if #whispers >= Wr.RECENT_MAX then table.remove(whispers, 1) end
    whispers[#whispers + 1] = { target = target, key = key, at = now }
end
local OFFLINE_MAX = 256
-- Shared by the synchronous TargetOffline result and correlated asynchronous system failures.
function Wr.markOffline(target, now)
    local key = who(target)
    now = S.num(now)
    if not key or not now then return nil end
    local n, oldest, okey = 0, nil, nil
    for k, at in pairs(offline) do
        if now - at >= Wr.OFFLINE then offline[k] = nil
        else n = n + 1; if not oldest or at < oldest then oldest, okey = at, k end end
    end
    if not offline[key] and n >= OFFLINE_MAX then offline[okey] = nil end
    offline[key] = now
    -- Consume once, but keep identities until their original expiry/cap for bare-name ambiguity checks.
    -- Duplicate errors cannot renew suppression or make a recent namesake look unambiguous.
    for _, r in ipairs(whispers) do if r.key == key then r.consumed = true end end
    return key
end
function Wr.offlineUntil(target, now, hopSeconds)
    local key = who(target)
    now = S.num(now)
    local at = key and offline[key]
    if not at or not now then return nil end
    if now - at >= Wr.OFFLINE then offline[key] = nil; return nil end
    if hopSeconds == 600 then return now - at < hopSeconds and at + hopSeconds or nil end
    return at + Wr.OFFLINE
end
-- Compile only a single %s (or %1$s) with literal text. Escape every Lua pattern character, interpret %% literally,
-- and fail closed on missing/unsupported formats. No English fallback, chat filter, or broad chat capture.
local template, failurePattern
local function localizedPattern()
    local raw = S.str(_G.ERR_CHAT_PLAYER_NOT_FOUND_S, 512)
    if raw == template then return failurePattern end
    template, failurePattern = raw, nil
    if not raw then return nil end
    local parts, captures, literals, i = {}, 0, 0, 1
    while i <= #raw do
        local c = raw:sub(i, i)
        if c == "%" then
            if raw:sub(i, i + 1) == "%%" then parts[#parts + 1] = "%%"; literals = literals + 1; i = i + 2
            elseif raw:sub(i, i + 1) == "%s" or raw:sub(i, i + 3) == "%1$s" then
                captures = captures + 1; parts[#parts + 1] = "(.-)"
                i = i + (raw:sub(i, i + 1) == "%s" and 2 or 4)
            else return nil end
        else
            parts[#parts + 1] = c:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
            literals = literals + 1; i = i + 1
        end
    end
    if captures == 1 and literals > 0 then failurePattern = "^" .. table.concat(parts) .. "$" end
    return failurePattern
end
function Wr.system(text)
    text = S.str(text, 512)
    local now = S.num(S.call(GetTime))
    if not text or not now then return nil end
    pruneWhispers(now)
    local pattern = localizedPattern()
    local name = pattern and text:match(pattern)
    local key = name and who(name)
    if not key then return nil end
    local match
    for _, r in ipairs(whispers) do
        -- A bare error cannot distinguish namesakes on different realms. Never guess a foreign realm from it,
        -- even if there is only one such attempt; surnames are never compacted here.
        if not name:find("-", 1, true) and (r.target:match("^([^%-]+)") or r.target):lower() == name:lower()
            and r.key ~= key then return nil end
        if r.key == key and not r.consumed then match = r end
    end
    if match then return Wr.markOffline(match.target, now) end
end
local function inCombat()
    local a, b = S.call(InCombatLockdown), S.call(UnitAffectingCombat, "player")
    return a == true or b == true
end
-- Read-only view of the actual rolling guild budget, across every prefix. Future
-- stamps still count after a clock rollback; inspecting never prunes or spends.
function Wr.guildMinute(now)
    now = S.num(now)
    if not now then return nil end
    local n = 0
    for _, at in ipairs(guildTimes) do if now - at < 60 then n = n + 1 end end
    return n, math.floor(GUILD_MINUTE / (inCombat() and 2 or 1))
end
-- room(prefix, kind, target, public, now, cost, low, catchup) -> ok: every budget has room for one send; low: a line
-- that may not spend the reserve; catchup: a pull's frame (its own allowance instead of the per-player cap)
local function room(prefix, kind, target, public, now, cost, low, catchup)
    local b = buckets[prefix] or { tokens = PREFIX_CAP, at = nil }
    buckets[prefix] = b
    refill(b, PREFIX_CAP, PREFIX_REFILL, now); refill(all, ALL_CAP, ALL_REFILL, now)
    if b.tokens < cost or all.tokens < cost + (low and Wr.RESERVE_TOKENS or 0) then return false end
    -- in combat (cost 2) every minute cap is halved
    local function cap(n) return math.floor(n / cost) end
    allTimes = recent(allTimes, now)
    if #allTimes >= cap(ALL_MINUTE) - (low and cap(Wr.RESERVE_MINUTE) or 0) then return false end
    if kind == "GUILD" then
        guildTimes = recent(guildTimes, now)
        if #guildTimes >= cap(GUILD_MINUTE) - (low and cap(Wr.RESERVE_GUILD) or 0) then return false end
    end
    if public then
        publicTimes = recent(publicTimes, now)
        if #publicTimes >= cap(PUBLIC_MINUTE) then return false end
        for k, l in pairs(publicTo) do l = recent(l, now); publicTo[k] = l[1] and l or nil end   -- pruned
        if catchup then
            local c = catchupTo[target]
            if c and (now < c.at or now - c.at >= Wr.CATCHUP_WINDOW) then c = nil; catchupTo[target] = nil end
            if c and c.n >= Wr.CATCHUP_FRAMES then return false end
        elseif #(publicTo[target] or {}) >= cap(PUBLIC_ONE) then return false end
    end
    return true
end
local function spend(prefix, kind, target, public, now, cost)
    buckets[prefix].tokens = buckets[prefix].tokens - cost
    all.tokens = all.tokens - cost
    allTimes[#allTimes + 1] = now
    if kind == "GUILD" then guildTimes[#guildTimes + 1] = now end
    if public then publicTimes[#publicTimes + 1] = now; local l = publicTo[target] or {}; l[#l + 1] = now; publicTo[target] = l end
end
local function spendCatchup(target, now)
    local c = catchupTo[target]
    if not c then
        local n = 0
        for k, v in pairs(catchupTo) do if now < v.at or now - v.at >= Wr.CATCHUP_WINDOW then catchupTo[k] = nil else n = n + 1 end end
        if n >= 256 then return end
        c = { at = now, n = 0 }; catchupTo[target] = c
    end
    c.n = c.n + 1
end

-- FLH membership is independent of the hop-any bucket. Whisper sends still
-- consume the existing 20/minute public ledger (even to a guildmate).
Wr.FLH_REPLIES, Wr.FLH_PROBES, Wr.FLH_GAP, Wr.FLH_NAME = 6, 4, 60, 600
local flhReplies, flhProbes, flhNames, flhHi = {}, {}, {}, {}
function Wr.flhProbeReady(target,now)
    local key=who(target)
    if not key or not S.num(now) then return false end
    local last=flhNames["probe:"..key]
    return #recent(flhProbes,now)<Wr.FLH_PROBES and #recent(publicTimes,now)<PUBLIC_MINUTE-Wr.FLH_REPLIES
        and not (last and now-last.at<Wr.FLH_NAME)
end
local function flhBudget(tag,kind,key,now)
    -- Membership shares the ordinary global ceilings, not an extra allowance.
    -- Probes yield first: keep six shared tokens/minute slots for owed answers.
    refill(all,ALL_CAP,ALL_REFILL,now); allTimes=recent(allTimes,now)
    local reserve=tag=="WP" and Wr.FLH_REPLIES or 0
    if all.tokens<1+reserve or #allTimes>=ALL_MINUTE-reserve then return false end
    flhReplies=recent(flhReplies,now); flhProbes=recent(flhProbes,now)
    for k,v in pairs(flhNames) do if now-v.at>=v.keep then flhNames[k]=nil end end
    publicTimes=recent(publicTimes,now); guildTimes=recent(guildTimes,now)
    if kind=="WHISPER" and #publicTimes>=PUBLIC_MINUTE then return false end
    for k,v in pairs(publicTo) do v=recent(v,now); publicTo[k]=v[1] and v or nil end
    if kind=="WHISPER" and #(publicTo[key] or {})>=PUBLIC_ONE then return false end
    if kind=="GUILD" and #guildTimes>=GUILD_MINUTE then return false end
    if tag=="WP" and not Wr.flhProbeReady(key,now) then return false end
    local owed=tag=="WR" or tag=="CA"
    local bucket=owed and flhReplies or flhProbes
    local rateKey=(owed and "reply:" or "probe:")..(key or "")
    local last=flhNames[rateKey]
    if owed or tag=="WP" then
        local cap=owed and Wr.FLH_REPLIES or Wr.FLH_PROBES
        if #bucket>=cap or (last and now-last.at<last.keep) or (not last and S.count(flhNames)>=64) then return false end
        bucket[#bucket+1]=now
        flhNames[rateKey]={at=now,keep=owed and Wr.FLH_GAP or Wr.FLH_NAME}
    elseif tag=="HI" then
        local lane=kind=="GUILD" and "GUILD" or "GROUP"
        if flhHi[lane] and now-flhHi[lane]<120 then return false end
        flhHi[lane]=now
    end
    if tag=="LQ" or tag=="LR" then
        refill(hopBucket,Wr.HOP_CAP,Wr.HOP_REFILL,now)
        hopTimes=recent(hopTimes,now)
        for k,v in pairs(hopTo) do v=recent(v,now); hopTo[k]=v[1] and v or nil end
        if hopBucket.tokens<1 or #hopTimes>=Wr.HOP_MINUTE or #(hopTo[key] or {})>=Wr.HOP_ONE then return false end
        hopBucket.tokens=hopBucket.tokens-1; hopTimes[#hopTimes+1]=now
        local list=hopTo[key] or {}; list[#list+1]=now; hopTo[key]=list
    end
    if kind=="WHISPER" then
        publicTimes[#publicTimes+1]=now
        local list=publicTo[key] or {}; list[#list+1]=now; publicTo[key]=list
    end
    all.tokens=all.tokens-1; allTimes[#allTimes+1]=now
    if kind=="GUILD" then guildTimes[#guildTimes+1]=now end
    return true
end
local enqueue
-- check(prefix, text, kind, target, opts) -> route, extras | nil, why: everything but budgets and the client
local function check(prefix, text, kind, target, opts)
    if S.secret(prefix) or S.secret(text) or S.secret(kind) or S.secret(target) then return nil, "bad text" end
    local route = type(prefix) == "string" and ROUTES[prefix]
    if not (route and type(kind) == "string" and route.kinds[kind]) then return nil, "blocked route" end
    if type(text) ~= "string" or #text < 1 or #text > 255 then return nil, "bad text" end
    -- K1 death payloads belong only to LEGW1, not the unrelated War Effort K type.
    if prefix ~= "LEGW1" and N.OwnDeath.decode(text) then return nil, "bad text" end
    local tag = route.check(text, kind)
    if not tag then return nil, "bad text" end
    if kind == "WHISPER" then
        local I = N.Invite
        local valid, _, canonical
        if I and I.name then valid, _, canonical = I.name(target) end
        if not valid then return nil, "bad text" end
        target = canonical
    else
        target = nil
    end
    opts = S.tab(opts) and opts or {}
    if prefix == "FLHNET2" then
        if not N.FLHMember or N.FLHMember.authorize(text,kind,target,opts)~=tag then return nil,"network off" end
        return route,tag,target,opts,kind=="WHISPER"
    end
    if tag == "fallback" and not (prefix == "LayerSwap" and opts.hopAny == true and opts.prio == "click") then return nil, "bad text" end
    -- a network whisper is public unless its target is a checked online guildmate (never the caller's word)
    local public = false
    -- the embassy's withdrawal "D|" to the guild goes even when the War Effort network is off or stood down (it
    -- takes back links we announced while it was on); nothing else does
    local withdraw = opts.withdraw == true and prefix == "WEFF1" and kind == "GUILD" and text == "D|"
    if route.net and not withdraw then
        if opts.net ~= route.net then return nil, "network off" end
        public = kind == "WHISPER" and not (N.Adapters and N.Adapters.guildMember(target) == true)
        local ok, why = N.Net.allowed(route.net, public and "public" or "guild")
        if not ok then return nil, why end
    end
    return route, tag, target, opts, public
end
-- the client call and its result; a third value true once the client was asked (whatever it answered)
local function deliver(prefix, text, kind, target, now, key, hop)
    local CI = _G.C_ChatInfo
    if S.secret(CI) or type(CI) ~= "table" then return false, "error" end
    local okFn, fn = pcall(function() return CI.SendAddonMessage end)
    if not okFn or type(fn) ~= "function" then return false, "error" end
    local ok, result = pcall(fn, prefix, text, kind, target)
    if kind == "WHISPER" then rememberWhisper(target, key, now) end
    if not ok then return false, "error", true end
    if S.secret(result) then return false, "refused", true end
    if result == 0 or result == true then return true, "sent", true end   -- (true: older clients return a boolean)
    if result == 3 or result == 8 then
        if now then
            paused[prefix] = now + Wr.PAUSE
            if hop then hopPause = now + Wr.HOP_PAUSE
            elseif prefix == "LayerSwap" then hopStop = now + Wr.PAUSE end
        end
        return false, "throttled", true
    end
    if result == 12 and key and now then
        Wr.markOffline(target, now)
        return false, "offline", true
    end
    return false, "refused", true
end

-- send(prefix, text, kind, target[, opts]) -> ok, why
-- opts: net (required on a network route), scope ("guild" or "public"), prio ("click", "own", "owed", "forward";
-- default "forward"), queue (wait for budget instead of refusing).
-- why: "sent", "queued", "blocked route", "bad text", "network off", "stand down", "no consent", "instance",
-- "paused", "offline", "throttled", "queue full", "refused" or "error". "sent" means the client took the message,
-- not that it was delivered.
local function sendNow(prefix, text, kind, target, opts, fromQueue)
    local route, tag, public
    route, tag, target, opts, public = check(prefix, text, kind, target, opts)
    if not route then return false, tag end
    local now = S.num(S.call(GetTime))
    if not now then return false, "error" end
    local prio = Wr.PRIO[opts.prio] or Wr.PRIO.forward
    local death = prefix == "LEGW1" and tag == "K"
    if death and (not N.Main.sharing() or S.call(IsInGuild) ~= true) then return false, "share off" end
    if S.call(IsInInstance) ~= false and (death or prio ~= Wr.PRIO.click) then return false, "instance" end
    local hop = opts.hopAny == true and opts.prio == "click" and prefix == "LayerSwap" and kind == "WHISPER" and (tag == "request" or tag == "fallback")
    if (hop and ((hopPause and now < hopPause) or Wr.hopBlocked(now)))
        or (not hop and paused[prefix] and now < paused[prefix]) then return false, "paused" end
    local key = target and who(target)
    if target and Wr.offlineUntil(target, now, hop and opts.hopKnown == true and 600 or nil) then return false, "offline" end
    if prefix == "FLHNET2" then
        if not flhBudget(tag,kind,key,now) then return false,"throttled" end
        return deliver(prefix,text,kind,target,now,key)
    end
    local cost = inCombat() and 2 or 1
    -- the reserve binds the lines that say they rank low (embassy, mesh); an unmarked line keeps the old rules
    local low = opts.prio == "embassy" or opts.prio == "catchup" or opts.prio == "mesh"
    local catchup = opts.catchup == true and prefix == "HeadHunter"
    if hop then
        refill(hopBucket, Wr.HOP_CAP, Wr.HOP_REFILL, now)
        hopTimes = recent(hopTimes, now)
        for k, v in pairs(hopTo) do v = recent(v, now); hopTo[k] = v[1] and v or nil end
        if hopBucket.tokens < cost or #hopTimes >= math.floor(Wr.HOP_MINUTE / cost)
            or #(hopTo[key] or {}) >= math.floor(Wr.HOP_ONE / cost) then return false, "throttled" end
        hopBucket.tokens = hopBucket.tokens - cost
        hopTimes[#hopTimes + 1] = now
        local list = hopTo[key] or {}; list[#list + 1] = now; hopTo[key] = list
        return deliver(prefix, text, kind, target, now, key, true)
    end
    if not room(prefix, kind, key, public, now, cost, low, catchup) then
        if opts.queue and not fromQueue and not death then return enqueue(prefix, text, kind, target, opts, prio) end
        return false, "throttled"
    end
    -- route limits, stamped before the client is asked (a refused send still waits)
    if prefix == "LFSw" then
        if lfswAt and (now < lfswAt or now - lfswAt < Wr.LFSW_EVERY) then return false, "throttled" end
        lfswAt = now
    end
    if death then
        if deathAt and (now < deathAt or now - deathAt < K_EVERY) then return false, "throttled" end
        local keep = {}
        for _, at in ipairs(deathTimes) do if now - at < K_WINDOW then keep[#keep + 1] = at end end
        deathTimes = keep
        if #deathTimes >= K_CAP then return false, "throttled" end
        deathAt = now; deathTimes[#deathTimes + 1] = now
    end
    if prefix == "LEGW1" and (tag == "F" or tag == "H") then
        local last = controlAt[tag]
        if last and (now < last or now - last < Wr.CONTROL_EVERY) then return false, "throttled" end
        controlAt[tag] = now
    end
    if prefix == "LayerSwap" and tag == "reply" then
        if replyAt and (now < replyAt or now - replyAt < Wr.REPLY_EVERY) then return false, "throttled" end
        replyAt = now
    end
    if catchup then
        -- a pull's frame counts in the public minute cap but not in the per-player one
        buckets[prefix].tokens = buckets[prefix].tokens - cost
        all.tokens = all.tokens - cost
        allTimes[#allTimes + 1] = now
        if public then publicTimes[#publicTimes + 1] = now end
        spendCatchup(key, now)
    else
        spend(prefix, kind, key, public, now, cost)
    end
    return deliver(prefix, text, kind, target, now, key)
end
function Wr.send(prefix, text, kind, target, opts) return sendNow(prefix, text, kind, target, opts, false) end

-- The queue: at most 40 lines, sent in priority order (then oldest first) as budget allows. Full: the oldest forward
-- makes room for a newer line; with no forward queued, the new line is refused.
local pump
enqueue = function(prefix, text, kind, target, opts, prio)
    if #queue >= Wr.QUEUE_MAX then
        -- the oldest line of the lowest priority present goes (mesh first, then embassy and relay lines)
        local drop
        for i, q in ipairs(queue) do
            if q.prio >= Wr.PRIO.embassy and (not drop or q.prio > queue[drop].prio or (q.prio == queue[drop].prio and q.seq < queue[drop].seq)) then drop = i end
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
        local ok, why
        -- a queued line whose caller says it no longer holds (opts.still) is dropped unsent
        local stillOk, still = true, true
        if type(q.opts.still) == "function" then stillOk, still = pcall(q.opts.still) end
        if not stillOk or not still then ok, why = false, "stale" else
            ok, why = sendNow(q.prefix, q.text, q.kind, q.target, q.opts, true)
        end
        if not ok and why == "throttled" and not paused[q.prefix] then break end   -- no room yet: wait
        table.remove(queue, 1)                                                     -- sent, or refused for good
    end
    if queue[1] then
        local T = _G.C_Timer
        if S.tab(T) and type(T.After) == "function" then pumping = pcall(T.After, 0.5, pump) == true end
    end
end
-- Battle.net keeps its sole queue/budget in BNet. The client function is acquired
-- there once; invocation stays in Wire's caller frame, with a final privacy check.
function Wr.bnet(net,id,prefix,text,prio,fn)
    if not N.BNet.allowed(net,id,prefix,text,prio) or S.secret(fn) or type(fn)~="function"
        or not N.BNet.dispatching(net,id,prefix,text,prio,fn) then return false end
    local ok,result=pcall(fn,id,prefix,text)
    return ok and not S.secret(result) and (result==0 or result==true)
end

function Wr.queued() return #queue end
function Wr.sizes() return N.Safe.count(publicTo), N.Safe.count(offline) end
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
    -- the player checked is the player invited: our realm dropped, any other realm kept (Invite.name)
    local valid, key, target = I.name(name)
    if not valid then return false, "bad name" end
    now = S.num(now)
    if not now then return false, "throttled" end
    if invite.at and (now < invite.at or now - invite.at < Wr.INVITE_EVERY) then return false, "throttled" end
    local last = invite.names[key]
    if last and (now < last or now - last < Wr.INVITE_NAME) then return false, "throttled" end
    local recent = {}
    for _, at in ipairs(invite.recent) do if now - at < Wr.INVITE_WINDOW then recent[#recent + 1] = at end end
    invite.recent = recent
    if #recent >= Wr.INVITE_CAP then return false, "throttled" end
    for k, at in pairs(invite.names) do if now - at >= Wr.INVITE_NAME then invite.names[k] = nil end end
    invite.at, invite.names[key] = now, now
    recent[#recent + 1] = now
    local fn = partyCall(INVITE)
    if not fn then return false, "error" end
    if not pcall(fn, target) then return false, "error" end
    return true, "invited"
end

-- Auto accept and leave (Main.partyInvite / Main.autoTick decide who and when). Each at most once per 10 s here,
-- stamped before the client is asked.
Wr.PARTY_EVERY = 10
local acceptAt, leaveAt = nil, nil
local function spaced(last, now) return last and (now < last or now - last < Wr.PARTY_EVERY) end
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
