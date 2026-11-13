-- Tracked names are configuration; locations and alert history are session-only.
local _,N=...
local F,S={},N.Safe
N.Find=F
F.MAX,F.TTL,F.ALERT=5,600,300
function F.name(raw)
    raw=S.str(raw,100)
    if not raw then return nil end
    raw=raw:match("^%s*(.-)%s*$")
    local first,second=raw:match("^([%a\128-\255]+) ([%a\128-\255]+)$")
    if first and #first<=36 and #second<=36 then return raw,raw:lower() end
    if raw:match("^[%a\128-\255]+%-?[%a'\128-\255]*$") and #raw>=2 and #raw<=72 then return raw,raw:lower() end
end
function F.new(saved)
    local st={names={},locations={},alerts={}}
    if S.tab(saved) then
        for i=1,F.MAX do local name=F.name(saved[i]); if name then F.add(st,name) end end
    end
    return st
end
function F.add(st,raw)
    local name,key=F.name(raw)
    if not name then return false,"enter a readable player name." end
    for _,v in ipairs(st.names) do if v:lower()==key then return true end end
    if #st.names>=F.MAX then return false,"track at most five names; clear one first." end
    st.names[#st.names+1]=name; return true
end
function F.remove(st,raw)
    if raw==nil then st.names={}; st.locations={}; st.alerts={}; return end
    for i=#st.names,1,-1 do if st.names[i]==raw then table.remove(st.names,i) end end
    st.locations[raw]=nil; st.alerts[raw]=nil
end
function F.hashes(name,home)
    local out={}
    local first,realm=name:match("^([^%-]+)%-(.+)$")
    first=first or name
    local function add(n,r) local h=N.Hash.player(n,r); if h then out[h]=true end end
    add(first,realm or home or ""); add(first,"")
    -- Forever's detector hashes UnitName's two returns as name + realm:
    -- its second return is actually a surname. Match that exact wire behaviour.
    local given,surname=name:match("^([^ ]+) (.+)$")
    if given then add(given,surname) end
    return out
end
function F.own(st,e,zone,now)
    if e.faction~="opposite" or not e.name or not e.source or not e.source:match("^own ") then return end
    local label=e.displayName or e.name
    for _,name in ipairs(st.names) do
        local short=name:match("^([^%-]+)") or name
        if name:lower()==label:lower() or (not name:find(" ",1,true) and short:lower()==e.name:lower() and (not name:find("-",1,true) or N.Hash.player(short,e.realm)==N.Hash.player(short,name:match("%-(.+)$")))) then
            st.locations[name]={name=name,own=true,zone=zone,at=now,class=e.class,level=e.level}
        end
    end
end
-- r: {sender, zone, at, enemies}. An enemy matches by name hash (War Effort) or by the name itself (HeadHunter,
-- relayed HeadHunter): the full name, or a realm-less tracked name against the reported name.
local function named(name,e)
    if not e.name then return false end
    local want,got=name:lower(),e.name:lower()
    return want==got or (want:match("^([^%-]+)")==got)
end
function F.report(st,r,home)
    for _,name in ipairs(st.names) do
        local hashes=F.hashes(name,home)
        for _,e in ipairs(r.enemies) do
            if (e.hash and hashes[e.hash]) or named(name,e) then
                local old=st.locations[name]
                if not old or (not old.own and old.at<=r.at) or r.at-old.at>=F.TTL then
                    st.locations[name]={name=name,zone=r.zone,at=r.at,spotter=r.sender,class=e.class,level=e.level,possible=true}
                end
            end
        end
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
            row.same=loc.own or spot==true
            row.probably=spot=="probably"         -- an equal key while ours is ambiguous: not a certain same layer
            row.travel=loc.zone~=zone
            row.status=loc.own and "is on YOUR layer" or "possible match, seen by "..loc.spotter
            row.canAsk=not row.same and not row.travel and loc.spotter~=nil
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
