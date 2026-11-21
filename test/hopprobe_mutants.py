"""HopProbe-only mutants: private copies, syntax checked, assertion kills only."""
from pathlib import Path
import json
import os
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
LUA = os.environ.get('LAYERENEMIES_LUA') or shutil.which('lua5.1') or shutil.which('lua')
MUTANTS = [
    ('creature-early', '=3,5,5,40', '=2,5,5,40'),
    ('creature-late', '=3,5,5,40', '=4,5,5,40'),
    ('player-early', '=3,5,5,40', '=3,4,5,40'),
    ('player-late', '=3,5,5,40', '=3,6,5,40'),
    ('one-fifth-edge', 'retained*P.REMAINING_DENOMINATOR<=before.playerCount', 'retained*P.REMAINING_DENOMINATOR<before.playerCount'),
    ('one-fifth-removed', 'retained*P.REMAINING_DENOMINATOR<=before.playerCount', 'true'),
    ('movement-edge', '<P.YARDS^2', '<=P.YARDS^2'),
    ('movement-map', 'and a.map==b.map', ''),
    ('movement-vertical', '+(a.z-b.z)^2', ''),
    ('event-removed', 'if transfer then', 'if false then'),
    ('before-unparsed', 'not before.unparsed and not after.unparsed', 'not after.unparsed'),
    ('after-unparsed', 'not before.unparsed and not after.unparsed', 'not before.unparsed'),
    ('retained-creature', 'and not retained then', 'then'),
    ('matching-npc', 'if after.npcs[npc] then', 'if true then'),
    ('spawn-identity', 'local key=npc..":"..spawn', 'local key=guid'),
    ('creature-dedupe', 'if not out.creatures[key] then', 'if true then'),
    ('player-dedupe', 'if not out.players[guid] then', 'if true then'),
    ('player-flag', 'if guid and player==true then', 'if guid and player~=nil then'),
    ('snapshot-cap', 'if i>P.MAX_UNITS then break end', 'if i>P.MAX_UNITS-1 then break end'),
    ('sparse-condition', 'and before.playerCount<P.PLAYERS then', 'or before.playerCount<P.PLAYERS then'),
    ('result-creatures', 'the creatures around you changed.', 'the creatures around you changed!'),
    ('result-players', 'the players around you changed.', 'the players around you changed!'),
    ('result-unchanged', 'No change seen;', 'No change found;'),
    ('result-sparse', 'Too little around you to tell.', 'Too little around you to tell!'),
    ('result-missed', ' did not invite.', ' did not invite!'),
]


def run(root):
    return subprocess.run([str(LUA), 'test/harness.lua', '--only', 'HopProbe'], cwd=root,
                          capture_output=True, text=True, timeout=90)


def main():
    assert LUA, 'Set LAYERENEMIES_LUA to a Lua 5.1 binary'
    results = []
    with tempfile.TemporaryDirectory(prefix='le-probe-', dir=os.environ.get('TMPDIR', ROOT)) as temp:
        root = Path(temp)
        for folder in ('LayerEnemies', 'test'):
            shutil.copytree(ROOT / folder, root / folder, ignore=shutil.ignore_patterns('__pycache__'))
        baseline = run(root)
        assert baseline.returncode == 0, baseline.stdout + baseline.stderr
        print(next(s for s in baseline.stdout.splitlines() if s.startswith('RESULT:')), flush=True)
        target = root / 'LayerEnemies/HopProbe.lua'
        original = target.read_text()
        for rule, old, new in MUTANTS:
            assert original.count(old) == 1, (rule, original.count(old))
            target.write_text(original.replace(old, new, 1))
            try:
                subprocess.run([str(LUA), '-e', 'assert(loadfile("LayerEnemies/HopProbe.lua"))'],
                               cwd=root, check=True, capture_output=True)
                result = run(root)
                failures = [re.sub(r'0x[0-9a-fA-F]+', '0xADDR', s) for s in result.stdout.splitlines()
                            if s.startswith('FAIL ') and ('expected' in s or 'not equal' in s)]
                caught = result.returncode != 0 and bool(failures)
                results.append({'rule': rule, 'caught': caught, 'assertions': failures})
                print(('CAUGHT ' if caught else 'SURVIVED ') + rule, flush=True)
            finally:
                target.write_text(original)
    (ROOT / 'notes/hopprobe-mutants.json').write_text(json.dumps(results, indent=2) + '\n')
    caught = sum(r['caught'] for r in results)
    print(f'RESULT: {caught}/{len(results)} HopProbe mutants killed', flush=True)
    assert caught == len(results), [r['rule'] for r in results if not r['caught']]


if __name__ == '__main__':
    main()
