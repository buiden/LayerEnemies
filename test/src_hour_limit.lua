local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
H.test("Parity pace: corrupt saves cannot silently remove the estimate",function()
    local N=H.load(); local T=N.Trust
    for _,saved in ipairs({
        {who="Cedar Scout",moves={1000}},
        {who="Cedar Scout",start=1000,moves={1000,H.secret}},
        {who="Cedar Scout",start=H.secret,moves={}},
        {who="Cedar Scout",start=1000,moves={},hold=H.secret},
    }) do
        local p=T.paceLoad(saved,"Cedar Scout",1001)
        yes(T.paceWait(p,1001)>0,"invalid saved pacing is not a fresh hour")
    end
end)
H.test("Parity pace: ten moves, back-to-back hours, reload and per-character",function()
    local N=H.load(); local T=N.Trust; yes(T.paceLoad,"pace exists")
    local p=T.paceLoad(nil,"Cedar Scout",1000)
    for i=0,8 do T.paceMove(p,1000+i); eq(T.paceWait(p,1000+i),0) end
    T.paceMove(p,1010); eq(T.paceWait(p,1010),3590)
    local copy=T.paceLoad(p,"Cedar Scout",1010); eq(T.paceWait(copy,1010),3590)
    eq(T.paceWait(T.paceLoad(p,"Birch Scout",1010),1010),0)
    local late=T.paceLoad(copy,"Cedar Scout",1010)
    T.paceMove(late,4700); eq(late.start,4600)
    eq(T.paceWait(copy,4599),1); eq(T.paceWait(copy,4600),0)
    T.paceMove(copy,4700); eq(copy.start,4600); eq(#copy.moves,1)
    for i=1,9 do T.paceMove(copy,4700+i) end
    eq(T.paceWait(copy,4709),3491); eq(T.paceWait(copy,8200),0)
end)
H.test("Parity pace: refusal hold 900 seconds, rollback fails closed and bounded loads",function()
    local N=H.load(); local T=N.Trust; yes(T.paceLoad,"pace exists")
    local p=T.paceLoad(nil,"Cedar Scout",1000)
    T.paceRefused(p,1000); eq(T.paceWait(p,1000),900); eq(T.paceWait(p,1899),1); eq(T.paceWait(p,1900),0)
    T.paceMove(p,2000); T.paceRefused(p,2001); yes(T.paceWait(p,1999)>0)
    local q=T.paceLoad({who="Cedar Scout",start=2000,moves={2000},hold=2901},"Cedar Scout",1999)
    yes(T.paceWait(q,1999)>0); no(#q.moves>10)
end)
H.test("Parity pace: hidden click blocks combat and estimate hold, no r2 before admission",function()
    local N=H.load(nil,function() GetBuildInfo=function() return "x","71037","d",16001 end end)
    H.clock(120); H.wall(1000)
    LayerSwapDB={book={["Host Cedar"]={layer="8000-8",zone=100,at=1000,host=true}}}
    H.combat(true); no(N.Main.blindPreview().enabled,"combat disables hidden ask"); no(N.Main.hopAny())
    H.combat(false); yes(N.Main.blindPreview().enabled)
    yes(N.Main.hopAny()); local found=false
    for _,s in ipairs(H.sent()) do if s.prefix=="LayerSwap" then found=true; eq(s.text,"inv layer <LS 100 r2 25.0,75.0>") end end
    yes(found); N.Main.hopAnyStop()
    for i=1,10 do N.Trust.paceMove(LayerEnemiesDB.hopLimit,1000+i) end
    H.wall(1010); H.clock(200); local p=N.Main.blindPreview()
    no(p.enabled); yes(p.reason:find("estimate",1,true)); no(N.Main.hopAny())
    yes(N.HopBar.statusText():find("estimate",1,true),"bar shows estimated wait")
end)
