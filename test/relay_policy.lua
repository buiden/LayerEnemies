-- Owner's round-1 rulings: real receive, slash-command, timer and Wire paths.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function fixture(saved)
    local N=H.load(saved); H.advance(1); H.establish(N)
    N.Relay.rand=function() return .5 end
    return N
end
local function incoming(prefix,text,sender)
    H.deliver("CHAT_MSG_ADDON",prefix,text,"PARTY",sender or "Birch Scout"); H.drain()
end
local function spy(i)
    incoming("[Spy]","1.3.8|Enemy "..H.abc(i or 1).."|MAGE|40|Orc|Ashenvale||0.4|0.6||100")
end
local function b36(n)
    local digits,out="0123456789abcdefghijklmnopqrstuvwxyz",""
    n=math.floor(n)
    repeat local r=n%36; out=digits:sub(r+1,r+1)..out; n=(n-r)/36 until n==0
    return out
end
local function hh(i)
    incoming("HeadHunter","1AP:"..b36(100)..";"..b36(GetServerTime())..";dw;6y;0000002A;Cedar Vale/M/40;4",
        "Cedar Scout"..(i and ("-"..H.abc(i)) or ""))
end
local function own()
    H.units().target=H.player("Ownenemy","Horde","Player-1-998")
    H.deliver("PLAYER_TARGET_CHANGED"); H.drain()
end
local function counts()
    local c={all=0,O=0,spy=0,hh=0}
    for _,m in ipairs(H.sent()) do
        if m.prefix=="LEGW1" then
            eq(m.kind,"GUILD"); c.all=c.all+1
            if m.text:sub(1,2)=="O|" then c.O=c.O+1 end
            if m.text:sub(1,8)=="R|1|spy|" then c.spy=c.spy+1 end
            if m.text:sub(1,7)=="R|1|hh|" then c.hh=c.hh+1 end
        end
    end
    return c
end
local function observe(N)
    own(); spy(); hh()
    yes(N.Main.store.localSeen["Player-1-998"],"own observation is live")
    yes(N.Known.get(N.Main.find.known,"Enemy a",H.clock()),"Spy observation is still received")
    local heardHH=false
    for _,r in pairs(N.Main.store.reports) do if r.record.src=="hh" then heardHH=true end end
    yes(heardHH,"HH observation is still received")
end
local function finish(N)
    for _=1,4 do H.advance(1) end
    N.Main.shareTick(); no(N.Main.error)
end

test("Guild relay policy: sharing on sends own, Spy and HeadHunter lines",function()
    local N=fixture(); observe(N); finish(N)
    local c=counts(); eq(c.O,1); eq(c.spy,1); eq(c.hh,1); eq(c.all,3)
end)
for _,mode in ipairs({"before receipt","during wait","saved off"}) do
    test("Guild relay policy: share off silences own, Spy and HeadHunter "..mode,function()
        local N=fixture(mode=="saved off" and {share=false} or nil)
        if mode=="before receipt" then SlashCmdList.LAYERENEMIES("share off") end
        observe(N)
        if mode=="during wait" then
            eq(N.Safe.count(N.Main.relay.pending),2,"both relay families are pending")
            SlashCmdList.LAYERENEMIES("share off")
        end
        finish(N); eq(counts().all,0,"no LEGW1 traffic of any kind while sharing is off")
        eq(next(N.Main.relay.pending),nil,"no held relay backlog")
        H.advance(61); eq(counts().all,0,"no delayed replay"); no(N.Main.error)
    end)
end

test("Guild relay policy: off then on cancels pending relays but allows fresh observations",function()
    local N=fixture(); spy(); hh(); eq(N.Safe.count(N.Main.relay.pending),2)
    SlashCmdList.LAYERENEMIES("share off"); SlashCmdList.LAYERENEMIES("share on")
    H.advance(3); eq(counts().all,0,"cancelled relays cannot revive after a quick toggle")
    H.advance(121); observe(N); finish(N)
    local c=counts(); eq(c.O,1); eq(c.spy,1); eq(c.hh,1); no(N.Main.error)
end)

test("Guild relay policy: saved share off also silences guild membership and host discovery",function()
    local N=fixture({share=false}); N.Net.SHIP.we=true; N.Net.setSwitch("we",true)
    N.Main.weHello("request"); N.Main.weTick()
    N.Main.findHosts()
    for _=1,40 do H.advance(1) end
    for _,m in ipairs(H.sent()) do no(m.kind=="GUILD","all guild sends respect the master sharing switch") end
end)

for _,family in ipairs({"Spy","HeadHunter","mixed"}) do
    for _,fighting in ipairs({false,true}) do
        test("Guild relay policy: "..family.." burst reserves own O capacity "..(fighting and "in combat" or "out of combat"),function()
            local N=fixture(); H.combat(fighting)
            for cycle=1,4 do
                if cycle>1 then H.advance(61) end
                own(); H.advance(2.4)
                for i=1,5 do
                    if family=="HeadHunter" or (family=="mixed" and i%2==0) then hh(i) else spy(i) end
                end
                eq(N.Safe.count(N.Main.relay.pending),5,"five live relays await dispatch")
                H.advance(.6); N.Main.shareTick()
                local c=counts()
                eq(c.O,cycle,"every own O survives the preceding relay burst")
                eq(c.spy+c.hh,cycle*(fighting and 1 or 3),"relays leave two own tokens, including one combat line")
                eq(next(N.Main.relay.pending),nil); eq(N.Wire.queued(),0,"reserve refusal never queues")
            end
            H.advance(30); eq(counts().O,4); no(N.Main.error)
        end)
    end
end

test("Guild relay policy: combat relay sends with a full prefix bucket and leaves one own line",function()
    local N=fixture(); H.combat(true)
    eq(#H.sent(),0,"no earlier send has spent the full bucket")
    hh(); H.advance(.6)
    eq(counts().hh,1,"a full bucket must allow a combat relay")
    own(); H.advance(3.1); N.Main.shareTick()
    eq(counts().O,1,"the relay leaves room for an own combat line")
    eq(next(N.Main.relay.pending),nil); eq(N.Wire.queued(),0); no(N.Main.error)
end)

-- Reviewer round-2: a slow stream refills prefix tokens but can exhaust Wire's
-- separate rolling guild-minute budget. Count actual sends, not our mirror.
for _,fighting in ipairs({false,true}) do
    for _,every in ipairs(fighting and {1,4} or {1}) do
        test("Guild relay policy: sustained HH keeps all five own O slots combat="..tostring(fighting).." every="..every,function()
            local N=fixture(); H.combat(fighting)
            local refused=0; local send=N.Wire.send
            N.Wire.send=function(prefix,text,...)
                local ok,why,attempted=send(prefix,text,...)
                if prefix=="LEGW1" and text:sub(1,2)=="O|" and not ok then refused=refused+1 end
                return ok,why,attempted
            end
            for t=1,300 do
                own(); if t%every==0 then hh(t) end
                H.advance(1); N.Main.shareTick()
            end
            eq(counts().O,5,"all five own minute slots must reach Wire")
            eq(refused,0,"no own refusal under sustained relay load")
            yes(counts().hh>0,"own priority must not be a vacuous pass with all relays suppressed")
            local cap=fighting and 10 or 20
            local reserve=fighting and 2 or 3
            for i,m in ipairs(H.sent()) do
                if m.kind=="GUILD" then
                    local used=0
                    for j=1,i do local earlier=H.sent()[j]
                        if earlier.kind=="GUILD" and m.at-earlier.at<60 then used=used+1 end
                    end
                    yes(used<=cap,"Wire's original guild cap still holds")
                    if m.text:sub(1,2)=="R|" then yes(used<=cap-reserve,"relay must leave the last guild slots") end
                end
            end
            eq(N.Wire.queued(),0); no(N.Main.error)
        end)
    end
end

for _,fighting in ipairs({false,true}) do
    test("Guild relay policy: minute reserve includes other prefixes combat="..tostring(fighting),function()
        local N=fixture()
        -- Fill Wire using real guild sends on another prefix, not a relay-local counter.
        local limit=fighting and 8 or 17
        for i=1,limit do
            N.Net.SHIP.we=true
            yes(N.Wire.send("WEFF1","Q","GUILD",nil,{net="we",prio="own"}))
            N.Net.SHIP.we=false -- no automatic WE traffic in the timer steps
            H.advance(2)
        end
        eq(#H.sent(),limit,"the intended guild allowance is full, not the own reserve")
        H.combat(fighting)
        local at=H.clock()
        local used,cap=N.Wire.guildMinute(at)
        eq(used,limit); eq(cap,fighting and 10 or 20)
        eq(N.Wire.guildMinute(at+60),0,"expiry boundary is exclusive")
        eq(N.Wire.guildMinute(at),limit,"inspection at a future time must not prune Wire's budget")
        eq(N.Wire.guildMinute(at-60),limit,"future stamps still count after rollback")
        local before=#H.sent(); hh(); H.advance(.6)
        eq(#H.sent(),before,"a full relay allowance drops the relay, even with unused LEGW1 tokens")
        eq(next(N.Main.relay.pending),nil); eq(N.Wire.queued(),0)
        -- Expired minute stamps must not hold back a fresh relay.
        H.combat(false); H.advance(61); hh(2); H.advance(.6)
        eq(counts().hh,1); no(N.Main.error)
    end)
end

test("Guild relay policy: earlier guild control lines count against the relay reserve",function()
    local N=fixture(); yes(N.Main.findHosts(),"real guild question consumes one LEGW1 token")
    own(); H.advance(2.4)
    -- A second own-priority control line immediately before the burst consumes another token.
    H.deliver("GUILD_ROSTER_UPDATE"); H.drain()
    SlashCmdList.LAYERENEMIES("host on")
    eq(counts().all,2,"real H line consumes one LEGW1 token")
    for i=1,5 do spy(i) end
    H.advance(.6); N.Main.shareTick()
    local c=counts(); eq(c.O,1); eq(c.spy,2,"the relay gate includes other LEGW1 authors")
    no(N.Main.error)
end)

test("Guild relay policy: clear and clock rollback cannot refill the reserve",function()
    local N=fixture(); N.Relay.rand=function() return 0 end
    for i=1,3 do hh(i) end
    H.advance(.05); eq(counts().hh,3,"relay capacity was consumed")
    SlashCmdList.LAYERENEMIES("share off"); SlashCmdList.LAYERENEMIES("share on")
    hh(4); H.advance(.05); eq(counts().hh,3,"clearing pending relays cannot refill tokens")
    H.advance(-1); hh(5); H.advance(.05); eq(counts().hh,3,"a backwards clock cannot refill tokens")
    H.advance(3); hh(6); H.advance(.05); eq(counts().hh,4,"forward time still refills normally")
    eq(N.Wire.queued(),0); no(N.Main.error)
end)

test("Guild relay policy: combat relay then K then O has the documented one-line reserve limit",function()
    local N=fixture(); H.combat(true); own(); H.advance(2.1)
    local refused=0; local send=N.Wire.send
    N.Wire.send=function(prefix,text,...)
        local ok,why,attempted=send(prefix,text,...)
        if prefix=="LEGW1" and text:sub(1,2)=="O|" and not ok then refused=refused+1 end
        return ok,why,attempted
    end
    for i=1,5 do spy(i) end
    H.advance(.6)
    C_DeathRecap={HasRecapEvents=function() return true end,GetRecapEvents=function()
        return {{sourceGUID="Player-1-998",sourceName="Ownenemy",sourceFlags=0x448,overkill=10,timestamp=H.clock()}}
    end}
    H.deliver("PLAYER_DEAD"); H.advance(.3); N.Main.shareTick()
    local kills=0; for _,m in ipairs(H.sent()) do if m.text:sub(1,2)=="K|" then kills=kills+1 end end
    eq(kills,1,"K still sends once")
    eq(counts().spy,1,"combat relays remain active with one own line reserved")
    eq(counts().O,0,"known limit: K uses the one reserved own line, so the following O is dropped")
    eq(refused,1,"the O really reached Wire and was refused, not silently omitted")
    eq(next(N.Main.relay.pending),nil)
    eq(N.Wire.queued(),0); no(N.Main.error)
end)

for _,fighting in ipairs({false,true}) do
    test("Guild relay policy: merged K author preserves the reserve "..(fighting and "in combat" or "out of combat"),function()
        local N=fixture(); H.combat(fighting); own(); H.advance(2.1)
        C_DeathRecap={HasRecapEvents=function() return true end,GetRecapEvents=function()
            return {{sourceGUID="Player-1-998",sourceName="Ownenemy",sourceFlags=0x448,overkill=10,timestamp=H.clock()}}
        end}
        H.deliver("PLAYER_DEAD"); H.advance(.3)
        eq(counts().all,1,"K has really consumed the shared LEGW1 prefix budget")
        yes(H.sent()[1].text:sub(1,2)=="K|")
        for i=1,5 do spy(i) end
        H.advance(.6); N.Main.shareTick()
        local c=counts(); eq(c.O,1,"own sighting survives K followed by relays")
        eq(c.spy,fighting and 0 or 2,"K participates in reserve accounting")
        no(N.Main.error)
    end)
end
