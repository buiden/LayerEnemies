"""D1-only behavioral mutants, isolated under scratch; no donor or other mutant execution."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
LUA = os.environ.get('LAYERENEMIES_LUA', '/opt/data/tools/lua/lua-5.1.5/src/lua')
MUTANTS = [
    ('encoded-byte ceiling', 'Wanted.lua', '#bytes>30272', '#bytes>65536'),
    ('inflate ceiling', 'Wanted.lua', 'Cd.inflate(raw,65536)', 'Cd.inflate(raw,262144)'),
    ('WNTD twelve parts', 'Wanted.lua', 'bnet and 8 or 12', 'bnet and 8 or 13'),
    ('WNTDP eight parts', 'Wanted.lua', 'bnet and 8 or 12', 'bnet and 9 or 12'),
    ('WNTD part size', 'Wanted.lua', 'bnet and 3784 or 240', 'bnet and 3784 or 241'),
    ('WNTDP part size', 'Wanted.lua', 'bnet and 3784 or 240', 'bnet and 3785 or 240'),
    ('per-sender assemblies across routes', 'Wanted.lua', 'text,false,now,"addon:"..key)', 'text,false,now)'),
    ('four addon assemblies per sender', 'Wanted.lua', 'bnet and 2 or 4', 'bnet and 2 or 5'),
    ('two BNet assemblies per sender', 'Wanted.lua', 'bnet and 2 or 4', 'bnet and 3 or 4'),
    ('sixteen global assemblies', 'Wanted.lua', 'total>=16', 'total>=17'),
    ('thirty second assembly lifetime', 'Wanted.lua', 'now-v.at>=30', 'now-v.at>30'),
    ('assembly rollback', 'Wanted.lua', 'if st.time and now<st.time then', 'if false then'),
    ('fragment tag conflict', 'Wanted.lua', 'r.tag~=tag or r.total~=n', 'r.total~=n'),
    ('fragment total conflict', 'Wanted.lua', 'r.tag~=tag or r.total~=n', 'r.tag~=tag'),
    ('fragment duplicate conflict', 'Wanted.lua', '(r.parts[p] and r.parts[p]~=b)', 'false'),
    ('audited release version', 'Wanted.lua', 'not plain(t) or not version(t.v)', 'not plain(t)'),
    ('E/S not whisper', 'Wanted.lua', 'if dist=="WHISPER" and (tag=="E" or tag=="S") then', 'if false then'),
    ('sighting batch ceiling', 'Wanted.lua', 'array(t.s,15)', 'array(t.s,16)'),
    ('R record batch ceiling', 'Wanted.lua', 'tag=="R" and 10 or 8', 'tag=="R" and 11 or 8'),
    ('F record batch ceiling', 'Wanted.lua', 'tag=="R" and 10 or 8', 'tag=="R" and 10 or 9'),
    ('known local faction veto', 'Wanted.lua', 'r and r.faction=="same" and S.num(r.at)', 'false and S.num(r.at)'),
    ('known retained faction veto', 'Wanted.lua', 'e and e.guid==g and e.faction==faction', 'false'),
    ('record participant faction', 'Wanted.lua', 'or f==faction or (g and sameFaction(g,now,faction))', 'or (g and sameFaction(g,now,faction))'),
    ('record hash', 'Wanted.lua', 'if string.format("%08x",b*65536+a)~=r.hash then', 'if false then'),
    ('record identity', 'Wanted.lua', 'or r.id~=r.origin..":"..string.format("%d",r.seq)', ''),
    ('live sequence minimum', 'Wanted.lua', 'integer(r.seq,1000001,2147483647)', 'integer(r.seq,1,2147483647)'),
    ('sequence maximum', 'Wanted.lua', 'integer(r.seq,1000001,2147483647)', 'integer(r.seq,1000001,2147483648)'),
    ('flat-data field count', 'Wanted.lua', '#keys>64', '#keys>65'),
    ('flat-data string ceiling', 'Wanted.lua', 'S.str(v,512)', 'S.str(v,513)'),
    ('record numeric type', 'Wanted.lua', 'if numeric[k] and not S.num(v) then', 'if false then'),
    ('record age', 'Wanted.lua', 'wall-t>=N.Known.TTL', 'wall-t>N.Known.TTL'),
    ('record future clock', 'Wanted.lua', 'or t>wall or wall-t', 'or wall-t'),
    ('bounty seenAt not posting time', 'Wanted.lua', 'at=age(d.seenAt,wall,now)', 'at=age(r.t,wall,now)'),
    ('claim killT not posting time', 'Wanted.lua', 'at=age(d.killT,wall,now)', 'at=age(r.t,wall,now)'),
    ('guild R origin must be sender', 'Wanted.lua', 'if tag=="R" and dist~="WHISPER" and origin~=key then', 'if false then'),
    ('F always relayed', 'Wanted.lua', '(tag=="F" or origin~=key)', '(origin~=key)'),
    ('relayed R honest provenance', 'Wanted.lua', '(tag=="F" or origin~=key)', '(tag=="F")'),
    ('record replay id', 'Wanted.lua', 'local identity="record:"..r.id', 'local identity="record:"..sender..r.id'),
    ('packet replay age', 'Wanted.lua', 'not state.seen[key] and S.count(state.seen)<512', 'S.count(state.seen)<512'),
    ('bounded dedupe ledger', 'Wanted.lua', 'S.count(state.seen)<512', 'S.count(state.seen)<513'),
    ('location field namespaces', 'Wanted.lua', 'if mapKey=="m" then zone=d.z else zone=d.zone end', 'zone=d.z or d.zone'),
    ('observer percentages', 'Wanted.lua', 'x,y=x/100,y/100', 'x,y=x/200,y/200'),
    ('seen near label', 'Sources.lua', 'if x and kind~="self" then', 'if false then'),
    ('tracked names gate', 'Sources.lua', 'if not F.tracked(M.find,name) and #(watchers or {})==0 then', 'if false then'),
    ('silent later alert poll', 'Find.lua', 'if row.evidenceKind then return false end', 'if false then return false end'),
    ('source switch', 'Sources.lua', 'Src.has(name) and N.Net.switch(name)', 'Src.has(name)'),
    ('secret readable scalars', 'Safe.lua', 'local ok, hidden = pcall(issecretvalue, v)', 'local ok, hidden = true, false'),
    ('BNet faction eligibility', 'Wanted.lua', 'or peer.faction==faction or (peer.faction', 'or (peer.faction'),
    ('BNet realm eligibility', 'Wanted.lua', 'or realm(peer.realm)~=realm(N.Main.homeRealm())', ''),
    ('BNet anonymous only', 'Wanted.lua', 'S.str(t.k,1)~="L"', '(S.str(t.k,1)~="L" and S.str(t.k,1)~="N")'),
    ('summary twelve entries', 'Wanted.lua', 'array(t.z,12)', 'array(t.z,13)'),
    ('summary twenty carriers', 'Wanted.lua', 'S.count(state.far)>=20', 'S.count(state.far)>=21'),
    ('summary ten minute expiry', 'Wanted.lua', 'now-r.at>=600', 'now-r.at>600'),
    ('summary count clamp', 'Wanted.lua', 'math.min(200,math.floor(v.n))', 'math.floor(v.n)'),
    ('sixty addon datagrams', 'Wanted.lua', 'budget("addon:"..key,now,60)', 'budget("addon:"..key,now,61)'),
    ('thirty BNet datagrams', 'Wanted.lua', 'budget("bn:"..id,now,30)', 'budget("bn:"..id,now,31)'),
    ('rate identity ceiling', 'Wanted.lua', 'S.count(state.rates)>=128', 'S.count(state.rates)>=129'),
    ('no Wanted roster scan', 'Directory.lua', 'if key~="wanted" then schedule(key, D.FIRST) end', 'schedule(key, D.FIRST)'),
    ('channel free slots', 'Directory.lua', 'slots<=7', 'slots<=8'),
    ('donor stand-down', 'Wanted.lua', 'N.Net.LIST.wanted.standDown="WantedDeadOrDead"', 'N.Net.LIST.wanted.standDown=nil'),
    ('no receive sends', 'Wanted.lua', 'local function addon(prefix,text,dist,sender)\n', 'local function addon(prefix,text,dist,sender)\n    N.BNet.send("wanted",71,"WNTDB","bad","own")\n'),
    ('no saved evidence', 'Wanted.lua', 'if accepted then state.seen[identity]=now+N.Known.TTL end', 'if accepted then state.seen[identity]=now+N.Known.TTL; LayerEnemiesDB.wantedName=sender end'),
]

def main():
    results=[]
    scratch=Path('/opt/data/cache/scratch')
    with tempfile.TemporaryDirectory(prefix='le-wanted-mutants-', dir=scratch) as tmp:
        root=Path(tmp)
        for folder in ('LayerEnemies','test'):
            shutil.copytree(ROOT/folder, root/folder)
        for name, filename, old, new in MUTANTS:
            path=root/'LayerEnemies'/filename
            original=path.read_text()
            assert original.count(old)==1, (name, original.count(old))
            path.write_text(original.replace(old,new))
            try:
                subprocess.run([str(Path(LUA).with_name('luac')),'-p',str(path)], check=True, capture_output=True)
                run=subprocess.run([LUA,'test/harness.lua','--only','Wanted:'],cwd=root,
                                   capture_output=True,text=True,errors='replace',timeout=180)
                failures=[line for line in run.stdout.splitlines() if line.startswith('FAIL ')]
                killed=run.returncode!=0 and bool(failures) and 'RESULT:' in run.stdout
                results.append(dict(rule=name,killed=killed,failures=failures))
                print(('KILLED ' if killed else 'SURVIVED ')+name,flush=True)
            finally:
                path.write_text(original)
    (ROOT/'notes/wanted-mutants.json').write_text(json.dumps(results,indent=2)+'\n')
    killed=sum(r['killed'] for r in results)
    print(f'Wanted mutants: {killed}/{len(results)} killed')
    raise SystemExit(0 if killed==len(results) else 1)

if __name__=='__main__':
    main()
