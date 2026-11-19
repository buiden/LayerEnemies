-- Composed Wanted/WarBoard ingress and final Find rendering, not donor execution.
local h=...
local eq,yes,no=h.eq,h.yes,h.no
h.test("Stack: WarBoard mutant evidence rerun is byte and mtime stable",function()
    local p=assert(io.popen("python3 -B test/warboard_mutants_test.py 2>&1; printf '\\nRUNNER_RC=%s\\n' \"$?\""))
    local result=p:read("*a"); p:close()
    yes(result:find("RUNNER_RC=0",1,true),(result:gsub("[\r\n]+"," | ")))
    yes(result:find("Ran 1 test",1,true),"real evidence regression was collected")
end)
for _,route in ipairs({"BN self","BN third","GUILD","PARTY","RAID","CHANNEL"}) do
    h.test("Stack: WarBoard position subject survives Wanted observer wording on "..route,function()
        local N=h.load()
        N.Net.SHIP.warboard=true
        _G.WOW_PROJECT_ID=42
        _G.GetRealmName=function() return "PvP 123" end
        C_AddOns.GetAddOnMetadata=function() return "1.2.4" end
        C_BattleNet.GetGameAccountInfoByID=function(id)
            return {gameAccountID=id,characterName=route=="BN third" and "Relay Carrier" or "Enemy Player",
                realmName="123",factionName="Horde",clientProgram="WoW",isOnline=true,
                wowProjectID=42,isInCurrentRegion=true}
        end
        N.BNet.peers=function() return {} end
        yes(N.Find.add(N.Main.find,"Wanted Target")); yes(N.Find.add(N.Main.find,"Enemy Player"))
        local encoded=N.Codec.addonEncode(N.Codec.deflateStored(N.Codec.lsWrite({v="1.29.2",
            s={{g="Player-1-DEF",n="Wanted Target-123",m=100,x=20,y=40}}})))
        local parts=math.ceil(#encoded/240)
        for i=1,parts do h.deliver("CHAT_MSG_ADDON","WNTD","S:mix:"..i.."/"..parts..":"..
            encoded:sub((i-1)*240+1,i*240),"GUILD","Witness Player") end
        eq(N.Wanted.stats.accepted,1,"real Wanted evidence reaches the shared projection")
        CreateVector2D=function(x,y) return {x=x,y=y} end
        C_Map.GetMapPosFromWorldPos=function() return 100,{GetXY=function() return .2,.4 end} end
        local envelope={t="FBLP",v=5,rs="pvp",d={targetName="Enemy Player",targetGuid="Player-1-ABC",
            faction="Horde",rank=3,worldX=12,worldY=34,instanceID=1,zone="Ashenvale",
            subZone="Astranaar",shard="123",sentAt=h.wall(),roster={}}}
        local bytes=N.Codec.addonEncode(N.Codec.deflateStored(N.Codec.aceWrite(envelope)))
        if route:sub(1,2)=="BN" then
            h.deliver("BN_CHAT_MSG_ADDON","WarBoard","WBF1|A|5|pvp|1.6.3|3","WHISPER",71)
            h.deliver("BN_CHAT_MSG_ADDON","WarBoard","WBF1|D|"..bytes,"WHISPER",71)
        else
            for _,part in ipairs(N.Codec.aceCommSplit(bytes)) do
                h.deliver("CHAT_MSG_ADDON","WarBoard",part,route,"Enemy Player-123")
            end
        end
        local rows=N.Main.findRows(); eq(#rows,2)
        local texts={}
        for _,r in ipairs(rows) do
            yes(r.reported); local text=N.Main.findDetails(r); texts[r.name]=text
            eq(r.x,.2); eq(r.y,.4); no(r.canAsk); no(r.layer)
            if r.source=="wanted" then
                eq(r.pos,"observer"); yes(text:find("seen near observer",1,true))
            else
                eq(r.source,"warboard"); eq(r.pos,"enemy")
                no(text:find("seen near observer",1,true),"enemy coordinates never become the relay's position")
                if route=="BN self" then
                    eq(r.evidenceKind,"self"); yes(text:find("own position",1,true))
                    no(text:find("reported position",1,true))
                else
                    eq(r.evidenceKind,"relayed"); yes(text:find("reported position",1,true))
                    no(text:find("own position",1,true))
                end
            end
        end
        N.UI.toggle(); N.UI.select("find")
        local shown={}
        for _=1,#rows do
            local bottom=0
            for _,card in ipairs(N.UI.pool) do if card:IsShown() then
                shown[card.tracked]=true; eq(card.sub:GetText(),texts[card.tracked])
                yes(card.sub:GetHeight()>=card.sub:GetStringHeight(),"complete mixed-source text is measured")
                local top=-card.point[5]; yes(top>=bottom,"mixed cards do not overlap")
                bottom=top+card:GetHeight(); yes(bottom<=N.UI.body:GetHeight())
            end end
            N.UI.body.scripts.OnMouseWheel(nil,-1)
        end
        for name in pairs(texts) do yes(shown[name],"each complete mixed-source row is reachable") end
        eq(#h.sent(),0,"receiving both sources sends nothing")
    end)
end
