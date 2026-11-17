-- Shared extension seams; source modules register themselves explicitly.
local _,N=...
local Src,S={},N.Safe
N.Sources=Src
Src.stats={refused=0}
local sources,order,owners,registered={},{},{},{}
-- Main's existing prefix chain remains its sole owner; never migrate it here.
local legacy={WEFF1=true,HeadHunter=true,LayerSwap=true,LFSw=true,LEGW1=true,FLHNET2=true,OverlordF=true,
    OpenMapLoc=true,["[Spy]"]=true,ForeverSpy1=true,FSENT03=true,GBOUNTY=true,WALLOFSHAME=true,FTold1=true}
local started,timer,last=false,false,nil
function Src.has(name) return S.str(name,32)~=nil and sources[name]~=nil end
function Src.owns(prefix) return S.str(prefix,16)~=nil and owners[prefix]~=nil end
function Src.enabled(name) return Src.has(name) and N.Net.switch(name) end
function Src.count(name,key)
    local r=S.str(name,32) and sources[name]
    if r and (key=="heard" or key=="accepted" or key=="sent" or key=="refused") then
        r.counters[key]=(S.num(r.counters[key]) or 0)+1
    end
end
function Src.authorized(name,prefix)
    return Src.enabled(name) and owners[prefix]==sources[name]
end
local function call(r,key,...)
    if not r[key] then return false end
    local ok=pcall(r[key],...)
    if not ok then Src.count(r.name,"refused") end
    return ok
end
local function register(r)
    if not S.tab(r) then return false end
    local name=S.str(r.name,32)
    if not name or not name:match("^[a-z]+$") or sources[name] or #order>=32 then return false end
    if not S.tab(r.prefixes) or #r.prefixes>8 then return false end
    local copy={name=name,prefixes={},counters=S.tab(r.counters) and r.counters or {}}
    for _,key in ipairs({"onAddon","onBNet","tick"}) do
        local fn=r[key]
        if S.secret(fn) or (fn~=nil and type(fn)~="function") then return false end
        copy[key]=fn
    end
    local seen={}
    for _,prefix in ipairs(r.prefixes) do
        prefix=S.str(prefix,16)
        if not prefix or legacy[prefix] or owners[prefix] or seen[prefix] then return false end
        seen[prefix]=true; copy.prefixes[#copy.prefixes+1]=prefix
    end
    for _,key in ipairs({"heard","accepted","sent","refused"}) do copy.counters[key]=0 end
    sources[name]=copy; order[#order+1]=copy
    for _,prefix in ipairs(copy.prefixes) do owners[prefix]=copy end
    -- Registration opts in this source's switch without altering legacy readers.
    if not N.Net.LIST[name] then N.Net.LIST[name]={name=name}; N.Net.SHIP[name]=true end
    if started then Src.start() end
    return true
end
function Src.register(r)
    local ok,result=pcall(register,r)
    if ok and result then return true end
    Src.stats.refused=Src.stats.refused+1; return false
end
function Src.addon(prefix,text,dist,sender)
    if not Src.owns(prefix) or S.secret(text) or S.secret(dist) or S.secret(sender) then return false end
    local r=owners[prefix]
    if not Src.enabled(r.name) or type(text)~="string" or #text>4096 or not S.str(dist,32) or not S.str(sender,100) then return false end
    Src.count(r.name,"heard"); return call(r,"onAddon",prefix,text,dist,sender)
end
function Src.bnet(prefix,text,id)
    if not Src.owns(prefix) or S.secret(text) or not S.num(id) or id<1 or id%1~=0 then return false end
    local r=owners[prefix]
    if not Src.enabled(r.name) or type(text)~="string" or #text>4096 then return false end
    Src.count(r.name,"heard"); return call(r,"onBNet",prefix,text,id)
end
function Src.tick(now)
    now=S.num(now)
    if not now or (last and now-last<1) then return end
    last=now
    if N.Adapters.inCombat() or N.Adapters.inInstance()~=false then return end
    for _,r in ipairs(order) do if Src.enabled(r.name) then call(r,"tick",now) end end
end
local function pulse()
    timer=false
    Src.tick(S.call(GetTime))
    Src.start()
end
function Src.start()
    started=true
    for prefix,r in pairs(owners) do
        if not registered[prefix] then
            registered[prefix]=true -- one attempt, including refusal; never double-register
            local ok,result=pcall(function() return S.call(C_ChatInfo.RegisterAddonMessagePrefix,prefix) end)
            if not ok or result~=true then Src.count(r.name,"refused") end
        end
    end
    -- Main's inherited heartbeat is 2/5 s. Future sources get a separate 1 s
    -- clock without changing the built readers' cadence; empty registry: no timer.
    if #order>0 and not timer then
        local ok,result=pcall(function()
            local t=_G.C_Timer
            if not S.tab(t) or type(S.clean(t.After))~="function" then return false end
            t.After(1,pulse); return true
        end)
        timer=ok and result==true
    end
end
-- All event clocks are monotonic GetTime seconds. Sources convert wire wall time
-- before offering; nil at means unknown, never an invented observation timestamp.
local kinds={self="said by own client",witness="seen by witness",relayed="via relay",cached="cached"}
local function offer(ev)
    local M,A,F=N.Main,N.Adapters,N.Find
    if not S.tab(ev) or not M or not M.find or A.inCombat() or A.inInstance()~=false then return false end
    for _,key in ipairs({"name","guid","faction","zone","map","x","y","shard","at","got","kind","net","via","note","tag","clear","expiresAt","pos"}) do
        if S.secret(ev[key]) then return false end
    end
    local net,kind=S.str(ev.net,32),S.str(ev.kind,16)
    if not net or not Src.enabled(net) or not kind or not kinds[kind] then return false end
    local name=N.Invite.name(ev.name)
    if not name or M.isMe(name) or A.ignored(name) then return false end
    local now=S.num(S.call(GetTime))
    if not now then return false end
    local _,_,_,watchers=N.Watch.match(M.watch,name,now)
    if not F.tracked(M.find,name) and #(watchers or {})==0 then return false end
    local got=ev.got==nil and now or S.num(ev.got)
    local at=ev.at==nil and got or S.num(ev.at)
    if not got or not at or got>now or at>got or now-at>=N.Known.TTL then return false end
    local map=ev.map~=nil and S.num(ev.map) or nil
    if ev.map~=nil and (not map or map<1 or map>999999 or map%1~=0) then return false end
    local zone,zoneText
    if ev.zone~=nil then
        zoneText=S.str(ev.zone,120)
        if zoneText then zone=A.zoneByName(zoneText)
        else
            local id=S.num(ev.zone)
            if not id or id<1 or id>999999 or id%1~=0 then return false end
            zone=A.zone(id)
        end
    end
    zone=zone or (map and A.zone(map)) or nil
    local x,y=S.num(ev.x),S.num(ev.y)
    if ev.x~=nil or ev.y~=nil then
        if not map or not x or not y or x<0 or x>1 or y<0 or y>1 then return false end
    end
    local guid,faction,shard,via=S.str(ev.guid,160),S.str(ev.faction,16),S.str(ev.shard,80),N.Invite.name(ev.via)
    if (ev.guid~=nil and not guid) or (ev.faction~=nil and faction~="Horde" and faction~="Alliance")
        or (ev.shard~=nil and not shard) or (ev.via~=nil and not via) then return false end
    local note,tag=S.str(ev.note,360),S.str(ev.tag,16)
    local expires=S.num(ev.expiresAt)
    if (ev.note~=nil and not note) or (ev.tag~=nil and not tag)
        or (ev.pos~=nil and ev.pos~="enemy" and ev.pos~="observer")
        or (ev.clear~=nil and type(ev.clear)~="boolean")
        or (ev.expiresAt~=nil and (not expires or expires<=got or expires>at+N.Known.TTL)) then return false end
    if ev.clear then
        if not tag then return false end
        N.Known.withdraw(M.find.known,net,name,tag,now)
        Src.count(net,"accepted"); if N.UI then N.UI.refresh() end
        return true
    end
    local detail=net.." "..kind..": "..kinds[kind].." (claim)"
    if zoneText then detail=detail.." · "..zoneText end
    if shard then detail=detail.." · shard "..shard.." (source key)" end
    if ev.at==nil then detail=detail.." · time unknown" end
    if note then detail=detail.." · "..note end
    F.report(M.find,{sender=via or name,zone=zone,at=at,now=now,enemies={{name=name}},source=net,
        kind="claim",relayed=kind=="relayed" or kind=="cached",detail=detail,x=x,y=y,
        pos=ev.pos or (kind=="self" and "enemy" or "observer"),ns="unknown",
        observedAt=ev.at,got=got,evidenceKind=kind,guid=guid,faction=faction,shard=shard,map=map,
        expiresAt=expires,evidenceTag=tag},M.homeRealm())
    Src.count(net,"accepted")
    if N.UI then N.UI.refresh() end
    return true
end
function Src.offer(ev)
    local ok,result=pcall(offer,ev)
    if ok and result then return true end
    local safe,net=pcall(function() return S.tab(ev) and S.str(ev.net,32) end)
    if safe then Src.count(net,"refused") end
    return false
end
function Src.lines()
    local out={}
    for _,r in ipairs(order) do
        local c=r.counters
        out[#out+1]=r.name..": heard="..c.heard.." accepted="..c.accepted.." sent="..c.sent.." refused="..c.refused
    end
    return out
end
