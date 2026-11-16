"""Local-only kill-record mutants. Restore every edited byte in finally; no dependencies."""
from pathlib import Path
import argparse
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
MUTANTS = [
    ("relay-old-D", "Kills 12b:", [
        ("LayerEnemies/Relay.lua", 'if now - record.at >= Rl.TTL.hh then return false, "too old" end', '-- age gate removed'),
        ("LayerEnemies/Relay.lua", 'if kill and age >= Rl.TTL.hh then return nil end', '-- send-time age gate removed'),
    ]),
    ("D-behind-hhMesh", "Kills 12a: whispered D reaches Find and guild in stand-down", [
        ("LayerEnemies/Main.lua", 'if mesh then return end', 'if mesh or not N.Net.allowed("hh","public") then return end'),
    ]),
    ("match-incomplete-killer", "Kills 11: incomplete killer", [
        ("LayerEnemies/HeadHunter.lua", 'if #enemy ~= 7 or enemy[2] ~= "" then return nil end',
         'if #enemy ~= 7 then return nil end'),
    ]),
    ("show-D-layer", "Kills 11: D creates a timed killer claim in stand-down", [
        ("LayerEnemies/HeadHunter.lua", 'return { type = "D", t = t, map = map, x = x, y = y, confidence = confidence,',
         'return { type = "D", t = t, map = map, x = x, y = y, layer = b36(f[10]), confidence = confidence,'),
        ("LayerEnemies/HeadHunter.lua", 't.rid = "D:" .. d.t; t.enemies = d.enemies; t.pos = "victim"\n                t.layer = { ns = "unknown" }',
         't.rid = "D:" .. d.t; t.enemies = d.enemies; t.pos = "victim"\n                t.layer = { ns = "zoneuid", value = d.layer }'),
        ("LayerEnemies/Main.lua", '..(record.kind=="killi" and " (inferred)" or "")},M.homeRealm())',
         '..(record.kind=="killi" and " (inferred)" or "")\n'
         '                ..(record.layer.value and (" · layer "..record.layer.value) or "")},M.homeRealm())'),
    ]),
    ("ask-relayed-kill", "Kills relay: guild claims never reach", [
        ("LayerEnemies/Find.lua", 'and loc.spotter~=nil and not loc.relayed and loc.kind~="claim"', 'and loc.spotter~=nil'),
    ]),
    ("accept-sim", "Kills 12: simulated", [
        ("LayerEnemies/HeadHunter.lua", 'if confidence ~= "e" and confidence ~= "i" then return nil end',
         'if confidence ~= "e" and confidence ~= "i" and confidence ~= "s" then return nil end'),
    ]),
    ("ignore-author-victim", "Kills 11: author must be", [
        ("LayerEnemies/HeadHunter.lua", 'if not victim or not authorKey or authorKey ~= victimKey then return nil end',
         'if not victim or not authorKey then return nil end'),
    ]),
    ("no-kill-rate-cap", "Kills relay budget: fifth", [
        ("LayerEnemies/Relay.lua", 'if #st.kills >= Rl.KILL_RATE then return false end', '-- rate cap removed'),
    ]),
    ("relay-non-whisper-catchup", "Kills relay: non-whisper", [
        ("LayerEnemies/Relay.lua", 'if record.route ~= "WHISPER" then return false, "kill route" end', '-- route gate removed'),
    ]),
    ("repeat-kill-id", "Kills R1 M1: one D id", [
        ("LayerEnemies/Relay.lua", 'if not event or event.offered then return false, "seen" end',
         'if not event then return false, "seen" end'),
    ]),
    ("short-kill-memory", "Kills R1 M1: one D id", [
        ("LayerEnemies/Relay.lua", 'expires = now + N.Known.TTL + N.HeadHunter.WINDOW', 'expires = now + 120'),
    ]),
    ("refresh-guild-kill-age", "Kills R1 S2:", [
        ("LayerEnemies/Relay.lua", 'if not event or event.found then return false end', 'if not event then return false end'),
        ("LayerEnemies/Relay.lua", 'record.at = math.min(record.at, event.at)', '-- original timestamp discarded'),
    ]),
    ("kill-self", "Kills R1 S1:", [
        ("LayerEnemies/Main.lua", 'and not M.isMe(enemy.name)', ''),
    ]),
    ("kill-victim", "Kills R1 S1:", [
        ("LayerEnemies/Main.lua", 'and killer~=record.okey', ''),
    ]),
    ("spend-own-reserve", "Kills R1 M2:", [
        ("LayerEnemies/Relay.lua", 'if ok then ok, why = Rl.spend(now, true) end',
         '-- reserve removed'),
    ]),
    ("forget-own-prefix-traffic", "Kills R1 M2: earlier own traffic", [
        ("LayerEnemies/Relay.lua", 'tokens = math.max(0, tokens - cost)',
         'if relay then tokens = math.max(0, tokens - cost) end'),
    ]),
    ("share-off-relays", "Kills R1 share:", [
        ("LayerEnemies/Main.lua", 'if not M.sharing() then return end\n    local time=now()', '-- offer gate removed\n    local time=now()'),
        ("LayerEnemies/Main.lua", 'if not M.sharing() then N.Relay.clear(M.relay); return end', '-- dispatch gate removed'),
        ("LayerEnemies/Main.lua", 'if not on and M.relay then N.Relay.clear(M.relay) end', '-- pending cancellation removed'),
    ]),
    ("kills-bypass-shared-reserve", "Kills R2 reserve:", [
        ("LayerEnemies/Relay.lua", 'if ok then ok, why = Rl.spend(now, true) end',
         'if ok and not kill then ok, why = Rl.spend(now, true) end'),
    ]),
    ("full-kill-ledger-drops-new-id", "Kills R2 ledger:", [
        ("LayerEnemies/Relay.lua", 'if n >= Rl.MAX then st.killRecords[oldestKey] = nil end',
         'if n >= Rl.MAX then return nil end'),
    ]),
]


def run(command):
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    output = result.stdout + result.stderr
    counts = re.search(r"RESULT: (\d+) tests passed, (\d+) failed, (\d+) assertions", output)
    assert counts, "harness did not reach RESULT:\n" + output
    return result, output, int(counts[2])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--lua", default="lua")
    args = parser.parse_args()
    command = [args.lua, "test/harness.lua", "--kills-only"]
    baseline, output, failed = run(command)
    assert baseline.returncode == 0 and failed == 0, output
    results = []
    for name, expected, edits in MUTANTS:
        originals = {path: (ROOT / path).read_bytes() for path, _, _ in edits}
        try:
            for path, before, after in edits:
                file = ROOT / path
                text = file.read_text()
                assert text.count(before) == 1, (name, path, text.count(before))
                file.write_text(text.replace(before, after))
            for path in originals:
                subprocess.run([str(Path(args.lua).with_name('luac')), '-p', path], cwd=ROOT, check=True)
            result, output, failed = run(command)
            (ROOT / ("build-kill-mutant-" + name + ".log")).write_text(output)
            caught = [line[5:] for line in output.splitlines() if line.startswith("FAIL ")]
            row = {"mutant": name, "failed": failed, "rc": result.returncode,
                   "expected_case_failed": any(line.startswith(expected) for line in caught), "caught_by": caught}
            results.append(row)
            print(json.dumps(row), flush=True)
            assert result.returncode != 0 and failed > 0 and row["expected_case_failed"], name + " survived its regression"
        finally:
            for path, original in originals.items():
                (ROOT / path).write_bytes(original)
    final, output, failed = run(command)
    assert final.returncode == 0 and failed == 0, output
    print(next(line for line in output.splitlines() if line.startswith("RESULT:")))
    (ROOT / "build-kill-mutants-summary.log").write_text(json.dumps(results, indent=2) + "\n")


if __name__ == "__main__":
    main()
