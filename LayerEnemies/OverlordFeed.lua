-- Overlord 2.5.4 protocol only; independently written, no donor code.
-- NH-free v8 comparison + named kill feed, not a ranking host.
local _,N=...
local Q,S,F,P={},N.Safe,N.Find,N.OverlordPeer
N.OverlordFeed=Q
-- lp6/lr/ld claim ranking pages, race-bearing pages, and differential v8 pages.
-- This location-only reader implements none of that ranking exchange. Do not
-- impersonate it merely to pass the provider's >=8 gate (SyncRelay:2843-2851).
Q.capability=""
Q.available=true -- unknown v8 requesters are served; never announce to a source.
function Q.new() return {sources={},sessions={},stops={},heard={},serial=0} end
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
    if not r.version then return true end -- first-hand K/HR can identify a provider before NH
    local major,minor,patch=(r.version or ""):match("^(%d+)%.(%d+)%.(%d+)")
    return major and (tonumber(major)>2 or tonumber(major)==2 and tonumber(minor)>=5)
end
local function friend(r,c)
    if r.route~="BNET" then return false end
    local key=P.key(r.name)
    if not c.groups or not c.guildNames then return false end
    for _,v in ipairs(c.friends or {}) do
        if v.friend and v.id==r.id and P.key(v.name)==key then
            local live=c.online and c.online(r.id)
            local identity=S.str(v.realm,60) and N.Adapters.peerIdentity(v.name,v.realm)
            local current=live and S.str(live.realm,60) and N.Adapters.peerIdentity(live.name,live.realm)
            if not identity or identity~=current then return false end
            if c.groups[identity] or c.guildNames[identity] then return false end
            return P.key(live.name)==key
        end
    end
    return false
end
local function eligible(r,c)
    return r and r.hops==0 and r.pool==c.pool and c.now>=r.at and supported(r) and friend(r,c)
end
local function current(r,c)
    return eligible(r,c) and r.epoch and r.epoch<=c.wall and c.now>=r.epochAt
end
-- Keep first-hand Battle.net evidence for this session, independently of C2's
-- 300-second route cache. Never learn a source from a forwarded or guild packet.
function Q.remember(st,r,c)
    if r.route~="BNET" or r.hops~=0 or r.pool~=c.pool then return end
    local key=P.key(r.name)
    if st.heard[key] or S.count(st.heard)<200 then st.heard[key]=r end
end
-- Only isolated Battle.net friends may be selected. Shared C2 lanes keep talking.
function Q.prepare(st,peer,c)
    peer.feed=st;st.peer=peer
    Q.flushStops(st,peer,c)
    if not Q.available or not ready(c) then return end
    for key,source in pairs(st.sources) do
        local r=st.heard[key]
        if not eligible(r,c) or source.id~=r.id or source.pool~=c.pool or source.me~=c.me
            or c.now<source.since then Q.stop(st,peer,c,key);st.sources[key]=nil end
    end
    local candidates={}
    for key,r in pairs(st.heard) do if eligible(r,c) then candidates[#candidates+1]={key=key,r=r} end end
    table.sort(candidates,function(a,b)
        if (a.r.route=="BNET")~=(b.r.route=="BNET") then return a.r.route=="BNET" end
        return a.key<b.key
    end)
    for _,v in ipairs(candidates) do
        if not st.sources[v.key] and S.count(st.sources)<2 then
            local live=c.online(v.r.id)
            st.sources[v.key]={name=v.r.name,id=v.r.id,route=v.r.route,since=c.now,pool=c.pool,me=c.me,
                identity=N.Adapters.peerIdentity(live.name,live.realm)}
        end
    end
end
function Q.suppressed(peer,c,route,name,id)
    local st=peer.feed
    if not st or (route~="BNET" and route~="WHISPER") then return false end
    for key,source in pairs(st.sources) do
        if name and P.key(name)==key or id and id==source.id then return true end
    end
    return false
end
local function quiet(st,key,c)
    local source=st.sources[key]
    if not source then return false end
    local a=st.peer and st.peer.announced
    if not a or a.pool~=c.pool or a.me~=c.me then return true end
    local last=math.max(a.names[key] or -math.huge,a.names[source.identity] or -math.huge,
        a.accounts[source.id] or -math.huge,a.unknown or -math.huge)
    return c.now-last>300
end
function Q.stop(st,peer,c,key)
    local s=st.sessions[key]
    st.sessions[key]=nil
    if not s or not s.opened or not peer or not c then return end
    local row={name=s.name,id=s.id,route=s.route,pool=s.pool,me=st.me,epoch=s.epoch,at=c.now}
    st.stops[key]=row
    Q.flushStops(st,peer,c)
end
function Q.flushStops(st,peer,c)
    Q.pruneStops(st,c)
    if not c or not c.stopAllowed or type(c.send)~="function" then return end
    for key,row in pairs(st.stops) do
        local queued=row.queued and (not c.stopQueued or c.stopQueued(row))
        if not queued and row.pool==c.pool and row.me==c.me then
            local route=row.route=="BNET" and "BNET" or "WHISPER"
            local target=route=="BNET" and {name=row.name,id=row.id} or row.name
            local function valid(live)
                return st.stops[key]==row and live.pool==row.pool and live.me==row.me
                    and live.now>=row.at and row.safeAt and live.now-row.safeAt<=60
            end
            row.queued=P.emit(peer,c,"HR","8:X:"..row.epoch,route,target,"stop:"..key,0,true,
                {stop=row,valid=valid,sent=function() st.stops[key]=nil end})
        end
    end
end
function Q.cancel(st,peer,c)
    for key in pairs(st.sessions) do Q.stop(st,peer,c,key) end
    st.sources={}
    Q.flushStops(st,peer,c)
end
function Q.pruneStops(st,c)
    if not c or not S.num(c.now) then return end
    for key,row in pairs(st.stops) do
        if c.stopPaused then row.safeAt=nil
        elseif not row.safeAt then row.safeAt=c.now end
        if c.now<row.at or row.safeAt and c.now-row.safeAt>60 then st.stops[key]=nil end
    end
end
function Q.observe(st,peer,p,r,c)
    if not ready(c) or not r or p.hops~=0 then return end
    local e
    -- Learn only this direct peer's current epoch; never turn it into global authority.
    if p.kind=="K" then
        local f=split(p.payload,13)
        if f and #f==13 and P.key(f[1])==P.key(p.origin)
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
        if r.epoch~=e then Q.stop(st,peer,c,P.key(r.name)) end
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
        or p.pool~=c.pool or not friend(r,c) or r.route~="BNET" then return end
    local key=P.key(p.origin);local s=st.sessions[key]
    if not s or s.pool~=c.pool or s.id~=r.id or not s.asked or c.now<s.asked
        or not ((c.now-s.asked<600) or (s.live and c.now>=s.live and c.now-s.live<420)) then return end
    if p.kind=="HA" then
        if #p.payload>250 then return end
        local f=split(p.payload,12)
        if not f or f[1]~="8" or tonumber(f[3])~=s.epoch or f[4]~=s.nonce or f[5]~="1" then return end
        if f[2]=="R" and (#f==5 or #f==6 and f[6]=="C") then
            s.asked,s.live,s.nonce=nil,nil,nil
            s.silent,s.delay=0,200
        elseif f[2]=="S" and #f==8 and f[6]=="LK" and uint(f[7],10000) and uint(f[8],2147483646) then
            s.live=c.now;s.silent,s.delay=0,200
        elseif f[2]=="P" and #f==12 and f[6]=="V" and f[7]=="0" and f[8]=="64"
            and uint(f[9],2147483646) and f[10]=="-" and uint(f[11],24,1) and f[12]=="LK" then
            s.live=c.now;s.silent,s.delay=0,200 -- fingerprints have no people/places; HB D is deliberately not ingested.
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
    s.silent,s.delay=0,200
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
    if not Q.available then Q.cancel(st,peer,c);return end
    if not ready(c) then Q.cancel(st,peer,c);return end
    if st.pool~=c.pool or st.me~=c.me then st.pool,st.me=c.pool,c.me end
    Q.prepare(st,peer,c)
    for key,s in pairs(st.sessions) do
        for who,value in pairs(s.known) do
            if not c.tracked(value.name) or c.now<value.at or c.now-value.at>=900 then s.known[who]=nil end
        end
        local r=st.heard[key]
        if not current(r,c) or r.epoch~=s.epoch or r.id~=s.id or s.pool~=c.pool
            or c.now<s.created then Q.stop(st,peer,c,key) end
    end
    local candidates={}
    for key,r in pairs(st.heard) do
        if current(r,c) and quiet(st,key,c) then candidates[#candidates+1]={key=key,r=r} end
    end
    table.sort(candidates,function(a,b)
        if (a.r.route=="BNET")~=(b.r.route=="BNET") then return a.r.route=="BNET" end
        return a.key<b.key
    end)
    for _,v in ipairs(candidates) do
        local key,r=v.key,v.r;local s=st.sessions[key]
        if not s and S.count(st.sessions)<2 then
            s={name=r.name,route=r.route,epoch=r.epoch,pool=c.pool,id=r.id,created=c.now,known={}};st.sessions[key]=s
        end
        if s and (not s.attempt or c.now>=s.attempt and c.now-s.attempt>=(s.delay or 200)) then
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
                    local latest=st.heard[key]
                    return st.sessions[key]==s and quiet(st,key,live) and current(latest,live) and latest.epoch==s.epoch and latest.id==s.id
                end
                local function sent(at,live)
                    if not valid(live) then return end
                    if keep then s.kept=at else
                        s.opened=true;s.asked=at;s.nonce=nonce;s.live=nil
                        s.silent=math.min(5,(s.silent or 0)+1)
                        s.delay=math.min(1800,200*2^(s.silent-1))
                    end
                end
                P.emit(peer,c,"HR",body,route,target,"feed:"..key,s.delay or 200,false,{valid=valid,sent=sent})
            end
        end
    end
end
