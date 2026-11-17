-- Session-only roster evidence. Pure data helpers; no client calls or sends.
local _,N=...
local P,S={},N.Safe
N.Presence=P
P.TTL,P.EVERY,P.STEP=660,300,50
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
    return {zone=zone,route=route,faction=faction,guid=guid}
end
function P.accept(member,route)
    local ok,record=pcall(accept,member,route)
    if ok then return record end
end
function P.note(st,name,record,now)
    st.presence[name]={zone=record.zone,route=record.route,faction=record.faction,guid=record.guid,at=now}
end
function P.sweep(st,now)
    for name,r in pairs(st.presence) do
        if now-r.at>=P.TTL or now<r.at then st.presence[name]=nil end
    end
end
