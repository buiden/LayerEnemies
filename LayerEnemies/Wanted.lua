-- Wanted v1.29.2: protocol-only, receive-only. No donor/library code.
-- Pure bounded decoding below; registry callbacks at the end own runtime reads.
local _,N=...
local W,S,Cd,Src={},N.Safe,N.Codec,N.Sources
N.Wanted=W
W.stats={}
local function plain(t) return S.tab(t) and getmetatable(t)==nil end
local function integer(v,lo,hi) return S.num(v) and v%1==0 and v>=lo and v<=hi end
local function guid(v) return S.str(v,64) and v:match("^Player%-%d+%-%x+$") and v end
local function version(v) return S.str(v,32) and v:match("^1%.29%.[012]$") end
function W.decode(bytes)
    if S.secret(bytes) or type(bytes)~="string" or #bytes>30272 then return nil end
    local raw=Cd.addonDecode(bytes)
    raw=raw and Cd.inflate(raw,65536)
    return raw and Cd.lsRead(raw) or nil
end
local function context()
    local A=N.Adapters
    if not Src.enabled("wanted") or A.inCombat() or A.inInstance()~=false then return nil end
    local now=S.num(S.call(GetTime))
    local faction=S.str(S.call(UnitFactionGroup,"player"),16)
    if not now or (faction~="Alliance" and faction~="Horde") then return nil end
    return now,faction
end
local function place(d,mapKey,layer)
    local zone
    if mapKey=="m" then zone=d.z else zone=d.zone end
    if zone~=nil and not S.str(zone,64) then return nil end
    local map=d[mapKey]
    if map~=nil and not integer(map,1,999999) then return nil end
    if not zone and not map then return nil end
    local x,y=S.num(d.x),S.num(d.y)
    if d.x~=nil or d.y~=nil then
        if not x or not y or x<0 or x>100 or y<0 or y>100 then return nil end
        if map then x,y=x/100,y/100 else x,y=nil,nil end
    end
    local shard=layer and d.l or nil
    if shard~=nil and (not S.str(shard,32) or not shard:match("^%d+%-%d+%-%d+$")) then return nil end
    return {zone=zone,map=map,x=x,y=y,shard=shard}
end
local function array(t,cap)
    if not plain(t) then return nil end
    local n=0
    for k in pairs(t) do if not integer(k,1,cap) then return nil end; n=n+1 end
    for i=1,n do if t[i]==nil then return nil end end
    return n
end
-- These are numbered Wanted fragments, NOT AceComm control bytes. Audit §3.
function W.join(st,key,text,bnet,now,owner)
    if not plain(st) or not S.str(key,180) or not S.num(now) or S.secret(text) or type(text)~="string"
        or #text>(bnet and 3800 or 255) then return nil end
    owner=owner or key
    if not S.str(owner,180) then return nil end
    if st.time and now<st.time then return nil end
    st.time=now; st.streams=st.streams or {}
    for k,v in pairs(st.streams) do if now-v.at>=30 then st.streams[k]=nil end end
    local tag,id,p,n,b
    if bnet then id,p,n,b=text:match("^(%d+):(%d+)/(%d+):(.+)$"); tag="BN"
    else tag,id,p,n,b=text:match("^([ESRF]):([0-9a-z]+):(%d+)/(%d+):(.+)$") end
    if not id or #id>(bnet and 5 or 3) or not integer(tonumber(id,bnet and 10 or 36),1,46655) then return nil end
    p,n=tonumber(p),tonumber(n)
    if not integer(n,1,bnet and 8 or 12) or not integer(p,1,n) or #b>(bnet and 3784 or 240) then return nil end
    local k=key..":"..id; local r=st.streams[k]
    if r and (r.tag~=tag or r.total~=n or (r.parts[p] and r.parts[p]~=b)) then st.streams[k]=nil; return nil end
    if n==1 then return b,tag,id end
    if not r then
        local total,own=0,0
        for _,v in pairs(st.streams) do total=total+1; if v.owner==owner then own=own+1 end end
        if total>=16 or own>=(bnet and 2 or 4) then return nil end
        r={owner=owner,tag=tag,total=n,parts={},count=0,at=now}; st.streams[k]=r
    end
    if not r.parts[p] then r.parts[p]=b; r.count=r.count+1 end
    if r.count~=n then return nil end
    st.streams[k]=nil
    return table.concat(r.parts),tag,id
end
local state={streams={},seen={},far={},rates={}}
W.state=state
local function budget(key,now,cap)
    if state.last and now<state.last then return false end
    state.last=now
    for k,r in pairs(state.rates) do if now-r.at>=120 then state.rates[k]=nil end end
    local r=state.rates[key]; local bucket=math.floor(now/60)
    if not r then
        if S.count(state.rates)>=128 then return false end
        r={at=now,bucket=bucket,n=0}; state.rates[key]=r
    end
    if r.bucket~=bucket then r.bucket,r.n=bucket,0 end
    if r.n>=cap then return false end
    r.n=r.n+1; r.at=now; return true
end
local function freshKey(key,now)
    for k,v in pairs(state.seen) do if now>=v then state.seen[k]=nil end end
    return not state.seen[key] and S.count(state.seen)<512
end
local function sameFaction(g,now,faction)
    local r=N.Main.store.localSeen[g]
    if r and r.faction=="same" and S.num(r.at) and now>=r.at and now-r.at<600 then return true end
    N.Known.prune(N.Main.find.known,now)
    for _,p in pairs(N.Main.find.known.entries) do
        for _,slot in ipairs({"own","seen","reported"}) do
            local e=p[slot]
            if e and e.guid==g and e.faction==faction then return true end
        end
    end
    return false
end
local function sighting(d,sender,now,faction)
    if not plain(d) or not guid(d.g) or not N.Invite.name(d.n) or sameFaction(d.g,now,faction) then return false end
    local e=place(d,"m")
    if not e then return false end
    e.name,e.guid,e.net,e.via,e.kind,e.got=d.n,d.g,"wanted",sender,"witness",now
    return Src.offer(e)
end
local recordKinds={kill=true,death=true,assist=true,claim=true,bounty=true,spotted=true}
local envelope={kind=true,id=true,origin=true,seq=true,prev=true,t=true,data=true,hash=true}
local numeric={killT=true,seenAt=true,postedAt=true,level=true,x=true,y=true,mapId=true}
-- Adler-32 proves only byte consistency, not a signature or an authenticated chain.
function W.record(r)
    if not plain(r) then return nil end
    for k,v in pairs(r) do if S.secret(k) or not envelope[k] or S.secret(v) then return nil end end
    if not S.str(r.kind,16) or not recordKinds[r.kind] or not S.str(r.origin,64) or not N.Invite.name(r.origin)
        or not integer(r.seq,1000001,2147483647) or not S.str(r.id,80)
        or r.id~=r.origin..":"..string.format("%d",r.seq) or not S.str(r.prev,128)
        or not S.num(r.t) or not plain(r.data) or not S.str(r.hash,8) or not r.hash:match("^%x%x%x%x%x%x%x%x$") then return nil end
    local keys={}
    for k,v in pairs(r.data) do
        if not S.str(k,64) or S.secret(v) then return nil end
        local typ=type(v)
        if typ=="number" then if not S.num(v) then return nil end
        elseif typ=="string" then if v~="" and not S.str(v,512) then return nil end
        elseif typ~="boolean" then return nil end
        if numeric[k] and not S.num(v) then return nil end
        keys[#keys+1]=k; if #keys>64 then return nil end
    end
    if r.data.amount~=nil and not integer(r.data.amount,0,2147483647) then return nil end
    if r.kind=="bounty" and r.data.amount==nil then return nil end
    table.sort(keys)
    local lines={r.kind,r.id,r.prev,tostring(r.t)}
    for _,k in ipairs(keys) do lines[#lines+1]=k.."="..tostring(r.data[k]) end
    local bytes=table.concat(lines,"\n"); local a,b=1,0
    for i=1,#bytes do a=(a+bytes:byte(i))%65521; b=(b+a)%65521 end
    if string.format("%08x",b*65536+a)~=r.hash then return nil end
    return r
end
local function age(t,wall,now)
    if not S.num(t) or not wall or t>wall or wall-t>=N.Known.TTL then return nil end
    return now-(wall-t)
end
local function guidName(g,now)
    local found
    N.Known.prune(N.Main.find.known,now)
    for _,p in pairs(N.Main.find.known.entries) do
        for _,slot in ipairs({"own","seen","reported"}) do
            local e=p[slot]
            if e and e.guid==g and N.Find.tracked(N.Main.find,e.name) then
                if found and found~=e.name then return nil end
                found=e.name
            end
        end
    end
    return found
end
local function offerRecord(r,tag,dist,sender,key,now,faction,wall)
    if not W.record(r) then Src.count("wanted","refused"); return false end
    local _,origin=N.Invite.name(r.origin)
    if tag=="R" and dist~="WHISPER" and origin~=key then return false end
    local at=age(r.t,wall,now)
    if not at then return false end
    local d=r.data
    if r.kind=="bounty" then at=age(d.seenAt,wall,now)
    elseif r.kind=="claim" then at=age(d.killT,wall,now) end
    if not at then return false end
    local loc=place(d,"mapId",r.kind~="bounty" and r.kind~="claim")
    if not loc then return false end
    local identity="record:"..r.id
    if not freshKey(identity,now) then return false end
    local kind=r.kind=="bounty" and "cached" or (tag=="F" or origin~=key) and "relayed" or "witness"
    local accepted=false
    local function participant(name,g,f)
        if not N.Invite.name(name) or (g~=nil and not guid(g)) or (f~=nil and f~="Alliance" and f~="Horde")
            or f==faction or (g and sameFaction(g,now,faction)) then return end
        local e={name=name,guid=g,faction=f,zone=loc.zone,map=loc.map,x=loc.x,y=loc.y,shard=loc.shard,
            at=at,got=now,kind=kind,net="wanted",via=sender}
        if Src.offer(e) then accepted=true end
    end
    if r.kind=="bounty" then participant(d.targetName,d.target,d.faction)
    elseif r.kind=="spotted" then if guid(d.target) then participant(guidName(d.target,now),d.target,nil) end
    else
        participant(d.killerName,d.killer,d.killerFaction)
        participant(d.victimName,d.victim,d.victimFaction)
    end
    if accepted then state.seen[identity]=at+N.Known.TTL end
    return accepted
end
local function addon(prefix,text,dist,sender)
    local now,faction=context()
    if not now or prefix~="WNTD" or (dist~="GUILD" and dist~="CHANNEL" and dist~="WHISPER") then return end
    local name,key=N.Invite.name(sender); sender=name
    if not sender or N.Main.isMe(sender) or N.Adapters.ignored(sender) then return end
    if not budget("addon:"..key,now,60) then Src.count("wanted","refused"); return end
    local b,tag,id=W.join(state,"addon:"..dist..":"..key,text,false,now,"addon:"..key)
    if not b then return end
    local identity="packet:"..key..":"..tag..":"..id
    if not freshKey(identity,now) then return end
    local t=W.decode(b)
    if not plain(t) or not version(t.v) then Src.count("wanted","refused"); return end
    if dist=="WHISPER" and (tag=="E" or tag=="S") then return end
    local accepted=false
    if tag=="E" then accepted=sighting(t,sender,now,faction)
    elseif tag=="S" then
        local n=array(t.s,15)
        if not n then return end
        for i=1,n do if sighting(t.s[i],sender,now,faction) then accepted=true end end
    else
        local n=array(t.r,tag=="R" and 10 or 8)
        local wall=S.num(S.call(GetServerTime))
        if not n or not wall then return end
        for i=1,n do offerRecord(t.r[i],tag,dist,sender,key,now,faction,wall) end
    end
    if accepted then state.seen[identity]=now+N.Known.TTL end
end
local function sweep(now)
    if not S.num(now) then return end
    for k,r in pairs(state.far) do if now<r.at or now-r.at>=600 then state.far[k]=nil end end
    for k,r in pairs(state.streams) do if now<r.at or now-r.at>=30 then state.streams[k]=nil end end
    for k,t in pairs(state.seen) do if now>=t then state.seen[k]=nil end end
    for k,r in pairs(state.rates) do if now-r.at>=120 then state.rates[k]=nil end end
end
local function realm(v)
    v=S.str(v,100)
    return v and v:lower():gsub("[%s%-%']","")
end
local function bnet(prefix,text,id)
    local now,faction=context()
    if not now or (prefix~="WNTDB" and prefix~="WNTDP") or not integer(id,1,2147483647) then return end
    if not budget("bn:"..id,now,30) then Src.count("wanted","refused"); return end
    local peer=N.BNet.who(id)
    if not plain(peer) or not N.Invite.name(peer.name) or not S.str(peer.faction,16)
        or peer.faction==faction or (peer.faction~="Alliance" and peer.faction~="Horde")
        or not realm(peer.realm) or realm(peer.realm)~=realm(N.Main.homeRealm()) then return end
    if S.secret(text) or type(text)~="string" or #text>3800 then return end
    local b=text
    if prefix=="WNTDP" then b=W.join(state,"bn:"..id,text,true,now) end
    if not b then return end
    local t=W.decode(b)
    if not plain(t) or S.str(t.k,1)~="L" then return end -- H/A/N have no location; never answer them.
    local n=array(t.z,12)
    if not n then return end
    local rows={}
    for i=1,n do
        local v=t.z[i]
        if not plain(v) or not integer(v.m,1,999999) or not S.str(v.l,32) or not v.l:match("^%d+%-%d+%-%d+$")
            or not S.num(v.n) or v.n<1 then return end
        rows[i]={m=v.m,l=v.l,n=math.min(200,math.floor(v.n))}
    end
    sweep(now)
    if not state.far[id] and S.count(state.far)>=20 then return end
    state.far[id]={at=now,rows=rows}; Src.count("wanted","accepted")
end
local function status()
    local now=context()
    if not now then return {} end
    sweep(now)
    local values={}
    for _,r in pairs(state.far) do
        local own={}
        for _,v in ipairs(r.rows) do own[v.m..":"..v.l]=v end
        for k,v in pairs(own) do
            if not values[k] or values[k].n<v.n then values[k]=v end
        end
    end
    local keys,out={},{}
    for k in pairs(values) do keys[#keys+1]=k end; table.sort(keys)
    for _,k in ipairs(keys) do local v=values[k]; out[#out+1]="Wanted opposite-faction users: map "..v.m.." / layer "..v.l..": "..v.n end
    return out
end
Src.register{name="wanted",prefixes={"WNTD","WNTDB","WNTDP"},onAddon=addon,onBNet=bnet,tick=sweep,status=status,counters=W.stats}
N.Net.LIST.wanted.standDown="WantedDeadOrDead"
