-- Independent Overlord Forever 2.5.1 protocol reader. Protocol only, no code copied.
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
function Ov.new() return {pending={},serial=0,guilds={},seen={},ring={},cursor=0,stats={lines=0,taken=0,refused=0}} end
function Ov.sweep(st,now)
    for key,a in pairs(st.pending) do
        if now<a.at or now-a.at>=30 then st.pending[key]=nil end
    end
end
function Ov.seen(st,origin,id)
    local _,key=identity(origin)
    if not key or not validId(id) then return true end
    key=key..":"..id
    if st.seen[key] then return true end
    st.cursor=st.cursor%256+1
    local old=st.ring[st.cursor]
    if old then st.seen[old]=nil end
    st.ring[st.cursor]=key; st.seen[key]=true
    return false
end
-- The second return carries the envelope id to packet(), never inferred from its contents.
function Ov.fragment(st,text,sender,now)
    if not bytes(text,255) or not identity(sender) or not S.num(now) then return false end
    local id,part,count,chunk=text:match("^BF:([^:]*):([^:]*):([^:]*):(.*)$")
    part,count=uint(part,24,1),uint(count,24,1)
    if not validId(id) or not part or not count or part>count or count>2 or #chunk>230 then return false end
    Ov.sweep(st,now)
    if count==1 then return chunk,id end
    local _,who=identity(sender)
    local key=who..":"..id
    local a=st.pending[key]
    if not a then
        local n,oldest,serial=0,nil,math.huge
        for k,v in pairs(st.pending) do
            n=n+1
            if v.serial<serial then oldest,serial=k,v.serial end
        end
        if n>=32 then st.pending[oldest]=nil end
        st.serial=st.serial+1
        a={at=now,serial=st.serial,chunks={},count=count,got=0}; st.pending[key]=a
    end
    if a.count~=count or (a.chunks[part] and a.chunks[part]~=chunk) then return false end
    if not a.chunks[part] then a.chunks[part]=chunk; a.got=a.got+1 end
    if a.got<count then return nil end
    st.pending[key]=nil
    return table.concat(a.chunks),id
end
function Ov.packet(wire,id,sender,serverNow)
    if not bytes(wire,3600) or not validId(id) then return nil end
    local f=fields(wire,"|",7)
    if not f or f[2]~=id or f[4]~="*" or (f[6]~="GW" and f[6]~="GD") then return nil end
    local at=uint(f[3],9007199254740991)
    if not fresh(at,serverNow,120) then return nil end
    local path,used={},{}
    local start=1
    while true do
        local comma=f[5]:find(",",start,true)
        local name,key=identity(f[5]:sub(start,comma and comma-1 or #f[5]))
        if not name or used[key] or #path>=4 then return nil end
        path[#path+1]=name; used[key]=true
        if not comma then break end
        start=comma+1
    end
    local origin=path[1]
    local _,key=identity(path[#path]); local _,last=identity(sender)
    if key~=last then return nil end
    return {kind=f[6],payload=f[7],origin=origin,at=at}
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
    d.victim=victim
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
