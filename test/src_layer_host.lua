local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no

test("Layer A4: ambiguous GuildHost decide is silent for every answer kind",function()
    local N=H.load(); local G=N.GuildHost
    for _,req in ipairs({{want="7086-7"},{want="8000-8"},{nots={"7086-7"}},{nots={"8000-8"}}}) do
        local st=G.new(); st.on=true; req.name="Guest Cedar"; req.zone=100
        local own={self="me",zone=100,key="7086",id="7086-7",inInstance=false,inCombat=false,
            raid=false,leader=true,members={},member=true,ambiguous=true}
        local verdict,reply=G.decide(st,req,own,100)
        eq(verdict,"drop"); eq(reply,nil); eq(next(st.asked),nil); eq(st.lastInvite,nil)
        own.ambiguous=false; local positive=G.decide(st,req,own,100); no(positive=="drop")
    end
end)

test("Layer A4: live host snapshot passes ambiguity and sends no answer",function()
    local N=H.hopLoad(); H.roster({{"Guest Cedar-TestRealm",true}})
    H.deliver("GUILD_ROSTER_UPDATE"); yes(N.Main.setHost(true))
    N.Main.npcs.ambigAt=H.clock()
    local attempts=0; local real=N.Wire.invite
    N.Wire.invite=function(...) attempts=attempts+1; return real(...) end
    local before=#H.sent()
    H.deliver("CHAT_MSG_ADDON","LayerSwap","inv layer <LS 100 want 7086-0>","WHISPER","Guest Cedar")
    eq(attempts,0); eq(#H.sent(),before); yes(N.Main.hostOwn().ambiguous)
    N.Main.npcs.ambigAt=nil
    H.deliver("CHAT_MSG_ADDON","LayerSwap","inv layer <LS 100 want 7086-0>","WHISPER","Guest Cedar")
    eq(attempts,1,"ambiguity refusal did not consume the request")
    no(N.Main.error)
end)
