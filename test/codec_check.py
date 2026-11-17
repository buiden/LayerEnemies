"""Run: python3 test/codec_check.py (stdlib only, foreground, no donor execution).

Runs unit/fuzz/benchmark tests, compares Lua writers against independent Python
format readers and zlib, then differentially checks mutated compressed streams.
Mutation-rule gate is separate: python3 test/codec_mutants.py.
"""
from pathlib import Path
import json
import os
import random
import subprocess
import zlib
from codec_reference import ace_encode, ace_decode, ls_encode, ls_decode, normalize

ROOT = Path(__file__).resolve().parents[1]
LUA = os.environ.get('LAYERENEMIES_LUA', '/opt/data/tools/lua/lua-5.1.5/src/lua')


def bridge(requests):
    data = ''.join(mode + '\t' + payload.hex() + '\n' for mode, payload in requests)
    p = subprocess.run([LUA, 'test/codec_bridge.lua'], input=data, capture_output=True, text=True, cwd=ROOT, timeout=120, check=True)
    lines = p.stdout.splitlines()
    assert len(lines) == len(requests), (len(lines), len(requests), p.stderr)
    return [None if x == 'nil' else bytes.fromhex(x) for x in lines]


def run():
    for filename in ('test/codec.lua', 'test/codec_fuzz.lua', 'test/benchmark.lua'):
        subprocess.run([LUA, filename], cwd=ROOT, check=True, timeout=120)
    rng = random.Random(20261117)
    raw = [b'', b'hello', bytes(range(256))]
    raw += [bytes(rng.randrange(256) for _ in range(n)) for n in (65535, 65536, 131070, 262144)]
    for _ in range(250):
        alphabet = bytes(rng.randrange(256) for _ in range(rng.choice((1, 2, 5, 80, 256))))
        raw.append(bytes(rng.choice(alphabet) for _ in range(rng.randrange(16384))))
    requests, expected, compressed = [], [], []
    for i, value in enumerate(raw):
        c = zlib.compressobj((0, 3, 5, 7, 9)[i % 5], zlib.DEFLATED, -15)
        stream = c.compress(value) + c.flush()
        compressed.append(stream)
        requests.append(('inflate', stream)); expected.append(value)
    for value in raw:
        requests.append(('deflateStored', value)); expected.append(value)
    results = bridge(requests)
    refused_at_input_cap = 0
    for (mode, payload), result, value in zip(requests, results, expected):
        if mode == 'inflate' and len(payload) > 262169:
            assert result is None  # codec's documented compressed-input cap, not a zlib failure
            refused_at_input_cap += 1
            continue
        assert result is not None, (mode, len(payload))
        if mode == 'deflateStored':
            result = zlib.decompress(result, -15)
        assert result == value, mode
    print('ZLIB: %d inflate + %d stored-writer comparisons passed (%d input-cap refusals)' % (len(raw), len(raw), refused_at_input_cap), flush=True)

    objects: list[dict] = [dict(data=bytes(range(256)), x=-1/3, empty={})]
    for _ in range(250):
        objects.append({'k': bytes(rng.randrange(256) for _ in range(rng.randrange(128))),
                        'n': rng.uniform(-1e8, 1e8), 'i': rng.randrange(-2**52, 2**52),
                        'b': bool(rng.randrange(2)), 'nested': [{'v': rng.randrange(65536)}, {}]})
    archive = json.loads((ROOT / 'test/fixtures/codec_audits.json').read_text())
    objects += [x['expected'] for x in archive['wanted']] + [archive['warboard']['expected']]
    requests = [(mode, encoder(obj)) for obj in objects for mode, encoder in (('ace', ace_encode), ('ls', ls_encode))]
    results = bridge(requests)
    for i, ((mode, payload), result) in enumerate(zip(requests, results)):
        assert result is not None, (mode, i)
        decoded = (ace_decode if mode == 'ace' else ls_decode)(result)
        assert decoded == normalize(objects[i // 2]), (mode, i)
    print('SERIALIZERS: %d independent Python->Lua->Python comparisons passed' % len(results), flush=True)

    mutated = []
    for _ in range(1000):
        data = bytearray(rng.choice(compressed))
        idx = rng.randrange(len(data))
        data[idx] ^= 1 << rng.randrange(8)
        mutated.append(bytes(data))
    results = bridge([('inflate', x) for x in mutated])
    accepted = 0
    for stream, result in zip(mutated, results):
        if result is not None:
            obj = zlib.decompressobj(-15)
            reference = obj.decompress(stream, 262145)
            assert obj.eof and not obj.unused_data and reference == result
            accepted += 1
    print('DIFFERENTIAL: 1000 bit-mutated streams; %d accepted and matched zlib, others refused' % accepted, flush=True)
    print('CODEC CHECK: PASS', flush=True)


if __name__ == '__main__':
    run()
