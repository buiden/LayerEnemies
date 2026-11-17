"""One independent mutation per quiet-notice rule; only private scratch copies are edited."""
from pathlib import Path
import json
import os
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
LUA = Path(os.environ.get('LAYERENEMIES_LUA', '/opt/data/tools/lua/lua-5.1.5/src/lua'))
SCRATCH = Path(os.environ.get('TMPDIR', '/opt/data/cache/scratch'))
MUTANTS = [
    ('register-at-start', 'LayerEnemies/Main.lua', '    N.Wire.registerSystemFilter()', '    -- mutant: no filter'),
    ('register-once', 'LayerEnemies/Wire.lua', 'if filterAttempted then return end', 'if false then return end'),
    ('registration-protected', 'LayerEnemies/Wire.lua', 'S.call(_G.ChatFrame_AddMessageEventFilter, "CHAT_MSG_SYSTEM", systemFilter)', '_G.ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", systemFilter)'),
    ('callback-fails-open', 'LayerEnemies/Wire.lua', 'local ok, hide = pcall(function()', 'local function direct(fn) return true, fn() end; local ok, hide = direct(function()'),
    ('system-event-only', 'LayerEnemies/Wire.lua', 'if S.str(event, 50) ~= "CHAT_MSG_SYSTEM" then return nil end', 'if false then return nil end'),
    ('own-receipt-required', 'LayerEnemies/Wire.lua', 'notice.hide = notice.owned == true and', 'notice.hide = true and'),
    ('one-line-per-whisper', 'LayerEnemies/Wire.lua', 'match.noticed = true', 'match.noticed = false'),
    ('offline-stamp-not-renewed', 'LayerEnemies/Wire.lua', 'notice.key = match.consumed and match.key or Wr.markOffline(match.target, now)', 'notice.key = Wr.markOffline(match.target, now)'),
    ('separate-display-consumption', 'LayerEnemies/Wire.lua', 'if r.key == key and not r.noticed and not match then', 'if r.key == key and not r.noticed and not r.consumed and not match then'),
    ('namesake-ambiguity', 'LayerEnemies/Wire.lua', 'if match and not ambiguous then', 'if match then'),
    ('full-realm-identity', 'LayerEnemies/Wire.lua', 'local key = who(name)', 'local key = who((name:match("^([^%-]+)")))'),
    ('spaced-name-identity', 'LayerEnemies/Wire.lua', 'local key = who(name)', 'local key = who((name:gsub("%s", "")))'),
    ('literal-surname-validation', 'LayerEnemies/Invite.lua', '    base=base or name', '    name=name:gsub("%.", ""); base=base or name'),
    ('secret-text-refused', 'LayerEnemies/Wire.lua', 'text = S.str(text, 512)', 'text = type(text) == "string" and text'),
    ('no-english-fallback', 'LayerEnemies/Wire.lua', 'local raw = S.str(_G.ERR_CHAT_PLAYER_NOT_FOUND_S, 512)', 'local raw = S.str(_G.ERR_CHAT_PLAYER_NOT_FOUND_S, 512) or \'No player named "%s" is currently playing.\''),
    ('exact-localized-line', 'LayerEnemies/Wire.lua', 'failurePattern = "^" .. table.concat(parts) .. "$"', 'failurePattern = table.concat(parts)'),
    ('localized-literals-escaped', 'LayerEnemies/Wire.lua', r'parts[#parts + 1] = c:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")', 'parts[#parts + 1] = c'),
    ('single-name-template', 'LayerEnemies/Wire.lua', 'if captures == 1 and literals > 0 then', 'if captures >= 1 then'),
    ('thirty-second-expiry', 'LayerEnemies/Wire.lua', 'Wr.RECENT_WINDOW, Wr.RECENT_MAX = 30, 64', 'Wr.RECENT_WINDOW, Wr.RECENT_MAX = 31, 64'),
    ('rollback-prunes-evidence', 'LayerEnemies/Wire.lua', 'if now >= r.at and now - r.at < Wr.RECENT_WINDOW then', 'if now - r.at < Wr.RECENT_WINDOW then'),
    ('whisper-ledger-cap', 'LayerEnemies/Wire.lua', 'if #whispers >= Wr.RECENT_MAX then table.remove(whispers, 1) end', '-- mutant: uncapped whispers'),
    ('decision-ledger-cap', 'LayerEnemies/Wire.lua', 'if #notices >= Wr.RECENT_MAX then table.remove(notices, 1) end', '-- mutant: uncapped decisions'),
    ('fallback-only-same-tick', 'LayerEnemies/Wire.lua', 'and (r.id or now == r.at)', 'and true'),
    ('distinct-lineIDs', 'LayerEnemies/Wire.lua', 'if r.id == lineID and (r.text == text', 'if (r.text == text'),
    ('cache-idempotence', 'LayerEnemies/Wire.lua', 'if cached then return cached.key, cached end', 'if false then return cached.key, cached end'),
    ('main-forwards-lineID', 'LayerEnemies/Main.lua', 'guarded(M.whisperSystem,...)', 'guarded(M.whisperSystem,(...))'),
    ('counter-per-line', 'LayerEnemies/Wire.lua', 'if not notice.counted then hiddenNotices', 'if true then hiddenNotices'),
    ('unmatched-counter', 'LayerEnemies/Wire.lua', 'unmatchedNotices = unmatchedNotices + 1', 'unmatchedNotices = unmatchedNotices + 0'),
    ('no-unmatched-names', 'LayerEnemies/Wire.lua', 'if not notice.owned then notice.text, notice.fingerprint, notice.bytes = nil, fingerprint, #text end', '-- mutant: unmatched text retained'),
    ('only-accepted-display-evidence', 'LayerEnemies/Wire.lua', 'at = now, display = display == true', 'at = now, display = true'),
    ('sync-offline-display-receipt', 'LayerEnemies/Wire.lua', 'result == 0 or result == true or result == 12', 'result == 0 or result == true'),
    ('legacy-boolean-display-receipt', 'LayerEnemies/Wire.lua', 'result == 0 or result == true or result == 12', 'result == 0 or result == 12'),
    ('quiet-off', 'LayerEnemies/Wire.lua', 'LayerEnemiesDB.quietWhispers ~= false', 'true'),
    ('default-on', 'LayerEnemies/Main.lua', 'LayerEnemiesDB.quietWhispers=saved.quietWhispers~=false', 'LayerEnemiesDB.quietWhispers=saved.quietWhispers==true'),
    ('saved-off', 'LayerEnemies/Main.lua', 'LayerEnemiesDB.quietWhispers=saved.quietWhispers~=false', 'LayerEnemiesDB.quietWhispers=true'),
    ('quiet-command', 'LayerEnemies/Main.lua', 'LayerEnemiesDB.quietWhispers=state=="on"', 'LayerEnemiesDB.quietWhispers=state~="on"'),
    ('no-saved-notice-names', 'LayerEnemies/Wire.lua', 'match.noticed = true', 'match.noticed = true; LayerEnemiesDB.noticeName = match.target'),
    ('filter-API-owner', 'test/verify.py', "API_OWNERS['ChatFrame_AddMessageEventFilter'] = 'Wire.lua'", '# mutant: unowned filter API'),
]


def run(root):
    return subprocess.run([str(LUA), 'test/harness.lua', '--only', 'Quiet'], cwd=root,
                          capture_output=True, text=True, timeout=120)


def main():
    with tempfile.TemporaryDirectory(prefix='le-quiet-mutants-', dir=SCRATCH) as name:
        root = Path(name)
        shutil.copytree(ROOT / 'test', root / 'test')
        shutil.copytree(ROOT / 'LayerEnemies', root / 'LayerEnemies')
        baseline = run(root)
        assert baseline.returncode == 0, baseline.stdout + baseline.stderr
        counts = re.search(r'RESULT: (\d+) tests passed, (\d+) failed', baseline.stdout)
        assert counts and int(counts[1]) >= 25
        results = []
        for rule, file, old, new in MUTANTS:
            path = root / file
            original = path.read_text()
            assert original.count(old) == 1, (rule, original.count(old))
            path.write_text(original.replace(old, new, 1))
            try:
                if path.suffix == '.lua':
                    subprocess.run([str(LUA.with_name('luac')), '-p', str(path)], check=True, capture_output=True)
                    result = run(root)
                    failures = [line for line in result.stdout.splitlines() if line.startswith('FAIL ')]
                else:
                    result = subprocess.run(['python3', 'test/api_policy_test.py', 'ApiPolicyTests.test_system_filter_owner_is_wire_only'],
                                            cwd=root, capture_output=True, text=True, timeout=30)
                    failures = [line for line in result.stderr.splitlines() if line.startswith('FAIL: ')]
                caught = result.returncode != 0 and bool(failures)
                results.append({'rule': rule, 'caught': caught, 'failures': failures})
                print(('CAUGHT ' if caught else 'SURVIVED ') + rule, flush=True)
            finally:
                path.write_text(original)
        out = ROOT / 'notes/quiet-mutants.json'
        out.parent.mkdir(exist_ok=True)
        out.write_text(json.dumps(results, indent=2) + '\n')
        caught = sum(row['caught'] for row in results)
        print(f'MUTANTS: {caught}/{len(results)} caught')
        assert caught == len(results), [r['rule'] for r in results if not r['caught']]


if __name__ == '__main__':
    main()
