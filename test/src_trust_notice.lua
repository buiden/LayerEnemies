local H=...
local warning="LayerEnemies: layer IDs look unreliable (parse failures); layers hidden for this session. /le blind off to override."
local recovery="LayerEnemies: layer IDs readable again; layers shown."
local function count(text,first)
    local n=0; for i=(first or 0)+1,#H.log() do if H.log()[i]==text then n=n+1 end end; return n
end
local function failRead()
    H.units().target={guid="Creature-unreadable",player=false}
    H.deliver("PLAYER_TARGET_CHANGED"); H.drain(); H.units().target=nil
end
H.test("Trust notice: automatic blind prints locally once with reason",function()
    local N=H.load(); H.establish(N); H.units().target=nil; H.units().mouseover=nil; H.clock(120)
    SendChatMessage=function() error("must never broadcast trust status") end
    local first=#H.log()
    for i=1,9 do failRead() end; H.eq(count(warning,first),0)
    failRead(); H.eq(N.Trust.state(N.Main.store,H.clock()),"blind"); H.eq(count(warning,first),1)
    for i=1,30 do failRead(); N.Main.poll() end
    H.readLayer(N,7); H.units().target=nil; N.Main.poll()
    H.eq(N.Trust.state(N.Main.store,H.clock()),"blind","detection remains sticky")
    H.clock(141); N.Main.poll()
    H.eq(count(warning,first),1); H.eq(count(recovery,first),0); H.no(N.Main.error)
end)
for _,mode in ipairs({"expiry","zone","Bulo"}) do
H.test("Trust notice: ordinary "..mode.." recovery is silent",function()
    local N=H.load(); H.establish(N); H.units().target=nil; H.units().mouseover=nil
    H.clock(311)
    if mode=="zone" then
        C_Map.GetBestMapForUnit=function() return 200 end
        H.deliver("ZONE_CHANGED_NEW_AREA"); H.drain()
    else N.Main.poll() end
    H.eq(N.Trust.state(N.Main.store,H.clock()),"unknown")
    local first=#H.log(); H.clock(312)
    if mode=="Bulo" then BuloLayerForever={current="9000-9",Radar={seen={}}}; N.Main.poll()
    else H.readLayer(N,7); H.units().target=nil end
    for i=1,5 do N.Main.poll() end
    H.eq(N.Trust.state(N.Main.store,H.clock()),"known")
    H.eq(count(recovery,first),0); H.eq(count(warning,first),0); H.no(N.Main.error)
end)
end
-- Blind remains sticky in production. These notifier controls simulate a future
-- automatic clear, not a new recovery algorithm or a manual command.
local function automaticPair(N)
    H.clock(311); for i=1,10 do failRead() end
    H.eq(count(warning),1,"automatic blind ON was actually printed")
    H.clock(312); N.Main.store.trust.blind=nil
    H.readLayer(N,7); H.units().target=nil
end
H.test("Trust notice: rapid automatic transitions defer one local line",function()
    local N=H.load(); H.establish(N); H.units().target=nil; H.units().mouseover=nil
    automaticPair(N)
    H.eq(count(recovery),0,"recovery cannot flood immediately after blind ON")
    H.clock(320); N.Main.poll(); H.eq(count(recovery),0)
    H.clock(321); N.Main.poll(); H.eq(count(recovery),1,"pending pair eventually reported")
    H.clock(332); N.Main.poll(); H.eq(count(recovery),1); H.no(N.Main.error)
end)
H.test("Trust notice: manual override cancels a pending automatic notice",function()
    local N=H.load(); H.establish(N); H.units().target=nil; H.units().mouseover=nil
    automaticPair(N)
    H.eq(count(recovery),0,"automatic recovery still rate-limited")
    SlashCmdList.LAYERENEMIES("blind on")
    H.clock(322); N.Main.poll(); H.eq(count(recovery),0,"manual transition cancels queued automatic feedback")
    SlashCmdList.LAYERENEMIES("blind off")
    H.clock(700); N.Main.poll(); H.readLayer(N,7); H.units().target=nil
    H.eq(count(recovery),0,"manual feedback consumes any automatic pair"); H.no(N.Main.error)
end)
H.test("Trust notice: same-state manual off cancels pending recovery",function()
    local N=H.load(); H.establish(N); H.units().target=nil; H.units().mouseover=nil
    automaticPair(N)
    SlashCmdList.LAYERENEMIES("blind off")
    H.eq(N.Trust.state(N.Main.store,H.clock()),"known","manual off leaves the current state unchanged")
    H.clock(321); N.Main.poll()
    H.eq(count(recovery),0,"same-state manual command cancels the pending automatic pair")
    H.no(N.Main.error)
end)
H.test("Trust notice: manual controls keep only their existing feedback",function()
    local N=H.load(); H.establish(N); H.units().target=nil; H.units().mouseover=nil; H.clock(120)
    local first=#H.log()
    for _,command in ipairs({"blind on","blind on","blind off","blind auto"}) do SlashCmdList.LAYERENEMIES(command) end
    H.eq(count(warning,first),0); H.eq(count(recovery,first),0)
    local feedback=0; for i=first+1,#H.log() do if H.log()[i]:find("LayerEnemies: layer trust ",1,true) then feedback=feedback+1 end end
    H.eq(feedback,4); H.no(N.Main.error)
end)
H.test("Trust notice: unprinted blind ON cannot have a recovery pair",function()
    local N=H.load(); local T,s=N.Trust,N.Store.new(0)
    T.read(s,100,"7086-7",7); H.eq(T.notice(s,100),nil)
    s.trustNotice.at=100 -- the local notice slot is occupied
    s.trust.blind="parse failures"; H.eq(T.notice(s,101),nil)
    s.trust.blind=nil; H.eq(T.notice(s,102),nil)
    H.eq(T.notice(s,110),nil,"no automatic blind ON was printed")
end)
H.test("Trust notice: automatic pair is consumed once",function()
    local N=H.load(); local T,s=N.Trust,N.Store.new(0)
    T.read(s,100,"7086-7",7); H.eq(T.notice(s,100),nil)
    s.trust.blind="parse failures"; H.eq(T.notice(s,101),warning)
    s.trust.blind=nil; H.eq(T.notice(s,111),recovery)
    T.read(s,112,nil,nil); H.eq(T.notice(s,112),nil)
    T.read(s,122,"9000-9",9); H.eq(T.notice(s,122),nil,"ordinary recovery cannot reuse the old pair")
end)
