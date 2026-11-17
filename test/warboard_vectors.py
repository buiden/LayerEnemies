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

# Reviewer flood: unlike the whitespace-overflow fixture above, this is a
# complete Ace SHRD envelope that inflates AND deserializes under the old cap.
# Reproduces the reviewer's raw-DEFLATE bytes without running donor code.
prefix = b'^1^T^St^SSHRD^Sv^N5^Srs^Spvp^Sd^T^Sname^SEnemy^Srealm^SPlayer^Sfaction^SHorde^Sjunk^S'
suffix = b'^t^t^^'
plain = prefix + b'a' * (262006 - len(prefix) - len(suffix)) + suffix
compressor = zlib.compressobj(7, zlib.DEFLATED, -15)
raw = compressor.compress(plain) + compressor.flush()
escaped = raw.replace(b'\x01', b'\x01\x03').replace(b'\x00', b'\x01\x02')
assert len(plain) == 262006 and len(escaped) == 603
path = path.with_name('warboard-review-bomb.bin')
path.write_bytes(raw)  # receive-path tests use the actual addon encoder
print(path.name, len(raw), hashlib.sha256(raw).hexdigest())
