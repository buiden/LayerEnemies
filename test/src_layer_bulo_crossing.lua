-- Bulo can stay readable while the NPC evidence expires before a group move.
local H=...
for _,expired in ipairs({false,true}) do
    H.test("Layer Bulo crossing: Find and actual O with "..(expired and "expired NPC history" or "Bulo-only history"),function()
        local N=H.load()
        if expired then H.establish(N) end
        BuloLayerForever={current="7086-7",Radar={seen={}}}
        H.clock(20); N.Main.poll()
        H.clock(309); H.drain(); H.yes(N.Main.track("Cedar Vale"))
        H.units().target=H.player("Cedar Vale","Horde","Player-1-ABC")
        H.deliver("PLAYER_TARGET_CHANGED"); H.drain(); H.units().target=nil; H.units().mouseover=nil
        H.yes(N.Main.findRows()[1].same)
        H.group(true); H.deliver("GROUP_ROSTER_UPDATE")
        local serial,first=N.Main.store.serial,#H.sent()
        H.clock(311); N.Main.poll()
        for kind=3,4 do
            H.units().target={guid="Creature-0-9000-0-9-"..kind.."-ABC",player=false}
            H.deliver("PLAYER_TARGET_CHANGED"); H.drain()
        end
        H.units().target=nil; H.advance(3); N.Main.shareTick()
        local row=N.Main.findRows()[1]
        local text=N.Main.findText(row):lower()
        local layers={}
        for i=first+1,#H.sent() do
            local s=H.sent()[i]
            if s.prefix=="LEGW1" and s.text:sub(1,2)=="O|" then
                layers[#layers+1]=s.text:match("^O|1|[^|]+|[^|]+|[^|]+|[^|]+|([^|]*)|") or "bad shape"
            end
        end
        H.eq(row.status.." / "..tostring(row.same==true).." / "..table.concat(layers,","),
            "seen by you / false / ","Find status / same / actual O layer (cancelled at crossing)")
        H.no(text:find("your layer",1,true)); H.yes(text:find("cedar vale",1,true))
        H.yes(N.Main.store.serial>serial,"real group-associated boundary")
        H.eq(N.Main.store.bulo,"9000-9"); H.eq(#layers,0,"old sighting must not be sent")
        H.eq(N.Main.store.localSeen["Player-1-ABC"],nil); H.no(N.Main.error)
    end)
end
