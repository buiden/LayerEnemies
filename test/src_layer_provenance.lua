-- Regression cases adapted from the read-only layer review probes.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local GUID="Player-1-ABC"
local function read(kind,uid,server)
    H.units().target={guid="Creature-0-"..server.."-0-"..uid.."-"..kind.."-ABC",player=false}
    H.deliver("PLAYER_TARGET_CHANGED"); H.drain()
end
local function sight(N,name,guid)
    H.units().target=H.player(name or "Cedar Vale","Horde",guid or GUID)
    H.deliver("PLAYER_TARGET_CHANGED"); H.drain(); H.units().target=nil
end
local function setup(join)
    local N=H.load(); H.establish(N)
    H.units().target=nil; H.units().mouseover=nil
    if join then H.clock(90); H.group(true); H.deliver("GROUP_ROSTER_UPDATE"); H.drain() end
    H.clock(120); H.drain(); yes(N.Main.track("Cedar Vale"))
    return N
end
local function ownLines(first)
    local lines={}
    for i=first+1,#H.sent() do
        local s=H.sent()[i]
        if s.prefix=="LEGW1" and s.text:sub(1,2)=="O|" then
            eq(s.kind,"GUILD"); lines[#lines+1]=s.text
        end
    end
    return lines
end
local function projectionAndWire(N,first,known)
    local r=N.Main.findRows()[1]; yes(r); local text=N.Main.findText(r):lower()
    local lines=ownLines(first); eq(#lines,1,"actual guild sighting send")
    local layer=lines[1]:match("^O|1|[^|]+|[^|]+|[^|]+|[^|]+|([^|]*)|")
    yes(layer~=nil,"valid O shape")
    -- Collect both consumer results before asserting: RED names the lying Find
    -- projection and the actual wire field, not merely a retained object.
    local state=r.status.." / "..tostring(r.same==true).." / "..layer.." / "..tostring(text:find("your layer",1,true)~=nil)
    eq(state,known and "is on YOUR layer / true / 7086 / true" or "seen by you / false /  / false",
        "Find status / same / actual O layer / rendered your-layer wording")
    yes(text:find("cedar vale",1,true)); yes(text:find("ashenvale",1,true)); no(N.Main.error)
end
for _,case in ipairs({"unchanged","NPC server","NPC zoneUID","Bulo","Bulo zoneUID","join30","expiry"}) do
    test("Layer provenance: Find and actual O after "..case,function()
        local N=setup(case=="join30"); local at=N.Main.npcs.last
        if case=="expiry" then H.clock(at+298); H.drain() end
        sight(N); local seen=N.Main.store.localSeen[GUID]; yes(seen)
        eq(seen.layer,"7086-7"); yes(N.Main.findRows()[1].same)
        local serial,first=N.Main.store.serial,#H.sent()
        H.clock(H.clock()+.5)
        if case=="NPC server" or case=="join30" then read(3,7,"9000"); read(4,7,"9000")
        elseif case=="NPC zoneUID" then read(3,8,"7086"); read(4,8,"7086")
        elseif case=="Bulo" or case=="Bulo zoneUID" then
            BuloLayerForever={current=case=="Bulo" and "9000-9" or "7086-8",Radar={seen={}}}; N.Main.poll()
        elseif case=="expiry" then H.clock(at+300); N.Main.poll(); eq(N.Main.store.bulo,nil) end
        H.units().target=nil; H.advance(3); N.Main.shareTick()
        eq(N.Main.store.serial,serial); eq(N.Main.store.localSeen[GUID],seen)
        projectionAndWire(N,first,case=="unchanged")
    end)
end

test("Layer provenance: Bulo refresh cannot rewrite an own sighting key",function()
    local N=setup(); sight(N); local first=#H.sent()
    H.clock(120.5)
    BuloLayerForever={current="9000-9",Radar={seen={[GUID]={at=120.5,src="target",hostile=true}}}}
    N.Main.poll(); eq(N.Main.store.localSeen[GUID].source,"Bulo target")
    eq(N.Main.store.localSeen[GUID].ownAt,120)
    H.advance(3); N.Main.shareTick(); projectionAndWire(N,first,false)
    eq(N.Main.store.localSeen[GUID].ownKey,"7086-7")
end)

test("Layer provenance: five-minute Find history loses same-layer text on expiry",function()
    local N=setup(); sight(N); local at=N.Main.npcs.last
    H.clock(at+299); N.Main.poll(); yes(N.Main.findRows()[1].same)
    H.clock(at+300); N.Main.poll(); eq(N.Main.store.bulo,nil)
    local r=N.Main.findRows()[1]
    eq(r.status,"seen by you"); no(r.same); no(N.Main.findText(r):lower():find("your layer",1,true))
    no(N.Main.error)
end)

test("Layer provenance: reacquisition under the new key restores Find and wire",function()
    local N=setup(); sight(N)
    H.clock(120.5); read(3,9,"9000"); read(4,9,"9000")
    H.clock(121); sight(N); local first=#H.sent()
    H.advance(3); N.Main.shareTick()
    local r=N.Main.findRows()[1]; yes(r.same); eq(r.status,"is on YOUR layer")
    local lines=ownLines(first); eq(#lines,1); yes(lines[1]:find("|9000|",1,true))
    no(N.Main.error)
end)

for _,case in ipairs({"unchanged","rotation","mixed","expiry"}) do
    test("Layer provenance: actual War Effort cohort layer after "..case,function()
        local N=setup(); local at=N.Main.npcs.last
        N.Net.SHIP.we=true; N.Net.setConsent("public")
        if case=="expiry" then H.clock(at+298); H.drain() end
        H.deliver("CHAT_MSG_ADDON","WEFF1","H|1.6.6|100|7086|1|19","GUILD","Birch Scout")
        yes(N.Main.weHeard.GUILD,"real reader hello admitted")
        sight(N)
        if case~="mixed" then sight(N,"Aspen Reed","Player-1-DEF") end
        local first=#H.sent(); H.clock(H.clock()+.5)
        if case=="rotation" or case=="mixed" then
            read(3,7,"9000"); read(4,7,"9000")
            if case=="mixed" then H.clock(121); sight(N,"Aspen Reed","Player-1-DEF") end
        elseif case=="expiry" then H.clock(at+300); N.Main.poll() end
        H.units().target=nil; H.advance(3); N.Main.shareTick(); H.drain()
        local n=0
        for i=first+1,#H.sent() do
            local s=H.sent()[i]
            if s.prefix=="WEFF1" and s.text:sub(1,2)=="C|" then
                local d=N.Protocol.decode(s.text); yes(d); eq(d.count,2)
                eq(d.layer,case=="unchanged" and 7086 or 0,"actual C layer belongs to every own sighting")
                n=n+1
            end
        end
        eq(n,1,"actual guild C sent"); projectionAndWire(N,first,case=="unchanged")
    end)
end

for _,case in ipairs({"rotation","expiry"}) do
    test("Layer provenance: pending K preserves names and gates layer after "..case,function()
        local N=setup(); local at=N.Main.npcs.last
        if case=="expiry" then H.clock(at+299.9); H.drain() end
        sight(N)
        C_DeathRecap={HasRecapEvents=function() return true end,GetRecapEvents=function()
            return {{sourceGUID=GUID,sourceName="Cedar",sourceFlags=0x448,overkill=10,timestamp=H.clock()}}
        end}
        local first=#H.sent(); H.deliver("PLAYER_DEAD")
        if case=="rotation" then read(3,7,"9000"); read(4,7,"9000")
        else H.clock(at+300); N.Main.poll(); eq(N.Main.store.bulo,nil) end
        H.advance(.3)
        local n=0
        for i=first+1,#H.sent() do
            local s=H.sent()[i]
            if s.prefix=="LEGW1" and s.text:sub(1,2)=="K|" then
                n=n+1; local decoded=N.OwnDeath.decode(s.text); yes(decoded); eq(decoded.layer,case=="rotation" and "7086" or nil)
            end
        end
        eq(n,1); no(N.Main.error)
    end)
end
