"""F2 review-rule mutations, portable and byte-stable; never edits the checkout."""
from pathlib import Path
import argparse
import ast
import json
import os
import re
import runpy
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
HELPERS = runpy.run_path(str(ROOT / 'test/flh_member_mutants.py'))
MUTANTS = [
    ('S1-shared-burst', 'lua', [('LayerEnemies/Wire.lua', 'all.tokens<1+reserve or #allTimes', 'false or #allTimes')]),
    ('S1-shared-minute', 'lua', [('LayerEnemies/Wire.lua', 'or #allTimes>=ALL_MINUTE-reserve', 'or false')]),
    ('S1-shared-accounting', 'lua', [('LayerEnemies/Wire.lua', 'all.tokens=all.tokens-1; allTimes[#allTimes+1]=now', '-- no global accounting')]),
    ('S1-owed-priority', 'lua', [('LayerEnemies/Wire.lua', 'local reserve=tag=="WP" and Wr.FLH_REPLIES or 0', 'local reserve=0')]),
    ('S2-stay-joined', 'lua', [
        ('LayerEnemies/Directory.lua', 'N.Main.sharing() and (joined[key] or N.FLHMember.allowed("WHISPER","WP"))', 'N.FLHMember.allowed("WHISPER","WP")'),
        ('LayerEnemies/Directory.lua', ' and (key~="flh" or calm())', '')]),
    ('S2-defer-unsafe-leave', 'lua', [('LayerEnemies/Directory.lua', ' and (key~="flh" or calm())', '')]),
    ('S3-declined', 'lua', [('LayerEnemies/FLHMember.lua', 'LD="declined",', '')]),
    ('S3-no-answer', 'lua', [('LayerEnemies/FLHMember.lua', 'LA="didn\'t answer",', '')]),
    ('S3-queued', 'lua', [('LayerEnemies/FLHMember.lua', 'HQ="queued you",', '')]),
    ('S3-bare-negative', 'lua', [('LayerEnemies/FLH.lua', 'if cmd=="LN" and #fields==2 then layout={id=2} end', '-- bare LN not understood')]),
    ('S3-one-status-line', 'lua', [('LayerEnemies/FLHMember.lua', 'N.Main.say("LayerEnemies: "..text)', '-- silent decline')]),
    ('N2-named-leader', 'lua', [('LayerEnemies/FLHMember.lua', 'p.asked[leaderKey]={name=leader,at=r.first}', 'p.asked[key]={name=asked.name,at=r.first}')]),
    ('N2-replace-host-authority', 'lua', [('LayerEnemies/FLHMember.lua', 'p.asked={}', 'p.asked=p.asked')]),
    ('N2-original-window', 'lua', [('LayerEnemies/FLHMember.lua', 'return -- preserve r.first and p.at', 'r.first=S.call(GetTime); p.at=r.first\n        return -- preserve r.first and p.at')]),
    ('S4-truthy-extra-route', 'policy', [('LayerEnemies/Wire.lua', 'FLHNET2 = { kinds = { ', 'FLHNET2 = { kinds = { CHANNEL = 1, ')]),
    ('S4-bracket-extra-route', 'policy', [('LayerEnemies/Wire.lua', 'FLHNET2 = { kinds = { ', 'FLHNET2 = { kinds = { ["CHANNEL"] = true, ')]),
    ('S4-post-table-assignment', 'policy', [('LayerEnemies/Wire.lua', 'Wr.ROUTES = {}', 'ROUTES.FLHNET2.kinds.CHANNEL = true\nWr.ROUTES = {}')]),
    ('N1-disclose-cross-realm-introduction', 'policy', [('README.md', 'name, realm, map and layer on its own realm\'s channel', 'name only')]),
    ('N3-normalize-hop-evidence', 'evidence', [('test/hop_fanout_mutants.py', 'result.stdout = normalize(result.stdout, root)', 'result.stdout = result.stdout')]),
    ('N3-no-identical-report-write', 'evidence', [('test/hop_fanout_mutants.py', 'if not path.exists() or path.read_bytes() != data:', 'if True:')]),
]


def run(root, lua, suite):
    command = ([lua, 'test/harness.lua', '--only=FLH member: R2'] if suite == 'lua' else
               ['python3', '-B', '-m', 'unittest', 'test.api_policy_test' if suite == 'policy' else 'test.flh_mutants_test'])
    proc = subprocess.run(command, cwd=root, capture_output=True, text=True, errors='replace', timeout=180)
    output = HELPERS['normalize'](proc.stdout + proc.stderr, root)
    if suite == 'lua':
        match = re.search(r'RESULT: (\d+) tests passed, (\d+) failed, (\d+) assertions', output)
        assert match, output
        passed, failed, assertions = map(int, match.groups())
        diagnostics = [line for line in output.splitlines() if line.startswith('FAIL ')]
        total = passed + failed
    else:
        match = re.search(r'Ran (\d+) tests', output)
        assert match and 'ERROR:' not in output and 'errors=' not in output, output
        total = int(match[1]); assertions = None
        diagnostics = [line for line in output.splitlines() if line.startswith('FAIL:')]
        failed = len(diagnostics)
    return {'rc': proc.returncode, 'tests': total, 'failed': failed,
            'assertions': assertions, 'caught_by': diagnostics}, output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lua', default=os.environ.get('LAYERENEMIES_LUA') or shutil.which('lua5.1') or shutil.which('lua'))
    parser.add_argument('--scratch', default=os.environ.get('TMPDIR') or str(ROOT.parent))
    args = parser.parse_args()
    if not args.lua:
        parser.error('--lua or LAYERENEMIES_LUA must select Lua 5.1')
    with tempfile.TemporaryDirectory(prefix='le-flh-rulings-', dir=Path(args.scratch).resolve()) as tmp:
        root = Path(tmp)
        for folder in ('LayerEnemies', 'test'):
            shutil.copytree(ROOT / folder, root / folder)
        shutil.copy2(ROOT / 'README.md', root / 'README.md')
        baseline = {}
        for suite in ('lua', 'policy', 'evidence'):
            baseline[suite], output = run(root, args.lua, suite)
            assert baseline[suite]['rc'] == 0 and baseline[suite]['failed'] == 0, output
        results = []
        for name, suite, edits in MUTANTS:
            originals = {}
            try:
                for filename, before, after in edits:
                    path = root / filename
                    originals.setdefault(path, path.read_bytes())
                    text = path.read_text()
                    assert text.count(before) == 1, (name, filename, text.count(before))
                    path.write_text(text.replace(before, after))
                for path in originals:
                    if path.suffix == '.lua':
                        subprocess.run([args.lua, '-e', 'assert(loadfile(' + json.dumps(str(path)) + '))'],
                                       cwd=root, capture_output=True, check=True, timeout=30)
                    elif path.suffix == '.py':
                        ast.parse(path.read_text(), filename=str(path))
                result, output = run(root, args.lua, suite)
                assert result['tests'] == baseline[suite]['tests'], (name, output)
                result.update(mutant=name, suite=suite, killed=result['rc'] != 0 and result['failed'] > 0)
                results.append(result)
                print(name + ': ' + ('KILLED' if result['killed'] else 'SURVIVED'), flush=True)
            finally:
                for path, content in originals.items():
                    path.write_bytes(content)
        final = {}
        for suite in baseline:
            final[suite], output = run(root, args.lua, suite)
            assert final[suite] == baseline[suite], output
    report = {'baseline': baseline, 'final': final, 'mutants': results}
    (ROOT / 'notes').mkdir(exist_ok=True)
    HELPERS['write_report'](ROOT / 'notes/flh-rulings-mutants.json', report)
    print('Mutants: %d/%d killed' % (sum(row['killed'] for row in results), len(results)))
    assert all(row['killed'] for row in results), 'surviving mutant'


if __name__ == '__main__':
    main()
