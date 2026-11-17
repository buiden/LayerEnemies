"""FLH receive-only rule mutants; run in private scratch, never alter the worktree."""
from pathlib import Path
import argparse
import json
import os
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
MUTANTS = [
    ('host-zero-is-host', 'Main.lua', 'if msg.host==1 and msg.map>0', 'if msg.host~=nil and msg.map>0'),
    ('no-length-cap', 'FLH.lua', ' or #text>255', ''),
    ('720-second-flh-hosts', 'Hosts.lua', 'Hs.FLH_KEEP = 180', 'Hs.FLH_KEEP = 720'),
    ('ttl-off-by-one', 'Hosts.lua', 'Hs.FLH_KEEP = 180', 'Hs.FLH_KEEP = 181'),
    ('clock-rollback-retains-cache', 'Hosts.lua', 'wall<e.at or wall-e.at>=Hs.FLH_KEEP', 'wall-e.at>=Hs.FLH_KEEP'),
    ('unbounded-cache', 'Hosts.lua', 'S.count(st.flhHosts)>=Hs.MAX', 'false'),
    ('case-duplicates', 'Hosts.lua', 'st.flhHosts[key]={name=target', 'st.flhHosts[name]={name=target'),
    ('no-withdrawal', 'Hosts.lua', 'if claim==nil then st.flhHosts[key]=nil; return false end', 'if claim==nil then return false end'),
    ('non-numeric-id', 'FLH.lua', 'then value=integer(value)\n        elseif field=="key"', 'then value=integer(value) or (field=="id" and 1)\n        elseif field=="key"'),
    ('unknown-is-presence', 'FLH.lua', 'local layout=layouts[cmd]', 'local layout=layouts[cmd] or layouts.HI'),
    ('pipe-only-split', 'FLH.lua', 'gmatch("([^|:]*)[|:]")', 'gmatch("([^|]*)[|]")'),
    ('drop-empty-fields', 'FLH.lua', 'gmatch("([^|:]*)[|:]")', 'gmatch("([^|:]+)[|:]")'),
    ('zero-fingerprint', 'FLH.lua', 'n and n>0 and s', 'n and n>=0 and s'),
    ('discard-fingerprint-spelling', 'FLH.lua', 'n and n>0 and s', 'n and n>0 and tostring(n)'),
    ('no-secret-check', 'FLH.lua', 'S.secret(text) or type(text)', 'type(text)'),
    ('no-control-check', 'FLH.lua', ' or text:find("%c")', ''),
    ('no-metadata-validation', 'FLH.lua', 'if not fields[i]:match("^[A-Z][A-Z0-9_]*=[^|:]*$") then return nil end', '-- metadata unchecked'),
    ('no-csv-validation', 'FLH.lua', 'if not FL.key(key) then return nil end', 'if false then return nil end'),
    ('no-prefix-registration', 'Main.lua', 'S.call(C_ChatInfo.RegisterAddonMessagePrefix,"FLHNET2") -- receive only', '-- receive registration missing'),
    ('no-prefix-dispatch', 'Main.lua', 'if prefix=="FLHNET2" then return M.flhIn(text,kind,sender) end', '-- dispatch missing'),
    ('channel-presence', 'Main.lua', 'kind~="GUILD" and kind~="PARTY" and kind~="RAID" and kind~="WHISPER"', 'kind~="GUILD" and kind~="PARTY" and kind~="RAID" and kind~="WHISPER" and kind~="CHANNEL"'),
    ('requests-become-hosts', 'Main.lua', '(msg.cmd~="HI" and msg.cmd~="WR" and msg.cmd~="CA")', '(msg.cmd~="HI" and msg.cmd~="WR" and msg.cmd~="CA" and msg.cmd~="WP" and msg.cmd~="CQ")'),
    ('answer-received-lines', 'Main.lua', 'local msg=N.FLH.decode(text)', 'N.Wire.send("FLHNET2","WR|42|1234|0.1.3|100|8|0","WHISPER",sender)\n    local msg=N.FLH.decode(text)'),
    ('own-echo-host', 'Main.lua', 'if not A.ownIdentity() or M.isMe(sender) or A.ignored(sender) then return end', 'if not A.ownIdentity() or A.ignored(sender) then return end'),
    ('ignored-host', 'Main.lua', 'if not A.ownIdentity() or M.isMe(sender) or A.ignored(sender) then return end', 'if not A.ownIdentity() or M.isMe(sender) then return end'),
    ('unreadable-own-identity', 'Main.lua', 'if not A.ownIdentity() or M.isMe(sender)', 'if M.isMe(sender)'),
    ('combat-ingress', 'Main.lua', 'if A.inCombat() or A.inInstance()~=false then return end', 'if A.inInstance()~=false then return end'),
    ('instance-ingress', 'Main.lua', 'if A.inCombat() or A.inInstance()~=false then return end', 'if A.inCombat() then return end'),
    ('guildless-ingress', 'Main.lua', 'if kind=="GUILD" and S.call(IsInGuild)~=true then return end', '-- no guild check'),
    ('missing-host-projection', 'Main.lua', 'flh=not listed and M.heard.flhHosts or nil', 'flh=nil'),
    ('all-zone-hosts', 'Invite.lua', 'and e.map==env.zone and age>=0', 'and age>=0'),
    ('flh-is-server-layer', 'Invite.lua', 'c.flhKey,c.flhAge=e.key,age', 'c.layer=e.key\n                c.flhKey,c.flhAge=e.key,age'),
    ('flh-renews-legacy-age', 'Invite.lua', 'c.flhKey,c.flhAge=e.key,age', 'c.age=age\n                c.flhKey,c.flhAge=e.key,age'),
    ('flh-becomes-layerswap-host', 'Invite.lua', 'c.hosts.FLH=true;', 'c.hosts.LayerSwap=true;'),
    ('flh-promotes-listed-nonhost', 'Invite.lua', 'c.hosts.FLH=true;', 'c.hosts.FLH=true; c.host=true;'),
    ('flh-evicts-known-layer-host', 'Invite.lua', 'if af~=bf then return not af end', '-- mutant: FLH claims may evict layer rows'),
    ('persist-host-names', 'Main.lua', 'N.Hosts.flh(M.heard,sender,claim,wall)', 'N.Hosts.flh(M.heard,sender,claim,wall)\n    LayerEnemiesDB.flh=M.heard.flhHosts'),
    ('no-honest-flh-label', 'Main.lua', 'local claim="FLH key "..key.." (claim, "..ago(c.flhAge).." ago)"', 'local claim="layer "..key'),
    ('clipped-provenance', 'UI.lua', '(friendly and e.flhKey) and 60', '(friendly and e.flhKey) and 24'),
]


def run(root, lua):
    proc = subprocess.run([lua, 'test/harness.lua', '--flh-only'], cwd=root,
                          text=True, capture_output=True, timeout=120)
    output = proc.stdout + proc.stderr
    match = re.search(r'RESULT: (\d+) tests passed, (\d+) failed, (\d+) assertions', output)
    assert match, 'No complete test result:\n' + output
    return {'passed': int(match[1]), 'failed': int(match[2]), 'rc': proc.returncode,
            'caught_by': [line[5:] for line in output.splitlines() if line.startswith('FAIL ')]}, output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lua', default=os.environ.get('LAYERENEMIES_LUA', '/opt/data/tools/lua/lua-5.1.5/src/lua'))
    parser.add_argument('--scratch', default=os.environ.get('TMPDIR', '/opt/data/cache/scratch'))
    args = parser.parse_args()
    evidence = ROOT / 'notes/flh-mutants.json'
    with tempfile.TemporaryDirectory(prefix='le-flh-mutants-', dir=args.scratch) as directory:
        root = Path(directory)
        for part in ('LayerEnemies', 'test'):
            shutil.copytree(ROOT / part, root / part)
        baseline, output = run(root, args.lua)
        assert baseline['rc'] == 0 and baseline['failed'] == 0 and baseline['passed'] > 0, output
        total = baseline['passed']
        results = []
        for name, filename, before, after in MUTANTS:
            path = root / 'LayerEnemies' / filename
            original = path.read_bytes()
            text = original.decode()
            assert text.count(before) == 1, (name, 'unique mutation site required', text.count(before))
            try:
                path.write_text(text.replace(before, after))
                result, output = run(root, args.lua)
                assert result['passed'] + result['failed'] == total, (name, 'test inventory changed')
                result['mutant'] = name
                result['killed'] = result['rc'] != 0 and result['failed'] > 0
                results.append(result)
                print(f"{name}: {'KILLED' if result['killed'] else 'SURVIVED'} ({result['failed']} failed)")
            finally:
                path.write_bytes(original)
        final, output = run(root, args.lua)
        assert final['rc'] == 0 and final['failed'] == 0 and final['passed'] == total, output
    evidence.parent.mkdir(exist_ok=True)
    evidence.write_text(json.dumps({'baseline': baseline, 'mutants': results, 'final': final}, indent=2) + '\n')
    print(next(line for line in output.splitlines() if line.startswith('RESULT:')))
    print(f"Mutants: {sum(r['killed'] for r in results)}/{len(MUTANTS)} killed")
    assert len(results) == len(MUTANTS) and all(r['killed'] for r in results), 'Surviving mutant'


if __name__ == '__main__':
    main()
