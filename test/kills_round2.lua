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
