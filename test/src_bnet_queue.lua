local h=...
local test,eq,yes,no=h.test,h.eq,h.yes,h.no
local fixture=assert(loadfile("test/bnet_queue_fixture.lua"))(h)
local function setup()
    local N=h.load(); yes(N.BNet and type(N.BNet.send)=="function","shared queue exists")
    for _,pair in ipairs({{"alpha","AlphaSrc"},{"beta","BetaSrc"}}) do
        yes(N.Sources.register{name=pair[1],prefixes={pair[2]},counters={}})
    end
    _G.WOW_PROJECT_ID=42
    C_BattleNet.GetGameAccountInfoByID=function(id)
        return {gameAccountID=id,characterName="Other Player",realmName="Other Realm",factionName="Horde",clientProgram="WoW",
            isOnline=true,wowProjectID=42,isInCurrentRegion=true}
    end
    return N
end
local function bnSent()
    local out={}; for _,s in ipairs(h.sent()) do if s.kind=="BN" then out[#out+1]=s end end; return out
end

test("BNet queue: single shared thirty per minute cap and one second pace",function()
    local N=setup()
    -- Production sources count in default shares. Include configured networks so
    -- this still reaches the exact shared 30/minute boundary, not a smaller cap.
    local rows={{"wanted","WNTDB",4},{"overlord","OverlordF",8},{"warboard","WarBoard",10},
        {"alpha","AlphaSrc",4},{"beta","BetaSrc",4}}
    for i=1,3 do fixture.register(N,rows[i][1],rows[i][2]) end
    yes(fixture.defaultShare(N)>=4)
    local byPrefix={}
    for _,r in ipairs(rows) do
        byPrefix[r[2]]=r[1]
        for i=1,r[3] do yes(N.BNet.send(r[1],71,r[2],r[1]..i,"own")) end
    end
    eq(#bnSent(),0,"enqueue is not a send")
    h.advance(.5); eq(#bnSent(),0)
    h.advance(.5); eq(#bnSent(),1)
    -- Refill freed slots, rather than assuming a source may queue above its share.
    for i=1,10 do
        local delivered=bnSent(); local last=delivered[#delivered]
        yes(N.BNet.send(byPrefix[last.prefix],71,last.prefix,"refill"..i,"own"))
        h.advance(1)
    end
    for _=1,19 do h.advance(1) end; eq(#bnSent(),30)
    for _=1,30 do h.advance(1) end; eq(#bnSent(),30,"rolling minute is shared across nets")
    yes(N.BNet.send("alpha",71,"AlphaSrc","fresh-a","own"))
    yes(N.BNet.send("alpha",71,"AlphaSrc","fresh-b","own"))
    h.advance(1); eq(#bnSent(),31,"exact sixty-second boundary")
    h.advance(50); eq(#bnSent(),32,"no catch-up burst with still-live work")
end)

test("BNet queue: owed answers precede own work FIFO within a priority",function()
    local N=setup()
    yes(N.BNet.send("alpha",71,"AlphaSrc","own-a","own"))
    yes(N.BNet.send("beta",71,"BetaSrc","owed-b","owed"))
    yes(N.BNet.send("alpha",71,"AlphaSrc","owed-a","owed"))
    for _=1,3 do h.advance(1) end
    local s=bnSent(); eq(#s,3); eq(s[1].text,"owed-b"); eq(s[2].text,"owed-a"); eq(s[3].text,"own-a")
end)

test("BNet queue: unregistered source wrong prefix and dormant PR never send",function()
    local N=h.load(); yes(N.BNet and type(N.BNet.send)=="function")
    no(N.BNet.send("alpha",71,"AlphaSrc","line","owed"))
    for _=1,120 do h.advance(1) end; eq(#bnSent(),0)
    N=setup(); no(N.BNet.send("alpha",71,"BetaSrc","line","owed")); no(N.BNet.send("alpha",71,"OpenMapLoc","line","owed"))
    for _=1,120 do h.advance(1) end; eq(#bnSent(),0)
    eq(N.BNet.queued(),0)
end)

for _,mode in ipairs({"share","public","switch","combat","instance"}) do
    test("BNet queue: "..mode.." off refuses and drops pending work before dispatch",function()
        local N=setup()
        yes(N.BNet.send("alpha",71,"AlphaSrc","pending","owed"))
        local function off()
            if mode=="share" then N.Main.setShare(false)
            elseif mode=="public" then N.Net.setConsent("guild")
            elseif mode=="switch" then N.Net.setSwitch("alpha",false)
            elseif mode=="combat" then h.combat(true) else h.instance(true) end
        end
        local function on()
            if mode=="share" then N.Main.setShare(true)
            elseif mode=="public" then N.Net.setConsent("public")
            elseif mode=="switch" then N.Net.setSwitch("alpha",true)
            elseif mode=="combat" then h.combat(false) else h.instance(false) end
        end
        off(); no(N.BNet.send("alpha",71,"AlphaSrc","blocked","owed")); h.advance(1); eq(#bnSent(),0); eq(N.BNet.queued(),0)
        on(); h.advance(2); eq(#bnSent(),0)
        yes(N.BNet.send("alpha",71,"AlphaSrc","fresh","owed")); h.advance(1); eq(#bnSent(),1)
        if mode=="share" or mode=="public" or mode=="switch" then
            yes(N.BNet.send("alpha",71,"AlphaSrc","cancelled","owed")); off(); on(); h.advance(1); eq(#bnSent(),1)
        end
    end)
end

test("BNet queue: Wire cannot dispatch outside the queue's private delivery",function()
    local N=setup(); local count=0
    no(N.Wire.bnet("alpha",71,"AlphaSrc","bypass","owed",function() count=count+1; return 0 end))
    eq(count,0); eq(#bnSent(),0)
    yes(N.BNet.send("alpha",71,"AlphaSrc","allowed","owed")); h.advance(1); eq(#bnSent(),1)
end)

test("BNet queue: failed client send is spent counted and never retried",function()
    local N=setup(); local count=0
    -- Independent caller-frame spy for unavailable/refused clients; do not bypass the gate.
    C_BattleNet.SendGameData=function()
        count=count+1
        local level=2; local info=debug.getinfo(level,"S")
        while info.what=="C" do level=level+1; info=debug.getinfo(level,"S") end
        eq(info.source,"@LayerEnemies/Wire.lua")
        return false
    end
    yes(N.BNet.send("alpha",71,"AlphaSrc","refused","owed")); h.advance(1); eq(count,1); eq(N.BNet.queued(),0)
    for _=1,65 do h.advance(1) end; eq(count,1)
    N.Main.net("net"); yes(table.concat(h.log(),"\n"):find("alpha: heard=0 accepted=0 sent=0 refused=1",1,true))
end)

test("BNet queue: per-network shares stand-down owed exception and live peer validation",function()
    local N=setup()
    if not N.Sources.has("wanted") then yes(N.Sources.register{name="wanted",prefixes={"WNTDB"},counters={}}) end
    N.Net.SHIP.wanted=true -- reuse the real registered source when D1 is present
    for _=1,4 do yes(N.BNet.send("wanted",71,"WNTDB","hello","own")) end
    no(N.BNet.send("wanted",71,"WNTDB","overflow","own"))
    for _=1,5 do h.advance(1) end; eq(#bnSent(),4)
    N.Net.LIST.alpha.standDown="Donor"; h.loaded().Donor=true
    no(N.BNet.send("alpha",71,"AlphaSrc","own","own")); yes(N.BNet.send("alpha",71,"AlphaSrc","owed","owed"))
    h.advance(1); eq(#bnSent(),5)
    yes(N.BNet.send("alpha",71,"AlphaSrc","gone","owed")); C_BattleNet.GetGameAccountInfoByID=function() return nil end
    h.advance(1); eq(#bnSent(),5); eq(N.BNet.queued(),0)
end)

test("BNet queue: bounds secrets rollback and timer absence fail closed",function()
    local N=setup()
    for _,a in ipairs({{h.secret,71,"AlphaSrc","x","owed"},{"alpha",h.secret,"AlphaSrc","x","owed"},
        {"alpha",71,h.secret,"x","owed"},{"alpha",71,"AlphaSrc",h.secret,"owed"},
        {"alpha",71,"AlphaSrc","x",h.secret},{"alpha",0,"AlphaSrc","x","owed"},
        {"alpha",71,"AlphaSrc",string.rep("x",4097),"owed"}}) do no(N.BNet.send(unpack(a))) end
    local limit=fixture.defaultShare(N)
    for _=1,limit do yes(N.BNet.send("alpha",71,"AlphaSrc","line","own")) end
    no(N.BNet.send("alpha",71,"AlphaSrc","overflow","own")); eq(N.BNet.queued(),limit)
    h.advance(1); eq(#bnSent(),1); h.clock(h.clock()-10); N.BNet.pump(h.clock()); eq(#bnSent(),1)
    N=setup(); C_Timer=nil; no(N.BNet.send("alpha",71,"AlphaSrc","timerless","own")); eq(N.BNet.queued(),0)
end)
