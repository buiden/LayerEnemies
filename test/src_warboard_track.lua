-- E2 fixtures independently constructed from PLAN 8.5 / WarBoard 1.6.3 audit.
local h=...
local eq,yes,no=h.eq,h.yes,h.no
local function test(name,fn) h.test("WarBoard track: "..name,fn) end
local function advance(n) for _=1,n do h.advance(1) end end
local current
local function setup(names,saved)
    local N=h.load(saved); current=N; N.Net.SHIP.warboard=true
    _G.WOW_PROJECT_ID=42
    _G.GetRealmName=function() return "PvP 123" end
    _G.UnitNameUnmodified=function() return "Hunter","Player" end
    _G.UnitGUID=function(unit) return unit=="player" and "Player-123-00000001" or nil end
    _G.GetServerTime=function() return h.wall() end
    C_AddOns.GetAddOnMetadata=function() return "1.2.5" end
    local accounts={}
    for i,name in ipairs(names or {"Enemy Player"}) do
        accounts[70+i]={gameAccountID=70+i,characterName=name,realmName="123",factionName="Horde",clientProgram="WoW",
            isOnline=true,wowProjectID=42,isInCurrentRegion=true,playerGuid="Player-123-"..string.format("%08X",i+1)}
        if not N.Find.tracked(N.Main.find,name) then yes(N.Find.add(N.Main.find,name)) end
    end
    C_BattleNet.GetGameAccountInfoByID=function(id) return accounts[id] end
    N.BNet.peers=function() return {} end
    return N,accounts
end
-- Tracking-unit fixtures seed already-confirmed state, never an unsolicited A.
-- Real symmetric H/A exchanges and target rejection live in src_warboard_debt.lua.
local function confirm(id,cmd)
    id=id or 71
    if cmd=="H" then
        h.deliver("BN_CHAT_MSG_ADDON","WarBoard","WBF1|H|5|pvp|1.6.3|3","WHISPER",id)
    else
        local N=current
        local st=N.WarBoard.state; local who=N.BNet.who(id,true)
        st.serial=(st.serial or 0)+1
        st.peers[id]={at=h.clock(),key=N.Invite.key(N.OpenMap.bnName(who.name,who.realm)),
            faction=who.faction,rs="pvp",confirmed=true,proof=st.serial,proofAt=h.clock()}
    end
end
local function decode(N,text)
    eq(text:sub(1,7),"WBF1|D|")
    local raw=N.Codec.addonDecode(text:sub(8)); local plain=raw and N.Codec.inflate(raw,4000)
    local e=plain and N.Codec.aceRead(plain); yes(e,"our reader round trip")
    return e
end
local function frames(N,kind)
    local out={}
    for _,s in ipairs(h.sent()) do
        if s.prefix=="WarBoard" and s.text:sub(1,7)=="WBF1|D|" then
            local e=decode(N,s.text); eq(s.kind,"BN"); yes(e.t=="FBAK" or e.t=="FBUN")
            if not kind or e.t==kind then out[#out+1]={e=e,send=s} end
        end
    end
    return out
end
local function tick(N) N.WarBoard.tick(N.WarBoard.state,N.Adapters.warboardContext()) end
local function same(a,b)
    if type(a)~="table" then eq(a,b); return end
    eq(type(b),"table"); for k,v in pairs(a) do same(v,b[k]) end
    for k in pairs(b) do yes(a[k]~=nil,"no extra wire field "..tostring(k)) end
end
local function expected(kind,at,target)
    local d={targetGuid=target.playerGuid,hunterGuid="Player-123-00000001",hunterName="Hunter Player",
        hunterFaction="Alliance",faction="Alliance",sentAt=at}
    if kind=="FBAK" then d.targetName=target.characterName end
    return {t=kind,v=5,rs="pvp",av="LayerEnemies/1.2.5",senderName="Hunter Player",d=d}
end
local function position(N,account,at,guid,absent)
    local d={targetGuid=guid or account.playerGuid,targetName=account.characterName,faction="Horde",rank=1,
        worldX=1,worldY=2,instanceID=1,zone="Ashenvale",subZone="Astranaar",sentAt=at or h.wall(),
        roster=absent and {} or {{guid="Player-123-00000001",name="Hunter Player",faction="Alliance"}}}
    local e={t="FBLP",v=5,rs="pvp",d=d}
    h.deliver("BN_CHAT_MSG_ADDON","WarBoard","WBF1|D|"..N.Codec.addonEncode(N.Codec.deflateStored(N.Codec.aceWrite(e))),"WHISPER",account.gameAccountID)
end
local function many(n)
    local names={}; for i=1,n do names[i]="Enemy "..string.char(64+i) end
    local N,a=setup(names); for id in pairs(a) do confirm(id) end; return N,a
end
local function start()
    local N,a=setup(); confirm(); tick(N); advance(1); eq(#frames(N,"FBAK"),1); return N,a
end
local function stop(N,mode)
    if mode=="remove" then N.Find.remove(N.Main.find,"Enemy Player")
    elseif mode=="clear" then N.Find.remove(N.Main.find)
    elseif mode=="track" then SlashCmdList.LAYERENEMIES("warboard track off")
    elseif mode=="share" then N.Main.setShare(false)
    elseif mode=="guild" then N.Net.setConsent("guild")
    elseif mode=="source" then N.Net.setSwitch("warboard",false)
    elseif mode=="standdown" then h.loaded().WarBoard=true
    elseif mode=="logout" then h.deliver("PLAYER_LOGOUT") end
end
local function debt(guid)
    local n=0; for _,v in ipairs(LayerEnemiesDB.warboardOwed or {}) do if v==guid then n=n+1 end end; return n
end

test("exact FBAK and FBUN audit fields and codec round trip",function()
    local N,a=start(); local out=frames(N,"FBAK")[1]
    eq(out.send.target,71); same(expected("FBAK",out.e.d.sentAt,a[71]),out.e)
    eq(out.e.d.sentAt%1,0); yes(math.abs(out.e.d.sentAt-GetServerTime())<=1)
    -- Audit 11 has no FBAK fixture; these independent Ace bytes pin audit 4/5.
    local plain="^1^T^St^SFBAK^Sv^N5^Srs^Spvp^Sav^SLayerEnemies/1.2.5^SsenderName^SHunter~`Player^Sd^T"
        .."^StargetGuid^SPlayer-123-00000002^StargetName^SEnemy~`Player^ShunterGuid^SPlayer-123-00000001"
        .."^ShunterName^SHunter~`Player^ShunterFaction^SAlliance^Sfaction^SAlliance^SsentAt^N"..out.e.d.sentAt.."^t^t^^"
    same(N.Codec.aceRead(plain),out.e)
    stop(N,"remove"); advance(2); local un=frames(N,"FBUN"); eq(#un,1)
    same(expected("FBUN",un[1].e.d.sentAt,a[71]),un[1].e); eq(un[1].send.target,71)
end)

for _,mode in ipairs({"remove","clear","track","share","guild","source","standdown","logout"}) do
    test(mode.." sends exactly one owed FBUN through stop gates",function()
        local N,a=start(); eq(debt(a[71].playerGuid),1)
        stop(N,mode); advance(4); eq(#frames(N,"FBUN"),1,mode); eq(debt(a[71].playerGuid),1)
        advance(130); eq(#frames(N,"FBUN"),1,"no duplicate stop"); eq(#frames(N,"FBAK"),1)
        advance(771); eq(debt(a[71].playerGuid),0)
    end)
    test(mode.." cancels an unsent ask without creating debt",function()
        local N=setup(); confirm(); tick(N); eq(N.BNet.queued(),1)
        stop(N,mode); advance(4); eq(#frames(N),0); eq(#(LayerEnemiesDB.warboardOwed or {}),0)
    end)
end
for _,mode in ipairs({"combat","instance"}) do
    test(mode.." holds cleanup until safe including an already queued FBUN",function()
        for _,queued in ipairs({false,true}) do
            local N,a=start()
            if queued then stop(N,"track"); tick(N); yes(N.BNet.queued()>0) end
            if mode=="combat" then h.combat(true); h.deliver("PLAYER_REGEN_DISABLED") else h.instance(true); h.deliver("PLAYER_ENTERING_WORLD",false,false) end
            stop(N,"share"); advance(180); eq(#frames(N,"FBUN"),0); eq(debt(a[71].playerGuid),1)
            if queued then eq(N.BNet.queued(),1,"already queued FBUN is held, not dropped") end
            if mode=="combat" then h.combat(false) else h.instance(false) end
            advance(4); eq(#frames(N,"FBUN"),1); eq(debt(a[71].playerGuid),1)
            advance(121); eq(#frames(N,"FBUN"),1)
        end
    end)
end

test("FBUN refused and throwing client retries three times sixty seconds apart",function()
    for _,throws in ipairs({false,true}) do
        local N,a=start(); local attempts={}
        C_BattleNet.SendGameData=function(id,prefix,text)
            if prefix=="WarBoard" and text:sub(1,7)=="WBF1|D|" then
                eq(decode(N,text).t,"FBUN"); attempts[#attempts+1]=h.clock()
            end
            if throws then error("refused") end; return false
        end
        stop(N,"track"); advance(300); eq(#attempts,3); eq(debt(a[71].playerGuid),1)
        yes(attempts[2]-attempts[1]>=60); yes(attempts[3]-attempts[2]>=60)
        advance(600); eq(#attempts,6,"next window reopens, lifetime bound remains")
    end
end)
test("accepted FBUN remains unverified until roster proof not queue admission",function()
    local N,a=start(); stop(N,"track"); tick(N); eq(debt(a[71].playerGuid),1)
    local old=C_BattleNet.SendGameData; local count=0
    C_BattleNet.SendGameData=function(id,prefix,text)
        if text:sub(1,7)=="WBF1|D|" then count=count+1; if count==1 then return false end end
        return true
    end
    advance(59); eq(debt(a[71].playerGuid),1); eq(count,1)
    advance(5); eq(count,2); eq(debt(a[71].playerGuid),1)
    position(N,a[71],nil,nil,true); eq(debt(a[71].playerGuid),0)
    advance(121); eq(count,2)
end)
test("reload login settles GUID only with answered target H even source off",function()
    local N,a=start(); local saved=LayerEnemiesDB; local g=a[71].playerGuid
    saved.tracked={}; saved.nets.warboard=false
    N,a=setup({},saved); a[88]={gameAccountID=88,characterName="Renamed Target",realmName="123",factionName="Horde",
        clientProgram="WoW",isOnline=true,wowProjectID=42,isInCurrentRegion=true,playerGuid=g}
    advance(4); eq(#frames(N),0); eq(debt(g),1)
    confirm(88,"H"); advance(3); local un=frames(N,"FBUN"); eq(#un,1); eq(un[1].send.target,88); eq(un[1].e.d.targetGuid,g)
    eq(debt(g),1); position(N,a[88],nil,nil,true); eq(debt(g),0); eq(#frames(N,"FBAK"),0)
end)
test("logout in combat retains owed list and login while tracked cleans before asking",function()
    local N,a=start(); h.combat(true); h.deliver("PLAYER_LOGOUT"); eq(debt(a[71].playerGuid),1)
    local saved=LayerEnemiesDB; N,a=setup(nil,saved); confirm(); advance(4)
    local out=frames(N); yes(#out>=1); eq(out[1].e.t,"FBUN"); eq(#frames(N,"FBUN"),1)
end)
test("only new saved field is bounded dense target GUID list oldest out",function()
    local raw={}; for i=1,45 do raw[i]="Player-123-"..string.format("%08X",i+100) end
    raw.name="NEVER SAVE"; raw.zone="Secret Zone"
    local N=setup({}, {warboardOwed=raw,warboardTrack=false})
    eq(#LayerEnemiesDB.warboardOwed,40); eq(LayerEnemiesDB.warboardOwed[1],raw[6]); eq(LayerEnemiesDB.warboardOwed[40],raw[45])
    eq(LayerEnemiesDB.warboardTrack,nil)
    for k,v in pairs(LayerEnemiesDB.warboardOwed) do yes(type(k)=="number" and k>=1 and k<=40); yes(type(v)=="string" and v:match("^Player%-%d+%-%x+$")) end
    N=setup({}, {warboardOwed={"Enemy Player",{},h.secret,"Player-123-ABC","Player-123-ABC"}})
    same({"Player-123-ABC"},LayerEnemiesDB.warboardOwed)
end)
test("switch defaults on is session only and status states limits",function()
    local N=start(); yes(N.WarBoardTrack.on); SlashCmdList.LAYERENEMIES("warboard track off"); no(N.WarBoardTrack.on)
    eq(LayerEnemiesDB.warboardTrack,nil)
    local out={}; N.Main.say=function(s) out[#out+1]=s end; SlashCmdList.LAYERENEMIES("net warboard")
    yes(table.concat(out,"\n"):find("tracking: off",1,true)); yes(table.concat(out,"\n"):find("6/min",1,true))
    SlashCmdList.LAYERENEMIES("warboard track on"); yes(N.WarBoardTrack.on)
end)
test("only own Find names never shared Watch or untracked",function()
    for _,watch in ipairs({false,true}) do
        local N=setup(); N.Find.remove(N.Main.find)
        if watch then N.Watch.match=function() return true,true,true,{"Guildmate"} end end
        confirm(); advance(120); eq(#frames(N),0)
    end
end)
test("confirmation rules identity expiry and ambiguous accounts fail closed",function()
    for _,mode in ipairs({"none","H","expired","name","rules","faction","ambiguous","realm","offline"}) do
        local N,a=setup()
        if mode=="H" then confirm(71,"H") elseif mode~="none" then confirm() end
        if mode=="expired" then h.clock(h.clock()+1200)
        elseif mode=="name" then a[71].characterName="Other Player"
        elseif mode=="rules" then N.WarBoard.state.peers[71].rs="normal"
        elseif mode=="faction" then a[71].factionName="Alliance"
        elseif mode=="realm" then a[71].realmName="Other"
        elseif mode=="offline" then a[71].isOnline=false
        elseif mode=="ambiguous" then a[72]={}; for k,v in pairs(a[71]) do a[72][k]=v end; a[72].gameAccountID=72; confirm(72) end
        tick(N); if mode=="expired" then eq(N.BNet.queued(),0,"expiry admission boundary") end
        advance(3); eq(#frames(N,"FBAK"),0,mode)
    end
end)
test("GUID only from live client never a received frame",function()
    for _,value in ipairs({false,h.secret,"","invented","Player-1-nope",string.rep("x",81)}) do
        local N,a=setup(); confirm(); a[71].playerGuid=value; position(N,a[71],nil,"Player-123-FFFFFFFF")
        advance(3); eq(#frames(N,"FBAK"),0)
    end
    local N,a=setup(); confirm(); position(N,a[71],nil,"Player-123-FFFFFFFF"); tick(N); advance(1)
    eq(frames(N,"FBAK")[1].e.d.targetGuid,a[71].playerGuid)
    N,a=setup(); confirm(); a[71].playerGuid=nil; advance(3); eq(#frames(N),0)
end)
test("dispatch rechecks live GUID own identity scope and rules",function()
    for _,mode in ipairs({"guid","name","faction","rules","own","ignored"}) do
        local N,a=setup(); confirm(); tick(N)
        if mode=="guid" then a[71].playerGuid="Player-123-FFFFFFFF"
        elseif mode=="name" then a[71].characterName="Other Player"
        elseif mode=="faction" then a[71].factionName="Alliance"
        elseif mode=="rules" then GetRealmName=function() return "PvE 123" end
        elseif mode=="own" then UnitGUID=function() return "Player-123-FFFFFFFF" end
        else N.Adapters.ignored=function() return true end end
        h.clock(h.clock()+1); N.BNet.pump(h.clock()); eq(#frames(N,"FBAK"),0,mode)
    end
end)
test("server time integer mandatory and not local wall clock",function()
    for _,value in ipairs({false,h.secret,0,1.5,math.huge}) do
        local N=setup(); confirm(); GetServerTime=function() return value end; advance(3); eq(#frames(N),0)
    end
    for _,mode in ipairs({"nil","throw"}) do
        local N=setup(); confirm(); GetServerTime=function() if mode=="throw" then error("unreadable") end end; advance(3); eq(#frames(N),0)
    end
    local N=setup(); confirm(); GetServerTime=function() return 1700000123 end; tick(N); advance(1)
    eq(frames(N,"FBAK")[1].e.d.sentAt,1700000123)
end)
test("first asks three attempts six seconds apart then FBUN and 300 second idle",function()
    local N,a=start(); advance(25); position(N,a[71],nil,nil,true); local asks=frames(N,"FBAK"); eq(#asks,3); eq(#frames(N,"FBUN"),1)
    for i=2,3 do yes(asks[i].send.at-asks[i-1].send.at>=6); yes(asks[i].send.at-asks[i-1].send.at<=7) end
    advance(280); eq(#frames(N,"FBAK"),3)
    advance(25); yes(#frames(N,"FBAK")>3)
end)
test("fresh positions then renewal 45 to 300 seconds only and 45 apart",function()
    local N,a=start(); position(N,a[71]); advance(44); eq(#frames(N,"FBAK"),1)
    advance(3); eq(#frames(N,"FBAK"),2)
    advance(40); eq(#frames(N,"FBAK"),2)
    advance(6); eq(#frames(N,"FBAK"),3)
    local asks=frames(N,"FBAK"); yes(asks[3].send.at-asks[2].send.at>=45)
end)
test("newest position controls renewal and old out of order data cannot refresh",function()
    local N,a=start(); position(N,a[71]); advance(20); position(N,a[71]); advance(20)
    position(N,a[71],h.wall()-35); advance(24); eq(#frames(N,"FBAK"),1)
    advance(3); eq(#frames(N,"FBAK"),2)
end)
test("past 300 seconds sends FBUN idle until 300 pause or new handshake",function()
    local N,a=start(); position(N,a[71]); local at=h.clock()
    h.clock(at+300); tick(N); eq(#frames(N,"FBUN"),0)
    h.clock(at+301); tick(N); advance(2); eq(#frames(N,"FBUN"),1)
    position(N,a[71],nil,nil,true)
    advance(100); local count=#frames(N,"FBAK"); tick(N); eq(#frames(N,"FBAK"),count)
    confirm(); advance(4); yes(#frames(N,"FBAK")>count)
end)
test("six FBAK per rolling minute admission and dispatch max twenty targets",function()
    local N,a=many(20); tick(N); eq(N.BNet.queued(),6)
    advance(60); eq(#frames(N,"FBAK"),6)
    advance(180); local out=frames(N,"FBAK"); local seen={}
    for _,r in ipairs(out) do
        seen[r.send.target]=true; local n=0
        for _,other in ipairs(out) do if other.send.at>r.send.at-60 and other.send.at<=r.send.at then n=n+1 end end
        yes(n<=6)
    end
    eq(N.Safe.count(seen),20); no(N.Find.add(N.Main.find,"Extra Player"))
end)
test("owed A before FBUN before FBAK within ten frame WarBoard share",function()
    local N,a=many(10); tick(N); advance(6); eq(#frames(N,"FBAK"),6)
    N.Find.remove(N.Main.find); tick(N); confirm(71,"H"); advance(1)
    local last=h.sent()[#h.sent()]; eq(last.text:sub(1,7),"WBF1|A|")
    advance(52); local n=0; for _,s in ipairs(h.sent()) do if s.prefix=="WarBoard" then n=n+1 end end; eq(n,10)
    advance(10); eq(#frames(N,"FBUN"),6)
end)
test("positions remain honest Find evidence and never new guild relay",function()
    local N,a=start(); local before=#h.sent(); local routed=0; local send=N.Wire.send
    N.Wire.send=function(prefix,...) if prefix=="WarBoard" then routed=routed+1 end; return send(prefix,...) end
    position(N,a[71],h.wall()-12)
    local r=N.Find.rows(N.Main.find,h.clock(),100)[1]; yes(r.reported); eq(r.evidenceKind,"self"); eq(r.source,"warboard")
    yes(r.detail:find("own position",1,true)); no(r.canAsk); no(N.Find.alert(N.Main.find,r,h.clock()))
    eq(r.pos,"enemy"); eq(routed,0,"no forwarding attempt even if transport refuses")
    advance(3); for i=before+1,#h.sent() do no(h.sent()[i].prefix=="WarBoard" and h.sent()[i].kind~="BN") end
end)
test("rollback stays silent and tagged cancellation preserves other targets and A",function()
    local N,a=many(2); tick(N); confirm(72,"H"); N.Find.remove(N.Main.find,"Enemy A")
    advance(1); eq(h.sent()[#h.sent()].text:sub(1,7),"WBF1|A|"); advance(1)
    eq(#frames(N,"FBAK"),1); eq(frames(N,"FBAK")[1].send.target,72)
    h.clock(h.clock()-100); tick(N); advance(2); eq(#frames(N,"FBAK"),1)
end)
test("README send table first exact consequences and persistent debt",function()
    local f=assert(io.open("README.md")); local text=f:read("*a"); f:close()
    local section=assert(text:find("## 1.2.0 - WarBoard tracking request",1,true))
    local tableAt=assert(text:find("| What LE sends |",section,true))
    local effect=assert(text:find("This asks the tracked player's WarBoard client to broadcast its position to WarBoard peers every 15 seconds, as a WarBoard hunter's client does.",1,true))
    yes(tableAt<effect)
    yes(text:find("Those broadcasts go to the whole WarBoard network and carry a hunter list with your character's name; anyone running WarBoard, including the tracked player, can see that you are tracking them.",1,true))
    yes(text:find("warboardOwed",1,true))
end)

test("active request and received evidence save only target GUID no other metadata",function()
    local N,a=setup(); local before={}
    for k,v in pairs(LayerEnemiesDB) do if k~="warboardOwed" then before[k]=N.Codec.aceWrite({v}) end end
    confirm(); tick(N); advance(1); position(N,a[71]); advance(2)
    same({a[71].playerGuid},LayerEnemiesDB.warboardOwed)
    for k,v in pairs(LayerEnemiesDB) do
        if k~="warboardOwed" then yes(before[k],"no new saved key"); eq(N.Codec.aceWrite({v}),before[k]) end
    end
end)
test("no generic owed bypass for H FBAK foreign net or invented FBUN",function()
    local N,a=start(); local ask=frames(N,"FBAK")[1].send.text
    stop(N,"share"); tick(N); yes(N.BNet.queued()>0)
    no(N.BNet.send("warboard",71,"WarBoard",ask,"owed"))
    no(N.BNet.send("warboard",71,"WarBoard","WBF1|A|5|pvp|LayerEnemies/1.2.5|0","owed"))
    local un=expected("FBUN",GetServerTime(),a[71]); un.d.targetGuid="Player-123-FFFFFFFF"
    local text="WBF1|D|"..N.Codec.addonEncode(N.Codec.deflateStored(N.Codec.aceWrite(un)))
    no(N.BNet.send("warboard",71,"WarBoard",text,"owed")); no(N.BNet.send("other",71,"WarBoard",text,"owed"))
    advance(3); eq(#frames(N,"FBUN"),1)
end)
test("server clock unreadable at dispatch does not send or forget cleanup",function()
    local N,a=start(); stop(N,"track"); tick(N); local server=GetServerTime
    GetServerTime=function() return h.secret end; advance(3)
    eq(#frames(N,"FBUN"),0); eq(debt(a[71].playerGuid),1)
    GetServerTime=server; advance(3); eq(#frames(N,"FBUN"),1)
end)
test("missing own name GUID faction version or rules never asks",function()
    for _,mode in ipairs({"name","guid","faction","version","rules"}) do
        local N=setup(); confirm()
        if mode=="name" then UnitNameUnmodified=function() return h.secret end
        elseif mode=="guid" then UnitGUID=function() return nil end
        elseif mode=="faction" then UnitFactionGroup=function() return nil end
        elseif mode=="version" then C_AddOns.GetAddOnMetadata=function() return nil end
        else GetRealmName=function() return "123" end end
        advance(3); eq(#frames(N),0,mode)
    end
end)
test("failed FBAK spends three attempts and still owes FBUN",function()
    local N,a=setup(); confirm(); local kinds={}
    C_BattleNet.SendGameData=function(id,prefix,text)
        if text:sub(1,7)=="WBF1|D|" then kinds[#kinds+1]=decode(N,text).t end; return false
    end
    advance(40); same({"FBAK","FBAK","FBAK","FBUN"},kinds); eq(debt(a[71].playerGuid),1)
end)
test("all actual request attempts respect six after shared queue delay",function()
    local N,a=many(20)
    -- Occupy the entire shared minute within the composed queue caps and source
    -- registry bound: 26 one-frame sources plus Wanted's four-slot share.
    N.Net.SHIP.wanted=true -- h.load disables built networks for suite isolation
    for i=1,26 do
        local net,prefix="load"..string.char(96+i),"LoadTest"..i
        yes(N.Sources.register{name=net,prefixes={prefix}},"load register "..net)
        yes(N.BNet.send(net,71,prefix,"load","own"),"load queue "..net)
    end
    for _=1,4 do yes(N.BNet.send("wanted",71,"WNTD","load","own"),"Wanted load queue") end
    for _=1,30 do h.clock(h.clock()+1); N.BNet.pump(h.clock()) end
    tick(N); eq(N.BNet.queued(),6); advance(29); eq(#frames(N),0)
    advance(100); local out=frames(N,"FBAK"); yes(#out>=6)
    for _,r in ipairs(out) do local n=0
        for _,q in ipairs(out) do if q.send.at>r.send.at-60 and q.send.at<=r.send.at then n=n+1 end end
        yes(n<=6,"actual attempt sliding window")
    end
end)
test("same GUID debt cannot be redirected by a received forged position",function()
    local N,a=start(); local g=a[71].playerGuid
    position(N,a[71],nil,"Player-123-FFFFFFFF"); stop(N,"track"); advance(3)
    local un=frames(N,"FBUN"); eq(#un,1); eq(un[1].e.d.targetGuid,g)
end)
test("restored forty debt bound oldest out on the next attempted request",function()
    local raw={}; for i=1,40 do raw[i]="Player-123-"..string.format("%08X",i+100) end
    local N,a=setup(nil,{warboardOwed=raw}); confirm(); tick(N); advance(1)
    eq(#frames(N,"FBAK"),1); eq(#LayerEnemiesDB.warboardOwed,40)
    eq(LayerEnemiesDB.warboardOwed[1],raw[2]); eq(LayerEnemiesDB.warboardOwed[40],a[71].playerGuid)
    -- The bounded debt list must not leave an unbounded session tombstone map.
    local retained
    for i=1,20 do local key,v=debug.getupvalue(N.WarBoardTrack.size,i); if key=="records" then retained=v end end
    yes(retained); eq(N.Safe.count(retained),40)
end)

for _,mode in ipairs({"remove","clear","track","share","guild","source"}) do
    test(mode.." quick stop resume cannot erase withdrawal obligation",function()
        local N=start(); stop(N,mode)
        if mode=="remove" or mode=="clear" then N.Find.add(N.Main.find,"Enemy Player")
        elseif mode=="track" then SlashCmdList.LAYERENEMIES("warboard track on")
        elseif mode=="share" then N.Main.setShare(true)
        elseif mode=="guild" then N.Net.setConsent("public")
        elseif mode=="source" then N.Net.setSwitch("warboard",true) end
        advance(30); eq(#frames(N,"FBUN"),1); eq(#frames(N,"FBAK"),1)
    end)
end
test("six forty-five and sixty second exact admission boundaries",function()
    local N,a=start(); local at=h.clock()
    h.clock(at+5); tick(N); eq(N.BNet.queued(),0)
    h.clock(at+6); tick(N); eq(N.BNet.queued(),1)
    N,a=start(); h.clock(h.clock()+10); position(N,a[71]); at=h.clock()
    h.clock(at+44); tick(N); eq(N.BNet.queued(),0)
    h.clock(at+45); tick(N); eq(N.BNet.queued(),1)
    N,a=start(); stop(N,"track"); local tried
    C_BattleNet.SendGameData=function() tried=h.clock(); return false end
    tick(N); advance(1); yes(tried); at=tried
    h.clock(at+59); tick(N); eq(N.BNet.queued(),0)
    h.clock(at+60); tick(N); eq(N.BNet.queued(),1)
end)
test("H cannot revive an expired A confirmation",function()
    local N=setup(); confirm(); h.clock(h.clock()+1200); confirm(71,"H"); advance(3)
    eq(#frames(N,"FBAK"),0)
end)
test("renewal exact forty-five second per target boundary",function()
    local N,a=start(); position(N,a[71]); advance(47)
    local asks=frames(N,"FBAK"); eq(#asks,2); local at=asks[2].send.at
    h.clock(at+44); tick(N); eq(N.BNet.queued(),0)
    h.clock(at+45); tick(N); eq(N.BNet.queued(),1)
end)
test("twenty active targets even when corrupted Find holds twenty one",function()
    local N,a=many(20); local e=N.Find.new({"Extra Player"}).entries[1]
    N.Main.find.entries[21]=e; N.Main.find.byName[e.shortKey]={e}
    a[91]={}; for k,v in pairs(a[71]) do a[91][k]=v end
    a[91].gameAccountID=91; a[91].characterName="Extra Player"; a[91].playerGuid="Player-123-FFFFFFFF"; confirm(91)
    tick(N); eq(N.WarBoardTrack.size(),20)
end)
test("handshake before stale give-up cannot bypass the subsequent idle pause",function()
    local N,a=start(); position(N,a[71]); local at=h.clock()
    h.clock(at+10); confirm() -- newer than initial ask, but not a post-stop handshake
    h.clock(at+301); tick(N); advance(4); eq(#frames(N,"FBUN"),1)
    position(N,a[71],nil,nil,true)
    eq(#frames(N,"FBAK"),1,"old handshake must not restart the stopped request")
    advance(100); eq(#frames(N,"FBAK"),1)
    confirm(); advance(3); eq(#frames(N,"FBAK"),2)
end)
