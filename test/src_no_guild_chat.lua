local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
H.test("Parity guild: draft functions removed and arbitrary guild draft refused",function()
    local N=H.load()
    for _,name in ipairs({"guildLine","guildBlindLine","guildRequest","GUILD"}) do eq(N.Hop[name],nil,name) end
    eq(N.Main.guildAsk,nil); eq(N.Main.layerswapGuild,nil); eq(N.Hop.new().guildAsk,nil)
    no(N.Main.openChat("/g inv layer <LS 100 r2 20.0,30.0>"))
    no(N.Main.openChat("anything","GUILD"))
end)
for _,hidden in ipairs({false,true}) do
    test("Parity guild: empty host list searches WHO without chat hidden="..tostring(hidden),function()
        local N=H.hopLoad()
        if hidden then N.Main.store.trust=N.Trust.new(71037); N.Trust.drop(N.Main.store,"test"); LayerEnemiesDB.hopLimit=N.Trust.paceLoad(nil,N.Adapters.ownIdentity(),H.wall()) end
        LayerSwapDB=nil; local drafts=0
        N.Main.openChat=function() drafts=drafts+1; return true end
        local p=N.Main.hopAnyPreview(); yes(p.enabled)
        H.clickWith(function() yes(N.Main.hopAny(p)) end)
        eq(#H.whoCalls(),1); eq(drafts,0); yes(N.Main.hopAnyState.round)
        H.deliver("WHO_LIST_UPDATE"); yes(#H.sent()>0)
        for _,s in ipairs(H.sent()) do if s.prefix=="LayerSwap" then eq(s.kind,"WHISPER"); if hidden then yes(s.text:find(" r2 ",1,true)) end end end
        no(N.Main.error)
    end)
end
H.test("Parity guild: no-host targeted preview replaces guild ask with WHO",function()
    local N=H.hopLoad(); local M=N.Main
    local r={zone=100,layer={ns="server",value="9000"},kind="sighting",hand="first",heard=H.clock()}
    local p=M.hopPreview(r); eq(p.label,"Find a host"); eq(p.mode,"search")
    H.clickWith(function() yes(M.hopTo(r,p)) end); eq(#H.whoCalls(),1); no(M.error)
end)
