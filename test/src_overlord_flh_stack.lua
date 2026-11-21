-- Stack composition: use real Overlord receive/reply and FLH click flights.
local H=...
local eq,yes,no=H.eq,H.yes,H.no
local function setup()
    local N=H.load()
    Enum.GameRule={HardcoreRuleset=1,RPRuleset=2,PvPRuleset=3}
    C_GameRules={IsGameRuleActive=function(i) return i==3 end}
    UnitName=function() return "Alice Vale",GetRealmName() end
    C_AddOns.GetAddOnMetadata=function() return "1.3.0" end
    N.Net.SHIP.overlord=true; N.Net.SHIP.flh=true; N.Net.SHIP.we=true
    H.establish(N); H.clock(math.ceil(H.clock()))
    local serverTime=GetServerTime
    GetServerTime=function() return math.floor(serverTime()) end
    return N
end
local function replies(id,name)
    name=name or "Budget Scout"
    local text=table.concat({"global",id,GetServerTime(),"Alice Vale",name,"NH","2.5.4"},"|")
    H.deliver("CHAT_MSG_ADDON","OverlordF","BF:"..id..":1:1:"..text,"WHISPER",name)
end
local function lines(prefix,cmd)
    local out={}
    for _,s in ipairs(H.sent()) do
        if s.prefix==prefix and (not cmd or s.text:match("^(%u+)")==cmd) then out[#out+1]=s end
    end
    return out
end
local function hosts(N)
    for i=1,10 do H.deliver("CHAT_MSG_ADDON","FLHNET2","HI|100|"..(10+i).."|1|0.1.3|1234","WHISPER","Host "..H.abc(i)) end
    eq(#N.Main.candidates(),10)
end
local function offer(N)
    local q=lines("FLHNET2","LQ")[1]; yes(q)
    local m=N.FLH.decode(q.text)
    H.deliver("CHAT_MSG_ADDON","FLHNET2","LO|"..m.id.."|100|"..m.wantedKey.."|0|0","WHISPER",q.target)
end
local function ordinary(N,n)
    for i=1,n do yes(N.Wire.send("LayerSwap","inv layer <LS 100 want 7102-8 50.0,50.0>","WHISPER","Other "..H.abc(i),{prio="click"})) end
end
for _,first in ipairs({true,false}) do
    H.test("Overlord FLH stack: unarmed full eight-token burst, peer first "..tostring(first),function()
        local N=setup(); eq(N.FLHMember.reserved(H.clock()),0)
        if not first then ordinary(N,3) end
        for i=1,5 do replies("burst"..i,"Budget "..H.abc(i)) end
        eq(#lines("OverlordF"),5)
        if first then ordinary(N,3) end
        eq(#H.sent(),8)
        no(N.Wire.send("LayerSwap","same","WHISPER","Final Scout",{prio="own"}))
        eq(#H.sent(),8); eq(N.FLHMember.reserved(H.clock()),0); no(N.Main.error)
    end)
end
H.test("Overlord FLH stack: armed LR reserve blocks peer reply without charging it",function()
    local N=setup(); hosts(N); yes(N.FLHMember.hop())
    eq(#lines("FLHNET2","LQ"),7); eq(N.FLHMember.reserved(H.clock()),1)
    replies("blocked"); eq(#lines("OverlordF"),0)
    eq(N.Main.overlordPeer.actual["reply:budget scout"],nil)
    offer(N); eq(#lines("FLHNET2","LR"),1); eq(#H.sent(),8)
    eq(N.FLHMember.reserved(H.clock()),0); no(N.Main.error)
end)
H.test("Overlord FLH stack: canceled click immediately returns last token to peer",function()
    local N=setup(); hosts(N); yes(N.FLHMember.hop())
    eq(#lines("FLHNET2","LQ"),7); replies("held"); eq(#lines("OverlordF"),0)
    N.FLHMember.stop(); eq(N.FLHMember.reserved(H.clock()),0)
    replies("released"); eq(#lines("OverlordF"),1); eq(#H.sent(),8); no(N.Main.error)
end)
H.test("Overlord FLH stack: peer reply cannot steal final rolling-minute LR slot",function()
    local N=setup(); hosts(N); local at=H.clock()
    for i=1,34 do
        H.clock(at+(i-1)*1.5)
        if i%2==0 then yes(N.Wire.send("WEFF1","H|1.6.6|100|7086|1|19|0|123|100|456|H|60|1|42|1","PARTY",nil,{net="we",prio="own"}))
        else yes(N.Wire.send("LEGW1","R|probe-"..i,"GUILD",nil,{prio="own"})) end
    end
    H.clock(at+59); yes(N.FLHMember.hop()); eq(#lines("FLHNET2","LQ"),5)
    replies("minute"); eq(#lines("OverlordF"),0); eq(#H.sent(),39)
    offer(N); eq(#lines("FLHNET2","LR"),1); eq(#H.sent(),40)
    replies("fullminute","Later Scout"); eq(#lines("OverlordF"),0); eq(#H.sent(),40); no(N.Main.error)
end)
