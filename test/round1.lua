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

test("Round1 cost: polling 20 tracked names visits only matching Known entries",function()
    local N=H.load(); local F,K,M=N.Find,N.Known,N.Main
    for i=1,20 do yes(F.add(M.find,"Tracked "..H.abc(i))) end
    for i=1,300 do
        local name=i<=5 and "Tracked "..H.abc(i) or "Untracked "..H.abc(i)
        K.put(M.find.known,{name=name,zone=100,at=H.clock(),source="spy",kind="seen",spotter="Scout"},H.clock())
    end
    eq(N.Safe.count(M.find.known.entries),300)
    local known=M.find.known
    for poll=1,2 do
        local visits,lookups=0,0
        local original=pairs; local index=known.byName
        local counted={[known.entries]=true}
        for _,bucket in original(index or {}) do counted[bucket]=true end
        if index then known.byName=setmetatable({},{__index=function(_,key) lookups=lookups+1; return index[key] end}) end
        pairs=function(t)
            local iter,state,key=original(t)
            if not counted[t] then return iter,state,key end
            return function(s,k)
                local nextKey,value=iter(s,k)
                if nextKey~=nil then visits=visits+1 end
                return nextKey,value
            end,state,key
        end
        local ok,err=pcall(M.poll)
        pairs=original; if index then known.byName=index end
        yes(ok,err); no(M.error)
        yes(visits+lookups<=25,"20 keys + 5 matching entries, not a cache scan: "..visits.." visits + "..lookups.." lookups")
    end
    local rows=M.findRows()
    for i,r in ipairs(rows) do eq(r.at~=nil,i<=5,"index must still return every matching finding") end
end)

test("Round1 cost: Known index follows aliases replacement eviction expiry and rollback",function()
    local N=H.load(); local F,K=N.Find,N.Known
    local st=F.new({"Cedar","Cedar Vale","Cedar Vale-A"},"Home")
    local function rows(at) return F.rows(st,at,100) end
    F.own(st,{name="Cedar",displayName="Cedar Vale",realm="Vale",source="own target",faction="opposite"},100,10)
    for _,r in ipairs(rows(10)) do yes(r.at) end
    F.remove(st); F.add(st,"Cedar"); yes(rows(10)[1].own,"add reuses the own first-name alias")
    -- A replacement without an own first-name alias must not inherit one.
    F.report(st,{sender="Scout",zone=100,at=11,source="spy",enemies={{name="Cedar Vale"}}},"Home")
    -- Whether an own slot remains is a separate precedence policy; expiry removes it.
    eq(rows(3610)[1].at,nil)
    F.add(st,"Cedar Vale"); yes(rows(3610)[2].at); eq(rows(3611)[2].at,nil)
    for i=1,301 do K.put(st.known,{name="Enemy "..H.abc(i),zone=100,at=4000+i,source="spy",kind="seen"},4301) end
    F.remove(st); F.add(st,"Enemy a"); F.add(st,"Enemy "..H.abc(301))
    eq(rows(4301)[1].at,nil); yes(rows(4301)[2].at)
    eq(rows(1)[2].at,nil,"clock rollback removes future evidence and aliases")
    eq(next(st.known.entries),nil)
    if st.known.byName then eq(next(st.known.byName),nil,"no dangling index entries") end
end)

test("Round1 own: a newer guild O keeps fresh own evidence primary and both lines visible",function()
    for _,trackAfter in ipairs({false,true}) do
        for _,ownFirst in ipairs({true,false}) do
            local N=H.load(); H.advance(1); local M,F=N.Main,N.Find
            local at=H.clock()
            if not trackAfter then yes(M.track("Cedar Vale")) end
            local function own()
                F.own(M.find,{name="Cedar Vale",source="own target",faction="opposite",layer="7086-7"},100,at,H.clock())
            end
            if ownFirst then own() end
            H.advance(1)
            local line=N.Relay.ownLine({rid=7,zone=100,age=0,layer="7085",count=1,enemies={{name="Cedar Vale"}}})
            H.deliver("CHAT_MSG_ADDON","LEGW1",line,"GUILD","DirectScout")
            if not ownFirst then own() end
            if trackAfter then yes(M.track("Cedar Vale")) end
            local r=M.findRows()[1]
            yes(r.own,"your fresh own sighting must remain primary"); yes(r.same); no(r.canAsk); eq(r.at,at)
            local text=M.findText(r)
            yes(text:find("is on YOUR layer",1,true)); yes(text:find("Seen by DirectScout",1,true))
            yes(text:find("layer 7085 (their claim)",1,true)); yes(text:find("1 s ago",1,true))
            N.UI.toggle(); N.UI.select("find"); no(N.UI.pool[1].ask:IsShown())
            yes(N.UI.pool[1].sub:GetText():find("Seen by DirectScout",1,true)); eq(N.UI.pool[1].hopRecord,false)
            H.advance(598); yes(M.findRows()[1].own,"599 seconds is still primary")
            H.advance(1); r=M.findRows()[1]; eq(r.spotter,"DirectScout"); yes(r.canAsk,"600-second own evidence no longer suppresses Ask")
            yes(M.findText(r):find("last known: Seen by you",1,true)); eq(#H.sent(),0); no(M.error)
        end
    end
end)

test("Round1 own: an own sighting in another zone does not suppress fresh on-site evidence",function()
    local N=H.load(); local F,M=N.Find,N.Main
    yes(M.track("Cedar Vale"))
    F.own(M.find,{name="Cedar Vale",source="own target",faction="opposite",layer="7086-7"},200,H.clock())
    H.advance(1)
    F.report(M.find,{sender="Scout",zone=100,at=H.clock(),source="guild",enemies={{name="Cedar Vale"}}},"Test Realm")
    local r=M.findRows()[1]; eq(r.spotter,"Scout"); yes(r.canAsk); no(r.same)
    yes(M.findText(r):find("Seen by you",1,true),"out-of-zone own line is retained as detail")
end)

test("Round1 realm: own realm equality normalizes and folds full strings",function()
    local N=H.load(); local st=N.Find.new({"Alice-Érea52"},"Home")
    N.Find.own(st,{name="Alice",realm="érea - 52",source="own target",faction="opposite"},100,H.clock())
    yes(N.Find.rows(st,H.clock(),100)[1].own,"non-ASCII realm case is folded, not hashed")
end)
