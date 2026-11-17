-- Round-2 owner rulings, exercised through real event handlers/codecs.
local h=...
local eq,yes,no=h.eq,h.yes,h.no
local function test(name,fn) h.test("WarBoard R2: "..name,fn) end
local function setup()
    local N=h.load(); N.Net.SHIP.warboard=true
    WOW_PROJECT_ID=42; GetRealmName=function() return "PvP 123" end
    C_AddOns.GetAddOnMetadata=function() return "1.1.0" end
    C_BattleNet.GetGameAccountInfoByID=function(id)
        return {gameAccountID=id,characterName="Enemy Player",realmName="123",factionName="Horde",clientProgram="WoW",
            isOnline=true,wowProjectID=42,isInCurrentRegion=true}
    end
    N.BNet.peers=function() return {} end
    yes(N.Find.add(N.Main.find,"Enemy Player"))
    local meter={calls=0,bytes=0,charged=0,caps={}}
    local inflate,decode=N.Codec.inflate,N.WarBoard.decode
    N.Codec.inflate=function(raw,cap,...)
        meter.calls=meter.calls+1; meter.caps[#meter.caps+1]=cap
        local text,used=inflate(raw,cap,...)
        meter.bytes=meter.bytes+(used or (text and #text) or 0)
        return text,used
    end
    N.WarBoard.decode=function(...)
        local e,cost=decode(...); meter.charged=meter.charged+(cost or 0)
        return e,cost
    end
    return N,meter
end
local function bn(text,id) h.deliver("BN_CHAT_MSG_ADDON","WarBoard",text,"WHISPER",id or 71) end
local function confirm(id) bn("WBF1|A|5|pvp|1.6.3|3",id) end
local function encode(N,text) return N.Codec.addonEncode(N.Codec.deflateStored(text)) end
local function wire(N,t,d) return encode(N,N.Codec.aceWrite({t=t,v=5,rs="pvp",d=d})) end
local function addon(N,encoded,sender,dist,prefix)
    for _,p in ipairs(N.Codec.aceCommSplit(encoded)) do
        h.deliver("CHAT_MSG_ADDON",prefix or "WarBoard",p,dist or "GUILD",sender or "Guild Mate-123")
    end
end
local function shrd(i)
    return {faction="Horde",guid="Player-1-ABC",name="Enemy",realm="Player",sentAt=h.wall()*1000+(i or 0),
        isGroupLeader=false,shard="123",zone="Ashenvale",mapID=100}
end
local function row(N) return N.Find.rows(N.Main.find,h.clock(),100)[1] end
local function counter(N,key)
    for _,line in ipairs(N.Sources.lines()) do
        if line:match("^warboard:") then return tonumber(line:match(key.."=(%d+)")) or 0 end
    end
    error("missing WarBoard counters")
end
local function bomb(N,i)
    local f=assert(io.open("test/fixtures/warboard-round2-bomb.bin","rb")); local raw=f:read("*a"); f:close()
    -- RFC1951 stored-block padding is ignored: two empty nonfinal blocks
    -- create 1,024 distinct streams without changing the reviewer's output.
    i=i or 0
    if i>0 then raw=string.char((i%32)*8,0,0,255,255,math.floor(i/32)*8,0,0,255,255)..raw end
    return N.Codec.addonEncode(raw)
end

test("overall ceiling bounds twenty senders times forty distinct bombs",function()
    local N,meter=setup(); local base=bomb(N)
    eq(#base+7,558,"reviewer's no-type WBF1 D frame")
    local text=N.Codec.inflate(N.Codec.addonDecode(base),262144)
    eq(#text,262027); yes(N.Codec.aceRead(text),"old decoder parses the real bomb")
    local distinct={}
    meter.calls=0; meter.bytes=0; meter.charged=0
    for sender=1,20 do
        for j=1,40 do
            local encoded=bomb(N,(sender-1)*40+j)
            no(distinct[encoded]); distinct[encoded]=true
            addon(N,encoded,"Flood"..h.abc(sender).."-123","GUILD")
        end
    end
    eq(N.Safe.count(distinct),800)
    yes(meter.bytes>0,"real inflater exercised")
    yes(meter.charged<=196608,"all unauthenticated senders share 192 KiB per ten seconds")
    yes(meter.bytes<=meter.charged,"charged bytes cover partial inflation")
    no(row(N).reported); no(N.Main.error)
    print("WORK R2 guild800: "..meter.calls.." calls, "..meter.bytes.." actual, "..meter.charged.." charged")
end)

test("channel flood leaves a guild reserve and confirmed BN room",function()
    local N,meter=setup(); confirm()
    for i=1,230 do addon(N,bomb(N,i),"Stranger"..h.abc(i).."-123","CHANNEL",i%2==0 and "WarBoardBN" or "WarBoard") end
    yes(meter.charged<=131072,"channel strangers cannot consume the 64 KiB group reserve")
    yes(meter.bytes>0); yes(meter.bytes<=meter.charged)
    print("WORK R2 channel230: "..meter.calls.." calls, "..meter.bytes.." actual, "..meter.charged.." charged")
    local before=counter(N,"accepted")
    addon(N,wire(N,"SHRD",shrd()),"Guild Mate-123")
    eq(counter(N,"accepted"),before+1,"fresh guildmate admitted after channel sender/byte flood")
    bn("WBF1|D|"..wire(N,"SHRD",shrd(1)))
    eq(counter(N,"accepted"),before+2,"confirmed BN room is independent of unauthenticated budget")
    yes(row(N).reported); no(N.Main.error)
end)

test("channel sender slots cannot evict fresh guild party raid or BN senders",function()
    for _,route in ipairs({"GUILD","PARTY","RAID","BN"}) do
        local N=setup()
        for i=1,230 do
            -- Orphan continuations spend input slots but perform no decode.
            h.deliver("CHAT_MSG_ADDON","WarBoard","\002x","CHANNEL","Stranger"..h.abc(i).."-123")
        end
        eq(counter(N,"accepted"),0)
        local e=wire(N,"SHRD",shrd())
        if route=="BN" then confirm(); bn("WBF1|D|"..e)
        else addon(N,e,"Fresh Mate-123",route) end
        yes(row(N).reported,route.." retains sender-table room after 230 strangers")
        yes(N.Safe.count(N.WarBoard.state.rates)<=200,"input memory is still bounded")
    end
end)

test("all addon routes share one ceiling while confirmed BN is separate",function()
    local N,meter=setup(); confirm()
    for i,dist in ipairs({"GUILD","PARTY","RAID","CHANNEL"}) do
        addon(N,bomb(N,i),"Carrier"..h.abc(i).."-123",dist,i%2==0 and "WarBoardBN" or "WarBoard")
    end
    eq(meter.charged,196608,"not one global budget per route or prefix")
    local count=meter.calls
    bn("WBF1|D|"..wire(N,"SHRD",shrd()))
    eq(meter.calls,count+1); yes(row(N).reported)
    local charged=meter.charged
    addon(N,bomb(N,10),"Other Carrier-123","RAID")
    eq(meter.charged,charged,"confirmed BN does not refill the exhausted addon pool")
end)

test("cheap honest burst accepts all 119 SHRD from one confirmed account",function()
    local N,meter=setup(); confirm()
    for i=1,119 do bn("WBF1|D|"..wire(N,"SHRD",shrd(i))) end
    eq(counter(N,"accepted"),119,"small honest reports do not spend expensive attempts")
    eq(meter.calls,119); yes(meter.charged<=131072)
    yes(row(N).reported); no(N.Main.error)
    print("WORK R2 honest119: "..meter.bytes.." actual, "..meter.charged.." charged; all accepted")
end)

test("cheap reports leave all sixteen expensive attempts available",function()
    local N,meter=setup(); confirm()
    for i=1,20 do bn("WBF1|D|"..wire(N,"SHRD",shrd(i))) end
    eq(counter(N,"accepted"),20)
    for i=1,17 do
        local d={id="medium"..i,name="Enemy Player",guid="Player-1-ABC",faction="Horde",zone="Ashenvale",
            t=h.wall(),atype="pvp_kill",creditDelta=1,contributionDelta=1,kills=1,padding=string.rep("p",2500)}
        bn("WBF1|D|"..wire(N,"FREC",d))
        eq(counter(N,"accepted"),20+math.min(i,16),"cheap frames cannot consume expensive attempts")
    end
    eq(meter.caps[#meter.caps],2048)
end)

test("cheap frames still exhaust the byte budget",function()
    local N,meter=setup(); confirm()
    for i=1,119 do
        local d=shrd(i); d.padding=string.rep("p",1500)
        local text=N.Codec.aceWrite({t="SHRD",v=5,rs="pvp",d=d})
        yes(#text<2048,"small-path fixture")
        bn("WBF1|D|"..encode(N,text))
    end
    yes(counter(N,"accepted")>16,"small-path exemption exercised")
    yes(counter(N,"accepted")<119,"byte cap, not attempts, bounds cheap traffic")
    eq(meter.charged,131072); yes(meter.bytes<=meter.charged)
end)

test("expensive attempts stay capped but leave the cheap path open",function()
    local N,meter=setup(); confirm(); local start=h.clock()
    local function large(i)
        return wire(N,"FREC",{id="large"..i,name="Enemy Player",guid="Player-1-ABC",faction="Horde",zone="Ashenvale",
            t=h.wall(),atype="pvp_kill",creditDelta=1,contributionDelta=1,kills=1,padding=string.rep("p",2500)})
    end
    for i=1,16 do bn("WBF1|D|"..large(i)) end
    eq(counter(N,"accepted"),16,"reach the expensive-attempt boundary without exhausting bytes")
    for i,dist in ipairs({"GUILD","PARTY","RAID","CHANNEL"}) do
        addon(N,large(16+i),"Enemy Player-123",dist,i%2==0 and "WarBoardBN" or "WarBoard")
        yes(meter.caps[#meter.caps]<=2048,"route aliases cannot recover expensive allowance")
    end
    eq(counter(N,"accepted"),16)
    bn("WBF1|D|"..wire(N,"SHRD",shrd()))
    eq(counter(N,"accepted"),17,"small valid reports still decode after sixteen expensive attempts")
    h.clock(start+9.99); bn("WBF1|D|"..large(21)); eq(counter(N,"accepted"),17)
    h.clock(start+10); bn("WBF1|D|"..large(22)); eq(counter(N,"accepted"),18)
end)

for _,typ in ipairs({"SHRD","FBLP","FREC","FBLC","FCBD"}) do
    test("untracked "..typ.." reopens immediately when the name is added",function()
        local N,meter=setup(); confirm(); N.Find.remove(N.Main.find,"Enemy Player")
        local d=shrd()
        if typ=="FBLP" then
            d={targetName="Enemy Player",targetGuid="Player-1-ABC",faction="Horde",rank=3,worldX=12,worldY=34,
                instanceID=1,zone="Ashenvale",sentAt=h.wall(),roster={}}
        elseif typ=="FREC" then
            d={id="example",guid="Player-1-ABC",name="Enemy Player",faction="Horde",atype="pvp_kill",
                creditDelta=1,contributionDelta=1,kills=1,t=h.wall(),zone="Ashenvale"}
        elseif typ=="FBLC" or typ=="FCBD" then
            d={targetName="Enemy Player",targetGuid="Player-1-ABC",faction="Horde",zone="Ashenvale",sentAt=h.wall()}
            if typ=="FCBD" then d={requestId="req",relayName="Relay Carrier",relayGuid="Player-1-DEF",page=1,
                rulesVersion=3,faction="Horde",kind="bounty_locations",entries={d}} end
        end
        local e=wire(N,typ,d)
        bn("WBF1|D|"..e)
        eq(counter(N,"accepted"),0); eq(#N.WarBoard.state.frameOrder,0,"untracked refusal is not a cached decode outcome")
        yes(N.Find.add(N.Main.find,"Enemy Player"))
        bn("WBF1|D|"..e)
        eq(counter(N,"accepted"),1); eq(meter.calls,2); yes(row(N).reported)
        eq(#N.WarBoard.state.frameOrder,1,"admitted copy is remembered")
        bn("WBF1|D|"..e); eq(meter.calls,2); eq(counter(N,"deduped"),1)
    end)
end

test("portable mutant runner accepts relocated checkout cwd and scratch",function()
    local p=assert(io.popen("python3 -B test/warboard_mutants_portability_test.py 2>&1"))
    local result=p:read("*a"); p:close()
    yes(result:find("PASS portable WarBoard mutant runner",1,true),(result:gsub("[\r\n]+"," | ")))
end)

test("overall window is rolling with exact expiry and rollback refusal",function()
    local N,meter=setup(); local start=h.clock()
    addon(N,bomb(N,1),"First Carrier-123")
    eq(meter.charged,98304)
    h.clock(start+5); addon(N,bomb(N,2),"Second Carrier-123","PARTY")
    eq(meter.charged,196608)
    h.clock(start+9.99); addon(N,bomb(N,3),"Third Carrier-123","RAID")
    eq(meter.charged,196608)
    h.clock(start+10); addon(N,bomb(N,3),"Third Carrier-123","RAID")
    eq(meter.charged,294912,"only the first charge expires at ten seconds")
    h.clock(start+10.01); addon(N,bomb(N,4),"Fourth Carrier-123")
    eq(meter.charged,294912,"not a fixed window reset")
    h.clock(start+9); addon(N,bomb(N,5),"Fifth Carrier-123")
    eq(meter.charged,294912,"rollback never opens a fresh allowance")
    h.clock(start+15); addon(N,bomb(N,4),"Fourth Carrier-123")
    eq(meter.charged,393216)
end)
