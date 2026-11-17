-- WarBoard Forever 1.6.3 protocol facts only; independent implementation.
-- No donor code, ledger, subscriptions, forwarding or SavedVariables. See THIRD_PARTY.md.
local _,N=...
local W,S,BN,Src={},N.Safe,N.BNet,N.Sources
N.WarBoard=W
local rules={normal=true,pvp=true,rp=true,rppvp=true,hardcore=true}
local function refuse() Src.count("warboard","refused"); return false end
local function recent(at,now,gap) return at and now-at<gap end -- rollback cannot reopen a gate
local function pruneTimes(t,now)
    for i=#t,1,-1 do if now-t[i]>=60 then table.remove(t,i) end end
end
local function slots(t,now,ttl)
    local n=0
    for key,r in pairs(t) do
        if now-r.at>=ttl then t[key]=nil else n=n+1 end
    end
    return n
end
function W.new()
    return {peers={},rates={},hellos={},answers={},answerSent={},helloSent={},parts={},seen={},seenOrder={},seenBytes=0,shards={}}
end
W.state=W.new()
local function context() return N.Adapters.warboardContext() end
local function identity(id,ctx)
    local who=BN.who(id)
    if not S.tab(who) or not S.str(who.faction,16) or who.faction==ctx.faction then return nil end
    if who.faction~="Alliance" and who.faction~="Horde" then return nil end
    local name=N.OpenMap.bnName(who.name,who.realm)
    if not name then return nil end
    return {name=name,key=N.Invite.key(name),faction=who.faction}
end
local function input(st,key,ctx)
    if st.high and ctx.now<st.high then return false end
    st.high=ctx.now
    local r=st.rates[key]
    if not r then
        if slots(st.rates,ctx.now,60)>=200 then return false end
        r={at=ctx.now,times={}}; st.rates[key]=r
    end
    pruneTimes(r.times,ctx.now)
    if #r.times>=120 then return false end
    r.at=ctx.now; r.times[#r.times+1]=ctx.now
    return true
end
-- The ONLY outbound grammar. The protocol/rules digits describe the wire, not
-- WarBoard's identity or gameplay implementation. LE has no gameplay rules: 0.
local function send(st,id,cmd,ctx)
    if cmd~="H" and cmd~="A" then return refuse() end
    if not ctx.version then return refuse() end
    local text="WBF1|"..cmd.."|5|"..ctx.rs.."|LayerEnemies/"..ctx.version.."|0"
    local prio=cmd=="A" and "owed" or "own"
    if not BN.allowed("warboard",id,"WarBoard",text,prio) then return refuse() end
    if cmd=="H" then
        local r=st.hellos[id]
        if r and recent(r.at,ctx.now,600) then return false end
        if not r and slots(st.hellos,ctx.now,600)>=200 then return refuse() end
        st.hellos[id]={at=ctx.now} -- charge attempts, including queue refusal; no retry
    else
        pruneTimes(st.answers,ctx.now)
        if #st.answers>=6 then return refuse() end
        st.answers[#st.answers+1]=ctx.now
    end
    local rs,faction=ctx.rs,ctx.faction
    return BN.send("warboard",id,"WarBoard",text,prio,function(now)
        local live=context()
        if not live or live.rs~=rs or live.faction~=faction or not identity(id,live) or now<ctx.now or now-ctx.now>=120 then return false end
        -- Actual-attempt caps as well as enqueue caps: a delayed cohort must not
        -- burst through the answer cap when the shared queue opens again.
        if cmd=="A" then
            pruneTimes(st.answerSent,now)
            if #st.answerSent>=6 then return false end
            st.answerSent[#st.answerSent+1]=now
        else
            local r=st.helloSent[id]
            if r and recent(r.at,now,600) then return false end
            if not r and slots(st.helloSent,now,600)>=200 then return false end
            st.helloSent[id]={at=now}
        end
        return true
    end)
end
local Cd=N.Codec
local function integer(v,lo,hi)
    v=S.num(v); return v and v%1==0 and v>=lo and v<=hi and v or nil
end
local function faction(v) return S.str(v,16) and (v=="Horde" or v=="Alliance") and v or nil end
local function optionalString(v,max)
    return not S.secret(v) and (v==nil or v=="" or S.str(v,max)~=nil)
end
local function array(t,max)
    if not S.tab(t) then return nil end
    local count=0
    for k in pairs(t) do
        if not integer(k,1,max) then return nil end
        count=count+1; if count>max then return nil end
    end
    for i=1,count do if t[i]==nil then return nil end end
    return count
end
local function stamp(v,ctx,age)
    v=integer(v,1,4000000000)
    if not v or v>ctx.wall+120 or ctx.wall-v>=age then return nil end
    return ctx.now-math.max(0,ctx.wall-v)
end
-- Envelopes and opaque bytes are bounded independently of compression ratio.
function W.decode(encoded)
    if S.secret(encoded) or type(encoded)~="string" or #encoded<1 or #encoded>262144 then return nil end
    local raw=Cd.addonDecode(encoded)
    local text=raw and Cd.inflate(raw,262144)
    return text and Cd.aceRead(text) or nil
end
function W.assemble(st,text,id,now)
    for key,r in pairs(st.parts) do if now<r.at or now-r.at>=90 then st.parts[key]=nil end end
    local direct=text:match("^WBF1|D|(.*)$")
    if direct then return direct end
    local token,i,n,chunk=text:match("^WBF1|F|([%x%-]+)|(%d+)|(%d+)|(.*)$")
    i,n=tonumber(i),tonumber(n)
    if not token or #token>80 or not integer(n,2,64) or not integer(i,1,n) then return nil end
    local key=id..":"..token
    local r=st.parts[key]
    if r and r.n~=n then st.parts[key]=nil; return nil end
    if not r then
        if S.count(st.parts)>=16 then return nil end
        r={at=now,n=n,size=0,count=0,chunks={}}; st.parts[key]=r
    end
    if r.chunks[i]~=nil then return nil end -- first copy wins, no age refresh
    r.size=r.size+#chunk
    if r.size>262144 then st.parts[key]=nil; return nil end
    r.chunks[i]=chunk; r.count=r.count+1
    if r.count==n then st.parts[key]=nil; return table.concat(r.chunks) end
end
local function origin(name,carrier)
    name=N.Invite.name(name)
    if not name then return nil,false end
    local key=N.Invite.key(name)
    if key==N.Invite.key(carrier) then return carrier,true end
    -- Payloads omit realm; transport identity may add it, never the other way round.
    if not name:find("-",1,true) and N.Find.fold(name)==N.Find.fold(carrier:match("^([^%-]+)") or carrier) then return carrier,true end
    return name,false
end
local function event(name,guid,fac,ctx,carrier,kind,bridge)
    local own; name,own=origin(name,carrier)
    if not name or (guid~=nil and not S.str(guid,80)) or not faction(fac) or fac==ctx.faction then return nil end
    if kind~="cached" and (bridge or not own) then kind="relayed" end
    return {net="warboard",name=name,guid=guid,faction=fac,kind=kind,via=carrier,got=ctx.now}
end
local function knownName(name,ctx)
    local M=N.Main
    if not M or not M.find or M.isMe(name) or N.Adapters.ignored(name) then return false end
    local _,_,_,watch=N.Watch.match(M.watch,name,ctx.now)
    return N.Find.tracked(M.find,name) or #(watch or {})>0
end
local function shardText(v,max,digits)
    local num=S.num(v)
    if num and num>=0 and num<=999999999999 and num%1==0 then v=string.format("%.0f",num) end
    local s=S.str(v,max)
    return s and (not digits or s:match("^%d+$")) and s or nil
end
local function location(st,t,d,e,ctx,carrier,bridge,cached)
    if not S.tab(d) then return false end
    local ev
    if t=="SHRD" then
        local first,last=S.str(d.name,36),S.str(d.realm,36)
        local seq=integer(d.sentAt,1,4000000000000)
        if not first or not last or not seq or math.abs(ctx.wall-math.floor(seq/1000))>120
            or (e.ttl~=nil and not integer(e.ttl,0,1)) or S.secret(d.clear)
            or (d.clear~=nil and type(d.clear)~="boolean")
            or S.secret(d.isGroupLeader) or (d.isGroupLeader~=nil and type(d.isGroupLeader)~="boolean") then return false end
        ev=event(first.." "..last,d.guid,d.faction,ctx,carrier,"self",bridge)
        if not ev or not knownName(ev.name,ctx) then return false end
        -- SHRD realm is a surname. Its wire identity stays the same when a
        -- different carrier adds/omits the transport realm suffix. Keep one
        -- sequence and one admitted cache spelling, including after a clear.
        local key=N.Invite.key(first.." "..last); local old=st.shards[key]
        if old and seq<=old.seq then return false end
        if not old and slots(st.shards,ctx.now,3600)>=300 then return false end
        if old then ev.name=old.name end
        ev.tag="SHRD"; ev.clear=d.clear; ev.expiresAt=ctx.now+180
        if not d.clear then
            ev.zone=S.str(d.zone,100); ev.shard=shardText(d.shard,12,true)
            ev.map=d.mapID~=nil and integer(d.mapID,1,999999) or nil
            if not ev.zone or not ev.shard or (d.mapID~=nil and not ev.map) then return false end
        end
        if not Src.offer(ev) then return false end
        st.shards[key]={seq=seq,at=ctx.now,name=ev.name}; return true
    elseif t=="FBLP" then
        local x,y=S.num(d.worldX),S.num(d.worldY)
        local at=stamp(d.sentAt,ctx,121)
        local n=array(d.roster,100)
        if not S.str(d.targetGuid,80) or not x or not y or math.abs(x)>100000000 or math.abs(y)>100000000
            or not integer(d.instanceID,0,100000) or not integer(d.rank,0,14) or not at
            or not S.str(d.zone,100) or not optionalString(d.subZone,100) or n==nil
            or S.secret(d.approximate) or (d.approximate~=nil and type(d.approximate)~="boolean") then return false end
        for i=1,n do
            local r=d.roster[i]
            if not S.tab(r) or not S.str(r.guid,80) or not S.str(r.name,80)
                or (r.faction~=nil and not faction(r.faction)) then return false end
        end
        ev=event(d.targetName,d.targetGuid,d.faction,ctx,carrier,"self",bridge)
        if not ev then return false end
        ev.at=at; ev.zone=d.zone; ev.shard=d.shard~=nil and shardText(d.shard,20,false) or nil
        if d.shard~=nil and not ev.shard then return false end
        ev.pos="enemy"
        ev.note="own position; "..d.zone..(d.subZone and d.subZone~="" and ("; "..d.subZone) or "")
            ..(d.approximate and "; approximate coordinates; zone labels are current" or "")
        if not knownName(ev.name,ctx) then return false end
        local pos=N.Adapters.worldMapPos(x,y,d.instanceID)
        if pos then ev.zone,ev.map,ev.x,ev.y=pos.map,pos.map,pos.x,pos.y end
    elseif t=="FREC" then
        local at=stamp(d.t,ctx,3600)
        if not S.str(d.id,160) or not S.str(d.guid,80) or not S.str(d.zone,100) or not at
            or not integer(d.creditDelta,-100000,100000) or not integer(d.contributionDelta,0,100000)
            or not integer(d.kills,1,50) or (d.rv~=nil and not integer(d.rv,0,1000000)) then return false end
        if d.atype~="pvp_kill" and d.atype~="witnessed_pvp_kill" then return false end
        for _,key in ipairs({"objId","obj","contractId","claimWitnessId","zone","targetName","targetGuid",
            "claimSourceGuid","witnessName","witnessGuid","claimVerification"}) do
            local limit=(key=="zone" and 100) or (key=="claimVerification" and 20)
                or ((key=="objId" or key=="obj" or key=="contractId" or key=="claimWitnessId") and 160) or 80
            if not optionalString(d[key],limit) then return false end
        end
        if S.secret(d.isRepeat) or (d.isRepeat~=nil and type(d.isRepeat)~="boolean")
            or (d.rewardWarCredit~=nil and not integer(d.rewardWarCredit,0,100000)) then return false end
        if d.clearedBountyIds~=nil then
            local n=array(d.clearedBountyIds,200); if not n then return false end
            local ids={}
            for i=1,n do
                local id=S.str(d.clearedBountyIds[i],160)
                if not id or ids[id] then return false end
                ids[id]=true
            end
        end
        local kind="self"
        if d.atype=="witnessed_pvp_kill" then
            if not S.str(d.witnessName,80) or not S.str(d.witnessGuid,80) or not S.str(d.targetGuid,80)
                or not d.targetGuid:match("^Player%-") or d.witnessGuid==d.guid or d.targetGuid==d.guid
                or d.creditDelta~=0 or d.kills~=1 or not integer(d.rv,3,1000000) then return false end
            local _,direct=origin(d.witnessName,carrier)
            kind=direct and not bridge and "witness" or "relayed"
        end
        ev=event(d.name,d.guid,d.faction,ctx,carrier,cached and "cached" or kind,bridge)
        if not ev then return false end
        -- Witness attribution is to the witness, not the killer's own carrier.
        if not cached and kind=="witness" then ev.kind="witness" end
        ev.at=at; ev.zone=d.zone; ev.note="killer zone; unverified record"
    elseif t=="FBLC" then
        local at=stamp(d.sentAt,ctx,3600)
        if not at or not S.str(d.targetGuid,80) or not S.str(d.zone,100) then return false end
        ev=event(d.targetName,d.targetGuid,d.faction,ctx,carrier,"cached",bridge)
        if not ev then return false end
        ev.at=at; ev.zone=d.zone; ev.note="cached zone"
    else return false end
    ev.tag=t
    return Src.offer(ev)
end
local types={SHRD=true,FBLP=true,FREC=true,FBLC=true,FCBD=true}
local function payload(st,encoded,ctx,carrier,bridge,bnetFaction)
    if st.seen[encoded] then return false end
    local e=W.decode(encoded)
    if not S.tab(e) or not types[S.str(e.t,16)] or not S.num(e.v) or e.v>5 or e.rs~=ctx.rs
        or (e.scope~=nil and e.scope~="FACTION") or not S.tab(e.d) then return refuse() end
    local fac=e.faction~=nil and e.faction or e.d.faction
    if not faction(fac) or (bnetFaction and fac~=bnetFaction) then return refuse() end
    local accepted=false
    if e.t=="FCBD" then
        local d=e.d; local n=array(d.entries,40)
        if not n or not S.str(d.requestId,160) or not S.str(d.relayGuid,80) or not N.Invite.name(d.relayName)
            or not integer(d.page,1,100000) or not S.num(d.rulesVersion) then return refuse() end
        local inner=d.kind=="bounty_locations" and "FBLC" or (d.kind=="activity" or d.kind=="witnessed_kills") and "FREC"
        if inner then for i=1,n do
            if location(st,inner,d.entries[i],e,ctx,carrier,true,true) then accepted=true end
        end end
    else accepted=location(st,e.t,e.d,e,ctx,carrier,bridge,false) end
    -- Remember only accepted evidence: validation failures cannot poison replay.
    if not accepted then return false end
    while #st.seenOrder>=512 or st.seenBytes+#encoded>1048576 do
        local old=table.remove(st.seenOrder,1); st.seen[old]=nil; st.seenBytes=st.seenBytes-#old
    end
    st.seen[encoded]=true; st.seenOrder[#st.seenOrder+1]=encoded; st.seenBytes=st.seenBytes+#encoded
    return true
end
function W.bnet(st,text,id,ctx)
    if not ctx or S.secret(text) or type(text)~="string" or #text>4000 or #text<1 or not S.num(id) or id<1 or id%1~=0 then return refuse() end
    local who=identity(id,ctx)
    if not who or not input(st,"bn:"..id,ctx) then return refuse() end
    local cmd,proto,rs,version,rv=text:match("^WBF1|([HA])|(%d+)|([^|]+)|([^|]*)|(%d+)$")
    if cmd then
        if proto~="5" or not rules[rs] or not S.str(version,80) or #rv>7 then st.peers[id]=nil; return refuse() end
        if rs~=ctx.rs then
            st.peers[id]=nil
            if cmd=="H" then send(st,id,"A",ctx) end
            return false
        end
        if not st.peers[id] and slots(st.peers,ctx.now,1200)>=200 then return refuse() end
        st.peers[id]={at=ctx.now,key=who.key,faction=who.faction,rs=rs}
        if cmd=="H" then send(st,id,"A",ctx) end
        return true
    end
    local peer=st.peers[id]
    if not peer or peer.rs~=ctx.rs or peer.key~=who.key or peer.faction~=who.faction
        or ctx.now<peer.at or ctx.now-peer.at>=1200 then return refuse() end
    local encoded=W.assemble(st,text,id,ctx.now)
    return encoded and payload(st,encoded,ctx,who.name,false,who.faction) or false
end
function W.addon(st,prefix,text,dist,sender,ctx)
    if not ctx or (prefix~="WarBoard" and prefix~="WarBoardBN") or S.secret(text) or type(text)~="string" or #text>255
        or (dist~="GUILD" and dist~="PARTY" and dist~="RAID" and dist~="CHANNEL") then return refuse() end
    sender=N.Invite.name(sender)
    if not sender or N.Main.isMe(sender) then return false end
    local key=prefix..":"..dist..":"..N.Invite.key(sender)
    if not input(st,"addon:"..N.Invite.key(sender),ctx) then return refuse() end
    st.comm=st.comm or {}; st.comm.now=ctx.now
    local encoded=Cd.aceCommJoin(st.comm,key,text)
    return encoded and payload(st,encoded,ctx,sender,prefix=="WarBoardBN") or false
end
function W.tick(st,ctx)
    if not ctx or (st.high and ctx.now<st.high) then return end
    if recent(st.scan,ctx.now,60) then return end
    if not Src.enabled("warboard") or not N.Main.sharing() or not N.Net.allowed("warboard","public") then return end
    st.scan=ctx.now
    local selected,seen=0,{}
    for _,r in ipairs(BN.peers(ctx.now)) do
        if S.tab(r) and S.num(r.id) and r.id>0 and r.id%1==0 and not seen[r.id]
            and (r.faction=="Horde" or r.faction=="Alliance") and r.faction~=ctx.faction then
            seen[r.id]=true; selected=selected+1
            if selected>20 then break end
            if identity(r.id,ctx) then send(st,r.id,"H",ctx) end
        end
    end
end
Src.register{name="warboard",prefixes={"WarBoard","WarBoardBN"},counters={},
    onBNet=function(prefix,text,id) if prefix=="WarBoard" then W.bnet(W.state,text,id,context()) end end,
    onAddon=function(prefix,text,dist,sender) W.addon(W.state,prefix,text,dist,sender,context()) end,
    tick=function() W.tick(W.state,context()) end}
N.Net.LIST.warboard.name="WarBoard"
N.Net.LIST.warboard.standDown="WarBoard"
