-- Session-only roster evidence. Pure data helpers; no client calls or sends.
local _,N=...
local P,S={},N.Safe
N.Presence=P
P.TTL,P.EVERY,P.STEP=660,300,50
P.OPEN=60
-- Pinned build 70938 ClubMemberPresence: Online=1, Away=4, Busy=5.
local function accept(member,route)
    if not S.tab(member) or (route~="community" and route~="friend") then return nil end
    local name,zone=S.str(member.name,100),S.str(member.zone,120)
    local faction,guid=S.str(member.faction,16),S.str(member.guid,120)
    if not name or not zone or (faction~="Horde" and faction~="Alliance") then return nil end
    if S.secret(member.guid) then return nil end
    if route=="community" then
        local presence=S.num(member.presence)
        if presence~=1 and presence~=4 and presence~=5 then return nil end
    end
    local class=S.str(member.class,16)
    local level=S.num(member.level)
    if not (N.FriendShare and N.FriendShare.classOk(class)) then class=nil end
    if not (N.FriendShare and N.FriendShare.level(level)) then level=nil end
    return {zone=zone,route=route,faction=faction,guid=guid,class=class,level=level}
end
function P.accept(member,route)
    local ok,record=pcall(accept,member,route)
    if ok then return record end
end
function P.note(st,name,record,now)
    st.presence[name]={zone=record.zone,route=record.route,faction=record.faction,guid=record.guid,source=record.source,at=now}
end
-- A newly read source replaces its old evidence, even when it no longer yields
-- an online character. Sources not visited retain only their ordinary TTL.
function P.forget(records,source)
    for name,r in pairs(records) do
        if r.source==source then records[name]=nil end
    end
end
function P.sweep(st,now)
    for name,r in pairs(st.presence) do
        -- a guildmate's shared friend (source "g:") lives as long as FriendShare keeps it
        local ttl=type(r.source)=="string" and r.source:sub(1,2)=="g:" and N.FriendShare and N.FriendShare.TTL or P.TTL
        if now-r.at>=ttl or now<r.at then st.presence[name]=nil end
    end
end
