-- Guild watch lists: session-only hashed identities, never locations or saved data.
-- One incremental hash -> senders index; own list hashes change only with Find.
local _,N=...
local W,S,F={},N.Safe,N.Find
N.Watch=W
W.MAX,W.PARTS,W.SENDERS,W.CHUNK=100,3,200,39
W.TTL,W.PART_TTL,W.RATE=1500,120,3
local alphabet="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
local function id(n) return alphabet:sub(n%62+1,n%62+1)..alphabet:sub(math.floor(n/62)+1,math.floor(n/62)+1) end
local function bump(st) st.serial=(st.serial+1)%3844; st.id=id(st.serial) end
local function refresh() return 600+(math.random()*240-120) end
local function window(times,now,seconds)
    local out={}; for _,at in ipairs(times) do if now-at<seconds then out[#out+1]=at end end; return out
end
function W.hash(raw)
    local name=F.name(raw)
    if not name then return nil end
    return N.Hash.hash6(F.fold(name:match("^[^%-]+")))
end
local function remove(st,key)
    local held=st.held[key]
    if not held then return end
    for hash in pairs(held.hashes or {}) do
        local bucket=st.byHash[hash]
        bucket[key]=nil; if not next(bucket) then st.byHash[hash]=nil end
    end
    st.held[key]=nil; st.count=st.count-1
end
function W.prune(st,now)
    for key,h in pairs(st.held) do
        if h.partial and now-h.partial.at>=W.PART_TTL then h.partial=nil end
        if h.at and now-h.at>=W.TTL then
            remove(st,key)
            if h.partial then
                h.hashes=nil; h.at=nil; h.signature=nil
                st.held[key]=h; st.count=st.count+1
            end
        elseif not h.at and not h.partial then remove(st,key) end
    end
    for hash,at in pairs(st.noticed) do if now-at>=600 then st.noticed[hash]=nil end end
end
function W.roster(st,keys)
    if not keys then return end -- incomplete/unreadable roster proves no departures
    st.roster=keys -- only a complete update can readmit a departed sender
    for key in pairs(st.held) do if not keys[key] then remove(st,key) end end
end
function W.reset(st,now)
    S.clear(st.held); S.clear(st.byHash); st.count=0; st.roster=nil
    S.clear(st.noticed); st.notices={}; st.pending=nil
    st.due=now+20+math.random()*60
    st.dirty=st.on and next(st.own)~=nil
    -- Keep the send timestamps: guild changes cannot reopen the T budget.
end
function W.new(find,now,on)
    local st={held={},byHash={},count=0,own={},noticed={},notices={},times={},serial=0,id="00",on=on,
        due=now+20+math.random()*60}
    st.loginDue=st.due
    W.sync(st,find,now,true)
    return st
end
function W.sync(st,find,now,initial)
    if st.entries==find.entries then return false end
    st.entries=find.entries
    local keys,hashes={},{}
    for _,name in ipairs(find.names) do
        keys[#keys+1]=F.fold(name)
        local hash=W.hash(name); if hash then hashes[hash]=true end
    end
    table.sort(keys)
    local content=table.concat(keys,"|")
    if st.content==content then return false end
    st.content=content; st.own=hashes; bump(st)
    if st.on then
        st.pending=nil
        if not initial then st.due=math.max(now+10,st.last and st.last+60 or st.loginDue or 0) end
        -- Empty-at-login has nothing to advertise. Removing names still owes a clear.
        st.dirty=not initial or next(hashes)~=nil
    elseif initial then st.dirty=false end
    -- While opted out, edits neither renew advertising nor cancel an owed clear.
    return true
end
function W.enable(st,on,now)
    if st.on==on then return end
    st.on=on; bump(st); st.pending=nil; st.dirty=true
    st.due=on and math.max(now+10,st.last and st.last+60 or 0) or now
end
local function pack(st)
    if not st.on or not next(st.own) then return {"T|1|"..st.id.."|0|0|"} end
    local hashes={}; for hash in pairs(st.own) do hashes[#hashes+1]=hash end; table.sort(hashes)
    local total=math.ceil(#hashes/W.CHUNK); local lines={}
    for part=1,total do
        local chunk={}
        for i=(part-1)*W.CHUNK+1,math.min(part*W.CHUNK,#hashes) do chunk[#chunk+1]=hashes[i] end
        lines[#lines+1]="T|1|"..st.id.."|"..part.."|"..total.."|"..table.concat(chunk)
    end
    return lines
end
-- An owner-managed queue: Wire never holds a stale T or drains several budget
-- windows together. A refused/bucket-blocked line waits here for the next tick.
function W.tick(st,now,allowed)
    W.prune(st,now)
    if not allowed then return end
    if not st.pending and now>=st.due and (st.dirty or (st.on and next(st.own))) then
        st.pending={lines=pack(st),part=1}
    end
    local pending=st.pending
    if not pending then return end
    st.times=window(st.times,now,60)
    if #st.times>=W.RATE then return end
    local ok,why,attempted=N.Wire.send("LEGW1",pending.lines[pending.part],"GUILD",nil,{prio="own",queue=false})
    if attempted then st.times[#st.times+1]=now end
    if not ok then return end
    st.last=now
    pending.part=pending.part+1
    if pending.part>#pending.lines then
        st.pending=nil; st.dirty=false; st.due=now+refresh()
    end
end
local function validHash(hash)
    local value,power=0,1
    for i=1,6 do
        local digit=alphabet:find(hash:sub(i,i),1,true)
        if not digit then return false end
        value=value+(digit-1)*power; power=power*62
    end
    return value<4294967296
end
-- -> changed hash set, or nil. Invalid parts discard the incoming set only.
function W.receive(st,text,sender,now)
    local name,key=N.Invite.name(sender)
    if not name then return end
    if st.roster and not st.roster[key] then return end
    W.prune(st,now)
    local old=st.held[key]
    local function invalid()
        if old then old.partial=nil; if not old.at then remove(st,key) end end
    end
    if S.secret(text) or type(text)~="string" or #text>255 then invalid(); return end
    local token,part,total,body=text:match("^T|1|([0-9A-Za-z][0-9A-Za-z])|([0-3])|([0-3])|([0-9A-Za-z]*)$")
    if not token then invalid(); return end
    part,total=tonumber(part),tonumber(total)
    if part==0 and total==0 and body=="" then remove(st,key); return end
    if part<1 or total<1 or part>total or #body==0 or #body%6~=0 or #body>W.CHUNK*6 then invalid(); return end
    for i=1,#body,6 do if not validHash(body:sub(i,i+5)) then invalid(); return end end
    if not old then
        if st.count>=W.SENDERS then return end
        old={name=name}; st.held[key]=old; st.count=st.count+1
    end
    local p=old.partial
    if not p or p.id~=token then p={id=token,total=total,at=now,parts={},count=0}; old.partial=p end
    if p.total~=total or (p.parts[part] and p.parts[part]~=body) then invalid(); return end
    if not p.parts[part] then p.count=p.count+#body/6; p.parts[part]=body end
    if p.count>W.MAX then invalid(); return end
    for i=1,total do if not p.parts[i] then return end end
    local hashes,ordered={},{}
    for i=1,total do
        for at=1,#p.parts[i],6 do
            local hash=p.parts[i]:sub(at,at+5)
            if not hashes[hash] then hashes[hash]=true; ordered[#ordered+1]=hash end
        end
    end
    table.sort(ordered); local signature=table.concat(ordered)
    local changed=signature~=old.signature
    remove(st,key)
    st.held[key]={name=name,id=token,at=now,hashes=hashes,signature=signature}; st.count=st.count+1
    for hash in pairs(hashes) do
        local bucket=st.byHash[hash] or {}; st.byHash[hash]=bucket; bucket[key]=true
    end
    return changed and hashes or nil
end
-- One hash and one held-index lookup per name, not a scan of all held lists.
function W.match(st,name,now)
    local hash=W.hash(name)
    if not hash then return false end
    local ours=st.own[hash]==true
    local bucket=st.byHash[hash]
    local senders={}
    for key in pairs(bucket or {}) do
        local h=st.held[key]
        if h and now>=h.at and now-h.at<W.TTL then senders[#senders+1]=h.name end
    end
    return ours or #senders>0,ours,hash,senders
end
function W.notice(st,e,now,enabled,instance)
    if not enabled or instance~=false or e.faction~="opposite" or type(e.source)~="string" or not e.source:match("^own ") then return end
    for hash,at in pairs(st.noticed) do if now-at>=600 then st.noticed[hash]=nil end end
    local name=F.name(e.displayName or e.name)
    if not name then return end
    local listed,ours,hash,senders=W.match(st,name,now)
    if not listed or ours or #senders==0 then return end
    local at=st.noticed[hash]
    if at and now-at<600 then return end
    st.notices=window(st.notices,now,60)
    if #st.notices>=3 then return end
    st.notices[#st.notices+1]=now; st.noticed[hash]=now
    table.sort(senders)
    -- T carries hashes only: even an equal spelling is not exact-name evidence.
    return "LayerEnemies: "..name.." may be tracked by "..senders[1]..(#senders>1 and (" and "..(#senders-1).." others") or "")
end
