"""Exercise the exact binary allowlist and header gate, without client libraries."""
from pathlib import Path
import importlib.util
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('le_verify', ROOT / 'test/verify.py')
assert spec is not None and spec.loader is not None
v = importlib.util.module_from_spec(spec)
spec.loader.exec_module(v)
EXPECTED = {'Media/call-h1.tga', 'Media/call-h2.tga', 'Media/call-h6.tga'}


class CallAssets(unittest.TestCase):
    def setUp(self):
        (ROOT / 'dist').mkdir(exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=ROOT / 'dist', prefix='call-gate-')
        self.addon = Path(self.temp.name) / 'LayerEnemies'
        shutil.copytree(ROOT / 'LayerEnemies', self.addon)
        self.listed = [s for s in (self.addon / 'LayerEnemies.toc').read_text().splitlines() if s.endswith('.lua')]

    def tearDown(self):
        self.temp.cleanup()

    def test_exact_media_and_source_allowlist(self):
        self.assertEqual(set(getattr(v, 'MEDIA', ())), EXPECTED, 'three heading paths must be explicitly admitted')
        self.assertEqual(set(v.payload_files(self.listed, self.addon)), set(self.listed) | EXPECTED | {'LayerEnemies.toc'})
        v.check_media(self.addon)

    def test_reject_stray_media(self):
        self.assertTrue(hasattr(v, 'payload_files'), 'explicit packaging gate')
        (self.addon / 'Media').mkdir(exist_ok=True)
        (self.addon / 'Media/stray.tga').write_bytes(b'not shipped')
        with self.assertRaises(AssertionError):
            v.payload_files(self.listed, self.addon)

    def test_reject_stray_addon_file_and_folder(self):
        self.assertTrue(hasattr(v, 'payload_files'), 'explicit packaging gate')
        for name in ('stray.txt', 'test'):
            path = self.addon / name
            if name == 'test':
                path.mkdir()
            else:
                path.write_bytes(b'not shipped')
            with self.assertRaises(AssertionError):
                v.payload_files(self.listed, self.addon)
            if path.is_dir():
                path.rmdir()
            else:
                path.unlink()

    def test_reject_changed_header_and_size(self):
        self.assertTrue(hasattr(v, 'check_media'), 'TGA format gate')
        path = self.addon / 'Media/call-h1.tga'
        original = path.read_bytes()
        for offset, value in ((0, 1), (1, 1), (2, 10), (12, 128), (14, 32), (16, 24), (17, 40)):
            raw = bytearray(original)
            raw[offset] = value
            path.write_bytes(raw)
            with self.assertRaises(AssertionError, msg='header byte %d' % offset):
                v.check_media(self.addon)
        path.write_bytes(original[:-1])
        with self.assertRaises(AssertionError):
            v.check_media(self.addon)
        # A valid footer and header must not conceal an extra byte in the body.
        path.write_bytes(original[:-26] + b'\0' + original[-26:])
        with self.assertRaises(AssertionError):
            v.check_media(self.addon)

    def test_call_sources_and_art_references(self):
        self.assertTrue(hasattr(v, 'check_call_text'), 'Latin client text and asset-reference gate')
        v.check_call_text(self.addon)
        path = self.addon / 'CallText.lua'
        text = path.read_text()
        path.write_text(text.replace('call-h1.tga', 'stray.tga'))
        with self.assertRaises(AssertionError):
            v.check_call_text(self.addon)
        path.write_text(text.replace('Interface', 'Foreign'))
        with self.assertRaises(AssertionError):
            v.check_call_text(self.addon)
        path.write_text(text + '\n-- \u0627\n')
        with self.assertRaises(AssertionError):
            v.check_call_text(self.addon)


if __name__ == '__main__':
    unittest.main(verbosity=2)
