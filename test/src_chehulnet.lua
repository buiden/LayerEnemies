-- Handwritten HELLO vectors; no donor addon or library is executed.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local hello="CHN1|H|gos+pl|MAGE|60|craft:Enchanting,lfg,mv=10|100:7"
local function receive(text,dist,sender)
    H.deliver("CHAT_MSG_ADDON","ChehulNet",text or hello,dist or "GUILD",sender or "Cedar Vale")
end

test("ChehulNet: registry receives guild and group with counters and live switch",function()
    local N=H.load(); local C=N.ChehulNet
    yes(N.Sources.has("chehulnet")); yes(H.registered().ChehulNet); yes(N.shipped.chehulnet)
    for i,dist in ipairs({"GUILD","PARTY","RAID"}) do receive(hello,dist,"Peer"..H.abc(i)) end
    eq(#C.rows(),3); eq(C.stats.heard,3); eq(C.stats.accepted,3); eq(C.stats.sent,0)
    for _,dist in ipairs({"WHISPER","CHANNEL","SAY","YELL","INSTANCE_CHAT","BATTLEGROUND"}) do receive(hello,dist) end
    H.deliver("BN_CHAT_MSG_ADDON","ChehulNet",hello,"WHISPER",71); eq(#C.rows(),3)
    eq(C.stats.accepted,3)
    N.Main.net("net chehulnet off"); receive(); eq(#C.rows(),0)
    N.Main.net("net chehulnet on"); receive(); eq(#C.rows(),4)
    N.Main.net("net"); yes(table.concat(H.log(),"\n"):find("chehulnet: heard=",1,true))
    eq(C.stats.sent,0); eq(#H.sent(),0); no(N.Main.error)
end)

test("ChehulNet: unreadable foreign values and live context fail silent",function()
    local N=H.load(); local C=N.ChehulNet
    for i=1,4 do
        local args={"ChehulNet",hello,"GUILD","Cedar Vale"}; args[i]=H.secret
        H.deliver("CHAT_MSG_ADDON",unpack(args))
    end
    for _,name in ipairs({"Me","ME-TestRealm","Bad2",H.secret}) do receive(hello,"GUILD",name) end
    eq(#C.rows(),0)
    for _,gate in ipairs({H.combat,H.instance}) do
        for _,state in ipairs({true,H.secret}) do gate(state); receive(); gate(false); eq(#C.rows(),0) end
    end
    for _,fn in ipairs({function() return true end,function() return nil end,function() return H.secret end,function() error("locked") end}) do
        C_FriendList.IsIgnored=fn; receive(); eq(#C.rows(),0)
    end
    C_FriendList.IsIgnored=function() return false end
    local own=UnitName
    for _,fn in ipairs({function() return nil end,function() return H.secret end,function() error("locked") end}) do UnitName=fn; receive() end
    UnitName=own; eq(#C.rows(),0)
    local wall=N.Adapters.wall; N.Adapters.wall=function() return nil end; receive(); N.Adapters.wall=wall; eq(#C.rows(),0)
    local original=issecretvalue
    issecretvalue=function(v) return v==hello or original(v) end; receive(); issecretvalue=original; eq(#C.rows(),0)
    receive(); eq(#C.rows(),1); no(N.Main.error); eq(#H.sent(),0)
end)

test("ChehulNet: no sends joins evidence saved names or own layer changes even on later ticks",function()
    local N=H.load(); local C=N.ChehulNet; H.establish(N)
    N.Main.find=N.Find.new({"Cedar Vale"})
    local calls=0
    local function count() calls=calls+1; return false end
    N.Wire.send=count; N.BNet.send=count; N.Sources.offer=count; N.Find.report=count; N.Presence.note=count
    JoinChannelByName=count; SendAddonMessage=count; PlaySound=count
    local function snap(t)
        local parts={}; for k,v in pairs(t) do parts[#parts+1]=tostring(k).."="..(type(v)=="table" and snap(v) or tostring(v)) end
        table.sort(parts); return table.concat(parts,";")
    end
    local saved=snap(LayerEnemiesDB); local store=N.Main.store
    local layer,uid,raw,current=store.bulo,store.zoneUID,N.Main.npcs.raw,N.Main.npcs.current
    for _,dist in ipairs({"GUILD","PARTY","RAID","WHISPER","CHANNEL"}) do
        receive(hello,dist); receive("CHN1|H|gos|MAGE|60||100:7086",dist,"Elsewhere")
        receive("CHN1|Q|gos|MAGE|60||100:7",dist)
    end
    eq(#C.rows(),2)
    H.advance(1); N.Main.findAlerts(); eq(calls,0)
    eq(store.bulo,layer); eq(store.zoneUID,uid); eq(N.Main.npcs.raw,raw); eq(N.Main.npcs.current,current)
    eq(#N.Main.reportedRows(),0); eq(#N.Main.candidates(),0); no(N.Main.findRows()[1].at)
    H.deliver("PLAYER_LOGOUT"); eq(snap(LayerEnemiesDB),saved)
    H.advance(400); eq(#C.rows(),0); eq(calls,0); eq(#H.sent(),0); no(N.Main.error)
end)

test("ChehulNet: pure store accepts only guild group and whole other identities",function()
    local N=H.load(); local C=N.ChehulNet; local st=C.new("Me")
    for _,dist in ipairs({"GUILD","PARTY","RAID"}) do
        yes(C.note(st,"Cedar Vale-TestRealm",C.parse(hello),dist,1000))
    end
    eq(N.Safe.count(st.entries),1); yes(st.entries["cedar vale"])
    for _,dist in ipairs({"WHISPER","CHANNEL","SAY","YELL","INSTANCE_CHAT","BATTLEGROUND","",H.secret}) do
        no(C.note(st,"Nope",C.parse(hello),dist,1000))
    end
    for _,who in ipairs({"Me","ME-TestRealm","bad|name","Bad2",H.secret}) do no(C.note(st,who,C.parse(hello),"GUILD",1000)) end
    eq(N.Safe.count(st.entries),1)
    yes(C.note(st,"Me-OtherRealm",C.parse(hello),"GUILD",1000))
    yes(C.note(st,"Cedar Vale-OtherRealm",C.parse(hello),"GUILD",1000)); eq(N.Safe.count(st.entries),3)
    no(C.note(C.new(nil),"Cedar Vale",C.parse(hello),"GUILD",1000))
    for _,bad in ipairs({false,H.secret,setmetatable({},{__index=function() error("unreadable") end})}) do
        local ok,result=pcall(C.note,st,"New Peer",bad,"GUILD",1000); yes(ok); no(result)
    end
    for _,field in ipairs({"class","level","map","zone"}) do
        local r=C.parse(hello); r[field]=H.secret
        local ok,result=pcall(C.note,st,"New Peer",r,"GUILD",1000); yes(ok); no(result)
    end
    no(C.note(st,"New Peer",C.parse(hello),"GUILD",H.secret)); eq(N.Safe.count(st.entries),3)
end)

test("ChehulNet: comparisons require own readings and never use server keys",function()
    local C=H.load().ChehulNet; local st=C.new("Me")
    for _,v in ipairs({{"Same",100,7},{"Other",100,7086},{"Away",200,7},{"Unknown",nil,nil}}) do
        yes(C.note(st,v[1],{class="MAGE",map=v[2],zone=v[3]},"GUILD",1000))
    end
    local function rows(map,zone,amb)
        local out={}; for _,r in ipairs(C.view(st,map,zone,1010,amb)) do out[r.name]=r; eq(r.layer,nil); eq(r.uid,nil); eq(r.age,10) end
        return out
    end
    local r=rows(100,7,false); eq(r.Same.rel,"same"); eq(r.Other.rel,"other"); eq(r.Away.rel,nil); eq(r.Unknown.rel,nil)
    for _,args in ipairs({{100,7,true},{100,nil,false},{nil,7,false},{100,H.secret,false},{H.secret,7,false},{100,7,H.secret}}) do
        for _,v in pairs(rows(unpack(args))) do eq(v.rel,nil) end
    end
    C.note(st,"Same",{class="MAGE"},"GUILD",1011); eq(C.view(st,100,7,1011)[3].layer,nil)
    for _,v in ipairs(C.view(st,100,7,1011)) do if v.name=="Same" then eq(v.rel,nil) end end
    for _,value in ipairs({0,-1,1.5,100000000,math.huge,0/0}) do
        C.note(st,"Invalid",{map=value,zone=value,level=value},"GUILD",1012)
        local found
        for _,v in ipairs(C.view(st,100,7,1012)) do if v.name=="Invalid" then found=v end end
        yes(found); eq(found.map,nil); eq(found.zone,nil); eq(found.level,nil)
    end
end)

test("ChehulNet: expiry rollback replacement and oldest eviction are bounded",function()
    local N=H.load(); local C=N.ChehulNet; local st=C.new("Me")
    C.note(st,"Cedar",C.parse(hello),"GUILD",1000)
    eq(#C.view(st,100,7,1399),1); eq(#C.view(st,100,7,1400),0); eq(next(st.entries),nil)
    C.note(st,"Cedar",C.parse(hello),"GUILD",1500); C.sweep(st,1499); eq(next(st.entries),nil)
    for i=1,200 do yes(C.note(st,"Peer"..H.abc(i),C.parse(hello),"GUILD",2000+i)) end
    eq(N.Safe.count(st.entries),200)
    C.note(st,"PEERA",C.parse(hello),"PARTY",2201); eq(N.Safe.count(st.entries),200)
    C.note(st,"Newest",C.parse(hello),"RAID",2202); eq(N.Safe.count(st.entries),200)
    yes(st.entries.peera); eq(st.entries.peerb,nil); yes(st.entries.newest)
    C.sweep(st,2602); eq(next(st.entries),nil)
end)

test("ChehulNet: Friendly hints have no Ask and never become hop candidates",function()
    local N=H.load(); H.establish(N)
    receive("CHN1|H|gos|MAGE|60||100:8")
    receive(hello,"PARTY","Same Peer")
    receive("CHN1|H|gos|MAGE|60||200:8","RAID","Away Peer")
    receive("CHN1|H|gos|MAGE|60||0:0","GUILD","Unknown Peer")
    eq(#N.Main.candidates(),0); eq(#N.Main.candidates(true),0)
    N.UI.tab="friendly"; N.UI.frame:Show(); N.UI.render()
    local r=N.UI.pool[1]; yes(r and r:IsShown(),"other-layer hint appears")
    eq(r.title:GetText(),"Cedar Vale")
    yes(N.UI.chehulTitle and N.UI.chehulTitle:IsShown(),"separate hint subsection title")
    eq(N.UI.chehulTitle:GetText(),"Guildmates on other layers (hints)")
    yes(r.sub:GetText():find("another layer of your zone",1,true)); no(r.ask:IsShown()); no(r.spotter); no(r.hostRow); no(r.hopRecord)
    no(r.sub:GetText():lower():find("confirmed",1,true))
    eq(r.age:GetText(),"0 s")
    if N.UI.pool[2] then no(N.UI.pool[2]:IsShown()) end
    N.Main.npcs.ambigAt=H.clock(); N.UI.render(); no(r:IsShown())
    N.Main.npcs.ambigAt=nil; N.Main.store.zoneUID=nil; N.UI.render(); no(r:IsShown())
    eq(#H.sent(),0)
end)

test("ChehulNet: hints never inflate the Friendly tab count",function()
    for _,case in ipairs({{0,140},{3,10},{3,0}}) do
        local N=H.load(); H.establish(N)
        for i=1,case[1] do N.Hosts.flh(N.Main.heard,"Host"..H.abc(i),{map=100,key="8"},H.wall()) end
        for i=1,case[2] do receive("CHN1|H|gos|MAGE|60||100:8","GUILD","Ally"..H.abc(i)) end
        N.UI.tab="friendly"; N.UI.frame:Show(); N.UI.render()
        eq(N.UI.tabs.friendly.label:GetText(),"Friendly ("..case[1]..")","only hosts count")
        local hosts,hints=N.ChehulNet.friendly(N.Main.candidates())
        eq(#hosts,case[1]); yes(hints,"separate hint projection"); eq(#hints,case[2])
        eq(#N.Main.candidates(),case[1]); eq(#N.Main.candidates(true),0,"FLH hints do not enter the Bulo/LayerSwap-only list")
        for _,hint in ipairs(hints) do yes(hint.chehulHint); no(hint.host); eq(hint.layer,nil) end
        eq(#H.sent(),0); no(N.Main.error)
    end
end)

test("ChehulNet: hint subsection follows every host with measured paged rows",function()
    local N=H.load(); H.establish(N); local U=N.UI
    for i=1,3 do N.Hosts.flh(N.Main.heard,"Host"..H.abc(i),{map=100,key="8"},H.wall()) end
    -- An annotated host remains above the hints, even when its card is taller.
    receive("CHN1|H|gos|MAGE|60||100:8","GUILD","Hosta")
    local expected={}
    for _,r in ipairs(N.Main.candidates()) do expected[#expected+1]=r.name end
    for i=1,10 do
        local name="Ally"..H.abc(i); expected[#expected+1]=name
        receive("CHN1|H|gos|MAGE|60||100:8","GUILD",name)
    end
    U.tab="friendly"; U.frame:Show(); U.render()
    yes(U.chehulTitle,"hints have their own subsection heading")
    local function top(frame) return -frame.point[5] end
    local compact
    for _,size in ipairs({10,24,10}) do
        U.chehulTitle:SetFont("Fonts\\FRIZQT__.TTF",size,"")
        local visited={}
        for offset=0,#expected do
            U.offset=offset; U.render()
            local firstHint,lastHost,previous,visible=nil,nil,nil,0
            for _,r in ipairs(U.pool) do if r:IsShown() then
                visible=visible+1
                local index=U.offset+visible
                eq(r.title:GetText(),expected[index],"hosts first, then sorted hints")
                visited[index]=true
                yes(r.sub:GetHeight()>=r.sub:GetStringHeight(),"hint and host details measured")
                yes(top(r)+r:GetHeight()<=U.body:GetHeight(),"complete card inside page")
                if previous then yes(top(r)>=top(previous)+previous:GetHeight()+4,"rows do not overlap") end
                previous=r
                if index<=3 then lastHost=r; eq(r.spotter,expected[index],"existing FLH action preserved"); yes(r.ask:IsShown())
                else
                    firstHint=firstHint or r
                    no(r.ask:IsShown()); no(r.hostRow); no(r.hopRecord); no(r.spotter)
                    yes(r.sub:GetText():find("Hint only",1,true))
                    no(r.sub:GetText():find("Guildmates on other layers (hints)",1,true),"heading is not duplicated in each card")
                end
            end end
            yes(visible>0,"no orphan heading page")
            eq(U.chehulTitle:IsShown(),firstHint~=nil,"heading appears only with visible hints")
            if firstHint then
                eq(U.chehulTitle:GetText(),"Guildmates on other layers (hints)")
                yes(U.chehulTitle:GetHeight()>=U.chehulTitle:GetStringHeight(),"heading measured")
                yes(top(firstHint)>=top(U.chehulTitle)+U.chehulTitle:GetHeight()+4,"hint below complete heading")
                if lastHost then yes(top(U.chehulTitle)>=top(lastHost)+lastHost:GetHeight()+4,"section after last visible host") end
            end
        end
        for i=1,#expected do yes(visited[i],"every host and hint reachable") end
        if not compact then compact=U.chehulTitle:GetHeight()
        elseif size==24 then yes(U.chehulTitle:GetHeight()>compact,"wraps at larger font")
        else eq(U.chehulTitle:GetHeight(),compact,"heading shrinks on reuse") end
    end
    U.select("local"); no(U.chehulTitle:IsShown())
    U.select("friendly"); H.wall(H.wall()+400); U.render()
    no(U.chehulTitle:IsShown()); eq(U.offset,0); eq(U.tabs.friendly.label:GetText(),"Friendly (0)")
    for _,r in ipairs(U.pool) do no(r:IsShown()) end
    -- A compact LayerSwap host and one hint share a page: exercise the actual
    -- boundary, not just the repeated heading on hint-only pages.
    LayerSwapDB={book={Hostz={layer="7102",zone="100",host=true,at=H.wall()}}}
    receive("CHN1|H|gos|MAGE|60||100:8","GUILD","Allyz"); U.render()
    local host,hint=U.pool[1],U.pool[2]
    yes(host:IsShown()); yes(hint and hint:IsShown(),"mixed host/hint page")
    eq(host.title:GetText(),"Hostz"); yes(host.hostRow); yes(host.ask:IsShown())
    eq(hint.title:GetText(),"Allyz"); no(hint.hostRow); no(hint.ask:IsShown())
    yes(top(U.chehulTitle)>=top(host)+host:GetHeight()+4,"section after host on mixed page")
    yes(top(hint)>=top(U.chehulTitle)+U.chehulTitle:GetHeight()+4,"hint follows mixed-page heading")
    eq(U.tabs.friendly.label:GetText(),"Friendly (1)")
    eq(#H.sent(),0); no(N.Main.error)
end)

test("ChehulNet: existing hosts gain independent measured annotation without capability changes",function()
    local N=H.load(); H.establish(N)
    N.Hosts.flh(N.Main.heard,"Cedar Vale",{map=100,key="12345678901234567890123456789012"},H.wall())
    receive("CHN1|H|gos|MAGE|60||100:8")
    local before=N.Main.candidates()[1]; local raw=N.Main.heard.flhHosts["cedar vale"]
    local out=N.ChehulNet.friendly(N.Main.candidates()); eq(#out,1)
    eq(out[1].layer,before.layer); eq(out[1].flhKey,before.flhKey); eq(out[1].host,before.host); eq(out[1].age,before.age)
    yes(out[1].chehulText:find("other layer (ChehulNet claim)",1,true)); no(out[1].chehulHint)
    no(out[1].chehulText:lower():find("confirmed",1,true),"HELLO is a claim, not verification")
    eq(raw.key,before.flhKey); eq(N.Main.candidates()[1].chehulText,nil)
    -- The same identity merges from any already known host source; no new
    -- host flags or server-layer fields are inferred from a HELLO.
    for _,source in ipairs({"LayerEnemies","HeadHunter","Forever Layer Hop"}) do
        local base={name="CEDAR VALE-TestRealm",short="cedar vale",layer="7102",uid=9,age=77,host=true,hosts={[source]=true},sources={source}}
        local view=N.ChehulNet.friendly({base}); eq(#view,1); yes(view[1].chehulText)
        eq(base.chehulText,nil); eq(view[1].layer,"7102"); eq(view[1].uid,9); eq(view[1].age,77)
        eq(N.Safe.count(view[1].hosts),1)
    end
    N.UI.tab="friendly"; N.UI.frame:Show(); N.UI.render()
    local r=N.UI.pool[1]; yes(r.sub:GetText():find("other layer (ChehulNet claim)",1,true)); yes(r.ask:IsShown())
    no(r.sub:GetText():lower():find("confirmed",1,true))
    yes(r.sub:GetHeight()>=r.sub:GetStringHeight(),"new detail measured before paging")
    yes(r:GetHeight()>=26+r.sub:GetHeight()+32,"text does not overlap button")
    H.wall(H.wall()+400); N.UI.render(); no(r:IsShown()); eq(#N.Main.candidates(),0)
end)

test("ChehulNet: layer command counts distinct current-map UIDs and names our peers",function()
    local N=H.load(); H.establish(N)
    receive(); receive(hello,"PARTY","Same Peer")
    receive("CHN1|H|gos|MAGE|60||100:8","RAID","Other Peer")
    receive("CHN1|H|gos|MAGE|60||200:9","GUILD","Away Peer")
    receive("CHN1|H|gos|MAGE|60||0:0","GUILD","Unknown Peer")
    SlashCmdList.LAYERENEMIES("layer")
    local lines=table.concat(H.log(),"\n")
    no(lines:lower():find("confirmed",1,true))
    yes(lines:find("2 distinct layers",1,true)); yes(lines:find("same layer as you: Cedar Vale",1,true))
    yes(lines:find("same layer as you: Same Peer",1,true)); no(lines:find("Away Peer",1,true)); no(lines:find("Other Peer",1,true))
    N.Main.npcs.ambigAt=H.clock(); local at=#H.log(); SlashCmdList.LAYERENEMIES("layer")
    local more={}; for i=at+1,#H.log() do more[#more+1]=H.log()[i] end
    local text=table.concat(more,"\n"); no(text:find("same layer as you:",1,true)); yes(text:find("comparison unavailable",1,true))
    eq(#H.sent(),0); no(N.Main.error)
end)

test("ChehulNet: layer command caps same-layer names at eight with exact overflow",function()
    for _,count in ipairs({0,1,8,9,60,200}) do
        local N=H.load(); H.establish(N)
        -- Other-map and other-layer claims must not consume the name budget
        -- or inflate the overflow. At the store cap, populate only same peers.
        if count<200 then
            receive("CHN1|H|gos|MAGE|60||100:8","GUILD","A Different")
            receive("CHN1|H|gos|MAGE|60||200:7","GUILD","A Distant")
        end
        local names={}
        for i=1,count do
            names[i]="Peer"..H.abc(i); receive(hello,"PARTY",names[i])
        end
        table.sort(names)
        local at=#H.log(); SlashCmdList.LAYERENEMIES("layer")
        local peers,more,lines={},{},{}
        for i=at+1,#H.log() do
            local line=H.log()[i]; lines[#lines+1]=line
            if line:find("same layer as you:",1,true) then peers[#peers+1]=line end
            if line:find("and %d+ more") then more[#more+1]=line end
        end
        eq(#peers,math.min(8,count),"at most eight peer lines")
        eq(#more,count>8 and 1 or 0,"one overflow line only when needed")
        if count>8 then yes(more[1]:find("and "..(count-8).." more",1,true)); eq(lines[#lines],more[1]) end
        for i,line in ipairs(peers) do yes(line:find("same layer as you: "..names[i].." (",1,true)) end
        eq(#lines,count==0 and 2 or 1+math.min(8,count)+(count>8 and 1 or 0))
        eq(#H.sent(),0); no(N.Main.error)
    end
end)

test("ChehulNet: 5000 deterministic fuzz inputs are bounded and silent",function()
    local N=H.load(); local C=N.ChehulNet; local st=C.new("Me")
    local seed=17711
    local function random(n) seed=(seed*48271)%2147483647; return seed%n end
    local accepted=0
    for i=1,5000 do
        local bytes={}
        for j=1,random(300) do bytes[j]=string.char(random(256)) end
        local text=table.concat(bytes)
        if i%3==0 then text="CHN1|H|gos|MAGE|"..random(300).."|craft:Enchanting,lfg|"..random(250)..":"..random(100000001) end
        local spent=0
        debug.sethook(function() spent=spent+1000; if spent>100000 then error("instruction budget") end end,"",1000)
        local ok,rec=pcall(C.parse,text)
        debug.sethook()
        yes(ok,"fuzz parser must terminate")
        if rec then
            accepted=accepted+1
            yes(#text<=255); yes(rec.level==nil or rec.level>=1 and rec.level<=255 and rec.level%1==0)
            yes(rec.zone==nil or rec.zone>=1 and rec.zone<=99999999 and rec.zone%1==0)
            yes(C.note(st,"Peer"..H.abc(i),rec,"GUILD",1000+i/100))
        end
        receive(text,"GUILD","Peer"..H.abc(i))
    end
    yes(accepted>1000,"valid-shaped fuzz reaches storage too")
    yes(N.Safe.count(st.entries)<=200); yes(#C.rows()<=200); eq(#H.sent(),0); no(N.Main.error)
end)

test("ChehulNet: live map changes withhold comparison and UI rows expire independently",function()
    local N=H.load(); H.establish(N)
    receive("CHN1|H|gos|MAGE|60||100:8")
    eq(N.ChehulNet.rows()[1].rel,"other")
    local location=N.Adapters.location; N.Adapters.location=function() return 200 end
    eq(N.ChehulNet.rows()[1].rel,nil)
    N.Adapters.location=location
    N.Main.store.zone=200
    eq(N.ChehulNet.rows()[1].rel,nil,"do not reuse another zone's own UID")
    N.Main.store.zone=100
    H.wall(H.wall()+399)
    N.Hosts.flh(N.Main.heard,"Cedar Vale",{map=100,key="8"},H.wall())
    eq(#N.ChehulNet.friendly(N.Main.candidates()),1)
    H.wall(H.wall()+1)
    local rows=N.ChehulNet.friendly(N.Main.candidates()); eq(#rows,1); eq(rows[1].chehulText,nil); yes(rows[1].hosts.FLH)
end)

test("ChehulNet: display context errors and missing clock cannot assert a relation",function()
    local N=H.load(); H.establish(N); receive("CHN1|H|gos|MAGE|60||100:8")
    local clock=GetTime; GetTime=function() return nil end
    eq(N.ChehulNet.rows()[1].rel,nil); GetTime=clock
    local api=C_Map; C_Map=setmetatable({},{__index=function() error("unreadable map API") end})
    local ok,rows=pcall(N.ChehulNet.rows); yes(ok); eq(#rows,0); C_Map=api
    local old=issecretvalue; issecretvalue=function(v) return v==100 or old(v) end
    rows=N.ChehulNet.rows(); for _,r in ipairs(rows) do eq(r.rel,nil) end
    issecretvalue=old; eq(N.ChehulNet.rows()[1].rel,"other"); no(N.Main.error)
end)

test("ChehulNet: exact HELLO grammar and optional layer",function()
    local N=H.load(); yes(N.ChehulNet,"TOC loads the independent reader")
    local parse=N.ChehulNet.parse
    local r=parse(hello); yes(r); eq(r.class,"MAGE"); eq(r.level,60); eq(r.map,100); eq(r.zone,7)
    for _,layer in ipairs({"0:0","","no:7","100:bogus","100:0","100:100000000","100:1.5","100:1e2","100:0x10"}) do
        r=parse("CHN1|H|gos|MAGE|60|craft:Enchanting,lfg|"..layer)
        yes(r); eq(r.zone,nil)
    end
    r=parse("CHN1|H|gos|MAGE|60|craft:Enchanting,lfg"); yes(r); eq(r.map,nil); eq(r.zone,nil)
    for _,level in ipairs({"","0","256","-1","1.2","1e2","nan","inf"}) do
        r=parse("CHN1|H|gos|MAGE|"..level.."||100:7"); yes(r); eq(r.level,nil)
    end
    for _,level in ipairs({1,255}) do eq(parse("CHN1|H|gos|MAGE|"..level.."||100:7").level,level) end
    eq(parse("CHN1|H|gos||60||99999999:99999999").zone,99999999)
    eq(parse("CHN1|H|gos|fake|60||100:7").class,nil)
    for _,bad in ipairs({"",false,42,{},H.secret,"CHN2|H|gos|MAGE|60||100:7","CHN1|h|gos|MAGE|60||100:7",
        "CHN1|H|gos|MAGE|60","CHN1|H|gos|MAGE|60||100:7|extra"}) do
        local ok,result=pcall(parse,bad); yes(ok); eq(result,nil)
    end
    eq(parse(nil),nil)
    local secretCheck=issecretvalue
    issecretvalue=function(v) return v==hello or secretCheck(v) end
    local ok,result=pcall(parse,hello)
    issecretvalue=secretCheck
    yes(ok); eq(result,nil,"a readable scalar marked secret must be refused by the parser itself")
    for i=0,31 do eq(parse(string.char(i)..hello),nil); eq(parse(hello..string.char(i)),nil) end
    eq(parse(hello..string.char(127)),nil)
    local base="CHN1|H||MAGE|60||100:7"
    local line="CHN1|H|"..string.rep("a",255-#base).."|MAGE|60||100:7"
    eq(#line,255); yes(parse(line)); eq(parse(line.."0"),nil)
end)
