-- Independent reader for HeadHunter 1.1.1 battle pings (P) and outlaw sightings (L), direct or inside one E
-- envelope. Written from the documented grammar; nothing is copied. Pure: no sends, no SavedVariables.
-- We never send on this prefix, never join HeadHunterSync and never answer N.
local _, N = ...
local S = N.Safe
local HH = {}
N.HeadHunter = HH
HH.WINDOW, HH.MAX, HH.TTL, HH.RATE = 300, 64, 300, 6
HH.classes = { W = "WARRIOR", P = "PALADIN", H = "HUNTER", R = "ROGUE", I = "PRIEST", S = "SHAMAN", M = "MAGE",
    L = "WARLOCK", D = "DRUID" }

-- Lower-case base36, 1..10 digits.
local function b36(s)
    if type(s) ~= "string" or #s < 1 or #s > 10 or not s:match("^[0-9a-z]+$") then return nil end
    return tonumber(s, 36)
end
HH.b36 = b36
-- Coordinate: base36 0..999 -> /1000; empty is unknown (nil, ok); anything else fails.
local function coord(s)
    if s == "" then return nil, true end
    local n = b36(s)
    if not n or n > 999 then return nil, false end
    return n / 1000, true
end
-- Fields on ";" keeping empties.
local function fields(s)
    local f = {}
    for v in (s .. ";"):gmatch("([^;]*);") do f[#f + 1] = v end
    return f
end
-- A player key or given name: 2..80 bytes, no controls and none of | : ; , ~ /
local function key(s)
    if type(s) ~= "string" or #s < 2 or #s > 80 or s:find("[%c|:;,~/]") then return nil end
    return s
end
HH.key = key
local function faction(f)
    if f == "A" or f == "Alliance" then return "A" end
    if f == "H" or f == "Horde" then return "H" end
end

-- P: mapID;t;x;y;idList[;names;layer]  -> fields table or nil
local function P(f)
    if #f ~= 5 and #f ~= 7 then return nil end
    local map, t = b36(f[1]), b36(f[2])
    local x, okx = coord(f[3]); local y, oky = coord(f[4])
    if not (map and map > 0 and t and okx and oky) then return nil end
    local enemies, allies = 0, 0
    if f[5] ~= "" then
        for id in (f[5] .. ","):gmatch("([^,]*),") do
            local ally, short = id:match("^(%+?)(%w+)$")
            if not short or #short > 16 then return nil end
            if ally == "+" then allies = allies + 1 else enemies = enemies + 1 end
            if enemies > 12 or allies > 12 then return nil end
        end
    end
    local named = {}
    if #f == 7 and f[6] ~= "" then
        for item in (f[6] .. ","):gmatch("([^,]*),") do
            local name, code, level = item:match("^([^/]*)/([^/]*)/([^/]*)$")
            name = key(name)
            if not name or #named >= 3 then return nil end
            local lvl
            if level == "s" then lvl = -1
            elseif level ~= "" then
                if not level:match("^%d%d?%d?$") then return nil end
                lvl = tonumber(level); if lvl < 1 or lvl > 100 then return nil end
            end
            if code ~= "" and not HH.classes[code] then return nil end
            named[#named + 1] = { name = name, class = HH.classes[code], level = lvl }
        end
    end
    local layer
    if #f == 7 and f[7] ~= "" then
        layer = b36(f[7]); if not layer or layer < 1 then return nil end
    end
    return { type = "P", map = map, t = t, x = x, y = y, count = enemies, enemies = named, layer = layer }
end
-- L: outlawId;mapID;t;x;y
local function L(f)
    if #f ~= 5 then return nil end
    local outlaw = f[1]
    local guid = outlaw:match("^guid:(.+)$")
    if guid then
        if #outlaw > 120 or outlaw:find("[%c|;~]") then return nil end
    elseif not key(outlaw) then return nil end
    local map, t = b36(f[2]), b36(f[3])
    local x, okx = coord(f[4]); local y, oky = coord(f[5])
    if not (map and map > 0 and t and okx and oky) then return nil end
    return { type = "L", outlaw = outlaw, named = not guid, map = map, t = t, x = x, y = y }
end

-- decode(text, sender, serverNow, ownFaction, ctx) -> {records} (possibly empty), why
-- ctx: {heard = GetTime() at receipt, route = chat type, zoneFn = uiMapID -> zone (identity when absent)}.
function HH.decode(text, sender, serverNow, ownFaction, ctx)
    local out = {}
    ctx = S.tab(ctx) and ctx or {}
    if S.secret(text) or type(text) ~= "string" or #text > 255 then return out, "invalid" end
    sender = S.str(sender, 100); serverNow = S.num(serverNow); ownFaction = faction(ownFaction)
    if not sender or not serverNow or not ownFaction then return out, "unavailable" end
    local version, side, kind, body = text:match("^(%d)([AH])(%u):(.+)$")
    if not version then return out, "invalid" end
    if version ~= "1" then return out, "version" end
    if kind ~= "P" and kind ~= "L" and kind ~= "E" then return out, "ignored" end
    local why = "none"
    for rec in (body .. "~"):gmatch("([^~]*)~") do
        local origin, side2, inner, innerKind = sender, side, rec, kind
        if kind == "E" then
            local w, author, f2, server, hops, first, rest = rec:match("^([^;]*);([^;]*);([^;]*);([^;]*);([^;]*);([^;]*);(.+)$")
            innerKind = rest and rest:sub(1, 1)
            if not (rest and key(author) and (f2 == "A" or f2 == "H")) then innerKind = nil end
            -- envelope fields: world 1..40 bytes without controls, server lower-case 1..10 ("0" is unknown),
            -- hops base36 1..5, firstSent base36 up to 10 digits; anything else drops the record
            local h = b36(hops)
            if innerKind and not (#w >= 1 and #w <= 40 and not w:find("%c") and server:match("^[0-9a-z]+$") and #server <= 10
                and h and h >= 1 and h <= 5 and b36(first)) then innerKind = nil end
            origin, side2, inner = author, f2, rest and rest:sub(2)
        end
        local d
        if innerKind == "P" then d = P(fields(inner)) elseif innerKind == "L" then d = L(fields(inner)) end
        if not d then
            why = (innerKind == "P" or innerKind == "L") and "invalid" or (kind == "E" and innerKind and "ignored" or "invalid")
        elseif side2 ~= ownFaction then why = "other faction"
        elseif serverNow - d.t > HH.WINDOW or d.t - serverNow > HH.WINDOW then why = "stale"
        else
            local zone = ctx.zoneFn and ctx.zoneFn(d.map) or (not ctx.zoneFn and d.map) or nil
            local t = {
                src = "hh", origin = origin, via = sender, route = ctx.route, zone = zone, x = d.x, y = d.y,
                heard = ctx.heard, age = math.max(0, math.floor(serverNow - d.t)), share = "public",
            }
            if d.type == "P" then
                t.kind = "fight"; t.rid = tostring(d.t); t.count = d.count; t.enemies = d.enemies
                t.layer = d.layer and { ns = "zoneuid", value = d.layer } or { ns = "unknown" }
            else
                t.kind = "outlaw"; t.rid = N.Hash.hash3(d.outlaw:lower()) .. ":" .. d.t; t.count = 1
                t.enemies = d.named and { { name = d.outlaw } } or {}
                t.layer = { ns = "unknown" }
            end
            local r, bad
            if zone then r, bad = N.Record.new(t) end
            if r then out[#out + 1] = r; why = "ok" else why = zone and ("record: " .. tostring(bad)) or "zone unknown" end
        end
    end
    return out, why
end

-- Receive state: 6 frames per sender per 10 s.
function HH.new() return { rates = {}, n = 0 } end
function HH.allow(st, sender, now)
    local k = tostring(sender):lower()
    for key2, v in pairs(st.rates) do if now - v.at >= 10 then st.rates[key2] = nil; st.n = st.n - 1 end end
    local v = st.rates[k]
    if not v then
        if st.n >= 512 then return false end
        v = { at = now, n = 0 }; st.rates[k] = v; st.n = st.n + 1
    end
    if v.n >= HH.RATE then return false end
    v.n = v.n + 1
    return true
end
