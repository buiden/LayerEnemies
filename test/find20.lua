-- Section 4.2 only: bounded Find matching, presentation and local alert batching.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function names(n)
    local out={}; for i=1,n do out[i]="Seeker "..H.abc(i) end; return out
end
local function spyIndex(st,key)
    local original=st[key]; eq(type(original),"table",key.." is prebuilt")
    local count=0
    st[key]=setmetatable({}, {__index=function(_,k) count=count+1; return original[k] end})
    return function() return count end
end
local function alerts(N)
    local out={}
    for _,line in ipairs(H.log()) do
        if line:find("LayerEnemies: Seeker ",1,true) or line:find("more tracked names located",1,true) then out[#out+1]=line end
    end
    return out
end

test("Find20 26: load builds at most 180 hash candidates once",function()
    local N=H.load(); local F=N.Find; local original=N.Hash.player; local calls=0
    N.Hash.player=function(...) calls=calls+1; return original(...) end
    local st=F.new(names(20),"Test Realm")
    eq(#st.names,20); yes(calls>0,"lookup is built on load"); yes(calls<=180,"one bounded build, not one per loaded name")
    eq(type(st.byHash),"table"); eq(type(st.byName),"table")
    for _,name in ipairs(st.names) do
        for hash in pairs(F.hashes(name,"Test Realm")) do
            yes(st.byHash[hash],"every legacy hash candidate indexed")
        end
        yes(st.byName[F.fold(name)],"folded full name indexed")
    end
end)

test("Find20 26: report has zero list hashes and at most 10 plus 20 index reads",function()
    local N=H.load(); local F=N.Find; local list=names(20); local st=F.new(list,"Test Realm")
    local enemies={}
    for i=1,10 do enemies[#enemies+1]={hash=N.Hash.player(list[i],"Test Realm"),level=i} end
    for i=11,20 do enemies[#enemies+1]={name=list[i],level=i} end
    -- For the old implementation this fails on the actual operation budget, not a missing field.
    local original=N.Hash.player; local calls=0
    N.Hash.player=function(...) calls=calls+1; return original(...) end
    F.report(st,{sender="Scout",zone=100,at=20,enemies=enemies},"Test Realm")
    eq(calls,0,"reports must not hash the tracked list")
    local hashReads,nameReads=spyIndex(st,"byHash"),spyIndex(st,"byName")
    F.report(st,{sender="Scout",zone=100,at=21,enemies=enemies},"Test Realm")
    eq(calls,0); eq(hashReads(),10); yes(nameReads()<=20); yes(hashReads()+nameReads()<=30)
    for i,name in ipairs(list) do eq(st.locations[name].level,i); eq(st.locations[name].at,21) end
end)

test("Find20 26: own sighting uses at most two name index reads",function()
    local N=H.load(); local F=N.Find; local st=F.new(names(20),"Test Realm")
    local reads=spyIndex(st,"byName")
    -- Looking through the tracked list on the hot path is forbidden, even for a miss.
    st.names=setmetatable({}, {__index=function() error("own scanned names") end})
    F.own(st,{name="Seeker",displayName="Seeker t",realm="t",faction="opposite",source="own target"},100,30)
    yes(reads()<=2); yes(st.locations["Seeker t"])
    local before=reads()
    F.own(st,{name="Unlisted",faction="opposite",source="own target"},100,31)
    yes(reads()-before<=2)
end)

test("Find20 lookup rebuilds only on a list change or first readable home",function()
    local N=H.load(); local F=N.Find; local original=N.Hash.player; local calls=0
    N.Hash.player=function(...) calls=calls+1; return original(...) end
    local st=F.new({"Alice"}); local first=st.byHash; yes(first)
    local loaded=calls; yes(loaded>0)
    F.report(st,{sender="Scout",zone=100,at=20,enemies={}},""); eq(calls,loaded)
    F.report(st,{sender="Scout",zone=100,at=21,enemies={}},"Test Realm")
    yes(calls>loaded); yes(calls-loaded<=9); no(st.byHash==first)
    local ready=calls; local hashes,byName=st.byHash,st.byName
    yes(F.add(st,"ALICE")); F.remove(st,"Nobody")
    F.report(st,{sender="Scout",zone=100,at=22,enemies={}},"Test Realm")
    F.report(st,{sender="Scout",zone=100,at=23,enemies={}},"")
    eq(calls,ready); eq(st.byHash,hashes); eq(st.byName,byName)
    yes(F.add(st,"Cedar")); yes(calls>ready); yes(calls-ready<=18)
    local hash=original("Cedar","Test Realm")
    F.report(st,{sender="Scout",zone=100,at=24,enemies={{hash=hash}}},"Test Realm"); yes(st.locations.Cedar)
    F.remove(st,"cedar"); eq(st.locations.Cedar,nil)
    F.report(st,{sender="Scout",zone=100,at=25,enemies={{hash=hash},{name="Cedar"}}},"Test Realm"); eq(st.locations.Cedar,nil)
    F.remove(st); eq(next(st.byHash),nil); eq(next(st.byName),nil)
end)

test("Find20 home becomes known on the normal poll without waiting for a report",function()
    local N=H.load(); local M,F=N.Main,N.Find
    M.find=F.new({"Alice"}); local before=M.find.byHash
    M.poll(); no(M.find.byHash==before,"first readable home builds the lookup even without reports")
    yes(M.find.byHash[N.Hash.player("Alice",M.homeRealm())])
    local ready=M.find.byHash; M.poll(); eq(M.find.byHash,ready,"later polls do not rebuild")
end)

test("Find20 27: twenty adds fit, twenty-first refuses, duplicates remain idempotent",function()
    local N=H.load(); local F=N.Find; local st=F.new()
    for _,name in ipairs(names(20)) do yes(F.add(st,name),"all twenty slots available") end
    eq(F.MAX,20); eq(#st.names,20); yes(F.add(st,"SEEKER A")); eq(#st.names,20)
    local ok,why=F.add(st,"Extra Person"); no(ok); yes(why:find("20",1,true)); eq(#st.names,20)
end)

test("Find20 27: saved input is validated and deduplicated within its first twenty entries",function()
    local N=H.load(); local F=N.Find; local saved={}
    for i=1,10 do saved[#saved+1]="Seeker "..H.abc(i); saved[#saved+1]="SEEKER "..H.abc(i):upper() end
    for i=21,30 do saved[i]="Beyond "..H.abc(i) end
    saved[1]="Bad|r"; saved[2]=H.secret
    local st=F.new(saved); eq(#st.names,9,"invalid and folded duplicate entries dropped; no scan past slot twenty")
    local seen={}
    for _,name in ipairs(st.names) do local valid,key=F.name(name); yes(valid); no(seen[key]); seen[key]=true end
    eq(st.names[1],"Seeker b"); eq(st.names[9],"Seeker j")
    st=F.new(names(30)); eq(#st.names,20); eq(st.names[20],"Seeker t")
end)

-- Preserve legacy own comparisons, hash collisions and precedence; section 4.3
-- deliberately extends unqualified tracked names to qualified named reports.
test("Find20 matching preserves legacy aliases, realm checks, collisions and precedence",function()
    local N=H.load(); local F=N.Find
    local list={"Alice","Alice-TestRealm","Alice-Foreign","ÉLODIE","élodie-TestRealm","Élodie-Foreign",
        "First Surname","First","PFKMEclrzj","CuhFVPbgzA"}
    local function oldNamed(name,e)
        if not e.name then return false end
        local want,got=F.fold(name),F.fold(e.name)
        return want==got or want:match("^([^%-]+)")==got
            or (not want:find("-",1,true) and want==got:match("^([^%-]+)"))
    end
    local function oldOwn(name,e)
        local short=name:match("^([^%-]+)") or name
        return F.fold(name)==F.fold(e.displayName or e.name) or (not name:find(" ",1,true)
            and F.fold(short)==F.fold(e.name) and (not name:find("-",1,true)
            or N.Hash.player(short,e.realm)==N.Hash.player(short,name:match("%-(.+)$"))))
    end
    for _,enemy in ipairs({{name="ALICE"},{name="Alice-TestRealm"},{name="Alice-Foreign"},{name="Alice-Elsewhere"},
        {name="Élodie"},{name="élodie-TestRealm"},{name="First"},{name="First Surname"},{name="First Other"},
        {hash="Y8Y"},{hash=N.Hash.player("Élodie","Test Realm")},{name="Alice",hash="Y8Y"}}) do
        local st=F.new(list,"Test Realm")
        F.report(st,{sender="Scout",zone=100,at=20,enemies={enemy}},"Test Realm")
        for _,name in ipairs(list) do
            eq(not not st.locations[name],not not ((enemy.hash and F.hashes(name,"Test Realm")[enemy.hash]) or oldNamed(name,enemy)),name)
        end
    end
    for _,enemy in ipairs({{name="Alice",realm="Test Realm"},{name="Alice",realm="Foreign"},{name="Alice",realm="Elsewhere"},
        {name="Alice",displayName="Alice-Foreign",realm="Test Realm"},{name="Élodie",realm="Test Realm"},
        {name="First",displayName="First Surname",realm="Surname"},{name="First",displayName="First Other",realm="Other"}}) do
        enemy.faction="opposite"; enemy.source="own target"
        local st=F.new(list,"Test Realm"); F.own(st,enemy,100,20)
        for _,name in ipairs(list) do eq(not not st.locations[name],not not oldOwn(name,enemy),name) end
    end
    local st=F.new({"Alice-TestRealm","Alice-Foreign"},"Test Realm")
    F.report(st,{sender="Scout",zone=100,at=20,enemies={{name="Alice",level=1},{name="Alice",level=2}}},"Test Realm")
    for _,name in ipairs(st.names) do eq(st.locations[name].level,2) end
    F.report(st,{sender="Relay",zone=200,at=21,relayed=true,enemies={{name="Alice",level=3}}},"Test Realm")
    for _,name in ipairs(st.names) do eq(st.locations[name].level,2); eq(st.locations[name].spotter,"Scout") end
end)

test("Find20 aliases preserve trailing-hyphen validation and full-name own guards",function()
    local N=H.load(); local F=N.Find
    yes(F.name("Alice-"),"legacy parser accepts this spelling; do not change parsing here")
    local st=F.new({"Alice-"},"Test Realm")
    F.report(st,{sender="Scout",zone=100,at=20,enemies={{name="Alice"}}},"Test Realm")
    yes(st.locations["Alice-"],"legacy report short alias includes a trailing hyphen")
    F.boundary(st)
    F.own(st,{name="Alice",realm="",faction="opposite",source="own target"},100,21)
    yes(st.locations["Alice-"],"legacy own comparison uses the empty realm")
    st=F.new({"Alice-TestRealm"},"Test Realm")
    F.own(st,{name="Alice-TestRealm",displayName="Unrelated",realm="TestRealm",faction="opposite",source="own target"},100,22)
    eq(st.locations["Alice-TestRealm"],nil,"full enemy name is not a short-name alias")
end)

test("Find20 28: adding a name prints only its row, including a retained sighting",function()
    local N=H.load(); local M=N.Main
    for _,name in ipairs(names(19)) do yes(M.track(name)) end
    local before=#H.log(); yes(M.track("Seeker t")); eq(#H.log()-before,1); yes(H.log()[#H.log()]:find("Seeker t",1,true))
    before=#H.log(); yes(M.track("SEEKER A")); eq(#H.log()-before,1); yes(H.log()[#H.log()]:find("Seeker a",1,true))
    local saved=LayerEnemiesDB; eq(saved.byHash,nil); eq(saved.byName,nil); eq(saved.alertWindow,nil)
    M.track(nil)
    N.Store.observe(M.store,{key="Player-1-88",name="Seeker a",at=H.clock(),faction="opposite",source="own target"},H.clock())
    before=#H.log(); yes(M.track("Seeker a")); eq(#H.log()-before,1,"one status, not status plus duplicate alert")
end)

test("Find20 28: five names in one second give three details, one summary and one sound",function()
    local N=H.load(); local M,F=N.Main,N.Find; local list=names(5); local sounds=0
    PlaySound=function() sounds=sounds+1 end
    for _,name in ipairs(list) do yes(F.add(M.find,name)) end
    local start=H.clock()
    for i,name in ipairs(list) do
        F.report(M.find,{sender="Scout",zone=100,at=H.clock(),enemies={{name=name}}},"Test Realm")
        M.findAlerts(); H.advance(.2)
    end
    eq(#alerts(N),3,"only three detail lines during the window"); eq(sounds,1)
    H.advance(start+10-H.clock()); local lines=alerts(N)
    eq(#lines,4); eq(lines[4],"LayerEnemies: 2 more tracked names located, see Find"); eq(sounds,1)
    M.findAlerts(); eq(#alerts(N),4,"summary emitted only once")
    for _,name in ipairs(list) do yes(M.find.alerts[name],"folded names still consume their per-name alert") end
    F.report(M.find,{sender="Scout",zone=200,at=H.clock(),enemies={{name=list[1]}}},"Test Realm")
    M.findAlerts(); eq(#alerts(N),5); eq(sounds,2,"new window, unchanged new-zone per-name rule")
    eq(#H.sent(),0)
end)

test("Find20 sound cooldown is rolling and quiet alerts do not consume it",function()
    local N=H.load(); local M,F=N.Main,N.Find; local sounds=0; PlaySound=function() sounds=sounds+1 end
    for _,name in ipairs(names(3)) do yes(F.add(M.find,name)) end
    local function locate(name,quiet)
        F.report(M.find,{sender="Scout",zone=100,at=H.clock(),enemies={{name=name}}},"Test Realm"); M.findAlerts(quiet)
    end
    locate("Seeker a",true); eq(sounds,0)
    H.advance(8); locate("Seeker b"); eq(sounds,1)
    H.advance(2); locate("Seeker c"); eq(sounds,1,"new line window must not reset sound cooldown")
    H.advance(8); F.report(M.find,{sender="Scout",zone=200,at=H.clock(),enemies={{name="Seeker a"}}},"Test Realm")
    M.findAlerts(); eq(sounds,2)
end)

test("Find20 UI sorts located first, newest first, with compact missing status and paging",function()
    local N=H.load(); local F,M,U=N.Find,N.Main,N.UI; local list=names(20)
    for i=#list,1,-1 do yes(F.add(M.find,list[i])) end
    F.report(M.find,{sender="Scout",zone=100,at=H.clock()-2,enemies={{name="Seeker t"}}},"Test Realm")
    F.report(M.find,{sender="Scout",zone=100,at=H.clock()-1,enemies={{name="Seeker s"}}},"Test Realm")
    U.toggle(); U.select("find")
    eq(U.pool[1].tracked,"Seeker s"); eq(U.pool[2].tracked,"Seeker t")
    yes(U.findTitle,"full title has room outside the narrow tab"); eq(U.findTitle:GetText(),"Find (2 located / 20)")
    yes(U.banner:GetText():find("Up to 20 names",1,true)); eq(U.input.kind,"EditBox")
    U.body.scripts.OnMouseWheel(nil,-1); U.body.scripts.OnMouseWheel(nil,-1)
    eq(U.offset,2); eq(U.pool[1].tracked,"Seeker a"); eq(U.pool[1].sub.height,14)
    eq(U.pool[1].sub:GetText(),"Not located"); no(U.pool[1].ask:IsShown()); yes(U.pool[1].clear:IsShown())
    local visible=0
    for _,r in ipairs(U.pool) do if r:IsShown() then visible=visible+1; yes(-r.point[5]+r.height<=U.body.height,"no overflow") end end
    yes(visible>=3,"compact missing rows fit at least three")
    for _=1,30 do U.body.scripts.OnMouseWheel(nil,-1) end
    local last
    for _,r in ipairs(U.pool) do if r:IsShown() then last=r.tracked end end
    eq(last,"Seeker r","last missing name reachable despite variable row heights")
    local count=#H.frames(); for _=1,5 do U.render() end; eq(#H.frames(),count,"pooled rows reused")
    U.select("local"); no(U.findTitle:IsShown())
end)

test("Find20 UI counts shared positions as located without changing their alert or layer meaning",function()
    local N=H.load(); local M,F,U=N.Main,N.Find,N.UI
    for _,name in ipairs({"Alpha","Birch","Cedar"}) do yes(F.add(M.find,name)) end
    M.find.locations.Birch={name="Birch",zone=100,at=H.clock()-2,spotter="Scout",possible=true}
    M.find.places.Cedar={map=200,x=.4,y=.5,at=H.clock()-1,route="GUILD"}
    U.toggle(); U.select("find"); eq(U.pool[1].tracked,"Cedar"); eq(U.findTitle:GetText(),"Find (2 located / 3)")
    yes(U.pool[1].place:IsShown()); no(U.pool[1].ask:IsShown())
    no(F.alert(M.find,M.findRows()[3],H.clock()),"shared position is not an alert")
    F.remove(M.find,"Cedar"); U.render(); eq(U.pool[1].tracked,"Birch")
    eq(U.findTitle:GetText(),"Find (1 located / 2)")
end)
