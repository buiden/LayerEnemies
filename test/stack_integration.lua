-- Composition checks for the eight-level feature stack; no donor or live client.
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

test("Stack: six mixed Wanted presence and Overlord cards use measured heights and page without overlap",function()
    for _,presenceFirst in ipairs({true,false}) do
        _G.C_Club=nil; _G.BNGetNumFriends=nil
        local names={"Cedar Vale","Birch Moss","Elm Grove","Ash Reed","Oak Brook","Pine Wood"}
        local N=H.load({tracked=names,share=false,findShare=false,consent="guild"})
        local M,U=N.Main,N.UI
        Enum.GameRule={HardcoreRuleset=1,RPRuleset=2,PvPRuleset=3}
        C_GameRules={IsGameRuleActive=function(rule) return rule==3 end}
        H.advance(.01); no(M.presenceJob)
        local saved=snapshot(LayerEnemiesDB); local attempts=0
        N.Wire.send=function() attempts=attempts+1; error("mixed receive sent") end
        N.BNet.send=N.Wire.send
        C_Club={GetSubscribedClubs=function() return {{clubId="504",clubType=0}} end,
            GetClubMembers=function() return {1,2,3,4,5,6} end,
            GetMemberInfo=function(_,id) return {presence=1,bnetAccountId=id} end}
        C_BattleNet.GetAccountInfoByID=function(id) return {gameAccountInfo={
            characterName=names[id],realmName="Test Realm",areaName="Duskwood",
            factionName="Horde",isOnline=true,clientProgram="WoW"}} end
        BNGetNumFriends=function() return 0 end
        local function scan()
            M.presenceScan(true)
            for _=1,100 do if not M.presenceJob then break end; H.advance(.001) end
            no(M.presenceJob); eq(M.presenceStats.matches,6)
        end
        local function claims()
            local sights={}
            for i,name in ipairs(names) do sights[i]={g=string.format("Player-1-%X",i),n=name.."-TestRealm",m=100} end
            local encoded=assert(N.Codec.addonEncode(assert(N.Codec.deflateStored(assert(N.Codec.lsWrite({v="1.29.2",s=sights}))))))
            local count=math.ceil(#encoded/240)
            for i=1,count do H.deliver("CHAT_MSG_ADDON","WNTD","S:mx:"..i.."/"..count..":"..encoded:sub((i-1)*240+1,i*240),"GUILD","Witness Player") end
            eq(N.Wanted.stats.accepted,6,"all Wanted names admitted before overlay")
            -- Both are claims in the one retained Reported slot. Leave four
            -- Wanted reports and two Overlord claims, each with presence.
            H.advance(1) -- Overlord wall timestamps are whole seconds, newer than Wanted receipt.
            for i=5,6 do H.deliver("CHAT_MSG_ADDON","OverlordF","EK:"..names[i].."-TestRealm:MAGE:Horde:"..math.floor(GetServerTime())..":#100:0","PARTY","Elm Scout") end
            eq(M.overlord.stats.taken,2)
        end
        if presenceFirst then scan(); claims() else claims(); scan() end
        local rows=M.findRows(); eq(#rows,6)
        local expected={}
        for i,r in ipairs(rows) do
            yes(r.presence); yes(r.reported); no(r.canAsk)
            eq(r.reported.source,i<=4 and "wanted" or "overlord")
            expected[r.name]=M.findDetails(r)
        end
        U.frame:Show(); U.select("find"); local reached={}
        for _=1,#names do
            local visible,bottom=0,0
            for _,card in ipairs(U.pool) do if card:IsShown() then
                visible=visible+1; reached[card.tracked]=true
                local top=-card.point[5]; yes(top>=bottom,"mixed cards do not overlap")
                bottom=top+card:GetHeight(); yes(bottom<=U.body:GetHeight(),"complete mixed card stays in page")
                eq(card.sub:GetText(),expected[card.tracked],"complete claim text retained")
                eq(card.sub:GetHeight(),math.ceil(card.sub:GetStringHeight()),"claim box uses actual measured text")
                eq(card.presence:GetHeight(),math.ceil(card.presence:GetStringHeight()),"presence box uses actual measured text")
                eq(-card.presence.point[5],26+card.sub:GetHeight()+3,"presence directly follows complete claim")
                eq(card:GetHeight(),26+card.sub:GetHeight()+3+card.presence:GetHeight()+32,"card height is measured content plus title gap and actions")
                no(card.ask:IsShown()); yes(card.clear:IsShown())
            end end
            yes(visible>=2,"several mixed evidence cards per page")
            U.body.scripts.OnMouseWheel(nil,-1)
        end
        for _,name in ipairs(names) do yes(reached[name],"every mixed card reachable") end
        eq(attempts,0); eq(#H.sent(),0); no(M.error); eq(snapshot(LayerEnemiesDB),saved)
    end
end)

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
