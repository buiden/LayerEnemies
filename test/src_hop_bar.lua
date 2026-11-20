-- 1.2.5 hop bar (owner's request): a small movable bar with your layer and the hop status; a left-click hops like the
-- window's "Hop to another layer" button, through the same function, gates and limits; nothing new is sent.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function bar(N) return N.HopBar.frame end
local function click(N,button,shift)
    _G.IsShiftKeyDown=function() return shift==true end
    local f=bar(N)
    H.clickWith(function() f.scripts.OnMouseDown(f,button); f.scripts.OnClick(f,button) end)
    _G.IsShiftKeyDown=nil
end
local function lines(N) N.HopBar.refresh(); return bar(N).text:GetText(),bar(N).status:GetText() end

test("Hop bar: on by default, a plain clamped movable button, saved settings checked",function()
    local N=H.load({})
    local f=bar(N); yes(f,"created at login"); yes(f:IsShown(),"shown by default")
    eq(f.kind,"Button"); yes(f.clamped); eq(f.clicks[1],"LeftButtonUp"); eq(f.clicks[2],"RightButtonUp")
    eq(f.bg.color[4],.55,"black at 55%"); eq(f.logoText:GetText(),"LE")
    no(f.scripts.OnEnter,"no tooltip")
    eq(LayerEnemiesDB.bar.shown,true); eq(LayerEnemiesDB.bar.oneline,false); eq(LayerEnemiesDB.bar.position,nil)
    eq(f.point[1],"TOP"); eq(f.point[5],-160)
    local bad=N.HopBar.load({shown="no",oneline=1,position={point="NOWHERE",relative="TOP",x=0,y=0},extra=true})
    eq(bad.shown,true); eq(bad.oneline,false); eq(bad.position,nil); eq(bad.extra,nil)
    N=H.load({bar={shown=false,oneline=true,position={point="LEFT",relative="LEFT",x=20,y=-30}}})
    no(bar(N),"not created while hidden"); eq(LayerEnemiesDB.bar.oneline,true); eq(LayerEnemiesDB.bar.position.x,20)
    SlashCmdList.LAYERENEMIES("bar on"); yes(bar(N):IsShown()); eq(bar(N).point[1],"LEFT"); eq(bar(N).point[4],20)
end)

test("Hop bar: line one is your layer from the window's source, Detecting... or the instance name",function()
    local N=H.load({})
    eq((lines(N)),"Detecting...")
    H.establish(N)
    local key=N.Layer.key(N.Main.store.bulo); yes(key)
    eq((lines(N)),"Layer "..key)
    N.UI.toggle(); N.UI.render(); eq(N.UI.layer:GetText(),key,"same key as YOUR LAYER")
    _G.GetInstanceInfo=function() return "The Deadmines","party" end; H.instance(true)
    eq((lines(N)),"The Deadmines"); H.instance(false); _G.GetInstanceInfo=nil
end)

test("Hop bar: left-click runs the window's hop, with its gates and its 10 s gap; the status follows",function()
    local N=H.hopLoad()
    local calls=0; local real=N.Main.hopAny; N.Main.hopAny=function(...) calls=calls+1; return real(...) end
    local _,status=lines(N); eq(status,"Hop ready")
    local before=#H.sent()
    click(N,"LeftButton"); eq(calls,1); eq(#H.whoCalls(),1,"one who search, as the window's button")
    no(N.Main.error); yes(N.Main.hopAnyState.round)
    _,status=lines(N); eq(status,"Hopping: searching...")
    H.advance(1); H.deliver("WHO_LIST_UPDATE")
    _,status=lines(N); eq(status,"Hopping: asking 8...","eight asked at once, as the window's round")
    for _=1,3 do H.advance(1) end
    _,status=lines(N); local n=tonumber(status:match("^Hopping: asking (%d+)%.%.%.$")); yes(n and n>8,status)
    eq(n,N.Main.hopAnyState.round.sent,"the count is the round's own")
    yes(#H.sent()>before)
    -- a click during the round stops it, like the window's Stop
    click(N,"LeftButton"); no(N.Main.hopAnyState.round); eq(calls,1)
    _,status=lines(N); yes(status:find("^Wait %d+s$"),status)
    click(N,"LeftButton"); eq(calls,2,"the click reaches Main.hopAny"); no(N.Main.hopAnyState.round,"which refuses inside 10 s")
    eq(#H.whoCalls(),1)
    H.advance(11); _,status=lines(N); eq(status,"Hop ready")
    H.combat(true); _,status=lines(N); eq(status,"Hop ready"); yes(bar(N):IsShown(),"still shown in combat")
    click(N,"LeftButton"); yes(N.Main.hopAnyState.round); eq(#H.whoCalls(),2); H.combat(false)
    N.Main.hopAnyStop(); H.advance(11)
    N.Main.setConsent("guild"); _,status=lines(N); eq(status,"Guild-only mode")
end)

test("Hop bar: the end of a drag is not a click, and a drag ending off the bar does not eat the next click",function()
    local N=H.hopLoad(); local f=bar(N)
    local calls=0; N.Main.hopAny=function() calls=calls+1 end
    f.scripts.OnMouseDown(f,"LeftButton"); f.scripts.OnDragStart(f); yes(f.moving)
    f:SetPoint("BOTTOMLEFT",UIParent,"BOTTOMLEFT",40,50); f.scripts.OnDragStop(f); no(f.moving)
    f.scripts.OnClick(f,"LeftButton"); eq(calls,0,"drag release is not a click")
    eq(LayerEnemiesDB.bar.position.point,"BOTTOMLEFT"); eq(LayerEnemiesDB.bar.position.x,40)
    -- dragged off the bar: no OnClick came, the next press starts clean
    f.scripts.OnMouseDown(f,"LeftButton"); f.scripts.OnDragStart(f); f.scripts.OnDragStop(f)
    click(N,"LeftButton"); eq(calls,1)
end)

test("Hop bar: right-click opens the window; Shift+right-click hides the bar and says how to bring it back",function()
    local N=H.load({}); H.establish(N)
    no(N.UI.frame:IsShown()); click(N,"RightButton"); yes(N.UI.frame:IsShown()); click(N,"RightButton"); no(N.UI.frame:IsShown())
    local logged=#H.log()
    click(N,"RightButton",true)
    no(bar(N):IsShown()); eq(LayerEnemiesDB.bar.shown,false)
    local said=false; for i=logged+1,#H.log() do if tostring(H.log()[i]):find("/le bar on",1,true) then said=true end end
    yes(said,"chat line names /le bar on")
end)

test("Hop bar: /le bar on, off and oneline; one-line mode puts both on one line",function()
    local N=H.load({}); H.establish(N)
    SlashCmdList.LAYERENEMIES("bar off"); no(bar(N):IsShown()); eq(LayerEnemiesDB.bar.shown,false)
    SlashCmdList.LAYERENEMIES("bar on"); yes(bar(N):IsShown()); eq(LayerEnemiesDB.bar.shown,true)
    local two=bar(N).height
    SlashCmdList.LAYERENEMIES("bar oneline"); eq(LayerEnemiesDB.bar.oneline,true)
    local one,status=lines(N); yes(one:find("^Layer .+   Hop "),one); eq(status,""); no(bar(N).status:IsShown())
    yes(bar(N).height<two)
    yes(bar(N).width>=bar(N).text:GetStringWidth(),"width follows the text")
    SlashCmdList.LAYERENEMIES("bar  oneline"); eq(LayerEnemiesDB.bar.oneline,false)
    SlashCmdList.LAYERENEMIES("bar")
end)

test("Hop bar: the 1 s refresh sends nothing and stops while hidden",function()
    local N=H.hopLoad()
    local refreshes=0; local real=N.HopBar.refresh; N.HopBar.refresh=function() refreshes=refreshes+1; return real() end
    local before=#H.sent()
    for _=1,5 do H.advance(1) end
    yes(refreshes>=4,"ticks while shown: "..refreshes); eq(#H.sent(),before,"nothing sent")
    SlashCmdList.LAYERENEMIES("bar off"); local at=refreshes
    for _=1,5 do H.advance(1) end; eq(refreshes,at,"no ticks while hidden")
    SlashCmdList.LAYERENEMIES("bar on"); for _=1,3 do H.advance(1) end; yes(refreshes>at+1)
end)

test("Hop bar: a click acts only on what the bar showed (a round started since the last paint is left alone)",function()
    local N=H.hopLoad(); N.HopBar.refresh(); eq(bar(N).round,false)
    H.hopClick(N) -- the round starts from the window or /le hop any, between two paints of the bar
    yes(N.Main.hopAnyState.round)
    local calls,stops=0,0
    N.Main.hopAny=function() calls=calls+1 end
    local stop=N.Main.hopAnyStop; N.Main.hopAnyStop=function(...) stops=stops+1; return stop(...) end
    local f=bar(N); H.clickWith(function() f.scripts.OnMouseDown(f,"LeftButton"); f.scripts.OnClick(f,"LeftButton") end)
    eq(calls,0,"no second hop"); eq(stops,0,"and no stop of a round it did not show"); yes(N.Main.hopAnyState.round)
    eq(bar(N).round,N.Main.hopAnyState.round,"the click repaints")
end)

test("Hop bar: a right-button press during a left drag does not turn the drag's release into a click",function()
    local N=H.hopLoad(); local f=bar(N)
    local calls=0; N.Main.hopAny=function() calls=calls+1 end
    f.scripts.OnMouseDown(f,"LeftButton"); f.scripts.OnDragStart(f)
    f.scripts.OnMouseDown(f,"RightButton")
    f.scripts.OnDragStop(f); f.scripts.OnClick(f,"LeftButton")
    eq(calls,0,"no hop from the drag")
    -- a left press during the drag (a second button chord) does not clear it either
    f.scripts.OnMouseDown(f,"LeftButton"); f.scripts.OnDragStart(f); f.scripts.OnMouseDown(f,"LeftButton")
    f.scripts.OnDragStop(f); f.scripts.OnClick(f,"LeftButton"); eq(calls,0)
    click(N,"LeftButton"); eq(calls,1,"the next real click still hops")
    -- a drag released off the bar leaves the flag; a right-click is still a right-click
    N.UI.create(); f.scripts.OnMouseDown(f,"LeftButton"); f.scripts.OnDragStart(f); f.scripts.OnDragStop(f)
    no(N.UI.frame:IsShown()); click(N,"RightButton"); yes(N.UI.frame:IsShown(),"right-click opens the window")
    click(N,"LeftButton"); eq(calls,2)
end)

local function dump(v,seen,depth)
    if type(v)~="table" then return type(v)=="function" and "fn" or tostring(v) end
    if seen[v] or depth>6 then return "<ref>" end; seen[v]=true
    local keys={} for k in pairs(v) do keys[#keys+1]=k end
    table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
    local out={} for _,k in ipairs(keys) do out[#out+1]=tostring(k).."="..dump(v[k],seen,depth+1) end
    seen[v]=nil
    return "{"..table.concat(out,",").."}"
end
test("Hop bar: the 1 s refresh only reads (an expired ask is not cleared by the display)",function()
    local N=H.hopLoad(); local M=N.Main
    M.invite.pending={name="Seeker A",short="seeker a",at=H.clock()-500}
    M.hop.pending={name="Seeker B",short="seeker b",at=H.clock()-500}
    local function state() return dump({M.invite,M.hop,M.hopAnyState,M.store,M.auto,LayerEnemiesDB},{},0) end
    local before=state()
    for _=1,3 do N.HopBar.refresh() end
    local _,status=lines(N)
    eq(state(),before,"no state changed by the bar's ticks")
    yes(M.invite.pending,"the expired ask is still there for its owner to clear"); yes(M.hop.pending)
    eq(status,"Hop ready","and it does not hold the hop back")
    M.asking(); eq(M.invite.pending,nil,"the owner's own check still clears it")
end)
