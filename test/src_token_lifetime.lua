local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function load(saved)
    return H.load(saved,function() GetBuildInfo=function() return "x","71037","d",16001 end end)
end
for _,event in ipairs({"SHARD_TRANSFER","ZONE_CHANGED","PLAYER_ENTERING_WORLD"}) do
    test("Parity lifetime: drop on "..event,function()
        local N=load(); local M=N.Main
        yes(N.Trust.adopt(M.store,H.clock(),"8000-8",100,"host","Host Cedar"))
        if event=="ZONE_CHANGED" then N.Adapters.location=function() return 200,.2,.3 end end
        H.deliver(event,false,false); H.drain()
        eq(N.Trust.state(M.store,H.clock()),"blind"); eq(M.store.bulo,nil); no(M.error)
    end)
end
H.test("Parity lifetime: save only at logout, restore only reload same identity zone and fresh clock",function()
    local N=load(); local M=N.Main; H.wall(1000)
    yes(N.Trust.adopt(M.store,H.clock(),"8000-8",100,"peer","Host Cedar"))
    no(LayerEnemiesDB.layerToken); H.deliver("PLAYER_LOGOUT")
    local save=LayerEnemiesDB.layerToken; yes(save,"logout token"); eq(save.id,"8000-8"); eq(save.at,1000)
    for _,case in ipairs({"reload","login","old","future","character","zone","missing","secret"}) do
        local copy={}; for k,v in pairs(save) do copy[k]=v end
        if case=="old" then copy.at=879 elseif case=="future" then copy.at=1001
        elseif case=="character" then copy.who="Other Scout" elseif case=="zone" then copy.zone=200 end
        local X=load({layerToken=copy}); H.wall(1000)
        if case=="missing" then H.deliver("PLAYER_ENTERING_WORLD")
        elseif case=="secret" then H.deliver("PLAYER_ENTERING_WORLD",false,H.secret)
        else H.deliver("PLAYER_ENTERING_WORLD",case=="login",case~="login") end
        H.drain(); eq(X.Trust.state(X.Main.store,H.clock()),case=="reload" and "known" or "blind",case)
        no(LayerEnemiesDB.layerToken,"restore consumed"); no(X.Main.error)
    end
end)
H.test("Parity review logout: unresolved host group cannot save a token",function()
    local N=load(); local M=N.Main; H.clock(120); H.wall(1000)
    yes(N.Trust.adopt(M.store,H.clock(),"7000-7",100,"peer","Host Birch"))
    LayerSwapDB={book={["Host Cedar"]={layer="8000-8",zone=100,at=1000,host=true}}}
    yes(M.hopAny())
    H.deliver("CHAT_MSG_ADDON","LayerSwap","heard Me|8000-8|100|h","WHISPER","Host Cedar")
    H.deliver("PARTY_INVITE_REQUEST","Host Cedar")
    H.group(true); H.units().party1={name="Host Cedar",leader=true,player=true}
    H.deliver("GROUP_ROSTER_UPDATE")
    yes(M.auto.group and M.auto.group.joinedAt); no(M.auto.group.transfer)
    H.deliver("PLAYER_LOGOUT")
    eq(LayerEnemiesDB.layerToken,nil,"unresolved host group must not save old equality")
    no(M.error)
end)
H.test("Parity review restore: grouped reload cannot restore or answer same",function()
    local N=load(); H.wall(1000)
    yes(N.Trust.adopt(N.Main.store,H.clock(),"7000-7",100,"peer","Host Birch"))
    local save=N.Trust.save(N.Main.store,H.wall(),N.Adapters.ownIdentity())
    for _,kind in ipairs({"grouped","unreadable"}) do
        N=load({layerToken=save}); H.wall(1000)
        H.group(true); H.units().party1={name="Host Cedar",leader=true,player=true}
        if kind=="unreadable" then N.Adapters.grouped=function() return nil end end
        H.deliver("PLAYER_ENTERING_WORLD",false,true); H.drain()
        eq(N.Trust.state(N.Main.store,H.clock()),"blind",kind)
        local own=N.Main.hostOwn(); own.member=true
        local req=N.GuildHost.parse("inv layer <LS 100 not 7000-7 r2>"); req.name="Cedar Scout"
        local st=N.GuildHost.new(); st.on=true
        local verdict,reply=N.GuildHost.decide(st,req,own,H.clock())
        no(verdict=="same" or reply=="same","reload cannot emit false same")
        no(N.Main.error)
    end
end)
H.test("Parity lifetime: expiry does not expire token; missing live zone drops permanently",function()
    local N=load(); local M=N.Main
    yes(N.Trust.adopt(M.store,0,"8000-8",100,"peer","Host Cedar"))
    H.clock(1000); M.poll(); eq(N.Trust.state(M.store,1000),"known")
    N.Adapters.location=function() return nil end; M.poll(); eq(N.Trust.state(M.store,1000),"blind")
    N.Adapters.location=function() return 100,.2,.3 end; M.poll(); eq(N.Trust.state(M.store,1000),"blind")
end)
