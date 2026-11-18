-- F2 reviewer rulings. Independent fixtures; donor source is never executed.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function receive(text,sender,kind)
    H.deliver("CHAT_MSG_ADDON","FLHNET2",text,kind or "WHISPER",sender or "Cedar Vale")
end
local function member()
    local N=H.load(); H.establish(N); H.clock(math.ceil(H.clock()))
    C_AddOns.GetAddOnMetadata=function() return "1.2.1" end
    N.Net.SHIP.flh=true; N.Net.SHIP.hh=true; N.Net.SHIP.we=true
    return N
end
local function lines(cmd)
    local out={}
    for _,s in ipairs(H.sent()) do
        if s.prefix=="FLHNET2" and (not cmd or s.text:match("^(%u+)")==cmd) then out[#out+1]=s end
    end
    return out
end
local function replies(n)
    for i=1,n do receive((i%2==0 and "CQ|42|100|8|1|0.1.3|1234" or "WP|42|1234|0.1.3|100|8|1"),"Owed "..H.abc(i)) end
end
local function ordinaryBurst(N,n)
    local sent=0
    for i=1,n do
        local ok
        if i<=5 then ok=N.Wire.send("LayerSwap","inv layer <LS 100 want 7102-8 50.0,50.0>","WHISPER","Normal "..H.abc(i),{prio="click"})
        else ok=N.Wire.send("HeadHunter","1AH:own","WHISPER","Peer "..H.abc(i),{net="hh",prio="own"}) end
        if ok then sent=sent+1 end
    end
    return sent
end
local function ordinaryMinute(N,limit)
    local start=H.clock(); local sent=0
    for i=1,78 do
        H.clock(start+(i-1)*.75)
        local ok
        if sent<(limit or 40) then
            if i%2==1 then ok=N.Wire.send("LEGW1","R|probe-"..i,"GUILD",nil,{prio="own"})
            else ok=N.Wire.send("WEFF1","H|1.6.6|100|7086|1|19|0|123|100|456|H|60|1|42|1","PARTY",nil,{net="we",prio="own"}) end
        end
        if ok then sent=sent+1 end
    end
    H.clock(start+59)
    return sent,start
end
local function probe(N)
    IsInGuild=function() return false end
    N.UI.create(); N.UI.tab="friendly"; N.UI.frame:Show()
    N.Directory.members=function() return {"Directory Alder"} end
    N.FLHMember.tick(H.clock())
end
local function host(N,name)
    name=name or "Cedar Vale"
    receive("HI|100|8|1|0.1.3|1234",name)
    for _,row in ipairs(N.Main.candidates()) do if row.short==name:lower() then return row end end
end
local function query(N)
    yes(N.Main.hopHostTo(host(N)))
    return N.FLH.decode(lines("LQ")[1].text).id
end
local function offer(id,sender)
    receive("LO|"..id.."|100|8|0|0",sender)
end

test("FLH member: R2 eight ordinary plus six owed replies never exceeds eight at once",function()
    local N=member(); eq(ordinaryBurst(N,11),8)
    replies(6); eq(#H.sent(),8); eq(#lines(),0)
    H.clock(H.clock()+1.5); replies(1)
    eq(#lines(),1,"a local refusal did not charge the owed sender")
end)

test("FLH member: R2 forty ordinary in fifty nine seconds leaves no reply room",function()
    local N=member(); local n,start=ordinaryMinute(N)
    eq(n,40); replies(6); eq(#H.sent(),40); eq(#lines(),0)
    H.clock(start+60); replies(1); eq(#lines(),1,"exact rolling expiry frees one slot")
end)

test("FLH member: R2 replies charge the shared bucket before ordinary traffic",function()
    local N=member(); replies(6); eq(#lines(),6)
    eq(ordinaryBurst(N,11),2); eq(#H.sent(),8)
    H.clock(H.clock()-60); replies(6); eq(ordinaryBurst(N,11),0); eq(#H.sent(),8)
end)

for _,cmd in ipairs({"HI","WR","CA","WP","LQ","LR"}) do
    test("FLH member: R2 "..cmd.." spends the overall burst",function()
        local N=member()
        if cmd=="HI" then N.FLHMember.tick(H.clock())
        elseif cmd=="WR" then receive("WP|42|1234|0.1.3|100|8|1")
        elseif cmd=="CA" then receive("CQ|42|100|8|1|0.1.3|1234")
        elseif cmd=="WP" then probe(N)
        elseif cmd=="LQ" then query(N)
        else offer(query(N)) end
        eq(#lines(cmd),1,"real authorized send reached the client")
        local reserve=cmd=="LQ" and 1 or 0
        eq(ordinaryBurst(N,11),8-#lines()-reserve); eq(#H.sent(),8-reserve)
    end)
end

test("FLH member: R2 probes leave six shared burst slots for owed replies",function()
    local N=member(); eq(ordinaryBurst(N,2),2)
    probe(N); eq(#lines("WP"),0,"probe loses priority at the shared ceiling")
    replies(6); eq(#lines(),6); eq(#H.sent(),8)
    H.clock(H.clock()+60); probe(N); eq(#lines("WP"),1,"refused probe keeps its name eligible")
end)

test("FLH member: R2 probes leave six shared minute slots for owed replies",function()
    local N=member(); eq(ordinaryMinute(N,34),34)
    probe(N); eq(#lines("WP"),0)
    replies(6); eq(#lines(),6); eq(#H.sent(),40)
end)

local function namedCount(list,name)
    local n=0; for _,v in ipairs(list) do if v==name then n=n+1 end end; return n
end
for _,mode in ipairs({"combat","instance"}) do
    test("FLH member: R2 directory stays joined through twenty "..mode.." periods",function()
        local N=member(); N.Directory.sync(); H.advance(3)
        local flh,hh="ForeverLayerHopNet","HeadHunterSync"
        eq(namedCount(H.joined(),flh),1); eq(namedCount(H.joined(),hh),1)
        for _=1,20 do
            if mode=="combat" then H.combat(true); H.deliver("PLAYER_REGEN_DISABLED") else H.instance(true) end
            local before=#lines()
            for _=1,30 do H.advance(1) end
            eq(#lines(),before,"membership sends stay gated")
            eq(N.Directory.joined("flh"),flh)
            if mode=="combat" then H.combat(false); H.deliver("PLAYER_REGEN_ENABLED") else H.instance(false) end
            for _=1,60 do H.advance(1) end
        end
        eq(namedCount(H.joined(),flh),1); eq(namedCount(H.left(),flh),0)
        eq(namedCount(H.joined(),hh),1); eq(namedCount(H.left(),hh),0)
        no(N.Main.error)
    end)
    test("FLH member: R2 privacy leave waits until after "..mode,function()
        local N=member(); N.Directory.sync(); eq(N.Directory.joined("flh"),"ForeverLayerHopNet")
        if mode=="combat" then H.combat(true) else H.instance(true) end
        N.Main.net("net flh off"); N.Directory.sync()
        eq(namedCount(H.left(),"ForeverLayerHopNet"),0)
        replies(1); eq(#lines(),0)
        H.combat(false); H.instance(false); N.Directory.sync()
        eq(namedCount(H.left(),"ForeverLayerHopNet"),1); no(N.Directory.joined("flh"))
    end)
end

for _,case in ipairs({{"LD|%d","declined"},{"LA|%d","didn't answer"},{"HQ|%d|2","queued you"},
    {"LN|%d","declined"},{"LN|%d|busy","declined"}}) do
    test("FLH member: R2 host status "..case[1].." cancels and prints once",function()
        local N=member(); local id=query(N); offer(id); yes(N.Main.invite.pending)
        local before=#H.log()
        receive(case[1]:format(id))
        H.deliver("PARTY_INVITE_REQUEST","Cedar Vale"); eq(H.accepts(),0)
        no(N.Main.invite.pending); no(N.FLHMember.pending())
        eq(#H.log(),before+1); yes(H.log()[#H.log()]:find(case[2],1,true))
        local detail=N.FLHMember.detail(host(N)); yes(detail:find(case[2],1,true))
        receive(case[1]:format(id)); offer(id)
        eq(#H.log(),before+1); eq(#lines("LR"),1); no(N.Main.error)
    end)
end

test("FLH member: R2 only the selected host and matching status can cancel",function()
    for _,status in ipairs({"LD|%d","LA|%d","HQ|%d|2","LN|%d","LN|%d|busy"}) do
        local N=member(); local id=query(N); offer(id); local before=#H.log()
        receive(status:format(id),"Stranger Alder")
        receive(status:format(id),"Cedar Vale-OtherRealm")
        receive(status:format(id+1)); receive(status:format(id),nil,"GUILD")
        eq(#H.log(),before); yes(N.Main.invite.pending)
        H.deliver("PARTY_INVITE_REQUEST","Cedar Vale"); eq(H.accepts(),1)
    end
end)

test("FLH member: R2 LI transfers authority only to its named whole leader",function()
    local N=member(); local id=query(N); offer(id); yes(N.Main.invite.pending)
    receive("LI|"..id.."|S|Leader Alder-OtherRealm")
    for _,name in ipairs({"Cedar Vale","Stranger Alder","Leader Alder","Leader Alder-TestRealm"}) do
        H.deliver("PARTY_INVITE_REQUEST",name); eq(H.accepts(),0)
    end
    H.deliver("PARTY_INVITE_REQUEST","Leader Alder-OtherRealm"); eq(H.accepts(),1)
    H.deliver("PARTY_INVITE_REQUEST","Leader Alder-OtherRealm"); eq(H.accepts(),1)
    eq(N.Main.auto.group.short,"leader alder-otherrealm"); no(N.Main.error)
end)

for _,elapsed in ipairs({89,90,91}) do
    test("FLH member: R2 LI retains the original ninety second window at "..elapsed,function()
        local N=member(); local start=H.clock(); local id=query(N)
        H.clock(start+85); offer(id); receive("LI|"..id.."|S|Leader Alder")
        H.clock(start+elapsed); H.deliver("PARTY_INVITE_REQUEST","Leader Alder")
        eq(H.accepts(),elapsed<90 and 1 or 0)
    end)
end

test("FLH member: R2 LI cannot arm without the selected host successful LR and id",function()
    for _,mode in ipairs({"no click","before offer","other host","other realm","wrong id","wrong route","LR refused"}) do
        local N=member(); local id=mode=="no click" and 1 or query(N)
        if mode~="no click" and mode~="before offer" then
            if mode=="LR refused" then H.result(3) end
            offer(id); H.result(0)
        end
        receive("LI|"..(mode=="wrong id" and id+1 or id).."|S|Leader Alder",
            mode=="other host" and "Stranger Alder" or mode=="other realm" and "Cedar Vale-OtherRealm" or nil,
            mode=="wrong route" and "GUILD" or nil)
        H.deliver("PARTY_INVITE_REQUEST","Leader Alder"); eq(H.accepts(),0,mode)
        if mode=="other host" or mode=="other realm" or mode=="wrong id" or mode=="wrong route" then
            H.deliver("PARTY_INVITE_REQUEST","Cedar Vale"); eq(H.accepts(),1,"invalid LI cannot redirect the pending host")
        end
    end
end)

test("FLH member: R2 LI missing or invalid leader never accepts anyone",function()
    for _,suffix in ipairs({"|S","|S|Bad2","|S|Me"}) do
        local N=member(); local id=query(N); offer(id)
        receive("LI|"..id..suffix)
        for _,name in ipairs({"Cedar Vale","Leader Alder"}) do H.deliver("PARTY_INVITE_REQUEST",name); eq(H.accepts(),0) end
        no(N.Main.error)
    end
end)

test("FLH member: R2 bare LI is only an acknowledgement and cannot undo a handoff",function()
    local N=member(); local id=query(N); offer(id); receive("LI|"..id)
    H.deliver("PARTY_INVITE_REQUEST","Cedar Vale"); eq(H.accepts(),1)
    N=member(); id=query(N); offer(id)
    receive("LI|"..id.."|S|Leader Alder"); receive("LI|"..id)
    H.deliver("PARTY_INVITE_REQUEST","Cedar Vale"); eq(H.accepts(),0)
    H.deliver("PARTY_INVITE_REQUEST","Leader Alder"); eq(H.accepts(),1)
end)

test("FLH member: R2 decline after LI cancels leader authority too",function()
    for _,status in ipairs({"LD|","LA|","LN|","HQ|"}) do
        local N=member(); local id=query(N); offer(id); receive("LI|"..id.."|S|Leader Alder")
        receive(status..id..(status=="HQ|" and "|2" or ""))
        H.deliver("PARTY_INVITE_REQUEST","Leader Alder"); eq(H.accepts(),0)
        no(N.Main.invite.pending); no(N.FLHMember.pending())
    end
end)
