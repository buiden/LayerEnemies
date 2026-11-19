-- Reviewer regressions: real receive paths and a forwarding inflate-byte spy.
local h=...
local eq,yes,no=h.eq,h.yes,h.no
local function test(name,fn) h.test("WarBoard review: "..name,fn) end
local function setup()
    local N=h.load(); N.Net.SHIP.warboard=true
    WOW_PROJECT_ID=42; GetRealmName=function() return "PvP 123" end
    C_AddOns.GetAddOnMetadata=function() return "1.2.5" end
    C_BattleNet.GetGameAccountInfoByID=function(id)
        return {gameAccountID=id,characterName="Enemy Player",realmName="123",factionName="Horde",clientProgram="WoW",
            isOnline=true,wowProjectID=42,isInCurrentRegion=true}
    end
    N.BNet.peers=function() return {} end
    yes(N.Find.add(N.Main.find,"Enemy Player"))
    local meter={calls=0,bytes=0,caps={}}
    local inflate=N.Codec.inflate
    N.Codec.inflate=function(raw,cap,...)
        meter.calls=meter.calls+1; meter.caps[#meter.caps+1]=cap
        local text,used=inflate(raw,cap,...)
        meter.bytes=meter.bytes+(used or (text and #text) or 0)
        return text,used
    end
    return N,meter
end
local function bn(text,id) h.deliver("BN_CHAT_MSG_ADDON","WarBoard",text,"WHISPER",id or 71) end
local function confirm(id) bn("WBF1|A|5|pvp|1.6.3|3",id) end
local function envelope(N,t,d)
    return N.Codec.aceWrite({t=t,v=5,rs="pvp",d=d})
end
local function encode(N,text) return N.Codec.addonEncode(N.Codec.deflateStored(text)) end
local function addon(N,encoded,sender,dist,prefix)
    for _,p in ipairs(N.Codec.aceCommSplit(encoded)) do
        h.deliver("CHAT_MSG_ADDON",prefix or "WarBoard",p,dist or "GUILD",sender or "Enemy Player-123")
    end
end
local function multipart(encoded,token,id)
    local cut=math.floor(#encoded/2)
    bn("WBF1|F|"..token.."|1|2|"..encoded:sub(1,cut),id)
    bn("WBF1|F|"..token.."|2|2|"..encoded:sub(cut+1),id)
end
local function shrd()
    return {faction="Horde",guid="Player-1-ABC",name="Enemy",realm="Player",sentAt=h.wall()*1000,
        isGroupLeader=false,shard="123",zone="Ashenvale",mapID=100}
end
local function position()
    return {targetName="Enemy Player",targetGuid="Player-1-ABC",faction="Horde",rank=3,worldX=12,worldY=34,
        instanceID=1,zone="Ashenvale",subZone="Astranaar",shard="123",sentAt=h.wall(),roster={}}
end
local function row(N) return N.Find.rows(N.Main.find,h.clock(),100)[1] end
local function counter(N,key)
    for _,line in ipairs(N.Sources.lines()) do
        if line:match("^warboard:") then return tonumber(line:match(key.."=(%d+)")) or 0 end
    end
    error("missing WarBoard counters")
end
local function refused(N) return counter(N,"refused") end
local function bomb(N)
    local f=assert(io.open("test/fixtures/warboard-review-bomb.bin","rb")); local raw=f:read("*a"); f:close()
    return N.Codec.addonEncode(raw)
end
local caps={SHRD=2048,FBLP=40960,FREC=73728,FBLC=2048,FCBD=98304}
for _,typ in ipairs({"SHRD","FBLP","FREC","FBLC","FCBD"}) do
    test(typ.." inflate ceiling is applied before bomb expansion",function()
        local N,meter=setup()
        -- Type first, type-looking text nested under d must never increase it.
        local text="^1^T^St^S"..typ.."^Sv^N5^Srs^Spvp^Sd^T^St^SFCBD^Sjunk^S"..string.rep("a",caps[typ]).."^t^t^^"
        no(N.WarBoard.decode(encode(N,text)))
        yes(meter.bytes<=caps[typ],"per-type inflate work ceiling")
        yes(meter.caps[1]<=98304,"unknown type never gets the shared 256 KiB limit")
    end)
end

test("reviewer 130 BN bombs have bounded inflated bytes and refusal accounting",function()
    local N,meter=setup(); confirm(); local encoded=bomb(N); local before=refused(N)
    eq(#encoded,603,"exact reviewer encoded payload (610 bytes with D header)")
    local plain=N.Codec.inflate(N.Codec.addonDecode(encoded),262144)
    eq(#plain,262006); yes(N.Codec.aceRead(plain),"reviewer bomb decodes CLEANLY with old ceiling")
    meter.calls=0; meter.bytes=0; meter.caps={}
    for _=1,130 do bn("WBF1|D|"..encoded) end
    yes(meter.bytes>0,"forwarding spy counted real partial inflate output")
    yes(meter.bytes<=2048,"130 repeated SHRD bombs must not inflate 119 times")
    eq(meter.calls,1,"failed frame hash avoids decoding repeats")
    eq(refused(N)-before,130,"all failed or rate-refused frames counted")
    eq(counter(N,"deduped"),118,"119 payload slots after handshake: one decode, 118 hash hits")
    no(row(N).reported); no(N.Main.error)
    print("WORK BN130: "..meter.calls.." inflate calls, "..meter.bytes.." inflated bytes")
end)

test("reviewer twenty addon senders cannot multiply repeated-bomb work",function()
    local N,meter=setup(); local encoded=bomb(N); local before=refused(N)
    for sender=1,20 do
        for _=1,40 do addon(N,encoded,"Sender"..string.char(64+sender).."x-123") end
    end
    yes(meter.bytes<=20*2048,"twenty sender bomb flood is bounded in bytes, not wall time")
    yes(meter.calls<=20,"failed payloads remembered")
    eq(refused(N)-before,800); eq(counter(N,"deduped"),799)
    no(row(N).reported); no(N.Main.error)
    print("WORK addon800: "..meter.calls.." inflate calls, "..meter.bytes.." inflated bytes")
end)

test("decode attempt cap spans both prefixes and every route for one identity",function()
    local N,meter=setup(); confirm()
    local function large(i)
        return encode(N,"^1^T^St^SFREC^Sv^N5^Srs^Spvp^Sd^T^Sjunk^S"..string.rep("a",2500)..i.."^t^t^^")
    end
    -- R2: attempts charge work above 2 KiB, not tiny parses. Reach that
    -- boundary through BN before probing addon aliases (no frame-cap masking).
    for i=1,16 do bn("WBF1|D|"..large(i)) end
    eq(meter.calls,16)
    for i,route in ipairs({"GUILD","PARTY","RAID","CHANNEL"}) do
        addon(N,large(16+i),"Enemy Player-123",route,i%2==0 and "WarBoardBN" or "WarBoard")
        yes(meter.caps[#meter.caps]<=2048,"no route reopens expensive attempts")
    end
    local e=encode(N,envelope(N,"SHRD",shrd()))
    addon(N,e); yes(row(N).reported,"small reports are still permitted")
    h.clock(h.clock()+9.99); bn("WBF1|D|"..large(21)); eq(meter.caps[#meter.caps],2048)
    h.clock(h.clock()+.01); bn("WBF1|D|"..large(22)); yes(meter.caps[#meter.caps]>2048)
    local count=meter.calls
    h.clock(h.clock()-1); addon(N,encode(N,"rollback")); eq(meter.calls,count)
end)

test("decode bytes budget stops distinct large frames before attempt cap",function()
    local N,meter=setup(); confirm()
    -- FREC's legitimate optional 200 IDs justify a larger envelope; padding is
    -- deliberately invalid but distinct, so failure memory cannot hide byte caps.
    for i=1,4 do
        local text="^1^T^St^SFREC^Sv^N5^Srs^Spvp^Sd^T^Sjunk^S"..string.rep("a",60000)..i.."^t^t^^"
        local e=encode(N,text)
        for p=1,math.ceil(#e/3800) do
            bn("WBF1|F|"..i.."|"..p.."|"..math.ceil(#e/3800).."|"..e:sub((p-1)*3800+1,p*3800))
        end
    end
    yes(meter.calls>=2,"exercise byte gate, not an inactive receive path")
    yes(meter.bytes<=131072,"sender may inflate at most 128 KiB per rolling ten seconds")
    local count=meter.calls
    bn("WBF1|D|"..encode(N,envelope(N,"SHRD",shrd())))
    eq(meter.calls,count,"exhausted bytes block even small frames")
    no(row(N).reported)
end)

test("failed hashes last sixty seconds without repeat refresh or retained payloads",function()
    local N,meter=setup(); confirm(); local encoded=bomb(N)
    bn("WBF1|D|"..encoded); eq(meter.calls,1)
    h.clock(h.clock()+10); bn("WBF1|D|"..encoded); eq(meter.calls,1,"failure survives decode window")
    h.clock(h.clock()+49.99); addon(N,encoded); eq(meter.calls,1,"shared transport failure memory")
    h.clock(h.clock()+.01); bn("WBF1|D|"..encoded); eq(meter.calls,2,"exact failure expiry; repeats never refresh it")
    local st=N.WarBoard.state
    yes(type(st.frames)=="table","bounded failure hash ledger exists")
    for key,value in pairs(st.frames or {}) do
        yes(#tostring(key)<=64,"hash, not full encoded payload retained")
        yes(type(value)=="table"); no(value.encoded); no(value.payload)
    end
end)

test("sender decode and failed-hash memory are bounded and expire",function()
    local N=setup()
    for i=1,220 do
        for j=1,3 do addon(N,encode(N,"invalid"..i..":"..j),"Sender"..string.char(65+math.floor((i-1)/26))..string.char(65+(i-1)%26).."x-123") end
    end
    local st=N.WarBoard.state
    yes(type(st.decodeRates)=="table"); yes(type(st.frames)=="table")
    yes(N.Safe.count(st.decodeRates or {})<=200)
    yes(N.Safe.count(st.frames or {})<=512)
    h.clock(h.clock()+60); h.wall(h.wall()+60)
    addon(N,encode(N,envelope(N,"SHRD",shrd())),"Fresh Sender")
    yes(row(N).reported,"expired tables must not permanently block fresh peers")
end)

test("decode sender bucket cap is independent of the input-frame bucket cap",function()
    local N,meter=setup(); local currentName
    C_BattleNet.GetGameAccountInfoByID=function(id)
        return {gameAccountID=id,characterName=currentName,realmName="123",factionName="Horde",clientProgram="WoW",
            isOnline=true,wowProjectID=42,isInCurrentRegion=true}
    end
    for i=1,201 do
        currentName="Carrier "..string.char(65+math.floor((i-1)/26))..string.char(65+(i-1)%26)
        local id=71+math.floor((i-1)/16)
        confirm(id); bn("WBF1|D|"..encode(N,"^1^T^St^SNO"..i.."^t^^"),id)
    end
    eq(meter.calls,200,"neither the sixteen/account nor input-frame cap may hide the sender-table bound")
    eq(N.Safe.count(N.WarBoard.state.decodeRates or {}),200)
    h.clock(h.clock()+10); h.wall(h.wall()+10)
    bn("WBF1|D|"..encode(N,envelope(N,"SHRD",shrd())),83)
    yes(row(N).reported,"expired sender entries reclaimed")
end)

test("failed hash cap evicts oldest and does not retain more than 512",function()
    local N,meter=setup()
    for i=1,35 do
        for j=1,16 do
            addon(N,encode(N,"^1^T^St^SNO"..i.."x"..j.."^t^^"),"Sender"..string.char(65+math.floor((i-1)/26))..string.char(65+(i-1)%26).."x-123")
        end
    end
    eq(meter.calls,560,"no other limit hides failure-cache eviction")
    eq(N.Safe.count(N.WarBoard.state.frames or {}),512)
    eq(#(N.WarBoard.state.frameOrder or {}),512)
end)

test("BN decode quota belongs to account as well as current character",function()
    local N,meter=setup(); confirm()
    local function large(i)
        return encode(N,"^1^T^St^SFREC^Sv^N5^Srs^Spvp^Sd^T^Sjunk^S"..string.rep("a",2500)..i.."^t^t^^")
    end
    for i=1,16 do bn("WBF1|D|"..large(i)) end
    eq(meter.calls,16)
    local old=C_BattleNet.GetGameAccountInfoByID
    C_BattleNet.GetGameAccountInfoByID=function(id) local r=old(id); r.characterName="Other Carrier"; return r end
    confirm(); bn("WBF1|D|"..large(17))
    eq(meter.caps[#meter.caps],2048,"new character and handshake cannot reset account's expensive quota")
    bn("WBF1|D|"..encode(N,envelope(N,"SHRD",shrd()))); yes(row(N).reported)
end)

test("every decoded frame is hashed even when record or context is refused",function()
    local N,meter=setup(); confirm(); local d=position(); d.rank=15
    local e=encode(N,envelope(N,"FBLP",d)); local before=refused(N)
    bn("WBF1|D|"..e); bn("WBF1|D|"..e)
    eq(meter.calls,1); eq(refused(N)-before,2)
    e=encode(N,N.Codec.aceWrite({t="SHRD",v=5,rs="normal",d=shrd()}))
    bn("WBF1|D|"..e); eq(meter.calls,2)
    GetRealmName=function() return "Normal 123" end
    bn("WBF1|A|5|normal|1.6.3|3"); bn("WBF1|D|"..e)
    eq(meter.calls,2); no(row(N).reported,"decoded-frame dedupe covers context refusals too")
    h.clock(h.clock()+60); h.wall(h.wall()+60); bn("WBF1|D|"..e)
    eq(meter.calls,3); yes(row(N).reported,"eligible again after the bounded sixty-second memory")
end)

test("decoded untracked frames reopen on tracking without waiting sixty seconds",function()
    local N,meter=setup(); confirm(); N.Find.remove(N.Main.find,"Enemy Player")
    local encoded=encode(N,envelope(N,"SHRD",shrd()))
    bn("WBF1|D|"..encoded); yes(N.Find.add(N.Main.find,"Enemy Player"))
    bn("WBF1|D|"..encoded); yes(row(N).reported); eq(meter.calls,2); eq(counter(N,"deduped"),0)
    local got=row(N).got
    h.clock(h.clock()+30); h.wall(h.wall()+30)
    bn("WBF1|D|"..encoded); eq(row(N).got,got); eq(meter.calls,2); eq(counter(N,"deduped"),1)
end)

test("accepted payload duplicates count hash hits and preserve first receipt",function()
    local N,meter=setup(); confirm(); local e=encode(N,envelope(N,"SHRD",shrd()))
    bn("WBF1|D|"..e); yes(row(N).reported); local got=row(N).got
    h.clock(h.clock()+1); addon(N,e,"Relay Carrier")
    eq(meter.calls,1); eq(counter(N,"deduped"),1); eq(row(N).got,got)
end)

test("one account holding unfinished parts cannot starve another for ten minutes",function()
    local N=setup(); confirm(71); confirm(72)
    local tries,stored=0,0
    local start,wall=h.clock(),h.wall()
    for sec=0,599 do
        h.clock(start+sec); h.wall(wall+sec)
        if sec%90==0 then
            for i=1,16 do bn("WBF1|F|"..string.format("%x",sec*100+i).."|1|2|xx",71) end
        end
        if sec%30==15 then
            tries=tries+1
            multipart(encode(N,envelope(N,"SHRD",shrd())),string.format("%x",900000+sec),72)
            if row(N).reported and row(N).got==h.clock() then stored=stored+1 end
        end
    end
    eq(tries,20); eq(stored,20,"all fresh two-part SHRD from the other account stored")
    yes(N.Safe.count(N.WarBoard.state.parts)<=2,"attacker owns at most two unfinished streams")
end)

test("two assembly slots per account release on completion conflict and expiry",function()
    local N=setup(); confirm(); local st=N.WarBoard.state
    for i=1,3 do bn("WBF1|F|"..i.."|1|2|x") end
    eq(N.Safe.count(st.parts),2)
    bn("WBF1|F|1|2|2|y"); eq(N.Safe.count(st.parts),1)
    bn("WBF1|F|3|1|2|x"); eq(N.Safe.count(st.parts),2)
    bn("WBF1|F|3|2|3|y"); eq(N.Safe.count(st.parts),1)
    h.clock(h.clock()+90); bn("WBF1|F|4|1|2|x"); eq(N.Safe.count(st.parts),1)
end)

for _,route in ipairs({"GUILD","PARTY","RAID","CHANNEL","BN third","BN self"}) do
    test("FBLP wording "..route,function()
        local N=setup(); local d=position()
        if route=="BN third" then
            C_BattleNet.GetGameAccountInfoByID=function(id)
                return {gameAccountID=id,characterName="Other Carrier",realmName="123",factionName="Horde",clientProgram="WoW",
                    isOnline=true,wowProjectID=42,isInCurrentRegion=true}
            end
        end
        local e=encode(N,envelope(N,"FBLP",d))
        if route:sub(1,2)=="BN" then confirm(); bn("WBF1|D|"..e)
        else addon(N,e,"Enemy Player-123",route) end -- even a matching addon sender is not authenticated BN self
        local r=row(N); yes(r.reported); eq(r.pos,"enemy")
        local text=N.Main.findDetails(r)
        if route=="BN self" then yes(text:find("own position",1,true))
        else yes(text:find("reported position",1,true)); no(text:find("own position",1,true)); eq(r.evidenceKind,"relayed") end
    end)
end

test("addon assembly quota aggregates all prefixes and routes for a sender",function()
    local N=setup(); local e=encode(N,envelope(N,"SHRD",shrd())); local cut=math.floor(#e/2)
    local streams={{"WarBoard","GUILD"},{"WarBoardBN","PARTY"},{"WarBoard","RAID"}}
    for _,r in ipairs(streams) do h.deliver("CHAT_MSG_ADDON",r[1],"\001"..e:sub(1,cut),r[2],"Relay Carrier") end
    h.deliver("CHAT_MSG_ADDON","WarBoard","\003"..e:sub(cut+1),"RAID","Relay Carrier")
    no(row(N).reported,"third route cannot allocate a third stream")
    h.deliver("CHAT_MSG_ADDON","WarBoard","\003"..e:sub(cut+1),"GUILD","Relay Carrier")
    yes(row(N).reported,"one of the two admitted streams completes")
end)

test("largest normal location payloads survive either envelope key order",function()
    local N=setup()
    local long=function(n) return string.rep("~",n) end -- worst-case Ace string escaping
    local shard=shrd(); shard.guid=long(80); shard.name=long(36); shard.realm=long(36)
    shard.zone=long(100); shard.shard=string.rep("9",12); shard.mapID=999999; shard.objId=long(160)
    local loc={targetGuid=long(80),targetName=long(80),faction="Horde",zone=long(100),sentAt=h.wall()}
    local p=position(); p.targetGuid=long(80); p.targetName=long(80); p.zone=long(100); p.subZone=long(100); p.shard=long(20)
    for i=1,100 do p.roster[i]={guid=long(80),name=long(80),faction="Alliance"} end
    local rec={id=long(160),name=long(80),guid=long(80),faction="Horde",rv=3,atype="witnessed_pvp_kill",
        creditDelta=0,contributionDelta=1,kills=1,t=h.wall(),zone=long(100),targetGuid="Player-"..long(73),
        witnessName=long(80),witnessGuid=long(79).."w",isRepeat=false,rewardWarCredit=0,clearedBountyIds={}}
    local batch={requestId=long(160),kind="witnessed_kills",page=100000,rulesVersion=3,relayName=long(80),
        relayGuid=long(80),faction="Horde",entries={}}
    for i=1,40 do batch.entries[i]=rec end
    local full={}; for k,v in pairs(rec) do full[k]=v end
    full.clearedBountyIds={}
    for i=1,200 do full.clearedBountyIds[i]=long(156)..string.format("%04d",i) end
    for _,k in ipairs({"objId","obj","contractId","claimWitnessId"}) do full[k]=long(160) end
    full.targetName=long(80); full.claimSourceGuid=long(80); full.claimVerification=long(20)
    for _,case in ipairs({{"SHRD",shard},{"FBLC",loc},{"FBLP",p},{"FREC",full},{"FCBD",batch}}) do
        local typ,d=case[1],case[2]
        -- Arbitrary Ace table iteration order is part of the donor protocol.
        local inner=N.Codec.aceWrite(d):sub(3,-3)
        for _,first in ipairs({true,false}) do
            local meta="^S"..string.rep("~|",80)
            local fields="^Sv^N5^Srs^Spvp^Sav"..meta.."^SsenderName"..meta.."^Sd"..inner
            local text="^1^T"..(first and "^St^S"..typ..fields or fields.."^St^S"..typ).."^t^^"
            yes(#text<caps[typ],"largest producer fixture fits its envelope ceiling")
            local decoded=N.WarBoard.decode(encode(N,text)); yes(decoded,typ.." survives max fields and either key order")
            eq(decoded.t,typ)
            print("SIZE "..typ..": "..#text.." / "..caps[typ])
        end
    end
end)

test("README explains the new-peer publication side effect below the send table",function()
    local f=assert(io.open("README.md")); local text=f:read("*a"); f:close()
    local line="When LayerEnemies completes the handshake, a real WarBoard client treats it as a new peer and shares its profile, kill streak and board snapshot with its Battle.net contacts, as it does for any WarBoard user."
    local at=text:find(line,1,true); yes(at,"owner-approved disclosure retained verbatim")
    yes(at>assert(text:find("| Tracking request/cancel |",1,true))); yes(at<assert(text:find("H, A, FBAK and FBUN use",1,true)))
    local why=text:find("**Why the handshake is needed**",1,true)
    yes(why and why>text:find("| Tracking request/cancel |",1,true) and why<at,"reason directly follows send table")
    local section=text:sub(why,assert(text:find("H, A, FBAK and FBUN use",why,true))-1)
    for _,required in ipairs({"a player's zone and shard, positions, and kill records",
        "peers that have completed its hello/answer exchange", "never answers a hello receives nothing at all",
        "reading WarBoard is impossible without it", "under its own name and version",
        "every eligible opposite-faction Battle.net friend or community member account that is online in WoW",
        "This handshake does not request a position broadcast; the tracking-request section above does."}) do
        yes(section:find(required,1,true),"handshake explanation includes: "..required)
    end
    eq(select(2,text:gsub("When LayerEnemies completes the handshake", "")),1,"no duplicate side-effect disclosure")
end)
