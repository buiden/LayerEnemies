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
H.test("Trust notice: automatic expiry recovery prints once",function()
    local N=H.load(); H.establish(N); H.units().target=nil; H.units().mouseover=nil
    H.clock(311); N.Main.poll(); H.eq(N.Trust.state(N.Main.store,H.clock()),"unknown")
    local first=#H.log(); H.clock(312); H.readLayer(N,7); H.units().target=nil
    for i=1,5 do N.Main.poll() end
    H.eq(count(recovery,first),1); H.eq(count(warning,first),0); H.no(N.Main.error)
end)
H.test("Trust notice: rapid automatic transitions defer one local line",function()
    local N=H.load(); H.establish(N); H.units().target=nil; H.units().mouseover=nil
    H.clock(311); N.Main.poll(); H.clock(312); H.readLayer(N,7); H.units().target=nil
    local first=#H.log()
    H.clock(313); for i=1,10 do failRead() end
    H.eq(count(warning,first),0,"do not flood immediately after recovery")
    H.clock(321); N.Main.poll(); H.eq(count(warning,first),0)
    H.clock(322); N.Main.poll(); H.eq(count(warning,first),1,"pending transition eventually reported")
    N.Main.poll(); H.eq(count(warning,first),1); H.no(N.Main.error)
end)
H.test("Trust notice: manual override cancels a pending automatic notice",function()
    local N=H.load(); H.establish(N); H.units().target=nil; H.units().mouseover=nil
    H.clock(311); N.Main.poll(); H.clock(312); H.readLayer(N,7); H.units().target=nil
    local first=#H.log()
    H.clock(313); for i=1,10 do failRead() end
    H.eq(N.Trust.state(N.Main.store,H.clock()),"blind")
    H.eq(count(warning,first),0,"automatic warning still rate-limited")
    SlashCmdList.LAYERENEMIES("blind on")
    H.clock(322); N.Main.poll(); H.eq(count(warning,first),0,"manual transition cancels queued automatic feedback")
    H.eq(count(recovery,first),0); H.no(N.Main.error)
end)
H.test("Trust notice: manual controls keep only their existing feedback",function()
    local N=H.load(); H.establish(N); H.units().target=nil; H.units().mouseover=nil; H.clock(120)
    local first=#H.log()
    for _,command in ipairs({"blind on","blind on","blind off","blind auto"}) do SlashCmdList.LAYERENEMIES(command) end
    H.eq(count(warning,first),0); H.eq(count(recovery,first),0)
    local feedback=0; for i=first+1,#H.log() do if H.log()[i]:find("LayerEnemies: layer trust ",1,true) then feedback=feedback+1 end end
    H.eq(feedback,4); H.no(N.Main.error)
end)
