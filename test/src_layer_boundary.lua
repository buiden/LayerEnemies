local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function npc(kind,uid,server)
    return "Creature-0-"..(server or "7086").."-0-"..uid.."-"..kind.."-ABC"
end
local function read(N,kind,uid,server)
    H.units().target={guid=npc(kind,uid,server),player=false}
    H.deliver("PLAYER_TARGET_CHANGED"); H.drain(); no(N.Main.error)
end
local function seeded()
    local N=H.load(); H.establish(N); H.clock(120)
    -- Real unit and guild-record ingress; forwarding spies count cancellation,
    -- without manufacturing a pending death recap or cancelling it ourselves.
    H.units().target=H.player("Enemy One","Horde")
    H.deliver("PLAYER_TARGET_CHANGED"); H.drain()
    H.deliver("CHAT_MSG_ADDON","LEGW1","O|1|42|100|0.200|0.300|8000|0|1|456e656d79204f6e65:MAGE:60","GUILD","Scout One")
    local sight=N.Main.store.localSeen["Player-1-123"]; yes(sight)
    local key,row=next(N.Main.store.reports); yes(row)
    local cancelled={death=0,share=0,fragments=0}
    local cancel=N.OwnDeath.cancel; N.OwnDeath.cancel=function(...) cancelled.death=cancelled.death+1; return cancel(...) end
    local share=N.Share.cancel; N.Share.cancel=function(...) cancelled.share=cancelled.share+1; return share(...) end
    local fragments=N.Reports.clearPending; N.Reports.clearPending=function(...) cancelled.fragments=cancelled.fragments+1; return fragments(...) end
    return N,{sight=sight,key=key,row=row,serial=N.Main.store.serial,cancelled=cancelled}
end
local function kept(N,s)
    eq(N.Main.store.localSeen["Player-1-123"],s.sight); eq(N.Main.store.reports[s.key],s.row)
    eq(N.Main.store.serial,s.serial); eq(s.cancelled.death,0); eq(s.cancelled.share,0); eq(s.cancelled.fragments,0)
end
local function wiped(N,s)
    eq(N.Main.store.localSeen["Player-1-123"],nil); eq(N.Main.store.reports[s.key],nil)
    yes(N.Main.store.serial>s.serial); yes(s.cancelled.death>0); yes(s.cancelled.share>0); yes(s.cancelled.fragments>0)
end

test("Layer A5: rotating NPC identifiers update confirmed key without wipes",function()
    local N,s=seeded()
    for i=1,4 do
        H.clock(130+i); read(N,10*i,7+i); kept(N,s)
        read(N,10*i+1,7+i); kept(N,s)
        eq(N.Main.store.bulo,"7086-"..(7+i)); eq(N.Main.store.zoneUID,7+i)
    end
    eq(#N.Main.keyChanges,3,"bounded churn evidence for PR 2")
    eq(N.Main.keyChanges[1],132); eq(N.Main.keyChanges[3],134)
end)

test("Layer A5: rotating Bulo IDs and donor transfer notifications wipe nothing",function()
    local N,s=seeded(); local callbacks={}
    BuloLayerForever={current="8000-8",Radar={seen={}},On=function(_,event,fn) callbacks[event]=fn end}
    H.clock(131); N.Main.poll(); kept(N,s); eq(N.Main.store.bulo,"8000-8")
    BuloLayerForever.current="9000-9"; H.clock(132); callbacks.LFS_TRANSFER(); H.drain()
    kept(N,s); eq(N.Main.store.bulo,"9000-9"); eq(#N.Main.keyChanges,2)
end)

for _,event in ipairs({"PLAYER_ENTERING_WORLD","SHARD_TRANSFER","ZONE_CHANGED","ZONE_CHANGED_NEW_AREA"}) do
    for _,changed in ipairs({false,true}) do
        test("Layer A5: real "..event..(changed and " with new zone" or " same zone"),function()
            local N,s=seeded()
            if changed then C_Map.GetBestMapForUnit=function() return 200 end end
            H.clock(131); H.deliver(event); H.drain()
            if event:match("^ZONE") and not changed then kept(N,s) else wiped(N,s) end
            no(N.Main.error)
        end)
    end
end

for _,join in ipairs({true,false}) do
    for _,delay in ipairs({10,11}) do
        for _,source in ipairs({"npc","bulo"}) do
            test("Layer A5: "..(join and "join" or "leave").." "..source.." confirmed change at "..delay.." seconds",function()
                local N,s=seeded()
                if not join then H.group(true); H.clock(121); H.deliver("GROUP_ROSTER_UPDATE") end
                H.clock(130); H.group(join); H.deliver("GROUP_ROSTER_UPDATE"); kept(N,s)
                H.clock(130+delay)
                if source=="npc" then read(N,3,8); kept(N,s); read(N,4,8)
                else BuloLayerForever={current="8000-8",Radar={seen={}}}; N.Main.poll() end
                if delay==10 then wiped(N,s) else kept(N,s); eq(#N.Main.keyChanges,1) end
                eq(N.Main.store.bulo,source=="npc" and "7086-8" or "8000-8"); no(N.Main.error)
            end)
        end
    end
end

test("Layer A5: unreadable group state and repeated roster are not new transitions",function()
    local N,s=seeded(); H.clock(130); IsInGroup=function() return H.secret end
    H.deliver("GROUP_ROSTER_UPDATE"); H.clock(131); N.Main.applyLayer("8000-8","Bulo server id"); kept(N,s)
    IsInGroup=function() return false end; H.deliver("GROUP_ROSTER_UPDATE")
    H.clock(132); H.deliver("GROUP_ROSTER_UPDATE"); N.Main.applyLayer("9000-9","Bulo server id"); kept(N,s)
end)

test("Layer A5: unreadable map is not a crossing and churn ages out",function()
    local N,s=seeded(); C_Map.GetBestMapForUnit=function() return nil end
    H.clock(131); H.deliver("ZONE_CHANGED"); H.drain(); kept(N,s)
    C_Map.GetBestMapForUnit=function() return 100 end
    H.deliver("ZONE_CHANGED"); H.drain(); kept(N,s)
    N.Main.applyLayer("8000-8","Bulo server id"); eq(#N.Main.keyChanges,1)
    H.clock(730); N.Main.applyLayer("9000-9","Bulo server id"); eq(#N.Main.keyChanges,2)
    H.clock(731); N.Main.applyLayer("10000-10","Bulo server id"); eq(#N.Main.keyChanges,2)
    eq(N.Main.keyChanges[1],730)
end)

test("Layer A5: NPC changes are counted while Bulo supplies the server key",function()
    for _,join in ipairs({false,true}) do
        local N,s=seeded(); BuloLayerForever={current="7086-7",Radar={seen={}}}; N.Main.poll()
        H.clock(130); if join then H.group(true); H.deliver("GROUP_ROSTER_UPDATE") end
        H.clock(140); read(N,3,8); read(N,4,8)
        eq(N.Main.store.zoneUID,8)
        if join then wiped(N,s) else kept(N,s); eq(#N.Main.keyChanges,1) end
    end
end)

test("Layer A5: confirmed post-join NPC key keeps its expiry clock",function()
    local N=H.load(); H.establish(N)
    H.clock(130); H.group(true); H.deliver("GROUP_ROSTER_UPDATE")
    H.clock(140); read(N,3,8); read(N,4,8)
    eq(N.Main.store.bulo,"7086-8"); eq(N.Main.store.zoneUID,8)
    H.clock(439); N.Main.poll(); eq(N.Main.store.bulo,"7086-8")
    H.clock(440); N.Main.poll(); eq(N.Main.store.bulo,nil); eq(N.Main.store.zoneUID,nil)
end)

test("Layer A5: post-join Bulo change discards the old NPC fingerprint",function()
    local N=H.load(); H.establish(N)
    H.clock(130); H.group(true); H.deliver("GROUP_ROSTER_UPDATE")
    H.clock(140); BuloLayerForever={current="8000-8",Radar={seen={}}}; N.Main.poll()
    eq(N.Main.store.bulo,"8000-8"); eq(N.Main.store.zoneUID,nil)
end)

test("Layer A5: expiry and recovery are not a new crossing",function()
    local N,s=seeded(); H.clock(420); N.Main.poll(); eq(N.Main.store.bulo,nil); kept(N,s)
    read(N,3,8); read(N,4,8); kept(N,s); eq(N.Main.store.bulo,"7086-8")
end)

for _,transfer in ipairs({false,true}) do
    test("Layer A5: pending own-death send "..(transfer and "cancels on real transfer" or "survives an ID rotation"),function()
        local N=H.load(); H.establish(N); H.advance(.1)
        H.units().target=H.player("Enemy One","Horde","Player-1-123")
        H.deliver("PLAYER_TARGET_CHANGED"); H.drain()
        C_DeathRecap={HasRecapEvents=function() return true end,GetRecapEvents=function()
            return {{sourceGUID="Player-1-123",sourceName="Enemy",sourceFlags=0x448,overkill=10,timestamp=H.clock()}}
        end}
        H.deliver("PLAYER_DEAD")
        if transfer then H.deliver("SHARD_TRANSFER") else N.Main.applyLayer("8000-8","Bulo server id") end
        H.advance(.3)
        local deaths=0; for _,s in ipairs(H.sent()) do if s.prefix=="LEGW1" and s.text:sub(1,2)=="K|" then deaths=deaths+1 end end
        eq(deaths,transfer and 0 or 1); no(N.Main.error)
    end)
end
