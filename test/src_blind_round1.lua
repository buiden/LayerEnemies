-- Round-1 corrections; synthetic identities and real event entrypoints.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local HOST="Host Cedar"
local function setup(mode)
    local N=H.load(); H.clock(120)
    if mode=="known" then H.establish(N) else SlashCmdList.LAYERENEMIES("blind on") end
    _G.LayerSwapDB={book={[HOST]={layer="9000-8",zone=100,at=H.wall(),host=true}}}
    return N,N.Main
end
local function ask(N,M,mode)
    if mode=="known" then
        local c=M.candidates()[1]; yes(c); yes(M.hopHostTo(c,M.hostPreview(c)))
    else yes(M.hopAny()) end
end
local function join(M)
    H.deliver("PARTY_INVITE_REQUEST",HOST)
    H.group(true); H.units().party1={name=HOST,leader=true,player=true}
    H.deliver("GROUP_ROSTER_UPDATE")
    yes(M.auto.group); yes(M.auto.group.joinedAt)
end
local function samples(spawn)
    for i=1,3 do H.units()["nameplate"..i]={guid="Creature-0-1-0-2-"..i.."-"..spawn,player=false} end
end
local function ticks(M)
    for _,dt in ipairs({5,10,15,.2}) do H.advance(dt); M.autoTick() end
end
for _,route in ipairs({"whisper","guild"}) do
    for _,sent in ipairs({false,true}) do
        test("Blind R1 draft: "..route.." sent="..tostring(sent).." expires honestly",function()
            local N,M=setup(); _G.LayerSwapDB=nil
            if route=="whisper" then M.heard.flhHosts={{name=HOST,map=100,key="8",at=H.wall()}} end
            M.openWhisper=function() return true end; M.openChat=function() return true end
            ask(N,M); H.deliver("PARTY_INVITE_REQUEST",HOST); eq(H.accepts(),0)
            local mark=#H.log()
            if sent then
                H.advance(60)
                if route=="whisper" then H.deliver("CHAT_MSG_WHISPER_INFORM",N.Invite.MESSAGE,HOST)
                else H.deliver("CHAT_MSG_GUILD","inv layer <LS 100 25.0,75.0>",N.Adapters.ownIdentity()) end
                H.advance(61); M.autoTick(); eq(N.HopBar.statusText(),""); yes(M.blindPending)
                H.advance(60)
            else H.advance(121) end
            M.autoTick()
            eq(N.HopBar.statusText(),sent and (route=="whisper" and HOST or N.Hop.GUILD.name).." did not invite." or "")
            if not sent then eq(#H.log(),mark,"unsent expiry is quiet") end
            eq(M.blindPending,nil); eq(M.invite.pending,nil); eq(H.accepts(),0); eq(#H.sent(),0); no(M.error)
        end)
    end
end
-- Adapted from the reviewer's observed-invite/no-group repro, with approved exact texts.
for _,mode in ipairs({"accepted","manual","refused","off-after-accept"}) do
    test("Blind R1 invite: observed without group "..mode.." never becomes missed",function()
        local N,M=setup(); ask(N,M)
        if mode=="manual" then M.setAutoHop(false) end
        if mode=="refused" then N.Wire.accept=function() return false,"error" end end
        H.deliver("PARTY_INVITE_REQUEST",HOST)
        local accepted=mode=="accepted" or mode=="off-after-accept"
        eq(H.accepts(),accepted and 1 or 0)
        if mode=="off-after-accept" then M.setAutoHop(false) end
        H.advance(61); M.autoTick()
        if mode=="accepted" or mode=="manual" then
            eq(M.blindPending,nil,"join watchdog consumes the attempt")
            eq(N.HopBar.statusText(),accepted and "Accepted Host Cedar's invite, but no group formed." or "Host Cedar invited; not accepted.")
        end
        H.advance(60); M.autoTick()
        eq(N.HopBar.statusText(),accepted and "Accepted Host Cedar's invite, but no group formed." or "Host Cedar invited; not accepted.")
        for _,line in ipairs(H.log()) do no(line:find("did not invite",1,true)) end
        eq(M.blindPending,nil); eq(M.invite.pending,nil); eq(M.auto.group,nil); eq(H.leaves(),0)
        H.deliver("PARTY_INVITE_REQUEST",HOST); eq(H.accepts(),accepted and 1 or 0)
        no(M.error)
    end)
end
test("Blind R1 invite: known acceptance converted before group keeps invite evidence",function()
    local N,M=setup("known"); ask(N,M,"known")
    H.deliver("PARTY_INVITE_REQUEST",HOST); eq(H.accepts(),1)
    SlashCmdList.LAYERENEMIES("blind on"); M.autoTick(); yes(M.auto.group.blind)
    H.advance(61); M.autoTick()
    eq(N.HopBar.statusText(),"Accepted Host Cedar's invite, but no group formed.")
    eq(M.auto.group,nil); eq(M.invite.pending,nil); eq(H.leaves(),0); no(M.error)
end)
for _,kind in ipairs({"empty","hidden","throwing"}) do
    test("Blind R1 snapshot: "..kind.." after join reports too little",function()
        local N,M=setup(); samples("ABC"); ask(N,M); join(M)
        for i=1,40 do H.units()["nameplate"..i]=nil end
        if kind=="hidden" then H.units().target={guid="Creature-hidden",player=false}
        elseif kind=="throwing" then UnitGUID=function() error("unreadable") end end
        ticks(M)
        eq(N.HopBar.statusText(),"Joined Host Cedar. Too little around you to tell.")
        eq(H.leaves(),1); no(M.error)
    end)
end
for _,gate in ipairs({"group","instance","pending","cooldown"}) do
    test("Blind R1 tooltip: disabled button explains "..gate,function()
        local N,M=setup()
        if gate=="group" then H.group(true)
        elseif gate=="instance" then H.instance(true)
        elseif gate=="pending" then ask(N,M)
        else M.invite.lastAsk=H.clock() end
        N.UI.toggle(); N.UI.render()
        local p=M.hopAnyPreview(); no(p.enabled); yes(p.reason)
        local text; GameTooltip={SetOwner=function() end,SetText=function(_,v) text=v end,Show=function() end}
        N.UI.hopAny.scripts.OnEnter()
        yes(text and text:find(p.reason,1,true),"disabled tooltip includes refusal reason")
        no(M.error)
    end)
end
-- The reviewer's known-to-blind cancellation repro, extended with stale events.
test("Blind R1 stop: accepted known hop converted to blind is cancelled",function()
    local N,M=setup("known"); ask(N,M,"known"); join(M)
    SlashCmdList.LAYERENEMIES("blind on"); M.autoTick(); yes(M.auto.group.blind)
    SlashCmdList.LAYERENEMIES("hop stop")
    eq(M.auto.group,nil,"converted probe ownership cancelled")
    eq(M.blindPending,nil); eq(M.invite.pending,nil)
    local mark=#H.log(); ticks(M); H.advance(121)
    H.deliver("PARTY_INVITE_REQUEST",HOST); H.deliver("SHARD_TRANSFER")
    eq(H.leaves(),0); eq(H.accepts(),1); eq(#H.log(),mark); no(M.error)
end)
-- Review leave probes, covering both result deadlines and event-time recovery.
for _,changed in ipairs({false,true}) do
    for _,guard in ipairs({"combat","unknown-combat","extra-member","extra-while-waiting"}) do
        test("Blind R1 leave: changed="..tostring(changed).." guard="..guard,function()
            local N,M=setup(); samples("ABC"); ask(N,M); join(M)
            if changed then samples("DEF") end
            local original=InCombatLockdown
            if guard=="combat" or guard=="extra-while-waiting" then H.combat(true)
            elseif guard=="unknown-combat" then InCombatLockdown=function() return H.secret end
            else H.units().party2={name="Friend Elm",player=true} end
            ticks(M); eq(H.leaves(),0,"guard holds at result and leave deadline")
            if guard=="extra-while-waiting" then
                H.units().party2={name="Friend Elm",player=true}; H.deliver("GROUP_ROSTER_UPDATE")
            end
            H.combat(false); InCombatLockdown=original; H.deliver("PLAYER_REGEN_ENABLED")
            if guard=="extra-member" or guard=="extra-while-waiting" then
                eq(M.auto.group,nil,"additional member permanently disarms leave")
                H.units().party2=nil; H.deliver("GROUP_ROSTER_UPDATE"); H.advance(31)
                eq(H.leaves(),0,"return to two players must not rearm leave")
            else
                eq(H.leaves(),1,"combat end releases owed leave")
                H.advance(31); eq(H.leaves(),1)
            end
            no(M.error)
        end)
    end
end
test("Blind R1 Find: exact-join sighting suppresses the count before any projection",function()
    local N,M=setup(); M.track("Enemy Oak")
    N.Find.report(M.find,{enemies={{name="Enemy Oak"}},zone=100,at=120,sender="Scout Birch"})
    N.Find.changed(M.find,120)
    eq(M.find.search["Enemy Oak"].count,0,"equal join timestamp is included without a UI read")
end)
local function sight(N,M,kind,at)
    if kind=="own" then N.Find.own(M.find,{name="Enemy Oak",faction="opposite",source="own target"},100,at)
    else
        N.Find.report(M.find,{enemies={{name="Enemy Oak"}},zone=100,at=at,sender="Scout Birch",
            source=kind=="hash" and "headhunter" or nil})
    end
end
for _,kind in ipairs({"own","report","hash"}) do
    for _,delay in ipairs({0,2,6}) do
        test("Blind R1 Find: "..kind.." sighting after join at "..delay.." is not a missed hop",function()
            local N,M=setup(); M.track("Enemy Oak"); M.track("Enemy Elm")
            samples("ABC"); ask(N,M); join(M); local joined=M.auto.group.joinedAt
            H.advance(delay); sight(N,M,kind,H.clock())
            samples("DEF"); H.advance(delay<5 and 5-delay or 15-delay); M.autoTick()
            eq(M.find.search["Enemy Oak"].count,0,"ingress keeps the count honest without UI projection")
            eq(M.findRows()[1].search,nil)
            eq(M.findRows()[2].search,"not seen on 1 layers tried"); no(M.error)
        end)
    end
    test("Blind R1 Find: "..kind.." sighting before join still counts and late post-join replay resets",function()
        local N,M=setup(); M.track("Enemy Oak"); samples("ABC"); ask(N,M)
        sight(N,M,kind,120); H.advance(1); join(M); local joined=M.auto.group.joinedAt
        samples("DEF"); H.advance(5)
        eq(M.findRows()[1].search,"not seen on 1 layers tried")
        sight(N,M,kind,joined-1); eq(M.findRows()[1].search,"not seen on 1 layers tried")
        sight(N,M,kind,joined+1); eq(M.findRows()[1].search,nil)
        N.Find.changed(M.find,joined+10)
        sight(N,M,kind,joined+1); eq(M.findRows()[1].search,"not seen on 1 layers tried")
        no(M.error)
    end)
end
