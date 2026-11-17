"""Exercise the real runner from a relocated checkout and unrelated cwd/TMPDIR."""
from contextlib import redirect_stdout
from importlib.util import module_from_spec, spec_from_file_location
from io import StringIO
from pathlib import Path
import json
import os
import shutil
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    with tempfile.TemporaryDirectory(prefix='warboard-portable-') as temporary:
        root = Path(temporary)
        clone = root / 'different checkout'
        clone.mkdir()
        for folder in ('LayerEnemies', 'test'):
            shutil.copytree(ROOT / folder, clone / folder)
        shutil.copyfile(ROOT / 'README.md', clone / 'README.md')
        (clone / 'notes').mkdir()
        elsewhere = root / 'elsewhere'
        elsewhere.mkdir()
        (elsewhere / 'relative-scratch').mkdir()
        spec = spec_from_file_location('relocated_mutants', clone / 'test/warboard_mutants.py')
        assert spec is not None and spec.loader is not None
        runner = module_from_spec(spec)
        spec.loader.exec_module(runner)
        assert runner.ROOT == clone
        # A real rule kill, not a stubbed subprocess or empty mutant inventory.
        setattr(runner, 'MUTANTS', runner.MUTANTS[:1])
        cwd, old_tmpdir, old_cache = Path.cwd(), os.environ.get('TMPDIR'), tempfile.tempdir
        output = StringIO()
        try:
            os.chdir(elsewhere)
            os.environ['TMPDIR'] = 'relative-scratch'
            tempfile.tempdir = None
            with redirect_stdout(output):
                try:
                    runner.main()
                except SystemExit as result:
                    assert result.code == 0, output.getvalue()
        finally:
            os.chdir(cwd)
            if old_tmpdir is None:
                os.environ.pop('TMPDIR', None)
            else:
                os.environ['TMPDIR'] = old_tmpdir
            tempfile.tempdir = old_cache
        result = json.loads((clone / 'notes/warboard-mutants.json').read_text())
        assert len(result) == 1 and result[0]['killed'], result
        assert 'RESULT: 1/1 WarBoard mutants killed' in output.getvalue(), output.getvalue()
        assert not list((elsewhere / 'relative-scratch').iterdir()), 'scratch copy not cleaned'
    print('PASS portable WarBoard mutant runner: relocated checkout, cwd and TMPDIR')


if __name__ == '__main__':
    main()
