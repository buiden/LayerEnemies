local H=...
local function confirm(N,source,key,kind)
    if source=="Bulo" then BuloLayerForever={current=key,Radar={seen={}}}; N.Main.poll()
    else
        local server,uid=key:match("^(%d+)%-(%d+)$")
        for i=kind,kind+1 do
            H.units().target={guid="Creature-0-"..server.."-0-"..uid.."-"..i.."-ABC",player=false}
            H.deliver("PLAYER_TARGET_CHANGED"); H.drain()
        end
        H.units().target=nil
    end
end
for _,source in ipairs({"NPC","Bulo"}) do
    for _,delay in ipairs({2,10,11}) do
        H.test("Layer churn counting: "..source.." change at boundary plus "..delay,function()
            local N=H.load(); H.establish(N); H.units().target=nil; H.units().mouseover=nil
            H.clock(100); H.deliver("SHARD_TRANSFER"); H.drain()
            H.clock(101); confirm(N,source,"8000-8",3)
            H.eq(N.Main.store.bulo,"8000-8"); H.eq(#N.Main.keyChanges,0,"first post-boundary learning is not churn")
            local serial=N.Main.store.serial
            H.clock(100+delay); confirm(N,source,"9000-9",5)
            H.eq(N.Main.store.bulo,"9000-9"); H.eq(N.Main.store.serial,serial,"unexplained change never wipes")
            H.eq(#N.Main.keyChanges,1,"every subsequent unexplained change counts, even within ten seconds")
            H.eq(N.Main.keyChanges[1],100+delay)
            confirm(N,source,"9000-9",7); H.eq(#N.Main.keyChanges,1,"same-key refresh does not count")
            H.no(N.Main.error)
        end)
    end
end
