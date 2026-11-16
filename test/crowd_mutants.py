"""Behavioral crowd mutants; run from any directory (stdlib only).

Usage: python test/crowd_mutants.py --lua /path/to/lua5.1
       python test/crowd_mutants.py --lua /path/to/lua5.1 --output notes/crowd-mutants.json

Requires a green harness. Each single mutant must compile and fail its named
regression, not merely crash. Source bytes are restored in finally blocks,
including on timeouts/errors. A final unmodified harness run checks restoration.
Do not run concurrently with any writer or verifier of this checkout.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
# label, relative source, exact old text, replacement, required killing test
MUTANTS = [
    ("all recent marked shared", "LayerEnemies/Share.lua",
     "for _, e in ipairs(fitted) do", "for _, e in ipairs(rep.enemies) do",
     "crowd 5: nine enemies use consecutive 4,4,1 slots without repeats"),
    ("freshness back to 15", "LayerEnemies/Share.lua",
     "3, 15, 60, 45", "3, 15, 60, 15",
     "crowd 6: a sighting waiting 30 seconds keeps its real age"),
    ("more than one O per 15 seconds", "LayerEnemies/Share.lua",
     "3, 15, 60, 45", "3, 1, 60, 45",
     "crowd rate: duplicate and fractional pumps never open an early slot"),
    ("fourth line allowed", "LayerEnemies/Share.lua",
     "Sh.LINES = 3", "Sh.LINES = 4",
     "crowd cap: no fourth line for a 13-plus snapshot even at age 45"),
    ("repeat name inside 60 seconds", "LayerEnemies/Share.lua",
     "3, 15, 60, 45", "3, 15, 15, 45",
     "crowd repeat: a new arrival never pulls a recently sent name along"),
    ("age field is not the real age", "LayerEnemies/Relay.lua",
     "age = now - at", "age = 0",
     "crowd 6: a sighting waiting 30 seconds keeps its real age"),
    ("byte-trimmed entries marked shared", "LayerEnemies/Relay.lua",
     "items[#items] = nil; fitted[#fitted] = nil; line = packed()",
     "items[#items] = nil; line = packed()",
     "crowd packing: byte-trimmed names wait for the next slot"),
    ("refused send marked shared", "LayerEnemies/Main.lua",
     "N.Share.sent(M.share,rep,accepted and fitted or {},time)",
     "N.Share.sent(M.share,rep,fitted or {},time)",
     "crowd refusal: no shared stamp on a refused send and retry still waits 15 seconds"),
    ("cancelled snapshot can reopen", "LayerEnemies/Share.lua",
     "for key in pairs(seen) do st.skipped[key] = now end",
     "for key in pairs(seen) do st.skipped[key] = nil end",
     "crowd switch: share off cancels the remaining snapshot without resetting pace"),
    ("cancelled stores accumulate", "LayerEnemies/Share.lua",
     "    S.clear(st.skipped)\n", "",
     "crowd cancel memory: repeated boundaries keep skipped keys bounded to the current store"),
]


def run(lua):
    result = subprocess.run([lua, "test/harness.lua"], cwd=ROOT,
                            text=True, capture_output=True, timeout=120)
    match = re.search(r"^RESULT: (\d+) tests passed, (\d+) failed, (\d+) assertions$",
                      result.stdout, re.M)
    assert match, "harness did not complete: " + result.stderr
    return result, match.group(0), int(match[2])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lua", required=True, help="Lua 5.1 interpreter path")
    parser.add_argument("--output", type=Path, help="optional JSON evidence file")
    args = parser.parse_args()
    baseline, summary, failures = run(args.lua)
    assert baseline.returncode == 0 and failures == 0, summary
    originals = {name: (ROOT / name).read_bytes() for _, name, *_ in MUTANTS}
    report = {"baseline": summary, "mutants": []}

    def save():
        if args.output:
            args.output.write_text(json.dumps(report, indent=2) + "\n")

    try:
        for label, name, old, new, required in MUTANTS:
            path = ROOT / name
            original = originals[name]
            source = original.decode()
            assert source.count(old) == 1, "nonunique or missing anchor: " + label
            try:
                path.write_text(source.replace(old, new, 1))
                # A syntax failure is not a killed behavioral mutant.
                subprocess.run([args.lua, "-e", "assert(loadfile(" + json.dumps(name) + "))"],
                               cwd=ROOT, capture_output=True, text=True, check=True, timeout=20)
                result, summary, failures = run(args.lua)
                killed = [line for line in result.stdout.splitlines() if line.startswith("FAIL ")]
                target = next((line for line in killed if line.startswith("FAIL " + required + ": ")), None)
                assert result.returncode != 0 and failures > 0 and target, "mutant survived its target: " + label
                assert ": expected " in target, "not an assertion failure: " + target
                report["mutants"].append({"mutant": label, "killing_test": required,
                                          "failure": target, "result": summary})
                save()
                print(label + " -> " + required)
            finally:
                path.write_bytes(original)
    finally:
        for name, original in originals.items():
            (ROOT / name).write_bytes(original)
        assert all((ROOT / name).read_bytes() == original for name, original in originals.items())
        report["restored_sha256"] = {name: hashlib.sha256(raw).hexdigest() for name, raw in originals.items()}
        save()
    final, summary, failures = run(args.lua)
    assert final.returncode == 0 and failures == 0, summary
    assert len(report["mutants"]) == len(MUTANTS)
    report["restored_result"] = summary
    save()
    print(summary)
    print("Killed %d/%d behavioral mutants; all source bytes restored." % (len(report["mutants"]), len(MUTANTS)))


if __name__ == "__main__":
    main()
