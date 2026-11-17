-- Composition checks for the five-level feature stack; no donor or live client.
local H=...
local eq,yes,no=H.eq,H.yes,H.no
local function test(name,fn)
    H.test(name,function()
        local ok,err=xpcall(fn,debug.traceback)
        if not ok then error(err) end
    end)
end
local function snapshot(value)
    if type(value)~="table" then return type(value)..":"..tostring(value) end
    local out={}
    for key,v in pairs(value) do out[#out+1]=snapshot(key).."="..snapshot(v) end
    table.sort(out); return "{"..table.concat(out,",").."}"
end

test("Stack: slash commands route independently without shadowing",function()
    local N=H.load(); local M=N.Main; local calls={}
    local methods={"presenceStatus","track","setFindShare","setFindNotice","hopAnyStop","hopAny",
        "setAutoHop","net","hopHost","hopIndex","hosts","findHosts","text"}
    for _,name in ipairs(methods) do
        local key=name
        M[key]=function(...) calls[#calls+1]={key,...} end
    end
    for _,case in ipairs({
        {"presence","presenceStatus"},{"find","track"},{"find Cedar Vale-RealmA","track","Cedar Vale-RealmA"},
        {"find  share off","setFindShare",false},{"find notice on","setFindNotice",true},
        {"hop stop","hopAnyStop"},{"hop any","hopAny"},{"hop auto on","setAutoHop",true},
        {"hop auto off","setAutoHop",false},{"hop host 2","hopHost",2},{"hop 3","hopIndex",3},
        {"hosts","hosts"},{"hosts find","findHosts"},{"reports","text","reports"},
        {"net","net","net"},{"net guild","net","net guild"}}) do
        local before=#calls
        SlashCmdList.LAYERENEMIES(case[1]); eq(#calls,before+1,case[1].." dispatches once")
        eq(calls[#calls][1],case[2],case[1]); eq(calls[#calls][2],case[3],case[1].." argument")
    end
    eq(#H.sent(),0); no(M.error)
end)

for _,presenceFirst in ipairs({true,false}) do
    test("Stack: presence FLH and Overlord coexist without sends or persistence presenceFirst="..tostring(presenceFirst),function()
        _G.C_Club=nil; _G.BNGetNumFriends=nil
        local N=H.load({tracked={"Cedar Vale"},share=false,findShare=false,consent="guild"})
        Enum.GameRule={HardcoreRuleset=1,RPRuleset=2,PvPRuleset=3}
        C_GameRules={IsGameRuleActive=function(rule) return rule==3 end}
        -- Finish the empty login scan before installing this case's roster.
        H.advance(.01); no(N.Main.presenceJob,"login scan finished")
        local M=N.Main; local saved=snapshot(LayerEnemiesDB); local attempted=0
        N.Wire.send=function() attempted=attempted+1; error("receive-only composition attempted a send") end
        _G.C_Club={
            GetSubscribedClubs=function() return {{clubId="504",clubType=0}} end,
            GetClubMembers=function() return {1} end,
            GetMemberInfo=function() return {name="Cedar#1234",presence=1,bnetAccountId=42} end}
        _G.C_BattleNet.GetAccountInfoByID=function(id)
            eq(id,42,"club member resolves through its account")
            return {gameAccountInfo={characterName="Cedar Vale",realmName="Test Realm",areaName="Duskwood",
                factionName="Horde",playerGuid="Player-1-cedar",isOnline=true,clientProgram="WoW"}}
        end
        _G.WOW_PROJECT_ID=11; _G.BNGetNumFriends=function() return 0 end
        _G.C_BattleNet.GetFriendAccountInfo=function() return nil end
        local function scan()
            M.presenceScan(true)
            for _=1,100 do if not M.presenceJob then break end; H.advance(.001) end
            no(M.presenceJob); eq(M.presenceStats.matches,1,"real roster scan matched")
        end
        local function receive()
            -- Wire timestamps are integer seconds; the harness advances its wall clock fractionally.
            local stamp=math.floor(GetServerTime())
            H.deliver("CHAT_MSG_ADDON","FLHNET2","HI|100|008|1|0.1.3|1234","PARTY","Birch Scout")
            H.deliver("CHAT_MSG_ADDON","OverlordF","EK:Cedar Vale:MAGE:Horde:"..stamp..":#100:0","PARTY","Elm Grove")
            H.deliver("CHAT_MSG_ADDON","OverlordF","GW:1:Enemy Guild:H:77:6:#100:12345:"..stamp,"PARTY","Elm Grove")
        end
        if presenceFirst then scan(); receive() else receive(); scan() end
        local row=M.findRows()[1]
        yes(row.presence); eq(row.presence.route,"community"); eq(row.presence.zone,"Duskwood")
        yes(row.reported); eq(row.reported.source,"overlord"); eq(row.status,"named as killer (claim)")
        no(row.canAsk); eq(row.spotter,"Elm Grove","claim provenance is not an Ask target"); eq(row.layer,nil)
        local text=M.findText(row); yes(text:find("named as killer (claim)",1,true)); yes(text:find("online (community)",1,true))
        local hosts=M.candidates(); eq(#hosts,1); eq(hosts[1].flhKey,"008"); eq(hosts[1].layer,nil)
        local reports=M.reportedRows(); eq(#reports,1); eq(reports[1].guild,"Enemy Guild"); eq(reports[1].record,nil)
        N.UI.toggle(); N.UI.select("find"); yes(N.UI.pool[1].presence:IsShown()); no(N.UI.pool[1].ask:IsShown())
        N.UI.select("reported"); eq(N.UI.pool[1].title:GetText(),"guild Enemy Guild"); no(N.UI.pool[1].ask:IsShown())
        N.UI.select("friendly"); yes(N.UI.pool[1].sub:GetText():find("FLH key 008",1,true)); yes(N.UI.pool[1].ask.disabled)
        eq(snapshot(LayerEnemiesDB),saved,"all received data stays session-only")
        yes(H.registered().FLHNET2); yes(H.registered().OverlordF)
        eq(attempted,0); eq(#H.sent(),0); no(M.error)
    end)
end
