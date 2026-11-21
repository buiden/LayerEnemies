local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function setup(mode)
    local N=H.load(); H.clock(120)
    if mode~="unknown" then SlashCmdList.LAYERENEMIES("blind on") end
    _G.LayerSwapDB={book={["Host Cedar"]={layer="987654-876543",zone=100,at=H.wall(),host=true}}}
    return N,N.Main
end
local function sent()
    local out={}; for _,s in ipairs(H.sent()) do if s.prefix=="LayerSwap" then out[#out+1]=s end end; return out
end
local function join(N,name)
    H.deliver("PARTY_INVITE_REQUEST",name or "Host Cedar")
    H.group(true); H.units().party1={name=name or "Host Cedar",leader=true,player=true}
    H.deliver("GROUP_ROSTER_UPDATE")
end
local function sample(count,spawn,players)
    for i=1,40 do H.units()["nameplate"..i]=nil end
    for i=1,count do H.units()["nameplate"..i]={guid="Creature-0-987654-0-876543-"..i.."-"..(spawn or "ABC"),player=false} end
    for i=1,(players or 0) do H.units()["nameplate"..(count+i)]={guid="Player-987654-"..i,player=true} end
end
local function barClick(N)
    local f=N.HopBar.frame; N.HopBar.refresh()
    H.clickWith(function() f.scripts.OnMouseDown(f,"LeftButton"); f.scripts.OnClick(f,"LeftButton") end)
end
for _,mode in ipairs({"unknown","blind"}) do
    test("Blind live: "..mode.." bar click asks once without WHO and only correlated inviter accepted",function()
        local N,M=setup(mode)
        eq(M.hopAnyPreview().label,"Hop (blind)")
        eq(M.hopAnyPreview().detail,"Layer IDs are unreadable. This asks a host for an invite; the addon cannot say which layer you land on.")
        eq(N.HopBar.layerText(),mode=="blind" and "layer hidden" or "Detecting...")
        barClick(N); eq(#sent(),1); eq(#H.whoCalls(),0)
        eq(sent()[1].text,"inv layer <LS 100 25.0,75.0>"); eq(sent()[1].kind,"WHISPER"); eq(sent()[1].target,"Host Cedar")
        barClick(N); H.advance(11); eq(#sent(),1,"no repeat or deferred fallback")
        H.deliver("PARTY_INVITE_REQUEST","Host Cedar-OtherRealm"); eq(H.accepts(),0)
        H.deliver("PARTY_INVITE_REQUEST","Host Birch"); eq(H.accepts(),0)
        H.deliver("PARTY_INVITE_REQUEST","Host Cedar"); eq(H.accepts(),1)
        H.deliver("PARTY_INVITE_REQUEST","Host Cedar"); eq(H.accepts(),1)
        no(M.error)
    end)
end

test("Blind live: manual whisper draft arms only after matching sent event",function()
    local N,M=setup(); _G.LayerSwapDB=nil
    M.heard.flhHosts={ash={name="Host Ash",map=100,key="777",at=H.wall()}}
    local draft; M.openWhisper=function(name,line) draft={name,line}; return true end
    yes(M.hopAny()); eq(#sent(),0); eq(draft[1],"Host Ash")
    eq(draft[2],"/w Host Ash Hi! Could you invite me to your layer please?")
    H.deliver("PARTY_INVITE_REQUEST","Host Ash"); eq(H.accepts(),0)
    H.deliver("CHAT_MSG_WHISPER_INFORM",N.Invite.MESSAGE,"Host Birch")
    H.deliver("PARTY_INVITE_REQUEST","Host Ash"); eq(H.accepts(),0)
    H.deliver("CHAT_MSG_WHISPER_INFORM",N.Invite.MESSAGE,"Host Ash")
    H.deliver("PARTY_INVITE_REQUEST","Host Ash"); eq(H.accepts(),1); no(M.error)
end)

test("Blind live: guild fallback is only a draft; correlation starts at actual send",function()
    local N,M=setup(); _G.LayerSwapDB=nil
    local draft; M.openChat=function(line) draft=line; return true end
    yes(M.hopAny()); eq(draft,"/g inv layer <LS 100 25.0,75.0>"); eq(#sent(),0)
    H.roster({{"Host Cedar",true},{"Host Birch",true}}); H.deliver("GUILD_ROSTER_UPDATE")
    H.deliver("CHAT_MSG_ADDON","LayerSwap","claim "..N.Adapters.ownIdentity(),"GUILD","Host Cedar")
    H.deliver("PARTY_INVITE_REQUEST","Host Cedar"); eq(H.accepts(),0)
    H.deliver("CHAT_MSG_GUILD",draft:sub(4),N.Adapters.ownIdentity())
    H.deliver("PARTY_INVITE_REQUEST","Host Cedar"); eq(H.accepts(),0,"pre-send answer cleared")
    H.deliver("PARTY_INVITE_REQUEST","Host Birch"); eq(H.accepts(),0,"not every guildmate is correlated")
    H.deliver("CHAT_MSG_ADDON","LayerSwap","claim "..N.Adapters.ownIdentity(),"GUILD","Host Cedar")
    H.deliver("PARTY_INVITE_REQUEST","Host Cedar"); eq(H.accepts(),1); no(M.error)
end)

test("Blind live: snapshot before ask, only allowed units, checks at five fifteen thirty",function()
    local N,M=setup(); sample(3,"ABC")
    local takes=0; local real=N.HopProbe.snapshot
    N.HopProbe.snapshot=function(...) takes=takes+1; return real(...) end
    local unitsRead={}; local guid=_G.UnitGUID
    _G.UnitGUID=function(u) unitsRead[u]=true; return guid(u) end
    yes(M.hopAny()); eq(takes,1,"before ask")
    no(unitsRead.party1target); no(unitsRead.raid1target)
    join(N); H.advance(4.99); eq(takes,1)
    H.advance(.01); eq(takes,2)
    H.advance(9.99); eq(takes,2); H.advance(.01); eq(takes,3)
    H.advance(14.99); eq(takes,3); H.advance(.01); eq(takes,4)
    eq(H.leaves(),1)
    eq(N.HopBar.statusText(),"Joined Host Cedar. No change seen; the hop may not have worked.")
    no(M.error)
end)

for _,case in ipairs({{"creatures",3,0},{"players",0,5},{"sparse",2,0},{"transfer",0,0}}) do
    test("Blind live: result "..case[1].." never shows GUID digits and leaves with preserved guard",function()
        local N,M=setup(); sample(case[2],"ABC",case[3]); _G.UnitPosition=function() return 0,0,0,100 end
        yes(M.hopAny()); join(N); local mark=#H.log()
        if case[1]=="creatures" then sample(3,"DEF")
        elseif case[1]=="players" then sample(0,nil,1)
        elseif case[1]=="transfer" then H.deliver("SHARD_TRANSFER") end
        local changed=case[1]~="sparse"
        H.advance(5)
        eq(H.leaves(),0)
        if changed then H.advance(2.99); eq(H.leaves(),0); H.advance(.06)
        else H.advance(10); eq(H.leaves(),0); H.advance(15) end
        eq(H.leaves(),1)
        local result=case[1]
        eq(N.HopBar.statusText(),N.HopProbe.text(result,"Host Cedar"))
        for i=mark+1,#H.log() do no(H.log()[i]:find("987654",1,true)); no(H.log()[i]:find("876543",1,true)) end
        no(M.error)
    end)
end

test("Blind live: no invite expires to exact missed text; never repeats",function()
    local N,M=setup(); yes(M.hopAny()); H.advance(120.1)
    eq(N.HopBar.statusText(),"Host Cedar did not invite."); eq(#sent(),1)
    eq(M.invite.pending,nil); eq(H.accepts(),0); no(M.error)
end)

for _,why in ipairs({"instance","leader","manual"}) do
    test("Blind live: leave guard "..why.." is preserved",function()
        local N,M=setup(); sample(3,"ABC"); yes(M.hopAny())
        if why=="manual" then M.setAutoHop(false) end
        join(N); sample(3,"DEF"); H.advance(5)
        if why=="instance" then H.instance(true)
        elseif why=="leader" then H.units().party1.leader=false end
        H.advance(31); eq(H.leaves(),0); no(M.error)
    end)
end

test("Blind live: B10 ends an existing layered round at trust transition with exact message",function()
    local N=H.hopLoad(); H.hopClick(N); H.deliver("WHO_LIST_UPDATE")
    yes(N.Main.hopAnyState.round); local before=#sent()
    SlashCmdList.LAYERENEMIES("blind on")
    eq(N.Main.hopAnyState.round,nil,"no wait for another send tick")
    local found=false
    for _,text in ipairs(H.log()) do if text=="LayerEnemies: layer IDs became unreadable; click Hop (blind)" then found=true end end
    yes(found); H.advance(5); eq(#sent(),before); no(N.Main.error)
end)

test("Blind live: B9 unconstrained host asks invite; named layers and same never answered",function()
    local N=H.load(); H.clock(120); SlashCmdList.LAYERENEMIES("blind on")
    H.roster({{"Host Cedar",true},{"Host Birch",true}}); H.deliver("GUILD_ROSTER_UPDATE")
    local invites={}; N.Wire.invite=function(name) invites[#invites+1]=name; return true end
    N.Main.setHost(true)
    H.deliver("CHAT_MSG_ADDON","LayerSwap","inv layer <LS 100 25.0,75.0>","WHISPER","Host Cedar")
    eq(#invites,1); H.advance(10)
    H.deliver("CHAT_MSG_GUILD","inv layer <LS 100 25.0,75.0>","Host Birch")
    eq(#invites,2)
    H.advance(61); local first=#sent()
    H.deliver("CHAT_MSG_ADDON","LayerSwap","inv layer <LS 100 want 7086-7 25.0,75.0>","WHISPER","Host Cedar")
    H.deliver("CHAT_MSG_GUILD","inv layer <LS 100 not 7086-7 25.0,75.0>","Host Birch")
    eq(#invites,2); eq(#sent(),first)
    for _,s in ipairs(sent()) do no(s.text=="same") end; no(N.Main.error)
end)
