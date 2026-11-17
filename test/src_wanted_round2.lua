-- S4: bounded replay memory must not silence a busy honest sender.
local h=...
local test,eq,yes,no=h.test,h.eq,h.yes,h.no
local function setup()
    local N=h.load(); N.Net.SHIP.wanted=true; N.Net.setConsent("public")
    yes(N.Find.add(N.Main.find,"Enemy One")); return N
end
local function count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
local function peer(i) return "Scout "..h.abc(i) end
local function payload(N,t) return assert(N.Codec.addonEncode(assert(N.Codec.deflateStored(assert(N.Codec.lsWrite(t)))))) end
local function send(N,tag,t,route,sender,id)
    local b=payload(N,t); local n=math.ceil(#b/240)
    for i=1,n do
        local f=tag..":"..string.format("%x",id or 1)..":"..i.."/"..n..":"..b:sub((i-1)*240+1,i*240)
        h.deliver("CHAT_MSG_ADDON","WNTD",f,route or "GUILD",sender or "Lone Scout")
    end
end
local function event(N,id,x,route,sender)
    send(N,"E",{v="1.29.2",g="Player-1-AB",n="Enemy One",m=100,x=x or 50,y=40},route,sender,id)
end
local function key(N,id,sender,tag)
    local _,owner=N.Invite.name(sender or "Lone Scout")
    return "packet:"..owner..":"..(tag or "E")..":"..string.format("%x",id)
end
local function shown(N,x)
    local r=N.Find.rows(N.Main.find,h.clock(),100)[1]
    return r and r.reported and r.x and math.abs(r.x*100-x)<0.001 and r.got==h.clock()
end
local function cadence(every,n,route)
    local N=setup(); local shownCount=0
    for i=1,n do
        local x=(i%90)+1; event(N,i,x,route)
        if shown(N,x) then shownCount=shownCount+1 end
        h.advance(every)
    end
    eq(shownCount,n,"every new sighting reaches Find")
    eq(N.Wanted.stats.accepted,n); eq(N.Wanted.stats.refused,0)
    eq(N.Wanted.stats.evicted,n-32,"every displaced live ID is counted")
    eq(count(N.Wanted.state.seen),32); no(N.Main.error)
end

test("Wanted: R2 S4 one sighting a minute for two hours shows 120 of 120",function()
    cadence(60,120,"GUILD")
end)
test("Wanted: R2 S4 one sighting every twenty seconds shows all sixty",function()
    cadence(20,60,"GUILD")
end)
test("Wanted: R2 S4 twenty-second cadence stays live for two hours",function()
    cadence(20,360,"GUILD")
end)
test("Wanted: R2 S4 channel scout also shows 120 of 120",function()
    cadence(60,120,"CHANNEL")
end)

local function fill(N,route,first,last)
    for sender=first,last do for id=1,32 do event(N,id,50,route,peer(sender)) end end
end
local function publicCount(N)
    local n=0; for _,v in pairs(N.Wanted.state.seen) do if not v.guild then n=n+1 end end; return n
end

test("Wanted: R2 S4 public pool evicts oldest public ID not an older guild ID",function()
    local N=setup(); event(N,1,49,"GUILD","Protected Mate")
    fill(N,"CHANNEL",1,8)
    eq(count(N.Wanted.state.seen),257); eq(publicCount(N),256)
    h.advance(1); event(N,1,51,"CHANNEL","New Scout")
    yes(shown(N,51)); eq(count(N.Wanted.state.seen),257); eq(publicCount(N),256)
    no(N.Wanted.state.seen[key(N,1,peer(1))],"oldest public admission removed")
    yes(N.Wanted.state.seen[key(N,2,peer(1))]); yes(N.Wanted.state.seen[key(N,1,"New Scout")])
    yes(N.Wanted.state.seen[key(N,1,"Protected Mate")],"guild reserve remains protected")
end)

test("Wanted: R2 S4 global pool evicts oldest ID and admits a new guild scout",function()
    for _,firstRoute in ipairs({"GUILD","CHANNEL"}) do
        local N=setup(); fill(N,firstRoute,1,8); fill(N,"GUILD",9,16)
        eq(count(N.Wanted.state.seen),512)
        h.advance(1); event(N,1,52,"GUILD","New Scout")
        yes(shown(N,52)); eq(count(N.Wanted.state.seen),512)
        no(N.Wanted.state.seen[key(N,1,peer(1))],"oldest globally removed")
        yes(N.Wanted.state.seen[key(N,2,peer(1))]); yes(N.Wanted.state.seen[key(N,1,"New Scout")])
    end
end)

test("Wanted: R2 S4 public traffic can replace borrowed slots but not the guild reserve",function()
    local N=setup(); fill(N,"GUILD",1,16)
    eq(count(N.Wanted.state.seen),512); eq(publicCount(N),0)
    fill(N,"CHANNEL",17,24)
    eq(N.Wanted.stats.accepted,768,"a full global ledger does not refuse new public evidence")
    eq(count(N.Wanted.state.seen),512); eq(publicCount(N),256)
    for sender=9,16 do for id=1,32 do yes(N.Wanted.state.seen[key(N,id,peer(sender))]) end end
    h.advance(1); event(N,1,53,"CHANNEL","New Scout")
    yes(shown(N,53)); eq(count(N.Wanted.state.seen),512); eq(publicCount(N),256)
    no(N.Wanted.state.seen[key(N,1,peer(17))],"full public pool replaces itself")
    yes(N.Wanted.state.seen[key(N,1,peer(9))],"older guild ID survives public overflow")
end)

local function diagnostics(N)
    local before=#h.log(); N.Main.net("net wanted")
    local lines={}; for i=before+1,#h.log() do lines[#lines+1]=h.log()[i] end
    return table.concat(lines,"\n")
end

test("Wanted: R2 S4 eviction counter is visible through net wanted including zero",function()
    local N=setup()
    yes(diagnostics(N):find("Wanted replay: evicted=0",1,true),"zero counter is visible")
    for i=1,32 do event(N,i,i) end
    eq(N.Wanted.stats.evicted,0)
    h.advance(1); event(N,33,33); eq(N.Wanted.stats.evicted,1)
    yes(diagnostics(N):find("Wanted replay: evicted=1",1,true))
    h.combat(true)
    yes(diagnostics(N):find("Wanted replay: evicted=1",1,true),"counter stays readable in combat")
    h.combat(false)
end)

test("Wanted: R2 S4 counter counts public and global evictions not refusals",function()
    local N=setup(); fill(N,"CHANNEL",1,8)
    eq(N.Wanted.stats.evicted,0)
    event(N,1,51,"CHANNEL","New Scout"); eq(N.Wanted.stats.evicted,1)
    fill(N,"GUILD",9,16); eq(count(N.Wanted.state.seen),512)
    event(N,1,52,"GUILD","New Guildmate"); eq(N.Wanted.stats.evicted,2)
    yes(shown(N,52)); eq(N.Wanted.stats.refused,0)
end)

test("Wanted: R2 S4 overlapping sender and public limits count both evictions",function()
    local N=setup(); event(N,1,1,"GUILD")
    for i=2,32 do event(N,i,i,"CHANNEL") end
    fill(N,"CHANNEL",1,7); event(N,1,50,"CHANNEL",peer(8))
    eq(count(N.Wanted.state.seen),257); eq(publicCount(N),256)
    event(N,33,33,"CHANNEL")
    yes(shown(N,33)); eq(count(N.Wanted.state.seen),256); eq(publicCount(N),256)
    no(N.Wanted.state.seen[key(N,1)]); no(N.Wanted.state.seen[key(N,2)])
    yes(N.Wanted.state.seen[key(N,3)]); eq(N.Wanted.stats.evicted,2)
    eq(N.Wanted.stats.refused,0)
end)

local function record(id,age)
    local r={kind="kill",id="Record Origin:"..(1000000+id),origin="Record Origin",seq=1000000+id,
        prev="0",t=GetServerTime()-(age or 0),data={victim="Player-1-AB",victimName="Enemy One",
        victimFaction="Horde",mapId=100,x=50,y=40}}
    local keys={}; for k in pairs(r.data) do keys[#keys+1]=k end; table.sort(keys)
    local s=r.kind.."\n"..r.id.."\n"..r.prev.."\n"..tostring(r.t)
    for _,k in ipairs(keys) do s=s.."\n"..k.."="..tostring(r.data[k]) end
    local a,b=1,0; for i=1,#s do a=(a+s:byte(i))%65521; b=(b+a)%65521 end
    r.hash=string.format("%08x",b*65536+a); return r
end
local function report(N,r,id,sender)
    send(N,"F",{v="1.29.2",r={r}},"WHISPER",sender,id)
end

test("Wanted: R2 S4 mixed records evict by admission not observation or expiry",function()
    local N=setup(); event(N,1,1)
    h.advance(1); local r=record(1,300); report(N,r,40,"Lone Scout-TestRealm")
    local rk="record:"..r.id; local remembered=N.Wanted.state.seen[rk]; yes(remembered)
    for i=2,31 do event(N,i,i) end
    eq(count(N.Wanted.state.seen),32)
    h.advance(1); event(N,32,32)
    yes(shown(N,32)); no(N.Wanted.state.seen[key(N,1)])
    eq(N.Wanted.state.seen[rk],remembered,"newer admission with earlier expiry survives")
    local accepted,expires,order=N.Wanted.stats.accepted,remembered.expires,remembered.order
    h.advance(1); report(N,r,41,"Other Carrier")
    eq(N.Wanted.stats.accepted,accepted,"retained record duplicate dropped across carriers")
    eq(N.Wanted.state.seen[rk].expires,expires); eq(N.Wanted.state.seen[rk].order,order)
    event(N,33,33); yes(shown(N,33)); no(N.Wanted.state.seen[rk],"next oldest is the record")
    eq(count(N.Wanted.state.seen),32); eq(N.Wanted.stats.evicted,2)
end)

test("Wanted: R2 S4 expired IDs are pruned before capacity eviction at exact expiry",function()
    local N=setup(); local first=h.clock(); event(N,1,1)
    h.clock(first+1); for i=2,32 do event(N,i,i) end
    eq(count(N.Wanted.state.seen),32)
    -- No tick: intake itself must release the just-expired ID, not evict a live one.
    h.clock(first+3600); event(N,1,40)
    yes(shown(N,40)); eq(count(N.Wanted.state.seen),32)
    for i=2,32 do yes(N.Wanted.state.seen[key(N,i)]) end
    eq(N.Wanted.stats.evicted or 0,0)
    h.clock(first+3601); N.Sources.tick(h.clock())
    eq(count(N.Wanted.state.seen),1); eq(N.Wanted.stats.evicted or 0,0,"expiry is not eviction")
end)

test("Wanted: R2 S4 invalid untracked and duplicate input cannot evict remembered IDs",function()
    for _,full in ipairs({"sender","global"}) do
        local N=setup()
        if full=="sender" then for i=1,32 do event(N,i,i) end else fill(N,"GUILD",1,16) end
        local snapshot={}
        for k,v in pairs(N.Wanted.state.seen) do snapshot[k]={entry=v,expires=v.expires,order=v.order} end
        local accepted=N.Wanted.stats.accepted; h.advance(1)
        event(N,1,90,"GUILD",full=="sender" and "Lone Scout" or peer(1))
        h.deliver("CHAT_MSG_ADDON","WNTD","E:ee:1/1:bad","GUILD","Lone Scout")
        for i,d in ipairs({{v="1.29.2",g="Player-1-AB",n="Untracked One"},
                {v="1.30.0",g="Player-1-AB",n="Enemy One"},
                {v="1.29.2",g="bad",n="Enemy One"}}) do send(N,"E",d,"GUILD","Lone Scout",40+i) end
        local r=record(1); r.hash="00000000"; report(N,r,45,"Lone Scout")
        eq(N.Wanted.stats.accepted,accepted); eq(N.Wanted.stats.evicted or 0,0)
        eq(count(N.Wanted.state.seen),count(snapshot))
        for k,v in pairs(snapshot) do
            eq(N.Wanted.state.seen[k],v.entry); eq(v.entry.expires,v.expires); eq(v.entry.order,v.order)
        end
        no(N.Main.error)
    end
end)

test("Wanted: R2 S4 sender overflow evicts only its oldest admission even with tied clocks",function()
    local N=setup(); event(N,1,99,"GUILD","Protected Mate")
    local protected=key(N,1,"Protected Mate")
    for i=1,32 do event(N,i,i) end
    eq(count(N.Wanted.state.seen),33); yes(N.Wanted.state.seen[key(N,1)])
    local first=N.Wanted.state.seen[key(N,1)]; local accepted=N.Wanted.stats.accepted
    h.advance(1); event(N,1,90,"CHANNEL","Lone Scout-TestRealm")
    eq(N.Wanted.stats.accepted,accepted,"retained duplicate is dropped across routes")
    eq(N.Wanted.state.seen[key(N,1)],first,"duplicate does not refresh replay memory")
    event(N,33,33); yes(shown(N,33),"sender remains useful when full")
    eq(count(N.Wanted.state.seen),33); no(N.Wanted.state.seen[key(N,1)],"oldest sender ID evicted")
    yes(N.Wanted.state.seen[protected],"another sender's older ID survives")
    for i=2,33 do yes(N.Wanted.state.seen[key(N,i)],"other sender IDs remain") end
    -- Replaying an evicted sighting is the explicit bounded-memory trade-off.
    h.advance(1); event(N,1,91); yes(shown(N,91))
    no(N.Wanted.state.seen[key(N,2)]); yes(N.Wanted.state.seen[key(N,1)])
end)
