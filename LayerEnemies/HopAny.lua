-- One explicit click owns one bounded zone search. Pure state; Main owns the API calls.
-- LayerSwap wire compatibility only: no donor implementation or libraries copied.
local _,N=...
local H,S,I,L={},N.Safe,N.Invite,N.Layer
N.HopAny=H
H.CAP,H.PACE,H.CLICK,H.WHO,H.REPLY=8,1,10,5,120
H.ROWS,H.ROUNDS=49,45
H.SKIP,H.MAX_SKIP,H.FAILED=21600,300,600
H.FALLBACK,H.FALLBACK_LATE=3,10
function H.new() return {quiet={},failures={},book={},round=nil,lastClick=nil} end
function H.check(st,c)
    if c.guildOnly then return false,"guild-only mode: this asks players outside your guild." end
    if c.grouped then return false,"leave your current group first; group state must be readable." end
    if c.instance~=false then return false,"not available in an instance or with instance state unreadable." end
    if not c.zone or not c.zoneName or c.zone~=c.own.zone then return false,"your live zone is not known." end
    if not L.key(c.own.server) or c.own.ambiguous then return false,I.HINT.." An ambiguous key cannot be used." end
    if not c.self then return false,"your own name is not readable." end
    if st.round and st.round.phase=="who" then return false,"a who search is still outstanding." end
    if st.round or c.asking then return false,"an ask or hop is still open; stop it or wait for it to end." end
    if st.lastClick and c.now-st.lastClick<H.CLICK then return false,"wait 10 s between hop-any clicks." end
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
    st.round={phase="who",at=c.now,zone=c.zone,zoneName=c.zoneName,from=L.key(c.own.server),line=c.line,asked={},answered={},replies={},anyTried={},offline={},negatives={},count=0,sent=0,negative=0}
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
        for key,at in pairs(r.offline or {}) do st.quiet[key]=at end
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
    if r.phase~="who" and time-(r.firstSend or r.at)>H.REPLY then
        local note=r.invited and ("an invite arrived from "..r.invited.."; this search has ended.")
            or r.host and (r.host.." answered as a host but sent no invite within 120 s.")
            or ("asked "..r.sent.." players, no host answered. Click again to ask others.")
        if r.negative>0 then note=note.." "..r.negative.." said same layer or not hosting." end
        H.close(st,time); return note
    end
end
-- Priority is a session/book hint, not proof of a layer, and never adds a name absent from WHO.
function H.hosts(lists,st,time,wall)
    local out={}
    for _,raw in pairs(lists or {}) do
        if S.tab(raw) then
            local scanned=0
            pcall(function()
                for name,v in pairs(raw) do
                    scanned=scanned+1; if scanned>I.MAX_SCAN then break end
                    local ok,key,host,gone=pcall(function()
                        if not S.tab(v) then return nil end
                        local at=S.num(v.gone)
                        return I.key(name),S.clean(v.host)==true,S.secret(v.gone) or (at and wall and wall-at<H.FAILED)
                    end)
                    if ok and key then out[#out+1]={short=key,host=host,gone=gone} end
                end
            end)
        end
    end
    for key,v in pairs(st and st.book or {}) do
        if time-v.at>=N.Hosts.KEEP then st.book[key]=nil
        else out[#out+1]={short=key,host=v.host} end
    end
    return out
end
-- Only selected names are held; WHO is not a host directory. Whole-name keys use Invite's existing rule.
function H.candidates(st,rows,c)
    H.prune(st,c.now)
    local ranks,known,gone,seen,out={},{},{},{},{}
    for _,v in ipairs(c.hosts or {}) do
        known[v.short]=true
        if v.gone then gone[v.short]=true end
        if v.host then ranks[v.short]=1 end
    end
    for i,row in ipairs(rows or {}) do
        if i>H.ROWS then break end
        local name,key,target=I.name(row.fullName)
        local at=key and c.invite.asked[key]
        if name and key~=c.self and not gone[key] and not seen[key] and (known[key] or not st.quiet[key])
            and not (at and c.now-at<I.NAME_COOLDOWN) and not c.ignored(target) and not c.offline(target,c.now,known[key] and H.FAILED or nil) then
            seen[key]=true
            out[#out+1]={name=target,short=key,known=known[key],rank=ranks[key] or (row.area==c.zoneName and 2 or 3),index=i}
        end
    end
    table.sort(out,function(a,b) return a.rank<b.rank or (a.rank==b.rank and a.index<b.index) end)
    return out
end
function H.who(st,rows,c)
    local r=st.round
    if not r or r.phase~="who" or c.now<r.at or c.now-r.at>=H.WHO then return false end
    r.names=H.candidates(st,rows,c); r.index=1; r.phase="send"
    if #r.names==0 then H.close(st,c.now); return false,"nobody new to ask in this zone." end
    return true
end
function H.isFailed(st,key,time)
    local at=st.failures[key]
    return at and time-at<H.FAILED
end
function H.failed(st,name,time)
    local key=I.key(name); if not key then return end
    for k,at in pairs(st.failures) do if time-at>=H.FAILED then st.failures[k]=nil end end
    if not st.failures[key] and S.count(st.failures)>=H.MAX_SKIP then
        local oldest,stamp
        for k,at in pairs(st.failures) do if not stamp or at<stamp then oldest,stamp=k,at end end
        st.failures[oldest]=nil
    end
    st.failures[key]=time
end
-- Two checks after the queue, at +3/+10. The second also catches late replies; each responder gets one try.
function H.fallback(st,time)
    local r=st.round
    if not r.doneAt or r.invited or time<r.doneAt then return nil end
    local age=time-r.doneAt
    local stage=age>=H.FALLBACK_LATE and 2 or age>=H.FALLBACK and 1 or 0
    if stage==0 or (r.fallbackStage or 0)>=stage then return nil end
    if not r.anyAt or time-r.anyAt>=H.PACE then r.anyAt=time; r.anyUsed=0 end
    if time<r.anyAt or r.anyUsed>=H.CAP then return nil end
    if stage==1 then
        for _,reply in pairs(r.replies) do
            if reply.kind=="heard" and reply.hosting and reply.zone==r.zone and reply.layer and not L.same(reply.layer,r.from) then
                r.fallbackStage=1; return nil
            end
        end
    end
    for _,c in ipairs(r.names or {}) do
        local reply=r.replies[c.short]
        if reply and reply.kind=="heard" and reply.hosting and not reply.layer and reply.zone==r.zone
            and not r.anyTried[c.short] and not H.isFailed(st,c.short,time) then
            r.anyTried[c.short]=true; r.anyUsed=r.anyUsed+1; r.sending=true
            return {name=c.name,short=c.short,known=true,fallback=true,line=(r.line:gsub(" not %d+%-%d+",""))}
        end
    end
    r.fallbackStage=stage
end
-- Reserve before calling out: a reentrant pump must see the spent slot and pace.
function H.next(st,time)
    local r=st.round
    if not r or r.sending then return nil end
    if r.phase=="wait" then return H.fallback(st,time) end
    if r.phase~="send" then return nil end
    if not r.roundAt or time-r.roundAt>=H.PACE then
        if (r.rounds or 0)>=H.ROUNDS then r.phase="wait"; r.doneAt=time; return nil end
        r.rounds=(r.rounds or 0)+1; r.roundAt=time; r.used=0
    end
    if time<r.roundAt or r.used>=H.CAP then return nil end
    local c=r.names[r.index]
    if not c then return nil end
    r.used=r.used+1; r.count=r.count+1; r.index=r.index+1; r.lastAttempt=time; r.sending=true
    return c
end
local function asked(st,name,time)
    local r=st.round
    if not r or time<r.at or time-(r.firstSend or r.at)>H.REPLY then return nil end
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
    r.answered[key]=true; r.replies[key]=reply; st.quiet[key]=nil
    if not st.book[key] and S.count(st.book)>=H.MAX_SKIP then
        local oldest,stamp
        for k,v in pairs(st.book) do if not stamp or v.at<stamp then oldest,stamp=k,v.at end end
        st.book[oldest]=nil
    end
    st.book[key]={host=reply.kind=="same" or reply.hosting,at=time}
    if host then
        local first=not r.host
        if first then r.host=r.asked[key].name end
        return reply,r.asked[key].name,first and (r.host.." heard you and is hosting; waiting for an invite.") or nil
    end
    if reply.kind=="heard" then return reply,r.asked[key].name end
end
function H.invite(st,name,time)
    local r=st.round
    local _,key,target=I.name(name)
    if not r or not key or H.isFailed(st,key,time) then return false end
    if r.asked[key] then r.answered[key]=true; st.quiet[key]=nil end
    r.phase="wait"; r.invited=target
    return true
end
function H.sent(st,c,time,ok,why)
    local r=st.round
    r.sending=nil
    if c.fallback then
        -- One fallback attempt per responder, including a refusal; never return it to the head.
        return
    end
    if ok then
        if not r.firstSend then r.firstSend=time; st.lastClick=time end
        r.sent=r.sent+1; r.lastSend=time; r.asked[c.short]={name=c.name,at=time}
    elseif why=="offline" then r.offline[c.short]=time
    elseif why=="throttled" or why=="paused" then
        r.index=r.index-1; r.used=H.CAP -- leave this exact head for the next round
    elseif why~="offline" and why~="ignored" then
        H.close(st,time); return "search stopped: whisper "..tostring(why).."; no retry. A late invite may still arrive."
    end
    if r.index>#r.names or (r.rounds>=H.ROUNDS and r.used>=H.CAP) then r.phase="wait"; r.doneAt=time end
end
