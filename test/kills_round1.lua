-- Reviewer round-1 regressions. Synthetic identities; real receive/send paths.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function b36(n)
    local digits,out="0123456789abcdefghijklmnopqrstuvwxyz",""
    repeat local r=n%36; out=digits:sub(r+1,r+1)..out; n=math.floor(n/36) until n==0
    return out
end
local function death(opts)
    opts=opts or {}
    local stamp=b36(GetServerTime()-(opts.age or 0))
    local victim=opts.victim or "Birch Scout"
    return "1AE:eu-pvp;"..victim..";A;5cy;1;"..stamp..";D"..table.concat({stamp,victim,"1o","W","H",
        "2s","dw","6y",opts.conf or "e","9ix",(opts.killer or "Cedar Vale")..",,14,M,O,2,"},";")
end
local function boot()
    local N=H.load(); N.Net.SHIP.hh=true; H.loaded().HeadHunter=true
    N.Relay.rand=function() return 1 end
    H.advance(1) -- legacy controls must be later than the Store epoch
    return N
end
local function hear(text,sender,route)
    H.deliver("CHAT_MSG_ADDON","HeadHunter",text,route or "WHISPER",sender or "Birch Scout")
end
local function guild(text,sender) H.deliver("CHAT_MSG_ADDON","LEGW1",text,"GUILD",sender or "Guild Carrier") end
local function sends(pattern)
    local out={}
    for _,s in ipairs(H.sent()) do if s.prefix=="LEGW1" and (not pattern or s.text:match(pattern)) then out[#out+1]=s end end
    return out
end
local function hex(s) return (s:gsub(".",function(c) return string.format("%02x",c:byte()) end)) end
local function wire(opts)
    opts=opts or {}
    return table.concat({"R","1","hh",opts.kind or "kill",hex(opts.victim or "Birch Scout"),opts.rid or "D:720101",
        "100","500","250","","u","",tostring(opts.age or 0),hex(opts.killer or "Cedar Vale")..":MAGE:40"},"|")
end
local function row(N) return N.Main.findRows()[1] end
local function absent(N)
    eq(next(N.Main.find.known.entries),nil)
    eq(next(N.Main.relay.pending),nil)
    H.advance(1.1); eq(#sends(),0); no(N.Main.error)
end

for _,lane in ipairs({"HeadHunter","guild"}) do
    test("Kills R1 S1: "..lane.." rejects ourselves and killer equals victim",function()
        for _,conf in ipairs({"e","i"}) do
            for _,killer in ipairs({"Me","ME-TestRealm","Birch Scout","BIRCH SCOUT-TestRealm"}) do
                local N=boot(); N.Main.track(killer)
                if lane=="HeadHunter" then hear(death({killer=killer,conf=conf}),"Other Carrier")
                else guild(wire({killer=killer,kind=conf=="e" and "kill" or "killi"})) end
                absent(N); eq(row(N).at,nil)
            end
        end
        -- Foreign namesakes are different people, not contradictions.
        local N=boot(); N.Main.track("Me-Elsewhere")
        if lane=="HeadHunter" then hear(death({killer="Me-Elsewhere"}))
        else guild(wire({killer="Me-Elsewhere"})) end
        yes(row(N).at); no(N.Main.error)
    end)
end

for _,age in ipairs({0,-300}) do
    test("Kills R1 M1: one D id across carriers for its lifetime skew="..age,function()
        local N=boot(); N.Main.track("Cedar Vale")
        local frame=death({age=age}); local began=H.clock()
        hear(frame); H.advance(1.1); eq(#sends("^R|1|hh|kill"),1)
        for _,elapsed in ipairs({121,242,299}) do
            H.advance(elapsed-(H.clock()-began)); hear(frame,"Other Carrier"); H.advance(1.1)
            N.Main.relayTick()
        end
        H.advance(1.1); eq(#sends("^R|1|hh|kill"),1,"same event must never re-forward")
        eq(row(N).at,began,"replay cannot refresh evidence, even during future skew")
        no(N.Main.error)
    end)
end

for _,kind in ipairs({"kill","killi"}) do
    test("Kills R1 S2: identical guild "..kind.." preserves age at 240 seconds",function()
        local N=boot(); N.Main.track("Cedar Vale")
        local text=wire({kind=kind}); guild(text); local at=row(N).at; yes(at)
        H.advance(240); eq(row(N).age,240)
        guild(text,"Other Carrier"); eq(row(N).at,at); eq(row(N).age,240)
        eq(#sends(),0); no(N.Main.error)
    end)
end

test("Kills R1 M1: guild and whisper carriers share identity and stand-down",function()
    for _,guildFirst in ipairs({false,true}) do
        local N=boot(); N.Main.track("Cedar Vale")
        local frame=death(); local text=wire()
        if guildFirst then guild(text) else hear(frame) end
        local at=row(N).at; yes(at)
        if guildFirst then hear(frame,"Other Carrier") else guild(text) end
        H.advance(1.1); eq(#sends(),0,"guild copy cancels or prevents pending relay")
        H.advance(240); guild(text,"Later Carrier"); hear(frame,"Last Carrier"); H.advance(1.1)
        eq(#sends(),0); eq(row(N).at,at); no(N.Main.error)
    end
end)

test("Kills R1 M1: kill id survives legacy relay history eviction",function()
    local N=boot(); local frame=death(); hear(frame); H.advance(1.1)
    for i=1,N.Relay.MAX+1 do
        guild(wire({kind="outlaw",victim="Victim "..H.abc(i),rid="other:"..i}),"Carrier "..H.abc(i))
    end
    H.advance(121); hear(frame,"Last Carrier"); H.advance(1.1)
    eq(#sends("^R|1|hh|kill"),1); no(N.Main.error)
end)

local function burst(mode)
    if mode=="mixed" then
        for i=1,4 do hear(death({victim="Victim "..H.abc(i),killer="Enemy "..H.abc(i)}),"Carrier "..H.abc(i)) end
    end
    for i=1,mode=="mixed" and 1 or 5 do
        local stamp=b36(GetServerTime())
        hear("1AL:Old Enemy;2s;"..stamp..";dw;6y","Legacy "..H.abc(i))
    end
end
local function ownLine(N,id)
    return N.Relay.ownLine({rid=id,zone=100,count=1,x=.25,y=.75,age=0,layer="7086",enemies={{name="Own Enemy"}}})
end
for _,mode in ipairs({"mixed","legacy"}) do
    test("Kills R1 M2: "..mode.." relay burst leaves two own tokens",function()
        local N=boot(); burst(mode); H.advance(1.1)
        eq(#sends("^R|"),3,"prefix burst 5 minus own reserve 2")
        for id=1,2 do yes(N.Wire.send("LEGW1",ownLine(N,id),"GUILD",nil,{prio="own"})) end
        eq(#sends("^O|"),2); eq(next(N.Main.relay.pending),nil); no(N.Main.error)
    end)
    for _,combat in ipairs({false,true}) do
        test("Kills R1 M2: real own sighting survives "..mode.." burst combat="..tostring(combat),function()
            local N=boot(); H.combat(combat)
            H.units().target=H.player("Own Enemy","Horde")
            H.deliver("PLAYER_TARGET_CHANGED"); H.drain(); H.advance(1.9)
            burst(mode); H.advance(1.2); N.Main.shareTick()
            eq(#sends("^O|"),1,"own sighting must leave at its settle slot")
            eq(#sends("^R|"),combat and 1 or 3)
            yes(N.Main.share.shared["Player-1-123"]); no(N.Main.error)
        end)
    end
end

for _,mode in ipairs({"off before receipt","off while pending","off then on while pending","off at dispatch"}) do
    test("Kills R1 share: "..mode.." sends nothing on LEGW1",function()
        local N=boot(); N.Main.track("Cedar Vale")
        if mode=="off before receipt" then SlashCmdList.LAYERENEMIES("share off") end
        H.units().target=H.player("Own Enemy","Horde"); H.deliver("PLAYER_TARGET_CHANGED"); H.drain()
        hear(death()); burst("legacy")
        if mode~="off before receipt" then yes(next(N.Main.relay.pending),"exercise a live pending timer") end
        if mode=="off at dispatch" then LayerEnemiesDB.share=false
        elseif mode~="off before receipt" then SlashCmdList.LAYERENEMIES("share off") end
        if mode=="off then on while pending" then
            SlashCmdList.LAYERENEMIES("share on")
            -- Only test cancellation of held relays in this mode, not new own observations.
            N.Main.store.localSeen={}
        end
        H.advance(4); N.Main.relayTick(); N.Main.shareTick()
        eq(#sends(),0); eq(next(N.Main.relay.pending),nil)
        yes(row(N).reported,"sharing off does not stop reading")
        no(N.Main.error)
    end)
end
