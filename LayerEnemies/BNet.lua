-- Shared Battle.net identity/transport seam. No discovery or send without a caller.
local _,N=...
local BN,A,S={},N.Adapters,N.Safe
N.BNet=BN
local cache,cacheAt={},nil
local function safe() return not A.inCombat() and A.inInstance()==false end
local function copies(rows)
    local out={}
    for _,r in ipairs(rows) do
        out[#out+1]={id=r.id,name=r.name,realm=r.realm,faction=r.faction,friend=r.friend,club=r.club}
    end
    return out
end
function BN.peers(now)
    now=S.num(now)
    if not now or not safe() then return {} end
    if cacheAt and now>=cacheAt and now-cacheAt<30 then return copies(cache) end
    local out,seen={},{}
    local function add(r,friend,club)
        if not r or seen[r.id] then return end
        seen[r.id]=true
        out[#out+1]={id=r.id,name=r.name,realm=r.realm,faction=r.faction,friend=friend,club=club}
    end
    for _,r in ipairs(A.bnFriendGames() or {}) do add(r,true) end
    for _,club in ipairs(A.clubs() or {}) do
        for _,member in ipairs(A.clubMemberIds(club.id) or {}) do
            local account=A.clubPeer(club.id,member)
            if account then add(A.bnAccount(account),false,club.id) end
        end
    end
    cache,cacheAt=out,now
    return copies(cache)
end

-- A single bounded queue and rolling attempt ledger, shared by every network.
-- Queued is admission only; clients can still refuse at dispatch. No retries.
local queue,times,lastSend,timer,serial={},{},nil,false,0
local shares={overlord=8,wanted=4,warboard=10}
local function refuse(net) N.Sources.count(net,"refused"); return false end
function BN.allowed(net,id,prefix,text,prio)
    if not S.str(net,32) or not S.str(prefix,16) or not S.num(id) or id<1 or id%1~=0
        or S.secret(text) or type(text)~="string" or #text<1 or #text>4096
        or not S.str(prio,16) or (prio~="owed" and prio~="own") then return false end
    -- C2 extends the built Overlord receiver in place; its tick-only registration
    -- may use its legacy prefix without seizing Main's receive ownership.
    local authorized=N.Sources.authorized(net,prefix)
        or (net=="overlord" and prefix=="OverlordF" and N.Sources.enabled(net))
    if not authorized or not N.Main.sharing() or N.Net.consent()~="public" or not safe() then return false end
    local ok,why=N.Net.allowed(net,"public")
    return ok or (why=="stand down" and prio=="owed")
end
local dispatch
function BN.dispatching(net,id,prefix,text,prio,fn)
    return dispatch and dispatch.net==net and dispatch.id==id and dispatch.prefix==prefix
        and dispatch.text==text and dispatch.prio==prio and dispatch.fn==fn or false
end
local function deliver(q)
    local ok,fn=pcall(function()
        local api=_G.C_BattleNet
        if not S.tab(api) then return nil end
        return S.clean(api.SendGameData)
    end)
    if not ok or type(fn)~="function" then return false end
    q.fn=fn; dispatch=q
    local called,result=pcall(N.Wire.bnet,q.net,q.id,q.prefix,q.text,q.prio,fn)
    dispatch=nil; q.fn=nil
    return called and result==true
end
local schedule
function BN.pump(now)
    now=S.num(now)
    if not now then return end
    -- Privacy and safety are rechecked even while a budget is exhausted.
    for i=#queue,1,-1 do
        local q=queue[i]
        if not BN.allowed(q.net,q.id,q.prefix,q.text,q.prio) or not BN.who(q.id) then
            refuse(q.net); table.remove(queue,i)
        end
    end
    local keep={}
    for _,stamp in ipairs(times) do if now-stamp.at<60 then keep[#keep+1]=stamp end end
    times=keep
    if #times<30 and (not lastSend or now-lastSend>=1) then
        table.sort(queue,function(a,b)
            if a.prio~=b.prio then return a.prio=="owed" end
            return a.seq<b.seq
        end)
        for i,q in ipairs(queue) do
            local count=0
            for _,stamp in ipairs(times) do if stamp.net==q.net then count=count+1 end end
            if count<(shares[q.net] or 30) then
                table.remove(queue,i)
                lastSend=now; times[#times+1]={at=now,net=q.net} -- spend before the client, including failures
                if deliver(q) then N.Sources.count(q.net,"sent") else refuse(q.net) end
                break -- never catch up several frames after a long pause
            end
        end
    end
    if #queue>0 and not schedule() then BN.cancel() end
end
schedule=function()
    if timer then return true end
    local ok,result=pcall(function()
        local t=_G.C_Timer
        if not S.tab(t) or type(S.clean(t.After))~="function" then return false end
        t.After(1,function() timer=false; BN.pump(S.call(GetTime)) end)
        return true
    end)
    timer=ok and result==true
    return timer
end
function BN.send(net,id,prefix,text,prio)
    if S.secret(prio) then return refuse(net) end
    prio=prio==nil and "own" or prio
    if not BN.allowed(net,id,prefix,text,prio) or not BN.who(id) or #queue>=60 or not schedule() then return refuse(net) end
    serial=serial+1
    queue[#queue+1]={net=net,id=id,prefix=prefix,text=text,prio=prio,seq=serial}
    return true
end
function BN.cancel(net)
    for i=#queue,1,-1 do
        if not net or queue[i].net==net then refuse(queue[i].net); table.remove(queue,i) end
    end
end
function BN.queued() return #queue end

function BN.who(id)
    if not safe() then return nil end
    local r=A.bnGame(id)
    if r then return {name=r.name,realm=r.realm,faction=r.faction} end
end
