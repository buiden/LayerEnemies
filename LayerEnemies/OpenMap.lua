-- Independent reader of OpenMapLoc's tab-separated position format. No donor code or runtime dependency.
local _,N=...
local O,S,F,I={},N.Safe,N.Find,N.Invite
N.OpenMap=O
O.TTL=150
function O.decode(text)
    if S.secret(text) or type(text)~="string" or #text>64 then return nil end
    if text=="L0" then return "clear" end
    local map,x,y,class,level=text:match("^L1\t(%d+)\t([01]%.%d%d%d%d)\t([01]%.%d%d%d%d)\t(%u*)\t(%d+)$")
    map,x,y,level=tonumber(map),tonumber(x),tonumber(y),tonumber(level)
    if not map or map<1 or map>999999 or x>1 or y>1 or (x==0 and y==0) or level>80 then return nil end
    return {map=map,x=x,y=y,class=class~="" and class or nil,level=level}
end
-- Battle.net supplies a display realm (possibly with spaces), not a surname. Never guess a missing realm.
function O.bnName(character,realm)
    character,realm=S.str(character,100),S.str(realm,60)
    if not character or not realm then return nil end
    realm=realm:gsub("[%s%-]","")
    local suffix=character:match("%-(.+)$")
    if suffix then
        if F.fold(suffix)~=F.fold(realm) then return nil end
    else character=character.."-"..realm end
    return I.name(character)
end
function O.faction(theirs,ours)
    theirs,ours=S.str(theirs),S.str(ours)
    if (theirs~="Alliance" and theirs~="Horde") or (ours~="Alliance" and ours~="Horde") then return nil end
    return theirs==ours and "same" or "opposite"
end
-- Exact full identity only; Invite strips the home realm, never a foreign realm or a surname.
function O.match(st,sender,me)
    local full,key=I.name(sender)
    if not key or not me or F.fold(key)==F.fold(me) then return nil end
    key,full=F.fold(key),F.fold(full)
    for _,name in ipairs(st.names) do
        local want=F.fold(name)
        if want==key or want==full then return name end
    end
end
