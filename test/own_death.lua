-- Synthetic recap fixtures: field shapes are a native-client unknown, not a capture.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local GUID="Player-1-123"
local function recapRow()
    return {sourceGUID=GUID,sourceName="Cedar",sourceFlags=0x448,overkill=10,timestamp=H.clock()}
end
local function setup(saved)
    local N=H.load(saved); H.establish(N)
    H.advance(.1); H.unit("target",H.player("Cedar Vale","Horde",GUID))
    H.deliver("PLAYER_TARGET_CHANGED"); H.drain()
    local rows={recapRow()}
    C_DeathRecap={HasRecapEvents=function() return true end,GetRecapEvents=function() return rows end}
    return N,rows
end
local function deaths()
    local out={}
    for _,s in ipairs(H.sent()) do if s.prefix=="LEGW1" and s.text:sub(1,2)=="K|" then out[#out+1]=s end end
    return out
end
local function die() H.deliver("PLAYER_DEAD"); H.advance(.3) end

test("K: hostile opposite-player recap sends one exact guild line after PLAYER_DEAD",function()
    local N=setup(); H.establish(N)
    -- Snapshot at death, not the position after the recap delay.
    H.deliver("PLAYER_DEAD"); eq(#deaths(),0)
    H.map(200); C_Map.GetPlayerMapPosition=function() return {GetXY=function() return .1,.2 end} end
    H.advance(.3)
    eq(#deaths(),1,"one own-death line")
    local s=deaths()[1]
    eq(s.text,"K|1|100|0.250|0.750|7086|0|e|43656461722056616c65:MAGE:60:f")
    eq(s.kind,"GUILD"); eq(s.target,nil)
    H.advance(3); eq(#deaths(),1); no(N.Main.error)
end)

local LINE="K|1|100|0.250|0.750|7086|0|e|43656461722056616c65:MAGE:60:f"
local function send(N,line,opts,prefix,kind)
    return N.Wire.send(prefix or "LEGW1",line or LINE,kind or "GUILD","Birch Moss",opts or {prio="own"})
end
local BAD={"K|2|100|0.250|0.750|7086|0|e|", "K|1|0||||0|e|", "K|1|100||||121|e|",
    "K|1|100|1.001|0.750||0|e|", "K|1|100|0.25|0.750||0|e|", "K|1|100|0.250|||0|e|",
    "K|1|100||||0|x|", "K|1|100||||0|e|4:MAGE:60:f", "K|1|100||||0|e|4365646172:BOGUS:60:f",
    "K|1|100||||0|e|4365646172:MAGE:0:f", "K|1|100||||0|e|4365646172:MAGE:101:f",
    "K|1|100||||0|e|4365646172:MAGE:60:q", LINE.."|tail",LINE..",extra","K|1","K|"}
test("K: whole grammar refuses malformed lines at Wire, not just a K prefix",function()
    for _,line in ipairs(BAD) do local N=H.load(); no(send(N,line),line); eq(#H.sent(),0) end
end)
test("K: Wire rate is 120 seconds inclusive, rolls back closed and stamps refused API calls",function()
    local N=H.load(); yes(send(N)); H.advance(119.99); no(send(N)); H.advance(.01); yes(send(N)); eq(#deaths(),2)
    H.advance(-121); no(send(N)); eq(#deaths(),2)
    N=H.load(); H.result(3); no(send(N)); H.advance(31); H.result(0); no(send(N)); eq(#deaths(),1)
end)
test("K: sixth line within 30 minutes refused and oldest expires at 1800",function()
    local N=H.load()
    for i=1,5 do yes(send(N)); H.advance(120) end
    no(send(N)); eq(#deaths(),5)
    H.advance(1199.99); no(send(N)); H.advance(.01); yes(send(N)); eq(#deaths(),6)
end)
test("K: Wire cannot bypass share or instance with click priority or queue it",function()
    local N=H.load({share=false}); no(send(N)); eq(#deaths(),0)
    N=H.load(); H.instance(true); no(send(N,nil,{prio="click",queue=true})); eq(#deaths(),0)
    N=H.load()
    for i=1,5 do yes(N.Wire.send("LEGW1","budget","GUILD")) end
    no(send(N,nil,{prio="own",queue=true})); eq(N.Wire.queued(),0)
    H.advance(10); eq(#deaths(),0)
end)
test("K: only LEGW1 GUILD accepts the death payload and old stand-downs stay closed",function()
    for _,prefix in ipairs({"LEGW1","WEFF1","HeadHunter","LFSw","LayerSwap","GBOUNTY","WALLOFSHAME","FTold1"}) do
        for _,kind in ipairs({"GUILD","PARTY","RAID","WHISPER","CHANNEL","INSTANCE_CHAT"}) do
            local N=H.load(); N.Net.SHIP.we=true; N.Net.SHIP.hh=true
            local ok=send(N,nil,{prio="own",net=prefix=="WEFF1" and "we" or "hh"},prefix,kind)
            eq(not not ok,prefix=="LEGW1" and kind=="GUILD",prefix.."/"..kind)
        end
    end
    local N=H.load(); N.Net.SHIP.we=true; N.Net.SHIP.hh=true
    H.loaded("WarEffortScout",true); H.loaded("HeadHunter",true)
    local ok,why=N.Wire.send("WEFF1","Q","GUILD",nil,{net="we"}); no(ok); eq(why,"stand down")
    ok,why=N.Wire.send("HeadHunter","1AN:1","WHISPER","Birch Moss",{net="hh"}); no(ok); eq(why,"stand down")
    -- K is our own guild protocol, not a donor network. Guild-only is sufficient consent.
    N.Main.setConsent("guild"); yes(send(N)); eq(#deaths(),1)
end)

local function popup(N) return N.CallUI.frame and N.CallUI.frame:IsShown() end
local function incoming(N,line,sender,kind)
    H.deliver("CHAT_MSG_ADDON","LEGW1",line or LINE,kind or "GUILD",sender or "Birch Moss")
end
local function receiver(saved)
    local N=H.load(saved); H.roster({{"Birch Moss",true},{"Cedar Vale",true}})
    H.deliver("GUILD_ROSTER_UPDATE"); return N
end
test("K: grammar round trip retains full partial or empty killer and age boundary",function()
    local N=H.load(); local D=N.OwnDeath; yes(D)
    for _,line in ipairs({LINE,"K|1|200|0.000|1.000||120|h|4365646172::-1:p","K|1|100||||0|h|"}) do
        local r=D.decode(line); yes(r,line); eq(D.line(r),line)
    end
    for _,line in ipairs(BAD) do no(D.decode(line),line) end
end)
test("K: guild death enters Call only, never reports relay Find locations or ask candidates",function()
    local N=receiver(); N.Main.track("Cedar Vale")
    incoming(N); yes(popup(N)); local e=N.CallUI.event
    eq(e.victim,"Birch Moss"); eq(e.killer,"Cedar Vale"); eq(e.zone,100); eq(e.x,.25); eq(e.full,true)
    eq(N.Main.find.locations["Cedar Vale"],nil); eq(#N.Main.candidates(),0); eq(next(N.Main.relay.pending),nil)
    eq(next(N.Main.store.reports),nil); eq(#H.sent(),0); no(N.Main.error)
    N.CallUI.help:Click(); eq(#N.Main.find.names,1); eq(#H.sent(),0)
end)
test("K: partial or empty killer still displays but Help never adds it to Find",function()
    for _,item in ipairs({"4365646172:MAGE:60:p",""}) do
        local N=receiver(); incoming(N,"K|1|100||||0|h|"..item); yes(popup(N))
        eq(N.CallUI.event.full,false); N.CallUI.help:Click(); eq(#N.Main.find.names,0); eq(#H.sent(),0)
    end
end)
test("K: unknown version drops silently, non-guild sender and killer equals sender refused",function()
    local N=receiver(); N.Main.lastDrop="sentinel"; incoming(N,(LINE:gsub("^K|1|","K|2|")))
    no(popup(N)); eq(N.Main.lastDrop,"sentinel"); no(N.Main.error)
    incoming(N,nil,"Stranger Pine"); no(popup(N))
    incoming(N,nil,"Cedar Vale"); no(popup(N))
    incoming(N,nil,"CEDAR VALE-TestRealm"); no(popup(N))
    for _,kind in ipairs({"WHISPER","PARTY","RAID","CHANNEL"}) do incoming(N,nil,nil,kind); no(popup(N)) end
    incoming(N); yes(popup(N)); eq(#H.sent(),0)
end)
test("K: own split combined home names refused and unknown own identity fails closed",function()
    for _,combined in ipairs({false,true}) do
        local N=receiver(); UnitName=function() return combined and "Birch Moss" or "Birch","Moss" end
        for _,who in ipairs({"Birch Moss","Birch Moss-TestRealm","BIRCH MOSS"}) do incoming(N,nil,who); no(popup(N)) end
        UnitName=function() return "Fir",H.secret end; incoming(N,nil,"Cedar Vale"); no(popup(N))
        no(N.Main.error); eq(#H.sent(),0)
    end
end)
test("K: call off drops all state, share off still receives, existing Call cooldowns apply",function()
    local N=receiver({call=false}); incoming(N); no(popup(N)); eq(next(N.Main.call.victims),nil)
    N=receiver({share=false}); incoming(N); yes(popup(N)); N.CallUI.dismiss:Click()
    H.advance(179); incoming(N); no(popup(N)); H.advance(1); incoming(N); yes(popup(N))
    eq(#H.sent(),0)
end)

test("K: mob fall drowning pet friendly and same-faction duel never send",function()
    for _,mode in ipairs({"mob","fall","drown","pet","friendly","duel","unknown","targetOnly"}) do
        local N,rows=setup(); local r=rows[1]
        if mode=="mob" then r.sourceGUID="Creature-0-1-0-1-2-AB"; r.sourceFlags=0x848
        elseif mode=="fall" or mode=="drown" then r.sourceGUID=nil; r.sourceName=mode; r.sourceFlags=0
        elseif mode=="pet" then r.sourceGUID="Pet-0-1-AB"; r.sourceFlags=0x1048
        elseif mode=="friendly" then r.sourceFlags=0x418
        elseif mode=="duel" then N.Main.store.localSeen[GUID].faction="same"
        elseif mode=="unknown" then N.Main.store.localSeen[GUID].faction="unknown"
        else N.Main.store.localSeen={} end
        die(); H.advance(2); eq(#deaths(),0,mode); no(N.Main.error)
    end
end)
test("K: race fallback proves faction but not a full name, neutral unknown and same races refuse",function()
    for _,race in ipairs({"Orc","Scourge","Tauren","Troll","Human","Gnome","NightElf","Dwarf","Pandaren","Unknown"}) do
        local N=setup(); N.Main.store.localSeen={}
        GetPlayerInfoByGUID=function(g) eq(g,GUID); return "Mage","MAGE",race,race,2,"Cedar","Test Realm" end
        die(); local expected=race=="Orc" or race=="Scourge" or race=="Tauren" or race=="Troll"
        eq(#deaths(),expected and 1 or 0,race)
        if expected then yes(deaths()[1].text:find("|4365646172:MAGE::p$")); no(N.Main.error) end
    end
end)
test("K: seen name proof stays partial without a matching GUID; stale or foreign identity is no proof",function()
    for _,mode in ipairs({"fullName","bare","foreign","stale","epoch"}) do
        local N,rows=setup(); rows[1].sourceGUID="Player-1-999"; rows[1].sourceName="Cedar Vale"
        if mode=="bare" then rows[1].sourceName="Cedar"
        elseif mode=="foreign" then rows[1].sourceName="Cedar Vale-OtherRealm"
        elseif mode=="stale" then N.Main.store.localSeen[GUID].at=H.clock()-600
        elseif mode=="epoch" then N.Main.store.localSeen[GUID].epoch=-1 end
        die(); eq(#deaths(),mode=="fullName" and 1 or 0,mode)
        if mode=="fullName" then yes(deaths()[1].text:find(":p$")) end
    end
end)
test("K: absent empty secret or erroring recap APIs never send and never set Main.error",function()
    for _,mode in ipairs({"absent","empty","secret","hasSecret","hasFalse","hasNil","hasError","getError","rowSecret","rowError","huge"}) do
        local N,rows=setup()
        if mode=="absent" then C_DeathRecap=nil
        elseif mode=="empty" then C_DeathRecap.GetRecapEvents=function() return {} end
        elseif mode=="secret" then C_DeathRecap.GetRecapEvents=function() return H.secret end
        elseif mode=="hasSecret" then C_DeathRecap.HasRecapEvents=function() return H.secret end
        elseif mode=="hasFalse" then C_DeathRecap.HasRecapEvents=function() return false end
        elseif mode=="hasNil" then C_DeathRecap.HasRecapEvents=function() return nil end
        elseif mode=="hasError" then C_DeathRecap.HasRecapEvents=function() error("recap") end
        elseif mode=="getError" then C_DeathRecap.GetRecapEvents=function() error("recap") end
        elseif mode=="rowSecret" then rows[1]=H.secret
        elseif mode=="rowError" then rows[1]=setmetatable({},{__index=function() error("recap") end})
        else for i=2,65 do rows[i]=recapRow() end end
        H.deliver("PLAYER_DEAD"); H.advance(.3); H.advance(.7); H.advance(1)
        eq(#deaths(),0,mode); no(N.Main.error)
    end
end)
test("K: every required recap field secret or missing fails closed without error",function()
    for _,field in ipairs({"sourceGUID","sourceName","sourceFlags","timestamp","overkill"}) do
        for _,mode in ipairs({"secret","missing"}) do
            local N,rows=setup(); rows[1][field]=mode=="secret" and H.secret or nil
            die(); H.advance(1.7); eq(#deaths(),0,field.." "..mode); no(N.Main.error)
        end
    end
end)
test("K: h confidence retains hostile hit even when mob finishes, e prefers a player finisher",function()
    local N,rows=setup(); rows[1].overkill=-1
    rows[2]={sourceGUID="Creature-0-1-0-1-2-AB",sourceName="Forest Wolf",sourceFlags=0x848,overkill=10,timestamp=H.clock()+.1}
    die(); eq(#deaths(),1); yes(deaths()[1].text:find("|h|",1,true))
    N,rows=setup(); rows[1].overkill=0; die(); yes(deaths()[1].text:find("|e|",1,true))
end)
test("K: retry deadlines are 0.3 1 2 seconds, bounded and no late recap beyond them",function()
    for _,ready in ipairs({.3,1,2,3}) do
        local N=setup(); local at=H.clock(); local reads={}
        C_DeathRecap.GetRecapEvents=function()
            reads[#reads+1]=H.clock()-at
            if H.clock()-at+.00001>=ready then return {recapRow()} end
            return {}
        end
        H.deliver("PLAYER_DEAD")
        local scheduled={}
        for _,timer in ipairs(H.timers()) do
            for i,d in ipairs({.3,1,2}) do if math.abs(timer.at-at-d)<.00001 then scheduled[i]=true end end
        end
        eq(#scheduled,3)
        H.advance(.29); eq(#reads,1); eq(reads[1],0) -- mandatory death-time fingerprint read
        -- Cross each deadline by an epsilon: accumulated Lua doubles can land just below it.
        H.advance(.011); H.advance(.7); H.advance(1); H.advance(10)
        eq(#deaths(),ready<=2 and 1 or 0)
        eq(#reads,1+(ready==.3 and 1 or ready==1 and 2 or 3))
        for i,t in ipairs(reads) do yes(math.abs(t-({0,.301,1.001,2.001})[i])<.00001) end
        if ready<=2 then eq(N.OwnDeath.decode(deaths()[1].text).age,math.floor(ready)) end
        no(N.Main.error)
    end
end)
test("K: share off at death or toggled off-on before retries cancels held work",function()
    local N=setup({share=false}); die(); H.advance(2); eq(#deaths(),0)
    N=setup(); H.deliver("PLAYER_DEAD"); N.Main.setShare(false); N.Main.setShare(true); H.advance(.3)
    eq(#deaths(),0); no(N.Main.error)
end)
test("K: BG arena dungeon unknown instance never send; entering later cancels",function()
    for _,kind in ipairs({"pvp","arena","party","unknown","secret","error"}) do
        local N=setup(); IsInInstance=function()
            if kind=="error" then error("instance") end
            if kind=="unknown" then return nil end
            if kind=="secret" then return H.secret end
            return true,kind
        end
        die(); H.advance(2); eq(#deaths(),0,kind); no(N.Main.error)
    end
    local N=setup(); H.deliver("PLAYER_DEAD"); H.instance(true); H.advance(.3); H.instance(false); H.advance(1.7); eq(#deaths(),0)
end)
test("K: resurrection guild-change or zone boundary invalidates already scheduled retries",function()
    for _,event in ipairs({"PLAYER_ALIVE","PLAYER_UNGHOST","PLAYER_GUILD_UPDATE","ZONE_CHANGED_NEW_AREA"}) do
        local N=setup(); H.deliver("PLAYER_DEAD")
        if event=="PLAYER_GUILD_UPDATE" then IsInGuild=function() return false end
        elseif event=="ZONE_CHANGED_NEW_AREA" then H.map(200) end
        H.deliver(event); H.drain()
        IsInGuild=function() return true end
        H.advance(.3); H.advance(1.7); eq(#deaths(),0,event); no(N.Main.error)
    end
end)
test("K: delayed callbacks from a superseded death cannot send its snapshot",function()
    local N,rows=setup(); H.deliver("PLAYER_DEAD"); H.advance(.1); H.map(200)
    rows[1].timestamp=H.clock() -- genuinely new death, not a replay of the first recap
    H.deliver("PLAYER_DEAD"); H.advance(.2); eq(#deaths(),0); H.advance(.101)
    eq(#deaths(),1); eq(N.OwnDeath.decode(deaths()[1].text).zone,200)
    H.advance(2); eq(#deaths(),1)
end)

test("K: layer field has the same 15-digit grammar as O including zero",function()
    local N=H.load()
    for _,layer in ipairs({"0","123456789012345"}) do
        local line="K|1|100|||"..layer.."|0|e|"
        yes(N.OwnDeath.decode(line)); yes(N.Relay.decodeOwn("O|1|1|100|||"..layer.."|0|1|","Birch Moss",H.clock()))
        eq(N.OwnDeath.line(N.OwnDeath.decode(line)),line)
    end
    no(N.OwnDeath.decode("K|1|100|||1234567890123456|0|e|"))
end)
test("K: source flag type and hostile masks each independently required",function()
    for _,flags in ipairs({0x848,0x1048,0x418,0x428,0x408,0x458,-1,.5}) do
        local N,rows=setup(); rows[1].sourceFlags=flags; die(); eq(#deaths(),0,tostring(flags)); no(N.Main.error)
    end
end)
test("K: death-event rate limits and cap apply after attribution, not only direct Wire callers",function()
    local N,rows=setup()
    local function freshDeath() rows[1].timestamp=H.clock(); die() end
    freshDeath(); H.advance(60); freshDeath(); eq(#deaths(),1)
    for i=2,5 do H.advance(121); freshDeath(); eq(#deaths(),i) end
    H.advance(121); freshDeath(); eq(#deaths(),5); no(N.Main.error)
end)
test("K: shared prefix pause and budgets drop events, never postpone or retry a send",function()
    for _,mode in ipairs({"pause","budget","refuse","error"}) do
        local N=setup()
        if mode=="pause" then H.result(3); N.Wire.send("LEGW1","pause","GUILD"); H.result(0)
        elseif mode=="budget" then for i=1,5 do yes(N.Wire.send("LEGW1","budget","GUILD")) end
        elseif mode=="refuse" then H.result(4)
        else H.result(function() error("client") end) end
        die(); H.advance(40); eq(#deaths(),(mode=="refuse" or mode=="error") and 1 or 0,mode)
        eq(N.Wire.queued(),0); no(N.Main.error)
    end
end)
test("K: send caller sentinel catches a disguised out-of-Wire client invocation",function()
    H.load()
    local hidden=C_ChatInfo["Send".."AddonMessage"]
    pcall(hidden,"LEGW1",LINE,"GUILD")
    yes(H.forbidden()>0); H.clearForbidden()
end)
test("K: exposed route copy cannot widen LEGW1 or any other prefix",function()
    local N=H.load(); N.Wire.ROUTES.LEGW1.WHISPER=true
    N.Wire.ROUTES.GBOUNTY={GUILD=true}
    no(send(N,nil,nil,"LEGW1","WHISPER")); no(send(N,nil,nil,"GBOUNTY","GUILD")); eq(#deaths(),0)
end)
test("K: seen same-faction proof overrides contradictory opposite-race metadata",function()
    local N=setup(); N.Main.store.localSeen[GUID].faction="same"
    GetPlayerInfoByGUID=function() return "Mage","MAGE","Orc","Orc" end
    die(); H.advance(2); eq(#deaths(),0); no(N.Main.error)
end)
test("K: zone cancellation persists even when race can still prove the killer after store reset",function()
    local N=setup(); GetPlayerInfoByGUID=function() return "Mage","MAGE","Orc","Orc" end
    H.deliver("PLAYER_DEAD"); H.map(200); H.deliver("ZONE_CHANGED_NEW_AREA"); H.drain()
    H.advance(.3); H.advance(1.7); eq(#deaths(),0); no(N.Main.error)
end)
test("K: death in an instance cannot become eligible by leaving before the first retry",function()
    local N=setup(); H.instance(true); H.deliver("PLAYER_DEAD"); H.instance(false)
    H.advance(.3); H.advance(1.7); eq(#deaths(),0); no(N.Main.error)
end)

local function raceProof()
    GetPlayerInfoByGUID=function() return "Rogue","ROGUE","Orc","Orc" end
end
local function nextDeath()
    H.deliver("PLAYER_ALIVE"); H.advance(1901)
end
for _,mode in ipairs({"persistent","fresh mob","fresh player"}) do
    test("K review F1: earlier recap is refused while retrying for "..mode,function()
        local N,rows=setup(); raceProof(); die(); eq(#deaths(),1)
        nextDeath(); local at=H.clock(); local reads={}
        C_DeathRecap.GetRecapEvents=function()
            reads[#reads+1]=H.clock()-at
            if mode~="persistent" and H.clock()-at>=.9 then
                local row=recapRow(); row.timestamp=at
                if mode=="fresh mob" then row.sourceGUID="Creature-0-1-0-1-2-AB"; row.sourceFlags=0x848 end
                return {row}
            end
            return rows
        end
        H.deliver("PLAYER_DEAD"); H.advance(.301); eq(#deaths(),1,"no stale K at first retry")
        H.advance(.7); H.advance(1); H.advance(3)
        eq(#deaths(),mode=="fresh player" and 2 or 1)
        yes(#reads>=3,"stale refusal must retain later recap retries")
        if mode=="fresh player" then eq(N.OwnDeath.decode(deaths()[2].text).age,1) end
        no(N.Main.error)
    end)
end
for _,mode in ipairs({"share off","instance","unproven"}) do
    test("K review F1: records death rows even when no K is sent for "..mode,function()
        local N,rows=setup()
        if mode=="share off" then N.Main.setShare(false)
        elseif mode=="instance" then H.instance(true)
        else N.Main.store.localSeen={} end
        H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(2); eq(#deaths(),0)
        nextDeath(); N.Main.setShare(true); H.instance(false); raceProof()
        H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(.7); H.advance(1)
        eq(#deaths(),0,"the unsent earlier death still owns these rows"); no(N.Main.error)
    end)
end
for _,refresh in ipairs({false,true}) do
    test("K review F1: world entry seeds the held recap before the first death refresh="..tostring(refresh),function()
        local N,rows=setup(); raceProof()
        H.deliver("PLAYER_ENTERING_WORLD"); H.drain()
        local at=H.clock()
        C_DeathRecap.GetRecapEvents=function()
            if refresh and H.clock()-at>=.9 then
                local row=recapRow(); row.timestamp=at+1; return {row}
            end
            return rows
        end
        H.deliver("PLAYER_DEAD"); H.advance(.301); eq(#deaths(),0,"pre-login recap cannot be the first death")
        H.advance(.7); H.advance(1); eq(#deaths(),refresh and 1 or 0); no(N.Main.error)
    end)
end
test("K review F1: row-set identity ignores table allocation and order",function()
    local N,rows=setup(); raceProof()
    rows[2]={sourceGUID="Creature-0-1-0-1-2-AB",sourceName="Forest Wolf",sourceFlags=0x848,
        timestamp=H.clock()-.1,overkill=-1,amount=20}
    die(); eq(#deaths(),1); nextDeath()
    local copy={}
    for i=1,2 do copy[3-i]={}; for k,v in pairs(rows[i]) do copy[3-i][k]=v end end
    C_DeathRecap.GetRecapEvents=function() return copy end
    H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(.7); H.advance(1)
    eq(#deaths(),1); no(N.Main.error)
end)
for _,field in ipairs({"sourceGUID","sourceName","timestamp","amount","overkill"}) do
    test("K review F1: a changed recap "..field.." identifies a new row set",function()
        local N,rows=setup(); raceProof(); rows[1].amount=100
        die(); eq(#deaths(),1); nextDeath()
        local values={sourceGUID="Player-1-456",sourceName="Cedar Grove",timestamp=H.clock(),amount=101,overkill=11}
        rows[1][field]=values[field]
        H.deliver("PLAYER_DEAD"); H.advance(.301); eq(#deaths(),2,field); no(N.Main.error)
    end)
end
test("K review F1: an ineligible fresh row set does not stop later eligible retries",function()
    local N,rows=setup(); raceProof(); local at=H.clock()
    C_DeathRecap.GetRecapEvents=function()
        if H.clock()-at<.9 then return {{sourceGUID="Creature-0-1-0-1-2-AB",sourceName="Forest Wolf",
            sourceFlags=0x848,timestamp=at,amount=50,overkill=0}} end
        return rows
    end
    H.deliver("PLAYER_DEAD"); H.advance(.301); eq(#deaths(),0)
    H.advance(.7); eq(#deaths(),1); no(N.Main.error)
end)
test("K review F1: fingerprint history saturates closed instead of forgetting a prior death",function()
    local N,rows=setup({share=false}); raceProof()
    local first=rows[1].timestamp
    for i=1,257 do rows[1].timestamp=first+i; H.deliver("PLAYER_DEAD") end
    N.Main.setShare(true)
    for _,stamp in ipairs({first+1,first+1000}) do
        rows[1].timestamp=stamp; H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(.7); H.advance(1)
        eq(#deaths(),0,"neither forgotten nor overflow recaps are fresh")
    end
    no(N.Main.error)
end)
