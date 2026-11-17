-- Owner's round-1 rulings; reviewer schedules replayed through real dispatch/Find.
local h=...
local test,eq,yes,no=h.test,h.eq,h.yes,h.no
local function setup()
    local N=h.load(); N.Net.SHIP.wanted=true; N.Net.setConsent("public")
    yes(N.Find.add(N.Main.find,"Enemy One")); return N
end
local function count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
local function peer(prefix,i) return prefix..string.char(65+i%26)..string.char(97+math.floor(i/26)).."x" end
local function sight(x) return {g="Player-1-AB",n="Enemy One",z="Ashenvale",m=100,x=x or 50,y=40} end
local function payload(N,t) return assert(N.Codec.addonEncode(assert(N.Codec.deflateStored(assert(N.Codec.lsWrite(t)))))) end
local function frames(N,tag,t,id,chunk)
    local b=payload(N,t); chunk=chunk or 240
    local out={}; local n=math.ceil(#b/chunk)
    for i=1,n do out[i]=tag..":"..(id or "a")..":"..i.."/"..n..":"..b:sub((i-1)*chunk+1,i*chunk) end
    return out
end
local function send(N,tag,t,route,sender,id)
    for _,f in ipairs(frames(N,tag,t,id)) do h.deliver("CHAT_MSG_ADDON","WNTD",f,route or "GUILD",sender or "Honest Mate") end
end
local function event(N,x,route,sender,id)
    local d=sight(x); d.v="1.29.2"; send(N,"E",d,route,sender,id); return d
end
local function row(N) return N.Find.rows(N.Main.find,h.clock(),100)[1] end
local function shown(N,x) local r=row(N); return r and r.reported and r.x and math.abs(r.x*100-x)<0.001 end
local function ledgerCount(N)
    -- Also reads the old flat ledger, to make the baseline failure behavioral.
    local rates=N.Wanted.state.rates
    if rates.guild then
        return count(rates.guild)+count(rates.channel)+count(rates.whisper)+count(rates.bnet)
    end
    return count(rates)
end

test("Wanted: R1 S1 300 channel users cannot suppress 75 guild sightings",function()
    local N=setup(); local shownCount,tries=0,0
    for sec=1,900 do
        h.advance(1)
        for k=1,3 do
            local i=(sec*3+k)%300
            h.deliver("CHAT_MSG_ADDON","WNTD","H:"..string.format("%x",sec)..":1/1:abc","CHANNEL",peer("User",i))
        end
        if sec%12==0 then
            tries=tries+1; local x=(tries%90)+1
            event(N,x,"GUILD",peer("Mate",tries%5),string.format("%x",tries))
            if shown(N,x) then shownCount=shownCount+1 end
        end
    end
    eq(tries,75); eq(shownCount,75); no(N.Main.error)
end)

test("Wanted: R1 S1 128 junk senders cannot suppress 20 guild sightings",function()
    local N=setup(); local shownCount,tries=0,0
    local function junk()
        for i=1,128 do h.deliver("CHAT_MSG_ADDON","WNTD","junk","CHANNEL",peer("Chan",i)) end
    end
    junk()
    for sec=1,600 do
        h.advance(1)
        if sec%100==0 then junk() end
        if sec%30==15 then
            tries=tries+1; event(N,tries,"GUILD","Honest Mate",string.format("%x",tries))
            if shown(N,tries) then shownCount=shownCount+1 end
        end
    end
    eq(tries,20); eq(shownCount,20); no(N.Main.error)
end)

test("Wanted: R1 S1 invalid tags and shapes take no sender entries",function()
    local N=setup(); local invalid={"junk","H:a:1/1:abc","R:0:1/1:a","R:a:0/2:a","R:a:1/13:a",
        "R:a:1/1:","R:a:1/1:"..string.rep("a",241),"R:1000:1/2:a"}
    for _,route in ipairs({"GUILD","CHANNEL","WHISPER"}) do
        for i,f in ipairs(invalid) do h.deliver("CHAT_MSG_ADDON","WNTD",f,route,peer("Junk",i)) end
    end
    send(N,"E",{v="1.29.2"},"WHISPER","Bad Route")
    eq(ledgerCount(N),0,"basic validation precedes sender admission")
    eq(count(N.Wanted.state.streams),0)
    event(N,21); yes(shown(N,21)); eq(ledgerCount(N),1)
end)

test("Wanted: R1 S1 valid channel whisper and BNet floods leave guild capacity",function()
    local N=setup(); local calls=0; local decode=N.Wanted.decode
    N.Wanted.decode=function(...) calls=calls+1; return decode(...) end
    for _,route in ipairs({"CHANNEL","WHISPER"}) do
        local before=calls
        for i=1,130 do h.deliver("CHAT_MSG_ADDON","WNTD","R:a:1/1:bad",route,peer("Flood",i)) end
        eq(calls-before,128,"independent capped "..route.." table")
    end
    N.BNet.who=function() return nil end
    for i=1,130 do h.deliver("BN_CHAT_MSG_ADDON","WNTDB","bad","WHISPER",i) end
    local before=calls
    for i=1,130 do h.deliver("CHAT_MSG_ADDON","WNTD","R:a:1/1:bad","GUILD",peer("Mate",i)) end
    eq(calls-before,128,"guild has its own full cap")
    eq(ledgerCount(N),512)
    -- Existing member is still serviced when every lane is full.
    event(N,22,"GUILD",peer("Mate",1)); yes(shown(N,22))
    h.clock(h.clock()+120); N.Sources.tick(h.clock()); eq(ledgerCount(N),0)
end)

local function hash(r)
    local keys={}; for k in pairs(r.data) do keys[#keys+1]=k end; table.sort(keys)
    local s=r.kind.."\n"..r.id.."\n"..r.prev.."\n"..tostring(r.t)
    for _,k in ipairs(keys) do s=s.."\n"..k.."="..tostring(r.data[k]) end
    local a,b=1,0; for i=1,#s do a=(a+s:byte(i))%65521; b=(b+a)%65521 end
    return string.format("%08x",b*65536+a)
end
local function record(i,origin)
    origin=origin or "Honest Mate"
    local r={kind="kill",id=origin..":"..(1000000+i),origin=origin,seq=1000000+i,prev="0",t=GetServerTime(),
        data={victim="Player-1-AB",victimName="Enemy One",victimFaction="Horde",zone="Stormwind City",mapId=200,x=50,y=40}}
    r.hash=hash(r); return r
end
local function report(N,r,route,sender,id)
    r.hash=hash(r); send(N,"F",{v="1.29.2",r={r}},route,sender,id)
end

test("Wanted: R1 S2 sightings show only map-derived zone never free text",function()
    for _,text in ipairs({"Orgrimmar (confirmed by GM)","\226\128\174reversed","a\tb","x\0y","line\nbreak","|cffff0000Org|r",string.rep("Z",65)}) do
        for _,tag in ipairs({"E","S"}) do
            local N=setup(); local d=sight(); d.z=text; d.v="1.29.2"
            send(N,tag,tag=="E" and d or {v="1.29.2",s={d}},"CHANNEL","Some Stranger")
            local r=row(N); yes(r and r.reported); eq(r.zone,100)
            local detail=N.Main.findDetails(r)
            no(detail:find(text,1,true),"sender free text absent"); yes(detail:find("Ashenvale",1,true))
        end
    end
end)

test("Wanted: R1 S2 records cannot contradict map zone or inject bidi",function()
    for _,text in ipairs({"Stormwind City","Orgrimmar (confirmed by GM)","\226\128\174reversed"}) do
        local N=setup(); local r=record(1); r.data.zone=text
        report(N,r,"CHANNEL","Some Stranger")
        local out=row(N); yes(out and out.reported); eq(out.zone,200)
        local detail=N.Main.findDetails(out)
        no(detail:find(text,1,true)); yes(detail:find("Durotar",1,true))
    end
end)

test("Wanted: R1 S2 absent invalid and unresolved maps have no zone fallback",function()
    for _,map in ipairs({false,0,-1,1.5,"100",1000000,424242}) do
        for _,kind in ipairs({"sighting","record"}) do
            local N=setup()
            if kind=="sighting" then
                local d=sight(); d.m=map or nil; d.z="Orgrimmar (confirmed by GM)"
                send(N,"S",{v="1.29.2",s={d}})
            else
                local r=record(1); r.data.mapId=map or nil; r.data.zone="Orgrimmar (confirmed by GM)"
                report(N,r)
            end
            local r=row(N)
            -- Malformed records may still fail scalar/hash validation; never show free text.
            if r and r.reported then
                eq(r.zone,nil); no(N.Main.findDetails(r):find("Orgrimmar",1,true))
                if map~=424242 then eq(r.x,nil); eq(r.y,nil) end
            end
            if map==false then yes(r and r.reported,"mapless evidence survives with place unknown") end
        end
    end
end)

local function hold(route,sender,id)
    h.deliver("CHAT_MSG_ADDON","WNTD","S:"..id..":1/2:xx",route,sender)
end

test("Wanted: R1 S3 two assemblies per canonical sender across routes",function()
    local N=setup()
    hold("GUILD","Honest Mate","1"); hold("CHANNEL","Honest Mate-TestRealm","2")
    h.deliver("CHAT_MSG_ADDON","WNTD","R:3:1/2:xx","WHISPER","Honest Mate")
    eq(count(N.Wanted.state.streams),2)
    h.clock(h.clock()+30); N.Sources.tick(h.clock()); eq(count(N.Wanted.state.streams),0)
    hold("GUILD","Honest Mate","4"); eq(count(N.Wanted.state.streams),1)
end)

test("Wanted: R1 S3 BNet dispatch shares one assembly owner across message IDs",function()
    local N=setup(); N.BNet.who=function() return {name="Other Peer",realm="Test Realm",faction="Horde"} end
    for i=1,3 do h.deliver("BN_CHAT_MSG_ADDON","WNTDP",i..":1/2:xx","WHISPER",71) end
    eq(count(N.Wanted.state.streams),2)
    h.deliver("BN_CHAT_MSG_ADDON","WNTDP","1:1/2:xx","WHISPER",72)
    eq(count(N.Wanted.state.streams),3,"another peer keeps its own allowance")
end)

test("Wanted: R1 S3 reserved assemblies survive a full public pool",function()
    local N=setup()
    for i=1,8 do hold("CHANNEL",peer("Holder",i),"1"); hold("CHANNEL",peer("Holder",i),"2") end
    eq(count(N.Wanted.state.streams),8,"only eight public slots")
    -- BNet cannot borrow the guild reserve either.
    N.BNet.who=function() return {name="Other Peer",realm="Test Realm",faction="Horde"} end
    h.deliver("BN_CHAT_MSG_ADDON","WNTDP","1:1/2:xx","WHISPER",71)
    eq(count(N.Wanted.state.streams),8)
    for i=1,4 do hold("GUILD",peer("Mate",i),"1"); hold("GUILD",peer("Mate",i),"2") end
    eq(count(N.Wanted.state.streams),16)
    hold("GUILD","Overflow Mate","1"); eq(count(N.Wanted.state.streams),16)
end)

test("Wanted: R1 S3 renewed channel holds cannot suppress 20 five-frame guild messages",function()
    local N=setup(); local big={v="1.29.2",s={}}
    for i=1,15 do big.s[i]=sight(); big.s[i].z="Zone "..i..string.rep("q",40) end
    eq(#frames(N,"S",big),5,"reviewer's genuine five-frame S")
    local function holders(sec)
        for sender=1,4 do
            for i=1,4 do hold("CHANNEL",peer("Hold",sender),string.format("%x",sec+i)) end
        end
    end
    holders(0); local shownCount,tries=0,0
    for sec=1,600 do
        h.advance(1)
        if sec%29==0 then holders(sec) end
        if sec%30==15 then
            tries=tries+1; for _,d in ipairs(big.s) do d.x=tries end
            send(N,"S",big,"GUILD","Honest Mate",string.format("%x",tries))
            if shown(N,tries) then shownCount=shownCount+1 end
        end
    end
    eq(tries,20); eq(shownCount,20); no(N.Main.error)
end)

test("Wanted: R1 S3 sixty sightings a minute cannot freeze another guildmate",function()
    for _,route in ipairs({"CHANNEL","GUILD"}) do
        local N=setup(); yes(N.Find.add(N.Main.find,"Protected One"))
        local d=sight(); d.n="Protected One"; d.g="Player-1-AC"; d.v="1.29.2"
        send(N,"E",d,"GUILD","Protected Mate")
        local held=N.Known.get(N.Main.find.known,"Protected One",h.clock()).reported.at
        for minute=1,12 do
            for i=1,60 do event(N,50,route,"Flood Sender",string.format("%x",(minute-1)*60+i)) end
            for _=1,60 do h.advance(1) end
        end
        eq(count(N.Wanted.state.seen),33,"32 flood IDs plus protected guild ID")
        h.advance(30); event(N,23,"GUILD","Honest Mate"); yes(shown(N,23))
        local accepted=N.Wanted.stats.accepted
        send(N,"E",d,"GUILD","Protected Mate")
        eq(N.Wanted.stats.accepted,accepted,"flood never evicts someone else's replay identity")
        eq(N.Known.get(N.Main.find.known,"Protected One",h.clock()).reported.at,held)
    end
end)

test("Wanted: R1 S3 replay ownership is carrier-wide across routes and record origins",function()
    local N=setup()
    for i=1,32 do
        h.advance(3)
        if i%2==0 then event(N,i,"GUILD","Flood Sender",string.format("%x",i))
        else
            local r=record(i,peer("Origin",i)); r.data.x=i
            report(N,r,"WHISPER","Flood Sender-TestRealm",string.format("%x",i))
        end
    end
    eq(count(N.Wanted.state.seen),32); yes(shown(N,32))
    event(N,33,"CHANNEL","Flood Sender","ee"); yes(shown(N,33),"full sender quota evicts rather than silences")
    eq(count(N.Wanted.state.seen),32,"sender quota still covers packet and record IDs")
    local r=record(99,"Invented Origin"); r.data.x=34
    report(N,r,"GUILD","Flood Sender","ef"); yes(shown(N,34))
    eq(count(N.Wanted.state.seen),32,"origin aliases cannot buy extra quota")
    event(N,35,"GUILD","Honest Mate"); yes(shown(N,35))
    h.clock(h.clock()+3600); N.Sources.tick(h.clock()); eq(count(N.Wanted.state.seen),0)
    event(N,36,"GUILD","Flood Sender","ee"); yes(shown(N,36),"expiry releases sender quota")
end)

test("Wanted: R1 S3 replay reserves 256 guild entries within global 512",function()
    local N=setup()
    for sender=1,8 do
        for i=1,32 do event(N,50,"CHANNEL",peer("Public",sender),string.format("%x",i)) end
    end
    eq(count(N.Wanted.state.seen),256)
    event(N,51,"CHANNEL","Overflow Public"); eq(count(N.Wanted.state.seen),256); yes(shown(N,51))
    local r=record(1); r.data.x=52
    report(N,r,"WHISPER","Overflow Whisper"); eq(count(N.Wanted.state.seen),256); yes(shown(N,52))
    for sender=1,8 do
        for i=1,32 do event(N,53,"GUILD",peer("Guild",sender),string.format("%x",i)) end
    end
    eq(count(N.Wanted.state.seen),512); yes(shown(N,53))
    event(N,54,"GUILD","Overflow Guild"); eq(count(N.Wanted.state.seen),512); yes(shown(N,54))
    h.clock(h.clock()+3600); N.Sources.tick(h.clock()); eq(count(N.Wanted.state.seen),0)
    event(N,55,"CHANNEL","Overflow Public"); yes(shown(N,55))
end)

test("Wanted: R1 N6 accepts any 1.29 patch and no other version family",function()
    for _,v in ipairs({"1.29.0","1.29.1","1.29.2","1.29.3","1.29.9","1.29.99","1.29.1000","1.29.2147483648"}) do
        local N=setup(); local d=sight(); d.v=v
        send(N,"E",d); yes(shown(N,50),v)
        h.advance(1); d.x=51
        send(N,"S",{v=v,s={d}},"GUILD",nil,"b"); yes(shown(N,51),v.." batch")
        local r=record(1); r.hash=hash(r)
        send(N,"F",{v=v,r={r}},"WHISPER","Carrier Mate","c"); eq(row(N).zone,200,v.." record")
    end
    for _,v in ipairs({"1.28.0","1.28.9","1.30.0","0.29.3","2.29.3","1.29","1.29.","1.29.-1","1.29.+3",
        "1.29.3.1","1.29.3-beta","1.29.3 "," 1.29.3","LayerEnemies"}) do
        local N=setup(); local d=sight(); d.v=v
        send(N,"E",d); no(row(N).reported,v)
    end
end)
