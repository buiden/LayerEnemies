-- One-click hop: one LayerSwap-format request, whispered once per click to one player known to stand on the wanted
-- server key in our zone. LayerSwap and Bulo hosts both read it. We never retry, never fan out, never answer requests.
local _, N = ...
local S = N.Safe
local Hp = {}
N.Hop = Hp
Hp.REPLY = 120                                                 -- seconds a reply from the asked player is read

-- line(zone, server, uid, x, y) -> "inv layer <LS <zone> want <server>-<uid>[ <x>,<y>]>"
-- x, y: our own map position as fractions 0..1 (sent as percent with one decimal), omitted when unknown.
function Hp.line(zone, server, uid, x, y)
    zone, x, y = S.num(zone), S.num(x), S.num(y)
    server = N.Layer.key(server)
    uid = S.num(uid) or 0
    if not zone or zone < 1 or zone % 1 ~= 0 or not server or uid < 0 or uid % 1 ~= 0 then return nil end
    local pos = ""
    if x and y and x >= 0 and x <= 1 and y >= 0 and y <= 1 then pos = string.format(" %.1f,%.1f", x * 100, y * 100) end
    return string.format("inv layer <LS %d want %s-%d%s>", zone, server, uid, pos)
end

-- reply(text, sender, me) -> {kind="heard", layer?, zone?, hosting} | {kind="same"} | nil
-- heard is used only when its first field is our own full name.
function Hp.reply(text, sender, me)
    if S.secret(text) or type(text) ~= "string" or #text > 255 or not S.str(sender, 100) then return nil end
    if text == "same" then return { kind = "same" } end
    local who, layer, zone, host = text:match("^heard (.-)|([^|]*)|([^|]*)|([^|]*)$")
    if not who or not me or who ~= me then return nil end
    -- malformed fields make the reply unreadable, not "unknown"
    if not (layer == "-" or layer:match("^%d+%-%d+$")) or not (zone == "-" or zone:match("^%d+$")) or (host ~= "h" and host ~= "-") then return nil end
    return { kind = "heard", layer = layer ~= "-" and layer or nil, zone = zone ~= "-" and tonumber(zone) or nil, hosting = host == "h" }
end

function Hp.new() return { pending = nil } end
function Hp.clear(st) st.pending = nil end

-- The candidate for a record: one player known to stand on the record's server key, in this order: a Bulo guild
-- line with the host flag, a LayerSwap book entry, a Bulo guild line without it, the War Effort origin itself.
-- list: Invite.collect output. Returns {name, short, uid?, source, addon=true|false} or nil.
function Hp.candidate(record, list)
    local key = record and record.layer and record.layer.ns == "server" and N.Layer.key(record.layer.value)
    if not key then return nil end
    local best, rank
    for _, c in ipairs(list or {}) do
        if c.layer == key and not c.same then
            local r
            -- each source ranks by its own host flag: a Bulo non-host who is also a LayerSwap host ranks as LayerSwap
            for _, src in ipairs(c.sources or {}) do
                local v = src == "Bulo" and (c.hosts and c.hosts.Bulo and 1 or 3) or src == "LayerSwap" and 2 or nil
                if v and (not r or v < r) then r = v end
            end
            if r and (not rank or r < rank or (r == rank and c.age < best.age)) then best, rank = c, r end
        end
    end
    if best then
        local src = rank == 2 and "LayerSwap" or "Bulo"
        return { name = best.name, short = best.short, uid = best.uid, source = src, addon = true }
    end
    if record.src == "we" then
        local name, short = N.Invite.name(record.origin)
        if name then return { name = name, short = short, source = "War Effort reporter", addon = false } end
    end
end

-- request(st, record, candidate, ctx) -> ok, message[, line]
-- ctx: now, grouped, own = {zone, server, ambiguous}, invite (Invite state, for the shared cooldowns and the join
-- watch), x, y (own position or nil). An addon candidate gets the whisper through Wire; a War Effort reporter
-- without a host addon gets nothing sent: the caller opens the prefilled chat whisper instead.
-- The preconditions, each with its own message; nothing is reserved or sent. zoneName: optional uiMapID -> text.
function Hp.check(record, candidate, ctx)
    if ctx.grouped then return false, "leave your current group first; an invite cannot reach you while grouped." end
    if not S.tab(record) then return false, "nothing to hop to." end
    -- the live map zone decides: unreadable or different from the report refuses (the cached zone can lag)
    if not ctx.zone or not ctx.own.zone then return false, "your zone is not known." end
    if record.zone ~= ctx.zone or record.zone ~= ctx.own.zone then
        return false, "travel to " .. (ctx.zoneName and ctx.zoneName(record.zone) or tostring(record.zone)) .. " first."
    end
    if not record.layer or record.layer.ns ~= "server" then return false, "this report's layer cannot be compared with yours." end
    if N.Record.relation(record, ctx.own) == "same" then return false, "that report is on your layer already." end
    if not candidate then return false, "no one known on that layer to ask." end
    return true
end
function Hp.request(st, record, candidate, ctx)
    local I = N.Invite
    local fine, reason = Hp.check(record, candidate, ctx)
    if not fine then return false, reason end
    local ok, why = I.reserve(ctx.invite, candidate, ctx.now)
    if not ok then return false, why end
    ctx.invite.pending = { name = candidate.name, target = N.Layer.key(record.layer.value), from = ctx.own.server, at = ctx.now }
    if not candidate.addon then return true, "whisper", I.line(candidate.name) end
    local line = Hp.line(record.zone, record.layer.value, candidate.uid, ctx.x, ctx.y)
    if not line then return false, "the request could not be built." end
    local sent, result = N.Wire.send("LayerSwap", line, "WHISPER", candidate.name)
    if not sent then
        ctx.invite.pending = nil
        return false, result == "throttled" and "the client is throttling whispers; not sent. Click again later."
            or result == "refused" and "the client refused the whisper; not sent."
            or "the whisper could not be sent."
    end
    st.pending = { name = candidate.name, short = candidate.short, at = ctx.now, layer = N.Layer.key(record.layer.value) }
    return true, "sent", line
end

-- A LayerSwap-prefix message from the asked player within 120 s -> text to show, or nil.
function Hp.receive(st, text, sender, me, now, ambiguous)
    local p = st.pending
    if not p then return nil end
    if now - p.at > Hp.REPLY then st.pending = nil; return nil end
    -- the whole name, realm included: Alice-OtherRealm is not the Alice we asked
    local _, key = N.Invite.name(sender)
    if not key or key ~= p.short then return nil end
    local r = Hp.reply(text, sender, me)
    if not r then return nil end
    if r.kind == "same" then return p.name .. " says you're on their layer" .. (ambiguous and " (probably: your key is ambiguous)." or ".") end
    return p.name .. " heard you (layer " .. (r.layer or "unknown") .. ", hosting: " .. (r.hosting and "yes" or "no") .. ")."
end
