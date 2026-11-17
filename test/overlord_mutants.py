"""Independent local mutants for Overlord's receive-only contract; restores exact bytes."""
from pathlib import Path
import json
import os
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
LUA = Path(os.environ.get("LAYERENEMIES_LUA", "/opt/data/tools/lua/lua-5.1.5/src/lua"))
OV = "LayerEnemies/Overlord.lua"
MAIN = "LayerEnemies/Main.lua"
# Each mutation targets one admission, lifetime, provenance or side-effect rule.
MUTANTS = [
    ("last-sender", "packet path", OV, "if key~=last then", "if false then"),
    ("rampage-normal-height", "32 rampages", "LayerEnemies/UI.lua", 'local function minimumHeight(e)', 'local function minimumHeight(e)\n        if U.tab=="reported" and e.guild then return 184 end'),
    ("foreign-pool", "foreign packet pools", MAIN, 'if p and p.pool~=pool then return refuse() end', '-- mutant: foreign envelope pool accepted'),
    ("unknown-pool", "unknown own pool", MAIN, 'if not pool then return refuse() end', '-- mutant: unknown local pool accepted'),
    ("ruleset-pool", "pool detection", OV, 'pvp and "global" or "pve"', 'pvp and "pve" or "global"'),
    ("GD-payload-pool", "GD foreign payload pool", MAIN, 'if d and p.kind=="GD" and d.pool~=pool then return refuse() end', '-- mutant: foreign GD payload pool accepted'),
    ("assembly-sender", "two parts", OV, 'local key=who..":"..id', 'local key="shared:"..id'),
    ("envelope-id", "packet identity", OV, ' or f[2]~=id', ''),
    ("three-parts", "fragment frame bounds", OV, ' or count>2', ' or count>3'),
    ("own-faction", "GW bounds", MAIN, ' or g.faction==own:sub(1,1)', ''),
    ("untracked-killer", "untracked killers", MAIN, 'if not N.Find.tracked(M.find,d.killer) and #watchers==0 then', 'if false then'),
    ("120-inclusive", "packet age", OV, 'wall-ts<=age', 'wall-ts<age'),
    ("dedupe", "origin id ring", OV, 'if st.seen[key] then return true end', 'if false then return true end'),
    ("guild-direct-EK", "direct route matrix", MAIN, 'elseif kind=="PARTY" or kind=="RAID" then', 'elseif kind=="PARTY" or kind=="RAID" or kind=="GUILD" then'),
    ("fragment-252", "fragment frame bounds", OV, 'if not bytes(text,255)', 'if not bytes(text,256)'),
    ("chunk-230", "fragment frame bounds", OV, '#chunk>230', '#chunk>231'),
    ("id-64", "fragment frame bounds", OV, 'S.str(id,64)', 'S.str(id,65)'),
    ("id-alphabet", "fragment frame bounds", OV, 'id:match("^[%w%-]+$")', 'id:match("^[%w_%-]+$")'),
    ("part-order", "fragment frame bounds", OV, ' or part>count', ''),
    ("packet-3600", "packet identity", OV, 'bytes(wire,3600)', 'bytes(wire,36000)'),
    ("broadcast", "packet identity", OV, ' or f[4]~="*"', ''),
    ("path-four", "packet path", OV, '#path>=4', '#path>=5'),
    ("path-repeat", "packet path", OV, ' or used[key]', ''),
    ("integer-time", "packet age", OV, 'local at=uint(f[3],9007199254740991)', 'local at=tonumber(f[3])'),
    ("clock-skew", "packet age", OV, 'ts-wall<=30', 'ts-wall<=31'),
    ("control-bytes", "packet identity", OV, ' or v:find("%c")', ''),
    ("pending-cap", "33 pending", OV, 'if n>=32 then', 'if n>=33 then'),
    ("assembly-30", "fragment duplicate", OV, 'now-a.at>=30', 'now-a.at>=31'),
    ("duplicate-renews-partial", "fragment duplicate", OV, 'if a.count~=count', 'a.at=now\n    if a.count~=count'),
    ("duplicate-conflict", "fragment duplicate", OV, ' or (a.chunks[part] and a.chunks[part]~=chunk)', ''),
    ("seen-ring", "origin id ring", OV, 'st.cursor%256+1', 'st.cursor%257+1'),
    ("GW-kills", "GW bounds", OV, 'uint(f[4],9999,50)', 'uint(f[4],10000,50)'),
    ("GW-members", "GW bounds", OV, 'uint(f[5],999,5)', 'uint(f[5],1000,5)'),
    ("GW-layer", "GW bounds", OV, 'uint(f[7],99999999)', 'uint(f[7],100000000)'),
    ("GW-age", "GW bounds", OV, 'fresh(ts,serverNow,300)', 'fresh(ts,serverNow,301)'),
    ("guild-name-cap", "GW bounds", OV, 'S.str(f[2],24)', 'S.str(f[2],25)'),
    ("zone-ref-cap", "GW bounds", OV, 'S.str(ref,40)', 'S.str(ref,41)'),
    ("guild-TTL", "GW one per guild", OV, 'now-g.at>=300', 'now-g.at>=301'),
    ("guild-cap", "GW one per guild", OV, '#rows>=32', '#rows>=33'),
    ("combat", "combat and instance", MAIN, 'A.inCombat() or A.inInstance()~=false then return refuse()', 'A.inInstance()~=false then return refuse()'),
    ("instance", "combat and instance", MAIN, 'A.inCombat() or A.inInstance()~=false then return refuse()', 'A.inCombat() then return refuse()'),
    ("whisper", "direct route matrix", MAIN, 'if kind~="GUILD" and kind~="PARTY" and kind~="RAID" then return end', 'if kind~="GUILD" and kind~="PARTY" and kind~="RAID" and kind~="WHISPER" then return end'),
    ("outgoing-attempt", "single guild rampage", MAIN, 'stats.taken=stats.taken+1', 'stats.taken=stats.taken+1; N.Wire.send("LEGW1","test","GUILD")'),
    ("claim-Ask", "claim never overwrites", "LayerEnemies/Find.lua", 'and loc.spotter~=nil and not loc.relayed and loc.kind~="claim"', 'and loc.spotter~=nil'),
    ("claim-hour", "EK tracked killer", "LayerEnemies/Known.lua", 'TTL=3600,MAX=300', 'TTL=3601,MAX=300'),
    ("secret-map-name", "map lookup failures", MAIN, 'S.secret(name) or S.secret(kind)', 'false or S.secret(kind)'),
    ("secret-map-object", "secret map objects", MAIN, 'not ok or S.secret(info)', 'not ok'),
    ("secret-map-type", "secret map objects", MAIN, 'S.secret(name) or S.secret(kind) or S.secret(parent)', 'S.secret(name) or S.secret(parent)'),
    ("secret-map-parent", "secret map objects", MAIN, 'or S.secret(parent)', ''),
    ("EK-future", "killer payload exact", MAIN, 'if d.ts-wall>30', 'if d.ts-wall>31'),
    ("EK-age", "killer payload exact", MAIN, 'p.kind=="EK" and wall-d.ts>120', 'p.kind=="EK" and wall-d.ts>121'),
    ("save-received-data", "session counters", MAIN, 'Ov.rampage(M.overlord,g,time,wall)', 'Ov.rampage(M.overlord,g,time,wall); LayerEnemiesDB.overlord=M.overlord'),
]


def run():
    p = subprocess.run([str(LUA), "test/harness.lua", "--overlord-only"], cwd=ROOT, text=True, capture_output=True)
    text = p.stdout + p.stderr
    match = re.search(r"RESULT: (\d+) tests passed, (\d+) failed, (\d+) assertions", text)
    assert match, text
    return p.returncode, text, int(match[2])


def main():
    rc, text, failed = run()
    assert rc == 0 and failed == 0, text
    results = []
    for name, expected, relative, before, after in MUTANTS:
        path = ROOT / relative
        original = path.read_bytes()
        try:
            source = original.decode()
            assert source.count(before) == 1, (name, source.count(before))
            path.write_text(source.replace(before, after))
            subprocess.run([str(LUA.with_name("luac")), "-p", str(path)], check=True)
            rc, text, failed = run()
            catches = [line for line in text.splitlines() if line.startswith("FAIL Overlord:")]
            killed = rc != 0 and failed > 0 and any(line.startswith("FAIL Overlord: " + expected) for line in catches)
            results.append({"mutant": name, "killed": killed, "failed": failed, "caught_by": catches})
            print(f"{name}: {'KILLED' if killed else 'SURVIVED'} ({failed} failures)", flush=True)
        finally:
            path.write_bytes(original)
    rc, text, failed = run()
    assert rc == 0 and failed == 0, text
    result = {"total": len(results), "killed": sum(r["killed"] for r in results), "results": results}
    (ROOT / "notes/overlord-mutants.json").write_text(json.dumps(result, indent=2) + "\n")
    print(next(line for line in text.splitlines() if line.startswith("RESULT:")))
    print(f"MUTANTS: {result['killed']}/{result['total']} killed")
    assert result["killed"] == result["total"], "surviving mutants"


if __name__ == "__main__":
    main()
