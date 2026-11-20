-- Session-only trust. Pure: all clocks, observations and client facts are inputs.
local _,N=...
local T,L={},N.Layer
N.Trust=T
-- Architect's guesses, not game-verified thresholds.
T.EXPIRE,T.COLD_FAILURES,T.FAILURE_STREAK=300,20,10
T.CHANGES,T.CHANGE_WINDOW,T.EXCUSE_WINDOW=3,600,10
T.HOPS,T.GROUP_SECONDS=3,60
T.NOTICE_EVERY=10
function T.new() return {seen=0,success=false,failures=0,changes={},hops={}} end
local function state(s) s.trust=s.trust or T.new(); return s.trust end
function T.state(s,now)
    if not s then return "unknown" end
    local t=state(s)
    if t.blind then return "blind" end
    if L.key(s.bulo) and t.at and now and now>=t.at and now-t.at<T.EXPIRE then return "known" end
    return "unknown"
end
-- Local feedback only; the caller prints it. Manual controls have their own line.
function T.notice(s,now,manual)
    s.trustNotice=s.trustNotice or {}; local n=s.trustNotice
    local current,old=T.state(s,now),n.state; n.state=current
    if manual then n.pending=nil; n.hidden=current~="known"; return end
    if current~=old then
        n.pending=nil
        if current=="blind" and state(s).blind~="manual" then
            n.pending="LayerEnemies: layer IDs look unreliable ("..state(s).blind.."); layers hidden for this session. /le blind off to override."
        elseif current=="known" and n.hidden then n.pending="LayerEnemies: layer IDs readable again; layers shown." end
        n.hidden=current=="blind" or (current=="unknown" and (old=="known" or n.hidden))
    end
    if n.pending and (not n.at or (now>=n.at and now-n.at>=T.NOTICE_EVERY)) then
        local text=n.pending; n.pending=nil; n.at=now; return text
    end
end
-- The only current-own-key reader. Second result is the confirmed NPC zoneUID.
function T.own(s,now)
    if T.state(s,now)=="known" then
        local uid=N.Safe.num(s.zoneUID) or tonumber(N.Safe.str(s.zoneUID,32))
        return s.bulo,uid and uid>0 and uid%1==0 and uid or nil
    end
end
function T.read(s,now,id,uid)
    local t=state(s)
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
function T.bulo(snap,blocked,npcs)
    local id=snap.current
    if id==blocked and (not npcs.current or npcs.raw~=id) then return nil end
    return L.bulo(id) and id or nil
end
-- Dispatch-time projection of our own WE bytes; preserve every other field.
function T.we(s,text,now,own)
    if not own or T.own(s,now) then return text end
    local prefix,inner=text:match("^(W|[^|]*|[^|]*|)(.*)$")
    inner=inner or text
    inner=inner:gsub("^(C|[^|]*|[^|]*|[^|]*|[^|]*|)[^|]*", "%10")
    inner=inner:gsub("^(H|[^|]*|[^|]*|)[^|]*", "%10")
    return (prefix or "")..inner
end
-- Mask received claims for consumers without changing a remote relay payload.
function T.record(s,record,now,hide)
    if not hide and T.state(s,now)~="blind" then return record end
    local out={}; for k,v in pairs(record) do out[k]=v end
    out.layer={ns="unknown"}; return out
end
function T.manual(s,mode)
    if mode=="on" then state(s).blind="manual"
    elseif mode=="off" or mode=="auto" then
        local at=state(s).at; s.trust=T.new(); s.trust.at=at
    else return false end
    return true
end
function T.creature(s,parsed)
    local t=state(s)
    t.seen=math.min(t.seen+1,T.COLD_FAILURES)
    if parsed then t.success=true; t.failures=0
    else t.failures=math.min(t.failures+1,T.FAILURE_STREAK) end
    if (not t.success and t.seen>=T.COLD_FAILURES) or (t.success and t.failures>=T.FAILURE_STREAK) then t.blind="parse failures" end
end
function T.excuse(s,now) state(s).excusedAt=now end
function T.change(s,now,key,source)
    local t=state(s)
    if key and key==t.changeKey and source~=t.changeSource and t.changeAt and now>=t.changeAt
        and now-t.changeAt<=T.EXCUSE_WINDOW then return false end
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
function T.group(s,now,peer,claim,outdoors,joinedAt,claimAt)
    local t=state(s)
    local own=L.key(T.own(s,now)); claim=L.key(claim)
    if not T.fresh(s,now,joinedAt) or not claimAt or claimAt<=joinedAt or claimAt>now
        or now-claimAt>=T.EXPIRE then t.group=nil; return end
    if not outdoors or not peer or not own or not claim or own==claim then t.group=nil; return end
    local g=t.group
    if not g or g.peer~=peer or g.own~=own or g.claim~=claim or now<g.at then
        g={peer=peer,own=own,claim=claim,at=now}; t.group=g
    end
    if now-g.at>=T.GROUP_SECONDS then t.blind="group contradiction" end
end
