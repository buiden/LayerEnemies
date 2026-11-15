-- 1.0 lane C1: the Spy family in. Spy Forever 1.3.8 ("[Spy]", GUILD/PARTY/RAID), Forever Spy 0.15.1 ("ForeverSpy1",
-- PARTY/RAID) and Forever Sentinel PVP 0.6.3 ("FSENT03", PARTY/RAID). Each line means "the sender sees this enemy".
-- Written from the wire formats; no donor code copied. Pure: decode only; Main stores what it returns. Receive only:
-- nothing is sent on these prefixes.
local _, N = ...
local S = N.Safe
local Sp = {}
N.Spy = Sp
Sp.ROUTES = {
    ["[Spy]"] = { GUILD = true, PARTY = true, RAID = true },
    ForeverSpy1 = { PARTY = true, RAID = true },
    FSENT03 = { PARTY = true, RAID = true },
}
Sp.SRC = { ["[Spy]"] = "spy", ForeverSpy1 = "fspy", FSENT03 = "sent" }
local CLASSES = { WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, PRIEST = true, DEATHKNIGHT = true, SHAMAN = true,
    MAGE = true, WARLOCK = true, MONK = true, DRUID = true, DEMONHUNTER = true, EVOKER = true }

local function fields(text, sep)
    local f = {}
    for v in (text .. sep):gmatch("([^" .. sep .. "]*)" .. sep) do f[#f + 1] = v; if #f > 12 then break end end
    return f
end
-- name(raw): the enemy in our one name rule. Spy and Sentinel key a Forever player "First-Last" (the client hands the
-- surname where Classic had the realm), optionally followed by "-<realm>"; Forever Spy sends "First Last". A part
-- after a hyphen is a realm only when it is all digits (Forever realms are numeric).
local function realm(part) return part:match("^%d+$") ~= nil end
function Sp.name(raw)
    if type(raw) ~= "string" or raw == "" or #raw > 60 then return nil end
    if raw:find(" ", 1, true) then return (N.Invite.name(raw)) end
    local a, b, c = raw:match("^([^%-]+)%-([^%-]+)%-([^%-]+)$")
    if a then
        if not realm(c) then return nil end
        return (N.Invite.name(a .. " " .. b .. "-" .. c))
    end
    a, b = raw:match("^([^%-]+)%-([^%-]+)$")
    if a then
        if realm(b) then return (N.Invite.name(a .. "-" .. b)) end
        return (N.Invite.name(a .. " " .. b))
    end
    return (N.Invite.name(raw))
end
local function int(s, lo, hi)
    if type(s) ~= "string" or not s:match("^%-?%d+$") or #s > 6 then return nil end
    local n = tonumber(s)
    return n and n >= lo and n <= hi and n or nil
end
local function coord(s)
    if type(s) ~= "string" or #s > 12 or not s:match("^%d*%.?%d+$") then return nil end
    local n = tonumber(s)
    return n and n >= 0 and n <= 1 and n or nil
end
local function zoneText(s) return type(s) == "string" and #s >= 1 and #s <= 70 and not s:find("[%c|~]") and s or nil end

-- decode(prefix, text) -> { enemy = {name, class, level}, map | zoneName, x, y, age, key } or nil, why
-- map: a uiMapID (Spy's mapID, climbed to its zone by the caller); zoneName: a zone's display name (Forever Spy,
-- Sentinel), looked up by the caller.
function Sp.decode(prefix, text)
    if S.secret(text) or type(text) ~= "string" or #text > 255 or not Sp.SRC[prefix] then return nil, "invalid" end
    if prefix == "[Spy]" then
        -- AceComm splits a long line into parts marked by a first byte of 1 to 3; Spy's lines stay under 240 bytes,
        -- so a part is never parsed
        local first = text:byte(1)
        if not first or first <= 3 then return nil, "multi-part" end
        local f = fields(text, "|")
        if #f ~= 11 then return nil, "invalid" end
        local name = Sp.name(f[2])
        if not name then return nil, "name" end
        local class = f[3] ~= "" and f[3] or nil
        if class and not CLASSES[class] then return nil, "class" end
        local level = nil
        if f[4] ~= "" then level = int(f[4], 1, 100); if not level then return nil, "level" end end
        local x, y
        if f[8] ~= "" or f[9] ~= "" then
            x, y = coord(f[8]), coord(f[9])
            if not x or not y then return nil, "position" end
        end
        if #f[10] > 24 or f[10]:find("%c") then return nil, "guild" end
        local map = int(f[11], 1, 999999)
        if not map then return nil, "map" end
        return { enemy = { name = name, class = class, level = level }, map = map, x = x, y = y, age = 0 }
    elseif prefix == "ForeverSpy1" then
        local version, raw, zone = text:match("^(%d+)\t([^\t]+)\t([^\t]+)$")
        if version ~= "1" then return nil, "invalid" end
        -- Forever Spy sends the whole name with its space
        if raw:find("[%[%];%-]") or raw:find("^%s") or raw:find("%s$") then return nil, "name" end
        local name = N.Invite.name(raw)
        zone = zoneText(zone)
        if not name or not zone then return nil, "invalid" end
        return { enemy = { name = name }, zoneName = zone, age = 0 }
    else
        local f = fields(text, "~")
        if #f ~= 7 or f[1] ~= "1" then return nil, "invalid" end
        if #f[2] > 50 or not f[2]:match("^Player%-%d+%-%x+$") then return nil, "guid" end
        local name = Sp.name(f[3])
        if not name then return nil, "name" end
        local class = f[4] ~= "" and f[4] or nil
        if class and not CLASSES[class] then return nil, "class" end
        local level = int(f[5], -1, 1000)
        if not level then return nil, "level" end
        local age = int(f[7], 0, 120)
        local zone = zoneText(f[6])
        if not age or not zone then return nil, "invalid" end
        return { enemy = { name = name, class = class, level = (level >= 1 and level <= 100) and level or nil }, zoneName = zone,
            age = age }
    end
end
-- record(prefix, d, ctx) -> record or nil, why; ctx = { sender, route, heard, zone }
-- One row per observer and enemy: the rid is the enemy's name hash, so a repeat refreshes nothing and is one row.
function Sp.record(prefix, d, ctx)
    local hash = N.Hash.hash3(d.enemy.name:lower())
    return N.Record.new({ src = Sp.SRC[prefix], kind = "seen", origin = ctx.sender, via = ctx.sender, route = ctx.route,
        rid = hash, zone = ctx.zone, x = d.x, y = d.y, count = 1,
        enemies = { { name = d.enemy.name, hash = hash, class = d.enemy.class, level = d.enemy.level } },
        layer = { ns = "unknown" }, heard = ctx.heard, age = d.age, share = "guild", pos = d.x and "observer" or nil })
end
