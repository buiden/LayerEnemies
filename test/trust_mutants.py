"""Trust-only behavioral mutants; private copies, syntax checked, assertion kills only."""
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
    ('blind-reader', 'if t.blind then return "blind" end', 'if false then return "blind" end'),
    ('expiry-late', 'now-t.at<T.EXPIRE', 'now-t.at<=T.EXPIRE'),
    ('expiry-early', '=300,20,10', '=299,20,10'),
    ('clock-rollback', 'now>=t.at and ', ''),
    ('own-state-gate', 'if T.state(s,now)=="known" then', 'if s then'),
    ('bulo-boundary', 'if id==blocked and ', 'if false and '),
    ('mask-in-blind', 'if not hide and T.state(s,now)~="blind" then return record end', 'if not hide then return record end'),
    ('mask-copy', 'local out={}; for k,v in pairs(record) do out[k]=v end', 'local out=record'),
    ('manual-on', 'state(s).blind="manual"', 'state(s).blind=nil'),
    ('manual-off', 'local at=state(s).at; s.trust=T.new(); s.trust.at=at', 'local at=state(s).at; s.trust.at=at'),
    ('cold-early', '=300,20,10', '=300,19,10'),
    ('cold-late', '=300,20,10', '=300,21,10'),
    ('streak-early', '=300,20,10', '=300,20,9'),
    ('streak-late', '=300,20,10', '=300,20,11'),
    ('success-reset', 't.success=true; t.failures=0', 't.success=true'),
    ('churn-early', '=3,600,10', '=2,600,10'),
    ('churn-late', '=3,600,10', '=4,600,10'),
    ('churn-window', 'now-t.changes[i]>=T.CHANGE_WINDOW', 'now-t.changes[i]>T.CHANGE_WINDOW'),
    ('excuse-edge', 'now-t.excusedAt<=T.EXCUSE_WINDOW', 'now-t.excusedAt<T.EXCUSE_WINDOW'),
    ('no-excuse', 'if t.excusedAt and ', 'if false and '),
    ('hop-early', 'T.HOPS,T.GROUP_SECONDS=3,60', 'T.HOPS,T.GROUP_SECONDS=2,60'),
    ('hop-late', 'T.HOPS,T.GROUP_SECONDS=3,60', 'T.HOPS,T.GROUP_SECONDS=4,60'),
    ('hop-formed', 'not formed or ', ''),
    ('hop-full-key', 'local valid=L.key(before) and L.key(after)', 'before,after=L.key(before),L.key(after); local valid=before and after'),
    ('hop-movement', 'or before~=after', ''),
    ('hop-distinct', 'if names[name] then return end;', 'if false then return end;'),
    ('group-early', 'T.HOPS,T.GROUP_SECONDS=3,60', 'T.HOPS,T.GROUP_SECONDS=3,59'),
    ('group-late', 'T.HOPS,T.GROUP_SECONDS=3,60', 'T.HOPS,T.GROUP_SECONDS=3,61'),
    ('group-outdoors', 'not outdoors or ', ''),
    ('group-same', 'or own==claim', ''),
    ('group-continuity', 'g.peer~=peer or ', ''),
]


def run(root):
    return subprocess.run([str(LUA), 'test/harness.lua', '--only', 'Trust'], cwd=root,
                          capture_output=True, text=True, timeout=90)


def main():
    assert LUA, 'Set LAYERENEMIES_LUA to a Lua 5.1 binary'
    results = []
    with tempfile.TemporaryDirectory(prefix='le-trust-', dir=os.environ.get('TMPDIR', ROOT)) as temp:
        root = Path(temp)
        for folder in ('LayerEnemies', 'test'):
            shutil.copytree(ROOT / folder, root / folder, ignore=shutil.ignore_patterns('__pycache__'))
        baseline = run(root)
        assert baseline.returncode == 0, baseline.stdout + baseline.stderr
        print(next(s for s in baseline.stdout.splitlines() if s.startswith('RESULT:')), flush=True)
        target = root / 'LayerEnemies/Trust.lua'
        original = target.read_text()
        for rule, old, new in MUTANTS:
            assert original.count(old) == 1, (rule, original.count(old))
            target.write_text(original.replace(old, new, 1))
            try:
                subprocess.run([str(LUA), '-e', 'assert(loadfile("LayerEnemies/Trust.lua"))'],
                               cwd=root, check=True, capture_output=True)
                result = run(root)
                failures = [re.sub(r'0x[0-9a-fA-F]+', '0xADDR', s) for s in result.stdout.splitlines()
                            if s.startswith('FAIL ') and ('expected' in s or 'not equal' in s)]
                caught = result.returncode != 0 and bool(failures)
                results.append({'rule': rule, 'caught': caught, 'assertions': failures})
                print(('CAUGHT ' if caught else 'SURVIVED ') + rule, flush=True)
            finally:
                target.write_text(original)
    (ROOT / 'notes/trust-mutants.json').write_text(json.dumps(results, indent=2) + '\n')
    caught = sum(r['caught'] for r in results)
    print(f'RESULT: {caught}/{len(results)} Trust mutants killed', flush=True)
    assert caught == len(results), [r['rule'] for r in results if not r['caught']]


if __name__ == '__main__':
    main()
