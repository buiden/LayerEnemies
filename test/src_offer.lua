local h=...
local test,eq,yes,no=h.test,h.eq,h.yes,h.no
local function setup(name)
    local N=h.load(); yes(N.Sources); yes(N.Sources.register{name="probe",prefixes={},counters={}})
    if name then N.Find.add(N.Main.find,name) end
    return N
end
local function ev(kind)
    return {name="Enemy Player",zone="Ashenvale",map=100,x=.2,y=.4,shard="123",at=h.clock()-3,got=h.clock(),
        kind=kind or "self",net="probe",via="Witness Player",guid="Player-1-111",faction="Horde"}
end

test("Sources: offer admits tracked evidence through Find without Ask layer or sound",function()
    for _,kind in ipairs({"self","witness","relayed","cached"}) do
        local N=setup("Enemy Player"); yes(type(N.Sources.offer)=="function","offer gate exists")
        yes(N.Sources.offer(ev(kind)))
        local row=N.Find.rows(N.Main.find,h.clock(),100)[1]
        eq(row.source,"probe"); eq(row.zone,100); eq(row.x,.2); eq(row.y,.4); eq(row.kind,"claim")
        eq(row.pos,kind=="self" and "enemy" or "observer"); no(row.canAsk); no(row.layer); no(row.same)
        yes(row.status:find(kind,1,true)); yes(row.status:find("123",1,true))
        local known=N.Known.get(N.Main.find.known,"Enemy Player",h.clock()).reported
        eq(known.observedAt,h.clock()-3); eq(known.got,h.clock()); eq(known.evidenceKind,kind)
        eq(known.guid,"Player-1-111"); eq(known.faction,"Horde"); eq(known.shard,"123")
        local sounds=0; N.Main.alertSound=function() sounds=sounds+1 end
        N.Main.findAlerts(); eq(sounds,0,"source claims never sound on a later poll")
        eq(#h.sent(),0)
    end
end)

test("Sources: offer drops untracked and contradictory realms before Known stores anything",function()
    local N=setup("Enemy Player-OtherRealm"); yes(type(N.Sources.offer)=="function")
    local e=ev(); e.name="Enemy Player-TestRealm"; no(N.Sources.offer(e)); eq(next(N.Main.find.known.entries),nil)
    e.name="Stranger Player"; no(N.Sources.offer(e)); eq(next(N.Main.find.known.entries),nil)
    e.name="Enemy Player-OtherRealm"; yes(N.Sources.offer(e))
    N=setup("Enemy Player"); e.name="Enemy Player-OtherRealm"; yes(N.Sources.offer(e))
    N=setup("Enemy Player-OtherRealm"); e.name="Enemy Player"; yes(N.Sources.offer(e))
    yes(N.Find.rows(N.Main.find,h.clock(),100)[1].realmUnknown)
end)

test("Sources: offer uses only live guild Watch matches and never adds saved tracked names",function()
    local N=setup(); yes(type(N.Sources.offer)=="function")
    local hash=N.Watch.hash("Enemy Player")
    N.Watch.receive(N.Main.watch,"T|1|aa|1|1|"..hash,"Guild Peer",h.clock())
    yes(N.Sources.offer(ev("relayed"))); eq(#N.Main.find.names,0)
    yes(N.Known.get(N.Main.find.known,"Enemy Player",h.clock()))
    h.clock(h.clock()+N.Watch.TTL); local e=ev(); e.name="Enemy Player"; no(N.Sources.offer(e))
end)

test("Sources: unknown observed time stays unknown and duplicate old evidence never becomes fresh",function()
    local N=setup("Enemy Player"); yes(type(N.Sources.offer)=="function")
    local e=ev(); e.at=nil; yes(N.Sources.offer(e))
    local row=N.Find.rows(N.Main.find,h.clock(),100)[1]; yes(row.status:find("time unknown",1,true))
    local first=N.Known.get(N.Main.find.known,e.name,h.clock()).reported; eq(first.observedAt,nil); eq(first.got,h.clock())
    h.clock(h.clock()+20); yes(N.Sources.offer(e)); eq(N.Known.get(N.Main.find.known,e.name,h.clock()).reported.at,first.at)
    e=ev(); e.at=h.clock()-N.Known.TTL; no(N.Sources.offer(e))
    e=ev(); e.at=h.clock()+1; no(N.Sources.offer(e))
    e=ev(); e.got=h.clock()+1; no(N.Sources.offer(e))
end)

test("Sources: readable-looking secret scalars cannot be offered",function()
    local N=setup("Enemy Player"); local old=issecretvalue
    for _,key in ipairs({"name","guid","faction","zone","map","x","y","shard","at","got","kind","net","via"}) do
        local e=ev(); local hidden=e[key]
        _G.issecretvalue=function(v) return rawequal(v,hidden) or old(v) end
        local ok,result=pcall(N.Sources.offer,e)
        _G.issecretvalue=old
        yes(ok); no(result,key); eq(next(N.Main.find.known.entries),nil)
    end
end)

test("Sources: malformed secret and throwing offers store nothing and never set runtime error",function()
    local N=setup("Enemy Player"); yes(type(N.Sources.offer)=="function")
    for _,key in ipairs({"name","guid","faction","zone","map","x","y","shard","at","got","kind","net","via"}) do
        local e=ev(); e[key]=h.secret; no(N.Sources.offer(e),key)
    end
    for _,pair in ipairs({{"kind","own"},{"net","missing"},{"x",1.1},{"y",-1},{"map",-1},{"name","Bad|Name"}}) do
        local e=ev(); e[pair[1]]=pair[2]; no(N.Sources.offer(e))
    end
    no(N.Sources.offer(setmetatable({},{__index=function() error("unreadable") end})))
    eq(next(N.Main.find.known.entries),nil); no(N.Main.error)
    h.combat(true); no(N.Sources.offer(ev())); h.combat(false); h.instance(true); no(N.Sources.offer(ev()))
end)
