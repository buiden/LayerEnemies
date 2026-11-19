-- 1.2.4 Battle.net friend and community presence shared with the guild (owner's request, 2026-11-19).
-- Every opposite-faction friend or community member our client sees online with a zone goes to the guild on LEGW1
-- as "P|1|<age>|<entries>". Entry: hex(name):hex(zone):faction:class:level:guid. An entry with an empty zone says
-- that character went offline (or left our view). Session-only on both sides; nothing here is saved.
-- Pure helpers only: no client calls and no sends (Main owns those).
local _,N=...
local S=N.Safe
local FS={}
N.FriendShare=FS
FS.VERSION="1"
FS.REFRESH=300        -- everything again every 5 minutes
FS.TTL=900            -- a received entry not refreshed for 15 minutes is gone
FS.CHANGE_GAP=15      -- a friend or community change rescans at most this often
FS.ANSWER_GAP=30      -- a guild watch list naming one of ours is answered at most this often per name
FS.MAX_SENDER,FS.MAX=100,400
FS.LINE=255
local CLASSES={WARRIOR=true,PALADIN=true,HUNTER=true,ROGUE=true,PRIEST=true,DEATHKNIGHT=true,SHAMAN=true,
    MAGE=true,WARLOCK=true,MONK=true,DRUID=true,DEMONHUNTER=true,EVOKER=true}
local FACTION={Alliance="A",Horde="H"}
local FACTIONBACK={A="Alliance",H="Horde"}
local function hex(s) return (s:gsub(".",function(c) return string.format("%02x",c:byte()) end)) end
local function unhex(h)
    if #h==0 or #h%2==1 or h:find("[^%x]") then return nil end
    return (h:gsub("%x%x",function(b) return string.char(tonumber(b,16)) end))
end
FS.classOk=function(c) return type(c)=="string" and CLASSES[c]==true end
local function level(v)
    v=S.num(v)
    if v and v>=1 and v<=100 and v%1==0 then return v end
end
FS.level=level
local function guidOk(g) return type(g)=="string" and #g<=60 and g:match("^[%w%-]+$")~=nil end

-- entry(e) -> one wire entry, or nil. e: name, zone (nil = offline), faction, class, level, guid.
function FS.entry(e)
    local name=S.str(e.name,100); if not name then return nil end
    if not e.zone then return hex(name)..":::::" end
    local zone=S.str(e.zone,120); if not zone then return nil end
    return table.concat({hex(name),hex(zone),FACTION[e.faction] or "",FS.classOk(e.class) and e.class or "",
        level(e.level) and tostring(e.level) or "",guidOk(e.guid) and e.guid or ""},":")
end
-- lines(entries, age) -> list of lines, each at most FS.LINE bytes, as few as fit.
function FS.lines(entries,age)
    age=math.max(0,math.min(900,math.floor(S.num(age) or 0)))
    local head="P|"..FS.VERSION.."|"..age.."|"
    local out,items,used={},{},#head
    for _,e in ipairs(entries) do
        local item=FS.entry(e)
        if item and #head+#item<=FS.LINE then
            local extra=#item+(#items>0 and 1 or 0)
            if used+extra>FS.LINE then out[#out+1]=head..table.concat(items,","); items,used={},#head; extra=#item end
            items[#items+1]=item; used=used+extra
        end
    end
    if #items>0 then out[#out+1]=head..table.concat(items,",") end
    return out
end
-- decode(text) -> {age=, entries={...}} or nil, why. Every field is checked; one bad entry refuses the line.
function FS.decode(text)
    if S.secret(text) or type(text)~="string" or #text>FS.LINE then return nil,"invalid" end
    local version,age,body=text:match("^P|([^|]*)|(%d+)|([^|]*)$")
    if not version then return nil,"invalid" end
    if version~=FS.VERSION then return nil,"version" end
    age=tonumber(age); if age>900 then return nil,"invalid" end
    local entries={}
    for item in (body..","):gmatch("([^,]*),") do
        local n,z,f,c,l,g=item:match("^(%x+):(%x*):([AH]?):(%u*):(%d*):([%w%-]*)$")
        if not n then return nil,"invalid" end
        local name=unhex(n); if not name or not S.str(name,100) or name:find("[%c|]") then return nil,"invalid" end
        local e={name=name}
        if z~="" then
            e.zone=unhex(z); if not e.zone or not S.str(e.zone,120) or e.zone:find("%c") then return nil,"invalid" end
            e.faction=FACTIONBACK[f]
            if c~="" then if not CLASSES[c] then return nil,"invalid" end; e.class=c end
            if l~="" then e.level=level(tonumber(l)); if not e.level then return nil,"invalid" end end
            if g~="" then if not guidOk(g) then return nil,"invalid" end; e.guid=g end
        elseif f~="" or c~="" or l~="" or g~="" then return nil,"invalid" end
        entries[#entries+1]=e
    end
    if #entries==0 then return nil,"invalid" end
    return {age=age,entries=entries}
end

-- Sender side. out: sent (key -> entry last sent), fullAt, answered (key -> time).
function FS.newOut() return {sent={},fullAt=nil,answered={},queue={},stats={lines=0,entries=0,refused=0}} end
local function same(a,b)
    return a.zone==b.zone and a.faction==b.faction and a.class==b.class and a.level==b.level and a.guid==b.guid and a.name==b.name
end
-- plan(out, current, now) -> entries to send now (changes, withdrawals, or all on refresh), and records them sent.
function FS.plan(out,current,now)
    local full=not out.fullAt or now<out.fullAt or now-out.fullAt>=FS.REFRESH
    local list={}
    for key,e in pairs(current) do
        if full or not out.sent[key] or not same(out.sent[key],e) then list[#list+1]=e end
    end
    for key,e in pairs(out.sent) do
        if not current[key] then list[#list+1]={name=e.name} end
    end
    table.sort(list,function(a,b) return a.name<b.name end)
    out.sent={}; for key,e in pairs(current) do out.sent[key]=e end
    if full then out.fullAt=now end
    return list,full
end
-- answer(out, keys, now) -> entries (already shared) for a guild watch list that names them, at most every ANSWER_GAP.
function FS.answer(out,keys,now)
    local list={}
    for key in pairs(keys) do
        local e,at=out.sent[key],out.answered[key]
        if e and (not at or now<at or now-at>=FS.ANSWER_GAP) then out.answered[key]=now; list[#list+1]=e end
    end
    table.sort(list,function(a,b) return a.name<b.name end)
    return list
end

-- Receiver side. inn: by (sender key .. "\0" .. name key) -> entry with sender and at.
function FS.newIn() return {items={},count=0,perSender={}} end
local function drop(inn,id)
    local r=inn.items[id]; if not r then return end
    inn.items[id]=nil; inn.count=inn.count-1
    inn.perSender[r.senderKey]=(inn.perSender[r.senderKey] or 1)-1
    if inn.perSender[r.senderKey]<=0 then inn.perSender[r.senderKey]=nil end
end
FS.drop=drop
-- put(inn, sender, senderKey, nameKey, entry, at) -> stored row, or nil (withdrawn or full).
function FS.put(inn,sender,senderKey,nameKey,e,at)
    local id=senderKey.."\0"..nameKey
    if not e.zone then drop(inn,id); return nil end
    if not inn.items[id] then
        if inn.count>=FS.MAX or (inn.perSender[senderKey] or 0)>=FS.MAX_SENDER then return nil end
        inn.count=inn.count+1; inn.perSender[senderKey]=(inn.perSender[senderKey] or 0)+1
    end
    local r={name=e.name,nameKey=nameKey,zone=e.zone,faction=e.faction,class=e.class,level=e.level,guid=e.guid,
        sender=sender,senderKey=senderKey,at=at}
    inn.items[id]=r
    return r
end
function FS.prune(inn,now)
    for id,r in pairs(inn.items) do
        if now<r.at or now-r.at>=FS.TTL then drop(inn,id) end
    end
end
-- rows(inn, now) -> fresh rows, newest first, then by name.
function FS.rows(inn,now)
    FS.prune(inn,now)
    local out={}
    for _,r in pairs(inn.items) do out[#out+1]=r end
    table.sort(out,function(a,b) if a.at~=b.at then return a.at>b.at end; if a.nameKey~=b.nameKey then return a.nameKey<b.nameKey end; return a.senderKey<b.senderKey end)
    return out
end
