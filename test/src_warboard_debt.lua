-- E2 review regressions. Independent peer model from audit 6.4 / mani probes;
-- no donor code. H prompts A; an A is never spontaneously injected.
local h=...
local eq,yes,no=h.eq,h.yes,h.no
local function test(name,fn) h.test("WarBoard debt: "..name,fn) end
local ME="Player-123-00000001"
local function advance(n) for _=1,n do h.advance(1) end end
local function decode(N,text)
    if text:sub(1,7)~="WBF1|D|" then return nil end
    return N.Codec.aceRead(N.Codec.inflate(N.Codec.addonDecode(text:sub(8)),4000))
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
        isInCurrentRegion=true,playerGuid="Player-123-0000000"..(id-69)} end
    C_BattleNet.GetGameAccountInfoByID=function(id) return accounts[id] end
    N.BNet.peers=function() local out={}; for id,a in pairs(accounts) do
        if a.isOnline then out[#out+1]={id=id,name=a.characterName,realm=a.realmName,faction=a.factionName} end
    end; table.sort(out,function(a,b) return a.id<b.id end); return out end
    local r=remote or {confirmed=false,sub=false,rejected=0}
    local function incoming(cmd,id)
        h.deliver("BN_CHAT_MSG_ADDON","WarBoard","WBF1|"..cmd.."|5|pvp|1.6.3|3","WHISPER",id or 71)
    end
    local function hello(id)
        if not id or id==71 then r.hello=h.clock() end
        incoming("H",id)
        -- The installed real addon owns answers, not LE. Model its independent
        -- answer at the safe boundary; do not count it as an LE send.
        if h.loaded().WarBoard and not r.unsafe then r.confirmed=true end
    end
    C_BattleNet.SendGameData=function(id,prefix,text)
        local sent=h.sent(); sent[#sent+1]={target=id,prefix=prefix,text=text,kind="BN",at=h.clock()}
        if r.fail then return false end
        if prefix~="WarBoard" then return 0 end
        if text:sub(1,7)=="WBF1|H|" then
            incoming("A",id)
            if id==71 and (not r.hello or h.clock()-r.hello>=600) then hello(id) end
        elseif text:sub(1,7)=="WBF1|A|" then if id==71 then r.confirmed=true end
        else
            local e=decode(N,text)
            if e and id==71 then
                if not r.confirmed then r.rejected=r.rejected+1
                elseif e.t=="FBAK" then r.sub=true
                elseif e.t=="FBUN" and not r.drop then r.sub=false end
            end
        end
        return 0
    end
    local function count(kind,id,from)
        local out={}
        for i=(from or 0)+1,#h.sent() do local s=h.sent()[i]
            if s.prefix=="WarBoard" then local e=decode(N,s.text); local k=e and e.t or s.text:sub(6,6)
                if (not kind or k==kind) and (not id or s.target==id) then out[#out+1]=s end
            end
        end
        return #out,out
    end
    local function position(listed,id,edit)
        id=id or 71; local a=accounts[id]
        local d={targetGuid=a.playerGuid,targetName=a.characterName,faction="Horde",rank=1,worldX=1,worldY=2,
            instanceID=1,zone="Ashenvale",subZone="Astranaar",sentAt=h.wall(),roster=listed and {{guid=ME,name="Hunter Player",faction="Alliance"}} or {}}
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
    elseif mode=="donor" then h.loaded().WarBoard=true
    else N.WarBoardTrack.set(false) end
end
local function start()
    local N,r,hello,count,pos,a=setup()
    yes(N.Find.add(N.Main.find,"Enemy Player")); hello(); advance(8)
    yes(r.sub,"peer actually subscribed"); yes(count("FBAK")>0)
    pos(true); return N,r,hello,count,pos,a
end
local function debt() return #LayerEnemiesDB.warboardOwed end

for _,mode in ipairs({"share","source","guild","donor"}) do
    test("M1 "..mode.." relog settles from target H only",function()
        local N,r=start(); h.combat(true); h.deliver("PLAYER_REGEN_DISABLED"); stop(N,mode); h.deliver("PLAYER_LOGOUT")
        local saved=LayerEnemiesDB; h.combat(false)
        local hello,count,pos; N,r,hello,count,pos=setup(saved,r); if mode=="donor" then stop(N,mode) end
        for _=1,3 do hello(); advance(600) end
        yes(count("FBUN",71)>0,"withdrawal delivered after relog"); no(r.sub); eq(r.rejected,0); eq(debt(),0)
        eq(count("FBAK"),0)
        if mode=="donor" then eq(count("H"),0); eq(count("A"),0) end
        local before=#h.sent(); hello(); hello(72); advance(620)
        eq(count(nil,nil,before),0,"exception closes with debt; other accounts stay silent")
    end)
    for _,unsafe in ipairs({"combat","instance"}) do
        test("M1 "..mode.." "..unsafe.." 30 minute stop recovers",function()
            local N,r,hello,count,pos=start(); local before=#h.sent()
            r.unsafe=true
            if unsafe=="combat" then h.combat(true); h.deliver("PLAYER_REGEN_DISABLED")
            else h.instance(true); h.deliver("PLAYER_ENTERING_WORLD",false,false) end
            stop(N,mode)
            for _=1,6 do hello(); advance(300) end
            eq(count(nil,nil,before),0,"unsafe sends forbidden"); yes(r.sub)
            r.unsafe=false; h.combat(false); h.instance(false)
            if mode=="donor" then hello() end
            advance(400); yes(count("FBUN",71,before)>0); no(r.sub); eq(r.rejected,0)
            advance(901); eq(debt(),0)
        end)
    end
end
for _,mode in ipairs({"share","source","guild","track"}) do
    test("M2 "..mode.." target reload during combat reanswers latest H",function()
        local N,r,hello,count,pos=start()
        h.combat(true); h.deliver("PLAYER_REGEN_DISABLED"); stop(N,mode)
        r.confirmed=false; hello(); advance(20); h.combat(false); h.deliver("PLAYER_REGEN_ENABLED")
        advance(400); eq(r.rejected,0,"no FBUN before answering latest H"); no(r.sub); eq(count("FBUN"),1)
        eq(debt(),1,"sent unverified remains owed"); advance(901); eq(debt(),0)
    end)
end

test("M2 accepted send retained until later roster excludes hunter",function()
    local N,r,hello,count,pos=start(); stop(N,"track"); advance(5)
    eq(count("FBUN"),1); no(r.sub); eq(debt(),1)
    advance(1); pos(false); eq(debt(),0)
end)
test("M2 source off and removed Find still observes cleanup roster",function()
    local N,r,hello,count,pos=start(); stop(N,"source"); N.Find.remove(N.Main.find)
    advance(5); eq(count("FBUN"),1); eq(debt(),1)
    pos(false); eq(debt(),0); eq(#N.Find.rows(N.Main.find,h.clock(),100),0)
end)
test("M2 listed roster rehandshakes then resends lost withdrawal",function()
    local N,r,hello,count,pos=start(); r.drop=true; stop(N,"share"); advance(5)
    eq(count("FBUN"),1); eq(debt(),1); yes(r.sub)
    local before=#h.sent(); pos(true); r.drop=false
    for _=1,12 do advance(60); if not r.sub then break end end
    eq(count("FBUN"),2); yes(count("H",71,before)+count("A",71,before)>0,"fresh handshake before resend")
    no(r.sub); eq(debt(),1); advance(1); pos(false); eq(debt(),0)
end)
test("M2 missing roster silence clears only at fifteen minute boundary",function()
    local N,r,hello,count,pos=start(); stop(N,"track"); advance(5)
    local _,out=count("FBUN"); local at=out[1].at
    h.clock(at+899); N.WarBoard.tick(N.WarBoard.state,N.Adapters.warboardContext()); eq(debt(),1)
    h.clock(at+900); N.WarBoard.tick(N.WarBoard.state,N.Adapters.warboardContext()); eq(debt(),0)
end)
test("M2 stale relayed malformed or wrong account roster cannot settle",function()
    local N,r,hello,count,pos,a=start(); stop(N,"track"); advance(5)
    eq(debt(),1)
    pos(false,72,function(d) d.targetGuid=a[71].playerGuid; d.targetName=a[71].characterName end); eq(debt(),1)
    a[72].characterName=a[71].characterName; hello(72); advance(2)
    pos(false,72,function(d) d.targetGuid=a[71].playerGuid end); eq(debt(),1,"same name is not target account")
    pos(false,71,function(d) d.targetName="Relayed Player" end); eq(debt(),1,"target carrier is not necessarily subject")
    pos(false,71,function(d) d.sentAt=h.wall()-30 end); eq(debt(),1)
    pos(false,71,function(d) d.roster=nil end); eq(debt(),1)
    advance(1); pos(false); eq(debt(),0)
end)
test("S1 failed sends reopen after ten minutes three per window",function()
    local N,r,hello,count,pos=start(); r.fail=true; stop(N,"track"); advance(599)
    eq(count("FBUN"),3); eq(debt(),1); yes(r.sub)
    r.fail=false; advance(10); eq(count("FBUN"),4); no(r.sub)
    advance(901); eq(debt(),0)
end)
test("M2 login six attempt bound reopens with debt retained",function()
    local N,r,hello,count,pos=start(); r.fail=true; stop(N,"share"); advance(1300)
    eq(count("FBUN"),6); eq(debt(),1)
    r.fail=false; local saved=LayerEnemiesDB
    N,r,hello,count,pos=setup(saved,r); hello(); advance(1800)
    eq(count("FBUN"),1,"reload reopens six attempts"); eq(debt(),0); no(r.sub)
end)
test("M2 continuous listed rosters prevent quiet clearing at resend bound",function()
    local N,r,hello,count,pos=start(); r.drop=true; stop(N,"share")
    for i=1,80 do advance(60); pos(true) end
    eq(count("FBUN"),6); eq(debt(),1); yes(r.sub)
    advance(901); eq(debt(),1,"known rejected withdrawal is not silence success")
end)
test("S3 per character save waits for original hunter login",function()
    local f=assert(io.open("LayerEnemies/LayerEnemies.toc")); local toc=f:read("*a"); f:close()
    yes(toc:find("## SavedVariablesPerCharacter: LayerEnemiesDB",1,true))
    local N,r=start(); h.combat(true); h.deliver("PLAYER_LOGOUT"); local saved=LayerEnemiesDB
    N=setup(nil,r); UnitGUID=function() return "Player-123-000000AA" end; N.WarBoardTrack.set(false)
    advance(901); eq(debt(),0); yes(r.sub,"alt's own empty save cannot clear main subscription")
    local hello,count,pos; N,r,hello,count,pos=setup(saved,r); N.WarBoardTrack.set(false); hello(); advance(10)
    eq(count("FBUN"),1); no(r.sub)
end)
test("M1 exception cannot reach another account while debt remains",function()
    for _,mode in ipairs({"share","source","guild"}) do
        local N,r,hello,count,pos=start(); stop(N,mode); advance(5); eq(debt(),1)
        local before=#h.sent(); hello(72); advance(5)
        eq(count(nil,72,before),0); eq(count("FBAK",nil,before),0)
    end
end)
test("M2 latest safe H supersedes queued withdrawal and failed answer",function()
    local N,r,hello,count,pos=start(); stop(N,"share")
    N.WarBoard.tick(N.WarBoard.state,N.Adapters.warboardContext())
    yes(N.BNet.queued()>0); r.confirmed=false; hello(); r.fail=true
    advance(10); eq(count("FBUN"),0); eq(debt(),1)
    r.fail=false; advance(65); eq(count("FBUN"),1); eq(r.rejected,0); no(r.sub)
end)
test("M1 donor observes owed H during unsafe wait without LE answer",function()
    local N,r,hello,count,pos=start(); local before=#h.sent()
    h.combat(true); h.deliver("PLAYER_REGEN_DISABLED"); stop(N,"donor")
    for _=1,5 do advance(300); hello() end
    eq(count(nil,nil,before),0)
    h.combat(false); h.deliver("PLAYER_REGEN_ENABLED"); advance(5)
    eq(count("FBUN",71,before),1); no(r.sub)
    eq(count("H",nil,before),0); eq(count("A",nil,before),0)
end)
test("M1 answered H without received A does not grant normal request eligibility",function()
    local g="Player-123-00000002"
    local N,r,hello,count,pos=setup({tracked={"Enemy Player"},warboardOwed={g}})
    N.BNet.peers=function() return {} end
    hello(); h.clock(h.clock()+1); N.BNet.pump(h.clock()) -- deliver A before discovery
    advance(5); eq(count("FBUN"),1); eq(count("H"),0)
    pos(false); eq(debt(),0); advance(305)
    eq(count("FBAK"),0,"answered H alone is not a received-A confirmation")
end)
test("M1 queued handshakes stand down when real addon loads",function()
    local N,r,hello,count,pos=start(); stop(N,"share"); advance(5)
    local before=#h.sent(); pos(true); hello(); yes(N.BNet.queued()>0,"answer actually queued before donor loads")
    h.loaded().WarBoard=true; advance(5)
    eq(count("A",nil,before),0); eq(count("H",nil,before),0)
end)
test("M2 saved attempts sanitize only retained target GUIDs",function()
    local g="Player-123-00000002"
    local N=setup({warboardOwed={g,attempts={[g]=99,foreign=4}}})
    eq(LayerEnemiesDB.warboardOwed.attempts[g],0)
    eq(LayerEnemiesDB.warboardOwed.attempts.foreign,nil)
    local n=0; for _ in pairs(LayerEnemiesDB.warboardOwed.attempts) do n=n+1 end; eq(n,1)
end)
test("S2 N1 README states cleanup limitations without crash guarantee",function()
    local f=assert(io.open("README.md")); local s=f:read("*a"):gsub("%s+"," "); f:close()
    for _,phrase in ipairs({"client crash before", "no FBUN", "that character's next login", "sent, unverified", "15 minutes", "6 FBUN", "10 minutes", "debt-settlement exception", "target may keep broadcasting"}) do
        yes(s:find(phrase,1,true),phrase)
    end
    yes(s:find("The **debt-settlement exception** permits only H",1,true))
    no(s:find("a crash or logout cannot silently forget cleanup",1,true))
    no(s:find("block all sends, including owed answers",1,true))
end)
