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
HEADINGS = {'Media/call-h1.tga', 'Media/call-h2.tga', 'Media/call-h6.tga'}
SMALL = {'Media/call-victim.tga', 'Media/call-killer.tga', 'Media/call-where.tga',
         'Media/call-help.tga', 'Media/call-dismiss-a.tga', 'Media/call-dismiss-b.tga'}
EXPECTED = HEADINGS | SMALL


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
        self.assertEqual(set(getattr(v, 'MEDIA', ())), EXPECTED, 'exactly three headings, three labels and three buttons')
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
        for name in sorted(EXPECTED):
            path = self.addon / name
            self.assertTrue(path.is_file(), 'required art: ' + name)
            original = path.read_bytes()
            for offset in (0, 1, 2, 12, 14, 16, 17):
                raw = bytearray(original)
                raw[offset] ^= 1
                path.write_bytes(raw)
                with self.assertRaises(AssertionError, msg='%s header byte %d' % (name, offset)):
                    v.check_media(self.addon)
            path.write_bytes(original[:-1])
            with self.assertRaises(AssertionError):
                v.check_media(self.addon)
            # A valid footer and header must not conceal an extra byte in the body.
            path.write_bytes(original[:-26] + b'\0' + original[-26:])
            with self.assertRaises(AssertionError):
                v.check_media(self.addon)
            path.write_bytes(original)

    def test_exact_dimensions_padding_and_ink_for_every_asset(self):
        import struct
        for name in sorted(EXPECTED):
            path = self.addon / name
            self.assertTrue(path.is_file(), 'required art: ' + name)
            width, height = (256, 64) if name in HEADINGS else (128, 32)
            raw = path.read_bytes()
            self.assertEqual(len(raw), 18 + width * height * 4 + 26)
            self.assertEqual(raw[:18], struct.pack('<BBBHHBHHHHBB', 0, 0, 2, 0, 0, 0, 0, 0, width, height, 32, 0x08))
            self.assertEqual(raw[-26:], struct.pack('<II', 0, 0) + b'TRUEVISION-XFILE.\0')
            alpha = raw[21:-26:4]
            ink = [(i % width, i // width) for i, value in enumerate(alpha) if value]
            self.assertTrue(ink)
            self.assertTrue(all(4 <= x < width - 4 and 4 <= y < height - 4 for x, y in ink))
            self.assertLessEqual(max(x for x, _ in ink) - min(x for x, _ in ink) + 1, 190 if name in HEADINGS else 120)
            # The label's leftmost colon is only the required padding from the value.
            if name in {'Media/call-victim.tga', 'Media/call-killer.tga', 'Media/call-where.tga'}:
                self.assertEqual(min(x for x, _ in ink), 4)

    def test_reject_small_padding_empty_and_footer_damage(self):
        path = self.addon / 'Media/call-victim.tga'
        self.assertTrue(path.is_file(), 'required label art')
        original = path.read_bytes()
        for mode in ('padding', 'empty', 'footer'):
            raw = bytearray(original)
            if mode == 'padding':
                raw[21] = 255
            elif mode == 'empty':
                raw[21:-26:4] = bytes(128 * 32)
            else:
                raw[-1] = 1
            path.write_bytes(raw)
            with self.assertRaises(AssertionError, msg=mode):
                v.check_media(self.addon)
        path.write_bytes(original)

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
