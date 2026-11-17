"""Independent format oracles, not upstream library code.

Sources (FORMAT ONLY): LibSerialize v1.1.3 Encoding format/type-byte documentation
at 3587abd411888ab19b9e4d53fe6091e53a491fbc; AceSerializer r1284 grammar.
Use Python struct for IEEE doubles; deliberately encode LS tables as arrays/maps
without references (the Lua reader's reference forms have hand-authored goldens).
"""
import struct


def addon_encode(data):
    return data.replace(b'\x01', b'\x01\x03').replace(b'\0', b'\x01\x02')


def addon_decode(data):
    result = bytearray()
    it = iter(data)
    for b in it:
        assert b != 0
        if b == 1:
            suffix = next(it)
            assert suffix in (2, 3)
            b = suffix - 2
        result.append(b)
    return bytes(result)


def ls_encode(value):
    def size(kind, count):
        width = max(1, (count.bit_length() + 7) // 8)
        return bytes([(kind + width - 1) * 8]) + count.to_bytes(width, 'big')

    def emit(v):
        if v is None:
            return b'\0'
        if isinstance(v, bool):
            return bytes([96 if v else 104])
        if isinstance(v, (int, float)):
            if isinstance(v, float) or abs(v) >= 2**53:
                return b'\x48' + struct.pack('>d', v)
            n = abs(v)
            if 0 <= v < 128:
                return bytes([2 * v + 1])
            if n < 4096:
                return bytes([(n % 16) * 16 + (12 if v < 0 else 4), n // 16])
            width, tag = next((w, t) for w, t in ((2, 1), (3, 3), (4, 5), (7, 7)) if n < 256**w)
            return bytes([(tag + (v < 0)) * 8]) + n.to_bytes(width, 'big')
        if isinstance(v, str):
            v = v.encode()
        if isinstance(v, bytes):
            return (bytes([len(v) * 16 + 2]) if len(v) < 16 else size(14, len(v))) + v
        if isinstance(v, list):
            return (bytes([len(v) * 16 + 10]) if len(v) < 16 else size(20, len(v))) + b''.join(map(emit, v))
        assert isinstance(v, dict)
        return (bytes([len(v) * 16 + 6]) if len(v) < 16 else size(17, len(v))) + b''.join(emit(k) + emit(x) for k, x in v.items())
    return b'\1' + emit(value)


def ls_decode(data):
    pos = 1
    assert data[0] in (1, 2)
    strings, tables = [], []

    def take(n):
        nonlocal pos
        value = data[pos:pos+n]
        assert len(value) == n
        pos += n
        return value

    def integer(n):
        return int.from_bytes(take(n), 'big')

    def text(n):
        s = take(n)
        if n > 2:
            strings.append(s)
        return s

    def table(array, pairs):
        t = {}
        tables.append(t)
        for k in range(1, array+1):
            value = read()
            if value is not None:
                t[k] = value
        for _ in range(pairs):
            k, v = read(), read()
            t[k] = v
        return t

    def read():
        b = integer(1)
        if b & 1:
            return b >> 1
        if b & 3 == 2:
            count, kind = b >> 4, (b >> 2) & 3
            if kind == 0:
                return text(count)
            if kind == 1:
                return table(0, count)
            if kind == 2:
                return table(count, 0)
            return table((count & 3)+1, (count >> 2)+1)
        if b & 7 == 4:
            value = (b >> 4) + 16 * integer(1)
            return -value if b & 8 else value
        tag = b >> 3
        if tag == 0:
            return None
        if tag <= 8:
            n = integer((2, 2, 3, 3, 4, 4, 7, 7)[tag-1])
            return -n if tag % 2 == 0 else n
        if tag == 9:
            return struct.unpack('>d', take(8))[0]
        if tag in (10, 11):
            value = float(take(integer(1)))
            return -value if tag == 11 else value
        if tag in (12, 13):
            return tag == 12
        family, width = divmod(tag-14, 3)
        width += 1
        count = integer(width)
        if family == 0:
            return text(count)
        if family == 1:
            return table(0, count)
        if family == 2:
            return table(count, 0)
        if family == 3:
            return table(count, integer(width))
        return (strings if family == 4 else tables)[count-1]
    out = read()
    assert pos == len(data)
    return out


def ace_encode(value):
    def escape(raw):
        out = bytearray()
        for b in raw:
            if b in (30, 94, 126, 127):
                out += b'~' + bytes([{30: 122, 94: 125, 126: 124, 127: 123}[b]])
            elif b <= 32:
                out += b'~' + bytes([b+64])
            else:
                out.append(b)
        return bytes(out)

    def emit(v):
        if v is None:
            return b'^Z'
        if isinstance(v, bool):
            return b'^B' if v else b'^b'
        if isinstance(v, (int, float)):
            return b'^N' + str(v).encode()
        if isinstance(v, str):
            v = v.encode()
        if isinstance(v, bytes):
            return b'^S' + escape(v)
        if isinstance(v, list):
            v = dict(enumerate(v, 1))
        return b'^T' + b''.join(emit(k)+emit(x) for k, x in v.items()) + b'^t'
    return b'^1' + emit(value) + b'^^'


def ace_decode(data):
    pos = 2
    assert data[:2] == b'^1'

    def read():
        nonlocal pos
        assert data[pos] == 94
        tag = data[pos+1:pos+2]
        end = data.index(b'^', pos+2)
        payload = data[pos+2:end]
        pos = end
        if tag == b'T':
            out = {}
            while data[pos:pos+2] != b'^t':
                key, value = read(), read()
                out[key] = value
            pos += 2
            return out
        if tag == b'S':
            out = bytearray()
            it = iter(payload)
            for b in it:
                if b == 126:
                    c = next(it)
                    escapes = {122: 30, 123: 127, 124: 126, 125: 94}
                    b = escapes[c] if c in escapes else c-64
                out.append(b)
            return bytes(out)
        if tag == b'N':
            return float(payload)
        if tag == b'B':
            return True
        if tag == b'b':
            return False
        assert tag == b'Z'
        return None
    out = read()
    assert data[pos:] == b'^^'
    return out


def normalize(value):
    if isinstance(value, str):
        return value.encode()
    if isinstance(value, list):
        return {i: normalize(v) for i, v in enumerate(value, 1)}
    if isinstance(value, dict):
        return {normalize(k): normalize(v) for k, v in value.items()}
    return value
