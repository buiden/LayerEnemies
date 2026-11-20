local H=...
local function fresh()
    local N=H.load(); H.yes(N.Trust,"Trust module loaded")
    return N,N.Store.new(0)
end
H.test("Trust: invalid keys, clock rollback and manual usage fail closed",function()
    local N,s=fresh(); local T=N.Trust
    for _,id in ipairs({0,"0","0-0","broken"}) do T.read(s,10,id,7); H.eq(T.own(s,10),nil) end
    T.read(s,10,"7086-7",7); H.eq(T.own(s,9),nil)
    H.eq(T.manual(s,"bogus"),false); H.eq(T.state(s,10),"known")
    T.manual(s,"on"); T.excuse(s,10); T.creature(s,true); T.read(s,11,"9000-9",9)
    H.eq(T.state(s,11),"blind"); T.manual(s,"off"); H.eq(T.state(s,11),"known")
end)
H.test("Trust: Bulo boundary admission and immutable local masking",function()
    local N,s=fresh(); local T=N.Trust
    H.eq(T.bulo({current="7086-7"},"7086-7",{}),nil)
    H.eq(T.bulo({current="7086-7"},"7086-7",{current=7,raw="7086-7"}),"7086-7")
    H.eq(T.bulo({current="7086-7"},"7086-7",{current=9,raw="9000-9"}),nil)
    H.eq(T.bulo({current="bad"},nil,{}),nil)
    local r={name="Cedar Vale",layer={ns="server",value="9000"},count=1}
    H.eq(T.record(s,r,0),r); T.manual(s,"on")
    local c=T.record(s,r,0); H.no(c==r); H.eq(c.layer.ns,"unknown"); H.eq(c.count,1); H.eq(r.layer.value,"9000")
end)
H.test("Trust: reader expiry and sticky manual state",function()
    local N,s=fresh(); local T=N.Trust
    H.eq(T.state(s,0),"unknown"); H.eq(T.own(s,0),nil)
    T.read(s,10,"7086-7",7); H.eq(T.own(s,309),"7086-7")
    H.eq(T.state(s,310),"unknown"); H.eq(T.own(s,310),nil)
    T.read(s,311,"7086-7",7); H.eq(T.state(s,311),"known")
    T.manual(s,"on"); H.eq(T.state(s,311),"blind"); H.eq(T.own(s,311),nil)
    T.read(s,500,"9000-9",9); H.eq(T.own(s,500),nil)
    T.manual(s,"off"); H.eq(T.own(s,500),"9000-9")
    T.manual(s,"on"); T.manual(s,"auto"); H.eq(T.state(s,500),"known")
end)
H.test("Trust: parse thresholds 19/20 cold and 9/10 after success",function()
    local N,s=fresh(); local T=N.Trust
    for i=1,19 do T.creature(s,false) end; H.eq(T.state(s,0),"unknown")
    T.creature(s,false); H.eq(T.state(s,0),"blind")
    s=N.Store.new(0); T.read(s,0,"7086-7",7); T.creature(s,true)
    for i=1,9 do T.creature(s,false) end; H.eq(T.state(s,0),"known")
    T.creature(s,true)
    for i=1,9 do T.creature(s,false) end; H.eq(T.state(s,0),"known")
    T.creature(s,false); H.eq(T.state(s,0),"blind")
end)
H.test("Trust: churn 2/3 and 600-second window with ten-second excuses",function()
    local N,s=fresh(); local T=N.Trust
    T.change(s,1); T.change(s,2); H.eq(T.state(s,2),"unknown")
    T.change(s,3); H.eq(T.state(s,3),"blind")
    s=N.Store.new(0); T.change(s,1); T.change(s,2); T.change(s,601)
    H.eq(T.state(s,601),"unknown"); T.change(s,601.1); H.eq(T.state(s,601.1),"blind")
    s=N.Store.new(0); T.excuse(s,10)
    T.change(s,19); T.change(s,20); H.eq(#s.trust.changes,0)
    T.change(s,21); T.change(s,22); H.eq(T.state(s,22),"unknown")
    T.change(s,23); H.eq(T.state(s,23),"blind")
end)
H.test("Trust: three distinct accepted formed unchanged hops in a row",function()
    local N,s=fresh(); local T=N.Trust
    local function hop(store,host,before,after,formed)
        T.read(store,0,after,7); T.npc(store,0,after)
        T.hop(store,host,before,after,formed,0,-1)
    end
    hop(s,"one","7086","7086",true); hop(s,"two","7086","7086",true)
    H.eq(T.state(s,0),"known"); hop(s,"two","7086","7086",true); H.eq(T.state(s,0),"known")
    hop(s,"three","7086","7086",true); H.eq(T.state(s,0),"known","repeated host breaks distinct triple")
    hop(s,"four","7086","7086",true); H.eq(T.state(s,0),"blind")
    for _,case in ipairs({"moved","not formed","unknown","suffix"}) do
        s=N.Store.new(0); hop(s,"one","7086","7086",true); hop(s,"two","7086","7086",true)
        local after=case~="unknown" and "9000" or nil
        if case=="not formed" then after="7086" end
        if case=="suffix" then after="7086-9" end
        hop(s,"break",case=="suffix" and "7086-7" or "7086",after,case~="not formed")
        hop(s,"three","7086","7086",true); H.eq(T.state(s,0),"known",case)
    end
end)
H.test("Trust: outdoor group mismatch at 59/60 and continuity",function()
    local N,s=fresh(); local T=N.Trust
    T.read(s,0,"7086-7",7); T.npc(s,0,"7086-7")
    T.group(s,0,"peer","9000",true,-1,0); T.group(s,59,"peer","9000",true,-1,0); H.eq(T.state(s,59),"known")
    T.group(s,60,"peer","9000",true,-1,0); H.eq(T.state(s,60),"blind")
    s=N.Store.new(0); T.read(s,0,"7086-7",7); T.npc(s,0,"7086-7")
    T.group(s,0,"peer","7086",true,-1,0); T.group(s,60,"peer","7086",true,-1,0)
    H.eq(T.state(s,60),"known","matching peer never contradicts")
    for _,case in ipairs({"indoor","same","peer changed","unknown"}) do
        s=N.Store.new(0); T.read(s,0,"7086-7",7); T.npc(s,0,"7086-7"); T.group(s,0,"peer","9000",true,-1,0)
        local claim=case~="unknown" and (case=="same" and "7086" or "9000") or nil
        T.group(s,59,case=="peer changed" and "other" or "peer",claim,case~="indoor",-1,0)
        T.group(s,60,"peer","9000",true,-1,0); H.eq(T.state(s,60),"known",case)
    end
end)
