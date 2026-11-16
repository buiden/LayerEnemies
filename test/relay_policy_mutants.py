"""One compiling mutant per guild-relay owner ruling; always restore source bytes."""
from pathlib import Path
import argparse
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
MUTANTS = [
    ('relay-ignores-share-off', 'LayerEnemies/Main.lua', [
        ('function M.offerRelay(record)\n    if not M.sharing() then return end',
         'function M.offerRelay(record)'),
        ('    if not M.sharing() then N.Relay.clear(M.relay); return end\n', ''),
        ('    if not on and M.relay then N.Relay.clear(M.relay) end\n', ''),
    ]),
    ('spend-own-reserve', 'LayerEnemies/Relay.lua', [
        ('local PREFIX_CAP, PREFIX_REFILL, OWN_RESERVE = 5, 2, 2',
         'local PREFIX_CAP, PREFIX_REFILL, OWN_RESERVE = 5, 2, 0'),
    ]),
]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lua', default='/opt/data/tools/lua/lua-5.1.5/src/lua')
    args = parser.parse_args()
    def run():
        p = subprocess.run([args.lua, 'test/harness.lua', '--relay-policy-only'],
                           cwd=ROOT, capture_output=True, text=True, timeout=120)
        text = p.stdout + p.stderr
        match = re.search(r'RESULT: (\d+) tests passed, (\d+) failed, (\d+) assertions', text)
        assert match, text
        return p.returncode, tuple(map(int, match.groups())), text
    rc, baseline, text = run()
    assert rc == 0 and baseline[1] == 0 and baseline[0] > 0, text
    results = []
    for name, filename, edits in MUTANTS:
        path = ROOT / filename
        original = path.read_bytes()
        mutated = original.decode()
        for before, after in edits:
            assert mutated.count(before) == 1, name
            mutated = mutated.replace(before, after)
        try:
            path.write_text(mutated)
            subprocess.run([str(Path(args.lua).with_name('luac')), '-p', filename], cwd=ROOT, check=True)
            rc, counts, text = run()
            assert counts[0] + counts[1] == baseline[0], (name, counts)
            assert rc != 0 and counts[1] > 0, (name, 'survived', text)
            results.append({'mutant': name, 'failed': counts[1], 'killed': True,
                            'caught_by': [line for line in text.splitlines() if line.startswith('FAIL ')]})
        finally:
            path.write_bytes(original)
    rc, final, text = run()
    assert rc == 0 and final == baseline, text
    print(json.dumps(results, indent=2))
    print('RESULT: %d/%d mutants killed; %d policy tests passed, 0 failed' %
          (len(results), len(MUTANTS), final[0]))

if __name__ == '__main__':
    main()
