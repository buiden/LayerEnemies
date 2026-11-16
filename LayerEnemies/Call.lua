-- Receive-only call admission. All event/history data is session-only.
local _,N=...
local C,S={},N.Safe
N.Call=C
C.MAX,C.AGE,C.VICTIM,C.GLOBAL,C.DEDUPE=64,120,180,20,60
function C.new() return {victims={}} end
function C.pick(age,random)
    random=random or math.random
    local T=N.CallText
    local bodies={}
    for _,id in ipairs(T.BODIES) do if id~="B4" or age<=30 then bodies[#bodies+1]=id end end
    return T.HEADINGS[random(#T.HEADINGS)],bodies[random(#bodies)]
end
local function key(name) local _,k=N.Invite.name(name); return k end
function C.known(store,name,time)
    local want=key(name)
    if not want then return false end
    for _,e in pairs(store.localSeen) do
        if e.faction=="opposite" and e.epoch==store.serial and S.num(e.at) and time>=e.at and time-e.at<600
            and key(e.displayName or e.name)==want then return true end
    end
    return false
end
local function prune(st,time)
    for k,v in pairs(st.victims) do
        if time<v.at or time-v.at>=C.VICTIM then st.victims[k]=nil end
    end
end
local function room(st)
    while S.count(st.victims)>=C.MAX do
        local oldest,at
        for k,v in pairs(st.victims) do if not at or v.at<at then oldest,at=k,v.at end end
        st.victims[oldest]=nil
    end
end
function C.receive(st,r,victim,time,ctx)
    -- Caller supplies readable own identity and instance status; nil is never permission.
    if not ctx.on or ctx.instance~=false or not ctx.me then return end
    if not S.tab(r) or r.kind~="death" or (r.src~="gb" and r.src~="wos") then return end
    local k=key(victim)
    if not k or k==ctx.me then return end
    local enemy=S.tab(r.enemies) and r.enemies[1]
    if not S.tab(enemy) or not key(enemy.name) or key(enemy.name)==ctx.me then return end
    if not ((r.src=="gb" and S.str(enemy.class,24)) or ctx.known) then return end
    local at=S.num(r.at) or S.num(r.heard)
    if not at or time<at or time-at>C.AGE then return end
    prune(st,time)
    local old=st.victims[k]
    -- One death, possibly two sources: keep the first time; enrich only the same killer/zone with position.
    if old and time-old.at<=C.DEDUPE then
        local e=old.event
        if e and not e.x and S.num(r.x) and S.num(r.y) and r.x>=0 and r.x<=1 and r.y>=0 and r.y<=1
            and e.zone==r.zone and key(e.killer)==key(enemy.name) then
            local copy={}; for field,value in pairs(e) do copy[field]=value end
            copy.x,copy.y,copy.class,copy.level=r.x,r.y,enemy.class or e.class,enemy.level or e.level
            old.event=copy
            if st.current==e then st.current=copy; return copy,"enrich" end
        end
        return
    end
    if old and time-old.at<C.VICTIM then return end
    if st.last and time-st.last<C.GLOBAL then return end
    if st.current and at<st.current.at then return end
    local x,y=S.num(r.x),S.num(r.y)
    if not x or not y or x<0 or x>1 or y<0 or y>1 then x,y=nil,nil end
    local e={victim=victim,key=k,killer=enemy.name,class=enemy.class,level=enemy.level,
        full=enemy.partial~=true and enemy.full~=false,zone=r.zone,x=x,y=y,at=at,source=r.src}
    room(st); st.victims[k]={at=time,event=e}; st.last=time; st.current=e
    return e,"show"
end
