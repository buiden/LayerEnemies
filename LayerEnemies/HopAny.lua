-- One explicit click owns one bounded zone search. Pure state; Main owns the API calls.
-- LayerSwap wire compatibility only: no donor implementation or libraries copied.
local _,N=...
local H,S,I,L={},N.Safe,N.Invite,N.Layer
N.HopAny=H
H.CAP,H.PACE,H.CLICK,H.WHO,H.REPLY=8,1,30,5,120
H.SKIP,H.MAX_SKIP=21600,300
function H.new() return {quiet={},round=nil,lastClick=nil} end
function H.check(st,c)
    if c.guildOnly then return false,"guild-only mode: this asks players outside your guild." end
    if c.grouped then return false,"leave your current group first; group state must be readable." end
    if c.instance~=false then return false,"not available in an instance or with instance state unreadable." end
    if c.combat then return false,"not available in combat or with combat state unreadable." end
    if not c.zone or not c.zoneName or c.zone~=c.own.zone then return false,"your live zone is not known." end
    if not L.key(c.own.server) or c.own.ambiguous then return false,I.HINT.." An ambiguous key cannot be used." end
    if not c.self then return false,"your own name is not readable." end
    if st.round and st.round.phase=="who" then return false,"a who search is still outstanding." end
    if st.round or c.asking then return false,"an ask or hop is still open; stop it or wait for it to end." end
    if st.lastClick and c.now-st.lastClick<H.CLICK then return false,"wait 30 s between hop-any clicks." end
    if not c.line then return false,"your map position is not readable; the request could not be built." end
    if not c.term then return false,"the localized who search is not available on this client." end
    if c.invite.lastAsk and c.now-c.invite.lastAsk<I.GLOBAL_COOLDOWN then return false,"one ask every 10 s." end
    return true
end
function H.begin(st,c)
    local ok,why=H.check(st,c); if not ok then return false,why end
    -- Reserve the shared overall cooldown once, not once per stranger. Real names are stamped at each send.
    local mark={name="hop to another layer",short="#hop-any"}
    ok,why=I.reserve(c.invite,mark,c.now)
    if not ok then return false,why end
    c.invite.asked[mark.short]=nil
    st.lastClick=c.now
    st.round={phase="who",at=c.now,zone=c.zone,zoneName=c.zoneName,from=L.key(c.own.server),line=c.line,asked={},answered={},negatives={},count=0,sent=0,negative=0}
    return true
end
function H.prune(st,time)
    for key,at in pairs(st.quiet) do if time-at>=H.SKIP then st.quiet[key]=nil end end
end
function H.close(st,time)
    local r=st.round
    if r and time then
        H.prune(st,time)
        for key,p in pairs(r.asked) do if not r.answered[key] then st.quiet[key]=p.at end end
        while S.count(st.quiet)>H.MAX_SKIP do
            local oldest,stamp
            for key,at in pairs(st.quiet) do
                if not stamp or at<stamp or (at==stamp and key<oldest) then oldest,stamp=key,at end
            end
            st.quiet[oldest]=nil
        end
    end
    st.round=nil
end
function H.expire(st,time)
    local r=st.round
    if not r then return end
    if time<r.at or (r.phase=="who" and time-r.at>=H.WHO) then
        H.close(st,time); return "the game did not answer the search."
    end
    if r.phase~="who" and time-(r.lastSend or r.at)>H.REPLY then
        local note=r.invited and ("an invite arrived from "..r.invited.."; this search has ended.")
            or r.host and (r.host.." answered as a host but sent no invite within 120 s.")
            or ("asked "..r.sent.." players, no host answered. Click again to ask others.")
        if r.negative>0 then note=note.." "..r.negative.." said same layer or not hosting." end
        H.close(st,time); return note
    end
end
-- Only selected names are held; WHO is not a host directory. Whole-name keys use Invite's existing rule.
function H.candidates(st,rows,c)
    H.prune(st,c.now)
    local ranks,seen,out={},{},{}
    for _,v in ipairs(c.hosts or {}) do
        if v.host and v.layer and not L.same(v.layer,c.own.server) then ranks[v.short]=1 end
    end
    for i,row in ipairs(rows or {}) do
        local name,key,target=I.name(row.fullName)
        local at=key and c.invite.asked[key]
        if name and row.area==c.zoneName and key~=c.self and not seen[key] and not st.quiet[key]
            and not (at and c.now-at<I.NAME_COOLDOWN) and not c.ignored(target) and not c.offline(target,c.now) then
            seen[key]=true
            out[#out+1]={name=target,short=key,rank=ranks[key] or (c.guild(target)==true and 2 or 3),index=i}
        end
    end
    table.sort(out,function(a,b) return a.rank<b.rank or (a.rank==b.rank and a.index<b.index) end)
    for i=#out,H.CAP+1,-1 do out[i]=nil end
    return out
end
function H.who(st,rows,c)
    local r=st.round
    if not r or r.phase~="who" or c.now<r.at or c.now-r.at>=H.WHO then return false end
    r.names=H.candidates(st,rows,c); r.index=1; r.phase="send"
    if #r.names==0 then H.close(st,c.now); return false,"nobody new to ask in this zone." end
    return true
end
-- Reserve before calling out: a reentrant pump must see the spent slot and pace.
function H.next(st,time)
    local r=st.round
    if not r or r.sending or r.phase~="send" or r.count>=H.CAP or (r.lastAttempt and time-r.lastAttempt<H.PACE) then return nil end
    local c=r.names[r.index]
    if not c then return nil end
    r.count=r.count+1; r.index=r.index+1; r.lastAttempt=time; r.sending=true
    return c
end
local function asked(st,name,time)
    local r=st.round
    if not r or time<r.at or time-(r.lastSend or r.at)>H.REPLY then return nil end
    local key=I.key(name)
    if not key or not r.asked[key] then return nil end
    return r,key
end
function H.receive(st,text,name,me,time)
    local r,key=asked(st,name,time)
    if not r then return nil end
    local reply=N.Hop.reply(text,name,me)
    if not reply then return nil end
    local host=reply.kind=="heard" and reply.hosting and reply.zone==r.zone
        and L.key(reply.layer) and not L.same(reply.layer,r.from)
    -- Same-layer / not-hosting replies are summarized once per name, never one chat line per answer.
    if not r.negatives[key] and (reply.kind=="same" or not reply.hosting) then
        r.negatives[key]=true; r.negative=r.negative+1
    end
    r.answered[key]=true; st.quiet[key]=nil
    if host then
        local first=not r.host
        if first then r.host=r.asked[key].name end
        r.phase="wait"
        return reply,r.asked[key].name,first and (r.host.." heard you and is hosting; waiting for an invite.") or nil
    end
    if reply.kind=="heard" and not reply.hosting then return reply,r.asked[key].name end
end
function H.invite(st,name,time)
    local r,key=asked(st,name,time)
    if not r then return false end
    r.answered[key]=true; st.quiet[key]=nil; r.phase="wait"; r.invited=r.asked[key].name
    return true
end
function H.sent(st,c,time,ok,why)
    local r=st.round
    r.sending=nil
    if ok then
        r.sent=r.sent+1; r.lastSend=time; r.asked[c.short]={name=c.name,at=time}
    elseif why~="offline" then
        H.close(st,time); return "search stopped: whisper "..tostring(why).."; no retry. A late invite may still arrive."
    end
    if r.count>=H.CAP or r.index>#r.names then r.phase="wait" end
end
