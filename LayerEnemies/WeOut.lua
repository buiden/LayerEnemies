-- War Effort 1.6.6 encoders (WEFF1, protocol minor 19): C and E (our own first-hand reports, and sync answers), H
-- (hello), Q (hello request) and K (reply to a layer request). Written from the wire format; no donor code copied. Pure.
local _, N = ...
local W = {}
N.WeOut = W
W.PER_PART, W.MAX_PARTS, W.MAX_COUNT = 18, 9, 200
W.MINOR = 19                -- the War Effort protocol minor we read and write
-- The hello's version field (War Effort reads x.y.z only). Fixed, not our addon version: War Effort shows its users
-- "a newer version of War Effort is available" for a guildmate's hello up to two minors ahead of its own (Hello.lua
-- update notice), so this must stay below War Effort's own version.
W.VERSION = "1.0.0"
W.JOIN_OFF = 2              -- K status: does not accept layer requests

local CODE
local function code(class)
    if not CODE then CODE = {}; for k, v in pairs(N.Protocol.classes) do CODE[v] = k end end
    return class and CODE[class] or "?"
end
local function coord(v)
    v = tonumber(v) or 0
    if v ~= v or v < 0 then v = 0 elseif v > 1 then v = 1 end
    return string.format("%.3f", v)
end
local function stampOf(s) return tostring(math.floor(tonumber(s) or 0) % 3600) end

-- cluster(rid, map, x, y, layer, count, stamp[, i, n]) -> "C|..." with the stamp (servertime % 3600) in its place;
-- i and n (1 <= i <= n <= 3): a sync answer's marker after an empty spread field
function W.cluster(rid, map, x, y, layer, count, stamp, i, n)
    count = math.max(1, math.min(W.MAX_COUNT, math.floor(tonumber(count) or 1)))
    local c = table.concat({ "C", tostring(rid), tostring(map), coord(x), coord(y), tostring(tonumber(layer) or 0),
        tostring(count), stampOf(stamp) }, "|")
    if i and n then c = c .. "||" .. tostring(i) .. ":" .. tostring(n) end
    return c
end
-- hello(t) -> "H|version|map|layer|1|19|0|0|stamp|<guild: unknown>|class|level|public[|0|1]"
--   t = { map, layer (number or nil: 0), class token, level, public (bool), ambiguous, stamp (server time) }
--   sharing 1, mode 0 (full), realm id 0 (unknown), guild id empty (unknown); ambiguous adds the received-count
--   place (0) and "1"
function W.hello(t)
    local lvl = tonumber(t.level)
    lvl = (lvl and lvl >= 1 and lvl <= 100) and math.floor(lvl) or 0
    local f = { "H", W.VERSION, tostring(math.floor(tonumber(t.map) or 0)), tostring(math.floor(tonumber(t.layer) or 0)), "1",
        tostring(W.MINOR), "0", "0", stampOf(t.stamp), "", t.class and code(t.class) ~= "?" and code(t.class) or "-",
        tostring(lvl), t.public and "1" or "0" }
    if t.ambiguous then f[#f + 1] = "0"; f[#f + 1] = "1" end
    return table.concat(f, "|")
end
function W.query() return "Q" end
-- presence(guild id or nil, ask) -> "P|19|<id or ->|0|<a or empty>" (the continent field is always 0)
function W.presence(guild, ask)
    local g = type(guild) == "string" and guild:match("^%d+$") and #guild <= 20 and guild or "-"
    return "P|" .. tostring(W.MINOR) .. "|" .. g .. "|0|" .. (ask and "a" or "")
end
-- links(keys) -> "D|key,key,key" (at most 3; "D|": none any more)
function W.links(keys)
    local out = {}
    for i = 1, math.min(#keys, 3) do out[i] = keys[i] end
    return "D|" .. table.concat(out, ",")
end
local function hex(s) return (s:gsub(".", function(c) return string.format("%02x", c:byte()) end)) end
W.hex = hex
-- wrap(kind, origin, realm, inner) -> "W|hexorigin|realm|inner" or "G|..."; nil when it would not fit 255 bytes
function W.wrap(kind, origin, realm, inner)
    if type(origin) ~= "string" or #origin < 2 or #origin > 100 or origin:find("[%c|]") or type(inner) ~= "string" then return nil end
    local r = tonumber(realm) and tonumber(realm) >= 1 and tostring(math.floor(tonumber(realm))) or ""
    local s = kind .. "|" .. hex(origin) .. "|" .. r .. "|" .. inner
    return #s <= 255 and s or nil
end
-- rebuild(inner) -> the C, E or H line made again from its decoded fields (Protocol.decode), so nothing a sender put
-- after them travels on: a wrapped line (W out, G in) carries only what we read. nil for any other type.
function W.rebuild(m)
    if type(m) ~= "table" then return nil end
    if m.type == "C" then
        local f = { "C", tostring(m.rid), tostring(m.map), coord(m.x), coord(m.y), tostring(m.layer), tostring(m.count),
            m.stamp and tostring(m.stamp) or "" }
        if m.spread then f[9] = tostring(m.spread) end
        while f[#f] == "" do f[#f] = nil end
        return table.concat(f, "|")
    elseif m.type == "E" then
        local items = {}
        for _, e in ipairs(m.enemies or {}) do
            local lvl = e.level == -1 and "-1" or (e.level and tostring(e.level)) or "?"
            items[#items + 1] = e.hash .. ":" .. code(e.class) .. ":" .. lvl
        end
        local f = { "E", tostring(m.rid), tostring(m.part), tostring(m.total), table.concat(items, ",") }
        if m.stamp then f[6] = tostring(m.stamp) end
        return table.concat(f, "|")
    elseif m.type == "H" then
        local guild = m.guildId == false and "-" or (type(m.guildId) == "string" and m.guildId) or ""
        local f = { "H", m.version, tostring(m.map), tostring(m.layer), tostring(m.sharing), m.minor and tostring(m.minor) or "",
            "0", "0", m.stamp and tostring(m.stamp) or "", guild, m.class and code(m.class) or "-", tostring(m.level or 0),
            m.public == true and "1" or m.public == false and "0" or "" }
        -- the received count and the ambiguity flag as read (an unknown count stays empty before a flag)
        if m.received or m.ambiguous then f[14] = m.received and tostring(m.received) or "" end
        if m.ambiguous then f[15] = "1" end
        return table.concat(f, "|")
    end
end
-- joinOff(id, stamp) -> "K|id|2|stamp": we do not take layer requests
function W.joinOff(id, stamp) return "K|" .. tostring(id) .. "|" .. tostring(W.JOIN_OFF) .. "|" .. stampOf(stamp) end
-- enemies(rid, list, stamp) -> { "E|...", ... }: list entries { hash (3 letters or digits), class token, level };
-- 18 per part, at most 9 parts; entries without a valid hash are left out
function W.enemies(rid, list, stamp)
    local items = {}
    for _, e in ipairs(list or {}) do
        if type(e.hash) == "string" and e.hash:match("^%w%w%w$") then
            local lvl = tonumber(e.level)
            lvl = (lvl == -1 or (lvl and lvl >= 1 and lvl <= 100 and lvl % 1 == 0)) and tostring(lvl) or "?"
            items[#items + 1] = e.hash .. ":" .. code(e.class) .. ":" .. lvl
        end
    end
    local total = math.min(W.MAX_PARTS, math.ceil(#items / W.PER_PART))
    local out = {}
    for part = 1, total do
        local slice = {}
        for i = (part - 1) * W.PER_PART + 1, math.min(#items, part * W.PER_PART) do slice[#slice + 1] = items[i] end
        out[part] = table.concat({ "E", tostring(rid), tostring(part), tostring(total), table.concat(slice, ","), stampOf(stamp) }, "|")
    end
    return out
end
