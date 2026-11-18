-- R3 batch-hop regressions at the real Wire/client boundary, no donor code.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function receive(text,sender)
    H.deliver("CHAT_MSG_ADDON","FLHNET2",text,"WHISPER",sender or "Host a")
end
local function member()
    local N=H.load(); H.establish(N); H.clock(math.ceil(H.clock()))
    C_AddOns.GetAddOnMetadata=function() return "1.2.2" end
    N.Net.SHIP.flh=true; N.Net.SHIP.hh=true
    return N
end
local function hosts(N)
    for i=1,10 do receive("HI|100|"..(10+i).."|1|0.1.3|1234","Host "..H.abc(i)) end
    eq(#N.Main.candidates(),10,"host fixtures admitted")
end
local function lines(cmd)
    local out={}
    for _,s in ipairs(H.sent()) do
        if s.prefix=="FLHNET2" and s.text:match("^(%u+)")==cmd then out[#out+1]=s end
    end
    return out
end
local function ordinary(N,n)
    for i=1,n do
        yes(N.Wire.send("HeadHunter","1AN:LayerEnemies","WHISPER","Other "..H.abc(i),{net="hh",prio="own"}))
    end
end
local function offer(N,q)
    local m=N.FLH.decode(q.text)
    receive("LO|"..m.id.."|100|"..m.wantedKey.."|0|0",q.target)
end
local function ceilings()
    -- Replay every actual attempt, including client refusals. No mirroring of
    -- Wire internals: independently enforce capacity 8/refill 1 per 1.5 s,
    -- at most 8 at one timestamp and at most 40 in any rolling 60 seconds.
    local tokens,last,same,stamp=8,nil,0,nil
    local sent=H.sent()
    for i,s in ipairs(sent) do
        if last and s.at>last then tokens=math.min(8,tokens+(s.at-last)/1.5) end
        last=math.max(last or s.at,s.at)
        yes(tokens>=1-1e-8,"shared burst/refill ceiling at attempt "..i)
        tokens=tokens-1
        if stamp==s.at then same=same+1 else stamp,same=s.at,1 end
        yes(same<=8,"eight at once")
        local n=0
        for j=1,i do if s.at-sent[j].at<60 then n=n+1 end end
        yes(n<=40,"forty in every rolling minute")
    end
end

test("FLH batch: ordinary whisper then offer at half a second accepts",function()
    local N=member(); hosts(N); ordinary(N,1)
    SlashCmdList.LAYERENEMIES("hop flh")
    eq(#lines("LQ"),6,"one shared token must remain for LR")
    local q=lines("LQ")[1]; H.advance(.5); offer(N,q)
    eq(#lines("LR"),1); eq(lines("LR")[1].target,q.target)
    H.deliver("PARTY_INVITE_REQUEST",q.target); eq(H.accepts(),1)
    ceilings(); no(N.Main.error)
end)

test("FLH batch: unsent queries pace without spending the reserved token",function()
    local N=member(); hosts(N); ordinary(N,2)
    SlashCmdList.LAYERENEMIES("hop flh"); eq(#lines("LQ"),5)
    H.advance(1); eq(#lines("LQ"),5)
    H.advance(1); eq(#lines("LQ"),6)
    H.advance(1.01); eq(#lines("LQ"),7) -- just beyond the fractional refill boundary
    offer(N,lines("LQ")[7]); eq(#lines("LR"),1)
    H.deliver("PARTY_INVITE_REQUEST",lines("LQ")[7].target); eq(H.accepts(),1)
    ceilings(); no(N.Main.error)
end)

test("FLH batch: ordinary and owed traffic cannot steal the reserved LR",function()
    local N=member(); hosts(N); ordinary(N,1)
    SlashCmdList.LAYERENEMIES("hop flh")
    no(N.Wire.send("LayerSwap","same","WHISPER","Normal Peer",{prio="own"}))
    receive("WP|42|1234|0.1.3|100|8|1","Stranger Alder")
    eq(#lines("WR"),0); eq(#lines("LQ"),6)
    offer(N,lines("LQ")[1]); eq(#lines("LR"),1)
    ceilings()
end)

test("FLH batch: reserve expires at the original window without a tick",function()
    local N=member(); hosts(N); local at=H.clock()
    SlashCmdList.LAYERENEMIES("hop flh"); eq(#lines("LQ"),7)
    H.clock(at+90)
    local sent=0
    for i=1,5 do if N.Wire.send("HeadHunter","1AH:own","WHISPER","Normal "..H.abc(i),{net="hh",prio="own"}) then sent=sent+1 end end
    for i=1,5 do if N.Wire.send("LayerSwap","inv layer <LS 100 want 7102-8 50.0,50.0>","WHISPER","Later "..H.abc(i),{prio="click"}) then sent=sent+1 end end
    eq(sent,8,"expiry releases the reserve even before the guest tick")
    offer(N,lines("LQ")[1]); eq(#lines("LR"),0)
    ceilings()
end)

local function limitHost(N,name)
    for _=1,3 do yes(N.Wire.send("HeadHunter","1AH:own","WHISPER",name,{net="hh",prio="own"})) end
end
local function namedQuery(N)
    local row=N.Main.candidates()[1]
    yes(N.Main.hopHostTo(row)); return lines("LQ")[1]
end
local function failureLines()
    local out={}
    for _,line in ipairs(H.log()) do if line:find("could not be sent (send limit); click again",1,true) then out[#out+1]=line end end
    return out
end

test("FLH batch: refused LR keeps selection and waits for actual budget room",function()
    local N=member(); hosts(N); limitHost(N,"Host a")
    local at=H.clock(); local q=namedQuery(N); local send=N.Wire.send; local attempts=0
    N.Wire.send=function(prefix,text,...)
        if text:match("^LR|") then attempts=attempts+1 end
        return send(prefix,text,...)
    end
    offer(N,q); eq(attempts,1); eq(#lines("LR"),0); yes(N.FLHMember.pending()); no(N.Main.invite.pending)
    for _=1,59 do H.advance(1); offer(N,q) end
    eq(attempts,1,"polls and duplicate offers must not spend retries")
    eq(#failureLines(),0); H.deliver("PARTY_INVITE_REQUEST",q.target); eq(H.accepts(),0)
    H.clock(at+60); N.FLHMember.tick(H.clock())
    eq(attempts,2); eq(#lines("LR"),1); eq(lines("LR")[1].target,q.target)
    eq(N.Main.invite.pending.at,at,"retry retains the original armed deadline")
    H.deliver("PARTY_INVITE_REQUEST",q.target); eq(H.accepts(),1)
    ceilings(); no(N.Main.error)
end)

for _,elapsed in ipairs({89,90}) do
    test("FLH batch: successful retry never extends invite authority at "..elapsed,function()
        local N=member(); hosts(N); limitHost(N,"Host a")
        local at=H.clock(); local q=namedQuery(N); offer(N,q)
        H.clock(at+89); N.FLHMember.tick(H.clock()); eq(#lines("LR"),1)
        H.clock(at+elapsed); H.deliver("PARTY_INVITE_REQUEST",q.target)
        eq(H.accepts(),elapsed<90 and 1 or 0); ceilings()
    end)
end

test("FLH batch: third LR refusal ends the click with one exact chat line and row note",function()
    local N=member(); hosts(N); local at=H.clock(); local q=namedQuery(N)
    H.result(3); offer(N,q); eq(#lines("LR"),1); yes(N.FLHMember.pending())
    eq(#failureLines(),0); no(N.Main.invite.pending)
    for i=1,2 do H.clock(at+i*30); N.FLHMember.tick(H.clock()); eq(#lines("LR"),i+1) end
    no(N.FLHMember.pending()); no(N.Main.invite.pending); eq(#failureLines(),1)
    eq(failureLines()[1],"LayerEnemies: hop request to "..q.target.." could not be sent (send limit); click again")
    yes(N.FLHMember.detail(N.Main.candidates()[1]):find("send limit",1,true))
    H.result(0); offer(N,q); H.advance(120); offer(N,q)
    eq(#lines("LR"),3); eq(#failureLines(),1)
    H.deliver("PARTY_INVITE_REQUEST",q.target); eq(H.accepts(),0); ceilings()
end)

test("FLH batch: pending LR at expiry prints once and never sends after ninety seconds",function()
    local N=member(); hosts(N); local at=H.clock(); local q=namedQuery(N)
    H.clock(at+89); H.result(3); offer(N,q); H.result(0)
    eq(#lines("LR"),1); yes(N.FLHMember.pending())
    H.clock(at+90); N.FLHMember.tick(H.clock()); eq(#failureLines(),1)
    no(N.FLHMember.pending()); H.clock(at+120); N.FLHMember.tick(H.clock()); offer(N,q)
    eq(#lines("LR"),1); eq(#failureLines(),1); ceilings()
end)

test("FLH batch: a full burst paces all queries within the original click window",function()
    local N=member(); hosts(N); ordinary(N,5)
    for i=1,3 do yes(N.Wire.send("LayerSwap","inv layer <LS 100 want 7102-8 50.0,50.0>","WHISPER","Normal "..H.abc(i),{prio="click"})) end
    local at=H.clock(); yes(N.FLHMember.hop()); eq(#lines("LQ"),0)
    H.clock(at+4); N.FLHMember.tick(H.clock()); eq(#lines("LQ"),1)
    offer(N,lines("LQ")[1]); eq(#lines("LR"),1); eq(N.Main.invite.pending.at,at)
    H.clock(at+90); H.deliver("PARTY_INVITE_REQUEST",lines("LQ")[1].target); eq(H.accepts(),0)
    ceilings(); no(N.Main.error)
end)

-- Additional budget boundaries: these assert real admitted attempts, not just
-- reservation flags, including release while the guest still awaits an invite.
test("FLH batch: the last rolling-minute slot belongs to LR",function()
    local N=member(); N.Net.SHIP.we=true; hosts(N); local at=H.clock()
    for i=1,34 do
        H.clock(at+(i-1)*1.5)
        if i%2==0 then
            yes(N.Wire.send("WEFF1","H|1.6.6|100|7086|1|19|0|123|100|456|H|60|1|42|1","PARTY",nil,{net="we",prio="own"}))
        else yes(N.Wire.send("LEGW1","R|probe-"..i,"GUILD",nil,{prio="own"})) end
    end
    H.clock(at+59); SlashCmdList.LAYERENEMIES("hop flh")
    eq(#lines("LQ"),5,"only five of six remaining minute slots are queryable")
    no(N.Wire.send("HeadHunter","1AH:own","WHISPER","Normal Peer",{net="hh",prio="own"}))
    offer(N,lines("LQ")[1]); eq(#lines("LR"),1); eq(#H.sent(),40)
    ceilings()
end)

test("FLH batch: LR success and explicit stop release shared capacity immediately",function()
    for _,stop in ipairs({false,true}) do
        local N=member(); hosts(N); local q=namedQuery(N)
        if stop then N.FLHMember.stop() else offer(N,q); yes(N.Main.invite.pending) end
        local admitted=0
        for i=1,5 do
            if N.Wire.send("HeadHunter","1AH:own","WHISPER","Normal "..H.abc(i),{net="hh",prio="own"}) then admitted=admitted+1 end
        end
        for i=1,5 do
            if N.Wire.send("LayerSwap","inv layer <LS 100 want 7102-8 50.0,50.0>","WHISPER","Later "..H.abc(i),{prio="click"}) then admitted=admitted+1 end
        end
        eq(admitted,stop and 7 or 6); eq(#H.sent(),8); ceilings()
    end
end)

test("FLH batch: a refused selection cannot be redirected by another queried host",function()
    local N=member(); hosts(N); limitHost(N,"Host a"); local at=H.clock()
    SlashCmdList.LAYERENEMIES("hop flh"); local queries=lines("LQ"); yes(#queries>=2)
    offer(N,queries[1]); offer(N,queries[2]); eq(#lines("LR"),0); no(N.Main.invite.pending)
    local id=N.FLH.decode(queries[1].text).id
    receive("LI|"..id.."|S|Other Leader",queries[1].target)
    H.deliver("PARTY_INVITE_REQUEST","Other Leader"); eq(H.accepts(),0)
    H.clock(at+60); N.FLHMember.tick(H.clock()); eq(#lines("LR"),1)
    eq(lines("LR")[1].target,queries[1].target)
    offer(N,queries[2]); H.deliver("PARTY_INVITE_REQUEST",queries[2].target); eq(H.accepts(),0)
    H.deliver("PARTY_INVITE_REQUEST",queries[1].target); eq(H.accepts(),1); ceilings()
end)

for _,mode in ipairs({"stop","share","consent","network","combat","instance","zone","donor","rollback"}) do
    test("FLH batch: retry and paced query cancellation on "..mode,function()
        for _,retry in ipairs({false,true}) do
            local N=member(); hosts(N); local at=H.clock()
            if retry then limitHost(N,"Host a") else ordinary(N,2) end
            SlashCmdList.LAYERENEMIES("hop flh"); local q=lines("LQ")[1]; yes(q)
            if retry then offer(N,q); eq(#lines("LR"),0) end
            local before=#lines("LQ")
            if mode=="stop" then N.FLHMember.stop()
            elseif mode=="share" then N.Main.setShare(false); N.Main.setShare(true)
            elseif mode=="consent" then N.Net.setConsent("guild"); N.Net.setConsent("public")
            elseif mode=="network" then N.Net.setSwitch("flh",false); N.Net.setSwitch("flh",true)
            elseif mode=="combat" then H.combat(true)
            elseif mode=="instance" then H.instance(true)
            elseif mode=="zone" then N.Main.store.zoneUID=99
            elseif mode=="donor" then H.loaded().ForeverLayerHop=true
            else H.clock(at-1); N.FLHMember.tick(H.clock()) end
            H.clock(at+60); N.FLHMember.tick(H.clock()); offer(N,q)
            eq(#lines("LQ"),before); eq(#lines("LR"),0); no(N.FLHMember.pending())
            H.deliver("PARTY_INVITE_REQUEST",q.target); eq(H.accepts(),0); ceilings(); no(N.Main.error)
        end
    end)
end

test("FLH batch: an offline head cannot block the paced batch",function()
    local N=member(); hosts(N); N.Wire.markOffline("Host a",H.clock())
    yes(N.FLHMember.hop()); eq(#lines("LQ"),6)
    eq(lines("LQ")[1].target,"Host b"); offer(N,lines("LQ")[1]); eq(#lines("LR"),1)
    ceilings()
end)

test("FLH batch: paced discovery still caps the whole click at seven queries",function()
    local N=member(); hosts(N); SlashCmdList.LAYERENEMIES("hop flh")
    for _=1,10 do H.advance(1) end
    eq(#lines("LQ"),7); ceilings()
end)

for _,stopAt in ipairs({2,6}) do
    for _,result in ipairs({0,3}) do
        test("FLH batch: stop inside LQ "..stopAt.." preserves attempted cooldown result "..result,function()
            local N=member(); hosts(N); if stopAt==6 then ordinary(N,2) end
            local at=H.clock(); local stopped,target,stamp=false
            H.result(function()
                local queries=lines("LQ")
                if not stopped and #queries==stopAt then
                    stopped=true; target=queries[stopAt].target; stamp=queries[stopAt].at
                    SlashCmdList.LAYERENEMIES("hop stop")
                    return result
                end
                return 0
            end)
            N.FLHMember.hop(); H.advance(2)
            yes(stopped,"real client callback stopped the initial or paced batch")
            eq(#lines("LQ"),stopAt); no(N.FLHMember.pending())
            eq(N.Main.invite.asked[N.Invite.key(target)],stamp,"canceled client attempt still spends name cooldown")
            H.result(0); H.clock(at+35); yes(N.FLHMember.hop())
            H.advance(10)
            local count=0
            for _,q in ipairs(lines("LQ")) do if q.target==target then count=count+1 end end
            eq(count,1,"a second click cannot re-query the canceled in-flight name before sixty seconds")
            ceilings(); no(N.Main.error)
        end)
    end
end

for _,reenterAt in ipairs({1,6}) do
    test("FLH batch: recursive tick inside LQ "..reenterAt.." cannot consume remaining targets",function()
        local N=member(); hosts(N); if reenterAt==6 then ordinary(N,2) end
        local entered=false
        H.result(function()
            if not entered and #lines("LQ")==reenterAt then
                entered=true; N.FLHMember.tick(H.clock())
            end
            return 0
        end)
        yes(N.FLHMember.hop()); H.advance(10); yes(entered,"client callback reentered the source tick")
        H.result(0)
        local seen={}
        for _,q in ipairs(lines("LQ")) do no(seen[q.target],"a target is attempted only once"); seen[q.target]=true end
        eq(#lines("LQ"),7,"nested tick cannot discard eligible targets")
        offer(N,lines("LQ")[7]); eq(#lines("LR"),1)
        H.deliver("PARTY_INVITE_REQUEST",lines("LQ")[7].target); eq(H.accepts(),1)
        ceilings(); no(N.Main.error)
    end)
end

for _,phase in ipairs({"offer","paced","retry","selected"}) do
    test("FLH batch: join then leave between ticks revokes "..phase.." click",function()
        local N=member(); hosts(N); local at=H.clock()
        if phase=="paced" then ordinary(N,2)
        elseif phase=="retry" then limitHost(N,"Host a") end
        if phase=="offer" or phase=="selected" then namedQuery(N) else yes(N.FLHMember.hop()) end
        local q=lines("LQ")[1]; yes(q)
        if phase=="retry" or phase=="selected" then offer(N,q) end
        local before,requests=#lines("LQ"),#lines("LR")
        eq(requests,phase=="selected" and 1 or 0)
        H.clock(at+.1); H.group(true); H.deliver("GROUP_ROSTER_UPDATE")
        yes(N.Main.wasGrouped,"real group handler observed joining")
        H.clock(at+.2); H.group(false); H.deliver("GROUP_ROSTER_UPDATE")
        H.clock(at+.3); offer(N,q); H.deliver("PARTY_INVITE_REQUEST",q.target)
        H.clock(at+60); N.FLHMember.tick(H.clock()); offer(N,q)
        eq(#lines("LR"),requests,"transient join revokes deferred or initial LR authority")
        eq(H.accepts(),0,"leaving cannot revive old click invite authority")
        eq(#lines("LQ"),before,"transient join cancels unsent paced queries")
        no(N.FLHMember.pending()); no(N.Main.invite.pending); ceilings(); no(N.Main.error)
    end)
end

for _,change in ipairs({"other layer","own layer","same layer new spelling","withdrawn"}) do
    test("FLH batch: paced query revalidates current host "..change,function()
        local N=member(); hosts(N); ordinary(N,2)
        local at=H.clock(); yes(N.FLHMember.hop()); eq(#lines("LQ"),5)
        H.clock(at+1)
        local key=change=="own layer" and N.FLHMember.context().key
            or change=="same layer new spelling" and "00016" or "99"
        receive("HI|100|"..key.."|"..(change=="withdrawn" and "0" or "1").."|0.1.3|1234","Host f")
        local live
        for _,row in ipairs(N.Main.candidates()) do if row.short=="host f" then live=row end end
        if change=="withdrawn" then no(live) else yes(live); eq(live.flhKey,key,"new claim reached the real host row") end
        H.clock(at+10); N.FLHMember.tick(H.clock())
        local asked
        for _,q in ipairs(lines("LQ")) do if q.target=="Host f" then asked=q end end
        if change=="same layer new spelling" then
            yes(asked); eq(N.FLH.decode(asked.text).wantedKey,key,"wire uses the exact current key, not the click-time spelling")
            offer(N,asked); eq(#lines("LR"),1)
        else
            no(asked,"changed or withdrawn host must not receive a stale query")
            no(N.Main.invite.asked["host f"],"a skipped host does not spend its cooldown")
            local last=lines("LQ")[#lines("LQ")]; eq(last.target,"Host g","skip cannot stall the next target")
            offer(N,last); eq(#lines("LR"),1)
        end
        ceilings(); no(N.Main.error)
    end)
end

-- The reviewer's r2b/r2c cadence: 12 clicks over 3600 timer-driven seconds,
-- refreshed host claims, 30 directory peers, and independent WP/CQ strangers.
local function replay(strangers,offset,delay)
    local N=member(); local names={}
    for i=1,30 do names[i]="Directory "..H.abc(i) end
    H.channelMembers("ForeverLayerHopNet",names)
    N.Directory.sync(); N.Directory.refresh("flh"); H.advance(3)
    N.UI.create(); N.UI.tab="friendly"; N.UI.frame:Show(); N.UI.render()
    hosts(N); for _=1,120 do H.advance(1) end
    local clicks,accepted=0,H.accepts()
    for s=1,3600 do
        H.advance(1)
        if strangers and s%10==0 then
            receive("WP|"..s.."|1234|0.1.3|100|8|1","Stranger "..H.abc(s/10))
            receive("CQ|"..s.."|100|8|1|0.1.3|1234","Asker "..H.abc(s/10))
        end
        if s%60==0 then hosts(N); N.Main.store.zoneUID=100+s/60 end
        if s%300==30+offset then
            local before=#lines("LQ")
            SlashCmdList.LAYERENEMIES("hop flh"); clicks=clicks+1
            H.advance(delay)
            local q=lines("LQ")[before+1]; yes(q,"click must actually query a host")
            eq(q.target:lower(),"host a"); offer(N,q)
            H.advance(.5); H.deliver("PARTY_INVITE_REQUEST",q.target)
            H.advance(1-((delay+.5)%1))
            SlashCmdList.LAYERENEMIES("hop stop")
            if N.Main.leaveGroup then N.Main.leaveGroup() end
        end
    end
    eq(clicks,12); ceilings(); no(N.Main.error)
    return clicks,H.accepts()-accepted
end
for _,delay in ipairs({.2,1}) do
    test("FLH batch replay: twelve WP plus CQ clicks with offer at "..delay,function()
        local clicks,accepted=replay(true,0,delay)
        print("FLH_REPLAY strangers delay="..delay.." accepted="..accepted.."/"..clicks)
        eq(accepted,12)
    end)
end
for _,strangers in ipairs({true,false}) do
    test("FLH batch replay: 120 offset clicks "..(strangers and "with strangers" or "own probes control"),function()
        local clicks,accepted=0,0
        for offset=0,18,2 do
            local n,a=replay(strangers,offset,.5); clicks,accepted=clicks+n,accepted+a
        end
        print("FLH_REPLAY offset-sweep strangers="..tostring(strangers).." accepted="..accepted.."/"..clicks)
        eq(clicks,120); eq(clicks-accepted,0)
    end)
end
