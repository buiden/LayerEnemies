"""Spy relay regression mutants. Local-only; source bytes restored in finally."""
from pathlib import Path
import argparse
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
MUTANTS = [
    ('relay-spy-from-guild', 'LayerEnemies/Relay.lua',
     'local spy = source(record) == "spy"',
     'local spy = source(record) == "spy"\n'
     '    if spy and record.route == "GUILD" then record.route = "PARTY"; record.share = "public" end'),
    ('no-spy-rate-cap', 'LayerEnemies/Relay.lua',
     'if #st.spyTimes >= Rl.SPY_MAX then return false, "spy rate" end',
     '-- missing rolling-minute cap'),
    ('no-per-name-limit', 'LayerEnemies/Relay.lua',
     'if st.spyNames[key] then return false, "spy name" end',
     '-- missing full-name limit'),
    ('origin-is-us', 'LayerEnemies/Relay.lua',
     'src, record.kind, hex(record.origin), rid',
     'src, record.kind, hex(src == "spy" and N.Adapters.ownIdentity() or record.origin), rid'),
    ('spy-layer-included', 'LayerEnemies/Relay.lua',
     'if src == "hh" or src == "spy" then ns, layer = "u", "" end',
     'if src == "hh" then ns, layer = "u", "" end'),
    ('relayed-spy-origin-askable', 'LayerEnemies/Find.lua',
     'and loc.spotter~=nil and not loc.relayed and loc.kind~="claim"',
     'and loc.spotter~=nil'),
    ('spy-stand-down-ignored', 'LayerEnemies/Relay.lua',
     'st.pending[key] = nil\n    remember(st, key, now)',
     'if record.label ~= "spy" then st.pending[key] = nil end\n    remember(st, key, now)'),
]


def run(command):
    proc = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=300)
    output = proc.stdout + proc.stderr
    match = re.search(r'RESULT: (\d+) tests passed, (\d+) failed, (\d+) assertions', output)
    assert match, 'Harness did not reach RESULT:\n' + output
    result = {'passed': int(match[1]), 'failed': int(match[2]), 'rc': proc.returncode,
              'caught_by': [line[5:] for line in output.splitlines() if line.startswith('FAIL ')]}
    return result, output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lua', default='lua')
    args = parser.parse_args()
    command = [args.lua, 'test/harness.lua', '--spy-relay-only']
    baseline, output = run(command)
    assert baseline['rc'] == 0 and baseline['failed'] == 0 and baseline['passed'] > 0, output
    expected = baseline['passed']
    results = []
    for name, filename, before, after in MUTANTS:
        path = ROOT / filename
        original = path.read_bytes()
        text = original.decode()
        assert text.count(before) == 1, (name, 'unique mutation site required', text.count(before))
        try:
            path.write_text(text.replace(before, after))
            result, output = run(command)
            assert result['passed'] + result['failed'] == expected, (name, 'test inventory changed')
            result['mutant'] = name
            result['killed'] = result['rc'] != 0 and result['failed'] > 0
            results.append(result)
            (ROOT / ('build-spy-mutant-' + name + '.log')).write_text(output)
        finally:
            path.write_bytes(original)
    final, output = run(command)
    assert final['rc'] == 0 and final['failed'] == 0 and final['passed'] == expected, output
    (ROOT / 'build-spy-mutants.log').write_text(json.dumps(results, indent=2) + '\n')
    print('| Mutant | Failed tests | Result |')
    print('|---|---:|---|')
    for result in results:
        print('| %s | %d | %s |' % (result['mutant'], result['failed'], 'KILLED' if result['killed'] else 'SURVIVED'))
    print(next(line for line in output.splitlines() if line.startswith('RESULT:')))
    assert len(results) == len(MUTANTS) and all(r['killed'] for r in results), 'Surviving mutant'


if __name__ == '__main__':
    main()
