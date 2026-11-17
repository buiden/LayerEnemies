"""E1 rule mutants: independent local copies, Lua 5.1 syntax then assertion kill.
No donor execution; no syntax error, timeout or runner exception counts as killed.
"""
from pathlib import Path
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
LUA = os.environ.get('LAYERENEMIES_LUA', '/opt/data/tools/lua/lua-5.1.5/src/lua')
MUTANTS = []

def add(rule, old, new, selector, file='WarBoard.lua', suite='WarBoard: '):
    MUTANTS.append((rule, file, old, new, suite + selector))

add('H answered; no A loop', 'if cmd=="H" then send(st,id,"A",ctx) end\n        return true', 'send(st,id,"A",ctx)\n        return true', 'compatible H')
add('protocol exactly five', 'proto~="5"', 'false', 'wrong ruleset')
add('wrong ruleset removes peer', 'st.peers[id]=nil\n            if cmd=="H"', 'do end\n            if cmd=="H"', 'wrong ruleset')
add('unknown ruleset silent', 'if not now or not wall or not rs or', 'rs=rs or "pvp"\n        if not now or not wall or not rs or', 'wrong ruleset', 'Adapters.lua')
add('own identity never donor', '"|LayerEnemies/"..ctx.version', '"|WarBoard/1.6.3"', 'compatible H')
add('twenty selected accounts', 'if selected>20 then', 'if selected>21 then', 'discovery selects')
add('sixty second scan', 'recent(st.scan,ctx.now,60)', 'recent(st.scan,ctx.now,59)', 'discovery selects')
add('six hundred second H dispatch', 'recent(r.at,now,600)', 'recent(r.at,now,1)', 'H delayed dispatch')
add('six hundred second H admission', 'recent(r.at,ctx.now,600)', 'recent(r.at,ctx.now,599)', 'H admission')
add('six answers admitted per minute', '#st.answers>=6', '#st.answers>=7', 'A six per rolling')
add('six answers actually attempted per minute', '#st.answerSent>=6', '#st.answerSent>=7', 'A dispatch cap')
add('ten shared WarBoard sends per minute', 'warboard=10', 'warboard=11', 'discovery selects', 'BNet.lua')
add('thirty shared network sends per minute', '#times<30', '#times<31', 'A dispatch cap', 'BNet.lua')
add('final source predicate honored', 'if valid~=true then refuse(q.net); complete(q,false); break end', 'do end', 'live account identity', 'BNet.lua')
add('share off silence', 'not N.Main.sharing()', 'false', 'share stops', 'BNet.lua')
add('public off silence', 'not authorized or not N.Main.sharing() or N.Net.consent()~="public" or not safe() then return false end\n    local ok,why=N.Net.allowed(net,"public")', 'not authorized or not N.Main.sharing() or not safe() then return false end\n    local ok,why=N.Net.allowed(net,"guild")', 'public stops', 'BNet.lua')
add('stand down own sends', 'standDown="WarBoard"', 'standDown="Uninstalled"', 'stand down')
add('handshake grammar cannot masquerade as FBAK', 'local text="WBF1|"..cmd', 'local text="WBF1|FBAK"..cmd', 'compatible H')
add('no forwarding', 'if st.seen[encoded] then return duplicate() end', 'BN.send("warboard",71,"WarBoard","WBF1|D|"..encoded,"own")\n    if st.seen[encoded] then return duplicate() end', 'no unsolicited application response')
add('no alternative send route', 'local queued=BN.send("warboard",id,"WarBoard",text,prio,function(now)', 'N.Wire.send("WarBoard",text,"GUILD")\n    local queued=BN.send("warboard",id,"WarBoard",text,prio,function(now)', 'compatible H')
add('confirmed peer required', 'if not peer or peer.rs~=ctx.rs', 'peer=peer or {rs=ctx.rs,key=who.key,faction=who.faction,at=ctx.now}\n    if not peer or peer.rs~=ctx.rs', 'unconfirmed wrong')
add('peer lifetime bounded', 'ctx.now-peer.at>=1200', 'ctx.now-peer.at>1200', 'unconfirmed wrong')
add('identity rechecked', 'peer.key~=who.key', 'false', 'unconfirmed wrong')
add('carrier faction matches envelope', '(bnetFaction and fac~=bnetFaction)', 'false', 'invalid SHRD faction')
add('four thousand byte frame', '#text>4000', '#text>4001', 'frame four thousand')
add('sixty four fragments', 'integer(n,2,64)', 'integer(n,2,65)', 'fragment limits')
add('sixteen assemblies', 'S.count(st.parts)>=16', 'S.count(st.parts)>=17', 'fragment limits')
add('ninety second assembly expiry', 'now-r.at>=90', 'now-r.at>90', 'fragment limits')
add('assembly sender isolation', 'local key=id..":"..token', 'local key=token', 'confirmed fragment sender isolation')
add('assembly count mismatch', 'if r and r.n~=n then', 'if false then', 'fragment conflict')
add('hundred twenty inbound frames', '#r.times>=120', '#r.times>=121', 'inbound rolling')
add('two hundred sender buckets', 'slots(st.rates,ctx.now,60)>=200', 'slots(st.rates,ctx.now,60)>=201', 'inbound rolling')
add('two hundred peers', 'slots(st.peers,ctx.now,1200)>=200', 'slots(st.peers,ctx.now,1200)>=201', 'inbound rolling')
add('dedupe retains receipt time', 'if st.seen[encoded] then return duplicate() end', 'if false then return false end', 'dedupe FBLP')
add('five hundred twelve dedupe entries', '#st.seenOrder>=512', '#st.seenOrder>=513', 'dedupe ring')
add('one MiB encoded memory', 'st.seenBytes+#encoded>1048576', 'st.seenBytes+#encoded>2097152', 'dedupe byte bound')
add('version upper bound', 'e.v>5', 'e.v>6', 'invalid SHRD v ')
add('payload ruleset match', 'e.rs~=ctx.rs', 'false', 'invalid SHRD rs')
add('no whisper route', 'dist~="CHANNEL") then', 'dist~="CHANNEL" and dist~="WHISPER") then', 'addon routes')
add('honest relayed kind', 'if kind~="cached" and (bridge or not own) then', 'if false then', 'addon routes')
add('tracked admission', 'if not F.tracked(M.find,name) and #(watchers or {})==0 then', 'if false then', 'untracked FBLP', 'Sources.lua')
add('source silence on later poll', 'if row.evidenceKind then return false end', 'if false then return false end', 'silent claim poll', 'Find.lua')
add('SHRD millisecond timestamp', 'math.floor(seq/1000)', 'seq', 'SHRD own zone')
add('SHRD stale sequence', 'math.abs(ctx.wall-math.floor(seq/1000))>120', 'false', 'invalid SHRD sentAt')
add('SHRD sequence ordering', 'if old and seq<=old.seq then', 'if false then', 'SHRD ordering')
add('SHRD sequence independent of carrier spelling', 'N.Invite.key(first.." "..last); local old=st.shards[key]', 'N.Invite.key(ev.name); local old=st.shards[key]', 'SHRD clear and sequence')
add('SHRD clear uses admitted spelling', 'if old then ev.name=old.name end', 'do end', 'SHRD clear and sequence')
add('only enemy faction admitted', 'or fac==ctx.faction then', 'then', 'same faction addon')
add('SHRD expires after one eighty', 'ev.expiresAt=ctx.now+180', 'ev.expiresAt=ctx.now+181', 'SHRD own zone')
add('clear respects source', 'e.source==source and e.evidenceTag==tag', 'e.evidenceTag==tag', 'source clear', 'Known.lua')
add('clear respects type', 'e.source==source and e.evidenceTag==tag', 'e.source==source', 'source clear', 'Known.lua')
add('position age bound', 'stamp(d.sentAt,ctx,121)', 'stamp(d.sentAt,ctx,122)', 'safe fields')
add('position future bound', 'v>ctx.wall+120', 'v>ctx.wall+121', 'safe fields')
add('coordinate provenance', 'ev.pos="enemy"', 'ev.pos="observer"', 'relayed FBLP')
add('coordinate axis order', 'vector(worldY,worldX)', 'vector(worldX,worldY)', 'FBLP world', 'Adapters.lua')
add('child map conversion', 'if zone~=map then', 'if false then', 'client child-map', 'Adapters.lua')

add('FREC structural option fields', 'if not optionalString(d[key],limit) then', 'if false then', 'FREC optional')
add('cached batch remains cached', 'cached and "cached" or kind', 'kind', 'FREC names')
add('rollback refusal', 'if st.high and ctx.now<st.high then', 'if false then', 'rollback refusal')
add('secret value boundary', 'local ok, hidden = pcall(issecretvalue, v)', 'local ok, hidden = true, false', 'safe fields', 'Safe.lua')


# Review rulings: each independent guard gets an assertion-killed mutant.
def review(rule, old, new, selector, file='WarBoard.lua'):
    add(rule, old, new, selector, file, suite='WarBoard review: ')

for typ, cap in [('SHRD', 2048), ('FBLP', 40960), ('FREC', 73728), ('FBLC', 2048), ('FCBD', 98304)]:
    review(typ + ' per-type inflate ceiling', f'{typ}={cap}', f'{typ}={cap // 2 if typ == "FCBD" else cap * 2}',
           'largest normal location' if typ == 'FCBD' else typ + ' inflate ceiling')
review('unknown type bounded before classification', 'math.min(98304,allowance or 98304)',
       'math.min(262144,allowance or 262144)', 'SHRD inflate ceiling')
review('streaming type limit lowers actual inflation', 'maxOut=math.min(maxOut,limit)',
       'maxOut=maxOut', 'SHRD inflate ceiling', 'Codec.lua')
review('sixteen expensive decode attempts per sender', 'rate.attempts>=16', 'rate.attempts>=17', 'decode attempt cap')
review('rolling ten-second decode window', 'now-r.times[i].at>=10', 'now-r.times[i].at>=9', 'decode attempt cap')
review('sender inflated-byte allowance reaches inflater',
       'local allowance=math.min(131072-rate.bytes,acct and (131072-acct.bytes) or 131072)',
       'local allowance=98304', 'decode bytes budget')
review('one decode owner across BN and addon paths', 'decodeRate(st.decodeRates,N.Invite.key(carrier),ctx.now)',
       'decodeRate(st.decodeRates,(account and "bn:"..account or N.Invite.key(carrier)),ctx.now)', 'decode attempt cap')
review('account decode bucket survives character change', 'account and decodeRate(st.decodeAccounts,account,ctx.now)',
       'account and decodeRate(st.decodeAccounts,carrier,ctx.now)', 'BN decode quota')
review('failed payload hash avoids repeated inflation', 'if st.frames[hash] then return duplicate() end',
       'if false then return duplicate() end', 'reviewer 130 BN bombs')
review('decoded non-tracking refusals are hashed, not only failures', 'rememberFrame(st,hash,ctx.now)',
       'if not e then rememberFrame(st,hash,ctx.now) end', 'every decoded frame')
review('sixty-second frame memory', 'now-st.frames[key].at<60', 'now-st.frames[key].at<59', 'failed hashes last')
review('duplicates do not refresh hash lifetime', 'if st.frames[hash] then return duplicate() end',
       'if st.frames[hash] then st.frames[hash].at=ctx.now; return duplicate() end', 'failed hashes last')
review('five hundred twelve frame hashes', '#st.frameOrder>=512', '#st.frameOrder>=513', 'failed hash cap')
review('two hundred decode sender buckets', 'slots(rates,now,10)>=200', 'slots(rates,now,10)>=201',
       'decode sender bucket cap')
review('refused decode counted',
       'or (e.scope~=nil and e.scope~="FACTION") or not S.tab(e.d) then return decodedRefuse() end',
       'or (e.scope~=nil and e.scope~="FACTION") or not S.tab(e.d) then remember(); return false end', 'reviewer 130 BN bombs')
review('dedupe hits counted', 'Src.count("warboard","deduped")', 'do end', 'accepted payload duplicates')
review('two unfinished BN assemblies per account', 'if owned>=2 then return nil end',
       'if owned>=16 then return nil end', 'one account holding unfinished')
review('two unfinished addon assemblies per sender', 'if owned>=2 then return nil end',
       'if owned>=16 then return nil end', 'addon assembly quota', 'Codec.lua')
review('addon assembly owner independent of route key', 'Cd.aceCommJoin(st.comm,key,text,N.Invite.key(sender))',
       'Cd.aceCommJoin(st.comm,key,text,key)', 'addon assembly quota')
review('relayed position wording is not own position',
       '(ev.kind=="self" and "own position; " or "reported position; ")',
       '"own position; "', 'FBLP wording BN third')
review('matching addon subject is not authenticated BN self',
       'if e.t=="FBLP" and not bnetFaction then bridge=true end', 'do end', 'FBLP wording GUILD')
review('README discloses new-peer publication',
       'When LayerEnemies completes the handshake, a real WarBoard client treats it as a new peer and shares its profile, kill streak and board snapshot with its Battle.net contacts, as it does for any WarBoard user.',
       '', 'README explains', '../README.md')


# Round-2 rulings: isolate aggregate work, reserve, cheap path and tracking policy.
def round2(rule, old, new, selector, file='WarBoard.lua'):
    add(rule, old, new, selector, file, suite='WarBoard R2: ')

round2('overall unauthenticated decode ceiling', 'byteRoom(st.decodeTotal,ctx.now,196608)',
       'byteRoom(st.decodeTotal,ctx.now,393216)', 'overall ceiling')
round2('aggregate bytes charged across senders and routes', 'spendBytes(st.decodeTotal,ctx.now,cost)',
       'do end', 'all addon routes')
round2('channel cannot spend the guild reserve', 'byteRoom(st.decodeChannel,ctx.now,131072)',
       'byteRoom(st.decodeChannel,ctx.now,196608)', 'channel flood')
round2('channel byte charges retained', 'spendBytes(st.decodeChannel,ctx.now,cost)',
       'do end', 'channel flood')
round2('aggregate budget uses a rolling ten-second window', 'if now-entry.at<10 then break end',
       'if now-entry.at<9 then break end', 'overall window')
round2('confirmed BN has separate aggregate room',
       'if not account then\n        allowance=math.min(allowance,byteRoom',
       'if true then\n        allowance=math.min(allowance,byteRoom', 'all addon routes')
round2('channel strangers cannot fill sender slots', 'or (channel and channelSlots(st.rates)>=100)',
       'or false', 'channel sender slots')
round2('small honest bursts not clipped at sixteen frames', 'if allowance<=0 then return refuse() end',
       'if allowance<=0 or #rate.times>=16 then return refuse() end', 'cheap honest burst')
round2('cheap frames do not consume expensive attempts', 'charge.expensive=cost>2048',
       'charge.expensive=true', 'cheap reports leave')
round2('cheap probe remains available after expensive attempts', 'then allowance=math.min(allowance,2048) end',
       'then return refuse() end', 'expensive attempts stay')
round2('untracked refusals are not remembered', 'if not untracked then remember() end',
       'remember()', 'untracked ')
round2('mutant runner does not require owner scratch path', 'def main():\n    scratch = Path(tempfile.gettempdir())',
       "def main():\n    scratch = Path(os.environ.get('TMPDIR', '/opt/data/cache/scratch'))\n    assert str(scratch).startswith('/opt/data/cache/scratch')",
       'portable mutant runner', '../test/warboard_mutants.py')

round2('identical mutant evidence is not rewritten',
       'if not report.exists() or report.read_bytes() != content:\n        report.write_bytes(content)',
       'if True:\n        report.write_bytes(content)', 'portable mutant runner', '../test/warboard_mutants.py')
round2('random traceback paths and addresses normalized',
       "def diagnostic(line):\n    line = re.sub(r'(?:table|function): 0x[0-9a-fA-F]+', '<object>', line)",
       'def diagnostic(line):\n    return line', 'portable mutant runner', '../test/warboard_mutants.py')


def diagnostic(line):
    line = re.sub(r'(?:table|function): 0x[0-9a-fA-F]+', '<object>', line)
    return re.sub(r'File "[^"\n]*/((?:test|LayerEnemies)/[^"\n]+)"', r'File "<checkout>/\1"', line)


def main():
    scratch = Path(tempfile.gettempdir())
    results = []
    with tempfile.TemporaryDirectory(prefix='le-warboard-mutants-', dir=scratch) as tmp:
        root = Path(tmp)
        for folder in ('LayerEnemies', 'test'):
            shutil.copytree(ROOT / folder, root / folder)
        shutil.copyfile(ROOT / 'README.md', root / 'README.md')
        for rule, file, old, new, selector in MUTANTS:
            path = root / 'LayerEnemies' / file
            original = path.read_text()
            assert original.count(old) == 1, (rule, 'mutation must match exactly once')
            path.write_text(original.replace(old, new))
            try:
                if path.suffix == '.lua':
                    subprocess.run([str(Path(LUA).with_name('luac')), '-p', str(path)], check=True, capture_output=True)
                elif path.suffix == '.py':
                    subprocess.run([sys.executable, '-m', 'py_compile', str(path)], check=True, capture_output=True)
                run = subprocess.run([LUA, 'test/harness.lua', '--only', selector], cwd=root,
                                     capture_output=True, text=True, errors='replace', timeout=90)
                failures = [diagnostic(s) for s in run.stdout.splitlines() if s.startswith('FAIL ')]
                killed = run.returncode != 0 and 'RESULT:' in run.stdout and any('expected ' in s for s in failures)
                results.append({'rule': rule, 'file': file, 'selector': selector, 'killed': killed, 'failures': failures})
                print(('KILLED ' if killed else 'SURVIVED ') + rule, flush=True)
            finally:
                path.write_text(original)
    report = ROOT / 'notes/warboard-mutants.json'
    content = (json.dumps(results, indent=2) + '\n').encode()
    if not report.exists() or report.read_bytes() != content:
        report.write_bytes(content)
    total = sum(r['killed'] for r in results)
    print(f'RESULT: {total}/{len(results)} WarBoard mutants killed')
    raise SystemExit(total != len(results))


if __name__ == '__main__':
    main()
