"""FLH mutation evidence must be deterministic, portable, and not rewritten."""
from pathlib import Path
import os
import runpy
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


class MutationEvidenceTests(unittest.TestCase):
    def test_reports_normalize_runtime_identity_and_checkout_paths(self):
        for name in ('flh_mutants.py', 'flh_member_mutants.py'):
            with self.subTest(runner=name):
                runner = runpy.run_path(str(ROOT / 'test' / name))
                results = []
                for checkout, address in (('/scratch/clone-a', '0x123abc'), ('/scratch/clone-b', '0x789def')):
                    output = ('FAIL FLH: identity: ' + checkout + '/test/harness.lua:7: '
                              'expected nil, got table: ' + address + '\n'
                              'RESULT: 28 tests passed, 1 failed, 100 assertions\n')
                    proc = type('Process', (), {'returncode': 1, 'stdout': output, 'stderr': ''})()
                    with patch('subprocess.run', return_value=proc):
                        result, _ = runner['run'](Path(checkout), '/lua')
                    results.append(result)
                self.assertEqual(results[0], results[1])
                self.assertIn('test/harness.lua:7', results[0]['caught_by'][0])

    def test_hop_report_normalizes_runtime_identity_and_checkout_paths(self):
        runner = runpy.run_path(str(ROOT / 'test/hop_fanout_mutants.py'))
        results = []
        for checkout, address in (('/scratch/clone-a', '0x123abc'), ('/scratch/clone-b', '0x789def')):
            output = ('FAIL Hop fanout: identity: ' + checkout + '/test/harness.lua:7: '
                      'expected nil, got table: ' + address + '\n')
            proc = type('Process', (), {'returncode': 1, 'stdout': output, 'stderr': ''})()
            with patch('subprocess.run', return_value=proc), patch.dict(runner['run'].__globals__, LUA='/lua'):
                result = runner['run'](Path(checkout))
            results.append(result.stdout)
        self.assertEqual(results[0], results[1])
        self.assertIn('test/harness.lua:7', results[0])
        self.assertIn('table: <address>', results[0])

    def test_report_writer_preserves_identical_evidence(self):
        for name in ('flh_mutants.py', 'flh_member_mutants.py', 'hop_fanout_mutants.py'):
            with self.subTest(runner=name), tempfile.TemporaryDirectory(dir=os.environ['TMPDIR']) as tmp:
                runner = runpy.run_path(str(ROOT / 'test' / name))
                self.assertTrue('write_report' in runner, 'missing stable report writer')
                path = Path(tmp) / 'report.json'
                runner['write_report'](path, {'baseline': {'rc': 0}, 'mutants': []})
                # A fast rewrite can share one filesystem timestamp tick. Pin an
                # old mtime so a write is observable without sleeps or timing luck.
                os.utime(path, ns=(1_000_000_000, 1_000_000_000))
                before = path.read_bytes(), path.stat().st_mtime_ns
                runner['write_report'](path, {'mutants': [], 'baseline': {'rc': 0}})
                self.assertEqual((path.read_bytes(), path.stat().st_mtime_ns), before)


if __name__ == '__main__':
    unittest.main()
