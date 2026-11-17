"""Run the presence mutant CLI from a relocated checkout and unrelated cwd."""
from pathlib import Path
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class PresenceMutantPortability(unittest.TestCase):
    def test_relocated_clone_with_relative_tmpdir(self):
        lua = Path(os.environ.get("LAYERENEMIES_LUA", "/opt/data/tools/lua/lua-5.1.5/src/lua")).resolve()
        with tempfile.TemporaryDirectory(prefix="presence-cli-") as directory:
            work = Path(directory)
            clone = work / "arbitrary-checkout"
            for folder in ("LayerEnemies", "test"):
                shutil.copytree(ROOT / folder, clone / folder)
            cwd = work / "unrelated-cwd"
            cwd.mkdir()
            (cwd / "scratch").mkdir()
            output = work / "mutants.json"
            env = dict(os.environ, TMPDIR="scratch")
            # Portability is a runner contract, not a second full mutation gate.
            # Execute its real CLI entrypoint with one real mutation; the separate
            # full-suite command still checks every rule with unchanged limits.
            entrypoint = (
                "import importlib.util, sys; "
                "spec=importlib.util.spec_from_file_location('presence_mutants',sys.argv.pop(1)); "
                "runner=importlib.util.module_from_spec(spec); spec.loader.exec_module(runner); "
                "runner.MUTANTS=runner.MUTANTS[:1]; runner.main()"
            )
            result = subprocess.run(
                [sys.executable, "-c", entrypoint, str(clone / "test/presence_mutants.py"),
                 "--lua", str(lua), "--output", str(output)],
                cwd=cwd, env=env, capture_output=True, text=True, timeout=180,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            report = json.loads(output.read_text())
            self.assertGreater(report["total"], 0)
            self.assertEqual(report["total"], 1, "exactly the selected real mutant ran")
            self.assertEqual(report["caught"], report["total"])
            self.assertIn("0 failed", report["baseline"])
            self.assertIn("0 failed", report["final"])
            self.assertEqual(list((cwd / "scratch").iterdir()), [], "temporary copies cleaned")


if __name__ == "__main__":
    unittest.main()
