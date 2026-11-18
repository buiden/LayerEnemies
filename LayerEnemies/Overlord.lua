-- Independent Overlord Forever 2.5.4 protocol reader. Protocol only, no code copied.
-- Pure: caller supplies clocks, transport identity and resolved map; no client calls or sends.
local _,N=...
local Ov,S,F={},N.Safe,N.Find
N.Overlord=Ov
local function bytes(v,max)
    if S.secret(v) or type(v)~="string" or #v>max or v:find("%c") then return nil end
    return v
end
local function fields(text,sep,count)
    local out,start={},1
    while true do
        local at=text:find(sep,start,true)
        out[#out+1]=text:sub(start,at and at-1 or #text)
        if #out>count then return nil end
        if not at then break end
        start=at+1
    end
    if #out==count then return out end
end
local function uint(v,max,min)
    v=S.str(v,20)
    if not v or not v:match("^%d+$") then return nil end
    local n=S.num(tonumber(v))
    if n and n%1==0 and n>=(min or 0) and n<=max then return n end
end
local function identity(v)
    v=S.str(v,100)
    if not v then return nil end
    local name,key=F.name(v)
    if name==v and name and name:sub(-1)~="-" then return name,key end
end
local function validId(id) return S.str(id,64) and id:match("^[%w%-]+$") end
local function fresh(ts,wall,age)
    return S.num(wall) and ts and wall-ts<=age and ts-wall<=30
end
local function zone(ref)
    if not S.str(ref,40) or not ref:match("^[#@]?[%w_%-]+$") then return false end
    if ref:sub(1,1)=="#" then
        local map=uint(ref:sub(2),9007199254740991,1)
        return map or false
    end
    return nil -- valid donor-only location, not a guess at a map
end
-- Campaign tags from Overlord 2.5.1 RealmPools.lua; no donor calls or PvP default.
function Ov.pool(realm,hc,rp,pvp)
    local named
    realm=S.str(realm,100)
    if realm then
        local text=" "..realm:lower().." "
        local role=text:find("roleplay",1,true) or text:find("[%s%-]rp[%s%-%d]") or text:find("rppvp",1,true)
        local versus=text:find("pvp",1,true)
        if text:find("hardcore",1,true) then named="hc"
        elseif role then named=versus and "rpv" or "rpg"
        elseif versus then named="global"
        elseif text:find("pve",1,true) or text:find("normal",1,true) then named="pve" end
    end
    hc,rp,pvp=S.clean(hc),S.clean(rp),S.clean(pvp)
    if hc==true then return "hc" end
    if hc~=false or type(rp)~="boolean" or type(pvp)~="boolean" then return named end
    local pool=rp and (pvp and "rpv" or "rpg") or (pvp and "global" or "pve")
    -- Explicit realm labels resolve startup all-false and RP/PvP partial detection.
    if pool=="pve" and named then return named end
    if named=="rpv" and (pool=="rpg" or pool=="global") then return named end
    return pool
end
function Ov.new() return {pending={},serial=0,guilds={},seen={},ring={},cursor=0,stats={lines=0,taken=0,refused=0}} end
function Ov.sweep(st,now)
    for key,a in pairs(st.pending) do
        if now<a.at or now-a.at>=120 or now-a.last>=30 then st.pending[key]=nil end
    end
end
-- Bounded work before parsing on every route. Names share a bucket across addon
-- distributions; BNet additionally retains an account bucket across character changes.
function Ov.admit(st,sender,now,size,route,account)
    if not identity(sender) or not S.num(now) or not S.num(size) then return false end
    local b=st.budget
    if not b or now<b.at or now-b.at>=10 then b={at=now,senders={},bytes=0,public=0,frames=0}; st.budget=b end
    local who=sender:lower()
    local keys={who}; if account then keys[2]="bn:"..account end
    local guild=route=="GUILD"
    local count,pub=0,0
    for _,r in pairs(b.senders) do count=count+1; if not r.guild then pub=pub+1 end end
    for _,key in ipairs(keys) do
        local r=b.senders[key]
        if not r then
            if count>=128 or (not guild and pub>=96) then return false end
            r={bytes=0,n=0,guild=guild}; b.senders[key]=r;count=count+1;if not guild then pub=pub+1 end
        end
        if r.n>=120 or r.bytes+size>14400 then return false end
    end
    if b.bytes+size>128000 or (not guild and b.public+size>96000) or b.frames>=640
        or (not guild and (b.publicFrames or 0)>=512) then return false end
    for _,key in ipairs(keys) do local r=b.senders[key];r.n=r.n+1;r.bytes=r.bytes+size end
    b.bytes=b.bytes+size;b.frames=b.frames+1
    if not guild then b.public=b.public+size;b.publicFrames=(b.publicFrames or 0)+1 end
    return true
end
function Ov.seen(st,origin,id)
    local _,key=identity(origin)
    if not key or not validId(id) then return true end
    key=key..":"..id
    if st.seen[key] then return true end
    st.cursor=st.cursor%2000+1
    local old=st.ring[st.cursor]
    if old then st.seen[old]=nil end
    st.ring[st.cursor]=key; st.seen[key]=true
    return false
end
-- The second return carries the envelope id to packet(), never inferred from its contents.
function Ov.fragment(st,text,sender,now,route)
    if not bytes(text,255) or not identity(sender) or not S.num(now) then return false end
    local id,part,count,chunk=text:match("^BF:([^:]*):([^:]*):([^:]*):(.*)$")
    part,count=uint(part,24,1),uint(count,24,1)
    if not validId(id) or not part or not count or part>count or #chunk>230 then return false end
    Ov.sweep(st,now)
    if count==1 then return chunk,id end
    local _,who=identity(sender)
    local key=who..":"..id
    local a=st.pending[key]
    local n,owned,pub,totalBytes,publicBytes=0,0,0,0,0
    for _,v in pairs(st.pending) do
        n=n+1;totalBytes=totalBytes+v.bytes
        if v.owner==who then owned=owned+1 end
        if not v.guild then pub=pub+1;publicBytes=publicBytes+v.bytes end
    end
    if not a then
        if n>=64 or owned>=4 or (route~="GUILD" and pub>=48) then return false end
        st.serial=st.serial+1
        a={at=now,last=now,serial=st.serial,chunks={},count=count,got=0,bytes=0,owner=who,guild=route=="GUILD"}
        st.pending[key]=a
    end
    if a.count~=count or (a.chunks[part] and a.chunks[part]~=chunk) then return false end
    if not a.chunks[part] then
        if a.bytes+#chunk>3600 or totalBytes+#chunk>65536 or (not a.guild and publicBytes+#chunk>49152) then
            st.pending[key]=nil;return false
        end
        a.chunks[part]=chunk;a.got=a.got+1;a.bytes=a.bytes+#chunk;a.last=now
    end
    if a.got<count then return nil end
    st.pending[key]=nil
    return table.concat(a.chunks),id
end
local peerKinds={NH=true,HR=true,HB=true,HA=true,SR=true,LK=true,SH=true,GE=true,GP=true,ZS=true,MN=true,K=true}
function Ov.packet(wire,id,sender,serverNow,me)
    if not bytes(wire,3600) or not validId(id) then return nil end
    local f
    if me then
        local a,b,c,d,e,g,h=wire:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|(.*)$")
        if a then f={a,b,c,d,e,g,h} end
    else f=fields(wire,"|",7) end
    if not f or f[2]~=id or (f[4]~="*" and (not me or not identity(f[4]) or F.fold(f[4])~=F.fold(me)))
        or (f[6]~="GW" and f[6]~="GD" and not (me and peerKinds[f[6]])) then return nil end
    local at=uint(f[3],9007199254740991)
    if not fresh(at,serverNow,120) then return nil end
    local path,used={},{}
    local start=1
    while true do
        local comma=f[5]:find(",",start,true)
        local name,key=identity(f[5]:sub(start,comma and comma-1 or #f[5]))
        if not name or used[key] or #path>=4 or (me and F.fold(me)==key) then return nil end
        path[#path+1]=name; used[key]=true
        if not comma then break end
        start=comma+1
    end
    local origin=path[1]
    local _,key=identity(path[#path]); local _,last=identity(sender)
    if key~=last then return nil end
    return {pool=f[1],kind=f[6],payload=f[7],origin=origin,at=at,target=f[4],hops=#path-1}
end
function Ov.direct(text)
    text=bytes(text,255)
    local kind,payload
    if text then kind,payload=text:match("^([A-Z]+):(.*)$") end
    if kind=="GW" or kind=="GD" or kind=="EK" then return {kind=kind,payload=payload} end
end
local function killer(name,class,ref,ts,epoch)
    name=identity(name)
    if not name or (class~="" and (not S.str(class,20) or not class:match("^%u+$"))) then return nil end
    local map
    if ref~="" then map=zone(ref); if map==false then return nil end end
    ts=uint(ts,9007199254740991)
    if not ts or not uint(epoch,9007199254740991) then return nil end
    return {killer=name,class=class~="" and class or nil,map=map,ts=ts}
end
function Ov.gd(payload)
    payload=bytes(payload,252)
    local f=payload and fields(payload,":",8)
    if not f or (f[1]~="H" and f[1]~="A") or not S.str(f[2],64) then return nil end
    local victim=identity(f[8])
    local d=killer(f[4],f[5],f[6],f[3],f[7])
    if not victim or not d or F.fold(victim)==F.fold(d.killer) then return nil end
    d.victim,d.pool=victim,f[2]
    return d
end
function Ov.ek(payload)
    payload=bytes(payload,252)
    local f=payload and fields(payload,":",6)
    if not f or (f[3]~="Horde" and f[3]~="Alliance") then return nil end
    return killer(f[1],f[2],f[5],f[4],f[6])
end
function Ov.gw(payload,serverNow)
    payload=bytes(payload,200)
    local f=payload and fields(payload,":",8)
    if not f or f[1]~="1" or (f[3]~="H" and f[3]~="A") then return nil end
    local guild=S.str(f[2],24)
    if not guild or guild:match("^%s") or guild:match("%s$") or guild:find("%s%s") or guild:find("[,%%]") then return nil end
    local kills,members=uint(f[4],9999,50),uint(f[5],999,5)
    local map
    if f[6]~="" then map=zone(f[6]); if map==false then return nil end end
    local layer=f[7]~="" and uint(f[7],99999999) or nil
    if f[7]~="" and not layer then return nil end
    local ts=uint(f[8],9007199254740991)
    if not kills or not members or not fresh(ts,serverNow,300) then return nil end
    return {guild=guild,faction=f[3],kills=kills,members=members,map=map,layer=layer,ts=ts}
end
function Ov.rows(st,now)
    local rows={}
    for key,g in pairs(st.guilds) do
        if now<g.at or now-g.at>=300 then st.guilds[key]=nil
        else rows[#rows+1]=g end
    end
    table.sort(rows,function(a,b) if a.at==b.at then return a.key<b.key end; return a.at>b.at end)
    return rows
end
function Ov.rampage(st,g,now,wall)
    local rows=Ov.rows(st,now)
    local key=F.fold(g.guild)
    local at=now-math.max(0,wall-g.ts)
    if st.guilds[key] and st.guilds[key].at>=at then return end
    if not st.guilds[key] and #rows>=32 then st.guilds[rows[#rows].key]=nil end
    g.key,g.at=key,at
    st.guilds[key]=g
end
