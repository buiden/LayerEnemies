"""Retained C1 regressions retargeted to C2 framing; portable scratch-only runner."""
import argparse
from overlord_peer_mutants import run
OV = "LayerEnemies/Overlord.lua"
MAIN = "LayerEnemies/Main.lua"
# Each mutation targets one admission, lifetime, provenance or side-effect rule.
MUTANTS = [
    ("diagnostic-pool-omitted", "net diagnostic shows", MAIN, '.." · pool "..pool', ''),
    ("diagnostic-unknown-misleading", "net diagnostic explains", MAIN, 'or "unknown (receiving nothing)"', 'or "global"'),
    ("last-sender", "packet path", OV, "if key~=last then", "if false then"),
    ("rampage-normal-height", "32 rampages", "LayerEnemies/UI.lua", 'local function minimumHeight(e)', 'local function minimumHeight(e)\n        if U.tab=="reported" and e.guild then return 184 end'),
    ("foreign-pool", "foreign packet pools", MAIN, 'if wire==false then return refuse() end\n        p=Ov.packet(wire,id,canonical,wall,me)\n        if p and p.pool~=pool then return refuse() end', 'if wire==false then return refuse() end\n        p=Ov.packet(wire,id,canonical,wall,me)'),
    ("unknown-pool", "unknown own pool", MAIN, 'local pool=M.overlordPool()\n    if not pool', 'local pool=M.overlordPool() or "global"\n    if not pool'),
    ("ruleset-pool", "pool detection", OV, 'pvp and "global" or "pve"', 'pvp and "pve" or "global"'),
    ("GD-payload-pool", "GD foreign payload pool", MAIN, 'if d and p.kind=="GD" and d.pool~=pool then return refuse() end', '-- mutant: foreign GD payload pool accepted'),
    ("assembly-sender", "two parts", OV, 'local key=who..":"..id', 'local key="shared:"..id'),
    ("envelope-id", "packet identity", OV, ' or f[2]~=id', ''),
    ("twenty-five-parts", "fragment frame bounds", OV, 'uint(part,24,1),uint(count,24,1)', 'uint(part,25,1),uint(count,25,1)'),
    ("own-faction", "GW bounds", MAIN, ' or g.faction==own:sub(1,1)', ''),
    ("untracked-killer", "untracked killers", MAIN, 'if not N.Find.tracked(M.find,d.killer) and #watchers==0 then', 'if false then'),
    ("120-inclusive", "packet age", OV, 'wall-ts<=age', 'wall-ts<age'),
    ("dedupe", "origin id ring", OV, 'if st.seen[key] then return true end', 'if false then return true end'),
    ("guild-direct-EK", "direct route matrix", MAIN, 'elseif kind=="PARTY" or kind=="RAID" then', 'elseif kind=="PARTY" or kind=="RAID" or kind=="GUILD" then'),
    ("fragment-252", "fragment frame bounds", OV, 'if not bytes(text,255,true)', 'if not bytes(text,256,true)'),
    ("chunk-230", "fragment frame bounds", OV, '#chunk>230', '#chunk>231'),
    ("id-64", "fragment frame bounds", OV, 'S.str(id,64)', 'S.str(id,65)'),
    ("id-alphabet", "fragment frame bounds", OV, 'id:match("^[%w%-]+$")', 'id:match("^[%w_%-]+$")'),
    ("part-order", "fragment frame bounds", OV, ' or part>count', ''),
    ("packet-3600", "packet identity", OV, 'bytes(wire,3600,true)', 'bytes(wire,36000,true)'),
    ("target-address", "packet identity", OV, '(f[4]~="*" and (not me', '(false and (not me'),
    ("path-four", "packet path", OV, '#path>=4', '#path>=5'),
    ("path-repeat", "packet path", OV, ' or used[key]', ''),
    ("integer-time", "packet age", OV, 'local at=uint(f[3],9007199254740991)', 'local at=tonumber(f[3])'),
    ("clock-skew", "packet age", OV, 'ts-wall<=30', 'ts-wall<=31'),
    ("control-bytes", "packet identity", OV, 'if f[7]:find("%c") and (f[6]~="GW" or not gwFields(f[7])) then return nil end', ''),
    ("pending-cap", "64 pending", OV, 'n>=64', 'n>=65'),
    ("assembly-30", "fragment duplicate", OV, 'now-a.last>=30', 'now-a.last>=31'),
    ("duplicate-renews-partial", "fragment duplicate", OV, 'if a.count~=count', 'a.last=now\n    if a.count~=count'),
    ("duplicate-conflict", "fragment duplicate", OV, ' or (a.chunks[part] and a.chunks[part]~=chunk)', ''),
    ("seen-ring", "origin id ring", OV, 'st.cursor%2000+1', 'st.cursor%2001+1'),
    ("GW-kills", "GW bounds", OV, 'uint(f[4],9999,50)', 'uint(f[4],10000,50)'),
    ("GW-members", "GW bounds", OV, 'uint(f[5],999,5)', 'uint(f[5],1000,5)'),
    ("GW-layer", "GW bounds", OV, 'uint(f[7],99999999,1)', 'uint(f[7],100000000,1)'),
    ("GW-age", "GW bounds", OV, 'fresh(ts,serverNow,300)', 'fresh(ts,serverNow,301)'),
    ("guild-name-cap", "GW bounds", OV, 'S.str(f[2],24)', 'S.str(f[2],25)'),
    ("zone-ref-cap", "GW bounds", OV, 'S.str(ref,40)', 'S.str(ref,41)'),
    ("guild-TTL", "GW one per guild", OV, 'now-g.at>=300', 'now-g.at>=301'),
    ("guild-cap", "GW one per guild", OV, '#rows>=32', '#rows>=33'),
    ("combat", "combat and instance", MAIN, 'A.inCombat() or A.inInstance()~=false then return refuse()', 'A.inInstance()~=false then return refuse()'),
    ("instance", "combat and instance", MAIN, 'A.inCombat() or A.inInstance()~=false then return refuse()', 'A.inCombat() then return refuse()'),
    ("whisper", "direct route matrix", MAIN, 'and kind~="WHISPER" and kind~="BNET"', 'and kind~="BNET"'),
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


# The original rule/fixture labels above remain searchable. Use the generic
# selector so C2 boundary controls can kill raised-limit mutants as well.
if __name__ == "__main__":
    parser=argparse.ArgumentParser();parser.add_argument('--write',action='store_true')
    current=[(name,path.removeprefix('LayerEnemies/'),before,after,'Overlord')
             for name,expected,path,before,after in MUTANTS]
    raise SystemExit(0 if run(current,'overlord-mutants.json',parser.parse_args().write) else 1)
