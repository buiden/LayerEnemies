-- Hosts learned from LayerSwap "heard" replies to our own hop request, kept 12 minutes. Read only: storing a reply
-- sends nothing. The entries have the shape of LayerSwap's own book, so Invite reads them like that book.
local _, N = ...
local S = N.Safe
local Hs = {}
N.Hosts = Hs
Hs.KEEP, Hs.MAX = 720, 64

function Hs.new() return { heard = {} } end

-- Entries 720 s old or older go.
function Hs.prune(st, wall)
    if not S.num(wall) then return end
    for name, e in pairs(st.heard) do if wall - e.at >= Hs.KEEP then st.heard[name] = nil end end
end

-- heard(st, name, reply, wall): reply is a Hop.reply table from the player we asked (Hop.receive already checked
-- who, how and when). Hosting with a layer and a zone stores the name; a "-" (not hosting) reply removes it.
function Hs.heard(st, name, reply, wall)
    if not S.tab(reply) or reply.kind ~= "heard" or not S.str(name, 100) or not S.num(wall) then return false end
    Hs.prune(st, wall)
    if not reply.hosting then st.heard[name] = nil; return false end
    if not reply.layer or not reply.zone then return false end
    if not st.heard[name] then
        local n, oldest, key = 0, nil, nil
        for k, e in pairs(st.heard) do n = n + 1; if not oldest or e.at < oldest then oldest, key = e.at, k end end
        if n >= Hs.MAX then st.heard[key] = nil end
    end
    st.heard[name] = { layer = reply.layer, zone = reply.zone, at = wall, host = true }
    return true
end
