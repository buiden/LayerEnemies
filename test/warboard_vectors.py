"""Independent stdlib zlib fixture; no donor or embedded library execution."""
from pathlib import Path
import hashlib
import zlib

# A syntactically valid Ace root with ignored literal whitespace over the limit.
plain = b'^1^T^t^^' + b' ' * 262144
compressor = zlib.compressobj(7, zlib.DEFLATED, -15)
raw = compressor.compress(plain) + compressor.flush()
escaped = raw.replace(b'\x01', b'\x01\x03').replace(b'\x00', b'\x01\x02')
path = Path(__file__).with_name('fixtures') / 'warboard-bomb.bin'
path.parent.mkdir(exist_ok=True)
path.write_bytes(escaped)
print(path.name, len(escaped), hashlib.sha256(escaped).hexdigest())
