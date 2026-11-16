-- Round-1 review regressions. Real Find/Main paths; no transport changes.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no

for _,realms in ipairs({{"1234","84860"},{"Home","ochg"}}) do
    test("Round1 realm: own sighting rejects colliding realm "..realms[1].."/"..realms[2],function()
        local N=H.load(); local F=N.Find
        eq(N.Hash.player("Alice",realms[1]),N.Hash.player("Alice",realms[2]),"fixture is a real hash collision")
        for _,before in ipairs({true,false}) do
            local st=F.new(nil,"Test Realm")
            if before then yes(F.add(st,"Alice-"..realms[1])) end
            F.own(st,{name="Alice",displayName="Alice "..realms[2],realm=realms[2],source="own target",faction="opposite"},100,H.clock())
            if not before then yes(F.add(st,"Alice-"..realms[1])) end
            eq(F.rows(st,H.clock(),100)[1].at,nil,"wrong realm must not identify a tracked player")
            F.own(st,{name="Alice",displayName="Alice "..realms[1],realm=realms[1],source="own target",faction="opposite"},100,H.clock())
            yes(F.rows(st,H.clock(),100)[1].own,"matching realm still identifies the player")
        end
    end)
end

test("Round1 realm: own realm equality normalizes and folds full strings",function()
    local N=H.load(); local st=N.Find.new({"Alice-Érea52"},"Home")
    N.Find.own(st,{name="Alice",realm="érea - 52",source="own target",faction="opposite"},100,H.clock())
    yes(N.Find.rows(st,H.clock(),100)[1].own,"non-ASCII realm case is folded, not hashed")
end)
