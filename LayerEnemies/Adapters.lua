local _, N = ...
local A,S = {},N.Safe
N.Adapters=A
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
    return {key=guid,name=name,realm=realm,class=class,level=level,faction=faction}
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
function A.grouped() return S.call(IsInGroup)==true end
-- Foreign friend lists, never written to. nil = addon absent, false = unreadable.
-- Shapes read from Bulo Layer Forever 3.0.24 (Guild.lua) and LayerSwap 1.14.18.
function A.friendLists()
    local out={}
    local ok,list=pcall(function()
        local ns=_G.BuloLayerForever
        if ns==nil then return nil end
        if not S.tab(ns) or not S.tab(ns.Guild) or not S.tab(ns.Guild.list) then return false end
        return ns.Guild.list
    end)
    if ok then out.bulo=list else out.bulo=false end
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
    return out
end
function A.policy(prefix,kind,sender,channel)
    -- Read the installed version's persisted settings; never mutate or join/send.
    local ok,allowed,reason=pcall(function()
        if not A.loaded("WarEffortScout") then return false,"not installed" end
        local api=C_AddOns
        local metadata=S.tab(api) and api.GetAddOnMetadata or GetAddOnMetadata
        if S.str(S.call(metadata,"WarEffortScout","Version"),30)~="0.2.13" then return false,"privacy unavailable: unsupported version" end
        local db=_G.WarEffortScoutDB
        if not S.tab(db) or not S.tab(db.ignored) or S.secret(db.silent) or S.secret(db.guildOnly) or type(db.silent)~="boolean" or type(db.guildOnly)~="boolean" then return false,"privacy settings unavailable" end
        if db.silent then return false,"unavailable: War Effort silent mode" end
        -- Legacy-network enablement is local, not exposed; do not guess it.
        if prefix=="ZRAD1" then return false,"legacy privacy unavailable" end
        if prefix~="WEFF1" then return false,"prefix" end
        local me,realm=S.call(UnitName,"player"); me,realm=S.str(me),S.str(realm)
        realm=realm or S.str(S.call(GetRealmName))
        if not me or not realm then return false,"own identity unavailable" end
        local name,remoteRealm=sender:match("^([^%-]+)%-(.+)$")
        name=name or sender; remoteRealm=remoteRealm or realm
        if N.Hash.nameKey(name,remoteRealm)==N.Hash.nameKey(me,realm) or sender:lower()==me:lower() then return false,"own echo" end
        -- War Effort uses Ambiguate(..., 'none'); demand the same readable key.
        local short=S.str(S.call(Ambiguate,sender,"none"),100)
        if not short then return false,"ignore policy unavailable" end
        local ignored=S.clean(db.ignored[short:lower()])
        if S.secret(db.ignored[short:lower()]) then return false,"ignore policy unavailable" end
        if ignored~=nil and ignored~=false then return false,"ignored sender" end
        -- Honor the client's ignore list too, only when a supported query is available.
        local friends=C_FriendList
        if not S.tab(friends) or type(S.clean(friends.IsIgnored))~="function" then return false,"client ignore policy unavailable" end
        local isIgnored=S.call(friends.IsIgnored,sender)
        if type(isIgnored)~="boolean" then return false,"client ignore policy unavailable" end
        if isIgnored then return false,"ignored sender" end
        if kind=="GUILD" then
            if S.call(IsInGuild)~=true then return false,"guild unavailable" end
            return true,"guild"
        end
        if kind~="CHANNEL" or db.guildOnly then return false,"channel disallowed" end
        local faction=S.str(S.call(UnitFactionGroup,"player"),20)
        local expected=faction=="Alliance" and "WarEffortPubA" or faction=="Horde" and "WarEffortPubH" or nil
        if not expected or channel~=expected then return false,"wrong channel" end
        local id=S.num(S.call(GetChannelName,expected))
        if not id or id<1 then return false,"channel membership unavailable" end
        return true,"public"
    end)
    if not ok then return false,"privacy settings unavailable" end
    return allowed,reason
end
