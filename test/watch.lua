-- Shared watch list: real Main/Share/Relay/Wire with the client fixture only.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function snapshot(value)
    if type(value)~="table" then return type(value)..":"..tostring(value) end
    local out={}; for key,v in pairs(value) do out[#out+1]=tostring(key).."="..snapshot(v) end
    table.sort(out); return "{"..table.concat(out,",").."}"
end
local function ready(saved)
    local N=H.load(saved); H.establish(N); H.time(100)
    yes(N.Watch and N.Main.watch,"watch module initialized")
    return N,N.Watch,N.Main.watch
end
-- Independent hash vector: same 32-bit loop and little-endian digits as hash3.
local function hash(name)
    local text=name:match("^[^%-]+"):lower()
    local value,out=5381,""
    for i=1,#text do value=(value*33+text:byte(i))%4294967296 end
    local alphabet="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    for _=1,6 do local n=value%62; out=out..alphabet:sub(n+1,n+1); value=math.floor(value/62) end
    return out
end
local function names(n)
    local out={}; for i=1,n do out[i]="Watch "..H.abc(i) end; return out
end
local function line(id,part,parts,list)
    local data={}; for _,name in ipairs(list or {}) do data[#data+1]=hash(name) end
    return table.concat({"T","1",id,tostring(part),tostring(parts),table.concat(data)},"|")
end
local function slice(list,a,b) local out={}; for i=a,b do out[#out+1]=list[i] end; return out end
local function receive(N,text,who,kind)
    H.deliver("CHAT_MSG_ADDON","LEGW1",text,kind or "GUILD",who or "Birch Scout")
    no(N.Main.error)
end
local function lines(kind)
    local out={}; for _,m in ipairs(H.sent()) do
        if m.prefix=="LEGW1" and m.text:sub(1,2)==kind.."|" then
            eq(m.kind,"GUILD"); eq(m.target,nil); yes(#m.text<=255); out[#out+1]=m
        end
    end; return out
end
local function pump(N,at) H.time(at); N.Main.watchTick(); no(N.Main.error) end
local function own(N,i,at,name)
    local e={key="Player-1-watch"..i,name=name or "Watch "..H.abc(i),displayName=name or "Watch "..H.abc(i),
        realm="Test Realm",class="MAGE",level=60,faction="opposite",source="own target",at=at or H.time()}
    yes(N.Store.observe(N.Main.store,e,H.time())); return e
end
local function sight(N,name,unit)
    unit=unit or "target"
    local e=H.player(name,"Horde","Player-1-site"); e.realm=nil; H.units()[unit]=e
    N.Main.observe(unit); no(N.Main.error)
end
local function notices()
    local out={}; for _,text in ipairs(H.log()) do if text:find(" is tracked by ",1,true) then out[#out+1]=text end end
    return out
end
local function holds(N,who,name)
    local w=N.Main.watch
    local _,key=N.Invite.name(who)
    return w.byHash[hash(name)] and w.byHash[hash(name)][key]~=nil or false
end
local function list(N,who,id,entries) receive(N,line(id,1,1,entries),who) end

test("watch 16: twenty names use one T line and a new id replaces the complete list",function()
    local N,W,st=ready({tracked=names(20)})
    pump(N,100); local sent=lines("T"); eq(#sent,1)
    local id,p,ps,body=sent[1].text:match("^T|1|(%w%w)|(%d)|(%d)|(.*)$")
    yes(id); eq(p,"1"); eq(ps,"1"); eq(#body,120)
    receive(N,sent[1].text); eq(N.Safe.count(st.held["birch scout"].hashes),20)
    list(N,"Birch Scout","zz",{"Other Name"})
    yes(holds(N,"Birch Scout","Other Name")); no(holds(N,"Birch Scout","Watch a"))
    N.Main.track("Another Name"); eq(#N.Main.find.names,20,"full list remains unchanged")
    N.Main.track("Watch a",true); pump(N,160)
    local second=lines("T")[2]; yes(second); no(second.text:match("^T|1|"..id.."|"))
end)

test("watch 16: hundred hashes commit only when all three parts arrive",function()
    local N,W,st=ready(); local all=names(100)
    list(N,"Birch Scout","aa",{"Old Name"})
    receive(N,line("ab",1,3,slice(all,1,39))); receive(N,line("ab",3,3,slice(all,79,100)))
    yes(holds(N,"Birch Scout","Old Name")); no(holds(N,"Birch Scout","Watch a"))
    receive(N,line("ab",2,3,slice(all,40,78)))
    eq(N.Safe.count(st.held["birch scout"].hashes),100); no(holds(N,"Birch Scout","Old Name"))
end)

test("watch 16: incomplete sets expire at 120 seconds and a new id discards them",function()
    local N,W,st=ready(); local all=names(100)
    list(N,"Birch Scout","aa",{"Old Name"})
    receive(N,line("ab",1,3,slice(all,1,39))); receive(N,line("ab",3,3,slice(all,79,100)))
    pump(N,220); eq(st.held["birch scout"].partial,nil); yes(holds(N,"Birch Scout","Old Name"))
    receive(N,line("ab",2,3,slice(all,40,78))); no(holds(N,"Birch Scout","Watch a"))
    receive(N,line("ac",1,2,{"New Name"})); receive(N,line("ad",2,2,{"Later Name"}))
    yes(holds(N,"Birch Scout","Old Name")); no(holds(N,"Birch Scout","New Name"))
    receive(N,line("ad",1,2,{"Final Name"})); yes(holds(N,"Birch Scout","Later Name"))
    no(holds(N,"Birch Scout","New Name"))
end)

test("watch 17: find share off sends one clear, stops refresh, and keeps local Find",function()
    local N,W,st=ready({tracked={"Watch a"}}); pump(N,100)
    SlashCmdList.LAYERENEMIES("find share off"); pump(N,101)
    eq(LayerEnemiesDB.findShare,false); local sent=lines("T"); eq(#sent,2)
    yes(sent[2].text:match("^T|1|%w%w|0|0|$"))
    SlashCmdList.LAYERENEMIES("find share off"); pump(N,1000); pump(N,2000); eq(#lines("T"),2)
    sight(N,"Watch a"); yes(N.Main.findRows()[1].at)
    list(N,"Birch Scout","aa",{"Other Name"}); yes(holds(N,"Birch Scout","Other Name"))
    SlashCmdList.LAYERENEMIES("find share on"); pump(N,2010); eq(#lines("T"),3)
end)

test("watch 18: refresh extends 25-minute expiry and clear removes the index at once",function()
    local N,W,st=ready(); list(N,"Birch Scout","aa",{"Watch a"})
    pump(N,1500); yes(holds(N,"Birch Scout","Watch a"))
    list(N,"Birch Scout","aa",{"Watch a"}); pump(N,2999); yes(holds(N,"Birch Scout","Watch a"))
    pump(N,3000); no(holds(N,"Birch Scout","Watch a")); eq(next(st.held),nil)
    list(N,"Birch Scout","ab",{"Watch b"}); receive(N,line("ac",0,0))
    eq(next(st.held),nil); eq(next(st.byHash),nil)
end)

test("watch 18: leave and guild switches clear complete and partial lists on either event",function()
    for _,event in ipairs({"PLAYER_GUILD_UPDATE","GUILD_ROSTER_UPDATE"}) do
        for _,leave in ipairs({true,false}) do
            local N,W,st=ready(); H.deliver("GUILD_ROSTER_UPDATE")
            list(N,"Birch Scout","aa",{"Watch a"}); receive(N,line("bb",1,2,{"Watch b"}),"Cedar Scout")
            H.guild(not leave,leave and "Test Guild" or "Next Guild"); H.deliver(event,"player")
            eq(next(st.byHash),nil,event); eq(next(st.held),nil,event)
        end
    end
end)

test("watch roster: remove departed senders, retain offline and unreadable rosters",function()
    local N,W,st=ready(); list(N,"Birch Scout","aa",{"Watch a"}); list(N,"Cedar Scout","aa",{"Watch b"})
    H.roster({{"Birch Scout",false}}); H.deliver("GUILD_ROSTER_UPDATE")
    yes(holds(N,"Birch Scout","Watch a")); no(holds(N,"Cedar Scout","Watch b"))
    GetGuildRosterInfo=function() return H.secret end; H.deliver("GUILD_ROSTER_UPDATE")
    yes(holds(N,"Birch Scout","Watch a"))
end)

test("watch 19: ninth listed enemy is in the first O line for either list owner",function()
    for _,ours in ipairs({true,false}) do
        local N=ready()
        for i=1,9 do own(N,i,100) end
        if ours then N.Main.track("Watch i") else list(N,"Birch Scout","aa",{"Watch i"}) end
        H.time(103); N.Main.shareTick(); local sent=lines("O"); eq(#sent,1)
        local r=N.Relay.decodeOwn(sent[1].text,"Cedar Scout",103)
        eq(r.enemies[1].name,"Watch i"); eq(#r.enemies,4)
    end
end)

test("watch 20: changed lists and refreshes never bypass the sixty-second O cooldown",function()
    local N=ready(); own(N,1,100); H.time(103); N.Main.shareTick(); eq(#lines("O"),1)
    H.time(130); list(N,"Birch Scout","aa",{"Watch a"}); N.Main.shareTick(); eq(#lines("O"),1)
    H.time(131); list(N,"Birch Scout","aa",{"Watch a"}); list(N,"Birch Scout","ab",{"Watch a"})
    H.time(145); N.Main.shareTick(); eq(#lines("O"),1)
    H.time(160); own(N,1,160); N.Main.shareTick()
    H.time(162); N.Main.shareTick(); eq(#lines("O"),1)
    H.time(163); N.Main.shareTick(); eq(#lines("O"),2)
end)

test("watch receipt: fitted names retain their cooldown while still fresh",function()
    local N=ready(); own(N,1,100); H.time(103); N.Main.shareTick(); eq(#lines("O"),1)
    H.time(104); list(N,"Birch Scout","aa",{"Watch a"})
    H.time(118); N.Main.shareTick(); eq(#lines("O"),1)
    H.time(119); list(N,"Birch Scout","ab",{"Watch a","Unseen Name"})
    H.time(133); N.Main.shareTick(); eq(#lines("O"),1)
end)

test("watch withdrawal: a cleared list cannot prioritize an unsent name",function()
    for _,ours in ipairs({false,true}) do
        local N=ready(); for i=1,9 do own(N,i,100) end
        H.time(103); N.Main.shareTick(); H.time(104)
        if ours then N.Main.track("Watch i") else list(N,"Birch Scout","aa",{"Watch i"}) end
        H.time(105)
        if ours then N.Main.track(nil) else receive(N,line("ab",0,0)) end
        H.time(118); N.Main.shareTick(); eq(#lines("O"),2)
        eq(N.Relay.decodeOwn(lines("O")[2].text,"Reader",118).enemies[1].name,"Watch e")
    end
end)

test("watch O locality: list changes never become extra War Effort names",function()
    for _,fresh in ipairs({0,2}) do
        local N=ready(); N.Net.SHIP.we=true
        H.deliver("CHAT_MSG_ADDON","WEFF1","H|1.6.6|100|7086|1|19|0|123|100","GUILD","Wes")
        for i=1,4 do own(N,i,100) end
        local function messages(kind)
            local out={}; for _,m in ipairs(H.sent()) do if m.prefix=="WEFF1" and m.text:sub(1,1)==kind then out[#out+1]=m end end
            return out
        end
        H.time(103); N.Main.shareTick(); eq(#messages("C"),1); eq(#messages("E"),1)
        H.time(104); list(N,"Birch Scout","aa",names(4))
        H.time(105); for i=5,4+fresh do own(N,i,105) end
        H.time(118); N.Main.shareTick(); eq(#lines("O"),fresh==0 and 1 or 2)
        eq(#messages("C"),fresh==0 and 1 or 2); eq(#messages("E"),fresh==0 and 1 or 2)
        if fresh>0 then
            local report=N.Protocol.decode(messages("E")[2].text); eq(#report.enemies,2)
            local normal={}; for i=5,6 do normal[N.Hash.player("Watch "..H.abc(i),"Test Realm")]=true end
            for _,e in ipairs(report.enemies) do yes(normal[e.hash],"only normally eligible names travel on War Effort") end
        end
    end
end)

test("watch priority: changed lists preserve unsent names and own freshness",function()
    local N=ready(); for i=1,9 do own(N,i,100) end
    H.time(103); N.Main.shareTick(); H.time(118); N.Main.shareTick()
    H.time(119); list(N,"Birch Scout","aa",names(8)); N.Main.shareTick(); eq(#lines("O"),2)
    H.time(133); N.Main.shareTick(); eq(#lines("O"),3); H.time(148); N.Main.shareTick(); eq(#lines("O"),3)
    local r=N.Relay.decodeOwn(lines("O")[3].text,"Cedar Scout",133)
    eq(#r.enemies,1); eq(r.enemies[1].name,"Watch i")
    N=ready(); own(N,1,100); H.time(103); N.Main.shareTick(); H.time(145)
    list(N,"Birch Scout","aa",{"Watch a"}); N.Main.shareTick(); eq(#lines("O"),1)
    N=ready(); local e=own(N,1,100); e=N.Main.store.localSeen[e.key]; e.ownAt=nil; e.ownSource=nil
    H.time(130); list(N,"Birch Scout","aa",{"Watch a"}); N.Main.shareTick(); eq(#lines("O"),0)
end)

test("watch changed list: already sent names cannot displace a pending burst",function()
    local N=ready(); for i=1,9 do own(N,i,100) end
    H.time(103); N.Main.shareTick(); H.time(104); list(N,"Birch Scout","aa",{"Watch a"})
    N.Main.shareTick(); eq(#lines("O"),1)
    H.time(118); N.Main.shareTick(); eq(#lines("O"),2)
    eq(N.Relay.decodeOwn(lines("O")[2].text,"Cedar Scout",118).enemies[1].name,"Watch e")
    H.time(119); list(N,"Birch Scout","ab",{"Watch a","Watch b"})
    H.time(133); N.Main.shareTick(); eq(#lines("O"),3)
    eq(N.Relay.decodeOwn(lines("O")[3].text,"Cedar Scout",133).enemies[1].name,"Watch i")
end)

test("watch 21: own sighting prints one quiet notice, never inside ten minutes or an instance",function()
    local N=ready(); local sounds=0; PlaySound=function() sounds=sounds+1 end
    local frames=#H.frames(); list(N,"Birch Scout","aa",{"Watch a"}); sight(N,"Watch a")
    eq(notices()[1],"LayerEnemies: Watch a is tracked by Birch Scout"); eq(#notices(),1)
    H.time(699); sight(N,"Watch a"); eq(#notices(),1)
    H.time(700); H.instance(true); sight(N,"Watch a"); eq(#notices(),1)
    H.instance(false); sight(N,"Watch a"); eq(#notices(),2)
    eq(sounds,0); eq(#H.frames(),frames)
end)

test("watch 21: no notice for own-list, reported, relayed, guild O or friendly entries",function()
    local N=ready({tracked={"Watch a-Area52"}})
    list(N,"Birch Scout","aa",{"Watch a","Watch b"}); sight(N,"Watch a-OtherRealm"); eq(#notices(),0)
    local r=N.Record.new({src="hh",kind="group",origin="Cedar Scout",rid="91",zone=100,heard=100,
        layer={ns="unknown"},enemies={{name="Watch b",class="MAGE",level=60}},route="WHISPER",share="public"})
    yes(r); N.Main.findRecord(r); eq(#notices(),0)
    receive(N,N.Relay.encode(r,100),"Elm Scout"); eq(#notices(),0)
    receive(N,N.Relay.ownLine({rid=5,zone=100,count=1,enemies={{name="Watch b"}}}),"Elm Scout"); eq(#notices(),0)
    local e=H.player("Watch b","Alliance"); H.units().target=e; N.Main.observe("target"); eq(#notices(),0)
    SlashCmdList.LAYERENEMIES("find notice off"); eq(LayerEnemiesDB.findNotice,false)
    sight(N,"Watch b"); eq(#notices(),0)
    SlashCmdList.LAYERENEMIES("find notice on"); sight(N,"Watch b"); eq(#notices(),1)
end)

test("watch notice budget: three per sliding minute and sorted watcher attribution",function()
    local N=ready(); list(N,"Elm Scout","aa",names(5)); list(N,"Birch Scout","aa",names(5)); list(N,"Cedar Scout","aa",names(5))
    for i=1,4 do sight(N,"Watch "..H.abc(i)) end
    eq(#notices(),3); eq(notices()[1],"LayerEnemies: Watch a is tracked by Birch Scout and 2 others")
    H.time(159.999); sight(N,"Watch d"); eq(#notices(),3)
    H.time(160); sight(N,"Watch d"); eq(#notices(),4)
end)

test("watch 22: login jitter and refresh jitter stay in their documented intervals",function()
    for _,random in ipairs({0,1}) do
        local old=math.random; math.random=function() return random end
        local N=H.load({tracked={"Watch a"}}); math.random=old
        yes(N.Watch,"watch module initialized")
        local due=N.Main.watch.due; yes(due>=30 and due<=90)
        H.time(due-.001); N.Main.watchTick(); eq(#lines("T"),0)
        H.time(due); N.Main.watchTick(); eq(#lines("T"),1)
        local nextAt=N.Main.watch.due; yes(nextAt-due>=480 and nextAt-due<=720)
        pump(N,nextAt-.001); eq(#lines("T"),1); pump(N,nextAt); eq(#lines("T"),2)
    end
end)

test("watch 22: ten edits debounce once and content sends remain sixty seconds apart",function()
    local N=ready()
    for i=1,10 do H.time(100+i); N.Main.track("Watch "..H.abc(i)) end
    pump(N,119.999); eq(#lines("T"),0); pump(N,120); eq(#lines("T"),1)
    H.time(121); N.Main.track("Watch k"); pump(N,131); eq(#lines("T"),1)
    pump(N,179.999); eq(#lines("T"),1); pump(N,180); eq(#lines("T"),2)
end)

test("watch 22: no T outside guild, inside instance, or with master sharing off",function()
    for _,mode in ipairs({"guild","instance","share","unreadable"}) do
        local N=ready({tracked={"Watch a"}})
        if mode=="guild" then H.guild(false)
        elseif mode=="instance" then H.instance(true)
        elseif mode=="share" then N.Main.setShare(false)
        else IsInInstance=function() return nil end end
        pump(N,100); pump(N,1000); eq(#lines("T"),0,mode)
    end
    local N=ready({tracked={"Watch a"}}); SlashCmdList.LAYERENEMIES("net guild"); pump(N,100)
    eq(#lines("T"),1,"guild-only consent does not disable LEGW1/GUILD")
end)

test("watch 22: T hard cap waits and retries after three actual sends in sixty seconds",function()
    local N=ready({tracked={"Watch a"}}); pump(N,100)
    H.time(101); SlashCmdList.LAYERENEMIES("find share off"); pump(N,101)
    H.time(102); SlashCmdList.LAYERENEMIES("find share on"); pump(N,112)
    -- Force a third eligible snapshot; toggles/clears are not the normal change cooldown.
    H.time(113); SlashCmdList.LAYERENEMIES("find share off"); pump(N,113)
    H.time(114); SlashCmdList.LAYERENEMIES("find share on"); pump(N,124)
    H.time(125); SlashCmdList.LAYERENEMIES("find share off"); pump(N,125)
    eq(#lines("T"),3); pump(N,159.999); eq(#lines("T"),3)
    pump(N,160); eq(#lines("T"),4,"fourth line waited instead of being lost")
    for i,m in ipairs(lines("T")) do local n=0
        for j=1,i do if m.at-lines("T")[j].at<60 then n=n+1 end end
        yes(n<=3)
    end
end)

test("watch queue: a full Wire bucket waits and rechecks policy before retry",function()
    local N,W,st=ready({tracked={"Watch a"}})
    for i=1,5 do yes(N.Wire.send("LEGW1","fixture","GUILD",nil,{prio="own",queue=false})) end
    pump(N,100); eq(#lines("T"),0); yes(st.pending,"T retained by its owner")
    N.Main.setShare(false); pump(N,102); eq(#lines("T"),0)
    N.Main.setShare(true); pump(N,104); eq(#lines("T"),1)
    pump(N,105); eq(#lines("T"),1)
end)

test("watch queue: a guild change drops an old pending list and reschedules in the new guild",function()
    local N,W,st=ready({tracked={"Watch a"}})
    for i=1,5 do yes(N.Wire.send("LEGW1","fixture","GUILD",nil,{prio="own",queue=false})) end
    pump(N,100); yes(st.pending)
    H.time(101); H.guild(true,"Next Guild"); H.deliver("PLAYER_GUILD_UPDATE","player")
    eq(st.pending,nil); pump(N,102); eq(#lines("T"),0)
end)

test("watch 22: base control and report decoders ignore the unknown T kind",function()
    local N=H.load(); local text=line("aa",1,1,{"Watch a"})
    eq(N.Relay.control(text),nil); eq(N.Relay.decode(text,"Birch Scout",100),nil)
    eq(N.Relay.decodeOwn(text,"Birch Scout",100),nil)
end)

test("watch 23: only the two switches are saved, never held lists or notice history",function()
    local N,W,st=ready(); eq(LayerEnemiesDB.findShare,true); eq(LayerEnemiesDB.findNotice,true)
    local before=snapshot(LayerEnemiesDB)
    list(N,"Birch Scout","aa",{"Watch a"}); sight(N,"Watch a"); pump(N,101)
    eq(snapshot(LayerEnemiesDB),before)
    local allowed={options=true,tracked=true,position=true,guildHost=true,consent=true,nets=true,share=true,call=true,callArt=true,
        netNotice=true,autoHop=true,weReportId=true,findShare=true,findNotice=true}
    for key in pairs(LayerEnemiesDB) do yes(allowed[key],"configuration only") end
    SlashCmdList.LAYERENEMIES("find share off"); SlashCmdList.LAYERENEMIES("find notice off")
    local saved=LayerEnemiesDB; N=H.load(saved)
    eq(LayerEnemiesDB.findShare,false); eq(LayerEnemiesDB.findNotice,false)
    eq(next(N.Main.watch.held),nil); eq(next(N.Main.watch.byHash),nil)
end)

test("watch 24: 101st hash, fourth part and malformed data drop only the incoming set",function()
    local all=names(101)
    for _,bad in ipairs({line("ab",3,3,slice(all,79,101)),line("ab",4,4,{"Watch a"}),
        "T|1|ab|2|3|bad",line("ab",2,2,{"Watch a"}),"T|1|ab|2|3|______",
        "T|2|ab|2|3|000000",line("ab",2,3,slice(all,1,40))}) do
        local N,W,st=ready(); list(N,"Birch Scout","aa",{"Old Name"})
        receive(N,line("ab",1,3,slice(all,1,39))); receive(N,line("ab",2,3,slice(all,40,78)))
        receive(N,bad); eq(st.held["birch scout"].partial,nil)
        yes(holds(N,"Birch Scout","Old Name")); no(holds(N,"Birch Scout","Watch a"))
    end
end)

test("watch 24: cap includes partial senders, 201st is ignored, clear frees a slot",function()
    local N,W,st=ready()
    for i=1,200 do receive(N,line("aa",1,2,{"Watch a"}),"Member "..H.abc(i)) end
    eq(N.Safe.count(st.held),200)
    list(N,"Overflow Scout","aa",{"Watch b"}); eq(N.Safe.count(st.held),200)
    no(holds(N,"Overflow Scout","Watch b"))
    receive(N,line("ab",0,0),"Member a"); list(N,"Overflow Scout","aa",{"Watch b"})
    yes(holds(N,"Overflow Scout","Watch b")); eq(N.Safe.count(st.held),200)
end)

test("watch 25: folded base-name hash matches case and realm, never class and level",function()
    local N,W,st=ready(); eq(W.hash("Watch a-Area 52"),hash("Watch a")); eq(#W.hash("Watch a"),6)
    eq(W.hash("ЁЖИК-A"),W.hash("ёжик-B")); eq(W.hash("Élan-A"),W.hash("élan-B"))
    list(N,"Birch Scout","aa",{"Watch a-Area52"})
    sight(N,"Different Name"); eq(#notices(),0,"same class/level is not identity")
    sight(N,"WATCH A-OtherRealm"); eq(#notices(),1)
    own(N,1,100,"Different Name"); own(N,9,100,"WATCH A-OtherRealm")
    H.time(103); N.Main.shareTick(); eq(N.Relay.decodeOwn(lines("O")[1].text,"Cedar Scout",103).enemies[1].name,"WATCH A-OtherRealm")
end)

test("watch lookup budget: one hash per sighting regardless of held-list size",function()
    local N,W,st=ready()
    for i=1,200 do list(N,"Member "..H.abc(i),"aa",names(20)) end
    local calls=0; local original=N.Hash.hash6
    N.Hash.hash6=function(text) calls=calls+1; return original(text) end
    for i=1,10 do sight(N,"Stranger "..H.abc(i)) end
    eq(calls,10,"never hash every held list per sighting")
end)

test("watch receive policy: guild only, own echo and unreadable names never enter the index",function()
    local N,W,st=ready(); local text=line("aa",1,1,{"Watch a"})
    for _,kind in ipairs({"PARTY","RAID","WHISPER"}) do receive(N,text,"Birch Scout",kind) end
    receive(N,text,"Me-TestRealm"); receive(N,text,"bad|name"); receive(N,H.secret,"Birch Scout")
    eq(next(st.byHash),nil); H.guild(false); receive(N,text); eq(next(st.byHash),nil)
end)

test("watch opt-out lifecycle: saved off and edits while off never advertise again",function()
    local N=ready({tracked={"Watch a"},findShare=false}); pump(N,100); pump(N,1000)
    eq(#lines("T"),0,"saved off stays silent")
    N.Main.track("Watch b"); pump(N,1100); eq(#lines("T"),0,"edits do not undo opt-out")
    N=ready({tracked={"Watch a"}}); pump(N,100)
    H.time(101); SlashCmdList.LAYERENEMIES("find share off"); eq(#lines("T"),2)
    H.time(102); N.Main.track("Watch b"); pump(N,200); pump(N,1000); eq(#lines("T"),2)
end)

test("watch expiry: an incomplete replacement keeps its own 120-second lifetime",function()
    local N,W,st=ready(); list(N,"Birch Scout","aa",{"Old Name"})
    H.time(1590); receive(N,line("ab",1,2,{"Watch a"}))
    pump(N,1600); no(holds(N,"Birch Scout","Old Name")); yes(st.held["birch scout"] and st.held["birch scout"].partial)
    H.time(1601); receive(N,line("ab",2,2,{"Watch b"}))
    yes(holds(N,"Birch Scout","Watch a")); yes(holds(N,"Birch Scout","Watch b"))
end)

test("watch receive conflicts: duplicate parts are idempotent, conflicting parts drop the set",function()
    local N,W,st=ready(); list(N,"Birch Scout","aa",{"Old Name"})
    local one=line("ab",1,2,{"Watch a"})
    receive(N,one); receive(N,one); receive(N,line("ab",2,2,{"Watch b"}))
    eq(N.Safe.count(st.held["birch scout"].hashes),2)
    receive(N,line("ac",1,2,{"Watch c"})); receive(N,line("ac",1,2,{"Watch d"}))
    eq(st.held["birch scout"].partial,nil); yes(holds(N,"Birch Scout","Watch a"))
end)

test("watch notice history: event-only operation still bounds remembered notices",function()
    local N,W,st=ready(); local all=names(30)
    list(N,"Birch Scout","aa",all)
    for i=1,20 do
        H.time(100+i*61); sight(N,"Watch "..H.abc(i))
    end
    yes(N.Safe.count(st.noticed)<=10,"ten-minute notice history is bounded")
end)

for _,flap in ipairs({1,5,30}) do
    test("watch R1 repeat: list churn every "..flap.." seconds preserves per-name sixty seconds",function()
        for _,ours in ipairs({false,true}) do
            local N=ready(); local serial=0
            for t=100,400 do
                H.time(t); own(N,1,t)
                if (t-100)%flap==0 then
                    serial=serial+1
                    if ours then
                        N.Main.track("Watch a")
                        N.Main.track("Unseen Name",serial%2==0)
                    else
                        list(N,"Birch Scout",serial%2==0 and "aa" or "ab",
                            serial%2==0 and {"Watch a"} or {"Watch a","Unseen Name"})
                    end
                end
                N.Main.shareTick()
            end
            local sent=lines("O"); eq(#sent,5,"unchanged sixty-second send budget")
            for i=2,#sent do yes(sent[i].at-sent[i-1].at>=60,"same name must wait sixty seconds") end
            no(N.Main.error)
        end
    end)
end

test("watch R1 fairness: nine enemies all leave while four listed names churn",function()
    local N=ready()
    for t=100,279 do
        H.time(t); for i=1,9 do own(N,i,t) end
        local watched=names(4); if t%2==0 then watched[#watched+1]="Unseen Name" end
        list(N,"Birch Scout",t%2==0 and "aa" or "ab",watched); N.Main.shareTick()
    end
    local sent,seen=lines("O"),{}
    for _,m in ipairs(sent) do
        local r=N.Relay.decodeOwn(m.text,"Reader",m.at)
        for _,e in ipairs(r.enemies) do seen[e.name]=true end
    end
    eq(N.Safe.count(seen),9,"unlisted names must not starve")
    eq(#sent,9,"same total O lines as the base cohort")
    local first=N.Relay.decodeOwn(sent[1].text,"Reader",sent[1].at)
    for i=1,4 do eq(first.enemies[i].name,"Watch "..H.abc(i),"listed names first") end
    no(N.Main.error)
end)

local function report(N,i,name)
    return N.Record.new({src="hh",kind="group",origin="Origin "..H.abc(i),rid=tostring(i),zone=100,heard=100,
        layer={ns="unknown"},enemies={{name=name or "Other Name",class="MAGE",level=60}},route="WHISPER",share="public"})
end

test("watch relays: listed name takes the last available token before unlisted reports",function()
    local N=ready(); list(N,"Birch Scout","aa",{"Watch a"}); N.Relay.rand=function() return 1 end
    N.Main.offerRelay(report(N,1)); N.Main.offerRelay(report(N,2,"Watch a-OtherRealm"))
    H.time(103); for i=1,4 do yes(N.Wire.send("LEGW1","fixture","GUILD")) end
    N.Main.relayTick(); local sent=lines("R"); eq(#sent,1)
    eq(N.Relay.decode(sent[1].text,"Cedar Scout",103).enemies[1].name,"Watch a-OtherRealm")
    eq(next(N.Main.relay.pending),nil,"forward bucket losers still drop, no cap change")
end)

test("watch relays: full pending cap drops an unlisted entry before a listed one",function()
    local N=ready(); list(N,"Birch Scout","aa",{"Watch a"}); N.Relay.rand=function() return 2 end
    for i=1,N.Relay.PENDING do N.Main.offerRelay(report(N,i)) end
    local r=report(N,200,"Watch a"); N.Main.offerRelay(r)
    yes(N.Main.relay.pending[N.Relay.key(r)],"listed relay admitted by dropping an unlisted relay")
    eq(N.Safe.count(N.Main.relay.pending),N.Relay.PENDING)
end)
