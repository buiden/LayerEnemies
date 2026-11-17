"""E2 rule mutants. Portable scratch/Lua override; stable assertion-only report."""
from pathlib import Path
import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
LUA = os.environ.get('LAYERENEMIES_LUA') or shutil.which('lua5.1') or shutil.which('lua')
MUTANTS = []

def add(rule, old, new, selector, file='LayerEnemies/WarBoardTrack.lua'):
    MUTANTS.append((rule, [(file, old, new)], 'WarBoard track: ' + selector))

add('dispatch rollback is silent', '(high and now<high)', 'false', 'dispatch rollback')
add('exact request kind', 'frame(kind,r,me,ctx)\n    local d=', 'frame(kind,r,me,ctx)\n    kind="FBUN"\n    local d=', 'exact FBAK')
add('own addon identity', 'atom("LayerEnemies/"..ctx.version)', 'atom("WarBoard/1.6.3")', 'exact FBAK')
add('own GUID and faction fields', 'hunterGuid=me.guid,hunterName=me.name', 'hunterGuid=r.guid,hunterName=me.name', 'exact FBAK')
add('only own Find names', 'ipairs(N.Main.find.entries)', 'ipairs(N.Find.new({"Enemy Player"}).entries)', 'only own Find')
add('confirmed A required', 'not peer.confirmed or', 'false or', 'confirmed A only')
add('peer identity binding', 'N.Invite.key(full)~=peer.key', 'false', 'confirmed A only')
add('peer ruleset binding', 'peer.rs~=ctx.rs', 'false', 'confirmed A only')
add('peer confirmation expiry', 'ctx.now-peer.at>=1200', 'ctx.now-peer.at>1200', 'confirmed A only')
add('H cannot refresh expired A', 'ctx.now-old.at<1200', 'true', 'confirmation cannot', 'LayerEnemies/WarBoard.lua')
add('live GUID syntax', 'v:match("^Player%-%d+%-%x+$")', 'true', 'missing secret')
add('ambiguous target refused', 'if count==1 then', 'if count>=1 then', 'missing secret')
add('twenty retained targets', 'T.size()<20', 'T.size()<21', 'cleanup bounded')
add('two requests admitted per minute', 'not room(admitted[kind],ctx.now)', 'false', 'two admitted')
add('two actual requests per minute', 'if not room(attempted[kind],now) then', 'if false then', 'shared delay')
add('per-name admission interval', 'recent(c.queued,ctx.now,45)', 'recent(c.queued,ctx.now,44)', 'queued attempt')
# Both admission and dispatch guards enforce the actual-send interval.
MUTANTS.append(('per-name actual interval', [('LayerEnemies/WarBoardTrack.lua', 'recent(c.sent,ctx.now,45)', 'recent(c.sent,ctx.now,44)'),
                                          ('LayerEnemies/WarBoardTrack.lua', 'recent(c.sent,now,45)', 'recent(c.sent,now,44)')],
                'WarBoard track: per-name forty-five'))
add('fresh positions do not renew', 'now-r.location>=45', 'now-r.location>=44', 'fresh FBLP')
add('over-age positions do not renew', 'now-r.location<=300', 'true', 'fresh FBLP')
add('new targets before renewals', 'return (a.last or -math.huge)<(b.last or -math.huge)', 'return (a.last or -math.huge)>(b.last or -math.huge)', 'two admitted')
add('remove cancels immediately', 'if N.WarBoardTrack then N.WarBoardTrack.changed(st) end\nend\nfunction F.hashes', 'do end\nend\nfunction F.hashes', 'remove cancels', 'LayerEnemies/Find.lua')
add('clear cancels immediately', 'if N.WarBoardTrack then N.WarBoardTrack.changed(st) end\n        return', 'do end\n        return', 'clear cancels', 'LayerEnemies/Find.lua')
add('track off cancels immediately', 'if not T.on then T.stop() end', 'do end', 'track cancels')
add('share off cancels active obligation', 'if not on then N.OwnDeath.cancel(); N.BNet.cancel(); if N.WarBoardTrack then N.WarBoardTrack.stop() end end', 'if not on then N.OwnDeath.cancel(); N.BNet.cancel() end', 'share active quick', 'LayerEnemies/Main.lua')
add('guild only cancels active obligation', 'N.BNet.cancel(); if N.WarBoardTrack then N.WarBoardTrack.stop() end', 'N.BNet.cancel()', 'guild active quick', 'LayerEnemies/Net.lua')
add('source off cancels active obligation', 'if key=="warboard" and N.WarBoardTrack then N.WarBoardTrack.stop() end', 'do end', 'source active quick', 'LayerEnemies/Net.lua')
add('combat event cancels immediately', 'if N.WarBoardTrack then N.WarBoardTrack.stop() end\n        guarded(M.hopAnyStop,"combat started")', 'guarded(M.hopAnyStop,"combat started")', 'combat cancels', 'LayerEnemies/Main.lua')
add('instance event cancels immediately', 'if N.WarBoardTrack and A.inInstance()~=false then N.WarBoardTrack.stop() end', 'do end', 'instance cancels', 'LayerEnemies/Main.lua')
add('logout drops queue', 'if N.WarBoardTrack then N.WarBoardTrack.stop(true) end', 'do end', 'logout cancels', 'LayerEnemies/Main.lua')
add('cancel after attempted request', 'if r.sent then r.closing=true else records[r.key]=nil end', 'records[r.key]=nil', 'remove stops')
add('FBUN omits target name', 'if kind=="FBAK" then d.targetName=r.name end', 'd.targetName=r.name', 'remove stops')
add('two cancels per minute', 'return #list<2', 'return #list<3', 'cleanup bounded')
MUTANTS.append(('queued GUID revalidated', [('LayerEnemies/WarBoardTrack.lua', 'if not who or who.key~=r.key or who.guid~=r.guid then retire(r); return false end', 'if not who or who.key~=r.key then retire(r); return false end'),
                                           ('LayerEnemies/WarBoardTrack.lua', 'picked.guid~=r.guid', 'false')], 'WarBoard track: dispatch rechecks'))
add('queued own GUID revalidated', 'self.guid~=me.guid', 'false', 'dispatch rechecks')
add('default on', 'LayerEnemiesDB.warboardTrack=saved.warboardTrack~=false', 'LayerEnemiesDB.warboardTrack=saved.warboardTrack==true', 'saved boolean', 'LayerEnemies/Main.lua')
add('saved off retained', 'LayerEnemiesDB.warboardTrack=saved.warboardTrack~=false', 'LayerEnemiesDB.warboardTrack=true', 'saved boolean', 'LayerEnemies/Main.lua')
add('status shows switch', '(N.WarBoardTrack.on and "on" or "off")', '"on"', 'saved boolean', 'LayerEnemies/Main.lua')
add('owed A precedes tracking', 'if a.prio~=b.prio then return a.prio=="owed" end', 'if a.prio~=b.prio then return a.prio~="owed" end', 'queue share', 'LayerEnemies/BNet.lua')
add('cancel preserves H and A queue', '(not tag or queue[i].tag==tag)', 'true', 'tagged cancellation', 'LayerEnemies/BNet.lua')
add('client refusals spend caps', 'attempted[kind][#attempted[kind]+1]=now', 'do end', 'shared delay')
add('Find keeps own position provenance', 'ev.pos="enemy"', 'ev.pos="observer"', 'positions use', 'LayerEnemies/WarBoard.lua')


def main():
    if not LUA:
        raise SystemExit('Set LAYERENEMIES_LUA to a Lua 5.1 interpreter')
    results = []
    with tempfile.TemporaryDirectory(prefix='le-warboard-track-') as tmp:
        root = Path(tmp)
        for folder in ('LayerEnemies', 'test'):
            shutil.copytree(ROOT / folder, root / folder)
        shutil.copyfile(ROOT / 'README.md', root / 'README.md')
        for rule, changes, selector in MUTANTS:
            original = {}
            try:
                for file, old, new in changes:
                    path = root / file
                    original.setdefault(path, path.read_bytes())
                    text = path.read_text()
                    assert text.count(old) == 1, (rule, 'anchor must occur once')
                    path.write_text(text.replace(old, new))
                for path in original:
                    if path.suffix == '.lua':
                        subprocess.run([LUA, '-e', 'assert(loadfile(' + json.dumps(str(path)) + '))'], check=True, capture_output=True)
                run = subprocess.run([LUA, 'test/harness.lua', '--only', selector], cwd=root,
                                     capture_output=True, text=True, errors='replace', timeout=90)
                failures = [re.sub(r'(?:table|function): 0x[0-9a-fA-F]+', '<object>', s)
                            for s in run.stdout.splitlines() if s.startswith('FAIL ')]
                killed = run.returncode != 0 and 'RESULT:' in run.stdout and any('expected ' in s for s in failures)
                results.append(dict(rule=rule, selector=selector, killed=killed, failures=failures))
                print(('KILLED ' if killed else 'SURVIVED ') + rule, flush=True)
            finally:
                for path, content in original.items():
                    path.write_bytes(content)
    report = ROOT / 'notes/warboard-track-mutants.json'
    content = (json.dumps(results, indent=2) + '\n').encode()
    if not report.exists() or report.read_bytes() != content:
        report.write_bytes(content)
    killed = sum(r['killed'] for r in results)
    print(f'RESULT: {killed}/{len(results)} WarBoard tracking mutants killed')
    print('Report SHA256: ' + hashlib.sha256(content).hexdigest())
    raise SystemExit(killed != len(results))


if __name__ == '__main__':
    main()
