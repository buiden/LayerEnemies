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
            netNotice=true,autoHop=true,weReportId=true}
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

-- Relay cases are appended in the next red/green slice.
H.killFixture={setup=setup,hear=hear,death=death,decode=decode,row=row}
