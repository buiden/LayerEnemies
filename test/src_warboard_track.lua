-- E2 protocol fixtures, independently constructed from audit-warboard.md.
local h=...
local eq,yes,no=h.eq,h.yes,h.no
local function test(name,fn) h.test("WarBoard track: "..name,fn) end
local function advance(n) for _=1,n do h.advance(1) end end
local function setup(names)
    local N=h.load(); N.Net.SHIP.warboard=true
    _G.WOW_PROJECT_ID=42
    _G.GetRealmName=function() return "PvP 123" end
    _G.UnitNameUnmodified=function() return "Hunter","Player" end
    _G.UnitGUID=function(unit) return unit=="player" and "Player-123-00000001" or nil end
    C_AddOns.GetAddOnMetadata=function() return "1.1.0" end
    local accounts={}
    for i,name in ipairs(names or {"Enemy Player"}) do
        accounts[70+i]={gameAccountID=70+i,characterName=name,realmName="123",factionName="Horde",clientProgram="WoW",
            isOnline=true,wowProjectID=42,isInCurrentRegion=true,playerGuid="Player-123-"..string.format("%08X",i+1)}
        yes(N.Find.add(N.Main.find,name))
    end
    C_BattleNet.GetGameAccountInfoByID=function(id) return accounts[id] end
    N.BNet.peers=function() return {} end -- isolate approved tracking from discovery
    return N,accounts
end
local function confirm(id,cmd)
    h.deliver("BN_CHAT_MSG_ADDON","WarBoard","WBF1|"..(cmd or "A").."|5|pvp|1.6.3|3","WHISPER",id or 71)
end
local function frames(N,kind)
    local out={}
    for _,s in ipairs(h.sent()) do
        if s.prefix=="WarBoard" and s.text:sub(1,7)=="WBF1|D|" then
            local raw=N.Codec.addonDecode(s.text:sub(8)); local plain=raw and N.Codec.inflate(raw,4000)
            local e=plain and N.Codec.aceRead(plain)
            yes(e,"application frame decodes"); eq(s.kind,"BN"); yes(e.t=="FBAK" or e.t=="FBUN")
            if not kind or e.t==kind then out[#out+1]={e=e,send=s} end
        end
    end
    return out
end
local function tick(N) N.WarBoard.tick(N.WarBoard.state,N.Adapters.warboardContext()) end
local function expected(N,kind,at,target)
    local d={targetGuid=target.playerGuid,hunterGuid="Player-123-00000001",hunterName="Hunter Player",
        hunterFaction="Alliance",faction="Alliance",sentAt=at}
    if kind=="FBAK" then d.targetName=target.characterName end
    return {t=kind,v=5,rs="pvp",av="LayerEnemies/1.1.0",senderName="Hunter Player",d=d}
end
local function same(a,b)
    if type(a)~="table" then eq(a,b); return end
    eq(type(b),"table"); for k,v in pairs(a) do same(v,b[k]) end
    for k in pairs(b) do yes(a[k]~=nil,"no extra wire field "..tostring(k)) end
end

test("exact FBAK envelope targets a confirmed Find player's live GUID",function()
    local N,accounts=setup(); confirm(); local at=h.wall(); tick(N)
    yes(N.WarBoardTrack,"module loaded"); yes(N.Adapters.warboardContext(),"context"); yes(N.Adapters.warboardSelf(),"self identity"); yes(N.BNet.who(71,true),"target identity"); yes(N.WarBoard.state.peers[71],"confirmed")
    eq(N.BNet.queued(),1,"tracking request queued, not directly sent")
    eq(#frames(N),0); advance(1)
    local out=frames(N,"FBAK"); eq(#out,1,"one FBAK on base feature path")
    eq(out[1].send.target,71); same(expected(N,"FBAK",at,accounts[71]),out[1].e)
    local plain="^1^T^St^SFBAK^Sv^N5^Srs^Spvp^Sav^SLayerEnemies/1.1.0^SsenderName^SHunter~`Player^Sd^T"
        .."^StargetGuid^SPlayer-123-00000002^StargetName^SEnemy~`Player^ShunterGuid^SPlayer-123-00000001"
        .."^ShunterName^SHunter~`Player^ShunterFaction^SAlliance^Sfaction^SAlliance^SsentAt^N"..at.."^t^t^^"
    local want="WBF1|D|"..N.Codec.addonEncode(N.Codec.deflateStored(plain))
    eq(out[1].send.text,want,"exact independent wire frame")
end)

local function position(N,account,at)
    local d={targetGuid=account.playerGuid,targetName=account.characterName,faction="Horde",rank=1,
        worldX=1,worldY=2,instanceID=1,zone="Ashenvale",subZone="Astranaar",sentAt=at or h.wall(),
        roster={{guid="Player-123-00000001",name="Hunter Player",faction="Alliance"}}}
    local e={t="FBLP",v=5,rs="pvp",d=d}
    h.deliver("BN_CHAT_MSG_ADDON","WarBoard","WBF1|D|"..N.Codec.addonEncode(N.Codec.deflateStored(N.Codec.aceWrite(e))),"WHISPER",account.gameAccountID)
end
local function names(n)
    local out={}; for i=1,n do out[i]="Enemy "..string.char(64+i) end; return out
end
local function many(n)
    local N,a=setup(names(n)); for id in pairs(a) do confirm(id) end; return N,a
end
local function stop(N,mode)
    if mode=="remove" then N.Find.remove(N.Main.find,"Enemy Player")
    elseif mode=="clear" then N.Find.remove(N.Main.find)
    elseif mode=="track" then SlashCmdList.LAYERENEMIES("warboard track off")
    elseif mode=="share" then N.Main.setShare(false)
    elseif mode=="guild" then N.Net.setConsent("guild")
    elseif mode=="source" then N.Net.setSwitch("warboard",false)
    elseif mode=="combat" then h.combat(true); h.deliver("PLAYER_REGEN_DISABLED")
    elseif mode=="instance" then h.instance(true); h.deliver("PLAYER_ENTERING_WORLD",false,false)
    elseif mode=="logout" then h.deliver("PLAYER_LOGOUT") end
end
local function resume(N,mode)
    if mode=="remove" or mode=="clear" then yes(N.Find.add(N.Main.find,"Enemy Player"))
    elseif mode=="track" then SlashCmdList.LAYERENEMIES("warboard track on")
    elseif mode=="share" then N.Main.setShare(true)
    elseif mode=="guild" then N.Net.setConsent("public")
    elseif mode=="source" then N.Net.setSwitch("warboard",true)
    elseif mode=="combat" then h.combat(false)
    elseif mode=="instance" then h.instance(false) end
end

test("only own Find names, never Watch-only or untracked targets",function()
    for _,watch in ipairs({false,true}) do
        local N=setup(); N.Find.remove(N.Main.find)
        if watch then N.Watch.match=function() return true,true,true,{"Guildmate"} end end
        confirm(); advance(120); eq(#frames(N),0); eq(N.BNet.queued(),0)
    end
end)

test("confirmed A only, not unconfirmed or hello-only, expired, mismatched peer",function()
    for _,mode in ipairs({"none","H","expired","identity","rules","faction"}) do
        local N,a=setup()
        if mode=="H" then confirm(71,"H") elseif mode~="none" then confirm() end
        if mode=="expired" then h.clock(h.clock()+1200); tick(N); eq(N.BNet.queued(),0,"expiry boundary")
        elseif mode=="identity" then a[71].characterName="Other Player"; yes(N.Find.add(N.Main.find,"Other Player"))
        elseif mode=="rules" then N.WarBoard.state.peers[71].rs="normal"
        elseif mode=="faction" then a[71].factionName="Alliance" end
        advance(2); eq(#frames(N,"FBAK"),0,mode)
    end
end)

test("missing secret malformed GUID and ambiguous account matches fail silent",function()
    for _,v in ipairs({false,h.secret,"","invented","Player-1-nope",string.rep("x",81)}) do
        local N,a=setup(); confirm(); a[71].playerGuid=v; advance(2); eq(#frames(N),0)
    end
    local N,a=setup(); confirm(); a[71].playerGuid=nil; advance(2); eq(#frames(N),0)
    N,a=setup(); a[72]={}; for k,v in pairs(a[71]) do a[72][k]=v end
    a[72].gameAccountID=72; a[72].playerGuid="Player-123-FFFFFFFF"; confirm(71); confirm(72)
    advance(2); eq(#frames(N),0,"ambiguous name has no target")
end)

test("own identity and ruleset must be readable, never borrow a donor identity",function()
    for _,mode in ipairs({"guid","name","version","rules"}) do
        local N=setup(); confirm()
        if mode=="guid" then UnitGUID=function() return h.secret end
        elseif mode=="name" then UnitNameUnmodified=function() return h.secret end
        elseif mode=="version" then C_AddOns.GetAddOnMetadata=function() return nil end
        else GetRealmName=function() return "123" end end
        advance(2); eq(#frames(N),0,mode)
    end
end)

test("two admitted and attempted per rolling minute, twenty names fair and bounded",function()
    local N,a=many(20); tick(N); eq(N.BNet.queued(),2,"own admission cap")
    advance(60); eq(#frames(N,"FBAK"),2,"rolling minute")
    advance(600)
    local seen={}; local out=frames(N,"FBAK")
    for _,r in ipairs(out) do
        seen[r.e.d.targetGuid]=true
        local count=0
        for _,other in ipairs(out) do if other.send.at>r.send.at-60 and other.send.at<=r.send.at then count=count+1 end end
        yes(count<=2,"actual rolling cap")
    end
    eq(N.Safe.count(seen),20,"new targets before renewal, no starvation")
    no(N.Find.add(N.Main.find,"Enemy Extra")); yes(N.WarBoardTrack.size()<=20)
end)

test("per-name forty-five seconds at admission and actual dispatch survives removal and toggles",function()
    local N=setup(); confirm(); local start=h.clock(); tick(N); advance(1); eq(#frames(N,"FBAK"),1)
    SlashCmdList.LAYERENEMIES("warboard track off"); SlashCmdList.LAYERENEMIES("warboard track on")
    N.Find.remove(N.Main.find); N.Find.add(N.Main.find,"Enemy Player")
    advance(43); eq(#frames(N,"FBAK"),1)
    -- The actual-send gap also gates enqueue; its timer then waits one second.
    advance(2); eq(#frames(N,"FBAK"),1); eq(N.BNet.queued(),1)
    advance(1); eq(#frames(N,"FBAK"),2)
    local out=frames(N,"FBAK"); yes(out[2].send.at-out[1].send.at>=45)
end)

test("fresh FBLP suppresses renewal, stale forty-five to three hundred renews only",function()
    local N,a=setup(); confirm(); tick(N); advance(1)
    position(N,a[71]); local first=h.clock()
    for _=1,4 do advance(15); position(N,a[71]) end
    eq(#frames(N,"FBAK"),1,"fresh position needs no renewal")
    advance(44); eq(#frames(N,"FBAK"),1); eq(N.BNet.queued(),0,"renewal admission boundary")
    advance(2); eq(#frames(N,"FBAK"),2,"stale 45 renews")
    h.clock(first+400); h.wall(h.wall()+400); tick(N); advance(2)
    eq(#frames(N,"FBAK"),2,"location older than 300 does not create renewal authority")
end)

for _,mode in ipairs({"remove","clear","track","share","guild","source","combat","instance","logout"}) do
    test(mode.." cancels queued requests synchronously, quick resume cannot revive",function()
        local N=setup(); confirm(); tick(N); eq(N.BNet.queued(),1)
        stop(N,mode); eq(N.BNet.queued(),0,"immediate drop "..mode)
        resume(N,mode); advance(3); eq(#frames(N,"FBAK"),0,"old queue remains dead")
    end)
    test(mode.." stops active requests; cancellation respects privacy and safety",function()
        local N,a=setup(); confirm(); tick(N); advance(1); eq(#frames(N,"FBAK"),1)
        stop(N,mode); advance(3); eq(#frames(N,"FBAK"),1)
        if mode=="remove" or mode=="clear" or mode=="track" then
            local out=frames(N,"FBUN"); eq(#out,1,"polite cancel"); same(expected(N,"FBUN",out[1].e.d.sentAt,a[71]),out[1].e)
        else
            eq(#frames(N,"FBUN"),0,"no bypass for cancel")
            resume(N,mode); advance(3)
            eq(#frames(N,"FBUN"),mode=="logout" and 0 or 1,"session cleanup after safe resume")
        end
    end)
end

test("dispatch rechecks name GUID faction ruleset tracking and ignored target",function()
    for _,mode in ipairs({"guid","name","faction","rules","ignored","own"}) do
        local N,a=setup(); confirm(); tick(N); eq(N.BNet.queued(),1)
        if mode=="guid" then a[71].playerGuid="Player-123-FFFFFFFF"
        elseif mode=="name" then a[71].characterName="Other Player"
        elseif mode=="faction" then a[71].factionName="Alliance"
        elseif mode=="rules" then GetRealmName=function() return "PvE 123" end
        elseif mode=="own" then UnitGUID=function() return "Player-123-FFFFFFFF" end
        else N.Adapters.ignored=function() return true end end
        h.clock(h.clock()+1); N.BNet.pump(h.clock()) -- dispatch before the source tick can retire it
        eq(#frames(N,"FBAK"),0,mode)
    end
end)

test("saved boolean switch defaults on, status reports it, names never newly saved",function()
    local N=setup(); yes(LayerEnemiesDB.warboardTrack)
    SlashCmdList.LAYERENEMIES("warboard track off"); eq(LayerEnemiesDB.warboardTrack,false)
    local save=LayerEnemiesDB; N.Main.started=false; N.Main.start(); eq(LayerEnemiesDB.warboardTrack,false)
    local out={}; N.Main.say=function(s) out[#out+1]=s end
    SlashCmdList.LAYERENEMIES("net warboard"); yes(table.concat(out,"\n"):find("tracking: off",1,true))
    SlashCmdList.LAYERENEMIES("warboard track on"); eq(LayerEnemiesDB.warboardTrack,true)
    local before=N.Codec.aceWrite(LayerEnemiesDB); confirm(); tick(N); advance(2)
    eq(N.Codec.aceWrite(LayerEnemiesDB),before,"only configured boolean and existing Find list saved")
    for k,v in pairs(LayerEnemiesDB) do if not save[k] and k~="warboardTrack" then no(type(v)=="table","no new identity table") end end
end)

test("stand-down stops requests while owed answers still pass",function()
    local N=setup(); h.loaded().WarBoard=true; confirm(71,"H"); advance(3)
    eq(#frames(N),0); local n=0
    for _,s in ipairs(h.sent()) do if s.prefix=="WarBoard" and s.text:match("^WBF1|A|") then n=n+1 end end
    eq(n,1)
end)

test("queue share leaves owed A first and H works beside tracking",function()
    local N,a=many(4); tick(N); eq(N.BNet.queued(),2)
    confirm(71,"H"); advance(1)
    local out={}; for _,s in ipairs(h.sent()) do if s.prefix=="WarBoard" then out[#out+1]=s end end
    eq(out[1].text:sub(1,7),"WBF1|A|","owed first")
    N.BNet.peers=function() return {{id=74,faction="Horde"}} end; N.WarBoard.state.scan=nil
    advance(10); local hello=false
    for _,s in ipairs(h.sent()) do if s.prefix=="WarBoard" and s.text:match("^WBF1|H|") then hello=true end end
    yes(hello,"discovery still gets through"); eq(#frames(N,"FBAK"),2)
end)

test("shared delay cannot burst two cohorts, queue share and failed attempts still charged",function()
    local N,a=many(6); yes(N.Sources.register{name="alpha",prefixes={"AlphaTest"}})
    for _=1,30 do yes(N.BNet.send("alpha",71,"AlphaTest","load","own")) end
    advance(30); local count=0; for _,s in ipairs(h.sent()) do if s.prefix=="AlphaTest" then count=count+1 end end
    eq(count,30); tick(N)
    advance(30); eq(#frames(N,"FBAK"),0)
    advance(6); eq(#frames(N,"FBAK"),2)
    advance(24); tick(N); advance(10); eq(#frames(N,"FBAK"),2,"no second dispatch cohort before 60")
end)

test("positions use existing honest Find path with age, no new guild relay",function()
    local N,a=setup(); confirm(); tick(N); advance(1); local before=#h.sent(); position(N,a[71],h.wall()-12)
    local rows=N.Find.rows(N.Main.find,h.clock(),100)
    local r=rows[1]; yes(r.reported); eq(r.evidenceKind,"self"); eq(r.source,"warboard")
    yes(r.detail:find("own position",1,true)); eq(r.pos,"enemy"); yes(h.clock()-r.at>=12); no(r.canAsk)
    advance(2)
    for i=before+1,#h.sent() do no(h.sent()[i].prefix=="WarBoard" and h.sent()[i].kind~="BN") end
    no(N.Find.alert(N.Main.find,r,h.clock()))
end)

test("rollback never reopens request allowance",function()
    local N=setup(); confirm(); tick(N); advance(1); eq(#frames(N,"FBAK"),1)
    h.clock(h.clock()-100); tick(N); advance(2); eq(#frames(N,"FBAK"),1)
end)

for _,mode in ipairs({"share","guild","source","combat","instance"}) do
    test(mode.." active quick off-on keeps the cancellation obligation",function()
        local N=setup(); confirm(); tick(N); advance(1)
        stop(N,mode); resume(N,mode); advance(3)
        eq(#frames(N,"FBUN"),1); eq(#frames(N,"FBAK"),1)
    end)
end

test("queued attempt forty-five-second admission bound survives unsent cancellation",function()
    local N=setup(); confirm(); local start=h.clock(); tick(N); eq(N.BNet.queued(),1)
    N.Find.remove(N.Main.find); N.Find.add(N.Main.find,"Enemy Player")
    h.clock(start+44); tick(N); eq(N.BNet.queued(),0)
    h.clock(start+45); tick(N); eq(N.BNet.queued(),1)
end)

test("cleanup bounded to two per minute and twenty retained obligations",function()
    local N,a=many(20); advance(610); eq(N.Safe.count(a),20)
    for id in pairs(a) do confirm(id) end
    N.Find.remove(N.Main.find); tick(N); local at=h.clock()
    advance(60); eq(#frames(N,"FBUN"),2)
    -- New eligible names cannot displace unsent cleanup; total state stays bounded.
    for i=1,20 do
        local id=100+i; a[id]={}; for k,v in pairs(a[71]) do a[id][k]=v end
        a[id].gameAccountID=id; a[id].characterName="Other "..string.char(64+i); a[id].playerGuid="Player-123-"..string.format("%08X",100+i)
        yes(N.Find.add(N.Main.find,a[id].characterName)); confirm(id)
    end
    tick(N); yes(N.WarBoardTrack.size()<=20)
    local out=frames(N,"FBUN")
    for _,r in ipairs(out) do yes(r.send.at>=at) end
end)

test("missing own identity after enqueue drops request and client refusal spends caps",function()
    local N=setup(); confirm(); tick(N); UnitNameUnmodified=function() return nil end
    advance(2); eq(#frames(N),0)
    N=setup(); confirm(); local attempted=0
    C_BattleNet.SendGameData=function() attempted=attempted+1; return false end
    advance(44); eq(attempted,1); advance(4); eq(attempted,2); advance(10); eq(attempted,2)
end)

test("confirmation cannot be revived by H after old A expired",function()
    local N=setup(); confirm(); h.clock(h.clock()+1200); confirm(71,"H"); advance(3)
    eq(#frames(N,"FBAK"),0)
end)

test("dispatch rollback after a later source tick stays silent",function()
    local N=setup(); confirm(); tick(N); local start=h.clock(); eq(N.BNet.queued(),1)
    h.clock(start+20); tick(N)
    h.clock(start+1); N.BNet.pump(h.clock()); eq(#frames(N,"FBAK"),0)
end)

test("tagged cancellation preserves another target and an owed answer",function()
    local N,a=many(2); tick(N); eq(N.BNet.queued(),2); confirm(72,"H"); eq(N.BNet.queued(),3)
    N.Find.remove(N.Main.find,"Enemy A"); eq(N.BNet.queued(),2)
    advance(1); local last=h.sent()[#h.sent()]; eq(last.text:sub(1,7),"WBF1|A|")
    advance(1); local out=frames(N,"FBAK"); eq(#out,1); eq(out[1].send.target,72)
end)

test("README tracking send table precedes exact effect and cancellation limitation",function()
    local f=assert(io.open("README.md")); local text=f:read("*a"); f:close()
    local section=assert(text:find("## Unreleased - WarBoard tracking request",1,true))
    local tableAt=assert(text:find("| What LE sends |",section,true))
    local effect=assert(text:find("This asks the tracked player's WarBoard client to broadcast its position to WarBoard peers every 15 seconds, as a WarBoard hunter's client does.",1,true))
    yes(tableAt<effect); yes(text:find("broadcasting indefinitely",1,true)); yes(text:find("**FBUN**",1,true))
end)
