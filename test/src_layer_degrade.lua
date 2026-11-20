-- Layer plan PR 1: always-correct expiry, decoder and real-boundary regressions.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function npc(kind,uid,server)
    return "Creature-0-"..(server or "7086").."-0-"..(uid or 7).."-"..kind.."-ABCDEF"
end
local function readNPC(kind,uid,server)
    H.units().target={guid=npc(kind,uid,server),player=false}
    H.deliver("PLAYER_TARGET_CHANGED"); H.drain()
end

test("Layer A1: poll expires an unread own key at 300 seconds, not 299",function()
    local N=H.load(); H.establish(N)
    local at=N.Main.npcs.last
    H.units().target=nil; H.units().mouseover=nil
    H.clock(at+299); N.Main.poll()
    eq(N.Main.store.bulo,"7086-7"); eq(N.Main.store.zoneUID,7)
    H.clock(at+300); N.Main.poll()
    eq(N.Main.store.bulo,nil,"expired own key"); eq(N.Main.store.zoneUID,nil)
    eq(N.Layer.server(N.Main.npcs),nil,"expired raw fallback")
    readNPC(3); eq(N.Main.store.bulo,nil,"expiry drops old votes")
    readNPC(4); eq(N.Main.store.bulo,"7086-7","fresh confirmation recovers")
    no(N.Main.error)
end)

test("Layer A1: a valid NPC read refreshes expiry, malformed reads do not",function()
    local N=H.load(); H.establish(N)
    H.clock(200); readNPC(3)
    H.clock(499); N.Main.poll(); eq(N.Main.store.bulo,"7086-7")
    H.units().target={guid="Creature-unreadable",player=false}
    H.deliver("PLAYER_TARGET_CHANGED"); H.drain()
    H.clock(500); N.Main.poll(); eq(N.Main.store.bulo,nil)
    no(N.Main.error)
end)

test("Layer A1: Bulo read loss expires on poll without wiping sightings",function()
    local N=H.load()
    local b={current="8000-8",Radar={seen={}}}; BuloLayerForever=b
    H.clock(110); N.Main.poll(); eq(N.Main.store.bulo,"8000-8")
    H.clock(111); H.units().target=H.player("Enemy","Horde")
    H.deliver("PLAYER_TARGET_CHANGED"); H.drain()
    local row=N.Main.store.localSeen["Player-1-123"]; yes(row)
    b.current=nil
    H.clock(410); N.Main.poll()
    eq(N.Main.store.bulo,"8000-8","299 seconds since the last valid poll")
    H.clock(411); N.Main.poll(); eq(N.Main.store.bulo,nil)
    eq(N.Main.store.localSeen["Player-1-123"],row,"expiry is not a transfer")
    no(N.Main.error)
end)

test("Layer A1: a late first NPC read cannot revive the expired confirmed key",function()
    local N=H.load(); H.establish(N); local at=N.Main.npcs.last
    H.clock(at+300); C_Timer=nil -- immediate event fallback runs before the next heartbeat
    readNPC(3,8)
    eq(N.Main.store.bulo,nil,"one new reading cannot retain an expired confirmation")
    eq(N.Main.store.zoneUID,nil)
    readNPC(4,8); eq(N.Main.store.bulo,"7086-8")
end)
