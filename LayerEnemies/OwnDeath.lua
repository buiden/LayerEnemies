-- Own-death recap adapter and K1 codec. No combat-log listener, unit/target guesses or donor code.
local _,N=...
local D,S={},N.Safe
N.OwnDeath=D
local CLASSES={WARRIOR=true,PALADIN=true,HUNTER=true,ROGUE=true,PRIEST=true,SHAMAN=true,
    MAGE=true,WARLOCK=true,DRUID=true,DEATHKNIGHT=true,MONK=true,DEMONHUNTER=true,EVOKER=true}
local function integer(v,lo,hi) v=S.num(v); return v and v%1==0 and v>=lo and v<=hi and v or nil end
local function number(s,lo,hi)
    if not s:match("^%d+$") then return nil end
    return integer(tonumber(s),lo,hi)
end
local function key(name) local _,k=N.Invite.name(name); return k end
local function hex(s) return (s:gsub(".",function(c) return string.format("%02x",c:byte()) end)) end
local function unhex(s)
    if #s<4 or #s>200 or #s%2~=0 or not s:match("^%x+$") then return nil end
    return N.Invite.name((s:gsub("%x%x",function(b) return string.char(tonumber(b,16)) end)))
end
-- Validate Unicode separately from player-name syntax; malformed high lead bytes
-- must not be interpreted as a shorter sequence by an identity parser.
local function utf8(s)
    local i=1
    while i<=#s do
        local b=s:byte(i)
        if b<128 then i=i+1
        else
            local n=b>=194 and b<=223 and 2 or b>=224 and b<=239 and 3 or b>=240 and b<=244 and 4
            if not n or i+n-1>#s then return false end
            local cp=b%(n==2 and 32 or n==3 and 16 or 8)
            for j=1,n-1 do
                local c=s:byte(i+j)
                if c<128 or c>191 then return false end
                cp=cp*64+c-128
            end
            if (n==3 and cp<2048) or (n==4 and (cp<65536 or cp>1114111))
                or (cp>=55296 and cp<=57343) then return false end
            i=i+n
        end
    end
    return true
end
-- One shared whole-grammar validator, used by Wire as well as the receiver. Nothing is normalized on receive.
function D.decode(text)
    if S.secret(text) or type(text)~="string" or #text>255 then return nil end
    local z,x,y,l,a,c,item=text:match("^K|1|(%d+)|([^|]*)|([^|]*)|(%d*)|(%d+)|([eh])|([^|]*)$")
    if not z then return nil end
    z,a=number(z,1,999999),number(a,0,120)
    local function coord(v)
        if not v:match("^[01]%.%d%d%d$") then return nil end
        local n=tonumber(v); return n and n<=1 and n or nil
    end
    if x=="" and y=="" then x,y=nil,nil
    else x,y=coord(x),coord(y); if not x or not y then return nil end end
    if l~="" then if #l>15 or N.Layer.key(l)~=l then return nil end else l=nil end
    if not z or not a then return nil end
    local enemies={}
    if item~="" then
        local h,cl,lv,full=item:match("^(%x+):(%u*):([%d%-]*):([fp])$")
        if not h or (cl~="" and not CLASSES[cl]) then return nil end
        local name=unhex(h)
        local level=lv~="" and integer(tonumber(lv),-1,100) or nil
        if not name or not utf8(name) or (lv~="" and (not level or level==0 or (lv~="-1" and not lv:match("^%d+$")))) then return nil end
        enemies[1]={name=name,class=cl~="" and cl or nil,level=level,partial=full=="p",full=full=="f"}
    end
    return {zone=z,x=x,y=y,layer=l,age=a,conf=c,enemies=enemies}
end
function D.line(rep)
    if not S.tab(rep) then return nil end
    local ok,line=pcall(function()
        local item=""
        local e=rep.enemies and rep.enemies[1]
        if e and N.Invite.name(e.name) then
            item=hex(e.name)..":"..(CLASSES[S.clean(e.class)] and e.class or "")..":"..
                (integer(e.level,-1,100) and e.level~=0 and tostring(e.level) or "")..":"..(e.full==true and "f" or "p")
        end
        local function coord(v) return v~=nil and string.format("%.3f",v) or "" end
        return table.concat({"K","1",tostring(rep.zone),coord(rep.x),coord(rep.y),rep.layer or "",
            tostring(rep.age),rep.conf,item},"|")
    end)
    return ok and D.decode(line) and line or nil
end

-- K1 is a guildmate's claim, not a sighting or an invitation source. No Store/Find/relay insertion.
function D.receive(text,sender,time)
    local r=D.decode(text)
    if not r or N.Adapters.guildMember(sender)~=true then return end
    local enemy=r.enemies[1]
    if enemy and key(enemy.name)==key(sender) then return end
    r.src,r.kind,r.origin,r.route="le","death",sender,"GUILD"
    r.at,r.heard=time-r.age,time
    return N.Main.callReceive(r,sender)
end

local function seen(store,guid,name,time)
    local want=key(name)
    local byName
    for g,e in pairs(store.localSeen) do
        if e.epoch==store.serial and S.num(e.at) and time>=e.at and time-e.at<600 then
            if g==guid then return e,true end
            if want and key(e.displayName or e.name)==want then byName=e end
        end
    end
    return byName,false
end
-- Deliberately limited to the original non-neutral races. Never infer faction for a neutral/custom race.
local RACES={Human="Alliance",Dwarf="Alliance",NightElf="Alliance",Gnome="Alliance",
    Orc="Horde",Scourge="Horde",Tauren="Horde",Troll="Horde"}
local function source(row,store,time)
    if not S.tab(row) then return nil end
    local guid=S.str(row.sourceGUID,120)
    local flags=integer(row.sourceFlags,0,4294967295)
    local stamp,overkill=S.num(row.timestamp),S.num(row.overkill)
    -- Standard type mask 0xfc00: only player (0x400); reaction mask 0xf0: only hostile (0x40).
    if not guid or not guid:match("^Player%-%d+%-%x+$") or not flags or not stamp or not overkill
        or math.floor(flags/1024)%64~=1 or math.floor(flags/16)%16~=4 then return nil end
    -- Required recap fields must be readable. A readable but unusable identity is omitted, never guessed.
    local raw=S.str(row.sourceName,100)
    if not raw then return nil end
    local name=N.Invite.name(raw)
    local e,byGUID=seen(store,guid,name,time)
    local _,class,_,race=S.call(GetPlayerInfoByGUID,guid)
    local own=S.str(S.call(UnitFactionGroup,"player"),20)
    if own~="Alliance" and own~="Horde" then return nil end
    local faction=e and e.faction
    -- A directly seen same-faction player is a duel, even if race metadata disagrees.
    if faction=="same" then return nil end
    if faction~="opposite" and not (RACES[race] and RACES[race]~=own) then return nil end
    local full=byGUID and e and N.Invite.name(e.displayName) or nil
    local enemy
    if full or name then
        enemy={name=full or name,full=full~=nil,partial=full==nil,
            class=e and e.class or S.str(class,24),level=e and e.level}
    end
    return {enemy=enemy,stamp=stamp,conf=overkill>=0 and "e" or "h"}
end
-- Exact, order-independent row fingerprints are owned by the first death that
-- observed them, not by a successful send. Never evict session history: at the
-- cap, refuse unseen sets rather than letting an old death become fresh again.
local recapDeath,recapCount,recapSeen=0,0,{}
local RECAP_CAP=256
local function fingerprint(rows)
    local parts,n={},0
    for _,row in pairs(rows) do
        n=n+1; if n>64 or not S.tab(row) then return nil end
        local fields={}
        for _,field in ipairs({"sourceGUID","sourceName","sourceFlags","timestamp","amount","damage","overkill"}) do
            local v=row[field]
            if S.secret(v) then return nil end
            if v==nil then fields[#fields+1]="-"
            elseif field=="sourceGUID" or field=="sourceName" then
                if type(v)~="string" or #v>120 then return nil end
                fields[#fields+1]="s"..#v..":"..v
            else
                if not S.num(v) then return nil end
                fields[#fields+1]="n"..string.format("%.17g",v)
            end
        end
        parts[#parts+1]=table.concat(fields,"|")
    end
    if n==0 then return nil end
    table.sort(parts)
    return table.concat(parts,"\n")
end
local function capture()
    local api=_G.C_DeathRecap
    if not S.tab(api) or S.call(api.HasRecapEvents)~=true then return end
    local rows=S.call(api.GetRecapEvents)
    if not S.tab(rows) then return end
    return rows,fingerprint(rows)
end
local function remember(id,owner)
    if not id then return false end
    if recapSeen[id]~=nil then return recapSeen[id]==owner end
    if recapCount>=RECAP_CAP then return false end
    recapSeen[id]=owner; recapCount=recapCount+1
    return true
end
function D.seed()
    -- PLAYER_ENTERING_WORLD also covers login/reload with a pre-session recap.
    pcall(function() local _,id=capture(); remember(id,0) end)
end
function D.recap(store,time)
    local ok,result=pcall(function()
        local rows,id=capture()
        if not remember(id,recapDeath) then return nil end
        local best,n=nil,0
        for _,row in pairs(rows) do
            n=n+1; if n>64 then return nil end
            local candidate=source(row,store,time)
            if candidate and (not best or (candidate.conf=="e" and best.conf~="e")
                or (candidate.conf==best.conf and candidate.stamp>best.stamp)) then best=candidate end
        end
        return best
    end)
    return ok and result or nil
end
local pending
function D.cancel() pending=nil end
local function permitted()
    return N.Main.sharing() and N.Adapters.inInstance()==false and S.call(IsInGuild)==true
        and S.str(S.call(GetGuildInfo,"player"),100) and N.Adapters.ownIdentity()
end
local function attempt(p)
    if pending~=p then return end
    if not permitted() or S.str(S.call(GetGuildInfo,"player"),100)~=p.guild then D.cancel(); return end
    local time=S.num(S.call(GetTime))
    if not time or time<p.at or time-p.at>2.5 then D.cancel(); return end
    local hit=D.recap(N.Main.store,time)
    if not hit then return end
    if hit.enemy and N.Main.isMe(hit.enemy.name) then D.cancel(); return end
    p.conf,p.enemies,p.age=hit.conf,hit.enemy and {hit.enemy} or {},math.floor(time-p.at)
    local line=D.line(p)
    D.cancel() -- one attempt, no budget backlog or replay after a client refusal
    if line then N.Wire.send("LEGW1",line,"GUILD",nil,{prio="own"}) end
end
function D.dead()
    D.cancel()
    local ok=pcall(function()
        recapDeath=recapDeath+1
        local time=S.num(S.call(GetTime))
        D.recap(N.Main.store,time) -- remember even an ineligible/unsent death
        if not permitted() then return end
        local zone,x,y=N.Adapters.location()
        if not time or not zone then return end
        local store=N.Main.store
        local p={at=time,zone=zone,x=x,y=y,guild=S.str(S.call(GetGuildInfo,"player"),100),
            layer=zone==store.zone and not store.ambiguous(time) and N.Layer.key(store.bulo) or nil}
        pending=p
        if not S.tab(C_Timer) or type(C_Timer.After)~="function" then D.cancel(); return end
        for _,delay in ipairs({0.3,1,2}) do
            C_Timer.After(delay,function()
                local good=pcall(attempt,p)
                if (not good or delay==2) and pending==p then D.cancel() end
            end)
        end
    end)
    if not ok then D.cancel() end
end
