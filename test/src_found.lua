-- 1.2.1 found pop-up: data-driven, no sends, one per name per 120 s, never in instances.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function spot(N,name)
    H.advance(1); local u=H.player(name,"Horde"); H.units().target=u
    H.deliver("PLAYER_TARGET_CHANGED"); H.drain()
end
local function shown(N) return N.Popup.frame and N.Popup.frame:IsShown() end
local function setup(name)
    local N=H.load(); yes(N.Main.track(name or "Cedar")); return N
end

test("Found: a tracked own sighting opens one pop-up with name zone age source and no send",function()
    local N=setup(); local before=#H.sent()
    spot(N,"Cedar"); yes(shown(N),"pop-up on the Find alert")
    local P=N.Popup; eq(P.title:GetText(),"Tracked enemy found")
    yes(P.rows[1]:GetText():find("^Cedar")); eq(P.rows[2]:GetText(),"Ashenvale")
    yes(P.rows[3]:GetText():find("s ago",1,true)); yes(P.rows[4]:GetText()~="")
    eq(P.buttons[1].label:GetText(),"Show on map"); eq(P.buttons[2].label:GetText(),"Dismiss")
    eq(#H.sent(),before,"no sends"); no(N.Main.error)
end)
test("Found: Show on map uses the shared waypoint code; Dismiss closes",function()
    local N=setup(); local calls={}
    local real=N.Main.showOnMap; N.Main.showOnMap=function(z,x,y) calls[#calls+1]={z,x,y}; return true end
    spot(N,"Cedar"); yes(shown(N)); N.Popup.buttons[1]:Click()
    eq(#calls,1); eq(calls[1][1],100); no(shown(N))
    N.Popup.buttons[1]:Click(); eq(#calls,1,"stale closure does nothing")
    N.Main.showOnMap=real
    N=setup(); spot(N,"Cedar"); yes(shown(N)); N.Popup.buttons[2]:Click(); no(shown(N))
end)
test("Found: auto-closes after 30 s",function()
    local N=setup(); spot(N,"Cedar"); yes(shown(N))
    H.advance(29); yes(shown(N)); H.advance(1.5); no(shown(N))
end)
test("Found: one per tracked name per 120 s, then again",function()
    local N=setup(); spot(N,"Cedar"); yes(shown(N)); N.Popup.close()
    yes(N.Main.foundPopup({name="Cedar",zone=100,age=0,status="seen by you"})==false,"inside 120 s")
    H.advance(121); yes(N.Main.foundPopup({name="Cedar",zone=100,age=0,status="seen by you"}))
end)
test("Found: never in an instance; /le found off silences and saves one boolean",function()
    local N=setup(); H.instance(true)
    no(N.Main.foundPopup({name="Cedar",zone=100,age=0})); no(shown(N)); H.instance(false)
    SlashCmdList.LAYERENEMIES("found off"); eq(LayerEnemiesDB.found,false)
    spot(N,"Cedar"); no(shown(N))
    SlashCmdList.LAYERENEMIES("found on"); eq(LayerEnemiesDB.found,true)
    yes(N.Main.foundPopup({name="Cedar",zone=100,age=0}))
end)
test("Found: a new alert type costs one TYPES entry",function()
    local N=H.load(); local ran=0
    N.Popup.TYPES.test={title="Test alert",rows=function(d) return {d.a} end,buttons={{label="Run",run=function() ran=ran+1 end}}}
    yes(N.Popup.show("test",{a="row one"})); eq(N.Popup.title:GetText(),"Test alert"); eq(N.Popup.rows[1]:GetText(),"row one")
    eq(N.Popup.rows[2]:GetText(),""); no(N.Popup.buttons[2]:IsShown()); N.Popup.buttons[1]:Click(); eq(ran,1)
end)

test("Found: non-string level and class render; a throwing pop-up cannot skip the alert sound",function()
    local N=H.load(); yes(N.Popup.show("found",{name="Cedar",level=60,class=false,zone=100,age=3}))
    eq(N.Popup.rows[1]:GetText(),"Cedar 60 false")
    N=setup(); local sounds=0; PlaySound=function() sounds=sounds+1 end
    N.Popup.show=function() error("boom") end
    spot(N,"Cedar"); eq(sounds,1,"alert sound still plays"); PlaySound=nil
end)
