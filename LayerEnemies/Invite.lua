-- Friendly players known to stand on another layer, and the manual ask flow.
-- Nothing here sends chat, invites, accepts or leaves: it only builds a list,
-- a line for the user to send, and messages about the user's own layer.
local _, N = ...
local I,S,L = {},N.Safe,N.Layer
N.Invite=I
I.MESSAGE="Hi! Could you invite me to your layer please?"
-- The 15 s is the vote window of Layer.lua, which counts distinct NPC ids (kinds), not individual creatures.
I.HINT="Your layer is not known yet: target or mouse over two different kinds of NPC within 15 seconds."
I.NAME_COOLDOWN,I.GLOBAL_COOLDOWN=60,10
I.JOIN_WINDOW,I.WATCH=300,60
I.BULO_STALE,I.BOOK_FRESH,I.REPORT_FRESH=720,900,600
I.MAX_SCAN,I.MAX_ROWS=512,40
function I.new() return { asked={}, lastAsk=nil, pending=nil, watch=nil } end
-- The one name rule (whisper, guild check, guild host, invite): "Name" or "First Surname" (Forever), letters only,
-- optionally "-Realm" (letters, digits, apostrophes; no spaces, as the client writes it). Anything else is nil.
-- Returns name, key, target. The key is the whole name, realm included: Scout-RealmA and Scout-RealmB are two
-- players. Our own realm is dropped from key and target, so "Bob" and "Bob-<our realm>" are one; any other realm
-- stays in both, and the target is what an invite names.
-- letters(w, digits): ASCII letters (and digits when allowed) or well-formed UTF-8 letters. Refused: the Latin-1
-- punctuation block (no-break space, soft hyphen, middle dot, U+00A0-U+00BF), U+00D7 and U+00F7, general
-- punctuation and invisible marks (U+2000-U+206F, U+FEFF, U+3000-U+303F), specials and surrogates, and any broken
-- byte sequence.
local function letters(w,digits)
    local i,n=1,#w
    while i<=n do
        local b=w:byte(i)
        if b<128 then
            if not ((b>=65 and b<=90) or (b>=97 and b<=122) or (digits and ((b>=48 and b<=57) or b==39))) then return false end
            i=i+1
        else
            local len=b>=0xF0 and b<=0xF4 and 4 or b>=0xE0 and 3 or b>=0xC2 and b<0xE0 and 2 or nil
            if not len or i+len-1>n then return false end
            local cp=b%(len==2 and 32 or len==3 and 16 or 8)
            for k=1,len-1 do
                local c=w:byte(i+k)
                if c<0x80 or c>0xBF then return false end
                cp=cp*64+(c-0x80)
            end
            if (len==3 and cp<0x800) or (len==4 and (cp<0x10000 or cp>0x10FFFF)) then return false end
            if cp<0xC0 or cp==0xD7 or cp==0xF7 or (cp>=0x2000 and cp<=0x206F) or cp==0xFEFF or (cp>=0x3000 and cp<=0x303F)
                or (cp>=0xD800 and cp<=0xDFFF) or cp>=0xFFF0 and cp<=0xFFFF then return false end
            i=i+len
        end
    end
    return true
end
function I.name(name)
    name=S.str(name,100)
    if not name then return nil end
    local base,realm=name:match("^(.-)%-([%w'\128-\255]+)$")
    if realm and not letters(realm,true) then return nil end
    base=base or name                                 -- a dash outside a realm suffix fails the letters check below
    local first,surname=base:match("^([%a\128-\255]+) ([%a\128-\255]+)$")
    if first then
        if #first<2 or #first>36 or #surname>36 or not letters(first) or not letters(surname) then return nil end
    elseif #base<2 or #base>36 or not base:match("^[%a\128-\255]+$") or not letters(base) then return nil end
    if realm then
        local home=I.home and S.str(I.home(),60)
        local function norm(v) return (v:lower():gsub("[%s%-']","")) end
        if home and norm(realm)==norm(home) then return name,base:lower(),base end
    end
    return name,name:lower(),name
end
I.home=nil                                                      -- set by Main: our realm name
-- the folded key of a player (our realm stripped, lower case) or nil; rate keys fall back to the raw name lowered
function I.key(name) local _,key=I.name(name); return key end
function I.rateKey(name) return I.key(name) or tostring(name):lower() end
function I.line(name) return "/w "..name.." "..I.MESSAGE end
local function zoneText(v)
    v=S.clean(v)
    if type(v)=="number" and v==v and v>0 and v%1==0 then return string.format("%.0f",v) end
    return S.str(v,40)
end
local readers={
    -- Bulo Layer Forever: Guild.list[name]={key,zone,host,at,other}
    Bulo=function(e) return L.key(e.key),zoneText(e.zone),S.num(e.at),S.clean(e.host)==true,false end,
    -- LayerSwap: LayerSwapDB.book[shortName]={layer,zone,at,host,gone}
    LayerSwap=function(e)
        local gone=e.gone
        return L.key(e.layer),zoneText(e.zone),S.num(e.at),S.clean(e.host)==true,S.secret(gone) or gone~=nil
    end,
}
-- The host's own zoneUID, from a full "server-zoneUID" id (LayerSwap book). Bulo guild lines carry only the key.
local function uid(source,e)
    if source~="LayerSwap" then return nil end
    local raw=S.str(S.clean(e.layer),32)
    local u=raw and raw:match("^%d+%-(%d+)$")
    return u and #u<=9 and tonumber(u) or nil
end
-- One foreign table, read only. Any surprise discards the whole source.
local function scan(raw,env,source,maxAge)
    local read,out,seen=readers[source],{},0
    for rawName,e in pairs(raw) do
        seen=seen+1; if seen>I.MAX_SCAN then break end
        local name,short=I.name(rawName)
        if name and short~=env.self and S.tab(e) then
            local layer,zone,at,host,skip=read(e)
            local age=at and env.wall-at
            if age and age<0 and age>=-5 then age=0 end
            if layer and zone and zone==env.zoneText and age and age>=0 and age<maxAge and not skip then
                out[#out+1]={name=name,short=short,layer=layer,uid=uid(source,e),age=age,host=host,hosts={[source]=host},source=source,same=L.same(layer,env.ownKey)}
            end
        end
    end
    return out
end
-- A fresh foreign layer claim is evidence; zoneUID is not a server-layer key. Returns true, "probably" (an equal
-- key while our own key is ambiguous: another layer of this zone shares it) or false.
function I.sameSpotter(name,env)
    local _,wanted=I.name(name)
    if not wanted or not env.ownKey or not env.wall then return false end
    env.zoneText=zoneText(env.zone)
    for _,source in ipairs({{"Bulo",env.bulo,I.BULO_STALE},{"LayerSwap",env.book,I.BOOK_FRESH}}) do
        if S.tab(source[2]) then
            local ok,claims=pcall(scan,source[2],env,source[1],source[3])
            if ok then for _,c in ipairs(claims) do if c.short==wanted and c.same then return env.ambiguous and "probably" or true end end end
        end
    end
    return false
end
local function addSource(c,label)
    for _,have in ipairs(c.sources) do if have==label then return end end
    c.sources[#c.sources+1]=label
end
local function better(a,b)
    -- Layerless FLH-only claims must not displace real layer rows at the cap.
    -- Keep the existing reporter and known-layer ordering otherwise.
    local af=a.flhKey~=nil and not a.layer and not a.reporter
    local bf=b.flhKey~=nil and not b.layer and not b.reporter
    if af~=bf then return not af end
    if (a.probably==true)~=(b.probably==true) then return not a.probably end
    if a.reporter~=b.reporter then return a.reporter end
    if a.host~=b.host then return a.host end
    if a.age~=b.age then return a.age<b.age end
    return a.short<b.short
end
-- env: now (GetTime), wall (time()), zone, ownKey, ambiguous, self, reporters, bulo, book.
-- While our own key is ambiguous an equal key is only "probably" our layer: such players stay listed, marked.
-- bulo/book: nil = not installed, false = unreadable, table = raw foreign list.
function I.collect(env)
    local byName,status={}, {}
    env.zoneText=zoneText(env.zone)
    local function source(label,field,raw,maxAge)
        if raw==nil then status[field]="not installed"; return end
        if not S.tab(raw) then status[field]="data unavailable"; return end
        if not env.self then status[field]="own name unreadable"; return end
        if not env.wall or not env.zoneText then status[field]="clock or zone unavailable"; return end
        local ok,claims=pcall(scan,raw,env,label,maxAge)
        if not ok then status[field]="data unavailable"; return end
        for _,c in ipairs(claims) do
            -- listed while our own key is unknown, so a host is visible; no hop or ask goes through such a row
            c.unknownOwn=not env.ownKey or nil
            local cur=byName[c.short]
            if not cur then
                c.sources={c.source}; byName[c.short]=c
            elseif c.age<cur.age then
                -- The fresher layer claim wins outright.
                c.sources={c.source}
                if cur.layer==c.layer then
                    c.host=c.host or cur.host
                    for k,v in pairs(cur.hosts or {}) do c.hosts[k]=c.hosts[k] or v end
                    for _,label in ipairs(cur.sources) do addSource(c,label) end
                end
                byName[c.short]=c
            elseif cur.layer==c.layer then
                cur.host=cur.host or c.host; addSource(cur,c.source)
                cur.hosts=cur.hosts or {}; cur.hosts[c.source]=cur.hosts[c.source] or c.host
            end
        end
        status[field]=#claims.." fresh in this zone"..(env.ownKey and "" or " (your layer is not known yet)")
    end
    source("Bulo","bulo",env.bulo,I.BULO_STALE)
    source("LayerSwap","book",env.book,I.BOOK_FRESH)
    -- FLH's GUID field 5 is a fingerprint claim, not a server key. Merge only
    -- the player's identity/provenance; never promote it to layer/uid or a
    -- LayerSwap/Bulo host flag. F2 guest actions consume this separate provenance.
    local flhCount=0
    if env.self and S.num(env.wall) and S.num(env.zone) and S.tab(env.flh) then
        for _,e in pairs(env.flh) do
            local name,key=I.name(e.name)
            local age=env.wall-e.at
            if name and key~=env.self and e.map==env.zone and age>=0 and age<N.Hosts.FLH_KEEP then
                local c=byName[key]
                if not c then
                    c={name=name,short=key,age=age,host=false,hosts={},sources={},unknownOwn=not env.ownKey or nil}
                    byName[key]=c
                end
                c.flhKey,c.flhAge=e.key,age
                c.hosts.FLH=true; addSource(c,"Forever Layer Hop")
                flhCount=flhCount+1
            end
        end
    end
    status.flh=flhCount.." fresh in this zone (FLH claims; guest hopping)"
    local reports=0
    if env.self and S.num(env.now) then
        for _,r in ipairs(env.reporters or {}) do
            local name,short=I.name(r.name)
            local age=S.num(r.at) and env.now-r.at
            -- A reporter whose zoneUID equals ours is taken to be on our layer.
            if name and short~=env.self and age and age>=0 and age<I.REPORT_FRESH and not r.match then
                local cur=byName[short]
                if not cur then
                    byName[short]={name=name,short=short,age=age,host=false,reporter=true,sources={"War Effort"}}
                    reports=reports+1
                elseif not cur.same and not cur.reporter then
                    cur.reporter=true; addSource(cur,"War Effort"); reports=reports+1
                end
            end
        end
    end
    status.reports=env.self and (reports.." not on your server key") or "own name unreadable"
    local out={}
    for _,c in pairs(byName) do
        if c.same and env.ambiguous then c.same=false; c.probably=true end
        if not c.same then c.reporter=c.reporter==true; out[#out+1]=c end
    end
    table.sort(out,better)
    for i=#out,I.MAX_ROWS+1,-1 do out[i]=nil end
    return out,status
end
-- The shared cooldowns of an ask or a hop: 60 s per name, 10 s overall. Reserves on success.
function I.reserve(st,c,now)
    for short,at in pairs(st.asked) do if now-at>=I.NAME_COOLDOWN then st.asked[short]=nil end end
    local last=st.asked[c.short]
    if last then return false,c.name.." was asked "..math.floor(now-last).." s ago; wait "..math.ceil(I.NAME_COOLDOWN-(now-last)).." s." end
    if st.lastAsk and now-st.lastAsk<I.GLOBAL_COOLDOWN then
        return false,"one ask every "..I.GLOBAL_COOLDOWN.." s; wait "..math.ceil(I.GLOBAL_COOLDOWN-(now-st.lastAsk)).." s."
    end
    st.asked[c.short]=now; st.lastAsk=now
    return true
end
-- Reserve the ask. Returns true and the chat line, or false and the reason.
function I.ask(st,c,now,grouped,ownKey)
    if grouped then return false,"leave your current group first; an invite cannot reach you while grouped." end
    local ok,why=I.reserve(st,c,now)
    if not ok then return false,why end
    st.pending={name=c.name,target=c.layer,from=ownKey,at=now}
    return true,I.line(c.name)
end
-- The user joined a group: watch the layer only when an ask came first.
function I.joined(st,now,key,zone)
    local p=st.pending
    st.pending=nil
    if not p or now-p.at>I.JOIN_WINDOW then return false end
    st.watch={name=p.name,target=p.target,from=key or p.from,zone=zone,deadline=now+I.WATCH,stop=now+I.WATCH*3}
    return true
end
-- key is the user's own confirmed layer key, nil while it is not confirmed; ambiguous: another layer of this zone
-- shares that key, so an unchanged key is only "probably" the same layer.
function I.tick(st,now,key,zone,ambiguous)
    local w=st.watch
    if not w then return nil end
    if zone~=w.zone then st.watch=nil; return "Zone changed - layer check cancelled." end
    if key and not w.from then
        st.watch=nil
        return "Now on layer "..key.." - your earlier layer was not known, so a move is not confirmed."
    end
    if key and not L.same(key,w.from) then
        st.watch=nil
        local note=w.target and not L.same(key,w.target) and (w.name.." was listed on layer "..w.target..", not "..key..".") or nil
        return "Moved to layer "..key..". Whether leaving the group keeps you there is not confirmed - stay grouped if unsure.",note
    end
    if now<w.deadline then return nil end
    if key then
        st.watch=nil
        if ambiguous then return "Probably still on your layer (your server key is ambiguous) - leave, wait a minute, try again." end
        return "Still on your layer - leave, wait a minute, try again."
    end
    if now>=w.stop then st.watch=nil; return "Layer check ended - your layer could not be confirmed." end
    if not w.warned then w.warned=true; return "Layer not confirmed yet - target or mouse over two different kinds of NPC." end
end
