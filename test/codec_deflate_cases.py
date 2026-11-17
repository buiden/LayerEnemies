"""Small RFC 1951 bit-level fixtures, independently checked with Python zlib.

This is a test-only bit packer, not a copy of an inflate implementation.
Regenerate as part of: python3 test/codec_vectors.py
"""
import zlib

ORDER = [16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15]


class Bits:
    def __init__(self):
        self.bits = []

    def low(self, value, width):
        self.bits += [(value >> i) & 1 for i in range(width)]

    def code(self, symbol, lengths):
        code, lookup = 0, {}
        for size in range(1, 16):
            for item in sorted(k for k, n in lengths.items() if n == size):
                lookup[item] = (code, size)
                code += 1
            code *= 2
        value, size = lookup[symbol]
        self.bits += [(value >> i) & 1 for i in range(size-1, -1, -1)]

    def finish(self):
        return bytes(sum(b << j for j, b in enumerate(self.bits[i:i+8])) for i in range(0, len(self.bits), 8))


def dynamic(lit, dist=None, ct=None, rle=None):
    dist = dist or {0: 0}
    if ct is None:
        used = set(lit.values()) | set(dist.values()) | {0}
        assert len(used) == 2
        ct = dict.fromkeys(used, 1)
    out = Bits()
    out.low(1, 1); out.low(2, 2)
    nl, nd = max(257, max(lit)+1), max(dist)+1
    nc = max(4, max(ORDER.index(k)+1 for k in ct))
    out.low(nl-257, 5); out.low(nd-1, 5); out.low(nc-4, 4)
    for k in ORDER[:nc]:
        out.low(ct.get(k, 0), 3)
    sequence = [(lit.get(i, 0), 0, 0) for i in range(nl)] + [(dist.get(i, 0), 0, 0) for i in range(nd)]
    for v, extra, width in (sequence if rle is None else rle):
        out.code(v, ct); out.low(extra, width)
    out.code(256, lit)
    return out.finish()


def fixed(sequence):
    lit = {i: 8 if i < 144 else 9 if i < 256 else 7 if i < 280 else 8 for i in range(288)}
    dist = dict.fromkeys(range(32), 5)
    out = Bits(); out.low(1, 1); out.low(1, 2)
    for kind, value, width in sequence:
        if kind == 'lit':
            out.code(value, lit)
        elif kind == 'dist':
            out.code(value, dist)
        else:
            out.low(value, width)
    return out.finish()


def cases():
    good = [('dynamic empty distance alphabet', dynamic({256: 1}), b''),
            ('dynamic one-symbol distance alphabet', dynamic({256: 1}, {0: 1}), b'')]
    bad = [
        ('oversubscribed code lengths', dynamic({256: 1}, ct={0: 1, 1: 1, 2: 1})),
        ('incomplete code lengths', dynamic({256: 1}, ct={0: 2, 1: 2})),
        ('incomplete literal alphabet', dynamic({65: 2, 256: 2})),
        ('repeat before first length', dynamic({256: 1}, ct={16: 1, 0: 2, 1: 2},
            rle=[(16, 0, 2)] + [(0, 0, 0)] * 253 + [(1, 0, 0), (0, 0, 0)])),
        ('repeat past alphabet end', dynamic({256: 1}, {0: 1}, ct={16: 1, 0: 2, 1: 2},
            rle=[(0, 0, 0)] * 256 + [(1, 0, 0), (16, 0, 2)])),
        ('reserved literal 286', fixed([('lit',65,0),('lit',286,0),('dist',0,0),('lit',256,0)])),
        ('reserved distance 30', fixed([('lit',65,0),('lit',257,0),('dist',30,0),('lit',256,0)])),
        ('distance before output', fixed([('lit',257,0),('dist',0,0),('lit',256,0)])),
    ]
    for name, wire, expected in good:
        assert zlib.decompress(wire, -15) == expected, name
    for name, wire in bad:
        try:
            zlib.decompress(wire, -15)
        except zlib.error:
            continue
        raise AssertionError('zlib accepted malformed fixture: ' + name)
    return good, bad
