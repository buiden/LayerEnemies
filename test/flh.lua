-- Independent wire vectors for FLH 0.1.9; donor source is never loaded.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local hop={
    {"LQ|42|100|*|8|7,8",{cmd="LQ",id=42,map=100,wantedKey="*",ownKey="8",knownCSV="7,8"}},
    {"LO|42|100|9|0|2",{cmd="LO",id=42,map=100,key="9",groupSize=0,load=2}},
    {"LR|42|100|9|0.1.3",{cmd="LR",id=42,map=100,key="9",version="0.1.3"}},
    {"LN|42|party full",{cmd="LN",id=42,reason="party full"}},
}
for _,v in ipairs(hop) do
    test("FLH: hop layout "..v[2].cmd.." decodes without performing it",function()
        local N=H.load(); local m=N.FLH.decode(v[1]); yes(m)
        for key,want in pairs(v[2]) do eq(m[key],want,key) end
        eq(m.host,nil); eq(#H.sent(),0)
    end)
end

test("FLH: HI preserves the decimal fingerprint and advertises a host",function()
    local N=H.load(); yes(N.FLH,"receive-only decoder is loaded by the TOC")
    local m=N.FLH.decode("HI|100|007|1|0.1.3|1234")
    yes(m); eq(m.cmd,"HI"); eq(m.map,100); eq(m.key,"007"); eq(m.host,1)
    eq(m.version,"0.1.3"); eq(m.realm,"1234"); eq(m.id,nil)
end)

test("FLH: separators metadata and unknown places preserve positions",function()
    local N=H.load(); local decode=N.FLH.decode
    for _,v in ipairs(hop) do
        for _,text in ipairs({v[1],(v[1]:gsub("|",":")),v[1].."|LANG=en|BUILD=0.1.9|POP=1|AUTO=1|ACT=2|CID=Player-1-2"}) do
            local m=decode(text); yes(m)
            for key,want in pairs(v[2]) do eq(m[key],want,key) end
        end
    end
    for _,text in ipairs({"HI|0||0|?|?", "HI:0::0:?:?", "HI|0::0|?:?|CID=Player-1-2"}) do
        local m=decode(text); yes(m); eq(m.map,0); eq(m.key,""); eq(m.host,0)
    end
    local m=decode("LQ|42|100|9||"); yes(m); eq(m.ownKey,""); eq(m.knownCSV,"")
    yes(decode("HI|100|8|1|future-version|1234"),"version is not a compatibility gate")
end)

test("FLH: malformed fields and unknown commands are silent nil",function()
    local N=H.load(); local decode=N.FLH.decode
    local invalid={false,42,{},H.secret,"", "PX|1", "PX|100|8|1|0.1.3|1234", "HI|100|8|1|0.1.3", "HI|100|8|1|0.1.3|1234|junk",
        "HI|100|8|1|0.1.3|1234|", "HI|100|8|1|0.1.3|1234|LANG=en\n", "HI|100|8|1|0.1.3|1234|CID=x:bad", "HI|100|8|01|0.1.3|1234",
        "HI|100|8|2|0.1.3|1234", "HI|100|8|-1|0.1.3|1234", "HI|100|8|h|0.1.3|1234",
        "HI|100|8|1||1234", "HI|100|8|1|0.1.3|", "HI|100||CID=Player-1|0.1.3|1234"}
    for _,cmd in ipairs({"WP","WR","CQ","CA","LQ","LO","LR","LN"}) do
        local tail=(cmd=="WP" or cmd=="WR") and "|1234|0.1.3|100|8|1"
            or (cmd=="CQ" or cmd=="CA") and "|100|8|1|0.1.3|1234"
            or cmd=="LQ" and "|100|*|8|7,8" or cmd=="LO" and "|100|8|0|0"
            or cmd=="LR" and "|100|8|0.1.3" or "|busy"
        for _,id in ipairs({"","abc","1e2","0x10","nan","inf","-1","1.2"," 1"}) do
            invalid[#invalid+1]=cmd.."|"..id..tail
        end
    end
    for _,key in ipairs({"0","000","*","-1","1.5","1e2","0x10","7086-7","CID=Player-1-2"}) do
        invalid[#invalid+1]="HI|100|"..key.."|1|0.1.3|1234"
        invalid[#invalid+1]="LR|42|100|"..key.."|0.1.3"
    end
    for _,csv in ipairs({"7,,8",",7","7,","0","*","7,x"}) do invalid[#invalid+1]="LQ|42|100|*|8|"..csv end
    for _,text in ipairs(invalid) do local ok,result=pcall(decode,text); yes(ok); eq(result,nil) end
    for i=0,31 do eq(decode("LN|42|bad"..string.char(i)),nil) end
    eq(decode("LN|42|bad"..string.char(127)),nil); eq(decode(nil),nil)
end)

test("FLH: the wire limit accepts 255 bytes and refuses 256",function()
    local decode=H.load().FLH.decode
    local line="HI|100|8|1|0.1.3|1234|BUILD="
    line=line..string.rep("a",255-#line); eq(#line,255); yes(decode(line))
    eq(decode(line.."a"),nil)
end)

test("FLH: its host cache is separate bounded and expires at 180 seconds",function()
    local N=H.load(); local Hs=N.Hosts; local st=Hs.new()
    yes(Hs.flh,"FLH has a dedicated host receiver")
    yes(Hs.heard(st,"Legacy",{kind="heard",layer="7102-5",zone=100,hosting=true},1000))
    yes(Hs.flh(st,"Cedar Vale-TestRealm",{map=100,key="007"},1000))
    eq(st.flhHosts["cedar vale"].name,"Cedar Vale"); eq(st.flhHosts["cedar vale"].key,"007")
    Hs.prune(st,1179); yes(st.flhHosts["cedar vale"]); yes(st.heard.Legacy)
    Hs.prune(st,1180); eq(next(st.flhHosts),nil); yes(st.heard.Legacy)
    Hs.flh(st,"Cedar Vale",{map=100,key="8"},2000); Hs.prune(st,2181); eq(next(st.flhHosts),nil)
    Hs.flh(st,"Cedar Vale",{map=100,key="8"},3000); Hs.prune(st,2999); eq(next(st.flhHosts),nil)
    for i=1,65 do yes(Hs.flh(st,"Peer"..H.abc(i),{map=100,key="8"},4000+i)) end
    eq(N.Safe.count(st.flhHosts),64); eq(st.flhHosts.peera,nil); yes(st.flhHosts["peer"..H.abc(65)])
    Hs.flh(st,"PEER"..H.abc(65),{map=100,key="9"},4066)
    eq(N.Safe.count(st.flhHosts),64); eq(st.flhHosts["peer"..H.abc(65)].key,"9")
    Hs.flh(st,"Peer"..H.abc(65),nil,4067); eq(N.Safe.count(st.flhHosts),63)
end)

local function receive(text,kind,sender)
    H.deliver("CHAT_MSG_ADDON","FLHNET2",text,kind or "GUILD",sender or "Cedar Vale")
end
local hostLines={"HI|100|8|1|0.1.3|1234","WR|42|1234|0.1.3|100|8|1","CA|42|100|8|1|0.1.3|1234"}
for _,kind in ipairs({"GUILD","PARTY","RAID","WHISPER"}) do
    test("FLH: passive "..kind.." presence admits only explicit hosts",function()
        local N=H.load(); yes(H.registered().FLHNET2)
        for i,text in ipairs(hostLines) do
            local name="Peer"..H.abc(i); receive(text,kind,name)
            local e=N.Main.heard.flhHosts[name:lower()]; yes(e); eq(e.map,100); eq(e.key,"8"); eq(e.at,H.wall())
        end
        receive("HI|100|8|0|0.1.3|1234",kind); eq(N.Main.heard.flhHosts["cedar vale"],nil)
        receive(hostLines[1],kind); yes(N.Main.heard.flhHosts["cedar vale"])
        receive("HI|100|8|0|0.1.3|1234",kind,"CEDAR VALE-TestRealm"); eq(N.Main.heard.flhHosts["cedar vale"],nil)
        receive(hostLines[1],kind); receive("HI|0||1|0.1.3|1234",kind); eq(N.Main.heard.flhHosts["cedar vale"],nil)
        eq(next(N.Main.heard.heard),nil); eq(#H.sent(),0); no(N.Main.error)
    end)
end

test("FLH: every received command is passive and non-presence cannot add hosts",function()
    local N=H.load(); local calls=0; local send=N.Wire.send
    N.Wire.send=function(...) calls=calls+1; return send(...) end
    local lines={"WP|42|1234|0.1.3|100|8|1","CQ|42|100|8|1|0.1.3|1234","PX|42","GQ"}
    for _,v in ipairs(hop) do lines[#lines+1]=v[1] end
    for _,kind in ipairs({"GUILD","PARTY","RAID","WHISPER","CHANNEL","INSTANCE_CHAT"}) do
        for _,line in ipairs(lines) do receive(line,kind) end
    end
    eq(next(N.Main.heard.flhHosts),nil)
    for _,line in ipairs(hostLines) do receive(line) end
    yes(N.Main.heard.flhHosts["cedar vale"])
    H.advance(181); eq(calls,0); eq(#H.sent(),0); no(N.Main.error)
end)

test("FLH: route identity ignore and unreadable context fail closed",function()
    local N=H.load()
    for _,kind in ipairs({"CHANNEL","SAY","INSTANCE_CHAT","BATTLEGROUND","","UNKNOWN"}) do receive(hostLines[1],kind) end
    for _,name in ipairs({"Me","Me-TestRealm","ME","bad|name","Bad2",H.secret}) do receive(hostLines[1],"WHISPER",name) end
    for i=1,4 do
        local args={"FLHNET2",hostLines[1],"GUILD","Cedar Vale"}; args[i]=H.secret
        H.deliver("CHAT_MSG_ADDON",unpack(args))
    end
    eq(next(N.Main.heard.flhHosts),nil); no(N.Main.error)
    receive(hostLines[1],"WHISPER","Me-OtherRealm"); yes(N.Main.heard.flhHosts["me-otherrealm"])
    receive(hostLines[1],"WHISPER","Cedar Vale-OtherRealm"); yes(N.Main.heard.flhHosts["cedar vale-otherrealm"])
    for _,mode in ipairs({"true","nil","secret","throw"}) do
        C_FriendList.IsIgnored=function()
            if mode=="true" then return true elseif mode=="secret" then return H.secret elseif mode=="throw" then error("unreadable") end
        end
        receive(hostLines[1]); eq(N.Main.heard.flhHosts["cedar vale"],nil)
    end
    C_FriendList.IsIgnored=function() return false end
    local own=UnitName; UnitName=function() return nil end
    receive(hostLines[1]); eq(N.Main.heard.flhHosts["cedar vale"],nil); UnitName=own
    for _,ctx in ipairs({H.combat,H.instance}) do
        ctx(true); receive(hostLines[1]); eq(N.Main.heard.flhHosts["cedar vale"],nil); ctx(false)
    end
    IsInGuild=function() return false end
    receive(hostLines[1]); eq(N.Main.heard.flhHosts["cedar vale"],nil)
    receive(hostLines[1],"PARTY"); yes(N.Main.heard.flhHosts["cedar vale"])
    eq(#H.sent(),0); no(N.Main.error)
end)

test("FLH: presence reaches friendly hosts without pretending to be a server key",function()
    local N=H.load(); H.establish(N); receive("HI|100|7086|1|0.1.3|1234")
    local rows,status=N.Main.candidates(); eq(#rows,1)
    local c=rows[1]; eq(c.name,"Cedar Vale"); eq(c.flhKey,"7086"); eq(c.flhAge,0)
    eq(c.layer,nil); eq(c.uid,nil); yes(c.host); yes(c.hosts.FLH)
    eq(c.sources[1],"Forever Layer Hop"); no(c.same); no(c.probably)
    yes(status.flh:find("1 fresh",1,true)); eq(#N.Main.candidates(true),0)
    eq(N.Hop.hostCandidate(c),nil); eq(N.Hop.hostRecord(c,100),nil); eq(N.Main.hostPreview(c),nil)
    no(N.Main.hopHostTo(c)); eq(#H.sent(),0)
    N.Main.hosts(); local lines=table.concat(H.log(),"\n")
    yes(lines:find("Forever Layer Hop",1,true)); yes(lines:find("FLH key 7086",1,true)); yes(lines:find("claim",1,true))
    N.UI.create(); N.UI.tab="friendly"; N.UI.frame:Show(); N.UI.render()
    local text=""; for _,f in ipairs(N.UI.pool) do text=text..(f.sub:GetText() or "") end
    yes(text:find("FLH key 7086",1,true)); yes(text:find("claim",1,true))
    eq(#H.sent(),0); no(N.Main.error)
end)

test("FLH: host projection is zone scoped fresh and visible with own layer unknown",function()
    local N=H.load(); receive(hostLines[1])
    local rows=N.Main.candidates(); eq(#rows,1); yes(rows[1].unknownOwn)
    receive("HI|200|8|1|0.1.3|1234","GUILD","Elsewhere"); eq(#N.Main.candidates(),1)
    H.wall(H.wall()+179); rows=N.Main.candidates(); eq(#rows,1); eq(rows[1].flhAge,179)
    H.wall(H.wall()+1); eq(#N.Main.candidates(),0); eq(next(N.Main.heard.flhHosts),nil)
    receive(hostLines[1]); H.wall(H.wall()-1); eq(#N.Main.candidates(),0)
    receive(hostLines[1]); N.Main.boundary(100); eq(#N.Main.candidates(),1)
    N.Main.boundary(200,true); eq(#N.Main.candidates(),0)
    N.Main.boundary(100,true); eq(#N.Main.candidates(),1)
end)

test("FLH: same identity merges independent provenance without changing LayerSwap fields",function()
    local N=H.load(); H.establish(N)
    N.Main.heard.heard["Cedar Vale-TestRealm"]={layer="7102-55",zone=100,at=H.wall()-30,host=true}
    receive(hostLines[1],"GUILD","CEDAR VALE")
    local rows=N.Main.candidates(); eq(#rows,1); local c=rows[1]
    eq(c.layer,"7102"); eq(c.uid,55); eq(c.age,30); eq(c.flhKey,"8"); eq(c.flhAge,0)
    yes(c.hosts.LayerSwap); yes(c.hosts.FLH); eq(#c.sources,2)
    eq(N.Hop.hostCandidate(c).source,"LayerSwap")
    receive("HI|100|8|0|0.1.3|1234"); c=N.Main.candidates()[1]
    eq(c.layer,"7102"); eq(c.flhKey,nil); eq(#c.sources,1); yes(c.hosts.LayerSwap)
    receive(hostLines[1],"GUILD","Cedar Vale-OtherRealm"); eq(#N.Main.candidates(),2)
    H.loaded().ForeverLayerHop=true; receive(hostLines[1],"GUILD","Donorpeer")
    eq(#N.Main.candidates(),3); no(N.Main.error)
end)

test("FLH: wire ingestion cannot persist names or silently refresh malformed hosts",function()
    local N=H.load()
    local function snapshot(t)
        local keys={}; for k in pairs(t) do keys[#keys+1]=k end
        table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
        local out={}
        for _,k in ipairs(keys) do out[#out+1]=tostring(k).."="..(type(t[k])=="table" and snapshot(t[k]) or tostring(t[k])) end
        return "{"..table.concat(out,",").."}"
    end
    local saved=snapshot(LayerEnemiesDB)
    receive(hostLines[1]); local stamp=N.Main.heard.flhHosts["cedar vale"].at
    H.wall(H.wall()+12)
    for _,bad in ipairs({"HI|100|oops|0|0.1.3|1234","HI|100|8|2|0.1.3|1234","PX|100|8|1|0.1.3|1234"}) do
        receive(bad); eq(N.Main.heard.flhHosts["cedar vale"].at,stamp)
    end
    eq(snapshot(LayerEnemiesDB),saved); eq(next(N.Main.store.reports),nil); eq(next(N.Main.store.localSeen),nil)
    eq(next(N.Main.find.locations),nil); eq(#H.sent(),0); no(N.Main.error)
    N=H.load(LayerEnemiesDB); eq(next(N.Main.heard.flhHosts),nil)
end)

test("FLH: seeded byte and structured fuzz is bounded silent and never sends",function()
    local N=H.load(); local decode=N.FLH.decode; local seed=1973
    local function random(n) seed=(seed*48271)%2147483647; return seed%n+1 end
    local valid={hostLines[1],hostLines[2],hostLines[3]}
    for _,v in ipairs(hop) do valid[#valid+1]=v[1] end
    local cmds={HI=true,WP=true,WR=true,CQ=true,CA=true,LQ=true,LO=true,LR=true,LN=true}
    local calls=0; local send=N.Wire.send
    N.Wire.send=function(...) calls=calls+1; return send(...) end
    for i=1,5000 do
        local s
        if i%2==0 then
            local base=valid[random(#valid)]; local at=random(#base)
            s=base:sub(1,at-1)..string.char(random(256)-1)..base:sub(at+1)
        else
            local bytes={}; for _=1,random(300) do bytes[#bytes+1]=string.char(random(256)-1) end
            s=table.concat(bytes)
        end
        local ok,m=pcall(decode,s); yes(ok,"fuzz decoder threw")
        if m then yes(cmds[m.cmd]); yes(#s<=255); no(s:find("%c")); yes(m.host==nil or m.host==0 or m.host==1) end
        receive(s); no(N.Main.error,"fuzz receive threw"); yes(N.Safe.count(N.Main.heard.flhHosts)<=64)
    end
    eq(calls,0); eq(#H.sent(),0)
end)

test("FLH: readable-looking secret strings are refused before any use",function()
    local N=H.load(); local original=issecretvalue
    local text=hostLines[1]
    issecretvalue=function(v) return v==text or original(v) end
    eq(N.FLH.decode(text),nil); receive(text); eq(next(N.Main.heard.flhHosts),nil)
    issecretvalue=original
    receive(text); yes(N.Main.heard.flhHosts["cedar vale"])
    local st=N.Hosts.new()
    for _,claim in ipairs({H.secret,{map=H.secret,key="8"},{map=100,key=H.secret},{map=0,key="8"},
        {map=100.5,key="8"},{map=100,key="0"},{map=100,key="7086-7"}}) do
        no(N.Hosts.flh(st,"Cedar Vale",claim,H.wall()))
    end
    no(N.Hosts.flh(st,H.secret,{map=100,key="8"},H.wall()))
    no(N.Hosts.flh(st,"Cedar Vale",{map=100,key="8"},H.secret)); eq(next(st.flhHosts),nil)
end)

test("FLH: friendly text gets space for its separate provenance and age",function()
    local N=H.load(); H.establish(N)
    N.Main.heard.heard["Cedar Vale"]={layer="7102-55",zone=100,at=H.wall()-30,host=true}
    receive(hostLines[1]); N.UI.create(); N.UI.tab="friendly"; N.UI.frame:Show(); N.UI.render()
    local r=N.UI.pool[1]; yes(r); yes(r.sub.height>=r.sub:GetStringHeight(),"new provenance must fit")
    yes(r.height>=26+r.sub.height,"row must contain the detail")
    local key=string.rep("9",100)
    receive("HI|100|"..key.."|1|0.1.3|1234"); N.UI.render()
    eq(N.Main.candidates()[1].flhKey,key,"display must not rewrite the fingerprint")
    yes(r.sub:GetText():find(string.rep("9",20).."...",1,true)); yes(r.sub.height>=r.sub:GetStringHeight())
end)

local presence={
    {"WP|42|1234|0.1.3|100|8|1","WP"},
    {"WR|42|1234|0.1.3|100|8|1","WR"},
    {"CQ|42|100|8|1|0.1.3|1234","CQ"},
    {"CA|42|100|8|1|0.1.3|1234","CA"},
}
for _,v in ipairs(presence) do
    test("FLH: presence layout "..v[2].." keeps its positional fields",function()
        local N=H.load()
        for _,text in ipairs({v[1],(v[1]:gsub("|",":")),v[1].."|LANG=en|BUILD=0.1.9|POP=2|AUTO=1|ACT=3|CID=Player-1-2"}) do
            local m=N.FLH.decode(text); yes(m)
            eq(m.cmd,v[2]); eq(m.id,42); eq(m.map,100); eq(m.key,"8")
            eq(m.host,1); eq(m.version,"0.1.3"); eq(m.realm,"1234")
        end
    end)
end
