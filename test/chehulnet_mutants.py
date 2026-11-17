"""G1 rule mutants, isolated copies only; no donor source is executed."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
LUA = os.environ.get('LAYERENEMIES_LUA', '/opt/data/tools/lua/lua-5.1.5/src/lua')
CORE = 'ChehulNet.lua'
MUTANTS = [
    ('exact protocol', CORE, 'f[1]~="CHN1"', 'false'),
    ('HELLO only', CORE, 'f[2]~="H"', 'false'),
    ('six required fields', CORE, '(#f~=6 and #f~=7)', '(#f~=5 and #f~=6 and #f~=7)'),
    ('no trailing field', CORE, 'if #f>7 then return nil end', 'if #f>7 then f[8]=nil; break end'),
    ('missing legacy layer accepted', CORE, '(#f~=6 and #f~=7)', '#f~=7'),
    ('255 bytes', CORE, '#text>255', '#text>256'),
    ('multipart controls ignored', CORE, 'function Ch.parse(text)', 'function Ch.parse(text)\n    if type(text)=="string" then text=text:gsub("^[\\001-\\009]", "") end'),
    ('no embedded controls', CORE, 'or text:find("%c")', ''),
    ('caps colon does not shift layer', CORE, 'f[7]:match("^(%d+):(%d+)$")', 'f[6]:match("^(%d+):(%d+)$")'),
    ('positive fields', CORE, 'v>=1', 'v>=0'),
    ('upper numeric limits', CORE, 'v<=max', 'v<=max+1'),
    ('whole numeric fields', CORE, 'and v%1==0', ''),
    ('decimal grammar', CORE, 'not text:match("^%d+$")', 'false'),
    ('known class or unknown', CORE, 'class and classes[class] and class or nil,level=decimal', 'class,level=decimal'),
    ('text secret refusal', CORE, 'if S.secret(text) or type(text)', 'if false or type(text)'),
    ('record secret refusal', CORE, 'if S.secret(rec[field]) then', 'if false then'),
    ('guild and group only', CORE, 'dist~="GUILD" and dist~="PARTY" and dist~="RAID"', 'dist~="GUILD" and dist~="PARTY" and dist~="RAID" and dist~="WHISPER"'),
    ('own identity excluded', CORE, 'not name or key==st.self', 'not name'),
    ('own identity required', CORE, 'not wall or not S.tab(rec) or not st.self', 'not wall or not S.tab(rec)'),
    ('realm isolation', CORE, 'local name,key,target=N.Invite.name(sender)', 'local name,key,target=N.Invite.name(sender)\n    if key then key=key:match("^[^-]+") end'),
    ('TTL boundary', CORE, 'wall-r.at>=Ch.TTL', 'wall-r.at>Ch.TTL'),
    ('no immortal records', CORE, 'wall-r.at>=Ch.TTL', 'false'),
    ('rollback expiry', CORE, 'wall<r.at or ', ''),
    ('200 entries', CORE, 'S.count(st.entries)>=Ch.MAX', 'S.count(st.entries)>Ch.MAX'),
    ('oldest out', CORE, 'e.at<st.entries[oldest].at', 'e.at>st.entries[oldest].at'),
    ('same-map comparison', CORE, 'r.map==myMap and r.zone', 'r.zone'),
    ('own UID required', CORE, 'myMap and myZone and', 'myMap and'),
    ('ambiguity withholds relation', CORE, 'if comparable and myMap', 'if true and myMap'),
    ('live-map safety', CORE, 'map==M.store.zone and number(M.store.zoneUID,99999999)', 'number(M.store.zoneUID,99999999)'),
    ('clock required for comparison', CORE, 'local amb=true', 'local amb=false'),
    ('combat gate', CORE, 'not N.Adapters.inCombat() and ', ''),
    ('instance gate', CORE, 'N.Adapters.inInstance()==false', 'true'),
    ('ignore gate', CORE, 'or A.ignored(sender)', ''),
    ('switch', 'Sources.lua', 'Src.has(name) and N.Net.switch(name)', 'Src.has(name)'),
    ('never set our layer', CORE, 'N.Sources.count("chehulnet","accepted")', 'N.Sources.count("chehulnet","accepted"); N.Main.store.bulo=tostring(rec.zone)'),
    ('never set our zoneUID', CORE, 'N.Sources.count("chehulnet","accepted")', 'N.Sources.count("chehulnet","accepted"); N.Main.store.zoneUID=rec.zone'),
    ('no sends even attempted', CORE, 'N.Sources.count("chehulnet","accepted")', 'N.Sources.count("chehulnet","accepted"); N.Wire.send("ChehulNet","CHN1|H","GUILD")'),
    ('no joins even attempted', CORE, 'N.Sources.count("chehulnet","accepted")', 'N.Sources.count("chehulnet","accepted"); JoinChannelByName("ChehulNet")'),
    ('no Find projection', CORE, 'N.Sources.count("chehulnet","accepted")', 'N.Sources.count("chehulnet","accepted"); N.Sources.offer({name=sender,net="chehulnet",kind="self",map=rec.map})'),
    ('no Reported projection', CORE, 'N.Sources.count("chehulnet","accepted")', 'N.Sources.count("chehulnet","accepted"); N.Main.reportedRows=function() return {{name=sender}} end'),
    ('no saved names', CORE, 'N.Sources.count("chehulnet","accepted")', 'N.Sources.count("chehulnet","accepted"); LayerEnemiesDB.chehul=sender'),
    ('other-layer hints only', CORE, 'if ally.rel=="other" then', 'if true then'),
    ('host annotation', CORE, 'row.host and "layer differs, confirmed"', 'false and "layer differs, confirmed"'),
    ('preserve host capabilities', CORE, 'row.chehulText="ChehulNet: "', 'row.layer=tostring(ally.zone); row.chehulText="ChehulNet: "'),
    ('no hint Ask', 'UI.lua', 'if e.chehulHint then askState(r,nil)', 'if e.chehulHint then askState(r,e.name,"Ask for invite")'),
    ('measure annotation before paging', 'UI.lua', 'if e.chehulText and not e.chehulHint then text=text.."\\n"..e.chehulText end', '-- annotation measured too late'),
    ('measure real text height', 'UI.lua', 'U.measure:SetText(text)\n        local layout=', 'U.measure:SetText(e.chehulText and "short" or text)\n        local layout='),
    ('layer command distinct count', CORE, 'S.count(layers).." distinct layers', '#rows.." distinct layers'),
    ('same names only', CORE, 'if row.rel=="same" then', 'if row.rel then'),
]


def main():
    results = []
    with tempfile.TemporaryDirectory(prefix='le-chehulnet-mutants-') as tmp:
        root = Path(tmp)
        for folder in ('LayerEnemies', 'test'):
            shutil.copytree(ROOT / folder, root / folder)
        for name, filename, old, new in MUTANTS:
            path = root / 'LayerEnemies' / filename
            original = path.read_text()
            assert original.count(old) == 1, (name, 'nonunique mutation')
            path.write_text(original.replace(old, new))
            try:
                subprocess.run([str(Path(LUA).with_name('luac')), '-p', str(path)], check=True, capture_output=True)
                run = subprocess.run([LUA, 'test/harness.lua', '--only', 'ChehulNet:'], cwd=root,
                                     capture_output=True, text=True, errors='replace', timeout=90)
                failures = [line for line in run.stdout.splitlines() if line.startswith('FAIL ')]
                killed = run.returncode != 0 and bool(failures) and 'RESULT:' in run.stdout
                results.append({'rule': name, 'killed': killed, 'failures': failures})
                print(('KILLED ' if killed else 'SURVIVED ') + name, flush=True)
            finally:
                path.write_text(original)
    (ROOT / 'notes/chehulnet-mutants.json').write_text(json.dumps(results, indent=2) + '\n')
    killed = sum(r['killed'] for r in results)
    print(f'RESULT: {killed}/{len(results)} ChehulNet mutants killed')
    if killed != len(results):
        raise SystemExit(1)


if __name__ == '__main__':
    main()
