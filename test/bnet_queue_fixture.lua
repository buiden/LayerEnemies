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
        local shipped={wanted="WNTDB",warboard="WarBoard"}
        eq(prefix,shipped[name],"reuse only the real shipped source and its own prefix")
        -- loadAddon disables already-shipped transports for test isolation.
        eq(N.shipped[name],true); N.Net.SHIP[name]=N.shipped[name]
        yes(N.Sources.authorized(name,prefix))
        -- WarBoard keeps its counters private; read the real public diagnostic,
        -- rather than replacing registration, callbacks or the transport.
        return setmetatable({},{__index=function(_,key)
            local line=N.Sources.lines(name)[1]
            return tonumber(line:match(key.."=(%d+)"))
        end})
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
    local rows={{"wanted","WNTDB",4},{"overlord","OverlordF",8},{"warboard","WarBoard",10},
        {"alpha","AlphaQueue",4},{"beta","BetaQueue",4}}
    for _,r in ipairs(rows) do r.c=F.register(N,r[1],r[2]) end
    yes(F.defaultShare(N)>=4,"fixture has enough default share to saturate thirty")
    return rows
end
local filledBy=setmetatable({},{__mode="k"})
function F.fill(N,amount,prio,tag)
    local filled,serial=0,0
    local held=filledBy[N] or {}; filledBy[N]=held
    -- Configured shares are real capacity too. Use them before adding default
    -- sources, so the registry's 32-source cap cannot mask the 52/60 boundaries.
    for _,r in ipairs({{"wanted","WNTDB",4},{"overlord","OverlordF",8},{"warboard","WarBoard",10}}) do
        if not held[r[1]] then F.register(N,r[1],r[2]); held[r[1]]=0 end
        for i=1,math.min(r[3]-held[r[1]],amount-filled) do
            yes(N.BNet.send(r[1],71,r[2],tag..":"..r[1]..i,prio))
            held[r[1]]=held[r[1]]+1; filled=filled+1
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
