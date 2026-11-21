"""PR 1 behavioral mutants; isolated scratch copies, never mutate the worktree.
Run: python3 test/presence_mutants.py [--output notes/presence-mutants.json]
Each mutant must compile and fail its named behavioral test. Baseline and final
runs must pass. No network/client access; temporary copies honor TMPDIR.
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
    ("R2 restore 56px presence text floor", U,
     "layout.presenceHeight=fitText(U.measure)", "layout.presenceHeight=fitText(U.measure,56)",
     "measured presence cards keep several per page without overlap"),
    ("R2 restore fixed presence card surcharge", U,
     'local function minimumHeight(e)\n        if U.tab=="find" then',
     'local function minimumHeight(e)\n        if U.tab=="find" then\n            if e.presence then return 76+56 end',
     "measured presence cards keep several per page without overlap"),
    ("R2 resolve offline member accounts", A,
     "if presence~=1 and presence~=4 and presence~=5 then return nil end", "if not presence then return nil end",
     "only online community members resolve Battle.net accounts"),
    ("R1 match club display name instead of resolved character", A,
     'local name=S.str(v(game.characterName),100)', 'local name=S.str(v(r.name),100)',
     "club character comes from account not member display name"),
    ("R1 accept non WoW game account", A,
     'if online~=true or client~="WoW" then', 'if online~=true then',
     "account resolution unavailable secret incomplete and non WoW fail silent"),
    ("R2 keep reread offline evidence until TTL", P,
     'if r.source==source then records[name]=nil end', 'if false then records[name]=nil end',
     "reread offline or non WoW drops personal and shared evidence immediately"),
    ("R3 omit resolved character count", M,
     'job.stats.resolved=job.stats.resolved+1', 'job.stats.resolved=job.stats.resolved+0',
     "diagnostic separates unresolved zoneless same faction and unmatched members"),
    ("R3 omit opposite faction count", M,
     'job.stats.opposite=job.stats.opposite+1', 'job.stats.opposite=job.stats.opposite+0',
     "diagnostic separates unresolved zoneless same faction and unmatched members"),
    ("R4 allow unlimited Find opening refreshes", P, 'P.OPEN=60', 'P.OPEN=0',
     "Find switches and window opens share one force per 60 seconds"),
    ("owner deviation accept same faction namesake", M,
     'if not record or N.OpenMap.faction(record.faction,S.call(UnitFactionGroup,"player"))~="opposite" then return end',
     'if not record then return end',
     "untracked offline mobile unknown and blank rows store nothing"),
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
    ("TTL inclusive boundary", P, "now-r.at>=ttl", "now-r.at>ttl", TTL),
    ("drop member cap", A, "for i=1,1000 do", "for i=1,1001 do", CAPS),
    ("allow Ask on presence-only", F, 'if not loc and not place then row.status="online ("..presence.route..")"; row.canAsk=false end',
     'if not loc and not place then row.status="online ("..presence.route..")"; row.canAsk=true end', TRACER),
    ("drop club cap", A, "for i=1,20 do", "for i=1,21 do", CAPS),
    ("read guild and character clubs", A, "if kind==0 then", "if kind<=2 then", CAPS),
    ("double per-frame work", P, "P.TTL,P.EVERY,P.STEP=660,300,50", "P.TTL,P.EVERY,P.STEP=660,300,100", CAPS),
    ("drop friend cap", A, "for i=1,math.min(n,200) do\n            local r,reason=presenceRead",
     "for i=1,math.min(n,201) do\n            local r,reason=presenceRead", FRIENDS),
    ("accept offline friend", A, "if online~=true or pid~=project then", "if pid~=project then", FRIENDS),
    ("accept other project", A, "if online~=true or pid~=project then", "if online~=true then", FRIENDS),
    ("missing faction guessed Horde", A, "local zone,faction=S.str(v(game.areaName),120),S.str(v(game.factionName),16)",
     'local zone,faction=S.str(v(game.areaName),120),S.str(v(game.factionName),16) or "Horde"',
     "missing erroring and secret APIs or tables are silent"),
    ("scan in combat", M, "M.find and (#M.find.names>0 or M.friendSendable()) and not A.inCombat() and A.inInstance()==false",
     "M.find and (#M.find.names>0 or M.friendSendable()) and A.inInstance()==false", SAFETY),
    ("scan in instances", M, "M.find and (#M.find.names>0 or M.friendSendable()) and not A.inCombat() and A.inInstance()==false",
     "M.find and (#M.find.names>0 or M.friendSendable()) and not A.inCombat()", SAFETY),
    ("scan empty Find", M, "M.find and (#M.find.names>0 or M.friendSendable()) and not A.inCombat() and A.inInstance()==false",
     "M.find and not A.inCombat() and A.inInstance()==false", SAFETY),
    ("keep future record", P, " or now<r.at", "", TTL),
    ("repeat before 600 seconds", F, "old and now>=old and now-old<600", "old and now>=old and now-old<599",
     "per name 600 second silent alert uses shared burst throttle"),
    ("lose bare-name matching", M, "N.OpenMap.match(M.find,sender,me,true)", "N.OpenMap.match(M.find,sender,me)",
     "qualified realm stays exact and bare name matches any realm"),
    ("friend falls back after realm conflict", M, 'if route=="friend" or route=="community" then sender=N.OpenMap.bnName(member.name,member.realm) end',
     'if route=="friend" or route=="community" then sender=N.OpenMap.bnName(member.name,member.realm) or member.name end',
     "invalid friend realm never falls back to a bare character"),
    ("presence overrides sighting", F, "if not loc and not place then row.status=", "if true then row.status=",
     "real sighting and OpenMap retain their status and Ask target"),
    ("scan every poll", M, "time-M.presenceAt<N.Presence.EVERY", "time-M.presenceAt<0",
     "automatic 300s cadence and Find opening refresh without overlap"),
    ("skip Find tab scan", U, 'if tab=="find" and U.tab~="find" then N.Main.presenceOpen() end',
     "if false then N.Main.presenceOpen() end", "automatic 300s cadence and Find opening refresh without overlap"),
    ("ignore measured presence height at render", U, "r.presence:SetHeight(layout.presenceHeight)", "r.presence:SetHeight(layout.presenceHeight+200)",
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


def stable_failure(line):
    # Keep the test filename, line, assertion and traceback; only the random
    # checkout root and Lua object address are nondeterministic identities.
    line = re.sub(r'File "[^"\n]*/(test/[^"/]+\.py)"', r'File "\1"', line)
    return re.sub(r'\b(table|function|thread|userdata): 0x[0-9a-fA-F]+\b', r'\1: <address>', line)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lua", default=os.environ.get("LAYERENEMIES_LUA", "/opt/data/tools/lua/lua-5.1.5/src/lua"))
    parser.add_argument("--output", default="notes/presence-mutants.json")
    args = parser.parse_args()
    lua = Path(args.lua)
    code, baseline = run(lua, ROOT)
    assert code == 0, baseline
    results = []
    # Honor the caller's TMPDIR (or the platform default), independent of clone path.
    with tempfile.TemporaryDirectory(prefix="le-presence-mutants-") as directory:
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
                failures = [stable_failure(s) for s in output.splitlines() if s.startswith("FAIL Presence:")]
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
    evidence = json.dumps(payload, indent=2) + "\n"
    if not output.exists() or output.read_text() != evidence:
        output.write_text(evidence)
    assert payload["caught"] == payload["total"], "mutant survived; strengthen the behavioral test"
    print(f"RESULT: {payload['caught']}/{payload['total']} mutants killed; baseline/final green")


if __name__ == "__main__":
    main()
