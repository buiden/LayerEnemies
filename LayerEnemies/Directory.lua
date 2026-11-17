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
D.FRESH = 600   -- two refresh intervals; only a successful read renews this lifetime

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
    if key == "wanted" then
        local faction = S.str(S.call(UnitFactionGroup,"player"),16)
        return (faction=="Alliance" or faction=="Horde") and ("WantedNet"..faction) or nil
    end
    if key ~= "we" then return nil end
    local tag = D.rulesetTag((S.call(GetRealmName)))
    local faction = S.call(UnitFactionGroup, "player")
    local letter = faction == "Alliance" and "A" or faction == "Horde" and "H" or nil
    return tag and letter and ("WarEffort" .. tag .. letter) or nil
end

-- joined[key]: the channel we read; ours[key]: we joined it, by our own join notice (only then do we ever leave it);
-- asked[key]: our join call, waiting for its YOU_JOINED/YOU_CHANGED notice (30 s); handLeft[key]: the player left
-- it by hand, so we do not join it again this session (a hand rejoin is read, never left by us); due[key]: when
-- this channel's one timer fires (toggling never adds a second; a timer that fired while the network was off stops
-- counting once its time has passed)
local joined, members, pending, ours, due, asked, handLeft = {}, {}, {}, {}, {}, {}, {}
local readAt = {}
D.NOTICE_WAIT = 30
local function calm()
    return S.call(IsInInstance) == false and S.call(InCombatLockdown) == false
end
local function windowOpen()
    local f = _G.ChannelFrame
    if not S.tab(f) or type(f.IsShown) ~= "function" then return false end
    local ok, shown = pcall(f.IsShown, f)
    return not ok or shown ~= false
end
-- the display list is readable and filled (at login it may still be empty): only then can "already in it" be told
local function listReady()
    local n = S.num(S.call(GetNumDisplayChannels))
    return n ~= nil and n >= 1
end
local function index(name)
    local n = S.num(S.call(GetNumDisplayChannels))
    if not n then return nil end
    for i = 1, math.min(n, 100) do
        local shown = S.str((S.call(GetChannelDisplayInfo, i)), 120)
        if shown and (shown:match("^%d+%. (.+)$") or shown):lower() == name:lower() then return i end
    end
end
-- ourselves by the one name rule (Invite.name keys); nil while our name or our home realm cannot be read (then our
-- own "-<realm>" entries cannot be told from peers)
local function me()
    local _, key = N.Adapters.ownIdentity()
    return key
end
local function read(key)
    pending[key] = nil
    -- conditions may have changed in the 3 s: combat, an instance or the Channels window stop the read
    if windowOpen() or not calm() then return end
    local name = joined[key]
    local i = name and index(name)
    if not i then members[key] = nil; return end
    local now = S.num(S.call(GetTime))
    local count = S.num((select(5, S.call(GetChannelDisplayInfo, i))))
    local CI = _G.C_ChatInfo
    -- an unreadable count forgets the list rather than keep an old one
    if not now or not count or count < 0 or count % 1 ~= 0 or not S.tab(CI) or type(CI.GetChannelRosterInfo) ~= "function" then members[key] = nil; return end
    local self = me()
    if not self then members[key] = nil; return end
    if count == 0 then members[key], readAt[key] = {}, now; return end
    -- one entry per player (the folded key): "Peer" and "Peer-<our realm>" are one, the first spelling listed stays
    local list, seen = {}, {}
    for r = 1, math.min(count, D.MAX) do
        local ok, who = pcall(CI.GetChannelRosterInfo, i, r)
        -- A missing/secret/erroring row is a failed scan, not an authoritative empty roster. Readable strings
        -- outside our name grammar are still skipped, as before. Never publish a partly readable snapshot.
        if not ok or S.secret(who) or type(who) ~= "string" or who == "" then members[key] = nil; return end
        who = S.str(who, 60)
        local _, pkey = N.Invite.name(who)
        if pkey and pkey ~= self and not seen[pkey] then seen[pkey] = true; list[#list + 1] = who end
    end
    members[key], readAt[key] = list, now
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
local function schedule(key, delay)
    local now = S.num(S.call(GetTime))
    if not now or (due[key] and now <= due[key]) then return end
    due[key] = now + delay
    local ok = N.Net.after(key, delay, function()
        due[key] = nil
        if joined[key] then D.refresh(key); schedule(key, D.EVERY) end
    end, "public")
    if not ok then due[key] = nil end
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
            if name and calm() and listReady() then
                -- already in that channel (the player joined it): read it, never join or leave it
                local result, called = false, false
                local slots = key=="wanted" and S.num(S.call(GetNumDisplayChannels)) or nil
                if not index(name) and not handLeft[key] and (key~="wanted" or (slots and slots>=1 and slots<=7)) then
                    called = true
                    local now = S.num(S.call(GetTime))
                    asked[key] = now and { name = name, at = now } or nil
                    local ok, r = pcall(JoinChannelByName, name, nil, 0, false)
                    -- a nil, false or empty return is no join (its notice, if one still comes, makes it ours, so it
                    -- can be left again)
                    result = ok and r ~= nil and r ~= false and r ~= "" and not S.secret(r)
                end
                if result or (not called and index(name)) then
                    joined[key] = name
                    -- D1 is only a passive channel receiver, not a whisper-directory peer.
                    if key~="wanted" then schedule(key, D.FIRST) end
                end
            end
        elseif not want and joined[key] then
            local name, mine = joined[key], ours[key]
            joined[key], members[key], pending[key], ours[key], asked[key] = nil, nil, nil, nil, nil
            if mine then pcall(LeaveChannelByName, name) end
        end
    end
end
-- CHAT_MSG_CHANNEL_NOTICE: our own join notice makes the channel ours; a leave we did not make is the player's
-- (not joined again this session)
function D.notice(what, shown, base)
    if S.secret(what) or S.secret(shown) or S.secret(base) then return end
    local name = S.str(base, 120) or (S.str(shown, 120) and (shown:match("^%d+%. (.+)$") or shown))
    if not name then return end
    local now = S.num(S.call(GetTime))
    for key in pairs(N.Net.LIST) do
        if what == "YOU_JOINED" or what == "YOU_CHANGED" then
            local a = asked[key]
            if a and a.name:lower() == name:lower() and now and now >= a.at and now - a.at <= D.NOTICE_WAIT then
                asked[key] = nil; ours[key] = true
            end
        elseif what == "YOU_LEFT" and joined[key] and joined[key]:lower() == name:lower() then
            joined[key], members[key], pending[key], ours[key], asked[key] = nil, nil, nil, nil, nil
            handLeft[key] = true
        end
    end
end
-- nil = unknown/unreadable/expired; {} = a successful empty read. Consumers must not confuse the two.
-- The table identity changes only on a successful read; returning it does not renew its age.
function D.members(key)
    local now, at = S.num(S.call(GetTime)), readAt[key]
    if not now or not at or now < at or now - at >= D.FRESH then members[key], readAt[key] = nil, nil end
    return members[key], members[key] and readAt[key] or nil
end
function D.count(key) local list = D.members(key); return list and #list or nil end
function D.joined(key) return joined[key] end
