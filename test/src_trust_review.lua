-- Independent round-2 review probes. Invented identities, mock client only.
local H=...
local function clearUnits() H.units().target=nil; H.units().mouseover=nil end
local function readKey(N,server,uid)
    for _,n in ipairs({31,32}) do
        H.units().target={guid="Creature-0-"..server.."-0-"..uid.."-"..n.."-ABCDEF",player=false}
        H.deliver("PLAYER_TARGET_CHANGED"); H.drain()
    end
    clearUnits()
end
local function state(N) return N.Trust.state(N.Main.store,H.clock()) end

H.test("Second opinion: peer joins an existing group with old claim",function()
    local N=H.load(); H.establish(N); clearUnits()
    H.roster({{"Birch Scout-TestRealm",true}}); H.deliver("GUILD_ROSTER_UPDATE")
    H.clock(100); H.units().party1={name="Oak Walker",leader=true}; H.group(true); H.deliver("GROUP_ROSTER_UPDATE")
    H.clock(101); H.readLayer(N,7); clearUnits()
    H.clock(110); H.deliver("CHAT_MSG_ADDON","LEGW1","H|1|9000|100","GUILD","Birch Scout"); H.drain()
    H.eq(N.Main.trustClaims["birch scout"].at,110); H.eq(state(N),"known")
    H.clock(120); H.units().party2={name="Birch Scout"}; H.deliver("GROUP_ROSTER_UPDATE"); H.drain()
    H.clock(121); H.readLayer(N,7); clearUnits()
    H.clock(181); N.Main.poll()
    print("SECOND existing-group localJoin="..tostring(N.Main.groupJoinedAt).." peerJoin=120 claimAt="..N.Main.trustClaims["birch scout"].at.." state="..state(N).." reason="..tostring(N.Main.store.trust.blind))
    H.no(N.Main.error); H.eq(state(N),"known","pre-peer-join claim must not cause sticky blindness")
end)

for _,delay in ipairs({1,11,30}) do
H.test("Second opinion: delayed same-key confirmation "..delay,function()
    local N=H.load(); H.establish(N); clearUnits()
    BuloLayerForever={current="7086-7",Radar={seen={}}}; H.clock(100); N.Main.poll()
    H.clock(120); BuloLayerForever.current="9000-9"; N.Main.poll()
    H.eq(#N.Main.store.trust.changes,1)
    H.clock(120+delay); readKey(N,9000,9)
    local afterConfirmation=#N.Main.store.trust.changes
    H.clock(170); BuloLayerForever.current="10000-10"; N.Main.poll()
    print("SECOND corroboration delay="..delay.." afterSameKey="..afterConfirmation.." afterSecondChange="..#N.Main.store.trust.changes.." state="..state(N).." reason="..tostring(N.Main.store.trust.blind))
    H.no(N.Main.error); H.eq(afterConfirmation,1,"confirmation of same transition is not a new change"); H.eq(state(N),"known")
end)
end

for _,newServer in ipairs({7086,9000}) do
H.test("Second opinion: queued H expiry recovery "..newServer,function()
    local N=H.load(); H.establish(N); clearUnits(); H.clock(300)
    N.Net.SHIP.we=true; N.Net.setConsent("public")
    C_Club={GetGuildClubId=function() return 789 end}
    N.Main.emb.rows["alder vale"]={name="Alder Vale",guild="456",minor=19,heardAt=300,presenceAt=300}
    N.Main.emb.mine={"g456"}; N.Main.emb.announced="D|g456"; N.Main.emb.announcedAt=300
    H.eq(N.Main.embassyWhy(),nil); H.yes(N.WeEmb.partner(N.Main.emb,"Alder Vale",300))
    for i=1,4 do H.yes(N.Wire.send("WEFF1","K|"..i.."|2|5","WHISPER","Alder Vale",{net="we",prio="owed"})) end
    H.yes(N.Main.weHello("request")); H.yes(N.Wire.queued()>0)
    local first=#H.sent()
    H.clock(311); N.Main.poll(); H.eq(state(N),"unknown")
    H.clock(312); readKey(N,newServer,newServer==7086 and 7 or 9); H.eq(state(N),"known")
    H.result(function()
        local line=H.sent()[#H.sent()]
        line.reviewOwnAtDispatch=N.Trust.own(N.Main.store,H.clock())
        return 0
    end)
    local sent,bad=0,0
    for _=1,70 do H.advance(1) end
    for i=first+1,#H.sent() do local line=H.sent()[i]
        if line.prefix=="WEFF1" and line.text:sub(1,2)=="W|" then
            local d=assert(N.Protocol.decode(line.text))
            if d.origin=="Me" and d.inner.type=="H" then
                sent=sent+1
                print("SECOND queued-H regained="..newServer.." ownAtDispatch="..tostring(line.reviewOwnAtDispatch).." wireLayer="..d.inner.layer.." sentAt="..line.at.." text="..line.text)
                if d.inner.layer~=0 and d.inner.layer~=newServer then bad=bad+1 end
            end
        end
    end
    H.no(N.Main.error); H.eq(sent,1,"queued H delivered"); H.eq(bad,0,"old own H layer must not revive under a different trusted key")
end)
end

for _,mode in ipairs({"stable","expiry"}) do
H.test("Second opinion: Find polling cap with held popup "..mode,function()
    local N=H.load(); H.establish(N); clearUnits()
    local M,F,K=N.Main,N.Find,N.Known
    for i=1,20 do H.yes(F.add(M.find,"Tracked "..H.abc(i))) end
    for i=1,300 do
        K.put(M.find.known,{name=(i<=5 and "Tracked " or "Untracked ")..H.abc(i),zone=100,at=H.clock(),source="spy",kind="seen",spotter="Cedar Scout"},H.clock())
    end
    -- Open within the real 30-second popup lifetime of the impending expiry.
    H.clock(300); M.poll(); H.yes(N.Popup.frame:IsShown())
    local visits,lookups,calls=0,0,0
    local original,index,rows=pairs,M.find.known.byName,M.findRows
    local counted={[M.find.known.entries]=true}
    for _,bucket in original(index) do counted[bucket]=true end
    M.find.known.byName=setmetatable({},{__index=function(_,key) lookups=lookups+1; return index[key] end})
    M.findRows=function(...) calls=calls+1; return rows(...) end
    pairs=function(t)
        local iter,s,k=original(t)
        if not counted[t] then return iter,s,k end
        return function(a,b) local key,value=iter(a,b); if key~=nil then visits=visits+1 end; return key,value end,s,k
    end
    H.clock(mode=="expiry" and 311 or 301)
    local before=#H.sent(); local ok,err=pcall(M.poll)
    pairs=original; M.find.known.byName=index; M.findRows=rows
    print("SECOND find mode="..mode.." calls="..calls.." visits="..visits.." lookups="..lookups.." sends="..(#H.sent()-before).." popupShown="..tostring(N.Popup.frame:IsShown()).." state="..state(N))
    H.yes(ok,err); H.no(M.error); H.yes(visits+lookups<=25,"unchanged 25-operation polling cap")
end)
end
