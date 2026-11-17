"""Source ownership and TOC coverage regressions; planted sends stay dormant."""
import importlib.util
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('verify', Path(__file__).with_name('verify.py'))
verify = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(verify)


class StaticChecksComplete(Exception):
    pass


class SendGateTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='le-send-gate-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        shutil.copytree(verify.ROOT / 'LayerEnemies', self.root / 'LayerEnemies')

    def gate_error(self, source, filename='Main.lua', replace=None):
        target = self.root / 'LayerEnemies' / filename
        original = target.read_text()
        if replace is not None:
            self.assertEqual(original.count(replace), 1, 'fixture replacement must be unique')
            target.write_text(original.replace(replace, source))
        else:
            target.write_text(original + '\n' + source + '\n')
        run = subprocess.run

        def compile_or_stop(args, **kwargs):
            # Use the real compiler; stop before running suites or packaging this fixture.
            if args[0] == str(verify.LUAC):
                return run(args, **kwargs)
            raise StaticChecksComplete()

        try:
            with patch.object(verify, 'ROOT', self.root), patch.object(subprocess, 'run', compile_or_stop):
                try:
                    verify.main()
                except StaticChecksComplete:
                    return None
                except AssertionError as exc:
                    return str(exc)
            self.fail('source gate did not reach the suite boundary')
        finally:
            target.write_text(original)

    def test_battle_net_identifiers_are_forbidden_in_every_file(self):
        cases = (
            ('bare game data', 'SendGameData(...)'),
            ('modern game data', 'C_BattleNet.SendGameData(...)'),
            ('legacy game data', 'BNSendGameData(...)'),
            ('legacy whisper', 'BNSendWhisper(...)'),
            ('other BN send', 'BNChannelSendMessage(...)'),
            ('future BN send', 'BNFutureSendPacket(...)'),
            ('table alias', 'local b=C_BattleNet; b.SendGameData(...)'),
            ('function alias', 'local send=SendGameData; send(...)'),
            ('literal member', 'local b=C_BattleNet; b["SendGameData"](...)'),
            ('literal global', '_G["BNSendWhisper"](...)'),
            ('long literal key', '_G[ [=[BNSendGameData]=] ](...)'),
            ('escaped literal key', r'_G["BNSend\087hisper"](...)'),
        )
        for filename in ('Main.lua', 'Wire.lua'):
            for label, source in cases:
                with self.subTest(file=filename, case=label):
                    error = self.gate_error('if false then ' + source + ' end', filename)
                    self.assertIsNotNone(error, 'source gate accepted ' + label)
                    self.assertIn('Unexpected outgoing/forbidden API:', error)

    def test_reviewer_combined_alias_and_whisper_plant(self):
        source = 'local function never() local b=C_BattleNet; b.SendGameData(1,"OpenMapLoc","H1"); BNSendWhisper(1,"x") end'
        self.assertIsNotNone(self.gate_error(source), 'reviewer plant escaped source gate')

    def test_addon_sends_are_wire_only_and_chat_sends_stay_forbidden(self):
        for source in ('SendAddonMessage(...)', 'C_ChatInfo.SendAddonMessage(...)',
                       'local c=C_ChatInfo; c.SendAddonMessage(...)',
                       'C_ChatInfo["SendAddonMessage"](...)',
                       '_G["SendChatMessage"](...)',
                       'local send=SendAddonMessage; send(...)', 'SendChatMessage(...)',
                       'local c=C_ChatInfo; c.SendChatMessage(...)'):
            with self.subTest(source=source):
                self.assertIsNotNone(self.gate_error('if false then ' + source + ' end'))
        # Wire owns one existing access in deliver, not an unrestricted send exemption.
        self.assertIsNotNone(self.gate_error('if false then C_ChatInfo.SendAddonMessage(...) end', 'Wire.lua'))
        self.assertIsNone(self.gate_error('-- SendAddonMessage is owned by deliver', 'Wire.lua'))
        self.assertIsNotNone(self.gate_error('if false then SendChatMessage(...) end', 'Wire.lua'))

    def test_indirect_addon_sends_fail_closed(self):
        cases = (
            'C_ChatInfo["Send".."AddonMessage"](...)',
            '_G["Send".."AddonMessage"](...)',
            '_G[("Se".."nd")..("Addon".."Message")](...)',
            'local k="SendAddonMessage"; C_ChatInfo[k](...)',
            'local k="Se".."nd".."AddonMessage"; C_ChatInfo[k](...)',
            'C_ChatInfo[k](...)',
            '_G["C_".."ChatInfo"][k](...)',
            'local c=C_ChatInfo; local d=c; d[k](...)',
            'local c=_G.C_ChatInfo; c[k](...)',
            'local c=_G["C_".."ChatInfo"]; c[k](...)',
            'local c=C_ChatInfo; local k="Send".."AddonMessage"; c[k](...)',
            'local box={C_ChatInfo}; box[1][k](...)',
            'local function send(c, ...) c[k](...) end; send(C_ChatInfo)',
            'local f=C_ChatInfo.SendAddonMessage',
        )
        for source in cases:
            with self.subTest(source=source):
                self.assertIsNotNone(self.gate_error('if false then ' + source + ' end'))

    def test_hidden_chat_sends_are_forbidden_even_in_wire(self):
        cases = (
            'local k="Send".."ChatMessage"; C_ChatInfo[k](...)',
            '_G["Send".."ChatMessage"](...)',
            '_G[("Se".."nd")..("Chat".."Message")](...)',
            'C_ChatInfo["Send".."ChatMessage"](...)',
            r'C_ChatInfo["\083end".."ChatMessage"](...)',
            'C_ChatInfo[ [=[Send]=] .. [=[ChatMessage]=] ](...)',
            'local c=C_ChatInfo; local k="SendChatMessage"; c[k](...)',
            'local f=C_ChatInfo.SendChatMessage; f(...)',
            'local f=SendChatMessage; f(...)',
            'local c=C_ChatInfo; local d=c; d[k](...)',
            '_G["C_".."ChatInfo"]["Send".."ChatMessage"](...)',
            '_G["_G"]["Send".."ChatMessage"](...)',
        )
        for filename in ('Main.lua', 'Wire.lua'):
            for source in cases:
                with self.subTest(file=filename, source=source):
                    self.assertIsNotNone(self.gate_error('if false then ' + source + ' end', filename))

    def test_chat_presence_predicate_prefixes_are_rejected(self):
        # Exact reviewer forms: '..' and '+' deliver the function to a metamethod
        # before the nil comparison. Even non-working/dead variants stay forbidden.
        metatable = ('setmetatable({}, {__concat=function(_, f) return f("x","WHISPER",nil,"Bob") end, '
                     '__lt=function(_, f) return f("x","WHISPER",nil,"Bob") end, '
                     '__add=function(_, f) return f("x","WHISPER",nil,"Bob") end, '
                     '__eq=function() return true end, '
                     '__index=function(_, k) return function(f) return f end end})')
        cases = (
            ('concat metamethod', 'local r = o .. C_ChatInfo.SendChatMessage == nil'),
            ('lt metamethod', 'local r = o < C_ChatInfo.SendChatMessage == nil'),
            ('add metamethod', 'local r = o + C_ChatInfo.SendChatMessage == nil'),
            ('legacy concat', 'local r = o .. _G.SendChatMessage == nil'),
            ('method call prefix', 'local f = o.C_ChatInfo.SendChatMessage == nil'),
        )
        for label, expression in cases:
            with self.subTest(case=label):
                error = self.gate_error('if false then local o=' + metatable + '; ' + expression + ' end', 'Wire.lua')
                self.assertIsNotNone(error, 'source gate accepted ' + label)
                self.assertIn('Unexpected outgoing/forbidden API: SendChatMessage', error or '')

    def test_chat_presence_statements_are_required_exactly_once(self):
        statements = (
            'local modernAbsent = not S.tab(C_ChatInfo) or S.call(function() return C_ChatInfo.SendChatMessage == nil end) == true',
            'local legacyAbsent = S.call(function() return _G.SendChatMessage == nil end) == true',
        )
        self.assertIsNone(self.gate_error('', 'Wire.lua'))
        for statement in statements:
            with self.subTest(statement=statement, mutation='third copy'):
                error = self.gate_error(statement, 'Wire.lua')
                self.assertIsNotNone(error, 'source gate accepted an extra exact presence statement')
                self.assertIn('chat presence statement must appear exactly once', error or '')
            with self.subTest(statement=statement, mutation='missing'):
                error = self.gate_error('', 'Wire.lua', replace=statement)
                self.assertIsNotNone(error, 'source gate accepted a missing presence statement')
                self.assertIn('chat presence statement must appear exactly once', error or '')
            for prefix in ('o .. ', 'o + ', 'o.'):
                altered = statement.replace('return ', 'return ' + prefix)
                with self.subTest(statement=statement, mutation=prefix):
                    error = self.gate_error(altered, 'Wire.lua', replace=statement)
                    self.assertIsNotNone(error, 'source gate accepted an altered presence statement')
                    self.assertIn('chat presence statement must appear exactly once', error or '')
            for suffix in (' and true', ' or false', ' .. "x"', ' + 1', ', replacement'):
                with self.subTest(statement=statement, mutation='suffix ' + suffix):
                    error = self.gate_error(statement + suffix, 'Wire.lua', replace=statement)
                    self.assertIsNotNone(error, 'source gate accepted an extended presence statement')
                    self.assertIn('chat presence statement must appear exactly once', error or '')
            with self.subTest(statement=statement, mutation='outside owner'):
                self.assertIsNotNone(self.gate_error(statement, 'Main.lua'))

    def test_predicate_metamethod_fixture_reaches_the_function(self):
        # Execute only a fake-client sentinel, never a planted real send API.
        source = '''
            local calls = 0
            C_ChatInfo = {SendChatMessage = function() calls = calls + 1 end}
            local o = setmetatable({}, {
                __concat = function(_, f) return f() end,
                __add = function(_, f) return f() end,
            })
            local concat = o .. C_ChatInfo.SendChatMessage == nil
            local add = o + C_ChatInfo.SendChatMessage == nil
            assert(concat and add and calls == 2)
            print("METAMETHOD_CALLS=" .. calls)
        '''
        result = subprocess.run([str(verify.LUA), '-'], input=source, capture_output=True, text=True, check=True)
        self.assertEqual(result.stdout.strip(), 'METAMETHOD_CALLS=2')

    def test_wire_send_access_belongs_to_deliver(self):
        wire = (self.root / 'LayerEnemies/Wire.lua').read_text()
        # Same single API reference, but moved to a second file-local function.
        moved = ('local function extraSend() return C_ChatInfo.SendAddonMessage end\n' +
                 wire.replace('CI.SendAddonMessage', 'extraSend()'))
        self.assertIsNotNone(self.gate_error(moved, 'Wire.lua', replace=wire))

    def test_extra_wire_access_in_deliver_is_rejected(self):
        start = 'local function deliver(prefix, text, kind, target, now, key, hop)\n'
        # Exact reviewer plant from so-le17, dormant unless sending a raid K packet.
        extra = '    if IsInRaid() and prefix=="LEGW1" and text:sub(1,2)=="K|" then C_ChatInfo.SendAddonMessage("WEFF1",text,"PARTY") end\n'
        self.assertIsNotNone(self.gate_error(start + extra, 'Wire.lua', replace=start))
        for source in ('local fn=C_ChatInfo.SendAddonMessage',
                       'C_ChatInfo["Send".."AddonMessage"](...)',
                       'local c=C_ChatInfo; c[k](...)'):
            with self.subTest(source=source):
                self.assertIsNotNone(self.gate_error('if false then ' + source + ' end', 'Wire.lua'))

    def test_read_only_chat_access_and_inert_send_names_are_allowed(self):
        sources = (
            'local gateChat=_G.C_ChatInfo; local gateAlias=gateChat; local f=gateAlias.GetChannelRosterInfo',
            'local gateChat=_G["C_".."ChatInfo"]; local f=gateChat["Register".."AddonMessagePrefix"]',
            'local note="SendAddonMessage"; local text="Send".."ChatMessage"',
            'local note=[=[SendChatMessage]=]; local SendAddonMessageCount=1',
            '-- SendAddonMessage\n--[=[ SendChatMessage ]=]',
        )
        for filename in ('Main.lua', 'Wire.lua'):
            for source in sources:
                with self.subTest(file=filename, source=source):
                    self.assertIsNone(self.gate_error(source, filename))
        # Trivia changes at the actual access must not turn into a naive text count.
        self.assertIsNone(self.gate_error('CI -- SendAddonMessage\n . SendAddonMessage',
                                         'Wire.lua', replace='CI.SendAddonMessage'))

    def test_harness_loads_every_toc_lua_filename(self):
        # These are TOC addon modules, not separate test suites. The old %w+
        # pattern silently skipped names containing underscores or punctuation.
        shutil.copytree(verify.ROOT / 'test', self.root / 'test')
        toc = self.root / 'LayerEnemies/LayerEnemies.toc'
        original = toc.read_text()
        for name in ('_ReviewProbe.lua', 'Review_probe.lua', 'Review-probe.lua'):
            with self.subTest(name=name):
                target = self.root / 'LayerEnemies' / name
                target.write_text('error("TOC module must not be skipped")\n')
                toc.write_text(original + name + '\n')
                try:
                    result = subprocess.run([str(verify.LUA), 'test/harness.lua'], cwd=self.root,
                                            capture_output=True, text=True)
                    self.assertNotEqual(result.returncode, 0, 'harness skipped ' + name)
                    self.assertIn('TOC module must not be skipped', result.stdout + result.stderr)
                finally:
                    target.unlink()
                    toc.write_text(original)

    def test_comments_and_strings_are_not_api_access(self):
        sources = (
            '-- SendGameData BNSendWhisper C_BattleNet.SendGameData SendAddonMessage SendChatMessage',
            '--[[ SendGameData BNSendGameData SendAddonMessage SendChatMessage ]]',
            '--[==[ ignored ]] and ]=] BNSendWhisper SendAddonMessage SendChatMessage ]==]',
            'local note="C_BattleNet.SendGameData BNSendGameData SendAddonMessage SendChatMessage"',
            "local note='BNSendWhisper SendAddonMessage SendChatMessage'",
            'local note=[=[ ignored ]] BNSendGameData SendAddonMessage SendChatMessage ]=]',
            r'local note="escaped \" quote BNSendGameData SendAddonMessage SendChatMessage"',
            "local note='escaped \\' quote BNSendGameData SendAddonMessage SendChatMessage'",
            'local note="escaped \\\nBNSendGameData SendAddonMessage SendChatMessage"',
        )
        for source in sources:
            with self.subTest(source=source):
                self.assertIsNone(self.gate_error(source), 'inert text must not count as an API access')

    def test_identifier_boundaries_and_long_comment_end(self):
        self.assertIsNone(self.gate_error('local NotBNSendWhisper, SendGameDatabase, SendAddonMessageCount'))
        for source in ('--[=[ ignored ]=]\nBNSendWhisper(...)',
                       'local note="safe"; SendGameData(...)',
                       'local note=[==[ BNSendWhisper ]=] ]==]; BNChannelSendMessage(...)'):
            with self.subTest(source=source):
                self.assertIsNotNone(self.gate_error('if false then ' + source + ' end'))


class ImmutableHookGuardPolicyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.sources = {p.name: p.read_text() for p in sorted((verify.ROOT / 'LayerEnemies').glob('*.lua'))}

    def refuse(self, code, filenames):
        # Compile each plant once, then exercise the real policy against each
        # complete shipped module. A missing Wire fixture cannot mask a binding.
        plant = '\nif false then ' + code + ' end\n'
        subprocess.run([str(verify.LUAC), '-p', '-'], input=plant, text=True, capture_output=True, check=True)
        for filename in filenames:
            with self.subTest(filename=filename, code=code):
                with self.assertRaisesRegex(AssertionError, 'pcall|hooksecurefunc'):
                    verify.check_send_policy(self.sources[filename] + plant, filename)

    def test_no_shipped_file_rebinds_hook_guards(self):
        self.assertIn('Wire.lua', self.sources)
        for filename, source in self.sources.items():
            with self.subTest(filename=filename):
                verify.check_send_policy(source, filename)

    def test_guard_assignments_are_rejected_in_every_addon_file(self):
        for name in ('pcall', 'hooksecurefunc'):
            for lhs in (name, '_G.' + name, '_G["' + name + '"]'):
                self.refuse(lhs + ' = function(...) end', self.sources)

    def test_folded_guard_keys_and_multiple_assignments_are_rejected(self):
        for name in ('pcall', 'hooksecurefunc'):
            forms = (name, '_G.' + name, "_G['" + name + "']",
                     '_G["' + name[:2] + '".."' + name[2:] + '"]',
                     '_G[ [=[' + name + ']=] ]',
                     '_G["\\' + str(ord(name[0])).zfill(3) + name[1:] + '"]')
            for lhs in forms:
                for code in (lhs + ' = replacement', lhs + ', other = replacement, nil',
                             'other, ' + lhs + ' = nil, replacement'):
                    self.refuse(code, ('Wire.lua', 'Main.lua', 'Adapters.lua'))

    def test_guard_declarations_parameters_and_loop_bindings_are_rejected(self):
        for name in ('pcall', 'hooksecurefunc'):
            for code in (
                    'local ' + name,
                    'local other, ' + name + ' = nil, replacement',
                    'local function ' + name + '(...) end',
                    'function ' + name + '(...) end',
                    'function _G.' + name + '(...) end',
                    'local function f(' + name + ') end',
                    'local f = function(other, ' + name + ') end',
                    'for ' + name + ' = 1, 2 do end',
                    'for other, ' + name + ' in pairs({}) do end'):
                self.refuse(code, ('Wire.lua', 'Main.lua', 'Adapters.lua'))

    def test_real_calls_and_inert_guard_names_remain_allowed(self):
        code = '''
            pcall(function() end)
            hooksecurefunc("GetTime", function() end)
            _G.hooksecurefunc("GetTime", function() end)
            local hookPresent = type(S.clean(_G.hooksecurefunc)) == "function"
            local note = 'local pcall, hooksecurefunc = replacement, replacement'
            -- _G.pcall = replacement; _G["hooksecurefunc"] = replacement
            --[=[ function pcall() end; function hooksecurefunc() end ]=]
        '''
        for filename in ('Wire.lua', 'Main.lua', 'Adapters.lua'):
            with self.subTest(filename=filename):
                verify.check_send_policy(self.sources[filename] + '\n' + code, filename)


class WhisperHookPolicyTests(unittest.TestCase):
    MODERN = 'pcall(_G.hooksecurefunc, C_ChatInfo, "SendChatMessage", observeChatWhisper)'
    LEGACY = 'pcall(_G.hooksecurefunc, "SendChatMessage", observeChatWhisper)'

    def check(self, source, filename='Wire.lua'):
        if filename == 'Wire.lua':
            # Keep these hook-focused fixtures valid under the exact presence contract.
            source = ('local function deliver() return C_ChatInfo.SendAddonMessage end\n'
                      'local modernAbsent = not S.tab(C_ChatInfo) or S.call(function() return C_ChatInfo.SendChatMessage == nil end) == true\n'
                      'local legacyAbsent = S.call(function() return _G.SendChatMessage == nil end) == true\n' + source)
        verify.check_send_policy(source, filename)

    def test_exact_posthook_registrations_are_allowed_only_in_wire(self):
        self.check(self.MODERN + '; ' + self.LEGACY)
        for source in (self.MODERN, self.LEGACY):
            for filename in ('Main.lua', 'Adapters.lua', 'Sources.lua'):
                with self.subTest(source=source, filename=filename):
                    with self.assertRaises(AssertionError):
                        self.check(source, filename)

    def test_third_registration_is_rejected(self):
        for extra in (self.MODERN, self.LEGACY):
            with self.subTest(extra=extra), self.assertRaisesRegex(AssertionError, 'exactly once'):
                self.check('; '.join((self.MODERN, self.LEGACY, extra)))

    def test_fourth_registration_is_rejected(self):
        with self.assertRaisesRegex(AssertionError, 'exactly once'):
            self.check('; '.join((self.MODERN, self.LEGACY, self.MODERN, self.LEGACY)))

    def test_missing_registration_is_rejected(self):
        for source in ('', self.MODERN, self.LEGACY):
            with self.subTest(source=source), self.assertRaisesRegex(AssertionError, 'exactly once'):
                self.check(source)

    def test_local_pcall_shadow_is_rejected(self):
        with self.assertRaisesRegex(AssertionError, 'pcall'):
            self.check('local pcall = function(...) end; ' + self.MODERN + '; ' + self.LEGACY)

    def test_local_function_pcall_is_rejected(self):
        with self.assertRaisesRegex(AssertionError, 'pcall'):
            # The reviewer exploit: the inert method-name argument becomes a real call.
            self.check('local function pcall(_, t, k, ...) return t[k](...) end; ' + self.MODERN + '; ' + self.LEGACY)

    def test_global_pcall_assignment_is_rejected(self):
        for lhs in ('pcall', '_G.pcall', '_G["p".."call"]'):
            with self.subTest(lhs=lhs), self.assertRaisesRegex(AssertionError, 'pcall'):
                self.check(lhs + ' = function(...) end; ' + self.MODERN + '; ' + self.LEGACY)

    def test_other_pcall_bindings_are_rejected(self):
        for binding in ('local a, pcall; ', 'function pcall(...) end; ',
                        'local function f(pcall) end; ', 'local f = function(pcall) end; ',
                        'for pcall in pairs({}) do end; ', 'for pcall = 1,2 do end; ',
                        'pcall, other = f, g; '):
            with self.subTest(binding=binding), self.assertRaisesRegex(AssertionError, 'pcall'):
                self.check(binding + self.MODERN + '; ' + self.LEGACY)

    def test_pcall_in_inert_text_is_not_a_binding(self):
        self.check('-- local pcall = evil\nlocal note = "function pcall() end"; ' + self.MODERN + '; ' + self.LEGACY)

    def test_posthook_exemption_never_allows_a_chat_send(self):
        sends = ('SendChatMessage(...)', '_G.SendChatMessage(...)', 'C_ChatInfo.SendChatMessage(...)',
                 'C_ChatInfo["Send".."ChatMessage"](...)', '_G["SendChatMessage"](...)',
                 'local fn=C_ChatInfo.SendChatMessage; fn(...)', 'pcall(SendChatMessage,...)',
                 'pcall(_G.hooksecurefunc, C_ChatInfo, "SendChatMessage", function() SendChatMessage(...) end)',
                 'local c=C_ChatInfo; local k="SendChatMessage"; c[k](...)')
        for source in sends:
            with self.subTest(source=source):
                with self.assertRaises(AssertionError):
                    self.check(self.MODERN + '; ' + self.LEGACY + '; ' + source)

    def test_extra_presence_predicates_are_rejected(self):
        for source in ('C_ChatInfo.SendChatMessage == nil', '_G.SendChatMessage == nil'):
            with self.subTest(source=source):
                with self.assertRaises(AssertionError):
                    self.check('local absent = ' + source, 'Main.lua')
                with self.assertRaisesRegex(AssertionError, 'Unexpected outgoing/forbidden API: SendChatMessage'):
                    self.check(self.MODERN + '; ' + self.LEGACY + '; local absent = ' + source)
                with self.assertRaises(AssertionError):
                    self.check(self.MODERN + '; ' + self.LEGACY + '; local absent = ' + source + '; SendChatMessage(...)')

    def test_namespace_escape_is_not_a_general_hook_permission(self):
        for source in ('pcall(other, C_ChatInfo, "SendChatMessage", observeChatWhisper)',
                       'pcall(_G.hooksecurefunc, C_ChatInfo, "SendAddonMessage", observeChatWhisper)',
                       'pcall(_G.hooksecurefunc, C_ChatInfo, key, observeChatWhisper)',
                       'use(C_ChatInfo)', 'local c=C_ChatInfo; use(c)'):
            with self.subTest(source=source):
                with self.assertRaisesRegex(AssertionError, 'chat namespace escapes'):
                    self.check(self.MODERN + '; ' + self.LEGACY + '; ' + source)


if __name__ == '__main__':
    unittest.main()
