# 1.2.0 PR 1 — read-only Battle.net presence

Implementation commit: `b0d7aa1d7296d09a4c43cc74270249563bcd15be`.
Base: `d9f0a71262d35cc59f1292757ed266ca08680eb9` (main, 1.1.0).
Branch: `feat/bnet-presence`. Local only; origin push URL is `DISABLED`.

## Round-1 reviewer fixes — stack/3-presence

Applied to stack base `dc9df49d7d30e14cee2838f0c675e00179377e96`, without
rewriting it or changing stack levels 1 or 2. The historical implementation
record below describes the original feature, not the corrected adapter contract.

### Owner rulings implemented

1. `A.clubMember` reads `presence` and the one newly permitted club field,
   `bnetAccountId`. It resolves `C_BattleNet.GetAccountInfoByID(...).gameAccountInfo`
   and uses only the resolved character name, realm (`realmName` with
   `realmDisplayName` fallback), zone, faction and optional player GUID. Online
   `WoW` is required. Raw club name/zone/faction/GUID are no longer read or used
   as character evidence. Missing, secret, throwing or incomplete resolution
   admits no presence row. The friend route retains its online/project gate.
2. Every visited club/member pair or friend-list slot replaces its own old
   evidence immediately, even when offline, non-WoW, incomplete or unreadable.
   Sources not visited retain the 660-second TTL. Source tokens are session-only;
   no account IDs/names are retained or saved. Other-source records, sightings,
   Ask targets and the 600-second notice cooldown are not cleared by withdrawal.
3. `/le presence` now separates community members read, resolved to a character,
   with a zone, and opposite faction, then labels matches as all-source totals.
   Counts remain name/zone-free and do not cause a scan. Partial safe resolution
   contributes only to the appropriate diagnostic stage, never a display row.
4. Find-tab switches and Find-window reopens share a once-per-60-second forced
   refresh allowance. Overlapping/unsafe scans do not consume another allowance;
   the existing 300-second automatic cadence remains unchanged.
5. Both deliberate deviations remain intended and are explicit in README:
   same-faction namesakes are dropped, and only Battle.net-type clubs are read
   because character communities are same-faction.

API evidence remains Forever build `1.60.1.70938` at
`bebcb6bf309cf41b41bd74f8ca651e6a105b2676`: generated
`ClubDocumentation.lua:1819` declares `bnetAccountId`; generated
`BattleNetDocumentation.lua:99-114` declares `GetAccountInfoByID`, and
`:495,514-533` declares `gameAccountInfo` and the character fields. WarBoard's
`Services/WarBoard_ForeverCommunity.lua:119-160` was read for API usage only.
Its nearby no-reuse notice was observed; no donor code was copied, and no donor
runtime dependency, subscription or wire protocol was introduced.

### Observed RED → GREEN

All names below have the `Presence: ` prefix and run through the real adapters,
scan driver and Find projection in `test/harness.lua --presence-only`.

| Ruling | Regression test | Observed RED before its production fix |
|---|---|---|
| 1 | `club character comes from account not member display name` | BattleTag member failed to resolve |
| 1 | `account resolution unavailable secret incomplete and non WoW fail silent` | Missing resolver incorrectly accepted the raw member name |
| 2 | `reread offline or non WoW drops personal and shared evidence immediately` | Offline reread retained the personal row before TTL |
| 3 | `diagnostic separates unresolved zoneless same faction and unmatched members` | Resolution stage count missing |
| 4 | `Find switches and window opens share one force per 60 seconds` | Twenty rapid tab/window reopens caused 21 reads rather than 1 |

Each tracer passed after its own fix. The additional unread-TTL/other-source
regression passed unchanged (not claimed as RED). An initial TTL fixture used
integer time despite the `.001` scan tick; corrected it to the actual record
stamp before accepting the RED result. Existing fixtures were migrated from raw
club character fields to explicit game-account fields; guild-hash display now
expects the resolved full name with realm. The old immediate-reopen assertion
was explicitly migrated to the owner's 60-second contract. No test was removed.

- Unchanged initial presence subset: `RESULT: 20 tests passed, 0 failed, 5874 assertions`.
- Final test file replayed in a detached copy of the exact stack base:
  `RESULT: 13 tests passed, 13 failed, 4990 assertions`. This includes failures
  from migrated character fixtures, not thirteen independent new defects.
- Corrected subset: `RESULT: 26 tests passed, 0 failed, 11002 assertions`.
- Full level-3 `python3 test/verify.py` (foreground):
  `RESULT: 1196 tests passed, 0 failed, 133691 assertions`.
- `python3 test/presence_mutants.py`: **38/38 killed**, baseline/final green.
  Seven mutants added, covering every new rule plus the retained faction rule;
  the existing club-type mutant remains. Old anchors were updated to the new
  character source/UI hook, and the UI mutant now violates the measured render
  height rather than an obsolete minimum-height calculation. No survivors or
  survivor-driven test additions. Full results: `notes/presence-mutants.json`.
- Syntax, static policy, packaging/source parity, 5,000 fuzz inputs, verifier,
  API-policy and asset gates all pass. `test/verify.py` and `Wire.lua` unchanged
  from this task's stack base. `git diff --check` passes.
- Level-3 deterministic archive SHA-256:
  `02dffeb7aee65b2bcf47170389487416971c26b675f782ab52995e3b8c3d0643`.
- Self-review only in this builder (no subagent review tool). The supplied
  reviewer probe was copied and run read-only before fixing; source evidence is
  not native-client validation. **Not tested in game (alpha, owner's decision).**

Forward merges retain this record; each level regenerates its own
`notes/test-results.txt` and `notes/verification.json`.

## Result and boundaries

- Four protected adapters, pure `Presence.lua`, incremental Main scan, independent
  Find evidence, pooled UI line and `/le presence` counts-only diagnostic.
- No new sends or saved player names. `Wire.lua` and **all of `test/verify.py`**
  are byte-for-byte unchanged from the base. No `/who` by name, subscriptions,
  community joins, Watch button, or donor code/wire protocol. No new THIRD_PARTY
  entry is needed for game-API-only reads.
- Presence never enters Known, Reports, peers, hosts or relay state. Existing
  sighting/OpenMap evidence and Ask targets stay independent.
- Only Battle.net clubs from the first 20 subscribed entries, up to 1,000 member
  IDs each, 50 member-info reads per timer tick; up to 200 friends. Empty personal
  Find, combat, instance, or unreadable safety state prevents roster reads.
- TTL 660 seconds, cadence 300 seconds, per-name notice gap 600 seconds; the
  existing three-lines/ten-seconds chat window is shared, with no presence sound.

## Source evidence (not a native-client observation)

Forever `Gethe/wow-ui-source@bebcb6bf309cf41b41bd74f8ca651e6a105b2676`,
version `1.60.1.70938`, fetched read-only from the generated documentation.

| New read | Implementation call | Pinned declaration |
|---|---|---|
| `C_Club.GetSubscribedClubs()` | `LayerEnemies/Adapters.lua:24` | `ClubDocumentation.lua:779-786` |
| `C_Club.GetClubMembers(clubId)` | `LayerEnemies/Adapters.lua:43` | `ClubDocumentation.lua:433-447` |
| `C_Club.GetMemberInfo(clubId, memberId)` | `LayerEnemies/Adapters.lua:60` | `ClubDocumentation.lua:611-625` |
| `BNGetNumFriends()` | `LayerEnemies/Adapters.lua:74,77` (local function alias) | Plan's existing legacy global contract; optional at runtime |
| `C_BattleNet.GetFriendAccountInfo(i)` | `LayerEnemies/Adapters.lua:82` | `BattleNetDocumentation.lua:148-160` |

The club calls declare `SecretInChatMessagingLockdown` and require initialized
clubs. `ClubMemberInfo` declares the allowed fields at 1814, 1816, 1818, 1825,
1841. Its faction is numeric: `PvPFactionConstantsDocumentation.lua:13-14`
(Horde=0, Alliance=1). `ClubMemberPresence` is Online=1, Away=4, Busy=5 at
`ClubDocumentation.lua:1684-1688`. ClubType.BattleNet=0 at 1753.
The friend gate reads only `gameAccountInfo`, its `isOnline` and `wowProjectID`,
then `characterName`, `realmName`, `areaName`, `factionName`, `playerGuid`
(`BattleNetDocumentation.lua:495,516-533`). No account identities or notes.

Missing APIs/required fields, secret values and thrown namespace/function/field
reads fail silently. Refusals are counted without retaining the offending value.
Friend zones are deliberately excluded from the community-zone diagnostic.

## Decisions resolving plan assumptions

1. The explicit builder base overrides the plan's integration ordering: held UI
   and hop branches were not merged into this branch. The coordinator integrates
   them later; UI conflicts remain possible.
2. Existing OpenMap deliberately rejects bare-name/foreign-realm aliases, while
   PR 1 explicitly requires a bare tracked name to accept any realm. Its matcher
   now has a presence-only opt-in; the default and every old OpenMap test remain
   unchanged. Qualified presence entries remain exact.
3. Guild-shared lists contain hashes, not names or realms. Their roster matches
   are labelled **possible guild watch match**, with one current character per
   active shared hash, no saved-list edits and no Clear/Ask action. Withdrawal
   removes names but cannot reset the hash's 600-second notice gap. Shared lists
   alone do not bypass the explicit empty-personal-Find scan rule.
4. This is an unreleased feature PR, not a release: TOC/archive version remains
   1.1.0; README has `Unreleased - Battle.net community and friend presence`.

## Verification

- Baseline `python3 test/verify.py`: `RESULT: 1119 tests passed, 0 failed, 118428 assertions`.
- First tracer was observed RED before any presence production code, then GREEN.
  Additional slices exposed missing friend reads, incremental scheduling,
  diagnostics, UI, bare-realm matching and notifications before implementation.
- Final `test/harness.lua` and `test/presence.lua` copied into a detached worktree
  of the exact base, without any new production files:
  `RESULT: 0 tests passed, 20 failed, 839 assertions`.
- Candidate presence subset: `RESULT: 20 tests passed, 0 failed, 5874 assertions`.
- Full `python3 test/verify.py`: `RESULT: 1139 tests passed, 0 failed, 124321 assertions`.
  Syntax, static API/send policy, packaging, archive integrity/source parity,
  5,000 fuzz inputs, 11 verifier tests, 7 API-policy tests and 11 asset tests pass.
- `python3 test/presence_mutants.py`: **31/31 killed**, including all six plan
  mutants. Each compiles and fails its named behavioral assertion; isolated
  scratch copies leave source bytes alone. Baseline/final subset both pass.
  No surviving mutant required an extra test after that run. The shared-cooldown
  withdrawal regression was found in self-review, reproduced RED and fixed before
  adding its mutant. Details: `presence-mutants.json`.
- `git diff --check` passes. Author self-review only (no reviewer tool in this
  worker); independent coordinator review is still separate.
- Deterministic archive SHA-256:
  `d609f4b19cd9169f4d7e9405a75b67da20d159ba5dc4e8ae999865491eb8e4fc`.

## Not knowable here

**Not tested in game (alpha, owner's decision).** Whether opposite-faction
community character names, zones, factions and presence are populated without
subscriptions; actual server staleness; live chat-lockdown/initialization behavior;
Battle.net friend availability on the installed client; and actual native font
wrapping are unverified. The mock proves the code's boundaries, not the server's
ability to locate a player. No live-client test or capture is requested as a gate.
