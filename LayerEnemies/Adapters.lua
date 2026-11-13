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
-- Unreadable (secret, missing, error) counts as grouped: the hop then refuses rather than assume.
function A.grouped() return S.call(IsInGroup)~=false end
-- Bulo's guild layer lines, heard on LFSw/GUILD: "L <key>|<zone>|<h or ->" (Bulo Guild.lua:118). We never send on
-- LFSw. Kept in the shape of Bulo's own Guild.list, so they fill the host list when Bulo is not installed.
A.GUILD_LINES,A.GUILD_MAX=720,256
function A.guildLine(list,text,sender,wall)
    if type(text)~="string" or #text>80 or not S.num(wall) then return false,"invalid" end
    local key,zone,host=text:match("^L ([^|]+)|([^|]*)|([h%-])$")
    if not key or not N.Layer.key(key) or key~=N.Layer.key(key) then return false,"invalid" end
    if zone~="" and not zone:match("^%d+$") then return false,"invalid" end
    -- the sender's own line; a cross-realm "First Surname-Realm" keeps the name only
    local name=sender
    if name:find(" ",1,true) then name=name:match("^(.-)%-[^ ]*$") or name end
    if not N.Invite.name(name) then return false,"name" end
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
function A.friendLists(guildLines)
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
-- Own name (with or without realm) -> "own echo"; unreadable identity -> refused.
local function echo(sender)
    local me,realm=S.call(UnitName,"player"); me,realm=S.str(me),S.str(realm)
    realm=realm or S.str(S.call(GetRealmName))
    if not me or not realm then return "own identity unavailable" end
    local name,remoteRealm=sender:match("^([^%-]+)%-(.+)$")
    name=name or sender; remoteRealm=remoteRealm or realm
    if N.Hash.nameKey(name,remoteRealm)==N.Hash.nameKey(me,realm) or sender:lower()==me:lower() then return "own echo" end
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
        if kind~="GUILD" and kind~="PARTY" and kind~="RAID" then return false,"route" end
        local mine=echo(sender); if mine then return false,mine end
        local ignored,why=A.ignored(sender)
        if ignored then return false,why end
        if kind=="GUILD" then
            if S.call(IsInGuild)~=true then return false,"guild unavailable" end
            return true,"guild"
        end
        return true,"group"
    end)
    if not ok then return false,"policy unavailable" end
    return allowed,reason
end
-- Types each route may carry (WEFF1): guild C E H G, home group C E H X.
A.WE_TYPES={GUILD={C=true,E=true,H=true,G=true},PARTY={C=true,E=true,H=true,X=true},RAID={C=true,E=true,H=true,X=true}}
