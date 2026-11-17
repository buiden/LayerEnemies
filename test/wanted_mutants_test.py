"""Regression for stable Wanted mutation evidence; no real mutant execution."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock

SPEC = importlib.util.spec_from_file_location('wanted_mutants', Path(__file__).with_name('wanted_mutants.py'))
assert SPEC is not None and SPEC.loader is not None
mutants = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(mutants)


class EvidenceTest(unittest.TestCase):
    def test_repeated_mutants_ignore_lua_addresses_and_do_not_rewrite(self):
        with tempfile.TemporaryDirectory(dir='/opt/data/cache/scratch', prefix='wanted-evidence-test-') as tmp:
            root = Path(tmp)
            for folder in ('LayerEnemies', 'test', 'notes'):
                (root / folder).mkdir()
            (root / 'LayerEnemies/Wanted.lua').write_text('local a=1\n')
            evidence = root / 'notes/wanted-mutants.json'
            def run(address):
                failure = f'FAIL Wanted: example: expected nil, got table: 0x{address}\nRESULT: 0 tests passed, 1 failed, 1 assertions\n'
                results = [subprocess.CompletedProcess([], 0, '', ''), subprocess.CompletedProcess([], 1, failure, '')]
                with mock.patch.object(mutants, 'ROOT', root), mock.patch.object(mutants, 'MUTANTS', [('rule', 'Wanted.lua', 'a=1', 'a=2')]), \
                        mock.patch.object(mutants.subprocess, 'run', side_effect=results), mock.patch('builtins.print'):
                    with self.assertRaises(SystemExit) as exit:
                        mutants.main()
                    self.assertEqual(exit.exception.code, 0)
            run('123abc')
            first, stamp = evidence.read_bytes(), evidence.stat().st_mtime_ns
            run('987def')
            self.assertEqual(evidence.read_bytes(), first, 'Lua addresses must not change evidence')
            self.assertEqual(evidence.stat().st_mtime_ns, stamp, 'unchanged evidence must not be rewritten')
            self.assertNotIn(b'0x123abc', first)
            self.assertIn(b'table: <address>', first)


if __name__ == '__main__':
    unittest.main()
