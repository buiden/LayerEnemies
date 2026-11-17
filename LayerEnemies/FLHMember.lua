-- FLHNET2 membership only. Protocol facts from 0.1.9, not donor code.
-- No hosted invites, peer exchange, foreign names in saves, or channel messages.
local _,N=...
local F,S,A,I,FL={},N.Safe,N.Adapters,N.Invite,N.FLH
N.FLHMember=F
F.stats={}
local flight,sequence=nil,0
local dispatch
local announced={}
local probed={}
local function count(key) N.Sources.count("flh",key) end
function F.context()
    local M=N.Main
    if not M or not M.store or not A.ownIdentity() then return nil end
    local map=A.location()
    local realm=S.str(S.call(GetRealmName),60)
    local info=S.tab(_G.C_AddOns) and _G.C_AddOns
    local version=info and S.str(S.call(info.GetAddOnMetadata,"LayerEnemies","Version"),40)
    local uid=S.num(M.store.zoneUID)
    if not map or map~=M.store.zone or not uid or uid<=0 or uid%1~=0 or M.store.ambiguous(S.call(GetTime)) or not realm or not version then return nil end
    return {map=map,key=string.format("%.0f",uid),realm=realm,version="LayerEnemies "..version}
end
function F.windowOpen()
    local U=N.UI
    return U and U.tab=="friendly" and U.frame and S.call(U.frame.IsShown,U.frame)==true or false
end
function F.probeAllowed()
    local M=N.Main
    return F.windowOpen() and not (M.hopAnyState and M.hopAnyState.round) and not M.asking()
end
function F.allowed(kind,tag)
    local M=N.Main
    if not M or not M.sharing() or N.Net.SHIP.flh~=true or not N.Net.switch("flh") then return false end
    if A.inCombat() or A.inInstance()~=false or not A.ownIdentity() then return false end
    if kind=="GUILD" then
        if S.call(IsInGuild)~=true then return false end
    elseif N.Net.consent()~="public" then return false end
    if kind=="PARTY" and (S.call(IsInGroup)~=true or S.call(IsInRaid)~=false) then return false end
    if kind=="RAID" and S.call(IsInRaid)~=true then return false end
    -- Stand-down still answers the two debts, but never originates membership.
    if tag~="WR" and tag~="CA" and A.loaded("ForeverLayerHop") then return false end
    return true
end
dispatch=function(text,kind,target,prio)
    if not text or flight then return false end
    flight={text=text,kind=kind,target=target,prio=prio}
    local ok,sent,why=pcall(N.Wire.send,"FLHNET2",text,kind,target,{net="flh",prio=prio})
    flight=nil
    count(ok and sent and "sent" or "refused")
    return ok and sent==true,why
end
local guest,notes=nil,{}
F.WAIT=90
local function sameKey(a,b)
    return a and b and a:gsub("^0+","")==b:gsub("^0+","")
end
function F.pending() return guest~=nil end
function F.detail(c) local r=notes[c.short]; return r and r.text end
function F.stop(reason)
    if not guest then return false end
    local M=N.Main
    if M and M.invite and M.invite.pending and M.invite.pending.flh then M.invite.pending=nil end
    guest=nil
    return true
end
local function note(r,text)
    local now=S.num(S.call(GetTime)) or 0
    for _,v in ipairs(r.targets) do
        if not notes[v.short] and S.count(notes)>=64 then
            local oldest,stamp
            for k,e in pairs(notes) do if not stamp or e.at<stamp or (e.at==stamp and k<oldest) then oldest,stamp=k,e.at end end
            notes[oldest]=nil
        end
        notes[v.short]={at=now,text=text}
    end
end
function F.checkGuest()
    local r=guest
    if not r then return false end
    local now=S.num(S.call(GetTime)); local c=F.context(); local M=N.Main
    if not now or now<r.at or now-(r.first or r.at)>=F.WAIT then
        note(r,"FLH request timed out (90 s)"); F.stop(); return false
    end
    if not c or not F.allowed("WHISPER","LQ") or A.grouped() or c.map~=r.map or not sameKey(c.key,r.own)
        or (M.hopAnyState and M.hopAnyState.round) then F.stop(); return false end
    return true
end
local function eligible(row,c)
    return row and row.hosts and row.hosts.FLH==true and FL.key(row.flhKey)
        and S.num(row.flhAge) and row.flhAge>=0 and row.flhAge<N.Hosts.FLH_KEEP
        and not sameKey(row.flhKey,c.key) and not A.ignored(row.name)
end
function F.preview(row)
    local c=F.context(); local M=N.Main; local time=S.num(S.call(GetTime))
    local ok=c and time and F.allowed("WHISPER","LQ") and not A.grouped() and not M.asking()
        and not M.auto.group and N.Layer.key(M.store.bulo) and eligible(row,c)
    local last=M.invite.asked[row.short]
    if last and time and time-last<I.NAME_COOLDOWN then ok=false end
    if M.invite.lastAsk and time and time-M.invite.lastAsk<I.GLOBAL_COOLDOWN then ok=false end
    return {label="Hop via "..row.name,enabled=ok==true,reason=not ok and "FLH hop unavailable: consent, layer or another ask." or nil,
        candidate={name=row.name,short=row.short,source="FLH",key=row.flhKey},
        detail="FLH guest request to "..row.name.."; fingerprint claim only"}
end
function F.hop(row,shown)
    local M=N.Main; local c=F.context(); local now=S.num(S.call(GetTime))
    if not c or not now or not F.allowed("WHISPER","LQ") or A.grouped() or M.asking() or M.auto.group or not N.Layer.key(M.store.bulo) then return false end
    local targets={}
    for _,live in ipairs(M.candidates()) do
        if (not row or live.short==row.short) and eligible(live,c) then
            if row and (live.name~=row.name or live.flhKey~=row.flhKey or (shown and
                (not shown.candidate or shown.candidate.source~="FLH" or shown.candidate.name~=live.name or shown.candidate.key~=live.flhKey))) then return false end
            local last=M.invite.asked[live.short]
            if not last or now-last>=I.NAME_COOLDOWN then
                local _,_,target=I.name(live.name)
                if not target then return false end
                targets[#targets+1]={name=target,short=live.short,key=live.flhKey}
                if row or #targets>=N.HopAny.CAP-1 then break end -- reserve one slot for LR
            end
        end
    end
    if #targets==0 then return false end
    local ok=I.reserve(M.invite,targets[1],now)
    if not ok then return false end
    sequence=sequence%2147483646+1
    local r={id=sequence,at=now,map=c.map,own=c.key,from=N.Layer.key(M.store.bulo),targets=targets,asked={}}
    guest=r
    for _,v in ipairs(targets) do
        if guest~=r or not F.checkGuest() then break end
        M.invite.asked[v.short]=now
        r.sending=v
        local sent=dispatch(FL.lq(r.id,c,v.key),"WHISPER",v.name,"click")
        if guest~=r then return false end
        r.sending=nil
        if sent then r.first=r.first or now; r.asked[v.short]=v end
    end
    if guest~=r then return false end
    if not r.first then note(r,"FLH request refused"); F.stop(); return false end
    note(r,"FLH: waiting for offer (90 s)")
    if N.UI then N.UI.refresh() end
    return true
end
local function offer(m,sender)
    if not F.checkGuest() then return end
    local r=guest; local key=I.key(sender); local asked=key and r.asked[key]
    if not asked or m.id~=r.id then return end
    if m.cmd=="LN" and r.selected==key then
        note(r,"FLH host refused"); F.stop(); return
    end
    if m.cmd~="LO" or r.selected or m.map~=r.map or not FL.key(m.key)
        or sameKey(m.key,r.own) or not sameKey(m.key,asked.key) then return end
    r.selected=key -- spend selection before the call, including refusal/reentry
    r.offer=asked
    local c=F.context()
    local sent=dispatch(FL.lr(r.id,c,m.key),"WHISPER",asked.name,"click")
    if guest~=r then return end
    if sent then
        -- Reuse the existing any-layer auto-leave rule, never treat an FLH key
        -- as the server-layer target. Only this selected, actually asked host.
        N.Main.invite.pending={flh=true,auto=true,any=true,at=r.first,from=r.from,zone=r.map,
            asked={[key]={name=asked.name,at=r.first}}}
        note(r,"FLH: waiting for selected host's invite")
    else note(r,"FLH invite request refused") end
    if N.UI then N.UI.refresh() end
end

-- Wire checks the private synchronous dispatch, exact grammar and live context.
-- Direct callers cannot manufacture an owed reply, directory probe or click.
function F.authorize(text,kind,target,opts)
    local q=flight
    if not q or q.used or q.text~=text or q.kind~=kind or q.target~=target or q.prio~=opts.prio or opts.net~="flh" then return nil end
    local m=FL.decode(text)
    if not m or not F.allowed(kind,m.cmd) or (target and (A.ignored(target) or N.Main.isMe(target))) then return nil end
    local c=F.context(); if not c then return nil end
    local expected
    if m.cmd=="HI" and kind~="WHISPER" and opts.prio=="own" then expected=FL.hi(c)
    elseif kind=="WHISPER" then
        if m.cmd=="WR" and opts.prio=="owed" then expected=FL.wr(m.id,c)
        elseif m.cmd=="CA" and opts.prio=="owed" then expected=FL.ca(m.id,c)
        elseif m.cmd=="WP" and opts.prio=="mesh" and F.probeAllowed() then expected=FL.wp(m.id,c)
        elseif opts.prio=="click" and F.checkGuest() and m.id==guest.id then
            if m.cmd=="LQ" and guest.sending and guest.sending.name==target then expected=FL.lq(m.id,c,guest.sending.key)
            elseif m.cmd=="LR" and guest.offer and guest.offer.name==target then expected=FL.lr(m.id,c,guest.offer.key) end
        end
    end
    if expected~=text then return nil end
    q.used=true
    return m.cmd
end
function F.received(m,kind,sender)
    count("heard")
    if kind=="WHISPER" and (m.cmd=="LO" or m.cmd=="LN") then offer(m,sender); return end
    if kind~="WHISPER" or (m.cmd~="WP" and m.cmd~="CQ") then return end
    local _,_,target=I.name(sender)
    if not target or not F.allowed(kind,m.cmd=="WP" and "WR" or "CA") then return end
    local c=F.context(); if not c then return end
    count("accepted")
    dispatch(m.cmd=="WP" and FL.wr(m.id,c) or FL.ca(m.id,c),"WHISPER",target,"owed")
end
function F.tick(now)
    if not S.num(now) then return end
    F.checkGuest()
    for k,v in pairs(notes) do if now<v.at or now-v.at>=600 then notes[k]=nil end end
    local c=F.context(); if not c then return end
    local text=FL.hi(c)
    if not text then return end
    for _,kind in ipairs({"GUILD","PARTY","RAID"}) do
        if F.allowed(kind,"HI") and announced[kind]~=text then
            if dispatch(text,kind,nil,"own") then announced[kind]=text end
        end
    end
    if not F.allowed("WHISPER","WP") or not F.probeAllowed() then return end
    local names=N.Directory.members("flh")
    if not names then return end
    for k,at in pairs(probed) do if now-at>=600 then probed[k]=nil end end
    for i=1,math.min(#names,N.Directory.MAX) do
        local _,key,target=I.name(names[i])
        if key and not probed[key] and S.count(probed)<64 and not A.ignored(target) and not N.Main.isMe(target)
            and not N.Wire.offlineUntil(target,now) and N.Wire.flhProbeReady(target,now) then
            sequence=sequence%2147483646+1
            probed[key]=now -- a failed client attempt is never retried
            dispatch(FL.wp(sequence,c),"WHISPER",target,"mesh")
            break -- at most one probe per registry tick
        end
    end
end
N.Net.LIST.flh={name="Forever Layer Hop",standDown="ForeverLayerHop",session=true}
N.Net.SHIP.flh=true
N.Sources.register{name="flh",prefixes={},tick=F.tick,counters=F.stats}
