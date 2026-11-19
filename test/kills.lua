-- HeadHunter D grammar fixtures are independently authored; no donor code is loaded.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function b36(n)
    local digits,out="0123456789abcdefghijklmnopqrstuvwxyz",""
    repeat local r=n%36; out=digits:sub(r+1,r+1)..out; n=math.floor(n/36) until n==0
    return out
end
local function death(opts)
    opts=opts or {}
    local t=GetServerTime()-(opts.age or 0)
    local victim=opts.victim or "Birch Scout"
    local killer=opts.killer or "Cedar Vale"
    local enemy=opts.enemy or (killer..",,14,M,O,2,")
    local body=table.concat({b36(t),victim,"1o","W","H",b36(opts.map or 100),"dw","6y",opts.conf or "e",
        opts.layer or "9ix",enemy},";")..(opts.assists or "")
    return "1AE:"..table.concat({"eu-pvp",opts.author or victim,opts.side or "A","5cy","1",b36(t),"D"..body},";")
end
local function setup(stand)
    local N=H.load(); N.Net.SHIP.hh=true; H.loaded().HeadHunter=stand or nil
    eq(N.Net.allowed("hh"),not stand); N.Relay.rand=function() return 1 end
    return N
end
local function hear(opts,sender,route)
    H.deliver("CHAT_MSG_ADDON","HeadHunter",death(opts),route or "WHISPER",sender or "Birch Scout")
end
local function row(N) return N.Main.findRows()[1] end
local function decode(N,opts,sender,route)
    return N.HeadHunter.decode(death(opts),sender or "Birch Scout",GetServerTime(),"Alliance",
        {heard=H.clock(),route=route or "WHISPER",zoneFn=N.Adapters.zone})
end
local function noEvidence(N)
    eq(next(N.Main.find.known.entries),nil); eq(#N.Store.rows(N.Main.store,H.clock(),"reported"),0)
    eq(next(N.Main.relay.pending),nil); no(N.Main.error)
end

for _,stand in ipairs({false,true}) do
    test("Kills 11: D creates a timed killer claim in "..(stand and "stand-down" or "LE-only"),function()
        local N=setup(stand); local received=H.clock(); hear({age=23,map=200})
        eq(#N.Main.findRows(),0,"tracked names only, no kill list")
        N.Main.track("Cedar Vale"); local r=row(N); yes(r.reported,"D must reach Known before tracking")
        eq(r.reported.source,"headhunter"); eq(r.reported.kind,"claim"); eq(r.reported.zone,200)
        eq(r.reported.pos,"victim"); eq(r.reported.x,.5); eq(r.reported.y,.25)
        eq(r.reported.at,received-23); eq(r.reported.age,23); eq(r.reported.class,"MAGE"); eq(r.reported.level,40)
        eq(r.seen,nil); no(r.canAsk); eq(r.reported.layer,nil); eq(r.reported.ns,"unknown")
        eq(r.reported.count,nil); eq(r.reported.kills,nil)
        local text=N.Main.findText(r); yes(text:find("killed Birch Scout",1,true)); yes(text:find("victim-reported",1,true))
        yes(text:find("Durotar",1,true)); yes(text:find("victim position",1,true)); no(text:find("(inferred)",1,true))
        no(text:find("via relay",1,true)); no(text:find("12345",1,true)); no(text:find("layer",1,true)); no(N.Main.error)
        if stand then eq(#N.Main.hhNet.history,0) end
    end)
end

test("Kills 11: incomplete killer never matches by partial name, class or level",function()
    for _,enemy in ipairs({"Cedar,1,14,M,O,2,Player-7103-00AB13","Cedar Vale,1,14,M,O,2,Player-7103-00AB13",
        "guid:Player-7103-00AB13,,14,M,O,2,","Player-7103-00AB13,,14,M,O,2,"}) do
        local N=setup(true); N.Main.track("Cedar"); N.Main.track("Cedar Vale")
        hear({enemy=enemy}); noEvidence(N)
        for _,r in ipairs(N.Main.findRows()) do eq(r.at,nil) end
    end
end)

test("Kills 11: author must be the victim under whole-name identity",function()
    for _,author in ipairs({"Other Scout","Birch Scout-Elsewhere"}) do
        local N=setup(true); hear({author=author}); noEvidence(N)
    end
    local N=setup(true); hear({author="BIRCH SCOUT-TestRealm"}); N.Main.track("Cedar Vale"); yes(row(N).reported)
end)

test("Kills 12: inferred label, victim attribution and relay provenance without Reported rows",function()
    local N=setup(true); N.Main.track("Cedar Vale"); hear({conf="i"},"Distant Scout")
    local r=row(N); yes(r.reported); eq(r.kind,"claim"); no(r.canAsk)
    local text=N.Main.findText(r); yes(text:find("(inferred)",1,true)); yes(text:find("victim-reported",1,true))
    yes(text:find("via relay",1,true)); yes(text:find("killed Birch Scout",1,true))
    eq(#N.Store.rows(N.Main.store,H.clock(),"reported"),0); eq(next(N.Main.store.reports),nil)
    eq(#N.Store.reporters(N.Main.store,H.clock()),0)
    N.UI.toggle(); N.UI.select("find"); local ui=N.UI.pool[1]
    yes(ui.sub:GetText():find("killed Birch Scout",1,true)); no(ui.ask:IsShown()); eq(ui.hopRecord,false)
    no(N.AskInvite("Birch Scout")); eq(N.Main.call.active,nil); no(N.Main.error)
end)

test("Kills 12: simulated and unknown confidence create no finding",function()
    for _,conf in ipairs({"s","?"}) do local N=setup(true); hear({conf=conf}); noEvidence(N) end
end)

test("Kills 12: assists and helpers never create entries or counts",function()
    local N=setup(true)
    hear({assists=";Willow Moss,,14,M,O,2,;Pine Grove,,14,M,O,2,;h4"})
    eq(N.Safe.count(N.Main.find.known.entries),1)
    local e=N.Known.get(N.Main.find.known,"Cedar Vale",H.clock()); yes(e); eq(e.reported.count,nil)
    eq(N.Known.get(N.Main.find.known,"Willow Moss",H.clock()),nil)
    N.Main.track("Willow Moss"); eq(row(N).at,nil); eq(#N.Store.rows(N.Main.store,H.clock(),"reported"),0)
end)

test("Kills age: catch-up retains real age, hour boundary expires without fresh alerts",function()
    for _,age in ipairs({1200,3599,3600,3601}) do
        local N=setup(true); hear({age=age},"Distant Scout")
        local sounds=0; PlaySound=function() sounds=sounds+1 end
        N.Main.track("Cedar Vale"); local r=row(N)
        if age<3600 then
            yes(r.reported); eq(r.age,age); yes(r.lastKnown); no(r.canAsk)
            yes(N.Main.findText(r):find(math.floor(age/60).." min ago",1,true))
            if age==3599 then H.advance(1); eq(row(N).at,nil) end
        else eq(r.at,nil) end
        eq(sounds,0); PlaySound=nil; no(N.Main.error)
    end
end)

test("Kills decode: envelope validation, other faction, malformed names and future skew",function()
    local N=setup(true)
    for _,opts in ipairs({{side="H"},{age=-301},{map=9999},{enemy="Cedar Vale,,xyz,M,O,2,"},
        {enemy="Cedar Vale,1,14,M,O,2,"},{enemy="Cedar Vale,,14,M,O,2"},{enemy="Bad|Name,,14,M,O,2,"}}) do
        eq(#decode(N,opts),0)
    end
    local r=decode(N,{age=-300})[1]; yes(r); eq(r.at,H.clock()); eq(r.layer.value,nil); eq(r.count,nil)
    local frame=death(); eq(#N.HeadHunter.decode(frame:gsub(";5cy;1;",";5cy;0;"),"Birch Scout",GetServerTime(),"Alliance",
        {heard=H.clock(),route="WHISPER",zoneFn=N.Adapters.zone}),0)
end)

test("Kills Find: claims cannot borrow the victim layer or replace first-hand evidence",function()
    local N=setup(true); N.Main.track("Cedar Vale")
    N.Find.report(N.Main.find,{sender="Local Scout",zone=100,at=H.clock(),source="guild",enemies={{name="Cedar Vale"}}})
    H.advance(1); hear({conf="i"})
    local r=N.Find.rows(N.Main.find,H.clock(),100,function() return true end)[1]
    yes(r.seen); yes(r.reported); eq(r.spotter,"Local Scout"); no(r.reported.same); no(r.reported.probably)
    no(r.reported.canAsk); eq(r.reported.layer,nil)
end)

for _,stand in ipairs({false,true}) do
    test("Kills counters: session receive totals in "..(stand and "stand-down" or "LE-only"),function()
        local N=setup(stand); local t=b36(GetServerTime())
        H.deliver("CHAT_MSG_ADDON","HeadHunter","1AP:2s;"..t..";dw;6y;a1","PARTY","Ping Scout")
        H.deliver("CHAT_MSG_ADDON","HeadHunter","1AL:Pine Grove;2s;"..t..";dw;6y","PARTY","Outlaw Scout")
        hear({}); hear({age=1200},"Distant Scout"); hear({conf="s"},"Another Scout")
        H.deliver("CHAT_MSG_ADDON","HeadHunter",death():gsub(";D[^~]+$",";Kignored"),"WHISPER","Count Scout")
        local stats=N.Main.hh.stats; yes(stats,"receive counters must not read mesh history")
        eq(stats.frames.P,1); eq(stats.frames.L,1); eq(stats.frames.E,4)
        eq(stats.records.D,3); eq(stats.records.K,1); eq(stats.kills.read,2); eq(stats.kills.fresh,1); eq(stats.kills.relayed,0)
        SlashCmdList.LAYERENEMIES("net")
        local text=table.concat(H.log(),"\n")
        yes(text:find("HeadHunter session: frames P=1 L=1 E=4",1,true)); yes(text:find("D=3",1,true)); yes(text:find("K=1",1,true))
        yes(text:find("kills read=2 fresh=1 relayed=0",1,true))
        local before=N.HeadHunter.summary(stats); N.Main.boundary(200); eq(N.HeadHunter.summary(stats),before)
        local allowed={options=true,tracked=true,position=true,guildHost=true,consent=true,nets=true,share=true,call=true,callArt=true,
            netNotice=true,autoHop=true,weReportId=true,findShare=true,shareFriends=true,findNotice=true,found=type(LayerEnemiesDB.found)=="boolean",quietWhispers=true,warboardOwed=type(LayerEnemiesDB.warboardOwed)=="table" and #LayerEnemiesDB.warboardOwed<=40}
        for k in pairs(LayerEnemiesDB) do yes(allowed[k],"no new SavedVariables field: "..k) end
        local function walk(v)
            if type(v)~="table" then return end
            no(v==stats or v==stats.frames or v==stats.records or v==stats.kills or v==N.Main.find.known,"session memory never saved")
            for _,child in pairs(v) do walk(child) end
        end
        walk(LayerEnemiesDB); local saved=LayerEnemiesDB; N=H.load(saved)
        eq(N.Main.hh.stats.kills.read,0); eq(next(N.Main.find.known.entries),nil)
    end)
end

local function guildSends()
    local out={}; for _,s in ipairs(H.sent()) do if s.prefix=="LEGW1" then out[#out+1]=s end end
    return out
end
local function context() return {inGuild=true,inInstance=false,guild="Test Guild"} end

for _,stand in ipairs({false,true}) do
    test("Kills 12a: whispered D reaches Find and guild in "..(stand and "stand-down" or "LE-only"),function()
        local N=setup(stand); N.Main.track("Cedar Vale"); hear({age=20},"Distant Scout")
        yes(row(N).reported); eq(N.Safe.count(N.Main.relay.pending),1); eq(#guildSends(),0)
        H.advance(.5); eq(#guildSends(),0); H.advance(.6)
        local sends=guildSends(); eq(#sends,1); eq(sends[1].kind,"GUILD"); eq(sends[1].target,nil)
        yes(sends[1].text:find("R|1|hh|kill|",1,true))
        local r=N.Relay.decode(sends[1].text,"Guild Carrier",H.clock()); yes(r)
        eq(r.origin,"Birch Scout"); eq(r.enemies[1].name,"Cedar Vale"); eq(r.zone,100)
        eq(r.x,.5); eq(r.y,.25); eq(r.pos,"victim"); eq(r.layer.ns,"unknown"); eq(r.layer.value,nil)
        eq(r.count,nil); eq(r.at,H.clock()-21); eq(N.Main.hh.stats.kills.relayed,1)
        SlashCmdList.LAYERENEMIES("net"); yes(table.concat(H.log(),"\n"):find("kills read=1 fresh=1 relayed=1",1,true))
        if stand then
            eq(#N.Main.hhNet.history,0); eq(next(N.Main.hhNet.peers),nil)
            for _,s in ipairs(H.sent()) do no(s.prefix=="HeadHunter","stand-down may only forward via guild route") end
        end
        no(N.Main.error)
    end)
end

test("Kills 12b: fresh whisper relays; old catch-up stays local with origin age",function()
    for _,age in ipairs({298,300,450,1200,3599,3600}) do
        local N=setup(true); hear({age=age},"Distant Scout")
        eq(N.Safe.count(N.Main.relay.pending),age<300 and 1 or 0,"only fresh D is offered")
        H.advance(1.1); eq(#guildSends(),age==298 and 1 or 0)
        N.Main.track("Cedar Vale"); local r=row(N)
        if age<3599 then yes(r.reported); eq(math.floor(r.age),age+1) else eq(r.at,nil) end
        eq(N.Main.hh.stats.kills.relayed,age==298 and 1 or 0)
    end
end)

test("Kills relay: recheck freshness at dispatch and encoding",function()
    local N=setup(true); local r=decode(N,{age=299})[1]; yes(r)
    yes(N.Relay.offer(N.Main.relay,r,H.clock(),context()))
    eq(N.Relay.encode(r,H.clock()+1),nil)
    H.advance(1.1); N.Main.relayTick(); eq(#guildSends(),0); eq(next(N.Main.relay.pending),nil)
    eq(N.Main.hh.stats.kills.relayed,0)
end)

test("Kills relay: non-whisper fresh and catch-up records stay local",function()
    for _,route in ipairs({"PARTY","RAID"}) do
        local N=setup(true); hear({},"Birch Scout",route); N.Main.track("Cedar Vale")
        yes(row(N).reported); eq(next(N.Main.relay.pending),nil); H.advance(3); eq(#guildSends(),0)
        local r=decode(N,{age=1200},"Birch Scout",route)[1]; yes(r)
        no(N.Relay.offer(N.Main.relay,r,H.clock(),context())); no(N.Main.error)
    end
end)

test("Kills relay: frozen main receiver ignores kill and killi as invalid",function()
    local N=setup(true); local frozen={}; for k,v in pairs(N) do frozen[k]=v end
    assert(loadfile("test/fixtures/relay_16549ca.lua"))("LayerEnemies",frozen)
    for _,conf in ipairs({"e","i"}) do
        local r=decode(N,{conf=conf})[1]; yes(r)
        local text=N.Relay.encode(r,H.clock()); yes(text)
        local old,why=frozen.Relay.decode(text,"Guild Carrier",H.clock()); eq(old,nil); eq(why,"invalid")
        local current=N.Relay.decode(text,"Guild Carrier",H.clock()); yes(current)
        eq(current.kind,conf=="e" and "kill" or "killi"); eq(current.count,nil)
    end
end)

test("Kills relay: guild claims never reach Reported, Ask, Hop, or re-forward",function()
    local N=setup(true); local r=decode(N,{conf="i"})[1]; yes(r)
    local text=N.Relay.encode(r,H.clock()); yes(text)
    H.deliver("CHAT_MSG_ADDON","LEGW1",text,"GUILD","Guild Carrier")
    N.Main.track("Cedar Vale"); local found=row(N); yes(found.reported); eq(found.kind,"claim"); no(found.canAsk)
    eq(found.seen,nil); eq(found.reported.source,"relayed"); eq(found.reported.pos,"victim")
    local shown=N.Main.findText(found); yes(shown:find("victim-reported",1,true)); yes(shown:find("via relay",1,true))
    yes(shown:find("(inferred)",1,true)); eq(found.layer,nil); eq(found.reported.count,nil)
    eq(#N.Store.rows(N.Main.store,H.clock(),"reported"),0); eq(next(N.Main.store.reports),nil)
    eq(#N.Store.reporters(N.Main.store,H.clock()),0); eq(next(N.Main.relay.pending),nil)
    N.UI.toggle(); N.UI.select("find"); no(N.UI.pool[1].ask:IsShown()); eq(N.UI.pool[1].hopRecord,false)
    no(N.AskInvite("Birch Scout")); H.advance(3); eq(#guildSends(),0); no(N.Main.error)
end)

test("Kills relay: malformed kill wire cannot smuggle counts, hashes, extra enemies or layer",function()
    local N=setup(true); local text=N.Relay.encode(assert(decode(N)[1]),H.clock()); yes(text)
    local fields={}; for v in (text.."|"):gmatch("([^|]*)|") do fields[#fields+1]=v end
    for _,change in ipairs({{3,"we"},{10,"1"},{11,"s"},{12,"12345"},{14,"AbC::"},
        {14,fields[14]..","..fields[14]},{14,""}}) do
        local copy={}; for i,v in ipairs(fields) do copy[i]=v end; copy[change[1]]=change[2]
        eq(N.Relay.decode(table.concat(copy,"|"),"Guild Carrier",H.clock()),nil)
    end
end)

test("Kills relay: guild copy during wait cancels our send",function()
    local N=setup(true); hear({}); eq(N.Safe.count(N.Main.relay.pending),1)
    local r=decode(N)[1]; local text=N.Relay.encode(r,H.clock()); yes(text)
    H.deliver("CHAT_MSG_ADDON","LEGW1",text,"GUILD","Guild Carrier")
    eq(next(N.Main.relay.pending),nil); H.advance(3); eq(#guildSends(),0); eq(N.Main.hh.stats.kills.relayed,0)
    hear({age=3}); eq(next(N.Main.relay.pending),nil,"repeat same event remains deduped")
end)

test("Kills relay budget: fifth within rolling minute is dropped, not queued",function()
    local N=setup(true)
    for i=1,5 do
        hear({killer="Enemy "..H.abc(i)},"Carrier "..H.abc(i)); H.advance(1.1); H.advance(4)
    end
    eq(#guildSends(),4); eq(N.Main.hh.stats.kills.relayed,4); eq(next(N.Main.relay.pending),nil)
    H.advance(61); eq(#guildSends(),4,"dropped fifth never retries")
    hear({killer="Enemy f"},"Carrier f"); H.advance(1.1); eq(#guildSends(),5)
end)

test("Kills relay budget: same whole killer name once per 60 seconds",function()
    local N=setup(true); hear({}); H.advance(1.1); eq(#guildSends(),1)
    H.advance(4); hear({killer="CEDAR VALE-TestRealm",victim="Pine Scout"},"Pine Scout")
    H.advance(1.1); eq(#guildSends(),1,"case and own realm do not evade cooldown")
    H.advance(53); hear({victim="Oak Scout"},"Oak Scout"); H.advance(1.1)
    eq(#guildSends(),1,"no repeat below 60 seconds")
    H.advance(1); hear({victim="Willow Scout"},"Willow Scout"); H.advance(1.1); eq(#guildSends(),2)
end)

test("Kills relay budget: realms stay distinct and backwards time never reopens allowance",function()
    local N=setup(true)
    for _,realm in ipairs({"Alpha","Beta"}) do hear({killer="Cedar Vale-"..realm}); H.advance(3) end
    eq(#guildSends(),2)
    H.advance(-4); hear({killer="Cedar Vale-Alpha",victim="Pine Scout"},"Pine Scout")
    H.advance(1.1); eq(#guildSends(),2)
end)

test("Kills relay priority: full Wire bucket drops without queue or successful counter",function()
    local N=setup(true); local optsSeen
    local send=N.Wire.send
    N.Wire.send=function(prefix,text,kind,target,opts)
        if prefix=="LEGW1" then optsSeen=opts; return false,"budget" end
        return send(prefix,text,kind,target,opts)
    end
    hear({}); H.advance(1.1); yes(optsSeen); eq(optsSeen.prio,"forward"); no(optsSeen.queue)
    eq(next(N.Main.relay.pending),nil); eq(N.Main.hh.stats.kills.relayed,0); eq(#guildSends(),0)
    N.Wire.send=send; H.advance(61); eq(#guildSends(),0)
end)

test("Kills relay lifecycle: no guild, instance and guild switch invalidate pending",function()
    for _,ctx in ipairs({{inGuild=false,inInstance=false,guild="Test Guild"},
        {inGuild=true,inInstance=true,guild="Test Guild"},{inGuild=true,inInstance=false,guild="Other Guild"}}) do
        local N=setup(true); local r=decode(N)[1]; yes(r); local st=N.Relay.new()
        yes(N.Relay.offer(st,r,H.clock(),context()))
        N.Relay.tick(st,H.clock()+3,ctx); eq(next(st.pending),nil); eq(#guildSends(),0)
    end
end)
