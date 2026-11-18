-- 1.2.1 "On my way": one hidden guild line from the Call help click; nothing saved.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function bounty(victim)
    H.deliver("CHAT_MSG_ADDON","GBOUNTY","D|Cedar Vale|100|42.5|61.0|Forest|60|2|ROGUE|","GUILD",victim or "Birch Moss")
end
local function lines(prefix,pattern)
    local out={}
    for _,s in ipairs(H.sent()) do if s.prefix==prefix and s.text:find(pattern) then out[#out+1]=s end end
    return out
end
local function said(text)
    local n=0; for _,l in ipairs(H.log()) do if l:find(text,1,true) then n=n+1 end end; return n
end
local function hex(s) return (s:gsub(".",function(c) return string.format("%02x",c:byte()) end)) end

test("Coming: help click sends one G line on LEGW1 GUILD naming victim and zone",function()
    local N=H.load(); bounty(); yes(N.CallUI.help)
    N.CallUI.help:Click()
    local g=lines("LEGW1","^G|")
    eq(#g,1); eq(g[1].kind,"GUILD"); eq(g[1].text,"G|1|100|"..hex("Birch Moss")); no(N.Main.error)
end)
test("Coming: codec round trip and malformed lines refused",function()
    local N=H.load(); local C=N.Coming
    local d=C.decode(C.line(100,"Birch Moss")); eq(d.zone,100); eq(d.victim,"Birch Moss")
    eq(C.decode(C.line(1434,"Ærin-Realm")).victim,"Ærin-Realm")
    for _,bad in ipairs({"G|1|100|","G|2|100|4142","G|1|0|4142","G|1|100|414","G|1|100|zz","G|1|100|41|x","G|1|100|7c41",
        "G|1|1000000|4142",123,nil}) do eq(C.decode(bad),nil) end
    eq(C.line(100,"A|B"),nil); eq(C.line(0,"Birch"),nil); eq(C.line(100,""),nil); eq(C.line(100.5,"Birch"),nil)
    eq(N.Wire.send("LEGW1","G|1|100|zz","GUILD",nil,{prio="click"}),false,"Wire refuses a malformed G line")
end)
test("Coming: one per event, 10 s gap and six per 600 s",function()
    local N=H.load(); local C=N.Coming; local st=C.new()
    yes(C.allow(st,0)); no(C.allow(st,9.9)); yes(C.allow(st,10))
    for i=2,5 do yes(C.allow(st,i*10)) end
    no(C.allow(st,70),"seventh inside 600 s"); yes(C.allow(st,600),"first one aged out")
    N=H.load(); bounty(); local e=N.Main.call.current; yes(e)
    yes(N.Main.comingSend(e)); no(N.Main.comingSend(e),"same alert event sends once"); eq(#lines("LEGW1","^G|"),1)
end)
test("Coming: share off, instance and no guild send nothing",function()
    for _,mode in ipairs({"share","instance","guild"}) do
        local N=H.load(); bounty(); local e=N.Main.call.current; yes(e)
        if mode=="share" then LayerEnemiesDB.share=false
        elseif mode=="instance" then H.instance(true)
        else IsInGuild=function() return false end end
        no(N.Main.comingSend(e)); eq(#lines("LEGW1","^G|"),0,mode)
        IsInGuild=function() return true end; H.instance(false)
    end
end)
test("Coming: receivers print one line; the victim gets COMING and the sound",function()
    local N=H.load(); local sounds=0; PlaySound=function() sounds=sounds+1 end
    H.deliver("CHAT_MSG_ADDON","LEGW1","G|1|100|"..hex("Birch Moss"),"GUILD","Oak Helper")
    eq(said("Oak Helper is coming to help Birch Moss (Ashenvale)."),1); eq(sounds,0)
    local _,me=N.Adapters.ownIdentity(); local mine=UnitName("player")
    H.deliver("CHAT_MSG_ADDON","LEGW1","G|1|100|"..hex(mine),"GUILD","Oak Helper")
    eq(said("COMING: Oak Helper is on the way."),1); eq(sounds,1); no(N.Main.error); PlaySound=nil
end)
test("Coming: 1.2.0 relay decoder drops the G line cleanly",function()
    local N=H.load(); local line=N.Coming.line(100,"Birch Moss")
    -- The pre-1.2.1 receive path: control(), then decode() for anything not O|/K|/T|.
    eq(N.Relay.control(line),nil)
    local ok,record,why=pcall(N.Relay.decode,line,"Oak Helper",H.clock())
    yes(ok); eq(record,nil); eq(why,"invalid")
end)

test("Coming: twenty helpers for one victim print once each per 60 s; sound once per 10 s; call off silent",function()
    local N=H.load(); local sounds=0; PlaySound=function() sounds=sounds+1 end
    local mine=UnitName("player"); local before=#H.log()
    for round=1,30 do
        for i=1,20 do H.deliver("CHAT_MSG_ADDON","LEGW1","G|1|100|"..hex(mine),"GUILD","Helper "..H.abc(i)) end
        H.advance(2)
    end
    local lines=0; for i=before+1,#H.log() do if H.log()[i]:find("COMING:",1,true) then lines=lines+1 end end
    eq(lines,20,"one line per helper inside 60 s"); yes(sounds<=6,"sound at most once per 10 s, got "..sounds)
    yes(N.Main.coming.collapsed>0); SlashCmdList.LAYERENEMIES("net")
    yes(table.concat(H.log(),"\n"):find("On my way (session): heard=",1,true))
    N=H.load(); SlashCmdList.LAYERENEMIES("call off"); before=#H.log(); sounds=0
    H.deliver("CHAT_MSG_ADDON","LEGW1","G|1|100|"..hex(mine),"GUILD","Oak Helper")
    eq(sounds,0); for i=before+1,#H.log() do no(H.log()[i]:find("COMING:",1,true)) end
    eq(N.Main.coming.quiet,1); PlaySound=nil
end)
