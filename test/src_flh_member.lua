-- FLH membership: handwritten wire facts; no donor implementation is executed.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function receive(text,kind,sender)
    H.deliver("CHAT_MSG_ADDON","FLHNET2",text,kind or "WHISPER",sender or "Cedar Vale")
end
local function member()
    local N=H.load(); H.establish(N); H.clock(math.ceil(H.clock())); N.Net.SHIP.flh=true
    yes(N.FLHMember,"membership runtime missing")
    local meta=C_AddOns.GetAddOnMetadata
    C_AddOns.GetAddOnMetadata=function(name,key) if name=="LayerEnemies" and key=="Version" then return "1.2.3" end; return meta(name,key) end
    return N
end
local function lines()
    local out={}; for _,s in ipairs(H.sent()) do if s.prefix=="FLHNET2" then out[#out+1]=s end end
    return out
end

test("FLH member: builders carry our identity and only our fingerprint",function()
    local N=H.load(); local F=N.FLH
    yes(F.hi,"membership builders missing")
    local own={map=100,key="7",realm="TestRealm",version="LayerEnemies 1.2.3"}
    local expected={
        {F.hi(own),"HI|100|7|0|LayerEnemies 1.2.3|TestRealm|BUILD=LayerEnemies 1.2.3"},
        {F.wr(42,own),"WR|42|TestRealm|LayerEnemies 1.2.3|100|7|0|BUILD=LayerEnemies 1.2.3"},
        {F.ca(42,own),"CA|42|100|7|0|LayerEnemies 1.2.3|TestRealm|BUILD=LayerEnemies 1.2.3"},
        {F.wp(42,own),"WP|42|TestRealm|LayerEnemies 1.2.3|100|7|0|BUILD=LayerEnemies 1.2.3|AUTO=1"},
        {F.lq(42,own,"8"),"LQ|42|100|8|7||BUILD=LayerEnemies 1.2.3"},
        {F.lr(42,own,"8"),"LR|42|100|8|LayerEnemies 1.2.3|BUILD=LayerEnemies 1.2.3"},
    }
    for _,v in ipairs(expected) do eq(v[1],v[2]); yes(F.decode(v[1])); yes(#v[1]<=255) end
    for _,bad in ipairs({H.secret,{}, {map=100,key="0",realm="TestRealm",version=own.version},
        {map=H.secret,key="7",realm="TestRealm",version=own.version},
        {map=100,key="7",realm="bad|realm",version=own.version},
        {map=100,key="7",realm="TestRealm",version="0.1.3"}}) do eq(F.hi(bad),nil) end
    eq(F.wr(H.secret,own),nil); eq(F.lq(42,own,"7086-7"),nil)
end)

local wp="WP|42|1234|0.1.3|100|8|1"
local cq="CQ|42|100|8|1|0.1.3|1234"
test("FLH member: owed replies share six per minute and one per sender per sixty seconds",function()
    local N=member()
    receive(wp); eq(#lines(),1)
    local r=lines()[1]; eq(r.kind,"WHISPER"); eq(r.target,"Cedar Vale")
    local m=N.FLH.decode(r.text); eq(m.cmd,"WR"); eq(m.id,42); eq(m.map,100); eq(m.key,"7"); eq(m.host,0)
    eq(m.realm,"Test Realm"); eq(m.version,"LayerEnemies 1.2.3")
    receive(wp); receive(cq,"WHISPER","CEDAR VALE-TestRealm"); eq(#lines(),1)
    for i=1,6 do receive(i%2==0 and wp or cq,"WHISPER","Peer"..H.abc(i)) end
    eq(#lines(),6)
    H.clock(H.clock()+59.99); receive(wp); eq(#lines(),6)
    H.clock(H.clock()+.01); receive(cq); eq(#lines(),7); eq(N.FLH.decode(lines()[7].text).cmd,"CA")
    H.clock(H.clock()-120); receive(wp); eq(#lines(),7,"rollback must not reopen a budget")
end)

test("FLH member: unsolicited wrong-route self and peer-exchange traffic owes nothing",function()
    local N=member()
    for _,dist in ipairs({"GUILD","PARTY","RAID","CHANNEL","SAY","INSTANCE_CHAT"}) do receive(wp,dist); receive(cq,dist) end
    for _,name in ipairs({"Me","Me-TestRealm","ME",H.secret,"Bad2"}) do receive(wp,"WHISPER",name) end
    for _,text in ipairs({"PX|42","PR|42","PI|42|100|8|1|x|realm|Some One","LQ|42|100|*|8|", "LR|42|100|7|0.1.3", "WR|42|1234|0.1.3|100|8|0"}) do receive(text) end
    eq(#lines(),0); no(N.Main.error)
    for _,text in ipairs({wp,cq,"LO|42|100|8|0|0","PX|42",N.FLH.hi(N.FLHMember.context())}) do
        for _,dist in ipairs({"CHANNEL","WHISPER","GUILD","PARTY","RAID"}) do
            no(N.Wire.send("FLHNET2",text,dist,"Cedar Vale",{net="flh",prio="owed"}),"direct callers cannot invent debt or click authority")
        end
    end
    eq(#lines(),0)
end)

for _,mode in ipairs({"share","guild","switch","combat","instance","identity","realm","ignored"}) do
    test("FLH member: "..mode.." refuses even owed whispers",function()
        local N=member()
        if mode=="share" then LayerEnemiesDB.share=false
        elseif mode=="guild" then N.Main.setConsent("guild")
        elseif mode=="switch" then N.Main.net("net flh off")
        elseif mode=="combat" then H.combat(true)
        elseif mode=="instance" then H.instance(true)
        elseif mode=="identity" then UnitName=function() return nil end
        elseif mode=="realm" then GetRealmName=function() return nil end
        elseif mode=="ignored" then C_FriendList.IsIgnored=function() return true end end
        receive(wp); receive(cq); eq(#lines(),0); no(N.Main.error)
    end)
end

test("FLH member: guild and group presence is change-driven and capped per route",function()
    local N=member(); local F=N.FLHMember
    IsInGroup=function() return true end; IsInRaid=function() return false end
    F.tick(H.clock()); eq(#lines(),2); eq(lines()[1].kind,"GUILD"); eq(lines()[2].kind,"PARTY")
    for _,s in ipairs(lines()) do local m=N.FLH.decode(s.text); eq(m.cmd,"HI"); eq(m.host,0); eq(m.key,"7") end
    H.clock(H.clock()+120); F.tick(H.clock()); eq(#lines(),2,"no periodic presence when unchanged")
    N.Main.store.zoneUID=9; F.tick(H.clock()); eq(#lines(),4)
    N.Main.store.zoneUID=10; H.clock(H.clock()+119.99); F.tick(H.clock()); eq(#lines(),4)
    H.clock(H.clock()+.01); F.tick(H.clock()); eq(#lines(),6)
    H.clock(H.clock()+120); N.Main.setConsent("guild"); N.Main.store.zoneUID=11; F.tick(H.clock())
    eq(#lines(),7); eq(lines()[7].kind,"GUILD","group is beyond guild consent")
    H.loaded().ForeverLayerHop=true; H.clock(H.clock()+120); N.Main.store.zoneUID=12; F.tick(H.clock()); eq(#lines(),7)
    N.Main.setConsent("public"); receive(wp); receive(cq); eq(#lines(),7,"the real addon owns even owed replies")
end)

local function open(N)
    N.UI.create(); N.UI.tab="friendly"; N.UI.frame:Show(); N.UI.render()
end
local function directory(N,n)
    local names={}; for i=1,n do names[i]="Directory "..H.abc(i) end
    H.channelMembers("ForeverLayerHopNet",names)
    N.Directory.sync(); yes(N.Directory.joined("flh"))
    yes(N.Directory.refresh("flh")); H.advance(3)
    return names
end
local function countCmd(N,cmd)
    local out={}; for _,v in ipairs(lines()) do if N.FLH.decode(v.text).cmd==cmd then out[#out+1]=v end end
    return out
end

test("FLH member: directory joins read only and probes four per minute only while Friendly is open",function()
    local N=member(); local names=directory(N,6)
    for _=1,60 do H.advance(60) end
    eq(#countCmd(N,"WP"),0,"closed window stays silent for an hour")
    open(N)
    local at=H.clock()
    for _=1,60 do H.advance(1) end
    local out=countCmd(N,"WP"); eq(#out,4)
    for _,v in ipairs(out) do eq(v.kind,"WHISPER"); yes(v.target:find("Directory ",1,true)) end
    H.advance(1); eq(#countCmd(N,"WP"),5,"the fifth waits for a minute slot")
    N.UI.frame:Hide(); H.advance(600); eq(#countCmd(N,"WP"),5)
    for _,v in ipairs(lines()) do no(v.kind=="CHANNEL") end
    no(N.Main.error)
end)

test("FLH member: one directory name waits six hundred seconds and stale snapshots do not probe",function()
    local N=member(); directory(N,1); open(N); H.advance(1)
    eq(#countCmd(N,"WP"),1); local first=H.clock()
    for _=1,599 do H.advance(1) end
    eq(#countCmd(N,"WP"),1)
    H.advance(1); eq(#countCmd(N,"WP"),2)
    N.UI.frame:Hide(); H.advance(1); N.UI.frame:Show()
    N.Directory.members=function() return nil end
    H.advance(1200); eq(#countCmd(N,"WP"),2)
    no(N.Main.error)
end)

for _,mode in ipairs({"guild","share","switch","combat","instance","donor","slots"}) do
    test("FLH member: directory refused for "..mode,function()
        local N=member()
        if mode=="guild" then N.Main.setConsent("guild")
        elseif mode=="share" then LayerEnemiesDB.share=false
        elseif mode=="switch" then N.Main.net("net flh off")
        elseif mode=="combat" then H.combat(true)
        elseif mode=="instance" then H.instance(true)
        elseif mode=="donor" then H.loaded().ForeverLayerHop=true
        else for i=2,8 do H.channels()[i]="User"..i end end
        open(N); N.Directory.sync(); H.advance(30)
        no(N.Directory.joined("flh")); eq(#H.joined(),0); eq(#countCmd(N,"WP"),0)
    end)
end

test("FLH member: existing fanout sends all forty nine on its original cadence beside owed replies",function()
    local N=H.hopLoad(); N.Net.SHIP.flh=true
    C_AddOns.GetAddOnMetadata=function() return "1.2.3" end
    directory(N,8); open(N); H.hopClick(N); H.deliver("WHO_LIST_UPDATE")
    local function hopCount() local n=0; for _,v in ipairs(H.sent()) do if v.prefix=="LayerSwap" then n=n+1 end end; return n end
    eq(hopCount(),8)
    for i=1,41 do
        receive(wp,"WHISPER","Owed "..H.abc(i)); H.advance(1)
        eq(hopCount(),8+i)
    end
    eq(#countCmd(N,"WR"),6); eq(#countCmd(N,"WP"),0,"no probes during any live fanout round")
    eq(N.Wire.queued(),0); no(N.Main.error)
end)

local function host(N,name,key)
    receive("HI|100|"..(key or "8").."|1|0.1.3|1234","WHISPER",name or "Cedar Vale")
    for _,row in ipairs(N.Main.candidates()) do if row.short==(name or "Cedar Vale"):lower() then return row end end
end
local function offer(N,id,name,key,map)
    receive("LO|"..id.."|"..(map or 100).."|"..(key or "8").."|0|0","WHISPER",name)
end

test("FLH member: named guest click correlates one offer and arms only its asked host",function()
    local N=member(); local row=host(N); no(row.host,"FLH does not promote the general host flag")
    local preview=N.Main.hostPreview(row); yes(preview); yes(preview.enabled); yes(preview.detail:find("FLH",1,true))
    yes(N.Main.hopHostTo(row,preview)); local q=countCmd(N,"LQ"); eq(#q,1); eq(q[1].target,"Cedar Vale")
    local msg=N.FLH.decode(q[1].text); eq(msg.map,100); eq(msg.ownKey,"7"); eq(msg.wantedKey,"8"); eq(msg.knownCSV,"")
    H.deliver("PARTY_INVITE_REQUEST","Cedar Vale"); eq(H.accepts(),0,"a query is not invite authority")
    offer(N,msg.id+1); offer(N,msg.id,"Unknown Host"); offer(N,msg.id,nil,"7"); offer(N,msg.id,nil,"0007"); offer(N,msg.id,nil,"9"); offer(N,msg.id,nil,"8",200)
    eq(#countCmd(N,"LR"),0)
    offer(N,msg.id); eq(#countCmd(N,"LR"),1)
    local lr=countCmd(N,"LR")[1]; eq(lr.target,"Cedar Vale"); eq(N.FLH.decode(lr.text).key,"8")
    offer(N,msg.id); offer(N,msg.id,"Other Host"); eq(#countCmd(N,"LR"),1)
    H.deliver("PARTY_INVITE_REQUEST","Cedar Vale-OtherRealm"); eq(H.accepts(),0)
    H.deliver("PARTY_INVITE_REQUEST","Cedar Vale-TestRealm"); eq(H.accepts(),1)
    H.deliver("PARTY_INVITE_REQUEST","Cedar Vale"); eq(H.accepts(),1)
    yes(N.Main.auto.group); eq(N.Main.auto.group.from,"7086"); no(N.Main.error)
end)

test("FLH member: explicit FLH batch leaves a selection slot inside the unchanged hop cap",function()
    local N=member()
    for i=1,20 do host(N,"Host "..H.abc(i),tostring(10+i)) end
    SlashCmdList.LAYERENEMIES("hop flh")
    local queries=countCmd(N,"LQ"); eq(#queries,N.HopAny.CAP-1)
    yes(#queries<N.HopAny.CAP); eq(N.Wire.HOP_CAP,8); eq(N.Wire.HOP_REFILL,1); eq(N.Wire.HOP_MINUTE,60)
    local q=N.FLH.decode(queries[2].text); offer(N,q.id,queries[2].target,q.wantedKey)
    eq(#countCmd(N,"LR"),1); eq(countCmd(N,"LR")[1].target,queries[2].target)
    for _,v in ipairs(queries) do local r=N.FLH.decode(v.text); offer(N,r.id,v.target,r.wantedKey) end
    eq(#countCmd(N,"LR"),1); eq(#lines(),N.HopAny.CAP)
    H.deliver("PARTY_INVITE_REQUEST",queries[1].target); eq(H.accepts(),0)
    H.deliver("PARTY_INVITE_REQUEST",queries[2].target); eq(H.accepts(),1)
    -- A reserved shared token must not hide an eighth queued target.
    N=member(); for i=1,20 do host(N,"Host "..H.abc(i),tostring(10+i)) end
    SlashCmdList.LAYERENEMIES("hop flh"); for _=1,10 do H.advance(1) end
    eq(#countCmd(N,"LQ"),N.HopAny.CAP-1)
end)

test("FLH member: timed-out row is measured and late offers cannot send",function()
    local N=member(); local row=host(N); yes(N.Main.hopHostTo(row))
    local id=N.FLH.decode(countCmd(N,"LQ")[1].text).id
    H.clock(H.clock()+90); offer(N,id); eq(#countCmd(N,"LR"),0)
    N.FLHMember.tick(H.clock()); no(N.Main.invite.pending)
    local rowNow=N.Main.candidates()[1]; yes(N.Main.hostPlace(rowNow):find("timed out",1,true))
    open(N); local r=N.UI.pool[1]; yes(r.sub:GetText():find("timed out",1,true))
    yes(r.sub.height>=r.sub:GetStringHeight()); yes(r.height>=26+r.sub.height)
    H.deliver("PARTY_INVITE_REQUEST","Cedar Vale"); eq(H.accepts(),0)
end)

for _,mode in ipairs({"share","guild","switch","combat","instance","zone","fingerprint","stop"}) do
    test("FLH member: pending guest is revoked by "..mode,function()
        local N=member(); local row=host(N); yes(N.Main.hopHostTo(row))
        local id=N.FLH.decode(countCmd(N,"LQ")[1].text).id
        if mode=="share" then SlashCmdList.LAYERENEMIES("share off")
        elseif mode=="guild" then N.Main.setConsent("guild")
        elseif mode=="switch" then N.Main.net("net flh off")
        elseif mode=="combat" then H.combat(true); H.deliver("PLAYER_REGEN_DISABLED")
        elseif mode=="instance" then H.instance(true)
        elseif mode=="zone" then N.Main.boundary(200,true)
        elseif mode=="fingerprint" then N.Main.store.zoneUID=9
        else SlashCmdList.LAYERENEMIES("hop stop") end
        offer(N,id); eq(#countCmd(N,"LR"),0)
        H.deliver("PARTY_INVITE_REQUEST","Cedar Vale"); eq(H.accepts(),0)
        no(N.FLHMember.pending()); no(N.Main.error)
    end)
end

test("FLH member: stale previews and unknown fingerprints never redirect a click",function()
    local N=member(); local row=host(N); local preview=N.Main.hostPreview(row)
    host(N,nil,"9"); no(N.Main.hopHostTo(row,preview)); eq(#countCmd(N,"LQ"),0)
    row=N.Main.candidates()[1]; N.Main.store.zoneUID=nil
    no(N.Main.hostPreview(row).enabled); no(N.Main.hopHostTo(row)); eq(#lines(),0)
end)

test("FLH member: an LR client throttle waits for the pause then retries the same selection",function()
    local N=member(); local row=host(N); yes(N.Main.hopHostTo(row))
    local id=N.FLH.decode(countCmd(N,"LQ")[1].text).id
    H.result(3); offer(N,id); H.result(0); offer(N,id)
    eq(#countCmd(N,"LR"),1); no(N.Main.invite.pending)
    H.deliver("PARTY_INVITE_REQUEST","Cedar Vale"); eq(H.accepts(),0)
    H.clock(H.clock()+31); N.FLHMember.tick(H.clock()); offer(N,id)
    eq(#countCmd(N,"LR"),2); yes(N.Main.invite.pending)
    H.deliver("PARTY_INVITE_REQUEST","Cedar Vale"); eq(H.accepts(),1)
end)

local function snapshot(t)
    local out={}; for k,v in pairs(t) do out[#out+1]=tostring(k).."="..(type(v)=="table" and snapshot(v) or tostring(v)) end
    table.sort(out); return table.concat(out,";")
end
test("FLH member: session switch and all received names never enter SavedVariables",function()
    local N=member(); eq(LayerEnemiesDB.nets.flh,nil,"no new saved field")
    local before=snapshot(LayerEnemiesDB)
    for i=1,100 do receive(wp,"WHISPER","Guest "..H.abc(i)); host(N,"Host "..H.abc(i)) end
    N.Main.net("net flh off"); N.Main.net("net flh on"); H.deliver("PLAYER_LOGOUT")
    eq(snapshot(LayerEnemiesDB),before); eq(N.Safe.count(N.Main.heard.flhHosts),64)
    N=H.load(LayerEnemiesDB); eq(LayerEnemiesDB.nets.flh,nil); yes(N.Net.switch("flh")); eq(next(N.Main.heard.flhHosts),nil)
end)

for _,state in ipairs({"nil","secret","throw"}) do
    test("FLH member: unreadable live APIs "..state.." are silent",function()
        for _,api in ipairs({"GetRealmName","IsInInstance","InCombatLockdown","UnitAffectingCombat","UnitName"}) do
            local N=member()
            _G[api]=function() if state=="secret" then return H.secret elseif state=="throw" then error("locked") end end
            receive(wp); N.FLHMember.tick(H.clock()); eq(#lines(),0); no(N.Main.error)
        end
    end)
end

test("FLH member: share and network off-on revoke already selected guests",function()
    for _,gate in ipairs({"share","flh","guild"}) do
        local N=member(); local row=host(N); yes(N.Main.hopHostTo(row))
        local id=N.FLH.decode(countCmd(N,"LQ")[1].text).id; offer(N,id); yes(N.Main.invite.pending)
        if gate=="share" then N.Main.setShare(false); N.Main.setShare(true)
        elseif gate=="flh" then N.Net.setSwitch("flh",false); N.Net.setSwitch("flh",true)
        else N.Net.setConsent("guild"); N.Net.setConsent("public") end
        H.deliver("PARTY_INVITE_REQUEST","Cedar Vale"); eq(H.accepts(),0); no(N.Main.invite.pending)
        offer(N,id); eq(#countCmd(N,"LR"),1)
    end
end)

test("FLH member: selected guest uses unchanged confirmed-move and failure leave rules",function()
    for _,moved in ipairs({true,false}) do
        local N=member(); local row=host(N); yes(N.Main.hopHostTo(row))
        local id=N.FLH.decode(countCmd(N,"LQ")[1].text).id; offer(N,id)
        H.deliver("PARTY_INVITE_REQUEST","Cedar Vale"); eq(H.accepts(),1)
        H.group(true); H.units().party1={name="Cedar Vale",leader=true}
        UnitIsGroupLeader=function(unit) return unit=="party1" end
        N.Main.autoTick(); eq(H.leaves(),0)
        if moved then N.Main.store.bulo="7102-8"; N.Main.autoTick(); H.clock(H.clock()+3)
        else H.clock(H.clock()+30) end
        N.Main.autoTick(); eq(H.leaves(),1); no(N.Main.auto.group)
    end
end)

test("FLH member: deterministic five thousand malformed and structured frames respect every send kind",function()
    local N=member(); local seed=73519
    local function random(n) seed=(seed*48271)%2147483647; return seed%n+1 end
    local frames={wp,cq,"HI|100|8|1|0.1.3|1234","LO|42|100|8|0|0","PX|42","PI|42|100|8|1|x|realm|Some One"}
    for i=1,5000 do
        local text
        if i%2==0 then local base=frames[random(#frames)]; local at=random(#base)
            text=base:sub(1,at-1)..string.char(random(256)-1)..base:sub(at+1)
        else local bytes={}; for _=1,random(300) do bytes[#bytes+1]=string.char(random(256)-1) end; text=table.concat(bytes) end
        debug.sethook(function() error("instruction ceiling") end,"",200000)
        local ok,err=pcall(receive,text,"WHISPER","Fuzz "..H.abc(i%200+1)); debug.sethook()
        yes(ok,err); no(N.Main.error); yes(N.Safe.count(N.Main.heard.flhHosts)<=64)
    end
    yes(#lines()<=6)
    for _,v in ipairs(lines()) do
        local m=N.FLH.decode(v.text); yes(m); yes(m.cmd=="WR" or m.cmd=="CA")
        eq(v.kind,"WHISPER"); eq(m.host,0); eq(m.version,"LayerEnemies 1.2.3")
    end
    eq(LayerEnemiesDB.nets.flh,nil); eq(N.Wire.queued(),0)
end)

test("FLH member: a guest query excludes every other hop path until stopped",function()
    local N=member(); local row=host(N); yes(N.Main.hopHostTo(row)); yes(N.Main.hopAnyBusy())
    N.Main.heard.heard["Legacy Host"]={layer="7102-55",zone=100,at=H.wall(),host=true}
    local legacy=N.Main.candidates()[1]; eq(legacy.name,"Legacy Host")
    no(N.Main.hopHostTo(legacy)); eq(#H.sent(),1)
    N.Main.hopAnyStop(); no(N.FLHMember.pending()); no(N.Main.invite.pending)
end)

test("FLH member: prefix isolation still shares the public per-person cap",function()
    local N=member(); N.Net.SHIP.hh=true
    for i=1,4 do yes(N.Wire.send("HeadHunter","1AH:own","WHISPER","Cedar Vale",{net="hh",prio="own"})) end
    receive(wp); eq(#lines(),0,"existing four public lines leave no per-person room")
    receive(wp,"WHISPER","Other Host"); eq(#lines(),1)
end)

test("FLH member: no channel send or hosting authority can be manufactured inside dispatch",function()
    local N=member(); local original=N.Wire.send
    for _,replacement in ipairs({"LO|42|100|7|0|0","HI|100|7|1|LayerEnemies 1.2.3|Test Realm","PX|42","PR|42","PI|42"}) do
        N.Wire.send=function(prefix,text,dist,target,opts) return original(prefix,replacement,dist,target,opts) end
        receive(wp,"WHISPER","Forged "..H.abc(#replacement))
    end
    N.Wire.send=function(prefix,text,dist,target,opts) return original(prefix,text,"CHANNEL",target,opts) end
    receive(wp); eq(#lines(),0); no(N.Main.error)
end)

test("FLH member: party and raid share one group presence lane with no guildless copy",function()
    local N=member(); IsInGuild=function() return false end
    IsInGroup=function() return true end; IsInRaid=function() return false end
    N.FLHMember.tick(H.clock()); eq(#lines(),1); eq(lines()[1].kind,"PARTY")
    IsInRaid=function() return true end
    N.FLHMember.tick(H.clock()); eq(#lines(),1)
    H.clock(H.clock()+120); N.FLHMember.tick(H.clock()); eq(#lines(),2); eq(lines()[2].kind,"RAID")
    eq(N.FLH.decode(lines()[2].text).host,0)
end)

test("FLH member: other public traffic leaves six owed slots before probes stop",function()
    local N=member(); directory(N,6); open(N); N.Net.SHIP.hh=true
    for i=1,14 do
        yes(N.Wire.send("HeadHunter","1AH:own","WHISPER","Stranger "..H.abc(i),{net="hh",prio="own"}))
        H.clock(H.clock()+3)
    end
    N.FLHMember.tick(H.clock()); eq(#countCmd(N,"WP"),0)
    for i=1,7 do receive(wp,"WHISPER","Owed "..H.abc(i)) end
    eq(#countCmd(N,"WR"),6)
    local row=host(N); yes(N.Main.hopHostTo(row)); eq(#countCmd(N,"LQ"),0,"shared twenty-whisper ceiling")
    yes(N.FLHMember.pending(),"budget refusal now paces the unspent query")
end)

test("FLH member: client refusal spends reply and probe budgets without queue or retry",function()
    local N=member(); H.result(3)
    receive(wp); H.result(0); receive(wp); eq(#countCmd(N,"WR"),1)
    N=member(); directory(N,1); open(N); H.result(3); H.advance(1); H.result(0); H.advance(59)
    eq(#countCmd(N,"WP"),1); eq(N.Wire.queued(),0); no(N.Main.error)
end)

test("FLH member: duplicate reentrant dispatch cannot spend one authority twice",function()
    local N=member(); local original=N.Wire.send
    N.Wire.send=function(prefix,text,kind,target,opts)
        local sent=original(prefix,text,kind,target,opts)
        no(original(prefix,text,kind,target,opts)); return sent
    end
    receive(wp); eq(#lines(),1)
    local row=host(N); yes(N.Main.hopHostTo(row)); eq(#countCmd(N,"LQ"),1)
end)

test("FLH member: forged selection target and changed offer keys are never sent",function()
    local N=member(); local row=host(N); yes(N.Main.hopHostTo(row))
    local id=N.FLH.decode(countCmd(N,"LQ")[1].text).id
    offer(N,id,nil,"9"); eq(#countCmd(N,"LR"),0)
    local original=N.Wire.send
    N.Wire.send=function(prefix,text,kind,target,opts) return original(prefix,text,kind,"Different Host",opts) end
    offer(N,id); eq(#countCmd(N,"LR"),0); no(N.Main.invite.pending)
end)

test("FLH member: Wire route grammar independently refuses host and peer-exchange packets",function()
    local N=member()
    N.FLHMember.authorize=function(text) return text:match("^[A-Z]+") end
    for _,text in ipairs({"LO|42|100|8|0|0","PX|42","PR|42","PI|42","CQ|42|100|8|1|0.1.3|1234",
        "HI|100|8|1|0.1.3|1234", "WR|42|1234|0.1.3|100|8|1"}) do
        no(N.Wire.send("FLHNET2",text,"WHISPER","Cedar Vale",{net="flh",prio="owed"}))
    end
    eq(#lines(),0)
end)

test("FLH member: private owed dispatch cannot be redirected to someone else",function()
    local N=member(); local original=N.Wire.send
    N.Wire.send=function(prefix,text,kind,target,opts) return original(prefix,text,kind,"Different Host",opts) end
    receive(wp); eq(#lines(),0)
end)

test("FLH member: a freshly known new zone still revokes an open old-zone offer",function()
    local N=member(); local row=host(N); yes(N.Main.hopHostTo(row))
    local id=N.FLH.decode(countCmd(N,"LQ")[1].text).id
    N.Main.store.zone=200; C_Map.GetBestMapForUnit=function() return 200 end
    yes(N.FLHMember.context()); offer(N,id); eq(#countCmd(N,"LR"),0); no(N.FLHMember.pending())
end)

test("FLH member: merged home-realm spelling keeps the shown host and sends canonically",function()
    local N=member()
    N.Main.heard.heard["Cedar Vale-TestRealm"]={layer="7102-55",zone=100,at=H.wall(),host=false}
    local row=host(N)
    eq(row.name,"Cedar Vale-TestRealm"); no(row.host); yes(row.hosts.FLH)
    -- An explicit FLH action may include a merged row; normal row clicks still
    -- prefer the established Bulo/LayerSwap path.
    local preview=N.FLHMember.preview(row); yes(preview.enabled)
    yes(N.FLHMember.hop(row,preview))
    local queries=countCmd(N,"LQ"); eq(#queries,1); eq(queries[1].target,"Cedar Vale")
    local id=N.FLH.decode(queries[1].text).id
    offer(N,id,"Cedar Vale-TestRealm"); eq(#countCmd(N,"LR"),1)
    eq(countCmd(N,"LR")[1].target,"Cedar Vale")
    H.deliver("PARTY_INVITE_REQUEST","Cedar Vale-TestRealm"); eq(H.accepts(),1)
end)

test("FLH member: failed presence is spent until our fingerprint changes",function()
    local N=member(); H.result(3)
    N.FLHMember.tick(H.clock()); eq(#countCmd(N,"HI"),1)
    H.result(0); H.clock(H.clock()+120); N.FLHMember.tick(H.clock())
    eq(#countCmd(N,"HI"),1,"a client-refused presence is not retried")
    N.Main.store.zoneUID=9; N.FLHMember.tick(H.clock())
    eq(#countCmd(N,"HI"),2,"a new fingerprint owns a new presence")
    eq(N.FLH.decode(countCmd(N,"HI")[2].text).key,"9")
    eq(N.Wire.queued(),0)
end)

for _,donor in ipairs({true,false}) do
    test("FLH member: owner thirty-minute "..(donor and "stand-down" or "no-donor control"),function()
        local N=member(); H.loaded().ForeverLayerHop=donor
        local names={}; for i=1,40 do names[i]="Directory "..H.abc(i) end
        H.channelMembers("ForeverLayerHopNet",names)
        N.Directory.sync(); open(N); yes(N.FLHMember.windowOpen()); yes(N.FLHMember.context())
        local started=H.clock()
        for elapsed=0,1800 do
            if elapsed>0 then H.advance(1) end
            if elapsed%60==0 then
                N.Main.store.zoneUID=elapsed%120==0 and 7 or 9
                receive(wp,"WHISPER","Probe Asker")
                receive(cq,"WHISPER","Claim Asker")
                receive("HI|100|8|1|0.1.3|1234","GUILD","Reader Oak")
            end
        end
        eq(H.clock()-started,1800)
        if donor then
            eq(#lines(),0,"no FLH sends including WR and CA while the donor owns the network")
            eq(#H.joined(),0,"no directory join while the donor owns the network")
            no(N.Directory.joined("flh"))
        else
            eq(#H.joined(),1); eq(H.joined()[1],"ForeverLayerHopNet")
            for _,cmd in ipairs({"HI","WR","CA","WP"}) do yes(#countCmd(N,cmd)>0,cmd.." still runs without the donor") end
        end
        local seen
        for _,row in ipairs(N.Main.candidates()) do if row.name=="Reader Oak" then seen=row end end
        yes(seen,"receive path still reads host claims"); yes(seen.hosts.FLH); eq(seen.flhKey,"8")
        eq(N.Wire.queued(),0); no(N.Main.error)
    end)
end

test("FLH member: owner load blocks new guest queries and revokes an outstanding offer",function()
    local N=member(); local row=host(N)
    yes(N.Main.hopHostTo(row)); local id=N.FLH.decode(countCmd(N,"LQ")[1].text).id
    H.loaded().ForeverLayerHop=true
    offer(N,id); eq(#countCmd(N,"LR"),0); no(N.FLHMember.pending()); no(N.Main.invite.pending)
    row=N.Main.candidates()[1]; yes(row.hosts.FLH,"donor-loaded claims remain readable")
    local preview=N.Main.hostPreview(row); no(preview.enabled); no(N.Main.hopHostTo(row,preview))
    SlashCmdList.LAYERENEMIES("hop flh"); eq(#countCmd(N,"LQ"),1,"no new query after the owner loads")
    H.deliver("PARTY_INVITE_REQUEST","Cedar Vale"); eq(H.accepts(),0); no(N.Main.error)
end)

test("FLH member: owner loading at dispatch blocks owed replies at the final gate",function()
    for _,text in ipairs({wp,cq}) do
        local N=member(); local send=N.Wire.send; local attempts=0
        N.Wire.send=function(prefix,payload,kind,target,opts)
            if prefix=="FLHNET2" then attempts=attempts+1; H.loaded().ForeverLayerHop=true end
            return send(prefix,payload,kind,target,opts)
        end
        receive(text); eq(attempts,1); eq(#lines(),0,"owner must be checked again inside Wire authorization")
        no(N.Main.error)
    end
end)

test("FLH member: probe rotation reaches forty names under a shared two-slot budget",function()
    local N=member(); local names=directory(N,40); open(N); N.Net.SHIP.hh=true
    for minute=1,21 do
        -- Twelve real public sends leave only two probe slots after the six owed
        -- reply slots are reserved. Keep the real directory snapshot fresh.
        N.UI.frame:Hide(); N.Directory.refresh("flh"); H.advance(3)
        for i=1,12 do
            yes(N.Wire.send("HeadHunter","1AH:own","WHISPER","Load "..H.abc(i),{net="hh",prio="own"}))
            H.clock(H.clock()+3)
        end
        N.UI.frame:Show()
        for _=1,21 do H.advance(1) end
        eq(#countCmd(N,"WP"),minute*2,"two admitted probes per minute under the real shared cap")
    end
    local out=countCmd(N,"WP"); local seen,last={},{}
    for i,v in ipairs(out) do
        local recent=0
        for j=1,i do if v.at-out[j].at<60 then recent=recent+1 end end
        yes(recent<=4,"round-robin does not widen the rolling probe cap")
        if last[v.target] then yes(v.at-last[v.target]>=600,"per-name cooldown is unchanged") end
        last[v.target]=v.at
        if i<=40 then seen[v.target]=true end
    end
    eq(N.Safe.count(seen),40,"every directory name gets a turn before the head repeats")
    for i,v in ipairs(out) do eq(v.target,names[(i-1)%#names+1],"stable round-robin order") end
    no(N.Main.error)
end)

test("FLH member: probe gate refusal from a transport pause does not charge the name",function()
    local N=member(); local names=directory(N,1); open(N)
    H.result(3); receive(wp); H.result(0)
    local refusedAt=H.clock()
    yes(N.Wire.flhProbeReady(names[1],refusedAt),"the probe passes preflight before the final pause gate")
    N.FLHMember.tick(H.clock()); eq(#countCmd(N,"WP"),0)
    H.clock(refusedAt+N.Wire.PAUSE-.01); N.FLHMember.tick(H.clock()); eq(#countCmd(N,"WP"),0)
    H.clock(refusedAt+N.Wire.PAUSE); N.FLHMember.tick(H.clock())
    eq(#countCmd(N,"WP"),1,"a locally refused probe can send when the pause clears, not after 600 s")
    eq(countCmd(N,"WP")[1].target,names[1]); yes(H.clock()-refusedAt<600)
    eq(N.Wire.queued(),0); no(N.Main.error)
end)

test("FLH member: probe gate refusal rotates past a full target without charging its name",function()
    local N=member(); local names=directory(N,2); open(N); N.Net.SHIP.hh=true
    local first=H.clock()
    for i=1,4 do
        yes(N.Wire.send("HeadHunter","1AH:own","WHISPER",names[1],{net="hh",prio="own"}))
        H.clock(H.clock()+3)
    end
    local refusedAt=H.clock()
    yes(N.Wire.flhProbeReady(names[1],refusedAt),"the final per-person gate is stricter than probe preflight")
    N.FLHMember.tick(H.clock()); eq(#countCmd(N,"WP"),0)
    H.clock(H.clock()+1); N.FLHMember.tick(H.clock())
    eq(#countCmd(N,"WP"),1); eq(countCmd(N,"WP")[1].target,names[2],"refusal does not monopolize selection")
    H.clock(first+60); N.FLHMember.tick(H.clock())
    eq(#countCmd(N,"WP"),2,"the first target can use a newly free slot without a false 600 s cooldown")
    eq(countCmd(N,"WP")[2].target,names[1]); yes(H.clock()-refusedAt<600)
    eq(N.Wire.queued(),0); no(N.Main.error)
end)
