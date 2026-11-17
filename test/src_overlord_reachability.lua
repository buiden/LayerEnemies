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
        allowed=true,own=true,stopAllowed=true,group="PARTY",groups={["birch scout"]=true},guild=true,guildNames={},
        friends={},out={},tracked=function() return true end,offer=function() end}
    route=route or "WHISPER"
    if route=="BNET" then c.friends={{id=71,name="Birch Scout",friend=true}} end
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
for _,route in ipairs({"WHISPER","BNET"}) do
    test("NH-free source serves and can route reply over "..route,function()
        local N,P,Q,peer,st,c,d,hear=fixture(route)
        hear(100);Q.tick(st,peer,c);P.tick(peer,c)
        eq(d.caps[c.me],nil,"no initial owed or periodic NH to feed source")
        eq(#requests(c),0)
        hear(250);Q.tick(st,peer,c);P.tick(peer,c)
        hear(400);Q.tick(st,peer,c);eq(#requests(c),0,"known capability still exists at exactly 300")
        c.now=401;Q.tick(st,peer,c);P.tick(peer,c)
        eq(#requests(c),1);eq(d.served,1);eq(d.refused,0);yes(d.subs[c.me])
        eq(d.routes[c.me].route,route,"HR teaches return route without NH")
        eq(d.caps[c.me],nil)
        c.now=500;hear(500);P.tick(peer,c);eq(d.caps[c.me],nil,"owed NH stays suppressed")
    end)
end
test("donor refuses recent NH but accepts unknown after expiry",function()
    local d=donor();local base="global|id|1800000000|Birch Scout|Alice Vale|"
    d:hear(base.."HR|8:V:1799999900:1800000000n100n1f:1:LK:0:0:H","BNET",71,0);eq(d.served,1)
    d:hear(base.."NH|LayerEnemies 1.1.0","BNET",71,10)
    d:hear(base.."HR|8:V:1799999900:1800000000n100n2f:1:LK:0:0:H","BNET",71,310);eq(d.refused,1)
    d:hear(base.."HR|8:V:1799999900:1800000000n100n3f:1:LK:0:0:H","BNET",71,311);eq(d.served,2)
end)
test("source guild and group NH lanes suppressed while other peers keep presence",function()
    local N,P,Q,peer,st,c,d,hear=fixture("BNET")
    c.guildNames["birch scout"]=true
    c.friends[2]={id=72,name="Cedar Friend",friend=true}
    hear(100);Q.tick(st,peer,c);P.tick(peer,c)
    eq(d.caps[c.me],nil)
    local other=0
    for _,v in ipairs(c.out) do if v.target==72 then other=other+1 end;no(v.route=="GUILD" or v.route=="PARTY") end
    eq(other,1,"unselected friend still hears C2 presence")
end)

test("busy HA even for zero comparison shares NH reply gap",function()
    local N,P,Q,peer,st,c,d,hear=fixture()
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
