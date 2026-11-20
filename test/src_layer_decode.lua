local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function hex(s) return (s:gsub(".",function(c) return string.format("%02x",c:byte()) end)) end
local enemy=hex("Enemy One")
for _,layer in ipairs({"bad!layer","0","0-0","0-0-0",string.rep("9",40)}) do
    test("Layer A3: O keeps name with unknown layer "..layer,function()
        local N=H.load(); local r=N.Relay.decodeOwn("O|1|42|100|0.200|0.300|"..layer.."|0|1|"..enemy..":MAGE:60","Scout One",100)
        yes(r); eq(r.layer.ns,"unknown"); eq(r.layer.value,nil); eq(r.enemies[1].name,"Enemy One"); eq(r.x,.2)
        no(N.Relay.decodeOwn("O|1|42|bad|0.200|0.300|"..layer.."|0|1|"..enemy..":MAGE:60","Scout One",100))
    end)
    test("Layer A3: K keeps name with unknown layer "..layer,function()
        local N=H.load(); local r=N.OwnDeath.decode("K|1|100|0.200|0.300|"..layer.."|0|e|"..enemy..":MAGE:60:f")
        yes(r); eq(r.layer,nil); eq(r.enemies[1].name,"Enemy One"); eq(r.x,.2)
        no(N.OwnDeath.decode("K|1|100|bad|0.300|"..layer.."|0|e|"..enemy..":MAGE:60:f"))
    end)
    test("Layer A3: R keeps name with unknown layer "..layer,function()
        local N=H.load(); local r=N.Relay.decode("R|1|we|group|"..hex("Scout One").."|42|100|200|300|1|s|"..layer.."|0|"..enemy..":MAGE:60","Carrier One",100)
        yes(r); eq(r.layer.ns,"unknown"); eq(r.layer.value,nil); eq(r.enemies[1].name,"Enemy One"); eq(r.x,.2)
        no(N.Relay.decode("R|1|we|group|"..hex("Scout One").."|42|bad|200|300|1|s|"..layer.."|0|"..enemy..":MAGE:60","Carrier One",100))
    end)
    test("Layer A3: WE C/H retain other fields with unknown layer "..layer,function()
        local N=H.load()
        local c=N.Protocol.decode("C|42|100|0.200|0.300|"..layer.."|1|100")
        yes(c); eq(c.layer,0); eq(c.rid,42); eq(c.count,1); eq(c.x,.2)
        local h=N.Protocol.decode("H|1.6.6|100|"..layer.."|1|19")
        yes(h); eq(h.layer,0); eq(h.map,100); eq(h.version,"1.6.6")
        no(N.Protocol.decode("C|42|bad|0.200|0.300|"..layer.."|1|100"))
        no(N.Protocol.decode("H|bad|100|"..layer.."|1|19"))
    end)
end

test("Layer A3: Overlord GW bad layer retains guild and counts, bad count drops",function()
    local N=H.load(); local r=N.Overlord.gw("1:Enemy Guild:H:50:5:#100:bad!layer:1000",1000)
    yes(r); eq(r.layer,nil); eq(r.guild,"Enemy Guild"); eq(r.kills,50); eq(r.members,5); eq(r.map,100)
    no(N.Overlord.gw("1:Enemy Guild:H:bad:5:#100:bad!layer:1000",1000))
end)

test("Layer A3: HH P bad layer retains names and coordinates",function()
    local N=H.load()
    local r=N.HeadHunter.decode("1AP:2s;2s;5k;8c;abc;Enemy One/M/60;bad!layer","Scout One",100,"Alliance",{heard=100,route="WHISPER"})
    eq(#r,1); eq(r[1].enemies[1].name,"Enemy One"); eq(r[1].layer.ns,"unknown"); eq(r[1].x,.2)
    eq(#N.HeadHunter.decode("1AP:2s;2s;bad!;8c;abc;Enemy One/M/60;bad!layer","Scout One",100,"Alliance",{heard=100,route="WHISPER"}),0)
end)

test("Layer A3: unknown-namespace R records ignore malformed layer values",function()
    local N=H.load()
    for _,shape in ipairs({{"hh","kill",""},{"hh","fight","1"},{"spy","seen","1"}}) do
        local text="R|1|"..shape[1].."|"..shape[2].."|"..hex("Scout One").."|42|100|200|300|"..shape[3].."|u|bad!layer|0|"..enemy..":MAGE:60"
        local r=N.Relay.decode(text,"Carrier One",100)
        yes(r); eq(r.layer.ns,"unknown"); eq(r.layer.value,nil); eq(r.enemies[1].name,"Enemy One")
    end
end)

test("Layer A3: malformed GW layer controls are separable but controls elsewhere drop",function()
    local N=H.load(); local r=N.Overlord.gw("1:Enemy Guild:H:50:5:#100:bad\001layer:1000",1000)
    yes(r); eq(r.layer,nil); eq(r.guild,"Enemy Guild")
    no(N.Overlord.gw("1:Enemy\001Guild:H:50:5:#100:bad:1000",1000))
end)

test("Layer A3: wrapped WE names and E fragments survive a bad C layer",function()
    local N=H.load(); H.clock(101)
    H.deliver("CHAT_MSG_ADDON","WEFF1","H|1.6.6|100|bad!layer|1|19","GUILD","Scout One")
    H.deliver("CHAT_MSG_ADDON","WEFF1","E|42|1|1|abc:H:60|100","GUILD","Scout One")
    H.deliver("CHAT_MSG_ADDON","WEFF1","C|42|100|0.200|0.300|bad!layer|1|100","GUILD","Scout One")
    local _,row=next(N.Main.store.reports); yes(row); eq(row.record.enemies[1].hash,"abc"); eq(row.record.layer.ns,"unknown")
    for _,wrapper in ipairs({"W","G","X"}) do
        local r=N.Protocol.decode(wrapper.."|"..hex("Scout One").."|123|C|42|100|0.200|0.300|bad!layer|1|100")
        yes(r); eq(r.origin,"Scout One"); eq(r.inner.layer,0)
        no(N.WeOut.rebuild(r.inner):find("bad!layer",1,true),"forwarded line retains the existing zero shape")
    end
end)

test("Layer A3: permissive K receipt does not widen outgoing wire grammar",function()
    local N=H.load()
    local text="K|1|100|||bad!layer|0|e|"..enemy..":MAGE:60:f"
    yes(N.OwnDeath.decode(text)); no(N.OwnDeath.decode(text,true))
    no(N.OwnDeath.line({zone=100,layer="bad!layer",age=0,conf="e"}))
    no(N.Wire.send("LEGW1",text,"GUILD",nil,{prio="own"})); eq(#H.sent(),0)
end)
