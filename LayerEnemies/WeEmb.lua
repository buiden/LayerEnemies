-- War Effort embassy (1.0 lane A3; War Effort 1.6.6 protocol minor 19). Our guild's War Effort users link it with
-- players of other guilds found in the War Effort directory channel: names are split among guildmates by a score,
-- each greets its share (P, "answer me"), an answer makes a partner; a guildmate holds links to at most three foreign
-- guilds and says which (D); the best-scored holder of a guild forwards our guild's own reports to one partner there
-- (W); a W from a partner goes into our guild as a bridge (G). Written from the wire format and the documented
-- timings; the score is the wire's arithmetic (DJB2), no donor code copied. Pure: Main sends what it returns.
-- Stricter than War Effort: a guildmate's report is forwarded only if that guildmate's own hello said public = 1.
local _, N = ...
local S = N.Safe
local E = {}
N.WeEmb = E
E.MINOR = 19
E.GREET, E.GREET_JITTER, E.IDLE = 60, 30, 20     -- one greeting a minute (+0..30 s); nothing to greet: look again in 20 s
E.ANSWER_WAIT, E.SILENT = 30, 1800               -- a greeting unanswered after 30 s: that player is left alone 1800 s
E.PRESENCE, E.REGREET = 150, 10                  -- our presence to one player at most every 150 s (10 s: a partner who lost us)
E.PARTNER, E.KEEPALIVE = 600, 300                -- a partner heard within 600 s counts; ours to the partners we hold every 300 s
E.REPLIES = 6                                    -- answers to greetings a minute, for the whole client
E.ROWS_MAX, E.LINKS_MAX = 60, 3
E.LINKS_SECONDS, E.LINKS_REPEAT, E.LINKS_GAP = 1500, 600, 120
E.RATE, E.BURST = 0.2, 6                         -- forwards a second, and at once
E.HELLO, E.CANDIDATE = 600, 600
E.BRIDGE_PER_MINUTE, E.BRIDGE_HELLOS = 10, 6
E.HELD_MAX = 256                                 -- foreign guild keys remembered from guildmates' D lines
E.VOUCH = 600                                    -- a P counts from a channel member, or from someone we greeted this long ago

-- The election score: (hash(name) * (hash(key) % 1048573 + 1)) % 2147483647, hash = DJB2 mod 2147483647.
function E.hash(s)
    local h = 5381
    for i = 1, #s do h = (h * 33 + s:byte(i)) % 2147483647 end
    return h
end
function E.score(name, key) return (E.hash(name) * (E.hash(key) % 1048573 + 1)) % 2147483647 end
-- first(me, names, key): does key rank us (lower-case name) first among names? Highest score wins, ties the lower name.
function E.first(me, names, key)
    local own = E.score(me, key)
    for _, name in ipairs(names or {}) do
        local low = tostring(name):lower()
        if low ~= me then
            local s = E.score(low, key)
            if s > own or (s == own and low < me) then return false end
        end
    end
    return true
end

function E.new()
    return { rows = {}, held = {}, mine = {}, announced = nil, announcedAt = nil, tokens = E.BURST, tokensAt = nil,
        forwarded = {}, replies = { at = -1e9, count = 0 }, nextGreetAt = 0, bridged = {}, bridgeTimes = {},
        bridgeHellos = {}, bridgeHelloAt = {} }
end
local function low(name) return type(name) == "string" and name:lower() or "" end
local function keyOf(row)
    if type(row.guild) == "string" then return "g" .. row.guild end
    return "n" .. N.WeOut.hex(row.name):lower()
end
local function usable(row, now)
    return row.heardAt ~= nil and now >= row.heardAt and now - row.heardAt <= E.PARTNER and (row.minor or 0) >= E.MINOR
        and not row.guildmate
end
function E.partner(st, name, now) local row = st.rows[low(name)]; return row ~= nil and usable(row, now) end
local function row(st, name)
    local k = low(name)
    local r = st.rows[k]
    if not r then
        local n = 0
        for _ in pairs(st.rows) do n = n + 1 end
        if n >= E.ROWS_MAX then return nil end
        r = { name = name }
        st.rows[k] = r
    end
    return r
end
function E.prune(st, now)
    local n = 0
    for _ in pairs(st.rows) do n = n + 1 end
    if n >= E.ROWS_MAX then
        for k, r in pairs(st.rows) do
            if not usable(r, now) and (r.silentUntil or 0) < now and now - (r.presenceAt or -1e9) > E.SILENT then st.rows[k] = nil end
        end
    end
    for k, f in pairs(st.forwarded) do if now - (f.t or 0) > E.HELLO then st.forwarded[k] = nil end end
    for _, list in ipairs({ st.bridgeTimes, st.bridgeHellos }) do
        for i = #list, 1, -1 do if now - list[i] >= 60 or now < list[i] then table.remove(list, i) end end
    end
    for k, at in pairs(st.bridgeHelloAt) do if now - at >= E.HELLO then st.bridgeHelloAt[k] = nil end end
    -- held keys: expired holders go, and a key nobody holds any more is dropped
    for key, holders in pairs(st.held) do
        for k, h in pairs(holders) do if now - h.at > E.LINKS_SECONDS or now < h.at then holders[k] = nil end end
        if next(holders) == nil then st.held[key] = nil end
    end
    local nb = 0
    for _ in pairs(st.bridged) do nb = nb + 1 end
    if nb > 256 then st.bridged = {} end
    -- a greeting unanswered for 30 s: left alone
    for _, r in pairs(st.rows) do
        if r.greetedAt and now - r.greetedAt >= E.ANSWER_WAIT and not (r.heardAt and r.heardAt >= r.greetedAt) and not r.silenced then
            r.silentUntil, r.silenced = r.greetedAt + E.ANSWER_WAIT + E.SILENT, true
        end
    end
end

-- The guildmates holding a foreign guild (their D within 1500 s, still heard in the guild).
local function otherHolders(st, key, now, heardInGuild)
    local list = {}
    for k, h in pairs(st.held[key] or {}) do
        if now - h.at > E.LINKS_SECONDS then st.held[key][k] = nil
        elseif heardInGuild(h.name) then list[#list + 1] = h.name end
    end
    return list
end
-- holdings(st, now, ctx) -> the foreign guilds we have a partner in, fewest other holders first, at most three
function E.holdings(st, now, ctx)
    local keys, seen = {}, {}
    if ctx.why then return keys end
    for _, r in pairs(st.rows) do
        if usable(r, now) then local k = keyOf(r); if not seen[k] then seen[k] = true; keys[#keys + 1] = k end end
    end
    local count = {}
    for _, k in ipairs(keys) do count[k] = #otherHolders(st, k, now, ctx.heardInGuild) end
    table.sort(keys, function(a, b) if count[a] ~= count[b] then return count[a] < count[b] end return a < b end)
    while #keys > E.LINKS_MAX do keys[#keys] = nil end
    return keys
end
local function partnerFor(st, key, now)
    local best, bestScore
    for k, r in pairs(st.rows) do
        if usable(r, now) and keyOf(r) == key then
            local s = E.score(k, "pair|" .. key)
            if not best or s > bestScore or (s == bestScore and k < low(best.name)) then best, bestScore = r, s end
        end
    end
    return best
end
local function forwarder(st, key, now, ctx)
    return E.first(ctx.me, otherHolders(st, key, now, ctx.heardInGuild), "fwd|" .. key)
end

-- tick(st, now, ctx) -> list of { kind, target, text } to send.
--   ctx = { why (nil: the embassy runs), me (our lower name), members (directory list or nil), candidates (guildmates
--   who may hold embassies), isGuildmate(name), heardInGuild(name), guild (our guild id), rand }
function E.tick(st, now, ctx)
    local out = {}
    E.prune(st, now)
    if not ctx.why then
        -- greet one of our share
        if now >= st.nextGreetAt then
            local share = {}
            local members = ctx.members
            if type(members) == "table" then
                for _, name in ipairs(members) do
                    local r = st.rows[low(name)]
                    if not ctx.isGuildmate(name) and not (r and r.guildmate) and E.first(ctx.me, ctx.candidates, "greet|" .. low(name)) then
                        if not r or not (usable(r, now) or (r.silentUntil or 0) > now or now - (r.presenceAt or -1e9) < E.PRESENCE) then
                            share[#share + 1] = name
                        end
                    end
                end
            end
            if share[1] then
                local name = share[math.floor((ctx.rand or math.random)() * #share) + 1] or share[1]
                local r = row(st, name)
                if r then
                    out[#out + 1] = { kind = "WHISPER", target = name, text = N.WeOut.presence(ctx.guild, true) }
                    r.presenceAt, r.greetedAt, r.silenced = now, now, nil
                end
                st.nextGreetAt = now + E.GREET + math.floor((ctx.rand or math.random)() * (E.GREET_JITTER + 1))
            else
                st.nextGreetAt = now + E.IDLE
            end
        end
        -- keepalive to the partners we hold
        for _, key in ipairs(st.mine) do
            local r = partnerFor(st, key, now)
            if r and now - (r.presenceAt or -1e9) >= E.KEEPALIVE then
                out[#out + 1] = { kind = "WHISPER", target = r.name, text = N.WeOut.presence(ctx.guild, false) }
                r.presenceAt = now
            end
        end
    end
    -- our links: on a change, again every 600 s while we hold any, at least 120 s apart; "D|" once when none any more
    local keys = E.holdings(st, now, ctx)
    local text = N.WeOut.links(keys)
    local due = not (text == st.announced and (#keys == 0 or now - (st.announcedAt or 0) < E.LINKS_REPEAT))
    -- a withdrawal (none any more) goes at once; a change waits 120 s after the last D
    local gap = #keys > 0 and st.announcedAt and now - st.announcedAt < E.LINKS_GAP
    if due and not (#keys == 0 and (not st.announced or st.announced == "D|")) and not gap then
        out[#out + 1] = { kind = "GUILD", text = text, links = keys }
    end
    return out
end
-- announced(st, text, keys, now): Main tells us a D went out; a withdrawal ("D|") drops our partners, so a former
-- partner's W is no longer taken (they are partners again only after a new vouched presence)
function E.announced(st, text, keys, now)
    st.announced, st.announcedAt, st.mine = text, now, keys
    if #keys == 0 then E.withdraw(st) end
end
function E.withdraw(st)
    for _, r in pairs(st.rows) do r.heardAt = nil end
    st.mine, st.forwarded = {}, {}
end
-- seat(st, key, target, now, ctx): are we still the forwarder for key, and target still its partner? (a queued W
-- is dropped when not)
function E.seat(st, key, target, now, ctx)
    if ctx.why then return false end
    local held = false
    for _, k in ipairs(st.mine) do if k == key then held = true end end
    if not held or not forwarder(st, key, now, ctx) then return false end
    local r = partnerFor(st, key, now)
    return r ~= nil and low(r.name) == low(target)
end

-- presence(st, msg, sender, now, ctx) -> a reply { kind, target, text } or nil
function E.presence(st, msg, sender, now, ctx)
    -- only a player in the War Effort channel, one we greeted in the last 10 minutes, or a live partner: anyone else
    -- gets no reply and makes no partner
    local old = st.rows[low(sender)]
    local vouched = (ctx.inChannel and ctx.inChannel(sender)) or (old and old.greetedAt and now >= old.greetedAt
        and now - old.greetedAt <= E.VOUCH) or (old and usable(old, now))
    if not vouched then return nil end
    local r = row(st, sender)
    if not r then return nil end
    local was = usable(r, now)
    r.minor, r.guild, r.heardAt, r.silentUntil, r.silenced = msg.minor, msg.guild, now, nil, nil
    r.guildmate = (type(ctx.guild) == "string" and msg.guild == ctx.guild) or ctx.isGuildmate(sender) == true
    if r.guildmate or not msg.ask or ctx.why then return nil end
    if now - (r.presenceAt or -1e9) < (was and E.REGREET or E.PRESENCE) then return nil end
    if now - st.replies.at >= 60 or now < st.replies.at then st.replies.at, st.replies.count = now, 0 end
    if st.replies.count >= E.REPLIES then return nil end
    st.replies.count = st.replies.count + 1
    r.presenceAt = now
    return { kind = "WHISPER", target = sender, text = N.WeOut.presence(ctx.guild, false) }
end
-- links(st, msg, sender, now): a guildmate's D
function E.links(st, msg, sender, now)
    local k = low(sender)
    for key, holders in pairs(st.held) do holders[k] = nil; if next(holders) == nil then st.held[key] = nil end end
    local n = 0
    for _ in pairs(st.held) do n = n + 1 end
    for _, key in ipairs(msg.links) do
        if not st.held[key] and n < E.HELD_MAX then st.held[key] = {}; n = n + 1 end
        if st.held[key] then st.held[key][k] = { name = sender, at = now } end
    end
end

local function take(st, now)
    st.tokens = math.min(E.BURST, st.tokens + math.max(0, now - (st.tokensAt or now)) * E.RATE)
    st.tokensAt = now
    if st.tokens < 1 then return false end
    st.tokens = st.tokens - 1
    return true
end
-- forward(st, origin, msg, text, now, ctx) -> list of { kind = "WHISPER", target, text = W } for a guild member's own
-- C (not a sync answer, a new report id), its first E, or H (once per 600 s per partner); nothing else
function E.forward(st, origin, msg, text, now, ctx)
    local out = {}
    if ctx.why or #st.mine == 0 then return out end
    for _, key in ipairs(st.mine) do
        if forwarder(st, key, now, ctx) then
            local r = partnerFor(st, key, now)
            if r and low(r.name) ~= low(origin) then
                local k = low(origin) .. "|" .. low(r.name)
                local f = st.forwarded[k] or {}
                local go
                if msg.type == "H" then go = not (f.helloAt and now - f.helloAt < E.HELLO)
                elseif msg.type == "C" then go = not msg.sync and f.rid ~= msg.rid
                elseif msg.type == "E" then go = f.rid == msg.rid and not f.e end
                if go and take(st, now) then
                    local w = N.WeOut.wrap("W", origin, nil, N.WeOut.rebuild(msg))
                    if w then
                        st.forwarded[k] = f
                        if msg.type == "H" then f.helloAt = now elseif msg.type == "C" then f.rid, f.e = msg.rid, nil else f.e = true end
                        f.t = now
                        out[#out + 1] = { kind = "WHISPER", target = r.name, text = w, key = key }
                    end
                end
            end
        end
    end
    return out
end
-- bridge(st, msg, sender, now, ctx) -> G text for our guild, or nil, why. Only from a live partner of another guild;
-- never a wrapper naming us or its own sender; a report once; 10 sightings and 6 hellos a minute.
function E.bridge(st, msg, sender, now, ctx)
    if ctx.why then return nil, "embassy off" end
    local r = st.rows[low(sender)]
    if not r or not usable(r, now) then return nil, "not a partner" end
    if ctx.isMe(msg.origin) then return nil, "own echo" end
    local o, s = low(msg.origin), low(sender)
    local function bare(n) return (n:match("^([^%-]+)") or n) end
    if o == s or bare(o) == bare(s) then return nil, "wrapped by its own origin" end
    E.prune(st, now)
    local inner = msg.inner
    if inner.type == "H" then
        if st.bridgeHelloAt[o] then return nil, "hello bridged lately" end
        if #st.bridgeHellos >= E.BRIDGE_HELLOS then return nil, "bridge hellos a minute" end
        st.bridgeHelloAt[o] = now; st.bridgeHellos[#st.bridgeHellos + 1] = now
    elseif inner.type == "C" then
        if st.bridged[o] == inner.rid then return nil, "bridged already" end
        if #st.bridgeTimes >= E.BRIDGE_PER_MINUTE then return nil, "bridges a minute" end
        st.bridgeTimes[#st.bridgeTimes + 1] = now
        st.bridged[o] = inner.rid
    elseif inner.type ~= "E" or st.bridged[o] ~= inner.rid then
        return nil, "enemy list without its sighting"
    end
    return N.WeOut.wrap("G", msg.origin, nil, N.WeOut.rebuild(inner))
end
-- State for /le status
function E.summary(st, now)
    local partners = 0
    for _, r in pairs(st.rows) do if usable(r, now) then partners = partners + 1 end end
    return partners, #st.mine
end
