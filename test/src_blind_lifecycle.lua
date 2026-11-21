local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function setup()
    local N=H.load(); H.clock(120); SlashCmdList.LAYERENEMIES("blind on")
    _G.LayerSwapDB={book={["Host Cedar"]={layer="987654-876543",zone=100,at=H.wall(),host=true}}}
    return N,N.Main
end

test("Blind lifecycle: stopping cancels pending acceptance and stale timers",function()
    local N,M=setup(); yes(M.hopAny()); SlashCmdList.LAYERENEMIES("hop stop")
    eq(M.invite.pending,nil); eq(M.blindPending,nil)
    H.deliver("PARTY_INVITE_REQUEST","Host Cedar"); eq(H.accepts(),0)
    local before=#H.log(); H.advance(121); eq(#H.log(),before,"cancelled result timer stays quiet")
end)

test("Blind lifecycle: a blind-painted click cannot turn into known fanout",function()
    local N,M=setup(); N.UI.tab="friendly"; N.UI.toggle(); N.UI.render(); N.HopBar.refresh()
    N.Trust.manual(M.store,"off"); N.Trust.read(M.store,H.clock(),"7086-7",7)
    local f=N.HopBar.frame
    H.clickWith(function() f.scripts.OnMouseDown(f,"LeftButton"); f.scripts.OnClick(f,"LeftButton") end)
    eq(#H.whoCalls(),0,"stale blind bar does not start WHO")
    H.clickWith(function() N.UI.hopAny.scripts.OnClick() end)
    eq(#H.whoCalls(),0,"stale blind window does not start WHO")
end)

test("Blind lifecycle: blind reply is remembered silently, not a sixth result text",function()
    local N,M=setup(); yes(M.hopAny()); local first=#H.log()
    H.deliver("CHAT_MSG_ADDON","LayerSwap","heard "..N.Adapters.ownIdentity().."|987654-876543|100|h","WHISPER","Host Cedar")
    eq(#H.log(),first); yes(M.heard.heard["Host Cedar"])
end)

test("Blind lifecycle: accepted known hop losing trust ends with sparse proxy, not failed-layer claim",function()
    local N=H.hopLoad(); local M=N.Main; H.clock(120)
    H.deliver("CHAT_MSG_ADDON","LFSw","L 9000|100|h","GUILD","Host Cedar")
    local c=M.candidates()[1]; yes(M.hopHostTo(c,M.hostPreview(c)))
    H.deliver("PARTY_INVITE_REQUEST","Host Cedar")
    H.group(true); H.units().party1={name="Host Cedar",player=true,leader=true}; H.deliver("GROUP_ROSTER_UPDATE")
    SlashCmdList.LAYERENEMIES("blind on"); H.advance(5); H.advance(10); H.advance(15)
    eq(H.leaves(),1); eq(N.HopBar.statusText(),"Joined Host Cedar. Too little around you to tell.")
    for _,text in ipairs(H.log()) do no(text:find("could not move",1,true)) end
end)

test("Blind lifecycle: trust loss after a known join keeps the original probe deadlines",function()
    local N=H.hopLoad(); local M=N.Main
    H.hopClick(N); H.deliver("WHO_LIST_UPDATE"); H.deliver("PARTY_INVITE_REQUEST","Seeker a")
    eq(H.accepts(),1); H.group(true); H.units().party1={name="Seeker a",leader=true}
    H.deliver("GROUP_ROSTER_UPDATE"); yes(M.auto.group.joinedAt)
    M.store.bulo=nil; M.autoTick(); H.advance(3.1); eq(H.leaves(),0)
    H.advance(27); eq(H.leaves(),1)
    eq(N.HopBar.statusText(),"Joined Seeker a. Too little around you to tell.")
end)

test("Blind Find: new sightings reset between hops without needing a UI projection",function()
    local N,M=setup(); M.track("Enemy Oak"); N.Find.changed(M.find,120)
    H.clock(121); N.Find.report(M.find,{enemies={{name="Enemy Oak"}},zone=100,at=121,sender="Scout Birch"})
    N.Find.changed(M.find,122)
    eq(M.findRows()[1].search,"not seen on 1 layers tried")
end)

test("HopProbe: vertical motion also counts toward forty yards",function()
    local N=H.load(); local P=N.HopProbe
    local raw={}; for i=1,5 do raw[i]={guid="Player-987654-"..i,player=true} end
    local a=P.snapshot(raw,{x=0,y=0,z=0,map=100})
    local b=P.snapshot({raw[1]},{x=0,y=0,z=40,map=100})
    eq(P.judge(a,b),"unchanged")
    b=P.snapshot({raw[1]},{x=0,y=0,z=39.99,map=100}); eq(P.judge(a,b),"players")
end)
