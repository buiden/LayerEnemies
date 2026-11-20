-- Independent Bulo/NPC corroboration repro, extended at the excuse window edge.
local H=...
for _,delay in ipairs({0,10,10.1}) do
    H.test("Trust corroboration: Bulo plus NPC at "..delay,function()
        local N=H.load(); H.establish(N)
        BuloLayerForever={current="7086-7",Radar={seen={}}}
        H.clock(100); N.Main.poll(); H.units().target=nil; H.units().mouseover=nil
        H.clock(120); BuloLayerForever.current="9000-9"; N.Main.poll()
        H.eq(#N.Main.store.trust.changes,1)
        H.clock(120+delay)
        for _,npc in ipairs({3,4}) do
            H.units().target={guid="Creature-0-9000-0-9-"..npc.."-ABC",player=false}
            H.deliver("PLAYER_TARGET_CHANGED"); H.drain()
        end
        H.units().target=nil
        local expected=delay<=10 and 1 or 2
        H.eq(#N.Main.store.trust.changes,expected,"one confirmed transition inside window")
        H.eq(#N.Main.keyChanges,expected,"diagnostic agrees with trust counter")
        H.clock(140); BuloLayerForever.current="10000-10"; N.Main.poll()
        H.eq(N.Trust.state(N.Main.store,H.clock()),delay<=10 and "known" or "blind")
        H.clock(160); BuloLayerForever.current="11000-11"; N.Main.poll()
        H.eq(N.Trust.state(N.Main.store,H.clock()),"blind","three distinct transitions still trigger")
        H.no(N.Main.error)
    end)
end
