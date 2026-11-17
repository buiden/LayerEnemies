-- Real dispatcher/Wire tests; only the client boundary is mocked by harness.lua.
local T=...
local test,eq,yes,no=T.test,T.eq,T.yes,T.no
local function start(N) T.click(N); T.deliver("WHO_LIST_UPDATE") end
local function ticks(n) for _=1,n do T.advance(1) end end

test("Hop fanout: 49 distinct requests within 45 rounds with eight initial then one per second",function()
    local N=T.load(); start(N); eq(#T.sent(),8)
    local first=T.time()
    for i=1,41 do T.advance(1); eq(#T.sent(),math.min(49,8+i)) end
    eq(#T.calls(),1); eq(#T.sent(),49); yes(T.time()-first<=45)
    local seen,batches={},{}
    for _,v in ipairs(T.sent()) do
        no(seen[v.target]); seen[v.target]=true
        eq(v.prefix,"LayerSwap"); eq(v.kind,"WHISPER")
        batches[v.at]=(batches[v.at] or 0)+1; yes(batches[v.at]<=8)
    end
    ticks(200); eq(#T.sent(),49); eq(N.Wire.queued(),0)
end)

test("Hop fanout: throttle leaves exact head until the next round",function()
    local N=T.load(); T.result(3); start(N)
    eq(#T.sent(),1); eq(T.sent()[1].target,"Seeker a")
    T.result(0); T.advance(.99); eq(#T.sent(),1)
    T.advance(.01); yes(T.sent()[2]); eq(T.sent()[2].target,"Seeker a")
    yes(N.Main.hopAnyState.round.asked["seeker a"])
end)

test("Hop fanout: permanent throttling makes at most 45 rounds",function()
    local N=T.load(); local attempts=0; local send=N.Wire.send
    N.Wire.send=function(...) attempts=attempts+1; return send(...) end
    T.result(3); start(N); ticks(100)
    eq(attempts,45); eq(N.Main.hopAnyState.round.phase,"wait")
    eq(#T.sent(),4,"per-target Wire cap also counts refused client attempts")
    ticks(200); eq(attempts,45)
end)

test("Hop fanout: same-zone rows precede other-zone rows without discarding them",function()
    local N=T.load()
    T.rows({{fullName="Away Peer",area="Durotar"},{fullName="Me",area="Ashenvale"},
        {fullName="Local Peer",area="Ashenvale"},{fullName="local peer-TestRealm",area="Ashenvale"},
        {fullName="Host Peer",area="Durotar"},{fullName="Bad123",area="Ashenvale"}})
    T.loaded("LayerSwap",true)
    LayerSwapDB={book={["Host Peer"]={host=true,at=time(),zone=200}}}
    start(N); eq(#T.sent(),3)
    eq(T.sent()[1].target,"Host Peer"); eq(T.sent()[2].target,"Local Peer"); eq(T.sent()[3].target,"Away Peer")
end)

test("Hop fanout: raw fiftieth row is never a replacement for unreadable rows",function()
    local N=T.load(); local rows={}
    for i=1,49 do rows[i]={fullName="Bad123",area="Ashenvale"} end
    rows[50]={fullName="Valid Peer",area="Ashenvale"}; T.rows(rows)
    start(N); ticks(50); eq(#T.sent(),0)
end)

test("Hop fanout: named requests and other prefixes keep their five token cap",function()
    local N=T.load()
    for i=1,6 do
        local ok=N.Wire.send("LayerSwap","inv layer <LS 100 want 8000-0>","WHISPER","Named "..T.abc(i),{prio="click"})
        eq(ok,i<=5)
    end
    eq(#T.sent(),5)
    N=T.load()
    for i=1,6 do
        local ok=N.Wire.send("LEGW1","ordinary"..i,"GUILD",nil,{prio="click",hopAny=true})
        eq(ok,i<=5,"hop marker cannot widen another prefix")
    end
    eq(#T.sent(),5); eq(N.Wire.QUEUE_MAX,40); eq(N.Wire.PAUSE,30); eq(N.Wire.OFFLINE,3600)
end)

test("Hop fanout: direct hop budget cannot exceed eight burst sixty per minute or four per target",function()
    local N=T.load()
    local function send(name,opts) return N.Wire.send("LayerSwap","inv layer <LS 100 not 7086-0>","WHISPER",name,opts or {prio="click",hopAny=true}) end
    for i=1,9 do eq(send("Budget "..T.abc(i)),i<=8) end
    for i=1,52 do T.advance(1); yes(send("Later "..T.abc(i))) end
    T.advance(1); no(send("Sixtyone Peer")); eq(#T.sent(),60)
    N=T.load()
    for i=1,5 do eq(send("Same Peer"),i<=4) end
    N=T.load()
    for i=1,6 do eq(send("Own "..T.abc(i),{prio="own",hopAny=true}),i<=5) end
end)

-- Lifecycle and protocol fallback: authorization stays scoped to one click.
test("Hop fanout: stopped click is blocked at nine seconds and allowed at ten",function()
    local N=T.load(); start(N); N.Main.hopAnyStop()
    T.advance(9); T.click(N); eq(#T.calls(),1)
    T.advance(1); T.click(N); eq(#T.calls(),2)
end)
test("Hop fanout: hosting reply does not end queue but any nonfailed invite does",function()
    local N=T.load(); start(N); T.reply("Seeker a")
    ticks(1); eq(#T.sent(),9)
    T.deliver("PARTY_INVITE_REQUEST","Unasked Person"); ticks(45)
    eq(#T.sent(),9); eq(#T.accepts(),0)
end)
for _,event in ipairs({"stop","GROUP_ROSTER_UPDATE","PLAYER_ENTERING_WORLD","ZONE_CHANGED_NEW_AREA","ZONE_CHANGED"}) do
    test("Hop fanout: cancellation "..event.." cannot resume",function()
        local N=T.load(); start(N)
        if event=="stop" then SlashCmdList.LAYERENEMIES("hop stop") else T.deliver(event) end
        ticks(200); eq(#T.sent(),8); no(N.Main.hopAnyState.round)
    end)
end
test("Hop fanout: session six-hour suppression and known-book bypass",function()
    local N=T.load(); local before=LayerEnemiesDB; start(N); ticks(170)
    eq(N.Safe.count(N.Main.hopAnyState.quiet),49)
    T.click(N); T.deliver("WHO_LIST_UPDATE"); ticks(10); eq(#T.sent(),49)
    T.loaded("LayerSwap",true); LayerSwapDB={book={["Seeker a"]={host=false,at=time()}}}
    T.click(N); T.deliver("WHO_LIST_UPDATE"); eq(#T.sent(),50); eq(T.sent()[50].target,"Seeker a")
    no(before.quiet); no(before.hopAnyState)
end)
test("Hop fanout: known offline skip is 600 seconds without changing other offline sends",function()
    local N=T.load(); T.loaded("LayerSwap",true)
    LayerSwapDB={book={["Seeker a"]={host=true,at=time()}}}
    T.rows({{fullName="Seeker a",area="Ashenvale"}})
    _G.ERR_CHAT_PLAYER_NOT_FOUND_S="No player named '%s' is currently playing."
    start(N); local first=T.time()
    T.deliver("CHAT_MSG_SYSTEM","No player named 'Seeker a' is currently playing.")
    N.Main.hopAnyStop(); T.time(first+599); T.click(N); T.deliver("WHO_LIST_UPDATE"); eq(#T.sent(),1)
    T.time(first+609); T.click(N); T.deliver("WHO_LIST_UPDATE"); eq(#T.sent(),2)
    yes(N.Wire.offlineUntil("Seeker a",T.time()),"ordinary sends still skip for one hour")
end)
test("Hop fanout: unknown same-zone host reasked once at plus three without exclusion",function()
    local N=T.load(); T.rows({{fullName="Unknown Host",area="Ashenvale"}}); start(N)
    T.reply("Unknown Host","h","-"); ticks(2); eq(#T.sent(),1)
    ticks(1); eq(#T.sent(),2); eq(T.sent()[2].text,"inv layer <LS 100 25.0,75.0>")
    ticks(20); eq(#T.sent(),2)
end)
test("Hop fanout: known alternative host delays unknown retry until plus ten",function()
    local N=T.load(); T.rows({{fullName="Unknown Host",area="Ashenvale"},{fullName="Known Host",area="Ashenvale"}})
    start(N); T.reply("Unknown Host","h","-"); T.reply("Known Host")
    ticks(9); eq(#T.sent(),2); ticks(1); eq(#T.sent(),3); eq(T.sent()[3].target,"Unknown Host")
end)
test("Hop fanout: late unknown answer caught at plus ten and fallback throttle is spent",function()
    local N=T.load(); T.rows({{fullName="Unknown Host",area="Ashenvale"}}); start(N)
    ticks(4); T.reply("Unknown Host","h","-"); T.result(3)
    ticks(6); eq(#T.sent(),2); T.result(0); ticks(20); eq(#T.sent(),2)
end)
test("Hop fanout: wrong-zone nonhosts same replies and known-failed hosts never fallback",function()
    local N=T.load(); start(N)
    T.reply("Seeker a","h","-","200"); T.reply("Seeker b","-","-")
    T.reply("Seeker c","h","-"); T.deliver("CHAT_MSG_ADDON","LayerSwap","same","WHISPER","Seeker c")
    N.HopAny.failed(N.Main.hopAnyState,"Seeker d",T.time())
    T.reply("Seeker d","h","-")
    T.deliver("PARTY_INVITE_REQUEST","Seeker d"); ticks(55)
    eq(#T.sent(),49,"known-failed invite cannot cancel fanout")
end)

-- Additional independent boundaries (not masked by another budget).
test("Hop fanout: half-second duplicate pumps consume no extra attempt",function()
    local N=T.load(); start(N); local count=N.Main.hopAnyState.round.count
    T.advance(.5); N.Main.hopAnyPump(); eq(N.Main.hopAnyState.round.count,count)
end)
test("Hop fanout: donor book gone timestamp blocks for six hundred seconds",function()
    local N=T.load(); T.loaded("LayerSwap",true)
    LayerSwapDB={book={["Seeker a"]={host=true,at=time(),gone=time()}}}
    T.rows({{fullName="Seeker a",area="Ashenvale"}})
    start(N); eq(#T.sent(),0); T.advance(600); start(N); eq(#T.sent(),1)
end)
test("Hop fanout: skip map never grows beyond cap even on offline results",function()
    local N=T.load(); local st=N.Main.hopAnyState
    for i=1,300 do st.quiet["other "..T.abc(i)]=T.time() end
    T.result(12); start(N); yes(N.Safe.count(st.quiet)<=300)
    ticks(45); yes(N.Safe.count(st.quiet)<=300)
end)
test("Hop fanout: offline unknown target remains suppressed for six hours",function()
    local N=T.load(); T.rows({{fullName="Unknown Peer",area="Ashenvale"}})
    T.result(12); start(N); N.Main.hopAnyStop(); T.result(0)
    T.advance(3601); start(N); eq(#T.sent(),1)
    T.advance(18000); start(N); eq(#T.sent(),2)
end)
test("Hop fanout: known-offline expiry is exact and ordinary expiry remains one hour",function()
    local N=T.load(); local at=T.time(); N.Wire.markOffline("Known Peer",at)
    yes(N.Wire.offlineUntil("Known Peer",at+599,600))
    no(N.Wire.offlineUntil("Known Peer",at+600,600))
    yes(N.Wire.offlineUntil("Known Peer",at+600))
end)
test("Hop fanout: failed automatic hop retains the host realm without penalizing its namesake",function()
    local N=T.load(); T.rows({{fullName="Known Host-Elsewhere",area="Ashenvale"}})
    start(N); T.deliver("PARTY_INVITE_REQUEST","Known Host-Elsewhere"); eq(#T.accepts(),1)
    T.group(true); T.unit("party1",{name="Known Host",realm="Elsewhere",leader=true})
    T.deliver("GROUP_ROSTER_UPDATE"); T.advance(30.1); eq(#T.leaves(),1)
    yes(N.HopAny.isFailed(N.Main.hopAnyState,"known host-elsewhere",T.time()))
    no(N.HopAny.isFailed(N.Main.hopAnyState,"known host",T.time()))
end)
test("Hop fanout: unknown-layer host answer earns next-click priority in memory only",function()
    local N=T.load(); T.rows({{fullName="Other Peer",area="Ashenvale"},{fullName="Unknown Host",area="Ashenvale"}})
    start(N); T.reply("Unknown Host","h","-"); N.Main.hopAnyStop(); T.advance(61)
    T.rows({{fullName="New Peer",area="Ashenvale"},{fullName="Unknown Host",area="Ashenvale"}})
    start(N); eq(T.sent()[3].target,"Unknown Host")
end)
test("Hop fanout: duplicate fallback pumps never exceed eight attempts per second",function()
    local N=T.load(); start(N)
    for _,s in ipairs(T.sent()) do T.reply(s.target,"h","-") end
    ticks(41)
    for _,s in ipairs(T.sent()) do T.reply(s.target,"h","-") end
    local attempts=0; local send=N.Wire.send
    N.Wire.send=function(...) attempts=attempts+1; return send(...) end
    ticks(3); local before=attempts
    for _=1,10 do N.Main.hopAnyPump() end
    eq(attempts,before); yes(before<=8)
end)

test("Hop fanout: cooldown and invite wait start at first accepted whisper",function()
    local N=T.load(); T.click(N); T.advance(4); T.deliver("WHO_LIST_UPDATE")
    N.Main.hopAnyStop(); T.advance(6); T.click(N); eq(#T.calls(),1)
    T.advance(4); T.click(N); eq(#T.calls(),2)
    N.Main.hopAnyStop()
    N=T.load(); start(N); ticks(119); yes(N.Main.hopAnyState.round)
    ticks(2); no(N.Main.hopAnyState.round)
end)

test("Hop fanout: SavedVariables exactly unchanged after sends responses fallback and stop",function()
    local function snapshot(v)
        if type(v)~="table" then return type(v)..":"..tostring(v) end
        local parts={}; for k,item in pairs(v) do parts[#parts+1]=snapshot(k).."="..snapshot(item) end
        table.sort(parts); return "{"..table.concat(parts,",").."}"
    end
    local N=T.load(); local before=snapshot(LayerEnemiesDB)
    start(N); T.reply("Seeker a","h","-"); ticks(60); N.Main.hopAnyStop()
    eq(snapshot(LayerEnemiesDB),before)
end)

local function uiFixture()
    local N=T.load(); local fs={}; local routed=false
    C_FriendList.SetWhoToUi=function(v) routed=v end
    for _,name in ipairs({"FriendsFrame","LFGWhoListFrame","WhoFrame"}) do
        local f={events={WHO_LIST_UPDATE=true},scripts={},shows=0,shown=false}
        function f:IsEventRegistered(e) return self.events[e]==true end
        function f:RegisterEvent(e) self.events[e]=true end
        function f:UnregisterEvent(e) self.events[e]=nil end
        function f:IsShown() return self.shown end
        function f:IsVisible() return self.shown end
        function f:GetScript(e) return self.scripts[e] end
        function f:SetScript(e,fn) self.scripts[e]=fn end
        f.scripts.OnEvent=function(self,event) if event=="WHO_LIST_UPDATE" then self.shows=self.shows+1 end end
        f.original=f.scripts.OnEvent; fs[#fs+1]=f; _G[name]=f
        -- Friends before our dispatcher, other frames after: both event orders must be safe.
        if name=="FriendsFrame" then table.insert(T.frames(),1,f) else table.insert(T.frames(),f) end
    end
    return N,fs,function() return routed end
end
local function registrations(fs,value)
    for _,f in ipairs(fs) do eq(f:IsEventRegistered("WHO_LIST_UPDATE"),value) end
end
local function restored(fs)
    registrations(fs,true)
    for _,f in ipairs(fs) do eq(f:GetScript("OnEvent"),f.original) end
end
test("Hop fanout: WHO hush before query and restoration after result in either event order",function()
    local N,fs,routed=uiFixture(); T.click(N); yes(routed()); registrations(fs,false)
    T.deliver("WHO_LIST_UPDATE"); T.drain(); restored(fs); no(routed())
    for _,f in ipairs(fs) do eq(f.shows,0) end
    T.manual(); T.deliver("WHO_LIST_UPDATE"); for _,f in ipairs(fs) do eq(f.shows,1) end
end)
for _,exit in ipairs({"timeout","stop","invite","error","reload"}) do
    test("Hop fanout: WHO restores registrations on "..exit.." and leaves manual search usable",function()
        local N,fs,routed=uiFixture()
        if exit=="error" then C_FriendList.SendWho=function() error("client refused") end end
        T.click(N); if exit~="error" then registrations(fs,false) end
        if exit=="timeout" then ticks(5)
        elseif exit=="stop" then N.Main.hopAnyStop()
        elseif exit=="invite" then T.deliver("PARTY_INVITE_REQUEST","Unasked Person")
        elseif exit=="reload" then T.deliver("PLAYER_LOGOUT") end
        registrations(fs,true)
        if exit=="timeout" or exit=="stop" or exit=="invite" then
            T.deliver("WHO_LIST_UPDATE"); T.drain(); for _,f in ipairs(fs) do eq(f.shows,0) end
        end
        T.drain(); restored(fs); no(routed()); eq(#T.sent(),0)
    end)
end
test("Hop fanout: no WHO result releases late guard at thirty seconds",function()
    local N,fs,routed=uiFixture(); T.click(N); ticks(5); registrations(fs,true)
    ticks(24); yes(routed()); ticks(1); restored(fs); no(routed())
    T.manual(); T.deliver("WHO_LIST_UPDATE"); for _,f in ipairs(fs) do eq(f.shows,1) end
end)
for _,delay in ipairs({1,6}) do
    test("Hop fanout: player WHO during pending or late lease wins at "..delay.." seconds",function()
        local N,fs=uiFixture(); T.click(N); ticks(delay); T.manual(); restored(fs)
        T.deliver("WHO_LIST_UPDATE"); ticks(40)
        for _,f in ipairs(fs) do eq(f.shows,1) end
        eq(#T.sent(),0); no(N.Main.hopAnyState.round)
    end)
end
test("Hop fanout: optional WHO APIs and throwing frames never strand other frames",function()
    for _,mode in ipairs({"missingSet","throwSet","missingFrame","throwFrame","noTimer"}) do
        local N,fs=uiFixture(); local timer=C_Timer.After
        if mode=="missingSet" then C_FriendList.SetWhoToUi=nil
        elseif mode=="throwSet" then C_FriendList.SetWhoToUi=function() error("blocked") end
        elseif mode=="missingFrame" then _G.FriendsFrame=nil
        elseif mode=="noTimer" then C_Timer.After=nil
        else fs[1].IsEventRegistered=function() error("unreadable") end end
        T.click(N); T.deliver("WHO_LIST_UPDATE"); no(N.Main.error,mode.." at query exit")
        C_Timer.After=timer; T.advance(31)
        for _,f in ipairs(fs) do yes(f.events.WHO_LIST_UPDATE,mode); eq(f:GetScript("OnEvent"),f.original,mode) end
        no(N.Main.error,mode)
    end
end)
test("Hop fanout: no event is detached when its restoration API is missing",function()
    local N,fs=uiFixture(); fs[1].RegisterEvent=nil
    T.click(N); yes(fs[1].events.WHO_LIST_UPDATE)
    N.Main.hopAnyStop(); ticks(30); yes(fs[1].events.WHO_LIST_UPDATE)
end)
test("Hop fanout: missing secure hook falls back without blocking manual WHO",function()
    local N,fs=uiFixture(); _G.hooksecurefunc=nil
    T.click(N); registrations(fs,true)
    T.manual(); T.deliver("WHO_LIST_UPDATE")
    for _,f in ipairs(fs) do eq(f.shows,1) end
end)
test("Hop fanout: result-handler error restores UI without displaying our result",function()
    local N,fs=uiFixture(); T.click(N)
    N.Adapters.whoRows=function() error("result failure") end
    T.deliver("WHO_LIST_UPDATE"); T.drain(); restored(fs)
    for _,f in ipairs(fs) do eq(f.shows,0) end
    no(N.Main.hopAnyState.round); eq(#T.sent(),0)
end)

test("Hop fanout: unregistered frame and visible player window retain their prior state",function()
    local N,fs,routed=uiFixture(); fs[1].events.WHO_LIST_UPDATE=nil; fs[2].shown=true
    T.click(N); T.deliver("WHO_LIST_UPDATE"); T.drain()
    no(fs[1].events.WHO_LIST_UPDATE); yes(fs[2].shown); yes(routed())
    eq(fs[1]:GetScript("OnEvent"),fs[1].original)
end)
