-- C2: own directory entries and addressed sends must never reach the client.
local H=...
local eq,yes=H.eq,H.yes
for _,name in ipairs({"Alice Vale","Élan Scout","Ølaf Scout","Борис Скаут"}) do
    H.test("Overlord peer: self silence "..name,function()
        local N=H.load();N.Net.SHIP.overlord=true
        Enum.GameRule={HardcoreRuleset=1,RPRuleset=2,PvPRuleset=3}
        C_GameRules={IsGameRuleActive=function(i) return i==3 end}
        UnitName=function() return name,GetRealmName() end
        C_AddOns.GetAddOnMetadata=function() return "1.2.2" end
        GetNumDisplayChannels=function() return 0 end
        IsInGuild=function() return false end
        IsInGroup=function() return false end
        local own=N.Find.fold(name).."-"..GetRealmName():gsub("%s","")
        N.Directory.members=function() return {own,"Birch Scout"} end
        N.BNet.peers=function() return {} end
        for i=1,61 do H.advance(1) end
        local self,other=0,0
        for _,s in ipairs(H.sent()) do
            if s.prefix=="OverlordF" and s.kind=="WHISPER" then
                if N.Find.fold(s.target)==N.Find.fold(name) then self=self+1 else other=other+1 end
            end
        end
        print("PROBE self "..name..": self="..self.." other="..other)
        eq(self,0,"no greeting to own canonical identity");eq(other,1,"self skip must not stall others")
        local P=N.OverlordPeer;local c=N.Main.overlordContext();local sends=0
        c.send=function() sends=sends+1;return true end
        for _,kind in ipairs({"NH","HA","HR"}) do
            P.emit(P.new(),c,kind,"test","WHISPER",own,"self",0,true)
            P.emit(P.new(),c,kind,"test","BNET",{id=71,name=own},"self",0,true)
        end
        eq(sends,0,"no addressed Overlord sends to self")
        local job={key="self",gap=0,owed=true,pool=c.pool,me=c.me,kind="NH",route="BNET",id=71,name=own}
        eq(P.claim(P.new(),job,c),false,"dispatch rechecks own identity")
    end)
end
