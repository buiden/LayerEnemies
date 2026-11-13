"""Local-only validation and packaging; run from the project root."""
from pathlib import Path
import hashlib
import json
import os
import re
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
LUA = Path(os.environ.get('LAYERENEMIES_LUA', '/opt/data/tools/lua/lua-5.1.5/src/lua'))
LUAC = LUA.with_name('luac')


def main():
    notes = ROOT / 'notes'
    notes.mkdir(exist_ok=True)
    files = sorted(ROOT.rglob('*.lua'))
    for file in files:
        subprocess.run([str(LUAC), '-p', str(file)], cwd=ROOT, check=True)
    toc = (ROOT / 'LayerEnemies/LayerEnemies.toc').read_text()
    listed = [line for line in toc.splitlines() if line.endswith('.lua')]
    actual = sorted(p.name for p in (ROOT / 'LayerEnemies').glob('*.lua'))
    assert sorted(listed) == actual, 'TOC does not match addon source files'
    assert '## Interface: 16001' in toc
    assert '## SavedVariablesPerCharacter: LayerEnemiesDB' in toc
    addon_text = '\n'.join(p.read_text() for p in (ROOT / 'LayerEnemies').glob('*.lua'))
    for forbidden in ('JoinChannelByName', 'SendChatMessage', 'COMBAT_LOG_EVENT_UNFILTERED',
                      'InviteUnit', 'LeaveParty', 'AcceptGroup', 'C_PartyInfo', 'RunMacroText'):
        assert forbidden not in addon_text, 'Unexpected outgoing/forbidden API: ' + forbidden
    senders = sorted(p.name for p in (ROOT / 'LayerEnemies').glob('*.lua') if 'SendAddonMessage' in p.read_text())
    assert senders == ['Wire.lua'], 'SendAddonMessage outside Wire.lua: ' + ', '.join(senders)
    for file in (ROOT / 'LayerEnemies').glob('*.lua'):
        if file.name != 'UI.lua':
            assert 'SetText' not in file.read_text(), 'Only the UI may set text directly'
    assert '## Version: 0.3.0' in toc
    assert 'OnUpdate' not in addon_text, 'Unexpected OnUpdate script'
    tests = subprocess.run([str(LUA), 'test/harness.lua'], cwd=ROOT, capture_output=True, text=True)
    (notes / 'test-results.txt').write_text(tests.stdout + tests.stderr)
    print(tests.stdout, end='')
    tests.check_returncode()
    counts = re.search(r'RESULT: (\d+) tests passed, (\d+) failed, (\d+) assertions', tests.stdout)
    assert counts and int(counts[2]) == 0
    assert int(counts[1]) > 0, 'the harness ran no tests'
    subprocess.run(['git', 'diff', '--check'], cwd=ROOT, check=True)
    dist = ROOT / 'dist'
    dist.mkdir(exist_ok=True)
    archive = dist / 'LayerEnemies-0.3.0.zip'
    expected = ['LayerEnemies/' + p.name for p in sorted((ROOT / 'LayerEnemies').iterdir()) if p.is_file()]
    expected.append('LayerEnemies/README.md')
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as out:
        for file in sorted((ROOT / 'LayerEnemies').iterdir()):
            if file.is_file():
                out.write(file, 'LayerEnemies/' + file.name)
        out.write(ROOT / 'README.md', 'LayerEnemies/README.md')
    with zipfile.ZipFile(archive) as zipped:
        assert zipped.testzip() is None
        assert sorted(zipped.namelist()) == sorted(expected)
        for file in (ROOT / 'LayerEnemies').iterdir():
            if file.is_file():
                assert zipped.read('LayerEnemies/' + file.name) == file.read_bytes()
        assert zipped.read('LayerEnemies/README.md') == (ROOT / 'README.md').read_bytes()
    result = {
        'lua_version': subprocess.run([str(LUA), '-v'], capture_output=True, text=True, check=True).stderr.strip(),
        'syntax_files': len(files),
        'syntax_status': 'PASS',
        'tests_passed': int(counts[1]),
        'tests_failed': int(counts[2]),
        'assertions': int(counts[3]),
        'fuzz_inputs': 5000,
        'toc_and_static_checks': 'PASS',
        'archive_integrity_and_source_parity': 'PASS',
        'archive': archive.relative_to(ROOT).as_posix(),
        'archive_members': len(expected),
        'archive_sha256': hashlib.sha256(archive.read_bytes()).hexdigest(),
        'real_client_verified': False,
        'live_remote_reports': 'War Effort 1.6.x and HeadHunter read-only, plus LEGW1 guild relays; dated by '
                               'time of receipt; shown as reported, not confirmed',
        'ask_for_invite': 'One click sends one LayerSwap-format request to one host; never invites, accepts or leaves',
        'sends': 'LayerSwap/WHISPER hop request and LEGW1/GUILD relay only',
        'visual_design': 'Approved B implemented with fourth Find tab; native client appearance unverified',
    }
    (notes / 'verification.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
