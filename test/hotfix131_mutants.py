"""Hotfix regression mutants; isolated copies, syntax check, assertion kills only."""
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
    ('peer-unreadable-realm-as-absent', 'Adapters.lua', 'if realm~=nil and (S.secret(realm) or realm~="" and not explicit) then return nil end', '', 'Realm audit:'),
    ('realm-required-again', 'Adapters.lua', 'if not name then return nil end\n    local _,key,full=N.Invite.name(name)', 'if not name or not home then return nil end\n    local _,key,full=N.Invite.name(name)', 'Realm-less:'),
    ('secret-second-cleaned-to-alias', 'Adapters.lua', 'local ok,name,second=pcall(UnitName,"player")', 'local name,second=S.call(UnitName,"player"); local ok=true', 'Realm-less:'),
    ('foreign-realm-stripped', 'Invite.lua', 'if home and norm(realm)==norm(home) then', 'if true then', 'Realm-less:'),
    ('single-name-refused', 'Adapters.lua', 'if not key or key:find("-",1,true) then return nil end', 'if not key or not key:find(" ",1,true) or key:find("-",1,true) then return nil end', 'Realm-less:'),
    ('combined-name-refused', 'Adapters.lua', 'if not key or key:find("-",1,true) then return nil end', 'if not key or key:find(" ",1,true) or key:find("-",1,true) then return nil end', 'Realm-less:'),
    ('flh-realm-required', 'FLHMember.lua', 'S.str(S.call(GetRealmName),60) or "?"', 'S.str(S.call(GetRealmName),60)', 'Realm audit:'),
    ('peer-home-required', 'Adapters.lua', 'if not N.Invite.name(identity) then return nil end', 'if not world or not N.Invite.name(identity) then return nil end', 'Realm audit:'),
    ('sighting-realm-required', 'Store.lua', 'if e.name then\n        local hash=N.Hash.player(e.name,e.realm)', 'if e.name and e.realm then\n        local hash=N.Hash.player(e.name,e.realm)', 'Realm audit:'),
    ('rules-fallback-removed', 'Directory.lua', 'local pool=N.Main and N.Main.overlordPool()\n    return ({global=', 'local pool=nil\n    return ({global=', 'Realm audit:'),
    ('wanted-home-required', 'Wanted.lua', 'or (home and realm(peer.realm)~=home)', 'or not home or realm(peer.realm)~=home', 'Realm audit:'),
    ('build-number-return', 'Adapters.lua', 'local _,build=S.call(GetBuildInfo)', 'local _,_,build=S.call(GetBuildInfo)', 'Trust build:'),
    ('build-integer-check', 'Adapters.lua', 'value>0 and value%1==0', 'value>0', 'Trust build:'),
    ('build-cutoff-late', 'Trust.lua', 'T.HIDDEN_ID_BUILD=71037', 'T.HIDDEN_ID_BUILD=71038', 'Trust build:'),
    ('build-cutoff-early', 'Trust.lua', 'T.HIDDEN_ID_BUILD=71037', 'T.HIDDEN_ID_BUILD=71036', 'Trust build:'),
    ('build-edge-exclusive', 'Trust.lua', 'build>=T.HIDDEN_ID_BUILD', 'build>T.HIDDEN_ID_BUILD', 'Trust build:'),
    ('build-startup-unbound', 'Main.lua', 'M.store.trust=N.Trust.new(A.build())', 'M.store.trust=N.Trust.new()', 'Trust build:'),
    ('build-manual-override', 'Trust.lua', 'if T.hidden(s) then return mode=="on" or mode=="off" or mode=="auto" end', 'if false then return true end', 'Trust build:'),
    ('build-read-unguarded', 'Trust.lua', 'if T.hidden(s) then return end\n    s.bulo=L.key(id)', 's.bulo=L.key(id)', 'Trust build:'),
    ('build-bulo-unguarded', 'Trust.lua', 'if T.hidden(s) then return nil end\n    local id=snap.current', 'local id=snap.current', 'Trust build:'),
    ('build-apply-unguarded', 'Main.lua', 'if N.Trust.hidden(M.store) or not L.key(id) then return end', 'if not L.key(id) then return end', 'Trust build:'),
    ('build-npc-unguarded', 'Main.lua', 'if N.Trust.hidden(M.store) then return end', '', 'Trust build:'),
    ('build-creature-reason-clobbered', 'Trust.lua', 'function T.creature(s,parsed)\n    if T.hidden(s) then return end', 'function T.creature(s,parsed)', 'Trust build:'),
    ('build-churn-reason-clobbered', 'Trust.lua', 'function T.change(s,now,key,source)\n    if T.hidden(s) then return false end', 'function T.change(s,now,key,source)', 'Trust build:'),
    ('build-notice-offered-override', 'Trust.lua', 'if T.hidden(s) then n.pending="LayerEnemies: "..T.HIDDEN_ID_REASON.."; layers hidden for this session." end', '', 'Trust build:'),
]


def run(root, selector):
    return subprocess.run([str(LUA), 'test/harness.lua', '--only', selector], cwd=root,
                          capture_output=True, text=True, timeout=90)


def main():
    assert LUA, 'Set LAYERENEMIES_LUA to Lua 5.1'
    results = []
    with tempfile.TemporaryDirectory(prefix='le-hotfix131-', dir=os.environ.get('TMPDIR', ROOT)) as tmp:
        root = Path(tmp)
        for folder in ('LayerEnemies', 'test'):
            shutil.copytree(ROOT / folder, root / folder, ignore=shutil.ignore_patterns('__pycache__'))
        for selector in sorted({m[4] for m in MUTANTS}):
            baseline = run(root, selector)
            assert baseline.returncode == 0, baseline.stdout + baseline.stderr
        for name, file, old, new, selector in MUTANTS:
            target = root / 'LayerEnemies' / file
            original = target.read_text()
            assert original.count(old) == 1, (name, original.count(old))
            target.write_text(original.replace(old, new, 1))
            try:
                syntax = subprocess.run([str(LUA), '-e', 'assert(loadfile("LayerEnemies/' + file + '"))'],
                                        cwd=root, capture_output=True, text=True)
                assert syntax.returncode == 0, syntax.stderr
                result = run(root, selector)
                failures = [re.sub(r'0x[0-9a-fA-F]+', '0xADDR', line) for line in result.stdout.splitlines()
                            if line.startswith('FAIL ') and 'expected' in line]
                killed = result.returncode != 0 and bool(failures)
                results.append({'name': name, 'killed': killed, 'assertions': failures})
                print(('CAUGHT ' if killed else 'SURVIVED ') + name, flush=True)
            finally:
                target.write_text(original)
    (ROOT / 'notes/hotfix131-mutants.json').write_text(json.dumps(results, indent=2) + '\n')
    killed = sum(r['killed'] for r in results)
    print(f'RESULT: {killed}/{len(results)} hotfix mutants killed', flush=True)
    assert killed == len(results)


if __name__ == '__main__':
    main()
