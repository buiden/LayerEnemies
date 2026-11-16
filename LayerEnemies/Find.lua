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
local function realmName(realm) return (realm:gsub("[%s%-]","")) end
local function parts(name)
    local base,realm=name:match("^([^%-]+)%-(.*)$")
    return base or name,realm and realmName(realm)
end
function F.name(raw)
    raw=S.str(raw,100)
    if not raw then return nil end
    raw=raw:match("^%s*(.-)%s*$")
    local first,second=raw:match("^([%a\128-\255]+) ([%a\128-\255]+)$")
    if first and #first<=36 and #second<=36 then return raw,F.fold(raw) end
    -- Grandfather every old accepted spelling, including trailing hyphens,
    -- apostrophes and the old 72-byte single-word/qualified limit.
    if raw:match("^[%a\128-\255]+%-?[%a'\128-\255]*$") and #raw>=2 and #raw<=72 then return raw,F.fold(raw) end
    local base,realm=parts(raw)
    if not realm or #realm<1 or #realm>40 or not realm:match("^[%a%d'\128-\255]+$") then return nil end
    first,second=base:match("^([%a\128-\255]+) ([%a\128-\255]+)$")
    if (first and #first<=36 and #second<=36) or (base:match("^[%a\128-\255]+$") and #base<=36) then
        local name=base.."-"..realm
        return name,F.fold(name)
    end
end
local function index(map,key,entry)
    local bucket=map[key]
    if not bucket then bucket={}; map[key]=bucket end
    bucket[#bucket+1]=entry
end
function F.rebuild(st)
    st.byHash,st.byName,st.entries={},{},{}
    st.homeKey=st.home and F.fold(realmName(st.home))
    for _,name in ipairs(st.names) do
        local short,realm=parts(name)
        local hashes,realmHash=F.hashes(name,st.home)
        -- Keep the legacy parser's trailing-hyphen spelling too: its own realm is empty.
        if name:sub(-1)=="-" then realmHash=N.Hash.player(short,nil) end
        local entry={name=name,key=F.fold(name),short=short,shortKey=F.fold(short),
            realm=realm,realmKey=realm and F.fold(realm),realmHash=realmHash,twoWord=short:find(" ",1,true)~=nil}
        st.entries[#st.entries+1]=entry
        index(st.byName,entry.shortKey,entry)
        for hash in pairs(hashes) do index(st.byHash,hash,entry) end
    end
end
-- Login can precede a readable realm. Learn it once; transient blanks never invalidate the set.
function F.home(st,home)
    home=S.str(home)
    if not st.home and home then st.home=home; F.rebuild(st) end
end
function F.new(saved,home)
    local st={names={},locations={},alerts={},places={},home=S.str(home),known=N.Known.new(),epoch=0}
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
    local given,surname=first:match("^([^ ]+) (.+)$")
    if given then add(given,surname) end
    return out,realmHash
end
-- One per-entry rule for immediate findings and the Known read projection.
-- A two-word own display has no realm unless it explicitly carries a suffix;
-- UnitName's second return is a surname on Forever, not realm evidence.
local function matches(entry,e,homeKey)
    if e.source=="own" and not entry.twoWord then
        return entry.key==F.fold(e.name) or (entry.shortKey==F.fold(e.ownName or e.name)
            and (not entry.realm or N.Hash.player(entry.short,e.realm)==entry.realmHash))
    end
    local base,realm=parts(e.name)
    if entry.shortKey~=F.fold(base) then return false end
    if not entry.realm then return true end
    if realm then return entry.realmKey==F.fold(realm) end
    return true,entry.realmKey~=homeKey or nil
end
local function location(e,name,realmUnknown)
    local loc={}
    for k,v in pairs(e) do loc[k]=v end
    loc.name=name; loc.cached=true; loc.realmUnknown=realmUnknown
    loc.own=e.source=="own" or nil
    if loc.own then loc.layerKnown=e.layer~=nil
    else loc.possible=true; loc.relayed=e.source=="relayed" end
    return loc
end
local function remember(st,entry,e)
    if not e then return end
    local match,realmUnknown=matches(entry,e,st.homeKey)
    if not match then return end
    local name=entry.name
    local old=st.locations[name]
    if not old or (e.kind=="seen" and (old.kind=="claim" or e.at>=old.at))
        or (e.kind=="claim" and (old.kind=="claim" or e.at-old.at>=F.TTL) and e.at>=old.at) then
        st.locations[name]=location(e,name,realmUnknown)
    end
end
function F.own(st,e,zone,now,readNow)
    if e.faction~="opposite" or not e.name or not e.source or not e.source:match("^own ") then return end
    local cached=N.Known.put(st.known,{name=e.displayName or e.name,ownName=e.name,realm=e.realm,
        zone=zone,x=e.x,y=e.y,pos="observer",at=now,source="own",spotter="you",class=e.class,level=e.level,
        layer=N.Layer.key(e.layer),ns=e.layer and "server" or "unknown",kind="seen",epoch=st.epoch,detail=e.source},readNow or now)
    local base=parts(e.displayName or e.name)
    local label,key=F.fold(base),F.fold(e.name)
    for _,entry in ipairs(st.byName[label] or {}) do remember(st,entry,cached) end
    if label~=key then
        for _,entry in ipairs(st.byName[key] or {}) do
            if not entry.twoWord then remember(st,entry,cached) end
        end
    end
end
-- Buckets are keyed by base; realms are checked per entry, never stripped from
-- identity. An unqualified tracked entry accepts any named realm.
function F.report(st,r,home)
    F.home(st,home)
    local function hashPut(entry,e,realmUnknown,evidenceName)
        local name=entry.name
        local old=st.locations[name]
        -- Hash-only and deferred HeadHunter evidence keep their existing lifetime.
        local keep=old and r.relayed and not old.relayed and r.at-old.at<F.TTL
        if not keep and (not old or (not old.own and old.at<=r.at) or r.at-old.at>=F.TTL) then
            st.locations[name]={name=name,zone=r.zone,at=r.at,spotter=r.sender,class=e.class,level=e.level,possible=true,relayed=r.relayed==true,
                source=r.source=="headhunter" and "headhunter" or nil,realmUnknown=realmUnknown,evidenceName=evidenceName}
        end
    end
    for _,e in ipairs(r.enemies) do
        local named=S.str(e.name,100)
        local base,realm
        if named then base,realm=parts(named); base=F.fold(base); realm=realm and F.fold(realm) end
        if e.hash then
            for _,entry in ipairs(st.byHash[e.hash] or {}) do
                -- A lossy hash cannot override explicit contradictory realm evidence.
                local conflict=base==entry.shortKey and realm and entry.realm and realm~=entry.realmKey
                if not conflict then hashPut(entry,e,entry.realm~=nil or nil) end
            end
        end
        if named then
            local candidates=st.byName[base]
            local source=r.source or (r.relayed and "relayed" or "spy")
            if source=="headhunter" then
                for _,entry in ipairs(candidates or {}) do
                    local match,realmUnknown=matches(entry,e,st.homeKey)
                    if match then hashPut(entry,e,realmUnknown,named) end
                end
            else
                local cached=N.Known.put(st.known,{name=e.name,zone=r.zone,x=r.x,y=r.y,pos=r.pos,at=r.at,
                    source=source,spotter=r.sender,class=e.class,level=e.level,layer=r.layer,ns=r.ns,
                    kind=(r.relayed or source=="death") and "claim" or "seen"},r.now or r.at)
                for _,entry in ipairs(candidates or {}) do remember(st,entry,cached) end
            end
        end
    end
end
-- A bounded read projection, not a scan on receipt. The hot paths above still use
-- the prebuilt Find20 indices. Reusing memory on add does not hash incoming reports.
local function project(st,loc,now,zone,sameSpotter)
    local row={}
    for k,v in pairs(loc) do row[k]=v end
    row.age=now-loc.at
    row.lastKnown=loc.cached and row.age>=F.TTL or nil
    row.travel=loc.zone~=zone
    local spot=not loc.own and sameSpotter and sameSpotter(loc.spotter,loc.zone)
    row.same=not row.travel and not row.lastKnown and ((loc.own and loc.layerKnown and loc.epoch==st.epoch) or spot==true)
    row.probably=not row.travel and not row.lastKnown and spot=="probably"
    row.status=loc.own and (row.same and "is on YOUR layer" or not loc.layerKnown and "seen by you, layer unknown" or "seen by you")
        or loc.source=="death" and "named as killer (claim)"
        or loc.relayed and "possible match, seen in a relayed report"
        or "possible match, seen by "..(loc.spotter or "unknown")
    if row.realmUnknown then row.status=row.status.." · realm not confirmed" end
    if row.lastKnown then row.status="last known: "..row.status end
    row.canAsk=not row.same and not row.travel and not row.lastKnown and not loc.own
        and loc.spotter~=nil and not loc.relayed and loc.kind~="claim"
    return row
end
function F.rows(st,now,zone,sameSpotter)
    local out={}
    N.Known.prune(st.known,now)
    for _,entry in ipairs(st.entries) do
        local name=entry.name
        local seen,reported,seenUnknown,reportedUnknown
        for _,pair in pairs(st.known.entries) do
            for _,slot in ipairs({"seen","reported"}) do
                local e=pair[slot]
                if e then
                    local match,realmUnknown=matches(entry,e,st.homeKey)
                    if match then
                        if slot=="seen" and (not seen or e.at>seen.at) then seen,seenUnknown=e,realmUnknown
                        elseif slot=="reported" and (not reported or e.at>reported.at) then reported,reportedUnknown=e,realmUnknown end
                    end
                end
            end
        end
        local loc=st.locations[name]
        if loc and (loc.cached or now-loc.at>=F.TTL or now<loc.at) then loc=nil end
        if loc and loc.evidenceName then
            -- Named HeadHunter findings live outside Known; newly learned home
            -- identity must still remove their no-realm warning, never a hash's.
            local _,realmUnknown=matches(entry,{name=loc.evidenceName},st.homeKey)
            loc.realmUnknown=realmUnknown
        end
        -- Prefer a fresh first-hand finding. Otherwise display the newest evidence
        -- as the summary, while retaining both independently aged detail lines.
        local primary,primaryUnknown=seen,seenUnknown
        if reported and (not seen or (now-seen.at>=F.TTL and reported.at>seen.at)) then primary,primaryUnknown=reported,reportedUnknown end
        local keep=loc and primary and primary.kind=="claim" and not loc.relayed and now-loc.at<F.TTL
        if primary and not keep and (not loc or primary.at>=loc.at or (primary.source=="own" and now-primary.at<F.TTL)) then loc=location(primary,name,primaryUnknown) end
        st.locations[name]=loc
        local row=loc and project(st,loc,now,zone,sameSpotter) or {name=name,status="Not located — needs your sighting or a nearby War Effort user."}
        if seen then row.seen=project(st,location(seen,name,seenUnknown),now,zone,sameSpotter) end
        if loc and loc.source=="headhunter" and (not seen or loc.at>seen.at) then row.seen=project(st,loc,now,zone,sameSpotter) end
        if reported then row.reported=project(st,location(reported,name,reportedUnknown),now,zone,sameSpotter) end
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
    if not row.at or now-row.at>=F.TTL or now<row.at then return false end
    local old=st.alerts[row.name]
    if old and old.zone==row.zone and now-old.at<F.ALERT then return false end
    st.alerts[row.name]={at=now,zone=row.zone}; return true
end
function F.boundary(st)
    st.epoch=st.epoch+1
    -- Only anonymous hash matches belong to the old zone epoch. Named memory and
    -- independent OpenMap places survive; old own evidence is no current-layer proof.
    for name,loc in pairs(st.locations) do if not loc.cached then st.locations[name]=nil end end
end
