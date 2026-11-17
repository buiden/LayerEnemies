-- Overlord 2.5.4 protocol only; independently written, no donor code.
-- Minimal v8 empty comparison + named kill feed, not a ranking host.
local _,N=...
local Q,S,F,P={},N.Safe,N.Find,N.OverlordPeer
N.OverlordFeed=Q
Q.capability="~lp8" -- SyncRelay's trailing ~lp(%d+) recognizes 8 directly.
function Q.new() return {sessions={},serial=0} end
local function uint(v,max,min)
    if not S.str(v,10) or not v:match("^%d+$") then return nil end
    local n=tonumber(v);if n and n>=(min or 0) and n<=max then return n end
end
local function split(s,max)
    local out={};for v in (s..":"):gmatch("(.-):") do out[#out+1]=v;if #out>max then return nil end end;return out
end
-- Canonical wire race names (protocol data, SyncAux.lua:1824-1872).
local raceNames={}
for name in ("Human Dwarf NightElf Gnome Orc Scourge Tauren Troll Skyborne "..
    "Draenei Worgen BloodElf Goblin Pandaren Nightborne HighmountainTauren "..
    "VoidElf LightforgedDraenei ZandalariTroll KulTiran DarkIronDwarf Vulpera "..
    "MagharOrc Mechagnome Dracthyr Earthen EarthenDwarf Haranir Harronir Haronir"):gmatch("%S+") do
    raceNames[name]=true
end
local identity
local function ready(c)
    return c.allowed==true and c.own==true and S.str(c.pool,16) and S.str(c.me,50)
        and S.num(c.now) and S.num(c.wall) and (c.faction=="A" or c.faction=="H")
end
local function supported(r)
    local major,minor,patch=(r.version or ""):match("^(%d+)%.(%d+)%.(%d+)")
    return major and (tonumber(major)>2 or tonumber(major)==2 and tonumber(minor)>=5)
end
local function friend(r,c)
    if r.route~="BNET" then return true end
    for _,v in ipairs(c.friends or {}) do
        if v.friend and v.id==r.id and F.fold(v.name)==F.fold(r.name) then return true end
    end
    return false
end
local function current(r,c)
    return r and r.hops==0 and r.pool==c.pool and c.now>=r.at and c.now-r.at<300
        and r.epoch and r.epoch<=c.wall and c.now>=r.epochAt and c.now-r.epochAt<600
        and supported(r) and friend(r,c)
end
local function announced(peer,r,c)
    if r.announced and r.announcePool==c.pool and r.announceMe==c.me
        and c.now>=r.announced and c.now-r.announced<300 then return true end
    local a=peer.announced
    local at=a and (r.route=="GUILD" and a.guild or (r.route=="PARTY" or r.route=="RAID") and a.group)
    return a and a.pool==c.pool and a.me==c.me and at and c.now>=at and c.now-at<300
end
function Q.cancel(st) st.sessions={} end
function Q.observe(st,peer,p,r,c)
    if not ready(c) or not r or p.hops~=0 then return end
    local e
    -- Learn only this direct peer's current epoch; never turn it into global authority.
    if p.kind=="K" then
        local f=split(p.payload,13)
        if f and #f==13 and F.fold(f[1])==F.fold(p.origin)
            and #f[2]<=24 and (f[2]:match("^#%d+$") or f[2]:match("^@[%w_%-]+$"))
            and identity("k"..table.concat({f[1],f[3],f[4],f[5],f[8],f[7],f[9],f[13]},":"),c.wall)
            and raceNames[f[10]] and f[11]:match("^[023]$")
            and f[12]=="B"..f[6] and uint(f[13],60,1) then e=uint(f[6],9999999999,1) end
    elseif p.kind=="HR" and p.target==c.me then
        local v=split(p.payload,10)
        if v and #v==9 and v[1]=="8" and v[2]=="V" and v[4]:match("^%w+$") and #v[4]<=32
            and v[5]=="1" and v[6]=="LK" and uint(v[7],10000) and uint(v[8],2147483646)
            and (v[9]=="A" or v[9]=="H" or v[9]=="-") then e=uint(v[3],9999999999,1) end
    end
    if e and e<=c.wall then
        if r.epoch~=e then st.sessions[F.fold(r.name)]=nil end
        r.epoch,r.epochAt=e,c.now
    end
end
-- Complete structural validation before applying any row. A malformed tail cannot
-- partially commit earlier rows. The marker never leaks between payloads.
function Q.decode(payload)
    payload=S.str(payload,600)
    if not payload or payload:find("%c") then return nil end
    local e,body=payload:match("^8:U:(%d+):(.*)$")
    e=uint(e,9999999999,1);if not e then return nil end
    local rows,pos={},1
    while pos<=#body do
        if #rows>=48 then return nil end
        local digits,stop=body:match("^(%d+)():",pos)
        local size=digits and #digits<=3 and uint(digits,250,2)
        if not size or stop+size>#body then return nil end
        rows[#rows+1]=body:sub(stop+1,stop+size);pos=stop+size+1
    end
    return e,rows
end
local classes={WARRIOR=true,PALADIN=true,HUNTER=true,ROGUE=true,PRIEST=true,SHAMAN=true,MAGE=true,WARLOCK=true,DRUID=true}
local function raceWire(field)
    if #field>41 then return false end
    local token=field:match("^([A-Za-z]+)[023]$")
    return token and (raceNames[token] or (#token==1 and ("hdngoutr"):find(token,1,true))) or false
end
identity=function(row,wall)
    local f=split(row:sub(2),9)
    if not f or (#f~=8 and #f~=9) then return nil end
    local name=F.name(f[1]);local total=uint(f[2],15000)
    if name~=f[1] or not name or not total or not classes[f[3]]
        or (f[4]~="Horde" and f[4]~="Alliance") or not f[5]:match("^%a%a%a?%a?$")
        or #f[6]>24 or not uint(f[7],math.floor(wall)+30) or not uint(f[8],60,1)
        or (#f==9 and not raceWire(f[9])) then return nil end
    return {name=name,total=total,faction=f[4]}
end
function Q.receive(st,peer,p,r,c)
    if not ready(c) or not r or p.hops~=0 or p.target~=c.me
        or p.pool~=c.pool or not friend(r,c) or (r.route~="WHISPER" and r.route~="BNET") then return end
    local key=F.fold(p.origin);local s=st.sessions[key]
    if not s or s.pool~=c.pool or s.id~=r.id or not s.asked or c.now<s.asked
        or not ((c.now-s.asked<600) or (s.live and c.now>=s.live and c.now-s.live<420)) then return end
    if p.kind=="HA" then
        if #p.payload>250 then return end
        local f=split(p.payload,12)
        if not f or f[1]~="8" or tonumber(f[3])~=s.epoch or f[4]~=s.nonce or f[5]~="1" then return end
        if f[2]=="R" and (#f==5 or #f==6 and f[6]=="C") then
            s.asked,s.live,s.nonce=nil,nil,nil
        elseif f[2]=="S" and #f==8 and f[6]=="LK" and uint(f[7],10000) and uint(f[8],2147483646) then
            s.live=c.now
        elseif f[2]=="P" and #f==12 and f[6]=="V" and f[7]=="0" and f[8]=="64"
            and uint(f[9],2147483646) and f[10]=="-" and uint(f[11],24,1) and f[12]=="LK" then
            s.live=c.now -- fingerprints have no people/places; HB D is deliberately not ingested.
        end
        return
    end
    if p.kind~="HB" or #p.payload>600 then return end
    local b=s.budget
    if b and c.now<b.at then return end
    if not b or c.now-b.at>=60 then b={at=c.now,rows=0,bytes=0};s.budget=b end
    local g=st.budget
    if g and c.now<g.at then return end
    if not g or c.now-g.at>=60 then g={at=c.now,rows=0,bytes=0};st.budget=g end
    if b.bytes+#p.payload>14400 or b.rows>=240 or g.bytes+#p.payload>28800 or g.rows>=480 then return end
    b.bytes=b.bytes+#p.payload;g.bytes=g.bytes+#p.payload
    local e,rows=Q.decode(p.payload)
    if e~=s.epoch or not rows or b.rows+#rows>240 or g.rows+#rows>480 then return end
    b.rows=b.rows+#rows;g.rows=g.rows+#rows;s.live=c.now;r.epochAt=c.now
    local zone
    for _,row in ipairs(rows) do
        local kind=row:sub(1,1)
        if kind=="z" then
            local ref=row:sub(2)
            zone=#ref<=24 and (ref:match("^#%d+$") or ref:match("^@[%w_%-]+$")) and ref or nil
        elseif kind=="k" or kind=="s" then
            local value
            if kind=="k" then value=identity(row,c.wall)
            else
                local name,count=row:match("^s([^:]+):(%d+)$")
                local prior=name and s.known[F.fold(name)]
                local total=uint(count,15000)
                if prior and total then value={name=prior.name,total=total,faction=prior.faction} end
            end
            if value and c.tracked(value.name) and value.faction:sub(1,1)~=c.faction then
                local who=F.fold(value.name);local old=s.known[who]
                if (old or S.count(s.known)<64) and (not old or value.total>old.total) then
                    value.at=c.now;s.known[who]=value
                    if zone and value.total>0 then
                        local map=zone:sub(1,1)=="#" and uint(zone:sub(2),999999,1) or nil
                        if map or zone:sub(1,1)=="@" then
                            c.offer{net="overlord",name=value.name,faction=value.faction,map=map,
                                zone=not map and zone or nil,via=r.name,kind="relayed",got=c.now}
                        end
                    end
                end
            end
        end
    end
end
function Q.tick(st,peer,c)
    if not ready(c) then Q.cancel(st);return end
    if st.pool~=c.pool or st.me~=c.me then Q.cancel(st);st.pool,st.me=c.pool,c.me end
    for key,s in pairs(st.sessions) do
        for who,value in pairs(s.known) do
            if not c.tracked(value.name) or c.now<value.at or c.now-value.at>=900 then s.known[who]=nil end
        end
        local r=peer.routes[key]
        if not current(r,c) or r.epoch~=s.epoch or r.id~=s.id or s.pool~=c.pool
            or c.now<s.created then st.sessions[key]=nil end
    end
    local candidates={}
    for key,r in pairs(peer.routes) do
        if current(r,c) and announced(peer,r,c) then candidates[#candidates+1]={key=key,r=r} end
    end
    table.sort(candidates,function(a,b)
        if (a.r.route=="BNET")~=(b.r.route=="BNET") then return a.r.route=="BNET" end
        return a.key<b.key
    end)
    for _,v in ipairs(candidates) do
        local key,r=v.key,v.r;local s=st.sessions[key]
        if not s and S.count(st.sessions)<2 then
            s={epoch=r.epoch,pool=c.pool,id=r.id,created=c.now,known={}};st.sessions[key]=s
        end
        if s and (not s.attempt or c.now>=s.attempt and c.now-s.attempt>=200) then
            s.attempt=c.now
            st.serial=st.serial+1
            local keep=s.live and c.now>=s.live and c.now-s.live<420
            local nonce=math.floor(c.wall).."n"..math.floor(c.now*1000).."n"..st.serial.."f"
            if #nonce<=32 then
                local body=keep and "8:K:"..s.epoch or "8:V:"..s.epoch..":"..nonce..":1:LK:0:0:"..(c.faction=="A" and "H" or "A")
                local route=r.route=="BNET" and "BNET" or "WHISPER"
                local target=route=="BNET" and {id=r.id,name=r.name} or r.name
                local function valid(live)
                    live=live or c
                    local latest=peer.routes[key]
                    return st.sessions[key]==s and current(latest,live) and latest.epoch==s.epoch and latest.id==s.id
                end
                local function sent(at)
                    if not valid() then return end
                    if keep then s.kept=at else s.asked=at;s.nonce=nonce;s.live=nil end
                end
                P.emit(peer,c,"HR",body,route,target,"feed:"..key,200,false,{valid=valid,sent=sent})
            end
        end
    end
end
