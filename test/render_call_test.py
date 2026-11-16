"""Offline renderer probes. Run with Pillow/RAQM and CALL_ART_FONT set to the pinned font."""
import contextlib
import importlib.util
import io
import os
from pathlib import Path
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('call_render', ROOT / 'tools/render_call.py')
assert spec and spec.loader
r = importlib.util.module_from_spec(spec)
spec.loader.exec_module(r)
FONT = Path(os.environ['CALL_ART_FONT'])


class CallRenderer(unittest.TestCase):
    def test_approved_small_copy_and_one_size_per_group(self):
        self.assertEqual(getattr(r, 'LABELS', {}), {'victim': 'من ربعنا:', 'killer': 'الغريم:', 'where': 'المكان:'})
        self.assertEqual(getattr(r, 'BUTTONS', {}), {'help': 'أبشر', 'dismiss-a': 'اعذروني', 'dismiss-b': 'سكّر'})
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            log = io.StringIO()
            with contextlib.redirect_stdout(log):
                r.render(FONT, root / 'art', root / 'previews')
            lines = log.getvalue().splitlines()
            for group in ('headings', 'labels', 'buttons'):
                self.assertEqual(sum(line.startswith(group + ': common size:') for line in lines), 1)
            expected = set(r.LINES) | set(r.LABELS) | set(r.BUTTONS)
            self.assertEqual({p.stem[5:] for p in (root / 'art').glob('*.tga')}, expected)
            for key in expected:
                raw = (root / 'art' / ('call-' + key + '.tga')).read_bytes()
                self.assertEqual(len(raw), 65580 if key in r.LINES else 16428)
                # Rebuild the shipped pixels, including unchanged original headings.
                self.assertEqual(raw, (ROOT / 'LayerEnemies/Media' / ('call-' + key + '.tga')).read_bytes())

    def test_overflow_fails_instead_of_clipping(self):
        self.assertTrue(hasattr(r, 'LABELS'), 'small art renderer')
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            with mock.patch.dict(r.LABELS, {'victim': r.LABELS['victim'] * 100}):
                with self.assertRaisesRegex(AssertionError, 'common size fits'):
                    r.render(FONT, root / 'art', root / 'previews')

    def test_no_unshaped_or_wrong_font_fallback(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            with mock.patch.object(r.features, 'check', return_value=False):
                with self.assertRaisesRegex(AssertionError, 'RAQM'):
                    r.render(FONT, root / 'art', root / 'previews')
            bad_font = root / 'wrong-font.ttf'
            bad_font.write_bytes(b'not the approved font')
            with self.assertRaisesRegex(AssertionError, 'pinned OFL font'):
                r.render(bad_font, root / 'art', root / 'previews')


if __name__ == '__main__':
    unittest.main(verbosity=2)
