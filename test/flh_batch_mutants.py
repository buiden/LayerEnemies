"""R3 batch-hop/route mutants; isolated copies, portable byte-stable reports."""
from pathlib import Path
import argparse
import ast
import json
import os
import re
import runpy
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
HELPERS = runpy.run_path(str(ROOT / 'test/flh_member_mutants.py'))
normalize, write_report = HELPERS['normalize'], HELPERS['write_report']
MEMBER, WIRE, GATE = 'LayerEnemies/FLHMember.lua', 'LayerEnemies/Wire.lua', 'test/verify.py'
READ = 'local route = type(prefix) == "string" and ROUTES[prefix]'
MUTANTS = [
    ('reserve-query-token', 'lua', [(WIRE, 'reserve=math.max(reserve,tag~="LR" and flhReserve(now) or 0)', 'reserve=reserve')]),
    ('reserve-ordinary-token', 'lua', [(WIRE, 'local reserve = flhReserve(now)', 'local reserve = 0')]),
    ('reserve-minute-slot', 'lua', [(WIRE, '#allTimes>=ALL_MINUTE-reserve', '#allTimes>=ALL_MINUTE')]),
    ('pace-unsent-queries', 'lua', [(MEMBER, '        else queries(r) end', '        else end')]),
    ('release-after-LR', 'lua', [(MEMBER, 'r and not r.selected and now>=r.at', 'r and now>=r.at')]),
    ('release-at-expiry', 'lua', [(MEMBER, ' and now-r.at<F.WAIT and 1 or 0', ' and 1 or 0')]),
    ('retry-unspent-selection', 'lua', [(MEMBER, '        r.retry=true', '        r.selected=key; r.retry=true')]),
    ('two-retries-only', 'lua', [(MEMBER, 'local LR_RETRIES=2', 'local LR_RETRIES=3')]),
    ('retry-only-with-room', 'lua', [(MEMBER, 'r.retry and N.Wire.flhClickReady("LR",r.offer.name,now)', 'r.retry')]),
    ('original-LR-window', 'lua', [(MEMBER, 'r.selected=key; r.retry=nil -- only a successful LR', 'r.first=S.call(GetTime); r.selected=key; r.retry=nil -- only a successful LR')]),
    ('original-paced-window', 'lua', [(MEMBER, 'if sent then r.first=r.at; r.asked[v.short]=v end', 'if sent then r.first=now; r.asked[v.short]=v end')]),
    ('failure-chat-line', 'lua', [(MEMBER, 'N.Main.say("LayerEnemies: hop request to "..r.offer.name.." could not be sent (send limit); click again")', '-- silent failure')]),
    ('failure-row-note', 'lua', [(MEMBER, 'FLH invite request refused (send limit)', 'FLH invite request refused')]),
    ('pending-host-binding', 'lua', [(MEMBER, 'm.cmd~="LO" or r.selected or r.offer or m.map', 'm.cmd~="LO" or r.selected or m.map')]),
    ('offline-query-head', 'lua', [(MEMBER, 'if N.Wire.offlineUntil(v.name,now) then', 'if false then')]),
    ('route-loop-over-alias', 'policy', [(WIRE, READ, READ + '\n    if route then for _, value in pairs(route) do if type(value) == "table" then value.CHANNEL = true end end end')]),
    ('route-computed-new-prefix', 'policy', [(WIRE, READ, READ + '\n    if prefix == "ReviewPrefix" then local key = "ki" .. "nds"; route = { [key] = { GUILD = true }, check = function() return "line" end } end')]),
    ('route-computed-channel', 'policy', [(WIRE, READ, READ + '\n    if prefix == "FLHNET2" and kind == "CHANNEL" then local key = "ki" .. "nds"; route = { [key] = { CHANNEL = true }, check = route.check } end')]),
    ('gate-alias-freeze', 'policy', [(GATE, "('ROUTES', 'kinds', 'route', 'check')", "('ROUTES', 'kinds')")]),
    ('route-expression-new-prefix', 'policy', [(WIRE, READ,
        'local fieldA="ki".."nds"; local fieldB="ch".."eck"\n    ' + READ +
        ' or (prefix=="ReviewPrefix" and { [fieldA]={GUILD=true}, [fieldB]=function() return "line" end })')]),
    ('route-expression-channel', 'policy', [(WIRE, READ,
        'local fieldA="ki".."nds"; local fieldB="ch".."eck"\n    ' + READ +
        ' and kind~="CHANNEL" or (prefix=="FLHNET2" and { [fieldA]={CHANNEL=true}, [fieldB]=function() return "line" end })')]),
    ('route-debug-upvalue', 'policy', [(WIRE, READ,
        'local _, captured=debug.getupvalue(Wr.send,1); debug.setupvalue(Wr.send,1,captured)\n    ' + READ)]),
    ('query-current-host-key', 'lua', [(MEMBER,
        'if not eligible(live,F.context()) or not sameKey(live.flhKey,v.key) then',
        'if false then'), (MEMBER,
        'v.key=live.flhKey -- same layer, but use the host\'s current wire key',
        '-- retain the click-time key')]),
    ('join-event-revokes-click', 'lua', [('LayerEnemies/Main.lua',
        'if grouped then N.FLHMember.stop("joined a group") end',
        '-- only poll group state at the next tick')]),
    ('query-reentrant-cursor', 'lua', [(MEMBER,
        'if r.sending then return end -- synchronous client hooks must not consume the cursor',
        '-- no in-progress guard')]),
    ('stop-inflight-name-cooldown', 'lua', [(MEMBER,
        'if sent or attempted then N.Main.invite.asked[v.short]=now end',
        'if guest==r and (sent or attempted) then N.Main.invite.asked[v.short]=now end')]),
]


def run(root, lua, suite='lua'):
    command = ([lua, 'test/harness.lua', '--only=FLH batch:'] if suite == 'lua' else
               [sys.executable, '-B', '-m', 'unittest', 'test.api_policy_test'])
    proc = subprocess.run(command, cwd=root, capture_output=True, text=True, errors='replace', timeout=1800)
    output = normalize(proc.stdout + proc.stderr, root)
    if suite == 'lua':
        match = re.search(r'RESULT: (\d+) tests passed, (\d+) failed, (\d+) assertions', output)
        assert match, 'incomplete fixture run:\n' + output
        passed, failed, assertions = map(int, match.groups())
        total = passed + failed
        diagnostics = [line for line in output.splitlines() if line.startswith('FAIL ')]
        assert not any('attempt to ' in line or 'instruction ceiling' in line for line in diagnostics), output
    else:
        match = re.search(r'Ran (\d+) tests', output)
        assert match and 'ERROR:' not in output and 'errors=' not in output, output
        total, assertions = int(match[1]), None
        diagnostics = [line for line in output.splitlines() if line.startswith('FAIL:')]
        failed = len(diagnostics)
    return {'rc': proc.returncode, 'tests': total, 'failed': failed,
            'assertions': assertions, 'caught_by': diagnostics}, output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lua', default=os.environ.get('LAYERENEMIES_LUA') or shutil.which('lua5.1') or shutil.which('lua'))
    parser.add_argument('--scratch', default=os.environ.get('TMPDIR') or str(ROOT.parent))
    parser.add_argument('--only', help='one exact mutant name (portable smoke test)')
    parser.add_argument('--report', default='notes/flh-batch-mutants.json', help='checkout-relative report')
    args = parser.parse_args()
    if not args.lua:
        parser.error('--lua or LAYERENEMIES_LUA must select Lua 5.1')
    mutants = [m for m in MUTANTS if not args.only or m[0] == args.only]
    assert mutants, 'unknown mutant'
    with tempfile.TemporaryDirectory(prefix='le-flh-batch-', dir=Path(args.scratch).resolve()) as tmp:
        root = Path(tmp)
        for folder in ('LayerEnemies', 'test'):
            shutil.copytree(ROOT / folder, root / folder)
        shutil.copy2(ROOT / 'README.md', root / 'README.md')
        baseline = {}
        for suite in ('lua', 'policy'):
            baseline[suite], output = run(root, args.lua, suite)
            assert baseline[suite]['rc'] == 0 and baseline[suite]['failed'] == 0, output
        results = []
        for name, suite, edits in mutants:
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
    report = ROOT / args.report
    report.parent.mkdir(parents=True, exist_ok=True)
    write_report(report, {'baseline': baseline, 'final': final, 'mutants': results})
    print('Mutants: %d/%d killed' % (sum(row['killed'] for row in results), len(results)))
    assert all(row['killed'] for row in results), 'surviving mutant'


if __name__ == '__main__':
    main()
