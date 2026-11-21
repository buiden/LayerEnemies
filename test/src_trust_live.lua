local H=...
local function npc(kind,key)
    local server,uid=key:match("^(%d+)%-(%d+)$")
    H.units().target={guid=server and ("Creature-0-"..server.."-0-"..uid.."-"..kind.."-ABC") or "Creature-unreadable",player=false}
    H.deliver("PLAYER_TARGET_CHANGED"); H.drain()
end
local function sight(name,guid)
    H.units().target=H.player(name,"Horde",guid)
    H.deliver("PLAYER_TARGET_CHANGED"); H.drain(); H.units().target=nil
end
local function ownLayer(s)
    return s.text:match("^O|1|[^|]+|[^|]+|[^|]+|[^|]+|([^|]*)|")
end
local function triggerPrivate(N)
    H.roster({{"Birch Scout-TestRealm",true}}); H.deliver("GUILD_ROSTER_UPDATE")
    H.units().party1={name="Birch Scout",leader=true}; H.group(true); H.deliver("GROUP_ROSTER_UPDATE")
    H.advance(1); npc(3,"7086-7"); H.units().target=nil
    H.deliver("CHAT_MSG_ADDON","LEGW1","H|1|9000|100","GUILD","Birch Scout"); H.drain()
    H.advance(59); H.eq(N.Trust.state(N.Main.store,H.clock()),"known")
    H.advance(1); N.Main.poll(); H.eq(N.Trust.state(N.Main.store,H.clock()),"blind")
end
local function triggerConstant(N,rotate)
    for i,name in ipairs({"Birch Scout","Aspen Reed","Maple Grove"}) do
        H.deliver("CHAT_MSG_ADDON","LFSw","L 9000|100|h","GUILD",name)
        local host
        for _,c in ipairs(N.Main.candidates()) do if c.name==name then host=c end end
        H.yes(host); H.yes(N.Main.hopHostTo(host,N.Main.hostPreview(host)))
        H.deliver("PARTY_INVITE_REQUEST",name); H.eq(H.accepts(),i)
        H.units().party1={name=name,leader=true}; H.group(true); H.deliver("GROUP_ROSTER_UPDATE")
        H.advance(1)
        if rotate then npc(i*2+3,"7086-"..(7+i)); npc(i*2+4,"7086-"..(7+i))
        else npc(i*2+3,"7086-7") end
        H.units().target=nil
        H.advance(N.Main.AUTO_FAIL+.2); H.eq(H.leaves(),i)
        H.eq(N.Trust.state(N.Main.store,H.clock()),i==3 and not rotate and "blind" or "known")
        H.group(false); H.units().party1=nil; H.deliver("GROUP_ROSTER_UPDATE"); H.advance(11)
    end
end
H.test("Trust live: real same-prefix suffix moves are not constant-ID hops",function()
    local N=H.load(); H.establish(N); H.clock(120)
    triggerConstant(N,true); H.eq(N.Trust.state(N.Main.store,H.clock()),"known"); H.no(N.Main.error)
end)
for _,case in ipairs({"manual","zero","unparseable","churn","constant","private"}) do
    H.test("Trust live: "..case.." hides own UI and sends layer-free O C H K",function()
        local N=H.load(); local M=N.Main
        if case~="zero" and case~="unparseable" then H.establish(N) end
        H.units().target=nil; H.units().mouseover=nil
        H.clock(120); H.drain(); H.yes(M.track("Cedar Vale"))
        sight("Dune Willow","Player-1-BAC")
        local before=M.store.localSeen["Player-1-BAC"]; H.yes(before)
        local serial=M.store.serial
        if case=="manual" then SlashCmdList.LAYERENEMIES("blind on")
        elseif case=="private" then triggerPrivate(N)
        elseif case=="constant" then triggerConstant(N)
        elseif case=="churn" then
            for i=1,3 do H.clock(120+i); npc(i*2+1,(8000+i).."-"..(8+i)); npc(i*2+2,(8000+i).."-"..(8+i)) end
        else for i=1,20 do npc(i,case=="zero" and "0-0" or "bad") end end
        H.eq(N.Trust.state(M.store,H.clock()),"blind")
        H.eq(M.store.serial,serial,"trigger is not a boundary")
        H.eq(M.store.localSeen["Player-1-BAC"],before,"pre-trigger sighting retained")
        H.eq(N.Trust.own(M.store,H.clock()),nil)
        N.UI.toggle(); H.eq(N.UI.layer:GetText(),""); H.no(N.UI.layer:IsShown())
        H.yes(N.UI.meta:GetText():find("layer IDs unreadable",1,true)); H.eq(N.HopBar.layerText(),"layer hidden")
        local first=#H.sent(); N.Net.SHIP.we=true; N.Net.setConsent("public")
        H.deliver("CHAT_MSG_ADDON","WEFF1","H|1.6.6|100|7086|1|19","GUILD","Birch Scout")
        H.clock(H.clock()+1); sight("Cedar Vale","Player-1-ABC"); sight("Aspen Reed","Player-1-DEF")
        local row=M.findRows()[1]; H.no(row.same); H.no(row.probably)
        local text=M.findText(row):lower(); H.no(text:find("layer",1,true)); H.yes(text:find("ashenvale",1,true))
        M.findAlerts(); H.yes(table.concat(H.log()," "):find("Cedar Vale",1,true),"Find alert still names enemy")
        H.yes(N.Popup.frame:IsShown()); H.eq(N.Popup.rows[2]:GetText(),"Ashenvale")
        for _,r in ipairs(N.Popup.rows) do H.no(r:GetText():lower():find("layer",1,true)) end
        H.roster({{"Caller Grove-TestRealm",true}}); H.deliver("GUILD_ROSTER_UPDATE")
        H.deliver("CHAT_MSG_ADDON","LEGW1","K|1|100|0.200|0.300|9000|0|e|43656461722056616c65:MAGE:60:f","GUILD","Caller Grove")
        H.yes(N.CallUI.frame and N.CallUI.frame:IsShown(),"Call window survives")
        H.advance(N.Share.EVERY); M.shareTick(); M.weHello("request"); H.drain()
        local counts={O=0,C=0,H=0}
        for i=first+1,#H.sent() do
            local s=H.sent()[i]
            if s.prefix=="LEGW1" and s.text:sub(1,2)=="O|" then H.eq(ownLayer(s),""); counts.O=counts.O+1
            elseif s.prefix=="WEFF1" and (s.text:sub(1,2)=="C|" or s.text:sub(1,2)=="H|") then
                local d=N.Protocol.decode(s.text); H.eq(d.layer,0); counts[s.text:sub(1,1)]=counts[s.text:sub(1,1)]+1
            end
        end
        H.yes(counts.O>0,"O sent"); H.yes(counts.C>0,"C sent"); H.yes(counts.H>0,"WE H sent")
        C_DeathRecap={HasRecapEvents=function() return true end,GetRecapEvents=function()
            return {{sourceGUID="Player-1-ABC",sourceName="Cedar",sourceFlags=0x448,overkill=10,timestamp=H.clock()}}
        end}
        first=#H.sent(); H.deliver("PLAYER_DEAD"); H.advance(.3)
        local n=0
        for i=first+1,#H.sent() do local s=H.sent()[i]
            if s.prefix=="LEGW1" and s.text:sub(1,2)=="K|" then n=n+1; H.eq(N.OwnDeath.decode(s.text).layer,nil) end
        end
        H.eq(n,1,"own-death K survives"); H.no(M.error)
        H.deliver("SHARD_TRANSFER"); H.drain()
        H.yes(M.store.serial>serial); H.eq(next(M.store.localSeen),nil); H.eq(next(M.store.reports),nil)
        H.eq(N.Trust.state(M.store,H.clock()),"blind","real transfer wipes but does not reset blind")
    end)
end
