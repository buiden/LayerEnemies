-- Additional receive surfaces use the same optional-home identity contract.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function setup(mode,name)
    return H.load(nil,function()
        local unit=UnitName
        UnitName=function(u) if u=="player" then return name end; return unit(u) end
        GetRealmName=function() if mode=="empty" then return "" end end
        GetNormalizedRealmName=GetRealmName
        Enum.GameRule={HardcoreRuleset=1,RPRuleset=2,PvPRuleset=3}
        C_GameRules={IsGameRuleActive=function(rule) return rule==3 end}
    end)
end
local function receive(prefix,text,sender,route)
    H.deliver("CHAT_MSG_ADDON",prefix,text,route or "GUILD",sender or "Birch Scout")
end
local function base36(n)
    local out=""; local alphabet="0123456789abcdefghijklmnopqrstuvwxyz"
    repeat local d=n%36; out=alphabet:sub(d+1,d+1)..out; n=math.floor(n/36) until n==0
    return out
end
for _,mode in ipairs({"empty","nil"}) do
    for _,name in ipairs({"Ash Example","Solo"}) do
        for _,lane in ipairs({"HeadHunter","OpenMap","ChehulNet","Overlord","Wanted","friend share","guild death","LayerSwap"}) do
            test("Realm routes: "..mode.." "..name.." "..lane,function()
                local N=setup(mode,name); local M=N.Main; H.clock(120)
                if lane=="HeadHunter" then
                    local line="1AP:2s;"..base36(GetServerTime())..";dw;6y;a1"
                    receive("HeadHunter",line,name,"PARTY"); eq(M.lastDrop,"own echo")
                    receive("HeadHunter",line,"Birch Scout","PARTY"); yes(next(M.store.reports))
                elseif lane=="OpenMap" then
                    yes(M.track(name)); yes(M.track("Birch Scout"))
                    local line="L1\t100\t0.4200\t0.5700\tMAGE\t60"
                    receive("OpenMapLoc",line,name); eq(next(M.find.places),nil)
                    receive("OpenMapLoc",line); yes(M.find.places["Birch Scout"])
                elseif lane=="ChehulNet" then
                    local line="CHN1|H|gos+pl|MAGE|60|craft:Enchanting,lfg,mv=10|100:7"
                    receive("ChehulNet",line,name); eq(#N.ChehulNet.rows(),0)
                    receive("ChehulNet",line); eq(#N.ChehulNet.rows(),1)
                elseif lane=="Overlord" then
                    local payload="1:Enemy Guild:H:77:6:#100:7086:"..GetServerTime()
                    local line="BF:pkt-1:1:1:global|pkt-1|"..GetServerTime().."|*|Birch Scout|GW|"..payload
                    receive("OverlordF",line,name); eq(#M.reportedRows(),0)
                    receive("OverlordF",line); eq(#M.reportedRows(),1)
                elseif lane=="Wanted" then
                    yes(M.track("Cedar Vale"))
                    local data={g="Player-1-AB",n="Cedar Vale",z="Ashenvale",m=100,x=50,y=40,v="1.29.2"}
                    local payload=N.Codec.addonEncode(N.Codec.deflateStored(N.Codec.lsWrite(data)))
                    local n=math.ceil(#payload/240)
                    local function send(sender)
                        for i=1,n do receive("WNTD","E:a:"..i.."/"..n..":"..payload:sub((i-1)*240+1,i*240),sender) end
                    end
                    send(name); eq(next(M.find.known.entries),nil)
                    send("Birch Scout"); yes(next(M.find.known.entries))
                elseif lane=="friend share" then
                    yes(M.track("Cedar Vale")); H.roster({{"Birch Scout",true}}); H.deliver("GUILD_ROSTER_UPDATE")
                    local lines=N.FriendShare.lines({{name="Cedar Vale",zone="Ashenvale",faction="Horde",class="ROGUE",level=58}},0)
                    for _,line in ipairs(lines) do receive("LEGW1",line,name) end
                    eq(next(M.find.presence),nil)
                    for _,line in ipairs(lines) do receive("LEGW1",line) end
                    yes(M.find.presence["Cedar Vale"])
                elseif lane=="guild death" then
                    H.roster({{"Birch Scout",true}}); H.deliver("GUILD_ROSTER_UPDATE")
                    local line="K|1|100|0.200|0.300||0|e|43656461722056616c65:MAGE:60:f"
                    receive("LEGW1",line,name); eq(M.call.current,nil)
                    receive("LEGW1",line); yes(M.call.current)
                else
                    local draft; M.openChat=function(line) draft=line; return true end
                    yes(M.hopAny()); yes(draft)
                    H.deliver("CHAT_MSG_GUILD",draft:sub(4),name)
                    receive("LayerSwap","claim "..name,"Host Cedar")
                    yes(M.hop.guildAsk.answered["host cedar"])
                    receive("LayerSwap","claim "..name,name)
                    no(M.hop.guildAsk.answered[name:lower()])
                end
                no(M.error)
            end)
        end
    end
end
