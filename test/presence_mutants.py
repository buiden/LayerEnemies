"""PR 1 behavioral mutants; isolated scratch copies, never mutate the worktree.
Run: python3 test/presence_mutants.py [--output notes/presence-mutants.json]
Each mutant must compile and fail its named behavioral test. Baseline and final
runs must pass. No network/client access; TMPDIR stays under the owner scratch.
"""
from pathlib import Path
import argparse
import json
import os
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
A, P, M, F, U = ["LayerEnemies/" + n + ".lua" for n in ("Adapters", "Presence", "Main", "Find", "UI")]
TRACER = "tracked community tracer has zone and no action or send"
CAPS = "fifty per tick thousand per club twenty clubs and guild exclusion"
FRIENDS = "friends use only online characters in this project and cap 200"
TTL = "expiry boundary future clocks and remove clear session state"
SAFETY = "no roster adapters with empty Find combat instance or unknown safety"
MUTANTS = [
    ("withdrawal resets shared cooldown", M, "M.presenceShared[hash]=nil\n",
     "M.presenceShared[hash]=nil; M.presenceSharedAlerts.presenceAlerts[hash]=nil\n",
     "guild watch hash matches are session-only possible rows and withdraw"),
    ("drop tracked-name filter", M,
     "if not senders or #senders==0 or not N.OpenMap.match({names={sender}},sender,me) then return end",
     "if not hash then return end",
     "untracked offline mobile unknown and blank rows store nothing"),
    ("accept Offline", P, "presence~=1 and presence~=4 and presence~=5", "presence~=1 and presence~=3 and presence~=4 and presence~=5",
     "untracked offline mobile unknown and blank rows store nothing"),
    ("drop secret refusal", A, 'if hidden then return nil,"secret" end', 'if false then return nil,"secret" end',
     "secret fields refuse exactly one row and diagnostic has no names"),
    ("TTL inclusive boundary", P, "now-r.at>=P.TTL", "now-r.at>P.TTL", TTL),
    ("drop member cap", A, "for i=1,1000 do", "for i=1,1001 do", CAPS),
    ("allow Ask on presence-only", F, 'if not loc and not place then row.status="online ("..presence.route..")"; row.canAsk=false end',
     'if not loc and not place then row.status="online ("..presence.route..")"; row.canAsk=true end', TRACER),
    ("drop club cap", A, "for i=1,20 do", "for i=1,21 do", CAPS),
    ("read guild and character clubs", A, "if kind==0 then", "if kind<=2 then", CAPS),
    ("double per-frame work", P, "P.TTL,P.EVERY,P.STEP=660,300,50", "P.TTL,P.EVERY,P.STEP=660,300,100", CAPS),
    ("drop friend cap", A, "math.min(n,200)", "math.min(n,201)", FRIENDS),
    ("accept offline friend", A, "if online~=true or pid~=project then", "if pid~=project then", FRIENDS),
    ("accept other project", A, "if online~=true or pid~=project then", "if online~=true then", FRIENDS),
    ("missing faction guessed Horde", A, "local faction,presence=S.num(v(r.faction)),S.num(v(r.presence))",
     "local faction,presence=S.num(v(r.faction)) or 0,S.num(v(r.presence))",
     "missing erroring and secret APIs or tables are silent"),
    ("scan in combat", M, "M.find and #M.find.names>0 and not A.inCombat() and A.inInstance()==false",
     "M.find and #M.find.names>0 and A.inInstance()==false", SAFETY),
    ("scan in instances", M, "M.find and #M.find.names>0 and not A.inCombat() and A.inInstance()==false",
     "M.find and #M.find.names>0 and not A.inCombat()", SAFETY),
    ("scan empty Find", M, "M.find and #M.find.names>0 and not A.inCombat() and A.inInstance()==false",
     "M.find and not A.inCombat() and A.inInstance()==false", SAFETY),
    ("keep future record", P, " or now<r.at", "", TTL),
    ("repeat before 600 seconds", F, "old and now>=old and now-old<600", "old and now>=old and now-old<599",
     "per name 600 second silent alert uses shared burst throttle"),
    ("lose bare-name matching", M, "N.OpenMap.match(M.find,sender,me,true)", "N.OpenMap.match(M.find,sender,me)",
     "qualified realm stays exact and bare name matches any realm"),
    ("friend falls back after realm conflict", M, 'if route=="friend" then sender=N.OpenMap.bnName(member.name,member.realm) end',
     'if route=="friend" then sender=N.OpenMap.bnName(member.name,member.realm) or member.name end',
     "invalid friend realm never falls back to a bare character"),
    ("presence overrides sighting", F, "if not loc and not place then row.status=", "if true then row.status=",
     "real sighting and OpenMap retain their status and Ask target"),
    ("scan every poll", M, "time-M.presenceAt<N.Presence.EVERY", "time-M.presenceAt<0",
     "automatic 300s cadence and Find opening refresh without overlap"),
    ("skip Find tab scan", U, 'if tab=="find" and U.tab~="find" then N.Main.presenceScan(true) end',
     "if false then N.Main.presenceScan(true) end", "automatic 300s cadence and Find opening refresh without overlap"),
    ("drop UI space for presence", U, "local extra=e.presence and 56 or 0", "local extra=0",
     "UI and slash text show zone age and hide stale pooled line"),
    ("presence send attempt", M, "N.Presence.note(M.find,name,record,now()) end",
     'N.Presence.note(M.find,name,record,now()); S.call(N.Wire.send,"LEGW1","presence","GUILD") end', TRACER),
    ("save presence names", M, "N.Presence.note(M.find,name,record,now()) end",
     "N.Presence.note(M.find,name,record,now()); LayerEnemiesDB.presence=M.find.presence end", TRACER),
    ("presence plays sound", M, 'M.findNotice(name.." — "..M.presenceText(',
     'S.call(M.alertSound); M.findNotice(name.." — "..M.presenceText(', TRACER),
    ("omit guild watch matches", M, "if not name then\n        -- Guild lists", "if not name then return end\n    if not name then\n        -- Guild lists",
     "guild watch hash matches are session-only possible rows and withdraw"),
    ("zone length cap lost", P, "S.str(member.zone,120)", "S.str(member.zone,121)",
     "pure bounds and adapter field allowlists"),
    ("name length cap lost", P, "S.str(member.name,100)", "S.str(member.name,101)",
     "pure bounds and adapter field allowlists"),
]


def run(lua, cwd):
    r = subprocess.run([str(lua), "test/harness.lua", "--presence-only"], cwd=cwd,
                       capture_output=True, text=True, timeout=60)
    return r.returncode, r.stdout + r.stderr


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lua", default=os.environ.get("LAYERENEMIES_LUA", "/opt/data/tools/lua/lua-5.1.5/src/lua"))
    parser.add_argument("--output", default="notes/presence-mutants.json")
    args = parser.parse_args()
    lua = Path(args.lua)
    code, baseline = run(lua, ROOT)
    assert code == 0, baseline
    results = []
    scratch = Path(os.environ.get("TMPDIR", "/opt/data/cache/scratch"))
    assert str(scratch).startswith("/opt/data/cache/scratch"), "use the owner scratch directory"
    with tempfile.TemporaryDirectory(prefix="le-presence-mutants-", dir=scratch) as directory:
        work = Path(directory)
        shutil.copytree(ROOT / "LayerEnemies", work / "LayerEnemies")
        shutil.copytree(ROOT / "test", work / "test")
        for label, filename, old, new, target in MUTANTS:
            path = work / filename
            original = path.read_text()
            assert original.count(old) == 1, (label, "anchor count", original.count(old))
            try:
                path.write_text(original.replace(old, new))
                subprocess.run([str(lua.with_name("luac")), "-p", str(path)], check=True, capture_output=True)
                code, output = run(lua, work)
                failures = [s for s in output.splitlines() if s.startswith("FAIL Presence:")]
                caught = code != 0 and any(s.startswith("FAIL Presence: " + target + ":") for s in failures)
                results.append({"mutant": label, "caught": caught, "target": target, "failures": failures})
                print(("KILLED " if caught else "SURVIVED ") + label)
            finally:
                path.write_text(original)
    final_code, final = run(lua, ROOT)
    assert final_code == 0, final
    baseline_result = re.search(r"RESULT: .*", baseline)
    final_result = re.search(r"RESULT: .*", final)
    assert baseline_result and final_result, "missing harness result"
    payload = {"baseline": baseline_result[0],
               "final": final_result[0], "mutants": results,
               "caught": sum(r["caught"] for r in results), "total": len(results)}
    output = ROOT / args.output
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(payload, indent=2) + "\n")
    assert payload["caught"] == payload["total"], "mutant survived; strengthen the behavioral test"
    print(f"RESULT: {payload['caught']}/{payload['total']} mutants killed; baseline/final green")


if __name__ == "__main__":
    main()
