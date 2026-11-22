"""Round-1 blind-hop lifecycle mutants; private copies and assertion kills only."""
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
    ('single-host-restart', 'HopAny.lua', ' or #all==1', ''),
    ('rotation-cycle', 'HopAny.lua', '(not old or old.cycle~=cycle)', 'true'),
    ('find-join-time', 'Main.lua', 'if changed then N.Find.changed(M.find,g.joinedAt) end', 'if changed then N.Find.changed(M.find,time) end'),
    ('find-seen-admission', 'Find.lua', 'h.seenAt=math.max(h.seenAt or at,at)', 'h.seenAt=nil'),
    ('find-seen-edge', 'Find.lua', 'h.seenAt>=joinedAt', 'h.seenAt>joinedAt'),
    ('find-count-seen', 'Find.lua', 'h.seenAt and h.seenAt>=joinedAt and 0 or h.count+1', 'h.count+1'),
    ('draft-unsent', 'Main.lua', 'or p.auto and "missed"', 'or "missed"'),
    ('invite-observed', 'Main.lua', '        p.invited=inviter', '        -- no invitation observation'),
    ('invite-accepted', 'Main.lua', 'if p.blind then p.accepted=true end', ''),
    ('invite-converted', 'Main.lua', 'invited=g.host,accepted=true', 'invited=g.host'),
    ('invite-watchdog', 'Main.lua', 'if g.blind then M.blindExpired(g.blind) end', ''),
    ('stop-converted', 'Main.lua', ' or (M.auto and M.auto.group and M.auto.group.blind)', ''),
    ('leave-combat', 'Main.lua', 'if A.inCombat() then return end\n    if M.autoHop() and not g.manual', 'if false then return end\n    if M.autoHop() and not g.manual'),
    ('leave-third-member', 'Main.lua', 'if #party.members~=M.BLIND_PARTNERS then M.clearAutoGroup()', 'if false then M.clearAutoGroup()'),
    ('leave-combat-recovery', 'Main.lua', 'if M.auto and M.auto.group and M.auto.group.blind then guarded(M.autoTick) end', ''),
    ('transfer-changed', 'Main.lua', ' or result=="transfer"', ''),
    ('tooltip-disabled', 'UI.lua', '(hop.enabled and hop.detail or hop.reason)', '(hop.detail or hop.reason)'),
    ('auto-off-pending', 'Main.lua', 'if not M.auto.on then M.clearAutoGroup() end', 'if not M.auto.on then M.auto.group=nil end'),
    ('group-clear-pending', 'Main.lua', 'if g and g.blind and not g.manual then M.hopDone() end', ''),
    ('group-clear-player-ask', 'Main.lua', 'if g and g.blind and not g.manual then M.hopDone() end', 'if M.blindPending or g and g.blind then M.hopDone() end'),
    ('expiry-observed-join', 'Main.lua', 'if p.joinedAt then M.hopDone(); return end', ''),
    ('retain-observed-join', 'Main.lua', 'if g.blind then g.blind.joinedAt=g.joinedAt end', ''),
    ('roster-third-member', 'Main.lua', '(not M.wasGrouped or M.auto.group.blind)', '(not M.wasGrouped)'),
]


def run(root):
    return subprocess.run([str(LUA), 'test/harness.lua', '--only', 'Blind'], cwd=root,
                          capture_output=True, text=True, timeout=90)


def main():
    assert LUA, 'Set LAYERENEMIES_LUA to a Lua 5.1 binary'
    results = []
    with tempfile.TemporaryDirectory(prefix='le-blind-', dir=os.environ.get('TMPDIR', ROOT)) as temp:
        root = Path(temp)
        for folder in ('LayerEnemies', 'test'):
            shutil.copytree(ROOT / folder, root / folder, ignore=shutil.ignore_patterns('__pycache__'))
        baseline = run(root)
        assert baseline.returncode == 0, baseline.stdout + baseline.stderr
        print(next(s for s in baseline.stdout.splitlines() if s.startswith('RESULT:')), flush=True)
        for rule, filename, old, new in MUTANTS:
            target = root / 'LayerEnemies' / filename
            original = target.read_text()
            assert original.count(old) == 1, (rule, original.count(old))
            target.write_text(original.replace(old, new, 1))
            try:
                subprocess.run([str(LUA), '-e', f'assert(loadfile("LayerEnemies/{filename}"))'],
                               cwd=root, check=True, capture_output=True)
                result = run(root)
                failures = [re.sub(r'0x[0-9a-fA-F]+', '0xADDR', s) for s in result.stdout.splitlines()
                            if s.startswith('FAIL ') and ('expected' in s or 'not equal' in s)]
                caught = result.returncode != 0 and bool(failures)
                results.append({'rule': rule, 'caught': caught, 'assertions': failures})
                print(('CAUGHT ' if caught else 'SURVIVED ') + rule, flush=True)
            finally:
                target.write_text(original)
    (ROOT / 'notes/blind-hop-mutants.json').write_text(json.dumps(results, indent=2) + '\n')
    caught = sum(r['caught'] for r in results)
    print(f'RESULT: {caught}/{len(results)} BlindHop mutants killed', flush=True)
    assert caught == len(results), [r['rule'] for r in results if not r['caught']]


if __name__ == '__main__':
    main()
