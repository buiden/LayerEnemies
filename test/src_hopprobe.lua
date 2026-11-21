-- Pure proxy rules: synthetic GUIDs only, never a client call.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function probe()
    local N=H.load(); yes(N.HopProbe,"HopProbe is loaded from the TOC"); return N.HopProbe
end
local function rows(creatures,players,spawn)
    local out={}
    for i=1,creatures do out[#out+1]={guid="Creature-0-987654-0-876543-"..i.."-"..(spawn or "ABC"),player=false} end
    for i=1,players do out[#out+1]={guid="Player-987654-"..i,player=true} end
    return out
end
local function snap(P,c,p,spawn,x,y,map)
    return P.snapshot(rows(c,p,spawn),{x=x or 0,y=y or 0,z=0,map=map or 100})
end

test("HopProbe: creature proxy at three, not two, matching NPCs and no retained spawn",function()
    local P=probe()
    eq(P.judge(snap(P,3,0),snap(P,3,0,"DEF")),"creatures")
    eq(P.judge(snap(P,2,0),snap(P,2,0,"DEF")),"sparse")
    eq(P.judge(snap(P,3,0),snap(P,3,0)),"unchanged")
    local after=rows(3,0,"DEF"); after[#after+1]=rows(1,0)[1]
    eq(P.judge(snap(P,3,0),P.snapshot(after)),"unchanged")
    after=rows(3,0,"DEF"); after[1].guid="Creature-0-987654-0-876543-999-DEF"
    eq(P.judge(snap(P,3,0),P.snapshot(after)),"unchanged")
end)

test("HopProbe: players at five and one fifth, movement strictly below forty yards",function()
    local P=probe()
    eq(P.judge(snap(P,0,5),snap(P,0,1,nil,39.999)),"players")
    eq(P.judge(snap(P,0,5),snap(P,0,2)),"unchanged")
    eq(P.judge(snap(P,0,4),snap(P,0,0)),"sparse")
    eq(P.judge(snap(P,0,5),snap(P,0,1,nil,40)),"unchanged")
    eq(P.judge(snap(P,0,5),snap(P,0,1,nil,24,32)),"unchanged")
    eq(P.judge(snap(P,0,5),snap(P,0,1,nil,0,0,101)),"unchanged")
    eq(P.judge(snap(P,0,5),P.snapshot(rows(0,0))),"unchanged")
end)

test("HopProbe: unparseable creatures use only transfer or players, sparse is no judgement",function()
    local P=probe()
    local raw=rows(3,5); raw[#raw+1]={guid="Creature-hidden",player=false}
    local before=P.snapshot(raw,{x=0,y=0,z=0,map=100})
    eq(P.judge(before,snap(P,3,5,"DEF")),"unchanged")
    eq(P.judge(before,snap(P,3,1,"DEF")),"players")
    eq(P.judge(P.snapshot({raw[#raw]}),snap(P,3,0,"DEF")),"sparse")
    eq(P.judge(snap(P,0,0),snap(P,0,0),true),"creatures","transfer is independent evidence")
    eq(P.judge(snap(P,0,0),snap(P,0,0),false),"sparse")
    eq(P.judge(snap(P,3,0),P.snapshot({{guid="Creature-hidden",player=false}})),"unchanged")
end)

test("HopProbe: snapshots dedupe and never infer players from unreadable flags",function()
    local P=probe()
    local raw=rows(1,1); raw[#raw+1]=raw[1]; raw[#raw+1]=raw[2]
    raw[#raw+1]={guid="Player-987654-999",player=H.secret}
    raw[#raw+1]={guid=H.secret,player=true}
    local s=P.snapshot(raw)
    eq(s.creatureCount,1); eq(s.playerCount,1)
    eq(P.judge(s,s),"sparse")
end)

test("HopProbe: unreadable after snapshot disables creatures even beside matching replacements",function()
    local P=probe(); local after=rows(3,0,"DEF")
    after[#after+1]={guid="Creature-hidden",player=false}
    eq(P.judge(snap(P,3,0),P.snapshot(after)),"unchanged")
end)

test("HopProbe: equality uses NPC plus last spawn field, never a server field",function()
    local P=probe(); local after=rows(3,0)
    for _,r in ipairs(after) do r.guid=r.guid:gsub("987654","123456"):gsub("876543","234567") end
    eq(P.judge(snap(P,3,0),P.snapshot(after)),"unchanged")
end)

test("HopProbe: bounded snapshot includes all forty two tokens, not a forty third",function()
    local P=probe(); local s=P.snapshot(rows(21,22))
    eq(s.creatureCount,21); eq(s.playerCount,21)
end)

test("HopProbe: exactly five result texts, no GUID digits in any result",function()
    local P=probe()
    local cases={
        {P.judge(snap(P,3,0),snap(P,3,0,"DEF")),"Hopped (layer unknown): the creatures around you changed."},
        {P.judge(snap(P,0,5),snap(P,0,1)),"Hopped (layer unknown): the players around you changed."},
        {P.judge(snap(P,3,0),snap(P,3,0)),"Joined Host Cedar. No change seen; you may be on the same layer."},
        {P.judge(snap(P,2,4),snap(P,2,4)),"Joined Host Cedar. Too little around you to tell."},
        {"missed","Host Cedar did not invite."},
    }
    for _,c in ipairs(cases) do
        local text=P.text(c[1],"Host Cedar")
        eq(text,c[2]); no(text:find("%d+")); no(text:find("other layer",1,true))
    end
    eq(P.text("missing","Host Cedar"),nil)
end)
