-- Guild relay (LEGW1): War Effort and HeadHunter records that reached us on PARTY, RAID or WHISPER, where the rest of
-- the guild cannot hear them, are passed on to the guild once. Received copies are stored as src "guild" with the
-- claimed source as a label, never as first-hand records, and are never relayed again.
local _, N = ...
local S = N.Safe
local Rl = {}
N.Relay = Rl
Rl.VERSION, Rl.MEMORY, Rl.MAX, Rl.PENDING = "1", 120, 256, 128
Rl.TTL = { we = 600, hh = 300 }                                 -- a relayed copy lives as long as a direct one
Rl.rand = function() return 0.5 + math.random() * 2 end       -- 0.5..2.5 s wait before sending

local SRC = { we = true, hh = true }
local KIND = { group = true, fight = true, outlaw = true }
local NS = { server = "s", zoneuid = "z", unknown = "u" }
local NSBACK = { s = "server", z = "zoneuid", u = "unknown" }
local CLASSES = { WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, PRIEST = true, DEATHKNIGHT = true, SHAMAN = true,
    MAGE = true, WARLOCK = true, MONK = true, DRUID = true, DEMONHUNTER = true, EVOKER = true }

local function hex(s) return (s:gsub(".", function(c) return string.format("%02x", c:byte()) end)) end
local function unhex(h)
    if type(h) ~= "string" or #h < 4 or #h > 200 or #h % 2 ~= 0 or not h:match("^%x+$") then return nil end
    local s = h:gsub("%x%x", function(b) return string.char(tonumber(b, 16)) end)
    if #s < 2 or #s > 100 or s:find("[%c|]") then return nil end
    return s
end
local function int(s, lo, hi)
    if type(s) ~= "string" or #s < 1 or #s > 10 or not s:match("^%-?%d+$") then return nil end
    local n = tonumber(s); if n and n >= lo and n <= hi then return n end
end

-- The first-hand id a record stands for: a relayed copy counts as the same report as the original.
function Rl.key(record)
    return (record.label or record.src) .. ":" .. record.origin:lower() .. ":" .. record.rid
end

-- encode(record, now) -> "R|1|src|kind|originHex|rid|zone|x3|y3|count|ns|layer|age|enemies" or nil
function Rl.encode(record, now)
    if not S.tab(record) or not SRC[record.src] or not KIND[record.kind] or not S.num(now) then return nil end
    local rid = record.rid
    if type(rid) ~= "string" or not rid:match("^[%w:%-]+$") then return nil end
    local function c3(v) return v and tostring(math.min(999, math.max(0, math.floor(v * 1000)))) or "" end
    local layer = record.layer and record.layer.value
    layer = layer ~= nil and tostring(layer) or ""
    local ns = NS[record.layer.ns]
    if record.src == "hh" then ns, layer = "u", "" end            -- HeadHunter never carries a usable layer
    if not layer:match("^[%w%-]*$") or #layer > 32 then return nil end
    local age = math.max(0, math.floor(now - record.heard)) + (record.age or 0)
    if age > 900 then return nil end                             -- too old for any receiver
    local head = table.concat({ "R", Rl.VERSION, record.src, record.kind, hex(record.origin), rid, tostring(record.zone),
        c3(record.x), c3(record.y), record.count and tostring(record.count) or "", ns, layer, tostring(age) }, "|") .. "|"
    if #head > 255 then return nil end
    local items = {}
    local used = #head
    for _, e in ipairs(record.enemies or {}) do
        local id = e.hash or (e.name and hex(e.name))
        if id then
            local item = id .. ":" .. (e.class or "") .. ":" .. (e.level and tostring(e.level) or "")
            local extra = #item + (#items > 0 and 1 or 0)
            if used + extra > 255 then break end
            items[#items + 1] = item; used = used + extra
        end
    end
    return head .. table.concat(items, ",")
end

-- decode(text, sender, now) -> record (src "guild", label = claimed src) | nil, reason
function Rl.decode(text, sender, now)
    if S.secret(text) or type(text) ~= "string" or #text < 1 or #text > 255 then return nil, "invalid" end
    if text:find("[^%w|%.:,%-?/]") then return nil, "invalid" end
    local f = {}
    for v in (text .. "|"):gmatch("([^|]*)|") do f[#f + 1] = v end
    if f[1] ~= "R" then return nil, "invalid" end
    if f[2] ~= Rl.VERSION then return nil, "version" end
    if #f ~= 14 then return nil, "invalid" end
    local src, kind, origin, rid = f[3], f[4], unhex(f[5]), f[6]
    if not SRC[src] or not KIND[kind] or not origin or not rid:match("^[%w:%-]+$") then return nil, "invalid" end
    -- a copy naming its own sender as the origin is not a relay (as War Effort refuses its own wrapped origin)
    local function bare(n) return (n:match("^([^%-]+)") or n):lower() end
    if type(sender) == "string" and (origin:lower() == sender:lower()
        or ((not origin:find("-", 1, true) or not sender:find("-", 1, true)) and bare(origin) == bare(sender))) then
        return nil, "origin is sender"
    end
    local zone = int(f[7], 1, 999999)
    local function c3(s) if s == "" then return nil, true end local n = int(s, 0, 999); return n and n / 1000, n ~= nil end
    local x, okx = c3(f[8]); local y, oky = c3(f[9])
    local count = f[10] ~= "" and int(f[10], 0, 80) or nil
    local ns = NSBACK[f[11]]
    if src == "hh" and ns ~= "unknown" then return nil, "invalid" end   -- HeadHunter never carries a usable layer
    local age = int(f[13], 0, 900)
    if age and age >= (Rl.TTL[src] or 0) then return nil, "too old" end
    if not (zone and okx and oky and (f[10] == "" or count) and ns and age) then return nil, "invalid" end
    local value = f[12] ~= "" and f[12] or nil
    if ns == "zoneuid" then value = value and tonumber(value) end
    local enemies = {}
    if f[14] ~= "" then
        for item in (f[14] .. ","):gmatch("([^,]*),") do
            local id, class, level = item:match("^([%w]+):([%u]*):([%-%d]*)$")
            if not id or #enemies >= 80 then return nil, "invalid" end
            if level ~= "" and not level:match("^%-?%d+$") then return nil, "invalid" end
            local e = { class = CLASSES[class] and class or nil, level = level ~= "" and tonumber(level) or nil }
            if #id == 3 then e.hash = id else e.name = unhex(id); if not e.name then return nil, "invalid" end end
            if e.level and (e.level < -1 or e.level > 100 or e.level == 0) then return nil, "invalid" end
            enemies[#enemies + 1] = e
        end
    end
    local record, why = N.Record.new({ src = "guild", kind = kind, origin = origin, via = sender, route = "GUILD", rid = rid,
        zone = zone, x = x, y = y, count = count, enemies = enemies, layer = { ns = ns, value = value },
        heard = now - age, share = "guild", label = src })
    if not record then return nil, "record: " .. tostring(why) end
    return record
end

Rl.RATE = 12                                                   -- LEGW1 messages per sender per 10 s
function Rl.new() return { seen = {}, n = 0, pending = {}, rates = {}, nrates = 0 } end
-- Receive limit per guildmate; excess is dropped silently. 512 senders at most.
function Rl.allow(st, sender, now)
    local k = tostring(sender):lower()
    local v = st.rates[k]
    if not v or now - v.at >= 10 then
        if not v then
            if st.nrates >= 512 then
                for key, w in pairs(st.rates) do if now - w.at >= 10 then st.rates[key] = nil; st.nrates = st.nrates - 1 end end
            end
            if st.nrates >= 512 then return false end
            st.nrates = st.nrates + 1
        end
        v = { at = now, n = 0 }; st.rates[k] = v
    end
    if v.n >= Rl.RATE then return false end
    v.n = v.n + 1
    return true
end
local function remember(st, key, now)
    for k, at in pairs(st.seen) do if now - at >= Rl.MEMORY then st.seen[k] = nil; st.n = st.n - 1 end end
    if not st.seen[key] then
        if st.n >= Rl.MAX then
            local oldest, ok
            for k, at in pairs(st.seen) do if not oldest or at < oldest then oldest, ok = at, k end end
            st.seen[ok] = nil; st.n = st.n - 1
        end
        st.n = st.n + 1
    end
    st.seen[key] = now
end
function Rl.seen(st, key, now) local at = st.seen[key]; return at ~= nil and now - at < Rl.MEMORY end

-- offer(st, record, now, ctx) -> true when a send is scheduled. ctx: inGuild, inInstance (both readable booleans).
function Rl.offer(st, record, now, ctx)
    if not S.tab(record) or not SRC[record.src] then return false, "source" end
    if record.route ~= "PARTY" and record.route ~= "RAID" and record.route ~= "WHISPER" then return false, "route" end
    if record.share == "guild" then return false, "guild share" end
    if ctx.inGuild ~= true or ctx.inInstance ~= false or type(ctx.guild) ~= "string" then return false, "not here" end
    local key = Rl.key(record)
    if Rl.seen(st, key, now) then return false, "seen" end
    local n = 0; for _ in pairs(st.pending) do n = n + 1 end
    if n >= Rl.PENDING then return false, "busy" end
    remember(st, key, now)
    st.pending[key] = { record = record, due = now + Rl.rand(), guild = ctx.guild }
    return true
end
-- A LEGW1 copy heard from a guildmate: remembered, and our own pending send of it stands down.
function Rl.heard(st, record, now)
    local key = Rl.key(record)
    st.pending[key] = nil
    remember(st, key, now)
end
-- tick(st, now, ctx) sends every due record once; a full bucket drops it (no queue). -> list of {key, ok, why}
-- ctx as for offer, read again now: left the guild, another guild, or an instance (or unreadable) drops it.
function Rl.tick(st, now, ctx)
    local out = {}
    ctx = S.tab(ctx) and ctx or {}
    for key, p in pairs(st.pending) do
        if now >= p.due then
            st.pending[key] = nil
            local text, ok, why = nil, false, "not here"
            if ctx.inGuild == true and ctx.inInstance == false and ctx.guild == p.guild then
                text = Rl.encode(p.record, now); why = "does not fit"
            end
            if text then ok, why = N.Wire.send("LEGW1", text, "GUILD", nil, { prio = "forward" }) end
            out[#out + 1] = { key = key, ok = ok, why = why }
        end
    end
    return out
end
function Rl.clear(st) S.clear(st.pending) end

-- Finding a LayerEnemies guild host (0.4.0): two control lines on LEGW1/GUILD, outside the "R" format, so a 0.3.x
-- decoder drops them as invalid.
--   F|1                  "which LayerEnemies hosts are on?", from the Find hosts click only
--   H|1|<key>|<zone>     a host's answer: our server key and uiMapID; once on enabling and once per F (60 s)
function Rl.findLine() return "F|1" end
function Rl.hostLine(key, zone)
    key = N.Layer.key(key); zone = S.num(zone)
    if not key or not zone or zone < 1 or zone > 999999 or zone % 1 ~= 0 then return nil end
    return "H|1|" .. key .. "|" .. string.format("%d", zone)
end
-- control(text) -> {kind = "F"} | {kind = "H", key, zone} | nil
function Rl.control(text)
    if S.secret(text) or type(text) ~= "string" or #text > 64 then return nil end
    if text == "F|1" then return { kind = "F" } end
    local key, zone = text:match("^H|1|(%d+)|(%d+)$")
    if not key or #key > 15 then return nil end
    zone = int(zone, 1, 999999)
    if not zone or not N.Layer.key(key) then return nil end
    return { kind = "H", key = N.Layer.key(key), zone = zone }
end
