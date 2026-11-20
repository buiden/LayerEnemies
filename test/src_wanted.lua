-- Wanted v1.29.2 protocol facts, constructed frames only; no donor execution.
local h=...
local test,eq,yes,no=h.test,h.eq,h.yes,h.no
local function setup(name)
    local N=h.load()
    if name then yes(N.Find.add(N.Main.find,name)) end
    return N
end
local function bytes(hex) return (hex:gsub('..',function(v) return string.char(tonumber(v,16)) end)) end
local function payload(N,t) return assert(N.Codec.addonEncode(assert(N.Codec.deflateStored(assert(N.Codec.lsWrite(t)))))) end
local function frames(N,tag,t,id,chunk)
    local b=payload(N,t); local n=math.ceil(#b/(chunk or 240)); local out={}
    for i=1,n do out[i]=tag..":"..(id or "a")..":"..i.."/"..n..":"..b:sub((i-1)*(chunk or 240)+1,i*(chunk or 240)) end
    return out
end
local function send(N,tag,t,route,sender,id)
    for _,f in ipairs(frames(N,tag,t,id)) do h.deliver("CHAT_MSG_ADDON","WNTD",f,route or "GUILD",sender or "Witness Player") end
end
local function sight(name) return {g="Player-1-AB",n=name or "Enemy One",z="Ashenvale",m=100,x=50,y=40} end
local function known(N,name) local p=N.Known.get(N.Main.find.known,name or "Enemy One",h.clock()); return p and p.reported end
local function empty(N) eq(next(N.Main.find.known.entries),nil); no(N.Main.error) end
local vectors=assert(loadfile("test/fixtures/wanted_vectors.lua"))()

test("Wanted: independent zlib record hash and decoder ceilings",function()
    local N=setup("Enemy One"); local raw=bytes(vectors.record)
    local t=N.Wanted.decode(raw); yes(t); eq(t.r[1].hash,vectors.hash); yes(N.Wanted.record(t.r[1]))
    h.deliver("CHAT_MSG_ADDON","WNTD","R:z:1/1:"..raw,"GUILD","Witness Player"); yes(known(N))
    eq(N.Wanted.decode(bytes(vectors.bomb)),nil,"64 KiB expansion ceiling")
    yes(N.Wanted.decode(bytes(vectors.limit)),"exact 64 KiB output is allowed")
    eq(N.Wanted.decode(bytes(vectors.over_depth)),nil)
    local big=payload(N,{big=string.rep("\000",16000)}); yes(#big>30272)
    eq(N.Wanted.decode(big),nil,"encoded bytes ceiling")
    for i=1,#raw-1 do eq(N.Wanted.decode(raw:sub(1,i)),nil,"truncated deflate") end
end)

test("Wanted: deterministic 5000-input decoder and dispatch fuzz has no errors",function()
    local N=setup("Enemy One"); local state={}; local seed=81723; local base=bytes(vectors.record)
    local function rand(n) seed=(seed*16807)%2147483647; return seed%n end
    local attempts=0; N.Wire.send=function() attempts=attempts+1 end; N.BNet.send=N.Wire.send
    for i=1,5000 do
        local out={}; for j=1,rand(300) do out[j]=string.char(rand(256)) end
        local s=table.concat(out)
        if i%3==0 then local k=rand(#base)+1; s=base:sub(1,k-1)..string.char(rand(256))..base:sub(k+1) end
        local tripped=false
        debug.sethook(function() tripped=true; error("Wanted fuzz instruction ceiling") end,"",1000000)
        local ok=pcall(function()
            N.Wanted.decode(s)
            N.Wanted.join(state,"fuzz"..(i%32),s,i%2==0,10+i/100)
            N.Wanted.record({kind=s,id=s,origin=s,seq=i,prev=s,t=i,data={x=s},hash=s})
            h.deliver("CHAT_MSG_ADDON","WNTD",s,"GUILD","Fuzz Player")
            h.deliver("BN_CHAT_MSG_ADDON",i%2==0 and "WNTDB" or "WNTDP",s,"WHISPER",i%128+1)
        end)
        debug.sethook(); yes(ok,"input "..i); no(tripped,"bounded decode "..i); no(N.Main.error)
    end
    empty(N); eq(attempts,0)
end)
local function count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
-- Independent test oracle for the audit's newline/sorted-key hash, not W's checker.
local function hash(r)
    local keys={}; for k in pairs(r.data) do keys[#keys+1]=k end; table.sort(keys)
    local s=r.kind.."\n"..r.id.."\n"..r.prev.."\n"..tostring(r.t)
    for _,k in ipairs(keys) do s=s.."\n"..k.."="..tostring(r.data[k]) end
    local a,b=1,0; for i=1,#s do a=(a+s:byte(i))%65521; b=(b+a)%65521 end
    return string.format("%08x",b*65536+a)
end
local function record(kind,changes)
    local d={killer="Player-1-CD",killerName="Friendly One",killerFaction="Alliance",victim="Player-1-AB",victimName="Enemy One",victimFaction="Horde",
        deathId="d1",zone="Ashenvale",mapId=100,x=50,y=40,l="1-0-6"}
    if kind=="claim" then d={bounty="w1",kill="k1",victim="Player-1-AB",victimName="Enemy One",zone="Ashenvale",killT=GetServerTime()-7}
    elseif kind=="bounty" then d={target="Player-1-AB",targetName="Enemy One",faction="Horde",amount=100,zone="Ashenvale",mapId=100,x=50,y=40,seenAt=GetServerTime()-8}
    elseif kind=="spotted" then d={target="Player-1-AB",zone="Ashenvale",mapId=100,x=50,y=40,l="1-0-6"} end
    local r={kind=kind,id="Witness Player:1000001",origin="Witness Player",seq=1000001,prev="0",t=GetServerTime()-3,data=d}
    if changes then changes(r) end
    r.hash=hash(r); return r
end

test("Wanted: record and sighting location fields do not alias each other",function()
    local N=setup("Enemy One"); local r=record("kill",function(v) v.data.z="Wrong Zone"; v.data.m=200 end)
    send(N,"R",{v="1.29.2",r={r}}); yes(known(N)); eq(known(N).zone,100); no(known(N).detail:find("Wrong Zone",1,true))
    N=setup("Enemy One"); local d=sight(); d.z=nil; d.m=nil; d.zone="Ashenvale"; d.mapId=200
    send(N,"S",{v="1.29.2",s={d}}); yes(known(N)); eq(known(N).zone,nil)
end)

test("Wanted: bad hashes and malformed payloads increment refusal without chat",function()
    local N=setup("Enemy One"); local before=#h.log(); local r=record("kill"); r.hash="00000000"
    send(N,"R",{v="1.29.2",r={r}}); yes(N.Wanted.stats.refused>0); empty(N); eq(#h.log(),before)
    local refusals=N.Wanted.stats.refused
    h.deliver("CHAT_MSG_ADDON","WNTD","S:b:1/1:not-deflate","GUILD","Witness Player")
    yes(N.Wanted.stats.refused>refusals); eq(#h.log(),before)
end)

test("Wanted: record batch and flat-data limits reject valid oversized objects",function()
    for _,pair in ipairs({{"R",11},{"F",9}}) do
        local N=setup("Enemy One"); local r=record("kill"); local list={}
        for i=1,pair[2] do list[i]=r end
        send(N,pair[1],{v="1.29.2",r=list}); empty(N)
    end
    local N=setup(); local W=N.Wanted
    local r=record("kill",function(v) v.data={}; for i=1,65 do v.data["k"..i]=i end end); no(W.record(r))
    r=record("kill",function(v) v.data={}; for i=1,64 do v.data["k"..i]=i end end); yes(W.record(r))
    r=record("kill",function(v) v.data.note=string.rep("x",513) end); no(W.record(r))
    r=record("kill",function(v) v.data.note=string.rep("x",512) end); yes(W.record(r))
    r=record("kill"); r.data.more={}; no(W.record(r))
    r=record("bounty",function(v) v.data.amount=-1 end); no(W.record(r))
    r=record("kill",function(v) v.seq=2147483648; v.id=v.origin..":"..v.seq end); no(W.record(r))
    r=record("kill",function(v) v.data.x="50" end); no(W.record(r))
end)

test("Wanted: stale and future records are refused before the offer boundary",function()
    for _,kind in ipairs({"kill","bounty","claim"}) do
        for _,dt in ipairs({-3600,1}) do
            local N=setup("Enemy One"); local offers=0; N.Sources.offer=function() offers=offers+1; return false end
            local r=record(kind,function(v)
                if kind=="bounty" then v.data.seenAt=GetServerTime()+dt
                elseif kind=="claim" then v.data.killT=GetServerTime()+dt else v.t=GetServerTime()+dt end
            end)
            send(N,"F",{v="1.29.2",r={r}}); eq(offers,0)
        end
    end
end)

test("Wanted: bounded dedupe evictions do not save evidence or new names",function()
    local N=setup("Enemy One"); local saved=N.Codec.lsWrite(LayerEnemiesDB)
    for i=1,512 do N.Wanted.state.seen["reserved"..i]={expires=h.clock()+3600,owner="reserved"..i,guild=true,order=i} end
    N.Wanted.state.seenOrder=512
    send(N,"S",{v="1.29.2",s={sight()}}); yes(known(N)); eq(count(N.Wanted.state.seen),512)
    no(N.Wanted.state.seen.reserved1); yes(N.Wanted.state.seen.reserved2); eq(N.Wanted.stats.evicted,1)
    send(N,"S",{v="1.29.2",s={sight()}}); eq(count(N.Wanted.state.seen),512); eq(N.Wanted.stats.evicted,1)
    no(N.Main.error)
    eq(N.Codec.lsWrite(LayerEnemiesDB),saved,"no evidence or name writes to saved state")
    h.clock(h.clock()+3600); N.Sources.tick(h.clock()); eq(count(N.Wanted.state.seen),0); eq(known(N),nil)
    N=setup(); local before=N.Codec.lsWrite(LayerEnemiesDB)
    N.Watch.receive(N.Main.watch,"T|1|aa|1|1|"..N.Watch.hash("Enemy One"),"Guild Peer",h.clock())
    send(N,"S",{v="1.29.2",s={sight()}}); yes(known(N)); eq(#N.Main.find.names,0)
    eq(N.Codec.lsWrite(LayerEnemiesDB),before)
end)

test("Wanted: known same-faction GUIDs cannot become enemies through sightings",function()
    local N=setup("Enemy One")
    yes(N.Sources.offer{name="Enemy One",guid="Player-1-AB",faction="Alliance",zone="Ashenvale",kind="self",net="wanted",at=h.clock()-1,got=h.clock()})
    local before=known(N).at
    send(N,"S",{v="1.29.2",s={sight()}}); eq(known(N).at,before); eq(known(N).faction,"Alliance")
end)

test("Wanted: echo realm identity and source switch cannot admit forged claims",function()
    local N=setup("Enemy One"); send(N,"S",{v="1.29.2",s={sight()}},"GUILD","Me"); empty(N)
    N=setup("Enemy One-Elsewhere"); send(N,"S",{v="1.29.2",s={sight("Enemy One-TestRealm")}}); empty(N)
    N=setup("Enemy One"); send(N,"S",{v="1.29.2",s={sight()}},"GUILD","Bad|Sender"); empty(N)
    N=setup("Enemy One"); N.Main.net("net wanted off"); send(N,"S",{v="1.29.2",s={sight()}}); empty(N)
    N.Main.net("net wanted on"); send(N,"S",{v="1.29.2",s={sight()}}); yes(known(N))
    N=setup("Enemy One"); h.loaded().WantedDeadOrDead=true
    send(N,"S",{v="1.29.2",s={sight()}}); yes(known(N),"stand-down does not disable receipt")
end)

test("Wanted: source diagnostics are opt-in bounded and protected",function()
    local N=setup(); local calls=0
    yes(N.Sources.register{name="diagnostic",prefixes={},status=function()
        calls=calls+1; local t={}; for i=1,241 do t[i]="line "..i end; return t
    end})
    N.Sources.lines(); eq(calls,0)
    local list=N.Sources.lines("diagnostic"); eq(calls,1); eq(#list,241)
    yes(N.Sources.register{name="brokenstatus",prefixes={},status=function() error("bad status") end})
    N.Main.net("net brokenstatus"); no(N.Main.error)
    N.Main.net("net wanted"); yes(table.concat(h.log(),"\n"):find("wanted: heard=0 accepted=0 sent=0 refused=0",1,true))
end)

test("Wanted: R and F records use record time participants and honest provenance",function()
    for _,kind in ipairs({"kill","death","assist","claim","bounty"}) do
        for _,route in ipairs({"GUILD","CHANNEL","WHISPER"}) do
            for _,tag in ipairs({"R","F"}) do
                local N=setup("Enemy One"); N.Find.add(N.Main.find,"Friendly One")
                local r=record(kind); send(N,tag,{v="1.29.2",r={r}},route)
                local e=known(N); yes(e,kind.." "..route.." "..tag)
                eq(e.kind,"claim"); eq(e.evidenceKind,kind=="bounty" and "cached" or tag=="F" and "relayed" or "witness")
                eq(e.observedAt,h.clock()-(kind=="bounty" and 8 or kind=="claim" and 7 or 3)); eq(e.got,h.clock())
                no(known(N,"Friendly One")); no(e.layer); no(N.Find.rows(N.Main.find,h.clock(),100)[1].canAsk)
                if kind=="kill" then eq(e.shard,"1-0-6"); eq(e.x,.5); eq(e.y,.4) end
                eq(#h.sent(),0)
            end
        end
    end
end)

test("Wanted: forged origin hash malformed envelope and stale records store nothing",function()
    local cases={
        function(r) r.id="wrong:1000001" end,
        function(r) r.seq=1000000; r.id=r.origin..":"..r.seq end,
        function(r) r.prev="" end,
        function(r) r.t=GetServerTime()-3600 end,
        function(r) r.t=GetServerTime()+1 end,
        function(r) r.data.x="50" end,
        function(r) r.data.victimFaction="unknown" end,
        function(r) r.origin="Another Player"; r.id=r.origin..":"..r.seq end,
        function(r) r.test=true end,
    }
    for i,change in ipairs(cases) do local N=setup("Enemy One"); send(N,"R",{v="1.29.2",r={record("kill",change)}}); empty(N) end
    local unknown=setup("Enemy One"); send(unknown,"R",{v="1.29.2",r={record("kill",function(r) r.data.l="6" end)}})
    yes(known(unknown)); eq(known(unknown).shard,nil,"separable malformed layer")
    local N=setup("Enemy One"); local r=record("kill"); r.hash="00000000"; send(N,"R",{v="1.29.2",r={r}}); empty(N)
    N=setup("Enemy One"); r=record("kill"); r.data.nested={}; send(N,"R",{v="1.29.2",r={r}}); empty(N)
    N=setup(); send(N,"R",{v="1.29.2",r={record("kill")}}); empty(N)
    for _,kind in ipairs({"claim","bounty"}) do
        N=setup("Enemy One"); r=record(kind,function(v) v.data[kind=="claim" and "killT" or "seenAt"]=GetServerTime()-3600 end)
        send(N,"F",{v="1.29.2",r={r}}); empty(N)
    end
end)

test("Wanted: relayed records cannot promote provenance or renew original time",function()
    local N=setup("Enemy One"); local r=record("death")
    send(N,"R",{v="1.29.2",r={r}},"WHISPER","Carrier Player"); eq(known(N).evidenceKind,"relayed")
    local at=known(N).at; h.clock(h.clock()+25)
    send(N,"F",{v="1.29.2",r={r}},"GUILD","Another Carrier","b"); eq(known(N).at,at)
    eq(N.Wanted.stats.accepted,1,"record dedupe across carriers")
end)

test("Wanted: spotted resolves only an already tracked exact GUID without a name cache",function()
    local N=setup("Enemy One"); send(N,"F",{v="1.29.2",r={record("spotted")}}); empty(N)
    send(N,"S",{v="1.29.2",s={sight()}},"GUILD",nil,"b"); yes(known(N))
    -- Let the spotted event be newer than the sighting, but distinct receipt time.
    h.clock(h.clock()+5); local r=record("spotted",function(v) v.t=GetServerTime() end)
    send(N,"F",{v="1.29.2",r={r}},"WHISPER",nil,"c")
    eq(known(N).evidenceKind,"relayed"); eq(known(N).shard,"1-0-6")
    N=setup("Enemy One"); r=record("spotted"); r.data.target="Player-1-EF"; r.hash=hash(r)
    send(N,"F",{v="1.29.2",r={r}}); empty(N)
end)

test("Wanted: Battle.net summaries are anonymous diagnostics never named evidence",function()
    local N=setup("Enemy One"); local calls=0
    N.BNet.who=function(id) calls=calls+1; return {name="Other Peer",realm="Test Realm",faction="Horde"} end
    local raw=bytes("635413ca16f211aa923213ca658914ca0932d435d03513ca63070102")
    h.deliver("BN_CHAT_MSG_ADDON","WNTDB",raw,"WHISPER",71)
    N.Trust.read(N.Main.store,h.clock(),"7086-7",7) -- known-mode source-key diagnostic
    N.Main.net("net wanted"); local text=table.concat(h.log(),"\n")
    yes(text:find("map 1424 / layer 1-0-6: 3",1,true),"anonymous audit L summary in diagnostics")
    eq(calls,1); empty(N); eq(#h.sent(),0)
    h.deliver("BN_CHAT_MSG_ADDON","WNTDB",payload(N,{k="L",z={{m=1424,l="1-0-6",n=2}}}),"WHISPER",72)
    local lines=N.Sources.lines("wanted"); yes(table.concat(lines,"\n"):find("layer 1-0-6: 3",1,true),"max not sum across senders")
    h.clock(h.clock()+600); N.Sources.tick(h.clock()); eq(count(N.Wanted.state.far),0,"L expires at 600 seconds")
    empty(N)
end)

test("Wanted: Battle.net eligibility and numbered parts are verified before ingestion",function()
    local N=setup(); N.BNet.who=function() return {name="Other Peer",realm="Test Realm",faction="Horde"} end
    local raw=payload(N,{k="L",z={{m=100,l="1-0-6",n=3}}})
    local cut=math.floor(#raw/2)
    h.deliver("BN_CHAT_MSG_ADDON","WNTDP","1:2/2:"..raw:sub(cut+1),"WHISPER",71)
    h.deliver("BN_CHAT_MSG_ADDON","WNTDP","1:1/2:"..raw:sub(1,cut),"WHISPER",71)
    yes(N.Wanted.state.far[71]); empty(N)
    for _,peer in ipairs({false,{name="Other Peer",realm="Elsewhere",faction="Horde"},{name="Other Peer",realm="Test Realm",faction="Alliance"}}) do
        N=setup(); N.BNet.who=function() return peer or nil end
        h.deliver("BN_CHAT_MSG_ADDON","WNTDB",raw,"WHISPER",71); eq(count(N.Wanted.state.far),0)
    end
    local W=N.Wanted; local st={}
    for i=1,2 do W.join(st,"bn:71",i..":1/2:a",true,10) end
    W.join(st,"bn:71","3:1/2:a",true,10); eq(count(st.streams),2)
    eq(W.join({},"bn:71","1:1/9:a",true,10),nil)
    st={}; W.join(st,"bn:71","1:1/9:a",true,10); eq(count(st.streams),0)
    eq(W.join({},"bn:71","a:1/1:a",true,10),nil)
    eq(W.join({},"bn:71","1:1/1:"..string.rep("a",3785),true,10),nil)
    eq(W.join({},"bn:71","1:1/1:"..string.rep("a",3784),true,10),string.rep("a",3784))
end)

test("Wanted: summary validation caps senders entries and finite counts",function()
    local N=setup(); N.BNet.who=function() return {name="Other Peer",realm="Test Realm",faction="Horde"} end
    for id=1,21 do h.deliver("BN_CHAT_MSG_ADDON","WNTDB",payload(N,{k="L",z={{m=100,l="1-0-6",n=id}}}),"WHISPER",id) end
    eq(count(N.Wanted.state.far),20)
    local invalid={ {m=0,l="1-0-6",n=1}, {m=100,l="bad",n=1}, {m=100,l="1-0-6",n=0} }
    for i,v in ipairs(invalid) do h.deliver("BN_CHAT_MSG_ADDON","WNTDB",payload(N,{k="L",z={v}}),"WHISPER",i); eq(N.Wanted.state.far[i].rows[1].n,i) end
    local z={}; for i=1,13 do z[i]={m=i,l="1-0-6",n=1} end
    h.deliver("BN_CHAT_MSG_ADDON","WNTDB",payload(N,{k="L",z=z}),"WHISPER",1); eq(#N.Wanted.state.far[1].rows,1)
    h.deliver("BN_CHAT_MSG_ADDON","WNTDB",payload(N,{k="L",z={{m=100,l="1-0-6",n=999}}}),"WHISPER",1)
    eq(N.Wanted.state.far[1].rows[1].n,200)
end)

test("Wanted: passive channel join preserves player ownership and two free slots",function()
    local N=setup(); eq(N.Directory.channel("wanted"),"WantedNetAlliance")
    N.Net.SHIP.wanted=true; N.Directory.sync(); yes(N.Directory.joined("wanted"))
    local scans=0; C_ChatInfo.GetChannelRosterInfo=function() scans=scans+1 end
    SetSelectedDisplayChannel=function() scans=scans+1 end
    h.advance(301); eq(scans,0,"D1 joins for receipt, not roster discovery")
    eq(h.forbidden(),0,"join and roster APIs stay owned by Directory")
    N.Main.net("net wanted off"); no(N.Directory.joined("wanted"))
    N=setup(); N.Net.SHIP.wanted=true; GetNumDisplayChannels=function() return 8 end
    N.Directory.sync(); no(N.Directory.joined("wanted"),"two free slots after joining")
    N=setup(); N.Net.SHIP.wanted=true; GetNumDisplayChannels=function() return 0 end
    N.Directory.sync(); no(N.Directory.joined("wanted"),"unreadable startup list")
    N=setup(); N.Net.SHIP.wanted=true; h.loaded().WantedDeadOrDead=true
    N.Directory.sync(); no(N.Directory.joined("wanted"),"donor owns membership")
    send(N,"S",{v="1.29.2",s={sight()}}); empty(N)
end)

test("Wanted: inbound budgets are per canonical sender and bounded globally",function()
    local N=setup("Enemy One"); local calls=0; local decode=N.Wanted.decode
    N.Wanted.decode=function(...) calls=calls+1; return decode(...) end
    -- Untracked input exercises the datagram budget without spending replay quota.
    for i=1,61 do send(N,"E",{v="1.29.2",g="Player-1-AB",n="Untracked One",z="Ashenvale"},"GUILD",nil,string.format("%x",i)) end
    eq(calls,60); eq(count(N.Wanted.state.rates.guild),1)
    -- The realm-qualified spelling must share the same budget.
    send(N,"S",{v="1.29.2",s={sight()}},"GUILD","Witness Player-TestRealm","ab"); eq(calls,60)
    h.clock(h.clock()+60); send(N,"S",{v="1.29.2",s={sight()}},"GUILD",nil,"ac"); eq(calls,61)
    N=setup(); calls=0; N.BNet.who=function() calls=calls+1; return {name="Other Peer",realm="Test Realm",faction="Horde"} end
    local b=payload(N,{k="L",z={{m=100,l="1-0-6",n=1}}})
    for i=1,31 do h.deliver("BN_CHAT_MSG_ADDON","WNTDB",b,"WHISPER",71) end
    eq(calls,30,"rate before resolver/decompression")
    for id=1,130 do h.deliver("BN_CHAT_MSG_ADDON","WNTDB",b,"WHISPER",id) end
    eq(count(N.Wanted.state.rates.bnet),128)
    h.clock(h.clock()+120); N.Sources.tick(h.clock()); eq(count(N.Wanted.state.rates.bnet),0)
end)

test("Wanted: receive tick and every ignored tag never attempt any send",function()
    local N=setup("Enemy One"); local attempts=0
    N.Wire.send=function() attempts=attempts+1; return false end
    N.BNet.send=function() attempts=attempts+1; return false end
    N.BNet.who=function() return {name="Other Peer",realm="Test Realm",faction="Horde"} end
    for _,tag in ipairs({"H","V","N","U","M","O","I","W","Y","J","P","T","A","C","L","X","K","G"}) do
        send(N,tag,{v="1.29.2",c={},s={sight()},r={record("kill")}},"WHISPER")
    end
    for _,k in ipairs({"H","A","N","S","R"}) do
        h.deliver("BN_CHAT_MSG_ADDON","WNTDB",payload(N,{k=k,v="1.29.2",s={sight()},r={record("kill")}}),"WHISPER",71)
    end
    h.deliver("BN_CHAT_MSG_ADDON","WNTDB",payload(N,{k="N",z={{m=100,l="1-0-6",n=1}}}),"WHISPER",71)
    eq(count(N.Wanted.state.far),0,"non-L body is never a layer summary")
    for _=1,4 do h.advance(1) end
    N.Main.findAlerts(); empty(N); eq(attempts,0); eq(#h.sent(),0); eq(N.Wanted.stats.sent,0)
    send(N,"S",{v="1.29.2",s={sight()}}); yes(known(N)); N.Main.findAlerts(); eq(attempts,0)
    for _,mode in ipairs({"combat","instance","off"}) do
        N=setup("Enemy One"); local b=payload(N,{k="L",z={{m=100,l="1-0-6",n=1}}}); local calls=0
        N.BNet.who=function() calls=calls+1 end
        if mode=="combat" then h.combat(true) elseif mode=="instance" then h.instance(true) else N.Main.net("net wanted off") end
        send(N,"S",{v="1.29.2",s={sight()}}); h.deliver("BN_CHAT_MSG_ADDON","WNTDB",b,"WHISPER",71)
        empty(N); eq(calls,0)
    end
end)

test("Wanted: two unfinished messages per sender cover all addon routes",function()
    local N=setup()
    for i=1,5 do
        local route=i<=2 and "GUILD" or i<=4 and "CHANNEL" or "WHISPER"
        h.deliver("CHAT_MSG_ADDON","WNTD","R:"..i..":1/2:a",route,"Witness Player")
    end
    eq(count(N.Wanted.state.streams),2,"a sender cannot multiply capacity by route")
end)

test("Wanted: numbered framing supports reorder and bounds every unfinished stream",function()
    local N=setup(); yes(N.Wanted and N.Wanted.join,"bounded frame join exists")
    local W=N.Wanted; local st={}
    eq(W.join(st,"peer","S:a:2/2:world",false,10),nil)
    eq(W.join(st,"peer","S:a:1/2:hello",false,11),"helloworld")
    eq(count(st.streams),0,"completed streams release capacity")
    eq(W.join(st,"peer","S:a:1/2:a",false,20),nil)
    eq(W.join(st,"other","S:a:2/2:b",false,20),nil)
    eq(W.join(st,"peer","S:a:2/2:b",false,50),nil,"expires at 30 not 31")
    local function bad(f) eq(W.join({},"peer",f,false,10),nil,f:sub(1,25)) end
    bad("S:0:1/1:a"); bad("S:1000:1/1:a"); bad("S:a:0/1:a"); bad("S:a:1/13:a")
    st={}; W.join(st,"peer","S:a:1/13:a",false,10); eq(count(st.streams),0)
    bad("S:a:1/1:"..string.rep("a",241)); bad("S:a:1/1:"); bad("\001S:a:1/1:a")
    st={}; for i=1,2 do W.join(st,"peer","S:"..i..":1/2:a",false,10) end
    W.join(st,"peer","S:3:1/2:a",false,10); eq(count(st.streams),2)
    st={}; for i=1,16 do W.join(st,"peer"..i,"S:a:1/2:a",false,10,nil,true) end
    W.join(st,"overflow","S:a:1/2:a",false,10,nil,true); eq(count(st.streams),16)
    st={}; W.join(st,"peer","S:a:1/2:a",false,10); W.join(st,"peer","S:a:1/2:b",false,11)
    eq(W.join(st,"peer","S:a:2/2:c",false,12),nil,"conflicting duplicate poisons assembly")
    st={}; W.join(st,"peer","S:a:1/2:a",false,10); eq(W.join(st,"peer","E:a:2/2:b",false,11),nil)
    eq(count(st.streams),0,"tag changes cannot complete another message")
    st={}; W.join(st,"peer","S:a:1/2:a",false,10); W.join(st,"peer","S:a:2/3:b",false,11)
    eq(count(st.streams),0,"total conflict")
    st={}; W.join(st,"peer","S:a:1/2:a",false,10)
    eq(W.join(st,"peer","S:a:2/2:b",false,9),nil,"rollback refused")
    st={}; for i=1,12 do local b=W.join(st,"peer","S:a:"..i.."/12:"..string.rep("a",240),false,10); if i==12 then eq(#b,2880) end end
end)

test("Wanted: fragmented S and E on guild and channel retain no untracked names",function()
    for _,route in ipairs({"GUILD","CHANNEL"}) do
        local N=setup("Enemy One"); local s=sight(); s.u=string.rep("x",180)
        local list=frames(N,"S",{v="1.29.2",s={s}},"a",120); yes(#list>1)
        for i=#list,1,-1 do h.deliver("CHAT_MSG_ADDON","WNTD",list[i],route,"Witness Player") end
        yes(known(N)); local at=known(N).at; h.clock(h.clock()+5)
        for _,f in ipairs(list) do h.deliver("CHAT_MSG_ADDON","WNTD",f,route,"Witness Player") end
        eq(known(N).at,at,"same packet cannot refresh receipt time")
        N=setup("Enemy One"); send(N,"E",setmetatable(sight(),nil),route) -- missing v is refused
        empty(N); local d=sight(); d.v="1.29.2"; send(N,"E",d,route); yes(known(N))
        N=setup(); send(N,"S",{v="1.29.2",s={sight()}},route); empty(N); eq(#N.Main.find.names,0)
    end
end)

test("Wanted: route version array faction and secret guards fail silent",function()
    for _,route in ipairs({"WHISPER","PARTY","RAID","SAY"}) do
        local N=setup("Enemy One"); send(N,"S",{v="1.29.2",s={sight()}},route); empty(N)
    end
    for _,v in ipairs({"1.28.9","1.30.0","1.29.2-beta.1","",false}) do
        local N=setup("Enemy One"); send(N,"S",{v=v,s={sight()}}); empty(N)
    end
    for _,change in ipairs({{"g","Creature-1-AB"},{"g","Player-bad"},{"n","Bad|Name"},{"x",101},{"y",false}}) do
        local N=setup("Enemy One"); local d=sight(); d[change[1]]=change[2]; send(N,"S",{v="1.29.2",s={d}}); empty(N)
    end
    local N=setup("Enemy One"); local list={}; for i=1,16 do list[i]=sight() end
    send(N,"S",{v="1.29.2",s=list}); empty(N)
    N=setup("Enemy One"); N.Main.store.localSeen["Player-1-AB"]={faction="same",at=h.clock()}
    send(N,"S",{v="1.29.2",s={sight()}}); empty(N)
    N=setup("Enemy One"); local old=issecretvalue; local packet=frames(N,"S",{v="1.29.2",s={sight()}})[1]
    issecretvalue=function(v) return v=="Enemy One" or old(v) end
    h.deliver("CHAT_MSG_ADDON","WNTD",packet,"GUILD","Witness Player"); issecretvalue=old; empty(N)
end)

test("Wanted: audit sighting vector reaches measured Find as witness near observer",function()
    local N=setup("Enemy One")
    yes(N.Sources.owns("WNTD"),"Wanted prefix registered")
    yes(h.registered().WNTD); yes(h.registered().WNTDB); yes(h.registered().WNTDP)
    -- audit section 11 example 8, Python zlib/independent LibSerialize bytes.
    local raw=bytes("6354132a4b32d433b2d433122a966a134adf14909358995aa46ba8ebe8249437c9352f35b752c13f2f5528d9c9d7d1dd5528a752a8aac8a5b428bf24b14828d72442a82255a832100102")
    h.deliver("CHAT_MSG_ADDON","WNTD","S:a:1/1:"..raw,"GUILD","Witness Player")
    local r=known(N); yes(r,"sighting is retained"); eq(r.evidenceKind,"witness"); eq(r.kind,"claim")
    eq(r.observedAt,nil); eq(r.got,h.clock()); eq(r.pos,"observer"); eq(r.x,.5); eq(r.y,.4); eq(r.map,1411)
    no(r.layer); local row=N.Find.rows(N.Main.find,h.clock(),100)[1]; no(row.canAsk)
    local text=N.Main.findDetails(row); yes(text:find("seen near",1,true)); yes(text:find("time unknown",1,true))
    N.UI.toggle(); N.UI.select("find"); local ui=N.UI.pool[1]
    yes(ui.sub:GetStringHeight()<=ui.sub.height,"measured details fit")
    local sounds=0; N.Main.alertSound=function() sounds=sounds+1 end; N.Main.findAlerts(); eq(sounds,0)
    eq(#h.sent(),0); no(N.Main.error)
end)
