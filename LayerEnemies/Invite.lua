-- Friendly players known to stand on another layer, and the manual ask flow.
-- Nothing here sends chat, invites, accepts or leaves: it only builds a list,
-- a line for the user to send, and messages about the user's own layer.
local _, N = ...
local I,S,L = {},N.Safe,N.Layer
N.Invite=I
I.MESSAGE="Hi! Could you invite me to your layer please? I'll leave right after."
I.NAME_COOLDOWN,I.GLOBAL_COOLDOWN=60,10
I.JOIN_WINDOW,I.WATCH=300,60
I.BULO_STALE,I.BOOK_FRESH,I.REPORT_FRESH=720,900,600
I.MAX_SCAN,I.MAX_ROWS=512,40
function I.new() return { asked={}, lastAsk=nil, pending=nil, watch=nil } end
-- A whisper target: letters only, optionally "-Realm". Returns name, dedupe key.
function I.name(name)
    name=S.str(name,60)
    if not name then return nil end
    local first,surname=name:match("^([%a\128-\255]+) ([%a\128-\255]+)$")
    if first and #first>=2 and #first<=36 and #surname<=36 then return name,name:lower() end
    local short,rest=name:match("^([^%-]+)(.*)$")
    if not short or #short<2 or #short>36 or not short:match("^[%a\128-\255]+$") then return nil end
    if rest~="" and not rest:match("^%-[%w'\128-\255]+$") then return nil end
    return name,short:lower()
end
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
                out[#out+1]={name=name,short=short,layer=layer,age=age,host=host,source=source,same=L.same(layer,env.ownKey)}
            end
        end
    end
    return out
end
-- A fresh foreign layer claim is evidence; zoneUID is not a server-layer key.
function I.sameSpotter(name,env)
    local _,wanted=I.name(name)
    if not wanted or not env.ownKey or not env.wall then return false end
    env.zoneText=zoneText(env.zone)
    for _,source in ipairs({{"Bulo",env.bulo,I.BULO_STALE},{"LayerSwap",env.book,I.BOOK_FRESH}}) do
        if S.tab(source[2]) then
            local ok,claims=pcall(scan,source[2],env,source[1],source[3])
            if ok then for _,c in ipairs(claims) do if c.short==wanted and c.same then return true end end end
        end
    end
    return false
end
local function addSource(c,label)
    for _,have in ipairs(c.sources) do if have==label then return end end
    c.sources[#c.sources+1]=label
end
local function better(a,b)
    if a.reporter~=b.reporter then return a.reporter end
    if a.host~=b.host then return a.host end
    if a.age~=b.age then return a.age<b.age end
    return a.short<b.short
end
-- env: now (GetTime), wall (time()), zone, ownKey, self, reporters, bulo, book.
-- bulo/book: nil = not installed, false = unreadable, table = raw foreign list.
function I.collect(env)
    local byName,status={}, {}
    env.zoneText=zoneText(env.zone)
    local function source(label,field,raw,maxAge)
        if raw==nil then status[field]="not installed"; return end
        if not S.tab(raw) then status[field]="data unavailable"; return end
        if not env.self then status[field]="own name unreadable"; return end
        if not env.wall or not env.zoneText then status[field]="clock or zone unavailable"; return end
        if not env.ownKey then status[field]="your layer is not known yet"; return end
        local ok,claims=pcall(scan,raw,env,label,maxAge)
        if not ok then status[field]="data unavailable"; return end
        for _,c in ipairs(claims) do
            local cur=byName[c.short]
            if not cur then
                c.sources={c.source}; byName[c.short]=c
            elseif c.age<cur.age then
                -- The fresher layer claim wins outright.
                c.sources={c.source}
                if cur.layer==c.layer then
                    c.host=c.host or cur.host
                    for _,label in ipairs(cur.sources) do addSource(c,label) end
                end
                byName[c.short]=c
            elseif cur.layer==c.layer then
                cur.host=cur.host or c.host; addSource(cur,c.source)
            end
        end
        status[field]=#claims.." fresh in this zone"
    end
    source("Bulo","bulo",env.bulo,I.BULO_STALE)
    source("LayerSwap","book",env.book,I.BOOK_FRESH)
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
    status.reports=env.self and (reports.." on another zoneUID") or "own name unreadable"
    local out={}
    for _,c in pairs(byName) do
        if not c.same then c.reporter=c.reporter==true; out[#out+1]=c end
    end
    table.sort(out,better)
    for i=#out,I.MAX_ROWS+1,-1 do out[i]=nil end
    return out,status
end
-- Reserve the ask. Returns true and the chat line, or false and the reason.
function I.ask(st,c,now,grouped,ownKey)
    if grouped then return false,"leave your current group first; an invite cannot reach you while grouped." end
    for short,at in pairs(st.asked) do if now-at>=I.NAME_COOLDOWN then st.asked[short]=nil end end
    local last=st.asked[c.short]
    if last then return false,c.name.." was asked "..math.floor(now-last).." s ago; wait "..math.ceil(I.NAME_COOLDOWN-(now-last)).." s." end
    if st.lastAsk and now-st.lastAsk<I.GLOBAL_COOLDOWN then
        return false,"one ask every "..I.GLOBAL_COOLDOWN.." s; wait "..math.ceil(I.GLOBAL_COOLDOWN-(now-st.lastAsk)).." s."
    end
    st.asked[c.short]=now; st.lastAsk=now
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
-- key is the user's own confirmed layer key, nil while it is not confirmed.
function I.tick(st,now,key,zone)
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
    if key then st.watch=nil; return "Still on your layer - leave, wait a minute, try again." end
    if now>=w.stop then st.watch=nil; return "Layer check ended - your layer could not be confirmed." end
    if not w.warned then w.warned=true; return "Layer not confirmed yet - target or mouse over two different NPCs." end
end
