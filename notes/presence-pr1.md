# 1.2.0 PR 1 — read-only Battle.net presence

Implementation commit: `b0d7aa1d7296d09a4c43cc74270249563bcd15be`.
Base: `d9f0a71262d35cc59f1292757ed266ca08680eb9` (main, 1.1.0).
Branch: `feat/bnet-presence`. Local only; origin push URL is `DISABLED`.

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
