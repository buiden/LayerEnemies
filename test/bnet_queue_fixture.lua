-- Composition-aware queue fixtures; exercise real registrations and real budgets.
-- No production source is disabled, replaced or unregistered by these tests.
local h=...
local yes,eq=h.yes,h.eq
local F={}
function F.register(N,name,prefix)
    N.fixtureCounters=N.fixtureCounters or {}
    if N.fixtureCounters[name] then yes(N.Sources.owns(prefix));return N.fixtureCounters[name] end
    if N.Sources.has(name) then
        if name=="overlord" then
            eq(prefix,"OverlordF");yes(N.OverlordPeer and N.OverlordPeer.stats)
            N.Net.SHIP.overlord=N.shipped.overlord
            Enum.GameRule={HardcoreRuleset=1,RPRuleset=2,PvPRuleset=3}
            C_GameRules={IsGameRuleActive=function(i) return i==3 end}
            return N.OverlordPeer.stats
        end
        eq(name,"wanted","only shipped transport registrations are reused")
        yes(N.Sources.owns(prefix)); yes(N.Wanted and N.Wanted.stats)
        -- loadAddon disables every already-shipped transport for test isolation.
        -- Restore only this queue test's real Wanted lane, as for new registrations.
        eq(N.shipped.wanted,true); N.Net.SHIP.wanted=N.shipped.wanted
        return N.Wanted.stats
    end
    local counters={}
    yes(N.Sources.register{name=name,prefixes={prefix},counters=counters})
    N.fixtureCounters[name]=counters
    return counters
end
function F.defaultShare(N)
    -- Independent specification formula; never call the queue's share helper.
    return math.max(1,math.floor(30/#N.Sources.lines()))
end
function F.mixed(N)
    local rows={{"wanted","WNTDB",4},{"overlord","OverlordF",8},{"warboard","WBQueue",10},
        {"alpha","AlphaQueue",4},{"beta","BetaQueue",4}}
    for _,r in ipairs(rows) do r.c=F.register(N,r[1],r[2]) end
    yes(F.defaultShare(N)>=4,"fixture has enough default share to saturate thirty")
    return rows
end
function F.fill(N,amount,prio,tag)
    local filled,serial=0,0
    -- Reuse configured shares before growing the registry. An additional shipped
    -- source lowers default shares; keep the same exact 52/60 queue boundaries.
    N.fixtureFill=N.fixtureFill or {}
    for _,r in ipairs({{"wanted","WNTDB",4},{"overlord","OverlordF",8},{"warboard","WBQueue",10}}) do
        F.register(N,r[1],r[2])
        local used=N.fixtureFill[r[1]] or 0
        for i=used+1,math.min(r[3],used+amount-filled) do
            yes(N.BNet.send(r[1],71,r[2],tag..":"..i,prio))
            filled=filled+1;N.fixtureFill[r[1]]=i
        end
    end
    while filled<amount do
        serial=serial+1
        local name,prefix=tag..h.abc(serial),"Fill"..tag..serial
        F.register(N,name,prefix)
        for i=1,math.min(F.defaultShare(N),amount-filled) do
            yes(N.BNet.send(name,71,prefix,prefix..":"..i,prio),"fill exact queue boundary with eligible work")
            filled=filled+1
        end
    end
    eq(filled,amount)
end
return F
