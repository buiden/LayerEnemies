local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
H.test("Parity host: token answers full id, not token/alias same, no-tag invited",function()
    local N=H.load(nil,function() GetBuildInfo=function() return "x","71037","d",16001 end end)
    H.clock(120); H.roster({{"Cedar Scout",true}}); H.deliver("GUILD_ROSTER_UPDATE")
    yes(N.Trust.adopt(N.Main.store,120,"8000-8",100,"peer","Host Cedar"))
    yes(N.Trust.adopt(N.Main.store,121,"9000-9",100,"peer","Host Birch"))
    N.Main.setHost(true)
    local own=N.Main.hostOwn(); yes(own.hidden,"host knows hidden token")
    for _,body in ipairs({"not 9000-9 r2","not 8000-8 r2","not 7000-7 not 8000-8 r2","r2 20.0,30.0","20.0,30.0","not 9000-7 r99"}) do
        local req=N.GuildHost.parse("inv layer <LS 100 "..body..">"); yes(req); req.name="Cedar Scout"
        local st=N.GuildHost.new(); st.on=true; own.member=true
        local verdict,reply=N.GuildHost.decide(st,req,own,120)
        if body:find("9000%-9") or body:find("8000%-8") then eq(verdict,"same"); eq(reply,"same")
        else eq(verdict,"invite"); eq(reply,"heard Cedar Scout|9000-9|100|h") end
    end
end)
