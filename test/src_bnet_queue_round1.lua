local h=...
local test,eq,yes,no=h.test,h.eq,h.yes,h.no
local function setup()
    local N=h.load()
    _G.WOW_PROJECT_ID=42
    C_BattleNet.GetGameAccountInfoByID=function(id)
        return {gameAccountID=id,characterName="Other Player",realmName="Other Realm",factionName="Horde",clientProgram="WoW",
            isOnline=true,wowProjectID=42,isInCurrentRegion=true}
    end
    return N
end
local function register(N,name,prefix)
    local counters={}
    yes(N.Sources.register{name=name,prefixes={prefix},counters=counters})
    return counters
end
local function sent()
    local out={}; for _,s in ipairs(h.sent()) do if s.kind=="BN" then out[#out+1]=s end end; return out
end

for _,row in ipairs({{"wanted","WNTDB",4},{"overlord","OLQueue",8},{"warboard","WBQueue",10}}) do
    test("BNet queue: S1 configured admission cap "..row[1],function()
        local N=setup(); local c=register(N,row[1],row[2])
        for i=1,row[3] do yes(N.BNet.send(row[1],71,row[2],"own-"..i,"own")) end
        no(N.BNet.send(row[1],72,row[2],"overflow","own"),"refuse beyond the network share at admission")
        no(N.BNet.send(row[1],72,row[2],"overflow-owed","owed"),"owed still obeys the per-network cap")
        eq(N.BNet.queued(),row[3]); eq(c.refused,2); eq(#sent(),0)
        h.advance(1); eq(c.sent,1); eq(N.BNet.queued(),row[3]-1)
        yes(N.BNet.send(row[1],72,row[2],"replacement","owed"),"dispatch frees one network slot")
        no(N.BNet.send(row[1],71,row[2],"over-replacement","own"))
        eq(N.BNet.queued(),row[3]); eq(c.refused,3)
        N.BNet.cancel(row[1]); eq(N.BNet.queued(),0)
        yes(N.BNet.send(row[1],71,row[2],"after-cancel","owed"),"cancellation frees admission")
    end)
end

for _,size in ipairs({1,2,4,32}) do
    test("BNet queue: S1 default fair admission share across "..size.." registered sources",function()
        local N=setup(); local rows={}; local limit=math.max(1,math.floor(30/size))
        for i=1,size do
            local name,prefix="source"..h.abc(i),"Queue"..i
            rows[i]={name=name,prefix=prefix,c=register(N,name,prefix)}
        end
        for _,r in ipairs(rows) do
            for i=1,limit do yes(N.BNet.send(r.name,71,r.prefix,"own-"..i,"own")) end
            no(N.BNet.send(r.name,71,r.prefix,"overflow","own"),"default is a fair share, not all 60 slots")
            no(N.BNet.send(r.name,72,r.prefix,"overflow-owed","owed"))
            eq(r.c.refused,2)
        end
        eq(N.BNet.queued(),limit*size)
    end)
end

test("BNet queue: S1 default fair share also limits rolling dispatch",function()
    local N=setup(); local c=register(N,"alpha","AlphaQueue"); register(N,"beta","BetaQueue")
    for i=1,16 do
        yes(N.BNet.send("alpha",71,"AlphaQueue","line"..i,"own"))
        h.advance(1)
    end
    eq(#sent(),15,"refilling the queue must not bypass the default per-minute share")
    eq(c.sent,15); eq(N.BNet.queued(),1); eq(c.refused,0)
    for _=1,44 do h.advance(1) end; eq(#sent(),15)
    h.advance(1); eq(#sent(),16); eq(N.BNet.queued(),0)
end)

test("BNet queue: S1 configured and default sources share one rolling cap",function()
    local N=setup()
    local rows={{"overlord","OLQueue",8},{"wanted","WNTDB",4},{"warboard","WBQueue",10},
        {"alpha","AlphaQueue",6},{"beta","BetaQueue",6}}
    for _,r in ipairs(rows) do register(N,r[1],r[2]) end
    for _,r in ipairs(rows) do
        for i=1,r[3] do yes(N.BNet.send(r[1],71,r[2],r[1]..i,"own")) end
    end
    eq(N.BNet.queued(),34)
    for _=1,30 do h.advance(1) end; eq(#sent(),30)
    for _=1,30 do h.advance(1) end
    eq(#sent(),30,"individual shares must not enlarge the global thirty-attempt limit")
    eq(N.BNet.queued(),4,"the test reaches the shared-budget wait with individually eligible work")
end)

test("BNet queue: S1 normal flood leaves eight owed-only slots",function()
    local N=setup()
    -- Register in stages to reach the global boundary independently of the
    -- per-network caps. New registrations tighten future admissions, not old ones.
    register(N,"alpha","AlphaQueue")
    for i=1,30 do yes(N.BNet.send("alpha",71,"AlphaQueue","alpha-"..i,"own")) end
    for _,r in ipairs({{"warboard","WBQueue",10},{"overlord","OLQueue",8},{"wanted","WNTDB",4}}) do
        register(N,r[1],r[2])
        for i=1,r[3] do yes(N.BNet.send(r[1],71,r[2],r[1]..i,"own")) end
    end
    local beta=register(N,"beta","BetaQueue")
    eq(N.BNet.queued(),52)
    no(N.BNet.send("beta",71,"BetaQueue","normal-overflow","own"),"normal traffic cannot use the eight reserved slots")
    eq(beta.refused,1); eq(N.BNet.queued(),52)
    for i=1,4 do yes(N.BNet.send("beta",71,"BetaQueue","owed-beta-"..i,"owed")) end
    local gamma=register(N,"gamma","GammaQueue")
    for i=1,4 do yes(N.BNet.send("gamma",71,"GammaQueue","owed-gamma-"..i,"owed")) end
    eq(N.BNet.queued(),60)
    no(N.BNet.send("gamma",71,"GammaQueue","owed-overflow","owed"),"absolute queue cap still applies")
    eq(gamma.refused,1)
    h.advance(1); eq(#sent(),1); eq(N.BNet.queued(),59)
    no(N.BNet.send("beta",71,"BetaQueue","normal-after-owed","own"),"dispatching owed does not release a normal slot")
    for _=1,7 do h.advance(1) end
    local rows=sent(); eq(#rows,8)
    for i,r in ipairs(rows) do
        eq(r.text,i<=4 and "owed-beta-"..i or "owed-gamma-"..(i-4),"all eight owed frames leave before normal traffic")
    end
    h.advance(1); eq(#sent(),9)
    yes(N.BNet.send("beta",71,"BetaQueue","normal-after-normal","own"),"dispatching normal releases a normal slot")
end)

test("BNet queue: S1 owed occupancy does not shrink the normal allowance",function()
    local N=setup(); register(N,"alpha","AlphaQueue")
    for i=1,30 do yes(N.BNet.send("alpha",71,"AlphaQueue","owed-"..i,"owed")) end
    for _,r in ipairs({{"warboard","WBQueue",10},{"overlord","OLQueue",8},{"wanted","WNTDB",4},
        {"beta","BetaQueue",6},{"gamma","GammaQueue",2}}) do
        register(N,r[1],r[2])
        for i=1,r[3] do yes(N.BNet.send(r[1],71,r[2],r[1]..i,"own"),"available non-reserved slots remain usable") end
    end
    eq(N.BNet.queued(),60)
    no(N.BNet.send("gamma",71,"GammaQueue","overflow","owed"))
end)

test("BNet queue: S1 reviewer flood admits another source and its owed answer within share",function()
    local N=setup(); local wanted=register(N,"wanted","WNTDB"); local other=register(N,"warboard","WBQueue")
    local admitted,serial={},0
    local function offer(net,prefix,prio)
        serial=serial+1; local text=net..serial
        if N.BNet.send(net,71,prefix,text,prio) then admitted[text]={at=h.clock(),net=net}; return true,text end
        return false,text
    end
    local accepted=0
    for _=1,1000 do if offer("wanted","WNTDB","own") then accepted=accepted+1 end end
    eq(accepted,4,"the reviewer's 1000-frame burst holds only Wanted's four slots")
    eq(wanted.refused,996)
    local ok,normal=offer("warboard","WBQueue","own"); yes(ok,"other source is still admitted")
    local owed; ok,owed=offer("warboard","WBQueue","owed"); yes(ok,"owed answer is still admitted")
    local start=h.clock()
    for _=1,125 do
        h.advance(1)
        for _=1,10 do offer("wanted","WNTDB","own") end
    end
    for _=1,61 do h.advance(1) end
    local rows,seen=sent(),{}
    yes(#rows>6,"sustained flood actually exercises later rolling windows")
    eq(rows[1].text,owed,"owed answer goes first")
    for i,r in ipairs(rows) do
        local a=admitted[r.text]; yes(a,"only admitted work leaves"); no(seen[r.text],"no retries"); seen[r.text]=r.at
        yes(r.at-a.at<=60,"nothing leaves more than sixty seconds after admission")
        if i>1 then yes(r.at-rows[i-1].at>=1,"global one-second spacing") end
        local all,net=0,0
        for j=1,i do
            if r.at-rows[j].at<60 then
                all=all+1; if rows[j].prefix==r.prefix then net=net+1 end
            end
        end
        yes(all<=30,"shared rolling minute"); yes(net<=(r.prefix=="WNTDB" and 4 or 10),"network rolling share")
    end
    yes(seen[normal] and seen[normal]-start<=60,"other source's normal frame leaves within its lifetime")
    yes(seen[owed] and seen[owed]-start<=60,"owed answer leaves within its lifetime")
    eq(other.sent,2); eq(other.refused,0); eq(N.BNet.queued(),0)
    h.advance(900); eq(#sent(),#rows,"no fifteen-minute backlog remains")
end)

test("BNet queue: S1 exact sixty-second boundary is live but older frames drop",function()
    local N=setup(); local c=register(N,"alpha","AlphaQueue"); local start=h.clock()
    yes(N.BNet.send("alpha",71,"AlphaQueue","at-boundary","own"))
    yes(N.BNet.send("alpha",71,"AlphaQueue","too-old","owed"))
    h.advance(60)
    local rows=sent(); eq(#rows,1); eq(rows[1].text,"too-old","owed wins at exactly sixty seconds")
    eq(rows[1].at-start,60); eq(N.BNet.queued(),1); eq(c.refused,0)
    h.advance(.001); N.BNet.pump(h.clock())
    eq(#sent(),1); eq(N.BNet.queued(),0,"expiry runs even inside the one-second pacing gate")
    eq(c.sent,1); eq(c.refused,1,"stale frame counted once")
    h.advance(900); eq(#sent(),1); eq(c.refused,1)
end)

for _,prio in ipairs({"own","owed"}) do
    test("BNet queue: S1 delayed dispatch drops expired "..prio.." frames",function()
        local N=setup(); local c=register(N,"alpha","AlphaQueue")
        yes(N.BNet.send("alpha",71,"AlphaQueue","old",prio))
        h.advance(61)
        eq(#sent(),0,"an old frame never reaches the client")
        eq(N.BNet.queued(),0); eq(c.sent,0); eq(c.refused,1)
        yes(N.BNet.send("alpha",71,"AlphaQueue","fresh",prio)); h.advance(1)
        eq(#sent(),1); eq(sent()[1].text,"fresh"); eq(c.sent,1)
        h.advance(900); eq(#sent(),1); eq(c.refused,1)
    end)
end

test("BNet queue: S1 expiry runs while the rolling minute is exhausted",function()
    local N=setup(); local alpha=register(N,"alpha","AlphaQueue"); register(N,"beta","BetaQueue")
    yes(N.BNet.send("alpha",71,"AlphaQueue","old-own","own"))
    h.advance(.5)
    for i=1,14 do yes(N.BNet.send("alpha",71,"AlphaQueue","owed-a"..i,"owed")) end
    for i=1,15 do yes(N.BNet.send("beta",71,"BetaQueue","owed-b"..i,"owed")) end
    for i=1,30 do
        h.advance(1)
        if i==1 then yes(N.BNet.send("alpha",71,"AlphaQueue","owed-replacement","owed")) end
    end
    eq(#sent(),30); eq(N.BNet.queued(),1); eq(alpha.refused,0)
    h.advance(30) -- old-own age 60.5, oldest attempt age 59: budget still exhausted.
    eq(#sent(),30); eq(N.BNet.queued(),0,"expired work is not held until the minute opens")
    eq(alpha.refused,1)
    yes(N.BNet.send("alpha",71,"AlphaQueue","fresh","own"))
    h.advance(1); eq(#sent(),31); eq(sent()[31].text,"fresh"); eq(alpha.refused,1)
end)

test("BNet queue: S1 unreadable admission clock fails closed",function()
    for _,clock in ipairs({function() return nil end,function() error("unreadable clock") end,function() return h.secret end}) do
        local N=setup(); local c=register(N,"alpha","AlphaQueue")
        _G.GetTime=clock
        no(N.BNet.send("alpha",71,"AlphaQueue","no-age","owed"),"must know the frame age before admission")
        eq(N.BNet.queued(),0); eq(c.refused,1)
        h.advance(61); eq(#sent(),0)
    end
end)
