"""NH-free C3 rule mutants. Checkout-relative, byte-stable, syntax-valid kills."""
import argparse
from overlord_peer_mutants import run

RULES = [
    ('source accounts suppress NH', 'OverlordFeed.lua', 'if name and F.fold(name)==key or id and id==source.id then', 'if name and F.fold(name)==key then'),
    ('unknown guild lane suppression', 'OverlordFeed.lua', 'not c.guildNames or c.guildNames[key]', 'c.guildNames and c.guildNames[key]'),
    ('unknown group lane suppression', 'OverlordFeed.lua', 'not c.groups or c.groups[key]', 'c.groups and c.groups[key]'),
    ('strict capability expiry', 'OverlordFeed.lua', 'c.now-source.since>300', 'c.now-source.since>=300'),
    ('source bound', 'OverlordFeed.lua', 'S.count(st.sources)<2', 'S.count(st.sources)<3'),
    ('source names suppress NH', 'OverlordFeed.lua', 'if name and F.fold(name)==key or id and id==source.id then', 'if id and id==source.id then'),
    ('guild lane suppression', 'OverlordFeed.lua', 'if route=="GUILD" and (not c.guildNames or c.guildNames[key]) then', 'if false then'),
    ('group lane suppression', 'OverlordFeed.lua', 'if (route=="PARTY" or route=="RAID") and (not c.groups or c.groups[key]) then', 'if false then'),
    ('queued NH dispatch suppression', 'OverlordPeer.lua', 'if job.kind=="NH" and N.OverlordFeed and N.OverlordFeed.suppressed(st,c,job.route,job.name,job.id) then', 'if false then'),
    ('source chosen before owed NH', 'OverlordPeer.lua', 'if st.feed and N.OverlordFeed then N.OverlordFeed.prepare(st.feed,st,c) end\n    -- Owed answers', 'if false then N.OverlordFeed.prepare(st.feed,st,c) end\n    -- Owed answers'),
    ('request no fabricated ranking', 'OverlordFeed.lua', ':1:LK:0:0:', ':1:LK:1:1:'),
    ('keep control', 'OverlordFeed.lua', 'keep and "8:K:"', 'keep and "8:X:"'),
    ('200 second keep', 'OverlordFeed.lua', 'c.now-s.attempt>=200', 'c.now-s.attempt>=199'),
    ('busy response', 'OverlordPeer.lua', 'local body=table.concat({v,"R",e,nonce,seq},":")', 'local body=table.concat({v,"S",e,nonce,seq,"LK",0,0},":")'),
    ('shared 150s owed gap', 'OverlordPeer.lua', 'P.emit(st,c,"HA",body,route,target,"reply:"..key,150,true)', 'P.emit(st,c,"HA",body,route,target,"answer:"..key,150,true)'),
    ('stop on unsubscribe', 'OverlordFeed.lua', 'for key in pairs(st.sessions) do Q.stop(st,peer,c,key) end', 'st.sessions={}'),
    ('stop after busy', 'OverlordFeed.lua', 'not s.opened or not peer', 'not s.asked or not peer'),
    ('stop on source departure', 'OverlordFeed.lua', 'then Q.stop(st,peer,c,key);st.sources[key]=nil end', 'then st.sessions[key]=nil;st.sources[key]=nil end'),
    ('group membership at receive', 'OverlordFeed.lua', 'if r.route~="BNET" then return c.groups and c.groups[F.fold(r.name)]==c.faction end', 'if r.route~="BNET" then return true end'),
    ('stop expiry', 'OverlordFeed.lua', 'if c.now<row.at or c.now-row.at>60 then st.stops[key]=nil end', 'if false then st.stops[key]=nil end'),
    ('stop on logout', 'Main.lua', 'guarded(M.overlordCancel);N.BNet.pump(now());', ''),
    ('BN stop crosses off switches', 'BNet.lua', 'and N.Main.overlordStopping(text,"BNET",id) then return true end', 'and false then return true end'),
    ('stop requires an outstanding request', 'Main.lua', 'if not st then return false end\n    local c=M.overlordContext()', 'if not st then return false end\n    if text:find("|HR|8:X:",1,true) then return true end\n    local c=M.overlordContext()'),
    ('stop donor loaded silence', 'Main.lua', 'N.Net.SHIP.overlord==true and not A.loaded("Overlord")', 'N.Net.SHIP.overlord==true'),
    ('capability suffix absent', 'OverlordFeed.lua', 'Q.capability=""', 'Q.capability="~ld~lr~lp6"'),
    ('source switch cancellation', 'Net.lua', 'if on~=true and key=="overlord" and N.Main and N.Main.overlordCancel then N.Main.overlordCancel() end', 'if false then N.Main.overlordCancel() end'),
    ('share cancellation', 'Main.lua', 'N.BNet.cancel(); M.overlordCancel()', 'N.BNet.cancel()'),
    ('Guild only cancellation', 'Net.lua', 'if level~="public" and N.Main and N.Main.overlordCancel then N.Main.overlordCancel() end', 'if false then N.Main.overlordCancel() end'),
]
MUTANTS = [(rule, file, old, new, 'Overlord reach:') for rule, file, old, new in RULES]
if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--write', action='store_true')
    raise SystemExit(0 if run(MUTANTS, 'overlord-reachability-mutants.json', parser.parse_args().write) else 1)
