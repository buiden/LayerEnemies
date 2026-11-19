-- PR 1: exercise the real adapters, scan driver, Find projection and UI.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function snapshot(v)
    if type(v)~="table" then return type(v)..":"..tostring(v) end
    local out={}; for k,value in pairs(v) do out[#out+1]=tostring(k).."="..snapshot(value) end
    table.sort(out); return "{"..table.concat(out,",").."}"
end
local function ready(names)
    _G.C_Club=nil; _G.BNGetNumFriends=nil
    local N=H.load({tracked=names or {"Cedar Vale"},share=false,findShare=false,netConsent="guild"})
    H.advance(90)
    N.Main.presenceJob=nil; N.Main.presenceAt=nil
    _G.Enum.ClubType={BattleNet=0,Character=1,Guild=2,Other=3}
    _G.Enum.PvPFaction={Horde=0,Alliance=1,Neutral=2}
    _G.Enum.ClubMemberPresence={Unknown=0,Online=1,OnlineMobile=2,Offline=3,Away=4,Busy=5}
    _G.WOW_PROJECT_ID=11
    local data={clubs={{clubId="504",clubType=0}},ids={1},member={name="Cedar Vale",zone="Stranglethorn Vale",faction=0,presence=1,guid="Player-1-cedar"},friends={}}
    local calls={clubs=0,ids=0,members=0,friends=0,count=0,forbidden=0}
    local function owner()
        local i=3
        while debug.getinfo(i,"S") do
            local info=debug.getinfo(i,"S")
            if info.what~="C" then eq(info.source,"@LayerEnemies/Adapters.lua","presence API owner"); return end
            i=i+1
        end
    end
    _G.C_Club={
        GetSubscribedClubs=function() owner(); calls.clubs=calls.clubs+1; return data.clubs end,
        GetClubMembers=function(id) owner(); calls.ids=calls.ids+1; return data.ids end,
        GetMemberInfo=function(id,member) owner(); calls.members=calls.members+1
            return type(data.member)=="function" and data.member(id,member) or data.member end,
        SetClubPresenceSubscription=function() calls.forbidden=calls.forbidden+1 end,
    }
    _G.BNGetNumFriends=function() owner(); calls.count=calls.count+1; return #data.friends end
    _G.C_BattleNet.GetFriendAccountInfo=function(i) owner(); calls.friends=calls.friends+1; return data.friends[i] end
    data.member.bnetAccountId=42
    data.game={characterName="Cedar Vale",realmName="Test Realm",areaName="Stranglethorn Vale",
        factionName="Horde",playerGuid="Player-1-cedar",isOnline=true,clientProgram="WoW"}
    calls.accounts=0
    _G.C_BattleNet.GetAccountInfoByID=function(id)
        owner(); calls.accounts=calls.accounts+1
        if type(data.game)~="function" then eq(id,42,"only supplied account ID") end
        return {gameAccountInfo=type(data.game)=="function" and data.game(id) or data.game}
    end
    local function refuse() calls.forbidden=calls.forbidden+1; error("presence must never send") end
    N.Wire.send=refuse; N.Main.offerRelay=refuse; _G.SendChatMessage=refuse; _G.BNSendGameData=refuse
    _G.C_BattleNet.SendGameData=refuse; _G.C_FriendList.SendWho=refuse
    N.Main.alertSound=refuse
    return N,data,calls
end
local function scan(N)
    yes(type(N.Main.presenceScan)=="function","presence scan driver exists")
    N.Main.presenceScan(true)
    for _=1,500 do
        if not N.Main.presenceJob then break end
        H.advance(.001)
    end
    no(N.Main.presenceJob,"bounded scan completes"); no(N.Main.error)
end
local function row(N) return N.Main.findRows()[1] end
local function friend(overrides)
    local game={characterName="Cedar Vale",realmName="Test Realm",areaName="Stranglethorn Vale",
        factionName="Horde",playerGuid="Player-1-cedar",isOnline=true,wowProjectID=11}
    for k,v in pairs(overrides or {}) do game[k]=v end
    return setmetatable({gameAccountInfo=game},{__index=function() error("account field must not be read") end})
end
local function notices()
    local out={}; for _,s in ipairs(H.log()) do if s:find("online (",1,true) then out[#out+1]=s end end; return out
end

test("Presence: club character comes from account not member display name",function()
    local N,data,calls=ready(); data.member={name="Cedar#1234",presence=1,bnetAccountId=42}
    scan(N); yes(row(N).presence,"BattleTag member resolves to tracked character"); eq(calls.accounts,1)
    eq(row(N).presence.zone,"Stranglethorn Vale"); eq(calls.forbidden,0)
    N,data=ready(); data.game.characterName="Other Enemy"
    scan(N); eq(row(N).presence,nil,"member display namesake is never a character match")
    N,data=ready({"Cedar-OtherRealm"}); data.game.characterName="Cedar"
    data.game.realmName=nil; data.game.realmDisplayName="Other Realm"
    scan(N); yes(row(N).presence,"display realm fallback is normalized")
end)

test("Presence: only online community members resolve Battle.net accounts",function()
    local N,data,calls=ready(); data.ids={}
    for i=1,1000 do data.ids[i]=i end
    data.member=function(_,id) return {presence=id%10==0 and 1 or 3,bnetAccountId=42} end
    N.Main.presenceScan(true); H.advance(.001)
    eq(calls.members,50,"member work budget unchanged")
    eq(calls.accounts,5,"only five online members resolve in the first tick")
    for _=1,30 do if not N.Main.presenceJob then break end; H.advance(.001) end
    eq(N.Main.presenceJob,nil); eq(calls.members,1000)
    eq(calls.accounts,100,"900 offline members never look up an account")
    yes(row(N).presence,"online members still contribute")
    for _,presence in ipairs({0,2,3,6,false,H.secret,"Online"}) do
        N,data,calls=ready(); data.member.presence=presence; scan(N)
        eq(calls.accounts,0,"non-online or unreadable member skips account resolution")
        eq(row(N).presence,nil)
    end
    for _,presence in ipairs({1,4,5}) do
        N,data,calls=ready(); data.member.presence=presence; scan(N)
        eq(calls.accounts,1,"Online Away and Busy still resolve"); yes(row(N).presence)
    end
    N,data,calls=ready(); scan(N); yes(row(N).presence)
    data.member.presence=3; H.time(101); scan(N)
    eq(calls.accounts,1,"offline reread does not repeat account lookup")
    eq(row(N).presence,nil,"offline reread still withdraws previous evidence")
end)

test("Presence: account resolution unavailable secret incomplete and non WoW fail silent",function()
    for _,mode in ipairs({"missing","throw","secret","index","gameMissing"}) do
        local N,data=ready()
        if mode=="missing" then C_BattleNet.GetAccountInfoByID=nil
        else C_BattleNet.GetAccountInfoByID=function()
            if mode=="throw" then error("unavailable") end
            if mode=="secret" then return H.secret end
            if mode=="index" then return setmetatable({},{__index=function() error("unreadable") end}) end
            return {}
        end end
        scan(N); eq(row(N).presence,nil,mode.." resolution cannot use member name")
    end
    for _,field in ipairs({"characterName","realmName","areaName","factionName","isOnline","clientProgram"}) do
        for _,mode in ipairs({"nil","secret","throw"}) do
            local N,data=ready(); data.game[field]=mode=="secret" and H.secret or nil
            if mode=="throw" then setmetatable(data.game,{__index=function(_,k) if k==field then error("unreadable") end end}) end
            scan(N); eq(row(N).presence,nil,field.." "..mode)
        end
    end
    for _,field in ipairs({"bnetAccountId","presence"}) do
        for _,value in ipairs({false,H.secret,""}) do
            local N,data=ready(); data.member[field]=value; scan(N); eq(row(N).presence,nil,field)
        end
    end
    for _,change in ipairs({{isOnline=false},{clientProgram="D3"},{factionName="Alliance"},
        {characterName="Cedar-RealmA",realmName="RealmB"}}) do
        local N,data=ready({"Cedar-RealmA","Cedar Vale"}); for k,v in pairs(change) do data.game[k]=v end
        scan(N); eq(next(N.Main.find.presence),nil,"online WoW opposite character required")
    end
end)

test("Presence: friends use only online characters in this project and cap 200",function()
    local N,data,calls=ready(); data.clubs={}; data.friends={friend()}
    scan(N); yes(row(N).presence,"friend location"); eq(row(N).status,"online (friend)"); eq(calls.forbidden,0)
    eq(N.Main.presenceStats.zones,0,"friend zones cannot masquerade as community availability")
    for _,overrides in ipairs({{isOnline=false},{isOnline=H.secret},{wowProjectID=12},{wowProjectID=H.secret},
        {characterName=H.secret},{realmName=H.secret},{areaName=H.secret},{factionName=H.secret},{playerGuid=H.secret},
        {characterName=""},{realmName=""},{areaName=""},{factionName=""},{factionName="Alliance"}}) do
        N,data,calls=ready(); data.clubs={}; data.friends={friend(overrides)}; scan(N)
        eq(row(N).presence,nil,"invalid friend"); eq(calls.forbidden,0)
    end
    N,data,calls=ready(); data.clubs={}; for i=1,201 do data.friends[i]=friend() end
    scan(N); eq(calls.friends,200,"friend cap")
end)

test("Presence: untracked offline mobile unknown and blank rows store nothing",function()
    for _,change in ipairs({{characterName="Other Enemy"},{presence=0},{presence=2},{presence=3},{areaName=""},{factionName="Alliance"},{factionName="Neutral"}}) do
        local N,data,calls=ready(); for k,v in pairs(change) do
            if k=="presence" then data.member[k]=v else data.game[k]=v end
        end
        if change.presence then
            eq(N.Presence.accept({name="Cedar Vale",zone="Ashenvale",faction="Horde",presence=change.presence},"community"),nil,
                "pure presence admission independently refuses non-online members")
        end
        scan(N); eq(next(N.Main.find.presence),nil); eq(next(N.Main.presenceShared),nil); eq(calls.forbidden,0)
    end
    for _,p in ipairs({1,4,5}) do local N,data=ready(); data.member.presence=p; scan(N); yes(row(N).presence) end
end)

test("Presence: secret fields refuse exactly one row and diagnostic has no names",function()
    for _,key in ipairs({"characterName","realmName","areaName","factionName","isOnline","clientProgram","playerGuid"}) do
        local N,data=ready(); data.game[key]=H.secret; scan(N)
        eq(next(N.Main.find.presence),nil); yes(N.Main.presenceStats,"counts available")
        eq(N.Main.presenceStats.refused,1); eq(N.Main.presenceStats.secret,true)
        SlashCmdList.LAYERENEMIES("presence")
        local text=H.log()[#H.log()]; yes(text:find("members read: 1",1,true)); yes(text:find("secret: yes",1,true))
        no(text:find("Cedar",1,true)); no(text:find("Stranglethorn",1,true))
    end
end)

test("Presence: missing erroring and secret APIs or tables are silent",function()
    for _,mode in ipairs({"missing","throw","secret","index"}) do
        for _,field in ipairs({"GetSubscribedClubs","GetClubMembers","GetMemberInfo"}) do
            local N,data,calls=ready()
            C_Club[field]=mode=="missing" and nil or function()
                if mode=="throw" then error("unavailable") end
                if mode=="secret" then return H.secret end
                return setmetatable({},{__index=function() error("unreadable field") end})
            end
            scan(N); eq(next(N.Main.find.presence),nil); eq(calls.forbidden,0)
        end
        local N,data=ready(); data.clubs={}; data.friends={friend()}
        C_BattleNet.GetFriendAccountInfo=mode=="missing" and nil or function()
            if mode=="throw" then error("unavailable") end
            if mode=="secret" then return H.secret end
            return setmetatable({},{__index=function() error("unreadable field") end})
        end
        scan(N); eq(next(N.Main.find.presence),nil)
    end
    for _,key in ipairs({"characterName","areaName","factionName"}) do
        for _,mode in ipairs({"nil","throw"}) do
            local N,data=ready(); data.game[key]=nil
            if mode=="throw" then setmetatable(data.game,{__index=function(_,k) if k==key then error("unreadable") end end}) end
            scan(N); eq(row(N).presence,nil)
        end
    end
end)

test("Presence: reread offline or non WoW drops personal and shared evidence immediately",function()
    for _,route in ipairs({"community","friend"}) do
        for _,mode in ipairs({"offline","nonWoW","missingCharacter"}) do
            local N,data=ready(); if route=="friend" then data.clubs={}; data.friends={friend()} end
            scan(N); yes(row(N).presence,"seed presence before transition")
            N.Find.report(N.Main.find,{sender="Birch Scout",zone=100,at=H.time(),enemies={{name="Cedar Vale"}},source="spy"})
            if route=="community" then
                if mode=="offline" then data.member={presence=3} end
                if mode=="nonWoW" then data.game={isOnline=true,clientProgram="D3"} end
                if mode=="missingCharacter" then data.game.characterName=nil end
            else
                if mode=="offline" then data.friends[1]={gameAccountInfo={isOnline=false}} end
                if mode=="nonWoW" then data.friends[1]={gameAccountInfo={isOnline=true,wowProjectID=12}} end
                if mode=="missingCharacter" then data.friends[1].gameAccountInfo.characterName=nil end
            end
            H.time(101); scan(N); eq(row(N).presence,nil,route.." "..mode.." clears before TTL")
            yes(row(N).canAsk,"sighting is not removed with presence")
        end
    end
    local N,data=ready({"Personal Enemy"}); local hash=N.Watch.hash("Cedar Vale")
    N.Watch.receive(N.Main.watch,"T|1|aa|1|1|"..hash,"Birch Scout",H.time()); scan(N)
    yes(N.Main.presenceShared[hash],"seed shared presence")
    data.game.isOnline=false; H.time(101); scan(N); eq(N.Main.presenceShared[hash],nil,"shared offline removed")
    data.game.isOnline=true; scan(N); yes(N.Main.presenceShared[hash]); eq(#notices(),1,"offline cannot reset alert cooldown")
end)

test("Presence: unread members keep TTL and another source keeps its own evidence",function()
    local N,data=ready(); scan(N); local at=N.Main.find.presence["Cedar Vale"].at
    data.ids={}; H.time(101); scan(N); yes(row(N).presence,"not read is not offline")
    H.time(at+659); yes(row(N).presence); H.time(at+660); eq(row(N).presence,nil,"unread still expires at 660")
    N,data=ready(); data.friends={friend()}; scan(N); eq(row(N).presence.route,"friend")
    data.member.presence=3; data.friends={}; H.time(101); scan(N)
    eq(row(N).presence.route,"friend","community withdrawal cannot delete the friend read")
end)

test("Presence: diagnostic separates unresolved zoneless same faction and unmatched members",function()
    for _,mode in ipairs({"unresolved","zoneless","sameFaction","unmatched","matched"}) do
        local N,data=ready()
        if mode=="unresolved" then C_BattleNet.GetAccountInfoByID=nil end
        if mode=="zoneless" then data.game.areaName=nil end
        if mode=="sameFaction" then data.game.factionName="Alliance" end
        if mode=="unmatched" then data.game.characterName="Other Enemy" end
        scan(N); SlashCmdList.LAYERENEMIES("presence"); local text=H.log()[#H.log()]
        local resolved=mode=="unresolved" and 0 or 1
        local zone=(mode=="unresolved" or mode=="zoneless") and 0 or 1
        local opposite=(mode=="unmatched" or mode=="matched") and 1 or 0
        local matches=mode=="matched" and 1 or 0
        yes(text:find("members read: 1",1,true),mode.." member attempted")
        yes(text:find("resolved to a character: "..resolved,1,true),mode.." resolution count")
        yes(text:find("with a zone: "..zone,1,true),mode.." zone count")
        yes(text:find("opposite faction: "..opposite,1,true),mode.." faction count")
        yes(text:find("matches: "..matches,1,true),mode.." match count")
        no(text:find("Cedar",1,true)); no(text:find("Enemy",1,true)); no(text:find("Stranglethorn",1,true))
    end
    local N,data,calls=ready(); N.Main.presenceStats=nil
    SlashCmdList.LAYERENEMIES("presence"); local text=H.log()[#H.log()]
    yes(text:find("resolved to a character: 0",1,true)); yes(text:find("opposite faction: 0",1,true))
    eq(calls.clubs+calls.members+calls.accounts+calls.friends,0,"diagnostic does not scan")
end)

test("Presence: expiry boundary future clocks and remove clear session state",function()
    local N,data=ready(); scan(N); local at=N.Main.find.presence["Cedar Vale"].at
    H.time(at+659); yes(row(N).presence); H.time(at+660); eq(row(N).presence,nil)
    H.time(100); scan(N); H.time(99); eq(row(N).presence,nil)
    H.time(100); scan(N); N.Main.track("Cedar Vale",true); eq(next(N.Main.find.presence),nil)
    N.Main.track("Cedar Vale"); scan(N); N.Main.track(nil); eq(next(N.Main.find.presence),nil)
end)

test("Presence: real sighting and OpenMap retain their status and Ask target",function()
    local N=ready()
    N.Find.report(N.Main.find,{sender="Birch Scout",zone=100,at=100,enemies={{name="Cedar Vale"}},source="spy"})
    local before=row(N); yes(before.canAsk); scan(N)
    eq(row(N).status,before.status); eq(row(N).canAsk,true); eq(row(N).spotter,"Birch Scout"); yes(row(N).presence)
    local N=ready(); N.Main.find.places["Cedar Vale"]={map=100,x=.4,y=.5,at=100,route="GUILD"}
    scan(N); eq(row(N).status,"shared position"); eq(row(N).canAsk,false); yes(row(N).presence)
end)

test("Presence: no roster adapters with empty Find combat instance or unknown safety",function()
    for _,mode in ipairs({"empty","combat","instance","unknownCombat","unknownInstance"}) do
        local N,data,calls=ready(mode=="empty" and {} or nil)
        if mode=="combat" then H.combat(true) end
        if mode=="instance" then H.instance(true) end
        if mode=="unknownCombat" then InCombatLockdown=function() return H.secret end end
        if mode=="unknownInstance" then IsInInstance=function() error("not ready") end end
        scan(N); eq(calls.clubs+calls.ids+calls.members+calls.friends+calls.count,0,mode)
    end
end)

test("Presence: fifty per tick thousand per club twenty clubs and guild exclusion",function()
    local N,data,calls=ready(); data.ids={}; for i=1,1001 do data.ids[i]=i end
    N.Main.presenceScan(true); eq(calls.members,0,"queued not inline")
    H.advance(.001); eq(calls.members,50,"per tick")
    H.combat(true); H.advance(.001); eq(calls.members,50,"cancel mid scan"); eq(N.Main.presenceJob,nil)
    H.combat(false); scan(N); eq(calls.members,1050,"1000 member cap")
    N,data,calls=ready(); data.clubs={}; for i=1,21 do data.clubs[i]={clubId=tostring(i),clubType=0} end
    scan(N); eq(calls.ids,20,"club cap"); eq(calls.members,20)
    for _,kind in ipairs({1,2,3}) do
        N,data,calls=ready(); data.clubs[1].clubType=kind; scan(N); eq(calls.ids,0); eq(calls.members,0)
    end
end)

test("Presence: qualified realm stays exact and bare name matches any realm",function()
    local N,data=ready({"Cedar-RealmA"}); data.game.characterName="Cedar"; data.game.realmName="RealmB"; scan(N); eq(row(N).presence,nil)
    data.game.realmName="RealmA"; scan(N); yes(row(N).presence)
    N,data=ready({"Cedar"}); data.game.characterName="Cedar"; data.game.realmName="Realm B"; scan(N); yes(row(N).presence,"bare tracker accepts foreign realm")
    N,data=ready({"Cedar-RealmA"}); data.game.characterName="Cedar"; data.game.realmName=nil; scan(N); eq(row(N).presence,nil,"unknown realm cannot confirm foreign")
end)

test("Presence: per name 600 second silent alert uses shared burst throttle",function()
    local N,data,calls=ready(); scan(N); eq(#notices(),1,"first notice")
    H.time(699); data.game.areaName="Ashenvale"; scan(N); eq(#notices(),1,"zone change cannot bypass 600s")
    H.time(700); scan(N); eq(#notices(),2); eq(calls.forbidden,0,"no sound")
    N,data,calls=ready({"Enemy Alpha","Enemy Bravo","Enemy Charlie","Enemy Delta"}); data.ids={1,2,3,4}
    data.member=function(_,id) return {presence=1,bnetAccountId=id} end
    data.game=function(id) return {characterName=N.Main.find.names[id],realmName="Test Realm",areaName="Stranglethorn Vale",
        factionName="Horde",isOnline=true,clientProgram="WoW"} end
    scan(N); eq(#notices(),3,"existing three-line burst limit"); eq(N.Main.find.alertWindow.more,1)
    eq(calls.forbidden,0)
end)

test("Presence: Find switches and window opens share one force per 60 seconds",function()
    local N,data,calls=ready(); N.UI.frame:Show(); N.UI.select("find"); H.advance(.001)
    eq(calls.clubs,1,"first Find open forces a scan")
    for _=1,10 do
        N.UI.select("friendly"); N.UI.select("find"); H.advance(.001)
        N.UI.frame:Hide(); N.UI.frame:Show(); H.advance(.001)
    end
    eq(calls.clubs,1,"tab and window spam cannot bypass 60s")
    H.time(159.999); N.UI.select("friendly"); N.UI.select("find"); H.advance(.0001)
    eq(calls.clubs,1,"before exact boundary")
    H.time(160); N.UI.select("friendly"); N.UI.select("find"); H.advance(.001)
    eq(calls.clubs,2,"exact 60s boundary refreshes")
    H.time(220); H.combat(true); N.UI.select("friendly"); N.UI.select("find"); H.advance(.001)
    eq(calls.clubs,2,"unsafe open does no work")
    H.combat(false); N.UI.select("friendly"); N.UI.select("find"); H.advance(.001)
    eq(calls.clubs,3,"refused safety scan does not spend refresh allowance")
end)

test("Presence: automatic 300s cadence and Find opening refresh without overlap",function()
    local N,data,calls=ready(); N.Main.poll(); H.advance(.001); eq(calls.clubs,1)
    H.time(399); N.Main.poll(); eq(calls.clubs,1); H.time(400); N.Main.poll(); H.advance(.001); eq(calls.clubs,2)
    N.UI.frame:Show(); N.UI.select("find"); H.advance(.001); eq(calls.clubs,3,"Find tab opens")
    N.UI.frame:Hide(); N.UI.frame:Show(); H.advance(.001); eq(calls.clubs,3,"Find reopen is rate limited")
    H.time(461); N.UI.frame:Hide(); N.UI.frame:Show(); H.advance(.001); eq(calls.clubs,4,"Find window reopens after allowance")
    data.ids={}; for i=1,101 do data.ids[i]=i end
    N.Main.presenceScan(true); N.Main.presenceScan(true); eq(calls.clubs,5,"coalesced scan")
    H.instance(true); H.advance(.001); eq(N.Main.presenceJob,nil,"cancel instance")
end)

test("Presence: UI and slash text show zone age and hide stale pooled line",function()
    local N,data=ready(); scan(N); N.UI.frame:Show(); N.UI.select("find"); H.advance(.001); N.UI.render()
    local card=N.UI.pool[1]; yes(card.presence,"presence font exists"); yes(card.presence:IsShown())
    yes(card.presence:GetText():find("online (community): Stranglethorn Vale",1,true))
    yes(card.presence:GetText():find(" s ago",1,true)); no(card.ask:IsShown(),"presence-only Ask hidden")
    yes(N.Main.findText(row(N)):find("Stranglethorn Vale",1,true)); yes(N.UI.findTitle:GetText():find("1 located",1,true))
    local bottom= -card.presence.point[5]+card.presence.height
    yes(bottom<=card.height-24,"presence line fits above buttons")
    data.game.areaName=""; H.time(800); N.UI.render(); no(card.presence:IsShown(),"pooled stale line hidden")
end)

test("Presence: measured presence cards keep several per page without overlap",function()
    local N=ready(); local U=N.UI
    local rows={{name="Cedar Vale"},{name="Birch Moss"},{name="Elm Grove"},
        {name="Ash Reed"},{name="Oak Brook"},{name="Pine Wood"}}
    N.Main.findRows=function() return rows end
    U.frame:Show(); U.select("find")
    local normalHeight=U.pool[1]:GetHeight()
    for _,zone in ipairs({"Ashenvale","The Very Long Region around the Ruins of an Ancient Kingdom"}) do
        for i,r in ipairs(rows) do r.presence={route=i%2==0 and "friend" or "community",zone=zone,age=3} end
        U.offset=0; U.render()
        local reached={}
        for page=1,#rows do
            local visible,bottom=0,0
            for _,card in ipairs(U.pool) do if card:IsShown() then
                visible=visible+1; reached[card.tracked]=true
                local top=-card.point[5]
                yes(top>=bottom,"presence cards never overlap")
                bottom=top+card:GetHeight()
                yes(bottom<=U.body:GetHeight(),"presence card fits inside page")
                yes(card.presence:IsShown()); eq(card.sub:GetText(),"")
                eq(card.presence:GetHeight(),math.ceil(card.presence:GetStringHeight()),"presence box is its measured height")
                yes(card:GetHeight()<=normalHeight+card.presence:GetHeight()-12,"no fixed presence-only height surcharge")
                yes(-card.presence.point[5]+card.presence:GetHeight()<=card:GetHeight()-24,"presence stays above Clear")
                no(card.ask:IsShown(),"presence cannot create an action")
            end end
            yes(visible>=2,"several presence cards on every full page")
            if zone=="Ashenvale" then eq(visible,3,"one-line presence cards page like normal cards") end
            U.body.scripts.OnMouseWheel(nil,-1)
        end
        for _,r in ipairs(rows) do yes(reached[r.name],"all presence cards reachable") end
    end
    for _,r in ipairs(rows) do r.presence=nil end
    U.render(); eq(U.pool[1]:GetHeight(),normalHeight); no(U.pool[1].presence:IsShown())
end)

test("Presence: invalid friend realm never falls back to a bare character",function()
    local N,data=ready({"Cedar-RealmA"}); data.clubs={}
    data.friends={friend({characterName="Cedar-RealmA",realmName="RealmB"})}
    scan(N); eq(row(N).presence,nil,"contradictory realm refused")
end)

test("Presence: guild watch hash matches are session-only possible rows and withdraw",function()
    local N,data,calls=ready({"Personal Enemy"})
    local hash=N.Watch.hash("Cedar Vale")
    yes(N.Watch.receive(N.Main.watch,"T|1|aa|1|1|"..hash,"Birch Scout",H.time()))
    scan(N)
    local found
    for _,r in ipairs(N.Main.findRows()) do if r.name=="Cedar Vale-TestRealm" then found=r end end
    yes(found,"guild tracked presence shown"); yes(found.guildTracked,"hash match labelled possible")
    eq(found.presence.zone,"Stranglethorn Vale"); eq(found.canAsk,false); eq(calls.forbidden,0)
    eq(#LayerEnemiesDB.tracked,1); eq(next(N.Main.find.known.pairs or {}),nil)
    N.Watch.receive(N.Main.watch,"T|1|ab|0|0|","Birch Scout",H.time())
    eq(#N.Main.findRows(),1,"withdrawn hash removes row")
    N.Watch.receive(N.Main.watch,"T|1|ac|1|1|"..hash,"Birch Scout",H.time())
    scan(N); eq(#notices(),1,"withdrawal cannot reset presence alert cooldown")
end)

test("Presence: shared lists alone do not trigger an empty personal Find scan",function()
    local N,data,calls=ready({})
    N.Watch.receive(N.Main.watch,"T|1|aa|1|1|"..N.Watch.hash("Cedar Vale"),"Birch Scout",H.time())
    scan(N); eq(calls.clubs+calls.members+calls.count,0)
end)

test("Presence: malformed names and throwing pure row fields fail silently",function()
    for _,name in ipairs({"x", "Bad|Name", "Name-Realm!", "Name with three", string.rep("X",101), "\255"}) do
        local N,data=ready(); data.game.characterName=name; scan(N); eq(next(N.Main.find.presence),nil)
    end
    local N=ready()
    local ok,result=pcall(N.Presence.accept,setmetatable({},{__index=function() error("unreadable") end}),"community")
    eq(ok,true,"pure reader fails silent"); eq(result,nil)
end)

test("Presence: pure bounds and adapter field allowlists",function()
    local N,data=ready()
    local base={name="x",zone="z",faction="Horde",presence=1}
    yes(N.Presence.accept(base,"community"),"one byte accepted by pure contract")
    base.name=string.rep("a",100); base.zone=string.rep("z",120); yes(N.Presence.accept(base,"community"))
    base.name=string.rep("a",101); eq(N.Presence.accept(base,"community"),nil)
    base.name="x"; base.zone=string.rep("z",121); eq(N.Presence.accept(base,"community"),nil)
    base.zone="z"; base.faction=nil; eq(N.Presence.accept(base,"community"),nil)
    base.faction="Horde"; eq(N.Presence.accept(base,"who"),nil)
    setmetatable(data.member,{__index=function(_,k) error("not permitted: "..k) end})
    -- 1.2.4: the class token and level are read too (they travel with the guild friend share)
    data.game.classFilename="WARRIOR"; data.game.characterLevel=60
    setmetatable(data.game,{__index=function(_,k) error("not permitted game field: "..k) end})
    scan(N); yes(row(N).presence,"reads only allowed community fields")
    local copied=row(N).presence; copied.zone="changed"; eq(row(N).presence.zone,"Stranglethorn Vale","projection does not alias memory")
end)

test("Presence: absent namespaces counts project and own faction fail closed",function()
    for _,mode in ipairs({"clubs","friends","count","project","own"}) do
        local N,data,calls=ready()
        if mode=="clubs" then C_Club=nil
        else
            data.clubs={}; data.friends={friend()}
            if mode=="friends" then C_BattleNet=nil end
            if mode=="count" then BNGetNumFriends=nil end
            if mode=="project" then WOW_PROJECT_ID=nil end
            if mode=="own" then UnitFactionGroup=function() return H.secret end end
        end
        scan(N); eq(row(N).presence,nil); eq(calls.forbidden,0)
    end
end)

test("Presence: cancel stale queued work on empty list and restart",function()
    local N,data,calls=ready(); N.Main.presenceScan(true)
    N.Main.track(nil); H.advance(.001); eq(calls.members,0); eq(N.Main.presenceJob,nil)
    N.Main.track("Cedar Vale"); N.Main.presenceScan(true); H.advance(.001); yes(row(N).presence)
    eq(calls.members,1); eq(calls.forbidden,0)
end)

test("Presence: tracked community tracer has zone and no action or send",function()
    local N,data,calls=ready(); local saved=snapshot(LayerEnemiesDB)
    scan(N)
    eq(row(N).presence.zone,"Stranglethorn Vale"); eq(row(N).presence.route,"community")
    eq(row(N).status,"online (community)"); eq(row(N).canAsk,false)
    eq(row(N).layer,nil); eq(row(N).spotter,nil); eq(calls.forbidden,0)
    eq(snapshot(LayerEnemiesDB),saved,"session only"); eq(calls.members,1)
end)
