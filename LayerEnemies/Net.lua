-- Network registry (1.0): one entry per network with its ship constant, the player's switch, the consent its public
-- part needs, and the addon whose presence stands it down. Wire asks Net before every network send; adapters use
-- Net.after for their timers, so a network that is off registers none.
local _, N = ...
local S = N.Safe
local Net = {}
N.Net = Net

-- Ship constants: a network whose constant is false never sends, whatever the player chose. 1.0.0 ships both on
-- (owner decision); a network that fails its live-test step on the PR build is turned off here before release.
Net.SHIP = { we = true, hh = true }
-- name: shown in /le net; standDown: the real addon whose presence makes us receive-only on its prefix.
Net.LIST = {
    we = { name = "War Effort", standDown = "WarEffortScout" },
    hh = { name = "HeadHunter", standDown = "HeadHunter" },
}
Net.CONSENT = { guild = true, public = true }

local state = { consent = nil, switches = {} }
local function loaded(name)
    local A = N.Adapters
    return A and A.loaded and A.loaded(name) or false
end

-- load(saved) -> sanitized { consent, nets }: consent is "guild", "public" or nil (no choice made: public, owner
-- decision 2026-11-14); a switch is off only when saved as false.
function Net.load(saved)
    saved = S.tab(saved) and saved or {}
    state.consent = Net.CONSENT[saved.consent] and saved.consent or nil
    local nets = S.tab(saved.nets) and saved.nets or {}
    state.switches = {}
    for key, entry in pairs(Net.LIST) do state.switches[key] = entry.session == true or nets[key] ~= false end
    local persisted={}
    for key,on in pairs(state.switches) do if not Net.LIST[key].session then persisted[key]=on end end
    return state.consent, persisted
end
local function save()
    if not S.tab(LayerEnemiesDB) then return end
    LayerEnemiesDB.consent = state.consent
    LayerEnemiesDB.nets = LayerEnemiesDB.nets or {}
    for key, on in pairs(state.switches) do
        if not Net.LIST[key].session then LayerEnemiesDB.nets[key] = on end
    end
end
-- consent(): the level in force ("public" until the player chooses guild only); chosen(): the saved choice or nil
function Net.consent() return state.consent or "public" end
function Net.chosen() return state.consent end
-- why(key) -> nil when the network may run at the level in force, else a reason for /le net and the window
function Net.why(key)
    local entry = Net.LIST[key]
    if not entry or Net.SHIP[key] ~= true then return "not in this version" end
    if not Net.switch(key) then return "switched off" end
    if entry.standDown and loaded(entry.standDown) then return entry.name .. " is loaded: it sends, we only read" end
    if Net.consent() ~= "public" then return "guild only" end
    return nil
end
function Net.setConsent(level)
    if not Net.CONSENT[level] then return false end
    if level~="public" and N.BNet then N.BNet.cancel(); if N.WarBoardTrack then N.WarBoardTrack.stop() end end
    if level~="public" and N.FLHMember then N.FLHMember.stop("guild only") end
    state.consent = level; save()
    if N.Directory then N.Directory.sync() end
    return true
end
function Net.switch(key) return state.switches[key] ~= false end
function Net.setSwitch(key, on)
    if not Net.LIST[key] then return false end
    if on~=true and N.BNet then
        N.BNet.cancel(key)
        if key=="warboard" and N.WarBoardTrack then N.WarBoardTrack.stop() end
    end
    if key=="flh" and on~=true then N.FLHMember.stop("network off") end
    state.switches[key] = on == true; if not Net.LIST[key].session then save() end
    if N.Directory then N.Directory.sync() end
    return true
end
-- allowed(key, scope) -> ok, why: "network off" (unknown, ship constant or switch), "stand down" (the real addon is
-- loaded) or "no consent" (a public scope while the player chose guild only). Guild scope needs no choice.
function Net.allowed(key, scope)
    local entry = Net.LIST[key]
    if not entry or Net.SHIP[key] ~= true or not Net.switch(key) then return false, "network off" end
    if entry.standDown and loaded(entry.standDown) then return false, "stand down" end
    if scope == "public" and Net.consent() ~= "public" then return false, "no consent" end
    if scope ~= "public" and scope ~= "guild" and scope ~= nil then return false, "network off" end
    return true
end
-- after(key, delay, fn[, scope]) -> registered: a timer only while the network may run; fn runs only if it still may.
function Net.after(key, delay, fn, scope)
    if not Net.allowed(key, scope) or type(fn) ~= "function" or not S.num(delay) then return false end
    local T = _G.C_Timer
    if not S.tab(T) or type(T.After) ~= "function" then return false end
    return pcall(T.After, delay, function() if Net.allowed(key, scope) then fn() end end) == true
end
