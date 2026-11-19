-- 1.2.4 Battle.net friend and community presence shared with the guild (owner's request, 2026-11-19).
-- Every opposite-faction friend or community member our client sees online with a zone goes to the guild on LEGW1
-- as "P|1|<age>|<entries>". Entry: name:zone:faction:class:level:guid. Name and zone are escaped: letters, digits
-- and "-" as they are, a space as ".", any other byte as "/" and two hex digits, so a line keeps to the characters
-- every LEGW1 reader accepts. Class is the class id (1-13), guid the part after "Player-". An entry with an empty
-- zone says that character went offline (or left our view). Session-only on both sides; nothing here is saved.
-- Pure helpers only: no client calls and no sends (Main owns those).
local _,N=...
local S=N.Safe
local FS={}
N.FriendShare=FS
FS.VERSION="1"
FS.REFRESH=300        -- everything again every 5 minutes (as the budget allows; see plan)
FS.TTL=900            -- a received entry not refreshed for 15 minutes is gone
FS.CHANGE_GAP=15      -- a friend or community change rescans at most this often
FS.ANSWER_GAP=30      -- a guild watch list naming one of ours is answered at most this often per name
FS.MAX_SENDER,FS.MAX=100,400
FS.LINE=255
local CLASS_IDS={"WARRIOR","PALADIN","HUNTER","ROGUE","PRIEST","DEATHKNIGHT","SHAMAN","MAGE","WARLOCK","MONK","DRUID",
    "DEMONHUNTER","EVOKER"}
local CLASSES,CLASS_ID={},{}
for id,token in ipairs(CLASS_IDS) do CLASSES[token]=true; CLASS_ID[token]=id end
local FACTION={Alliance="A",Horde="H"}
local FACTIONBACK={A="Alliance",H="Horde"}
local function esc(s)
    return (s:gsub("[^%w%-]",function(c) return c==" " and "." or string.format("/%02X",c:byte()) end))
end
local function unesc(t)
    if t:find("[^%w%-%./]") or t:gsub("/%x%x",""):find("/") then return nil end
    return (t:gsub("/(%x%x)",function(h) return string.char(tonumber(h,16)) end):gsub("%.",function() return " " end))
end
FS.esc,FS.unesc=esc,unesc
-- Well-formed UTF-8 (no overlong forms, no surrogates, nothing above U+10FFFF).
local function utf8ok(s)
    local i,n=1,#s
    while i<=n do
        local c=s:byte(i)
        local len,lo,hi=0,0x80,0xBF
        if c<0x80 then len=0
        elseif c>=0xC2 and c<=0xDF then len=1
        elseif c==0xE0 then len,lo=2,0xA0
        elseif c>=0xE1 and c<=0xEC or c==0xEE or c==0xEF then len=2
        elseif c==0xED then len,hi=2,0x9F
        elseif c==0xF0 then len,lo=3,0x90
        elseif c>=0xF1 and c<=0xF3 then len=3
        elseif c==0xF4 then len,hi=3,0x8F
        else return false end
        for k=1,len do
            local b=s:byte(i+k)
            if not b or b<(k==1 and lo or 0x80) or b>(k==1 and hi or 0xBF) then return false end
        end
        i=i+len+1
    end
    return true
end
FS.utf8ok=utf8ok
FS.classOk=function(c) return type(c)=="string" and CLASSES[c]==true end
local function level(v)
    v=S.num(v)
    if v and v>=1 and v<=100 and v%1==0 then return v end
end
FS.level=level
local function guidTail(g)
    if type(g)~="string" or #g>60 then return nil end
    return g:match("^Player%-(%d+%-%x+)$")
end
local function text(v,max)
    v=S.str(v,max)
    if v and utf8ok(v) then return v end -- S.str already refuses control bytes and "|"
end

-- entry(e) -> one wire entry, or nil. e: name, zone (nil = offline), faction, class, level, guid.
function FS.entry(e)
    local name=text(e.name,100); if not name then return nil end
    if not e.zone then return esc(name)..":::::" end
    local zone=text(e.zone,120); if not zone then return nil end
    return table.concat({esc(name),esc(zone),FACTION[e.faction] or "",CLASS_ID[e.class] or "",
        level(e.level) and tostring(e.level) or "",guidTail(e.guid) or ""},":")
end
local function headOf(age)
    age=math.max(0,math.min(900,math.floor(S.num(age) or 0)))
    return "P|"..FS.VERSION.."|"..age.."|"
end
-- lines(entries, age) -> list of lines, each at most FS.LINE bytes, as few as fit.
function FS.lines(entries,age)
    local head=headOf(age)
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
function FS.decode(line)
    if S.secret(line) or type(line)~="string" or #line>FS.LINE then return nil,"invalid" end
    local version,age,body=line:match("^P|([^|]*)|(%d+)|([^|]*)$")
    if not version then return nil,"invalid" end
    if version~=FS.VERSION then return nil,"version" end
    age=tonumber(age); if age>900 then return nil,"invalid" end
    local entries={}
    for item in (body..","):gmatch("([^,]*),") do
        local n,z,f,c,l,g=item:match("^([^:]+):([^:]*):([AH]?):(%d*):(%d*):([%x%-]*)$")
        if not n then return nil,"invalid" end
        local name=unesc(n); if not name or text(name,100)~=name then return nil,"invalid" end
        local e={name=name}
        if z~="" then
            e.zone=unesc(z); if not e.zone or text(e.zone,120)~=e.zone then return nil,"invalid" end
            e.faction=FACTIONBACK[f]
            if c~="" then e.class=CLASS_IDS[tonumber(c)]; if not e.class or c:sub(1,1)=="0" then return nil,"invalid" end end
            if l~="" then e.level=level(tonumber(l)); if not e.level or l:sub(1,1)=="0" then return nil,"invalid" end end
            if g~="" then e.guid="Player-"..g; if not guidTail(e.guid) then return nil,"invalid" end end
        elseif f~="" or c~="" or l~="" or g~="" then return nil,"invalid" end
        entries[#entries+1]=e
    end
    if #entries==0 then return nil,"invalid" end
    return {age=age,entries=entries}
end

-- Sender side. Nothing is dropped by a refresh: entries wait by key, and each line is built when it can be sent.
--   cur: key -> entry as last scanned; names: key -> name (for a withdrawal after the entry left cur)
--   sent: key -> entry as last sent; lastAt: key -> time last sent
--   urgent: keys in order (watch answers at the front, then changes and withdrawals), never cleared by a refresh
--   due: set of keys owed by a refresh; sent stalest first (never-sent first), so a refresh that the budget cannot
--   finish carries on where it stopped instead of starting again at "A".
function FS.newOut()
    return {cur={},names={},sent={},lastAt={},urgent={},due={},fullAt=nil,answered={},
        stats={lines=0,entries=0,refused=0}}
end
local function same(a,b)
    return a.zone==b.zone and a.faction==b.faction and a.class==b.class and a.level==b.level and a.guid==b.guid and a.name==b.name
end
local function urgentIndex(out,key)
    for i,k in ipairs(out.urgent) do if k==key then return i end end
end
local function pushUrgent(out,key,front)
    local i=urgentIndex(out,key)
    if i and not front then return end
    if i then table.remove(out.urgent,i) end
    if front then table.insert(out.urgent,1,key) else out.urgent[#out.urgent+1]=key end
    out.due[key]=nil
end
-- plan(out, current, now) -> full: takes a new scan. Changes and withdrawals (against what was last sent) become
-- urgent; on the first scan and every REFRESH all current keys become due (keys already waiting keep their place).
function FS.plan(out,current,now)
    local first=out.fullAt==nil
    local full=first or now<out.fullAt or now-out.fullAt>=FS.REFRESH
    for key,e in pairs(current) do
        out.names[key]=e.name
        -- changed against what the guild last heard, or for a key not sent yet, against the previous scan
        local was=out.sent[key] or out.cur[key]
        if not first and not (was and same(was,e)) then pushUrgent(out,key) end
    end
    for key in pairs(out.cur) do
        if not current[key] then
            out.due[key]=nil
            if out.sent[key] then pushUrgent(out,key)
            else local i=urgentIndex(out,key); if i then table.remove(out.urgent,i) end end
        end
    end
    out.cur=current
    if full then
        for key in pairs(current) do if not urgentIndex(out,key) then out.due[key]=true end end
        out.fullAt=now
    end
    return full
end
function FS.pending(out) return out.urgent[1]~=nil or next(out.due)~=nil end
-- nextLine(out, age) -> line, keys: urgent keys first in order, then due keys stalest first, packed into one line.
-- Keys whose entry cannot be written are dropped.
function FS.nextLine(out,age)
    local order={}
    for _,k in ipairs(out.urgent) do order[#order+1]=k end
    local due={}
    for k in pairs(out.due) do due[#due+1]=k end
    table.sort(due,function(a,b)
        local x,y=out.lastAt[a] or -1,out.lastAt[b] or -1
        if x~=y then return x<y end
        return a<b
    end)
    for _,k in ipairs(due) do order[#order+1]=k end
    local head=headOf(age)
    local items,keys,used={},{},#head
    for _,k in ipairs(order) do
        local e=out.cur[k] or (out.sent[k] and {name=out.names[k]})
        local item=e and FS.entry(e)
        if not item or #head+#item>FS.LINE then
            FS.done(out,{k},nil)
        else
            local extra=#item+(#items>0 and 1 or 0)
            if used+extra<=FS.LINE then items[#items+1]=item; keys[#keys+1]=k; used=used+extra end
        end
    end
    if #items==0 then return nil end
    return head..table.concat(items,","),keys
end
-- done(out, keys, now): those keys left in a line at now (now nil: dropped unsent).
function FS.done(out,keys,now)
    for _,k in ipairs(keys) do
        local i=urgentIndex(out,k); if i then table.remove(out.urgent,i) end
        out.due[k]=nil
        if now then
            out.lastAt[k]=now; out.sent[k]=out.cur[k]
            out.stats.entries=out.stats.entries+1
        end
        if not out.cur[k] then out.names[k]=nil; if not now then out.sent[k]=nil end end
    end
end
-- clear(out): nothing waits (sharing went off); what was sent is forgotten so it all goes again later.
function FS.clear(out)
    out.urgent,out.due,out.sent,out.lastAt,out.fullAt={},{},{},{},nil
end
-- answer(out, keys, now) -> count: current entries a guild watch list names go to the front, at most every
-- ANSWER_GAP per name.
function FS.answer(out,keys,now)
    local list={}
    for key in pairs(keys) do
        local at=out.answered[key]
        if out.cur[key] and (not at or now<at or now-at>=FS.ANSWER_GAP) then out.answered[key]=now; list[#list+1]=key end
    end
    table.sort(list,function(a,b) return a>b end)
    for _,key in ipairs(list) do pushUrgent(out,key,true) end
    return #list
end

-- Receiver side. inn: by (sender key .. "\0" .. name key) -> entry with sender and at.
function FS.newIn() return {items={},count=0,perSender={}} end
local function drop(inn,id)
    local r=inn.items[id]; if not r then return end
    inn.items[id]=nil; inn.count=inn.count-1; inn.sorted=nil
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
    inn.items[id]=r; inn.sorted=nil
    return r
end
function FS.prune(inn,now)
    -- nothing can expire before the oldest entry does (and a clock that steps back checks everything)
    if inn.sorted and inn.oldest and now>=inn.sortedAt and now-inn.oldest<FS.TTL then return end
    for id,r in pairs(inn.items) do
        if now<r.at or now-r.at>=FS.TTL then drop(inn,id) end
    end
end
-- rows(inn, now) -> fresh rows, newest first, then by name. The window redraws often with up to 400 entries, so the
-- sorted list is kept until an entry is stored, dropped or expires. Callers must not change the list.
function FS.rows(inn,now)
    FS.prune(inn,now)
    if inn.sorted then inn.sortedAt=now; return inn.sorted end
    local out,oldest={},nil
    for _,r in pairs(inn.items) do out[#out+1]=r; if not oldest or r.at<oldest then oldest=r.at end end
    table.sort(out,function(a,b) if a.at~=b.at then return a.at>b.at end; if a.nameKey~=b.nameKey then return a.nameKey<b.nameKey end; return a.senderKey<b.senderKey end)
    inn.sorted,inn.oldest,inn.sortedAt=out,oldest,now
    return out
end
