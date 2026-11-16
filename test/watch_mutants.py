"""Behavioral watch-list mutants; stdlib only, no live client.

Usage: python test/watch_mutants.py --lua /path/to/lua5.1
       python test/watch_mutants.py --lua /path/to/lua5.1 --output notes/watch-mutants.json

Each mutant must compile and fail its named assertion, not merely crash. The
full harness runs before, during and after mutation; source bytes are restored
in finally, including on timeouts. Do not run alongside writers to this checkout.
"""
from pathlib import Path
import argparse
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
WATCH = "LayerEnemies/Watch.lua"
MAIN = "LayerEnemies/Main.lua"
SHARE = "LayerEnemies/Share.lua"
# label, file, exact anchor, mutation, required behavioral killing test
MUTANTS = [
    ("hash every held list per sighting", WATCH,
     "function W.match(st,name,now)\n    local hash=W.hash(name)",
     "function W.match(st,name,now)\n"
     "    for _,held in pairs(st.held) do for saved in pairs(held.hashes or {}) do N.Hash.hash6(saved) end end\n"
     "    local hash=W.hash(name)",
     "watch lookup budget: one hash per sighting regardless of held-list size"),
    ("accept incomplete part set", WATCH,
     "for i=1,total do if not p.parts[i] then return end end",
     'for i=1,total do p.parts[i]=p.parts[i] or "" end',
     "watch 16: hundred hashes commit only when all three parts arrive"),
    ("no per-sender hash cap", WATCH, "100,3,200,39", "1000,3,200,39",
     "watch 24: 101st hash, fourth part and malformed data drop only the incoming set"),
    ("list never expires", WATCH, "1500,120,3", "1500000000,120,3",
     "watch 18: refresh extends 25-minute expiry and clear removes the index at once"),
    ("notice on relayed entries", MAIN,
     "function M.findRecord(record)\n",
     "function M.findRecord(record)\n"
     '    if record.hand=="relayed" then for _,e in ipairs(record.enemies or {}) do\n'
     '        M.watchNotice({name=e.name,class=e.class,level=e.level,source="own relay",faction="opposite"})\n'
     "    end end\n",
     "watch 21: no notice for own-list, reported, relayed, guild O or friendly entries"),
    ("no T rate limit", WATCH, "1500,120,3", "1500,120,3000",
     "watch 22: T hard cap waits and retries after three actual sends in sixty seconds"),
    ("match by class and level", WATCH,
     "    if not listed or ours or #senders==0 then return end",
     '    if not listed and e.class=="MAGE" and e.level==60 then\n'
     "        hash=next(st.byHash)\n"
     "        if hash then listed=true; for key in pairs(st.byHash[hash]) do senders[#senders+1]=st.held[key].name end end\n"
     "    end\n"
     "    if not listed or ours or #senders==0 then return end",
     "watch 25: folded base-name hash matches case and realm, never class and level"),
    ("find sharing-off still sends refresh", WATCH,
     "(st.dirty or (st.on and next(st.own)))", "(st.dirty or next(st.own))",
     "watch 17: find share off sends one clear, stops refresh, and keeps local Find"),
    ("master sharing-off still sends", MAIN,
     "local allowed=same and not M.guildWhy() and A.inInstance()==false and M.sharing()",
     "local allowed=same and not M.guildWhy() and A.inInstance()==false",
     "watch 22: no T outside guild, inside instance, or with master sharing off"),
    ("unlisted O goes first", SHARE,
     "return priority[a.key] > priority[b.key]", "return priority[a.key] < priority[b.key]",
     "watch 19: ninth listed enemy is in the first O line for either list owner"),
    # Early-repeat tickets were removed by the owner's sixty-second ruling.
    # Preserve receipt/withdrawal coverage against the replacement behavior.
    ("fitted names lose receipt cooldown", SHARE,
     "            if eligible then", "            if eligible or listed then",
     "watch receipt: fitted names retain their cooldown while still fresh"),
    ("withdrawn own list keeps hash priority", WATCH,
     "st.content=content; st.own=hashes; bump(st)",
     "st.content=content; if next(hashes) then st.own=hashes end; bump(st)",
     "watch withdrawal: a cleared list cannot prioritize an unsent name"),
    ("War Effort loses independent cooldown reservation", MAIN,
     "local public=N.Share.pickWe(M.share,M.store.localSeen,time,zone)",
     "local public=N.Share.pick(M.share.we or N.Share.new(),M.store.localSeen,time,zone)",
     "watch O locality: list changes never become extra War Effort names"),
    ("unlisted relay gets last token", "LayerEnemies/Relay.lua",
     "if a.listed~=b.listed then return a.listed end", "if a.listed~=b.listed then return b.listed end",
     "watch relays: listed name takes the last available token before unlisted reports"),
    ("list churn re-arms receipt cooldowns", WATCH,
     "    return changed and hashes or nil",
     "    if changed then S.clear(N.Main.share.shared); S.clear(N.Main.share.names) end\n"
     "    return changed and hashes or nil",
     "watch R1 repeat: list churn every 1 seconds preserves per-name sixty seconds"),
    ("unlisted sightings starve", SHARE,
     "            if eligible then",
     "            if eligible and (not watch or not next(watch.byHash) or listed) then",
     "watch R1 fairness: nine enemies all leave while four listed names churn"),
    ("bare subcommand is tracked", MAIN,
     'if command=="find share" or command=="find notice" then', 'if false then',
     "watch R1 slash: bare share shows usage without tracking or sharing it"),
    ("removed sender is readmitted", WATCH,
     "    if st.roster and not st.roster[key] then return end\n", "",
     "watch R1 roster: removed senders stay rejected until a complete roster readmits them"),
    ("hash notice claims definite identity", WATCH,
     'name.." may be tracked by "', 'name.." is tracked by "',
     "watch R1 wording: real hash collisions never claim definite identity"),
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
    parser.add_argument("--lua", required=True, help="Lua 5.1 interpreter")
    parser.add_argument("--output", type=Path, help="optional JSON evidence")
    args = parser.parse_args()
    base, summary, failures = run(args.lua)
    assert base.returncode == 0 and failures == 0, summary
    originals = {name: (ROOT / name).read_bytes() for _, name, *_ in MUTANTS}
    report = {"baseline": summary, "mutants": []}

    def save():
        if args.output:
            args.output.write_text(json.dumps(report, indent=2) + "\n")

    try:
        for label, name, old, new, required in MUTANTS:
            path = ROOT / name
            source = originals[name].decode()
            assert source.count(old) == 1, "nonunique or missing anchor: " + label
            try:
                path.write_text(source.replace(old, new, 1))
                subprocess.run([args.lua, "-e", "assert(loadfile(" + json.dumps(name) + "))"],
                               cwd=ROOT, capture_output=True, text=True, check=True, timeout=20)
                result, summary, failures = run(args.lua)
                target = next((s for s in result.stdout.splitlines()
                               if s.startswith("FAIL " + required + ": ")), None)
                assert result.returncode != 0 and failures > 0 and target, "mutant survived its target: " + label
                assert ": expected " in target, "not an assertion failure: " + target
                report["mutants"].append({"mutant": label, "killing_test": required,
                                          "failure": target, "result": summary})
                save()
                print(label + " -> " + required, flush=True)
            finally:
                path.write_bytes(originals[name])
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
