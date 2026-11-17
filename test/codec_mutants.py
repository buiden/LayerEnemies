"""Run: python3 test/codec_mutants.py. One mutant per named codec rule.

Each candidate is syntax-checked and exercised in a private scratch directory.
The real source is never edited; timeout/syntax failure is NOT a killed mutant.
"""
from pathlib import Path
import json
import os
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
LUA = Path(os.environ.get('LAYERENEMIES_LUA', '/opt/data/tools/lua/lua-5.1.5/src/lua'))
MUTANTS = [
    ('input-byte-ceiling', '262144, 8, 4097, 2048', '262145, 8, 4097, 2048'),
    ('compressed-input-ceiling', 'MAX_BYTES+25, 4194304', 'MAX_BYTES+1024, 4194304'),
    ('writer-output-ceiling', 'if size>(limit or MAX_BYTES) then fail() end', 'if false then fail() end'),
    ('inflate-caller-output-ceiling', 'if size+n>maxOut then fail() end', 'if size+n>MAX_BYTES then fail() end'),
    ('inflate-hard-output-ceiling', 'or maxOut>MAX_BYTES', 'or false'),
    ('inflate-work-ceiling', 'if work>MAX_WORK then fail() end', 'if false then fail() end'),
    ('stored-length-complement', 'len+nlen~=65535 or', 'false or'),
    ('raw-single-stream', 'if pos~=#input+1 then fail() end', 'if false then fail() end'),
    ('oversubscribed-huffman', 'if left<0 then fail() end', 'if false then fail() end'),
    ('incomplete-huffman', 'if left>0 and (complete or maximum~=1) then fail() end', 'if false then fail() end'),
    ('repeat-needs-prior-length', 'if index==0 then fail() end', 'if index==0 then all[-1]=0 end'),
    ('repeat-alphabet-ceiling', 'if index+count>nl+nd then fail() end', 'if index+count>nl+nd then count=nl+nd-index end'),
    ('reserved-literal-length', 'if v>285 then fail() end', 'if v>285 then v=285 end'),
    ('reserved-distance', 'if di>30 then fail() end', 'if di>30 then di=1 end'),
    ('distance-history', 'if offset>size or offset>32768 then fail() end', 'if false then fail() end'),
    ('stored-final-bit', 'char(last and 1 or 0,n%256', 'char(last and 0 or 1,n%256'),
    ('addon-zero-escape', '"\\001\\002" or "\\001\\003"', '"\\001\\003" or "\\001\\002"'),
    ('addon-forbids-literal-zero', 'if input:find("%z") then fail() end', 'if false then fail() end'),
    ('addon-escape-suffix', 'if suffix~=2 and suffix~=3 then fail() end', 'if suffix~=2 and suffix~=3 then suffix=2 end'),
    ('secret-boundary', 'return S and S.secret(v)', 'return false'),
    ('plain-tables', 'and getmetatable(v)==nil', 'and true'),
    ('finite-numbers', 'and v~=math.huge and v~=-math.huge', ''),
    ('table-depth', '262144, 8, 4097, 2048', '262144, 9, 4097, 2048'),
    ('logical-value-count', '262144, 8, 4097, 2048', '262144, 8, 4098, 2048'),
    ('root-slot-for-2048-entries', '262144, 8, 4097, 2048', '262144, 8, 4096, 2048'),
    ('table-entry-count', '262144, 8, 4097, 2048', '262144, 8, 4097, 2049'),
    ('logical-expanded-string-bytes', 'if stringBytes>MAX_BYTES then fail() end', 'if false then fail() end'),
    ('acyclic-graphs', 'if not plain(v) or active[v] or depth>=MAX_DEPTH then fail() end', 'if active[v] then return end; if not plain(v) or depth>=MAX_DEPTH then fail() end'),
    ('one-root-table', 'if not plain(root) then fail() end', 'if false then fail() end'),
    ('ace-version', 'if sub(input,1,2)~="^1" then fail() end', 'if false then fail() end'),
    ('ace-terminator-and-tail', 'if sub(input,at)~="^^" then fail() end', 'if false then fail() end'),
    ('ace-string-escape', 'if not b then fail() end\n        if b>=64', 'if not b then b=64 end\n        if b>=64'),
    ('duplicate-map-key', 'or seen[k] then fail() end', 'then fail() end'),
    ('libserialize-version', 'if version~=1 and version~=2 then fail() end', 'if false then fail() end'),
    ('libserialize-exact-integer', 'if v%256~=b then fail() end', 'if false then fail() end'),
    ('libserialize-reference-exists', 'if value==nil then fail() end', 'if value==nil then value="" end'),
    ('libserialize-single-root', 'if at~=#input+1 then fail() end', 'if false then fail() end'),
    ('acecomm-stream-count', 'count>=16', 'count>=17'),
    ('acecomm-byte-count', 'stream.size+#part>32768', 'stream.size+#part>32769'),
    ('acecomm-fragment-count', 'stream.count>=256', 'stream.count>=257'),
    ('acecomm-total-lifetime', 'now-stream.at>=120', 'now-stream.at>120'),
    ('acecomm-total-cap-retained', 'or now-stream.at>=120', 'or false'),
    ('acecomm-idle-boundary', 'now-stream.last>=15', 'now-stream.last>15'),
    ('acecomm-idle-refresh', 'stream.parts[stream.count]=part; stream.last=now', 'stream.parts[stream.count]=part'),
    ('acecomm-total-from-first', 'stream.parts[stream.count]=part; stream.last=now', 'stream.parts[stream.count]=part; stream.last=now; stream.at=now'),
    ('acecomm-idle-per-stream', 'stream.parts[stream.count]=part; stream.last=now', 'stream.parts[stream.count]=part; for _,s in next,streams do s.last=now end'),
    ('acecomm-accepted-fragments-only', 'if control<1 or control>9 then return text end', 'if control<1 or control>9 then if streams[key] then streams[key].last=now end; return text end'),
    ('acecomm-rollback', 'not state or now<state.now', 'not state'),
    ('acecomm-sender-key', 'local now=st.now', 'key="shared"; local now=st.now'),
    ('acecomm-first-replaces', 'streams[key]={at=now,last=now,parts={part},size=#part,count=1}', 'streams[key]=streams[key] or {at=now,last=now,parts={part},size=#part,count=1}'),
    ('acecomm-terminal-clears', 'streams[key]=nil\n        return concat(stream.parts)', 'return concat(stream.parts)'),
    ('acecomm-physical-frame', 'bytes(text,255)', 'bytes(text,256)'),
    ('acecomm-key-length', 'bytes(key,256)', 'bytes(key,257)'),
    ('acecomm-reserved-control', '#text==1 or control>=5', '#text==1'),
    ('acecomm-split-escape', 'local escape=first>=1 and first<=9', 'local escape=false'),
    ('acecomm-split-byte-count', 'bytes(input,32768)', 'bytes(input,32769)'),
]


def run():
    source = (ROOT / 'LayerEnemies/Codec.lua').read_text()
    baseline = subprocess.run([str(LUA), 'test/codec.lua'], cwd=ROOT, capture_output=True, text=True, errors='replace', timeout=30, check=True)
    print(baseline.stdout.strip(), flush=True)
    result = []
    scratch = Path(os.environ.get('TMPDIR', '/opt/data/cache/scratch'))
    assert str(scratch).startswith('/opt/data/cache/scratch')
    with tempfile.TemporaryDirectory(prefix='codec-mutants-', dir=scratch) as directory:
        target = Path(directory) / 'LayerEnemies/Codec.lua'
        target.parent.mkdir()
        for name, before, after in MUTANTS:
            count = source.count(before)
            assert count == (2 if name == 'duplicate-map-key' else 1), (name, count)
            target.write_text(source.replace(before, after))
            subprocess.run([str(LUA.with_name('luac')), '-p', str(target)], check=True, capture_output=True)
            env = dict(os.environ, CODEC_ROOT=directory)
            p = subprocess.run([str(LUA), 'test/codec.lua'], cwd=ROOT, env=env, capture_output=True, text=True, errors='replace', timeout=30)
            if p.returncode == 0:
                p = subprocess.run([str(LUA), 'test/codec_fuzz.lua'], cwd=ROOT, env=env, capture_output=True, text=True, errors='replace', timeout=30)
            killed = p.returncode != 0
            evidence = '\n'.join(x for x in (p.stdout+p.stderr).splitlines() if 'FAIL' in x or 'assertion failed' in x)[:1000]
            result.append(dict(rule=name, killed=killed, evidence=evidence))
            print(('KILLED ' if killed else 'SURVIVED ') + name, flush=True)
    (ROOT / 'notes/codec-mutants.json').write_text(json.dumps(result, indent=2) + '\n')
    killed = sum(x['killed'] for x in result)
    print('CODEC MUTANTS: %d/%d killed' % (killed, len(result)), flush=True)
    assert killed == len(result)


if __name__ == '__main__':
    run()
