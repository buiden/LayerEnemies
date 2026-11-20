-- Exercise A3 through the real wrappers, not only the inner layer decoders.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function setup()
    local N=H.load(); H.clock(100); H.drain(); yes(N.Find.add(N.Main.find,"Cedar Vale"))
    GetRealmName=function() return "PvP 123" end
    local name=UnitName
    UnitName=function(unit) if unit=="player" then return "Me",GetRealmName() end; return name(unit) end
    Enum.GameRule={HardcoreRuleset=1,RPRuleset=2,PvPRuleset=3}
    C_GameRules={IsGameRuleActive=function(rule) return rule==3 end}
    yes(N.Adapters.ownIdentity()); return N
end
local function gw(N,layer,route,field)
    local f={"1","Enemy Guild","H","50","5","#100",layer,tostring(GetServerTime())}
    if field then f[field]=f[field].."\001" end
    local payload=table.concat(f,":")
    if route=="direct" then H.deliver("CHAT_MSG_ADDON","OverlordF","GW:"..payload,"PARTY","Birch Scout")
    else
        local wire="global|review1|"..GetServerTime().."|*|Birch Scout|GW|"..payload
        -- Force assembly; the layer's control byte is transported as raw data.
        local chunk=40; local total=math.ceil(#wire/chunk)
        for i=1,total do
            H.deliver("CHAT_MSG_ADDON","OverlordF","BF:review1:"..i..":"..total..":"..wire:sub((i-1)*chunk+1,i*chunk),"GUILD","Birch Scout")
        end
    end
end
local function hash(r)
    local keys={}; for k in pairs(r.data) do keys[#keys+1]=k end; table.sort(keys)
    local s=r.kind.."\n"..r.id.."\n"..r.prev.."\n"..r.t
    for _,k in ipairs(keys) do s=s.."\n"..k.."="..tostring(r.data[k]) end
    local a,b=1,0; for i=1,#s do a=(a+s:byte(i))%65521; b=(b+a)%65521 end
    return string.format("%08x",b*65536+a)
end
local function wanted(N,layer,change)
    local r={kind="kill",id="Birch Scout:1000001",origin="Birch Scout",seq=1000001,prev="0",t=GetServerTime()-3,
        data={victimName="Cedar Vale",victim="Player-1-AB",victimFaction="Horde",mapId=100,x=50,y=40,l=layer}}
    if change then change(r) end
    r.hash=hash(r)
    return r
end
local function sendWanted(N,r)
    local b=assert(N.Codec.addonEncode(assert(N.Codec.deflateStored(assert(N.Codec.lsWrite({v="1.29.2",r={r}}))))))
    local total=math.ceil(#b/240)
    for i=1,total do H.deliver("CHAT_MSG_ADDON","WNTD","R:a:"..i.."/"..total..":"..b:sub((i-1)*240+1,i*240),"GUILD","Birch Scout") end
end
local values={{"valid","123","1-0-6"},{"punctuation","bad!layer","bad!layer"},{"pipe","bad|layer","bad|layer"}}
for _,b in ipairs({0,1,10,13,31,127}) do values[#values+1]={"byte "..b,"bad"..string.char(b).."layer","bad"..string.char(b).."layer"} end
for _,v in ipairs(values) do
    for _,route in ipairs({"direct","fragmented"}) do
        test("Layer outer guards: GW "..route.." "..v[1],function()
            local N=setup(); local before=#H.sent(); gw(N,v[2],route)
            eq(N.Main.overlord.stats.taken,1,"valid fields must survive separable bad layer")
            local rows=N.Overlord.rows(N.Main.overlord,H.clock()); eq(#rows,1)
            local r=rows[1]; eq(r.guild,"Enemy Guild"); eq(r.zone,100); eq(r.kills,50); eq(r.members,5)
            eq(r.layer,v[1]=="valid" and 123 or nil); eq(#H.sent(),before); no(N.Main.error)
        end)
    end
    test("Layer outer guards: Wanted "..v[1],function()
        local N=setup(); local before=#H.sent(); sendWanted(N,wanted(N,v[3]))
        local p=N.Known.get(N.Main.find.known,"Cedar Vale",H.clock()); yes(p,"checksum-valid record survives layer degradation")
        local r=p.reported; yes(r); eq(r.name,"Cedar Vale"); eq(r.zone,100); eq(r.x,.5); eq(r.y,.4)
        eq(r.guid,"Player-1-AB"); eq(r.at,97); eq(r.shard,v[1]=="valid" and "1-0-6" or nil)
        eq(r.ns,"unknown"); eq(#H.sent(),before); no(N.Main.error)
    end)
end
for _,route in ipairs({"direct","fragmented"}) do
    test("Layer outer guards: GW "..route.." rejects other malformed fields",function()
        for _,field in ipairs({1,2,3,4,5,6,8}) do
            local N=setup(); gw(N,"bad\001layer",route,field)
            eq(N.Main.overlord.stats.taken,0); eq(#N.Overlord.rows(N.Main.overlord,H.clock()),0); no(N.Main.error)
        end
        for _,layer in ipairs({"bad:layer",string.rep("x",201)}) do
            local N=setup(); gw(N,layer,route)
            eq(N.Main.overlord.stats.taken,0); no(N.Main.error)
        end
    end)
end

test("Layer outer guards: Overlord envelopes and non-GW controls stay strict",function()
    for field=1,6 do
        local N=setup()
        local f={"global","review1",tostring(GetServerTime()),"*","Birch Scout","GW","1:Enemy Guild:H:50:5:#100:bad\001layer:"..GetServerTime()}
        f[field]=f[field].."\001"
        local wire=table.concat(f,"|")
        no(N.Overlord.packet(wire,"review1","Birch Scout",GetServerTime(),"Me-PvP123"))
        H.deliver("CHAT_MSG_ADDON","OverlordF","BF:review1:1:1:"..wire,"GUILD","Birch Scout")
        eq(N.Main.overlord.stats.taken,0); no(N.Main.error)
    end
    local N=setup()
    no(N.Overlord.fragment(N.Main.overlord,"BF:bad\001id:1:1:x","Birch Scout",H.clock(),"GUILD"))
    for _,kind in ipairs({"GD","NH"}) do
        no(N.Overlord.packet("global|review1|"..GetServerTime().."|*|Birch Scout|"..kind.."|bad\001payload",
            "review1","Birch Scout",GetServerTime(),"Me-PvP123"))
    end
    for _,kind in ipairs({"GD","EK"}) do no(N.Overlord.direct(kind..":bad\001payload")) end
end)

test("Layer outer guards: Wanted retains checksum and non-layer guards",function()
    for _,case in ipairs({"hash","name","note","coordinate","oversize"}) do
        local N=setup()
        local r=wanted(N,"bad\001layer",function(v)
            if case=="name" then v.data.victimName="Cedar\001Vale"
            elseif case=="note" then v.data.note="bad|note"
            elseif case=="coordinate" then v.data.x=101
            elseif case=="oversize" then v.data.l=string.rep("x",513) end
        end)
        if case=="hash" then r.hash="00000000" end
        sendWanted(N,r); eq(N.Known.get(N.Main.find.known,"Cedar Vale",H.clock()),nil); no(N.Main.error)
    end
end)

test("Layer outer guards: Wanted identity-layer bridge still drops control and pipe",function()
    for _,layer in ipairs({"1-0-6","bad|layer","bad\001layer"}) do
        local N=setup()
        N.BNet.who=function() return {name="Enemy Peer",realm="PvP 123",faction="Horde"} end
        local b=N.Codec.addonEncode(N.Codec.deflateStored(N.Codec.lsWrite({k="L",z={{m=100,l=layer,n=3}}})))
        H.deliver("BN_CHAT_MSG_ADDON","WNTDB",b,"WHISPER",12)
        eq(N.Wanted.state.far[12]~=nil,layer=="1-0-6"); no(N.Main.error)
    end
end)
