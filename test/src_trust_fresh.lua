local H=...
for _,tag in ipairs({"O","K"}) do for _,age in ipairs({1,2,22}) do
    H.test("Trust fresh group: "..tag.." claim age "..age,function()
        local N=H.load(); H.establish(N); H.units().target=nil; H.units().mouseover=nil
        H.roster({{"Birch Scout-TestRealm",true}}); H.deliver("GUILD_ROSTER_UPDATE")
        H.clock(120); H.units().party1={name="Birch Scout",leader=true}; H.group(true); H.deliver("GROUP_ROSTER_UPDATE")
        H.clock(121); H.readLayer(N,7); H.units().target=nil
        H.clock(122)
        local line=tag=="O" and ("O|1|42|100|0.200|0.300|9000|"..age.."|1|43656461722056616c65:MAGE:60")
            or ("K|1|100|0.200|0.300|9000|"..age.."|e|43656461722056616c65:MAGE:60:f")
        H.deliver("CHAT_MSG_ADDON","LEGW1",line,"GUILD","Birch Scout")
        H.yes(N.Main.trustClaims["birch scout"],"valid claim admitted")
        H.clock(181); N.Main.poll(); H.eq(N.Trust.state(N.Main.store,H.clock()),"known")
        H.clock(182); N.Main.poll()
        H.eq(N.Trust.state(N.Main.store,H.clock()),age==1 and "blind" or "known","receipt cannot renew a pre-join claim")
        H.no(N.Main.error)
    end)
end end
for _,case in ipairs({"old own","Bulo only","equal own","fresh"}) do
    H.test("Trust fresh hop: "..case,function()
        local N=H.load(); H.establish(N); H.units().target=nil; H.units().mouseover=nil; H.clock(120)
        for i,name in ipairs({"Birch Scout","Aspen Reed","Maple Grove"}) do
            H.deliver("CHAT_MSG_ADDON","LFSw","L 9000|100|h","GUILD",name)
            local host
            for _,c in ipairs(N.Main.candidates()) do if c.name==name then host=c end end
            H.yes(host); H.yes(N.Main.hopHostTo(host,N.Main.hostPreview(host)))
            H.deliver("PARTY_INVITE_REQUEST",name); H.eq(H.accepts(),i)
            H.units().party1={name=name,leader=true}; H.group(true); H.deliver("GROUP_ROSTER_UPDATE")
            H.yes(N.Main.auto.group.joinedAt,"real accepted group formed")
            if case=="fresh" or case=="Bulo only" then H.advance(1) end
            if case=="Bulo only" then
                BuloLayerForever={current="7086-7",Radar={seen={}}}; N.Main.poll(); BuloLayerForever=nil
            end
            if case=="fresh" or case=="equal own" then H.readLayer(N,7); H.units().target=nil end
            H.advance(N.Main.AUTO_FAIL+.2); H.eq(H.leaves(),i)
            H.eq(N.Trust.state(N.Main.store,H.clock()),i==3 and case=="fresh" and "blind" or "known")
            if case~="fresh" then H.eq(#N.Main.store.trust.hops,0,"old reads never count as hops") end
            H.group(false); H.units().party1=nil; H.deliver("GROUP_ROSTER_UPDATE"); H.advance(11)
        end
        H.no(N.Main.error)
    end)
end
local function claim()
    H.deliver("CHAT_MSG_ADDON","LEGW1","H|1|9000|100","GUILD","Birch Scout"); H.drain()
end
local function read(N)
    H.readLayer(N,7); H.units().target=nil; H.units().mouseover=nil
end
for _,case in ipairs({"old peer","old own","Bulo only","equal peer","equal own","fresh"}) do
    H.test("Trust fresh group: "..case,function()
        local N=H.load(); H.establish(N); H.units().target=nil; H.units().mouseover=nil
        H.roster({{"Birch Scout-TestRealm",true}}); H.deliver("GUILD_ROSTER_UPDATE")
        H.clock(100); claim()
        H.clock(120); H.units().party1={name="Birch Scout",leader=true}; H.group(true); H.deliver("GROUP_ROSTER_UPDATE")
        if case=="equal peer" then claim() end
        if case=="equal own" then read(N) end
        H.clock(121)
        if case~="old peer" and case~="equal peer" then claim() end
        if case~="old own" and case~="Bulo only" and case~="equal own" then read(N) end
        if case=="Bulo only" then BuloLayerForever={current="7086-7",Radar={seen={}}} end
        N.Main.poll(); H.clock(180); N.Main.poll(); H.eq(N.Trust.state(N.Main.store,H.clock()),"known")
        H.clock(181); N.Main.poll()
        H.eq(N.Trust.state(N.Main.store,H.clock()),case=="fresh" and "blind" or "known","only post-join peer and NPC evidence contradict")
        H.no(N.Main.error)
    end)
end
