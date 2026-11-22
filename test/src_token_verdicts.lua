local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function start(kind)
    local N=H.load(nil,function() GetBuildInfo=function() return "x","71037","d",16001 end end)
    H.clock(120); H.wall(1000)
    LayerSwapDB={book={["Host Cedar"]={layer="8000-8",zone=100,at=1000,host=true}}}
    yes(N.Main.hopAny())
    if kind~="none" then
        local text=kind=="bad" and "heard invalid" or "heard Me|8000-8|100|h"
        H.deliver("CHAT_MSG_ADDON","LayerSwap",text,"WHISPER","Host Cedar")
    end
    H.deliver("PARTY_INVITE_REQUEST","Host Cedar")
    H.group(true); H.units().party1={name="Host Cedar",leader=true,player=true}
    H.deliver("GROUP_ROSTER_UPDATE"); yes(N.Main.auto.group.joinedAt)
    return N,N.Main
end
for _,kind in ipairs({"zone","stale","future","same","notjoined","stray"}) do
    test("Parity verdict: unusable transfer "..kind,function()
        local N,M=start("reply"); local g=M.auto.group
        if kind=="zone" then g.blind.reply.zone=200
        elseif kind=="stale" then g.blind.reply.at=H.clock()-121
        elseif kind=="future" then g.blind.reply.at=H.clock()+1
        elseif kind=="same" then
            yes(N.Trust.adopt(M.store,H.clock(),"8000-8",100,"peer","Host Birch"))
            g.trustBefore="8000-8"
        elseif kind=="notjoined" then g.joinedAt=nil
        elseif kind=="stray" then M.auto.group=nil end
        H.deliver("SHARD_TRANSFER"); H.drain()
        eq(N.Trust.state(M.store,H.clock()),"blind"); eq(#LayerEnemiesDB.hopLimit.moves,0); no(M.error)
    end)
end
for _,kind in ipairs({"reply","none","bad"}) do
    test("Parity verdict: transfer "..kind,function()
        local N,M=start(kind); H.deliver("SHARD_TRANSFER"); H.drain()
        if kind=="reply" then
            eq(N.Trust.own(M.store,H.clock()),"8000-8"); eq(#LayerEnemiesDB.hopLimit.moves,1)
            eq(M.blindStatus,"moved to Host Cedar's layer")
            H.advance(3.05); eq(H.leaves(),1)
        else H.advance(5); eq(N.Trust.state(M.store,H.clock()),"blind"); yes(M.blindStatus:find("layer unknown",1,true)) end
        no(M.error)
    end)
end
for _,mode in ipairs({"same","refused","missing","secret","throw","otherzone"}) do
    test("Parity verdict: phase "..mode,function()
        local N,M=start("reply")
        UnitPhaseReason=mode~="missing" and function()
            if mode=="secret" then return H.secret elseif mode=="throw" then error("unreadable") elseif mode=="refused" then return 1 end
        end or nil
        local map=C_Map.GetBestMapForUnit
        C_Map.GetBestMapForUnit=function(unit) if unit=="party1" and mode=="otherzone" then return 200 end; return map(unit) end
        H.advance(2.99); no(M.blindStatus); H.advance(.01)
        if mode=="same" then eq(M.blindStatus,"that host is on your layer already"); eq(N.Trust.own(M.store,H.clock()),"8000-8"); eq(H.leaves(),1)
        elseif mode=="refused" then eq(M.blindStatus,"the game refused the move"); eq(N.Trust.paceWait(LayerEnemiesDB.hopLimit,H.wall()),900); eq(H.leaves(),1)
        else no(M.blindStatus); H.advance(27); yes(M.blindStatus:find("Too little around you to tell",1,true),M.blindStatus) end
        no(M.error)
    end)
end
H.test("Parity verdict: wrong leader and repeated transfer cannot adopt",function()
    local N,M=start("reply"); H.units().party1.leader=false
    H.deliver("SHARD_TRANSFER"); H.drain(); eq(N.Trust.state(M.store,H.clock()),"blind")
    N,M=start("reply"); H.deliver("SHARD_TRANSFER"); H.drain(); eq(N.Trust.state(M.store,H.clock()),"known")
    H.deliver("SHARD_TRANSFER"); H.drain(); eq(N.Trust.state(M.store,H.clock()),"blind"); eq(#LayerEnemiesDB.hopLimit.moves,1)
end)
