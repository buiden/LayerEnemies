# API evidence

Checked the Forever-era Blizzard UI mirror commit
70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e by fetching the named
API documentation files read-only. This is source-level evidence, not a real
Forever client run.

Base URL:
https://github.com/Gethe/wow-ui-source/tree/70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e/Interface/AddOns/Blizzard_APIDocumentationGenerated

- PlayerScriptDocumentation.lua, GetPlayerInfoByGUID, line 770:
  global function; MayReturnNothing=true; arguments: guid;
  returns localizedClass, englishClass, localizedRace, englishRace, sex,
  name, realmName, optional level (eighth return). SecretArguments is
  AllowedWhenTainted. The adapter still checks function availability at
  runtime, wraps it in pcall, and checks every return for secrecy. This
  documents no faction return; race is not used to infer faction.
- UnitDocumentation.lua, UnitFactionGroup, line 1207:
  accepts unitName and optional checkDisplayRace=false; returns factionGroupTag
  and localized faction. The adapter requires readable Alliance/Horde tags
  for both player and observed unit, never infers faction from hostility.
- FriendListDocumentation.lua, C_FriendList.IsIgnored, line 235:
  accepts a string token, returns boolean isIgnored; RequiresFriendList=true.
  Missing, secret, or throwing implementations make the privacy gate fail
  closed. This source declaration does not establish friend-list readiness
  or name-normalization behavior in the actual client.

Third-party reference inspection (not copied into the addon):

- BuloLayerForever 3.0.24 Core.lua lines 266-280: NS:On(event, fn), callbacks
  receive event arguments without namespace/self; Layer.lua lines 305-329
  changes full current ID through LFS_RAW and LFS_LAYER. No exported tentative
  query was found. Radar.lua lines 86-95 records only timestamp/hostility/source.
- WarEffortScout 0.2.13 Protocol.lua header defines C/E/H grammar, field bounds,
  class codes, hash algorithm, and modulo-hour timestamp positions. Comms.lua
  lines 1158-1205 filters ignored senders, guild/public contexts and silent mode.
  Config.lua exposes the initialized settings as WarEffortScoutDB. Legacy
  enablement is local, so receipt of ZRAD1 is not treated as permission to read it.

The two NPC-GUID identifier methods remain source-author assumptions until
paired-client transfer/zone tests establish their actual behavior.
