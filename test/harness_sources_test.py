"""Registry-era harness contract: generic literal filter and discovered suites."""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
LUA = os.environ.get('LAYERENEMIES_LUA', '/opt/data/tools/lua/lua-5.1.5/src/lua')


class HarnessSourcesTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='le-src-harness-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for folder in ('LayerEnemies', 'test'):
            shutil.copytree(ROOT / folder, self.root / folder)
        (self.root / 'test/src__discovery.lua').write_text(
            'local h=...\nh.test("Discovery: literal [probe]",function() h.eq(1,1) end)\n'
            'h.test("Discovery: not selected",function() error("must be filtered") end)\n')

    def run_harness(self, *args):
        return subprocess.run([LUA, 'test/harness.lua', *args], cwd=self.root,
                              capture_output=True, text=True, timeout=180)

    def test_generic_space_filter_and_autoload(self):
        r = self.run_harness('--only', 'literal [probe]')
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn('RESULT: 1 tests passed, 0 failed', r.stdout)
        self.assertNotIn('PASS ', r.stdout.replace('PASS Discovery: literal [probe]', ''))

    def test_generic_equals_filter(self):
        r = self.run_harness('--only=literal [probe]')
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn('RESULT: 1 tests passed, 0 failed', r.stdout)

    def test_discovered_failure_is_not_hidden(self):
        r = self.run_harness('--only', 'Discovery: not selected')
        self.assertNotEqual(r.returncode, 0)
        self.assertIn('must be filtered', r.stdout + r.stderr)

    def test_empty_selection_and_invalid_args_fail_closed(self):
        for args in (('--only', 'NO_SUCH_TEST'), ('--only',), ('--only=',), ('--bogus',)):
            r = self.run_harness(*args)
            self.assertNotEqual(r.returncode, 0, args)


if __name__ == '__main__':
    unittest.main(verbosity=2)
