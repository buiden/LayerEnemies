"""E2 portable behavioral mutants; syntax/timeouts are not assertion kills.
Run from any working directory with LAYERENEMIES_LUA and TMPDIR overrides.
JSON contains deterministic assertion lines only, never paths/timings/addresses.
"""
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
if LUA:
    LUA = str(Path(shutil.which(LUA) or LUA).resolve())
MUTANTS = []

def add(rule, old, new, selector, file='LayerEnemies/WarBoardTrack.lua'):
    MUTANTS.append((rule, [(file, old, new)], 'WarBoard track: ' + selector))

def combined(rule, changes, selector):
    MUTANTS.append((rule, changes, 'WarBoard track: ' + selector))

add('exact request type', 't=kind,v=5', 't="FBUN",v=5', 'exact FBAK')
add('own addon identity', 'av="LayerEnemies/"..ctx.version', 'av="WarBoard/1.6.3"', 'exact FBAK')
add('own hunter GUID', 'hunterGuid=me.guid', 'hunterGuid=r.guid', 'exact FBAK')
add('faction equals hunter faction', 'faction=ctx.faction,sentAt=sentAt', 'faction=r.faction,sentAt=sentAt', 'exact FBAK')
add('FBUN omits targetName', 'if kind=="FBAK" then d.targetName=r.name end', 'd.targetName=r.name', 'exact FBAK')
add('GetServerTime not local wall clock', 'S.call(_G.GetServerTime)', 'A.wall()', 'server time integer', 'LayerEnemies/Adapters.lua')
add('integer server time', 'at%1==0', 'true', 'server time integer', 'LayerEnemies/Adapters.lua')
add('live clock rechecked at dispatch', 'local fresh=frame(kind,r,self,live)', 'local fresh=text', 'server clock unreadable')
add('only own Find not Watch-only', 'ipairs(N.Main.find.entries)', 'ipairs(N.Find.new({"Enemy Player"}).entries)', 'only own Find')
add('client GUID required', 'r.guid=S.str(v(game.playerGuid),80)', 'r.guid="Player-123-FFFFFFFF"', 'GUID only from live', 'LayerEnemies/Adapters.lua')
add('no GUID adopted from inbound frame', 'local r=records[ev.guid]', 'local r=records[ev.guid]; for _,v in pairs(records) do v.guid=ev.guid end', 'same GUID debt')
add('confirmed A required', 'not peer.confirmed or', 'false or', 'confirmation rules')
add('H does not resurrect expired confirmation', 'ctx.now-old.at<1200', 'true', 'H cannot revive', 'LayerEnemies/WarBoard.lua')
add('peer expiry boundary', 'ctx.now-peer.at>=1200', 'ctx.now-peer.at>1200', 'confirmation rules')
add('peer ruleset match', 'peer.rs~=ctx.rs', 'false', 'confirmation rules')
add('ambiguous account is not a target', 'if count==1 then', 'if count>=1 then', 'confirmation rules')
combined('twenty active targets', [
    ('LayerEnemies/WarBoardTrack.lua','if i>20 then break end','if i>21 then break end'),
    ('LayerEnemies/WarBoardTrack.lua','T.size()<20','T.size()<21')], 'twenty active')
combined('current account GUID at dispatch', [
    ('LayerEnemies/WarBoardTrack.lua','if not who or who.guid~=r.guid then','if not who then'),
    ('LayerEnemies/WarBoardTrack.lua','picks(st,live)[r.guid]','picks(st,live)[who.guid]')], 'dispatch rechecks')
add('current hunter GUID at dispatch', 'self.guid~=me.guid', 'false', 'dispatch rechecks')
add('first attempt gap six seconds', 'not r.last or now-r.last>=6', 'not r.last or now-r.last>=5', 'six forty-five')
combined('three first asks then cleanup', [
    ('LayerEnemies/WarBoardTrack.lua','(r.asks or 0)<3','(r.asks or 0)<4'),
    ('LayerEnemies/WarBoardTrack.lua','(r.asks or 0)>=3','(r.asks or 0)>=4')], 'first asks three')
add('first ask timeout always withdraws', 'elseif not r.location and (r.asks or 0)>=3 and ctx.now-r.last>=6 then retire(r,ctx.now) end', 'end', 'first asks three')
add('six admission budget', 'not room(admitted,ctx.now)', 'false', 'six FBAK')
add('six actual budget after delayed cohort', 'not room(attempted,now)', 'false', 'all actual request')
add('fresh positions not renewed', 'now-r.location>=45', 'now-r.location>=44', 'six forty-five')
add('renewal spacing forty five', 'now-r.last>=45', 'now-r.last>=44', 'renewal exact')
add('newest position only', '(not r.location or ev.at>r.location)', 'true', 'newest position')
add('renewal older than 300 withdraws', 'ctx.now-r.location>300', 'false', 'past 300')
add('300 second restart pause', 'ctx.now-w.at>=300', 'ctx.now-w.at>=200', 'first asks three')
add('new handshake permits stale restart', '(w.renewal and who.handshake>(w.handshake or ctx.now))', 'false', 'past 300')
combined('three FBUN attempts maximum', [
    ('LayerEnemies/WarBoardTrack.lua','elseif (r.tries or 0)>=3','elseif (r.tries or 0)>=4'),
    ('LayerEnemies/WarBoardTrack.lua','elseif not r.closing or (r.tries or 0)>=3','elseif not r.closing or (r.tries or 0)>=4')], 'FBUN refused')
add('FBUN retry admission sixty seconds', 'ctx.now-r.unlast<60', 'ctx.now-r.unlast<59', 'six forty-five')
add('debt before client call', 'r.sent=true; remember(r.guid)', 'r.sent=true', 'active request and')
add('accepted FBUN only settles', 'if kind=="FBUN" and ok then', 'if kind=="FBUN" then', 'accepted FBUN')
add('owed list retained at logout', 'T.closed=true', 'T.closed=true; for i=#owed,1,-1 do owed[i]=nil end', 'logout in combat')
add('saved GUID sanitation', 'local g=guid(raw[k])', 'local g=raw[k]', 'only new saved')
add('saved forty cap oldest out', 'if #owed>40 then', 'if #owed>41 then', 'only new saved')
add('bounded session debt records', 'records[old]=nil --', 'do end --', 'restored forty')
add('load resumes owed cleanup', 'records[g]={guid=g,closing=true,sent=true,tries=0}', 'records[g]=nil', 'crash login')
add('load retains owed GUID list', 'N.WarBoardTrack.load(saved.warboardOwed)', 'N.WarBoardTrack.load(nil)', 'crash login', 'LayerEnemies/Main.lua')
add('switch defaults on', 'T.closed=nil; T.on=true', 'T.closed=nil; T.on=false', 'switch defaults')
add('status prints track state', '(N.WarBoardTrack.on and "on" or "off")', '"on"', 'switch defaults', 'LayerEnemies/Main.lua')
add('remove synchronously owes withdrawal', 'if N.WarBoardTrack then N.WarBoardTrack.changed(st) end\nend\nfunction F.hashes', 'do end\nend\nfunction F.hashes', 'remove quick', 'LayerEnemies/Find.lua')
add('clear synchronously owes withdrawal', 'if N.WarBoardTrack then N.WarBoardTrack.changed(st) end\n        return', 'do end\n        return', 'clear quick', 'LayerEnemies/Find.lua')
add('track off synchronously owes withdrawal', 'if not T.on then T.stop() end', 'do end', 'track quick')
add('share off synchronously owes withdrawal', 'N.OwnDeath.cancel(); N.BNet.cancel(); if N.WarBoardTrack then N.WarBoardTrack.stop() end', 'N.OwnDeath.cancel(); N.BNet.cancel()', 'share quick', 'LayerEnemies/Main.lua')
add('Guild only synchronously owes withdrawal', 'N.BNet.cancel(); if N.WarBoardTrack then N.WarBoardTrack.stop() end', 'N.BNet.cancel()', 'guild quick', 'LayerEnemies/Net.lua')
add('source off synchronously owes withdrawal', 'if key=="warboard" and N.WarBoardTrack then N.WarBoardTrack.stop() end', 'do end', 'source quick', 'LayerEnemies/Net.lua')
add('logout owes withdrawal', 'if N.WarBoardTrack then N.WarBoardTrack.stop(true) end', 'do end', 'logout sends', 'LayerEnemies/Main.lua')
for mode in ('share','guild','source'):
    add(mode+' allows only owed FBUN past stop gate', 'if withdrawal(net,id,prefix,text,prio) then return safe() end', 'do end', mode+' sends', 'LayerEnemies/BNet.lua')
add('standdown still allows owed FBUN', 'if withdrawal(net,id,prefix,text,prio) then return safe() end', 'if withdrawal(net,id,prefix,text,prio) then return safe() and N.Net.allowed(net,"public") end', 'standdown sends', 'LayerEnemies/BNet.lua')
add('disabled source still ticks cleanup', 'or (r.name=="warboard" and N.WarBoardTrack and N.WarBoardTrack.hasOwed()) then call', 'then call', 'source sends', 'LayerEnemies/Sources.lua')
add('disabled source can confirm owed account', 'and not cleanup then return false end', 'then return false end', 'crash login', 'LayerEnemies/Sources.lua')
add('combat cleanup queue survives', 'not (q.cleanup and not safe()) and', 'true and', 'combat holds', 'LayerEnemies/BNet.lua')
add('instance cleanup queue survives', 'not (q.cleanup and not safe()) and', 'true and', 'instance holds', 'LayerEnemies/BNet.lua')
add('generic owed is not a bypass', 'if withdrawal(net,id,prefix,text,prio) then return safe() end', 'if prio=="owed" then return safe() end', 'no generic owed', 'LayerEnemies/BNet.lua')
add('owed A precedes FBUN', 'if a.cleanup~=b.cleanup then return not a.cleanup end', 'if a.cleanup~=b.cleanup then return a.cleanup end', 'owed A before', 'LayerEnemies/BNet.lua')
add('tagged cancel preserves other targets', '(not tag or q.tag==tag)', 'true', 'rollback stays', 'LayerEnemies/BNet.lua')
add('client completion settles debt', 'if q.done then S.call(q.done,ok) end', 'do end', 'accepted FBUN', 'LayerEnemies/BNet.lua')
add('Find coordinate provenance unchanged', 'ev.pos="enemy"', 'ev.pos="observer"', 'positions remain', 'LayerEnemies/WarBoard.lua')
add('no new guild forwarding', 'if accepted and N.WarBoardTrack then N.WarBoardTrack.note(ev) end', 'if accepted then N.Wire.send("WarBoard","forwarded","GUILD") end\n    if accepted and N.WarBoardTrack then N.WarBoardTrack.note(ev) end', 'positions remain', 'LayerEnemies/WarBoard.lua')


def main():
    if not LUA:
        raise SystemExit('Set LAYERENEMIES_LUA to a Lua 5.1 interpreter')
    results = []
    # Resolve a relative TMPDIR before moving into an isolated checkout.
    with tempfile.TemporaryDirectory(prefix='le-warboard-track-', dir=Path(tempfile.gettempdir()).resolve()) as tmp:
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
                    assert text.count(old) == 1, (rule, 'anchor must occur once', text.count(old))
                    path.write_text(text.replace(old, new))
                for path in original:
                    if path.suffix == '.lua':
                        subprocess.run([LUA, '-e', 'assert(loadfile(' + json.dumps(str(path)) + '))'], check=True, capture_output=True)
                run = subprocess.run([LUA, 'test/harness.lua', '--only', selector], cwd=root,
                                     capture_output=True, text=True, errors='replace', timeout=90)
                failures = [re.sub(r'(?:table|function): 0x[0-9a-fA-F]+', '<object>', s)
                            for s in run.stdout.splitlines() if s.startswith('FAIL ')]
                killed = run.returncode != 0 and 'RESULT:' in run.stdout and any('expected ' in s or 'forbidden API reached' in s for s in failures)
                results.append(dict(rule=rule, selector=selector, killed=killed, failures=failures))
                print(('KILLED ' if killed else 'SURVIVED ') + rule, flush=True)
            finally:
                for path, content in original.items():
                    path.write_bytes(content)
    report = ROOT / 'notes/warboard-track-mutants.json'
    report.parent.mkdir(parents=True, exist_ok=True)
    content = (json.dumps(results, indent=2) + '\n').encode()
    if not report.exists() or report.read_bytes() != content:
        report.write_bytes(content)
    killed = sum(r['killed'] for r in results)
    print(f'RESULT: {killed}/{len(results)} WarBoard tracking mutants killed')
    print('Report SHA256: ' + hashlib.sha256(content).hexdigest())
    raise SystemExit(killed != len(results))


if __name__ == '__main__':
    main()
