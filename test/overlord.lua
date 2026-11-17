-- Independent wire fixtures, never imports/executes the donor.
local H=...
local eq,yes,no=H.eq,H.yes,H.no
local active,attempts
local function rules(hc,rp,pvp)
    Enum.GameRule={HardcoreRuleset=1,RPRuleset=2,PvPRuleset=3}
    local values={[1]=hc,[2]=rp,[3]=pvp}
    C_GameRules={IsGameRuleActive=function(rule) return values[rule] end}
end
local function setup()
    active=H.load()
    rules(false,false,true) -- known PvP pool; never rely on an unknown-pool default
    -- A receiving test must not hide a send behind the gateway's own refusal.
    active.Wire.send=function() attempts=attempts+1; error("Overlord attempted a send") end
    return active
end
local function test(name,fn)
    H.test("Overlord: "..name,function()
        active=nil; attempts=0; fn()
        eq(attempts,0,"not even an attempted gateway send")
        eq(#H.sent(),0,"receive path sends zero lines")
        no(active and active.Main.error,"no swallowed runtime error")
    end)
end
local function gw(o)
    o=o or {}
    return table.concat({"1",o.guild or "Enemy Guild",o.faction or "H",o.kills or 77,o.members or 6,
        o.zone or "#1434",o.layer or 12345,o.ts or GetServerTime()},":")
end
local function packet(o)
    o=o or {}
    return table.concat({o.pool or "global",o.id or "pkt-1",o.at or GetServerTime(),o.target or "*",
        o.path or "Birch Scout",o.kind or "GW",o.payload or gw()},"|")
end
local function bf(wire,id,part,count) return "BF:"..(id or "pkt-1")..":"..(part or 1)..":"..(count or 1)..":"..wire end
local function hear(text,route,sender)
    if route==nil then route="GUILD" end
    if sender==nil then sender="Birch Scout" end
    H.deliver("CHAT_MSG_ADDON","OverlordF",text,route,sender)
end
local function maps()
    local prior=C_Map.GetMapInfo
    C_Map.GetMapInfo=function(id)
        if id==1434 then return {name="Stranglethorn Vale",mapType=3} end
        return prior(id)
    end
end

for _,reverse in ipairs({false,true}) do
    test("two parts join in either order reverse="..tostring(reverse),function()
        local N=setup(); local Ov=N.Overlord; local st=Ov.new(); local w=packet(); local a,b=w:sub(1,30),w:sub(31)
        local first=reverse and 2 or 1; local last=3-first
        eq(Ov.fragment(st,bf(first==1 and a or b,nil,first,2),"Birch Scout",10),nil)
        eq(Ov.fragment(st,bf(last==1 and a or b,nil,last,2),"Other Scout",10),nil,"never cross sender")
        local wire,id=Ov.fragment(st,bf(last==1 and a or b,nil,last,2),"BIRCH SCOUT",11)
        eq(wire,w); eq(id,"pkt-1"); yes(Ov.packet(wire,id,"Birch Scout",GetServerTime()))
        eq(N.Safe.count(st.pending),1,"completed assembly removed; foreign pending remains")
        hear(bf(a,nil,1,2)); eq(#N.Main.reportedRows(),0); hear(bf(b,nil,2,2)); eq(#N.Main.reportedRows(),1)
    end)
end

test("fragment frame bounds and single-part fast path",function()
    local N=setup(); local Ov=N.Overlord
    local st=Ov.new()
    for _,text in ipairs({"BF::1:1:x","BF:"..string.rep("a",65)..":1:1:x","BF:a_b:1:1:x","BF:a:0:1:x",
        "BF:a:2:1:x","BF:a:1:3:x","BF:a:1:24:x","BF:a:1:25:x","BF:a:1.5:2:x","BF:a:1:1.5:x",
        "BF:a:1:0:x","BF:a:1:1:"..string.rep("x",231),"BF:"..string.rep("a",17)..":1:1:"..string.rep("x",231),
        "BF:"..string.rep("a",18)..":1:1:"..string.rep("x",230),"not a frame"}) do
        eq(Ov.fragment(st,text,"Birch Scout",10),false,text:sub(1,70))
    end
    eq(Ov.fragment(st,"BF:"..string.rep("a",64)..":1:1:x","Birch Scout",10),"x")
    eq(Ov.fragment(st,"BF:"..string.rep("a",17)..":1:1:"..string.rep("x",230),"Birch Scout",10),string.rep("x",230))
    eq(N.Safe.count(st.pending),0,"singles never use pending slots")
end)

test("fragment duplicate conflicts and timeout do not extend assembly life",function()
    local N=setup(); local Ov=N.Overlord; local st=Ov.new()
    eq(Ov.fragment(st,"BF:wait:1:2:a","Birch Scout",10),nil)
    eq(Ov.fragment(st,"BF:wait:1:2:a","Birch Scout",39),nil)
    eq(Ov.fragment(st,"BF:wait:1:2:b","Birch Scout",39),false,"conflict")
    eq(Ov.fragment(st,"BF:wait:2:2:b","Birch Scout",40),nil,"30s expires from first part")
    eq(Ov.fragment(st,"BF:wait:1:2:a","Birch Scout",41),"ab")
    eq(next(st.pending),nil)
    eq(Ov.fragment(st,"BF:rollback:1:2:a","Birch Scout",50),nil)
    eq(Ov.fragment(st,"BF:rollback:2:2:b","Birch Scout",49),nil,"clock rollback discards partial")
end)

test("33 pending evicts oldest including same-time arrivals",function()
    local N=setup(); local Ov=N.Overlord; local st=Ov.new()
    for i=1,33 do eq(Ov.fragment(st,"BF:p"..i..":1:2:a","Birch Scout",10),nil) end
    eq(N.Safe.count(st.pending),32)
    eq(Ov.fragment(st,"BF:p2:2:2:b","Birch Scout",11),"ab","second oldest survived")
    eq(Ov.fragment(st,"BF:p1:2:2:b","Birch Scout",11),nil,"oldest dropped")
    Ov.sweep(st,41); eq(next(st.pending),nil,"idle sweep")
end)

test("packet identity exact seven fields broadcast and allowed kinds",function()
    local N=setup(); local Ov=N.Overlord; local wall=GetServerTime()
    for _,o in ipairs({{id="other"},{target="Birch Scout"},{kind="GE"},{kind="EK"},{kind="BOGUS"},
        {payload=gw().."|extra"},{payload=gw().."\n"}}) do eq(Ov.packet(packet(o),"pkt-1","Birch Scout",wall),nil) end
    eq(Ov.packet(packet()..string.rep("x",3600),"pkt-1","Birch Scout",wall),nil)
    local p=Ov.packet(packet({pool="unrelated-pool"}),"pkt-1","Birch Scout",wall)
    yes(p); eq(p.origin,"Birch Scout"); eq(p.kind,"GW"); eq(p.payload,gw())
end)

test("packet path one to four no repeats and last sender",function()
    local N=setup(); local Ov=N.Overlord; local wall=GetServerTime()
    for _,path in ipairs({"",",Birch Scout","Birch Scout,","Birch Scout,,Birch Scout","Other Scout",
        "Birch Scout,Other Scout","Other Scout,Birch Scout,OTHER SCOUT,Birch Scout",
        "Aa One,Bb Two,Cc Three,Dd Four,Birch Scout","Bad|Name","Birch Scout-Elsewhere"}) do
        eq(Ov.packet(packet({path=path}),"pkt-1","Birch Scout",wall),nil,path)
    end
    for _,path in ipairs({"Birch Scout","Origin Scout,Birch Scout","Origin Scout,Next Scout,Last Scout,Birch Scout"}) do
        yes(Ov.packet(packet({path=path}),"pkt-1","BIRCH SCOUT",wall),path)
    end
end)

test("packet age accepts 120 not 121 and skew 30 not 31",function()
    local N=setup(); local Ov=N.Overlord; local wall=GetServerTime()
    for _,delta in ipairs({-120,-119,0,30}) do yes(Ov.packet(packet({at=wall+delta}),"pkt-1","Birch Scout",wall)) end
    for _,at in ipairs({wall-121,wall+31,wall+.5,"nan","inf","1e6","-1"}) do
        eq(Ov.packet(packet({at=at}),"pkt-1","Birch Scout",wall),nil,tostring(at))
    end
end)

test("origin id ring takes once and caps at 256",function()
    local N=setup(); local Ov=N.Overlord; local st=Ov.new()
    yes(Ov.seen,"dedupe function exists"); no(Ov.seen(st,"Birch Scout","a")); yes(Ov.seen(st,"BIRCH SCOUT","a"))
    no(Ov.seen(st,"Other Scout","a"))
    for i=1,254 do no(Ov.seen(st,"Birch Scout","p"..i)) end
    yes(Ov.seen(st,"Birch Scout","a")); no(Ov.seen(st,"Birch Scout","overflow"))
    eq(N.Safe.count(st.seen),256); no(Ov.seen(st,"Birch Scout","a"),"oldest evicted")
    hear(bf(packet())); local at=N.Main.reportedRows()[1].at
    H.clock(H.clock()+1); hear(bf(packet({payload=gw({kills=88})})))
    eq(N.Main.reportedRows()[1].kills,77); eq(N.Main.reportedRows()[1].at,at)
    eq(N.Main.overlord.stats.taken,1)
end)

local function gd(o)
    o=o or {}
    return table.concat({o.faction or "A",o.pool or "global",o.ts or GetServerTime(),o.killer or "Cedar Vale",
        o.class or "MAGE",o.zone or "#1434",o.epoch or 0,o.victim or "Birch Scout"},":")
end
local function ek(o)
    o=o or {}
    return table.concat({o.killer or "Cedar Vale",o.class or "MAGE",o.faction or "Horde",o.ts or GetServerTime(),
        o.zone or "#1434",o.epoch or 0},":")
end
test("foreign packet pools are refused before evidence or dedupe",function()
    for _,kind in ipairs({"GW","GD"}) do for _,route in ipairs({"GUILD","PARTY","RAID"}) do
        local N=setup(); N.Main.track("Cedar Vale"); local logged=#H.log()
        for _,pool in ipairs({"pve","rpg","rpv","hc","unrelated-pool","","GLOBAL"}) do
            hear(bf(packet({pool=pool,kind=kind,payload=kind=="GW" and gw() or gd()})),route)
            eq(N.Main.overlord.stats.taken,0,"foreign pool "..pool)
            eq(#N.Main.reportedRows(),0); eq(next(N.Main.find.known.entries),nil)
            eq(next(N.Main.overlord.seen),nil,"refusal cannot poison a later matching packet")
        end
        eq(#H.log(),logged,"pool refusal is silent")
        hear(bf(packet({kind=kind,payload=kind=="GW" and gw() or gd()})),route)
        eq(N.Main.overlord.stats.taken,1,"matching packet accepted with the same identity")
    end end
end)

test("unknown own pool accepts no wrapped direct or partial traffic and recovers without reload",function()
    for _,mode in ipairs({"missing","nil","secret","throw","partial","enum","lookup"}) do
        local N=setup(); N.Main.track("Cedar Vale"); local logged=#H.log()
        GetRealmName=function() return "7102" end -- numeric realm is not a ruleset
        if mode=="missing" then C_GameRules=nil
        elseif mode=="nil" then C_GameRules.IsGameRuleActive=function() return nil end
        elseif mode=="secret" then C_GameRules.IsGameRuleActive=function() return H.secret end
        elseif mode=="throw" then C_GameRules.IsGameRuleActive=function() error("unreadable rules") end
        elseif mode=="partial" then rules(nil,false,true)
        elseif mode=="enum" then Enum.GameRule=H.secret
        else C_GameRules=setmetatable({}, {__index=function() error("unreadable API") end}) end
        hear(bf(packet())); hear(bf(packet({kind="GD",payload=gd()})))
        for _,route in ipairs({"PARTY","RAID"}) do
            hear("GW:"..gw(),route); hear("GD:"..gd(),route); hear("EK:"..ek(),route)
        end
        hear("BF:partial:1:2:global|")
        eq(N.Main.overlord.stats.taken,0,mode); eq(#N.Main.reportedRows(),0)
        eq(next(N.Main.find.known.entries),nil); eq(next(N.Main.overlord.pending),nil)
        eq(next(N.Main.overlord.seen),nil); eq(#H.log(),logged); no(N.Main.error)
        rules(false,false,true); hear(bf(packet())); eq(N.Main.overlord.stats.taken,1)
    end
end)

test("pool detection maps readable rules and explicit realm fallback without a PvP guess",function()
    for _,v in ipairs({{false,false,true,"global"},{false,false,false,"pve"},
        {false,true,false,"rpg"},{false,true,true,"rpv"},{true,true,true,"hc"}}) do
        local N=setup(); rules(v[1],v[2],v[3]); hear(bf(packet({pool=v[4]})))
        eq(N.Main.overlord.stats.taken,1,v[4])
        hear(bf(packet({id="wrong",pool=v[4]=="global" and "pve" or "global"}),"wrong"))
        eq(N.Main.overlord.stats.taken,1,"another campaign refused")
    end
    for _,v in ipairs({{"Classic PvP","global"},{"Classic PvE 2","pve"},{"Classic RP","rpg"},
        {"Classic Roleplay PvP","rpv"},{"Classic RPPvP","rpv"},{"Classic Hardcore","hc"}}) do
        local N=setup(); C_GameRules=nil; GetRealmName=function() return v[1] end
        hear(bf(packet({pool=v[2]}))); eq(N.Main.overlord.stats.taken,1,v[1])
    end
    local N=setup(); rules(false,false,false); GetRealmName=function() return "Classic PvP" end
    hear(bf(packet())); eq(N.Main.overlord.stats.taken,1,"explicit realm corrects startup all-false rules")
end)

test("GD foreign payload pool is refused on both direct and wrapped routes",function()
    local N=setup(); N.Main.track("Cedar Vale")
    hear("GD:"..gd({pool="pve"}),"PARTY")
    hear(bf(packet({kind="GD",payload=gd({pool="pve"})})))
    eq(N.Main.overlord.stats.taken,0); eq(next(N.Main.find.known.entries),nil)
    hear(bf(packet({kind="GD",payload=gd()}))); eq(N.Main.overlord.stats.taken,1)
end)

for _,kind in ipairs({"GD","EK"}) do
    test(kind.." tracked killer claim reaches Find for one hour with no Ask",function()
        local N=setup(); maps(); N.Main.track("Cedar Vale")
        local oldLogs=#H.log(); local at=H.clock()
        if kind=="GD" then hear(bf(packet({kind="GD",payload=gd()}))) else hear("EK:"..ek(),"PARTY") end
        local r=N.Main.findRows()[1]; yes(r.reported,"killer claim admitted")
        eq(r.status,"named as killer (claim)"); eq(r.zone,1434); eq(r.at,at)
        eq(r.reported.source,"overlord"); eq(r.layer,nil); no(r.canAsk); no(r.same); no(r.probably)
        yes(N.Main.findText(r):find("Stranglethorn Vale",1,true)); eq(#N.Main.reportedRows(),0)
        eq(#H.log(),oldLogs,"receipt prints nothing"); eq(next(N.Main.relay.pending),nil)
        N.UI.toggle(); N.UI.select("find"); no(N.UI.pool[1].ask:IsShown()); eq(N.UI.pool[1].hopRecord,false)
        H.clock(at+3599); yes(N.Main.findRows()[1].reported)
        H.clock(at+3600); eq(N.Main.findRows()[1].reported,nil)
    end)
end

test("untracked killers never enter Known even before later tracking",function()
    local N=setup()
    hear(bf(packet({kind="GD",payload=gd()}))); hear("EK:"..ek(),"RAID")
    eq(next(N.Main.find.known.entries),nil)
    N.Main.track("Cedar Vale"); eq(N.Main.findRows()[1].at,nil)
end)

test("tracked matcher keeps foreign realms distinct and supports unqualified names",function()
    local N=setup(); N.Main.track("Cedar Vale-RealmA")
    hear("EK:"..ek({killer="Cedar Vale-RealmB"}),"PARTY")
    eq(next(N.Main.find.known.entries),nil)
    hear("EK:"..ek({killer="Cedar Vale-RealmA"}),"PARTY"); yes(N.Main.findRows()[1].reported)
    N=setup(); N.Main.track("Cedar Vale")
    hear("EK:"..ek({killer="Cedar Vale-RealmB"}),"PARTY"); yes(N.Main.findRows()[1].reported)
end)

test("guildmate shared tracked killer is admitted without adding saved names",function()
    local N=setup(); local W=N.Watch; local st=N.Main.watch; local hash=W.hash("Cedar Vale")
    st.held["guild scout"]={name="Guild Scout",at=H.clock(),hashes={[hash]=true}}
    st.byHash[hash]={["guild scout"]=true}; st.count=1
    hear("EK:"..ek(),"PARTY")
    yes(N.Known.get(N.Main.find.known,"Cedar Vale",H.clock()))
    eq(#LayerEnemiesDB.tracked,0)
    N.Main.track("Cedar Vale"); yes(N.Main.findRows()[1].reported)
end)

test("claim never overwrites an existing first-hand Ask target",function()
    local N=setup(); N.Main.track("Cedar Vale")
    N.Find.report(N.Main.find,{sender="Local Scout",zone=100,at=H.clock(),source="guild",enemies={{name="Cedar Vale"}}})
    hear("EK:"..ek({zone="#100"}),"RAID")
    local r=N.Main.findRows()[1]; eq(r.spotter,"Local Scout"); yes(r.canAsk); yes(r.reported)
    no(r.reported.canAsk); eq(r.reported.layer,nil)
end)

test("direct route matrix EK only group and no whisper or channel",function()
    for _,route in ipairs({"GUILD","WHISPER","CHANNEL","SAY"}) do
        local N=setup(); N.Main.track("Cedar Vale")
        hear("EK:"..ek(),route); eq(next(N.Main.find.known.entries),nil,route)
        hear(bf(packet({kind="EK",payload=ek()})),route); eq(next(N.Main.find.known.entries),nil,route)
        hear("GW:"..gw(),route); eq(#N.Main.reportedRows(),0,route)
        if route~="GUILD" then hear(bf(packet()),route); eq(#N.Main.reportedRows(),0,route) end
    end
    for _,route in ipairs({"PARTY","RAID"}) do
        for _,kind in ipairs({"GW","GD","EK"}) do
            local N=setup(); N.Main.track("Cedar Vale")
            hear(kind..":"..(kind=="GW" and gw() or kind=="GD" and gd() or ek()),route)
            if kind=="GW" then eq(#N.Main.reportedRows(),1) else yes(N.Main.findRows()[1].reported) end
            hear(bf(packet({kind="EK",payload=ek()})),route)
            eq(N.Main.overlord.stats.taken,1,"wrapped EK never taken")
        end
    end
end)

test("killer payload exact fields no unknown killer and source age retained",function()
    local N=setup(); local Ov=N.Overlord; yes(Ov.gd); yes(Ov.ek)
    local d=Ov.gd(gd()); eq(d.killer,"Cedar Vale"); eq(d.victim,"Birch Scout"); eq(d.map,1434); eq(d.ts,GetServerTime())
    d=Ov.ek(ek()); eq(d.killer,"Cedar Vale"); eq(d.map,1434); eq(d.ts,GetServerTime())
    for _,o in ipairs({{killer="?"},{killer=""},{killer="Bad|Name"},{class="bad class"},{faction="X"},{zone="##1434"},{epoch="-1"},{ts="nan"}}) do
        eq(Ov.gd(gd(o)),nil); eq(Ov.ek(ek(o)),nil)
    end
    eq(Ov.gd(gd()..":extra"),nil); eq(Ov.ek(ek()..":extra"),nil)
    N.Main.track("Cedar Vale"); hear("EK:"..ek({ts=GetServerTime()-120}),"PARTY")
    eq(N.Main.findRows()[1].age,120)
    N=setup(); N.Main.track("Cedar Vale")
    hear("EK:"..ek({ts=GetServerTime()-121}),"PARTY"); eq(next(N.Main.find.known.entries),nil)
    hear("EK:"..ek({ts=GetServerTime()+31}),"PARTY"); eq(next(N.Main.find.known.entries),nil)
    hear("EK:"..ek({ts=GetServerTime()+30}),"PARTY"); eq(N.Main.findRows()[1].age,0)
end)

test("GW bounds faction timestamp and unknown places",function()
    local N=setup(); local Ov=N.Overlord; local wall=GetServerTime()
    for _,o in ipairs({{kills=10000},{members=1000},{layer=100000000},{layer=-1},{kills=49},{members=4},
        {ts=wall-301},{ts=wall+31},{ts=wall+.5},{faction="X"},{guild=""},{guild=string.rep("a",25)},
        {guild=" Bad"},{guild="Bad "},{guild="Bad  Name"},{guild="Bad%Name"},{guild="Bad,Name"},
        {zone="##1434"},{zone="#abc"},{zone=string.rep("a",41)},{zone="front:bad"}}) do
        eq(Ov.gw(gw(o),wall),nil,tostring(o.guild or o.zone or o.ts or o.kills or o.members or o.layer))
    end
    yes(Ov.gw(gw({kills=9999,members=999,layer=99999999,ts=wall-300}),wall))
    hear(bf(packet({payload=gw({faction="A"})}))); eq(#N.Main.reportedRows(),0,"own faction")
    for _,ref in ipairs({"@front7","capture-zone","#9999",""}) do
        N=setup(); hear(bf(packet({payload=gw({zone=ref,layer=""})})))
        eq(#N.Main.reportedRows(),1); local r=N.Main.reportedRows()[1]
        eq(r.zone,nil); eq(r.layer,nil); yes(N.Main.overlordText(r):find("place unknown, layer unknown",1,true))
    end
end)

test("GW one per guild capped expiring and survives zone or layer boundary",function()
    local N=setup(); hear(bf(packet({payload=gw({ts=GetServerTime()-1})})))
    local at=N.Main.reportedRows()[1].at
    hear(bf(packet({id="new",payload=gw({guild="ENEMY GUILD",kills=90})}),"new"))
    eq(#N.Main.reportedRows(),1); eq(N.Main.reportedRows()[1].kills,90)
    N.Main.boundary(200,true); eq(#N.Main.reportedRows(),1)
    H.clock(at+300); eq(#N.Main.reportedRows(),1)
    H.clock(at+301); eq(#N.Main.reportedRows(),0)
    N=setup()
    for i=1,33 do
        H.clock(10+i); local id="guild"..i
        hear(bf(packet({id=id,payload=gw({guild="Guild "..H.abc(i)})}),id))
    end
    eq(N.Safe.count(N.Main.overlord.guilds),32)
    eq(N.Main.overlord.guilds["guild a"],nil); yes(N.Main.overlord.guilds["guild ag"])
    H.clock(1); eq(#N.Main.reportedRows(),0,"clock rollback")
end)

test("GD claim time is not assumed to be kill time or renewed on arrival",function()
    local N=setup(); N.Main.track("Cedar Vale")
    hear(bf(packet({kind="GD",payload=gd({ts=GetServerTime()-1200})})))
    local r=N.Main.findRows()[1]; yes(r.reported); eq(r.age,1200)
    H.clock(H.clock()+2399); yes(N.Main.findRows()[1].reported)
    H.clock(H.clock()+1); eq(N.Main.findRows()[1].reported,nil)
    for _,age in ipairs({3600,3601,-31}) do
        N=setup(); N.Main.track("Cedar Vale")
        hear(bf(packet({kind="GD",payload=gd({ts=GetServerTime()-age})})))
        eq(next(N.Main.find.known.entries),nil)
    end
end)

test("bad origin id or sender cannot poison a later valid packet",function()
    local N=setup()
    hear(bf(packet({id="other"}))); hear(bf(packet({path="Other Scout"})))
    eq(#N.Main.reportedRows(),0)
    hear(bf(packet())); eq(#N.Main.reportedRows(),1); eq(N.Main.overlord.stats.taken,1)
end)

test("secrets malformed and throwing APIs are silent",function()
    local N=setup(); local Ov=N.Overlord; local st=Ov.new(); local wall=GetServerTime()
    for _,v in ipairs({H.secret,{},false,123}) do
        eq(Ov.fragment(st,v,"Birch Scout",10),false); eq(Ov.packet(v,"pkt-1","Birch Scout",wall),nil)
        eq(Ov.gw(v,wall),nil); eq(Ov.gd(v),nil); eq(Ov.ek(v),nil)
        hear(v); hear(bf(packet()),v); hear(bf(packet()),"GUILD",v)
    end
    eq(Ov.fragment(st,bf(packet()),H.secret,10),false)
    eq(Ov.fragment(st,bf(packet()),"Birch Scout",H.secret),false)
    eq(Ov.packet(packet(),"pkt-1","Birch Scout",H.secret),nil)
    eq(Ov.gw(gw(),H.secret),nil)
    local logged=#H.log()
    UnitFactionGroup=function() return H.secret end; hear(bf(packet())); eq(#N.Main.reportedRows(),0)
    UnitFactionGroup=function() return "Alliance" end
    C_Map.GetMapInfo=function() return setmetatable({}, {__index=function() error("unreadable map") end}) end
    hear(bf(packet())); no(N.Main.error); eq(#H.log(),logged)
end)

test("combat and instance unreadable gates do no map scans",function()
    for _,mode in ipairs({"combat","instance","combat secret","instance secret"}) do
        local N=setup(); local calls=0
        C_Map.GetMapInfo=function() calls=calls+1; error("must not scan") end
        if mode=="combat" then H.combat(true)
        elseif mode=="instance" then H.instance(true)
        elseif mode=="combat secret" then InCombatLockdown=function() return H.secret end
        else IsInInstance=function() return H.secret end end
        hear(bf(packet())); eq(#N.Main.reportedRows(),0); eq(calls,0)
        eq(next(N.Main.overlord.pending),nil)
    end
end)

test("net diagnostic shows the currently detected pool on the Overlord line",function()
    local N=setup()
    for _,case in ipairs({{false,false,true,"global"},{false,false,false,"pve"},
        {false,true,false,"rpg"},{false,true,true,"rpv"},{true,false,true,"hc"}}) do
        rules(case[1],case[2],case[3]); local before=#H.log()
        SlashCmdList.LAYERENEMIES("net")
        local found
        for i=before+1,#H.log() do
            local line=H.log()[i]
            if line:find("Overlord session:",1,true) then found=line end
        end
        yes(found,"Overlord has its own diagnostic line")
        yes(found:find("pool "..case[4],1,true),"diagnostic names the detected "..case[4].." pool")
        no(found:find("unknown",1,true)); yes(found:find("lines=0 taken=0 refused=0",1,true))
        eq(N.Main.overlord.stats.lines,0,"diagnostic does not receive traffic")
    end
end)

test("net diagnostic explains unknown pool receives nothing and updates on recovery",function()
    local N=setup(); GetRealmName=function() return "7102" end
    for _,mode in ipairs({"missing","partial","enum","throw"}) do
        rules(false,false,true)
        if mode=="missing" then C_GameRules=nil
        elseif mode=="partial" then rules(false,false,nil)
        elseif mode=="enum" then Enum.GameRule.HardcoreRuleset=nil
        else C_GameRules.IsGameRuleActive=function() error("not readable") end end
        local before=#H.log(); SlashCmdList.LAYERENEMIES("net")
        local found
        for i=before+1,#H.log() do
            local line=H.log()[i]
            if line:find("Overlord session:",1,true) then found=line end
        end
        yes(found and found:find("pool unknown (receiving nothing)",1,true),mode.." explains fail-closed receipt")
        eq(N.Main.overlord.stats.taken,0); eq(N.Main.overlord.stats.refused,0)
    end
    rules(false,false,true); local before=#H.log(); SlashCmdList.LAYERENEMIES("net")
    local text=table.concat(H.log(),"\n",before+1)
    yes(text:find("pool global",1,true)); no(text:find("receiving nothing",1,true),"diagnostic reflects recovered pool immediately")
end)

test("session counters diagnostics and no added SavedVariables",function()
    local N=setup(); hear(bf(packet())); hear(bf(packet())); hear("bad")
    eq(N.Main.overlord.stats.lines,3); eq(N.Main.overlord.stats.taken,1); eq(N.Main.overlord.stats.refused,1)
    SlashCmdList.LAYERENEMIES("net")
    yes(table.concat(H.log(),"\n"):find("Overlord session: lines=3 taken=1 refused=1",1,true))
    local allowed={options=true,tracked=true,position=true,guildHost=true,consent=true,nets=true,share=true,call=true,callArt=true,
        netNotice=true,autoHop=true,weReportId=true,findShare=true,findNotice=true,quietWhispers=true}
    for k in pairs(LayerEnemiesDB) do yes(allowed[k],"no new save field "..k) end
    local function walk(v)
        if type(v)~="table" then return end
        no(v==N.Main.overlord or v==N.Main.overlord.guilds or v==N.Main.overlord.pending or v==N.Main.find.known)
        for _,child in pairs(v) do walk(child) end
    end
    walk(LayerEnemiesDB)
end)

test("malformed frame fuzz bounded state and zero sends",function()
    local N=setup(); local Ov=N.Overlord; local st=Ov.new(); local wall=GetServerTime()
    math.randomseed(73021)
    for i=1,5000 do
        local chars={}
        for j=1,math.random(0,500) do chars[j]=string.char(math.random(0,255)) end
        local text=table.concat(chars)
        -- Exercise public parsers, plus real event ingress. No dependency mocks of decoder code.
        local ok=pcall(function()
            Ov.fragment(st,text,"Birch Scout",10); Ov.packet(text,"pkt-1","Birch Scout",wall)
            Ov.direct(text); Ov.gw(text,wall); Ov.gd(text); Ov.ek(text); hear(text)
        end)
        yes(ok,"fuzz "..i); no(N.Main.error)
    end
    for i=1,2000 do
        hear("BF:f"..i..":1:2:"..string.rep("x",200))
        yes(N.Safe.count(N.Main.overlord.pending)<=32)
    end
    eq(next(N.Main.find.known.entries),nil); eq(#N.Main.reportedRows(),0)
end)

test("map lookup failures cannot consume packet identity and secret names refuse",function()
    local N=setup(); local original=C_Map.GetMapInfo
    C_Map.GetMapInfo=function() return setmetatable({}, {__index=function() error("unreadable") end}) end
    hear(bf(packet())); eq(#N.Main.reportedRows(),0)
    C_Map.GetMapInfo=original; maps(); hear(bf(packet())); eq(#N.Main.reportedRows(),1)
    N=setup(); C_Map.GetMapInfo=function() return {name=H.secret,mapType=3} end
    hear(bf(packet())); eq(#N.Main.reportedRows(),0,"secret map name must skip row")
    local d=N.Overlord.gw(gw({zone="#1000000"}),GetServerTime()); yes(d); eq(d.map,1000000)
end)

test("slash Reported shows guild claim but no hop record",function()
    local N=setup(); maps(); hear(bf(packet()))
    SlashCmdList.LAYERENEMIES("reports")
    yes(table.concat(H.log(),"\n"):find("guild Enemy Guild: 77 kills by 6 in Stranglethorn Vale, layer 12345 (Overlord claim)",1,true))
    eq(#N.Main.hopList.records,0)
end)

test("secret map objects or map types skip the entire claim",function()
    for _,mode in ipairs({"object","type","parent"}) do
        local N=setup()
        C_Map.GetMapInfo=function()
            if mode=="object" then return H.secret end
            return {name="Secret place",mapType=mode=="type" and H.secret or 3,parentMapID=mode=="parent" and H.secret or 0}
        end
        hear(bf(packet())); eq(#N.Main.reportedRows(),0,mode)
        N.Main.track("Cedar Vale"); hear("EK:"..ek(),"PARTY")
        eq(next(N.Main.find.known.entries),nil,mode)
    end
end)

test("32 rampages use normal measured Reported rows with several per page and no overlap",function()
    local N=setup(); maps()
    for i=1,32 do
        local id="page"..i
        hear(bf(packet({id=id,payload=gw({guild="Guild "..H.abc(i)})}),id))
    end
    eq(#N.Main.reportedRows(),32)
    local U=N.UI; U.toggle(); U.select("reported")
    local seen={}
    local function page()
        local count,bottom=0,0
        for _,r in ipairs(U.pool) do if r:IsShown() then
            count=count+1; seen[r.title:GetText()]=true
            local top=-r.point[5]
            local measured=math.max(24,math.ceil(r.sub:GetStringHeight()))
            eq(r.sub.height,measured,"no oversized rampage-only text minimum")
            eq(r.height,math.max(80,26+measured+32+4)-4,"normal measured Reported card height")
            yes(top>=bottom,"cards must not overlap"); bottom=top+r.height
            yes(bottom<=U.body.height,"each complete row stays on its page")
            yes(26+r.sub.height<=r.height,"the full detail stays inside its card")
            no(r.ask:IsShown()); eq(r.hopRecord,false)
        end end
        return count
    end
    yes(page()>=3,"32 normal rampages must show several rows per page")
    for _=1,32 do U.body.scripts.OnMouseWheel(nil,-1); page() end
    eq(N.Safe.count(seen),32,"every rampage is reachable")
end)

test("single guild rampage reaches Reported without a hop",function()
    local N=setup(); maps(); hear(bf(packet()))
    yes(N.Main.overlord,"receive-only state exists")
    local rows=N.Main.reportedRows(); eq(#rows,1)
    local r=rows[1]; eq(r.guild,"Enemy Guild"); eq(r.kills,77); eq(r.members,6)
    eq(r.zone,1434); eq(r.layer,12345); eq(r.record,nil)
    eq(N.Main.overlordText(r),"guild Enemy Guild: 77 kills by 6 in Stranglethorn Vale, layer 12345 (Overlord claim)")
    N.UI.toggle(); N.UI.select("reported"); local ui=N.UI.pool[1]
    eq(ui.title:GetText(),"guild Enemy Guild"); yes(ui.sub:GetText():find("77 kills by 6",1,true))
    yes(ui.sub:GetText():find("layer 12345 (Overlord claim)",1,true)); no(ui.ask:IsShown()); eq(ui.hopRecord,false)
    eq(#N.Store.reporters(N.Main.store,H.clock()),0); eq(next(N.Main.relay.pending),nil)
    yes(H.registered().OverlordF); eq(#N.Main.findRows(),0)
end)
