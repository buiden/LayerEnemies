"""Regression tests for the verifier's source gate; no addon code is executed."""
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

    def gate_error(self, source, filename='Main.lua'):
        target = self.root / 'LayerEnemies' / filename
        original = target.read_text()
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
        self.assertIsNone(self.gate_error('if false then C_ChatInfo.SendAddonMessage(...) end', 'Wire.lua'))
        self.assertIsNotNone(self.gate_error('if false then SendChatMessage(...) end', 'Wire.lua'))

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


if __name__ == '__main__':
    unittest.main()
