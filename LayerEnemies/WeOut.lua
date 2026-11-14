-- War Effort 1.6.6 encoders (WEFF1, protocol minor 19): C and E, our own first-hand reports. Written from the wire
-- format (C|id|map|x|y|layer|count|stamp, E|id|part|total|hash:class:level,...|stamp); no donor code copied. Pure.
local _, N = ...
local W = {}
N.WeOut = W
W.PER_PART, W.MAX_PARTS, W.MAX_COUNT = 18, 9, 200

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

-- cluster(rid, map, x, y, layer, count, stamp) -> "C|..." with the stamp (servertime % 3600) in its place
function W.cluster(rid, map, x, y, layer, count, stamp)
    count = math.max(1, math.min(W.MAX_COUNT, math.floor(tonumber(count) or 1)))
    return table.concat({ "C", tostring(rid), tostring(map), coord(x), coord(y), tostring(tonumber(layer) or 0),
        tostring(count), stampOf(stamp) }, "|")
end
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
