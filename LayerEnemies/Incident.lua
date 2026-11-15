-- 1.0 lane C2: guild incident addons in, on GUILD only. PvP Guild Bounty Forever 1.1.3 ("GBOUNTY" D: the sender died
-- to this player), Wall of Shame Forever 0.5.0 ("WALLOFSHAME" D: the sender's own death and its killer) and Forever
-- Told ("FTold1" S: a wanted player seen). Written from the wire formats; no donor code copied (Wall of Shame's MIT
-- decoder was not used). Pure: decode only. Nothing is ever sent on these prefixes (they are not Wire routes).
local _, N = ...
local S = N.Safe
local Ic = {}
N.Incident = Ic
Ic.ROUTES = { GBOUNTY = { GUILD = true }, WALLOFSHAME = { GUILD = true }, FTold1 = { GUILD = true } }
Ic.SRC = { GBOUNTY = "gb", WALLOFSHAME = "wos", FTold1 = "ft" }
local CLASSES = { WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, PRIEST = true, DEATHKNIGHT = true, SHAMAN = true,
    MAGE = true, WARLOCK = true, MONK = true, DRUID = true, DEMONHUNTER = true, EVOKER = true }

local function fields(text, sep)
    local f = {}
    for v in (text .. sep):gmatch("([^" .. sep .. "]*)" .. sep) do f[#f + 1] = v; if #f > 12 then break end end
    return f
end
local function int(s, lo, hi)
    if type(s) ~= "string" or not s:match("^%d+$") or #s > 6 then return nil end
    local n = tonumber(s)
    return n >= lo and n <= hi and n or nil
end
local function percent(s)
    if type(s) ~= "string" or #s > 8 or not s:match("^%d+%.?%d*$") then return nil end
    local n = tonumber(s)
    return n and n >= 0 and n <= 100 and n / 100 or nil
end
local function zoneText(s) return type(s) == "string" and #s >= 1 and #s <= 70 and not s:find("[%c|~]") and s or nil end
local function level(s)
    if s == "" then return nil, true end
    local n = int(s, 1, 100)
    return n, n ~= nil
end

-- decode(prefix, text) -> { enemy = {name, class, level}, map | zoneName, x, y, kind } or nil, why
function Ic.decode(prefix, text)
    if S.secret(text) or type(text) ~= "string" or #text > 255 or not Ic.SRC[prefix] then return nil, "invalid" end
    if prefix == "GBOUNTY" then
        -- D|killer|mapID|x|y|subzone|level|raceID|class|guild; x and y are percent with one decimal
        local f = fields(text, "|")
        if f[1] ~= "D" then return nil, "ignored" end
        if #f ~= 10 then return nil, "invalid" end
        local name = N.Spy.name(f[2])
        if not name then return nil, "name" end
        local map = int(f[3], 1, 999999)
        if not map then return nil, "map" end
        local x, y
        if f[4] ~= "" or f[5] ~= "" then
            x, y = percent(f[4]), percent(f[5])
            if not x or not y then return nil, "position" end
        end
        local lvl, okL = level(f[7])
        if not okL then return nil, "level" end
        local class = f[9] ~= "" and f[9] or nil
        if class and not CLASSES[class] then return nil, "class" end
        return { kind = "death", enemy = { name = name, class = class, level = lvl }, map = map, x = x, y = y }
    elseif prefix == "WALLOFSHAME" then
        -- D|level|zone|class|deaths|killer|killer level|variant: the sender's own death; the killer as the game named
        -- it (a player, or a creature: both pass as a name; an environment key in capitals does not)
        local f = fields(text, "|")
        if f[1] ~= "D" then return nil, "ignored" end
        if #f ~= 8 then return nil, "invalid" end
        if f[6]:match("^[%u_]+$") then return nil, "environment" end
        local name = N.Spy.name(f[6])
        if not name then return nil, "name" end
        local zone = zoneText(f[3])
        local lvl, okL = level(f[7])
        if not zone or not okL then return nil, "invalid" end
        return { kind = "death", enemy = { name = name, level = lvl }, zoneName = zone }
    else
        -- S~name~where, where = "subzone, zone" or "zone"
        local f = fields(text, "~")
        if f[1] ~= "S" then return nil, "ignored" end
        if #f ~= 3 then return nil, "invalid" end
        local name = N.Spy.name(f[2])
        if not name then return nil, "name" end
        local zone = zoneText(f[3] and (f[3]:match(".*, (.+)$") or f[3]))
        if not zone then return nil, "invalid" end
        return { kind = "seen", enemy = { name = name }, zoneName = zone }
    end
end
-- record(prefix, d, ctx) -> record or nil, why; ctx = { sender, route, heard, zone, zoneMap }
-- Coordinates count only when they are the zone's own map (a child map's cannot be plotted on the zone).
function Ic.record(prefix, d, ctx)
    local x, y = d.x, d.y
    if d.map and d.map ~= ctx.zone then x, y = nil, nil end
    local hash = N.Hash.hash3(d.enemy.name:lower())
    return N.Record.new({ src = Ic.SRC[prefix], kind = d.kind, origin = ctx.sender, via = ctx.sender, route = ctx.route,
        rid = hash, zone = ctx.zone, x = x, y = y, count = 1,
        enemies = { { name = d.enemy.name, hash = hash, class = d.enemy.class, level = d.enemy.level } },
        layer = { ns = "unknown" }, heard = ctx.heard, age = 0, share = "guild", pos = x and "victim" or nil })
end
