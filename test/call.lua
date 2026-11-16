-- Popup probes share the real event dispatcher, clock and strict frame mock.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function bounty(victim,xy,class)
    H.deliver("CHAT_MSG_ADDON","GBOUNTY","D|Cedar Vale|100|"..(xy==false and "|" or "42.5|61.0").."|Forest|60|2|"..(class or "ROGUE").."|","GUILD",victim or "Birch Moss")
end
local function popup(N) return N.CallUI and N.CallUI.frame and N.CallUI.frame:IsShown() end

test("Call: guild bounty death shows victim killer zone and one sound without sending",function()
    local N=H.load(); local sounds=0; PlaySound=function() sounds=sounds+1 end
    local before=#H.sent(); bounty()
    yes(popup(N),"received death must show the popup")
    local U=N.CallUI
    eq(U.victim:GetText(),"Birch Moss")
    eq(U.killer:GetText(),"Cedar Vale 60 ROGUE")
    eq(U.where:GetText(),"Ashenvale")
    eq(sounds,1); eq(#H.sent(),before); no(N.Main.error); PlaySound=nil
end)

local function wos(victim,killer)
    H.deliver("CHAT_MSG_ADDON","WALLOFSHAME","D|60|Ashenvale|MAGE|1|"..(killer or "Cedar Vale").."|60|","GUILD",victim or "Birch Moss")
end
local function known(N,faction)
    H.advance(.1); H.unit("target",H.player("Cedar Vale",faction or "Horde"))
    H.deliver("PLAYER_TARGET_CHANGED"); H.drain()
end
local function record(age,src,coords)
    return {src=src or "gb",kind="death",zone=100,x=coords and .425,y=coords and .61,
        at=H.clock()-(age or 0),heard=H.clock(),enemies={{name="Cedar Vale",class="ROGUE",level=60}}}
end
local function receive(N,victim,age,src,coords)
    yes(N.Main.callReceive,"popup admission entrypoint")
    return N.Main.callReceive(record(age,src,coords),victim or "Birch Moss")
end

test("Call: WOS creature unknown and same-faction killers never show; known opposite does",function()
    for _,faction in ipairs({"unknown","Alliance","Horde"}) do
        local N=H.load(); if faction~="unknown" then known(N,faction) end
        wos("Birch Moss","Forest Wolf"); no(popup(N))
        wos(); eq(not not popup(N),faction=="Horde"); no(N.Main.error)
    end
end)
test("Call: WOS does not trust remote reports or a stale local identity",function()
    local N=H.load(); bounty("Other Victim"); N.CallUI.frame:Hide(); H.advance(20)
    wos(); no(popup(N),"report is not a local observation")
    known(N); H.advance(600); wos("Third Victim"); no(popup(N),"expired seen entry")
    -- Receive can precede the next store-prune heartbeat. The call gate must check age itself.
    N.Main.store.localSeen.synthetic={name="Cedar Vale",faction="opposite",epoch=N.Main.store.serial,at=H.clock()-600}
    wos("Fourth Victim"); no(popup(N),"stale local entry before prune")
end)
test("Call: FTold1 and HeadHunter D are not popup triggers",function()
    local N=H.load()
    H.deliver("CHAT_MSG_ADDON","FTold1","S~Cedar Vale~Ashenvale","GUILD","Birch Moss")
    H.deliver("CHAT_MSG_ADDON","HeadHunter","1AD:ignored","GUILD","Birch Moss")
    no(popup(N)); eq(#H.sent(),0); no(N.Main.error)
end)
test("Call: own death split combined and home realm names never show; other surname does",function()
    for _,combined in ipairs({false,true}) do
        local N=H.load()
        UnitName=function() return combined and "Birch Moss" or "Birch","Moss" end
        for _,who in ipairs({"Birch Moss","Birch-Moss","Birch Moss-TestRealm"}) do bounty(who); no(popup(N)) end
        bounty("Birch Grove"); yes(popup(N)); no(N.Main.error)
    end
end)
test("Call: unknown own identity refuses without recording; then recovers",function()
    local N=H.load(); local old=UnitName
    UnitName=function() return "Me",H.secret end; bounty(); no(popup(N))
    yes(N.Call); eq(next(N.Main.call.victims),nil)
    UnitName=old; bounty(); yes(popup(N))
end)
test("Call: switch is on for fresh and old saves; saved false survives reload",function()
    for _,saved in ipairs({{}, {share=false}, {call=true}, {call=false}}) do
        local expected=saved.call~=false
        local N=H.load(saved); eq(LayerEnemiesDB.call,expected)
        bounty(); eq(not not popup(N),expected)
        if not expected then eq(next(N.Main.call.victims),nil) end
        local copy=LayerEnemiesDB; N=H.load(copy); eq(LayerEnemiesDB.call,expected)
    end
end)
test("Call: slash and window switch clear the popup and all history without affecting share",function()
    local N=H.load(); bounty(); yes(popup(N))
    SlashCmdList.LAYERENEMIES("call off"); no(popup(N)); eq(LayerEnemiesDB.call,false)
    eq(next(N.Main.call.victims),nil); eq(N.Main.call.current,nil)
    bounty("Other Victim"); no(popup(N)); eq(next(N.Main.call.victims),nil)
    N.UI.frame:Show(); eq(N.UI.call.label:GetText(),"Call: off")
    N.UI.call:Click(); eq(LayerEnemiesDB.call,true); eq(N.UI.call.label:GetText(),"Call: on")
    eq(LayerEnemiesDB.share,true); bounty(); yes(popup(N)); eq(#H.sent(),0)
end)
test("Call: instance unreadable and erroring fail closed; combat alone is allowed",function()
    for _,value in ipairs({true,H.secret,"nil","error"}) do
        local N=H.load()
        IsInInstance=function() if value=="error" then error("unavailable") end; if value~="nil" then return value end end
        bounty(); no(popup(N)); yes(N.Call); eq(next(N.Main.call.victims),nil); no(N.Main.error)
    end
    local N=H.load(); H.combat(true); bounty(); yes(popup(N)); no(N.Main.error)
end)
test("Call: age 120 accepted 121 and future refused without history",function()
    local N=H.load()
    receive(N,"Birch Moss",121); no(popup(N)); eq(next(N.Main.call.victims),nil)
    receive(N,"Birch Moss",-1); no(popup(N)); eq(next(N.Main.call.victims),nil)
    receive(N,"Birch Moss",120); yes(popup(N)); eq(N.CallUI.age:GetText(),"120 s ago")
end)
test("Call: one victim per 180 seconds, all victims per 20, newest replaces",function()
    local N=H.load(); bounty(); local first=N.CallUI.event
    H.advance(19); bounty("Other Victim"); eq(N.CallUI.event,first)
    H.advance(1); bounty("Other Victim"); eq(N.CallUI.event.victim,"Other Victim")
    H.advance(159); bounty(); eq(N.CallUI.event.victim,"Other Victim")
    H.advance(1); bounty(); eq(N.CallUI.event.victim,"Birch Moss")
end)
test("Call: duplicate sources within 60 seconds prefer coordinates without sound or new lifetime",function()
    local N=H.load(); known(N); local sounds=0; PlaySound=function() sounds=sounds+1 end
    wos(); yes(popup(N)); local at=N.CallUI.event.at; eq(N.CallUI.event.x,nil)
    H.advance(1); bounty("BIRCH MOSS"); eq(N.CallUI.event.x,.425); eq(N.CallUI.event.at,at); eq(sounds,1)
    H.advance(1); wos(); eq(N.CallUI.event.x,.425); eq(sounds,1)
    PlaySound=nil
end)
test("Call: session table cap evicts oldest and ages prune; no event data saved",function()
    local N=H.load(); yes(N.Call); local C,st=N.Call,N.Main.call
    for i=1,C.MAX do st.victims["filler"..i]={at=H.clock()-i/100,event={}} end
    receive(N); yes(N.Safe.count(st.victims)<=C.MAX); eq(st.victims["filler"..C.MAX],nil)
    H.advance(181); receive(N,"Other Victim"); eq(N.Safe.count(st.victims),1)
    eq(LayerEnemiesDB.victims,nil); eq(LayerEnemiesDB.current,nil)
end)

test("Call: plain clamped popup under minimap or parent fallback and Escape closes",function()
    for _,mode in ipairs({"cluster","map","parent"}) do
        local N=H.load()
        if mode=="cluster" then MinimapCluster={} elseif mode=="map" then Minimap={} end
        bounty(); local U=N.CallUI; yes(popup(N)); eq(U.frame.width,220); eq(U.frame.strata,"HIGH"); eq(U.frame.clamped,true)
        eq(U.heading.width,192); eq(U.heading.height,48)
        eq(U.frame.point[2],MinimapCluster or Minimap or UIParent); eq(U.frame.point[3],mode=="parent" and "TOPRIGHT" or "BOTTOMRIGHT")
        yes(rawget(U.frame,"template")==nil)
        local found=false; for _,name in ipairs(UISpecialFrames) do if name=="LayerEnemiesCall" then _G[name]:Hide(); found=true end end
        yes(found); no(popup(N)); eq(#H.sent(),0)
    end
end)
test("Call: closes at 30 seconds; stale timer never closes replacement",function()
    local N=H.load(); bounty(); local first=N.CallUI.event
    H.advance(20); bounty("Other Victim"); yes(popup(N)); no(N.CallUI.event==first)
    H.advance(10); yes(popup(N)); eq(N.CallUI.age:GetText(),"10 s ago")
    H.advance(19); yes(popup(N)); H.advance(1); no(popup(N))
end)
test("Call: duplicate does not restart 30-second lifetime or revive dismissal",function()
    local N=H.load(); known(N); wos(); H.advance(20); bounty(); H.advance(10); no(popup(N))
    N=H.load(); known(N); wos(); yes(N.CallUI.dismiss); N.CallUI.dismiss:Click(); H.advance(1); bounty(); no(popup(N))
end)
test("Call: entering an instance hides a current call and blocks the old Help closure",function()
    local N=H.load(); bounty(); yes(N.CallUI.help); local click=N.CallUI.help.scripts.OnClick
    H.instance(true); H.deliver("PLAYER_ENTERING_WORLD"); H.drain(); no(popup(N))
    local before=#H.log(); click(); eq(#N.Main.find.names,0); eq(#H.log(),before)
end)
local function waypoint()
    local points,tracks,can={},{},{}
    C_Map.CanSetUserWaypointOnMap=function(zone) can[#can+1]=zone; return true end
    UiMapPoint={CreateFromCoordinates=function(zone,x,y) return {uiMapID=zone,position={x=x,y=y}} end}
    C_Map.SetUserWaypoint=function(point) points[#points+1]=point; return true end
    C_SuperTrack={SetSuperTrackedUserWaypoint=function(value) tracks[#tracks+1]=value end}
    return points,tracks,can
end
test("Call: waypoint works without the Mainline-only UiMapPoint helper",function()
    local N=H.load(); bounty(); local points,tracks=waypoint(); yes(N.CallUI.help)
    UiMapPoint=nil; CreateVector2D=function(x,y) return {x=x,y=y} end
    N.CallUI.help:Click(); eq(#points,1); eq(points[1].uiMapID,100)
    eq(points[1].position.x,.425); eq(points[1].position.y,.61); eq(tracks[1],true)
end)
test("Call: Help uses the shown event once for waypoint and full killer Find only",function()
    local N=H.load(); bounty(); local p,t,c=waypoint(); yes(N.CallUI.help)
    local before=#H.sent(); local click=N.CallUI.help.scripts.OnClick
    N.Main.call.current={zone=200,x=.1,y=.2,killer="Other Enemy",full=true}
    click(); eq(#p,1); eq(p[1].uiMapID,100); eq(p[1].position.x,.425); eq(p[1].position.y,.61)
    eq(#t,1); eq(t[1],true); eq(#c,1); eq(c[1],100); eq(N.Main.find.names[1],"Cedar Vale")
    click(); eq(#p,1); eq(#N.Main.find.names,1); eq(#H.sent(),before); no(popup(N))
end)
test("Call: Help without coordinates prints one useful line and does not set a waypoint",function()
    local N=H.load(); bounty(nil,false); local p=waypoint(); local before=#H.log(); yes(N.CallUI.help)
    N.CallUI.help:Click(); eq(#p,0)
    local lines=0; for i=before+1,#H.log() do if H.log()[i]:find("Ashenvale",1,true) then lines=lines+1; yes(H.log()[i]:find("position unavailable",1,true)) end end
    eq(lines,1); eq(N.Main.find.names[1],"Cedar Vale")
end)
test("Call: waypoint API absent false or throwing prints coordinates safely",function()
    for _,mode in ipairs({"absent","canFalse","canError","setError","setFalse","setNil","pointError","trackError"}) do
        local N=H.load(); bounty(); local p,t=waypoint(); yes(N.CallUI.help)
        if mode=="absent" then C_Map.SetUserWaypoint=nil
        elseif mode=="canFalse" then C_Map.CanSetUserWaypointOnMap=function() return false end
        elseif mode=="canError" then C_Map.CanSetUserWaypointOnMap=function() error("map") end
        elseif mode=="setError" then C_Map.SetUserWaypoint=function() error("map") end
        elseif mode=="setFalse" then C_Map.SetUserWaypoint=function() return false end
        elseif mode=="setNil" then C_Map.SetUserWaypoint=function() return nil end
        elseif mode=="pointError" then UiMapPoint.CreateFromCoordinates=function() error("point") end
        elseif mode=="trackError" then C_SuperTrack.SetSuperTrackedUserWaypoint=function() error("track") end end
        local before=#H.log(); yes(pcall(N.CallUI.help.Click,N.CallUI.help)); no(N.Main.error)
        if mode~="trackError" then
            local n=0; for i=before+1,#H.log() do if H.log()[i]:find("42.5, 61.0",1,true) then n=n+1 end end; eq(n,1)
        end
    end
end)
test("Call: Find full stays unchanged; partial names are never added",function()
    for _,partial in ipairs({false,true}) do
        local N=H.load(); local r=record(0)
        if partial then r.enemies[1].partial=true
        else for i=1,N.Find.MAX do yes(N.Find.add(N.Main.find,"Seeker "..H.abc(i))) end end
        local before=table.concat(N.Main.find.names,","); N.Main.callReceive(r,"Birch Moss"); yes(N.CallUI.help)
        local line=#H.log(); N.CallUI.help:Click(); eq(table.concat(N.Main.find.names,","),before)
        if not partial then yes(table.concat(H.log(),"\n"):find("20",1,true)) end
    end
end)
test("Call: Dismiss and x only close; swapping dismiss id changes only its art path",function()
    local N=H.load(); bounty(); local U,T=N.CallUI,N.CallText; local e=U.event
    yes(U.dismiss); yes(rawget(U.dismiss,"art"),"dismiss image")
    eq(T.HELP,"help"); eq(T.DISMISS,"dismiss_a")
    eq(U.help.art.texture,"Interface\\AddOns\\LayerEnemies\\Media\\call-help.tga")
    eq(U.dismiss.art.texture,"Interface\\AddOns\\LayerEnemies\\Media\\call-dismiss-a.tga")
    for _,b in ipairs({U.help,U.dismiss}) do
        yes(b.art:IsShown()); no(b.label:IsShown()); eq(b.label:GetText(),"")
        eq(b.art.width,96); eq(b.art.height,24); eq(b.art.point[1],"CENTER")
    end
    local body,heading,help=U.body:GetText(),U.heading.texture,U.help.art.texture
    local click,generation=U.dismiss.scripts.OnClick,U.generation
    T.DISMISS="dismiss_b"; U.render()
    eq(U.dismiss.art.texture,"Interface\\AddOns\\LayerEnemies\\Media\\call-dismiss-b.tga")
    eq(U.help.art.texture,help); eq(U.body:GetText(),body); eq(U.heading.texture,heading)
    eq(U.dismiss.label:GetText(),""); no(U.dismiss.label:IsShown())
    eq(U.dismiss.scripts.OnClick,click); eq(U.generation,generation); eq(U.event,e)
    local before=#H.log(); U.dismiss:Click(); eq(#H.log(),before); eq(#N.Main.find.names,0); eq(#H.sent(),0)
    H.advance(20); bounty("Other Victim"); yes(U.closeButton); U.closeButton:Click(); no(popup(N))
end)
test("Call: nil button art requests no texture and shows exact English including alternate Close",function()
    for _,dismiss in ipairs({"dismiss_a","dismiss_b"}) do
        local N=H.load(); local U,T=N.CallUI,N.CallText
        T.HELP="help"; T.DISMISS=dismiss; T.help.art=nil; T[dismiss].art=nil
        U.create(); yes(rawget(U.help,"art"),"help image"); yes(rawget(U.dismiss,"art"),"dismiss image")
        local requests=0
        U.help.art.SetTexture=function() requests=requests+1 end
        U.dismiss.art.SetTexture=function() requests=requests+1 end
        bounty(); yes(popup(N)); eq(requests,0)
        no(U.help.art:IsShown()); no(U.dismiss.art:IsShown())
        yes(U.help.label:IsShown()); yes(U.dismiss.label:IsShown())
        eq(U.help.label:GetText(),"On my way"); eq(U.dismiss.label:GetText(),dismiss=="dismiss_a" and "Not now" or "Close")
    end
end)
test("Call: exact three heading IDs and body IDs exist with swappable button art",function()
    local N=H.load(); local T=N.CallText
    yes(T); eq(table.concat(T.HEADINGS,","),"H2,H1,H6"); eq(table.concat(T.BODIES,","),"B1,B2,B3,B4,B5,B6")
    for _,id in ipairs(T.HEADINGS) do yes(T[id].art); yes(T[id].latin); yes(T[id].en); no(T[id].latin:find("%d")) end
    for _,id in ipairs({T.HELP,T.DISMISS,"dismiss_b"}) do yes(T[id].art); yes(T[id].en); yes(T[id].latin) end
end)
test("Call: art off persists and enlarges Latin; nil or failing texture retains Latin",function()
    for _,mode in ipairs({"off","nil","throw"}) do
        local N=H.load(); yes(N.CallUI)
        if mode=="off" then SlashCmdList.LAYERENEMIES("call art off"); eq(LayerEnemiesDB.callArt,false)
        elseif mode=="nil" then for _,id in ipairs(N.CallText.HEADINGS) do N.CallText[id].art=nil end
        else N.CallUI.create(); N.CallUI.heading.SetTexture=function() error("missing") end end
        bounty(); yes(popup(N)); local U=N.CallUI; eq(U.latin:GetText(),N.CallText[U.headingId].latin)
        if mode~="throw" then no(U.heading:IsShown()); eq(U.latin.font[2],14) else eq(U.latin.font[2],10) end
        no(N.Main.error)
        if mode=="off" then N=H.load(LayerEnemiesDB); eq(LayerEnemiesDB.callArt,false); bounty(); no(N.CallUI.heading:IsShown()) end
    end
end)
test("Call: random heading and English body draw including B4 only through age 30",function()
    local N=H.load(); yes(N.Call.pick); local C,T=N.Call,N.CallText
    local h,b={},{ }
    for i=1,6 do local hid,bid=C.pick(30,function(n) return (i-1)%n+1 end); h[hid]=true; b[bid]=true end
    for _,id in ipairs(T.HEADINGS) do yes(h[id]) end
    for _,id in ipairs(T.BODIES) do yes(b[id]) end
    for i=1,6 do local _,bid=C.pick(31,function(n) return (i-1)%n+1 end); no(bid=="B4") end
    bounty(); N.CallUI.bodyId="B4"; H.advance(31); N.CallUI.render(); no(N.CallUI.bodyId=="B4")
end)
test("Call: template percent and space slots are literal and text passed to client stays Latin",function()
    local N=H.load(); local T=N.CallText; yes(T.format); yes(T.clean)
    eq(T.format("B1",{victim="Fir % Vale",killer="Cedar Moss",zone="Ashenvale"}),"Cedar Moss owes blood for Fir % Vale. Meet in Ashenvale.")
    eq(T.clean("Zo\195\171 \201\143"),"Zo\195\171 \201\143")
    eq(T.clean("A\201\144\216\167\240\159\152\128Z"),"A???Z")
    bounty(); N.CallUI.event.victim="Fir \216\167"; N.CallUI.render()
    eq(N.CallUI.victim:GetText(),"Fir ?")
end)

test("Call: tracked killer and popup share one sound for the same incoming death",function()
    local N=H.load(); N.Main.track("Cedar Vale"); local sounds=0; PlaySound=function() sounds=sounds+1 end
    bounty(); yes(popup(N)); eq(sounds,1); eq(#H.sent(),0); PlaySound=nil
end)
test("Call: pure admission refuses own split identity and unavailable identity too",function()
    local N=H.load(); UnitName=function() return "Birch","Moss" end
    receive(N,"Birch Moss"); no(popup(N)); eq(next(N.Main.call.victims),nil)
    UnitName=function() return nil end; receive(N,"Other Victim"); no(popup(N)); eq(next(N.Main.call.victims),nil)
end)
test("Call: off forgets the last displayed event as well as histories",function()
    local N=H.load(); bounty(); SlashCmdList.LAYERENEMIES("call off")
    eq(N.CallUI.event,nil); eq(next(N.Main.call.victims),nil)
end)
test("Call: dedupe boundary 60 enriches, 61 does not; rejected copies are not remembered",function()
    for _,delay in ipairs({60,61}) do
        local N=H.load(); receive(N,"Birch Moss",0,"gb",false); H.advance(delay)
        local e,action=receive(N,"BIRCH MOSS",0,"gb",true)
        eq(action,delay==60 and "enrich" or nil)
        eq(N.Main.call.victims["birch moss"].event.x,delay==60 and .425 or nil)
    end
end)
test("Call: all repeats stay within one shown frame and a bounded timer population",function()
    local N=H.load(); bounty(); local count=#H.frames()
    for i=1,100 do H.advance(20); bounty("Victim "..H.abc(i)); yes(popup(N)); eq(#H.frames(),count); yes(#H.timers()<10) end
    eq(#H.sent(),0); no(N.Main.error)
end)

test("Call: label art right anchors each row and value ends three pixels before its colon ink",function()
    local N=H.load(); bounty(); local U,T=N.CallUI,N.CallText
    yes(U.rows,"dedicated label rows")
    local expected={victim={inkLeft=53,offset=36.75},killer={inkLeft=74,offset=52.5},where={inkLeft=68,offset=48}}
    local bottom=0
    for _,key in ipairs({"victim","killer","where"}) do
        local row,value=U.rows[key],U[key]
        eq(row.width,196); eq(row.point[1],"TOPLEFT"); eq(row.point[2],U.frame)
        eq(row.point[3],"TOPLEFT"); eq(row.point[4],12)
        eq(row.art.texture,"Interface\\AddOns\\LayerEnemies\\Media\\call-"..key..".tga")
        eq(row.art.texture,T[key].art); yes(row.art:IsShown())
        eq(row.art.width,96); eq(row.art.height,24)
        eq(row.art.point[1],"TOPRIGHT"); eq(row.art.point[2],row)
        eq(row.art.point[3],"TOPRIGHT"); eq(row.art.point[4],0); eq(row.art.point[5],0)
        eq(value.justifyH,"RIGHT"); eq(value.width,100)
        eq(value.point[1],"TOPRIGHT"); eq(value.point[2],row.art); eq(value.point[3],"TOPLEFT")
        eq(value.point[4],expected[key].offset,key.." colon-aligned offset"); eq(value.point[5],-4)
        eq(T[key].inkLeft,expected[key].inkLeft,key.." source-pixel inkLeft")
        eq(value.point[4],T[key].inkLeft*96/128-3,key.." scaled inkLeft minus gap")
        yes(-row.point[5]>=bottom); yes(row.height>=24)
        bottom=-row.point[5]+row.height
    end
    yes(-U.body.point[5]>bottom,"English sentence is below the label rows")
    U.killer.GetStringHeight=function() return 72 end; U.render()
    yes(U.rows.killer.height>=76,"wrapped value is not clipped by a fixed-height row")
    yes(-U.rows.where.point[5]>=-U.rows.killer.point[5]+U.rows.killer.height)
end)
test("Call: nil label art shows English LTR at full width and never requests a texture",function()
    local N=H.load(); bounty(); local U,T=N.CallUI,N.CallText
    yes(U.rows,"dedicated label rows")
    local expected={victim="One of ours: Birch Moss",killer="Killer: Cedar Vale 60 ROGUE",where="Where: Ashenvale"}
    for _,key in ipairs({"victim","killer","where"}) do
        local row,value=U.rows[key],U[key]; local path=T[key].art; T[key].art=nil
        local requested=0; local original=row.art.SetTexture
        row.art.SetTexture=function() requested=requested+1 end
        U.render(); eq(requested,0); no(row.art:IsShown()); yes(value:IsShown())
        eq(value:GetText(),expected[key]); eq(value.justifyH,"LEFT"); eq(value.width,196)
        eq(value.point[1],"TOPLEFT"); eq(value.point[2],row); eq(value.point[3],"TOPLEFT")
        eq(value.point[4],0); eq(value.point[5],0)
        T[key].art=path; row.art.SetTexture=original; U.render()
        yes(row.art:IsShown()); eq(value.justifyH,"RIGHT"); eq(value.width,100)
    end
end)
test("Call: art off or every nil art requests no texture and restores English for labels and buttons",function()
    for _,mode in ipairs({"off","nil"}) do
        local N=H.load(); local U,T=N.CallUI,N.CallText; U.create(); yes(U.rows)
        local images={U.heading,U.help.art,U.dismiss.art}
        for _,key in ipairs({"victim","killer","where"}) do images[#images+1]=U.rows[key].art end
        local requests=0; for _,image in ipairs(images) do image.SetTexture=function() requests=requests+1 end end
        if mode=="off" then SlashCmdList.LAYERENEMIES("call art off")
        else for _,entry in pairs(T) do if type(entry)=="table" then entry.art=nil end end end
        bounty(); yes(popup(N)); eq(requests,0)
        for _,image in ipairs(images) do no(image:IsShown()) end
        eq(U.victim:GetText(),"One of ours: Birch Moss"); eq(U.killer:GetText(),"Killer: Cedar Vale 60 ROGUE")
        eq(U.where:GetText(),"Where: Ashenvale"); eq(U.help.label:GetText(),"On my way"); eq(U.dismiss.label:GetText(),"Not now")
        yes(U.help.label:IsShown()); yes(U.dismiss.label:IsShown())
        if mode=="off" then
            SlashCmdList.LAYERENEMIES("call art on"); U.render(); yes(requests>0)
            for _,image in ipairs(images) do yes(image:IsShown()) end
            eq(U.victim:GetText(),"Birch Moss"); eq(U.victim.justifyH,"RIGHT")
        end
    end
end)

-- Closing-review guards: keep each boundary independent of unrelated admission gates.
test("Call review: WOS proof must belong to the current epoch",function()
    local N=H.load(); local s=N.Main.store
    s.localSeen.probe={name="Cedar Vale",faction="opposite",epoch=s.serial-1,at=H.clock()}
    wos(); no(popup(N)); eq(next(N.Main.call.victims),nil)
    s.localSeen.probe.epoch=s.serial; wos(); yes(popup(N)); eq(#H.sent(),0)
end)
test("Call review: WOS proof cannot come from the future",function()
    local N=H.load(); local s=N.Main.store
    s.localSeen.probe={name="Cedar Vale",faction="opposite",epoch=s.serial,at=H.clock()+1}
    wos(); no(popup(N)); eq(next(N.Main.call.victims),nil)
    s.localSeen.probe.at=H.clock(); wos(); yes(popup(N)); eq(#H.sent(),0)
end)
test("Call review: classless GB needs independent local opposite proof",function()
    local N=H.load(); bounty(nil,nil,""); no(popup(N)); eq(next(N.Main.call.victims),nil)
    known(N); bounty(nil,nil,""); yes(popup(N)); eq(#H.sent(),0)
end)
test("Call review: killer cannot be our own identity",function()
    local N=H.load(); local r=record(0)
    r.enemies[1].name=N.Adapters.ownIdentity(); yes(r.enemies[1].name)
    N.Main.callReceive(r,"Birch Moss"); no(popup(N)); eq(next(N.Main.call.victims),nil)
    r.enemies[1].name="Cedar Vale"; N.Main.callReceive(r,"Birch Moss"); yes(popup(N)); eq(#H.sent(),0)
end)
for _,field in ipairs({"zone","killer"}) do
    test("Call review: enrichment refuses a different "..field,function()
        local N=H.load(); receive(N); local first=N.CallUI.event
        H.advance(1); local r=record(0,"gb",true)
        if field=="zone" then r.zone=200 else r.enemies[1].name="Other Enemy" end
        local _,action=N.Main.callReceive(r,"Birch Moss")
        eq(action,nil); eq(N.Main.call.current,first); eq(first.x,nil)
        eq(N.Main.call.victims["birch moss"].event,first); eq(#H.sent(),0)
    end)
end
test("Call review: an older event cannot replace a newer displayed event",function()
    local N=H.load(); receive(N); local first=N.CallUI.event
    H.advance(20); receive(N,"Other Victim",30)
    eq(N.CallUI.event,first); eq(N.Main.call.current,first)
    eq(N.Main.call.victims["other victim"],nil); eq(#H.sent(),0)
end)
test("Call review: invalid coordinates are removed as a pair",function()
    for _,field in ipairs({"x","y"}) do
        for _,bad in ipairs({-.1,1.1,math.huge,0/0,"bad"}) do
            local N=H.load(); local r=record(0,"gb",true); r[field]=bad
            N.Main.callReceive(r,"Birch Moss"); yes(popup(N))
            eq(N.CallUI.event.x,nil,field); eq(N.CallUI.event.y,nil,field)
            local points=waypoint(); N.CallUI.help:Click(); eq(#points,0); eq(#H.sent(),0)
        end
    end
end)
test("Call review: history cap is the fixed contract of 64 entries",function()
    local N=H.load(); local history=N.Main.call.victims
    eq(N.Call.MAX,64)
    for i=1,64 do history["filler"..i]={at=H.clock()-i/100,event={}} end
    receive(N); eq(N.Safe.count(history),64); eq(history.filler64,nil)
    yes(history["birch moss"]); eq(#H.sent(),0)
end)
test("Call review: explicit full false is not a Find identity",function()
    local N=H.load(); local r=record(0); r.enemies[1].full=false
    N.Main.callReceive(r,"Birch Moss"); yes(popup(N)); eq(N.CallUI.event.full,false)
    N.CallUI.help:Click(); eq(#N.Main.find.names,0); eq(#H.sent(),0)
end)
test("Call review: old Help closure cannot act after a replacement render",function()
    local N=H.load(); bounty(); local click=N.CallUI.help.scripts.OnClick
    H.advance(20); local r=record(0,"gb",true); r.zone=200; r.enemies[1].name="Other Enemy"
    N.Main.callReceive(r,"Other Victim"); yes(popup(N)); local shown=N.CallUI.event
    local points=waypoint(); local before=#H.log()
    click(); eq(#points,0); eq(#H.log(),before); eq(#N.Main.find.names,0)
    yes(popup(N)); eq(N.CallUI.event,shown)
    N.CallUI.help:Click(); eq(#points,1); eq(points[1].uiMapID,200)
    eq(N.Main.find.names[1],"Other Enemy"); eq(#H.sent(),0)
end)
test("Call review: Help rechecks instance before the next event or timer",function()
    local N=H.load(); bounty(); local points=waypoint(); local before=#H.log()
    H.instance(true); N.CallUI.help:Click()
    eq(#points,0); eq(#H.log(),before); eq(#N.Main.find.names,0); eq(#H.sent(),0)
end)
test("Call review: waypoint uses a displayed map other than the local map",function()
    local N=H.load(); local r=record(0,"gb",true); r.zone=200
    N.Main.callReceive(r,"Birch Moss"); local points,_,can=waypoint(); N.CallUI.help:Click()
    eq(#points,1); eq(points[1].uiMapID,200); eq(can[1],200)
    eq(points[1].position.x,.425); eq(points[1].position.y,.61); eq(#H.sent(),0)
end)
test("Call review: Find accepts realm-qualified two-word killers",function()
    for _,suffix in ipairs({"-Stormrage","-1234"}) do
        local N=H.load(); local r=record(0); r.enemies[1].name="Cedar Vale"..suffix
        N.Main.callReceive(r,"Birch Moss"); yes(popup(N)); yes(N.CallUI.event.full)
        N.CallUI.help:Click(); eq(#N.Main.find.names,1); eq(N.Main.find.names[1],"Cedar Vale"..suffix); eq(#H.sent(),0)
    end
end)
for _,key in ipairs({"victim","killer","where"}) do
    test("Call review: "..key.." value and row grow with measured text height",function()
        for _,art in ipairs({true,false}) do
            local N=H.load({callArt=art}); bounty(); local U=N.CallUI
            U[key].GetStringHeight=function() return 72 end; U.render()
            eq(U[key].height,72,key.." FontString must not clip")
            eq(U.rows[key].height,art and 76 or 72,key.." row must contain text")
            local bottom=0
            for _,name in ipairs({"victim","killer","where"}) do
                local row=U.rows[name]; yes(-row.point[5]>=bottom+4,name.." below previous row")
                bottom=-row.point[5]+row.height
            end
            yes(-U.body.point[5]>=bottom+4,"body below detail rows"); eq(#H.sent(),0)
        end
    end)
end
