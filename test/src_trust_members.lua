-- Peer admission is distinct from our initial group join. Real roster events.
local H=...
local function clear() H.units().target=nil; H.units().mouseover=nil end
local function claim() H.deliver("CHAT_MSG_ADDON","LEGW1","H|1|9000|100","GUILD","Birch Scout"); H.drain() end
for _,case in ipairs({"old","equal","fresh","rejoin","already present"}) do
    H.test("Trust member join: "..case,function()
        local N=H.load(); H.establish(N); clear()
        H.roster({{"Birch Scout-TestRealm",true}}); H.deliver("GUILD_ROSTER_UPDATE")
        H.clock(100); H.units().party1={name="Oak Walker",leader=true}
        if case=="already present" then H.units().party2={name="Birch Scout"} end
        H.group(true); H.deliver("GROUP_ROSTER_UPDATE")
        H.clock(101); H.readLayer(N,7); clear()
        H.clock(110); claim()
        H.clock(120); H.units().party2={name="Birch Scout"}; H.deliver("GROUP_ROSTER_UPDATE")
        if case=="equal" then claim() end
        H.clock(121); H.readLayer(N,7); clear()
        if case=="fresh" or case=="rejoin" then claim() end
        if case=="rejoin" then
            H.clock(130); H.units().party2=nil; H.deliver("GROUP_ROSTER_UPDATE")
            H.clock(140); H.units().party2={name="Birch Scout"}; H.deliver("GROUP_ROSTER_UPDATE")
        end
        H.clock(case=="rejoin" and 201 or 181); N.Main.poll()
        H.eq(N.Trust.state(N.Main.store,H.clock()),(case=="fresh" or case=="already present") and "blind" or "known",
            "only a claim after both members joined contradicts")
        H.no(N.Main.error)
    end)
end
H.test("Trust member join: pure peer admission bounds",function()
    local N=H.load(); local T=N.Trust
    for _,peerAt in ipairs({false,110,111,109}) do
        local s=N.Store.new(0); T.read(s,121,"7086-7",7); T.npc(s,121,"7086-7")
        T.group(s,121,"birch scout","9000",true,100,110,peerAt or nil)
        H.eq(s.trust.group~=nil,peerAt==109,"claim must follow peer admission strictly")
    end
end)
