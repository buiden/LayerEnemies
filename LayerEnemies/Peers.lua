-- War Effort capability minor per reporter, learned from H (direct or wrapped). Decides what a C's layer means:
-- minor 13..19 sends the zone-scoped server number; anything else (or no hello) leaves the layer unknown.
local _, N = ...
local S = N.Safe
local Pe = {}
N.Peers = Pe
Pe.TTL, Pe.MAX = 900, 256

-- Names are compared whole, without case, as War Effort does: "Scout-RealmA" and "Scout-RealmB" are two reporters.
-- A sender seen with and without its realm is then two keys; a missed match leaves a layer unknown (the safe side).
function Pe.key(name)
    name = S.str(name, 100)
    if not name then return nil end
    return name:lower()
end
function Pe.new() return { list = {}, n = 0 } end
function Pe.hello(st, name, minor, now)
    local key = Pe.key(name)
    now = S.num(now)
    if not key or not now or not S.tab(st) then return false end
    minor = S.num(minor)
    if minor and (minor < 0 or minor > 999 or minor % 1 ~= 0) then minor = nil end
    local old = st.list[key]
    if not old then
        if st.n >= Pe.MAX then                                   -- full: drop the stalest entry
            local worst, wk
            for k, v in pairs(st.list) do if not worst or v.at < worst then worst, wk = v.at, k end end
            st.list[wk] = nil; st.n = st.n - 1
        end
        st.n = st.n + 1
    end
    st.list[key] = { minor = minor, at = now }
    return true
end
-- minor(st, name, now) -> number | nil (no hello within 900 s, or an unreadable minor)
function Pe.minor(st, name, now)
    local key = Pe.key(name)
    now = S.num(now)
    if not key or not now or not S.tab(st) then return nil end
    local v = st.list[key]
    if not v then return nil end
    if now - v.at > Pe.TTL then st.list[key] = nil; st.n = st.n - 1; return nil end
    return v.minor
end
-- Layer namespace for a reporter's C: "server" only for a known minor of 13..19.
function Pe.layerKnown(minor) return minor ~= nil and minor >= 13 and minor <= 19 end
