local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function hex(s) return (s:gsub(".",function(c) return string.format("%02x",c:byte()) end)) end
local enemy=hex("Cedar Vale")
local function setup()
    local N=H.load(); H.establish(N); H.clock(120); H.drain()
    H.units().target=nil; H.units().mouseover=nil
    SlashCmdList.LAYERENEMIES("blind on")
    return N
end

test("Trust surfaces: blind host fallback parser rejects extra coordinates",function()
    local N=setup()
    eq(N.GuildHost.parse("inv layer <LS 100 20.0,30.0 40.0,50.0>"),nil)
    eq(N.GuildHost.parse("inv layer <LS 100 120.0,30.0>"),nil)
    yes(N.GuildHost.parse("inv layer <LS 100 20.0,30.0>").blind)
end)

test("Trust surfaces: blind guild host invites unconstrained asks without layer replies",function()
    local N=H.hopLoad(); H.roster({{"Guest Cedar-TestRealm",true},{"Guest Birch-TestRealm",true}})
    H.deliver("GUILD_ROSTER_UPDATE"); yes(N.Main.setHost(true))
    local n=0; local real=N.Wire.invite
    N.Wire.invite=function(...) n=n+1; return real(...) end
    SlashCmdList.LAYERENEMIES("blind on"); local first=#H.sent()
    H.deliver("CHAT_MSG_ADDON","LayerSwap","inv layer <LS 100 want 7086-0>","WHISPER","Guest Cedar"); eq(n,0)
    H.deliver("CHAT_MSG_ADDON","LayerSwap","inv layer <LS 100 20.0,30.0>","WHISPER","Guest Cedar"); eq(n,1)
    H.advance(11)
    H.deliver("CHAT_MSG_GUILD","inv layer <LS 100 20.0,30.0>","Guest Birch"); eq(n,2)
    H.deliver("CHAT_MSG_ADDON","LEGW1","F|1","GUILD","Guest Birch"); H.advance(7)
    for i=first+1,#H.sent() do
        no(H.sent()[i].prefix=="LayerSwap","no same or layer-valued heard reply")
        no(H.sent()[i].prefix=="LEGW1" and H.sent()[i].text:sub(1,2)=="H|","no guild H advertisement")
    end
    yes(N.Main.host.on); no(N.Main.error)
end)

for _,mode in ipairs({"unknown","blind"}) do
    test("Trust surfaces: "..mode.." hides Friendly FLH ChehulNet and layer command",function()
        local N=H.load(); if mode=="blind" then H.establish(N); SlashCmdList.LAYERENEMIES("blind on") end
        H.clock(120); H.drain(); N.Net.SHIP.flh=true
        H.deliver("CHAT_MSG_ADDON","LFSw","L 9000|100|h","GUILD","Host Cedar")
        H.deliver("CHAT_MSG_ADDON","FLHNET2","HI|100|9911|1|0.1.3|1234","WHISPER","Host Birch")
        H.deliver("CHAT_MSG_ADDON","ChehulNet","CHN1|H|15|MAGE|60|Guild|100:8822","GUILD","Peer Maple")
        N.UI.toggle(); N.UI.select("friendly"); N.UI.refresh()
        eq(N.FLHMember.context(),nil); eq(N.FLH.hi(N.FLHMember.context()),nil)
        for _,r in ipairs(N.UI.pool) do if r:IsShown() then no(r.sub:GetText():find("layer 9000",1,true)); no(r.sub:GetText():find("FLH key",1,true)); no(r.sub:GetText():find("9911",1,true)) end end
        local first=#H.sent(); N.FLHMember.tick(H.clock()); H.advance(6)
        for i=first+1,#H.sent() do no(H.sent()[i].prefix=="FLHNET2") end
        local at=#H.log(); SlashCmdList.LAYERENEMIES("layer")
        eq(#H.log(),at+1); yes(H.log()[at+1]:find("layer IDs are not readable on this client",1,true))
        for _,r in ipairs(N.ChehulNet.rows()) do eq(r.rel,nil); if mode=="blind" then eq(r.zone,nil) end end
        no(N.Main.error)
    end)
end

for _,network in ipairs({"O","R","WE","HH"}) do
    test("Trust surfaces: blind "..network.." receipt retains names/count/position, layer unknown",function()
        local N=setup(); N.Main.track("Cedar Vale"); H.clock(121)
        if network=="O" then
            H.deliver("CHAT_MSG_ADDON","LEGW1","O|1|42|100|0.200|0.300|9000|0|1|"..enemy..":MAGE:60","GUILD","Birch Scout")
        elseif network=="R" then
            H.deliver("CHAT_MSG_ADDON","LEGW1","R|1|we|group|"..hex("Birch Scout").."|42|100|200|300|1|s|9000|0|"..enemy..":MAGE:60","GUILD","Carrier Maple")
        elseif network=="WE" then
            H.deliver("CHAT_MSG_ADDON","WEFF1","H|1.6.6|100|9000|1|19","GUILD","Birch Scout")
            H.deliver("CHAT_MSG_ADDON","WEFF1","E|42|1|1|abc:H:60|100","GUILD","Birch Scout")
            H.deliver("CHAT_MSG_ADDON","WEFF1","C|42|100|0.200|0.300|9000|1|100","GUILD","Birch Scout")
        else GetServerTime=function() return 100 end; H.deliver("CHAT_MSG_ADDON","HeadHunter","1AP:2s;2s;5k;8c;abc;Cedar Vale/M/60;9000","WHISPER","Birch Scout") end
        local _,r=next(N.Main.store.reports); yes(r,"receipt admitted")
        eq(r.record.layer.ns,"unknown"); eq(r.record.layer.value,nil); eq(r.record.x,.2); eq(r.record.count,1)
        local own=N.Store.own(N.Main.store,H.clock()); eq(N.Record.relation(r.record,own),"unknown")
        no(N.Main.findText(N.Main.findRows()[1]):find("9000",1,true)); no(N.Main.error)
    end)
end

test("Trust surfaces: WeOut remote rebuild keeps the sender claim in blind",function()
    local N=setup()
    local d=N.Protocol.decode("C|42|100|0.200|0.300|9000|1|100")
    local text=N.WeOut.rebuild(d); yes(text)
    N.Net.SHIP.we=true; yes(N.Wire.send("WEFF1",text,"GUILD",nil,{net="we",prio="own"}))
    eq(N.Protocol.decode(H.sent()[#H.sent()].text).layer,9000)
end)

test("Trust surfaces: blind host and Overlord readers retain names not keys",function()
    local N=setup()
    Enum.GameRule={HardcoreRuleset=1,RPRuleset=2,PvPRuleset=3}
    C_GameRules={IsGameRuleActive=function(rule) return rule==3 end}
    H.deliver("CHAT_MSG_ADDON","LFSw","L 9000|100|h","GUILD","Host Cedar")
    H.deliver("CHAT_MSG_ADDON","FLHNET2","HI|100|9911|1|0.1.3|1234","WHISPER","Host Birch")
    local hosts=N.Main.candidates(); eq(#hosts,2)
    for _,r in ipairs(hosts) do eq(r.layer,nil); eq(r.flhKey,nil) end
    H.deliver("CHAT_MSG_ADDON","OverlordF","GW:1:Enemy Guild:H:77:6:#100:12345:"..math.floor(GetServerTime()),"PARTY","Elm Grove")
    local rows=N.Main.reportedRows(); eq(#rows,1)
    eq(rows[1].guild,"Enemy Guild"); eq(rows[1].kills,77); eq(rows[1].members,6); eq(rows[1].layer,nil)
    no(N.Main.overlordText(rows[1]):find("12345",1,true)); no(N.Main.error)
end)

test("Trust surfaces: Bulo source feeds Trust but never overrides blindness",function()
    local N=setup(); BuloLayerForever={current="9999-99",Radar={seen={}}}; N.Main.poll()
    eq(N.Trust.own(N.Main.store,H.clock()),nil); eq(N.HopBar.layerText(),"layer hidden")
    no(N.Main.error)
end)
