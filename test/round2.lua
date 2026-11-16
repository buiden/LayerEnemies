-- Round-2 review regressions: independent first-hand memory and current-layer priority.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local name="Cedar Vale"
local function own(N,at)
    N.Find.own(N.Main.find,{name=name,source="own target",faction="opposite",layer="7086-7"},100,at,H.clock())
end
local function guild(N,zone,age,rid)
    local line=N.Relay.ownLine({rid=rid or 7,zone=zone or 100,age=age or 0,layer="7085",count=1,enemies={{name=name}}})
    yes(line); H.deliver("CHAT_MSG_ADDON","LEGW1",line,"GUILD","DirectScout")
end
local function claim(N,source)
    if source=="relayed" then
        local rec=assert(N.Record.new({src="hh",kind="fight",origin="RelayScout",via="RelayScout",route="PARTY",rid="8",zone=200,
            enemies={{name=name}},layer={ns="unknown"},heard=H.clock(),age=0,share="public"}))
        H.deliver("CHAT_MSG_ADDON","LEGW1",assert(N.Relay.encode(rec,H.clock())),"GUILD","Guildie")
    else
        H.deliver("CHAT_MSG_ADDON","GBOUNTY","D|Cedar-Vale|200|42.0|57.0|Road|47|1|ROGUE|Guild","GUILD","Witness")
    end
end
local function direct(N,ownAt,ownPrimary)
    local r=N.Main.findRows()[1]
    eq(r.source,ownPrimary and "own" or "guild"); eq(r.spotter,ownPrimary and "you" or "DirectScout")
    eq(r.canAsk,not ownPrimary); eq(not not r.same,ownPrimary)
    local text=N.Main.findText(r)
    yes(text:find("Seen by DirectScout",1,true),"guild first-hand line must remain visible")
    if ownAt then yes(text:find("Seen by you",1,true),"own history must remain visible too") end
    local found
    for _,e in pairs(N.Known.get(N.Main.find.known,name,H.clock())) do
        if type(e)=="table" then
            if e.source=="guild" then found=e; eq(e.at,1500); eq(e.kind,"seen"); eq(e.layer,"7085") end
            if e.source=="own" then eq(e.at,ownAt) end
        end
    end
    yes(found,"the retained guild detail keeps its origin time and first-hand kind")
    N.UI.toggle(); N.UI.select("find"); local ui=N.UI.pool[1]
    yes(ui:IsShown()); eq(ui.ask:IsShown(),not ownPrimary)
    if not ownPrimary then eq(ui.spotter,"DirectScout") end
    yes(ui.sub:GetText():find("Seen by DirectScout",1,true))
    if ownAt then yes(ui.sub:GetText():find("Seen by you",1,true)) end
    yes(ui.sub:GetText():find("Reported:",1,true),"the weaker claim remains a separately labelled detail")
    yes(N.Main.findText(r):find("Reported:",1,true))
    if ownAt then yes(ui.sub.height>=160,"space for own, guild and claim details") end
    yes(N.UI.body.height>=70+ui.height,"all retained lines fit above the footer")
    N.UI.toggle(); eq(#H.sent(),0); no(N.Main.error)
end

for _,source in ipairs({"relayed","death"}) do
    test("Round2 "..source..": guild O survives a newer claim beside own history",function()
        for _,trackAfter in ipairs({false,true}) do
            for _,ownFirst in ipairs({true,false}) do
                for _,ownAt in ipairs({1000,1400}) do
                    local N=H.load(); H.clock(ownAt); N.Main.applyLayer("7086-7","fixture")
                    if not trackAfter then yes(N.Main.track(name)) end
                    if ownFirst then own(N,ownAt) end
                    H.clock(1500); guild(N)
                    if not ownFirst then own(N,ownAt) end
                    H.clock(1601); claim(N,source)
                    if trackAfter then yes(N.Main.track(name)) end
                    direct(N,ownAt,ownAt==1400)
                end
            end
        end
    end)
end

test("Round2 claims: guild O survives relay and death without an own entry",function()
    for _,source in ipairs({"relayed","death"}) do
        for _,trackAfter in ipairs({false,true}) do
            local N=H.load(); H.clock(1500)
            if not trackAfter then yes(N.Main.track(name)) end
            guild(N); H.clock(1601); claim(N,source)
            if trackAfter then yes(N.Main.track(name)) end
            direct(N,nil,false)
            local r=N.Main.findRows()[1]; eq(r.reported.source,source); no(r.reported.canAsk)
        end
    end
end)

test("Round2 retention: own guild and claim expire independently without refreshing O",function()
    local N=H.load(); H.clock(1000); yes(N.Main.track(name)); own(N,1000)
    H.clock(1500); guild(N); H.clock(1601); claim(N,"relayed")
    -- An older O cannot erase the retained newer first-hand origin time.
    guild(N,100,200,9); direct(N,1000,false)
    H.clock(4599); local text=N.Main.findText(N.Main.findRows()[1])
    yes(text:find("Seen by you",1,true)); yes(text:find("Seen by DirectScout",1,true))
    H.clock(4600); local r=N.Main.findRows()[1]; text=N.Main.findText(r)
    no(text:find("Seen by you",1,true)); yes(text:find("Seen by DirectScout",1,true)); yes(text:find("Reported:",1,true))
    no(r.canAsk); H.clock(5100); r=N.Main.findRows()[1]
    no(N.Main.findText(r):find("DirectScout",1,true)); eq(r.reported.source,"relayed")
    H.clock(5201); eq(N.Main.findRows()[1].at,nil); eq(next(N.Main.find.known.entries),nil)
    eq(next(N.Main.find.known.byName),nil); eq(#H.sent(),0); no(N.Main.error)
end)

local function guildPrimary(N)
    local r=N.Main.findRows()[1]
    eq(r.source,"guild","previous-layer own evidence must not suppress current guild evidence")
    eq(r.spotter,"DirectScout"); yes(r.canAsk); no(r.same)
    local text=N.Main.findText(r)
    yes(text:find("Seen by you",1,true)); yes(text:find("Seen by DirectScout",1,true))
    no(text:find("is on YOUR layer",1,true))
    N.UI.toggle(); N.UI.select("find"); local ui=N.UI.pool[1]
    yes(ui.ask:IsShown()); eq(ui.spotter,"DirectScout")
    yes(ui.sub:GetText():find("Seen by you",1,true)); yes(ui.sub:GetText():find("Seen by DirectScout",1,true))
    eq(#H.sent(),0); no(N.Main.error)
end

test("Round2 own: layer change releases priority to guild O",function()
    for _,trackAfter in ipairs({false,true}) do
        for _,guildFirst in ipairs({false,true}) do
            local N=H.load(); H.clock(1000); N.Main.applyLayer("7086-7","fixture")
            if not trackAfter then yes(N.Main.track(name)) end
            own(N,1000); H.clock(1001)
            if guildFirst then guild(N) end
            N.Main.applyLayer("7087-8","fixture")
            if not guildFirst then guild(N) end
            if trackAfter then yes(N.Main.track(name)) end
            guildPrimary(N)
        end
    end
end)

test("Round2 own: unknown layer never takes priority over guild O",function()
    local N=H.load(); H.clock(1000); yes(N.Main.track(name))
    N.Find.own(N.Main.find,{name=name,source="own target",faction="opposite"},100,H.clock())
    N.Main.applyLayer("7086-7","fixture"); H.clock(1001); guild(N)
    guildPrimary(N)
end)

test("Round2 own: current-layer 599-second sighting stays primary beside another zone",function()
    local N=H.load(); H.clock(1000); yes(N.Main.track(name)); N.Main.applyLayer("7086-7","fixture"); own(N,1000)
    H.clock(1599); guild(N,200)
    local r=N.Main.findRows()[1]; yes(r.own); yes(r.same); no(r.canAsk); eq(r.age,599)
    local text=N.Main.findText(r)
    yes(text:find("is on YOUR layer",1,true)); yes(text:find("Seen by DirectScout in Durotar, 0 s ago",1,true))
    yes(text:find("travel to Durotar first",1,true)); eq(#H.sent(),0); no(N.Main.error)
end)

test("Round2 bounds: own storage participates in eviction and rollback indexing",function()
    local N=H.load(); local K=N.Known; local st=K.new()
    for i=1,300 do K.put(st,{name="Enemy "..i,zone=100,at=1000+i,source="spy",kind="seen"},1300) end
    K.put(st,{name="Enemy 1",ownName="Alias",zone=100,at=1301,source="own",kind="seen"},1301)
    K.put(st,{name="Newest",zone=100,at=1302,source="guild",kind="seen"},1302)
    eq(N.Safe.count(st.entries),300); yes(K.get(st,"Enemy 1",1302)); eq(K.get(st,"Enemy 2",1302),nil)
    yes(st.byName.alias); K.prune(st,1300); eq(st.byName.alias,nil)
    yes(K.get(st,"Enemy 1",1300)); eq(K.get(st,"Newest",1300),nil)
    K.prune(st,0); eq(next(st.entries),nil); eq(next(st.byName),nil)
end)

test("Round2 UI: own guild claim current hash and OpenMap all fit",function()
    local N=H.load(); H.clock(1000); yes(N.Main.track(name)); own(N,1000)
    H.clock(1500); guild(N); H.clock(1601); claim(N,"relayed")
    H.clock(2201)
    N.Find.report(N.Main.find,{sender="HashScout",zone=100,at=H.clock(),enemies={{hash=N.Hash.player("Cedar","Vale")}}},"Test Realm")
    H.deliver("CHAT_MSG_ADDON","OpenMapLoc","L1\t100\t0.4200\t0.5700\tMAGE\t60","GUILD",name)
    local r=N.Main.findRows()[1]; yes(r.canAsk); eq(r.spotter,"HashScout"); yes(r.place)
    N.UI.toggle(); N.UI.select("find"); local ui=N.UI.pool[1]
    yes(ui and ui:IsShown()); yes(ui.ask:IsShown()); eq(ui.spotter,"HashScout"); yes(ui.place:IsShown())
    for _,text in ipairs({"HashScout","Seen by DirectScout","Seen by you","Reported:"}) do
        yes(ui.sub:GetText():find(text,1,true),"every independent detail remains visible: "..text)
    end
    yes(ui.sub.height>=204,"four independent detail lines"); yes(N.UI.body.height>=70+ui.height)
    N.UI.select("local"); eq(N.UI.body.height,300); eq(N.UI.frame.height,514)
    eq(#H.sent(),0); no(N.Main.error)
end)
