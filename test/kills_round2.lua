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
local function sends(pattern)
    local n=0
    for _,m in ipairs(H.sent()) do if m.prefix=="LEGW1" and m.text:match(pattern or "^R|") then n=n+1 end end
    return n
end
local function own()
    H.units().target=H.player("Own Enemy","Horde")
    H.deliver("PLAYER_TARGET_CHANGED"); H.drain()
end

test("Kills R2 reserve: full combat bucket sends a kill relay and leaves one own line",function()
    local N=boot(); H.combat(true)
    eq(#H.sent(),0,"the combat bucket starts full")
    hear("Combat Victim","Combat Killer"); H.advance(1.1)
    eq(sends("^R|1|hh|kill|"),1,"combat must not suppress every kill relay")
    yes(shown(N,"Combat Killer"))
    own(); H.advance(3.1); N.Main.shareTick()
    eq(sends("^O|"),1,"one own line remains protected in combat")
    eq(next(N.Main.relay.pending),nil); eq(N.Wire.queued(),0); no(N.Main.error)
end)

-- Match rp2's 300-second mixed legacy/kill stream; at every=4 all due inputs are kills.
for _,every in ipairs({1,4}) do
    test("Kills R2 reserve: active combat relays keep all five own O slots every="..every,function()
        local N=boot(); H.combat(true)
        local refused=0; local send=N.Wire.send
        N.Wire.send=function(prefix,text,...)
            local ok,why,attempted=send(prefix,text,...)
            if prefix=="LEGW1" and text:sub(1,2)=="O|" and not ok then refused=refused+1 end
            return ok,why,attempted
        end
        for t=1,300 do
            own()
            if t%every==0 then
                if t%2==0 then hear("Vic "..H.abc(t),"Kil "..H.abc(t))
                else
                    local stamp=b36(GetServerTime()); local author="Leg "..H.abc(t)
                    H.deliver("CHAT_MSG_ADDON","HeadHunter","1AE:eu-pvp;"..author..";A;5cy;1;"..stamp
                        ..";LKl "..H.abc(t)..";2s;"..stamp..";dw;6y","WHISPER",author)
                end
            end
            H.advance(1); N.Main.shareTick()
        end
        eq(sends("^O|"),5,"all five own minute slots reach Wire")
        eq(refused,0)
        yes(sends()>0,"a zero-relay result is not an own-priority pass")
        -- The shared gate does not promise per-family fairness under mixed traffic.
        if every==4 then yes(sends("^R|1|hh|kill|")>0,"kill-only combat traffic must relay") end
        for i,m in ipairs(H.sent()) do
            if m.kind=="GUILD" then
                local used=0
                for j=1,i do local earlier=H.sent()[j]
                    if earlier.kind=="GUILD" and m.at-earlier.at<60 then used=used+1 end
                end
                yes(used<=10,"combat guild cap remains unchanged")
                if m.text:sub(1,2)=="R|" then yes(used<=8,"relays leave two combat guild-minute slots") end
            end
        end
        H.advance(.1) -- finish the final input's existing due+0.05s jitter callback
        eq(next(N.Main.relay.pending),nil); eq(N.Wire.queued(),0); no(N.Main.error)
    end)
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
