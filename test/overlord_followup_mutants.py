"""Reviewer follow-up mutants: exact behavioral regressions, no syntax kills."""
import argparse
from overlord_peer_mutants import run

MUTANTS = [
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
