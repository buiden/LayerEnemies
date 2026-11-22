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

    def test_chehulnet_has_no_send_join_save_or_enemy_projection_access(self):
        source = (Path(__file__).resolve().parents[1] / 'LayerEnemies/ChehulNet.lua').read_text()
        self.check_source(source, 'ChehulNet.lua')
        VERIFY['check_send_policy'](source, 'ChehulNet.lua')
        refs = {word for _, word in VERIFY['lua_references'](VERIFY['lua_tokens'](source))}
        self.assertFalse(refs & {'Wire', 'BNet', 'Directory', 'JoinChannelByName', 'LeaveChannelByName',
                                 'LayerEnemiesDB', 'Find', 'Presence', 'Store', 'Reports', 'Hosts',
                                 'LibStub', 'loadstring', 'dofile', 'offer', 'SetText', 'PlaySound'})
        self.assertIn('register', refs)
        toc = (Path(__file__).resolve().parents[1] / 'LayerEnemies/LayerEnemies.toc').read_text().splitlines()
        self.assertLess(toc.index('ChehulNet.lua'), toc.index('UI.lua'))

    def test_flh_routes_are_only_the_four_approved_routes(self):
        self.assertIn('check_route_policy', VERIFY)
        source = (Path(__file__).resolve().parents[1] / 'LayerEnemies/Wire.lua').read_text()
        VERIFY['check_route_policy'](source)
        for extra in ('CHANNEL = true, ', 'SAY = true, '):
            changed = source.replace('FLHNET2 = { kinds = { ', 'FLHNET2 = { kinds = { ' + extra)
            with self.assertRaises(AssertionError):
                VERIFY['check_route_policy'](changed)
        for name in ('FLHMember.lua', 'FLH.lua'):
            text = (Path(__file__).resolve().parents[1] / 'LayerEnemies' / name).read_text()
            VERIFY['check_send_policy'](text, name)
            refs = {word for _, word in VERIFY['lua_references'](VERIFY['lua_tokens'](text))}
            self.assertFalse(refs & {'SendAddonMessage', 'SendChatMessage', 'InviteUnit', 'AcceptGroup',
                                     'LeaveParty', 'LayerEnemiesDB', 'JoinChannelByName', 'SendGameData'})

    def test_flh_route_gate_rejects_truthy_nonboolean_routes(self):
        source = (Path(__file__).resolve().parents[1] / 'LayerEnemies/Wire.lua').read_text()
        for value in ('1', '"yes"', 'function() end', 'false'):
            with self.subTest(value=value), self.assertRaises(AssertionError):
                VERIFY['check_route_policy'](source.replace('FLHNET2 = { kinds = { ',
                    'FLHNET2 = { kinds = { CHANNEL = ' + value + ', '))

    def test_flh_route_gate_rejects_bracket_routes(self):
        source = (Path(__file__).resolve().parents[1] / 'LayerEnemies/Wire.lua').read_text()
        for key in ('["CHANNEL"]', '["CHAN".."NEL"]', '[routeName]'):
            with self.subTest(key=key), self.assertRaises(AssertionError):
                VERIFY['check_route_policy'](source.replace('FLHNET2 = { kinds = { ',
                    'FLHNET2 = { kinds = { ' + key + ' = true, '))

    def test_flh_route_gate_rejects_later_mutation_and_escape(self):
        source = (Path(__file__).resolve().parents[1] / 'LayerEnemies/Wire.lua').read_text()
        for later in ('ROUTES.FLHNET2.kinds.CHANNEL = true',
                      'ROUTES["FLHNET2"].kinds["CHANNEL"] = 1',
                      'local alias = ROUTES; alias.FLHNET2.kinds.CHANNEL = true',
                      'rawset(ROUTES.FLHNET2.kinds,"CHANNEL",true)',
                      'route.kinds.CHANNEL = true'):
            with self.subTest(later=later), self.assertRaises(AssertionError):
                VERIFY['check_route_policy'](source + '\n' + later)
        VERIFY['check_route_policy'](source + '\n-- ROUTES.FLHNET2.kinds.CHANNEL = true\n'
                                    'local inert="ROUTES.FLHNET2.kinds.CHANNEL = true"')

    def test_flh_route_gate_requires_complete_unique_literal_routes(self):
        source = (Path(__file__).resolve().parents[1] / 'LayerEnemies/Wire.lua').read_text()
        for kinds in ('GUILD = true, PARTY = true, RAID = true',
                      'GUILD = true, PARTY = true, RAID = true, WHISPER = false',
                      'GUILD = true, PARTY = true, RAID = true, WHISPER = true, WHISPER = false'):
            changed = source.replace('FLHNET2 = { kinds = { GUILD = true, PARTY = true, RAID = true, WHISPER = true',
                                     'FLHNET2 = { kinds = { ' + kinds)
            with self.subTest(kinds=kinds), self.assertRaises(AssertionError):
                VERIFY['check_route_policy'](changed)

    def test_flh_route_gate_rejects_loop_over_local_alias(self):
        source = (Path(__file__).resolve().parents[1] / 'LayerEnemies/Wire.lua').read_text()
        read = 'local route = type(prefix) == "string" and ROUTES[prefix]'
        plant = ('\n    if route then for _, value in pairs(route) do '
                 'if type(value) == "table" then value.CHANNEL = true end end end')
        self.assertEqual(source.count(read), 1)
        with self.assertRaises(AssertionError):
            VERIFY['check_route_policy'](source.replace(read, read + plant))

    def test_flh_route_gate_rejects_computed_replacement_routes(self):
        source = (Path(__file__).resolve().parents[1] / 'LayerEnemies/Wire.lua').read_text()
        read = 'local route = type(prefix) == "string" and ROUTES[prefix]'
        for plant in (
            'if prefix == "ReviewPrefix" then local key = "ki" .. "nds"; '
            'route = { [key] = { GUILD = true }, check = function() return "line" end } end',
            'if prefix == "FLHNET2" and kind == "CHANNEL" then local key = "ki" .. "nds"; '
            'route = { [key] = { CHANNEL = true }, check = route.check } end',
        ):
            with self.subTest(plant=plant), self.assertRaises(AssertionError):
                VERIFY['check_route_policy'](source.replace(read, read + '\n    ' + plant))

    def test_flh_route_gate_rejects_computed_declaration_fields_and_alias_escapes(self):
        source = (Path(__file__).resolve().parents[1] / 'LayerEnemies/Wire.lua').read_text()
        for i, changed in enumerate((
            source.replace('local ROUTES = {', 'local key="ki".."nds"\nlocal ROUTES = {')
                  .replace('check = flhText', 'check = flhText, [key] = { CHANNEL = true }'),
            source.replace('local tag = route.check(text, kind)',
                           'local alias=route; for _, v in pairs(alias) do if type(v)=="table" then v.CHANNEL=true end end\n'
                           '    local tag = route.check(text, kind)'),
            source.replace('local route, tag, public', 'local route, tag, public\n    route={ [key]={ CHANNEL=true } }'),
        )):
            with self.subTest(plant=i), self.assertRaises(AssertionError):
                VERIFY['check_route_policy'](changed)
        VERIFY['check_route_policy'](source + '\n-- route = { [key] = { CHANNEL=true } }\n'
                                    'local inert=[=[for _,v in pairs(route) do v.CHANNEL=true end]=]')

    def test_flh_route_gate_still_rejects_all_fourteen_earlier_reviewer_plants(self):
        source = (Path(__file__).resolve().parents[1] / 'LayerEnemies/Wire.lua').read_text()
        start = source.index('FLHNET2 = { kinds = { ')
        end = source.index('\n', start)
        line = source[start:end]
        table_end = source.index('\n}', start) + 2
        def inline(before, after):
            return source[:start] + line.replace(before, after, 1) + source[end:]
        def later(text):
            return source[:table_end] + '\n' + text + source[table_end:]
        plants = [
            inline('kinds = { ', 'kinds = { CHANNEL = true, '),
            inline('kinds = { ', 'kinds = { CHANNEL = 1, '),
            inline('kinds = { ', 'kinds = { ["CHANNEL"] = true, '),
            later('ROUTES.FLHNET2.kinds.CHANNEL = true'),
            later('rawset(ROUTES.FLHNET2.kinds,"CHANNEL",true)'),
            later('local R = ROUTES; R.FLHNET2["kin".."ds"].CHANNEL = true'),
            inline('check = flhText', 'check = flhText, kinds = { CHANNEL = true }'),
            inline('check = flhText', 'check = flhText, ["kinds"] = { CHANNEL = true }'),
            inline('check = flhText', 'check = flhText, ["kin".."ds"] = { CHANNEL = true }'),
            source.replace('WHISPER = true', 'WHISPER = true, YELL = true', 1),
            source[:start] + 'EVILPFX = { kinds = { WHISPER = true } },\n    ' + source[start:],
            later('local ROUTES = { X = { kinds = { CHANNEL = true } } }'),
            later('local ROUTES = setmetatable({}, {__index=function() return {kinds={CHANNEL=true}} end})'),
            source.replace('if not (route and type(kind)',
                           'route = route or { ["kin".."ds"] = { CHANNEL = true } }\n    if not (route and type(kind)', 1),
        ]
        self.assertEqual(len(plants), 14)
        for i, changed in enumerate(plants):
            with self.subTest(plant=i), self.assertRaises(AssertionError):
                VERIFY['check_route_policy'](changed)

    def test_flh_route_gate_rejects_expression_suffix_replacements(self):
        source = (Path(__file__).resolve().parents[1] / 'LayerEnemies/Wire.lua').read_text()
        read = 'local route = type(prefix) == "string" and ROUTES[prefix]'
        fields = 'local fieldA="ki".."nds"; local fieldB="ch".."eck"\n    '
        for prefix, kind in (('ReviewPrefix', 'GUILD'), ('FLHNET2', 'CHANNEL')):
            # Preserve the old whitelisted subsequence, but replace its result.
            # The FLH variant also applies when the real ROUTES lookup is truthy.
            suffix = (' or (prefix=="' + prefix + '" and { [fieldA]={ ' + kind +
                      '=true }, [fieldB]=function() return "line" end })')
            plant = fields + read + ((' and kind~="CHANNEL"') if kind == 'CHANNEL' else '') + suffix
            with self.subTest(prefix=prefix), self.assertRaises(AssertionError):
                VERIFY['check_route_policy'](source.replace(read, plant))

    def test_flh_route_gate_rejects_unreviewed_tables_and_computed_keys_in_check(self):
        source = (Path(__file__).resolve().parents[1] / 'LayerEnemies/Wire.lua').read_text()
        read = 'local route = type(prefix) == "string" and ROUTES[prefix]'
        for plant in ('local replacement={}', 'local replacement=other[key]'):
            with self.subTest(plant=plant), self.assertRaises(AssertionError):
                VERIFY['check_route_policy'](source.replace(read, plant + '\n    ' + read))

    def test_debug_upvalue_access_is_forbidden_in_every_addon_module(self):
        root = Path(__file__).resolve().parents[1] / 'LayerEnemies'
        plant = ('local _, captured=debug.getupvalue(Wr.send,1); '
                 'debug.setupvalue(Wr.send,1,captured)')
        for path in root.glob('*.lua'):
            self.check_source(path.read_text(), path.name)
            for access in (plant, 'local d=debug; d.getupvalue(fn,1)',
                           '_G["de".."bug"].getupvalue(fn,1)',
                           '_G.debug.setupvalue(fn,1,{})'):
                with self.subTest(file=path.name, access=access), self.assertRaises(AssertionError):
                    self.check_source(path.read_text() + '\n' + access, path.name)
        self.check_source('-- debug.getupvalue(fn,1)\nlocal inert="debug.setupvalue"')

    def test_flh_membership_side_effect_is_disclosed(self):
        readme = (Path(__file__).resolve().parents[1] / 'README.md').read_text()
        self.assertIn("A real Forever Layer Hop client on another realm that hears our messages may introduce "
                      "our name, realm, map and layer on its own realm's channel, as it does for any Forever "
                      "Layer Hop user; this is an accepted membership side effect.", readme)

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

    def test_phase_reader_is_adapter_only(self):
        for source in ('local f=UnitPhaseReason', 'local f=_G["Unit".."PhaseReason"]'):
            self.check_source(source, 'Adapters.lua')
            with self.assertRaisesRegex(AssertionError, 'Adapters.lua'):
                self.check_source(source, 'Main.lua')

    def test_guild_drafts_are_forbidden(self):
        root = Path(__file__).resolve().parents[1] / 'LayerEnemies'
        for path in root.glob('*.lua'):
            VERIFY['check_guild_drafts'](path.read_text(), path.name)
        for source in ('local line="/g inv layer"', 'local x=SLASH_GUILD',
                       'M.openChat("hello", "GUILD")', 'M.openChat("/".."g hello")'):
            with self.assertRaises(AssertionError):
                VERIFY['check_guild_drafts'](source, 'Main.lua')

    def test_permitted_owners(self):
        self.check_source('local api=C_FriendList; local f=api["Send".."Who"]', 'Adapters.lua')
        self.check_source('local f=_G["Accept".."Group"]', 'Wire.lua')
        self.check_source('local tip=_G.GameTooltip; local map=_G["C_".."Map"]')

    def test_system_filter_owner_is_wire_only(self):
        for access in ('ChatFrame_AddMessageEventFilter', '_G.ChatFrame_AddMessageEventFilter',
                       '_G["ChatFrame_".."AddMessageEventFilter"]'):
            code = 'if false then local fn=' + access + ' end'
            self.check_source(code, 'Wire.lua')
            for filename in ('Main.lua', 'Adapters.lua', 'Sources.lua'):
                with self.subTest(access=access, filename=filename), self.assertRaisesRegex(AssertionError, 'Wire.lua'):
                    self.check_source(code, filename)

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

    def test_warboard_is_pure_and_uses_only_the_shared_bnet_send(self):
        root = Path(__file__).resolve().parents[1] / 'LayerEnemies'
        source = (root / 'WarBoard.lua').read_text()
        tokens = VERIFY['lua_tokens'](source)
        names = {v for k, v in tokens if k == 'name'}
        self.check_source(source, 'WarBoard.lua')
        VERIFY['check_send_policy'](source, 'WarBoard.lua')
        self.assertFalse(names & {'_G', 'C_Timer', 'CreateFrame', 'LibStub', 'GetTime', 'time',
                                  'UnitFactionGroup', 'Wire', 'LayerEnemiesDB', 'loadstring', 'dofile'})
        self.assertFalse(any(v.startswith('C_') for v in names))
        self.assertEqual(source.count('BN.send('), 1)
        self.assertIn('Src.register{name="warboard"', source)
        self.assertNotIn('SendAddonMessage', names)
        track = (root / 'WarBoardTrack.lua').read_text()
        self.check_source(track, 'WarBoardTrack.lua')
        VERIFY['check_send_policy'](track, 'WarBoardTrack.lua')
        words = {v for k, v in VERIFY['lua_tokens'](track) if k == 'name'}
        self.assertFalse(words & {'_G', 'C_Timer', 'CreateFrame', 'Wire', 'LayerEnemiesDB', 'UnitGUID', 'GetTime'})
        self.assertEqual(track.count('BN.send('), 1)
        self.assertNotIn('SendGameData', names)
        for path in root.glob('*.lua'):
            refs = {v for _, v in VERIFY['lua_references'](VERIFY['lua_tokens'](path.read_text()))}
            if 'GetMapPosFromWorldPos' in refs:
                self.assertEqual(path.name, 'Adapters.lua')


    def test_composed_overlord_route_is_frozen_with_flh(self):
        source = (Path(__file__).resolve().parents[1] / 'LayerEnemies/Wire.lua').read_text()
        VERIFY['check_route_policy'](source)
        anchor = 'OverlordF = { kinds = { '
        self.assertEqual(source.count(anchor), 1)
        for field in ('CHANNEL=true, ', 'SAY=1, ', '["GUILD"]=true, '):
            with self.subTest(field=field), self.assertRaises(AssertionError):
                VERIFY['check_route_policy'](source.replace(anchor, anchor + field))
        for old, new in (('net="overlord"', 'net="flh"'),
                         ('and "peer" end, net="overlord"', 'and "other" end, net="overlord"')):
            self.assertEqual(source.count(old), 1)
            with self.assertRaises(AssertionError):
                VERIFY['check_route_policy'](source.replace(old, new))

    def test_overlord_peer_is_pure_and_uses_owned_transport(self):
        root = Path(__file__).resolve().parents[1] / 'LayerEnemies'
        source = (root / 'OverlordPeer.lua').read_text()
        self.check_source(source, 'OverlordPeer.lua')
        VERIFY['check_send_policy'](source, 'OverlordPeer.lua')
        refs = {v for k, v in VERIFY['lua_tokens'](source) if k == 'name'}
        self.assertFalse(refs & {'_G', 'C_Timer', 'GetTime', 'SendGameData', 'SendAddonMessage',
                                 'LayerEnemiesDB', 'LibStub', 'SetText', 'JoinChannelByName'})
        wire = (root / 'Wire.lua').read_text()
        self.assertIn('N.OverlordPeer.dispatching(text,kind,target)', wire)
        self.assertEqual((root / 'LayerEnemies.toc').read_text().count('OverlordPeer.lua'), 1)


    def test_overlord_feed_is_pure_and_does_not_serve_or_save(self):
        root = Path(__file__).resolve().parents[1] / 'LayerEnemies'
        source = (root / 'OverlordFeed.lua').read_text()
        self.check_source(source, 'OverlordFeed.lua')
        VERIFY['check_send_policy'](source, 'OverlordFeed.lua')
        refs = {v for k, v in VERIFY['lua_tokens'](source) if k == 'name'}
        self.assertFalse(refs & {'_G', 'C_Timer', 'GetTime', 'SendGameData', 'SendAddonMessage',
                                 'LayerEnemiesDB', 'LibStub', 'SetText', 'JoinChannelByName'})
        self.assertEqual((root / 'LayerEnemies.toc').read_text().count('OverlordFeed.lua'), 1)


if __name__ == '__main__':
    unittest.main(verbosity=2)
