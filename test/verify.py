"""Local-only validation and packaging; run from the project root."""
from pathlib import Path
import hashlib
import json
import os
import re
import subprocess
import struct
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
LUA = Path(os.environ.get('LAYERENEMIES_LUA', '/opt/data/tools/lua/lua-5.1.5/src/lua'))
LUAC = LUA.with_name('luac')
# Exactly three headings, three labels and three buttons, with per-file dimensions.
MEDIA = {
    'Media/call-h1.tga': (256, 64), 'Media/call-h2.tga': (256, 64), 'Media/call-h6.tga': (256, 64),
    'Media/call-victim.tga': (128, 32), 'Media/call-killer.tga': (128, 32), 'Media/call-where.tga': (128, 32),
    'Media/call-help.tga': (128, 32), 'Media/call-dismiss-a.tga': (128, 32), 'Media/call-dismiss-b.tga': (128, 32),
}


def payload_files(listed, addon=None):
    addon = addon or ROOT / 'LayerEnemies'
    shipped = sorted(listed + ['LayerEnemies.toc'] + list(MEDIA))
    paths = list(addon.rglob('*'))
    assert not any(p.is_symlink() for p in paths), 'addon folder holds a symlink'
    present = sorted(p.relative_to(addon).as_posix() for p in paths)
    assert present == sorted(shipped + ['Media']), 'addon folder holds files outside the TOC/Media set: %s' % sorted(set(present) ^ set(shipped + ['Media']))
    return shipped


def check_media(addon=None):
    addon = addon or ROOT / 'LayerEnemies'
    for name, (width, height) in MEDIA.items():
        expected_header = struct.pack('<BBBHHBHHHHBB', 0, 0, 2, 0, 0, 0, 0, 0, width, height, 32, 0x08)
        raw = (addon / name).read_bytes()
        assert len(raw) == 18 + width * height * 4 + 26, 'TGA size: ' + name
        assert raw[:18] == expected_header, 'TGA header: ' + name
        assert raw[-26:] == struct.pack('<II', 0, 0) + b'TRUEVISION-XFILE.\0', 'TGA footer: ' + name
        # Verify transparent padding and nonempty ink without an image-library dependency.
        alpha = raw[21:-26:4]
        ink = [(i % width, i // width) for i, a in enumerate(alpha) if a]
        assert ink and all(4 <= x < width - 4 and 4 <= y < height - 4 for x, y in ink), 'TGA padding: ' + name
        assert max(x for x, _ in ink) - min(x for x, _ in ink) + 1 <= (190 if width == 256 else 120), 'TGA ink width: ' + name


def check_call_text(addon=None):
    addon = addon or ROOT / 'LayerEnemies'
    for path in addon.glob('Call*.lua'):
        text = path.read_text()
        assert all(ord(c) <= 0x024F for c in text), 'non-Latin client source: ' + path.name
    text = (addon / 'CallText.lua').read_text()
    art = re.findall(r'art="([^"]+)"', text)
    sep = chr(92) * 2  # Lua source spells a literal backslash twice.
    prefix = sep.join(('Interface', 'AddOns', 'LayerEnemies')) + sep
    expected = [prefix + name.replace('/', sep) for name in MEDIA]
    assert sorted(art) == sorted(expected), 'CallText art must match the exact Media allowlist'
    assert text.count('.tga') == len(MEDIA), 'Unexpected CallText art path'



def lua_references(tokens):
    """Identifier/member references, with constant index expressions folded.

    Data strings and comments are inert, including strings containing API names.
    Dynamic keys on the API namespaces are refused separately, not evaluated.
    """
    for i, (kind, value) in enumerate(tokens):
        if kind == 'name':
            yield i, value
        elif (kind, value) == ('symbol', '['):
            try:
                key, end = constant_key(tokens, i + 1)
            except AssertionError:
                continue
            if tokens[end:end + 1] == [('symbol', ']')]:
                yield i, key


# Tokenize source, not execution traces: even an unreachable branch must respect
# the API owners. Constant global keys are folded; dynamic environment access
# and escaping _G are refused rather than guessed. No addon code is executed.
LUA_TOKENS = re.compile(r'''(?P<space>\s+)|(?P<comment>--(?:\[(?P<ceq>=*)\[.*?\](?P=ceq)\]|[^\n]*))|(?P<long>\[(?P<eq>=*)\[.*?\](?P=eq)\])|(?P<string>"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')|(?P<name>[A-Za-z_][A-Za-z_0-9]*)|(?P<concat>\.\.)|(?P<symbol>.)''', re.S)
API_OWNERS = {word: 'Adapters.lua' for word in ('C_FriendList', 'SendWho', 'GetNumWhoResults', 'GetWhoInfo', 'SetWhoToUi', 'FriendsFrame', 'LFGWhoListFrame', 'WhoFrame')}
API_OWNERS.update({word: 'Wire.lua' for word in ('C_PartyInfo', 'InviteUnit', 'AcceptGroup', 'LeaveParty')})


def lua_tokens(source):
    tokens = []
    escapes = dict(zip('abfnrtv', '\a\b\f\n\r\t\v'))
    for match in LUA_TOKENS.finditer(source):
        kind, value = match.lastgroup, match[0]
        if kind in ('space', 'comment'):
            continue
        if kind == 'string':
            def unescape(m: re.Match[str]) -> str:
                char = m.group(1)
                assert char is not None
                return chr(int(char)) if char.isdigit() else escapes.get(char, char)
            value = re.sub(r'\\([0-9]{1,3}|.)', unescape, value[1:-1], flags=re.S)
        elif kind == 'long':
            width = len(match['eq']) + 2
            kind, value = 'string', value[width:-width]
            if value.startswith('\n'):
                value = value[1:]
        tokens.append((kind, value))
    return tokens


def constant_key(tokens, at):
    def atom(i):
        if i < len(tokens) and tokens[i][0] == 'string':
            return tokens[i][1], i + 1
        if i < len(tokens) and tokens[i][1] == '(':
            value, end = constant_key(tokens, i + 1)
            assert end < len(tokens) and tokens[end][1] == ')', 'dynamic global key'
            return value, end + 1
        raise AssertionError('dynamic global key')
    value, at = atom(at)
    while at < len(tokens) and tokens[at][0] == 'concat':
        suffix, at = atom(at + 1)
        value += suffix
    return value, at


def check_api_policy(source, filename):
    def owner(word):
        expected = API_OWNERS.get(word)
        assert expected is None or filename == expected, word + ' outside ' + str(expected) + ': ' + filename
    tokens = lua_tokens(source)
    for i, (kind, value) in enumerate(tokens):
        if kind != 'name':
            continue
        owner(value)
        assert value not in ('getfenv', 'setfenv', 'rawget'), 'dynamic global access: ' + filename
        if value != '_G':
            continue
        following = tokens[i + 1:i + 3]
        if len(following) == 2 and following[0][1] == '.' and following[1][0] == 'name':
            owner(following[1][1])
        elif following and following[0][1] == '[':
            key, end = constant_key(tokens, i + 2)
            assert end < len(tokens) and tokens[end][1] == ']', 'dynamic global key: ' + filename
            owner(key)
        else:
            raise AssertionError('global environment alias: ' + filename)


def check_chat_namespace(tokens, filename):
    """Keep chat/global namespace access statically inspectable, including aliases.

    Permit direct local aliases and the existing type/secret/table inspections;
    reject passing/storing/returning the namespace or indexing it dynamically.
    Alias names are conservatively reserved throughout the file (no flow guesses).
    """
    aliases = {'C_ChatInfo': 'chat', '_G': 'global'}

    def access(at):
        role, end = aliases.get(tokens[at][1]), at + 1
        while role and end < len(tokens):
            if tokens[end] == ('symbol', '.') and tokens[end + 1][0] == 'name':
                key, end = tokens[end + 1][1], end + 2
            elif tokens[end] == ('symbol', '['):
                key, end = constant_key(tokens, end + 1)
                assert tokens[end:end + 1] == [('symbol', ']')], 'dynamic API key: ' + filename
                end += 1
            else:
                break
            role = aliases.get(key) if role == 'global' and key in ('_G', 'C_ChatInfo') else None
        return role, end

    # Only simple local bindings may carry a namespace. Iterate for alias chains.
    bindings = set()
    while True:
        before = len(bindings)
        for i in range(3, len(tokens)):
            if (tokens[i][0] == 'name' and tokens[i][1] in aliases and
                    tokens[i - 3] == ('name', 'local') and tokens[i - 2][0] == 'name' and
                    tokens[i - 1] == ('symbol', '=')):
                role, _ = access(i)
                if role == 'chat':
                    aliases[tokens[i - 2][1]] = role
                    bindings.add(i)
        if len(bindings) == before:
            break

    declarations = {i - 2 for i in bindings}
    i = 0
    while i < len(tokens):
        if tokens[i][0] != 'name' or tokens[i][1] not in aliases or i in declarations:
            i += 1
            continue
        role, end = access(i)
        if role == 'global':
            raise AssertionError('global environment alias: ' + filename)
        if role == 'chat' and i not in bindings:
            inspection = (tokens[i - 2:i] == [('name', 'type'), ('symbol', '(')] or
                          tokens[i - 4:i] in ([('name', 'S'), ('symbol', '.'), ('name', 'tab'), ('symbol', '(')],
                                              [('name', 'S'), ('symbol', '.'), ('name', 'secret'), ('symbol', '(')]))
            assert inspection and tokens[end:end + 1] == [('symbol', ')')], 'chat namespace escapes: ' + filename
        i = end


def check_send_policy(source, filename):
    tokens = lua_tokens(source)
    send_sites = []
    for at, word in lua_references(tokens):
        forbidden = (word == 'SendGameData' and filename != 'BNet.lua') or word == 'SendChatMessage' or re.fullmatch(r'BN\w*Send\w*', word)
        if word == 'SendGameData' and filename == 'BNet.lua':
            send_sites.append(at)
        assert not forbidden, 'Unexpected outgoing/forbidden API: ' + word + ' in ' + filename
        if word == 'SendAddonMessage':
            assert filename == 'Wire.lua', 'SendAddonMessage outside Wire.lua: ' + filename
            send_sites.append(at)
    check_chat_namespace(tokens, filename)
    if filename in ('Wire.lua', 'BNet.lua'):
        api = 'SendAddonMessage' if filename == 'Wire.lua' else 'SendGameData'
        assert len(send_sites) == 1, filename + ' must have exactly one ' + api + ' access'
        # Lua block keywords (not textual lines) locate the top-level deliver body.
        # for/while blocks are opened by their do; elseif does not open a block.
        blocks, deliveries = [], []
        for i, (kind, word) in enumerate(tokens):
            if kind != 'name':
                continue
            if word in ('function', 'if', 'do', 'repeat'):
                deliver = (not blocks and word == 'function' and
                           tokens[i - 1:i + 2] == [('name', 'local'), ('name', 'function'), ('name', 'deliver')])
                blocks.append((i, deliver))
            elif word in ('end', 'until'):
                start, deliver = blocks.pop()
                if deliver:
                    deliveries.append((start, i))
        assert len(deliveries) == 1 and deliveries[0][0] < send_sites[0] < deliveries[0][1], \
            api + ' must belong to the single local deliver function in ' + filename


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
    for file in (ROOT / 'LayerEnemies').glob('*.lua'):
        check_api_policy(file.read_text(), file.name)
    for forbidden in ('COMBAT_LOG_EVENT_UNFILTERED', 'JoinTemporaryChannel', 'JoinPermanentChannel',
                      'RunMacroText', 'UninviteUnit', 'ConfirmInviteUnit', 'ConfirmLeaveParty',
                      'ConvertToRaid', 'DeclineGroup', 'RequestInviteFromUnit'):
        assert forbidden not in addon_text, 'Unexpected outgoing/forbidden API: ' + forbidden
    # Inspect even dormant code: only Wire's one addon-send access is permitted.
    for file in (ROOT / 'LayerEnemies').glob('*.lua'):
        check_send_policy(file.read_text(), file.name)
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
    # Who APIs belong to the adapter only; runtime caller/stack tests additionally catch disguised calls.
    for word in ('SendWho', 'GetNumWhoResults', 'GetWhoInfo'):
        users = sorted(p.name for p in (ROOT / 'LayerEnemies').glob('*.lua')
                       if re.search(r'\b' + word + r'\b', p.read_text()))
        assert users == ['Adapters.lua'], word + ' outside Adapters.lua: ' + ', '.join(users)
    # Approved WHO suppression belongs only to the adapter, with no new send authority.
    for word in ('SetWhoToUi', 'FriendsFrame', 'LFGWhoListFrame', 'WhoFrame'):
        users = sorted(p.name for p in (ROOT / 'LayerEnemies').glob('*.lua')
                       if re.search(r'\b' + word + r'\b', p.read_text()))
        assert users == ['Adapters.lua'], word + ' outside Adapters.lua'
    # 1.0 lane B: HeadHunter frames are built only by HhNet.frame, for our own types N E Q O S H; never P, L or D
    hhnet = (ROOT / 'LayerEnemies/HhNet.lua').read_text()
    ours = re.search(r'local OURS = \{([^}]*)\}', hhnet)
    assert ours and sorted(re.findall(r'(\w) = true', ours[1])) == sorted('NEQOSH'), 'HhNet OURS must be exactly N E Q O S H'
    for t in re.findall(r'frame\([^,()]*,\s*"([^"]*)"', addon_text):
        assert t in 'NEQOSH' and len(t) == 1, 'HeadHunter frame of a type we never send: ' + t
    for file in (ROOT / 'LayerEnemies').glob('*.lua'):
        if file.name != 'HhNet.lua':
            assert not re.search(r'"1"\s*\.\.\s*side', file.read_text()), 'HeadHunter frames are built only in HhNet.lua: ' + file.name
    # Only the K1 author is new. No new prefix, public scope, party call or direct client send site.
    death = (ROOT / 'LayerEnemies/OwnDeath.lua').read_text()
    assert death.count('N.Wire.send') == 1
    assert 'N.Wire.send("LEGW1",line,"GUILD",nil,{prio="own"})' in death, 'K1 may send only on LEGW1/GUILD'
    assert re.search(r'LEGW1 = \{ kinds = \{ GUILD = true \}', wire), 'LEGW1 route must stay GUILD-only'

    for file in (ROOT / 'LayerEnemies').glob('*.lua'):
        if file.name not in ('UI.lua', 'CallUI.lua'):
            assert 'SetText' not in file.read_text(), 'Only the UI may set text directly'
    assert '## Version: 1.1.0' in toc
    assert 'OnUpdate' not in addon_text, 'Unexpected OnUpdate script'
    subprocess.run([sys.executable, '-I', '-B', 'test/test_verify.py'], cwd=ROOT, check=True)
    subprocess.run([sys.executable, '-I', 'test/api_policy_test.py'], cwd=ROOT, check=True)
    subprocess.run([sys.executable, '-I', 'test/harness_sources_test.py'], cwd=ROOT, check=True)
    shipped = payload_files(listed)
    check_media()
    check_call_text()
    subprocess.run([sys.executable, '-I', '-B', 'test/call_assets_test.py'], cwd=ROOT, check=True)
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
    archive = dist / 'LayerEnemies-1.1.0.zip'
    # the archive is the TOC's files plus the exact MEDIA set and README; anything else
    # in the addon folder (a stray file, a test folder) fails here instead of shipping
    shipped = payload_files(listed)
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
        'archive_bytes': archive.stat().st_size,
        'unpacked_bytes': sum((ROOT / 'LayerEnemies' / name).stat().st_size for name in shipped) + (ROOT / 'README.md').stat().st_size,
        'media_bytes': sum((ROOT / 'LayerEnemies' / name).stat().st_size for name in MEDIA),
        'call_assets_tests': 11,
        'archive_sha256': hashlib.sha256(archive.read_bytes()).hexdigest(),
        'real_client_verified': False,
        'live_remote_reports': 'War Effort 1.6.x and HeadHunter as a member, the Spy family and three guild '
                               'incident addons read-only, LEGW1 own sightings and relays; shown as reported, '
                               'not confirmed',
        'ask_for_invite': 'Single-host hops remain one request; hop-any clicks query WHO once with UI suppressed, consider 49 rows, use at most 8 attempts/round at 1 s for 45 rounds, 10 s between clicks; retry throttled heads and re-ask unknown same-zone hosts once at +3/+10 s; guild requests stay player-sent',
        'auto_accept_leave': 'On by default, saved: accepts only the asked host invite (120 s, not grouped/instance/combat), leaves only that group 3 s after the move or 30 s without one',
        'guild_host': 'Off until turned on, then saved (guildHost boolean, ON line at login); guild members only, guild name readable and unchanged; at most one InviteUnit per request, 10 s apart, 6 per 600 s; never in combat; refused beside LayerSwap or Bulo',
        'networks': 'Public by default (first-login line once); /le net guild|public, per-network switches, /le share on|off, window switches',
        'sends': 'LayerSwap/WHISPER, LEGW1/GUILD (including K1 own-death, share switch, 1/120s and 5/30min), LFSw/GUILD Q, WEFF1 (GUILD, PARTY, RAID, WHISPER) and '
                 'HeadHunter/WHISPER behind Net (both shipped on; /le net guild stops public scope); '
                 'OverlordF NH to non-source peers, busy HA only for addressed HR V, and NH-free HR 8:V/8:K feed requests '
                 '(two isolated live Battle.net friends of either faction; first-hand same-pool evidence once per session; '
                 'strictly more than 300s after actual NH, no wait if never sent; unanswered gaps 200/400/800/1600/1800s; '
                 'valid HA/HB resets to 200s) plus one best-effort HR 8:X stop per opened subscription; '
                 'no feed suppression of guild/party presence; '
                 'no ranking capability claim; '
                 '(WHISPER/GUILD/PARTY/RAID and Battle.net as documented in README; no forwarding or CHANNEL sends)',
        'visual_design': 'Approved B implemented with fourth Find tab; native client appearance unverified',
    }
    (notes / 'verification.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
