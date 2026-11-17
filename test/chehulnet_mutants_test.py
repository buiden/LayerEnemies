"""Exercise the real mutant runner with one real Lua mutant in scratch copies."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


class ChehulNetMutantRunnerTests(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location('chehulnet_mutants', ROOT / 'test/chehulnet_mutants.py')
        assert spec is not None and spec.loader is not None
        self.runner = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.runner)
        scratch = tempfile.TemporaryDirectory(prefix='le-chehulnet-runner-test-')
        self.addCleanup(scratch.cleanup)
        self.root = Path(scratch.name)
        for folder in ('LayerEnemies', 'test'):
            shutil.copytree(ROOT / folder, self.root / folder)
        (self.root / 'notes').mkdir()
        self.report = self.root / 'notes/chehulnet-mutants.json'
        setattr(self.runner, 'ROOT', self.root)
        # Real syntax check and harness, bounded to the first protocol mutant.
        # This also prevents recursion when the full runner mutates itself.
        setattr(self.runner, 'MUTANTS', self.runner.MUTANTS[:1])

    def run_runner(self, *args):
        output = io.StringIO()
        with patch.object(sys, 'argv', ['chehulnet_mutants.py', *args]), contextlib.redirect_stdout(output):
            self.runner.main()
        self.assertIn('RESULT: 1/1 ChehulNet mutants killed', output.getvalue())

    def test_default_reruns_preserve_existing_report_bytes_and_mtime(self):
        sentinel = b'[{"preserved": "review evidence"}]\n'
        self.report.write_bytes(sentinel)
        before = self.report.stat().st_mtime_ns
        for _ in range(2):
            self.run_runner()
            self.assertEqual(self.report.read_bytes(), sentinel, 'default run must not rewrite evidence')
            self.assertEqual(self.report.stat().st_mtime_ns, before, 'even an identical rewrite dirties metadata')

    def test_default_does_not_create_a_report(self):
        self.run_runner()
        self.assertFalse(self.report.exists(), 'only --write may create an evidence file')

    def test_write_flag_publishes_real_mutant_results(self):
        self.report.write_text('[]\n')
        self.run_runner('--write')
        results = json.loads(self.report.read_text())
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]['rule'], self.runner.MUTANTS[0][0])
        self.assertTrue(results[0]['killed'])
        self.assertTrue(results[0]['failures'])
        self.assertTrue(all(line.startswith('FAIL ChehulNet:') for line in results[0]['failures']))


if __name__ == '__main__':
    unittest.main(verbosity=2)
