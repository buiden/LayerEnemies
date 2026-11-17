"""Source-policy regressions: inspect dead code; never execute a planted API call."""
from pathlib import Path
import runpy
import unittest

VERIFY = runpy.run_path(str(Path(__file__).with_name('verify.py')))


PRESENCE_READS = {'GetSubscribedClubs', 'GetClubMembers', 'GetMemberInfo',
                  'BNGetNumFriends', 'GetFriendAccountInfo', 'GetAccountInfoByID',
                  'GetFriendNumGameAccounts', 'GetFriendGameAccountInfo'}


def presence_policy(source, filename):
    for _, word in VERIFY['lua_references'](VERIFY['lua_tokens'](source)):
        if word in PRESENCE_READS:
            assert filename == 'Adapters.lua', word + ' outside Adapters.lua'
        assert word != 'SetClubPresenceSubscription', 'presence subscription forbidden'


class ApiPolicyTests(unittest.TestCase):
    def test_presence_owners_and_no_subscription(self):
        for path in (Path(__file__).resolve().parents[1] / 'LayerEnemies').glob('*.lua'):
            presence_policy(path.read_text(), path.name)
        for word in PRESENCE_READS:
            for access in (word, '_G["' + word + '"]'):
                with self.subTest(access=access), self.assertRaisesRegex(AssertionError, 'Adapters.lua'):
                    presence_policy('if false then local x=' + access + ' end', 'Main.lua')
        with self.assertRaisesRegex(AssertionError, 'subscription'):
            presence_policy('local x=C_Club.SetClubPresenceSubscription', 'Adapters.lua')

    def test_presence_data_module_has_no_client_access(self):
        path = Path(__file__).resolve().parents[1] / 'LayerEnemies/Presence.lua'
        tokens = VERIFY['lua_tokens'](path.read_text())
        names = {value for kind, value in tokens if kind == 'name'}
        self.assertFalse(names & (PRESENCE_READS | {'_G', 'C_Club', 'C_BattleNet', 'C_Timer', 'GetTime', 'UnitFactionGroup', 'Wire'}))

    def test_bnet_send_has_one_owner_and_one_local_delivery_site(self):
        root = Path(__file__).resolve().parents[1] / 'LayerEnemies'
        source = (root / 'BNet.lua').read_text()
        VERIFY['check_send_policy'](source, 'BNet.lua')
        for name in ('Main.lua', 'Adapters.lua', 'Wire.lua', 'Sources.lua'):
            with self.subTest(name=name), self.assertRaises(AssertionError):
                VERIFY['check_send_policy']('local fn=C_BattleNet.SendGameData', name)
        for access in ('C_BattleNet.SendGameData', 'C_BattleNet["Send".."GameData"]', 'BNSendGameData'):
            with self.subTest(access=access), self.assertRaises(AssertionError):
                VERIFY['check_send_policy'](source + '\nif false then local x=' + access + ' end', 'BNet.lua')
        moved = source.replace('api.SendGameData', 'nil') + '\nlocal function bypass() return C_BattleNet.SendGameData end'
        with self.assertRaises(AssertionError):
            VERIFY['check_send_policy'](moved, 'BNet.lua')

    def check_source(self, source, name='Main.lua'):
        VERIFY['check_api_policy'](source, name)

    def test_dormant_who_aliases(self):
        for access in ('C_FriendList.SendWho', 'C_FriendList["Send".."Who"]',
                       '_G.C_FriendList["Send" .. ("Who")]',
                       '_G["C_".."FriendList"]["SendWho"]'):
            with self.subTest(access=access), self.assertRaisesRegex(AssertionError, 'Adapters.lua'):
                self.check_source('if false then local f=' + access + '; f("query",1) end')

    def test_who_ui_ownership_stays_in_adapter(self):
        for word in ('SetWhoToUi', 'FriendsFrame', 'LFGWhoListFrame', 'WhoFrame'):
            source = 'local value=_G["' + word + '"]'
            with self.subTest(word=word):
                with self.assertRaisesRegex(AssertionError, 'Adapters.lua'):
                    self.check_source(source)
                self.check_source(source, 'Adapters.lua')

    def test_dormant_accept_aliases(self):
        for access in ('AcceptGroup', '_G.AcceptGroup', '_G["Accept".."Group"]',
                       '_G[("Ac".."cept")..("Gr".."oup")]',
                       '_G["\\065ccept".."Group"]', ' _G[ [=[AcceptGroup]=] ]'):
            with self.subTest(access=access), self.assertRaisesRegex(AssertionError, 'Wire.lua'):
                self.check_source('if false then local f=' + access + '; f() end')

    def test_global_alias_and_dynamic_keys_fail_closed(self):
        for source in ('local g=_G; if false then g[key]() end',
                       'if false then _G[key]() end',
                       'local f=getfenv(); if false then f[key]() end',
                       'if false then rawget(_G,key)() end'):
            with self.subTest(source=source), self.assertRaises(AssertionError):
                self.check_source(source)

    def test_permitted_owners(self):
        self.check_source('local api=C_FriendList; local f=api["Send".."Who"]', 'Adapters.lua')
        self.check_source('local f=_G["Accept".."Group"]', 'Wire.lua')
        self.check_source('local tip=_G.GameTooltip; local map=_G["C_".."Map"]')

    def test_comments_and_plain_data_are_not_api_references(self):
        self.check_source('-- AcceptGroup\n--[=[ C_FriendList.SendWho ]=]\n'
                          'local note="AcceptGroup"; local text=[=[_G["Accept".."Group"]]=]')


    def test_codec_has_only_local_protocol_exports_and_no_send_api(self):
        import re
        source = (Path(__file__).resolve().parents[1] / 'LayerEnemies/Codec.lua').read_text()
        self.check_source(source, 'Codec.lua')
        VERIFY['check_send_policy'](source, 'Codec.lua')
        exports = re.findall(r'function Cd\.(\w+)\(', source)
        self.assertEqual(sorted(exports), sorted(('inflate', 'deflateStored', 'addonEncode', 'addonDecode',
                                                 'aceRead', 'aceWrite', 'lsRead', 'lsWrite', 'aceCommJoin', 'aceCommSplit')))
        names = [value for kind, value in VERIFY['lua_tokens'](source) if kind == 'name']
        self.assertFalse(set(names) & {'_G', 'LibStub', 'CreateFrame', 'C_Timer', 'GetTime', 'time', 'loadstring', 'dofile'})
        self.assertFalse(any(x.startswith('C_') for x in names))


    def test_wanted_is_receive_only_and_reuses_shared_codecs(self):
        root = Path(__file__).resolve().parents[1] / 'LayerEnemies'
        source = (root / 'Wanted.lua').read_text()
        self.check_source(source, 'Wanted.lua')
        VERIFY['check_send_policy'](source, 'Wanted.lua')
        names = {v for k, v in VERIFY['lua_tokens'](source) if k == 'name'}
        self.assertFalse(names & {'SendAddonMessage', 'SendGameData', 'BNSendGameData', 'Wire',
                                 'JoinChannelByName', 'LeaveChannelByName', 'CreateFrame', 'C_Timer',
                                 'LayerEnemiesDB', 'LibStub', 'lsWrite', 'aceWrite', 'addonEncode'})
        for use in ('Cd.addonDecode', 'Cd.inflate', 'Cd.lsRead', 'Src.register', 'Src.offer'):
            self.assertIn(use, source)
        # Wanted has numbered fragments, not AceComm. No extra event frame/wiring.
        self.assertNotIn('aceCommJoin', source)
        self.assertEqual((root / 'LayerEnemies.toc').read_text().count('Wanted.lua'), 1)


if __name__ == '__main__':
    unittest.main(verbosity=2)
