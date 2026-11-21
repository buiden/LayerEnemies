-- Forever build numbers come from GetBuildInfo's second return, not the TOC.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local reason="this game build hides layer IDs"
local function load(build)
    return H.load(nil,function()
        GetBuildInfo=function() return "1.15.8",build,"date",999999 end
    end)
end
local function npc(kind,key)
    local server,uid=key:match("^(%d+)%-(%d+)$")
    H.units().target={guid="Creature-0-"..server.."-0-"..uid.."-"..kind.."-ABC",player=false}
    H.deliver("PLAYER_TARGET_CHANGED"); H.drain()
end
for _,build in ipairs({"71037","71038",72000}) do
    test("Trust build: "..build.." blind at startup and immutable through manual resets",function()
        local N=load(build); local M,T=N.Main,N.Trust
        eq(T.state(M.store,H.clock()),"blind"); eq(M.store.trust.blind,reason)
        yes(table.concat(H.log()," "):find(reason,1,true)); no(table.concat(H.log()," "):find("off to override",1,true))
        for _,mode in ipairs({"off","auto","on"}) do
            SlashCmdList.LAYERENEMIES("blind "..mode)
            eq(T.state(M.store,H.clock()),"blind"); eq(M.store.trust.blind,reason)
            T.read(M.store,H.clock(),"7086-7",7)
            eq(M.store.bulo,nil); eq(M.store.zoneUID,nil); eq(T.own(M.store,H.clock()),nil)
            H.deliver("SHARD_TRANSFER"); H.drain(); eq(T.state(M.store,H.clock()),"blind")
        end
        no(M.error)
    end)
    test("Trust build: "..build.." never derives NPC or Bulo own keys",function()
        local N=load(build); local M=N.Main; H.clock(120)
        local reads=0; local parse=N.Layer.npc
        N.Layer.npc=function(...) reads=reads+1; return parse(...) end
        npc(1,"7086-7"); npc(2,"7086-7")
        eq(reads,0,"no creature layer extraction on hidden builds")
        eq(M.npcs.current,nil); eq(M.npcs.raw,nil); eq(#M.npcs.votes,0)
        eq(M.store.bulo,nil); eq(M.store.zoneUID,nil); no(M.layerKnown)
        _G.BuloLayerForever={current="9000-9",Radar={seen={}},On=function() end}
        M.poll(); eq(M.store.bulo,nil); eq(M.store.zoneUID,nil); eq(M.layerSource,"unknown")
        eq(N.Trust.bulo({current="9000-9"},nil,{},M.store),nil)
        M.applyLayer("9000-9","Bulo server id"); no(M.layerKnown); eq(M.store.bulo,nil)
        for i=1,21 do N.Trust.creature(M.store,false); N.Trust.change(M.store,120+i,tostring(i).."-7","local NPC server id") end
        eq(M.store.trust.seen,0); eq(#M.store.trust.changes,0)
        eq(N.Trust.state(M.store,H.clock()),"blind"); eq(M.store.trust.blind,reason)
        no(M.error)
    end)
    test("Trust build: "..build.." real Find Known and own O K WE stay layer-free",function()
        local N=load(build); local M=N.Main; H.clock(120)
        npc(1,"7086-7"); npc(2,"7086-7")
        _G.BuloLayerForever={current="9000-9",Radar={seen={}},On=function() end}; M.poll()
        _G.BuloLayerForever=nil
        yes(M.track("Cedar Vale")); N.Net.SHIP.we=true; N.Net.setConsent("public")
        H.deliver("CHAT_MSG_ADDON","WEFF1","H|1.6.6|100|7086|1|19","GUILD","Birch Scout")
        H.clock(121)
        for i,name in ipairs({"Cedar Vale","Aspen Reed"}) do
            H.units().target=H.player(name,"Horde","Player-1-"..(i==1 and "ABC" or "DEF"))
            H.deliver("PLAYER_TARGET_CHANGED"); H.drain()
        end
        local row=M.findRows()[1]; yes(row.at); eq(row.layer,nil); no(row.same); no(row.probably)
        local count=0
        for _,e in pairs(M.find.known.entries) do count=count+1; eq(e.layer,nil); eq(e.ownKey,nil) end
        yes(count>0)
        for _,e in pairs(M.store.localSeen) do eq(e.layer,nil); eq(e.ownKey,nil) end
        H.advance(N.Share.EVERY); M.shareTick(); M.weHello("request"); H.drain()
        local sent={O=0,C=0,H=0,K=0}
        for _,s in ipairs(H.sent()) do
            if s.prefix=="LEGW1" and s.text:sub(1,2)=="O|" then
                sent.O=sent.O+1; eq(N.Relay.decodeOwn(s.text,"Ash Example",H.clock()).layer.ns,"unknown")
            elseif s.prefix=="WEFF1" and (s.text:sub(1,2)=="C|" or s.text:sub(1,2)=="H|") then
                local d=N.Protocol.decode(s.text); eq(d.layer,0); sent[d.type]=sent[d.type]+1
            end
        end
        C_DeathRecap={HasRecapEvents=function() return true end,GetRecapEvents=function()
            return {{sourceGUID="Player-1-ABC",sourceName="Cedar",sourceFlags=0x448,overkill=10,timestamp=H.clock()}}
        end}
        H.deliver("PLAYER_DEAD"); H.advance(.3)
        for _,s in ipairs(H.sent()) do if s.prefix=="LEGW1" and s.text:sub(1,2)=="K|" then
            sent.K=sent.K+1; eq(N.OwnDeath.decode(s.text).layer,nil)
        end end
        for kind,n in pairs(sent) do yes(n>0,kind.." actually sent") end
        local held="C|1.6.6|1|100|0|7086|1|1"
        no(N.Trust.we(M.store,held,H.clock(),true):find("|7086|",1,true))
        no(M.error)
    end)
end

test("Trust build: 71036 retains exact NPC and Bulo behavior",function()
    local N=load("71036"); eq(N.Trust.state(N.Main.store,H.clock()),"unknown")
    H.establish(N); eq(N.Trust.own(N.Main.store,H.clock()),"7086-7")
    _G.BuloLayerForever={current="9000-9",Radar={seen={}},On=function() end}
    N.Main.poll(); eq(N.Trust.own(N.Main.store,H.clock()),"9000-9")
    SlashCmdList.LAYERENEMIES("blind on"); SlashCmdList.LAYERENEMIES("blind off")
    eq(N.Trust.state(N.Main.store,H.clock()),"known"); no(N.Main.error)
end)

test("Trust build: unreadable build keeps legacy behavior without inspecting secrets",function()
    for _,mode in ipairs({"missing","nil","empty","secret","throw","bad","fraction","nan"}) do
        local N=H.load(nil,function()
            GetBuildInfo=mode=="missing" and nil or function()
                if mode=="throw" then error("unreadable build") end
                local builds={empty="",secret=H.secret,bad="71037oops",fraction=71037.5,nan=0/0}
                return "1.15.8",builds[mode],"date",999999
            end
        end)
        eq(N.Trust.state(N.Main.store,H.clock()),"unknown",mode)
        H.establish(N); eq(N.Trust.own(N.Main.store,H.clock()),"7086-7"); no(N.Main.error)
    end
end)
