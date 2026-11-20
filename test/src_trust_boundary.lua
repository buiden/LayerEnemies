local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function npc(n,key)
    local a,b=key:match("^(%d+)%-(%d+)$")
    H.units().target={guid="Creature-0-"..a.."-0-"..b.."-"..n.."-ABC",player=false}
    H.deliver("PLAYER_TARGET_CHANGED"); H.drain()
end

test("Trust boundary: late LayerSwap answers carry no layer display",function()
    local N=H.hopLoad(); H.clock(120)
    H.deliver("CHAT_MSG_ADDON","LFSw","L 9000|100|h","GUILD","Host Cedar")
    local c=N.Main.candidates()[1]; yes(N.Main.hopHostTo(c,N.Main.hostPreview(c)))
    SlashCmdList.LAYERENEMIES("blind on"); local first=#H.log()
    H.deliver("CHAT_MSG_ADDON","LayerSwap","heard "..N.Adapters.ownIdentity().."|9000-0|100|h","WHISPER","Host Cedar")
    yes(#H.log()>first)
    for i=first+1,#H.log() do no(H.log()[i]:find("9000",1,true)); no(H.log()[i]:find("their layer",1,true)) end
end)

for _,mode in ipairs({"unknown","blind"}) do
    test("Trust boundary: "..mode.." Wanted bridge status hides keys keeps counts",function()
        local N=H.load(); H.clock(120)
        if mode=="blind" then SlashCmdList.LAYERENEMIES("blind on") end
        N.Wanted.state.far[71]={at=120,rows={{m=100,l="1-0-6",n=3}}}
        local text=table.concat(N.Sources.lines("wanted")," ")
        no(text:find("1-0-6",1,true)); yes(text:find("map 100",1,true)); yes(text:find(": 3",1,true))
    end)
end

for _,mode in ipairs({"unknown","blind"}) do
    test("Trust boundary: "..mode.." relays names but not a remote layer on R",function()
        local N=H.load(); H.establish(N); H.clock(120)
        H.deliver("CHAT_MSG_ADDON","WEFF1","H|1.6.6|100|9000|1|19","PARTY","Birch Scout")
        H.deliver("CHAT_MSG_ADDON","WEFF1","C|42|100|0.200|0.300|9000|1|100","PARTY","Birch Scout")
        local _,pending=next(N.Main.relay.pending); yes(pending,"relay owed before trigger")
        eq(pending.record.layer.value,"9000"); eq(pending.record.layer.ns,"server")
        if mode=="blind" then SlashCmdList.LAYERENEMIES("blind on")
        else N.Trust.read(N.Main.store,H.clock(),nil,nil) end
        H.advance(6); N.Main.relayTick()
        local count=0
        for _,s in ipairs(H.sent()) do if s.prefix=="LEGW1" and s.text:sub(1,2)=="R|" then
            local r=N.Relay.decode(s.text,"Carrier Cedar",H.clock()); yes(r)
            eq(r.layer.ns,"unknown"); eq(r.count,1); eq(r.x,.2); count=count+1
        end end
        eq(count,1); no(N.Main.error)
    end)
end

test("Trust boundary: same confirmed key refresh on one later NPC read",function()
    local N=H.load(); H.establish(N)
    H.clock(200); npc(3,"7086-7")
    H.clock(499); N.Main.poll(); eq(N.Trust.own(N.Main.store,H.clock()),"7086-7")
    H.clock(500); N.Main.poll(); eq(N.Trust.own(N.Main.store,H.clock()),nil)
end)

test("Trust boundary: queued War Effort own sync cannot leak its cached layer",function()
    local N=H.load(); H.establish(N); H.clock(120)
    N.Net.SHIP.we=true; N.WeNet.rand=function() return .1 end
    N.WeNet.keep(N.Main.we,{rid=42,t=119,server=100,map=100,x=.2,y=.3,layer=7086,count=1,enemies={}})
    H.deliver("CHAT_MSG_ADDON","WEFF1","Y|1|600","GUILD","Birch Scout")
    yes(#N.Main.we.waiting>0,"sync admitted before trigger")
    SlashCmdList.LAYERENEMIES("blind on"); H.advance(7); N.Main.weTick()
    local count=0
    for _,s in ipairs(H.sent()) do if s.prefix=="WEFF1" and s.kind=="WHISPER" and s.text:sub(1,2)=="C|" then
        eq(N.Protocol.decode(s.text).layer,0); count=count+1
    end end
    eq(count,1); no(N.Main.error)
end)

test("Trust boundary: active hop fanout stops before another layered send",function()
    local N=H.hopLoad(); H.hopClick(N); H.deliver("WHO_LIST_UPDATE")
    yes(N.Main.hopAnyState.round); local first=#H.sent()
    SlashCmdList.LAYERENEMIES("blind on"); H.advance(2)
    eq(N.Main.hopAnyState.round,nil)
    eq(#H.sent(),first,"old not-key ask is not sent in blind")
    no(N.Main.error)
end)

for _,mode in ipairs({"unknown","blind"}) do
    test("Trust boundary: "..mode.." hides existing source shard details",function()
        local N=H.load(); H.establish(N); H.clock(120); N.Main.track("Cedar Vale")
        yes(N.Sources.offer({net="wanted",kind="witness",name="Cedar Vale",zone="Ashenvale",map=100,
            x=.2,y=.3,shard="998877",got=120,at=120,via="Birch Scout"}))
        yes(N.Main.findText(N.Main.findRows()[1]):find("998877",1,true),"known positive")
        if mode=="blind" then SlashCmdList.LAYERENEMIES("blind on")
        else H.clock(311); N.Main.poll() end
        no(N.Main.findText(N.Main.findRows()[1]):find("998877",1,true))
        no(N.Main.error)
    end)
end

test("Trust boundary: blind new Wanted and WarBoard claims discard shard only",function()
    for _,net in ipairs({"wanted","warboard"}) do
        local N=H.load(); H.establish(N); H.clock(120); N.Main.track("Cedar Vale")
        SlashCmdList.LAYERENEMIES("blind on")
        yes(N.Sources.offer({net=net,kind="witness",name="Cedar Vale",zone="Ashenvale",map=100,
            x=.2,y=.3,shard="998877",got=120,at=120,via="Birch Scout"}))
        local r=N.Known.get(N.Main.find.known,"Cedar Vale",120).reported
        eq(r.shard,nil); eq(r.zone,100); eq(r.x,.2)
        no(N.Main.findText(N.Main.findRows()[1]):find("998877",1,true)); no(N.Main.error)
    end
end)
