"""Reviewer follow-up mutants: exact behavioral regressions, no syntax kills."""
import argparse
from overlord_peer_mutants import run

MUTANTS = [
    ('n1 preserve paused stops', 'OverlordFeed.lua',
     'if c.stopPaused then row.safeAt=nil',
     'if c.stopPaused then st.stops[key]=nil;row.safeAt=nil', 'Overlord followup: n1'),
    ('S2 friend cache invalidation', 'BNet.lua',
     'function BN.invalidatePeers() cache,cacheAt={},nil end',
     'function BN.invalidatePeers() end', 'Overlord followup: S2'),
    ('S1 senderless cancellation', 'Main.lua',
     'c.send=overlordSend -- prepare can cancel from a queued-send guard, not only the tick.',
     '', 'Overlord followup: S1'),
    ('M full realm identity', 'OverlordFeed.lua',
     'if c.groups[identity] or c.guildNames[identity] then return false end',
     'if c.groups[key] or c.guildNames[key] then return false end', 'Overlord followup: M'),
]
if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--write', action='store_true')
    raise SystemExit(0 if run(MUTANTS, 'overlord-followup-mutants.json', parser.parse_args().write) else 1)
