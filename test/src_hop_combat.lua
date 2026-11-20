-- Hopper combat policy: exercise real click, event, timer and Wire boundaries.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function requests(prefix,tag)
    local out={}
    for _,s in ipairs(H.sent()) do
        if s.prefix==prefix and (not tag or s.text:match("^(%u+)")==tag) then out[#out+1]=s end
    end
    return out
end
local function flhHosts(N)
    N.Net.SHIP.flh=true -- the common loader silences source sends for unrelated tests
    C_AddOns.GetAddOnMetadata=function() return "1.2.5" end
    for i=1,10 do
        H.deliver("CHAT_MSG_ADDON","FLHNET2","HI|100|"..(10+i).."|1|0.1.3|1234","WHISPER","Host "..H.abc(i))
    end
    eq(#N.Main.candidates(),10)
end
local function offer(N,q)
    local m=N.FLH.decode(q.text)
    H.deliver("CHAT_MSG_ADDON","FLHNET2","LO|"..m.id.."|100|"..m.wantedKey.."|0|0","WHISPER",q.target)
end

test("Hop combat: FLH guest batch paces in combat, reserves cost two for LR and keeps membership silent",function()
    local N=H.hopLoad(); flhHosts(N); H.combat(true)
    SlashCmdList.LAYERENEMIES("hop flh")
    eq(#requests("FLHNET2","LQ"),3,"eight shared tokens: three cost-two queries and one cost-two LR reserve")
    no(N.Wire.send("LayerSwap","same","WHISPER","Other Peer",{prio="own"}),"ordinary send cannot steal LR's two tokens")
    H.deliver("CHAT_MSG_ADDON","FLHNET2","WP|42|1234|0.1.3|100|8|1","WHISPER","Other Peer")
    H.advance(2); eq(#requests("FLHNET2","LQ"),3)
    H.advance(1.1); eq(#requests("FLHNET2","LQ"),4,"source timer must continue guest work in combat")
    local q=requests("FLHNET2","LQ")[1]; offer(N,q)
    eq(#requests("FLHNET2","LR"),1); eq(requests("FLHNET2","LR")[1].target,q.target)
    for _,s in ipairs(requests("FLHNET2")) do yes(s.text:match("^LQ|") or s.text:match("^LR|"),"no presence, probe or owed reply in combat") end
    H.deliver("PARTY_INVITE_REQUEST",q.target); eq(H.accepts(),1)
    no(N.Main.error); eq(H.forbidden(),0)
end)

test("Hop combat: FLH click survives combat starting before its offer",function()
    local N=H.hopLoad(); flhHosts(N); SlashCmdList.LAYERENEMIES("hop flh")
    local q=requests("FLHNET2","LQ")[1]; yes(q)
    H.combat(true); H.deliver("PLAYER_REGEN_DISABLED"); yes(N.FLHMember.pending())
    offer(N,q); eq(#requests("FLHNET2","LR"),0,"peace's last token cannot pay combat LR")
    H.advance(2); eq(#requests("FLHNET2","LR"),1,"held offer retries through source tick")
    H.deliver("PARTY_INVITE_REQUEST",q.target); eq(H.accepts(),1)
    no(N.Main.error); eq(H.forbidden(),0)
end)

local function clickBar(N)
    N.HopBar.refresh()
    local f=N.HopBar.frame
    H.clickWith(function() f.scripts.OnMouseDown(f,"LeftButton"); f.scripts.OnClick(f,"LeftButton") end)
end

for _,entry in ipairs({"slash","bar"}) do
    test("Hop combat: "..entry.." starts in combat and still uses the doubled Wire cost",function()
        local N=H.hopLoad(); H.combat(true)
        if entry=="slash" then H.hopClick(N) else
            eq(N.HopBar.statusText(),"Hop ready"); clickBar(N)
        end
        yes(N.Main.hopAnyState.round,"combat must not refuse a click")
        eq(#H.whoCalls(),1,"WHO remains synchronous in the click stack")
        H.deliver("WHO_LIST_UPDATE")
        eq(#requests("LayerSwap"),4,"eight-token bucket buys four combat requests, not eight")
        H.advance(1); eq(#requests("LayerSwap"),4,"one refill token is not enough in combat")
        H.advance(1); eq(#requests("LayerSwap"),5,"two refill tokens buy one request")
        no(N.Main.error); eq(H.forbidden(),0)
    end)
end

test("Hop combat: combat-start event and later pumps retain the clicked round",function()
    local N=H.hopLoad(); H.hopClick(N)
    local r=N.Main.hopAnyState.round; yes(r)
    H.combat(true); H.deliver("PLAYER_REGEN_DISABLED")
    eq(N.Main.hopAnyState.round,r,"combat start must not cancel the search")
    H.deliver("WHO_LIST_UPDATE"); eq(#requests("LayerSwap"),4)
    H.advance(2.1); eq(N.Main.hopAnyState.round,r); yes(#requests("LayerSwap")>4)
    no(N.Main.error); eq(H.forbidden(),0)
end)

local function join(name)
    H.group(true); H.units().party1={name=name,leader=true}
    H.deliver("GROUP_ROSTER_UPDATE")
end
local function manual(N,entry)
    H.deliver("CHAT_MSG_ADDON","LFSw","L 8000|100|h","GUILD","Host Cedar")
    if entry=="host" then
        SlashCmdList.LAYERENEMIES("hosts"); SlashCmdList.LAYERENEMIES("hop host 1")
    else
        local record=assert(N.Record.new({src="we",kind="group",origin="Scout",via="Scout",route="GUILD",rid="1",
            zone=100,count=1,layer={ns="server",value="8000"},heard=H.clock(),share="guild"}))
        N.Main.hopList={at=H.clock(),records={record},shown={N.Main.hopPreview(record)}}
        SlashCmdList.LAYERENEMIES("hop 1")
    end
end
for _,entry in ipairs({"host","report","slash","bar","flh"}) do
    test("Hop combat: instance still refuses "..entry.." requests",function()
        for _,state in ipairs({"instance","unreadable"}) do
            local N=H.hopLoad()
            if entry=="flh" then flhHosts(N) end
            H.combat(true)
            if state=="instance" then H.instance(true) else IsInInstance=function() return H.secret end end
            if entry=="slash" then H.hopClick(N)
            elseif entry=="bar" then clickBar(N)
            elseif entry=="flh" then SlashCmdList.LAYERENEMIES("hop flh")
            else manual(N,entry) end
            eq(#H.whoCalls(),0); eq(#H.sent(),0,"no request in "..state)
            no(N.Main.invite.pending); no(N.FLHMember.pending()); no(N.Main.error)
        end
    end)
end

test("Hop combat: guild host still refuses combat requests, but invites after combat",function()
    local N=H.hopLoad(); H.roster({{"Guest Cedar-TestRealm",true}})
    H.deliver("GUILD_ROSTER_UPDATE"); yes(N.Main.setHost(true))
    local attempts=0; local real=N.Wire.invite
    N.Wire.invite=function(...) attempts=attempts+1; return real(...) end
    H.combat(true)
    H.deliver("CHAT_MSG_ADDON","LayerSwap","inv layer <LS 100 want 7086-0>","WHISPER","Guest Cedar")
    eq(attempts,0,"host combat refusal stays in front of Wire")
    H.combat(false)
    H.deliver("CHAT_MSG_ADDON","LayerSwap","inv layer <LS 100 want 7086-0>","WHISPER","Guest Cedar")
    eq(attempts,1,"otherwise eligible request really invites")
    no(N.Main.error); eq(H.forbidden(),0)
end)

for _,entry in ipairs({"host","report"}) do
    test("Hop combat: manual "..entry.." request accepts only its asked host in combat",function()
        local N=H.hopLoad(); H.combat(true); manual(N,entry)
        local sent=requests("LayerSwap"); eq(#sent,1); eq(sent[1].target,"Host Cedar")
        H.deliver("PARTY_INVITE_REQUEST","Unasked Person"); eq(H.accepts(),0)
        H.deliver("PARTY_INVITE_REQUEST","Host Cedar-Elsewhere"); eq(H.accepts(),0)
        H.deliver("PARTY_INVITE_REQUEST","Host Cedar"); eq(H.accepts(),1)
        H.deliver("PARTY_INVITE_REQUEST","Host Cedar"); eq(H.accepts(),1,"one accept per request")
        no(N.Main.error); eq(H.forbidden(),0)
    end)
end

test("Hop combat: asked hop-any invite is accepted and a second hop works without combat ending",function()
    local N=H.hopLoad(); H.combat(true); H.hopClick(N); H.deliver("WHO_LIST_UPDATE")
    H.deliver("PARTY_INVITE_REQUEST","Seeker a"); eq(H.accepts(),1)
    join("Seeker a"); N.Main.applyLayer("8000-8","test")
    H.advance(2.9); eq(H.leaves(),0); H.advance(.2); eq(H.leaves(),1)
    H.units().party1=nil; H.deliver("GROUP_ROSTER_UPDATE")
    H.advance(11); H.hopClick(N); eq(#H.whoCalls(),2)
    H.deliver("WHO_LIST_UPDATE"); yes(N.Main.hopAnyState.round.sent>0)
    no(N.Main.error); eq(H.forbidden(),0)
end)

for _,moved in ipairs({true,false}) do
    test("Hop combat: leave "..(moved and "after a move" or "after failure").." does not wait for combat end",function()
        local N=H.hopLoad(); H.hopClick(N); H.deliver("WHO_LIST_UPDATE")
        H.deliver("PARTY_INVITE_REQUEST","Seeker a"); eq(H.accepts(),1); join("Seeker a")
        H.combat(true); H.deliver("PLAYER_REGEN_DISABLED")
        if moved then N.Main.applyLayer("8000-8","test"); H.advance(2.9)
        else H.advance(29.9) end
        eq(H.leaves(),0); H.advance(.2); eq(H.leaves(),1)
        H.advance(20); eq(H.leaves(),1,"leave exactly once")
        no(N.Main.error); eq(H.forbidden(),0)
    end)
end
