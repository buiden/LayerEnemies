-- Source-derived model, independently written; no donor Lua loaded/copied.
-- SyncRelay 2787-2834 learns a route before dispatch; 1438-1443 expires NH
-- only after 300 s; LeaderboardPages 2962-2969 serves unknown v8 callers.
local H=...
local eq,yes,no=H.eq,H.yes,H.no
local function test(n,f) H.test("Overlord reach: "..n,f) end
local function honest(text)
    local presence=text:match("|NH|(.*)$")
    if presence then eq(presence,"LayerEnemies 1.1.0","every send has no capability suffix") end
end
local function donor()
    local d={routes={},caps={},served=0,refused=0,keeps=0,stops=0,subs={}}
    function d:hear(text,route,target,at)
        honest(text)
        local owner,kind,body=text:match("|([^|]+)|([^|]+)|([^|]*)$")
        self.routes[owner]={route=route,target=target,at=at}
        if kind=="NH" then self.caps[owner]=at;return end
        if kind~="HR" then return end
        local v,op=body:match("^(%d+):(%u):")
        if op=="X" then self.subs[owner]=nil;self.stops=self.stops+1;return end
        if op=="K" then if self.subs[owner] then self.keeps=self.keeps+1 end;return end
        local nh=self.caps[owner]
        if v~="8" or nh and at-nh<=300 then self.refused=self.refused+1;return end
        if body:match(":%d+n%d+n%d+f:1:LK:0:0:[AH]$") then
            self.served=self.served+1;self.subs[owner]=true
        end
    end
    return d
end
local function fixture(route)
    local N=H.load();local P,Q=N.OverlordPeer,N.OverlordFeed
    local peer,st=P.new(),Q.new();peer.feed=st
    local c={now=100,wall=1800000000,me="Alice Vale",version="1.1.0",pool="global",faction="A",
        allowed=true,own=true,stopAllowed=true,groups={},guild=true,guildNames={},
        friends={},out={},tracked=function() return true end,offer=function() end}
    route=route or "BNET"
    if route=="BNET" then c.friends={{id=71,name="Birch Scout",friend=true}} end
    c.online=function(id) for _,v in ipairs(c.friends) do if v.id==id then return v end end end
    local d=donor()
    c.send=function(_,text,dist,target,prio,job)
        honest(text)
        if not P.claim(peer,job,c) then return false end
        c.out[#c.out+1]={text=text,route=dist,target=target,at=c.now,job=job,prio=prio}
        if target=="Birch Scout" or target==71 or dist=="PARTY" or dist=="GUILD" and c.guildNames["birch scout"] then d:hear(text,dist,target,c.now) end
        P.sent(peer,job,c);return true
    end
    local function hear(at)
        c.now=at
        local p={origin="Birch Scout",pool=c.pool,target=c.me,hops=0,kind="NH",payload="2.5.4~ld~lr~lp6"}
        local r=P.receive(peer,p,route,p.origin,route=="BNET" and 71 or nil,c)
        p.kind="K";p.payload="Birch Scout:#1434:21:WARRIOR:Horde:1799999900::en:0:Orc:2:B1799999900:60"
        Q.observe(st,peer,p,r,c)
    end
    return N,P,Q,peer,st,c,d,hear
end
local function requests(c,op)
    local out={};for _,v in ipairs(c.out) do if v.text:find("|HR|8:"..(op or ""),1,true) then out[#out+1]=v end end;return out
end
test("NH-free source serves and can route reply over BNET",function()
    local N,P,Q,peer,st,c,d,hear=fixture()
    hear(100);Q.tick(st,peer,c);P.tick(peer,c)
    eq(#requests(c),1,"never announced: no wait");eq(d.served,1);eq(d.refused,0);yes(d.subs[c.me])
    eq(d.routes[c.me].route,"BNET","HR teaches return route without NH")
    eq(d.caps[c.me],nil)
    c.now=500;hear(500);P.tick(peer,c);eq(d.caps[c.me],nil,"targeted NH stays suppressed")
end)
test("WHISPER group peer stays ordinary C2 without a feed",function()
    local N,P,Q,peer,st,c,d,hear=fixture("WHISPER")
    c.group="PARTY";c.groups["birch scout"]="A"
    hear(100);Q.tick(st,peer,c);P.tick(peer,c)
    eq(next(st.sources),nil);eq(#requests(c),0);eq(d.caps[c.me],100)
end)
test("donor refuses recent NH but accepts unknown after expiry",function()
    local d=donor();local base="global|id|1800000000|Birch Scout|Alice Vale|"
    d:hear(base.."HR|8:V:1799999900:1800000000n100n1f:1:LK:0:0:H","BNET",71,0);eq(d.served,1)
    d:hear(base.."NH|LayerEnemies 1.1.0","BNET",71,10)
    d:hear(base.."HR|8:V:1799999900:1800000000n100n2f:1:LK:0:0:H","BNET",71,310);eq(d.refused,1)
    d:hear(base.."HR|8:V:1799999900:1800000000n100n3f:1:LK:0:0:H","BNET",71,311);eq(d.served,2)
end)
test("guild and group NH lanes stay live and audible friend is not a source",function()
    local N,P,Q,peer,st,c,d,hear=fixture("BNET")
    c.guildNames["birch scout"]=true
    c.friends[2]={id=72,name="Cedar Friend",friend=true}
    hear(100);Q.tick(st,peer,c);P.tick(peer,c)
    eq(d.caps[c.me],100);eq(next(st.sources),nil)
    local other,guild=0,0
    for _,v in ipairs(c.out) do if v.target==72 then other=other+1 end;if v.route=="GUILD" then guild=guild+1 end end
    eq(other,1,"unselected friend still hears C2 presence");eq(guild,1)
end)

test("busy HA even for zero comparison shares NH reply gap",function()
    local N,P,Q,peer,st,c,d,hear=fixture("WHISPER")
    c.groups={};hear(100) -- not a feed source: ordinary owed NH
    local p={origin="Birch Scout",hops=0,target=c.me,kind="HR",payload="8:V:1799999900:123n4n5f:1:LK:0:0:H"}
    c.now=249;P.receive(peer,p,"WHISPER",p.origin,nil,c);eq(#c.out,1)
    c.now=250;P.receive(peer,p,"WHISPER",p.origin,nil,c);eq(#c.out,2)
    yes(c.out[2].text:find("|HA|8:R:1799999900:123n4n5f:1",1,true),"no ranking profile: busy, not equality")
    c.now=399;hear(399);eq(#c.out,2,"HA blocks NH within shared gap")
end)

test("keep at 200 then one stop on unsubscribe",function()
    local N,P,Q,peer,st,c,d,hear=fixture()
    hear(100);hear(250);hear(401);Q.tick(st,peer,c);eq(d.served,1)
    local r=peer.routes["birch scout"];local s=st.sessions["birch scout"]
    Q.receive(st,peer,{origin=r.name,pool=c.pool,target=c.me,hops=0,kind="HB",payload="8:U:1799999900:"},r,c)
    c.now=600;Q.tick(st,peer,c);eq(d.keeps,0)
    c.now=601;Q.tick(st,peer,c);eq(d.keeps,1)
    Q.cancel(st,peer,c);eq(d.stops,1);eq(next(st.sessions),nil);eq(next(st.sources),nil)
    Q.cancel(st,peer,c);eq(d.stops,1)
end)

test("stop remains owed after busy HA may have created remote subscription",function()
    local N,P,Q,peer,st,c,d,hear=fixture()
    hear(100);hear(250);hear(401);Q.tick(st,peer,c);eq(d.served,1)
    local r=peer.routes["birch scout"];local s=st.sessions["birch scout"]
    Q.receive(st,peer,{origin=r.name,pool=c.pool,target=c.me,hops=0,kind="HA",payload="8:R:"..s.epoch..":"..s.nonce..":1"},r,c)
    Q.cancel(st,peer,c);eq(d.stops,1,"request was sent even though receive lease was unarmed")
end)

test("account aliases and unreadable shared lanes cannot leak NH",function()
    local N,P,Q,peer,st,c,d,hear=fixture("BNET");hear(100)
    P.emit(peer,c,"NH",P.presence(c),"BNET",{id=71,name="Alternate Name"},"alias",120,false)
    eq(#c.out,0,"suppress the account, not just its current spelling")
    c.groups=nil;c.guildNames=nil;c.group="RAID"
    P.tick(peer,c);eq(next(st.sources),nil,"unknown shared audiences exclude friends")
    yes(#c.out>0,"C2 shared lanes remain live")
end)
test("source names suppress owed whispers including own-realm aliases",function()
    local N,P,Q,peer,st,c,d,hear=fixture("BNET");hear(100)
    P.emit(peer,c,"NH",P.presence(c),"WHISPER","birch scout-TestRealm","alias",150,true)
    eq(#c.out,0,"canonical selected name cannot be addressed")
    P.receive(peer,{origin="Birch Scout",pool=c.pool,target=c.me,hops=0,kind="NH",payload="2.5.4"},"WHISPER","Birch Scout",nil,c)
    eq(#c.out,0,"owed whisper cannot announce to the selected BNet source")
end)
local wireSerial=0
local function countNH(c)
    local n=0;for _,v in ipairs(c.out) do if v.text:find("|NH|",1,true) then n=n+1 end end;return n
end
test("a prior NH is forgotten only after continuous quiet and queue recheck",function()
    local N,P,Q,peer,st,c,d,hear=fixture("BNET")
    -- Presence was already queued before this friend became a feed source.
    peer.feed=nil
    local queued
    local send=c.send;c.send=function(_,_,_,_,_,job) queued=job;return true end
    P.emit(peer,c,"NH",P.presence(c),"BNET",{id=71,name="Birch Scout"},"bn:71",120,false)
    c.send=send;peer.feed=st
    d:hear("global|prior|1800000000|Birch Scout|Alice Vale|NH|LayerEnemies 1.1.0","BNET",71,c.now)
    P.sent(peer,queued,c)
    hear(100);no(P.claim(peer,queued,c),"already queued NH is suppressed at dispatch")
    hear(250);hear(400);Q.tick(st,peer,c);eq(#requests(c),0)
    c.now=401;Q.tick(st,peer,c);eq(d.served,1);eq(d.refused,0)
    -- Neither a new owed nor a periodic NH may reset the donor's capability clock.
    hear(550);P.tick(peer,c);eq(countNH(c),1,"only unrelated guild lane still announces")
end)
test("source count selection and rotation cannot skip silence",function()
    local N,P,Q,peer,st,c,d,hear=fixture()
    hear(100)
    for _,name in ipairs({"Cedar Friend","Maple Friend"}) do
        local id=71+#c.friends
        c.friends[#c.friends+1]={name=name,id=id,friend=true}
        P.receive(peer,{origin=name,pool=c.pool,target=c.me,hops=0,kind="NH",payload="2.5.4"},"BNET",name,id,c)
    end
    eq(N.Safe.count(st.sources),2);eq(st.sources["maple friend"],nil)
    table.remove(c.friends,1);Q.tick(st,peer,c)
    yes(st.sources["maple friend"]);eq(#requests(c),0,"replacement lacks a source-validated epoch")
end)
test("departed friend cannot deliver feed before next tick",function()
    local N,P,Q,peer,st,c,d,hear=fixture()
    hear(100);hear(250);hear(401);Q.tick(st,peer,c)
    local offered=0;c.offer=function() offered=offered+1 end;c.friends={}
    local row="kEnemy One:21:WARRIOR:Horde:en::0:60"
    local r=peer.routes["birch scout"]
    Q.receive(st,peer,{origin=r.name,target=c.me,hops=0,pool=c.pool,kind="HB",
        payload="8:U:1799999900:6:z#1434"..#row..":"..row},r,c)
    eq(offered,0,"current membership is required even before cancellation tick")
end)

local function live(route)
    local N=H.load();N.Net.SHIP.overlord=true
    Enum.GameRule={HardcoreRuleset=1,RPRuleset=2,PvPRuleset=3}
    C_GameRules={IsGameRuleActive=function(i) return i==3 end}
    C_AddOns.GetAddOnMetadata=function() return "1.1.0" end
    UnitName=function(unit) return unit=="party1" and "Birch Scout" or "Alice Vale",GetRealmName() end
    UnitFactionGroup=function() return "Alliance" end
    IsInGroup=function() return false end;IsInRaid=function() return false end;IsInGuild=function() return false end
    UnitExists=function(unit) return unit=="player" or unit=="party1" end
    GetNumGroupMembers=function() return 2 end
    N.BNet.who=function(id) return id==71 and {name="Birch Scout",faction="Horde"} end
    N.BNet.peers=function() return {{id=71,name="Birch Scout",friend=true}} end
    local function hear(kind,body,target)
        wireSerial=wireSerial+1;local id="live"..wireSerial
        local text=table.concat({"global",id,math.floor(GetServerTime()),target or "Alice Vale","Birch Scout",kind,body},"|")
        if true then H.deliver("BN_CHAT_MSG_ADDON","OverlordF","R2:Forever_global_H:BR:"..text,nil,71)
        else H.deliver("CHAT_MSG_ADDON","OverlordF","BF:"..id..":1:1:"..text,"WHISPER","Birch Scout") end
    end
    local e=GetServerTime()-100
    local function refresh()
        hear("NH","2.5.4~ld~lr~lp6")
        hear("K","Birch Scout:#1434:21:WARRIOR:Horde:"..e.."::en:0:Orc:2:B"..e..":60","*")
    end
    local function mature()
        refresh();N.Main.overlordTick(H.clock())
        H.advance(150);refresh();N.Main.overlordTick(H.clock())
        H.advance(151);refresh();N.Main.overlordTick(H.clock())
        H.advance(1)
        if route=="WHISPER" then
            local s=N.Main.overlordFeed.sessions["birch scout"];s.route="WHISPER";s.id=nil
        end -- legacy stop compatibility only, never a new whisper source
    end
    return N,mature,hear,e
end
for _,mode in ipairs({"combat","instance","pool","donor"}) do
    test("stop obeys "..mode.." gate before admission and queued dispatch",function()
        for _,when in ipairs({"before","queued"}) do
            local N,mature=live("BNET");mature()
            yes(N.Main.overlordFeed.sessions["birch scout"].asked)
            local before=#H.sent()
            if when=="queued" then N.Main.setShare(false);eq(N.BNet.queued(),1) end
            if mode=="combat" then H.combat(true)
            elseif mode=="instance" then H.instance(true)
            elseif mode=="pool" then C_GameRules=nil;GetRealmName=function() return "7102" end
            else H.loaded().Overlord=true end
            if when=="before" then N.Main.setShare(false) end
            N.Main.overlordTick(H.clock());H.advance(2)
            eq(#H.sent(),before,"all traffic, including withdrawals, is silent")
        end
    end)
end
test("unsolicited forged stop does not bypass closed privacy gates",function()
    local N=live("BNET");N.Main.setShare(false)
    no(N.BNet.send("overlord",71,"OverlordF","R2:Forever_global_A:BR:global|x|1800000000|Birch Scout|Alice Vale|HR|8:X:1799999900","owed"))
    eq(N.BNet.queued(),0)
end)
test("pending withdrawal records expire without retries",function()
    local N,P,Q,peer,st,c,d,hear=fixture("BNET")
    hear(100);hear(250);hear(401);Q.tick(st,peer,c)
    c.send=function() return true end -- accepted queue, not a client receipt
    Q.cancel(st,peer,c);eq(N.Safe.count(st.stops),1)
    c.now=462;Q.tick(st,peer,c);eq(N.Safe.count(st.stops),0)
end)
for _,route in ipairs({"WHISPER","BNET"}) do
    for _,mode in ipairs({"share","guild","switch","leave","logout"}) do
        test("live "..route.." source sends stop on "..mode,function()
            local N,mature,hear,e=live(route);mature()
            local s=N.Main.overlordFeed.sessions["birch scout"];yes(s and s.asked,"live path opened a subscription")
            for _,v in ipairs(H.sent()) do
                honest(v.text)
                if v.prefix=="OverlordF" and (v.target=="Birch Scout" or v.target==71 or v.kind=="PARTY") then no(v.text:find("|NH|",1,true)) end
            end
            if mode=="share" then N.Main.setShare(false)
            elseif mode=="guild" then N.Net.setConsent("guild")
            elseif mode=="switch" then N.Net.setSwitch("overlord",false)
            elseif mode=="logout" then H.deliver("PLAYER_LOGOUT")
            else N.BNet.peers=function() return {} end;N.Main.overlordTick(H.clock()) end
            eq(next(N.Main.overlordFeed.sessions),nil,"cancellation is immediate, not the next tick")
            H.advance(2)
            local stops=0
            for _,v in ipairs(H.sent()) do if v.text:find("|HR|8:X:"..e,1,true) then stops=stops+1 end end
            eq(stops,1,"one best-effort stop, including after privacy closes")
            eq(next(N.Main.overlordFeed.sessions),nil)
        end)
    end
end
