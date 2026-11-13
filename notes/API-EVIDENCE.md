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

## Tracked-target wire names (build 0.2.0)

Inspected WarEffortScout 0.2.13 source in the read-only reference cache:

- Protocol.lua 86–110: Hash3 is DJB2 with unsigned 32-bit modulo and three
  least-significant base-62 digits; NameKey lowercases name, appends '-',
  then lowercases realm after removing spaces and hyphens. Empty realm is
  valid and still leaves the trailing hyphen.
- Detect.lua 56–62: ReadEnemy reads both UnitName returns as name/realm, falls
  back to homeRealm if the second return is absent/empty, then hashes NameKey.
  Detect.Init initializes homeRealm from GetNormalizedRealmName/GetRealmName.
- Util.lua 50–57 and Probe.lua 685–687 explicitly describe Forever's second
  UnitName return as surname and join readable parts with a space for display.
  Comms.lua 1167 runs Ambiguate(sender, 'none'). The display convention does
  not change the detector's actual name/second-return hashing behaviour.
- Bulo Core.lua 138–168 and LayerSwap LayerSwap.lua 227–255 read the surname
  separator constant with a space fallback; LayerSwap notes that the player's
  own UnitName can already contain the full name in its first return.

Independent Python-derived fixed vectors, asserted by the Lua harness:
  alice-testrealm -> Zzm; alice- -> YNz.
Real collision fixture: pfkmeclrzj- and cuhfvpbgza- both hash to Y8Y.
These matches remain possible identities, never asserted identities.

At the Blizzard UI mirror commit above, Shared/ChatFrameUtil.lua 383–386
implements ChatFrameUtil.SendTell via SendTellWithMessage with empty text;
GetActiveWindow at 496–498 returns ACTIVE_CHAT_EDIT_BOX. These are source
checks only. SendTell itself formats and parses native whisper text. We have
not proved Forever's surname targeting or Insert behaviour in a live client;
missing/throwing APIs fall back to recipient/message instructions. No chat
send API is invoked by LayerEnemies.
