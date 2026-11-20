-- ChehulNet v15 / LibChehulMesh v10 (GuildOS v1.28.0): protocol facts only.
-- Independent HELLO reader, no donor code. GUID field 5 is a per-map zoneUID,
-- never an LE server-layer key. See THIRD_PARTY.md and notes/chehulnet-hello.md.
local _,N=...
local Ch,S={},N.Safe
N.ChehulNet=Ch
Ch.TTL,Ch.MAX=400,200
local classes={WARRIOR=true,PALADIN=true,HUNTER=true,ROGUE=true,PRIEST=true,DEATHKNIGHT=true,
    SHAMAN=true,MAGE=true,WARLOCK=true,MONK=true,DRUID=true,DEMONHUNTER=true,EVOKER=true}
local function number(v,max)
    v=S.num(v)
    return v and v>=1 and v<=max and v%1==0 and v or nil
end
local function decimal(text,max)
    text=S.str(text,255)
    if not text or not text:match("^%d+$") then return nil end
    return number(tonumber(text),max)
end
function Ch.parse(text)
    if S.secret(text) or type(text)~="string" or #text>255 or text:find("%c") then return nil end
    local f={}
    for field in (text.."|"):gmatch("([^|]*)|") do
        f[#f+1]=field
        if #f>7 then return nil end
    end
    if (#f~=6 and #f~=7) or f[1]~="CHN1" or f[2]~="H" then return nil end
    local map,zone
    if f[7] then
        local m,z=f[7]:match("^(%d+):(%d+)$")
        map=decimal(m,99999999); zone=map and decimal(z,99999999) or nil
    end
    local class=S.str(f[4],16)
    return {class=class and classes[class] and class or nil,level=decimal(f[5],255),map=map,zone=zone}
end

-- All received identities live here, not in SavedVariables or a host/evidence store.
function Ch.new(me) return {self=N.Invite.key(me),entries={}} end
function Ch.sweep(st,wall)
    wall=S.num(wall)
    if not wall then return end
    for key,r in pairs(st.entries) do
        if wall<r.at or wall-r.at>=Ch.TTL then st.entries[key]=nil end
    end
end
local function note(st,sender,rec,dist,wall)
    dist=S.str(dist,20); wall=S.num(wall)
    if dist~="GUILD" and dist~="PARTY" and dist~="RAID" then return false end
    if not wall or not S.tab(rec) or not st.self then return false end
    local name,key,target=N.Invite.name(sender)
    if not name or key==st.self then return false end
    for _,field in ipairs({"class","level","map","zone"}) do if S.secret(rec[field]) then return false end end
    local map=number(rec.map,99999999)
    local class=S.str(rec.class,16)
    local r={name=target,short=key,class=class and classes[class] and class or nil,level=number(rec.level,255),
        map=map,zone=map and number(rec.zone,99999999) or nil,dist=dist,at=wall}
    Ch.sweep(st,wall)
    if not st.entries[key] and S.count(st.entries)>=Ch.MAX then
        local oldest
        for k,e in pairs(st.entries) do
            if not oldest or e.at<st.entries[oldest].at or (e.at==st.entries[oldest].at and k<oldest) then oldest=k end
        end
        st.entries[oldest]=nil
    end
    st.entries[key]=r
    return true
end
function Ch.note(st,sender,rec,dist,wall)
    local ok,result=pcall(note,st,sender,rec,dist,wall)
    return ok and result==true
end
-- Pure projection. myZone is our own GUID-field-5 reading, not a server key.
-- Optional ambiguity flag lets the live adapter explicitly withhold comparison.
function Ch.view(st,myMap,myZone,wall,ambiguous)
    wall=S.num(wall)
    if not wall then return {} end
    Ch.sweep(st,wall)
    myMap=number(myMap,99999999); myZone=number(myZone,99999999)
    local comparable=not S.secret(ambiguous) and (ambiguous==nil or ambiguous==false)
    local out={}
    for key,r in pairs(st.entries) do
        local rel
        if comparable and myMap and myZone and r.map==myMap and r.zone then rel=r.zone==myZone and "same" or "other" end
        out[#out+1]={name=r.name,short=key,class=r.class,level=r.level,map=r.map,zone=r.zone,rel=rel,age=wall-r.at,dist=r.dist}
    end
    table.sort(out,function(a,b) return a.short<b.short end)
    return out
end

local session=Ch.new(nil)
Ch.stats={}
local function safe()
    return not N.Adapters.inCombat() and N.Adapters.inInstance()==false
end
local function receive(prefix,text,dist,sender)
    local A=N.Adapters
    if prefix~="ChehulNet" or not N.Sources.enabled("chehulnet") or not safe() then return end
    local _,self=A.ownIdentity()
    local rec=Ch.parse(text)
    if N.Trust.state(N.Main.store,S.call(GetTime))=="blind" and rec then rec.zone=nil end
    session.self=self
    if not self or A.ignored(sender) or not rec or not Ch.note(session,sender,rec,dist,A.wall()) then
        N.Sources.count("chehulnet","refused"); return
    end
    N.Sources.count("chehulnet","accepted")
    if N.UI then N.UI.refresh() end
end
local function rows()
    if not N.Sources.enabled("chehulnet") or not safe() then return {} end
    local M,A=N.Main,N.Adapters
    local _,self=A.ownIdentity()
    if not self or not M or not M.store then return {} end
    local map=number(A.location(),99999999)
    local now=S.num(S.call(GetTime))
    local _,uid=N.Trust.own(M.store,now)
    uid=map==M.store.zone and number(uid,99999999) or nil
    local amb=true
    if now then amb=S.call(M.store.ambiguous,now)~=false end
    local out=Ch.view(session,map,uid,A.wall(),amb)
    if N.Trust.state(M.store,now)=="blind" then for _,r in ipairs(out) do r.zone=nil end end
    return out,map,uid~=nil and not amb
end
function Ch.rows()
    local ok,result,map,comparable=pcall(rows)
    if ok then return result,map,comparable end
    return {},nil,false
end
-- Display-only projection: the hop/ask collectors never see a hint. Clone rows
-- so a ChehulNet annotation cannot change the independent host capabilities.
-- Return hosts and hints separately; only hosts belong in the Friendly count.
function Ch.friendly(hosts)
    local out,index,hints={},{},{}
    for _,host in ipairs(hosts) do
        local row={}; for key,value in pairs(host) do row[key]=value end
        out[#out+1]=row; index[row.short]=row
    end
    for _,ally in ipairs(Ch.rows()) do
        if ally.rel=="other" then
            local row=index[ally.short]
            local age="received "..math.floor(ally.age).." s ago; time unknown"
            if row then
                row.chehulText="ChehulNet: other layer (ChehulNet claim) ("..age..")"
            else
                hints[#hints+1]={name=ally.name,short=ally.short,age=ally.age,sources={"ChehulNet"},chehulHint=true,
                    chehulText="another layer of your zone · ChehulNet claim (guild/group; "..age..")\nHint only; whisper them yourself."}
            end
        end
    end
    return out,hints
end
function Ch.layer()
    if not N.Trust.own(N.Main.store,S.call(GetTime)) then return end
    local rows,map,comparable=Ch.rows()
    local layers={}
    for _,row in ipairs(rows) do if row.map==map and row.zone then layers[row.zone]=true end end
    N.Main.say("ChehulNet: guild/group report "..S.count(layers).." distinct layers in your current zone (HELLO claims, no server keys).")
    if not comparable then N.Main.say("ChehulNet: comparison unavailable (own zone reading unknown or ambiguous)."); return end
    local same=0
    for _,row in ipairs(rows) do
        if row.rel=="same" then
            same=same+1
            if same<=8 then
                N.Main.say("ChehulNet: same layer as you: "..row.name.." (received "..math.floor(row.age).." s ago; time unknown).")
            end
        end
    end
    if same>8 then N.Main.say("ChehulNet: and "..(same-8).." more.") end
    if same==0 then N.Main.say("ChehulNet: nobody has reported your zone-layer yet.") end
end
N.Sources.register{name="chehulnet",prefixes={"ChehulNet"},counters=Ch.stats,onAddon=receive,
    tick=function() Ch.sweep(session,N.Adapters.wall()) end}

