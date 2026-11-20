-- Session-only trust. Pure: all clocks, observations and client facts are inputs.
local _,N=...
local T,L={},N.Layer
N.Trust=T
-- Architect's guesses, not game-verified thresholds.
T.EXPIRE,T.COLD_FAILURES,T.FAILURE_STREAK=300,20,10
T.CHANGES,T.CHANGE_WINDOW,T.EXCUSE_WINDOW=3,600,10
T.HOPS,T.GROUP_SECONDS=3,60
function T.new() return {seen=0,success=false,failures=0,changes={},hops={}} end
local function state(s) s.trust=s.trust or T.new(); return s.trust end
function T.state(s,now)
    if not s then return "unknown" end
    local t=state(s)
    if t.blind then return "blind" end
    if L.key(s.bulo) and t.at and now and now>=t.at and now-t.at<T.EXPIRE then return "known" end
    return "unknown"
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
-- Bulo's source value is admitted here, never by a display or comparison reader.
function T.bulo(snap,blocked,npcs)
    local id=snap.current
    if id==blocked and (not npcs.current or npcs.raw~=id) then return nil end
    return L.bulo(id) and id or nil
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
function T.change(s,now)
    local t=state(s)
    if t.excusedAt and now>=t.excusedAt and now-t.excusedAt<=T.EXCUSE_WINDOW then return end
    for i=#t.changes,1,-1 do
        if now<t.changes[i] or now-t.changes[i]>=T.CHANGE_WINDOW then table.remove(t.changes,i) end
    end
    if #t.changes>=T.CHANGES then table.remove(t.changes,1) end
    t.changes[#t.changes+1]=now
    if #t.changes>=T.CHANGES then t.blind="key churn" end
end
function T.hop(s,host,before,after,formed)
    local t=state(s)
    local valid=L.key(before) and L.key(after)
    if not formed or not host or not valid or before~=after then t.hops={}; return end
    if #t.hops>=T.HOPS then table.remove(t.hops,1) end
    t.hops[#t.hops+1]=host
    local names={}; for _,name in ipairs(t.hops) do if names[name] then return end; names[name]=true end
    if #t.hops>=T.HOPS then t.blind="hop contradiction" end
end
function T.group(s,now,peer,claim,outdoors)
    local t=state(s)
    local own=L.key(T.own(s,now)); claim=L.key(claim)
    if not outdoors or not peer or not own or not claim or own==claim then t.group=nil; return end
    local g=t.group
    if not g or g.peer~=peer or g.own~=own or g.claim~=claim or now<g.at then
        g={peer=peer,own=own,claim=claim,at=now}; t.group=g
    end
    if now-g.at>=T.GROUP_SECONDS then t.blind="group contradiction" end
end
