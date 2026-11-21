-- Direct boundary controls supplement the real event regressions for mutants.
local H=...
H.test("Trust guards: NPC freshness is post-join, current, bounded and monotonic",function()
    local N=H.load(); local T,s=N.Trust,N.Store.new(0)
    T.read(s,100,"7086-7",7)
    T.npc(s,100,"9000-9"); H.no(T.fresh(s,100,99),"mismatched NPC cannot confirm our key")
    T.read(s,101,"9000-9",9)
    H.no(T.fresh(s,101,99),"a donor change cannot retroactively validate a mismatched NPC")
    T.read(s,100,"7086-7",7)
    T.npc(s,100,"7086-7"); H.yes(T.fresh(s,100,99))
    H.no(T.fresh(s,100,100),"same clock is not after join"); H.no(T.fresh(s,100,nil))
    T.read(s,99,"7086-7",7); H.no(T.fresh(s,99,98),"future NPC is not evidence")
    T.read(s,399,"7086-7",7); H.yes(T.fresh(s,399,99))
    T.read(s,400,"7086-7",7); H.no(T.fresh(s,400,99),"fresh donor cannot extend old NPC evidence")
    T.read(s,110,"9000-9",9); H.no(T.fresh(s,110,99),"NPC must confirm the current full key")
end)
H.test("Trust guards: peer claim must follow join and precede current time",function()
    local N=H.load(); local T=N.Trust
    for _,at in ipairs({99,100,103}) do
        local s=N.Store.new(0); T.read(s,101,"7086-7",7); T.npc(s,101,"7086-7")
        T.group(s,102,"peer","9000",true,100,at,98); H.eq(s.trust.group,nil,"stale/equal/future claim")
    end
    local s=N.Store.new(0); T.read(s,101,"7086-7",7); T.npc(s,101,"7086-7")
    T.group(s,341,"peer","9000",true,100,101,98); H.yes(s.trust.group)
    T.read(s,400,"7086-7",7); T.npc(s,400,"7086-7")
    T.group(s,400,"peer","9000",true,100,101,98); H.eq(T.state(s,400),"known")
    T.group(s,401,"peer","9000",true,100,101,98); H.eq(T.state(s,401),"known","expired peer cannot complete contradiction")
end)
H.test("Trust guards: coalescing never merges separate changes or clock rollback",function()
    local N=H.load(); local T=N.Trust
    for _,case in ipairs({"same source","different key","rollback"}) do
        local s=N.Store.new(0)
        H.yes(T.change(s,120,"9000-9","Bulo server id"))
        local key=case=="different key" and "10000-10" or "9000-9"
        local source=case=="same source" and "Bulo server id" or "local NPC server id"
        H.eq(T.change(s,case=="rollback" and 119 or 121,key,source),case~="same source",case.." transition identity")
        H.eq(#s.trust.changes,case=="different key" and 2 or 1)
    end
end)
H.test("Trust guards: outgoing WE projection preserves all nonlayer bytes",function()
    local N=H.load(); local T,s=N.Trust,N.Store.new(0)
    local lines={"C|42|100|0.200|0.300|9000|2|100||1:2","H|1.0.0|100|9000|1|19|0|0|100||M|60|1|0|1","E|42|1|1|AbC:M:60|100"}
    for _,inner in ipairs(lines) do for _,wrap in ipairs({false,true}) do
        local text=wrap and N.WeOut.wrap("W","Cedar Vale",123,inner) or inner
        H.eq(T.we(s,text,100,false),text,"remote claim never masked")
        local expected=text:gsub("|9000|","|0|")
        H.eq(T.we(s,text,100,true),expected)
        T.read(s,100,"9000-9",9); H.eq(T.we(s,text,100,true),text)
        T.read(s,100,"7086-7",7); H.eq(T.we(s,text,100,true),expected,"known but different key is masked")
        T.read(s,100,nil,nil)
    end end
end)
