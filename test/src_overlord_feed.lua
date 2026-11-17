-- Independent 2.5.4 protocol fixtures. Donor code is never loaded.
local H=...
local eq,yes,no=H.eq,H.yes,H.no
local function test(n,f) H.test("Overlord feed: "..n,f) end
-- Parser/lease fixtures seed a prior 301-second quiet selection; reachability
-- tests separately exercise the complete clock and actual Main/transport path.
-- No fixture overrides the shipping availability/capability policy.
local function setup(testEngine)
    local N=H.load();N.Net.SHIP.overlord=true
    N.Adapters.groupNames=function() return {} end
    IsInGuild=function() return false end
    N.BNet.peers=function() return {{id=71,name="Birch Scout",friend=true}} end
    N.BNet.who=function(id) return id==71 and {name="Birch Scout",faction="Horde"} end
    Enum.GameRule={HardcoreRuleset=1,RPRuleset=2,PvPRuleset=3}
    C_GameRules={IsGameRuleActive=function(i) return i==3 end}
    UnitName=function() return "Alice Vale",GetRealmName() end
    C_AddOns.GetAddOnMetadata=function() return "1.1.0" end
    return N
end
local serial=0
local function hear(kind,payload,name,route,target,path,pool)
    serial=serial+1;local id="feed"..serial;name=name or "Birch Scout";route=route or "BNET"
    local wire=table.concat({pool or "global",id,math.floor(GetServerTime()),target or "Alice Vale",path or name,kind,payload},"|")
    if route=="BNET" then
        H.deliver("BN_CHAT_MSG_ADDON","OverlordF","R2:Forever_"..(pool or "global").."_H:BR:"..wire,nil,71)
    else
        local count=math.ceil(#wire/200)
        for part=1,count do
            H.deliver("CHAT_MSG_ADDON","OverlordF","BF:"..id..":"..part..":"..count..":"..wire:sub((part-1)*200+1,part*200),route or "WHISPER",name)
        end
    end
end
local function requestSends()
    local out={};for _,s in ipairs(H.sent()) do if s.prefix=="OverlordF" and s.text:find("|HR|",1,true) then out[#out+1]=s end end;return out
end
local function epoch(N,name,e,route)
    name=name or "Birch Scout";e=e or GetServerTime()-100
    hear("NH","2.5.4~la~l9~ld~lr~lp6",name,route)
    hear("K",name..":#1434:21:WARRIOR:Horde:"..e.."::en:0:Orc:2:B"..e..":60",name,route,"*")
    N.Main.overlordTick(H.clock())
    local source=N.Main.overlordFeed.sources[N.Find.fold(name)]
    if source then source.since=H.clock()-301 end -- pre-existing quiet fixture
    N.Main.overlordTick(H.clock());if not route then N.BNet.pump(H.clock()) end;return e
end

local function blob(rows)
    local out={};for _,r in ipairs(rows) do out[#out+1]=#r..":"..r end;return table.concat(out)
end
local function feed(e,rows,name,route)
    hear("HB","8:U:"..e..":"..blob(rows),name,route)
end
local function full(name,total,faction)
    return "k"..(name or "Enemy One")..":"..(total or 21)..":WARRIOR:"..(faction or "Horde")..":en::0:60"
end
local function known(N,name)
    local p=N.Known.get(N.Main.find.known,name or "Enemy One",H.clock());return p and p.reported
end

-- Independent equivalent of the pinned NH capability parser, not donor code.
-- SyncRelay.lua:2843-2851: literal terminal lp6 is the entrance; each complete
-- contiguous chain found anywhere in the advert enables the next level.
local function donorCapability(text)
    if text:match("~lp(%d+)$")~="6" then return 5 end
    local level,chain=6,"~lp6"
    for _,token in ipairs({"lr","ld","l9","la","lb"}) do
        chain="~"..token..chain
        if not text:find(chain,1,true) then break end
        level=level+1
    end
    return level
end

test("honest advert omits unsupported ranking page capabilities",function()
    local vectors={{"plain",5},{"~lp8",5},{"~lp06",5},{"~lp6",6},{"~lr~lp6",7},
        {"~ld~lr~lp6",8},{"~l9~ld~lr~lp6",9},{"~la~l9~ld~lr~lp6",10},
        {"~lb~la~l9~ld~lr~lp6",11},{"~ld~lr~lp6junk~lp6",8},{"~ld~lp6",6}}
    for _,v in ipairs(vectors) do eq(donorCapability(v[1]),v[2]) end
    local N=setup(false);N.Adapters.groupNames=function() return {} end;hear("NH","2.5.4~ld~lr~lp6",nil,"WHISPER")
    local hello=H.sent()[1];yes(hello)
    local payload=hello.text:match("|NH|(.*)$")
    eq(payload,"LayerEnemies 1.1.0","no unsupported paged ranking claim")
    eq(donorCapability(payload),5,"known client would be refused; feed sources hear no NH")
end)

test("feed waits for quiet source without any capability claim",function()
    local N=setup(false);local e=GetServerTime()-100
    N.Main.overlordTick(H.clock());N.BNet.pump(H.clock()) -- actual NH before source selection
    hear("NH","2.5.4~ld~lr~lp6")
    hear("K","Birch Scout:#1434:21:WARRIOR:Horde:"..e.."::en:0:Orc:2:B"..e..":60",nil,nil,"*")
    N.Main.overlordTick(H.clock())
    eq(#requestSends(),0,"quiet period not yet completed")
    eq(next(N.Main.overlordFeed.sessions),nil)
    feed(e,{"z#1434",full()});eq(known(N),nil)
end)

test("empty comparison never claims equality to nonempty requester",function()
    local N=setup(false);local P=N.OverlordPeer;local st=P.new()
    local c={now=100,wall=1700000000,pool="global",me="Alice Vale",version="1.1.0",faction="A",allowed=true,own=true,out={}}
    c.send=function(_,text) c.out[#c.out+1]={text=text};return true end
    local p={origin="Birch Scout",hops=0,target=c.me,kind="HR",payload="8:V:1699488000:123n4n5f:1:LK:9:7:H"}
    P.receive(st,p,"WHISPER",p.origin,nil,c);eq(#c.out,1)
    yes(c.out[1].text:find("|HA|8:R:",1,true),"S means same, not merely our own count")
    c.now=250;p.payload="8:V:1699488000:123n4n5f:1:LK:0:0:H"
    P.receive(st,p,"WHISPER",p.origin,nil,c);eq(#c.out,2)
    yes(c.out[2].text:find("|HA|8:R:1699488000:123n4n5f:1",1,true))
end)

test("only exact donor thirteen-field K establishes an epoch",function()
    local N=setup();local e=GetServerTime()-100
    local stem="Birch Scout:#1434:21:WARRIOR:Horde:"..e.."::en:0:"
    for i,body in ipairs({stem.."B"..e..":60",stem.."B"..e..":60:garbage",
        stem.."Orc:2:B"..e..":60:garbage",stem.."garbage:2:B"..e..":60",
        stem.."Orc:1:B"..e..":60",stem.."Orc:2:B"..(e+1)..":60"}) do
        N=setup();hear("NH","2.5.4~ld~lr~lp6")
        hear("K",body,nil,nil,"*");N.Main.overlordTick(H.clock())
        eq(N.Main.overlordPeer.routes["birch scout"].epoch,nil,"bad K "..i)
        eq(#requestSends(),0)
    end
    N=setup();hear("NH","2.5.4~ld~lr~lp6")
    hear("K",stem.."Orc:2:B"..e..":60",nil,nil,"*")
    eq(N.Main.overlordPeer.routes["birch scout"].epoch,e,"donor race/sex precede bucket and level")
    N.Main.overlordFeed.sources["birch scout"].since=H.clock()-301
    N.Main.overlordTick(H.clock());N.BNet.pump(H.clock());eq(#requestSends(),1)
end)

test("solicited full then compact rows offer only tracked opposite names as unknown-time claims",function()
    local N=setup();yes(N.Find.add(N.Main.find,"Enemy One"));local e=epoch(N)
    local offers={};local original=N.Sources.offer
    N.Sources.offer=function(v) offers[#offers+1]=v;return original(v) end
    feed(e,{"z#1434",full()});eq(#offers,1);local p=known(N);yes(p)
    eq(offers[1].kind,"relayed");eq(offers[1].at,nil);eq(offers[1].shard,nil)
    eq(offers[1].net,"overlord");eq(offers[1].map,1434);eq(offers[1].via,"Birch Scout")
    yes(p.detail:find("time unknown",1,true));eq(p.kind,"claim");eq(p.layer,nil)
    feed(e,{"z#1434","sEnemy One:22"});eq(#offers,2)
    feed(e,{"z#1434","sEnemy One:22"});eq(#offers,2,"no repeat total refreshed")
    feed(e,{"z#1434",full("Untracked Player"),"cEnemy One:H:WARRIOR:1:site:en","bEnemy One:30"})
    eq(#offers,2);eq(N.Safe.count(N.Main.overlordFeed.sessions["birch scout"].known),1)
end)

local function model(N,count,route)
    local P,Q=N.OverlordPeer,N.OverlordFeed;local peer,st=P.new(),Q.new();peer.feed=st
    local c={now=100,wall=1700000000,pool="global",me="Alice Vale",version="1.1.0",faction="A",
        allowed=true,own=true,stopAllowed=true,groups={},guildNames={},friends={},out={},offers={},tracked=function() return true end}
    c.offer=function(v) c.offers[#c.offers+1]=v;return true end
    c.online=function(id) for _,f in ipairs(c.friends) do if f.id==id then return f end end end
    c.send=function(_,text,dist,target,prio,job)
        if not P.claim(peer,job,c) then return false end
        c.out[#c.out+1]={text=text,route=dist,target=target,at=c.now,job=job};P.sent(peer,job,c);return true
    end
    for i=1,(count or 1) do
        local name="Peer"..H.abc(i).." Scout";local id=i
        c.friends[#c.friends+1]={id=id,name=name,friend=true}
        local p={origin=name,pool=c.pool,target=c.me,hops=0,kind="NH",payload="2.5.4~lp8"}
        local r=P.receive(peer,p,route or "BNET",name,id,c)
        -- Sources receive no presence, including the initial owed greeting.
        p.kind="K";p.payload=name..":#1434:20:WARRIOR:Horde:1699488000::en:0:Orc:2:B1699488000:60"
        Q.observe(st,peer,p,r,c)
    end
    Q.prepare(st,peer,c)
    for _,source in pairs(st.sources) do source.since=c.now-301 end
    Q.tick(st,peer,c);return Q,st,peer,c
end
-- Explicit parser-only prehistory for replacement sources: global budgets do not
-- reset when a session is swapped. Full-clock source rotation is in reach tests.
local function replacement(Q,st,peer,c)
    Q.prepare(st,peer,c)
    for _,source in pairs(st.sources) do source.since=c.now-301 end
    Q.tick(st,peer,c)
end
local function receive(Q,st,peer,c,rows,key,kind,payload)
    key=key or "peera scout";local r=peer.routes[key]
    Q.receive(st,peer,{origin=r.name,pool=c.pool,hops=0,target=c.me,kind=kind or "HB",
        payload=payload or "8:U:1699488000:"..blob(rows)},r,c)
end
local function hr(c)
    local out={};for _,v in ipairs(c.out) do if v.text:find("|HR|",1,true) then out[#out+1]=v end end;return out
end

test("two sources 200 second request keep and busy state machine",function()
    local N=setup();local Q,st,peer,c=model(N,3);eq(#hr(c),2);eq(N.Safe.count(st.sources),2)
    local s=st.sessions["peera scout"]
    receive(Q,st,peer,c,{},nil,"HA","8:S:"..s.epoch..":"..s.nonce..":1:LK:0:0")
    c.now=299;Q.tick(st,peer,c);eq(#hr(c),2)
    c.now=300;Q.tick(st,peer,c);eq(#hr(c),4)
    yes(hr(c)[3].text:find("|HR|8:K:1699488000",1,true));yes(hr(c)[4].text:find("|HR|8:V:",1,true))
    local b=st.sessions["peerb scout"];receive(Q,st,peer,c,{},"peerb scout","HA","8:R:"..b.epoch..":"..b.nonce..":1:C")
    eq(b.asked,nil);receive(Q,st,peer,c,{"z#1434",full()},"peerb scout");eq(#c.offers,0)
    for _,v in ipairs(hr(c)) do eq(v.route,"BNET");yes(v.target==1 or v.target==2) end
end)

test("compact unknown no-zone stale totals and marker reset",function()
    local N=setup();local Q,st,peer,c=model(N)
    receive(Q,st,peer,c,{"z#1434","sEnemy One:20"});eq(#c.offers,0)
    receive(Q,st,peer,c,{full()});eq(#c.offers,0)
    receive(Q,st,peer,c,{"sEnemy One:22"});eq(#c.offers,0)
    receive(Q,st,peer,c,{"z#1434","sEnemy One:23"});eq(#c.offers,1)
    receive(Q,st,peer,c,{"z#1434","zgarbage","sEnemy One:24"});eq(#c.offers,1)
    receive(Q,st,peer,c,{"z@front_foo","sEnemy One:25"});eq(#c.offers,2);eq(c.offers[2].zone,"@front_foo");eq(c.offers[2].map,nil)
    receive(Q,st,peer,c,{"z#1434","sEnemy One:24",full("Friendly One",30,"Alliance")});eq(#c.offers,2)
end)

test("feed identities accept donor race strings then compact updates",function()
    for _,race in ipairs({"o2","Skyborne3","h0","Orc2"}) do
        local N=setup();local Q,st,peer,c=model(N)
        receive(Q,st,peer,c,{"z#1434",full()..":"..race})
        eq(#c.offers,1,race);eq(c.offers[1].name,"Enemy One")
        receive(Q,st,peer,c,{"z#1434","sEnemy One:22"});eq(#c.offers,2)
    end
    for _,race in ipairs({"2","o1","x2","Unknown3","o2:garbage",string.rep("a",42).."2"}) do
        local N=setup();local Q,st,peer,c=model(N)
        receive(Q,st,peer,c,{"z#1434",full()..":"..race})
        eq(#c.offers,0,race);receive(Q,st,peer,c,{"z#1434","sEnemy One:22"});eq(#c.offers,0)
    end
end)

for _,mode in ipairs({"share","guild","switch"}) do
    test("immediate "..mode.." off-on cancels lease with HR X",function()
        local N=setup();N.Find.add(N.Main.find,"Enemy One");local e=epoch(N);eq(#requestSends(),1)
        local before=#H.sent()
        if mode=="share" then N.Main.setShare(false);N.Main.setShare(true)
        elseif mode=="guild" then N.Net.setConsent("guild");N.Net.setConsent("public")
        else N.Net.setSwitch("overlord",false);N.Net.setSwitch("overlord",true) end
        eq(next(N.Main.overlordFeed.sessions),nil)
        H.advance(1);feed(e,{"z#1434",full()});eq(known(N),nil);eq(#H.sent(),before+1)
    end)
end

test("removed BNet friend cannot feed a prior subscriber",function()
    local N=setup();local Q,st,peer,c=model(N,1,"BNET")
    receive(Q,st,peer,c,{"z#1434",full()});eq(#c.offers,1)
    c.friends={};receive(Q,st,peer,c,{"z#1434",full(nil,22)});eq(#c.offers,1)
end)

test("queued subscription cancels if the route changes before dispatch",function()
    local N=setup();local Q,st,peer,c=model(N,1,"BNET");local j=hr(c)[1].job
    c.now=301;peer.routes["peera scout"].id=999;c.friends[1].id=999
    no(N.OverlordPeer.claim(peer,j,c))
end)

test("campaign epochs remain source and pool scoped and unknown never guessed",function()
    local N=setup();local Q,st,peer,c=model(N);local r=peer.routes["peera scout"]
    local old=r.epoch
    for _,v in ipairs({{"Other Scout",old+1},{r.name,c.wall+1}}) do
        Q.observe(st,peer,{kind="K",origin=r.name,hops=0,target="*",payload=v[1]..":#1434:1:WARRIOR:Horde:"..v[2].."::en:0:Orc:2:B"..v[2]..":60"},r,c)
        eq(r.epoch,old)
    end
    Q.observe(st,peer,{kind="HR",origin=r.name,hops=0,target=c.me,payload="8:V:1699488001:123n1n1f:1:LK:0:0:H"},r,c)
    eq(r.epoch,1699488001);eq(next(st.sessions),nil)
    c.pool="pve"
    r=N.OverlordPeer.receive(peer,{kind="NH",payload="2.5.4~lp8",pool="pve",origin=r.name,target=c.me,hops=0},"WHISPER",r.name,nil,c)
    eq(r.epoch,nil,"foreign pool epoch never carried forward");Q.tick(st,peer,c);eq(#hr(c),2,"old epoch withdrawal only")
end)

test("envelope direct addressing source lease and epoch gates",function()
    local N=setup();local Q,st,peer,c=model(N);local r=peer.routes["peera scout"]
    local p={kind="HB",payload="8:U:1699488000:"..blob({"z#1434",full()}),origin=r.name,pool=c.pool,target=c.me,hops=0}
    for _,change in ipairs({{"hops",1},{"target","*"},{"pool","pve"},{"origin","Unasked Scout"}}) do
        local old=p[change[1]];p[change[1]]=change[2];Q.receive(st,peer,p,r,c);p[change[1]]=old;eq(#c.offers,0)
    end
    p.payload="8:U:1699488001:"..blob({"z#1434",full()});Q.receive(st,peer,p,r,c);eq(#c.offers,0)
    p.payload="8:U:1699488000:"..blob({"z#1434",full()})
    c.now=700;Q.receive(st,peer,p,r,c);eq(#c.offers,0,"600 second initial lease")
    local s=st.sessions["peera scout"];s.live=300
    Q.receive(st,peer,p,r,c);eq(#c.offers,1)
    s.live=280;c.now=700;p.payload="8:U:1699488000:"..blob({"z#1434",full(nil,22)})
    Q.receive(st,peer,p,r,c);eq(#c.offers,1,"420 second live lease")
end)

test("parser exact 600 byte 48 row 250 row-byte and three digit bounds",function()
    local N=setup();local Q=N.OverlordFeed;local prefix="8:U:1699488000:"
    local payload,over
    for n=2,250 do
        local p=prefix..blob({string.rep("x",250),string.rep("x",250),string.rep("x",n)})
        if #p==600 then payload=p elseif #p==601 then over=p end
    end
    yes(payload);yes(Q.decode(payload));eq(Q.decode(over),nil)
    yes(Q.decode(prefix..blob({string.rep("x",250)})));eq(Q.decode(prefix..blob({string.rep("x",251)})),nil)
    local r={};for i=1,48 do r[i]="zz" end;yes(Q.decode(prefix..blob(r)));r[49]="zz";eq(Q.decode(prefix..blob(r)),nil)
    eq(Q.decode(prefix.."0002:zz"),nil);eq(Q.decode(prefix.."1:x"),nil);eq(Q.decode(prefix.."4:xx"),nil)
    eq(Q.decode(prefix.."2:zzjunk"),nil);eq(Q.decode(H.secret),nil)
    local Q2,st,peer,c=model(N);receive(Q2,st,peer,c,{},nil,"HB",prefix..blob({"z#1434",full()}).."junk");eq(#c.offers,0,"no partial commit")
end)

test("per source 240 rows and 14400 bytes per minute before decode",function()
    local N=setup();local Q,st,peer,c=model(N,2)
    local calls=0;local decode=Q.decode;Q.decode=function(...) calls=calls+1;return decode(...) end
    local rows={};for i=1,48 do rows[i]="zz" end
    for _=1,5 do receive(Q,st,peer,c,rows) end;eq(st.sessions["peera scout"].budget.rows,240)
    receive(Q,st,peer,c,rows);eq(calls,5)
    receive(Q,st,peer,c,{"z#1434",full()},"peerb scout");eq(#c.offers,1,"other source not starved")
    local prefix="8:U:1699488000:";local payload
    for n=2,250 do local p=prefix..blob({string.rep("x",250),string.rep("x",250),string.rep("x",n)});if #p==600 then payload=p end end
    c.now=160;calls=0
    for _=1,24 do receive(Q,st,peer,c,{},nil,"HB",payload) end;eq(calls,24)
    receive(Q,st,peer,c,{},nil,"HB",payload);eq(calls,24);eq(st.sessions["peera scout"].budget.bytes,14400)
    c.now=159;receive(Q,st,peer,c,{});eq(calls,24,"rollback cannot reopen budget")
    c.now=220;receive(Q,st,peer,c,{});eq(calls,25)
    c.now=219;receive(Q,st,peer,c,{});eq(calls,25,"rollback with spare byte budget")
    c.now=225;receive(Q,st,peer,c,{},"peerb scout");eq(calls,26)
    c.now=224;receive(Q,st,peer,c,{},"peerb scout");eq(calls,26,"sender rollback inside live global window")
end)

test("64 identities per source bounded and untracking prunes session-only state",function()
    local N=setup();local Q,st,peer,c=model(N,2)
    for i=1,65 do receive(Q,st,peer,c,{"z#1434",full("Enemy"..H.abc(i).." Name")}) end
    eq(N.Safe.count(st.sessions["peera scout"].known),64);eq(#c.offers,64)
    c.tracked=function() return false end;Q.tick(st,peer,c);eq(next(st.sessions["peera scout"].known),nil)
end)

for _,mode in ipairs({"share","guild","switch","combat","instance","pool","donor"}) do
    test("active subscription silent during "..mode,function()
        local N=setup();N.Find.add(N.Main.find,"Enemy One");local e=epoch(N);eq(#requestSends(),1)
        local before=#H.sent()
        if mode=="share" then N.Main.setShare(false)
        elseif mode=="guild" then N.Net.setConsent("guild")
        elseif mode=="switch" then N.Net.setSwitch("overlord",false)
        elseif mode=="combat" then H.combat(true)
        elseif mode=="instance" then H.instance(true)
        elseif mode=="pool" then C_GameRules=nil;GetRealmName=function() return "7102" end
        else H.loaded().Overlord=true end
        H.advance(1);feed(e,{"z#1434",full()});N.Main.overlordTick(H.clock()+200)
        eq(known(N),nil);eq(#H.sent(),before+((mode=="share" or mode=="guild" or mode=="switch") and 1 or 0));eq(N.BNet.queued(),0)
    end)
end

test("5000 fuzz inputs bounded without forwarding or saved feed names",function()
    local N=setup();local Q,st,peer,c=model(N);local seed=1907
    local function rand(n) seed=seed*16807%2147483647;return seed%n end
    local base="8:U:1699488000:"..blob({"z#1434",full()});local before=#c.out
    for i=1,5000 do
        local chars={};for _=1,rand(700) do chars[#chars+1]=string.char(rand(256)) end
        local text=table.concat(chars)
        if i%3==0 then local at=rand(#base)+1;text=base:sub(1,at-1)..string.char(rand(256))..base:sub(at+1) end
        local tripped=false;debug.sethook(function() tripped=true;error("feed instruction ceiling") end,"",1000000)
        local ok=pcall(function() Q.decode(text);receive(Q,st,peer,c,{},nil,"HB",text) end)
        debug.sethook();yes(ok);no(tripped);yes(N.Safe.count(st.sessions["peera scout"].known)<=64)
    end
    eq(#c.out,before);eq(next(N.Main.find.known.entries),nil);no(N.Main.error)
end)

test("real BNet friend crosses factions only after actual request dispatch",function()
    local N=setup();N.Find.add(N.Main.find,"Enemy One")
    N.BNet.who=function(id) return id==71 and {name="Birch Scout",faction="Horde",realm="Test Realm"} end
    N.BNet.peers=function() return {{id=71,name="Birch Scout",faction="Horde",friend=true}} end
    local sends={};C_BattleNet.SendGameData=function(id,prefix,text)
        local level,info=2,debug.getinfo(2,"S");while info.what=="C" do level=level+1;info=debug.getinfo(level,"S") end
        yes(info.source:find("Wire.lua",1,true));sends[#sends+1]={id=id,text=text};return true
    end
    local e=epoch(N,nil,nil,"BNET");eq(#sends,0);feed(e,{"z#1434",full()},nil,"BNET");eq(known(N),nil)
    for _=1,5 do H.advance(1) end
    local requests=0
    for _,v in ipairs(sends) do
        eq(v.id,71);yes(v.text:find("R2:Forever_global_A:BR:",1,true))
        if v.text:find("|HR|",1,true) then requests=requests+1;yes(v.text:match(":LK:0:0:H$")) end
    end
    eq(requests,1);feed(e,{"z#1434",full()},nil,"BNET");yes(known(N));eq(known(N).faction,"Horde")
    local previous=N.Main.overlordFeed.sessions["birch scout"]
    N.BNet.peers=function() return {} end
    feed(e,{"z#1434",full(nil,22)},nil,"BNET");eq(previous.known["enemy one"].total,21);eq(N.Main.overlordFeed.sessions["birch scout"],nil)
end)

test("NH while request waits in BNet queue preserves its answer",function()
    local N=setup();N.Find.add(N.Main.find,"Enemy One")
    N.BNet.who=function() return {name="Birch Scout",faction="Horde",realm="Test Realm"} end
    N.BNet.peers=function() return {{id=71,name="Birch Scout",friend=true}} end
    local requests=0;C_BattleNet.SendGameData=function(_,_,text)
        if text:find("|HR|",1,true) then requests=requests+1 end
        return true
    end
    yes(N.BNet.send("overlord",71,"OverlordF","test-queue-blocker","own"))
    local e=epoch(N,nil,nil,"BNET");H.advance(1);N.Main.overlordTick(H.clock())
    local s=N.Main.overlordFeed.sessions["birch scout"]
    yes(s);eq(s.asked,nil);eq(N.BNet.queued(),1,"HR waits behind other traffic, not an NH to its source")
    H.advance(0.5);hear("NH","2.5.4~ld~lr~lp6",nil,"BNET")
    eq(N.Main.overlordPeer.routes["birch scout"].at,H.clock(),"NH really refreshed the route")
    H.advance(0.5);eq(requests,1);eq(s.asked,H.clock(),"receipt uses dispatch time, not enqueue snapshot")
    feed(e,{"z#1434",full()..":o2"},nil,"BNET");yes(known(N),"answer retained after refreshed NH")
end)

test("failed request never grants a feed lease",function()
    for _,failure in ipairs({"HR"}) do
        local N=setup();N.Find.add(N.Main.find,"Enemy One")
        N.BNet.who=function() return {name="Birch Scout",faction="Horde",realm="Test Realm"} end
        N.BNet.peers=function() return {{id=71,name="Birch Scout",friend=true}} end
        local requests=0
        C_BattleNet.SendGameData=function(_,_,text)
            if text:find("|HR|",1,true) then requests=requests+1 end
            return not text:find("|"..failure.."|",1,true)
        end
        local e=epoch(N,nil,nil,"BNET");for _=1,5 do H.advance(1) end
        eq(requests,failure=="NH" and 0 or 1)
        feed(e,{"z#1434",full()},nil,"BNET");eq(known(N),nil)
    end
end)

test("measured Find row has no Ask or Hop and feed data is not saved",function()
    local N=setup();N.Find.add(N.Main.find,"Enemy One");local e=epoch(N)
    local function snap(t)
        if type(t)~="table" then return type(t)..":"..tostring(t) end
        local rows={};for k,v in pairs(t) do rows[#rows+1]=snap(k).."="..snap(v) end;table.sort(rows);return "{"..table.concat(rows,";").."}"
    end
    local saved=snap(LayerEnemiesDB)
    feed(e,{"z@front_with_long_name",full()})
    local U=N.UI;U.toggle();U.tabs.find:Click();U.render()
    yes(U.pool[1].sub:GetText():find("time unknown",1,true));yes(U.pool[1].sub:GetText():find("@front_with_long_name",1,true))
    yes(U.pool[1].sub:GetHeight()>=U.pool[1].sub:GetStringHeight());no(U.pool[1].ask:IsShown())
    no(N.Find.rows(N.Main.find,H.clock(),100)[1].canAsk);eq(#N.Main.candidates(),0)
    H.deliver("PLAYER_LOGOUT");eq(snap(LayerEnemiesDB),saved)
end)

test("live feed keeps its lease beyond 900 seconds without another pull",function()
    local N=setup();local Q,st,peer,c=model(N);local r=peer.routes["peera scout"]
    for step=1,6 do
        c.now=100+200*step;r.at=c.now;r.announced=c.now
        receive(Q,st,peer,c,{"z#1434",full(nil,21+step)})
        Q.tick(st,peer,c)
    end
    eq(#hr(c),7)
    for i=2,7 do yes(hr(c)[i].text:find("|HR|8:K:",1,true),"keep, not another V") end
end)

test("malformed owner K cannot bootstrap epoch",function()
    for _,body in ipairs({
        "Birch Scout:#1434:21:BADCLASS:Horde:E::en:0:Orc:2:BE:60",
        "Birch Scout:|bad:21:WARRIOR:Horde:E::en:0:Orc:2:BE:60",
        "Birch Scout:#1434:21:WARRIOR:Horde:E::en:0:Orc:2:BE:0"}) do
        local N=setup();hear("NH","2.5.4~lp8")
        local e=tostring(GetServerTime()-100);body=body:gsub("BE","B"..e):gsub(":E:",":"..e..":")
        hear("K",body,nil,nil,"*");N.Main.overlordTick(H.clock());eq(#requestSends(),0)
    end
end)

test("zero totals and invalid full identities are not locations",function()
    local N=setup();local Q,st,peer,c=model(N)
    for _,row in ipairs({full(nil,0),full(nil,15001),full():gsub("WARRIOR","BADCLASS"),full():gsub(":60$",":0"),
        full():gsub(":en:",":<bad>:"),(full():gsub("::0:","::1700000031:"))}) do
        receive(Q,st,peer,c,{"z#1434",row});eq(#c.offers,0)
    end
end)

test("dispatch gap stale epochs routes old releases and foreign ACK are refused",function()
    local N=setup();local Q,st,peer,c=model(N);local r=peer.routes["peera scout"];local s=st.sessions["peera scout"]
    c.now=299;no(N.OverlordPeer.claim(peer,hr(c)[1].job,c),"actual 200 second gap")
    receive(Q,st,peer,c,{},nil,"HA","8:S:"..s.epoch..":wrongnonce:1:LK:0:0");eq(s.live,nil)
    c.now=400;Q.tick(st,peer,c);yes(st.sessions["peera scout"],"first-hand session evidence survives C2 route expiry")
    c.now=700;Q.tick(st,peer,c);yes(st.sessions["peera scout"],"source epoch is not guessed or expired by hearing cadence")
    r.version="2.4.9~lp8";Q.tick(st,peer,c);eq(next(st.sessions),nil,"provider predates feeds")
end)

test("future epoch independent of route expiry and fresh selection",function()
    local N=setup();local Q,st,peer,c=model(N);local r=peer.routes["peera scout"]
    c.now=700;r.at=c.now;r.epoch=c.wall+1
    Q.tick(st,peer,c);eq(next(st.sessions),nil,"a future epoch is unusable despite a warm route")
end)
test("old provider independent of quiet period and epoch",function()
    local N=setup();local Q,st,peer,c=model(N);local r=peer.routes["peera scout"]
    c.now=200;r.at=c.now;r.version="2.4.9~ld~lr~lp6"
    Q.tick(st,peer,c);eq(next(st.sessions),nil,"release below 2.5.0 loses its warm selection")
end)

test("batch row ceiling and marker byte bound are independent",function()
    local N=setup();local Q,st,peer,c=model(N);local s=st.sessions["peera scout"]
    local rows={};for i=1,47 do rows[i]="zz" end
    for _=1,5 do receive(Q,st,peer,c,rows) end
    receive(Q,st,peer,c,{"zz","zz","zz","zz"});eq(s.budget.rows,239)
    receive(Q,st,peer,c,{"z#1434",full()});eq(#c.offers,0);eq(s.budget.rows,239)
    c.now=160
    receive(Q,st,peer,c,{"z@"..string.rep("a",24),full()});eq(#c.offers,0)
end)

test("global feed budget survives source rotation and privacy cancellation",function()
    local N=setup();local Q,st,peer,c=model(N,3)
    local rows={};for i=1,48 do rows[i]="zz" end
    for _,key in ipairs({"peera scout","peerb scout"}) do for _=1,5 do receive(Q,st,peer,c,rows,key) end end
    peer.routes["peera scout"].hops=1;c.now=101;replacement(Q,st,peer,c);yes(st.sessions["peerc scout"].asked)
    receive(Q,st,peer,c,{"z#1434",full()},"peerc scout");eq(#c.offers,0,"global rows survive source churn")
    c.now=160;receive(Q,st,peer,c,{"z#1434",full()},"peerc scout");eq(#c.offers,1)
    local global=st.budget;Q.cancel(st);eq(st.budget,global,"privacy does not refill budget")
end)

test("global byte and batch-row ceilings hold across replacement sources",function()
    local N=setup();local Q,st,peer,c=model(N,4)
    local calls=0;local decode=Q.decode;Q.decode=function(...) calls=calls+1;return decode(...) end
    local prefix="8:U:1699488000:";local payload
    for n=2,250 do local p=prefix..blob({string.rep("x",250),string.rep("x",250),string.rep("x",n)});if #p==600 then payload=p end end
    for _,key in ipairs({"peera scout","peerb scout"}) do for _=1,24 do receive(Q,st,peer,c,{},key,"HB",payload) end end
    eq(st.budget.bytes,28800);eq(calls,48)
    peer.routes["peera scout"].hops=1;c.now=101;replacement(Q,st,peer,c)
    receive(Q,st,peer,c,{},"peerc scout","HB",payload);eq(calls,48)
    c.now=160;local rows={};for i=1,48 do rows[i]="zz" end
    for _=1,5 do receive(Q,st,peer,c,rows,"peerb scout") end
    rows[48]=nil;for _=1,5 do receive(Q,st,peer,c,rows,"peerc scout") end
    receive(Q,st,peer,c,{"zz","zz","zz","zz"},"peerc scout");eq(st.budget.rows,479)
    peer.routes["peerc scout"].hops=1;c.now=161;replacement(Q,st,peer,c);yes(st.sessions["peerd scout"].asked)
    receive(Q,st,peer,c,{"z#1434",full()},"peerd scout");eq(#c.offers,0);eq(st.budget.rows,479)
    receive(Q,st,peer,c,{"zz"},"peerd scout");eq(st.budget.rows,480)
    local before=calls;receive(Q,st,peer,c,{"zz"},"peerd scout");eq(calls,before)
end)

test("unknown epoch silent then direct owner K opens truthful v8 subscription",function()
    local N=setup()
    hear("NH","2.5.4~ld~lr~lp6");N.Main.overlordTick(H.clock());eq(#requestSends(),0)
    local e=epoch(N);local out=requestSends();eq(#out,1)
    eq(out[1].kind,"BN");eq(out[1].target,71)
    yes(out[1].text:find("|Alice Vale|HR|8:V:"..e..":",1,true))
    yes(out[1].text:match(":%d+n%d+n%d+f:1:LK:0:0:H$"))
    for _,v in ipairs(H.sent()) do no(v.text:find("~",1,true)) end
end)
