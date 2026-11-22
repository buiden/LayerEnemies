local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
for _,surface in ipairs({"window","bar"}) do
    for _,token in ipairs({false,true}) do
        test("Parity review search: stoppable "..surface.." token="..tostring(token),function()
            local N=H.hopLoad(); local M=N.Main
            M.store.trust=N.Trust.new(71037); N.Trust.drop(M.store,"fixture")
            LayerEnemiesDB.hopLimit=N.Trust.paceLoad(nil,N.Adapters.ownIdentity(),H.wall())
            if token then yes(N.Trust.adopt(M.store,H.clock(),"7000-7",100,"peer","Host Birch")) end
            LayerSwapDB=nil; N.UI.toggle()
            H.clickWith(function() yes(M.hopAny(M.hopAnyPreview())) end)
            local round=M.hopAnyState.round; yes(round); eq(round.phase,"who")
            H.combat(true) -- stopping an existing round is never a new request
            if surface=="window" then
                local preview=M.hopAnyPreview()
                eq(preview.label,"Stop"); yes(preview.enabled); eq(preview.round,round)
                N.UI.render(); eq(N.UI.hopAny.label:GetText(),"Stop"); eq(N.UI.hopAny.round,round)
                H.clickWith(function() N.UI.hopAny.scripts.OnClick() end)
            else
                local status,shown=N.HopBar.statusText()
                eq(status,"Hopping: searching..."); eq(shown,round)
                N.HopBar.refresh(); eq(N.HopBar.frame.round,round)
                H.clickWith(function() N.HopBar.hop() end)
            end
            eq(M.hopAnyState.round,nil); no(M.error)
        end)
    end
end
for _,automatic in ipairs({true,false}) do
    test("Parity search: WHO reply survives group boundary auto="..tostring(automatic),function()
        local N=H.hopLoad(); local M=N.Main
        M.store.trust=N.Trust.new(71037); N.Trust.drop(M.store,"fixture")
        LayerEnemiesDB.hopLimit=N.Trust.paceLoad(nil,N.Adapters.ownIdentity(),H.wall())
        LayerSwapDB=nil
        C_FriendList.GetNumWhoResults=function() return 1 end
        C_FriendList.GetWhoInfo=function() return {fullName="Host Cedar",area="Ashenvale"} end
        if not automatic then M.setAutoHop(false) end
        H.clickWith(function() yes(M.hopAny(M.hopAnyPreview())) end)
        H.deliver("WHO_LIST_UPDATE"); yes(M.blindPending)
        H.deliver("CHAT_MSG_ADDON","LayerSwap","heard Me|8000-8|100|h","WHISPER","Host Cedar")
        H.deliver("PARTY_INVITE_REQUEST","Host Cedar")
        eq(H.accepts(),automatic and 1 or 0)
        H.group(true); H.units().party1={name="Host Cedar",leader=true,player=true}
        H.deliver("GROUP_ROSTER_UPDATE")
        yes(M.auto.group,"matched host keeps probe after WHO round closes")
        H.deliver("SHARD_TRANSFER"); H.drain()
        eq(N.Trust.own(M.store,H.clock()),"8000-8")
        eq(M.blindStatus,"moved to Host Cedar's layer")
        eq(#LayerEnemiesDB.hopLimit.moves,1); no(M.error)
    end)
end
