"""One independent mutation per hop rule. Private scratch copies; never edits the working addon."""
from pathlib import Path
import argparse
import json
import os
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
LUA = os.environ.get('LAYERENEMIES_LUA') or shutil.which('lua5.1') or shutil.which('lua')
SCRATCH = Path(os.environ.get('TMPDIR') or str(ROOT.parent)).resolve()
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
    ('group-event-cancels', 'Main.lua', 'if grouped and M.hopAnyState and M.hopAnyState.round then M.hopAnyStop("joined a group") end', '-- mutant: no group cancellation'),
    ('world-event-cancels', 'Main.lua', 'guarded(M.hopAnySafe); guarded(M.boundary', 'guarded(M.boundary'),
    ('zone-event-cancels', 'Main.lua', 'if M.hopAnyState then M.hopAnyStop("zone changed") end', '-- mutant: no zone cancellation'),
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
    # Script restoration no longer exists; retain the result-exit restoration mutation.
    ('who-result-restore', 'Adapters.lua', 'whoLater(0,function() whoRelease(q) end)', 'whoLater(0,function() end)'),
    ('who-timeout-restore', 'Main.lua', 'A.whoEnd("timeout")', '-- mutant: no timeout restore'),
    ('who-stop-restore', 'Main.lua', '    A.whoEnd("stop")', '    -- mutant: no stop restore'),
    ('who-error-restore', 'Adapters.lua', 'if not accepted then A.whoEnd("error") end', 'if not accepted then -- mutant\n    end'),
    ('who-invite-restore', 'Main.lua', 'if N.HopAny.invite(M.hopAnyState,name,now()) then A.whoEnd("stop") end', 'N.HopAny.invite(M.hopAnyState,name,now())'),
    ('who-reload-restore', 'Main.lua', 'A.whoEnd("reload")', '-- mutant: no reload release'),
    ('who-late-deadline', 'Adapters.lua', 'A.WHO_LATE=30', 'A.WHO_LATE=31'),
    ('who-late-swallow', 'Adapters.lua', 'elseif reason~="timeout" and reason~="stop" then whoRelease(q) end', 'else whoRelease(q) end'),
    ('who-manual-ownership', 'Adapters.lua', 'if old and not whoSending then', 'if false then'),
    ('who-restore-method-preflight', 'Adapters.lua', '"IsEventRegistered","RegisterEvent","UnregisterEvent","IsVisible"', '"IsEventRegistered","UnregisterEvent","IsVisible"'),
    ('who-result-error-event-order', 'Adapters.lua', 'if reason=="result" or q.event then', 'if reason=="result" then'),
    ('no-saved-names', 'HopAny.lua', '    st.lastClick=c.now', '    _G.LayerEnemiesDB.hopNames=st.quiet\n    st.lastClick=c.now'),
    # Round-1 owner rulings: each cancellation boundary and both throttle directions.
    ('same-zone-event-keeps-click', 'Main.lua', '        guarded(M.zoneCheck,(A.location()))', '        guarded(M.hopAnyStop,"zone changed")\n        guarded(M.zoneCheck,(A.location()))'),
    ('ungrouped-roster-keeps-click', 'Main.lua', 'then guarded(M.groupCheck); guarded(M.inviteTick)', 'then guarded(M.hopAnyStop,"group changed"); guarded(M.groupCheck); guarded(M.inviteTick)'),
    # World boundaries now clear layered clicks even in the same zone. Retain
    # the historical ID by restoring the obsolete same-zone boundary bypass.
    ('same-zone-loading-keeps-click', 'Main.lua', 'guarded(M.hopAnySafe); guarded(M.boundary,A.location()); M.queuePoll()', 'guarded(M.hopAnySafe); if A.location()~=M.store.zone then guarded(M.boundary,A.location()) end; M.queuePoll()'),
    ('non-hop-throttle-stops-click', 'Wire.lua', 'elseif prefix == "LayerSwap" then hopStop = now + Wr.PAUSE end', 'end'),
    ('hop-throttle-pauses-ordinary', 'Wire.lua', '            paused[prefix] = now + Wr.PAUSE', '            if not hop then paused[prefix] = now + Wr.PAUSE end'),
    ('non-hop-throttle-survives-delayed-pump', 'Main.lua', 'N.Wire.hopBlocked(r.at)', 'N.Wire.hopBlocked(now())'),
    ('non-hop-pause-refuses-before-who', 'Main.lua', 'if N.Wire.hopBlocked(c.now) then', 'if false then'),
    ('who-never-replaces-event-script', 'Adapters.lua', '            local v={frame=frame}', '            frame:SetScript("OnEvent",function() end)\n            local v={frame=frame}'),
    ('who-visible-window-untouched', 'Adapters.lua', 'frame:IsVisible()~=false or frame:IsEventRegistered', 'frame:IsEventRegistered'),
]


def normalize(output, root):
    output = output.replace(str(root) + os.sep, '')
    return re.sub(r'(table|function|thread|userdata): 0x[0-9a-fA-F]+', r'\1: <address>', output)


def write_report(path, report):
    data = (json.dumps(report, indent=2, sort_keys=True) + '\n').encode()
    if not path.exists() or path.read_bytes() != data:
        path.write_bytes(data)


def run(root, lua=None):
    executable = lua or LUA
    assert executable, '--lua or LAYERENEMIES_LUA must select Lua 5.1'
    result = subprocess.run([executable, 'test/harness.lua', '--hop-any-only'], cwd=root,
                            capture_output=True, text=True, errors='replace', timeout=120)
    result.stdout = normalize(result.stdout, root)
    result.stderr = normalize(result.stderr, root)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lua', default=LUA)
    parser.add_argument('--scratch', default=str(SCRATCH))
    args = parser.parse_args()
    if not args.lua:
        parser.error('--lua or LAYERENEMIES_LUA must select Lua 5.1')
    with tempfile.TemporaryDirectory(prefix='le-hop-mutants-', dir=Path(args.scratch).resolve()) as name:
        root = Path(name)
        shutil.copytree(ROOT / 'test', root / 'test')
        shutil.copytree(ROOT / 'LayerEnemies', root / 'LayerEnemies')
        baseline = run(root, args.lua)
        assert baseline.returncode == 0, baseline.stdout + baseline.stderr
        results = []
        for rule, file, old, new in MUTANTS:
            path = root / 'LayerEnemies' / file
            original = path.read_text()
            assert original.count(old) == 1, (rule, original.count(old))
            path.write_text(original.replace(old, new, 1))
            try:
                syntax = subprocess.run([args.lua, '-e', 'assert(loadfile(' + json.dumps(str(path)) + '))'],
                                        capture_output=True, text=True, timeout=30)
                assert syntax.returncode == 0, (rule, syntax.stderr)
                result = run(root, args.lua)
                failures = [line for line in result.stdout.splitlines() if line.startswith('FAIL ')]
                caught = result.returncode != 0 and bool(failures)
                results.append({'rule': rule, 'file': file, 'caught': caught, 'failed_tests': failures})
                print(('CAUGHT ' if caught else 'SURVIVED ') + rule, flush=True)
            finally:
                path.write_text(original)
        output = {'baseline': baseline.stdout.splitlines()[-1], 'total': len(results),
                  'caught': sum(r['caught'] for r in results), 'mutants': results}
        final = run(root, args.lua)
        assert final.returncode == 0 and final.stdout == baseline.stdout, final.stdout + final.stderr
        (ROOT / 'notes').mkdir(exist_ok=True)
        write_report(ROOT / 'notes/hop-fanout-mutants.json', output)
        print(f"MUTANTS: {output['caught']}/{output['total']} caught")
        assert output['caught'] == output['total'], 'surviving mutants'


if __name__ == '__main__':
    main()
