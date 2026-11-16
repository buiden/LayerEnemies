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
        else for i=2,257 do rows[i]=recapRow() end end -- over RECORD_LIMIT: unread rows could be old
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
        -- Each 0.3/1/2 s tick reads for the send attempt (until it sends or ends) and for the
        -- record-only look, which always runs; nothing reads after 2 s.
        local ticks={0,.301,1.001,2.001}
        for _,t in ipairs(reads) do
            local ok=false; for _,v in ipairs(ticks) do if math.abs(t-v)<.00001 then ok=true end end
            yes(ok,"read only at death or a 0.3/1/2 s tick, got "..t)
        end
        local attemptsLeft=ready==.3 and 1 or ready==1 and 2 or 3
        eq(#reads,1+3+attemptsLeft)
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
    local N,rows=setup(); H.deliver("PLAYER_DEAD"); H.advance(.1); H.deliver("PLAYER_ALIVE"); H.map(200)
    rows[1].timestamp=H.clock() -- revive then die: genuinely new death, not a duplicate event
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
    local function freshDeath() H.deliver("PLAYER_ALIVE"); rows[1].timestamp=H.clock(); die() end
    die(); H.advance(60); freshDeath(); eq(#deaths(),1)
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
-- Review round 2 F1-C/F1-D: the recap can lag PLAYER_DEAD. Rows that show up
-- after an unannounced death's first look, or after its retries ran out, still
-- belong to that death and must never label the next one.
test("K review F1-C: rows arriving after an unsent death's first look stay with that death",function()
    local N=setup(); raceProof(); N.Main.setShare(false)
    local held={}
    C_DeathRecap.GetRecapEvents=function() return held end
    H.deliver("PLAYER_DEAD"); H.advance(.2); held={recapRow()}
    H.advance(.11); H.advance(.7); H.advance(1); eq(#deaths(),0)
    nextDeath(); N.Main.setShare(true)
    H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(.7); H.advance(1)
    eq(#deaths(),0,"late rows of the unsent death cannot become the next death's killer"); no(N.Main.error)
end)
test("K review F1-C: an unsent death's timed looks record a row set the client replaced before revive",function()
    local N=setup(); raceProof(); N.Main.setShare(false)
    local first={recapRow()}
    local held={}
    C_DeathRecap.GetRecapEvents=function() return held end
    H.deliver("PLAYER_DEAD"); H.advance(.2); held=first
    H.advance(.11); H.advance(.7)
    local other=recapRow(); other.timestamp=H.clock()+7; held={other}
    H.advance(1); eq(#deaths(),0)
    nextDeath(); N.Main.setShare(true); held=first -- the earlier set comes back
    H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(.7); H.advance(1)
    eq(#deaths(),0,"the row set seen only by a record-only look stays with the unsent death"); no(N.Main.error)
end)
test("K review F1-D: rows arriving after the retries ran out belong to the old death on revive",function()
    local N=setup(); raceProof()
    local held={}
    C_DeathRecap.GetRecapEvents=function() return held end
    H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(.7); H.advance(1); eq(#deaths(),0)
    H.advance(.1); held={recapRow()}
    for _,event in ipairs({"PLAYER_ALIVE","PLAYER_UNGHOST"}) do
        if event=="PLAYER_UNGHOST" then
            -- second variant: a different late row set claimed by the ghost-revive event
            nextDeath(); H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(.7); H.advance(1)
            local row=recapRow(); row.timestamp=H.clock()+5; held={row}
        end
        H.deliver(event); H.advance(1901)
        H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(.7); H.advance(1)
        eq(#deaths(),0,event.." must claim the held recap for the death that ended")
    end
    no(N.Main.error)
end)
for _,field in ipairs({"damage","sourceFlags"}) do
    test("K review (second opinion case 2): an old row back with edited "..field.." is still the old death",function()
        local N,rows=setup(); raceProof()
        rows[1].damage=10
        die(); H.advance(2); eq(#deaths(),1)
        nextDeath(); H.advance(1801) -- clear the K rate window
        local row=recapRow(); row.timestamp=rows[1].timestamp; row.damage=rows[1].damage
        if field=="damage" then row.damage=20 else row.sourceFlags=rows[1].sourceFlags+0x10000 end
        C_DeathRecap.GetRecapEvents=function() return {row} end
        die(); H.advance(2)
        eq(#deaths(),1,"rows differing only in "..field.." are the old death's rows: no new K"); no(N.Main.error)
    end)
end
test("K cap: after 256 rows the oldest are evicted; a newer death still sends, an evicted row never does",function()
    local N=setup(); raceProof(); N.Main.setShare(false)
    local held
    C_DeathRecap.GetRecapEvents=function() return held end
    for i=1,256 do
        local row=recapRow(); row.timestamp=1000+i; held={row}
        H.deliver("PLAYER_DEAD"); H.advance(2.1); H.deliver("PLAYER_ALIVE"); H.advance(1)
    end
    -- one more row evicts the oldest (timestamp 1001); the high mark (1500) already covers it
    local extra=recapRow(); extra.timestamp=1500; held={extra}
    H.deliver("PLAYER_DEAD"); H.advance(2.1); H.deliver("PLAYER_ALIVE"); H.advance(1)
    N.Main.setShare(true); H.advance(1801)
    local evicted=recapRow(); evicted.timestamp=1001; held={evicted}
    H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(.7); H.advance(1)
    eq(#deaths(),0,"an evicted old row returning alone is at or below the mark: no line")
    -- the next-oldest rows are still on record, and a different source stamped like an old row is old too
    for _,case in ipairs({{1003,"Player-1-123"},{1004,"Player-1-789"}}) do
        H.deliver("PLAYER_ALIVE"); H.advance(1801)
        local r=recapRow(); r.timestamp=case[1]; r.sourceGUID=case[2]; held={r}
        H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(.7); H.advance(1)
        eq(#deaths(),0,"row stamped "..case[1].." is old")
    end
    -- a never-seen row stamped before rows of earlier deaths is old, even after the cap
    H.deliver("PLAYER_ALIVE"); H.advance(1801)
    local mid=recapRow(); mid.timestamp=1257; mid.sourceGUID="Player-1-456"; mid.sourceName="Birch"; held={mid}
    H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(.7); H.advance(1)
    eq(#deaths(),0,"a never-seen row older than rows of earlier deaths is old")
    H.deliver("PLAYER_ALIVE"); H.advance(1801)
    H.deliver("PLAYER_ALIVE"); H.advance(1801)
    local row=recapRow(); row.timestamp=H.clock(); held={row}
    H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(.7); H.advance(1)
    eq(#deaths(),1,"a genuinely newer death still sends after the cap"); no(N.Main.error)
end)
test("K review N1 (accepted miss): an earlier death's 2 s look may take a quick next death's rows",function()
    local N=setup(); raceProof(); N.Main.setShare(false)
    local held={}
    C_DeathRecap.GetRecapEvents=function() return held end
    H.deliver("PLAYER_DEAD"); H.advance(.2); H.deliver("PLAYER_ALIVE")
    N.Main.setShare(true); H.advance(1.7)
    H.deliver("PLAYER_DEAD"); H.advance(.05); held={recapRow()}
    H.advance(.3); H.advance(.7); H.advance(1)
    eq(#deaths(),0,"documented miss: the earlier death's look claims rows that arrive inside its window"); no(N.Main.error)
end)
test("K review N2: rows arriving between the 1 s and 2 s looks of an unsent death stay with it",function()
    local N=setup(); raceProof(); N.Main.setShare(false)
    local held={}
    C_DeathRecap.GetRecapEvents=function() return held end
    H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(.7); H.advance(.5); held={recapRow()}
    H.advance(.6); eq(#deaths(),0)
    local late=held; held={} -- revive cannot see these rows: only the timed looks can claim
    H.deliver("PLAYER_ALIVE"); H.advance(1901); N.Main.setShare(true); held=late
    H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(.7); H.advance(1)
    eq(#deaths(),0,"the 2 s look claims rows that arrived after the 1 s look"); no(N.Main.error)
end)
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
for _,field in ipairs({"sourceGUID","sourceName","timestamp"}) do
    test("K review F1: a changed recap "..field.." is a new row; only a newer timestamp can name",function()
        local N,rows=setup(); raceProof(); rows[1].amount=100
        die(); eq(#deaths(),1); nextDeath()
        local values={sourceGUID="Player-1-456",sourceName="Cedar Grove",timestamp=H.clock(),amount=101,overkill=11}
        rows[1][field]=values[field]
        H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(.7); H.advance(1)
        -- a different source stamped like the earlier death's row happened before this death
        eq(#deaths(),field=="timestamp" and 2 or 1,field); no(N.Main.error)
    end)
end
for _,field in ipairs({"amount","overkill"}) do
    test("K review (second opinion case 2): a changed recap "..field.." alone is still the old row set",function()
        local N,rows=setup(); raceProof(); rows[1].amount=100
        die(); eq(#deaths(),1); nextDeath()
        rows[1][field]=({amount=101,overkill=11})[field]
        H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(.7); H.advance(1); eq(#deaths(),1,field); no(N.Main.error)
    end)
end
test("K review (second opinion case 1): rows shown during a cancelled death stay with it",function()
    local N=setup(); raceProof()
    local held={}
    C_DeathRecap.GetRecapEvents=function() return held end
    local prior={recapRow()}
    H.deliver("PLAYER_DEAD"); H.advance(.05); N.Main.setShare(false); N.Main.setShare(true)
    H.advance(.15); held=prior
    H.advance(.11); H.advance(.7); H.advance(1); H.advance(.089); held={}
    H.advance(.9); H.deliver("PLAYER_ALIVE"); H.advance(1); held=prior
    H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(.7); H.advance(1)
    eq(#deaths(),0,"a cancelled death's record-only looks claim its rows"); no(N.Main.error)
end)
test("K review (second opinion guard ordering): old rows after a quick revive and death are never sent",function()
    local N=setup(); raceProof(); N.Main.setShare(false)
    local held={}
    C_DeathRecap.GetRecapEvents=function() return held end
    local old={recapRow()}; old[1].timestamp=H.clock()
    H.deliver("PLAYER_DEAD"); H.advance(.2); H.deliver("PLAYER_ALIVE")
    N.Main.setShare(true); H.advance(1.7)
    H.deliver("PLAYER_DEAD"); H.advance(.05); held=old
    H.advance(.3); H.advance(.7); H.advance(1)
    eq(#deaths(),0,"the earlier death's 2 s look claims its own late rows first"); no(N.Main.error)
end)
for _,mode in ipairs({"subset","superset","secret sibling"}) do
    test("K fix check: a row first seen on an earlier death never names the killer ("..mode..")",function()
        local N=setup(); raceProof(); N.Main.setShare(false)
        local held={}
        C_DeathRecap.GetRecapEvents=function() return held end
        local old=recapRow()
        local function wolf(at) return {sourceGUID="Creature-0-1-0-1-2-AB",sourceName="Forest Wolf",sourceFlags=0x848,timestamp=at,overkill=-1,amount=20} end
        held=mode=="subset" and {old,wolf(H.clock()-.1)} or {old}
        H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(.7); H.advance(1); eq(#deaths(),0)
        nextDeath(); N.Main.setShare(true)
        if mode=="subset" then held={old}
        else local w=wolf(H.clock()); if mode=="secret sibling" then w.damage=H.secret end; held={old,w} end
        H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(.7); H.advance(1)
        eq(#deaths(),0,"the old Cedar row stays the earlier death's, whatever else is in the set"); no(N.Main.error)
    end)
end
test("K fix check: a new player row next to an old one still names the new killer",function()
    local N=setup(); raceProof(); N.Main.setShare(false)
    local held={}
    C_DeathRecap.GetRecapEvents=function() return held end
    local old=recapRow(); held={old}
    H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(.7); H.advance(1)
    nextDeath(); N.Main.setShare(true)
    local new=recapRow(); new.timestamp=H.clock(); new.sourceGUID="Player-1-456"; new.sourceName="Birch"
    held={old,new}
    H.deliver("PLAYER_DEAD"); H.advance(.301)
    eq(#deaths(),1); yes(N.OwnDeath.decode(deaths()[1].text)); no(N.Main.error)
end)
for _,mode in ipairs({"65 rows","throwing sibling"}) do
    test("K fix check: a death whose recap cannot name still owns its rows ("..mode..")",function()
        local N=setup(); raceProof(); N.Main.setShare(false)
        local held={}
        C_DeathRecap.GetRecapEvents=function() return held end
        local old=recapRow()
        if mode=="65 rows" then held={}; for i=1,64 do held[i]={sourceGUID="Creature-0-1-0-1-2-AB",sourceName="Forest Wolf",sourceFlags=0x848,timestamp=H.clock()-i,overkill=-1} end; held[65]=old
        else held={old,setmetatable({},{__index=function() error("row accessor failure") end})} end
        H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(.7); H.advance(1); eq(#deaths(),0)
        nextDeath(); N.Main.setShare(true); held={old}
        H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(.7); H.advance(1)
        eq(#deaths(),0,"the old row was recorded by the earlier death"); no(N.Main.error)
    end)
end
test("K fix check: a 65-row recap with a new killer sends; over 256 rows never name",function()
    for _,count in ipairs({65,256,257}) do
        local N=setup(); raceProof()
        local new=recapRow(); new.timestamp=H.clock()
        local held={new}; for i=2,count do held[i]={sourceGUID="Creature-0-1-0-1-2-AB",sourceName="Forest Wolf",sourceFlags=0x848,timestamp=H.clock()-i,overkill=-1} end
        C_DeathRecap.GetRecapEvents=function() return held end
        H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(.7); H.advance(1)
        eq(#deaths(),count<=256 and 1 or 0,count.." rows"); no(N.Main.error)
    end
end)
test("K blind: a row an unsent death could not record never names a later death; the death after that sends",function()
    for _,mode in ipairs({"secret-timestamp","nil-timestamp","secret-name","throwing-row","257-duplicates"}) do
        local N=setup(); raceProof(); N.Main.setShare(false)
        local stamp=H.clock()
        local function old() local r=recapRow(); r.timestamp=stamp; return r end
        local held
        if mode=="secret-timestamp" then held={old()}; held[1].timestamp=H.secret
        elseif mode=="nil-timestamp" then held={old()}; held[1].timestamp=nil
        elseif mode=="secret-name" then held={old()}; held[1].sourceName=H.secret
        elseif mode=="throwing-row" then held={setmetatable({},{__index=function() error("row accessor failure") end})}
        else
            local wolf={sourceGUID="Creature-0-1-0-1-2-AB",sourceName="Forest Wolf",sourceFlags=0x848,timestamp=stamp-1,overkill=-1}
            held={}; for i=1,256 do held[i]=wolf end; held[257]=old()
        end
        C_DeathRecap.GetRecapEvents=function() return held end
        H.deliver("PLAYER_DEAD"); H.advance(2.1); H.deliver("PLAYER_ALIVE"); H.advance(1)
        N.Main.setShare(true); H.advance(1801)
        held={old()}
        H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(.7); H.advance(1)
        eq(#deaths(),0,mode..": the unrecorded row, now readable, is never named"); no(N.Main.error)
        H.deliver("PLAYER_ALIVE"); H.advance(1801)
        local fresh=recapRow(); fresh.timestamp=H.clock(); held={fresh}
        H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(.7); H.advance(1)
        eq(#deaths(),1,mode..": the next clean death sends"); no(N.Main.error)
    end
end)
test("K blind: empty deaths keep suppression until a non-empty readable death",function()
    local N=setup(); raceProof()
    local old=recapRow()
    local hidden=recapRow(); hidden.timestamp=H.secret
    local held={hidden}
    C_DeathRecap.GetRecapEvents=function() return held end
    H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(.7); H.advance(1)
    eq(#deaths(),0)
    for i=1,2 do
        nextDeath(); held={}
        H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(.7); H.advance(1)
        eq(#deaths(),0,"empty death "..i.." sends nothing")
    end
    nextDeath(); held={old}
    H.deliver("PLAYER_DEAD"); eq(#deaths(),0)
    H.advance(.301); eq(#deaths(),0,"empty recaps cannot spend suppression at the first retry")
    H.advance(.7); eq(#deaths(),0,"suppression holds at the second retry")
    H.advance(1); eq(#deaths(),0,"suppression holds through the last retry")
    -- This death finally recorded a non-empty, fully readable recap. Only the
    -- next distinct death may name a new killer, never the old Cedar row.
    nextDeath()
    local fresh=recapRow(); fresh.sourceGUID="Player-1-456"; fresh.sourceName="Birch"; held={fresh}
    H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(.7); H.advance(1)
    eq(#deaths(),1); eq(N.OwnDeath.decode(deaths()[1].text).enemies[1].name,"Birch"); no(N.Main.error)
end)
for _,mode in ipairs({"empty","hidden","readable sibling"}) do
    test("K blind: duplicate PLAYER_DEAD cannot spend suppression after "..mode,function()
        local N=setup(); raceProof()
        local old=recapRow()
        local hidden=recapRow(); hidden.timestamp=H.secret
        local held={hidden}
        C_DeathRecap.GetRecapEvents=function() return held end
        H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(.7); H.advance(1)
        eq(#deaths(),0); nextDeath()
        if mode=="empty" then held={}
        elseif mode=="hidden" then held={hidden}
        else held={{sourceGUID="Creature-0-1-0-1-2-AB",sourceName="Forest Wolf",
            sourceFlags=0x848,timestamp=old.timestamp-1,overkill=-1}} end
        H.deliver("PLAYER_DEAD"); H.advance(.05); held={old}; H.deliver("PLAYER_DEAD")
        H.advance(.301); eq(#deaths(),0,"duplicate cannot turn A's row into a new death's killer")
        H.advance(.7); eq(#deaths(),0); H.advance(1); eq(#deaths(),0)
        no(N.Main.error)
    end)
end
for _,event in ipairs({"PLAYER_ALIVE","PLAYER_UNGHOST"}) do
    test("K: duplicate PLAYER_DEAD retains the first snapshot until "..event,function()
        local N,rows=setup(); raceProof()
        H.deliver("PLAYER_DEAD"); H.advance(.05); H.map(200)
        H.deliver("PLAYER_DEAD"); H.advance(.251)
        eq(#deaths(),1,"the duplicate must not cancel or replace the first death's pending send")
        eq(N.OwnDeath.decode(deaths()[1].text).zone,100)
        H.advance(1801); rows[1]=recapRow()
        H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(.7); H.advance(1)
        eq(#deaths(),1,"no new death before revive, even with a new row and expired send budgets")
        H.deliver(event); H.advance(1)
        local fresh=recapRow(); fresh.sourceGUID="Player-1-456"; fresh.sourceName="Birch"; rows[1]=fresh
        H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(.7); H.advance(1)
        eq(#deaths(),2); eq(N.OwnDeath.decode(deaths()[2].text).enemies[1].name,"Birch"); no(N.Main.error)
    end)
end
test("K blind: an incomplete death cannot recover after a later readable look",function()
    for _,mode in ipairs({"secret","throwing","overflow"}) do
        for _,phase in ipairs({"death","timer","revive"}) do
            local N=setup(); raceProof()
            local old=recapRow()
            local hidden=recapRow(); hidden.timestamp=H.secret
            local held={hidden}
            C_DeathRecap.GetRecapEvents=function() return held end
            H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(.7); H.advance(1); nextDeath()
            local bad
            if mode=="secret" then bad={hidden}
            elseif mode=="throwing" then bad={setmetatable({},{__index=function() error("row accessor failure") end})}
            else bad={}; for i=1,257 do bad[i]=old end end
            held=phase=="death" and bad or {old}
            H.deliver("PLAYER_DEAD")
            held=phase=="timer" and bad or {old}; H.advance(.301)
            held={old}; H.advance(.7); H.advance(1)
            held=phase=="revive" and bad or {old}; H.deliver("PLAYER_ALIVE")
            held={old}; H.deliver("PLAYER_UNGHOST"); H.advance(1901)
            local fresh=recapRow(); fresh.sourceGUID="Player-1-456"; fresh.sourceName="Birch"; held={fresh}
            H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(.7); H.advance(1)
            eq(#deaths(),0,mode.." at "..phase..": any incomplete look renews suppression")
            nextDeath(); fresh=recapRow(); fresh.sourceGUID="Player-1-789"; fresh.sourceName="Aspen"; held={fresh}
            H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(.7); H.advance(1)
            eq(#deaths(),1); eq(N.OwnDeath.decode(deaths()[1].text).enemies[1].name,"Aspen"); no(N.Main.error)
        end
    end
end)
test("K blind: an unrecordable row beside a sibling stamped lower or higher never lets the old row name a later death",function()
    for _,mode in ipairs({"ts-sib-lower","ts-sib-higher","name-sib-lower","name-sib-higher","throw-sib-lower","throw-sib-higher","257-lower","257-higher"}) do
        local N=setup(); raceProof(); N.Main.setShare(false)
        local function wolf(stamp) return {sourceGUID="Creature-0-1-0-1-2-AB",sourceName="Forest Wolf",sourceFlags=0x848,timestamp=stamp,overkill=-1} end
        local old=recapRow(); old.timestamp=H.clock()
        local d=mode:find("lower") and -1 or 1
        local held
        if mode:find("^257") then
            held={}; for i=1,256 do held[i]=wolf(old.timestamp+d*i*0.001) end; held[257]=old
        else
            local copy=recapRow(); copy.timestamp=old.timestamp
            if mode:find("^ts") then copy.timestamp=H.secret
            elseif mode:find("^name") then copy.sourceName=H.secret
            else copy=setmetatable({},{__index=function() error("row accessor failure") end}) end
            held={copy,wolf(old.timestamp+d)}
        end
        C_DeathRecap.GetRecapEvents=function() return held end
        H.deliver("PLAYER_DEAD"); H.advance(2.1); H.deliver("PLAYER_ALIVE"); H.advance(60)
        N.Main.setShare(true); H.advance(1801)
        held={old}
        H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(.7); H.advance(1)
        eq(#deaths(),0,mode..": the old row is never named"); no(N.Main.error)
    end
end)
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
test("K cap: an evicted earlier row is never fresh again; a newer one is",function()
    local N,rows=setup({share=false}); raceProof()
    local first=rows[1].timestamp
    for i=1,257 do
        rows[1].timestamp=first+i; H.deliver("PLAYER_DEAD"); H.deliver("PLAYER_ALIVE")
    end
    N.Main.setShare(true)
    for _,case in ipairs({{first+1,0},{first+1000,1}}) do
        rows[1].timestamp=case[1]; H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(.7); H.advance(1)
        eq(#deaths(),case[2],"evicted rows stay old; a newer timestamp is a new death")
        H.deliver("PLAYER_ALIVE")
    end
    no(N.Main.error)
end)

local function encodedName(raw)
    return (raw:gsub(".",function(c) return string.format("%02x",c:byte()) end))
end
test("K review S1: malformed UTF-8 after unhex is refused by codec Wire and receiver",function()
    local bad={string.char(245,128,128),string.char(192,128),string.char(237,160,128),
        string.char(244,144,128,128),string.char(226,130),string.char(128)}
    for lead=246,255 do bad[#bad+1]=string.char(lead,128,128) end
    for _,suffix in ipairs(bad) do
        local N=receiver(); local line="K|1|100||||0|e|"..encodedName("Ab"..suffix)..":::p"
        no(N.OwnDeath.decode(line),"invalid UTF-8 must not decode")
        incoming(N,line); no(popup(N)); no(send(N,line)); eq(#deaths(),0); no(N.Main.error)
    end
end)
test("K review S1: valid multi-byte names retain their exact bytes",function()
    local N=H.load()
    for _,name in ipairs({"Cedar","Zo\195\171",string.char(208,144,208,145),"Ab"..string.char(240,144,144,128)}) do
        local line="K|1|100||||0|e|"..encodedName(name)..":::p"
        local r=N.OwnDeath.decode(line); yes(r); eq(r.enemies[1].name,name); eq(N.OwnDeath.line(r),line)
    end
end)

test("K review S2: Wire refuses guildless K even at click priority",function()
    local N=H.load(); IsInGuild=function() return false end
    no(send(N,nil,{prio="click"})); eq(#deaths(),0)
    IsInGuild=function() return true end; yes(send(N,nil,{prio="click"})); eq(#deaths(),1)
end)
test("K review S2: delayed callbacks honor the 2.5 second absolute deadline",function()
    for _,delay in ipairs({2.5,2.501,30}) do
        local N=setup(); raceProof(); H.advance(100-H.clock())
        H.deliver("PLAYER_DEAD"); H.advance(delay)
        eq(#deaths(),delay==2.5 and 1 or 0,"late callback at "..delay)
        H.advance(3); eq(#deaths(),delay==2.5 and 1 or 0); no(N.Main.error)
    end
end)
test("K review S2: retry binds the live guild even without a guild-change event",function()
    local N=setup(); H.deliver("PLAYER_DEAD")
    GetGuildInfo=function() return "Different Guild" end
    H.advance(.301); H.advance(.7); H.advance(1)
    eq(#deaths(),0); no(N.Main.error)
end)
test("K review S2: recap killer matching our own name is not sent",function()
    local N,rows=setup(); raceProof(); N.Main.store.localSeen={}
    rows[1].sourceName=N.Adapters.ownIdentity(); yes(rows[1].sourceName)
    H.deliver("PLAYER_DEAD"); H.advance(.301); H.advance(.7); H.advance(1)
    eq(#deaths(),0); no(N.Main.error)
end)
test("K review S2: zone upper bound is 999999 not one million",function()
    local N=H.load(); yes(N.OwnDeath.decode("K|1|999999||||0|e|"))
    local line="K|1|1000000||||0|e|"
    no(N.OwnDeath.decode(line)); no(send(N,line)); eq(#deaths(),0)
end)
test("K review S2: unhex must validate player syntax as well as UTF-8",function()
    for _,raw in ipairs({"A|B","A\1B","A\nB","Cedar7","Cedar  Vale","Cedar-Vale-Other"}) do
        local N=receiver(); local line="K|1|100||||0|e|"..encodedName(raw)..":::p"
        no(N.OwnDeath.decode(line),"invalid player syntax")
        no(send(N,line)); incoming(N,line); no(popup(N)); eq(#deaths(),0); no(N.Main.error)
    end
end)
test("K review S2: K consumes the shared per-sender LEGW1 receive budget",function()
    local N=receiver()
    for i=1,30 do incoming(N) end
    local rate=N.Main.relay.rates["birch moss"]
    yes(rate,"K must enter the shared rate gate"); eq(rate.n,12)
    yes(popup(N)); eq(#deaths(),0); no(N.Main.error)
end)
