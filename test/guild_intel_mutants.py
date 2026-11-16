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
    ('party-member-invisible', 'LayerEnemies/Main.lua',
     'return A.inInstance()==false and S.call(UnitIsVisible,member)==true',
     'return A.inInstance()==false'),
    ('party-target-in-instance', 'LayerEnemies/Main.lua',
     'return A.inInstance()==false and S.call(UnitIsVisible,member)==true',
     'return S.call(UnitIsVisible,member)==true'),
    ('party-secret-unit-accepted', 'LayerEnemies/Main.lua',
     'function M.queueGroupTarget(unit)\n    unit=S.str(unit,30)',
     'function M.queueGroupTarget(unit)\n    unit=type(unit)=="string" and unit or nil'),
    ('realm-ignored', 'LayerEnemies/Find.lua',
     'if realm then return entry.realmKey==F.fold(realm) end',
     'if realm then return true end'),
    ('surname-includes-realm', 'LayerEnemies/Find.lua',
     'local given,surname=first:match("^([^ ]+) (.+)$")',
     'local given,surname=name:match("^([^ ]+) (.+)$")'),
    ('realm-warning-dropped', 'LayerEnemies/Find.lua',
     'if row.realmUnknown then row.status=row.status.." · realm not confirmed" end',
     '-- realm warning omitted'),
    ('home-realm-exemption-removed', 'LayerEnemies/Find.lua',
     'return true,entry.realmKey~=homeKey or nil', 'return true,true'),
    ('realm-digits-refused', 'LayerEnemies/Find.lua',
     r'''realm:match("^[%a%d'\128-\255]+$")''', r'''realm:match("^[%a'\128-\255]+$")'''),
    ('known-cross-realm-leak', 'LayerEnemies/Find.lua',
     'if e then\n                    local match,realmUnknown=matches(entry,e,st.homeKey)\n                    if match then',
     'if e then\n                    local match,realmUnknown=matches(entry,e,st.homeKey)\n'
     '                    if entry.shortKey==F.fold((parts(e.name))) then match=true end\n                    if match then'),
    ('named-hash-realm-conflict-ignored', 'LayerEnemies/Find.lua',
     'if not conflict then hashPut(entry,e,entry.realm~=nil or nil) end',
     'hashPut(entry,e,entry.realm~=nil or nil)'),
    ('headhunter-late-home-warning-stale', 'LayerEnemies/Find.lua',
     'if loc and loc.evidenceName then', 'if false then'),
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
