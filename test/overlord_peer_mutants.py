"""Portable C2 mutants: scratch copies, syntax checked, behavioral kills only."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
LUA = os.environ.get('LAYERENEMIES_LUA') or shutil.which('lua5.1') or shutil.which('lua') or '/opt/data/tools/lua/lua-5.1.5/src/lua'
# rule, file, unique anchor, replacement, test selector
MUTANTS = [
 ('round robin directory','OverlordPeer.lua','((st.greeter or 0)+step-1)%#members+1','step','Overlord peer:'),
 ('refused admission is uncharged','OverlordPeer.lua','local charged=ok and (result==true or attempted==true)','local charged=true','Overlord peer:'),
 ('refused greeting global gap','OverlordPeer.lua','if charged then st.greeting=c.now;st.greeter=index end','st.greeting=c.now;st.greeter=index','Overlord peer:'),
 ('Wire refusal actual gap','Main.lua','if attempted then P.claim(M.overlordPeer,job,live) end','P.claim(M.overlordPeer,job,live)','Overlord peer:'),
 ('shared NH HA gap','OverlordPeer.lua','P.emit(st,c,"HA",body,route,target,"reply:"..key,150,true)','P.emit(st,c,"HA",body,route,target,"answer:"..key,150,true)','Overlord peer:'),
 ('donor loaded context silence','Main.lua','and ok==true and not A.inCombat()','and true and not A.inCombat()','Overlord peer:'),
 ('donor loaded BNet silence','BNet.lua','net~="overlord" and why=="stand down"','why=="stand down"','Overlord peer:'),
 ('donor loaded Wire silence','Wire.lua','if not ok then return nil, why end','if not ok and not (prefix=="OverlordF" and why=="stand down" and opts.prio=="owed") then return nil, why end','Overlord peer:'),
 ('24 parts','Overlord.lua','uint(part,24,1),uint(count,24,1)','uint(part,25,1),uint(count,25,1)','Overlord peer:'),
 ('3600 bytes','Overlord.lua','a.bytes+#chunk>3600','a.bytes+#chunk>3601','Overlord peer:'),
 ('total assembly lifetime','Overlord.lua','now-a.at>=120','now-a.at>120','Overlord peer:'),
 ('idle assembly lifetime','Overlord.lua','now-a.last>=30','now-a.last>30','Overlord peer:'),
 ('duplicate idle refresh','Overlord.lua','if not a.chunks[part] then\n        if a.bytes','a.last=now\n    if not a.chunks[part] then\n        if a.bytes','Overlord peer:'),
 ('four streams per sender','Overlord.lua','owned>=4','owned>=5','Overlord peer:'),
 ('64 streams overall','Overlord.lua','n>=64','n>=65','Overlord peer:'),
 ('guild stream reserve','Overlord.lua','pub>=48','pub>=49','Overlord peer:'),
 ('assembly byte ceiling','Overlord.lua','totalBytes+#chunk>65536','false','Overlord peer:'),
 ('guild byte reserve','Overlord.lua','publicBytes+#chunk>49152','false','Overlord peer:'),
 ('sender frame budget','Overlord.lua','r.n>=120','r.n>120','Overlord peer:'),
 ('sender byte budget','Overlord.lua','r.bytes+size>14400','false','Overlord peer:'),
 ('global public work budget','Overlord.lua','b.public+size>96000','false','Overlord peer:'),
 ('sender table guild reserve','Overlord.lua','pub>=96','pub>=97','Overlord peer:'),
 ('account budget','Overlord.lua','if account then keys[2]="bn:"..account end','if false then keys[2]="bn:"..account end','Overlord peer:'),
 ('case-folded sender','Overlord.lua','local who=sender:lower()','local who=sender','Overlord peer:'),
 ('2000 seen ring','Overlord.lua','st.cursor%2000+1','st.cursor%1999+1','Overlord:'),
 ('path loop','Overlord.lua','or (me and F.fold(me)==key)','or false','Overlord peer:'),
 ('whisper reception','Main.lua','and kind~="WHISPER" and kind~="BNET"','and kind~="BNET"','Overlord peer:'),
 ('R2 pool isolation','Main.lua','if not pool or pool~=M.overlordPool() then return end','if not pool then return end','Overlord peer:'),
 ('own identity','OverlordPeer.lua','"LayerEnemies "..c.version','"Overlord 2.5.4"','Overlord peer:'),
 ('no forwarding','OverlordPeer.lua','local r=learn(st,p,route,sender,id,c)','c.send(c,p.payload,"WHISPER","Other Scout","own")\n    local r=learn(st,p,route,sender,id,c)','Overlord peer:'),
 ('only direct replies','OverlordPeer.lua','if p.hops~=0 or p.target~=c.me','if p.target~=c.me','Overlord peer:'),
 ('only addressed replies','OverlordPeer.lua','p.hops~=0 or p.target~=c.me','p.hops~=0','Overlord peer:'),
 ('six owed admissions','OverlordPeer.lua','#st.owed>=6','#st.owed>=7','Overlord peer:'),
 ('150 second reply gap','OverlordPeer.lua','P.emit(st,c,"NH",P.presence(c),route,target,"reply:"..key,150,true)','P.emit(st,c,"NH",P.presence(c),route,target,"reply:"..key,149,true)','Overlord peer:'),
 ('actual gap','OverlordPeer.lua','if not due(st.actual[job.key],c.now,job.gap) then','if false then','Overlord peer:'),
 ('actual owed cap','OverlordPeer.lua','#st.actualOwed>=6','#st.actualOwed>=7','Overlord peer:'),
 ('pool dispatch recheck','OverlordPeer.lua','function P.claim(st,job,c,checkOnly)\n    if not ready(c,job.owed) or c.pool~=job.pool','function P.claim(st,job,c,checkOnly)\n    if not ready(c,job.owed) or false','Overlord peer:'),
 ('alone guild interval','OverlordPeer.lua','and 120 or 600','and 120 or 599','Overlord peer:'),
 ('heard guild interval','OverlordPeer.lua','and 120 or 600','and 119 or 600','Overlord peer:'),
 ('group interval','OverlordPeer.lua','"group",120,false','"group",119,false','Overlord peer:'),
 ('five bridges','OverlordPeer.lua','math.min(5,#live)','math.min(6,#live)','Overlord peer:'),
 ('two probes','OverlordPeer.lua','math.min(2,#unheard)','math.min(3,#unheard)','Overlord peer:'),
 ('friends only','OverlordPeer.lua','if f.friend and #live+#unheard<200 then','if #live+#unheard<200 then','Overlord peer:'),
 ('greeting cadence','OverlordPeer.lua','due(st.greeting,c.now,60)','due(st.greeting,c.now,59)','Overlord peer:'),
 ('six partners','OverlordPeer.lua','partners<6','partners<7','Overlord peer:'),
 ('truthful empty counts','OverlordPeer.lua','body=body..":"..stream..":0:0"','body=body..":"..stream..":1:1"','Overlord peer:'),
 ('route ceiling','OverlordPeer.lua','n>=128','n>=129','Overlord peer:'),
 ('route guild reserve','OverlordPeer.lua','pub>=96','pub>=97','Overlord peer:'),
 ('route expiry','OverlordPeer.lua','now-r.at>=300','now-r.at>300','Overlord peer:'),
 ('two free slots','Directory.lua','slots<=7','slots<=8','Overlord peer:'),
 ('private Wire flight','Wire.lua','not N.OverlordPeer.dispatching(text,kind,target)','false','Overlord peer:'),
 ('queue guard','BNet.lua','if q.guard then valid,allowed=pcall(q.guard) end','if false then valid,allowed=pcall(q.guard) end','Overlord peer:'),
 ('BN eight cap','BNet.lua','overlord=8','overlord=9','BNet queue:'),
]

def run(mutants=MUTANTS, report='overlord-peer-mutants.json', write=False):
    scratch = Path(os.environ.get('TMPDIR', str(Path.home() / 'cache/scratch'))).resolve()
    scratch.mkdir(parents=True, exist_ok=True)
    results=[]
    with tempfile.TemporaryDirectory(prefix='le-overlord-mut-', dir=scratch) as directory:
        root=Path(directory)
        for folder in ('LayerEnemies','test'):
            shutil.copytree(ROOT/folder,root/folder)
        for rule,file,old,new,selector in mutants:
            path=root/'LayerEnemies'/file
            original=path.read_text()
            if original.count(old)!=1: raise AssertionError((rule,'mutation anchor',original.count(old)))
            path.write_text(original.replace(old,new))
            try:
                subprocess.run([str(Path(LUA).with_name('luac')),'-p',str(path)],check=True,capture_output=True)
                proc=subprocess.run([LUA,'test/harness.lua','--only',selector],cwd=root,capture_output=True,text=True,errors='replace',timeout=180)
                failures=[re.sub(r'0x[0-9a-fA-F]+','0xADDR',s) for s in proc.stdout.splitlines() if s.startswith('FAIL ')]
                # A nil module/setup exception or crash is not a behavioral kill.
                kills=[s for s in failures if 'expected ' in s and ', got ' in s]
                killed=proc.returncode==1 and bool(kills) and 'RESULT:' in proc.stdout
                results.append({'rule':rule,'killed':killed,'failures':kills})
                print(('KILLED ' if killed else 'SURVIVED ')+rule)
            finally: path.write_text(original)
    encoded=json.dumps(results,indent=2,sort_keys=True)+'\n'
    target=ROOT/'notes'/report
    if write and (not target.exists() or target.read_text()!=encoded): target.write_text(encoded)
    count=sum(r['killed'] for r in results)
    print(f'RESULT: {count}/{len(results)} mutants killed')
    return count==len(results)

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--write',action='store_true')
    raise SystemExit(0 if run(write=parser.parse_args().write) else 1)
