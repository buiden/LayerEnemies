local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function start()
    local N=H.load(nil,function() GetBuildInfo=function() return "x","71037","d",16001 end end)
    H.clock(120); H.wall(1000)
    yes(N.Trust.adopt(N.Main.store,120,"987654-876543",100,"peer","Host Cedar"))
    return N,N.Main
end
H.test("Parity equality: numeric consumers and outgoing fields stay masked with token",function()
    local N,M=start(); local T=N.Trust
    local record={src="we",layer={ns="server",value="9000"},zone=100}
    eq(T.record(M.store,record,120).layer.ns,"unknown")
    eq(T.we(M.store,"H|1.6.6|100|987654|1|19",120,true),"H|1.6.6|100|0|1|19")
    eq(N.Record.relation(record,N.Store.own(M.store,120)),"unknown")
    yes(M.track("Birch Scout")); H.clock(121)
    H.units().target=H.player("Birch Scout","Horde","Player-1-ABC")
    H.deliver("PLAYER_TARGET_CHANGED"); H.drain()
    for _,e in pairs(M.store.localSeen) do eq(e.layer,nil); eq(e.ownKey,nil) end
    for _,e in pairs(M.find.known.entries) do eq(e.layer,nil); eq(e.ownKey,nil) end
    eq(M.findRows()[1].layer,nil); no(M.findRows()[1].same)
    N.Net.SHIP.we=true; N.Net.setConsent("public"); H.advance(N.Share.EVERY); M.shareTick(); M.weHello("request"); H.drain()
    for _,s in ipairs(H.sent()) do
        if s.prefix=="WEFF1" and (s.text:sub(1,2)=="C|" or s.text:sub(1,2)=="H|") then eq(N.Protocol.decode(s.text).layer,0) end
        if s.prefix=="LEGW1" and s.text:sub(1,2)=="O|" then eq(N.Relay.decodeOwn(s.text,"Ash Example",H.clock()).layer.ns,"unknown") end
    end
    no(M.error)
end)
H.test("Parity equality: UI and slash show shared host, never numbers or other-layer claims",function()
    local N,M=start()
    eq(N.HopBar.layerText(),"layer: shared with Host Cedar")
    N.UI.toggle(); N.UI.refresh(); no(N.UI.layer:IsShown()); yes(N.UI.meta:GetText():find("layer: shared with Host Cedar",1,true))
    local mark=#H.log()
    for _,cmd in ipairs({"status","layers","hosts","list","reports"}) do SlashCmdList.LAYERENEMIES(cmd) end
    for i=mark+1,#H.log() do local s=H.log()[i]; no(s:find("987654",1,true)); no(s:find("876543",1,true)); no(s:find("other layers",1,true)) end
end)
H.test("Parity equality: exact equal host excluded, unequal token not proof; request leaves full token",function()
    local N,M=start()
    LayerSwapDB={book={
        ["Host Birch"]={layer="987654-876543",zone=100,at=1000,host=true},
        ["Host Elm"]={layer="987654-123",zone=100,at=1000,host=true}}}
    local p=M.hopAnyPreview(); eq(p.label,"Hop (shared)"); eq(p.candidate.name,"Host Elm")
    yes(M.hopAny(p)); local found=false
    for _,s in ipairs(H.sent()) do if s.prefix=="LayerSwap" then found=true; eq(s.text,"inv layer <LS 100 not 987654-876543 r2 25.0,75.0>") end end
    yes(found); eq(#H.whoCalls(),0); no(M.error)
end)
