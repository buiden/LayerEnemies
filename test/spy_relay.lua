-- Guild-intel PR 4: real receive/timer/Wire paths, with synthetic identities only.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local ctx={inGuild=true,inInstance=false,guild="Test Guild"}
local function hx(s) return (s:gsub(".",function(c) return string.format("%02x",c:byte()) end)) end
local function fixture()
    local N=H.load(); H.advance(1); N.Relay.rand=function() return .5 end
    return N
end
local function line(name) return "1.3.8|"..(name or "Cedar-Vale").."|MAGE|40|Orc|Ashenvale||0.4|0.6||100" end
local function incoming(prefix,text,route,sender)
    H.deliver("CHAT_MSG_ADDON",prefix,text,route or "PARTY",sender or "Birch Scout"); H.drain()
end
local function outgoing()
    local out={}
    for _,m in ipairs(H.sent()) do
        yes(m.prefix=="LEGW1" and m.kind=="GUILD" and m.target==nil,"only the existing guild route")
        if m.text:sub(1,8)=="R|1|spy|" then out[#out+1]=m end
    end
    return out
end
local function record(N,name,extra)
    local t={src="spy",kind="seen",origin="Birch Scout",via="Birch Scout",route="PARTY",rid="abc",zone=100,
        heard=H.clock(),share="public",count=1,layer={ns="unknown"},enemies={{name=name or "Cedar Vale",hash="abc",class="MAGE",level=40}}}
    for k,v in pairs(extra or {}) do t[k]=v end
    return assert(N.Record.new(t))
end
local function wire(name,age)
    return "R|1|spy|seen|"..hx("Birch Scout").."|abc|100|400|600|1|u||"..tostring(age or 0).."|"..hx(name or "Cedar Vale")..":MAGE:40"
end
local function rows(N) return N.Store.rows(N.Main.store,H.clock(),"reported") end

for _,case in ipairs({{"[Spy]",line(),"spy",0},{"ForeverSpy1","1\tCedar Vale\tAshenvale","fspy",0},
    {"FSENT03","1~Player-7103-00AB13~Cedar-Vale~MAGE~40~Ashenvale~5","sent",5}}) do
    for _,route in ipairs({"PARTY","RAID"}) do
        test("Spy relay 7: "..case[1].." "..route.." becomes one named guild claim after the wait",function()
            local N=fixture(); N.Relay.rand=function() return 2 end
            incoming(case[1],case[2],route,"Birch-Scout-7103")
            eq(N.Safe.count(N.Main.relay.pending),1,"party/raid sighting offered")
            eq(#outgoing(),0); H.advance(1.9); eq(#outgoing(),0); H.advance(.2)
            local out=outgoing(); eq(#out,1); yes(#out[1].text<=255)
            local r=assert(N.Relay.decode(out[1].text,"Guild Courier",H.clock()))
            eq(r.src,"guild"); eq(r.label,"spy"); eq(r.kind,"seen"); eq(r.origin,"Birch Scout-7103")
            eq(r.hand,"relayed"); eq(r.count,1); eq(r.zone,100); eq(#r.enemies,1)
            eq(r.enemies[1].name,"Cedar Vale"); eq(r.enemies[1].hash,nil,"name, not the parser's hash")
            eq(r.layer.ns,"unknown"); eq(r.layer.value,nil); eq(r.at,H.clock()-math.floor(2.1+case[4]))
            if case[1]=="[Spy]" then eq(r.pos,"observer"); eq(r.x,.4); eq(r.y,.6) end
            local direct=rows(N)[1].record; eq(direct.src,case[3]); eq(direct.hand,"first")
            no(N.Main.error); H.advance(20); eq(#outgoing(),1,"no retry")
        end)
    end
end

test("Spy relay 7: GUILD never offered, even when a group copy would be eligible",function()
    local N=fixture(); incoming("[Spy]",line(),"GUILD")
    eq(#rows(N),1); eq(next(N.Main.relay.pending),nil); H.advance(3); eq(#outgoing(),0)
    local r=record(N,nil,{route="GUILD"}); local ok,why=N.Relay.offer(N.Main.relay,r,H.clock(),ctx)
    no(ok); eq(why,"route")
    for _,prefix in ipairs({"ForeverSpy1","FSENT03"}) do
        incoming(prefix,prefix=="ForeverSpy1" and "1\tCedar Vale\tAshenvale" or "1~Player-7103-00AB13~Cedar-Vale~MAGE~40~Ashenvale~0","GUILD")
    end
    H.advance(3); eq(#outgoing(),0)
end)

test("Spy relay 8: a guildmate copy cancels the pending relay and never echoes",function()
    local N=fixture(); N.Relay.rand=function() return 2 end
    incoming("[Spy]",line()); local key,p=next(N.Main.relay.pending); yes(p)
    H.advance(.5); local text=assert(N.Relay.encode(p.record,H.clock()))
    incoming("LEGW1",text,"GUILD","Guild Courier")
    eq(N.Main.relay.pending[key],nil); H.advance(3); eq(#outgoing(),0)
    incoming("[Spy]",line()); eq(next(N.Main.relay.pending),nil,"heard copy remains remembered")
    H.advance(3); eq(#outgoing(),0)
end)

test("Spy relay 9: frozen main decoder rejects unknown spy src without storing",function()
    local N=fixture(); N.Main.track("Cedar Vale")
    -- Verbatim Relay.lua from main 16549ca; not a reimplementation of the old grammar.
    assert(loadfile("test/fixtures/relay_16549ca.lua"))("LayerEnemies",N)
    local r,why=N.Relay.decode(wire(),"Guild Courier",H.clock()); eq(r,nil); eq(why,"invalid")
    incoming("LEGW1",wire(),"GUILD","Guild Courier")
    eq(N.Main.lastDrop,"relay invalid"); eq(next(N.Main.store.reports),nil)
    eq(next(N.Main.find.known.entries),nil); eq(N.Main.findRows()[1].at,nil); eq(#outgoing(),0)
end)

test("Spy relay 10: accepted into Known as relayed claim, never an ask or hop target",function()
    local N=fixture(); incoming("LEGW1",wire(),"GUILD","Guild Courier")
    local cached=N.Known.get(N.Main.find.known,"Cedar Vale",H.clock()); yes(cached); eq(cached.seen,nil)
    eq(cached.reported.source,"relayed"); eq(cached.reported.kind,"claim"); eq(cached.reported.spotter,"Birch Scout")
    eq(cached.reported.ns,"unknown"); eq(cached.reported.layer,nil); eq(cached.reported.pos,"observer")
    N.Main.track("Cedar Vale"); local r=N.Main.findRows()[1]; yes(r.reported); no(r.canAsk); no(r.reported.canAsk)
    yes(N.Main.findText(r):find("Reported:",1,true)); yes(N.Main.findText(r):find("claim",1,true))
    local rr=rows(N)[1]; eq(rr.source,"relayed by Guild Courier (Spy)")
    eq(N.Hop.candidate(rr.record,{}),nil); eq(#N.Store.reporters(N.Main.store,H.clock()),0)
    no(N.AskInvite("Birch Scout")); N.UI.toggle(); N.UI.select("find")
    no(N.UI.pool[1].ask:IsShown()); eq(N.UI.pool[1].hopRecord,false)
    eq(next(N.Main.relay.pending),nil); H.advance(3); eq(#outgoing(),0); no(N.Main.error)
end)

test("Spy relay codec: no layer even on a poisoned input, exactly one full name or no line",function()
    local N=fixture(); local r=record(N,nil,{layer={ns="server",value="7085"}})
    local text=assert(N.Relay.encode(r,H.clock())); yes(text:find("|1|u||0|",1,true)); no(text:find("7085",1,true))
    local back=assert(N.Relay.decode(text,"Guild Courier",H.clock())); eq(back.enemies[1].name,"Cedar Vale")
    eq(N.Relay.encode(record(N,nil,{enemies={}}),H.clock()),nil)
    eq(N.Relay.encode(record(N,nil,{enemies={{hash="abc"}}}),H.clock()),nil)
    eq(N.Relay.encode(record(N,nil,{enemies={{name="Cedar Vale"},{name="Elm Vale"}},count=2}),H.clock()),nil)
    eq(N.Relay.encode(record(N,nil,{kind="fight"}),H.clock()),nil)
    local long=string.rep("a",36).." "..string.rep("b",36).."-"..string.rep("c",20)
    eq(N.Relay.encode(record(N,long,{origin=long}),H.clock()),nil,"never truncate the sole name into an empty line")
    for _,bad in ipairs({wire():gsub("|1|u||","|1|s|7085|"),
        wire():gsub("|seen|","|fight|"),wire():gsub("|1|u|","|2|u|"),wire():gsub(hx("Cedar Vale"),"abc"),
        wire()..","..hx("Elm Vale")..":MAGE:40",wire():gsub(hx("Cedar Vale")..":MAGE:40","")}) do
        local decoded,why=N.Relay.decode(bad,"Guild Courier",H.clock()); eq(decoded,nil); eq(why,"invalid")
    end
    local unknown=N.Relay.decode(wire():gsub("|1|u||","|1|u|7085|"),"Guild Courier",H.clock())
    yes(unknown); eq(unknown.layer.ns,"unknown"); eq(unknown.layer.value,nil)
    local old,why=N.Relay.decode(wire(nil,600),"Guild Courier",H.clock()); eq(old,nil); eq(why,"too old")
    eq(N.Relay.decode(wire(),"Birch Scout",H.clock()),nil,"origin may not be its relayer")
end)

test("Spy relay cap: seventh in rolling minute dropped and a new sighting allowed at 60 seconds",function()
    local N=fixture(); local first
    for i=1,7 do
        incoming("[Spy]",line("Enemy-"..H.abc(i)),"PARTY","Scout "..H.abc(i)); H.advance(3)
        if i==1 then first=outgoing()[1] and outgoing()[1].at end
    end
    eq(#outgoing(),6,"seventh dropped despite refilled Wire tokens"); yes(first)
    eq(next(N.Main.relay.pending),nil); H.advance(10); eq(#outgoing(),6,"not deferred")
    H.advance(first+60-H.clock()); incoming("[Spy]",line("Enemy-h"),"RAID","Scout h"); H.advance(1)
    eq(#outgoing(),7,"sliding window reopens")
end)

test("Spy relay cap: pending burst rechecks the cap at dispatch",function()
    local N=fixture(); N.Relay.rand=function() return 10 end
    for i=1,7 do incoming("[Spy]",line("Enemy-"..H.abc(i)),"PARTY","Scout "..H.abc(i)) end
    eq(N.Safe.count(N.Main.relay.pending),7)
    local attempts=0; local send=N.Wire.send
    N.Wire.send=function(...) attempts=attempts+1; return send(...) end
    H.advance(11); eq(#N.Main.relay.spyTimes,6,"cap includes attempts refused by the own reserve")
    eq(attempts,3,"only sends that leave the two-token reserve reach Wire")
    eq(#outgoing(),3); eq(next(N.Main.relay.pending),nil); H.advance(60); eq(attempts,3)
end)

test("Spy relay cap: same full enemy name once per 60 seconds across origins, routes and family",function()
    local N=fixture(); GetRealmName=function() return "7102" end
    UnitName=function(u) if u=="player" then return "Me","7102" end end
    incoming("[Spy]",line()); H.advance(1); eq(#outgoing(),1)
    local first=outgoing()[1].at
    incoming("ForeverSpy1","1\tcedar vale\tAshenvale","RAID","Elm Scout"); H.advance(3); eq(#outgoing(),1)
    H.advance(first+59-H.clock()); incoming("FSENT03","1~Player-7103-00AB13~Cedar-Vale-7102~MAGE~40~Ashenvale~0","PARTY","Fir Scout")
    H.advance(1); eq(#outgoing(),1,"refused at offer, never queued to the boundary")
    incoming("[Spy]",line()); H.advance(1); eq(#outgoing(),2,"same observer can refresh after 60 s")
    incoming("[Spy]",line("Cedar-Vale-7103"),"RAID","Ash Scout"); H.advance(3)
    eq(#outgoing(),3,"different foreign realm is another name")
end)

test("Spy relay receiver: newer same-id sighting refreshes Known, older copy cannot regress it",function()
    local N=fixture(); incoming("LEGW1",wire(),"GUILD","Guild Courier")
    local first=H.clock(); H.advance(60); incoming("LEGW1",wire(),"GUILD","Guild Courier")
    N.Main.track("Cedar Vale"); eq(N.Main.findRows()[1].at,H.clock(),"named refresh reaches Find")
    local newest=N.Main.findRows()[1].at
    incoming("LEGW1",wire(nil,60),"GUILD","Other Courier"); eq(N.Main.findRows()[1].at,newest)
    eq(rows(N)[1].record.at,newest,"older carrier cannot rewind the Reported row either")
    yes(newest>first); eq(N.Safe.count(N.Main.store.reports),1)
end)

test("Spy relay A13: share guild, instance, unknown context, whisper and full pending refuse",function()
    local N=fixture()
    local cases={{record(N,nil,{share="guild"}),ctx,"guild share"},
        {record(N),{inGuild=true,inInstance=true,guild="Test Guild"},"not here"},
        {record(N),{inGuild=true,guild="Test Guild"},"not here"},
        {record(N),{inGuild=false,inInstance=false,guild="Test Guild"},"not here"},
        {record(N,nil,{route="WHISPER"}),ctx,"route"}}
    for _,c in ipairs(cases) do local ok,why=N.Relay.offer(N.Main.relay,c[1],H.clock(),c[2]); no(ok); eq(why,c[3]) end
    for i=1,128 do N.Main.relay.pending["held"..i]={due=H.clock()+100,guild="Test Guild"} end
    local ok,why=N.Relay.offer(N.Main.relay,record(N),H.clock(),ctx); no(ok); eq(why,"busy")
    N.Relay.clear(N.Main.relay); H.instance(true); incoming("[Spy]",line()); H.advance(3); eq(#outgoing(),0)
end)

test("Spy relay A13: instance or guild change during the wait drops, not retries",function()
    for _,mode in ipairs({"instance","guild"}) do
        local N=fixture(); N.Relay.rand=function() return 2 end
        incoming("[Spy]",line()); eq(N.Safe.count(N.Main.relay.pending),1)
        if mode=="instance" then H.instance(true) else GetGuildInfo=function() return "Another Guild" end end
        H.advance(3); eq(#outgoing(),0); eq(next(N.Main.relay.pending),nil)
        H.instance(false); H.advance(60); eq(#outgoing(),0)
    end
end)

test("Spy relay forward priority: full Wire bucket drops it without queueing ahead of own lines",function()
    local N=fixture()
    for i=1,5 do yes(N.Wire.send("LEGW1",wire("Enemy "..H.abc(i)),"GUILD",nil,{prio="own"})) end
    local captured; local send=N.Wire.send
    N.Wire.send=function(prefix,text,kind,target,opts) captured=opts; return send(prefix,text,kind,target,opts) end
    incoming("[Spy]",line()); H.advance(.6)
    eq(#outgoing(),5); yes(captured); eq(captured.prio,"forward"); no(captured.queue)
    eq(next(N.Main.relay.pending),nil); H.advance(30); eq(#outgoing(),5)
    local own=N.Relay.ownLine({rid=1,zone=100,count=1,enemies={{name="Elm Vale"}}})
    yes(N.Wire.send("LEGW1",own,"GUILD",nil,{prio="own"})); H.advance(10); eq(#H.sent(),6)
end)

test("Spy relay 8: stand-down also matches normalized Forever Spy and Sentinel sources",function()
    for _,case in ipairs({{"ForeverSpy1","1\tCedar Vale\tAshenvale"},
        {"FSENT03","1~Player-7103-00AB13~Cedar-Vale~MAGE~40~Ashenvale~0"}}) do
        local N=fixture(); N.Relay.rand=function() return 2 end
        incoming(case[1],case[2]); local _,p=next(N.Main.relay.pending); yes(p)
        incoming("LEGW1",assert(N.Relay.encode(p.record,H.clock())),"GUILD","Guild Courier")
        eq(next(N.Main.relay.pending),nil); H.advance(3); eq(#outgoing(),0)
        eq(#N.Main.relay.spyTimes,0,"stand-down spends no allowance")
    end
end)

test("Spy relay zone: another-zone sighting still goes to the guild and Find",function()
    local N=fixture(); incoming("[Spy]",(line():gsub("|100$","|200"))); H.advance(1)
    eq(#outgoing(),1); local text=outgoing()[1].text; eq(#rows(N),0,"local zone filter is independent")
    local receiver=fixture(); incoming("LEGW1",text,"GUILD","Guild Courier")
    receiver.Main.track("Cedar Vale"); local r=receiver.Main.findRows()[1]
    eq(r.zone,200); yes(r.travel); no(r.canAsk); eq(r.reported.source,"relayed")
end)

test("Spy relay cap: pending names coalesce at dispatch and bounded limits survive clears and clock rollback",function()
    local N=fixture()
    incoming("[Spy]",line(),"PARTY","Birch Scout")
    incoming("ForeverSpy1","1\tCedar Vale\tAshenvale","RAID","Elm Scout")
    eq(N.Safe.count(N.Main.relay.pending),2); H.advance(1); eq(#outgoing(),1)
    eq(next(N.Main.relay.pending),nil); eq(N.Safe.count(N.Main.relay.spyNames),1)
    N.Relay.clear(N.Main.relay)
    local ok,why=N.Relay.offer(N.Main.relay,record(N,nil,{origin="Fir Scout"}),H.clock()-2,ctx)
    no(ok); eq(why,"spy name","rollback does not reopen name limit")
    for i=1,12 do
        H.advance(61); incoming("[Spy]",line("Enemy-"..H.abc(i)),"PARTY","Scout "..H.abc(i)); H.advance(1)
        yes(#N.Main.relay.spyTimes<=6); yes(N.Safe.count(N.Main.relay.spyNames)<=6)
    end
    eq(#outgoing(),13); eq(N.Safe.count(N.Main.relay.spyNames),1,"expired names removed")
end)

test("Spy relay invalid: malformed family lines and self sightings never offered",function()
    local bad={{"[Spy]","broken"},{"[Spy]",line():gsub("MAGE","INVALID")},{"[Spy]",line():gsub("0.4","9.4",1)},
        {"[Spy]",line("Me")},{"ForeverSpy1","1\tMe\tAshenvale"},{"FSENT03","1~Player-7103-00AB13~Me~MAGE~40~Ashenvale~0"},
        {"ForeverSpy1","2\tCedar Vale\tAshenvale"},{"ForeverSpy1","1\tCedar Vale\tNowhere"},
        {"FSENT03","1~Creature-0-1~Cedar-Vale~MAGE~40~Ashenvale~0"},{"FSENT03","1~Player-7103-00AB13~Cedar-Vale~MAGE~40~Ashenvale~121"}}
    for _,case in ipairs(bad) do
        local N=fixture(); incoming(case[1],case[2]); eq(next(N.Main.relay.pending),nil); H.advance(3)
        eq(#outgoing(),0); no(N.Main.error)
    end
    -- These formats expose no faction/friendly flag. Race is not faction evidence.
    local N=fixture(); local d=assert(N.Spy.decode("[Spy]",line()))
    eq(d.faction,nil); eq(d.enemy.faction,nil); eq(d.enemy.friendly,nil)
    incoming("[Spy]",line(),"PARTY","Me"); H.advance(3); eq(#outgoing(),0)
end)
