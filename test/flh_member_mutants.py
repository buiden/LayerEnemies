"""F2 safety mutants: isolated copies, configurable Lua/scratch, deterministic JSON."""
from pathlib import Path
import argparse
import json
import os
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
# Each entry removes one rule; redundant guard sites are changed together.
MUTANTS = [
    ('reply-sender-gap', [('Wire.lua', 'Wr.FLH_NAME = 6, 4, 60, 600', 'Wr.FLH_NAME = 6, 4, 0, 600')]),
    ('reply-total-cap', [('Wire.lua', 'Wr.FLH_NAME = 6, 4, 60, 600', 'Wr.FLH_NAME = 7, 4, 60, 600')]),
    ('probe-total-cap', [('Wire.lua', 'Wr.FLH_NAME = 6, 4, 60, 600', 'Wr.FLH_NAME = 6, 5, 60, 600')]),
    ('probe-name-gap', [('Wire.lua', 'Wr.FLH_NAME = 6, 4, 60, 600', 'Wr.FLH_NAME = 6, 4, 60, 0'), ('FLHMember.lua', 'if now-at>=600 then probed[k]=nil end', 'if now-at>=0 then probed[k]=nil end')]),
    ('probe-window', [('FLHMember.lua', 'return F.windowOpen() and not', 'return true and not')]),
    ('probe-during-fanout', [('FLHMember.lua', 'return F.windowOpen() and not (M.hopAnyState and M.hopAnyState.round) and not M.asking()', 'return F.windowOpen()')]),
    ('host-flag', [('FLH.lua', 'fields={cmd,map,own,"0",version,realm}', 'fields={cmd,map,own,"1",version,realm}')]),
    ('presence-rate', [('Wire.lua', 'now-flhHi[lane]<120', 'now-flhHi[lane]<119')]),
    ('presence-change-driven', [('FLHMember.lua', 'and announced[kind]~=text', '')]),
    ('group-presence-lane', [('Wire.lua', 'kind=="GUILD" and "GUILD" or "GROUP"', 'kind')]),
    ('identity-is-layerenemies', [('FLH.lua', 'fields={cmd,map,own,"0",version,realm}', 'fields={cmd,map,own,"0","0.1.3",realm}')]),
    ('honest-build-marker', [('FLH.lua', 'fields[#fields+1]="BUILD="..version', 'fields[#fields+1]="BUILD=ForeverLayerHop 0.1.9"')]),
    ('share-off', [('FLHMember.lua', ' or not M.sharing()', '')]),
    ('guild-consent', [('FLHMember.lua', 'elseif N.Net.consent()~="public" then return false end', 'elseif false then return false end')]),
    ('network-switch', [('FLHMember.lua', ' or not N.Net.switch("flh")', '')]),
    ('combat-gate', [('FLHMember.lua', 'A.inCombat() or A.inInstance()~=false', 'A.inInstance()~=false'), ('Main.lua', 'if A.inCombat() or A.inInstance()~=false then return end', 'if A.inInstance()~=false then return end')]),
    ('instance-gate', [('FLHMember.lua', 'A.inCombat() or A.inInstance()~=false', 'A.inCombat()'), ('Main.lua', 'if A.inCombat() or A.inInstance()~=false then return end', 'if A.inCombat() then return end')]),
    ('stand-down', [('FLHMember.lua', 'and A.loaded("ForeverLayerHop")', 'and false')]),
    ('directory-slots', [('Directory.lua', 'local limited = key=="wanted" or key=="flh"', 'local limited = key=="wanted"')]),
    ('directory-consent', [('Directory.lua', 'if key=="flh" then want=want and N.FLHMember.allowed("WHISPER","WP") end', 'if key=="flh" then want=true end')]),
    ('owed-reserve', [('Wire.lua', '#recent(publicTimes,now)<PUBLIC_MINUTE-Wr.FLH_REPLIES', '#recent(publicTimes,now)<PUBLIC_MINUTE')]),
    ('public-total-cap', [('Wire.lua', 'if kind=="WHISPER" and #publicTimes>=PUBLIC_MINUTE then return false end', 'if false then return false end')]),
    ('public-per-person-cap', [('Wire.lua', 'if kind=="WHISPER" and #(publicTo[key] or {})>=PUBLIC_ONE then return false end', 'if false then return false end')]),
    ('independent-fanout-budget', [('Wire.lua', 'if prefix == "FLHNET2" then\n        if not flhBudget', 'if prefix == "FLHNET2" then\n        hopBucket.tokens=hopBucket.tokens-1\n        if not flhBudget')]),
    ('one-selection', [('FLHMember.lua', 'm.cmd~="LO" or r.selected or m.map', 'm.cmd~="LO" or m.map')]),
    ('request-id', [('FLHMember.lua', 'if not asked or m.id~=r.id then return end', 'if not asked then return end')]),
    ('offer-map', [('FLHMember.lua', ' or m.map~=r.map', '')]),
    ('offer-target-key', [('FLHMember.lua', ' or not sameKey(m.key,asked.key)', '')]),
    ('offer-window', [('FLHMember.lua', 'F.WAIT=90', 'F.WAIT=91')]),
    ('timeout-detail', [('FLHMember.lua', 'FLH request timed out (90 s)', 'FLH request ended')]),
    ('selected-target-only', [('FLHMember.lua', 'asked={[key]={name=asked.name,at=r.first}}', 'asked=r.asked')]),
    ('selection-after-success', [('FLHMember.lua', 'if sent then\n        -- Reuse', 'if true then\n        -- Reuse')]),
    ('guest-zone', [('FLHMember.lua', ' or c.map~=r.map', '')]),
    ('guest-own-key', [('FLHMember.lua', ' or not sameKey(c.key,r.own)', '')]),
    ('stale-preview', [('FLHMember.lua', 'if row and (live.name~=row.name', 'if false and row and (live.name~=row.name')]),
    ('batch-cap-reserves-lr', [('FLHMember.lua', '#targets>=N.HopAny.CAP-1', '#targets>=N.HopAny.CAP')]),
    ('no-saved-switch', [('Net.lua', 'if not Net.LIST[key].session then persisted[key]=on end', 'persisted[key]=on')]),
    ('general-host-flag', [('Invite.lua', 'c={name=name,short=key,age=age,host=false,hosts={}', 'c={name=name,short=key,age=age,host=true,hosts={}')]),
    ('private-flight-payload', [('FLHMember.lua', ' or q.target~=target', '')]),
    ('one-flight-use', [('FLHMember.lua', ' or q.used', '')]),
    ('share-off-on-revocation', [('Main.lua', '; N.FLHMember.stop("share off")', '')]),
    ('network-off-on-revocation', [('Net.lua', 'if key=="flh" and on~=true then N.FLHMember.stop("network off") end', '-- removed')]),
    ('consent-off-on-revocation', [('Net.lua', 'if level~="public" and N.FLHMember then N.FLHMember.stop("guild only") end', '-- removed')]),
    ('other-hop-exclusion', [('Main.lua', 'if N.FLHMember.pending() then\n        M.say', 'if false then\n        M.say')]),
    ('no-peer-name-disclosure', [('FLH.lua', 'fields={cmd,rid,map,key,own,""}', 'fields={cmd,rid,map,key,own,"8"}')]),
    ('no-channel-send', [('Wire.lua', 'FLHNET2 = { kinds = { GUILD = true', 'FLHNET2 = { kinds = { CHANNEL = true, GUILD = true')]),
    ('no-host-offer-route', [('Wire.lua', 'or m.cmd=="LQ" or m.cmd=="LR")', 'or m.cmd=="LQ" or m.cmd=="LR" or m.cmd=="LO")')]),
]


def run(root, lua, policy=False):
    cmd = (['python3', '-m', 'unittest', 'test.api_policy_test.ApiPolicyTests.test_flh_routes_are_only_the_four_approved_routes']
           if policy else [lua, 'test/harness.lua', '--only=FLH member:'])
    p = subprocess.run(cmd, cwd=root, text=True, capture_output=True, timeout=180)
    output = p.stdout + p.stderr
    if policy:
        return {'rc': p.returncode, 'failed': int(p.returncode != 0),
                'caught_by': ['F2 route/API policy'] if p.returncode else []}, output
    match = re.search(r'RESULT: (\d+) tests passed, (\d+) failed, (\d+) assertions', output)
    assert match, 'incomplete fixture run:\n' + output
    return {'rc': p.returncode, 'passed': int(match[1]), 'failed': int(match[2]),
            'assertions': int(match[3]),
            'caught_by': [line[5:] for line in output.splitlines() if line.startswith('FAIL ')]}, output


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--lua', default=os.environ.get('LAYERENEMIES_LUA') or shutil.which('lua5.1') or shutil.which('lua'))
    p.add_argument('--scratch', default=os.environ.get('TMPDIR') or str(ROOT.parent))
    args = p.parse_args()
    if not args.lua:
        p.error('--lua or LAYERENEMIES_LUA must select Lua 5.1')
    with tempfile.TemporaryDirectory(prefix='le-flh-member-mutants-', dir=args.scratch) as tmp:
        root = Path(tmp)
        for name in ('LayerEnemies', 'test'):
            shutil.copytree(ROOT / name, root / name)
        baseline, out = run(root, args.lua)
        assert baseline['rc'] == 0 and baseline['failed'] == 0 and baseline['passed'] > 0, out
        policy, out = run(root, args.lua, True)
        assert policy['rc'] == 0, out
        results = []
        for name, edits in MUTANTS:
            originals = {}
            try:
                for filename, before, after in edits:
                    path = root / 'LayerEnemies' / filename
                    originals.setdefault(path, path.read_bytes())
                    text = path.read_text()
                    assert text.count(before) == 1, (name, filename, text.count(before))
                    path.write_text(text.replace(before, after))
                result, out = run(root, args.lua, name == 'no-channel-send')
                if 'passed' in result:
                    assert result['passed'] + result['failed'] == baseline['passed'], (name, out)
                result.update(mutant=name, killed=result['rc'] != 0 and result['failed'] > 0)
                results.append(result)
                print(name + ': ' + ('KILLED' if result['killed'] else 'SURVIVED'))
            finally:
                for path, content in originals.items():
                    path.write_bytes(content)
        final, out = run(root, args.lua)
        assert final == baseline, out
    report = {'baseline': baseline, 'mutants': results, 'final': final}
    (ROOT / 'notes').mkdir(exist_ok=True)
    (ROOT / 'notes/flh-member-mutants.json').write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
    print(next(line for line in out.splitlines() if line.startswith('RESULT:')))
    print('Mutants: %d/%d killed' % (sum(x['killed'] for x in results), len(MUTANTS)))
    assert all(x['killed'] for x in results), 'surviving mutant'


if __name__ == '__main__':
    main()
