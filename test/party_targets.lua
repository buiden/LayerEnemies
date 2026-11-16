-- Group-target events use the same unit queue, privacy guards and own-sighting path.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function put(member,name,guid)
    H.units()[member]={visible=true}
    H.units()[member.."target"]=H.player(name or "Cedar Vale","Horde",guid or "Player-1-901")
    H.units()[member.."target"].realm=nil
end
local function fixture()
    local N=H.load(); H.advance(1); put("party2")
    H.deliver("UNIT_TARGET","party2"); H.drain()
    yes(N.Main.store.localSeen["Player-1-901"],"positive control: group-target observation works")
    return N
end
local function absent(N)
    eq(N.Main.store.localSeen["Player-1-902"],nil)
    eq(N.Main.find.known.entries["birch grove"],nil)
    no(N.Main.error); eq(#H.sent(),0)
end

test("PartyTargets 13: UNIT_TARGET is registered and party2target uses the coalesced queue",function()
    local N=H.load(); yes(N.Main.frame.events.UNIT_TARGET); H.advance(1); put("party2")
    N.Main.track("Cedar Vale")
    local original=N.Main.observe; local calls=0
    N.Main.observe=function(u) calls=calls+1; eq(u,"party2target"); return original(u) end
    H.deliver("UNIT_TARGET","party2"); H.deliver("UNIT_TARGET","party2")
    eq(calls,0); yes(N.Main.pendingUnits.party2target); H.drain(); eq(calls,1)
    local e=N.Main.store.localSeen["Player-1-901"]; yes(e); eq(e.source,"own (party target)"); eq(e.zone,100)
    local r=N.Main.findRows()[1]; yes(r.own); yes(r.seen); eq(r.source,"own"); no(r.same); no(r.canAsk)
    yes(N.Main.findText(r):find("own (party target)",1,true)); eq(#H.sent(),0); no(N.Main.error)
end)

test("PartyTargets 13: raid5target is a first-hand own sighting, shared by the existing path",function()
    local N=H.load(); H.advance(1); put("raid5"); N.Main.track("Cedar Vale")
    H.deliver("UNIT_TARGET","raid5"); H.drain()
    local e=N.Main.store.localSeen["Player-1-901"]; yes(e); eq(e.source,"own (party target)")
    yes(N.Main.findRows()[1].seen); eq(#H.sent(),0)
    H.advance(3); N.Main.shareTick()
    local own={}; for _,v in ipairs(H.sent()) do if v.prefix=="LEGW1" and v.text:sub(1,2)=="O|" then own[#own+1]=v end end
    eq(#own,1); eq(own[1].kind,"GUILD"); local r=N.Relay.decodeOwn(own[1].text,"Scout",H.clock())
    yes(r); eq(r.enemies[1].name,"Cedar Vale"); no(N.Main.error)
end)

test("PartyTargets guard: invisible or unreadable members are never observed",function()
    for _,mode in ipairs({"invisible","nil","secret","throw","missing"}) do
        local N=fixture(); put("party2","Birch Grove","Player-1-902")
        UnitIsVisible=mode~="missing" and function(unit)
            eq(unit,"party2","visibility checks the member, not its target")
            if mode=="invisible" then return false elseif mode=="secret" then return H.secret elseif mode=="throw" then error("unreadable") end
        end or nil
        H.deliver("UNIT_TARGET","party2"); H.drain(); absent(N)
    end
end)

test("PartyTargets guard: instance or unreadable instance state refuses observation",function()
    for _,mode in ipairs({"instance","nil","secret","throw","missing"}) do
        local N=fixture(); put("raid5","Birch Grove","Player-1-902")
        IsInInstance=mode~="missing" and function()
            if mode=="instance" then return true elseif mode=="secret" then return H.secret elseif mode=="throw" then error("unreadable") end
        end or nil
        H.deliver("UNIT_TARGET","raid5"); H.drain(); absent(N)
    end
end)

test("PartyTargets guard: visibility and instance are rechecked after queuing",function()
    for _,guard in ipairs({"visibility","instance"}) do
        local N=fixture(); put("party2","Birch Grove","Player-1-902")
        H.deliver("UNIT_TARGET","party2"); yes(N.Main.pendingUnits.party2target)
        if guard=="visibility" then H.units().party2.visible=false else H.instance(true) end
        H.drain(); absent(N)
    end
end)

test("PartyTargets guard: secret unit payload is rejected before matching, concatenation or APIs",function()
    local N=fixture(); put("party2","Birch Grove","Player-1-902")
    local original=issecretvalue
    issecretvalue=function(v) return v=="party2" or original(v) end
    H.deliver("UNIT_TARGET","party2"); H.drain(); issecretvalue=original
    absent(N)
    H.deliver("UNIT_TARGET",H.secret); H.drain(); absent(N)
    -- A secret group-target token also cannot enter through the public queue helper.
    issecretvalue=function(v) return v=="party2target" or original(v) end
    N.Main.queueUnit("party2target"); H.drain(); issecretvalue=original; absent(N)
end)

test("PartyTargets bounds: only party1-4 and raid1-40 members admit target tokens",function()
    local N=fixture(); put("party2","Birch Grove","Player-1-902")
    for _,token in ipairs({"player","target","mouseover","pet","party0","party5","party02","raid0","raid41","raid05","party2target","raid5target",false,{},H.secret}) do
        H.deliver("UNIT_TARGET",token)
    end
    H.deliver("UNIT_TARGET"); H.drain(); absent(N)
    for _,token in ipairs({"party1","party4","raid1","raid40"}) do
        put(token,"Birch Grove","Player-1-902"); H.deliver("UNIT_TARGET",token); yes(N.Main.pendingUnits[token.."target"])
    end
    H.drain(); yes(N.Main.store.localSeen["Player-1-902"]); no(N.Main.error)
end)

test("PartyTargets boundaries: queued old work is discarded and stale targets stay quarantined",function()
    local N=fixture(); put("party2","Birch Grove","Player-1-902")
    H.deliver("UNIT_TARGET","party2"); N.Main.boundary(100); H.drain(); absent(N)
    H.deliver("UNIT_TARGET","party2"); H.drain(); absent(N)
    put("party2","Birch Grove","Player-1-903"); H.advance(1); H.deliver("UNIT_TARGET","party2"); H.drain()
    yes(N.Main.store.localSeen["Player-1-903"]); no(N.Main.error)
end)

test("PartyTargets queue: all 44 member tokens fit alongside 42 existing unit tokens",function()
    local N=fixture()
    for i=1,40 do N.Main.queueUnit("nameplate"..i) end
    N.Main.queueUnit("target"); N.Main.queueUnit("mouseover")
    for i=1,4 do put("party"..i); H.deliver("UNIT_TARGET","party"..i) end
    for i=1,40 do put("raid"..i); H.deliver("UNIT_TARGET","raid"..i) end
    eq(N.Safe.count(N.Main.pendingUnits),86); H.drain(); eq(next(N.Main.pendingUnits),nil); no(N.Main.error)
end)
