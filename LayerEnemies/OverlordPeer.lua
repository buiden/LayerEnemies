-- Overlord 2.5.4 protocol facts only. Pure state machine: no client reads.
local _,N=...
local P,S,F={},N.Safe,N.Find
N.OverlordPeer=P
local flight
-- One source/recipient identity: shared Unicode fold, own realm stripped by
-- Invite. Raw fallback is only for already parsed wire names / rate keys.
function P.key(name)
    name=S.str(name,100);if not name then return nil end
    local _,_,target=N.Invite.name(name)
    return F.fold(target or name)
end
local function selfTarget(c,route,name)
    return (route=="WHISPER" or route=="BNET") and P.key(name)==P.key(c.me)
end
function P.new() return {routes={},gaps={},actual={},owed={},actualOwed={},serial=0,probe=0} end
local function ready(c,owed,stop)
    return (stop and c.stopAllowed==true or not stop and c.allowed==true) and (owed or c.own==true) and S.str(c.pool,16)
        and S.str(c.me,50) and S.str(c.version,32) and (c.faction=="A" or c.faction=="H")
        and S.num(c.now) and S.num(c.wall)
end
local function recent(list,now)
    local out={};for _,t in ipairs(list) do if now-t<60 then out[#out+1]=t end end;return out
end
local function due(last,now,gap) return not last or (now>=last and now-last>=gap) end
function P.presence(c) return "LayerEnemies "..c.version..(N.OverlordFeed and N.OverlordFeed.capability or "") end
function P.sweep(st,now)
    for k,r in pairs(st.routes) do if now<r.at or now-r.at>=300 then st.routes[k]=nil end end
    for k,t in pairs(st.gaps) do if now>=t and now-t>=3600 then st.gaps[k]=nil end end
    for k,t in pairs(st.actual) do if now>=t and now-t>=3600 then st.actual[k]=nil end end
end
function P.dispatching(text,route,target)
    return flight and flight.text==text and flight.route==route and flight.target==target or false
end
-- Check without spending before Wire admission; charge only a client attempt.
-- Battle.net charges at dispatch, including failures.
-- Queued Battle.net frames cannot burst across a new admission window.
function P.claim(st,job,c,checkOnly)
    if not ready(c,job.owed,job.stop) or c.pool~=job.pool or c.me~=job.me then return false end
    if selfTarget(c,job.route,job.name) then return false end
    if job.kind=="NH" and st.feed then N.OverlordFeed.prepare(st.feed,st,c) end
    if job.kind=="NH" and N.OverlordFeed and N.OverlordFeed.suppressed(st,c,job.route,job.name,job.id) then return false end
    if job.valid and not job.valid(c) then return false end
    if not due(st.actual[job.key],c.now,job.gap) then return false end
    st.actualOwed=recent(st.actualOwed,c.now)
    if job.owed and #st.actualOwed>=6 then return false end
    if checkOnly then return true end
    st.actual[job.key]=c.now
    if job.owed then st.actualOwed[#st.actualOwed+1]=c.now end
    return true
end
function P.sent(st,job,c)
    if not ready(c,job.owed,job.stop) or c.pool~=job.pool or c.me~=job.me then return end
    if job.kind=="NH" then
        if not st.announced or st.announced.pool~=c.pool or st.announced.me~=c.me then
            st.announced={pool=c.pool,me=c.me,names={},accounts={}}
        end
        local a=st.announced
        local function stamp(map,key,cap)
            for k,t in pairs(map) do if c.now>=t and c.now-t>300 then map[k]=nil end end
            if key then
                if map[key] or S.count(map)<cap then map[key]=c.now else a.unknown=c.now end
            end
        end
        if job.route=="BNET" then stamp(a.accounts,job.id,200) end
        if job.route=="BNET" or job.route=="WHISPER" then stamp(a.names,P.key(job.name),256) end
        local audience
        if job.route=="GUILD" then audience=c.guildNames
        elseif job.route=="PARTY" or job.route=="RAID" then audience=c.groups end
        if job.route=="GUILD" or job.route=="PARTY" or job.route=="RAID" then
            if not audience then a.unknown=c.now
            else for name in pairs(audience) do stamp(a.names,P.key(name),256) end end
        end
    end
    if job.sent then job.sent(c.now,c) end
end
function P.emit(st,c,kind,payload,route,target,key,gap,owed,callbacks)
    if not ready(c,owed,callbacks and callbacks.stop) or not due(st.gaps[key],c.now,gap) then return false end
    if route~="GUILD" and route~="PARTY" and route~="RAID" and route~="WHISPER" and route~="BNET" then return false end
    if kind~="NH" and kind~="HA" and kind~="HR" then return false end
    st.owed=recent(st.owed,c.now)
    if owed and #st.owed>=6 then return false end
    -- Bound target cooldowns independently of the expiring route table.
    if not st.gaps[key] and S.count(st.gaps)>=256 then return false end
    st.serial=st.serial+1
    local id=tostring(math.floor(c.wall)).."-"..st.serial
    local dest=(route=="BNET" and target.name) or (route=="WHISPER" and target) or "*"
    if selfTarget(c,route,dest) then return false end
    local packet=table.concat({c.pool,id,math.floor(c.wall),dest,c.me,kind,payload},"|")
    local text
    if route=="BNET" then text="R2:Forever_"..c.pool.."_"..c.faction..":BR:"..packet
    else text="BF:"..id..":1:1:"..packet;if #packet>230 or #text>255 then return false end end
    local address=route=="BNET" and target.id or target
    if kind=="NH" and N.OverlordFeed and N.OverlordFeed.suppressed(st,c,route,dest,address) then return false end
    local job={key=key,gap=gap,owed=owed==true,pool=c.pool,me=c.me,kind=kind,route=route,id=route=="BNET" and address or nil,
        name=dest~="*" and dest or nil,valid=callbacks and callbacks.valid,sent=callbacks and callbacks.sent,
        stop=callbacks and callbacks.stop}
    if job.stop then job.stop.text=text end
    flight={text=text,route=route,target=address}
    local ok,result,attempted=pcall(c.send,c,text,route,address,owed and "owed" or "own",job)
    flight=nil
    local charged=ok and (result==true or attempted==true)
    if charged then
        st.gaps[key]=c.now
        if owed then st.owed[#st.owed+1]=c.now end
    end
    return ok and result==true,charged
end
local function learn(st,p,route,sender,id,c)
    P.sweep(st,c.now)
    local key=P.key(p.origin)
    local old=st.routes[key] or st.feed and st.feed.heard[key]
    if old and old.pool~=(p.pool or c.pool) then old=nil end
    if old and old.hops==0 and p.hops>0 and c.now-old.at<240 then return old end
    if not old then
        local n,pub=0,0
        for _,r in pairs(st.routes) do n=n+1;if r.route~="GUILD" then pub=pub+1 end end
        if n>=128 or (route~="GUILD" and pub>=96) then return nil end
    end
    local r={name=p.origin,via=sender,route=route,id=id,hops=p.hops,at=c.now,pool=p.pool or c.pool,
        nh=old and old.nh,version=old and old.version,epoch=old and old.epoch,epochAt=old and old.epochAt,
        announced=old and old.announced,announcePool=old and old.announcePool,announceMe=old and old.announceMe}
    st.routes[key]=r
    return r
end
function P.receive(st,p,route,sender,id,c)
    local r=learn(st,p,route,sender,id,c)
    if not r then return end
    if route=="GUILD" then st.guildHeard=c.now end
    if p.kind=="NH" and p.hops==0 then r.nh=c.now;r.version=S.str(p.payload,200) end
    if st.feed and N.OverlordFeed then
        N.OverlordFeed.remember(st.feed,r,c)
        N.OverlordFeed.prepare(st.feed,st,c)
    end
    -- Owed answers only to direct addressed peers, never to overheard/relayed requests.
    if p.hops~=0 or p.target~=c.me or (route~="WHISPER" and route~="BNET") then return r end
    local target=route=="BNET" and {id=id,name=p.origin} or sender
    local key=P.key(p.origin)
    if p.kind=="NH" and route=="WHISPER" then
        P.emit(st,c,"NH",P.presence(c),route,target,"reply:"..key,150,true)
    elseif p.kind=="HR" then
        local v,op,e,nonce,seq,tail=p.payload:match("^([5-8]):([A-Z]):(%d+):(%w+):(%d+):?(.*)$")
        if not v or #p.payload>250 or #nonce>32 or #e>10 or tonumber(e)<1
            or tonumber(e)>c.wall or #seq>5 or tonumber(seq)<1 or tonumber(seq)>10000 then return r end
        if op~="V" then return r end
        local body=table.concat({v,"R",e,nonce,seq},":")
        P.emit(st,c,"HA",body,route,target,"reply:"..key,150,true)
    end
    -- SR: an empty map has zero pages in 2.5.4; no invented empty-map opcode.
    return r
end
function P.tick(st,c)
    if st.feed and N.OverlordFeed then N.OverlordFeed.prepare(st.feed,st,c) end
    P.sweep(st,c.now)
    if not ready(c,false) then return end
    if c.guild then
        local gap=st.guildHeard and c.now>=st.guildHeard and c.now-st.guildHeard<3600 and 120 or 600
        P.emit(st,c,"NH",P.presence(c),"GUILD",nil,"guild",gap,false)
    end
    if c.group=="PARTY" or c.group=="RAID" then
        P.emit(st,c,"NH",P.presence(c),c.group,nil,"group",120,false)
    end
    if due(st.cycle,c.now,120) then
        st.cycle=c.now
        local live,unheard={},{}
        for _,f in ipairs(c.friends or {}) do
            if f.friend and #live+#unheard<200 then
                local r=st.routes[P.key(f.name)]
                if r and r.hops==0 and r.route=="BNET" and r.id==f.id then live[#live+1]=f
                else unheard[#unheard+1]=f end
            end
        end
        table.sort(live,function(a,b) return a.id<b.id end)
        for i=1,math.min(5,#live) do local f=live[i]
            P.emit(st,c,"NH",P.presence(c),"BNET",f,"bn:"..f.id,120,false)
        end
        for i=1,math.min(2,#unheard) do
            local f=unheard[(st.probe+i-1)%#unheard+1]
            P.emit(st,c,"NH",P.presence(c),"BNET",f,"bn:"..f.id,120,false)
        end
        st.probe=st.probe+2
    end
    local partners=0
    for _,r in pairs(st.routes) do if r.hops==0 and r.route=="WHISPER" and r.nh then partners=partners+1 end end
    if partners<6 and due(st.greeting,c.now,60) then
        local members=c.directory or {}
        for step=1,#members do
            local index=((st.greeter or 0)+step-1)%#members+1
            local _,_,name=N.Invite.name(members[index])
            local key=P.key(name)
            if name and not st.routes[key] and due(st.gaps["hello:"..key],c.now,600) then
                local _,charged=P.emit(st,c,"NH",P.presence(c),"WHISPER",name,"hello:"..key,600,false)
                if charged then st.greeting=c.now;st.greeter=index;break end
                -- A local refusal costs no cooldown: try the next member this tick.
                -- One bounded directory pass, at most one charged greeting.
            end
        end
    end
end
-- Main still owns OverlordF. Registration owns only tick, counters and offer provenance.
P.stats={}
N.Sources.register{name="overlord",prefixes={},counters=P.stats,tick=function(now)
    if N.Main and N.Main.overlordTick then N.Main.overlordTick(now) end
end}
N.Net.LIST.overlord.standDown="Overlord"
