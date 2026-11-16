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
-- Recap rows are owned one by one by the first death that observed them, not by
-- a successful send. A row's identity is who and when (source GUID, name,
-- timestamp): damage, overkill and flags are ignored, so an old row shown again
-- with edited numbers stays old. Only rows owned by the current death can name a
-- killer, whatever else is in the set: a row first seen on an earlier death never
-- can. A miss is acceptable; a false killer is not. Never evict session history:
-- at the cap, unseen rows are refused rather than letting an old death's rows
-- become fresh again.
local recapDeath,recapCount,recapSeen=0,0,{}
local deathActive=false
local RECAP_CAP=256
local RECORD_LIMIT=256
-- seenHigh is the highest recap timestamp ever recorded this session; it never
-- goes down, even when the cap forgets rows. When a death starts it is fixed as
-- priorMark: a row the new death sees for the first time, stamped at or below
-- it, happened before this death began, so it is recorded as old and never
-- named. Only recap timestamps are compared with each other. At the cap the
-- oldest-stamped row is forgotten; which one is forgotten cannot make an old row
-- nameable, because seenHigh already covers it.
local seenHigh,priorMark
-- blind: some recap row seen since the current death began could not be recorded
-- (unreadable, or past RECORD_LIMIT). Its identity and time are unknown, so it may
-- come back readable at a later death. priorBlind stays fixed for each death:
-- every row it sees first is old. Carry that suppression across empty deaths;
-- only a non-empty recap with no unrecordable rows lets the next death recover.
local blind,priorBlind,recordedRows=false,false,false
local function rowId(row)
    if not S.tab(row) then return nil end
    local fields={}
    for _,field in ipairs({"sourceGUID","sourceName","timestamp"}) do
        local v=row[field]
        if S.secret(v) then return nil end
        -- A row without a timestamp cannot be told apart from the same row once it
        -- gains one, so it is not recorded (and makes the next death blind).
        if v==nil and field=="timestamp" then return nil end
        if v==nil then fields[#fields+1]="-"
        elseif field=="sourceGUID" or field=="sourceName" then
            if type(v)~="string" or #v>120 then return nil end
            fields[#fields+1]="s"..#v..":"..v
        else
            if not S.num(v) then return nil end
            fields[#fields+1]="n"..string.format("%.17g",v)
        end
    end
    return table.concat(fields,"|")
end
local function capture()
    local api=_G.C_DeathRecap
    if not S.tab(api) or S.call(api.HasRecapEvents)~=true then return end
    local rows=S.call(api.GetRecapEvents)
    if not S.tab(rows) then return end
    -- Record every row that reads cleanly, up to RECORD_LIMIT. A row whose fields
    -- cannot be read is never owned, so it can never be named; a list longer than
    -- RECORD_LIMIT names nothing, since its unread rows could be old.
    local list,n={},0
    for _,row in pairs(rows) do
        n=n+1
        if n>RECORD_LIMIT then list.tooMany=true; blind=true; break end
        local ok,id=pcall(rowId,row)
        local okTs,ts=pcall(function() return S.num(row.timestamp) end)
        list[n]={row=row,id=ok and id or nil,ts=okTs and ts or nil}
    end
    return list
end
local function oldest()
    local key,low
    for id,rec in pairs(recapSeen) do
        local ts=rec.ts or -math.huge
        if not key or ts<low then key,low=id,ts end
    end
    return key,low
end
local function admit(id,ts,owner)
    if recapCount>=RECAP_CAP then
        local key=oldest()
        recapSeen[key]=nil; recapCount=recapCount-1
    end
    recapSeen[id]={owner=owner,ts=ts}; recapCount=recapCount+1
    if ts and (seenHigh==nil or ts>seenHigh) then seenHigh=ts end
end
-- Records unseen rows for owner; marks each entry owned when its row belongs to owner.
local function remember(list,owner)
    if not list then return end
    if owner==recapDeath and #list>0 then recordedRows=true end
    for _,entry in ipairs(list) do
        local id=entry.id
        if not id then blind=true end
        if id then
            if recapSeen[id]==nil then
                local old=owner==recapDeath and (priorBlind or (priorMark~=nil and (entry.ts==nil or entry.ts<=priorMark)))
                admit(id,entry.ts,old and 0 or owner)
            end
            entry.owned=recapSeen[id]~=nil and recapSeen[id].owner==owner
        end
    end
end
function D.seed()
    -- PLAYER_ENTERING_WORLD also covers login/reload with a pre-session recap.
    pcall(function() remember(capture(),0) end)
end
-- Record-only: the recap can lag PLAYER_DEAD, so a death that is never
-- announced must still claim its rows when they arrive, or the next death
-- would take them as fresh and report the old killer.
local function claim(death) pcall(function() remember(capture(),death) end) end
function D.revived()
    -- Alive again: whatever recap is held belongs to the death just ended.
    claim(recapDeath)
    deathActive=false
    D.cancel()
end
function D.recap(store,time)
    local ok,result=pcall(function()
        local list=capture()
        if not list then return nil end
        remember(list,recapDeath)
        if list.tooMany then return nil end
        local best
        for _,entry in ipairs(list) do
            local candidate=entry.owned and source(entry.row,store,time)
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
    -- No client death ID: until revive, repeated PLAYER_DEAD is the same death.
    -- Do not replace its pending snapshot or consume its suppression again.
    if deathActive then return end
    deathActive=true
    D.cancel()
    local ok=pcall(function()
        recapDeath=recapDeath+1
        priorMark=seenHigh
        priorBlind=blind or (priorBlind and not recordedRows)
        blind=false; recordedRows=false
        local death=recapDeath
        local time=S.num(S.call(GetTime))
        D.recap(N.Main.store,time) -- remember even an ineligible/unsent death
        -- Every death looks at 0.3/1/2 s, record only, even after a cancel (share off,
        -- zone change, release), so late or withdrawn-and-reshown rows stay with it.
        -- These looks may outlive a quick next death and take its rows: that is a
        -- missed line, never a false one.
        if S.tab(C_Timer) and type(C_Timer.After)=="function" then
            for _,delay in ipairs({0.3,1,2}) do C_Timer.After(delay,function() claim(death) end) end
        end
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
