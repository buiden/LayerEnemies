-- Session-only trust. Pure: all clocks, observations and client facts are inputs.
local _,N=...
local T,L={},N.Layer
N.Trust=T
-- Architect's guesses, not game-verified thresholds.
T.EXPIRE,T.COLD_FAILURES,T.FAILURE_STREAK=300,20,10
T.CHANGES,T.CHANGE_WINDOW,T.EXCUSE_WINDOW=3,600,10
T.HOPS,T.GROUP_SECONDS=3,60
T.NOTICE_EVERY=10
T.HIDDEN_ID_BUILD=71037
T.HIDDEN_ID_REASON="this game build hides layer IDs"
function T.new(build)
    local hidden=N.Safe.num(build) and build>=T.HIDDEN_ID_BUILD or false
    return {seen=0,success=false,failures=0,changes={},hops={},hiddenIDs=hidden,
        blind=hidden and T.HIDDEN_ID_REASON or nil}
end
local function state(s) s.trust=s.trust or T.new(); return s.trust end
function T.hidden(s) return s and state(s).hiddenIDs==true or false end
function T.state(s,now)
    if not s then return "unknown" end
    local t=state(s)
    if t.hiddenIDs then return t.token and t.token.zone==s.zone and "known" or "blind" end
    if t.blind then return "blind" end
    if L.key(s.bulo) and t.at and now and now>=t.at and now-t.at<T.EXPIRE then return "known" end
    return "unknown"
end
-- Local feedback only; the caller prints it. Manual controls have their own line.
function T.notice(s,now,manual)
    s.trustNotice=s.trustNotice or {}; local n=s.trustNotice
    local current,old=T.state(s,now),n.state; n.state=current
    if manual then n.pending=nil; n.autoBlind=nil; return end
    if current~=old then
        n.pending=nil
        if current=="blind" and state(s).blind~="manual" then
            n.pending="LayerEnemies: layer IDs look unreliable ("..(state(s).blind or T.HIDDEN_ID_REASON).."); layers hidden for this session. /le blind off to override."
            if T.hidden(s) then n.pending="LayerEnemies: "..T.HIDDEN_ID_REASON.."; layers hidden for this session." end
        elseif current=="known" and n.autoBlind then
            n.pending=T.hidden(s) and ("LayerEnemies: "..T.label(s,now)) or "LayerEnemies: layer IDs readable again; layers shown."
        end
    end
    if n.pending and (not n.at or (now>=n.at and now-n.at>=T.NOTICE_EVERY)) then
        local text=n.pending; n.pending=nil; n.at=now; n.autoBlind=current=="blind"; return text
    end
end
-- The only current-own-key reader. Second result is the confirmed NPC zoneUID.
function T.own(s,now)
    if T.state(s,now)=="known" then
        if T.hidden(s) then return state(s).token.id,nil end
        local uid=N.Safe.num(s.zoneUID) or tonumber(N.Safe.str(s.zoneUID,32))
        return s.bulo,uid and uid>0 and uid%1==0 and uid or nil
    end
end
-- Hidden tokens are equality evidence from an observed host interaction only.
-- Numeric consumers never receive a hidden equality token.
function T.numeric(s,now)
    if T.hidden(s) then return nil end
    return T.own(s,now)
end
function T.masked(s,now) return T.hidden(s) or T.state(s,now)=="blind" end
function T.label(s,now)
    local token=T.hidden(s) and T.state(s,now)=="known" and state(s).token
    return token and ("layer: shared with "..token.host) or "layer hidden"
end
function T.adopt(s,now,id,zone,source,host)
    local S=N.Safe
    if not T.hidden(s) or not S.num(now) or not S.num(zone) or zone~=s.zone then return false end
    id=S.str(id,32); host=S.str(host,100); source=S.str(source,8)
    if not id or not id:match("^%d+%-%d+$") or not L.key(id) or not host
        or (source~="host" and source~="peer") then return false end
    local t=state(s); local previous=t.token and t.token.id
    if source=="host" and id==previous then return false end
    -- An alias is equivalent only after a no-move peer join, never a transfer.
    local alias
    if source=="peer" then alias=previous~=id and previous or t.token and t.token.alias end
    t.token={id=id,zone=zone,at=now,source=source,host=host,alias=alias}
    s.bulo,s.zoneUID=id,nil; t.blind=nil
    return true
end
function T.drop(s,why)
    if not T.hidden(s) then return end
    local t=state(s); t.token=nil; t.blind=T.HIDDEN_ID_REASON
    s.bulo,s.zoneUID=nil,nil
end
function T.save(s,wall,who)
    local t=state(s).token
    if T.hidden(s) and t and t.zone==s.zone and N.Safe.num(wall) and N.Safe.str(who,100) then
        return {id=t.id,zone=t.zone,who=who,at=wall,alias=t.alias}
    end
end
function T.restore(s,saved,wall,who,reload)
    T.drop(s,"world entry")
    local S=N.Safe
    if reload~=true or not S.tab(saved) or not S.num(wall) or not S.str(who,100) then return false end
    local ok,result=pcall(function()
        local at=S.num(saved.at)
        if not at or wall<at or wall-at>120 or S.str(saved.who,100)~=who then return false end
        if not T.adopt(s,wall,saved.id,saved.zone,"peer","previous host") then return false end
        local alias=S.str(saved.alias,32)
        if alias and alias:match("^%d+%-%d+$") and L.key(alias) then state(s).token.alias=alias end
        return true
    end)
    return ok and result==true
end
-- Estimated game pacing, per character; bounded to ten move timestamps.
T.MOVE_CAP,T.HOUR,T.REFUSAL_HOLD=10,3600,900
function T.paceLoad(saved,who,wall)
    local S=N.Safe
    local p={who=S.str(who,100),moves={}}
    if not S.tab(saved) or not p.who then return p end
    local ok,valid=pcall(function()
        if S.str(saved.who,100)~=p.who then return true end
        if saved.start~=nil and not S.num(saved.start) then return false end
        if saved.hold~=nil and not S.num(saved.hold) then return false end
        if not S.tab(saved.moves) then return false end
        p.start=S.num(saved.start); p.hold=S.num(saved.hold)
        for i=1,T.MOVE_CAP do
            local value=saved.moves[i]
            if value==nil then break end
            local at=S.num(value)
            if not at or not p.start or at<p.start then return false end
            p.moves[#p.moves+1]=at
        end
        return true
    end)
    if not ok or not valid then
        p.moves={}; p.start=nil
        p.hold=S.num(wall) and wall+T.REFUSAL_HOLD or nil
    end
    return p
end
function T.paceWait(p,wall)
    if not p or not p.who or not N.Safe.num(wall) then return T.REFUSAL_HOLD end
    if p.start and wall<p.start then return T.REFUSAL_HOLD end
    for _,at in ipairs(p.moves) do if wall<at then return T.REFUSAL_HOLD end end
    if p.start and wall-p.start>=T.HOUR then
        p.start=nil
        p.moves={}
    end
    local wait=p.hold and math.max(0,p.hold-wall) or 0
    if #p.moves>=T.MOVE_CAP and p.start then wait=math.max(wait,p.start+T.HOUR-wall) end
    return wait
end
function T.paceMove(p,wall)
    if T.paceWait(p,wall)>0 then return false end
    p.start=p.start or wall; p.moves[#p.moves+1]=wall
    return true
end
function T.paceRefused(p,wall)
    T.paceWait(p,wall)
    if p and N.Safe.num(wall) and #p.moves<T.MOVE_CAP then p.hold=wall+T.REFUSAL_HOLD end
end
function T.read(s,now,id,uid)
    local t=state(s)
    if T.hidden(s) then return end
    s.bulo=L.key(id) and id or nil; s.zoneUID=uid
    t.at=s.bulo and now or nil
end
-- Only a live NPC read matching the confirmed current own key is evidence.
function T.npc(s,now,id)
    if id and id==T.own(s,now) then local t=state(s); t.npcAt,t.npcKey=now,id end
end
function T.fresh(s,now,joinedAt)
    local t=state(s)
    return joinedAt~=nil and t.npcAt~=nil and t.npcAt>joinedAt and now>=t.npcAt
        and now-t.npcAt<T.EXPIRE and t.npcKey==T.own(s,now)
end
-- Bulo's source value is admitted here, never by a display or comparison reader.
function T.bulo(snap,blocked,npcs,s)
    if T.hidden(s) then return nil end
    local id=snap.current
    if id==blocked and (not npcs.current or npcs.raw~=id) then return nil end
    return L.bulo(id) and id or nil
end
-- Dispatch-time projection of our own WE bytes; preserve every other field.
function T.we(s,text,now,own)
    if not own then return text end
    local prefix,inner=text:match("^(W|[^|]*|[^|]*|)(.*)$")
    inner=inner or text
    local key=L.key(T.numeric(s,now))
    local queued=inner:match("^C|[^|]*|[^|]*|[^|]*|[^|]*|([^|]*)") or inner:match("^H|[^|]*|[^|]*|([^|]*)")
    if key and key==L.key(queued) then return text end
    inner=inner:gsub("^(C|[^|]*|[^|]*|[^|]*|[^|]*|)[^|]*", "%10")
    inner=inner:gsub("^(H|[^|]*|[^|]*|)[^|]*", "%10")
    return (prefix or "")..inner
end
-- Mask received claims for consumers without changing a remote relay payload.
function T.record(s,record,now,hide)
    if not hide and not T.masked(s,now) then return record end
    local out={}; for k,v in pairs(record) do out[k]=v end
    out.layer={ns="unknown"}; return out
end
function T.manual(s,mode)
    if T.hidden(s) then return mode=="on" or mode=="off" or mode=="auto" end
    if mode=="on" then state(s).blind="manual"
    elseif mode=="off" or mode=="auto" then
        local at=state(s).at; s.trust=T.new(); s.trust.at=at
    else return false end
    return true
end
function T.creature(s,parsed)
    if T.hidden(s) then return end
    local t=state(s)
    t.seen=math.min(t.seen+1,T.COLD_FAILURES)
    if parsed then t.success=true; t.failures=0
    else t.failures=math.min(t.failures+1,T.FAILURE_STREAK) end
    if (not t.success and t.seen>=T.COLD_FAILURES) or (t.success and t.failures>=T.FAILURE_STREAK) then t.blind="parse failures" end
end
function T.excuse(s,now) state(s).excusedAt=now end
function T.change(s,now,key,source)
    if T.hidden(s) then return false end
    local t=state(s)
    if key and key==t.changeKey and t.changeAt and now>=t.changeAt then return false end
    t.changeKey,t.changeSource,t.changeAt=key,source,now
    if t.excusedAt and now>=t.excusedAt and now-t.excusedAt<=T.EXCUSE_WINDOW then return true end
    for i=#t.changes,1,-1 do
        if now<t.changes[i] or now-t.changes[i]>=T.CHANGE_WINDOW then table.remove(t.changes,i) end
    end
    if #t.changes>=T.CHANGES then table.remove(t.changes,1) end
    t.changes[#t.changes+1]=now
    if #t.changes>=T.CHANGES then t.blind="key churn" end
    return true
end
function T.hop(s,host,before,after,formed,now,joinedAt)
    local t=state(s)
    if not T.fresh(s,now,joinedAt) then t.hops={}; return end
    local valid=L.key(before) and L.key(after)
    if not formed or not host or not valid or before~=after then t.hops={}; return end
    if #t.hops>=T.HOPS then table.remove(t.hops,1) end
    t.hops[#t.hops+1]=host
    local names={}; for _,name in ipairs(t.hops) do if names[name] then return end; names[name]=true end
    if #t.hops>=T.HOPS then t.blind="hop contradiction" end
end
function T.group(s,now,peer,claim,outdoors,joinedAt,claimAt,peerJoinedAt)
    local t=state(s)
    local own=L.key(T.own(s,now)); claim=L.key(claim)
    if not T.fresh(s,now,joinedAt) or not claimAt or claimAt<=joinedAt or claimAt>now
        or now-claimAt>=T.EXPIRE or not peerJoinedAt or claimAt<=peerJoinedAt then t.group=nil; return end
    if not outdoors or not peer or not own or not claim or own==claim then t.group=nil; return end
    local g=t.group
    if not g or g.peer~=peer or g.own~=own or g.claim~=claim or now<g.at then
        g={peer=peer,own=own,claim=claim,at=now}; t.group=g
    end
    if now-g.at>=T.GROUP_SECONDS then t.blind="group contradiction" end
end
