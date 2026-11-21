-- Hosts learned from LayerSwap "heard" replies to our own hop request, kept 12 minutes. Read only: storing a reply
-- sends nothing. The entries have the shape of LayerSwap's own book, so Invite reads them like that book.
local _, N = ...
local S = N.Safe
local Hs = {}
N.Hosts = Hs
Hs.KEEP, Hs.MAX = 720, 64
Hs.FLH_KEEP = 180

Hs.ASK_EVERY = 60
function Hs.new() return { heard = {}, flhHosts = {}, askedAt = nil } end

-- ask(st, now, inGuild) -> ok, message. One LFSw "Q" on GUILD: Bulo users in the guild answer with their own layer
-- line within 1 to 6 s (each at most once per 60 s, so a faster question is wasted). Only from a click.
function Hs.ask(st, now, inGuild)
    if not N.Main.sharing() then return false, "sharing is off; no guild question was sent (/le share on)." end
    if not inGuild then return false, "you are not in a guild; nothing was sent." end
    if not S.num(now) then return false, "the clock is unreadable; nothing was sent." end
    if st.askedAt and now - st.askedAt < Hs.ASK_EVERY and now >= st.askedAt then
        return false, "the guild was asked " .. math.floor(now - st.askedAt) .. " s ago; wait " .. math.ceil(Hs.ASK_EVERY - (now - st.askedAt)) .. " s."
    end
    st.askedAt = now
    local ok, why = N.Wire.send("LFSw", N.Wire.LFSW_TEXT, "GUILD", nil, { prio = "click" })
    if not ok then
        return false, why == "throttled" and "the question was sent less than 60 s ago or the client is throttling; not sent."
            or "the client refused the guild message; not sent."
    end
    return true, "asked the guild's Bulo users for their layers; answers take up to 6 s"
end
-- Seconds until the next question is allowed, or nil.
function Hs.askWait(st, now)
    if st.askedAt and S.num(now) and now - st.askedAt < Hs.ASK_EVERY and now >= st.askedAt then return math.ceil(Hs.ASK_EVERY - (now - st.askedAt)) end
end

-- Entries 720 s old or older go.
function Hs.prune(st, wall)
    if not S.num(wall) then return end
    for name, e in pairs(st.heard) do if wall - e.at >= Hs.KEEP then st.heard[name] = nil end end
    for key,e in pairs(st.flhHosts) do
        if wall<e.at or wall-e.at>=Hs.FLH_KEEP then st.flhHosts[key]=nil end
    end
end

-- Passive FLH presence, never a LayerSwap reply. nil withdraws only this source.
-- Map and decimal zoneUID stay separate from the server-key namespace.
function Hs.flh(st,name,claim,wall)
    local _,key,target=N.Invite.name(name)
    if not key or not S.num(wall) then return false end
    Hs.prune(st,wall)
    if claim==nil then st.flhHosts[key]=nil; return false end
    if not S.tab(claim) then return false end
    local map,layer=S.num(claim.map),N.FLH.key(claim.key)
    if not map or map<1 or map%1~=0 or not layer then return false end
    if not st.flhHosts[key] and S.count(st.flhHosts)>=Hs.MAX then
        local oldest
        for k,e in pairs(st.flhHosts) do
            if not oldest or e.at<st.flhHosts[oldest].at then oldest=k end
        end
        st.flhHosts[oldest]=nil
    end
    st.flhHosts[key]={name=target,map=map,key=layer,at=wall}
    return true
end

-- heard(st, name, reply, wall): reply is a Hop.reply table from the player we asked (Hop.receive already checked
-- who, how and when). Hosting with a layer and a zone stores the name; a "-" (not hosting) reply removes it.
function Hs.heard(st, name, reply, wall)
    if not S.tab(reply) or reply.kind ~= "heard" or not S.str(name, 100) or not S.num(wall) then return false end
    local key = N.Invite.key(name)
    if not key then return false end
    Hs.prune(st, wall)
    -- one entry per player (the folded key): another spelling of the same player is replaced; the book stays keyed
    -- by the spelling last heard, which is the name to whisper
    for k in pairs(st.heard) do if k ~= name and N.Invite.key(k) == key then st.heard[k] = nil end end
    if not reply.hosting then st.heard[name] = nil; return false end
    if not reply.layer or not reply.zone then return false end
    if not st.heard[name] then
        local n, oldest, key = 0, nil, nil
        for k, e in pairs(st.heard) do n = n + 1; if not oldest or e.at < oldest then oldest, key = e.at, k end end
        if n >= Hs.MAX then st.heard[key] = nil end
    end
    st.heard[name] = { layer = reply.layer, zone = reply.zone, at = wall, host = true, network = reply.network }
    return true
end
