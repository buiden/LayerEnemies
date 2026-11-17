-- Composition-aware queue fixtures; exercise real registrations and real budgets.
-- No production source is disabled, replaced or unregistered by these tests.
local h=...
local yes,eq=h.yes,h.eq
local F={}
function F.register(N,name,prefix)
    if N.Sources.has(name) then
        eq(name,"wanted","only the shipped Wanted registration is reused")
        yes(N.Sources.owns(prefix)); yes(N.Wanted and N.Wanted.stats)
        -- loadAddon disables every already-shipped transport for test isolation.
        -- Restore only this queue test's real Wanted lane, as for new registrations.
        eq(N.shipped.wanted,true); N.Net.SHIP.wanted=N.shipped.wanted
        return N.Wanted.stats
    end
    local counters={}
    yes(N.Sources.register{name=name,prefixes={prefix},counters=counters})
    return counters
end
function F.defaultShare(N)
    -- Independent specification formula; never call the queue's share helper.
    return math.max(1,math.floor(30/#N.Sources.lines()))
end
function F.mixed(N)
    local rows={{"wanted","WNTDB",4},{"overlord","OLQueue",8},{"warboard","WBQueue",10},
        {"alpha","AlphaQueue",4},{"beta","BetaQueue",4}}
    for _,r in ipairs(rows) do r.c=F.register(N,r[1],r[2]) end
    yes(F.defaultShare(N)>=4,"fixture has enough default share to saturate thirty")
    return rows
end
function F.fill(N,amount,prio,tag)
    local filled,serial=0,0
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
