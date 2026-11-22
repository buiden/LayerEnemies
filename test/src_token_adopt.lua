local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
H.test("Parity token adopt: hidden only, live zone, full id, source and alias",function()
    local N=H.load(); local T=N.Trust; yes(T.adopt,"adopt exists")
    local s={zone=100,trust=T.new(71036)}
    no(T.adopt(s,10,"8000-8",100,"host","Host Cedar"))
    s.trust=T.new(71037)
    for _,id in ipairs({"bad","8000","0-8","8000-8-extra",H.secret}) do no(T.adopt(s,10,id,100,"host","Host Cedar")) end
    no(T.adopt(s,10,"8000-8",200,"host","Host Cedar"))
    no(T.adopt(s,10,"8000-8",100,"npc","Host Cedar"))
    yes(T.adopt(s,10,"8000-8",100,"host","Host Cedar"))
    eq(T.own(s,10),"8000-8"); eq(select(2,T.own(s,10)),nil)
    eq(T.state(s,10000),"known"); no(T.adopt(s,11,"8000-8",100,"host","Host Cedar"))
    yes(T.adopt(s,12,"9000-9",100,"peer","Host Birch"))
    eq(s.trust.token.alias,"8000-8"); eq(s.trust.token.host,"Host Birch")
    T.read(s,13,"7000-7",7); T.creature(s,false); T.change(s,13,"7000-7")
    eq(T.own(s,13),"9000-9"); eq(s.zoneUID,nil)
    yes(T.adopt(s,14,"7000-7",100,"host","Host Elm"))
    eq(s.trust.token.alias,nil,"a real transfer cannot alias the layer left")
end)
