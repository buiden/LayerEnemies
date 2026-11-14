-- Directory channels (1.0): War Effort's and HeadHunter's named channels, joined only for their member lists (who is
-- running that network). Nothing is ever sent to a channel: Wire has no CHANNEL route. Joined only at consent "public"
-- for a network that may run, left when that ends; only channels we joined are ever left. The list is read the way the
-- Chat Channels window asks for it (select, then read), never while that window is open, in combat or an instance.
-- The channel names are wire facts; the code is ours.
local _, N = ...
local S = N.Safe
local D = {}
N.Directory = D

D.WAIT, D.EVERY, D.FIRST, D.MAX, D.TAG_MAX = 3, 300, 10, 500, 10

-- War Effort's ruleset tag from a realm name: "RPPvP", "RP", "PvP", "PvE", or the realm's own words (letters and
-- digits, a trailing number word dropped, 10 characters at most). nil without a name.
local RP_WORDS = { rp = true, roleplay = true, roleplaying = true, rpvp = true, rpve = true }
function D.rulesetTag(realm)
    if S.secret(realm) or type(realm) ~= "string" then return nil end
    local lower = realm:lower()
    local pvp = lower:find("pvp", 1, true) ~= nil
    local pve = not pvp and lower:find("pve", 1, true) ~= nil
    local rp = realm:find("RP[%s%p]*[Pp][Vv][PpEe]") ~= nil or lower:find("%f[%w]rp[%s%p]*pv[pe]") ~= nil
        or lower:find("%f[%w]r%.p%.") ~= nil
    local words, prev = {}, nil
    for w in lower:gmatch("%w+") do
        words[#words + 1] = w
        local bare = w:gsub("%d+$", "")
        if RP_WORDS[bare] or (prev == "role" and (bare == "play" or bare == "playing")) then rp = true
        elseif bare == "normal" and not pvp then pve = true end
        prev = bare
    end
    if rp then return pvp and "RPPvP" or "RP" end
    if pvp then return "PvP" end
    if pve then return "PvE" end
    if words[#words] and words[#words]:match("^%d+$") then words[#words] = nil end
    local tag = table.concat(words):sub(1, D.TAG_MAX)
    return tag ~= "" and tag or nil
end
-- channel(key) -> the channel name for that network, or nil while it cannot be known
function D.channel(key)
    if key == "hh" then return "HeadHunterSync" end
    if key ~= "we" then return nil end
    local tag = D.rulesetTag((S.call(GetRealmName)))
    local faction = S.call(UnitFactionGroup, "player")
    local letter = faction == "Alliance" and "A" or faction == "Horde" and "H" or nil
    return tag and letter and ("WarEffort" .. tag .. letter) or nil
end

local joined, members, pending = {}, {}, {}
local function calm()
    return S.call(IsInInstance) == false and S.call(InCombatLockdown) == false
end
local function windowOpen()
    local f = _G.ChannelFrame
    if not S.tab(f) or type(f.IsShown) ~= "function" then return false end
    local ok, shown = pcall(f.IsShown, f)
    return not ok or shown ~= false
end
local function index(name)
    local n = S.num(S.call(GetNumDisplayChannels))
    if not n then return nil end
    for i = 1, math.min(n, 100) do
        local shown = S.str((S.call(GetChannelDisplayInfo, i)), 120)
        if shown and (shown:match("^%d+%. (.+)$") or shown):lower() == name:lower() then return i end
    end
end
local function me() return (S.str((S.call(UnitName, "player")), 60) or ""):lower() end
local function read(key)
    pending[key] = nil
    local name = joined[key]
    local i = name and index(name)
    if not i then return end
    local count = S.num((select(5, S.call(GetChannelDisplayInfo, i)))) or 0
    local CI = _G.C_ChatInfo
    if count <= 0 or not S.tab(CI) or type(CI.GetChannelRosterInfo) ~= "function" then return end
    local list, self = {}, me()
    for r = 1, math.min(count, D.MAX) do
        local ok, who = pcall(CI.GetChannelRosterInfo, i, r)
        who = ok and S.str(who, 60)
        if who and (who:match("^([^%-]+)") or who):lower() ~= self then list[#list + 1] = who end
    end
    members[key] = list
end
-- refresh(key) -> asked: select the channel now, read its list D.WAIT s later
function D.refresh(key)
    local name = joined[key]
    if not name or pending[key] or windowOpen() or not calm() then return false end
    local i = index(name)
    if not i then return false end
    if not pcall(SetSelectedDisplayChannel, i) then return false end
    pending[key] = true
    if not N.Net.after(key, D.WAIT, function() read(key) end, "public") then pending[key] = nil; return false end
    return true
end
local function loop(key)
    if not joined[key] then return end
    D.refresh(key)
    N.Net.after(key, D.EVERY, function() loop(key) end, "public")
end
-- sync(): join what may run, leave what we joined and may not; called on consent, switch and heartbeat
function D.sync()
    local keys = {}
    for key in pairs(N.Net.LIST) do keys[#keys + 1] = key end
    table.sort(keys)
    for _, key in ipairs(keys) do
        local want = N.Net.allowed(key, "public")
        if want and not joined[key] then
            local name = D.channel(key)
            if name and calm() and pcall(JoinChannelByName, name, nil, 0, false) then
                joined[key] = name
                N.Net.after(key, D.FIRST, function() loop(key) end, "public")
            end
        elseif not want and joined[key] then
            pcall(LeaveChannelByName, joined[key])
            joined[key], members[key], pending[key] = nil, nil, nil
        end
    end
end
function D.members(key) return members[key] end
function D.count(key) return members[key] and #members[key] or nil end
function D.joined(key) return joined[key] end
