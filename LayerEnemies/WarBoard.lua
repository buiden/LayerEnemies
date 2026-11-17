-- WarBoard Forever 1.6.3 protocol facts only; independent implementation.
-- No donor code, ledger, forwarding or SavedVariables. Tracking is in WarBoardTrack.lua.
local _,N=...
local W,S,BN,Src={},N.Safe,N.BNet,N.Sources
N.WarBoard=W
local rules={normal=true,pvp=true,rp=true,rppvp=true,hardcore=true}
local controls={}
local function sequence(st) st.serial=(st.serial or 0)+1; return st.serial end
local function proof(st,peer,now)
    peer.proof=sequence(st); peer.proofAt=now
end
function W.handshake(id,text)
    return controls[id] and controls[id][text] and N.WarBoardTrack
        and N.WarBoardTrack.needsHandshake(id) and not N.Adapters.loaded("WarBoard") or false
end
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
local function byteWindow() return {times={},head=1,tail=0,bytes=0} end
local function byteRoom(r,now,cap)
    while r.head<=r.tail do
        local entry=r.times[r.head]
        if now-entry.at<10 then break end
        r.bytes=r.bytes-entry.bytes; r.times[r.head]=nil; r.head=r.head+1
    end
    if r.head>r.tail then r.times={}; r.head=1; r.tail=0 end
    return cap-r.bytes
end
local function spendBytes(r,now,cost)
    local last=r.times[r.tail]
    if last and last.at==now then last.bytes=last.bytes+cost
    else r.tail=r.tail+1; r.times[r.tail]={at=now,bytes=cost} end
    r.bytes=r.bytes+cost
end
local function channelSlots(rates)
    local n=0
    for _,r in pairs(rates) do if r.channel then n=n+1 end end
    return n
end
function W.new()
    return {peers={},rates={},hellos={},answers={},answerSent={},helloSent={},parts={},seen={},seenOrder={},seenBytes=0,shards={},
        decodeRates={},decodeAccounts={},decodeTotal=byteWindow(),decodeChannel=byteWindow(),frames={},frameOrder={}}
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
local function input(st,key,ctx,channel)
    if st.high and ctx.now<st.high then return false end
    st.high=ctx.now
    local r=st.rates[key]
    if not r then
        if slots(st.rates,ctx.now,60)>=200 or (channel and channelSlots(st.rates)>=100) then return false end
        r={at=ctx.now,times={},channel=channel}; st.rates[key]=r
    end
    if not channel then r.channel=nil end -- group/BN identities keep the reserved half
    pruneTimes(r.times,ctx.now)
    if #r.times>=120 then return false end
    r.at=ctx.now; r.times[#r.times+1]=ctx.now
    return true
end
-- The handshake outbound grammar (tracking owns FBAK/FBUN separately). The protocol/rules digits describe the wire, not
-- WarBoard's identity or gameplay implementation. LE has no gameplay rules: 0.
local function send(st,id,cmd,ctx)
    if cmd~="H" and cmd~="A" then return refuse() end
    if N.Adapters.loaded("WarBoard") then return false end
    if not ctx.version then return refuse() end
    local text="WBF1|"..cmd.."|5|"..ctx.rs.."|LayerEnemies/"..ctx.version.."|0"
    local prio=cmd=="A" and "owed" or "own"
    local debt=N.WarBoardTrack and N.WarBoardTrack.needsHandshake(id)
    local function permit(on)
        if not debt then return end
        if on then controls[id]=controls[id] or {}; controls[id][text]=(controls[id][text] or 0)+1
        elseif controls[id] then
            controls[id][text]=(controls[id][text] or 1)-1
            if controls[id][text]<=0 then controls[id][text]=nil end
            if not next(controls[id]) then controls[id]=nil end
        end
    end
    permit(true)
    local allowed=BN.allowed("warboard",id,"WarBoard",text,prio)
    permit(false)
    if not allowed then return refuse() end
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
    local peer=st.peers[id]; local hello=peer and peer.hello
    local sentAt
    permit(true)
    local queued=BN.send("warboard",id,"WarBoard",text,prio,function(now)
        local live=context()
        if not live or live.rs~=rs or live.faction~=faction or not identity(id,live) or now<ctx.now or now-ctx.now>=120
            or N.Adapters.loaded("WarBoard") then return false end
        if cmd=="A" and peer and (st.peers[id]~=peer or peer.hello~=hello) then return false end
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
        sentAt=now
        return true
    end,nil,function(ok)
        permit(false)
        if cmd=="A" and peer then
            peer.answerPending=nil
            if ok and st.peers[id]==peer and peer.hello==hello then
                peer.needAnswer=nil; proof(st,peer,sentAt)
                -- An answered H alone does not supply received-A request eligibility.
            end
        end
    end)
    if not queued then permit(false)
    elseif cmd=="A" and peer then peer.answerPending=true end
    return queued
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
-- Byte ceilings for the supported location schemas, including Ace escaping.
-- See notes/warboard.md for producer-field arithmetic and the FCBD scope.
local decodeCaps={SHRD=2048,FBLP=40960,FREC=73728,FBLC=2048,FCBD=98304}
function W.decode(encoded,allowance)
    if S.secret(encoded) or type(encoded)~="string" or #encoded<1 or #encoded>262144 then return nil,0 end
    local limit=math.min(98304,allowance or 98304)
    local raw=Cd.addonDecode(encoded)
    -- t lives INSIDE the compressed table and pairs order is unspecified. Read
    -- only top-level tokens as output arrives; never trust a nested t or scan
    -- a whole unbounded inflate. Until t arrives the largest supported cap wins.
    local depth,key,typeKey,token=0,true,false,nil
    local function choose(part)
        part=part:gsub("[%c ]","")
        local at=1
        while at<=#part do
            local pos=part:find("^",at,true)
            local tail=part:sub(at,pos and pos-1 or #part)
            if token then token=(token..tail):sub(1,9) end -- only tags / short type names needed
            if not pos then break end
            if token then
                local tag=token:sub(1,1)
                if tag=="T" then
                    if depth==1 then key=not key; typeKey=false end
                    depth=depth+1
                elseif tag=="t" then depth=depth-1
                elseif depth==1 and tag~="f" then
                    if key then typeKey=token=="St"; key=false
                    else
                        if typeKey then
                            limit=math.min(limit,decodeCaps[token:sub(2)] or 0)
                            return limit,true
                        end
                        key=true
                    end
                end
            end
            token=""; at=pos+1
        end
        return limit,false
    end
    local text,used
    if raw then text,used=Cd.inflate(raw,limit,choose) end
    -- Failures spend the remaining selected ceiling (not zero on early abort).
    -- This bounds repeated invalid streams and work not represented by output.
    local cost=text and #text or math.max(used or 0,limit)
    local e=text and Cd.aceRead(text)
    if not S.tab(e) or not decodeCaps[e.t] or #text>decodeCaps[e.t] then return nil,cost end
    return e,cost
end
local function decodeRate(rates,key,now)
    local r=rates[key]
    if not r then
        if slots(rates,now,10)>=200 then return nil end
        r={at=now,times={},bytes=0,attempts=0}; rates[key]=r
    end
    for i=#r.times,1,-1 do
        if now-r.times[i].at>=10 then
            local old=table.remove(r.times,i)
            r.bytes=r.bytes-old.bytes; r.attempts=r.attempts-(old.expensive and 1 or 0)
        end
    end
    if r.bytes>=131072 then return nil end
    return r
end
local function frameHash(encoded)
    -- Two independent rolling residues plus length; binary-safe and no payload
    -- retention. This is a short-lived refusal fingerprint, not authentication.
    local a,b=5381,52711
    for i=1,#encoded do
        local v=encoded:byte(i); a=(a*33+v)%2147483647; b=(b*131+v)%2147483629
    end
    return #encoded..":"..string.format("%x:%x",a,b)
end
local function frameKey(st,encoded,now)
    while #st.frameOrder>0 do
        local key=st.frameOrder[1]
        if now-st.frames[key].at<60 then break end
        st.frames[key]=nil; table.remove(st.frameOrder,1)
    end
    return frameHash(encoded)
end
local function rememberFrame(st,key,now)
    if not st.frames[key] then
        if #st.frameOrder>=512 then st.frames[table.remove(st.frameOrder,1)]=nil end
        st.frames[key]={at=now}; st.frameOrder[#st.frameOrder+1]=key
    end
end
local function duplicate()
    Src.count("warboard","deduped")
    return refuse()
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
        local owned=0
        for _,part in pairs(st.parts) do if part.owner==id then owned=owned+1 end end
        if owned>=2 then return nil end
        r={at=now,owner=id,n=n,size=0,count=0,chunks={}}; st.parts[key]=r
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
local function location(st,t,d,e,ctx,carrier,bridge,cached,account)
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
        if not ev then return false end
        if not knownName(ev.name,ctx) then return false,"untracked" end
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
        if not Src.offer(ev) then return nil end
        st.shards[key]={seq=seq,at=ctx.now,name=ev.name}; return true
    elseif t=="FBLP" then
        local x,y=S.num(d.worldX),S.num(d.worldY)
        local at=stamp(d.sentAt,ctx.received or ctx,121)
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
        ev.note=(ev.kind=="self" and "own position; " or "reported position; ")..d.zone..(d.subZone and d.subZone~="" and ("; "..d.subZone) or "")
            ..(d.approximate and "; approximate coordinates; zone labels are current" or "")
        if N.WarBoardTrack then N.WarBoardTrack.roster(ev,d.roster,account,ctx) end
        if ctx.cleanupOnly or not Src.enabled("warboard") or not knownName(ev.name,ctx) then return false,"untracked" end
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
    local accepted=Src.offer(ev)
    if accepted and N.WarBoardTrack then N.WarBoardTrack.note(ev) end
    return accepted or nil,not accepted and not knownName(ev.name,ctx) and "untracked" or nil
end
local types={SHRD=true,FBLP=true,FREC=true,FBLC=true,FCBD=true}
local function payload(st,encoded,ctx,carrier,bridge,bnetFaction,account,channel)
    if st.seen[encoded] then return duplicate() end
    local hash=frameKey(st,encoded,ctx.now)
    if st.frames[hash] then return duplicate() end
    -- Character key aggregates BN + both prefixes + all addon distributions;
    -- an additional account bucket prevents BN character changes resetting it.
    local rate=decodeRate(st.decodeRates,N.Invite.key(carrier),ctx.now)
    local acct=account and decodeRate(st.decodeAccounts,account,ctx.now) or nil
    if not rate or (account and not acct) then return refuse() end
    local allowance=math.min(131072-rate.bytes,acct and (131072-acct.bytes) or 131072)
    -- All non-handshaken routes share 192 KiB/rolling 10 s. Channel traffic
    -- can spend only 128 KiB of it, leaving 64 KiB for guild/party/raid.
    if not account then
        allowance=math.min(allowance,byteRoom(st.decodeTotal,ctx.now,196608))
        if channel then allowance=math.min(allowance,byteRoom(st.decodeChannel,ctx.now,131072)) end
    end
    if allowance<=0 then return refuse() end
    -- A small successful parse never spends an expensive attempt. Once those
    -- attempts run out, still try up to 2 KiB (charged to every byte budget),
    -- rather than clipping small SHRD bursts behind a sixteenth large frame.
    if rate.attempts>=16 or (acct and acct.attempts>=16) then allowance=math.min(allowance,2048) end
    local charge={at=ctx.now,bytes=0}
    rate.at=ctx.now; rate.times[#rate.times+1]=charge
    if acct then acct.at=ctx.now; acct.times[#acct.times+1]=charge end
    local e,cost=W.decode(encoded,allowance)
    charge.bytes=cost; charge.expensive=cost>2048
    rate.bytes=rate.bytes+cost
    if charge.expensive then rate.attempts=rate.attempts+1 end
    if acct then
        acct.bytes=acct.bytes+cost
        if charge.expensive then acct.attempts=acct.attempts+1 end
    end
    if not account then
        spendBytes(st.decodeTotal,ctx.now,cost)
        if channel then spendBytes(st.decodeChannel,ctx.now,cost) end
    end
    -- Cache decode failures and completed outcomes, but not a refusal caused
    -- by the local Find/Watch set: tracking a name must reopen that same frame.
    local function remember() rememberFrame(st,hash,ctx.now) end
    local function decodedRefuse() remember(); return refuse() end
    if not S.tab(e) or not types[S.str(e.t,16)] or not S.num(e.v) or e.v>5
        or (e.scope~=nil and e.scope~="FACTION") or not S.tab(e.d) then return decodedRefuse() end
    if e.rs~=ctx.rs then return decodedRefuse() end
    local fac=e.faction~=nil and e.faction or e.d.faction
    if not faction(fac) or (bnetFaction and fac~=bnetFaction) then return decodedRefuse() end
    if (ctx.cleanupOnly or not Src.enabled("warboard")) and e.t~="FBLP" then return decodedRefuse() end
    local accepted,invalid,untracked=false,false,false
    if e.t=="FCBD" then
        local d=e.d; local n=array(d.entries,40)
        if not n or not S.str(d.requestId,160) or not S.str(d.relayGuid,80) or not N.Invite.name(d.relayName)
            or not integer(d.page,1,100000) or not S.num(d.rulesVersion) then return decodedRefuse() end
        local inner=d.kind=="bounty_locations" and "FBLC" or (d.kind=="activity" or d.kind=="witnessed_kills") and "FREC"
        if inner then for i=1,n do
            local result,why=location(st,inner,d.entries[i],e,ctx,carrier,true,true)
            if result then accepted=true elseif result==false then invalid=true end
            if why=="untracked" then untracked=true end
        end end
    else
        -- Only a matching subject on authenticated BN may claim "own position".
        if e.t=="FBLP" and not bnetFaction then bridge=true end
        local why
        accepted,why=location(st,e.t,e.d,e,ctx,carrier,bridge,false,account)
        invalid=accepted==false; untracked=why=="untracked"
    end
    if not accepted then
        if not untracked then remember() end
        if invalid then return refuse() end
        return false
    end
    remember()
    while #st.seenOrder>=512 or st.seenBytes+#encoded>1048576 do
        local old=table.remove(st.seenOrder,1); st.seen[old]=nil; st.seenBytes=st.seenBytes-#old
    end
    st.seen[encoded]=true; st.seenOrder[#st.seenOrder+1]=encoded; st.seenBytes=st.seenBytes+#encoded
    return true
end
local function defer(st,text,id)
    local T,peer=N.WarBoardTrack,st.peers[id]
    if not T or not T.hasOwed() or not peer or not text:match("^WBF1|[DF]|") then return end
    local received=N.Adapters.warboardContext(true) -- clocks/rules only; never an account scan
    st.deferred=st.deferred or {}; st.deferredBytes=st.deferredBytes or 0
    if not received or received.rs~=peer.rs or received.now<peer.at or received.now-peer.at>=1200
        or #st.deferred>=128 or st.deferredBytes+#text>262144 or not input(st,"bn:"..id,received) then
        T.uncertain(id); return
    end
    st.deferred[#st.deferred+1]={text=text,id=id,received=received,peer=peer,at=peer.at}
    st.deferredBytes=st.deferredBytes+#text
end
local function drain(st,ctx)
    if not ctx or not st.deferred then return end
    local pending=st.deferred; st.deferred=nil; st.deferredBytes=0
    for _,q in ipairs(pending) do
        if not W.bnet(st,q.text,q.id,ctx,q) and N.WarBoardTrack then N.WarBoardTrack.uncertain(q.id) end
    end
end
function W.bnet(st,text,id,ctx,deferred)
    if N.WarBoardTrack and N.WarBoardTrack.closed then return false end
    if S.secret(text) or type(text)~="string" or #text>4000 or #text<1 or not S.num(id) or id<1 or id%1~=0 then return refuse() end
    if not ctx then
        defer(st,text,id)
        -- No identity scans or sends while unsafe. Remember only a possible H
        -- from an already known account; revalidate its client identity when safe.
        local cmd,rs,version,rv=text:match("^WBF1|([HA])|5|([^|]+)|([^|]+)|(%d+)$")
        local peer=st.peers[id]
        if peer and rs==peer.rs and S.str(version,80) and #rv<=7 then
            if cmd=="H" then peer.hello=sequence(st); peer.proof=nil; peer.needAnswer=true end
            if cmd=="H" then peer.donorObserved=N.Adapters.loaded("WarBoard") and N.Adapters.warboardContext(true) or nil end
        end
        return false
    end
    if not deferred then drain(st,ctx) end -- rosters precede newer traffic and silence settlement
    local who=identity(id,ctx)
    if not who or (not deferred and not input(st,"bn:"..id,ctx)) then return refuse() end
    local cmd,proto,rs,version,rv=text:match("^WBF1|([HA])|(%d+)|([^|]+)|([^|]*)|(%d+)$")
    if cmd then
        if proto~="5" or not rules[rs] or not S.str(version,80) or #rv>7 then st.peers[id]=nil; return refuse() end
        if rs~=ctx.rs then
            st.peers[id]=nil
            if cmd=="H" then send(st,id,"A",ctx) end
            return false
        end
        if not st.peers[id] and slots(st.peers,ctx.now,1200)>=200 then return refuse() end
        local old=st.peers[id]
        local confirmed=cmd=="A" or (old and old.confirmed and ctx.now>=old.at and ctx.now-old.at<1200
            and old.key==who.key and old.rs==rs and old.faction==who.faction)
        local peer=old and old.key==who.key and old.rs==rs and old.faction==who.faction and old or {}
        peer.at=ctx.now; peer.key=who.key; peer.faction=who.faction; peer.rs=rs; peer.confirmed=confirmed
        st.peers[id]=peer
        if cmd=="H" then peer.hello=sequence(st); peer.proof=nil; peer.needAnswer=true end
        local debt=N.WarBoardTrack and N.WarBoardTrack.owedAccount(id)
        local donor=N.Adapters.loaded("WarBoard")
        if debt and donor and cmd=="H" then
            peer.needAnswer=nil; proof(st,peer,ctx.now)
        elseif not donor and cmd=="A" and not peer.needAnswer then proof(st,peer,ctx.now) end
        if cmd=="H" then send(st,id,"A",ctx) end
        return true
    end
    local peer=st.peers[id]
    local at=deferred and deferred.at or (peer and peer.at)
    local received=deferred and deferred.received or ctx
    if not peer or peer.rs~=ctx.rs or peer.key~=who.key or peer.faction~=who.faction
        or (deferred and (deferred.peer~=peer or received.rs~=ctx.rs or received.faction~=ctx.faction))
        or received.now<at or received.now-at>=1200 then return refuse() end
    local encoded=W.assemble(st,text,id,received.now)
    if deferred then
        ctx={now=ctx.now,wall=ctx.wall,rs=ctx.rs,faction=ctx.faction,received=received,cleanupOnly=true}
    end
    return encoded and payload(st,encoded,ctx,who.name,false,who.faction,id) or false
end
function W.addon(st,prefix,text,dist,sender,ctx)
    if not ctx or (prefix~="WarBoard" and prefix~="WarBoardBN") or S.secret(text) or type(text)~="string" or #text>255
        or (dist~="GUILD" and dist~="PARTY" and dist~="RAID" and dist~="CHANNEL") then return refuse() end
    sender=N.Invite.name(sender)
    if not sender or N.Main.isMe(sender) then return false end
    local key=prefix..":"..dist..":"..N.Invite.key(sender)
    if not input(st,"addon:"..N.Invite.key(sender),ctx,dist=="CHANNEL") then return refuse() end
    st.comm=st.comm or {}; st.comm.now=ctx.now
    local encoded=Cd.aceCommJoin(st.comm,key,text,N.Invite.key(sender))
    return encoded and payload(st,encoded,ctx,sender,prefix=="WarBoardBN",nil,nil,dist=="CHANNEL") or false
end
function W.tick(st,ctx)
    if ctx and not (st.high and ctx.now<st.high) then drain(st,ctx) end
    local T=N.WarBoardTrack
    if T and T.hasOwed() and ctx and not (st.high and ctx.now<st.high) and N.Adapters.loaded("WarBoard") then
        -- Validate deferred donor-owned control observations only when safe;
        -- no LE handshake or account scan was performed in combat/instances.
        for id,peer in pairs(st.peers) do
            local observed=peer.donorObserved
            peer.donorObserved=nil
            local who=observed and ctx.now>=observed.now and ctx.now-observed.now<1200
                and observed.rs==ctx.rs and observed.faction==ctx.faction and T.owedAccount(id) and identity(id,ctx)
            if who and peer.rs==ctx.rs and who.key==peer.key and who.faction==peer.faction then
                peer.needAnswer=nil; peer.at=observed.now
                proof(st,peer,observed.now)
            end
        end
    end
    if T and T.hasOwed() and ctx and not (st.high and ctx.now<st.high) and not N.Adapters.loaded("WarBoard") then
        -- Only debt accounts may use the handshake exception, even with every
        -- normal send switch off. The usual H/A caps and shared budgets remain.
        for id,peer in pairs(st.peers) do
            if T.needsHandshake(id) and peer.rs==ctx.rs and identity(id,ctx) then
                if peer.needAnswer and not peer.answerPending then send(st,id,"A",ctx) end
                if not T.ready(peer,ctx.now) then send(st,id,"H",ctx) end
            end
        end
        if not recent(st.debtScan,ctx.now,60) then
            st.debtScan=ctx.now
            for _,r in ipairs(BN.peers(ctx.now)) do
                if T.needsHandshake(r.id) and identity(r.id,ctx) then
                    local peer=st.peers[r.id]
                    if not T.ready(peer,ctx.now) then send(st,r.id,"H",ctx) end
                end
            end
        end
    end
    if N.WarBoardTrack then N.WarBoardTrack.tick(st,ctx) end
    if N.WarBoardTrack and N.WarBoardTrack.closed then return end
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
