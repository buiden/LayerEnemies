-- Independent decoder for War Effort 1.6.6 (WEFF1, protocol minor 19): C, E and H, plus the G and X wrappers that
-- carry one of them for another reporter. Written from the documented grammar; nothing is copied. Pure.
local _, N = ...
local P, S = {}, N.Safe
N.Protocol = P
P.classes = { A = "WARRIOR", B = "PALADIN", C = "HUNTER", D = "ROGUE", E = "PRIEST", F = "DEATHKNIGHT", G = "SHAMAN",
    H = "MAGE", I = "WARLOCK", J = "MONK", K = "DRUID", L = "DEMONHUNTER", M = "EVOKER" }

-- Integer: optional leading "-", digits, at most 10 characters, then the bounds.
local function int(s, lo, hi)
    if type(s) ~= "string" or #s < 1 or #s > 10 or not s:match("^%-?%d+$") then return nil end
    local n = tonumber(s)
    if n and n >= lo and n <= hi then return n end
end
P.int = int
-- Coordinate: 0 or 1, or 0.x / 1.x with one to three decimals, in 0..1.
local function coord(s)
    if type(s) ~= "string" or not (s:match("^[01]$") or s:match("^[01]%.%d%d?%d?$")) then return nil end
    local n = tonumber(s); if n and n <= 1 then return n end
end
-- Even-length hex of a name: decoded, 2..100 bytes, no control bytes or "|".
local function hexname(h)
    if type(h) ~= "string" or #h < 4 or #h > 200 or #h % 2 ~= 0 or not h:match("^%x+$") then return nil end
    local name = h:gsub("%x%x", function(b) return string.char(tonumber(b, 16)) end)
    if #name < 2 or #name > 100 or name:find("[%c|]") then return nil end
    return name
end
P.hexname = hexname

local function split(text)
    local f = {}
    for field in (text .. "|"):gmatch("([^|]*)|") do f[#f + 1] = field end
    return f
end

local decodeInner
local function C(f)
    if #f < 7 then return nil end
    local r = { type = "C", rid = int(f[2], 1, 65535), map = int(f[3], 1, 999999), x = coord(f[4]), y = coord(f[5]),
        layer = int(f[6], 0, 99999999), count = int(f[7], 1, 200) }                               -- War Effort's MAX_COUNT
    if not (r.rid and r.map and r.x and r.y and r.layer and r.count) then return nil end
    r.stamp = int(f[8], 0, 3599)                                 -- invalid or absent: no stamp (age 0)
    r.spread = int(f[9], 0, 45)                                   -- invalid: unknown
    local i, n = (f[10] or ""):match("^(%d):(%d)$")
    i, n = tonumber(i), tonumber(n)
    r.sync = i ~= nil and n ~= nil and i >= 1 and i <= n and n <= 3
    return r
end
local function E(f)
    if #f < 5 or f[5] == "" then return nil end
    local r = { type = "E", rid = int(f[2], 1, 65535), part = int(f[3], 1, 9), total = int(f[4], 1, 9), enemies = {} }
    if not (r.rid and r.part and r.total) or r.part > r.total then return nil end
    for item in (f[5] .. ","):gmatch("([^,]*),") do
        local hash, code, level = item:match("^(%w%w%w):([A-M?]):([%d?%-]+)$")
        if not hash or #r.enemies >= 18 then return nil end
        local lvl
        if level == "-1" then lvl = -1 elseif level ~= "?" then lvl = int(level, 1, 100); if not lvl then return nil end end
        r.enemies[#r.enemies + 1] = { hash = hash, class = P.classes[code], level = lvl }
    end
    r.stamp = int(f[6], 0, 3599)
    return r
end
local function H(f)
    if #f < 5 or #f[2] > 20 or not f[2]:match("^%d+%.%d+%.%d+$") then return nil end
    local r = { type = "H", version = f[2], map = int(f[3], 0, 999999), layer = int(f[4], 0, 99999999), sharing = int(f[5], 0, 1) }
    if not (r.map and r.layer and r.sharing) then return nil end
    if f[6] == nil or f[6] == "" then r.minor = 0 else r.minor = int(f[6], 0, 999) end   -- invalid: unknown (nil)
    r.stamp = int(f[9], 0, 3599)
    return r
end
local function wrapper(f, kind)
    if #f < 4 then return nil end
    local origin = hexname(f[2])
    local realm = f[3]
    if not origin or not (realm == "" or int(realm, 1, 999999)) then return nil end
    local inner = decodeInner({ unpack(f, 4) })
    if not inner then return nil end
    if inner.type == "C" and inner.sync then return nil end        -- only live C travels wrapped
    return { type = kind, origin = origin, realm = realm ~= "" and tonumber(realm) or nil, inner = inner }
end
decodeInner = function(f)
    local t = f[1]
    if t == "C" then return C(f) elseif t == "E" then return E(f) elseif t == "H" then return H(f) end
end

-- decode(text) -> msg | nil, why. why is "ignored" for a well-formed message of another type (not an error) and
-- "invalid" otherwise.
function P.decode(text)
    if S.secret(text) or type(text) ~= "string" or #text < 1 or #text > 255 then return nil, "invalid" end
    if text:find("[^%w|%.:,%-?]") then return nil, "invalid" end
    local f = split(text)
    local t = f[1]
    local msg
    if t == "C" or t == "E" or t == "H" then msg = decodeInner(f)
    elseif t == "G" or t == "X" then msg = wrapper(f, t)
    else return nil, "ignored" end
    if not msg then return nil, "invalid" end
    return msg
end

-- Age of a stamp: (now - stamp) % 3600; more than half an hour counts as 0 (the stamp has no hour). No stamp: 0.
function P.age(stamp, serverNow)
    serverNow = S.num(serverNow)
    if not serverNow then return nil end
    -- no usable stamp: age 0 and untimed (the record then carries receipt time and says so)
    if stamp == nil then return 0, true end
    local age = (math.floor(serverNow) - stamp) % 3600
    if age > 1800 then return 0, true end
    return age
end
P.MAXAGE = 900                                                  -- C and E older than this are dropped
