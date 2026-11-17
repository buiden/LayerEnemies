"""Source-policy regressions: inspect dead code; never execute a planted API call."""
from pathlib import Path
import runpy
import unittest

VERIFY = runpy.run_path(str(Path(__file__).with_name('verify.py')))


class ApiPolicyTests(unittest.TestCase):
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


if __name__ == '__main__':
    unittest.main(verbosity=2)
