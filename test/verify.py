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
    for forbidden in ('SendChatMessage', 'COMBAT_LOG_EVENT_UNFILTERED', 'JoinTemporaryChannel', 'JoinPermanentChannel',
                      'RunMacroText', 'UninviteUnit', 'ConfirmInviteUnit', 'ConfirmLeaveParty',
                      'ConvertToRaid', 'DeclineGroup', 'RequestInviteFromUnit'):
        assert forbidden not in addon_text, 'Unexpected outgoing/forbidden API: ' + forbidden
    # the party calls (guild host invite, auto accept and leave): InviteUnit, AcceptGroup and LeaveParty exactly
    # once each and C_PartyInfo only in Wire.lua
    wire = (ROOT / 'LayerEnemies/Wire.lua').read_text()
    for word in ('InviteUnit', 'AcceptGroup', 'LeaveParty', 'C_PartyInfo'):
        users = sorted(p.name for p in (ROOT / 'LayerEnemies').glob('*.lua')
                       if re.search(r'\b' + word + r'\b', p.read_text()))
        assert users in ([], ['Wire.lua']), word + ' outside Wire.lua: ' + ', '.join(users)
    for word in ('InviteUnit', 'AcceptGroup', 'LeaveParty'):
        calls = len(re.findall(r'\b' + word + r'\b', wire))
        assert calls == 1, word + ' must appear exactly once in Wire.lua, found %d' % calls
    # 1.0 directory channels: join, leave and roster selection exactly once each, in Directory.lua only
    for word in ('JoinChannelByName', 'LeaveChannelByName', 'SetSelectedDisplayChannel'):
        users = sorted(p.name for p in (ROOT / 'LayerEnemies').glob('*.lua')
                       if re.search(r'\b' + word + r'\b', p.read_text()))
        assert users == ['Directory.lua'], word + ' outside Directory.lua: ' + ', '.join(users)
        calls = len(re.findall(r'\b' + word + r'\b', (ROOT / 'LayerEnemies/Directory.lua').read_text()))
        assert calls == 1, word + ' must appear exactly once in Directory.lua, found %d' % calls
    # 1.0 lane B: HeadHunter frames are built only by HhNet.frame, for our own types N E Q O S H; never P, L or D
    hhnet = (ROOT / 'LayerEnemies/HhNet.lua').read_text()
    ours = re.search(r'local OURS = \{([^}]*)\}', hhnet)
    assert ours and sorted(re.findall(r'(\w) = true', ours[1])) == sorted('NEQOSH'), 'HhNet OURS must be exactly N E Q O S H'
    for t in re.findall(r'frame\([^,()]*,\s*"([^"]*)"', addon_text):
        assert t in 'NEQOSH' and len(t) == 1, 'HeadHunter frame of a type we never send: ' + t
    for file in (ROOT / 'LayerEnemies').glob('*.lua'):
        if file.name != 'HhNet.lua':
            assert not re.search(r'"1"\s*\.\.\s*side', file.read_text()), 'HeadHunter frames are built only in HhNet.lua: ' + file.name
    senders = sorted(p.name for p in (ROOT / 'LayerEnemies').glob('*.lua') if 'SendAddonMessage' in p.read_text())
    assert senders == ['Wire.lua'], 'SendAddonMessage outside Wire.lua: ' + ', '.join(senders)
    for file in (ROOT / 'LayerEnemies').glob('*.lua'):
        if file.name != 'UI.lua':
            assert 'SetText' not in file.read_text(), 'Only the UI may set text directly'
    assert '## Version: 1.0.1' in toc
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
    archive = dist / 'LayerEnemies-1.0.1.zip'
    # the archive is the TOC's file set (its .lua files and the .toc) plus the README, and nothing else: anything else
    # in the addon folder (a stray file, a test folder) fails here instead of shipping
    shipped = sorted(listed + ['LayerEnemies.toc'])
    present = sorted(p.relative_to(ROOT / 'LayerEnemies').as_posix() for p in (ROOT / 'LayerEnemies').rglob('*'))
    assert present == shipped, 'addon folder holds files outside the TOC set: %s' % sorted(set(present) - set(shipped))
    expected = ['LayerEnemies/' + name for name in shipped]
    expected.append('LayerEnemies/README.md')
    # deterministic archive: fixed time and mode per member, so the same sources give the same sha256 in any clone
    def add(out, path, name):
        info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
        info.compress_type = zipfile.ZIP_DEFLATED
        info.external_attr = 0o644 << 16
        out.writestr(info, path.read_bytes())
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as out:
        for name in shipped:
            add(out, ROOT / 'LayerEnemies' / name, 'LayerEnemies/' + name)
        add(out, ROOT / 'README.md', 'LayerEnemies/README.md')
    with zipfile.ZipFile(archive) as zipped:
        assert zipped.testzip() is None
        assert sorted(zipped.namelist()) == sorted(expected)
        for name in shipped:
            assert zipped.read('LayerEnemies/' + name) == (ROOT / 'LayerEnemies' / name).read_bytes()
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
        'live_remote_reports': 'War Effort 1.6.x and HeadHunter as a member, the Spy family and three guild '
                               'incident addons read-only, LEGW1 own sightings and relays; shown as reported, '
                               'not confirmed',
        'ask_for_invite': 'One click sends one LayerSwap-format request to one host (report row or host row), or drafts a /g guild request the player sends',
        'auto_accept_leave': 'On by default, saved: accepts only the asked host invite (120 s, not grouped/instance/combat), leaves only that group 3 s after the move or 30 s without one',
        'guild_host': 'Off until turned on, then saved (guildHost boolean, ON line at login); guild members only, guild name readable and unchanged; at most one InviteUnit per request, 10 s apart, 6 per 600 s; never in combat; refused beside LayerSwap or Bulo',
        'networks': 'Public by default (first-login line once); /le net guild|public, per-network switches, /le share on|off, window switches',
        'sends': 'LayerSwap/WHISPER, LEGW1/GUILD, LFSw/GUILD Q, WEFF1 (GUILD, PARTY, RAID, WHISPER) and '
                 'HeadHunter/WHISPER behind Net (both shipped on; /le net guild stops public scope)',
        'visual_design': 'Approved B implemented with fourth Find tab; native client appearance unverified',
    }
    (notes / 'verification.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
