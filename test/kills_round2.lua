-- Round-2 corrections: shared relay admission and bounded kill-id eviction.
local H=...
local test,eq,yes,no=H.test,H.eq,H.yes,H.no
local function b36(n)
    local digits,out="0123456789abcdefghijklmnopqrstuvwxyz",""
    n=math.floor(n)
    repeat local r=n%36; out=digits:sub(r+1,r+1)..out; n=math.floor(n/36) until n==0
    return out
end
local function death(victim,killer)
    local stamp=b36(GetServerTime())
    return "1AE:eu-pvp;"..victim..";A;5cy;1;"..stamp..";D"..table.concat({stamp,victim,"1o","W","H",
        "2s","dw","6y","e","9ix",killer..",,14,M,O,2,"},";")
end
local function hex(s) return (s:gsub(".",function(c) return string.format("%02x",c:byte()) end)) end
local function wire(victim,killer,id)
    return table.concat({"R","1","hh","kill",hex(victim),"D:"..id,"100","500","250","","u","","0",hex(killer)..":MAGE:40"},"|")
end
local function boot()
    local N=H.load(); N.Net.SHIP.hh=true; H.loaded().HeadHunter=true
    N.Relay.rand=function() return 1 end
    H.advance(1); return N
end
local function hear(victim,killer)
    H.deliver("CHAT_MSG_ADDON","HeadHunter",death(victim,killer),"WHISPER",victim)
end
local function guild(victim,killer,id)
    H.deliver("CHAT_MSG_ADDON","LEGW1",wire(victim,killer,id),"GUILD","Guild Carrier")
end
local function shown(N,killer) return N.Known.get(N.Main.find.known,killer,H.clock()) end
local function sends()
    local n=0
    for _,m in ipairs(H.sent()) do if m.prefix=="LEGW1" and m.text:sub(1,2)=="R|" then n=n+1 end end
    return n
end

test("Kills R2 reserve: kill dispatch uses the shared spend gate",function()
    local N=boot(); local calls=0
    -- Replace the public admission seam, not Wire: every relay kind must obey it.
    N.Relay.spend=function(now,relay)
        eq(now,H.clock()); yes(relay); calls=calls+1
        return false,"own reserve"
    end
    hear("First Victim","First Killer"); H.advance(1.1)
    eq(calls,1,"kill must consult the same Relay.spend path as Spy/HH/WE")
    eq(sends(),0,"a denied shared gate must prevent the actual guild send")
    yes(shown(N,"First Killer"),"relay refusal cannot hide a received kill")
    eq(N.Relay.noteSend,nil,"no second reserve implementation")
    eq(next(N.Main.relay.pending),nil); eq(N.Wire.queued(),0); no(N.Main.error)
end)

test("Kills R2 reserve: kill relays leave the guild-minute own slots",function()
    local N=boot()
    for i=1,17 do
        N.Net.SHIP.we=true
        yes(N.Wire.send("WEFF1","Q","GUILD",nil,{net="we",prio="own"}))
        N.Net.SHIP.we=false; H.advance(2)
    end
    eq(#H.sent(),17)
    hear("Minute Victim","Minute Killer"); H.advance(1.1)
    eq(sends(),0,"kill uses the same three-slot minute reserve as every other relay")
    yes(shown(N,"Minute Killer")); eq(next(N.Main.relay.pending),nil)
    H.units().target=H.player("Own Enemy","Horde")
    H.deliver("PLAYER_TARGET_CHANGED"); H.drain(); H.advance(3.1); N.Main.shareTick()
    local own=0; for _,m in ipairs(H.sent()) do if m.text:sub(1,2)=="O|" then own=own+1 end end
    eq(own,1); eq(N.Wire.queued(),0); no(N.Main.error)
end)

for _,mode in ipairs({"260 direct kills at five per minute","300 guild kills at one per second"}) do
    test("Kills R2 ledger: new kill stays visible after "..mode,function()
        local N=boot(); local direct=mode:sub(1,3)=="260"
        local total,gap=direct and 260 or 300,direct and 12 or 1
        local accepted=0
        for i=1,total do
            local victim,killer="Victim "..H.abc(i),"Killer "..H.abc(i)
            if direct then hear(victim,killer) else guild(victim,killer,700000+i) end
            if shown(N,killer) then accepted=accepted+1 end
            H.advance(gap)
        end
        hear("Newest Victim","Newest Killer")
        yes(shown(N,"Newest Killer"),"a full kill ledger must not darken the next new kill")
        eq(accepted,total,"every valid input was shown when received")
        eq(N.Safe.count(N.Main.relay.killRecords),256,"ledger remains bounded")
        for _,delay in ipairs({600,400}) do
            H.advance(delay)
            local before=sends(); local suffix=H.abc(delay)
            hear("Latevictim "..suffix,"Latekiller "..suffix)
            yes(shown(N,"Latekiller "..suffix),"new kills remain visible without waiting for ledger expiry")
            H.advance(1.1); eq(sends(),before+1,"fresh kill may relay when the rate budgets have room")
            yes(N.Safe.count(N.Main.relay.killRecords)<=256)
        end
        no(N.Main.error)
    end)
end

test("Kills R2 ledger: overflow evicts the oldest admitted id and prunes expiry first",function()
    local N=boot(); local R=N.Relay; local st=R.new()
    local function record(i,at)
        return {src="hh",origin="Victim "..H.abc(i),rid="D:"..i,at=at}
    end
    local now=H.clock(); local ttl=N.Known.TTL+N.HeadHunter.WINDOW
    eq(ttl,3900)
    local first=record(1,now)
    yes(R.acceptKill(st,first,now)); local key=R.key(first)
    for i=2,256 do yes(R.acceptKill(st,record(i,now-100),now+i)) end
    yes(R.acceptKill(st,record(257,now),now+257),"overflow must admit the new id")
    eq(st.killRecords[key],nil,"evict oldest admission, not the oldest claimed event time")
    eq(N.Safe.count(st.killRecords),256)
    local second=R.key(record(2,now))
    yes(st.killRecords[second]); local expires=st.killRecords[second].expires
    no(R.acceptKill(st,record(2,now+300),now+300),"retained ids are still once-only")
    eq(st.killRecords[second].expires,expires,"duplicates cannot renew the eviction age")
    eq(st.killRecords[second].at,now-100,"duplicates cannot freshen the origin age")
    -- At this exact boundary only the second identity expires. No live id needs eviction.
    yes(R.acceptKill(st,record(258,expires),expires))
    eq(st.killRecords[second],nil); yes(st.killRecords[R.key(record(3,now))])
    eq(N.Safe.count(st.killRecords),256); no(N.Main.error)
end)
