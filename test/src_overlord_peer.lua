-- C2 protocol fixtures are independently constructed; no donor is executed.
local H=...
local eq,yes,no=H.eq,H.yes,H.no
local function test(n,f) H.test("Overlord peer: "..n,f) end
local function setup()
    local N=H.load()
    Enum.GameRule={HardcoreRuleset=1,RPRuleset=2,PvPRuleset=3}
    C_GameRules={IsGameRuleActive=function(i) return i==3 end}
    return N
end
local function packet(id,kind,body,name,target,path)
    return table.concat({"global",id,GetServerTime(),target or "*",path or name or "Birch Scout",kind,body},"|")
end
local function hear(id,kind,body,route,name,target,path)
    local w=packet(id,kind,body,name,target,path)
    H.deliver("CHAT_MSG_ADDON","OverlordF","BF:"..id..":1:1:"..w,route or "WHISPER",name or "Birch Scout")
end
local function ctx(N)
    return {now=100,wall=1700000000,pool="global",me="Alice Vale",version="1.3.0",faction="A",
        allowed=true,own=true,guild=true,group="PARTY",friends={},directory={},out={},
        send=function(c,text,route,target,prio) c.out[#c.out+1]={text=text,route=route,target=target,prio=prio,at=c.now}; return true end}
end
-- Public fixtures reused by the feed suite without sharing production internals.
H.overlordPeer={setup=setup,packet=packet,hear=hear,ctx=ctx}
local function enable(N)
    N.Net.SHIP.overlord=true
    UnitName=function() return "Alice Vale",GetRealmName() end
    C_AddOns.GetAddOnMetadata=function() return "1.3.0" end
    N.Main.overlordPeer=N.OverlordPeer.new()
end
H.overlordPeer.enable=enable
local function onlySent()
    local out={};for _,s in ipairs(H.sent()) do if s.prefix=="OverlordF" then out[#out+1]=s end end;return out
end

test("directory uses audited pool channel and two free slots",function()
    local N=setup();eq(N.Directory.channel("overlord"),"OverlordF")
    C_GameRules.IsGameRuleActive=function() return false end
    eq(N.Directory.channel("overlord"),"OverlordFE")
    N.Net.SHIP.overlord=true
    local joins=0;JoinChannelByName=function() joins=joins+1;return true end
    GetNumDisplayChannels=function() return 8 end
    N.Directory.sync();eq(joins,0)
    GetNumDisplayChannels=function() return 7 end
    N.Directory.sync();eq(joins,1)
    N.Net.setSwitch("overlord",false);N.Directory.sync();eq(N.Directory.joined("overlord"),nil)
end)

test("real whisper owes one truthful reply; no forwarding or bypass",function()
    local N=setup();enable(N)
    hear("hi","NH","2.5.4",nil,nil,"Alice Vale")
    local out=onlySent();eq(#out,1);eq(out[1].kind,"WHISPER");eq(out[1].target,"Birch Scout")
    yes(out[1].text:find("|Alice Vale|NH|LayerEnemies 1.3.0",1,true))
    hear("hi","NH","2.5.4",nil,nil,"Alice Vale");eq(#onlySent(),1)
    hear("relay","NH","2.5.4",nil,nil,"Alice Vale","Origin Scout,Birch Scout");eq(#onlySent(),1)
    hear("unaddressed","NH","2.5.4");eq(#onlySent(),1)
    hear("gw","GW","1:Enemy Guild:H:77:6:#1434:42:"..GetServerTime());eq(#onlySent(),1)
    no(N.Wire.send("OverlordF",out[1].text,"WHISPER","Other Scout",{net="overlord",prio="owed"}))
end)

for _,mode in ipairs({"share","guild","switch","combat","instance","pool","version","identity"}) do
    test("all sends silent with "..mode,function()
        local N=setup();enable(N)
        if mode=="share" then N.Main.setShare(false)
        elseif mode=="guild" then N.Net.setConsent("guild")
        elseif mode=="switch" then N.Net.setSwitch("overlord",false)
        elseif mode=="combat" then H.combat(true)
        elseif mode=="instance" then H.instance(true)
        elseif mode=="pool" then C_GameRules=nil;GetRealmName=function() return "7102" end
        elseif mode=="version" then C_AddOns.GetAddOnMetadata=function() return H.secret end
        else UnitName=function() return H.secret end end
        hear("hi","NH","2.5.4",nil,nil,"Alice Vale")
        N.Main.overlordTick(H.clock());eq(#onlySent(),0);eq(N.BNet.queued(),0)
    end)
end

test("owed cap six per minute and 150 seconds per peer",function()
    local N=setup();local P=N.OverlordPeer;local st=P.new();local c=ctx(N)
    local function recv(name)
        P.receive(st,{origin=name,target=c.me,hops=0,kind="NH",payload="2.5.4"},"WHISPER",name,nil,c)
    end
    for i=1,7 do recv(H.abc(i).." Scout") end;eq(#c.out,6)
    c.now=160;recv("a Scout");eq(#c.out,6)
    c.now=249;recv("a Scout");eq(#c.out,6)
    c.now=250;recv("a Scout");eq(#c.out,7)
    c.now=100;recv("a Scout");eq(#c.out,7,"rollback")
    for _,o in ipairs(c.out) do eq(o.prio,"owed");eq(o.route,"WHISPER");yes(o.text:find("|NH|LayerEnemies ",1,true)) end
end)

test("NH and HA share a per-peer gap at admission and dispatch",function()
    for _,first in ipairs({"NH","HR"}) do
        local N=setup();local P=N.OverlordPeer;local st=P.new();local c=ctx(N)
        local jobs={};c.send=function(_,_,_,_,_,job) jobs[#jobs+1]=job;return true end
        local p={origin="Birch Scout",target=c.me,hops=0,payload="2.5.4"}
        local function recv(kind)
            p.kind=kind;p.payload=kind=="NH" and "2.5.4" or "8:V:1699488000:123n4n5f:1:LK:0:0:H"
            P.receive(st,p,kind=="NH" and "WHISPER" or "BNET",p.origin,71,c)
        end
        local other=first=="NH" and "HR" or "NH"
        recv(first);eq(#jobs,1)
        c.now=249;recv(other);eq(#jobs,1,"shared admission gap")
        c.now=250;recv(other);eq(#jobs,2)
        yes(P.claim(st,jobs[1],c));c.now=251;no(P.claim(st,jobs[2],c),"shared dispatch gap")
        c.now=400;yes(P.claim(st,jobs[2],c));c.now=399;no(P.claim(st,jobs[1],c),"rollback")
    end
end)

test("guild alone 600 group 120 and heard guild 120",function()
    local N=setup();local P=N.OverlordPeer;local st=P.new();local c=ctx(N)
    P.tick(st,c);eq(#c.out,2)
    c.now=219;P.tick(st,c);eq(#c.out,2)
    c.now=220;P.tick(st,c);eq(#c.out,3);eq(c.out[3].route,"PARTY")
    c.now=699;c.group=nil;P.tick(st,c);eq(#c.out,3)
    c.now=700;P.tick(st,c);eq(#c.out,4);eq(c.out[4].route,"GUILD")
    P.receive(st,{origin="Guild Scout",target="*",hops=0,kind="NH",payload="2.5.4"},"GUILD","Guild Scout",nil,c)
    c.now=819;P.tick(st,c);eq(#c.out,4)
    c.now=820;P.tick(st,c);eq(#c.out,5)
end)

test("five live bridges two unheard friends per 120 second cycle",function()
    local N=setup();local P=N.OverlordPeer;local st=P.new();local c=ctx(N);c.guild=false;c.group=nil
    for i=1,10 do
        local name=H.abc(i).." Scout";c.friends[i]={id=i,name=name,friend=true}
        if i<=6 then P.receive(st,{origin=name,target="*",hops=0,kind="NH",payload="2.5.4"},"BNET",name,i,c) end
    end
    c.friends[11]={id=11,name="Club Only",friend=false}
    P.tick(st,c);eq(#c.out,7)
    local seen={};for _,o in ipairs(c.out) do eq(o.route,"BNET");no(seen[o.target]);seen[o.target]=true;no(o.target==11) end
    c.now=219;P.tick(st,c);eq(#c.out,7)
    c.now=220;P.tick(st,c);eq(#c.out,14)
end)

test("club-only accounts and disallowed pure contexts stay silent",function()
    local N=setup();local P=N.OverlordPeer;local s=P.new();local c=ctx(N)
    c.guild=false;c.group=nil;c.friends={{id=71,name="Club Scout",friend=false}}
    P.tick(s,c);eq(#c.out,0)
    for _,field in ipairs({"allowed","own"}) do
        c=ctx(N);c[field]=false;P.tick(P.new(),c);eq(#c.out,0,field)
    end
    c=ctx(N);c.pool=nil;P.tick(P.new(),c);eq(#c.out,0)
end)

test("whisper greeting once a minute stops at six partners",function()
    local N=setup();local P=N.OverlordPeer;local st=P.new();local c=ctx(N);c.guild=false;c.group=nil
    for i=1,8 do c.directory[i]="Dir"..H.abc(i).." Scout" end
    for i=1,6 do
        c.now=100+(i-1)*60;P.tick(st,c);eq(#c.out,i)
        local name=c.out[i].target
        P.receive(st,{origin=name,target="*",hops=0,kind="NH",payload="2.5.4"},"WHISPER",name,nil,c)
        -- Refresh existing partners, so the first one does not expire at minute five.
        for _,r in pairs(st.routes) do r.at=c.now end
        c.now=c.now+59;P.tick(st,c);eq(#c.out,i)
    end
    c.now=460;P.tick(st,c);eq(#c.out,6)
end)

test("directory greeting rotates through forty unanswered members",function()
    local N=setup();local P=N.OverlordPeer;local st=P.new();local c=ctx(N);c.guild=false;c.group=nil
    for i=1,40 do c.directory[i]="Dir"..H.abc(i).." Scout" end
    local seen,last={},{}
    for i=1,60 do
        c.now=100+(i-1)*60;P.tick(st,c);eq(#c.out,i)
        local name=c.out[i].target
        if i<=40 then no(seen[name],"round robin before any repeat") end
        if last[name] then yes(c.now-last[name]>=600) end
        seen[name]=true;last[name]=c.now
        c.now=c.now+59;P.tick(st,c);eq(#c.out,i,"minute cap")
    end
    eq(N.Safe.count(seen),40)
end)

test("refused greeting does not spend candidate or global cooldown",function()
    local N=setup();enable(N);N.BNet.peers=function() return {} end
    N.Directory.members=function() return {"Directory Scout"} end
    local original=N.Wire.send;local attempts=0
    N.Wire.send=function(prefix,text,route,...)
        if prefix=="OverlordF" and route=="WHISPER" then attempts=attempts+1;return false,"throttled" end
        return original(prefix,text,route,...)
    end
    N.Main.overlordTick(H.clock());eq(attempts,1)
    local st=N.Main.overlordPeer;eq(st.gaps["hello:directory scout"],nil);eq(st.actual["hello:directory scout"],nil)
    eq(st.greeting,nil)
    N.Wire.send=original;H.advance(1);N.Main.overlordTick(H.clock())
    local n=0;for _,v in ipairs(onlySent()) do if v.kind=="WHISPER" then n=n+1;eq(v.target,"Directory Scout") end end
    eq(n,1,"next tick remains eligible")
end)

test("queue refusal spends no peer cooldown but client attempts do",function()
    local N=setup();local P=N.OverlordPeer;local st=P.new();local c=ctx(N)
    c.send=function() return false end
    no(P.emit(st,c,"NH",P.presence(c),"BNET",{id=71,name="Birch Scout"},"bn:71",120,false))
    eq(st.gaps["bn:71"],nil)
    c.send=function() return false,true end -- client attempted and refused, not local admission refusal
    no(P.emit(st,c,"NH",P.presence(c),"WHISPER","Birch Scout","hello:birch scout",600,false))
    eq(st.gaps["hello:birch scout"],c.now)
end)

test("truthful empty V answer busy unsupported request and no invented map",function()
    local N=setup();local P=N.OverlordPeer;local st=P.new();local c=ctx(N)
    local p={origin="Birch Scout",target=c.me,hops=0,kind="HR",payload="8:V:1699488000:123n4n5f:1:LK:0:0:H"}
    P.receive(st,p,"WHISPER",p.origin,nil,c);eq(#c.out,1)
    yes(c.out[1].text:find("|HA|8:R:1699488000:123n4n5f:1",1,true))
    c.now=250;p.payload="8:T:1699488000:123n4n5f:1:LK:1:H"
    P.receive(st,p,"WHISPER",p.origin,nil,c);eq(#c.out,1,"unsupported HR T is silent")
    p.kind="SR";p.payload="H:2.5.4~1:0:::F";P.receive(st,p,"WHISPER",p.origin,nil,c);eq(#c.out,1)
    for _,o in ipairs(c.out) do eq(o.route,"WHISPER");eq(o.target,"Birch Scout");eq(o.prio,"owed") end
end)

test("claim dispatch stamps actual gap cap and changed pool",function()
    local N=setup();local P=N.OverlordPeer;local s=P.new();local c=ctx(N)
    local j={key="reply:a",gap=150,owed=true,pool=c.pool,me=c.me}
    yes(P.claim(s,j,c));c.now=249;no(P.claim(s,j,c));c.now=250;yes(P.claim(s,j,c))
    c.pool="pve";c.now=500;no(P.claim(s,j,c));c.pool="global";c.allowed=false;no(P.claim(s,j,c))
    c.allowed=true;s=P.new()
    for i=1,6 do j.key="answer:"..i;yes(P.claim(s,j,c)) end
    j.key="answer:7";no(P.claim(s,j,c));c.now=560;yes(P.claim(s,j,c))
end)

test("BNet shared queue used with eight frame cap and dispatch pool guard",function()
    local N=setup();enable(N)
    N.BNet.who=function(id) return {name="Peer"..H.abc(id).." Scout",faction="Horde",realm="Test Realm"} end
    local calls={};C_BattleNet.SendGameData=function(id,prefix,text)
        local level,info=2,debug.getinfo(2,"S")
        while info and info.what=="C" do level=level+1;info=debug.getinfo(level,"S") end
        yes(info.source:find("Wire.lua",1,true));calls[#calls+1]={id=id,text=text,at=H.clock()};return true
    end
    local c=N.Main.overlordContext();N.BNet.peers=function() return {} end
    for i=1,9 do
        local name="Peer"..H.abc(i).." Scout"
        H.deliver("BN_CHAT_MSG_ADDON","OverlordF","R2:Forever_global_H:BR:"..packet("ask"..i,"HR","8:V:"..(GetServerTime()-100)..":123n4n5f:1:LK:0:0:H",name,"Alice Vale"),nil,i)
    end
    eq(N.BNet.queued(),6,"owed admissions capped before queue: read="..N.Main.overlord.stats.lines.." refused="..N.Main.overlord.stats.refused.." routes="..N.Safe.count(N.Main.overlordPeer.routes).." own="..tostring(c.me).." wall="..tostring(c.wall))
    for _=1,7 do H.advance(1) end;eq(#calls,6)
    for _,x in ipairs(calls) do yes(x.text:find("|HA|8:R:",1,true));no(x.text:find("|Birch Scout|",1,true)) end
    local P=N.OverlordPeer;local st=N.Main.overlordPeer
    local job={key="test",gap=120,pool="global",me="Alice Vale"}
    yes(N.BNet.send("overlord",1,"OverlordF","queued","own",nil,nil,nil,function() return P.claim(st,job,N.Main.overlordContext()) end))
    C_GameRules.IsGameRuleActive=function() return false end
    H.advance(1);eq(#calls,6,"pool change cancels at actual dispatch")
end)

test("donor loaded blocks every send but retains incoming evidence",function()
    local N=setup();enable(N);H.loaded().Overlord=true
    N.Directory.members=function() return {"Directory Scout"} end
    N.BNet.peers=function() return {{id=71,name="Birch Scout",friend=true}} end
    N.BNet.who=function() return {name="Birch Scout",faction="Horde",realm="Test Realm"} end
    local calls=0;C_BattleNet.SendGameData=function() calls=calls+1;return true end
    for i=1,4 do
        N.Main.overlordTick(H.clock())
        hear("nh"..i,"NH","2.5.4",nil,nil,"Alice Vale")
        hear("hr"..i,"HR","8:V:"..(GetServerTime()-100)..":123n4n5f:1:LK:0:0:H",nil,nil,"Alice Vale")
        H.deliver("BN_CHAT_MSG_ADDON","OverlordF","R2:Forever_global_H:BR:"..packet("bn"..i,"HR",
            "8:V:"..(GetServerTime()-100)..":123n4n5f:1:LK:0:0:H",nil,"Alice Vale"),nil,71)
        H.advance(160)
    end
    eq(#onlySent(),0);eq(calls,0);eq(N.BNet.queued(),0)
    hear("gw","GW","1:Enemy Guild:H:77:6:#1434:42:"..GetServerTime())
    eq(#N.Main.reportedRows(),1,"stand-down still receives")
end)

test("donor loading cancels queued owed answers and gateway bypass",function()
    local N=setup();enable(N)
    N.BNet.who=function() return {name="Birch Scout",faction="Horde",realm="Test Realm"} end
    local calls=0;C_BattleNet.SendGameData=function() calls=calls+1;return true end
    H.deliver("BN_CHAT_MSG_ADDON","OverlordF","R2:Forever_global_H:BR:"..packet("queued","HR",
        "8:V:"..(GetServerTime()-100)..":123n4n5f:1:LK:0:0:H",nil,"Alice Vale"),nil,71)
    eq(N.BNet.queued(),1)
    H.loaded().Overlord=true
    no(N.Main.overlordContext().allowed,"no owed exemption in context")
    no(N.BNet.allowed("overlord",71,"OverlordF","queued","owed"),"no owed exemption in queue")
    local P=N.OverlordPeer;local c=ctx(N)
    c.send=function(_,text,route,target,prio)
        return N.Wire.send("OverlordF",text,route,target,{net="overlord",prio=prio})
    end
    no(P.emit(P.new(),c,"NH",P.presence(c),"WHISPER","Birch Scout","probe",150,true),"Wire refuses forged context")
    H.advance(1);eq(calls,0);eq(N.BNet.queued(),0);eq(#onlySent(),0)
end)

test("path target loop and malformed assemblies never learn routes",function()
    local N=setup();enable(N)
    hear("self","NH","2.5.4",nil,nil,"Alice Vale","Alice Vale,Birch Scout")
    hear("last","NH","2.5.4",nil,nil,"Alice Vale","Other Scout")
    hear("target","NH","2.5.4",nil,nil,"Other Scout")
    H.deliver("CHAT_MSG_ADDON","OverlordF","BF:incomplete:1:2:x","WHISPER","Birch Scout")
    eq(next(N.Main.overlordPeer.routes),nil);eq(#onlySent(),0)
    hear("good","NH","2.5.4",nil,nil,"Alice Vale");yes(N.Main.overlordPeer.routes["birch scout"])
end)

test("route ring reserves guild and expires at 300 seconds",function()
    local N=setup();local P=N.OverlordPeer;local st=P.new();local c=ctx(N)
    for i=1,130 do
        local name=H.abc(i).." Scout"
        P.receive(st,{origin=name,target="*",hops=0,kind="NH",payload="2.5.4"},"WHISPER",name,nil,c)
    end
    eq(N.Safe.count(st.routes),96)
    for i=1,40 do
        local name=H.abc(i).." Guild"
        P.receive(st,{origin=name,target="*",hops=0,kind="NH",payload="2.5.4"},"GUILD",name,nil,c)
    end
    eq(N.Safe.count(st.routes),128);P.sweep(st,399);eq(N.Safe.count(st.routes),128)
    P.sweep(st,400);eq(next(st.routes),nil)
end)

test("global assembly bytes and all 64 slots preserve guild room",function()
    local N=setup();local O=N.Overlord;local s=O.new()
    for i=1,48 do O.fragment(s,"BF:a:1:24:x",H.abc(i).." Public",100,"WHISPER") end
    for i=1,16 do O.fragment(s,"BF:a:1:24:x",H.abc(i).." Guild",100,"GUILD") end
    eq(N.Safe.count(s.pending),64)
    eq(O.fragment(s,"BF:a:1:24:x","Last Guild",100,"GUILD"),false)
    local function total() local bytes=0;for _,a in pairs(s.pending) do bytes=bytes+a.bytes end;return bytes end
    s=O.new()
    for i=1,40 do for p=1,15 do O.fragment(s,"BF:a:"..p..":24:"..string.rep("x",230),H.abc(i).." Public",100,"WHISPER") end end
    yes(total()<=49152);yes(total()>45000,"byte ceiling, not just stream count")
    eq(O.fragment(s,"BF:g:1:2:a","Guild Scout",100,"GUILD"),nil)
    eq(O.fragment(s,"BF:g:2:2:b","Guild Scout",100,"GUILD"),"ab")
    for i=1,40 do for p=1,15 do O.fragment(s,"BF:a:"..p..":24:"..string.rep("x",230),H.abc(i).." Guild",100,"GUILD") end end
    yes(total()<=65536);yes(total()>62000)
end)

test("work budgets canonical cross-route sender global and guild reserve",function()
    local N=setup();local O=N.Overlord;local s=O.new()
    for i=1,120 do yes(O.admit(s,"Birch Scout",100,1,i%2==0 and "WHISPER" or "PARTY")) end
    no(O.admit(s,"BIRCH SCOUT",100,1,"RAID"));yes(O.admit(s,"Birch Scout",110,1,"WHISPER"))
    s=O.new();for i=1,4 do yes(O.admit(s,"Birch Scout",100,3600,"WHISPER")) end
    no(O.admit(s,"Birch Scout",100,1,"WHISPER"))
    s=O.new();for i=1,26 do yes(O.admit(s,H.abc(i).." Scout",100,3600,"WHISPER")) end
    no(O.admit(s,"Last Scout",100,3600,"WHISPER"));yes(O.admit(s,"Guild Scout",100,3600,"GUILD"))
    s=O.new();for i=1,96 do yes(O.admit(s,H.abc(i).." Scout",100,1,"WHISPER")) end
    no(O.admit(s,"Public Last",100,1,"WHISPER"));yes(O.admit(s,"Guild Scout",100,1,"GUILD"))
    s=O.new();for i=1,120 do yes(O.admit(s,H.abc(i%2+1).." Scout",100,1,"BNET",71)) end
    no(O.admit(s,"Third Name",100,1,"BNET",71))
end)

test("5000 deterministic fuzz frames bounded silent and no saved names",function()
    local N=setup();local before=LayerEnemiesDB.find;local seed=17
    for i=1,5000 do
        seed=(seed*48271)%2147483647
        local text=string.rep(string.char(seed%127),seed%260)
        local ok=pcall(H.deliver,"CHAT_MSG_ADDON","OverlordF",text,i%2==0 and "WHISPER" or "GUILD","Fuzz Scout")
        yes(ok);no(N.Main.error)
    end
    eq(LayerEnemiesDB.find,before);eq(#onlySent(),0);yes(N.Safe.count(N.Main.overlord.pending)<=64)
end)

test("24 fragments, 3600 bytes, duplicate idle and total lifetime",function()
    local N=setup();local O=N.Overlord;local s=O.new();local data=string.rep("a",3600)
    for i=24,1,-1 do
        local w=O.fragment(s,"BF:full:"..i..":24:"..data:sub((i-1)*150+1,i*150),"Birch Scout",100,"WHISPER")
        if i==1 then eq(w,data) else eq(w,nil) end
    end
    eq(O.fragment(s,"BF:bad:1:25:x","Birch Scout",100),false)
    for i=1,16 do
        local w=O.fragment(s,"BF:big:"..i..":16:"..string.rep("b",i==16 and 151 or 230),"Birch Scout",100)
        if i==16 then eq(w,false,"3601 bytes refused") end
    end
    s=O.new()
    for i=1,7 do eq(O.fragment(s,"BF:slow:"..i..":24:x","Birch Scout",100+(i-1)*20),nil) end
    eq(s.pending["birch scout:slow"].got,1,"120 seconds total expires even with new parts")
    s=O.new();O.fragment(s,"BF:idle:1:3:x","Birch Scout",100)
    O.fragment(s,"BF:idle:1:3:x","Birch Scout",129)
    O.fragment(s,"BF:idle:2:3:y","Birch Scout",130)
    eq(s.pending["birch scout:idle"].got,1,"duplicates do not refresh idle")
end)

test("per sender assembly cap and guild reserve",function()
    local N=setup();local O=N.Overlord;local s=O.new()
    for i=1,4 do eq(O.fragment(s,"BF:p"..i..":1:24:x","Birch Scout",100,"WHISPER"),nil) end
    eq(O.fragment(s,"BF:p5:1:24:x","BIRCH SCOUT",100,"PARTY"),false)
    for i=1,100 do O.fragment(s,"BF:other:1:24:x",H.abc(i).." Scout",100,"WHISPER") end
    eq(N.Safe.count(s.pending),48)
    eq(O.fragment(s,"BF:g:1:2:a","Guild Scout",100,"GUILD"),nil)
    eq(O.fragment(s,"BF:g:2:2:b","Guild Scout",100,"GUILD"),"ab")
end)

test("whisper and R2 battle net receive GW; foreign band silent",function()
    local N=setup(); local body="1:Enemy Guild:H:77:6:#1434:42:"..GetServerTime()
    hear("a","GW",body);eq(#N.Main.reportedRows(),1,"whisper received")
    N=setup();N.BNet.who=function(id) return id==71 and {name="Birch Scout",realm="Test Realm",faction="Horde"} end
    H.deliver("BN_CHAT_MSG_ADDON","OverlordF","R2:Forever_pve_H:BR:"..packet("a","GW",body),nil,71)
    eq(#N.Main.reportedRows(),0)
    H.deliver("BN_CHAT_MSG_ADDON","OverlordF","R2:Forever_global_H:BR:"..packet("a","GW",body),nil,71)
    eq(#N.Main.reportedRows(),1,"BNet received")
end)

test("pure peer announces own truthful identity and answers targeted NH",function()
    local N=setup();yes(N.OverlordPeer,"peer exists")
    local P=N.OverlordPeer;local s=P.new();local c=ctx(N)
    P.tick(s,c);eq(#c.out,2);yes(c.out[1].text:find("LayerEnemies 1.3.0",1,true))
    P.receive(s,{origin="Birch Scout",target=c.me,hops=0,kind="NH",payload="2.5.4"},"WHISPER","Birch Scout",nil,c)
    eq(#c.out,3);eq(c.out[3].route,"WHISPER");eq(c.out[3].target,"Birch Scout");eq(c.out[3].prio,"owed")
    no(c.out[3].text:find("2.5.4",1,true));eq(c.out[3].text:match("~.*$"),nil)
end)
