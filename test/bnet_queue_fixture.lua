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
function F.mixed(N,total)
    total=total or 30
    local rows={{"wanted","WNTDB",4},{"overlord","OLQueue",8},{"warboard","WBQueue",10},
        {"alpha","AlphaQueue"},{"beta","BetaQueue"}}
    for _,r in ipairs(rows) do r.c=F.register(N,r[1],r[2]) end
    -- Keep one alpha admission slot for the expiry test's owed replacement;
    -- the first dispatch belongs to a different source, not alpha.
    while 22+(#rows-3)*F.defaultShare(N)-1<total do
        local r={"mixed"..h.abc(#rows),"MixedQueue"..#rows}
        r.c=F.register(N,r[1],r[2]); rows[#rows+1]=r
    end
    local remaining=total-22
    for i=4,#rows do
        rows[i][3]=math.min(F.defaultShare(N)-(i==4 and 1 or 0),remaining)
        remaining=remaining-rows[i][3]
    end
    eq(remaining,0,"fixture has eligible work at the exact shared boundary")
    return rows
end
local pools=setmetatable({},{__mode="k"})
function F.fill(N,amount,prio,tag)
    local pool=pools[N]
    if not pool then
        -- Use the configured shares too: another tick-only source must not make
        -- a queue-cap test hit the 32-source registry ceiling first.
        pool={{"wanted","WNTDB",4},{"overlord","OLQueue",8},{"warboard","WBQueue",10}}
        for _,r in ipairs(pool) do F.register(N,r[1],r[2]); r.used=0 end
        pools[N]=pool
    end
    local filled,index=0,1
    while filled<amount do
        if not pool[index] then
            local name,prefix=tag..h.abc(index),"Fill"..tag..index
            F.register(N,name,prefix); pool[index]={name,prefix,used=0}
        end
        local r=pool[index]
        for _=1,math.min(math.max(0,(r[3] or F.defaultShare(N))-r.used),amount-filled) do
            r.used=r.used+1
            yes(N.BNet.send(r[1],71,r[2],r[2]..":"..r.used,prio),"fill exact queue boundary with eligible work")
            filled=filled+1
        end
        index=index+1
    end
    eq(filled,amount)
end
return F
