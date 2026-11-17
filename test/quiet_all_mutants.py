"""Independent all-mode rule mutations; private copies, syntax-checked Lua and real assertions."""
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
WIRE = 'LayerEnemies/Wire.lua'
MAIN = 'LayerEnemies/Main.lua'
GATE = 'test/verify.py'
MUTANTS = [
    ('all-mode-hides-unowned', WIRE, 'if mode == "all" and observerReady then', 'if false then'),
    ('manual-target-exception', WIRE, 'notice.hide = not manualWhisper(key, now)', 'notice.hide = true'),
    ('hook-at-startup', MAIN, '    N.Wire.registerWhisperObserver()', '    -- no observer'),
    ('modern-entrypoint', WIRE, 'modern = pcall(_G.hooksecurefunc, C_ChatInfo, "SendChatMessage", observeChatWhisper)', 'modern = false'),
    ('legacy-entrypoint', WIRE, 'legacy = pcall(_G.hooksecurefunc, "SendChatMessage", observeChatWhisper)', 'legacy = false'),
    ('modern-registration-protected', WIRE, 'modern = pcall(_G.hooksecurefunc, C_ChatInfo, "SendChatMessage", observeChatWhisper)', 'modern = _G.hooksecurefunc(C_ChatInfo, "SendChatMessage", observeChatWhisper)'),
    ('legacy-registration-protected', WIRE, 'legacy = pcall(_G.hooksecurefunc, "SendChatMessage", observeChatWhisper)', 'legacy = _G.hooksecurefunc("SendChatMessage", observeChatWhisper)'),
    ('one-registration-attempt', WIRE, 'if observerAttempted then return end', 'if false then return end'),
    ('available-hook-is-sufficient', WIRE, 'observerReady = (modern or legacy) and (modernAbsent or modern) and (legacyAbsent or legacy)', 'observerReady = modern and legacy'),
    ('no-hook-fallback', WIRE, 'if mode == "all" and observerReady then', 'if mode == "all" then'),
    ('whisper-chat-type-only', WIRE, 'if S.str(chatType, 30) ~= "WHISPER" then return end', 'if false then return end'),
    ('existing-name-rule', WIRE, 'and S.call(who, raw)', 'and raw:lower()'),
    ('ten-second-lifetime', WIRE, 'now - r.at < 10 then', 'now - r.at < 11 then'),
    ('manual-rollback', WIRE, 'if now >= r.at and now - r.at < 10 then', 'if now - r.at < 10 then'),
    ('sixteen-target-limit', WIRE, 'if #manualWhispers >= 16 then', 'if #manualWhispers >= 17 then'),
    ('refresh-distinct-target', WIRE, 'if manualWhispers[i].key == key then table.remove(manualWhispers, i) end', 'if false then table.remove(manualWhispers, i) end'),
    ('prune-before-manual-match', WIRE, 'local function manualWhisper(key, now)\n    pruneManual(now)', 'local function manualWhisper(key, now)\n    -- no prune'),
    ('persist-all-mode', WIRE, 'if value == "all" then return "all" end', 'if value == "all" then return "on" end'),
    ('migrate-boolean-false', WIRE, 'if value == false or value == "off" then', 'if value == "off" then'),
    ('default-own-only', WIRE, '    return "on"\nend', '    return "all"\nend'),
    ('session-only-targets', WIRE, 'manualWhispers[#manualWhispers + 1] = { key = key, at = now }', 'manualWhispers[#manualWhispers + 1] = { key = key, at = now }; LayerEnemiesDB.manualWhispers = manualWhispers'),
    ('other-hidden-counter', WIRE, 'hiddenOtherNotices = hiddenOtherNotices + 1', 'hiddenOtherNotices = hiddenOtherNotices + 0'),
    ('shown-mode-counter', WIRE, 'if not notice.hide then shownNotices = shownNotices + 1 end', 'if not notice.hide and not notice.owned then shownNotices = shownNotices + 1 end'),
    ('shown-manual-counter', WIRE, 'shownNotices = shownNotices + 1', 'shownNotices = shownNotices + 0'),
    ('separate-own-counter', WIRE, 'if notice.owned then hiddenNotices = hiddenNotices + 1', 'if true then hiddenNotices = hiddenNotices + 1'),
    ('counter-idempotence', WIRE, 'if not notice.counted then', 'if true then'),
    ('manual-still-marks-offline', WIRE, 'local key = who(name)', 'local key = who(name); if manualWhisper(key, now) then return nil end'),
    ('hidden-decisions-exact-text', WIRE, 'if not notice.owned and not notice.hide then notice.text', 'if not notice.owned then notice.text'),
    ('exact-cache-precedence', WIRE, 'and (not cached or r.text == text) then cached = r end', 'then cached = r end'),
    ('callback-protected', WIRE, 'local function observeChatWhisper(_, chatType, _, target)\n    pcall(function()', 'local function observeChatWhisper(_, chatType, _, target)\n    local function direct(fn) fn() end; direct(function()'),
    ('net-fallback-disclosure', MAIN, 'or "Typed-whisper protection unavailable; all behaves like on (LayerEnemies whispers only)."', 'or "Typed-whisper protection active."'),
    ('quiet-query-current-mode', MAIN, 'if command=="quiet" then state=N.Wire.quietMode(LayerEnemiesDB.quietWhispers)', 'if command=="quiet" then state="on"'),
    ('chat-send-ban-stays', GATE, "or word == 'SendChatMessage' or", 'or False or'),
    ('hook-owner-gate', GATE, "assert filename == 'Wire.lua', 'chat post-hook outside Wire.lua: ' + filename", "assert True, 'mutant: hook anywhere'"),
    ('namespace-not-generally-allowed', GATE, "assert inspection and tokens[end:end + 1] == [('symbol', ')')], 'chat namespace escapes: ' + filename", "assert True, 'mutant: namespace escapes'"),
    ('review-M1-protect-everything', WIRE, 'if not key then manualProtectAll = now; return end', 'if not key then return end'),
    ('review-M1-non-ASCII', WIRE, r'not raw:find("[\128-\255]")', 'true'),
    ('review-Note-on-mode', WIRE, 'notice.hide = notice.owned == true and mode ~= "off" and not manualWhisper(key, now)', 'notice.hide = notice.owned == true and mode ~= "off"'),
    ('review-S1-every-existing-hook', WIRE, 'observerReady = (modern or legacy) and (modernAbsent or modern) and (legacyAbsent or legacy)', 'observerReady = modern or legacy'),
    ('review-S2-overflow-lifetime', WIRE, 'if #manualWhispers >= 16 then manualProtectAll = now; return end', 'if #manualWhispers >= 16 then table.remove(manualWhispers, 1) end'),
    ('review-S2-full-ledger', WIRE, 'if manualProtectAll or #manualWhispers >= 16 then return true end', 'if manualProtectAll then return true end'),
    ('review-S3-exact-once', GATE, "assert len(sites) == 1, 'chat post-hook must appear exactly once in Wire.lua: ' + registration", "assert len(sites) >= 1, 'chat post-hook must appear exactly once in Wire.lua: ' + registration"),
    ('review-S3-no-pcall-binding', GATE, "if word == 'pcall':", 'if False:'),
]


def run(root, policy=False):
    command = ['python3', '-B', 'test/test_verify.py', 'WhisperHookPolicyTests'] if policy else [str(LUA), 'test/harness.lua', '--only', 'QuietAll']
    return subprocess.run(command, cwd=root, capture_output=True, text=True, timeout=120)


def main():
    results = []
    with tempfile.TemporaryDirectory(prefix='le-quiet-all-mutants-', dir=SCRATCH) as name:
        root = Path(name)
        for folder in ('LayerEnemies', 'test'):
            shutil.copytree(ROOT / folder, root / folder, ignore=shutil.ignore_patterns('__pycache__'))
        for policy in (False, True):
            baseline = run(root, policy)
            assert baseline.returncode == 0, baseline.stdout + baseline.stderr
        for rule, file, old, new in MUTANTS:
            path = root / file
            original = path.read_text()
            assert original.count(old) == 1, (rule, original.count(old))
            path.write_text(original.replace(old, new, 1))
            try:
                if path.suffix == '.lua':
                    subprocess.run([str(LUA.with_name('luac')), '-p', str(path)], check=True, capture_output=True)
                result = run(root, file == GATE)
                failures = [re.sub(r'0x[0-9a-fA-F]+', '0xADDR', line) for line in (result.stdout + result.stderr).splitlines() if line.startswith(('FAIL ', 'FAIL: '))]
                caught = result.returncode != 0 and bool(failures)
                results.append({'rule': rule, 'caught': caught, 'failures': failures})
                print(('CAUGHT ' if caught else 'SURVIVED ') + rule, flush=True)
            finally:
                path.write_text(original)
    report = ROOT / 'notes/quiet-all-mutants.json'
    content = json.dumps(results, indent=2) + '\n'
    if not report.exists() or report.read_text() != content:
        report.write_text(content)
    caught = sum(row['caught'] for row in results)
    print(f'MUTANTS: {caught}/{len(results)} caught')
    assert caught == len(results), [r['rule'] for r in results if not r['caught']]


if __name__ == '__main__':
    main()
