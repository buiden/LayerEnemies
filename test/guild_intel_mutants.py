"""Local regression mutants; every source edit is restored in a finally block."""
from pathlib import Path
import argparse
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
MUTANTS = [
    ('boundary-wipes-memory', 'LayerEnemies/Find.lua', 'st.epoch=st.epoch+1',
     'st.epoch=st.epoch+1; st.known=N.Known.new(); st.locations={}'),
    ('retention-unbounded', 'LayerEnemies/Known.lua', 'TTL=3600,MAX=300', 'TTL=3600000000,MAX=300'),
    ('name-cap-unbounded', 'LayerEnemies/Known.lua', 'TTL=3600,MAX=300', 'TTL=3600,MAX=300000000'),
    ('ask-relayed-claim', 'LayerEnemies/Find.lua', 'and loc.spotter~=nil and not loc.relayed and loc.kind~="claim"',
     'and loc.spotter~=nil'),
    ('ask-last-known', 'LayerEnemies/Find.lua',
     'row.canAsk=not row.same and not row.travel and not row.lastKnown and not loc.own',
     'row.canAsk=not row.same and not row.travel and not loc.own'),
    ('cache-saved', 'LayerEnemies/Main.lua',
     'LayerEnemiesDB.tracked=M.find.names\n    if #M.find.names==0',
     'LayerEnemiesDB.tracked=M.find.names; LayerEnemiesDB.known=M.find.known\n    if #M.find.names==0'),
]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--lua', default='lua')
    args = parser.parse_args()
    command = [args.lua, 'test/harness.lua']
    baseline = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    assert baseline.returncode == 0, baseline.stdout + baseline.stderr
    results = []
    for name, filename, before, after in MUTANTS:
        path = ROOT / filename
        original = path.read_bytes()
        text = original.decode()
        assert text.count(before) == 1, (name, text.count(before))
        try:
            path.write_text(text.replace(before, after))
            run = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
            output = run.stdout + run.stderr
            (ROOT / ('build-guild-intel-mutant-' + name + '.log')).write_text(output)
            count = re.search(r'RESULT: (\d+) tests passed, (\d+) failed, (\d+) assertions', output)
            assert count, (name, 'mutant did not reach the test result', output)
            result = {'mutant': name, 'failed': int(count[2]), 'rc': run.returncode,
                      'caught_by': [line.split(': test/')[0][5:] for line in output.splitlines() if line.startswith('FAIL ')]}
            results.append(result)
            print(json.dumps(result))
            assert run.returncode != 0 and result['failed'] > 0, name + ' survived'
        finally:
            path.write_bytes(original)
    final = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    assert final.returncode == 0, final.stdout + final.stderr
    print(next(line for line in final.stdout.splitlines() if line.startswith('RESULT:')))
    (ROOT / 'build-guild-intel-mutants.log').write_text(json.dumps(results, indent=2) + '\n')


if __name__ == '__main__':
    main()
