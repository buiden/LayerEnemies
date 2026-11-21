-- Same-key confirmation is one transition regardless of observation delay.
local H=...
for _,delay in ipairs({0,10,10.1,30}) do
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
        local expected=1
        H.eq(#N.Main.store.trust.changes,expected,"one confirmed transition regardless of delay")
        H.eq(#N.Main.keyChanges,expected,"diagnostic agrees with trust counter")
        H.clock(170); BuloLayerForever.current="10000-10"; N.Main.poll()
        H.eq(N.Trust.state(N.Main.store,H.clock()),"known")
        H.clock(190); BuloLayerForever.current="11000-11"; N.Main.poll()
        H.eq(N.Trust.state(N.Main.store,H.clock()),"blind","three distinct transitions still trigger")
        H.no(N.Main.error)
    end)
end
H.test("Trust corroboration: intervening NPC key separates confirmations",function()
    local N=H.load(); H.establish(N)
    H.units().target=nil; H.units().mouseover=nil
    BuloLayerForever={current="7086-7",Radar={seen={}}}
    H.clock(100); N.Main.poll()
    H.clock(120); BuloLayerForever.current="9000-9"; N.Main.poll()
    for i,key in ipairs({"10000-10","9000-9"}) do
        H.clock(120+i*30)
        local server,uid=key:match("^(%d+)%-(%d+)$")
        for _,npc in ipairs({31,32}) do
            H.units().target={guid="Creature-0-"..server.."-0-"..uid.."-"..npc.."-ABC",player=false}
            H.deliver("PLAYER_TARGET_CHANGED"); H.drain()
        end
        H.units().target=nil
        H.eq(#N.Main.store.trust.changes,i+1,"intervening key is a distinct transition")
        H.eq(#N.Main.keyChanges,i+1)
    end
    H.eq(N.Trust.state(N.Main.store,H.clock()),"blind"); H.no(N.Main.error)
end)
