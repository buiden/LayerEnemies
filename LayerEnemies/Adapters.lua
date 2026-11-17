local _, N = ...
local A,S = {},N.Safe
N.Adapters=A

-- WHO UI ownership is temporary and session-only. No hiding windows or replacing SendWho.
-- Registered frames are detached during our query. On timeout/Stop their registrations return immediately;
-- a short-lived OnEvent guard swallows the late result (max 30 s). A player's SendWho wins ownership.
A.WHO_LATE=30
local whoLease,whoSending,whoHooked=nil,false,nil
local function whoLater(delay,fn)
    return S.tab(_G.C_Timer) and type(S.clean(_G.C_Timer.After))=="function" and pcall(_G.C_Timer.After,delay,fn)
end
local function whoFrames() return {_G.FriendsFrame,_G.LFGWhoListFrame,_G.WhoFrame} end
local function whoRoute(ui)
    pcall(function()
        local f=_G.C_FriendList
        if S.tab(f) and type(S.clean(f.SetWhoToUi))=="function" then f.SetWhoToUi(ui) end
    end)
end
local function whoRegisters(q)
    for _,v in ipairs(q.frames) do
        if v.detached then
            local ok=pcall(function() v.frame:RegisterEvent("WHO_LIST_UPDATE") end)
            if ok then v.detached=false end
        end
    end
end
local function whoRelease(q)
    if whoLease~=q then return end
    whoRegisters(q)
    for _,v in ipairs(q.frames) do
        pcall(function()
            -- Never overwrite a script another addon changed while we held the lease.
            if v.frame:GetScript("OnEvent")==v.guard then v.frame:SetScript("OnEvent",v.script) end
        end)
    end
    q.block=false; whoLease=nil
    local visible=false
    for _,frame in pairs(whoFrames()) do
        pcall(function() if frame:IsVisible() then visible=true end end)
    end
    whoRoute(visible)
end
function A.whoEnd(reason)
    local q=whoLease; if not q then return end
    q.active=false; whoRegisters(q)
    if reason=="result" or q.event then
        q.event=true
        -- Registration order is not promised by the client: keep guards until this event has finished.
        if not whoLater(0,function() whoRelease(q) end) then whoRelease(q) end
    elseif reason~="timeout" and reason~="stop" then whoRelease(q) end
end
function A.whoEvent()
    local q=whoLease
    if not q then return false end
    local time=S.num(S.call(GetTime))
    local mine=q.active and time and time>=q.at and time-q.at<N.HopAny.WHO
    A.whoEnd("result")
    return mine
end
local function whoHush(cancel)
    if whoLease then whoRelease(whoLease) end
    local q={at=S.num(S.call(GetTime)) or 0,frames={},active=true,block=true}
    whoLease=q
    -- Without a deadline timer, do not acquire UI state which could be left behind.
    if not whoLater(A.WHO_LATE,function() whoRelease(q) end) then whoLease=nil; return end
    pcall(function()
        local f=_G.C_FriendList
        if whoHooked~=f and type(S.clean(_G.hooksecurefunc))=="function" then
            _G.hooksecurefunc(f,"SendWho",function()
                local old=whoLease
                if old and not whoSending then
                    whoRelease(old)
                    if type(old.cancel)=="function" then pcall(old.cancel) end
                end
            end)
            whoHooked=f
        end
    end)
    q.cancel=cancel
    if whoHooked~=_G.C_FriendList then return end -- missing hook: retain the old UI behavior
    for _,frame in pairs(whoFrames()) do
        pcall(function()
            for _,method in ipairs({"IsEventRegistered","RegisterEvent","UnregisterEvent","GetScript","SetScript"}) do
                if type(S.clean(frame[method]))~="function" then return end
            end
            if frame:IsEventRegistered("WHO_LIST_UPDATE")~=true then return end
            local v={frame=frame,script=frame:GetScript("OnEvent")}
            v.guard=function(self,event,...)
                if event=="WHO_LIST_UPDATE" and q.block then return end
                if type(v.script)=="function" then return v.script(self,event,...) end
            end
            q.frames[#q.frames+1]=v
            frame:SetScript("OnEvent",v.guard)
            -- Mark first so even a partially failing client method is restored on every exit.
            v.detached=true
            frame:UnregisterEvent("WHO_LIST_UPDATE")
        end)
    end
    whoRoute(true)
end
-- Source: pinned Forever FriendList API; UI suppression reverses the former no-manipulation rule.

-- Presence readers: build 70938 (Gethe/wow-ui-source bebcb6bf).
-- Protect both API access and field reads. Second return identifies a secret
-- refusal without retaining the offending value or inspecting account data.
local function presenceRead(fn)
    local hidden=false
    local function value(v)
        if S.secret(v) then hidden=true; return nil end
        return v
    end
    local ok,result=pcall(fn,value)
    if hidden then return nil,"secret" end
    if ok then return result end
end
local function presenceId(v)
    return S.str(v,100) or (S.num(v) and v>=0 and v%1==0 and v or nil)
end
function A.clubs()
    return presenceRead(function(v)
        local api=v(_G.C_Club)
        if not S.tab(api) or type(v(api.GetSubscribedClubs))~="function" then return nil end
        local clubs=v(api.GetSubscribedClubs())
        if not S.tab(clubs) then return nil end
        local out={}
        for i=1,20 do
            local club=v(clubs[i]); if club==nil then break end
            if not S.tab(club) then return nil end
            local id,kind=presenceId(v(club.clubId)),S.num(v(club.clubType))
            if not id or not kind then return nil end
            -- ClubType.BattleNet=0; Character/Guild/Other are not Battle.net communities.
            if kind==0 then out[#out+1]={id=id,type=kind} end
        end
        return out
    end)
end
function A.clubMemberIds(clubId)
    return presenceRead(function(v)
        clubId=presenceId(v(clubId)); if not clubId then return nil end
        local api=v(_G.C_Club)
        if not S.tab(api) or type(v(api.GetClubMembers))~="function" then return nil end
        local ids=v(api.GetClubMembers(clubId))
        if not S.tab(ids) then return nil end
        local out={}
        for i=1,1000 do
            local id=v(ids[i]); if id==nil then break end
            id=presenceId(id); if not id then return nil end
            out[#out+1]=id
        end
        return out
    end)
end
function A.clubMember(clubId,memberId)
    return presenceRead(function(v)
        clubId,memberId=presenceId(v(clubId)),presenceId(v(memberId))
        if not clubId or not memberId then return nil end
        local api=v(_G.C_Club)
        if not S.tab(api) or type(v(api.GetMemberInfo))~="function" then return nil end
        local r=v(api.GetMemberInfo(clubId,memberId))
        if not S.tab(r) then return nil end
        local name,zone=S.str(v(r.name),100),S.str(v(r.zone),120)
        local faction,presence=S.num(v(r.faction)),S.num(v(r.presence))
        local guid=S.str(v(r.guid),120)
        -- PvPFaction: Horde=0, Alliance=1. Neutral and unavailable are not evidence.
        if not name or not zone or not presence or (faction~=0 and faction~=1) then return nil end
        return {name=name,zone=zone,faction=faction==0 and "Horde" or "Alliance",presence=presence,guid=guid}
    end)
end
function A.bnFriends()
    local refused=0
    local rows,why=presenceRead(function(v)
        local api=v(_G.C_BattleNet)
        local count=v(_G.BNGetNumFriends)
        local project=S.num(v(_G.WOW_PROJECT_ID))
        if not S.tab(api) or type(count)~="function" or type(v(api.GetFriendAccountInfo))~="function" or not project then return nil end
        local n=S.num(v(count()))
        if not n or n<0 or n%1~=0 then return nil end
        local out={}
        for i=1,math.min(n,200) do
            local r,reason=presenceRead(function(read)
                local account=read(api.GetFriendAccountInfo(i))
                if not S.tab(account) then return nil end
                local game=read(account.gameAccountInfo)
                if not S.tab(game) then return nil end
                local online,pid=read(game.isOnline),S.num(read(game.wowProjectID))
                if online~=true or pid~=project then return nil end
                local name,realm=S.str(read(game.characterName),100),S.str(read(game.realmName),60)
                local zone,faction=S.str(read(game.areaName),120),S.str(read(game.factionName),16)
                local guid=S.str(read(game.playerGuid),120)
                if not name or not realm or not zone or (faction~="Horde" and faction~="Alliance") then return nil end
                return {name=name,realm=realm,zone=zone,faction=faction,guid=guid}
            end)
            if reason=="secret" then refused=refused+1 end
            if r then out[#out+1]=r end
        end
        return out
    end)
    return rows,why or refused
end
-- Peer-only readers, independent of the four presence readers above. Source:
-- Forever build 70938 BattleNet/Club documentation, bebcb6bf309cf41b41bd74f8ca651e6a105b2676.
local function gameId(id) id=S.num(id); return id and id>0 and id%1==0 and id or nil end
local function peerGame(game,v)
    if not S.tab(game) then return nil end
    local project=S.num(v(_G.WOW_PROJECT_ID))
    local id=gameId(v(game.gameAccountID))
    if not project or not id or v(game.isOnline)~=true or S.str(v(game.clientProgram),16)~="WoW"
        or S.num(v(game.wowProjectID))~=project or v(game.isInCurrentRegion)~=true then return nil end
    local name,realm,faction=S.str(v(game.characterName),100),S.str(v(game.realmName),60),S.str(v(game.factionName),16)
    if not name or not realm or (faction~="Horde" and faction~="Alliance") or not N.OpenMap.bnName(name,realm) then return nil end
    return {id=id,name=name,realm=realm,faction=faction}
end
function A.clubPeer(clubId,memberId)
    return presenceRead(function(v)
        clubId,memberId=presenceId(v(clubId)),presenceId(v(memberId))
        if not clubId or not memberId then return nil end
        local api=v(_G.C_Club)
        if not S.tab(api) or type(v(api.GetMemberInfo))~="function" then return nil end
        local r=v(api.GetMemberInfo(clubId,memberId))
        if not S.tab(r) then return nil end
        return gameId(v(r.bnetAccountId))
    end)
end
function A.bnGame(id,withGuid)
    return presenceRead(function(v)
        id=gameId(v(id)); if not id then return nil end
        local api=v(_G.C_BattleNet)
        if not S.tab(api) or type(v(api.GetGameAccountInfoByID))~="function" then return nil end
        local game=v(api.GetGameAccountInfoByID(id))
        local r=peerGame(game,v)
        if r and r.id==id then
            if withGuid then r.guid=S.str(v(game.playerGuid),80) end
            return r
        end
    end)
end
function A.bnAccount(id)
    return presenceRead(function(v)
        id=gameId(v(id)); if not id then return nil end
        local api=v(_G.C_BattleNet)
        if not S.tab(api) or type(v(api.GetAccountInfoByID))~="function" then return nil end
        local r=v(api.GetAccountInfoByID(id))
        if not S.tab(r) then return nil end
        return peerGame(v(r.gameAccountInfo),v)
    end)
end
function A.bnFriendGames()
    return presenceRead(function(v)
        local api,count=v(_G.C_BattleNet),v(_G.BNGetNumFriends)
        if not S.tab(api) or type(count)~="function" then return nil end
        local n=S.num(v(count()))
        if not n or n<0 or n%1~=0 then return nil end
        local many=v(api.GetFriendNumGameAccounts)
        local read=v(api.GetFriendGameAccountInfo)
        local one=v(api.GetFriendAccountInfo)
        if not (type(many)=="function" and type(read)=="function") and type(one)~="function" then return nil end
        local out={}
        for i=1,math.min(n,200) do
            if type(many)=="function" and type(read)=="function" then
                local total=S.num(v(S.call(many,i)))
                if total and total>=0 and total%1==0 then
                    for j=1,math.min(total,10) do
                        local r=presenceRead(function(value) return peerGame(value(read(i,j)),value) end)
                        if r then out[#out+1]=r end
                    end
                end
            else
                local r=presenceRead(function(value)
                    local account=value(one(i))
                    if S.tab(account) then return peerGame(value(account.gameAccountInfo),value) end
                end)
                if r then out[#out+1]=r end
            end
        end
        return out
    end)
end
-- Source: pinned Forever FriendList API; temporary WHO UI ownership is managed above.
function A.whoTerm(zoneName)
    local f,e=_G.C_FriendList,_G.Enum
    local tag=S.str(_G.WHO_TAG_ZONE,32)
    zoneName=S.str(zoneName,120)
    if not S.tab(f) or not tag or not zoneName or tag:find('["\\]') or zoneName:find('["\\]') then return nil end
    for _,key in ipairs({"SendWho","GetNumWhoResults","GetWhoInfo"}) do
        if type(S.clean(f[key]))~="function" then return nil end
    end
    if not S.tab(e) or not S.tab(e.SocialWhoOrigin) or not S.num(e.SocialWhoOrigin.Social) then return nil end
    return tag..'"'..zoneName..'"'
end
function A.who(term,cancel)
    local f,e=_G.C_FriendList,_G.Enum
    if not S.str(term,180) or not S.tab(f) or type(S.clean(f.SendWho))~="function"
        or not S.tab(e) or not S.tab(e.SocialWhoOrigin) or not S.num(e.SocialWhoOrigin.Social) then return false end
    whoHush(cancel)
    whoSending=true
    local ok,result=pcall(f.SendWho,term,e.SocialWhoOrigin.Social)
    whoSending=false
    local accepted=ok and not S.secret(result) and result~=false
    if not accepted then A.whoEnd("error") end
    return accepted
end
-- Read no more than 49 rows. A malformed row is skipped, never converted to a short name.
function A.whoRows()
    local f=_G.C_FriendList
    if not S.tab(f) or type(S.clean(f.GetNumWhoResults))~="function" or type(S.clean(f.GetWhoInfo))~="function" then return nil end
    local ok,n=pcall(f.GetNumWhoResults)
    n=ok and S.num(n) or nil
    if not n or n<0 or n%1~=0 then return nil end
    local rows={}
    for i=1,math.min(n,49) do
        local fine,r=pcall(f.GetWhoInfo,i)
        if fine and S.tab(r) then
            local read,name,area=pcall(function() return S.str(r.fullName,100),S.str(r.area,120) end)
            if read and name and area then rows[#rows+1]={fullName=name,area=area} end
        end
    end
    return rows
end
function A.loaded(name)
    local api=C_AddOns
    if S.tab(api) then return S.call(api.IsAddOnLoaded,name)==true end
    return S.call(IsAddOnLoaded,name)==true
end
function A.zone(map)
    local api=C_Map
    return S.tab(api) and N.Layer.zone(map,api.GetMapInfo) or nil
end
function A.location()
    local api=C_Map
    if not S.tab(api) then return nil end
    local map=S.num(S.call(api.GetBestMapForUnit,"player"))
    local zone=A.zone(map)
    local p=S.call(api.GetPlayerMapPosition,map,"player")
    if not zone or not S.tab(p) then return zone end
    local x,y=S.call(p.GetXY,p)
    x,y=S.num(x),S.num(y)
    -- Child-map coordinates cannot be plotted on the parent without conversion.
    if map==zone and x and y and x>=0 and x<=1 and y>=0 and y<=1 then return zone,x,y end
    return zone
end
function A.unit(unit)
    if not S.str(unit,30) then return nil end
    if S.call(UnitExists,unit)~=true or S.call(UnitIsPlayer,unit)~=true or S.call(UnitIsUnit,unit,"player")==true then return nil end
    local guid=S.str(S.call(UnitGUID,unit),120)
    if not guid or not guid:match("^Player%-") then return nil end
    local name,realm=S.call(UnitName,unit)
    name,realm=S.str(name),S.str(realm)
    local displayName=name
    if name and realm and not name:find(" ",1,true) then displayName=name.." "..realm end
    if not realm then realm=S.str(S.call(GetRealmName)) end
    local _,class=S.call(UnitClass,unit)
    class=S.str(class,20)
    local level=S.num(S.call(UnitLevel,unit))
    if level and (level%1~=0 or level< -1 or level>100) then level=nil end
    local own=S.str(S.call(UnitFactionGroup,"player"),20)
    local theirs=S.str(S.call(UnitFactionGroup,unit),20)
    local faction="unknown"
    if (own=="Alliance" or own=="Horde") and (theirs=="Alliance" or theirs=="Horde") then
        faction=own~=theirs and "opposite" or "same"
    end
    return {key=guid,name=name,displayName=displayName,realm=realm,class=class,level=level,faction=faction}
end
-- This API is optional: its runtime availability and each return are checked.
-- Race never establishes faction; there are neutral/cross-faction races.
function A.enrich(guid)
    if not S.str(guid,120) or not guid:match("^Player%-") then return nil end
    local _,class,_,race,_,name,realm,level=S.call(GetPlayerInfoByGUID,guid)
    level=S.num(level)
    if level and (level%1~=0 or level< -1 or level>100) then level=nil end
    return S.str(name),S.str(realm),S.str(class,20),S.str(race,40),level
end
function A.buloSnapshot(epoch,now,known)
    local ns=_G.BuloLayerForever
    if ns==nil then return {status=A.loaded("BuloLayerForever") and "Bulo data unavailable" or "not installed"} end
    if not S.tab(ns) then error("namespace shape") end
    local current=S.clean(ns.current)
    if current~=nil and not N.Layer.bulo(current) then error("layer shape") end
    if not S.tab(ns.Radar) or not S.tab(ns.Radar.seen) then error("radar shape") end
    local observations={}; local inspected=0
    for guid,e in pairs(ns.Radar.seen) do
        inspected=inspected+1; if inspected>512 then break end
        guid=S.str(guid,160)
        if guid and S.tab(e) then
            local at,src=S.num(e.at),S.str(e.src,15)
            local hostile=S.clean(e.hostile)
            local previous=known and known[guid]
            if at and (not previous or previous.at<at) and at>epoch and at<=now and now-at<=45 and (src=="target" or src=="mouseover" or src=="nameplate") and type(hostile)=="boolean" then
                observations[#observations+1]={key=guid,at=at,source="Bulo "..src,hostile=hostile,faction="unknown"}
            end
        end
    end
    return {status=current and "installed" or "installed / no data",current=current,observations=observations,ns=ns}
end
function A.buloSubscribe(ns,callback)
    local ok=pcall(function()
        if not S.tab(ns) or type(S.clean(ns.On))~="function" then error("no bus") end
        for _,event in ipairs({"LFS_LAYER","LFS_RAW","LFS_TRANSFER"}) do
            ns:On(event,function() pcall(callback,event) end)
        end
    end)
    return ok
end
function A.bulo(epoch,now,known)
    local ok,result=pcall(A.buloSnapshot,epoch,now,known)
    if not ok then return {status="Bulo data unavailable"} end
    return result
end
-- Wall clock, the base of both foreign lists' "at" fields.
function A.wall() return S.num(S.call(_G.time)) end
-- WarBoard's pure protocol driver consumes only this guarded client snapshot.
-- Ruleset spellings are protocol facts; unknown/numeric realm tags stay unknown.
function A.warboardContext(receiveOnly)
    return presenceRead(function(v)
        if not receiveOnly and (A.inCombat() or A.inInstance()~=false) then return nil end
        local now,wall=S.num(v(S.call(GetTime))),S.num(v(A.wall()))
        local realm=S.str(v(S.call(GetRealmName)),60)
        local faction=S.str(v(S.call(UnitFactionGroup,"player")),16)
        local tags={PvP="pvp",PvE="normal",RP="rp",RPPvP="rppvp",hardcore="hardcore"}
        local rs=realm and tags[N.Directory.rulesetTag(realm)]
        if not now or not wall or not rs or (faction~="Alliance" and faction~="Horde") then return nil end
        local api=v(_G.C_AddOns)
        local version=S.tab(api) and S.str(v(S.call(v(api.GetAddOnMetadata),"LayerEnemies","Version")),40) or nil
        return {now=now,wall=wall,rs=rs,faction=faction,version=version}
    end)
end
function A.warboardTime()
    return presenceRead(function(v)
        local at=S.num(v(S.call(_G.GetServerTime)))
        return at and at>0 and at<=4000000000 and at%1==0 and at or nil
    end)
end
function A.warboardSelf()
    return presenceRead(function(v)
        local fn=v(_G.UnitNameUnmodified) or v(_G.UnitName)
        local first,last=S.call(fn,"player")
        first,last=S.str(v(first),36),v(last)
        if not first or (last~=nil and last~="" and not S.str(last,36)) then return nil end
        local name=first..(last and last~="" and (" "..last) or "")
        local guid=S.str(v(S.call(UnitGUID,"player")),80)
        if not guid or not guid:match("^Player%-%d+%-%x+$") or not N.Find.name(name) then return nil end
        return {name=name,guid=guid}
    end)
end
-- HBD wire worldX/worldY correspond to Blizzard vector Y/X, respectively.
-- Client-only conversion; no copied map transforms or donor library dependency.
-- Forever MapDocumentation.lua at bebcb6bf: (continentID, vector2) -> uiMapID, vector2.
function A.worldMapPos(worldX,worldY,instance)
    return presenceRead(function(v)
        worldX,worldY,instance=S.num(v(worldX)),S.num(v(worldY)),S.num(v(instance))
        if not worldX or not worldY or not instance or math.abs(worldX)>100000000 or math.abs(worldY)>100000000
            or instance<0 or instance>100000 or instance%1~=0 then return nil end
        local api,vector=v(_G.C_Map),v(_G.CreateVector2D)
        if not S.tab(api) or type(vector)~="function" or type(v(api.GetMapPosFromWorldPos))~="function" then return nil end
        local point=v(vector(worldY,worldX)); if point==nil then return nil end
        local map,pos=api.GetMapPosFromWorldPos(instance,point)
        map,pos=S.num(v(map)),v(pos)
        if not map or map<1 or map>999999 or map%1~=0 or pos==nil then return nil end
        local zone=A.zone(map)
        if not zone then return nil end
        if zone~=map then
            map,pos=api.GetMapPosFromWorldPos(instance,point,zone)
            map,pos=S.num(v(map)),v(pos)
            if map~=zone or pos==nil then return nil end
        end
        local get=v(pos.GetXY); if type(get)~="function" then return nil end
        local x,y=get(pos); x,y=S.num(v(x)),S.num(v(y))
        if not x or not y or x<0 or x>1 or y<0 or y>1 then return nil end
        return {map=map,x=x,y=y}
    end)
end
-- Unreadable (secret, missing, error) counts as grouped: the hop then refuses rather than assume.
function A.grouped() return S.call(IsInGroup)~=false end
-- true/false when readable, nil otherwise (callers fail closed).
function A.inInstance()
    local v=S.call(IsInInstance)
    if type(v)=="boolean" then return v end
end
-- Guild host state (read only). Each answer fails closed: unreadable is nil (or "in combat").
-- guildMember(name) -> true (exactly one online roster entry), false (none, offline, or ambiguous), nil (unreadable).
-- Compared by Invite.name keys (our realm dropped, any other kept): a foreign-realm sender never matches a bare
-- entry or one of our realm; a sender of our realm is ambiguous while a namesake of another realm is listed.
A.ROSTER_FRESH,A.ROSTER_EVERY,A.ROSTER_MAX=120,15,1000
A.roster={at=nil,askedAt=nil}
local function base(name) return name:match("^([^%-]+)%-") or name end
function A.guildMember(name)
    local _,want,target=N.Invite.name(name)
    if not want or S.call(IsInGuild)~=true then return nil end
    local spelled=base(target)                         -- the name part as the client spells it, case included
    local local_=not want:find("-",1,true)
    local count=S.num(S.call(GetNumGuildMembers))
    if not count or count<1 or count>A.ROSTER_MAX or count%1~=0 then return nil end
    local read=_G.GetGuildRosterInfo
    if S.secret(read) or type(read)~="function" then return nil end
    local found,other={},false
    for i=1,count do
        local ok,entry,_,_,_,_,_,_,_,online=pcall(read,i)
        if not ok or S.secret(entry) or S.secret(online) or type(entry)~="string" then return nil end
        local _,key,etarget=N.Invite.name(entry)
        if key==want and base(etarget)==spelled then found[#found+1]=online==true
        elseif key and local_ and base(key)==want then other=true end
    end
    if other then return false end
    return #found==1 and found[1]
end
-- A complete membership snapshot for watch-list removal. Offline is still a
-- member; a partial/unreadable roster proves no departures. No new roster request.
function A.guildNames()
    if S.call(IsInGuild)~=true then return nil end
    local count=S.num(S.call(GetNumGuildMembers))
    if not count or count<1 or count>A.ROSTER_MAX or count%1~=0 then return nil end
    local keys={}
    for i=1,count do
        local name=S.str((S.call(GetGuildRosterInfo,i)),100)
        local _,key=N.Invite.name(name)
        if not key then return nil end
        keys[key]=true
    end
    return keys
end
-- Seconds since the last GUILD_ROSTER_UPDATE, or nil.
function A.rosterSeen(now) A.roster.at=S.num(now) end
function A.rosterAge(now) if A.roster.at and S.num(now) then return now-A.roster.at end end
-- Asks the server for a new roster, at most once per 15 s. Returns true when it asked; inside the 15 s it returns
-- false and the seconds left, and marks the request owed (Main retries an owed one when the limit has passed).
function A.rosterRefresh(now)
    now=S.num(now)
    if not now then return false end
    if A.roster.askedAt and now-A.roster.askedAt<A.ROSTER_EVERY and now>=A.roster.askedAt then
        A.roster.owed=true
        return false,A.roster.askedAt+A.ROSTER_EVERY-now
    end
    A.roster.owed=nil
    local gi=_G.C_GuildInfo
    if not S.tab(gi) or S.secret(gi.GuildRoster) or type(gi.GuildRoster)~="function" then return false end
    A.roster.askedAt=now
    return pcall(gi.GuildRoster)==true
end
function A.inCombat()
    local a,b=S.call(InCombatLockdown),S.call(UnitAffectingCombat,"player")
    if type(a)~="boolean" or type(b)~="boolean" then return true end
    return a or b
end
-- {raid, leader, members = {names}} or nil when unreadable.
function A.party()
    local raid,leader,count=S.call(IsInRaid),S.call(UnitIsGroupLeader,"player"),S.num(S.call(GetNumGroupMembers))
    if type(raid)~="boolean" or type(leader)~="boolean" or not count or count<0 then return nil end
    local members={}
    for i=1,4 do
        -- every unit read must answer true or false; nil, secret, a throw or a missing API is unreadable
        local exists=S.call(UnitExists,"party"..i)
        if type(exists)~="boolean" then return nil end
        if exists then
            local n,realm=S.call(UnitName,"party"..i)
            n,realm=S.str(n,60),S.str(realm,60)
            if not n then return nil end
            members[#members+1]=realm and realm~="" and (n.."-"..realm) or n
        end
    end
    -- outside a raid the count must be ourselves plus the listed party units (0 when alone)
    if not raid and count~=(#members>0 and #members+1 or 0) and not (count==1 and #members==0) then return nil end
    return {raid=raid,leader=leader,members=members}
end
-- Bulo's guild layer lines, heard on LFSw/GUILD: "L <key>|<zone>|<h or ->" (Bulo Guild.lua:118). We never send an
-- L line; the only LFSw send is the one-letter question "Q" from a click (Hosts.ask, Wire). Kept in the shape of Bulo's own Guild.list, so they fill the host list when Bulo is not installed.
A.GUILD_LINES,A.GUILD_MAX=720,256
function A.guildLine(list,text,sender,wall)
    if type(text)~="string" or #text>80 or not S.num(wall) then return false,"invalid" end
    local key,zone,host=text:match("^L ([^|]+)|([^|]*)|([h%-])$")
    if not key or not N.Layer.key(key) or key~=N.Layer.key(key) then return false,"invalid" end
    if zone~="" and not zone:match("^%d+$") then return false,"invalid" end
    -- the sender's own line, named by the one name rule: our realm dropped, any other realm kept
    local _,_,name=N.Invite.name(sender)
    if not name then return false,"name" end
    for k,v in pairs(list) do if wall-v.at>=A.GUILD_LINES then list[k]=nil end end
    if not list[name] then
        local n,oldest,ok=0,nil,nil
        for k,v in pairs(list) do n=n+1; if not oldest or v.at<oldest then oldest,ok=v.at,k end end
        if n>=A.GUILD_MAX then list[ok]=nil end
    end
    list[name]={key=key,zone=zone~="" and tonumber(zone) or nil,host=host=="h",at=wall}
    return true
end
-- Foreign friend lists, never written to. nil = addon absent, false = unreadable.
-- Shapes read from Bulo Layer Forever 3.0.24 (Guild.lua) and LayerSwap 1.14.18.
-- guildLines: our own list of heard LFSw lines, used in Bulo's place when Bulo is not installed.
-- heard: hosts from LayerSwap replies to our own requests (Hosts.lua), used in the book's place when LayerSwap is not
-- installed.
function A.friendLists(guildLines,heard)
    local out={}
    local ok,list=pcall(function()
        local ns=_G.BuloLayerForever
        if ns==nil then return nil end
        if not S.tab(ns) or not S.tab(ns.Guild) or not S.tab(ns.Guild.list) then return false end
        return ns.Guild.list
    end)
    if ok then out.bulo=list else out.bulo=false end
    if out.bulo==nil and S.tab(guildLines) and next(guildLines)~=nil then out.bulo=guildLines end
    ok,list=pcall(function()
        local db=_G.LayerSwapDB
        if db==nil then return nil end
        if not S.tab(db) then return false end
        local book=db.book
        if S.secret(book) then return false end
        if book==nil then return {} end
        return type(book)=="table" and book or false
    end)
    if ok then out.book=list else out.book=false end
    -- LayerSwap loaded: its book only (empty until its saved table exists); our remembered replies stand in only
    -- while it is not loaded
    if out.book==nil and A.loaded("LayerSwap") then out.book={} end
    if out.book==nil and S.tab(heard) and next(heard)~=nil then out.book=heard end
    return out
end
-- Client ignore list for any name (immediate sender or a wrapper's origin). Unreadable counts as ignored.
function A.ignored(name)
    local friends=C_FriendList
    if not S.tab(friends) or type(S.clean(friends.IsIgnored))~="function" then return true,"client ignore policy unavailable" end
    local isIgnored=S.call(friends.IsIgnored,name)
    if type(isIgnored)~="boolean" then return true,"client ignore policy unavailable" end
    return isIgnored,isIgnored and "ignored sender" or nil
end
-- War Effort 1.6.6 traffic is read whether or not War Effort is installed: WEFF1 on GUILD, PARTY or RAID only.
-- Whispers (embassy partner state) and channels are Phase 2. Which types each route carries is checked after decode.
-- Our own full name and Invite key. Forever may return first/surname instead of name/realm.
-- Read the raw pair under pcall: Safe.call cleans a secret second value to nil, which would create a bare-first alias.
-- Only the actual home realm is folded; no surname or foreign realm becomes an alias.
function A.ownIdentity()
    if S.secret(UnitName) or type(UnitName)~="function" then return nil end
    local ok,name,second=pcall(UnitName,"player")
    if not ok or S.secret(name) or S.secret(second) then return nil end
    name=S.str(name,100)
    local home=S.str(S.call(N.Invite.home),60)
    if not name or not home then return nil end
    local _,key,full=N.Invite.name(name)
    if not key or key:find("-",1,true) then return nil end
    if second~=nil and second~="" then
        second=S.str(second,60)
        if not second then return nil end
        local function norm(v) return (v:lower():gsub("[%s%-']","")) end
        local realm=S.str(S.call(GetRealmName),60)
        local isRealm=norm(second)==norm(home) or (realm and norm(second)==norm(realm))
        local surname=full:match("^%S+ (%S+)$")
        if isRealm then
            -- A single word plus a surname-shaped realm could be either representation: do not guess.
            if not surname and N.Invite.name(full.." "..second) then return nil end
        elseif surname then
            if second:lower()~=surname:lower() then return nil end
        else
            if second:find("-",1,true) then return nil end
            full=full.." "..second
        end
    end
    local _,ownKey,target=N.Invite.name(full)
    return target,ownKey
end
-- Own name (with or without home realm) -> "own echo"; unreadable identity -> refused.
local function echo(sender)
    local _,me=A.ownIdentity()
    if not me then return "own identity unavailable" end
    local _,key=N.Invite.name(sender)
    if key and key==me then return "own echo" end
end
-- Spy family (lane C1): each prefix on its own routes (Spy.ROUTES); never our own lines; the ignore lists apply.
function A.spyPolicy(prefix,kind,sender)
    local ok,allowed,reason=pcall(function()
        local routes=N.Spy.ROUTES[prefix] or N.Incident.ROUTES[prefix]
        if not routes then return false,"prefix" end
        if not routes[kind] then return false,"route" end
        local mine=echo(sender); if mine then return false,mine end
        local ignored,why=A.ignored(sender)
        if ignored then return false,why end
        return true,"spy"
    end)
    if not ok then return false,"policy unavailable" end
    return allowed,reason
end
-- zoneByName(name) -> the zone (uiMapID, map type 3) shown under that name, or nil. Looked up among the zones of our
-- continent and of Azeroth (947); a name two zones share is no answer. Cached per session.
local zoneNames
function A.zoneByName(name)
    if type(name)~="string" or name=="" then return nil end
    local api=C_Map
    if not S.tab(api) or type(api.GetMapChildrenInfo)~="function" then return nil end
    if not zoneNames then
        local found={}
        -- add(root) -> true when that lookup gave a list with at least one readable zone
        local function add(root)
            local list=S.call(api.GetMapChildrenInfo,root,3,true)
            if not S.tab(list) then return false end
            local any=false
            for _,info in ipairs(list) do
                local id,n=S.tab(info) and S.num(info.mapID),S.tab(info) and S.str(info.name,70)
                if id and n then
                    any=true
                    if found[n]==nil then found[n]=id elseif found[n]~=id then found[n]=false end
                end
            end
            return any
        end
        local here=A.zone(S.num(S.call(api.GetBestMapForUnit,"player")))
        local info=here and S.call(api.GetMapInfo,here)
        local continent=S.tab(info) and S.num(info.parentMapID)
        local near=continent~=nil and continent>0 and add(continent)
        local world=add(947)
        -- kept only when both lookups gave data; otherwise this answer stands alone and the next line looks again
        if near and world then zoneNames=found end
        return found[name] or nil
    end
    return zoneNames[name] or nil
end
-- HeadHunter: read on PARTY, RAID and WHISPER only. Never sent on, never joined, never answered.
function A.hhPolicy(kind,sender)
    local ok,allowed,reason=pcall(function()
        if kind~="PARTY" and kind~="RAID" and kind~="WHISPER" then return false,"route" end
        local mine=echo(sender); if mine then return false,mine end
        local ignored,why=A.ignored(sender)
        if ignored then return false,why end
        return true,"headhunter"
    end)
    if not ok then return false,"policy unavailable" end
    return allowed,reason
end
function A.policy(prefix,kind,sender)
    local ok,allowed,reason=pcall(function()
        if prefix~="WEFF1" then return false,"prefix" end
        if kind~="GUILD" and kind~="PARTY" and kind~="RAID" and kind~="WHISPER" then return false,"route" end
        local mine=echo(sender); if mine then return false,mine end
        local ignored,why=A.ignored(sender)
        if ignored then return false,why end
        if kind=="GUILD" then
            if S.call(IsInGuild)~=true then return false,"guild unavailable" end
            return true,"guild"
        end
        if kind=="WHISPER" then return true,"whisper" end
        return true,"group"
    end)
    if not ok then return false,"policy unavailable" end
    return allowed,reason
end
-- Types each route may carry (WEFF1): guild C E H G, Q Y (lane A2), home group C E H X, whisper J (a layer request).
A.WE_TYPES={GUILD={C=true,E=true,H=true,G=true,Q=true,Y=true,D=true},PARTY={C=true,E=true,H=true,X=true},RAID={C=true,E=true,H=true,X=true},
    WHISPER={J=true,P=true,W=true}}
-- The continent a map is on (C_Map parents up to mapType 2), or nil
function A.continent(map)
    local id=S.num(map)
    for _=1,8 do
        if not id or id<1 then return nil end
        local info=S.tab(C_Map) and S.call(C_Map.GetMapInfo,id)
        if not S.tab(info) then return nil end
        if S.num(info.mapType)==2 then return id end
        id=S.num(info.parentMapID)
    end
end
