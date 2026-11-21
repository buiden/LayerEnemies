-- Final review guards; synthetic fixtures, real slash/events/timer entrypoints.
-- Fleeting-member sequences are adapted from the independent round-2 repros.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local HOST="Host Cedar"
local function setup()
    local N=H.load(); H.clock(120); SlashCmdList.LAYERENEMIES("blind on")
    LayerSwapDB={book={[HOST]={layer="9000-8",zone=100,at=H.wall(),host=true}}}
    return N,N.Main
end
local function sample(spawn)
    for i=1,3 do H.units()["nameplate"..i]={guid="Creature-0-1-0-2-"..i.."-"..spawn,player=false} end
end
local function join(M)
    H.deliver("PARTY_INVITE_REQUEST",HOST)
    H.group(true); H.units().party1={name=HOST,leader=true,player=true}
    H.deliver("GROUP_ROSTER_UPDATE"); yes(M.auto.group.joinedAt)
end
for _,stage in ipairs({"draft","asked","accepted","joined","shown"}) do
    test("Blind final cancel: auto off at "..stage.." consumes pending and stale timers",function()
        local N,M=setup(); sample("ABC")
        if stage=="draft" then LayerSwapDB=nil; M.openChat=function() return true end end
        yes(M.hopAny()); yes(M.blindPending)
        if stage=="accepted" then H.deliver("PARTY_INVITE_REQUEST",HOST)
        elseif stage=="joined" or stage=="shown" then join(M) end
        if stage=="shown" then sample("DEF"); H.advance(5) end
        local status=N.HopBar.statusText(); local accepts=H.accepts()
        if stage=="shown" then eq(status,"Hopped (layer unknown): the creatures around you changed.") end
        SlashCmdList.LAYERENEMIES("hop auto off")
        eq(M.auto.group,nil); eq(M.blindPending,nil,"auto off consumes the pending round")
        eq(M.invite.pending,nil,"cancelled invites cannot rearm")
        local mark=#H.log()
        H.advance(121); M.autoTick(); H.deliver("PARTY_INVITE_REQUEST",HOST)
        eq(N.HopBar.statusText(),status); eq(#H.log(),mark,"stale timers cannot overwrite a result")
        eq(H.accepts(),accepts); eq(H.leaves(),0); no(M.error)
    end)
end
for _,shown in ipairs({false,true}) do
    test("Blind final expiry: observed join survives lost group ownership shown="..tostring(shown),function()
        local N,M=setup(); sample("ABC"); yes(M.hopAny()); join(M)
        if shown then sample("DEF"); H.advance(5) end
        -- Retain a stale pending object to isolate the expiry guard from cancellation.
        M.auto.group=nil
        local status=N.HopBar.statusText(); local mark=#H.log()
        H.advance(121); M.autoTick()
        eq(N.HopBar.statusText(),status,"observed group formation never becomes unformed")
        eq(#H.log(),mark); eq(M.blindPending,nil); eq(H.leaves(),0); no(M.error)
    end)
end
for _,changed in ipairs({false,true}) do
    for _,when in ipairs({"before-result","armed","combat-wait"}) do
        test("Blind final roster: fleeting third member "..when.." changed="..tostring(changed),function()
            local N,M=setup(); sample("ABC"); yes(M.hopAny()); join(M)
            if changed then sample("DEF") end
            if when=="combat-wait" then H.combat(true); H.advance(5); H.advance(10); H.advance(15)
            elseif when=="armed" then H.advance(5) end
            H.units().party2={name="Friend Elm",player=true}; H.deliver("GROUP_ROSTER_UPDATE")
            eq(M.auto.group,nil,"third-member roster immediately disarms the attempt")
            eq(M.blindPending,nil)
            local status=N.HopBar.statusText()
            H.advance(.1); H.units().party2=nil; H.deliver("GROUP_ROSTER_UPDATE")
            H.advance(.1); H.combat(false); H.deliver("PLAYER_REGEN_ENABLED")
            H.advance(5); H.advance(10); H.advance(15); H.advance(121); M.autoTick()
            eq(H.leaves(),0,"returning to two players cannot rearm leave")
            eq(N.HopBar.statusText(),status); no(M.error)
        end)
    end
end
test("Blind final snapshot: unreadable creatures plus a visible player give too little",function()
    local N,M=setup(); sample("ABC"); yes(M.hopAny()); join(M)
    for i=1,3 do H.units()["nameplate"..i]=nil end
    H.units().nameplate1={guid="Creature-hidden",player=false}
    H.units().nameplate2={guid="Player-1-ABCD",player=true}
    H.advance(5); H.advance(10); H.advance(15)
    eq(N.HopBar.statusText(),"Joined Host Cedar. Too little around you to tell.")
    eq(H.leaves(),1); no(M.error)
end)
for _,exit in ipairs({"stop","manual-leave","raid","leader","instance","zone"}) do
    test("Blind final cancel: "..exit.." clears group and pending together",function()
        local N,M=setup(); sample("ABC"); yes(M.hopAny()); join(M)
        if exit=="stop" then SlashCmdList.LAYERENEMIES("hop stop")
        elseif exit=="manual-leave" then H.group(false); H.units().party1=nil; H.deliver("GROUP_ROSTER_UPDATE")
        elseif exit=="raid" then IsInRaid=function() return true end; M.autoTick()
        elseif exit=="leader" then H.units().party1.leader=false; M.autoTick()
        elseif exit=="instance" then H.instance(true); M.autoTick()
        else M.boundary(101,true) end
        eq(M.auto.group,nil); eq(M.blindPending,nil); eq(M.invite.pending,nil)
        local status=N.HopBar.statusText(); local mark=#H.log()
        H.advance(121); M.autoTick()
        eq(N.HopBar.statusText(),status); eq(#H.log(),mark); eq(H.leaves(),0); no(M.error)
    end)
end
