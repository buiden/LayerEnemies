"""Run isolated Find20 mutants; restore source bytes even on failure or timeout.

Usage: python test/find20_mutants.py /path/to/lua-5.1
No live client or outgoing API is used; each mutant runs the Find20 suite; full verification remains unfiltered.
"""
from pathlib import Path
import json
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
MUTANTS = [
    ("rebuild-every-report", "LayerEnemies/Find.lua",
     "function F.report(st,r,home)\n    F.home(st,home)",
     "function F.report(st,r,home)\n    F.home(st,home); F.rebuild(st)"),
    ("cap-back-to-five", "LayerEnemies/Find.lua",
     "F.MAX,F.TTL,F.ALERT=20,600,300", "F.MAX,F.TTL,F.ALERT=5,600,300"),
    ("saved-list-no-dedupe", "LayerEnemies/Find.lua",
     "if name and not seen[key] then", "if name then"),
    ("track-prints-all-rows", "LayerEnemies/Main.lua",
     'if N.Find.fold(row.name)==key then M.say("LayerEnemies: "..M.findText(row)); printed=row.name; break end',
     'M.say("LayerEnemies: "..M.findText(row)); printed=row.name'),
    ("no-sound-cooldown", "LayerEnemies/Main.lua",
     "if not quiet and (not st.soundAt or time-st.soundAt>=10) then", "if not quiet then"),
    ("no-detail-line-limit", "LayerEnemies/Main.lua",
     "if window.lines<3 then", "if true then"),
    ("overflow-not-counted", "LayerEnemies/Main.lua",
     "window.more=window.more+1", "window.more=window.more"),
    ("no-realmless-name-alias", "LayerEnemies/Find.lua",
     "index(st.byName,entry.shortKey,entry)", "index(st.byName,entry.key,entry)"),
    ("located-oldest-first", "LayerEnemies/UI.lua",
     "if aa~=bb then return aa>bb end", "if aa~=bb then return aa<bb end"),
    ("missing-status-stays-tall", "LayerEnemies/UI.lua",
     'r.sub:SetHeight(layout.subHeight)',
     'r.sub:SetHeight(U.tab=="find" and not e.at and math.max(44,layout.subHeight) or layout.subHeight)'),
    ("no-home-poll-rebuild", "LayerEnemies/Main.lua",
     "    N.Find.home(M.find,M.homeRealm())\n", ""),
]


def main():
    lua = sys.argv[1] if len(sys.argv) > 1 else "lua"
    originals = {path: (ROOT / path).read_bytes() for _, path, _, _ in MUTANTS}
    baseline = subprocess.run([lua, "test/harness.lua", "--only=Find20"], cwd=ROOT, capture_output=True, text=True, timeout=120)
    if baseline.returncode:
        raise SystemExit("Refusing mutation run: baseline harness is not green\n" + baseline.stdout + baseline.stderr)
    results = []
    try:
        for name, path, old, new in MUTANTS:
            target = ROOT / path
            source = originals[path].decode()
            if source.count(old) != 1:
                raise AssertionError("mutation target must be unique: " + name)
            try:
                target.write_text(source.replace(old, new, 1))
                run = subprocess.run([lua, "test/harness.lua", "--only=Find20"], cwd=ROOT, capture_output=True, text=True, timeout=120)
                output = run.stdout + run.stderr
                (ROOT / ("build-find20-mutant-" + name + ".log")).write_text(output)
                failures = [line for line in output.splitlines() if line.startswith("FAIL Find20")]
                result = {"mutant": name, "returncode": run.returncode,
                          "killed": run.returncode != 0 and bool(failures), "tests": failures}
                results.append(result)
                print(name + ": " + (failures[0] if result["killed"] else "SURVIVED or invalid execution"))
            finally:
                target.write_bytes(originals[path])
    finally:
        for path, content in originals.items():
            (ROOT / path).write_bytes(content)
            assert (ROOT / path).read_bytes() == content, "failed restoration: " + path
        (ROOT / "build-find20-mutants.log").write_text(json.dumps(results, indent=2) + "\n")
    if len(results) != len(MUTANTS) or not all(row["killed"] for row in results):
        raise SystemExit(1)
    print("MUTANTS: %d/%d killed; original source bytes restored" % (len(results), len(MUTANTS)))


if __name__ == "__main__":
    main()
