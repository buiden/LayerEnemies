"""PR0b-only mutants. Isolated copies under TMPDIR; never runs other feature mutants."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
LUA = os.environ.get('LAYERENEMIES_LUA', '/opt/data/tools/lua/lua-5.1.5/src/lua')
# Each mutation must compile and be killed by an assertion, not a setup error.
MUTANTS = [
    ('registry addon routing', 'Main.lua', 'if N.Sources.owns(prefix) then', 'if false then', 'Sources:'),
    ('legacy prefix refusal', 'Sources.lua', 'not prefix or legacy[prefix] or owners[prefix]', 'not prefix or owners[prefix]', 'Sources:'),
    ('duplicate prefix refusal', 'Sources.lua', 'legacy[prefix] or owners[prefix] or seen[prefix]', 'legacy[prefix] or seen[prefix]', 'Sources:'),
    ('OpenMap event exception', 'Main.lua', 'not S.secret(prefix) and prefix=="OpenMapLoc"', 'false', 'Sources:'),
    ('BNet event routing', 'Main.lua', 'guarded(N.Sources.bnet,prefix,text,id)', 'do end', 'Sources:'),
    ('one-time registration', 'Sources.lua', 'if not registered[prefix] then', 'if true then', 'Sources:'),
    ('registry tick cadence', 'Sources.lua', 't.After(1,pulse)', 't.After(2,pulse)', 'Sources:'),
    ('live source switch', 'Sources.lua', 'Src.has(name) and N.Net.switch(name)', 'Src.has(name)', 'Sources:'),
    ('tracked gate', 'Sources.lua', 'if not F.tracked(M.find,name) and #(watchers or {})==0 then', 'if false then', 'Sources:'),
    ('live Watch gate', 'Sources.lua', 'N.Watch.match(M.watch,name,now)', 'N.Watch.match(M.watch,name,0)', 'Sources:'),
    ('realm rule', 'Find.lua', 'if realm then return entry.realmKey==F.fold(realm) end', 'if realm then return true end', 'Sources:'),
    ('claim kind', 'Sources.lua', 'kind="claim",relayed=kind=="relayed"', 'kind="seen",relayed=kind=="relayed"', 'Sources:'),
    ('unknown observed time', 'Sources.lua', 'if ev.at==nil then detail=detail.." · time unknown" end', 'if false then detail=detail.." · time unknown" end', 'Sources:'),
    ('source age', 'Sources.lua', 'now-at>=N.Known.TTL', 'now-at>N.Known.TTL', 'Sources:'),
    ('secret offer', 'Safe.lua', 'local ok, hidden = pcall(issecretvalue, v)', 'local ok, hidden = true, false', 'Sources:'),
    ('silent claim on next poll', 'Find.lua', 'if row.evidenceKind then return false end', 'if false then return false end', 'Sources:'),
    ('peer online', 'Adapters.lua', 'v(game.isOnline)~=true', 'false', 'BNet:'),
    ('peer project', 'Adapters.lua', 'S.num(v(game.wowProjectID))~=project', 'false', 'BNet:'),
    ('peer client', 'Adapters.lua', 'S.str(v(game.clientProgram),16)~="WoW"', 'false', 'BNet:'),
    ('peer region', 'Adapters.lua', 'v(game.isInCurrentRegion)~=true', 'false', 'BNet:'),
    ('peer cache TTL', 'BNet.lua', 'now-cacheAt<30', 'now-cacheAt<31', 'BNet:'),
    ('club reader cap', 'Adapters.lua', 'for i=1,1000 do', 'for i=1,1001 do', 'BNet:'),
    ('friend game cap', 'Adapters.lua', 'math.min(total,10)', 'math.min(total,11)', 'BNet:'),
    ('shared minute budget', 'BNet.lua', '#times<30', '#times<31', 'BNet queue:'),
    ('one second pace', 'BNet.lua', 't.After(1,function()', 't.After(.5,function()', 'BNet queue:'),
    ('owed first', 'BNet.lua', 'return a.prio=="owed"', 'return a.prio=="own"', 'BNet queue:'),
    ('registered source authorization', 'BNet.lua', 'if not authorized or not N.Main.sharing()', 'if false or not N.Main.sharing()', 'BNet queue:'),
    ('share off', 'BNet.lua', 'not N.Main.sharing()', 'false', 'BNet queue:'),
    ('public off', 'BNet.lua',
     'if not authorized or not N.Main.sharing() or N.Net.consent()~="public" or not safe() then return false end\n    local ok,why=N.Net.allowed(net,"public")',
     'if not authorized or not N.Main.sharing() or not safe() then return false end\n    local ok,why=N.Net.allowed(net,"guild")', 'BNet queue:'),
    ('dispatch privacy recheck', 'BNet.lua', 'if not BN.allowed(q.net,q.id,q.prefix,q.text,q.prio) or not BN.who(q.id) then', 'if false then', 'BNet queue:'),
    ('cancel off-on share', 'Main.lua', 'N.OwnDeath.cancel(); N.BNet.cancel()', 'N.OwnDeath.cancel()', 'BNet queue:'),
    ('per-network share', 'BNet.lua', 'wanted=4', 'wanted=5', 'BNet queue:'),
    ('failed send dropped', 'BNet.lua', 'if deliver(q) then N.Sources.count(q.net,"sent") else refuse(q.net) end', 'if deliver(q) then N.Sources.count(q.net,"sent") else refuse(q.net); queue[#queue+1]=q end', 'BNet queue:'),
    ('Wire caller frame', 'BNet.lua', 'pcall(N.Wire.bnet,q.net,q.id,q.prefix,q.text,q.prio,fn)', 'pcall(fn,q.id,q.prefix,q.text)', 'BNet queue:'),
    ('Wire private dispatch', 'Wire.lua', 'or not N.BNet.dispatching(net,id,prefix,text,prio,fn)', 'or false', 'BNet queue:'),
    ('queue bound', 'BNet.lua', '#queue>=60', '#queue>60', 'BNet queue:'),
]


def main():
    results = []
    with tempfile.TemporaryDirectory(prefix='le-src-mutants-') as tmp:
        root = Path(tmp)
        for folder in ('LayerEnemies', 'test'):
            shutil.copytree(ROOT / folder, root / folder)
        for name, filename, old, new, selector in MUTANTS:
            path = root / 'LayerEnemies' / filename
            original = path.read_text()
            assert original.count(old) == 1, (name, 'nonunique mutation')
            path.write_text(original.replace(old, new))
            try:
                subprocess.run([str(Path(LUA).with_name('luac')), '-p', str(path)], check=True, capture_output=True)
                run = subprocess.run([LUA, 'test/harness.lua', '--only', selector], cwd=root,
                                     capture_output=True, text=True, timeout=180)
                failures = [line for line in run.stdout.splitlines() if line.startswith('FAIL ')]
                killed = run.returncode != 0 and bool(failures) and 'RESULT:' in run.stdout
                results.append({'rule': name, 'killed': killed, 'failures': failures})
                print(('KILLED ' if killed else 'SURVIVED ') + name)
            finally:
                path.write_text(original)
        for name, old, new in (
            ('generic harness filter', 'name:find(part,1,true)', 'name:find("NO_SUCH_FILTER",1,true)'),
            ('automatic source suites', 'for _,file in ipairs(files) do assert(loadfile(file))(sourceHarness) end', '-- no source suites'),
        ):
            path = root / 'test/harness.lua'
            original = path.read_text()
            assert original.count(old) == 1
            path.write_text(original.replace(old, new))
            try:
                run = subprocess.run([sys.executable, 'test/harness_sources_test.py'], cwd=root,
                                     capture_output=True, text=True, timeout=180)
                killed = run.returncode != 0 and 'FAIL:' in run.stderr
                results.append({'rule': name, 'killed': killed})
                print(('KILLED ' if killed else 'SURVIVED ') + name)
            finally:
                path.write_text(original)
    output = ROOT / 'notes/source-mutants.json'
    output.write_text(json.dumps(results, indent=2) + '\n')
    killed = sum(r['killed'] for r in results)
    print(f'RESULT: {killed}/{len(results)} source mutants killed')
    if killed != len(results):
        raise SystemExit(1)


if __name__ == '__main__':
    main()
