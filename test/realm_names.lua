-- Section 4.3: Find identity only; no wire, OpenMap or SavedVariables expansion.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function report(N,st,name,source,at)
    N.Find.report(st,{sender="Birch Scout",zone=100,at=at or H.clock(),source=source,
        relayed=source=="relayed",enemies={{name=name,class="MAGE",level=40}}},st.home)
end
local function row(N,st) return N.Find.rows(st,H.clock(),100)[1] end
local function tracked(N,name,home)
    local st=N.Find.new(nil,home or "Home")
    yes(N.Find.add(st,name),"accept tracked identity "..name)
    return st
end

test("Realm names: new forms normalize only the realm and preserve typed case",function()
    local F=H.load().Find
    for _,case in ipairs({{"First Last-Area 52","First Last-Area52"},{"Name-1234","Name-1234"},
        {"First Last-Area-52","First Last-Area52"},{"  fIRst lASt-aRea - 52  ","fIRst lASt-aRea52"},
        {"Élodie Łava-Яр' 12-É","Élodie Łava-Яр'12É"}}) do
        local name,key=F.name(case[1]); eq(name,case[2]); eq(key,F.fold(case[2]))
    end
end)

test("Realm names: new grammar enforces word realm and total byte limits",function()
    local F=H.load().Find
    local a,b=string.rep("A",36),string.rep("B",36)
    yes(F.name(a.." "..b.."-"..string.rep("1",26)),"exactly 100 bytes")
    yes(F.name("First Last-"..string.rep("1",40)),"40-byte realm")
    yes(F.name(a.."-1234")); yes(F.name("A B-1"))
    for _,bad in ipairs({a.."C-1234",a.."C Last-1","First "..b.."C-1",
        "First Last-"..string.rep("1",41),a.." "..b.."-"..string.rep("1",27),
        "First Last-","First Last- - ","First Last-A_52","First Last-A/52","First Last-52!",
        "First Last-A\t52","First Last-A|r","First  Last-A","One Two Three-A","First2 Last-A",
        "First L'ast-A","-1234",false,42,H.secret}) do no(F.name(bad),"reject invalid new spelling") end
end)

test("Realm names: every legacy accepted pattern keeps both return values",function()
    local N=H.load(); local F=N.Find
    -- Frozen parser from the base, including its permissive apostrophes, long
    -- single words/realms and trailing hyphen. New limits cannot invalidate saves.
    local function old(raw)
        raw=N.Safe.str(raw,100); if not raw then return end
        raw=raw:match("^%s*(.-)%s*$")
        local first,second=raw:match("^([%a\128-\255]+) ([%a\128-\255]+)$")
        if first and #first<=36 and #second<=36 then return raw,F.fold(raw) end
        if raw:match("^[%a\128-\255]+%-?[%a'\128-\255]*$") and #raw>=2 and #raw<=72 then return raw,F.fold(raw) end
    end
    local inputs={"  ÉLODIE  ","  ÉLODIE ŁAVA  ","ÉLODIE-ÉLUNE","Alice-","O'Neil","A'",false,H.secret,42,
        "/g Élodie","Élodie|r","Élodie2","One Two Three"}
    for n=1,101 do
        local s=string.rep("A",n)
        for _,raw in ipairs({s,s.."-",s.."-Z","A-"..s,s.." B","A "..s,"  "..s.."  "}) do inputs[#inputs+1]=raw end
    end
    for _,raw in ipairs(inputs) do
        local want,key=old(raw)
        if want or type(raw)~="string" or not raw:find("-",1,true) then
            local actual,folded=F.name(raw); eq(actual,want); eq(folded,key)
        end
    end
end)

test("Realm names: saved display dedupe removal and base buckets keep separate realms",function()
    local N=H.load(); local F=N.Find
    local st=F.new({"Name","Name-A","Name-B","First Last-Area 52","FIRST LAST-area-52"},"Home")
    eq(#st.names,4); eq(st.names[4],"First Last-Area52")
    eq(#st.byName.name,3); eq(st.byName["name-a"],nil); eq(st.byName["name-b"],nil)
    eq(#st.byName["first last"],1); eq(st.byName.first,nil,"two-word names never become first-name aliases")
    yes(F.add(st,"FIRST LAST-AREA 52")); eq(#st.names,4)
    F.remove(st,"first last-area -52"); eq(#st.names,3); eq(st.byName["first last"],nil)
    yes(N.Main.track("fIRst lASt-aRea - 52")); eq(LayerEnemiesDB.tracked[1],"fIRst lASt-aRea52")
    N=H.load(LayerEnemiesDB); eq(N.Main.find.names[1],"fIRst lASt-aRea52")
end)

for _,source in ipairs({"spy","guild","relayed","death","headhunter"}) do
    test("Realm names: "..source.." bare tracked base accepts any reported realm",function()
        local N=H.load()
        for _,base in ipairs({"Name","First Last"}) do
            local st=tracked(N,base)
            report(N,st,base.."-1234",source)
            yes(st.locations[base],"qualified evidence locates an unqualified entry")
            local r=row(N,st); yes(r.at); no(r.realmUnknown)
        end
    end)
    test("Realm names: "..source.." different explicit realms never match",function()
        local N=H.load()
        for _,base in ipairs({"Name","First Last"}) do
            local st=tracked(N,base.."-A")
            report(N,st,base.."-B",source)
            eq(st.locations[base.."-A"],nil); local r=row(N,st); eq(r.at,nil); eq(r.seen,nil); eq(r.reported,nil)
        end
    end)
    test("Realm names: "..source.." explicit realms normalize and fold before matching",function()
        local N=H.load()
        for _,base in ipairs({"Name","First Last"}) do
            local st=tracked(N,base.."-Érea52")
            report(N,st,N.Find.fold(base).."-Érea - 52",source)
            yes(st.locations[base.."-Érea52"]); local r=row(N,st); yes(r.at); no(r.realmUnknown)
            no(r.status:find("realm not confirmed",1,true))
        end
    end)
    test("Realm names: "..source.." realm-less evidence marks foreign realm unknown",function()
        local N=H.load()
        for _,base in ipairs({"Name","First Last"}) do
            local st=tracked(N,base.."-A")
            report(N,st,base,source)
            yes(st.locations[base.."-A"].realmUnknown)
            local r=row(N,st); yes(r.at); yes(r.realmUnknown)
            yes(r.status:find("realm not confirmed",1,true)); yes(N.Main.findText(r):find("realm not confirmed",1,true))
            local detail=r.reported or r.seen; yes(detail); yes(detail.realmUnknown)
            yes(detail.status:find("realm not confirmed",1,true))
        end
    end)
    test("Realm names: "..source.." home realm needs no unknown note",function()
        local N=H.load()
        for _,base in ipairs({"Name","First Last"}) do
            local st=tracked(N,base.."-Érea52","érea - 52")
            report(N,st,base,source)
            local r=row(N,st); yes(r.at); no(r.realmUnknown)
            no(r.status:find("realm not confirmed",1,true)); no(N.Main.findText(r):find("realm not confirmed",1,true))
        end
    end)
end

for _,source in ipairs({"own","spy","guild","relayed","death"}) do
    test("Realm names: Known "..source.." rejects cross-realm memory before and after adding",function()
        local N=H.load(); local F=N.Find; local st=F.new(nil,"Home")
        local kind=(source=="relayed" or source=="death") and "claim" or "seen"
        local function cache(name,zone)
            yes(N.Known.put(st.known,{name=name,ownName="First",realm="Last",zone=zone,at=H.clock(),source=source,kind=kind},H.clock()))
        end
        cache("First Last-B",200); yes(F.add(st,"First Last-A"))
        local r=row(N,st); eq(r.at,nil); eq(r.seen,nil); eq(r.reported,nil)
        cache("first last-a",100); r=row(N,st); eq(r.zone,100); no(r.realmUnknown)
        F.remove(st,"First Last-A"); yes(F.add(st,"First Last-A")); eq(row(N,st).zone,100)
        eq(N.Safe.count(st.known.entries),2,"different realm memory stays distinct")
    end)
    test("Realm names: Known "..source.." realm-less evidence has per-entry unknown flags",function()
        local N=H.load(); local F=N.Find; local st=F.new(nil,"Home")
        local kind=(source=="relayed" or source=="death") and "claim" or "seen"
        local cached=N.Known.put(st.known,{name="First Last",ownName="First",realm="Last",zone=100,
            at=H.clock(),source=source,kind=kind},H.clock()); yes(cached)
        for _,name in ipairs({"First Last-A","First Last-Home","First Last"}) do yes(F.add(st,name)) end
        local rows=F.rows(st,H.clock(),100)
        for i,r in ipairs(rows) do yes(r.at); eq(not not r.realmUnknown,i==1) end
        eq(cached.realmUnknown,nil,"ambiguity belongs to tracked row, not shared cache")
    end)
end

test("Realm names: own full display uses its realm not the surname second return",function()
    local N=H.load(); local F=N.Find
    for _,source in ipairs({"own target","own mouseover","own (party target)"}) do
        local st=tracked(N,"First Last-A"); yes(F.add(st,"First Last-B")); yes(F.add(st,"First Last"))
        F.own(st,{name="First",displayName="First Last-A",realm="Last",source=source,faction="opposite"},100,H.clock())
        yes(st.locations["First Last-A"]); eq(st.locations["First Last-B"],nil); yes(st.locations["First Last"])
        local rows=F.rows(st,H.clock(),100); yes(rows[1].at); no(rows[1].realmUnknown); eq(rows[2].at,nil); yes(rows[3].at)
    end
end)

test("Realm names: own realm-less surname sighting warns and alerts exactly once",function()
    local N=H.load(); local F,M=N.Find,N.Main
    yes(F.add(M.find,"First Last-A")); local sounds=0; PlaySound=function() sounds=sounds+1 end
    local before=#H.log()
    F.own(M.find,{name="First",displayName="First Last",realm="Last",source="own target",faction="opposite"},100,H.clock())
    local r=M.findRows()[1]; yes(r.own); yes(r.realmUnknown); yes(r.status:find("realm not confirmed",1,true))
    M.findAlerts(); M.findAlerts(); eq(sounds,1); eq(#H.log()-before,1)
    yes(H.log()[#H.log()]:find("realm not confirmed",1,true)); eq(#H.sent(),0)
    N.UI.toggle(); N.UI.select("find"); yes(N.UI.pool[1].sub:GetText():find("realm not confirmed",1,true))
    PlaySound=nil
end)

test("Realm names: own home-realm exemption is recomputed when home becomes readable",function()
    local N=H.load(); local F=N.Find; local st=F.new(); yes(F.add(st,"First Last-Area52"))
    F.own(st,{name="First",displayName="First Last",realm="Last",source="own target",faction="opposite"},100,H.clock())
    yes(row(N,st).realmUnknown); F.home(st,"area - 52"); local r=row(N,st); yes(r.at); no(r.realmUnknown)
    no(r.status:find("realm not confirmed",1,true))
end)

test("Realm names: real guild O receive retains realm uncertainty in Find text",function()
    local N=H.load(); yes(N.Main.track("First Last-A"))
    local line=N.Relay.ownLine({rid=7,zone=100,age=0,layer="7085",count=1,enemies={{name="First Last"}}})
    yes(line); H.deliver("CHAT_MSG_ADDON","LEGW1",line,"GUILD","Birch Scout")
    local r=N.Main.findRows()[1]; yes(r.seen); eq(r.source,"guild"); yes(r.realmUnknown)
    yes(N.Main.findText(r):find("realm not confirmed",1,true)); eq(#H.sent(),0); no(N.Main.error)
end)

test("Realm names: surname hashes use the base and never a typed-realm home tuple",function()
    local N=H.load(); local F,Hash=N.Find,N.Hash
    local got=F.hashes("First Last-A","Home")
    local want={}; for _,tuple in ipairs({{"First","Last"},{"First Last","A"},{"First Last",""}}) do want[Hash.player(tuple[1],tuple[2])]=true end
    for h in pairs(want) do yes(got[h],"required tuple") end
    for h in pairs(got) do yes(want[h],"only the three intended tuples") end
    no(got[Hash.player("First","Last-A")]); no(got[Hash.player("First Last","Home")])
    local calls,original=0,Hash.player; Hash.player=function(...) calls=calls+1; return original(...) end
    F.hashes("First Last-A","Home"); eq(calls,9,"three spellings for each of three tuples")
end)

test("Realm names: every hash tuple stays possible and never confirms even the home realm",function()
    local N=H.load(); local F=N.Find
    for _,home in ipairs({"Home","A"}) do
        for hash in pairs(F.hashes("First Last-A",home)) do
            local st=tracked(N,"First Last-A",home)
            F.report(st,{sender="Birch Scout",zone=100,at=H.clock(),enemies={{hash=hash}}},home)
            local r=row(N,st); yes(r.possible); no(r.own); no(r.same); yes(r.realmUnknown)
            yes(r.status:find("possible match",1,true)); yes(r.status:find("realm not confirmed",1,true))
            eq(next(st.known.entries),nil)
        end
    end
end)

test("Realm names: late home discovery removes the named HeadHunter uncertainty only",function()
    local N=H.load(); local F=N.Find; local st=F.new(); yes(F.add(st,"First Last-Home"))
    report(N,st,"First Last","headhunter"); yes(row(N,st).realmUnknown)
    F.home(st,"Home"); local r=row(N,st); yes(r.at); no(r.realmUnknown)
    no(r.status:find("realm not confirmed",1,true))
end)

test("Realm names: a hash cannot override an explicitly different named realm",function()
    local N=H.load(); local F=N.Find
    for _,source in ipairs({"spy","guild","relayed","death","headhunter"}) do
        local st=tracked(N,"First Last-A")
        F.report(st,{sender="Birch Scout",zone=100,at=H.clock(),source=source,relayed=source=="relayed",
            enemies={{name="First Last-B",hash=N.Hash.player("First","Last")}}},"Home")
        eq(st.locations["First Last-A"],nil); eq(row(N,st).at,nil)
    end
end)

test("Realm names: On my way adds the shown qualified killer and saves it without sends",function()
    local N=H.load()
    H.deliver("CHAT_MSG_ADDON","GBOUNTY","D|First Last-1234|100|42.5|61.0|Forest|60|2|ROGUE|","GUILD","Birch Moss")
    local U=N.CallUI; yes(U.frame and U.frame:IsShown()); eq(U.event.killer,"First Last-1234"); yes(U.event.full)
    local before=#H.sent(); U.help:Click()
    eq(N.Main.find.names[1],"First Last-1234"); eq(LayerEnemiesDB.tracked[1],"First Last-1234")
    eq(#H.sent(),before); no(U.frame:IsShown()); no(N.Main.error)
end)
