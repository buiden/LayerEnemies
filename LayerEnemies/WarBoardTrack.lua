-- WarBoard 1.6.3 protocol facts only. No donor code or direct client sends.
local _,N=...
local T,S,BN,Cd={},N.Safe,N.BNet,N.Codec
N.WarBoardTrack=T
T.on=true
local records,owed,waits={},{},{}
local admitted,attempted={},{}
local high
local function guid(v) return S.str(v,80) and v:match("^Player%-%d+%-%x+$") and v or nil end
local function room(list,now)
    for i=#list,1,-1 do if now-list[i]>=60 then table.remove(list,i) end end
    return #list<6
end
local function owes(g)
    for _,v in ipairs(owed) do if v==g then return true end end
    return false
end
local function remember(g)
    if owes(g) then return end
    owed[#owed+1]=g
    if #owed>40 then
        local old=table.remove(owed,1) -- bounded, oldest outstanding first
        records[old]=nil -- do not retain a forgotten debt's session record forever
        if owed.attempts then owed.attempts[old]=nil end
    end
end
local function settled(g)
    for i=#owed,1,-1 do if owed[i]==g then table.remove(owed,i) end end
    if owed.attempts then owed.attempts[g]=nil end
    records[g]=nil
end
-- Main owns the per-character GUID array. Optional attempts[guid] counts
-- enforce the lifetime cap across reloads; no names, accounts, clocks or evidence.
function T.load(raw)
    owed={}; records={}; waits={}; admitted={}; attempted={}; high=nil; T.closed=nil; T.on=true
    if S.tab(raw) then
        local keys={}
        for k in pairs(raw) do
            if #keys>=1000 then break end
            if S.num(k) and k>=1 and k%1==0 then keys[#keys+1]=k end
        end
        table.sort(keys)
        for _,k in ipairs(keys) do local g=guid(raw[k]); if g then remember(g) end end
    end
    for _,g in ipairs(owed) do
        local n=S.tab(raw) and S.tab(raw.attempts) and S.num(raw.attempts[g])
        if n then
            n=math.min(6,math.max(0,math.floor(n)))
            owed.attempts=owed.attempts or {}; owed.attempts[g]=n
        end
        records[g]={guid=g,closing=true,sent=true,tries=0,total=n or 0}
    end
    return owed
end
function T.hasOwed() return #owed>0 end
function T.owedAccount(id)
    local who=BN.who(id,true)
    return who and guid(who.guid) and owes(who.guid) and records[who.guid] or nil
end
function T.needsHandshake(id)
    local r=T.owedAccount(id)
    return r and r.closing and not r.accepted and (r.total or 0)<6
end
function T.ready(peer,now)
    return peer and peer.proof and peer.proof>(peer.hello or 0) and peer.proofAt
        and now>=peer.proofAt and now-peer.proofAt<1200
end
function T.size()
    local n=0; for _,r in pairs(records) do if not r.closing then n=n+1 end end; return n
end
local function allowed(ctx)
    return not T.closed and T.on and ctx and N.Main.sharing() and N.Sources.enabled("warboard")
        and N.Net.allowed("warboard","public") and S.str(ctx.version,40)
end
local function target(st,id,ctx,cleanup)
    local peer=st.peers[id]
    if not peer or (not cleanup and not peer.confirmed) or peer.rs~=ctx.rs or ctx.now<peer.at or ctx.now-peer.at>=1200 then return nil end
    if cleanup and not T.ready(peer,ctx.now) then return nil end
    local who=BN.who(id,true)
    local full=who and N.OpenMap.bnName(who.name,who.realm)
    if not full or not guid(who.guid) or not S.str(who.name,80) or not N.Find.name(who.name)
        or who.faction==ctx.faction or who.faction~=peer.faction or N.Invite.key(full)~=peer.key
        or N.Main.isMe(full) or (not cleanup and N.Adapters.ignored(full)) then return nil end
    return {id=id,name=who.name,full=full,key=N.Invite.key(full),guid=who.guid,faction=who.faction,handshake=peer.at}
end
local function picks(st,ctx)
    local candidates,out={},{}
    for id in pairs(st.peers) do local who=target(st,id,ctx); if who then candidates[#candidates+1]=who end end
    for i,entry in ipairs(N.Main.find.entries) do
        if i>20 then break end
        local match,count=nil,0
        local one={byName={[entry.shortKey]={entry}},homeKey=N.Main.find.homeKey}
        for _,who in ipairs(candidates) do
            if N.Find.tracked(one,who.full) then match=who; count=count+1 end
        end
        if count==1 then out[match.guid]=match end
    end
    return out
end
local function retire(r,now,renewal)
    if r.closing then return end
    BN.cancel("warboard",r) -- only this target; H/A and withdrawals survive
    r.pending=nil
    if r.sent then
        r.closing=true; r.tries=0
        waits[r.guid]={at=now or high or 0,handshake=r.handshake,renewal=renewal}
    else records[r.guid]=nil end
end
function T.stop(logout)
    for _,r in pairs(records) do retire(r,high) end
    if logout then
        T.closed=true
        -- Best effort through the same queue and budgets, never a direct flush.
        local ctx=N.Adapters.warboardContext()
        T.tick(N.WarBoard.state,ctx)
        if ctx then BN.pump(ctx.now) end
    end
end
function T.changed(find)
    if not N.Main or find~=N.Main.find then return end
    for _,r in pairs(records) do
        if not r.closing and not N.Find.tracked(find,r.full) then retire(r,high) end
    end
end
function T.set(on) T.on=on==true; if not T.on then T.stop() end end
function T.note(ev)
    local r=records[ev.guid]
    if r and r.sent and not r.closing and ev.tag=="FBLP" and ev.kind=="self"
        and N.Invite.key(ev.name)==r.key and S.num(ev.at) and (not r.location or ev.at>r.location) then
        r.location=ev.at -- newest observed position; old/out-of-order frames do not refresh it
    end
end
-- Called only after full FBLP validation, independently of Find/source admission.
function T.roster(ev,roster,id,ctx)
    local r=records[ev.guid]
    local who=id and BN.who(id,true)
    local me=N.Adapters.warboardSelf()
    if not r or not r.closing or not r.sent or not who or who.guid~=r.guid or not me
        or (r.hunter and r.hunter~=me.guid) or ev.kind~="self" or ev.at>ctx.now
        or (r.unlast and ev.at<=r.unlast) or (not r.unlast and (r.total or 0)<6) then return end
    if r.rosterAt and ev.at<=r.rosterAt then return end
    r.rosterAt=ev.at
    for _,hunter in ipairs(roster) do
        if hunter.guid==me.guid then
            r.accepted=nil -- observed failure invalidates the silence fallback
            local peer=N.WarBoard.state.peers[id]
            -- Retire only the proof used by the contradicted send. Later
            -- rosters cannot erase a fresh exchange still waiting to be used.
            if peer and peer.proof==r.unproof and (not peer.proofAt or peer.proofAt<=ev.at) then peer.proof=nil end
            return
        end
    end
    settled(r.guid)
end
local function retryDue(r,now)
    if r.accepted or (r.total or 0)>=6 then return false end
    if r.window and now-r.window>=600 then r.window=nil; r.tries=0 end
    return (r.tries or 0)<3 and (not r.unlast or now-r.unlast>=60)
end
local function frame(kind,r,me,ctx)
    local sentAt=N.Adapters.warboardTime()
    if not sentAt or not S.str(ctx.version,40) then return nil end
    local d={targetGuid=r.guid,hunterGuid=me.guid,hunterName=me.name,hunterFaction=ctx.faction,
        faction=ctx.faction,sentAt=sentAt}
    if kind=="FBAK" then d.targetName=r.name end
    local plain=Cd.aceWrite({t=kind,v=5,rs=ctx.rs,av="LayerEnemies/"..ctx.version,senderName=me.name,d=d})
    if not plain then return nil end
    local raw=Cd.deflateStored(plain); local encoded=raw and Cd.addonEncode(raw)
    return encoded and "WBF1|D|"..encoded or nil
end
-- Exact, private outstanding withdrawal frame, NOT a generic 'owed' bypass.
-- BN and Wire consult this at admission and dispatch, even with source off.
function T.withdrawal(id,text)
    for _,r in pairs(records) do
        if r.closing and r.sent and r.id==id and r.text==text and owes(r.guid) then return true end
    end
    return false
end
local function due(r,now)
    if not r.location then return (r.asks or 0)<3 and (not r.last or now-r.last>=6) end
    return now-r.location>=45 and now-r.location<=300 and (not r.last or now-r.last>=45)
end
local function enqueue(st,r,kind,me,ctx)
    if r.pending then return end
    if kind=="FBAK" then
        if not due(r,ctx.now) or not room(admitted,ctx.now) then return end
    elseif not retryDue(r,ctx.now) then return end
    local text=frame(kind,r,me,ctx)
    if not text or #text>4000 then return end
    r.text=text
    local prio=kind=="FBUN" and "owed" or "own"
    if not BN.allowed("warboard",r.id,"WarBoard",text,prio) then r.text=nil; return end
    r.pending=true
    local queued=BN.send("warboard",r.id,"WarBoard",text,prio,function(now)
        local live=N.Adapters.warboardContext(); local self=N.Adapters.warboardSelf()
        if records[r.guid]~=r or not live or not self or self.guid~=me.guid or self.name~=me.name
            or live.rs~=ctx.rs or live.faction~=ctx.faction or now<ctx.now or (high and now<high) then return false end
        local who=target(st,r.id,live,kind=="FBUN")
        if not who or who.guid~=r.guid then return false end
        if kind=="FBAK" then
            local picked=allowed(live) and not r.closing and picks(st,live)[r.guid]
            if not picked or picked.id~=r.id or not due(r,now) or not room(attempted,now) then return false end
        elseif not r.closing or not retryDue(r,now) then return false end
        -- Refresh sentAt after a long queue wait; no stale clock gets onto wire.
        local fresh=frame(kind,r,self,live); if not fresh then return false end
        r.text=fresh
        if kind=="FBAK" then
            attempted[#attempted+1]=now; r.last=now; r.asks=(r.asks or 0)+1
            r.sent=true; remember(r.guid) -- before the call, including ambiguous failures
        else
            r.tries=(r.tries or 0)+1; r.unlast=now; r.window=r.window or now
            r.unproof=st.peers[r.id].proof
            r.total=(r.total or 0)+1
            owed.attempts=owed.attempts or {}; owed.attempts[r.guid]=r.total
        end
        return fresh
    end,r,function(ok)
        r.pending=nil; r.text=nil
        if kind=="FBUN" and ok then
            r.accepted=r.unlast -- sent, unverified; never settle on API acceptance
        end
    end)
    if queued then if kind=="FBAK" then admitted[#admitted+1]=ctx.now end
    else r.pending=nil; r.text=nil end
end
function T.tick(st,ctx)
    if not ctx then return end -- paused: debts survive combat/instance/unreadable client
    if high and ctx.now<high then return end
    high=ctx.now
    local me=N.Adapters.warboardSelf()
    local selected=allowed(ctx) and me and picks(st,ctx) or {}
    for g,r in pairs(records) do
        if r.closing and r.accepted and ctx.now-r.accepted>=900 then settled(g) end
        if not r.closing then
            local who=selected[g]
            if not who or who.id~=r.id or r.hunter~=(me and me.guid) or r.rs~=ctx.rs then retire(r,ctx.now)
            elseif r.location and ctx.now-r.location>300 then retire(r,ctx.now,true)
            elseif not r.location and (r.asks or 0)>=3 and ctx.now-r.last>=6 then retire(r,ctx.now) end
        end
    end
    if not me then return end
    -- Recover GUID debts through confirmed accounts, never a name lookup/frame.
    for _,r in pairs(records) do
        if r.closing then
            for id in pairs(st.peers) do
                local who=target(st,id,ctx,true)
                if who and who.guid==r.guid then r.id=id; break end
            end
        end
    end
    for g,w in pairs(waits) do if ctx.now-w.at>=600 then waits[g]=nil end end
    for g,who in pairs(selected) do
        local w=waits[g]
        if not records[g] and T.size()<20 and (not w or ctx.now-w.at>=300
            or (w.renewal and who.handshake>w.at)) then
            who.hunter=me.guid; who.rs=ctx.rs; records[g]=who
        end
    end
    local list={}; for _,r in pairs(records) do list[#list+1]=r end
    table.sort(list,function(a,b)
        if a.closing~=b.closing then return a.closing==true end
        if (a.last or -math.huge)~=(b.last or -math.huge) then return (a.last or -math.huge)<(b.last or -math.huge) end
        return a.guid<b.guid
    end)
    for _,r in ipairs(list) do
        if r.closing then
            if r.id and (not r.hunter or r.hunter==me.guid) and (not r.rs or r.rs==ctx.rs) then
                local who=target(st,r.id,ctx,true)
                if who and who.guid==r.guid then enqueue(st,r,"FBUN",me,ctx) end
            end
        else enqueue(st,r,"FBAK",me,ctx) end
    end
end
