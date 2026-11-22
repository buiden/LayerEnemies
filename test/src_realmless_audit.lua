-- Local realm audit: no remote realm or ruleset is invented.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function setup(mode)
    return H.load(nil,function()
        local unit=UnitName
        UnitName=function(u) if u=="player" then return "Ash Example" end; return unit(u) end
        GetRealmName=function() if mode=="empty" then return "" end end
        GetNormalizedRealmName=GetRealmName
    end)
end
for _,mode in ipairs({"empty","nil"}) do
    test("Realm audit: "..mode.." local sightings retain hash hints Find and Known",function()
        local N=setup(mode); H.clock(120); yes(N.Main.track("Cedar Vale"))
        H.units().target=H.player("Cedar Vale","Horde","Player-1-ABC"); H.units().target.realm=nil
        H.deliver("PLAYER_TARGET_CHANGED"); H.drain()
        yes(N.Main.findRows()[1].at); yes(next(N.Main.find.known.entries)); eq(N.Main.find.home,nil)
        eq(N.Store.possible(N.Main.store,N.Hash.player("Cedar Vale",nil)),"possible identity: Cedar Vale")
        N.Find.home(N.Main.find,"8123"); eq(N.Main.find.home,"8123"); yes(N.Main.findRows()[1].at)
        no(N.Main.error)
    end)
    test("Realm audit: "..mode.." FLH owed reply uses existing unknown realm atom",function()
        local N=setup(mode); H.establish(N); H.clock(120); N.Net.SHIP.flh=true
        local meta=C_AddOns.GetAddOnMetadata
        C_AddOns.GetAddOnMetadata=function(addon,key) if addon=="LayerEnemies" and key=="Version" then return "1.3.2" end; return meta(addon,key) end
        H.deliver("CHAT_MSG_ADDON","FLHNET2","WP|42|1234|0.1.3|100|8|1","WHISPER","Birch Scout")
        local count=0
        for _,s in ipairs(H.sent()) do if s.prefix=="FLHNET2" then
            count=count+1; eq(s.target,"Birch Scout"); local d=N.FLH.decode(s.text)
            yes(d); eq(d.cmd,"WR"); eq(d.realm,"?"); eq(d.key,"7")
        end end
        eq(count,1); no(N.Main.error)
    end)
    test("Realm audit: "..mode.." peer membership stays realm-less without merging explicit worlds",function()
        local N=setup(mode); local A=N.Adapters
        eq(A.peerIdentity("Birch Scout"),"birch scout")
        eq(A.peerIdentity("Birch Scout-8123"),"birch scout-8123")
        eq(A.peerIdentity("Birch Scout","8124"),"birch scout-8124")
        eq(A.peerIdentity("Birch Scout-8123","8124"),nil)
        eq(A.peerIdentity("Birch Scout",""),"birch scout","an empty realm is realm-less")
        eq(A.peerIdentity("Birch Scout",nil),"birch scout","a nil realm is realm-less")
        for _,bad in ipairs({5,true,{},string.rep("x",61),"Bad\1Realm","Bad|Realm"}) do
            eq(A.peerIdentity("Birch Scout",bad),nil,"unreadable realm "..tostring(type(bad)))
        end
        local secret=issecretvalue
        local hidden={}
        issecretvalue=function(v) return v==hidden end
        eq(A.peerIdentity("Birch Scout",hidden),nil,"secret realm")
        issecretvalue=secret
        H.roster({{"Birch Scout",true}}); H.deliver("GUILD_ROSTER_UPDATE")
        yes(A.guildNames(A.peerIdentity)["birch scout"])
        H.units().party1={name="Birch Scout",player=true,faction="Alliance"}; H.group(true)
        yes(A.groupNames()["birch scout"])
        H.units().party1.realm=""; yes(A.groupNames()["birch scout"],"empty unit realm is realm-less")
        H.units().party1.realm="Bad\1Realm"; eq(A.groupNames(),nil,"unreadable unit realm stays unreadable")
        H.units().party1.realm=nil; no(N.Main.error)
    end)
    test("Realm audit: "..mode.." channels and WarBoard use readable rules not a missing realm",function()
        local N=setup(mode)
        _G.Enum={GameRule={HardcoreRuleset=1,RPRuleset=2,PvPRuleset=3}}
        for _,v in ipairs({{false,false,true,"PvP","pvp"},{false,false,false,"PvE","normal"},
            {false,true,true,"RPPvP","rppvp"},{false,true,false,"RP","rp"}}) do
            _G.C_GameRules={IsGameRuleActive=function(rule) return v[rule] end}
            eq(N.Directory.channel("we"),"WarEffort"..v[4].."A")
            local c=N.Adapters.warboardContext(true); yes(c); eq(c.rs,v[5])
        end
        _G.C_GameRules.IsGameRuleActive=function() return nil end
        eq(N.Directory.channel("we"),nil,"missing rules are not guessed")
        eq(N.Adapters.warboardContext(true),nil)
        no(N.Main.error)
    end)
    test("Realm audit: "..mode.." Wanted BNet skips only unavailable local realm comparison",function()
        local N=setup(mode); N.Net.SHIP.wanted=true
        N.BNet.who=function() return {name="Other Peer",realm="8123",faction="Horde"} end
        local payload=N.Codec.addonEncode(N.Codec.deflateStored(N.Codec.lsWrite({k="L",z={{m=100,l="1-0-6",n=3}}})))
        H.deliver("BN_CHAT_MSG_ADDON","WNTDB",payload,"WHISPER",71)
        yes(N.Wanted.state.far[71]); eq(next(N.Main.find.known.entries),nil)
        GetRealmName=function() return "8124" end
        H.deliver("BN_CHAT_MSG_ADDON","WNTDB",payload,"WHISPER",72)
        eq(N.Wanted.state.far[72],nil,"readable realm mismatch still refused")
        no(N.Main.error)
    end)
    test("Realm audit: "..mode.." Directory and guild hosting keep self guards",function()
        local N=setup(mode); N.Net.SHIP.hh=true; N.Net.setConsent("public")
        H.channelMembers("HeadHunterSync",{"Ash Example","Birch Scout"}); H.advance(10); H.advance(3.1)
        local peers=N.Directory.members("hh"); yes(peers); eq(#peers,1); eq(peers[1],"Birch Scout")
        H.roster({{"Birch Scout",true},{"Ash Example",true}}); H.deliver("GUILD_ROSTER_UPDATE")
        SlashCmdList.LAYERENEMIES("blind on"); SlashCmdList.LAYERENEMIES("host on")
        local calls=0; local invite=C_PartyInfo.InviteUnit
        C_PartyInfo.InviteUnit=function(name) calls=calls+1; eq(name,"Birch Scout") end
        H.deliver("CHAT_MSG_ADDON","LayerSwap","inv layer <LS 100 25.0,75.0>","WHISPER","Ash Example")
        eq(calls,0)
        H.deliver("CHAT_MSG_ADDON","LayerSwap","inv layer <LS 100 25.0,75.0>","WHISPER","Birch Scout")
        eq(calls,1); C_PartyInfo.InviteUnit=invite; no(N.Main.error)
    end)
end
