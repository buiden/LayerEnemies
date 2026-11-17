"""Real source/presence mutant reruns must preserve evidence bytes and mtime."""
from contextlib import redirect_stdout
import importlib.util
from io import StringIO
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]


def load_runner(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'test' / (name + '.py'))
    assert spec is not None and spec.loader is not None
    runner = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(runner)
    return runner


class StableEvidenceTest(unittest.TestCase):
    def check_rerun(self, name, rule, count):
        runner = load_runner(name + '_mutants')
        with tempfile.TemporaryDirectory(prefix=name + '-evidence-test-') as tmp:
            root = Path(tmp)
            for folder in ('LayerEnemies', 'test'):
                shutil.copytree(ROOT / folder, root / folder)
            (root / 'notes').mkdir()
            rules = [row for row in runner.MUTANTS if row[0] == rule]
            self.assertEqual(len(rules), 1)
            evidence = root / 'notes' / (name + '-mutants.json')

            def run():
                with mock.patch.object(runner, 'ROOT', root), mock.patch.object(runner, 'MUTANTS', rules), \
                        mock.patch.object(sys, 'argv', [name + '_mutants.py']), redirect_stdout(StringIO()):
                    runner.main()
                payload = json.loads(evidence.read_text())
                rows = payload if isinstance(payload, list) else payload['mutants']
                self.assertEqual(len(rows), count)
                self.assertTrue(all(row.get('killed', row.get('caught')) for row in rows))
                failures = [line for row in rows for line in row.get('failures', [])]
                self.assertTrue(any('expected nil, got table:' in line for line in failures),
                                'exercise real Lua object-address failure evidence')
                return evidence.read_bytes(), evidence.stat().st_mtime_ns

            first, stamp = run()
            second, later = run()
            self.assertTrue(second == first, 'actual mutant evidence must be byte-stable')
            self.assertTrue(later == stamp, 'unchanged evidence must not be rewritten')
            # Use exactly WarBoard's normalization, without losing diagnostic details.
            sample = 'FAIL probe: File "/scratch/random/test/example_test.py", line 12: expected nil, got table: 0xBEEF'
            expected = 'FAIL probe: File "test/example_test.py", line 12: expected nil, got table: <address>'
            self.assertEqual(runner.stable_failure(sample), expected)
            for kind in ('table', 'function', 'thread', 'userdata'):
                self.assertEqual(runner.stable_failure(kind + ': 0x123abc'), kind + ': <address>')

    def test_source_rerun_is_byte_and_mtime_stable(self):
        # The source runner also executes its two unchanged harness mutants.
        self.check_rerun('source', 'peer online', 3)

    def test_presence_rerun_is_byte_and_mtime_stable(self):
        self.check_rerun('presence', 'R1 accept non WoW game account', 1)


if __name__ == '__main__':
    unittest.main()
