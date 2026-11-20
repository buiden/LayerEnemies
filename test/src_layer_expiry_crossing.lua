-- Review repro: expiry between a group transition and a confirmed new key.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function read(kind,key)
    local server,uid=key:match("^(%d+)%-(%d+)$")
    H.units().target={guid="Creature-0-"..server.."-0-"..uid.."-"..kind.."-ABC",player=false}
    H.deliver("PLAYER_TARGET_CHANGED"); H.drain()
end
for _,source in ipairs({"NPC","Bulo"}) do
    for _,join in ipairs({true,false}) do
        for _,case in ipairs({"changed","same","late"}) do
            test("Layer expiry crossing: "..source.." "..(join and "join " or "leave ")..case,function()
                local N=H.load(); H.establish(N)
                H.units().target=nil; H.units().mouseover=nil
                local at=N.Main.npcs.last
                if source=="Bulo" then
                    H.clock(20); BuloLayerForever={current="7086-7",Radar={seen={}}}; N.Main.poll()
                    at=H.clock(); BuloLayerForever.current=nil
                end
                if not join then H.clock(50); H.group(true); H.deliver("GROUP_ROSTER_UPDATE"); H.drain() end
                H.clock(at+298); H.drain(); yes(N.Main.track("Cedar Vale"))
                H.units().target=H.player("Cedar Vale","Horde","Player-1-ABC")
                H.deliver("PLAYER_TARGET_CHANGED"); H.drain(); H.units().target=nil
                yes(N.Main.store.localSeen["Player-1-ABC"])
                H.clock(at+299); H.group(join); H.deliver("GROUP_ROSTER_UPDATE")
                local serial=N.Main.store.serial
                H.clock(at+300); N.Main.poll()
                eq(N.Main.store.bulo,nil); eq(N.Layer.server(N.Main.npcs),nil)
                local key=case=="same" and "7086-7" or "8000-8"
                H.clock(at+(case=="late" and 310 or 301))
                if source=="NPC" then
                    read(3,key); eq(N.Main.store.serial,serial,"one vote is not a crossing")
                    read(4,key)
                else BuloLayerForever.current=key; N.Main.poll() end
                eq(N.Main.store.bulo,key)
                if case=="changed" then
                    yes(N.Main.store.serial>serial,"expiry must not hide a group-associated crossing")
                    eq(N.Main.store.localSeen["Player-1-ABC"],nil); eq(#N.Main.keyChanges,0)
                    eq(N.Main.findRows()[1].status,"seen by you"); no(N.Main.findRows()[1].same)
                else
                    eq(N.Main.store.serial,serial); yes(N.Main.store.localSeen["Player-1-ABC"])
                    eq(#N.Main.keyChanges,case=="late" and 1 or 0)
                end
                no(N.Main.error)
            end)
        end
    end
end
