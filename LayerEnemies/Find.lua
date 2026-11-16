-- Tracked names are configuration; locations and alert history are session-only.
local _,N=...
local F,S={},N.Safe
N.Find=F
F.MAX,F.TTL,F.ALERT=20,600,300
-- Stock Lua lower() handles ASCII; keep this bounded to the two-byte letters used in player names.
local lower,upper={},{}
local function utf8(n) return string.char(192+math.floor(n/64),128+n%64) end
local function pair(a,b)
    a,b=utf8(a),utf8(b); lower[a]=b; upper[b]=a
end
for n=0x00C0,0x00DE do if n~=0x00D7 then pair(n,n+32) end end
-- Extended-A switches parity in the L/N and Z groups; dotted/dotless I, kra, apostrophe-n and long s stay alone.
for _,range in ipairs({{0x0100,0x012F},{0x0132,0x0137},{0x0139,0x0148},{0x014A,0x0177},{0x0179,0x017E}}) do
    for n=range[1],range[2],2 do pair(n,n+1) end
end
pair(0x0178,0x00FF)
for n=0x0410,0x042F do pair(n,n+32) end
for n=0x0400,0x040F do pair(n,n+80) end
function F.fold(s) return (s:lower():gsub("[\194-\223][\128-\191]",lower)) end
function F.name(raw)
    raw=S.str(raw,100)
    if not raw then return nil end
    raw=raw:match("^%s*(.-)%s*$")
    local first,second=raw:match("^([%a\128-\255]+) ([%a\128-\255]+)$")
    if first and #first<=36 and #second<=36 then return raw,F.fold(raw) end
    if raw:match("^[%a\128-\255]+%-?[%a'\128-\255]*$") and #raw>=2 and #raw<=72 then return raw,F.fold(raw) end
end
local function index(map,key,entry)
    local bucket=map[key]
    if not bucket then bucket={}; map[key]=bucket end
    bucket[#bucket+1]=entry
end
function F.rebuild(st)
    st.byHash,st.byName={},{}
    for _,name in ipairs(st.names) do
        local short=name:match("^([^%-]+)") or name
        local hashes,realmHash=F.hashes(name,st.home)
        -- Keep the legacy parser's trailing-hyphen spelling too: its own realm is empty.
        if name:sub(-1)=="-" then realmHash=N.Hash.player(short,nil) end
        local entry={name=name,key=F.fold(name),short=short,shortKey=F.fold(short),
            realm=name:find("-",1,true)~=nil,realmHash=realmHash}
        index(st.byName,entry.key,entry)
        if entry.shortKey~=entry.key then index(st.byName,entry.shortKey,entry) end
        for hash in pairs(hashes) do index(st.byHash,hash,entry) end
    end
end
-- Login can precede a readable realm. Learn it once; transient blanks never invalidate the set.
function F.home(st,home)
    home=S.str(home)
    if not st.home and home then st.home=home; F.rebuild(st) end
end
function F.new(saved,home)
    local st={names={},locations={},alerts={},places={},home=S.str(home)}
    local seen={}
    if S.tab(saved) then
        for i=1,F.MAX do
            local name,key=F.name(saved[i])
            if name and not seen[key] then st.names[#st.names+1]=name; seen[key]=true end
        end
    end
    F.rebuild(st)
    return st
end
function F.add(st,raw)
    local name,key=F.name(raw)
    if not name then return false,"enter a readable player name." end
    for _,v in ipairs(st.names) do if F.fold(v)==key then return true end end
    if #st.names>=F.MAX then return false,"track at most 20 names; clear one first." end
    st.names[#st.names+1]=name; F.rebuild(st); return true
end
function F.remove(st,raw)
    if raw==nil then
        local changed=#st.names>0
        st.names={}; st.locations={}; st.alerts={}; st.places={}
        if changed then F.rebuild(st) end
        return
    end
    local _,key=F.name(raw)
    if not key then return end
    local changed=false
    for i=#st.names,1,-1 do
        local name=st.names[i]
        if F.fold(name)==key then
            table.remove(st.names,i); st.locations[name]=nil; st.alerts[name]=nil; st.places[name]=nil
            changed=true
        end
    end
    if changed then F.rebuild(st) end
end
function F.hashes(name,home)
    local out={}
    local first,realm=name:match("^([^%-]+)%-(.+)$")
    first=first or name
    local function title(s)
        return (s:gsub("%S+",function(word)
            local c=word:match("^[\194-\223][\128-\191]") or word:sub(1,1)
            return (upper[c] or c:upper())..word:sub(#c+1)
        end))
    end
    local function put(n,r) local h=N.Hash.player(n,r); if h then out[h]=true end; return h end
    local function add(n,r)
        if type(r)~="string" then r="" end
        -- Sender hashes lower ASCII only. Try the spelling as given (base behaviour), folded and game-style
        -- Titlecase; never change the wire hash.
        local realmHash=put(n,r)
        n,r=F.fold(n),F.fold(r)
        put(n,r); put(title(n),title(r))
        return realmHash
    end
    local realmHash=add(first,realm or home or ""); add(first,"")
    -- Forever's detector hashes UnitName's two returns as name + realm:
    -- its second return is actually a surname. Match that exact wire behaviour.
    local given,surname=name:match("^([^ ]+) (.+)$")
    if given then add(given,surname) end
    return out,realmHash
end
function F.own(st,e,zone,now)
    if e.faction~="opposite" or not e.name or not e.source or not e.source:match("^own ") then return end
    local label,key=F.fold(e.displayName or e.name),F.fold(e.name)
    local function put(entry)
        local name=entry.name
        -- layerKnown: our layer was known when we saw them; without it "on YOUR layer" would be a guess
        st.locations[name]={name=name,own=true,zone=zone,at=now,class=e.class,level=e.level,layerKnown=e.layer~=nil}
    end
    local exact=st.byName[label]
    for _,entry in ipairs(exact or {}) do if entry.key==label then put(entry) end end
    local candidates=label==key and exact or st.byName[key]
    for _,entry in ipairs(candidates or {}) do
        if entry.shortKey==key and not entry.name:find(" ",1,true) and (not entry.realm or N.Hash.player(entry.short,e.realm)==entry.realmHash) then
            put(entry)
        end
    end
end
-- Name buckets retain all aliases: a realm-less report can match several qualified
-- tracked names, but a qualified report matches only that full name (as before).
function F.report(st,r,home)
    F.home(st,home)
    local function put(entry,e)
        local name=entry.name
        local old=st.locations[name]
        -- a relayed report never replaces a fresh first-hand one (which can be asked)
        local keep=old and r.relayed and not old.relayed and r.at-old.at<F.TTL
        if not keep and (not old or (not old.own and old.at<=r.at) or r.at-old.at>=F.TTL) then
            st.locations[name]={name=name,zone=r.zone,at=r.at,spotter=r.sender,class=e.class,level=e.level,possible=true,relayed=r.relayed==true}
        end
    end
    for _,e in ipairs(r.enemies) do
        if e.hash then for _,entry in ipairs(st.byHash[e.hash] or {}) do put(entry,e) end end
        if e.name then for _,entry in ipairs(st.byName[F.fold(e.name)] or {}) do put(entry,e) end end
    end
end
function F.rows(st,now,zone,sameSpotter)
    local out={}
    for _,name in ipairs(st.names) do
        local loc=st.locations[name]
        if loc and (now-loc.at>=F.TTL or now<loc.at) then st.locations[name]=nil; loc=nil end
        local row={name=name,status="Not located — needs your sighting or a nearby War Effort user."}
        if loc then
            for k,v in pairs(loc) do row[k]=v end
            row.age=now-loc.at
            local spot=not loc.own and sameSpotter and sameSpotter(loc.spotter,loc.zone)
            row.same=(loc.own and loc.layerKnown) or spot==true
            row.probably=spot=="probably"         -- an equal key while ours is ambiguous: not a certain same layer
            row.travel=loc.zone~=zone
            row.status=loc.own and (loc.layerKnown and "is on YOUR layer" or "seen by you, layer unknown")
                or loc.relayed and "possible match, seen in a relayed report"
                or "possible match, seen by "..loc.spotter
            row.canAsk=not row.same and not row.travel and loc.spotter~=nil and not loc.relayed
        end
        local place=st.places[name]
        if place and (now-place.at>=N.OpenMap.TTL or now<place.at) then st.places[name]=nil; place=nil end
        if place then
            row.place={}
            for k,v in pairs(place) do row.place[k]=v end
            row.place.age=now-place.at
            if not loc then row.status="shared position"; row.canAsk=false end
        end
        out[#out+1]=row
    end
    return out
end
function F.alert(st,row,now)
    if not row.at then return false end
    local old=st.alerts[row.name]
    if old and old.zone==row.zone and now-old.at<F.ALERT then return false end
    st.alerts[row.name]={at=now,zone=row.zone}; return true
end
function F.boundary(st) st.locations={} end
