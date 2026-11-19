-- Round-2 E2 ruling regressions. Independent wire peer; no donor code executed.
-- The peer answers H with A, but only receiving our A confirms us at its side.
local h=...
local eq,yes,no=h.eq,h.yes,h.no
local function test(name,fn) h.test("WarBoard rulings: "..name,fn) end
local ME,G="Player-123-00000001","Player-123-00000002"
local function advance(n) for _=1,n do h.advance(1) end end
local function incoming(cmd,id)
    h.deliver("BN_CHAT_MSG_ADDON","WarBoard","WBF1|"..cmd.."|5|pvp|1.6.3|3","WHISPER",id or 71)
end
local function decode(N,text)
    if text:sub(1,7)=="WBF1|D|" then
        return N.Codec.aceRead(N.Codec.inflate(N.Codec.addonDecode(text:sub(8)),4000))
    end
end
local function setup(saved,remote)
    local N=h.load(saved); N.Net.SHIP.warboard=true
    WOW_PROJECT_ID=42; GetRealmName=function() return "PvP 123" end
    UnitNameUnmodified=function() return "Hunter","Player" end
    UnitGUID=function(u) return u=="player" and ME end
    GetServerTime=function() return h.wall() end
    C_AddOns.GetAddOnMetadata=function() return "1.2.4" end
    local accounts={}
    for id=71,72 do accounts[id]={gameAccountID=id,characterName=id==71 and "Enemy Player" or "Other Player",
        realmName="123",factionName="Horde",clientProgram="WoW",isOnline=true,wowProjectID=42,
        isInCurrentRegion=true,playerGuid=id==71 and G or "Player-123-00000003"} end
    C_BattleNet.GetGameAccountInfoByID=function(id) return accounts[id] end
    N.BNet.peers=function() return {{id=71,name="Enemy Player",realm="123",faction="Horde"}} end
    local r=remote or {confirmed=false,sub=false,rejected=0}
    C_BattleNet.SendGameData=function(id,prefix,text)
        local out=h.sent(); out[#out+1]={target=id,prefix=prefix,text=text,kind="BN",at=h.clock()}
        local e=decode(N,text)
        if r.fail or (r.failD and e) then return 1 end
        if id~=71 or prefix~="WarBoard" then return 0 end
        if text:sub(1,7)=="WBF1|H|" then incoming("A")
        elseif text:sub(1,7)=="WBF1|A|" then r.confirmed=true
        elseif e then
            if not r.confirmed then r.rejected=r.rejected+1
            elseif e.t=="FBAK" then r.sub=true
            elseif e.t=="FBUN" and not r.drop then r.sub=false end
        end
        return 0
    end
    local function hello()
        incoming("H")
        if h.loaded().WarBoard then r.confirmed=true end -- the real addon's answer
    end
    local function count(kind,from)
        local out={}
        for i=(from or 0)+1,#h.sent() do local s=h.sent()[i]
            if s.prefix=="WarBoard" then local e=decode(N,s.text); local k=e and e.t or s.text:sub(6,6)
                if not kind or k==kind then out[#out+1]=s end
            end
        end
        return #out,out
    end
    local function position(listed,edit,id)
        id=id or 71; local a=accounts[id]
        local d={targetGuid=a.playerGuid,targetName=a.characterName,faction="Horde",rank=1,worldX=1,worldY=2,
            instanceID=1,zone="Ashenvale",subZone="Astranaar",sentAt=h.wall(),
            roster=listed and {{guid=ME,name="Hunter Player",faction="Alliance"}} or {}}
        if edit then edit(d) end
        local text="WBF1|D|"..N.Codec.addonEncode(N.Codec.deflateStored(N.Codec.aceWrite({t="FBLP",v=5,rs="pvp",d=d})))
        h.deliver("BN_CHAT_MSG_ADDON","WarBoard",text,"WHISPER",id)
        return text
    end
    return N,r,hello,count,position,accounts
end
local function stop(N,mode)
    if mode=="share" then N.Main.setShare(false)
    elseif mode=="source" then N.Net.setSwitch("warboard",false)
    elseif mode=="guild" then N.Net.setConsent("guild")
    else N.WarBoardTrack.set(false) end
end
local function debt() return #LayerEnemiesDB.warboardOwed end
local function start()
    local N,r,hello,count,pos,a=setup()
    yes(N.Find.add(N.Main.find,"Enemy Player")); hello()
    for _=1,30 do advance(1); if r.sub then break end end
    yes(r.sub,"target subscribed before stop"); eq(debt(),1)
    return N,r,hello,count,pos,a
end

for _,mode in ipairs({"share","source","guild"}) do
    test("M1 "..mode.." exhausted debt has no handshake exception",function()
        local N,r,hello,count,pos=start(); r.failD=true; stop(N,mode)
        for t=1,1800 do if t%300==0 then hello() end; advance(1) end
        eq(count("FBUN"),6); eq(debt(),1); yes(r.sub)
        local before=#h.sent()
        for t=1,7200 do if t%60==0 then hello() end; advance(1) end
        eq(count("A",before),0,"no answers after six attempts even with 120 target H")
        eq(count("H",before),0); eq(count("FBUN",before),0); eq(count("FBAK",before),0)
        eq(debt(),1)
    end)
    test("M1 "..mode.." accepted debt has no handshake exception",function()
        local N,r,hello,count,pos=start(); stop(N,mode); advance(5)
        eq(count("FBUN"),1); eq(debt(),1); no(r.sub)
        local before=#h.sent(); hello(); advance(5)
        eq(count("A",before),0,"sent-unverified is not a pending withdrawal")
        eq(count("H",before),0); eq(count("FBUN",before),0)
    end)
end

for _,donor in ipairs({true,false}) do
    local offsets=donor and {301,302,303,304,305,306,307,308,309,310,311,312,313,314,315} or {301,303,305,307,309,311,313,315}
    for _,offset in ipairs(offsets) do
        test("S1 "..(donor and "donor" or "own").." handshake offset "..offset,function()
            local N,r,hello,count,pos=start()
            h.combat(true); h.deliver("PLAYER_REGEN_DISABLED")
            if not donor then stop(N,"share") end
            h.deliver("PLAYER_LOGOUT"); local saved=LayerEnemiesDB; h.combat(false)
            N,r,hello,count,pos=setup(saved,r); h.loaded().WarBoard=donor; r.confirmed=false
            local withdrawn
            for t=1,3600 do
                -- Simulate the installed donor's outgoing H and the target's A.
                if donor and (t==3 or t%600==0) then incoming("A") end
                if t%600==offset then hello() end
                if t%15==0 and r.sub then pos(true) end
                advance(1)
                if not r.sub then withdrawn=t; break end
            end
            print("TIMING S1 "..(donor and "donor" or "own").." "..offset.." -> "..tostring(withdrawn))
            yes(withdrawn and withdrawn<=offset+3,"fresh target H must withdraw promptly, not wait another handshake")
            if donor then eq(count("H"),0); eq(count("A"),0) end
        end)
    end
end

test("S1 delayed roster cannot wipe newer unused confirmation",function()
    local N,r,hello,count,pos=start(); r.drop=true; stop(N,"share"); advance(5)
    eq(count("FBUN"),1); pos(true); advance(3); hello(); advance(1)
    local peer=N.WarBoard.state.peers[71]; local fresh=peer.proof
    yes(fresh); pos(true,function(d) d.sentAt=h.wall()-2 end)
    eq(peer.proof,fresh,"roster sent before confirmation must not wipe it")
    r.drop=false
    for t=1,65 do if t%15==0 and r.sub then pos(true) end; advance(1) end
    eq(count("FBUN"),2,"later listed rosters cannot repeatedly wipe an unused confirmation")
    no(r.sub)
end)

for _,unsafe in ipairs({"safe","combat","instance"}) do
    test("S2 donor A only "..unsafe.." cannot confirm or clear debt",function()
        local N,r,hello,count,pos=setup({warboardOwed={G}})
        h.loaded().WarBoard=true; r.sub=true; r.confirmed=false
        if unsafe~="safe" then
            -- Establish receive identity, then age that proof out before A.
            hello(); h.combat(unsafe=="combat"); h.instance(unsafe=="instance")
            advance(1300); r.confirmed=false
        end
        incoming("A") -- answer to the installed donor's H, NOT its answer to target H
        advance(5); h.combat(false); h.instance(false)
        advance(901)
        eq(count("FBUN"),0,"A alone cannot authorize a withdrawal")
        eq(debt(),1,"A-only traffic plus silence cannot falsely settle")
        yes(r.sub); eq(r.rejected,0); eq(count("H"),0); eq(count("A"),0)
        hello(); advance(5); eq(count("FBUN"),1); no(r.sub)
    end)
end

test("S2 donor unsafe H must still be under twenty minutes old",function()
    local N,r,hello,count,pos=start(); stop(N,"share")
    h.loaded().WarBoard=true; h.combat(true); h.deliver("PLAYER_REGEN_DISABLED")
    hello(); advance(1300); h.combat(false); advance(5)
    eq(count("FBUN"),0,"unsafe H receipt must not become fresh merely on safe resumption")
    eq(debt(),1); hello(); advance(5); eq(count("FBUN"),1); no(r.sub)
end)

test("S2 donor waits for target H then withdraws without rejected 3s send",function()
    local N,r,hello,count,pos=setup({warboardOwed={G}})
    h.loaded().WarBoard=true; r.sub=true
    advance(2); incoming("A"); advance(295)
    eq(count("FBUN"),0,"no withdrawal at 3 seconds from an A-only exchange")
    hello(); advance(5)
    eq(count("FBUN"),1); eq(r.rejected,0); no(r.sub); eq(debt(),1)
    advance(901); eq(debt(),0)
end)

test("S2 donor still remembering an established exchange withdraws promptly",function()
    local N,r,hello,count,pos=start(); local before=#h.sent()
    h.loaded().WarBoard=true; stop(N,"track"); advance(5)
    eq(count("FBUN",before),1); no(r.sub); eq(r.rejected,0)
    eq(count("H",before),0); eq(count("A",before),0)
end)

for _,mode in ipairs({"share","source","guild"}) do
    test("S3 "..mode.." six attempts reopen once per login and M1 then closes",function()
        local N,r,hello,count,pos=start(); stop(N,mode); r.failD=true
        for login=1,2 do
            for t=1,1800 do if t%300==0 then hello() end; advance(1) end
            eq(count("FBUN"),6,"each login permits six actual attempts")
            eq(LayerEnemiesDB.warboardOwed.attempts[G],6); eq(debt(),1)
            local _,out=count("FBUN")
            for i=2,#out do yes(out[i].at-out[i-1].at>=60) end
            yes(out[4].at-out[1].at>=600,"no fourth attempt in first window")
            N.WarBoardTrack.set(true); N.WarBoardTrack.set(false)
            local before=#h.sent()
            for t=1,7200 do if t%60==0 then hello() end; advance(1) end
            if login==2 then eq(count(nil,before),0,"exhaustion closes exception for two hours on next login") end
            eq(debt(),1); yes(r.sub)
            h.deliver("PLAYER_LOGOUT"); local saved=LayerEnemiesDB
            N,r,hello,count,pos=setup(saved,r); stop(N,mode)
            eq(LayerEnemiesDB.warboardOwed.attempts[G],0,"login resets bounded per-character attempts")
        end
        r.failD=false; hello(); advance(5)
        eq(count("FBUN"),1,"working client withdraws after next login")
        no(r.sub); eq(debt(),1); advance(901); eq(debt(),0)
    end)
end

test("S3 live proof cannot exceed six attempts within the same login",function()
    local N,r,hello,count,pos=start(); r.failD=true; stop(N,"share")
    for t=1,1300 do if t%300==0 then hello() end; advance(1) end
    eq(count("FBUN"),6)
    h.loaded().WarBoard=true; hello(); advance(10)
    eq(count("FBUN"),6,"new donor-owned proof cannot reopen the spent login allowance")
    yes(r.sub); eq(debt(),1)
end)

for _,unsafe in ipairs({"combat","instance"}) do
    test("N2 "..unsafe.." roster listing us survives long source-off wait",function()
        local N,r,hello,count,pos=start(); r.drop=true; stop(N,"source"); advance(5)
        eq(count("FBUN"),1); eq(debt(),1); yes(r.sub)
        local before=#h.sent(); local scans=0
        local account=C_BattleNet.GetGameAccountInfoByID
        C_BattleNet.GetGameAccountInfoByID=function(...) scans=scans+1; return account(...) end
        h.combat(unsafe=="combat"); h.instance(unsafe=="instance"); advance(3)
        pos(true); advance(1000)
        eq(scans,0,"unsafe receive does not scan accounts"); eq(count(nil,before),0)
        h.loaded().WarBoard=true; h.combat(false); h.instance(false); advance(5)
        eq(debt(),1,"a listed roster heard while unsafe vetoes silence settlement")
        eq(count("FBUN",before),0,"old confirmation is invalidated, not used to retry")
        hello(); r.drop=false; advance(5); eq(count("FBUN",before),1); no(r.sub)
        pos(false); eq(debt(),0)
    end)
    test("N2 "..unsafe.." excluding multipart roster is validated at receipt time",function()
        local N,r,hello,count,pos=start(); stop(N,"source"); advance(5)
        eq(count("FBUN"),1); eq(debt(),1)
        -- Produce a valid frame without delivering it, then deliver only pieces while unsafe.
        local deliver=h.deliver; local text
        h.deliver=function(_,_,s) text=s end; pos(false); h.deliver=deliver
        h.combat(unsafe=="combat"); h.instance(unsafe=="instance")
        local encoded=text:sub(8); local mid=math.floor(#encoded/2)
        h.deliver("BN_CHAT_MSG_ADDON","WarBoard","WBF1|F|abc|1|2|"..encoded:sub(1,mid),"WHISPER",71)
        h.deliver("BN_CHAT_MSG_ADDON","WarBoard","WBF1|F|abc|2|2|"..encoded:sub(mid+1),"WHISPER",71)
        advance(300); eq(debt(),1)
        h.combat(false); h.instance(false); advance(1)
        eq(debt(),0,"held valid roster settles before the silence deadline despite >121s wait")
    end)
end

for _,bytes in ipairs({false,true}) do
    test("N2 deferred inbox "..(bytes and "byte" or "frame").." bound vetoes lost input silence",function()
        local N,r,hello,count,pos=start(); r.drop=true; stop(N,"source"); advance(5)
        local record=N.WarBoardTrack.owedAccount(71); yes(record.accepted)
        h.combat(true)
        local text="WBF1|D|"..string.rep("x",bytes and 3993 or 1)
        for i=1,200 do
            h.deliver("BN_CHAT_MSG_ADDON","WarBoard",text,"WHISPER",71)
            if i==100 then advance(61) end
        end
        local st=N.WarBoard.state; yes(st.deferred)
        yes(#st.deferred<=128); yes(st.deferredBytes<=262144)
        no(record.accepted,"overflow must not retain an unprovable silence fallback")
        eq(count("FBUN"),1); eq(debt(),1)
    end)
end

test("N2 deferred inbox remains held during clock rollback",function()
    local N,r,hello,count,pos=start(); stop(N,"source"); advance(5)
    h.combat(true); advance(10); pos(false,function(d) d.sentAt=h.wall()-5 end)
    local received=h.clock(); h.combat(false); h.clock(received-3)
    incoming("A")
    eq(debt(),1,"rollback must not drain a queued roster before the ingress clock guard")
    h.clock(received); N.WarBoard.tick(N.WarBoard.state,N.Adapters.warboardContext())
    eq(debt(),0)
end)

test("N2 deferred roster cannot settle after current GUID changes",function()
    local N,r,hello,count,pos,a=start(); stop(N,"source"); advance(5)
    h.combat(true); advance(1); pos(false)
    a[71].playerGuid="Player-123-000000FF"
    h.combat(false); advance(1); eq(debt(),1,"queued evidence must match the live target GUID")
end)

test("N1 genuine recent confirmation permits FBAK when sharing resumes",function()
    local N,r,hello,count,pos=setup({tracked={"Enemy Player"},warboardOwed={G}}, {confirmed=true,sub=true,rejected=0})
    stop(N,"share"); advance(1000); eq(debt(),0); no(r.sub)
    local before=#h.sent(); N.Main.setShare(true); advance(2)
    eq(count("FBAK",before),1,"recent real confirmation is reusable, not cleanup-only consent")
    eq(count("H",before),0,"fresh ask need not wait for a new H while confirmation is under 20 min")
end)

local function parts(pos,listed,edit)
    local deliver=h.deliver; local text
    h.deliver=function(_,_,s) text=s end; pos(listed,edit); h.deliver=deliver
    local encoded=text:sub(8); local mid=math.floor(#encoded/2)
    return "WBF1|F|abc|1|2|"..encoded:sub(1,mid),"WBF1|F|abc|2|2|"..encoded:sub(mid+1)
end
local function receive(text) h.deliver("BN_CHAT_MSG_ADDON","WarBoard",text,"WHISPER",71) end
for _,unsafe in ipairs({"combat","instance"}) do
    test("delta cleanup-only partial starts in "..unsafe.." and finishes safe",function()
        local N,r,hello,count,pos=start(); stop(N,"track"); advance(5)
        eq(count("FBUN"),1); eq(debt(),1)
        local first,last=parts(pos,false)
        h.combat(unsafe=="combat"); h.instance(unsafe=="instance"); receive(first)
        eq(#N.WarBoard.state.deferred,1,"first chunk entered debt inbox")
        h.combat(false); h.instance(false)
        receive(last) -- drains first chunk before assembling the live final chunk
        eq(debt(),0,"valid complete roster still settles cleanup")
        no(N.Find.rows(N.Main.find,h.clock(),100)[1].reported,"queued partial never becomes delayed Find evidence")
        eq(count("FBUN"),1)
    end)
end

for _,field in ipairs({"characterName","realmName"}) do
    test("delta identity change "..field.." discards queued partial before completion",function()
        local N,r,hello,count,pos,a=start(); stop(N,"track"); advance(5)
        local first,last=parts(pos,false)
        h.combat(true); receive(first); eq(#N.WarBoard.state.deferred,1)
        h.combat(false); N.WarBoard.tick(N.WarBoard.state,N.Adapters.warboardContext())
        yes(N.WarBoard.state.parts["71:abc"],"queued partial actually drained into assembly")
        a[71][field]=field=="characterName" and "Other Player" or "456"
        incoming("A") -- new identity is fully admitted, not rejected by old-peer gate
        eq(N.WarBoard.state.peers[71].key,N.Invite.key(N.OpenMap.bnName(a[71].characterName,a[71].realmName)))
        local decoded=0; local decode=N.WarBoard.decode
        N.WarBoard.decode=function(...) decoded=decoded+1; return decode(...) end
        receive(last)
        eq(decoded,0,"old character chunks must never complete under new identity")
        eq(N.WarBoard.state.parts["71:abc"],nil,"mismatched assembly is discarded")
        eq(debt(),1)
        -- A new complete frame for the current character still works.
        yes(N.Find.add(N.Main.find,a[71].characterName..(field=="realmName" and "-456" or "")))
        pos(false); eq(decoded,1)
    end)
end

for _,multipart in ipairs({false,true}) do
    test("delta stale "..(multipart and "multipart" or "direct").." roster preserves accepted withdrawal",function()
        local N,r,hello,count,pos=start(); stop(N,"track"); advance(5)
        local record=N.WarBoardTrack.owedAccount(71); local accepted=record.accepted
        yes(accepted); eq(count("FBUN"),1)
        h.combat(true)
        if multipart then
            local first,last=parts(pos,true,function(d) d.sentAt=h.wall()-10 end)
            receive(first); receive(last); eq(#N.WarBoard.state.deferred,2)
        else pos(true,function(d) d.sentAt=h.wall()-10 end); eq(#N.WarBoard.state.deferred,1) end
        h.combat(false); advance(1)
        eq(record.accepted,accepted,"old roster cannot erase newer accepted FBUN")
        advance(65); eq(count("FBUN"),1,"no extra withdrawal from a stale deferred roster")
        no(N.Find.rows(N.Main.find,h.clock(),100)[1].reported)
        advance(900); eq(debt(),0,"original silence deadline remains usable")
    end)
end

test("delta incomplete cleanup keeps acceptance until original assembly expiry",function()
    local N,r,hello,count,pos=start(); stop(N,"track"); advance(5)
    local record=N.WarBoardTrack.owedAccount(71); local accepted=record.accepted; yes(accepted)
    local first=parts(pos,true); h.combat(true); receive(first); h.combat(false)
    N.WarBoard.tick(N.WarBoard.state,N.Adapters.warboardContext())
    eq(record.accepted,accepted,"an admitted partial is not yet lost evidence")
    advance(89); eq(record.accepted,accepted)
    advance(1); no(record.accepted,"expired incomplete roster retains uncertainty")
    eq(N.WarBoard.state.parts["71:abc"],nil)
end)

test("N1 README states revised confirmation and retry rules",function()
    local f=assert(io.open("README.md")); local s=f:read("*a"):gsub("%s+"," "); f:close()
    for _,phrase in ipairs({"A genuine confirmation under **20 minutes** old can authorize a new FBAK",
        "only while a withdrawal needs a handshake", "Each login/reload reopens six attempts",
        "only from an observed valid **H from the target**", "bounded inbox (128 frames, 256 KiB total)"}) do
        yes(s:find(phrase,1,true),phrase)
    end
    no(s:find("attempts per debt over its life",1,true))
end)
