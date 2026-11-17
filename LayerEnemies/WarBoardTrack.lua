-- WarBoard Forever 1.6.3 wire facts only; independent tracking client.
-- No donor code, forwarding, saved identities or direct client sends.
local _,N=...
local T,S,BN,Cd={},N.Safe,N.BNet,N.Codec
N.WarBoardTrack=T
T.on=true
local records,cooldowns={},{}
local admitted={FBAK={},FBUN={}}
local attempted={FBAK={},FBUN={}}
local high
local function recent(at,now,gap) return at and now-at<gap end
local function room(list,now)
    for i=#list,1,-1 do if now-list[i]>=60 then table.remove(list,i) end end
    return #list<2 -- own cap, independent of WarBoard's shared ten/minute
end
local function guid(v)
    return S.str(v,80) and v:match("^Player%-%d+%-%x+$") and v or nil
end
local function allowed(ctx)
    return not T.closed and ctx and N.Main.sharing() and N.Sources.enabled("warboard")
        and N.Net.allowed("warboard","public") and S.str(ctx.version,40)
        and S.num(ctx.wall) and ctx.wall>0 and ctx.wall%1==0
end
local function target(st,id,ctx)
    local peer=st.peers[id]
    if not peer or not peer.confirmed or peer.rs~=ctx.rs or ctx.now<peer.at or ctx.now-peer.at>=1200 then return nil end
    local who=BN.who(id,true)
    local full=who and N.OpenMap.bnName(who.name,who.realm)
    if not full or not guid(who.guid) or not S.str(who.name,80) or not N.Find.name(who.name)
        or who.faction==ctx.faction or who.faction~=peer.faction or N.Invite.key(full)~=peer.key
        or N.Main.isMe(full) or N.Adapters.ignored(full) then return nil end
    return {id=id,name=who.name,full=full,key=N.Invite.key(full),guid=who.guid,faction=who.faction}
end
-- One unambiguous client identity per own Find entry, never a Watch-only name.
local function picks(st,ctx)
    local candidates,out={},{}
    for id in pairs(st.peers) do
        local who=target(st,id,ctx)
        if who then candidates[#candidates+1]=who end
    end
    for i,entry in ipairs(N.Main.find.entries) do
        if i>20 then break end
        local match,count=nil,0
        local one={byName={[entry.shortKey]={entry}},homeKey=N.Main.find.homeKey}
        for _,who in ipairs(candidates) do
            if N.Find.tracked(one,who.full) then match=who; count=count+1 end
        end
        if count==1 then out[match.key]=match end
    end
    return out
end
local function retire(r)
    BN.cancel("warboard",r) -- private queue tag: do not drop H/A or other targets
    r.pending=nil
    if r.sent then r.closing=true else records[r.key]=nil end
end
function T.stop(logout)
    for _,r in pairs(records) do retire(r) end
    if logout then T.closed=true; records={}; BN.cancel("warboard") end
end
function T.changed(find)
    if not N.Main or find~=N.Main.find then return end
    for _,r in pairs(records) do
        if not r.closing and not N.Find.tracked(find,r.full) then retire(r) end
    end
end
function T.set(on)
    T.on=on==true
    if not T.on then T.stop() end
end
function T.size() return S.count(records) end
function T.note(ev)
    local key=ev.name and N.Invite.key(ev.name)
    local r=key and records[key]
    if r and not r.closing and ev.tag=="FBLP" and ev.kind=="self" and ev.guid==r.guid then r.location=ev.got end
end
local fields={"targetGuid","targetName","hunterGuid","hunterName","hunterFaction","faction","sentAt"}
local function frame(kind,r,me,ctx)
    local d={targetGuid=r.guid,hunterGuid=me.guid,hunterName=me.name,hunterFaction=ctx.faction,
        faction=ctx.faction,sentAt=ctx.wall}
    if kind=="FBAK" then d.targetName=r.name end
    -- Stable field order, using our codec's scalar escaping. Ace tables are
    -- unordered on the wire; the one-element wrapper is ^1^T^N1<scalar>^t^^.
    local function atom(v) return Cd.aceWrite({v}):sub(8,-5) end
    local plain="^1^T^St"..atom(kind).."^Sv^N5^Srs"..atom(ctx.rs).."^Sav"..atom("LayerEnemies/"..ctx.version)
        .."^SsenderName"..atom(me.name).."^Sd^T"
    for _,key in ipairs(fields) do if d[key]~=nil then plain=plain..atom(key)..atom(d[key]) end end
    return "WBF1|D|"..Cd.addonEncode(Cd.deflateStored(plain.."^t^t^^"))
end
local function due(r,now)
    -- The donor has no subscriber expiry. Do not renew a fresh position.
    return not r.location or (now-r.location>=45 and now-r.location<=300)
end
local function enqueue(st,r,kind,me,ctx)
    if r.pending or not room(admitted[kind],ctx.now) then return end
    local c=cooldowns[r.key]
    if kind=="FBAK" and c and (recent(c.queued,ctx.now,45) or recent(c.sent,ctx.now,45)) then return end
    if not c then
        local count=0
        for key,v in pairs(cooldowns) do
            if ctx.now-v.at>=600 then cooldowns[key]=nil else count=count+1 end
        end
        if count>=200 then return end
        c={}; cooldowns[r.key]=c
    end
    local text=frame(kind,r,me,ctx)
    if #text>4000 or not BN.allowed("warboard",r.id,"WarBoard",text,"own") then return end
    admitted[kind][#admitted[kind]+1]=ctx.now
    c.at=ctx.now
    if kind=="FBAK" then c.queued=ctx.now; r.last=ctx.now end
    r.pending=ctx.now
    local queued=BN.send("warboard",r.id,"WarBoard",text,"own",function(now)
        r.pending=nil
        local live=N.Adapters.warboardContext()
        local self=N.Adapters.warboardSelf()
        if records[r.key]~=r or not allowed(live) or not self or self.guid~=me.guid or self.name~=me.name
            or live.rs~=ctx.rs or live.faction~=ctx.faction or now<ctx.now or (high and now<high) or now-ctx.now>=120
            or math.abs(live.wall-ctx.wall)>120 then return false end
        local who=target(st,r.id,live)
        if not who or who.key~=r.key or who.guid~=r.guid then retire(r); return false end
        if kind=="FBAK" then
            local picked=T.on and not r.closing and picks(st,live)[r.key]
            if not picked or picked.id~=r.id or picked.guid~=r.guid or not due(r,now)
                or recent(c.sent,now,45) then return false end
        elseif not r.closing then return false end
        if not room(attempted[kind],now) then return false end
        attempted[kind][#attempted[kind]+1]=now -- charge client failures too
        if kind=="FBAK" then c.sent=now; c.at=now; r.sent=true
        else records[r.key]=nil end -- one best-effort cancel; never retry a refused send
        return true
    end,r)
    if not queued then r.pending=nil end
end
function T.tick(st,ctx)
    if not allowed(ctx) then T.stop(); return end
    if high and ctx.now<high then return end
    high=ctx.now
    local me=N.Adapters.warboardSelf()
    if not me then T.stop(); return end
    local selected=T.on and picks(st,ctx) or {}
    for key,r in pairs(records) do
        local who=selected[key]
        if not r.closing and (not who or who.id~=r.id or who.guid~=r.guid or r.hunter~=me.guid or r.rs~=ctx.rs) then retire(r) end
        if r.pending and ctx.now-r.pending>=120 then BN.cancel("warboard",r); r.pending=nil end
    end
    for key,who in pairs(selected) do
        if not records[key] and T.size()<20 then
            who.hunter=me.guid; who.rs=ctx.rs; records[key]=who
        end
    end
    local list={}
    for _,r in pairs(records) do list[#list+1]=r end
    table.sort(list,function(a,b)
        if a.closing~=b.closing then return a.closing==true end
        if (a.last or -math.huge)~=(b.last or -math.huge) then return (a.last or -math.huge)<(b.last or -math.huge) end
        return a.key<b.key
    end)
    for _,r in ipairs(list) do
        if r.closing then
            local who=target(st,r.id,ctx)
            if who and who.key==r.key and who.guid==r.guid and r.hunter==me.guid and r.rs==ctx.rs then enqueue(st,r,"FBUN",me,ctx) end
        elseif due(r,ctx.now) then enqueue(st,r,"FBAK",me,ctx) end
    end
end
