"""PLAN 6.5.1 C3 rule mutants: portable, byte-stable, behavioral kills only."""
import argparse
from overlord_peer_mutants import run

# Existing protocol/stop guards retain their original purpose. Removed shared-lane
# suppression and hearing-expiry rules are replaced by their approved opposites.
RULES = [
    ('source accounts suppress NH', 'OverlordFeed.lua', 'if name and (P.key(name)==key or N.Adapters.peerIdentity(name)==source.identity) or id and id==source.id then', 'if name and P.key(name)==key then'),
    ('source bound', 'OverlordFeed.lua', 'S.count(st.sources)<2', 'S.count(st.sources)<3'),
    ('source names suppress NH', 'OverlordFeed.lua', 'if name and (P.key(name)==key or N.Adapters.peerIdentity(name)==source.identity) or id and id==source.id then', 'if id and id==source.id then'),
    ('queued NH dispatch suppression', 'OverlordPeer.lua', 'if job.kind=="NH" and N.OverlordFeed and N.OverlordFeed.suppressed(st,c,job.route,job.name,job.id) then', 'if false then'),
    ('request no fabricated ranking', 'OverlordFeed.lua', ':1:LK:0:0:', ':1:LK:1:1:'),
    ('keep control', 'OverlordFeed.lua', 'keep and "8:K:"', 'keep and "8:X:"'),
    ('200 second keep', 'OverlordFeed.lua', 'c.now-s.attempt>=(s.delay or 200)', 'c.now-s.attempt>=(s.delay or 200)-1'),
    ('busy response', 'OverlordPeer.lua', 'local body=table.concat({v,"R",e,nonce,seq},":")', 'local body=table.concat({v,"S",e,nonce,seq,"LK",0,0},":")'),
    ('shared 150s owed gap', 'OverlordPeer.lua', 'P.emit(st,c,"HA",body,route,target,"reply:"..key,150,true)', 'P.emit(st,c,"HA",body,route,target,"answer:"..key,150,true)'),
    ('stop on unsubscribe', 'OverlordFeed.lua', 'for key in pairs(st.sessions) do Q.stop(st,peer,c,key) end', 'st.sessions={}'),
    ('stop after busy', 'OverlordFeed.lua', 'not s.opened or not peer', 'not s.asked or not peer'),
    ('stop on source departure', 'OverlordFeed.lua', 'then Q.stop(st,peer,c,key);st.sources[key]=nil end', 'then st.sessions[key]=nil;st.sources[key]=nil end'),
    ('friend membership at receive', 'OverlordFeed.lua', 'or not friend(r,c)', 'or false'),
    ('stop expiry', 'OverlordFeed.lua', 'if c.now<row.at or row.safeAt and c.now-row.safeAt>60 then st.stops[key]=nil end', 'if false then st.stops[key]=nil end'),
    ('stop on logout', 'Main.lua', 'guarded(M.overlordCancel);N.BNet.pump(now());', ''),
    ('logout cannot reopen', 'Main.lua', 'not M.overlordClosing and M.sharing()', 'M.sharing()'),
    ('BN stop crosses off switches', 'BNet.lua', 'and N.Main.overlordStopping(text,"BNET",id) then return true end', 'and false then return true end'),
    ('stop requires an outstanding request', 'Main.lua', 'if not st then return false end\n    local c=M.overlordContext()', 'if not st then return false end\n    if text:find("|HR|8:X:",1,true) then return true end\n    local c=M.overlordContext()'),
    ('stop donor loaded silence', 'Main.lua', 'N.Net.SHIP.overlord==true and not A.loaded("Overlord")', 'N.Net.SHIP.overlord==true'),
    ('capability suffix absent', 'OverlordFeed.lua', 'Q.capability=""', 'Q.capability="~ld~lr~lp6"'),
    ('source switch cancellation', 'Net.lua', 'if on~=true and key=="overlord" and N.Main and N.Main.overlordCancel then N.Main.overlordCancel() end', 'if false then N.Main.overlordCancel() end'),
    ('share cancellation', 'Main.lua', 'N.BNet.cancel(nil,true); M.overlordCancel()', 'N.BNet.cancel(nil,true)'),
    ('Guild only cancellation', 'Net.lua', 'if level~="public" and N.Main and N.Main.overlordCancel then N.Main.overlordCancel() end', 'if false then N.Main.overlordCancel() end'),
]
MUTANTS = [(rule, file, old, new, 'Overlord reach:') for rule, file, old, new in RULES]
MUTANTS += [
    ('M Battle.net friend not club-only', 'OverlordFeed.lua', 'if v.friend and v.id==r.id', 'if v.id==r.id', 'Overlord revision: M club'),
    ('M same-faction friend remains eligible', 'OverlordFeed.lua', 'if v.friend and v.id==r.id', 'if v.friend and v.faction=="Horde" and v.id==r.id', 'Overlord revision: M same-faction'),
    ('M first-hand K need not wait for NH', 'OverlordFeed.lua', 'if not r.version then return true end', 'if not r.version then return false end', 'Overlord revision: M same-faction'),
    ('M canonical guild roster', 'Adapters.lua', 'if canonical then key=canonical(name) end', 'if false then key=canonical(name) end', 'Overlord revision: M'),
    ('M unreadable party count', 'Adapters.lua', 'if read~=(raid and count or count-1) then return nil end', 'if false then return nil end', 'Overlord revision: M'),
    ('M realm-qualified party unit', 'Adapters.lua', 'local canonical=A.peerIdentity(name,realm)', 'local canonical=N.OverlordPeer.key(name)', 'Overlord followup: M'),
    ('M canonical Battle.net friend', 'OverlordFeed.lua', 'P.key(v.name)==key', 'F.fold(v.name)==key', 'Overlord revision: M'),
    ('M guild exclusion', 'OverlordFeed.lua', 'or c.guildNames[identity]', '', 'Overlord revision: M'),
    ('M group exclusion', 'OverlordFeed.lua', 'c.groups[identity] or ', '', 'Overlord revision: M'),
    ('M no lane suppression', 'OverlordFeed.lua', 'if not st or (route~="BNET" and route~="WHISPER") then return false end', 'if st and (route=="GUILD" or route=="PARTY" or route=="RAID") then return true end\n    if not st then return false end', 'Overlord revision: M'),
    ('M actual NH restarts quiet', 'OverlordPeer.lua', 'if job.kind=="NH" then\n        if not st.announced', 'if false then\n        if not st.announced', 'Overlord revision: clock actual'),
    ('clock strictly beyond 300', 'OverlordFeed.lua', 'return c.now-last>300', 'return c.now-last>=300', 'Overlord revision: clock'),
    ('clock no artificial initial wait', 'OverlordFeed.lua', 'if not a then return true end', 'if not a then return c.now-source.since>300 end', 'Overlord revision: clock never'),
    ('clock first-hand session retained', 'OverlordFeed.lua', 'c.now>=r.at and supported(r)', 'c.now>=r.at and c.now-r.at<300 and supported(r)', 'Overlord revision: clock once'),
    ('clock live account required', 'OverlordFeed.lua', 'local live=c.online and c.online(r.id)', 'local live=v', 'Overlord revision: clock ignores'),
    ('clock remember source hearing', 'OverlordPeer.lua', 'N.OverlordFeed.remember(st.feed,r,c)', '', 'Overlord revision: clock never'),
    ('S1 repeated stop retained', 'BNet.lua', 'local stop=keepStops and q.net=="overlord"', 'local stop=false and q.net=="overlord"', 'Overlord revision: S1'),
    ('S2 silent source exponential backoff', 'OverlordFeed.lua', 's.delay=math.min(1800,200*2^(s.silent-1))', 's.delay=200', 'Overlord revision: S2'),
    ('S2 backoff cap', 'OverlordFeed.lua', 's.delay=math.min(1800,200*2^(s.silent-1))', 's.delay=200*2^(s.silent-1)', 'Overlord revision: S2 silent'),
    ('S2 busy reply resets', 'OverlordFeed.lua', 's.asked,s.live,s.nonce=nil,nil,nil\n            s.silent,s.delay=0,200', 's.asked,s.live,s.nonce=nil,nil,nil', 'Overlord revision: S2 any'),
    ('S2 full feed resets', 'OverlordFeed.lua', 's.silent,s.delay=0,200\n    local zone', 'local zone', 'Overlord revision: S2 any'),
    ('S3 only V receives busy', 'OverlordPeer.lua', 'if op~="V" then return r end', 'if op=="F" then return r end', 'Overlord revision: S3 only'),
    ('S3 exact README reply promise', '../README.md', 'Only addressed HR V requests get a bounded busy HA', 'All incoming HR asks receive bounded busy HA', 'Overlord revision: S3 README'),
    ('session hearing cache bound', 'OverlordFeed.lua', 'S.count(st.heard)<200', 'S.count(st.heard)<201', 'Overlord revision: memory'),
    ('remembered metadata respects route ceiling', 'OverlordPeer.lua', 'if not st.routes[key] then\n        local n,pub=0,0', 'if not old then\n        local n,pub=0,0', 'Overlord revision: memory'),
]
if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--write', action='store_true')
    raise SystemExit(0 if run(MUTANTS, 'overlord-reachability-mutants.json', parser.parse_args().write) else 1)
