-- Replays the independent held-popup order, without allowing silent closure.
local H=...
for _,mode in ipairs({"known","unknown","blind","automatic","group event"}) do
    H.test("Trust held popup: "..mode,function()
        local N=H.load(); H.establish(N)
        H.units().target=nil; H.units().mouseover=nil
        if mode=="group event" then
            H.roster({{"Birch Scout-TestRealm",true}}); H.deliver("GUILD_ROSTER_UPDATE")
            H.clock(250); H.units().party1={name="Birch Scout",leader=true}; H.group(true); H.deliver("GROUP_ROSTER_UPDATE")
            H.clock(251); H.readLayer(N,7); H.units().target=nil
            H.deliver("CHAT_MSG_ADDON","LEGW1","H|1|9000|100","GUILD","Birch Scout")
        end
        H.clock(300)
        H.yes(N.Main.track("Cedar Vale"))
        H.units().target=H.player("Cedar Vale","Horde","Player-1-ABC")
        H.deliver("PLAYER_TARGET_CHANGED"); H.drain(); H.units().target=nil
        H.yes(N.Popup.frame:IsShown()); H.yes(N.Popup.rows[4]:GetText():find("YOUR layer",1,true))
        local data,generation=N.Popup.data,N.Popup.generation
        if mode=="blind" then SlashCmdList.LAYERENEMIES("blind on")
        elseif mode=="unknown" then H.clock(311); N.Main.poll()
        elseif mode=="group event" then
            H.clock(311)
            H.deliver("CHAT_MSG_ADDON","LEGW1","H|1|9000|100","GUILD","Birch Scout")
            H.eq(N.Trust.state(N.Main.store,H.clock()),"blind")
            H.eq(N.Popup.rows[4]:GetText(),N.Main.findRows()[1].status,"event-time transition repaints immediately")
        elseif mode=="automatic" then
            for i=1,10 do
                H.units().target={guid="Creature-unreadable",player=false}
                H.deliver("PLAYER_TARGET_CHANGED"); H.drain()
            end
            H.units().target=nil
        end
        H.advance(1)
        H.yes(N.Popup.frame:IsShown(),"same popup remains usable")
        H.eq(N.Popup.data,data); H.eq(N.Popup.generation,generation,"refresh does not extend lifetime")
        H.yes(N.Popup.rows[1]:GetText():find("Cedar Vale",1,true)); H.eq(N.Popup.rows[2]:GetText(),"Ashenvale")
        H.eq(N.Popup.rows[4]:GetText(),N.Main.findRows()[1].status,"held status is the live projection")
        if mode~="known" then H.no(N.Popup.rows[4]:GetText():find("layer",1,true)) end
        H.clock(330); H.drain(); H.no(N.Popup.frame:IsShown(),"original timeout retained")
        H.no(N.Main.error)
    end)
end
