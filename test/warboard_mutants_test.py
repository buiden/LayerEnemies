"""Actual mutation runs must leave committed evidence byte- and mtime-stable."""
from contextlib import redirect_stdout
import importlib.util
from io import StringIO
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('warboard_mutants', ROOT / 'test/warboard_mutants.py')
assert SPEC is not None and SPEC.loader is not None
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)


class StableEvidenceTest(unittest.TestCase):
    def test_real_portability_mutant_rerun_is_byte_and_mtime_stable(self):
        with tempfile.TemporaryDirectory(prefix='warboard-evidence-test-') as tmp:
            root = Path(tmp)
            for folder in ('LayerEnemies', 'test'):
                shutil.copytree(ROOT / folder, root / folder)
            shutil.copyfile(ROOT / 'README.md', root / 'README.md')
            (root / 'notes').mkdir()
            rules = [row for row in runner.MUTANTS if row[0] == 'mutant runner does not require owner scratch path']
            self.assertEqual(len(rules), 1)
            evidence = root / 'notes/warboard-mutants.json'
            def run():
                with mock.patch.object(runner, 'ROOT', root), mock.patch.object(runner, 'MUTANTS', rules), redirect_stdout(StringIO()):
                    with self.assertRaises(SystemExit) as result:
                        runner.main()
                    self.assertEqual(result.exception.code, 0)
                rows = json.loads(evidence.read_text())
                self.assertEqual(len(rows), 1)
                self.assertTrue(rows[0]['killed'])
                self.assertIn('expected ', rows[0]['failures'][0])
                self.assertIn('Traceback', rows[0]['failures'][0])
                return evidence.read_bytes(), evidence.stat().st_mtime_ns
            first, stamp = run()
            second, later = run()
            self.assertEqual(second, first, 'random scratch paths must not change actual failure evidence')
            self.assertEqual(later, stamp, 'unchanged evidence must not be rewritten')


if __name__ == '__main__':
    unittest.main()
