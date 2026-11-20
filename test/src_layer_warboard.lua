local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function setup()
    local N=H.load(); N.Net.SHIP.warboard=true
    GetRealmName=function() return "PvP 123" end
    yes(N.Find.add(N.Main.find,"Enemy Player"))
    return N
end
local function send(N,tag,d)
    local wire=N.Codec.addonEncode(N.Codec.deflateStored(N.Codec.aceWrite({t=tag,v=5,rs="pvp",d=d})))
    for _,part in ipairs(N.Codec.aceCommSplit(wire)) do H.deliver("CHAT_MSG_ADDON","WarBoard",part,"GUILD","Relay Carrier") end
end
local function position(layer)
    return {targetName="Enemy Player",targetGuid="Player-1-ABC",faction="Horde",rank=3,worldX=12,worldY=34,
        instanceID=1,zone="Ashenvale",subZone="Astranaar",shard=layer,sentAt=H.wall(),roster={}}
end
for _,layer in ipairs({false,{},string.rep("9",21)}) do
    test("Layer A3: WarBoard FBLP separable malformed layer "..type(layer),function()
        local N=setup(); local offered; local real=N.Sources.offer
        N.Sources.offer=function(e) offered=e; return real(e) end
        send(N,"FBLP",position(layer))
        yes(offered); eq(offered.shard,nil); eq(offered.name,"Enemy Player"); eq(offered.zone,"Ashenvale")
        yes(N.Known.get(N.Main.find.known,"Enemy Player",H.clock()))
        no(N.Main.error)
    end)
end
test("Layer A3: WarBoard malformed non-layer fields and SHRD identity still drop",function()
    for _,kind in ipairs({"position","identity"}) do
        local N=setup(); local offered=0; N.Sources.offer=function() offered=offered+1 end
        if kind=="position" then local d=position({}); d.worldX="bad"; send(N,"FBLP",d)
        else send(N,"SHRD",{name="Enemy",realm="Player",guid="Player-1-ABC",faction="Horde",
            sentAt=H.wall()*1000,zone="Ashenvale",mapID=100,shard="bad-layer"}) end
        eq(offered,0); no(N.Main.error)
    end
end)
