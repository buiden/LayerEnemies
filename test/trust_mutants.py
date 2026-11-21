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
    ('we-own-only', 'if not own then return text end', 'if false then return text end'),
    ('we-known-control', 'if key and key==L.key(queued) then return text end', 'if false then return text end'),
    ('we-mask-C', '^(C|[^|]*|[^|]*|[^|]*|[^|]*|)', '^(X|[^|]*|[^|]*|[^|]*|[^|]*|)'),
    ('we-mask-H', '^(H|[^|]*|[^|]*|)', '^(X|[^|]*|[^|]*|)'),
    ('npc-key-match', 'id and id==T.own(s,now)', 'id'),
    ('fresh-after-join', 't.npcAt>joinedAt', 't.npcAt>=joinedAt'),
    ('fresh-clock', 'and now>=t.npcAt', ''),
    ('fresh-expiry', 'now-t.npcAt<T.EXPIRE', 'now-t.npcAt<=T.EXPIRE'),
    ('fresh-current-key', 'and t.npcKey==T.own(s,now)', ''),
    ('hop-fresh', 'if not T.fresh(s,now,joinedAt) then t.hops={}; return end', 'if false then t.hops={}; return end'),
    ('group-fresh', 'if not T.fresh(s,now,joinedAt) or not claimAt', 'if false or not claimAt'),
    ('group-claim-after-join', 'claimAt<=joinedAt', 'claimAt<joinedAt'),
    ('group-claim-clock', 'or claimAt>now', ''),
    ('group-claim-expiry', 'now-claimAt>=T.EXPIRE', 'now-claimAt>T.EXPIRE'),
    ('coalesce-key', 'key==t.changeKey', 'true'),
    ('coalesce-source', 'key==t.changeKey and ', 'key==t.changeKey and source~=t.changeSource and '),
    ('coalesce-window-edge', 'now>=t.changeAt then return false end', 'now>=t.changeAt and now-t.changeAt<T.EXCUSE_WINDOW then return false end'),
    ('coalesce-window-late', 'now>=t.changeAt then return false end', 'now>=t.changeAt and now-t.changeAt<=T.EXCUSE_WINDOW+1 then return false end'),
    ('coalesce-clock', 'and now>=t.changeAt', ''),
    ('notice-manual', 'if manual then n.pending=nil; n.autoBlind=nil; return end', 'if false then n.pending=nil; n.autoBlind=nil; return end'),
    ('notice-once', 'if current~=old then', 'if true then'),
    ('notice-blind', 'if current=="blind" and state(s).blind~="manual" then', 'if false then'),
    ('notice-recovery', 'elseif current=="known" and n.autoBlind then', 'elseif false then'),
    ('notice-rate', 'now-n.at>=T.NOTICE_EVERY', 'true'),
    ('notice-rate-edge', 'now-n.at>=T.NOTICE_EVERY', 'now-n.at>T.NOTICE_EVERY'),
    ('group-peer-admission', 'or not peerJoinedAt or claimAt<=peerJoinedAt', ''),
    ('group-peer-admission-edge', 'claimAt<=peerJoinedAt', 'claimAt<peerJoinedAt'),
    ('we-current-key', 'key and key==L.key(queued)', 'key'),
    ('coalesce-delay-cap', 'now>=t.changeAt then return false end', 'now>=t.changeAt and now-t.changeAt<=T.EXCUSE_WINDOW then return false end'),
    ('notice-pair-required', 'and n.autoBlind then', 'then'),
    ('notice-pair-consumed', 'n.autoBlind=current=="blind"', 'n.autoBlind=true'),
    ('notice-pair-emitted', 'n.pending="LayerEnemies: layer IDs look unreliable', 'n.autoBlind=true; n.pending="LayerEnemies: layer IDs look unreliable'),
    ('notice-pair-manual-clear', 'n.pending=nil; n.autoBlind=nil; return end', 'n.pending=nil; return end'),
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
