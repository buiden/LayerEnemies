"""One independent mutation per hop rule. Private scratch copies; never edits the working addon."""
from pathlib import Path
import json
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
LUA = os.environ.get('LAYERENEMIES_LUA', '/opt/data/tools/lua/lua-5.1.5/src/lua')
SCRATCH = Path(os.environ.get('TMPDIR', '/opt/data/cache/scratch'))
MUTANTS = [
    ('first-49-raw-rows', 'Adapters.lua', 'math.min(n,49)', 'math.min(n,50)'),
    ('eight-attempt-round', 'HopAny.lua', '=8,1,10,5,120', '=9,1,10,5,120'),
    ('one-second-round', 'HopAny.lua', '=8,1,10,5,120', '=8,.5,10,5,120'),
    ('forty-five-round-ceiling', 'HopAny.lua', 'H.ROWS,H.ROUNDS=49,45', 'H.ROWS,H.ROUNDS=49,46'),
    ('ten-second-click', 'HopAny.lua', '=8,1,10,5,120', '=8,1,30,5,120'),
    ('first-send-cooldown', 'HopAny.lua', 'r.firstSend=time; st.lastClick=time', 'r.firstSend=time'),
    ('first-send-invite-window', 'HopAny.lua', 'r.phase~="who" and time-(r.firstSend or r.at)', 'r.phase~="who" and time-(r.lastSend or r.at)'),
    ('throttle-retains-head', 'HopAny.lua', 'r.index=r.index-1; r.used=H.CAP', 'r.used=H.CAP'),
    ('host-priority', 'HopAny.lua', 'if v.host then ranks[v.short]=1 end', 'if false then ranks[v.short]=1 end'),
    ('same-zone-priority', 'HopAny.lua', '(row.area==c.zoneName and 2 or 3)', '3'),
    ('other-zone-included', 'HopAny.lua', 'if name and key~=c.self', 'if name and row.area==c.zoneName and key~=c.self'),
    ('hosting-reply-keeps-sending', 'HopAny.lua', 'if first then r.host=r.asked[key].name end', 'if first then r.host=r.asked[key].name end; r.phase="wait"'),
    ('unasked-invite-stops', 'HopAny.lua', 'if not r or not key or H.isFailed(st,key,time) then', 'if not r or not key or not r.asked[key] or H.isFailed(st,key,time) then'),
    ('failed-invite-does-not-stop', 'HopAny.lua', 'if not r or not key or H.isFailed(st,key,time) then', 'if not r or not key then'),
    ('failed-host-retains-realm', 'Main.lua', 'N.HopAny.failed(M.hopAnyState,g.short,time)', 'N.HopAny.failed(M.hopAnyState,g.host,time)'),
    ('stop-cancels', 'Main.lua', 'N.HopAny.close(st,now())', '-- mutant: queue left open'),
    ('group-event-cancels', 'Main.lua', 'guarded(M.hopAnyStop,"group changed"); guarded(M.groupCheck)', 'guarded(M.groupCheck)'),
    ('world-event-cancels', 'Main.lua', 'guarded(M.hopAnyStop,"world changed"); guarded(M.boundary', 'guarded(M.boundary'),
    ('zone-event-cancels', 'Main.lua', 'guarded(M.hopAnyStop,"zone changed")', '-- mutant: no zone cancellation'),
    ('six-hour-skip', 'HopAny.lua', '=21600,300,600', '=3600,300,600'),
    ('skip-cap-300', 'HopAny.lua', '=21600,300,600', '=21600,301,600'),
    ('known-book-bypass', 'HopAny.lua', '(known[key] or not st.quiet[key])', '(not st.quiet[key])'),
    ('known-offline-600', 'Wire.lua', 'if hopSeconds == 600 then', 'if false then'),
    ('donor-gone-skip', 'HopAny.lua', 'and not gone[key] and not seen[key]', 'and not seen[key]'),
    ('offline-nonresponders-skip', 'HopAny.lua', 'then r.offline[c.short]=time', 'then r.offline[c.short]=nil'),
    ('fallback-three-seconds', 'HopAny.lua', 'H.FALLBACK,H.FALLBACK_LATE=3,10', 'H.FALLBACK,H.FALLBACK_LATE=4,10'),
    ('fallback-known-host-ten-seconds', 'HopAny.lua', 'H.FALLBACK,H.FALLBACK_LATE=3,10', 'H.FALLBACK,H.FALLBACK_LATE=3,11'),
    ('fallback-once', 'HopAny.lua', 'r.anyTried[c.short]=true;', 'r.anyTried[c.short]=nil;'),
    ('fallback-no-exclusion', 'HopAny.lua', 'line=(r.line:gsub(" not %d+%-%d+",""))', 'line=r.line'),
    ('fallback-same-zone', 'HopAny.lua', 'not reply.layer and reply.zone==r.zone', 'not reply.layer'),
    ('fallback-requires-host', 'HopAny.lua', 'reply.kind=="heard" and reply.hosting and not reply.layer', 'reply.kind=="heard" and not reply.layer'),
    ('fallback-spent-on-throttle', 'HopAny.lua', 'if c.fallback then\n        -- One fallback', 'if c.fallback then\n        if not ok then r.anyTried[c.short]=nil end\n        -- One fallback'),
    ('fallback-pace', 'HopAny.lua', 'if time<r.anyAt or r.anyUsed>=H.CAP then', 'if time<r.anyAt then'),
    ('hop-eight-token-burst', 'Wire.lua', '= 8, 1, 60, 4, 1', '= 7, 1, 60, 4, 1'),
    ('hop-one-token-second', 'Wire.lua', '= 8, 1, 60, 4, 1', '= 8, 2, 60, 4, 1'),
    ('hop-sixty-per-minute', 'Wire.lua', '= 8, 1, 60, 4, 1', '= 8, 1, 61, 4, 1'),
    ('hop-four-per-target', 'Wire.lua', '= 8, 1, 60, 4, 1', '= 8, 1, 60, 5, 1'),
    ('ordinary-prefix-unchanged', 'Wire.lua', '= 5, 2, 8, 1.5, 40', '= 6, 2, 8, 1.5, 40'),
    ('click-only-budget', 'Wire.lua', 'opts.hopAny == true and opts.prio == "click" and prefix', 'opts.hopAny == true and prefix'),
    ('who-ui-route', 'Adapters.lua', '    whoRoute(true)', '    whoRoute(false)'),
    ('who-unregister', 'Adapters.lua', 'frame:UnregisterEvent("WHO_LIST_UPDATE")', '-- mutant: no detach'),
    ('who-register-restore', 'Adapters.lua', 'v.frame:RegisterEvent("WHO_LIST_UPDATE")', 'do end'),
    ('who-script-restore', 'Adapters.lua', 'then v.frame:SetScript("OnEvent",v.script) end', 'then -- mutant\n            end'),
    ('who-timeout-restore', 'Main.lua', 'A.whoEnd("timeout")', '-- mutant: no timeout restore'),
    ('who-stop-restore', 'Main.lua', '    A.whoEnd("stop")', '    -- mutant: no stop restore'),
    ('who-error-restore', 'Adapters.lua', 'if not accepted then A.whoEnd("error") end', 'if not accepted then -- mutant\n    end'),
    ('who-invite-restore', 'Main.lua', 'if N.HopAny.invite(M.hopAnyState,name,now()) then A.whoEnd("stop") end', 'N.HopAny.invite(M.hopAnyState,name,now())'),
    ('who-reload-restore', 'Main.lua', 'A.whoEnd("reload")', '-- mutant: no reload release'),
    ('who-late-deadline', 'Adapters.lua', 'A.WHO_LATE=30', 'A.WHO_LATE=31'),
    ('who-late-swallow', 'Adapters.lua', 'event=="WHO_LIST_UPDATE" and q.block', 'event=="WHO_LIST_UPDATE" and q.active'),
    ('who-manual-ownership', 'Adapters.lua', 'if old and not whoSending then', 'if false then'),
    ('who-restore-method-preflight', 'Adapters.lua', '"IsEventRegistered","RegisterEvent","UnregisterEvent","GetScript","SetScript"', '"IsEventRegistered","UnregisterEvent","GetScript","SetScript"'),
    ('who-result-error-event-order', 'Adapters.lua', 'if reason=="result" or q.event then', 'if reason=="result" then'),
    ('no-saved-names', 'HopAny.lua', '    st.lastClick=c.now', '    _G.LayerEnemiesDB.hopNames=st.quiet\n    st.lastClick=c.now'),
]


def run(root):
    return subprocess.run([LUA, 'test/harness.lua', '--hop-any-only'], cwd=root, capture_output=True, text=True, timeout=120)


def main():
    with tempfile.TemporaryDirectory(prefix='le-hop-mutants-', dir=SCRATCH) as name:
        root = Path(name)
        shutil.copytree(ROOT / 'test', root / 'test')
        shutil.copytree(ROOT / 'LayerEnemies', root / 'LayerEnemies')
        baseline = run(root)
        assert baseline.returncode == 0, baseline.stdout + baseline.stderr
        results = []
        for rule, file, old, new in MUTANTS:
            path = root / 'LayerEnemies' / file
            original = path.read_text()
            assert original.count(old) == 1, (rule, original.count(old))
            path.write_text(original.replace(old, new, 1))
            try:
                syntax = subprocess.run([str(Path(LUA).with_name('luac')), '-p', str(path)], capture_output=True, text=True)
                assert syntax.returncode == 0, (rule, syntax.stderr)
                result = run(root)
                failures = [line for line in result.stdout.splitlines() if line.startswith('FAIL ')]
                caught = result.returncode != 0 and bool(failures)
                results.append({'rule': rule, 'file': file, 'caught': caught, 'failed_tests': failures})
                print(('CAUGHT ' if caught else 'SURVIVED ') + rule, flush=True)
            finally:
                path.write_text(original)
        output = {'baseline': baseline.stdout.splitlines()[-1], 'total': len(results),
                  'caught': sum(r['caught'] for r in results), 'mutants': results}
        (ROOT / 'notes/hop-fanout-mutants.json').write_text(json.dumps(output, indent=2) + '\n')
        print(f"MUTANTS: {output['caught']}/{output['total']} caught")
        assert output['caught'] == output['total'], 'surviving mutants'


if __name__ == '__main__':
    main()
