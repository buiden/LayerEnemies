# Guild-intel PR 1: session memory and group targets

## Commit 2: named session memory

- `Known.lua`: pure reducer, keyed by Find's folded name, two independently
  aged slots, 3600-second retention, at most 300 names. Input fields are copied;
  no enemy counts, kill counts, saved evidence or enumeration UI.
- Find retains named evidence across zone/layer/world boundaries and can show
  a first-hand line plus a reported claim. At age 600 it says `last known`
  and has no action; at age 3600 it is absent. OpenMap stays separate.
- Actual origin time is used for named records, including guild O age and
  Sentinel age. Only own/O evidence carries a server-layer claim.
- GBOUNTY/WALLOFSHAME deaths are named killer claims in any zone. No wire,
  relay, crowd, shared-watchlist, realm-parser or HeadHunter D changes.

### Rulings / ambiguities

- The delegated scope excludes the later-added realm-name section; `F.name`
  stays unchanged.
- The delegated five-source cache enum overrides the broader plan's
  `headhunter` source. Known accepts only own/guild/relayed/spy/death.
  Existing direct HeadHunter P/L retains its legacy ten-minute/boundary path
  outside Known (including priority over fresh relay claims), so it is not
  lost or mislabeled as Spy. Indirect HH envelopes/R lines use the existing
  relayed category. No HeadHunter D decoding or new cache source is added.
- A first-hand cache slot includes own, O and direct Spy evidence;
  relays/envelopes and killer claims use the reported slot. O is not a relay
  merely because it arrives via the guild dispatcher.
- The newest surviving slot determines a name's eviction age. Each slot
  expires independently; a very old arrival cannot displace newer memory.
- `>=600` is last-known/action-disabled; `>=3600` is expired. Hash-only War
  Effort findings keep their old ten-minute/boundary behavior.
- Own observations carry a session epoch in addition to the specified fields:
  retaining a historical server claim cannot assert today's layer after a
  boundary. Learning an initially unknown layer never upgrades old evidence.
  The existing own-name/realm metadata is also retained to preserve matching
  on a later add, without changing the parser.
- A fresh first-hand entry is the action/alert summary; otherwise the newest
  entry is. Both lines remain visible, with independent ages and zones.
- Removing a tracked name hides its evidence, not the bounded session cache.
- The accepted section 4 wording is implemented directly. Native rendering
  and client API behavior are not certified by the mocked UI harness.

### Red / green

- Initial test-first run against detached `e2b35cb`: **697 passed, 15 failed**.
- Additional idle-pruning regression before its fix: **713 passed, 1 failed**.
  Initial P/L coverage was green when added. Final scope review tightened
  it to reject a HeadHunter cache source: **713 passed, 1 failed** before
  the correction. Preserving legacy P/L/relay priority then kept all old
  direct/relay tests green.
- Final commit-2 tests replayed against detached `e2b35cb` (only tests copied):
  **689 passed, 25 failed**: 17 new cases plus 8 intentional old-expectation
  migrations. Missing cache/module entrypoints are expected base failures.
- Commit-2 green after restoration: **714 passed, 0 failed, 66513 assertions**.
- `test/guild_intel_mutants.py` restores every edit in `finally`. The first
  attempt exceeded its 180-second process budget after the six mutant results;
  a full rerun with 600 seconds completed, including restored green.

| Commit-2 mutant | Failed tests |
|---|---:|
| boundary wipes memory | 8 (before the source-scope correction) |
| retention unbounded | 6 |
| name cap unbounded | 1 |
| ask relayed claim | 21 |
| ask last-known entry | 3 |
| cache saved | 3 |

### Existing tests whose expectations / fixtures changed

All other existing tests, including the Find20 operation budgets, are retained.

| Existing test (name preserved) | Change and reason |
|---|---|
| Find match, no match, collisions, expiry, own sighting and alerts | Named own evidence survives a boundary, but loses same-layer certainty. Hash expiry unchanged. |
| relayed origins never become Find spotters (مانع T6 F1) | Direct line uses the specified capitalized `Seen by`; relay identity/action refusal unchanged. |
| previous zone 17: carried rows never become sends, Find locations, maps or actions | Independent named Find memory survives the crossing; no sends, maps or actions from carried Store rows. |
| OpenMap tiers 1 sighting only: frozen legacy row fields stay identical | Compare the legacy action projection and assert the new seen slot separately; source/slot metadata is intentionally additive. |
| OpenMap tiers 3 both same zone: sighting owns fields, place has its own age | Comparison fixture now shares Known memory as well as the old location projection. |
| OpenMap tiers 4 conflicting zones and ages stay separate in text and UI | Named ages at 60 seconds use `1 min` as specified; OpenMap keeps its own seconds/zone. |
| OpenMap tiers 7 independent 600 and 150 second expiry falls back either way | At 600, named evidence is last-known, not erased; comparison fixture also shares Known memory. |
| OpenMap tiers 8 ten-minute place stream never refreshes a sighting or calls findAlerts | At 600 the unchanged observation time remains, action-disabled; no OpenMap refresh or alert. |
| OpenMap tiers 9 L0 clears only place; layer boundary clears only sightings | Boundaries retain named evidence and place; zone change disables the sighting action. |
| OpenMap UI pool reuse hides stale places and drops former sighting actions | Use actual 3600-second expiry, not a boundary wipe, to test recycled actions and place-only state. |

## Commit 3: party and raid targets

- Register `UNIT_TARGET`; only sanitized `party1`–`party4` / `raid1`–`raid40`
  member payloads enqueue target tokens. Require visible member and confirmed
  non-instance status at enqueue and again at drain; unknown states fail closed.
- Reuse the unit queue, Store/Find own-sighting path and existing share behavior.
  Both party and raid targets use the requested `own (party target)` label.
- Expand the queue bound from 42 to 86 (42 old tokens plus 44 group targets).
  Include group targets in stale-GUID quarantine at boundaries, so pre-transfer
  unit data cannot be reported as a fresh post-transfer sighting.
- Nine test-first cases failed on the pre-party implementation. Replayed against
  the final commit-2 head with only the new tests: **714 passed, 9 failed**.
  Positive controls in refusal tests avoid vacuous passes from a missing event.
- Final restored harness: **723 passed, 0 failed, 67382 assertions**.
  No existing expected values changed in commit 3.
- Updated API evidence pins Forever `1.60.1.70938`; declarations alone do not
  establish client delivery, readability or permissions.

### Final mutation run (all source restored in finally)

| Mutant | Failed tests | Representative detecting test |
|---|---:|---|
| boundary wipes memory | 7 | Known 1 / Known 4 |
| retention unbounded | 6 | Known 2 / idle pruning |
| name cap unbounded | 1 | Known 14 bounded 300-name cache |
| ask relayed claim | 21 | relayed origins never become Find spotters |
| ask last-known entry | 3 | Known 2 |
| cache saved | 3 | Known 14 cache stays out of every saved table |
| invisible member observed | 2 | invisible/unreadable member + drain recheck |
| target observed inside instance | 2 | instance/unreadable instance + drain recheck |
| secret unit accepted | 1 | secret unit payload guard |

Runner: `python test/guild_intel_mutants.py --lua <lua-5.1-executable>`.
All nine mutants reached the test-result line, exited 1 and failed assertions;
none was counted merely for a syntax failure. Restored run exited 0.

## Native validation still required

Forever event delivery and target readability are not established by these
unit mocks. Visual wrapping/clipping of long two-line cards is not tested in
a native client. No installation or live-client action is performed here.

## Section 4.3: realm names in Find

### Test-first checkpoint and rulings

- Unmodified `2077d33`: **723 passed, 0 failed, 67382 assertions**.
- Only the new realm tests and their harness loader copied onto detached
  `2077d33`: **724 passed, 45 failed, 70631 assertions**, exit 1. The new
  legacy-parser oracle passed; missing grammar/matching/flags caused the reds.
- Rule 1's explicit backward-compatibility requirement takes precedence over
  its tighter new-form bounds: old accepted apostrophes, trailing hyphens,
  long single words and long alphabetic realms retain identical return values.
  The 36-byte word and 40-byte realm limits apply to newly accepted spellings.
- Single-word own sightings retain the old exact-display/first-name/hash
  comparison, even when display and second-return realm disagree. Two-word
  sightings use only a suffix on the display name as realm evidence, never
  the second return (which can be the surname).
- Hash-only matches cannot confirm even a home realm: they stay possible and
  carry the uncertainty note when the tracked entry is qualified. The home
  exemption applies to realm-less named evidence, not anonymous hash matches.
- Known remains a source cache, not a tracked-identity cache. Find applies the
  same per-entry matcher on receipt and read; uncertainty is a row property.
- No live-client claims: the true realm availability for surname characters
  and `UnitName` representation on build 70938 remain unknown.
- Follow-up edge tests first failed **769 passed, 2 failed**: newly learned
  home realm must update the separate named HeadHunter path, and a hash must
  not override a name's explicitly contradictory realm. Both then passed.
- Final tests (including the two intentional expectation changes below)
  replayed with only tests copied onto detached `2077d33`: **722 passed,
  49 failed, 70470 assertions**, exit 1. That is 47 new failing cases plus
  two intentionally changed old cases; the legacy parser oracle stays green.
- Green: **771 passed, 0 failed, 71244 assertions**.

### Existing tests whose expected values changed in section 4.3

Exactly two. All original `F.name` expectations, own-sighting comparisons,
operation budgets, collision behavior, and OpenMap tests are unchanged.

| Existing test | Change and reason |
|---|---|
| `Find20 matching preserves legacy aliases, realm checks, collisions and precedence` | Extend only the named-report oracle: an unqualified tracked base now accepts any reported realm (Rule 2). The frozen own oracle is unchanged. |
| `Call review: Find keeps its existing two-word realm limitation` | Renamed to `Call review: Find accepts realm-qualified two-word killers`; the Help click now adds exactly the displayed qualified killer instead of leaving Find empty (Rule 5). Popup admission and no-send checks remain. |

The `no-realmless-name-alias` Find20 mutant is retargeted to the new base-only
index: replace its base key with the full key to recreate the same missing
alias defect. Its kill criterion is unchanged. The pre-existing
`missing-status-stays-tall` target was stale after Known's variable detail
heights; it now changes only the missing-row height in the current expression.

### Review and execution notes

- Final review: self-review (no independent subagent tool). Checked parser
  compatibility precedence, normalized per-entry matching on both receipt and
  cache projection, single-word own exceptions, named/hash separation, popup
  add/save flow and unchanged transport/SavedVariables scope.
- One mutation target initially matched two sites; it was narrowed to the
  Known read loop. A foreground full run then hit the tool's 420-second limit;
  its interrupted mutation was explicitly restored before rerunning. The
  complete runners use a tracked background process and source-hash restoration
  checks, not partial output as a pass. No survivor was treated as killed.

### Completed mutation evidence

All **17/17 guild-intel** mutants and **11/11 Find20** mutants were killed by
assertion failures, not syntax errors. Every target was preflighted as unique
and syntactically valid. Both runners restore source in `finally`; a separate
SHA-256 comparison confirmed all mutated source files were restored byte for
byte. The restored harness reported **771 passed, 0 failed, 71244 assertions**.
No new case had to be added to kill a surviving mutant.

| Section 4.3 mutant | Failed tests | Representative detecting test |
|---|---:|---|
| realm ignored when both sides have one | 13 | different explicit realms never match (all named sources) |
| surname includes `-Realm` | 1 | surname hashes use the base and never a typed-realm home tuple |
| realm warning dropped | 7 | realm-less evidence marks foreign realm unknown |
| home-realm exemption removed | 12 | home realm needs no unknown note |
| digits refused in realm | 16 | new forms normalize only the realm and preserve typed case |
| Known cross-realm leak | 11 | Known rejects cross-realm memory before and after adding |
| named hash ignores contradictory realm | 1 | a hash cannot override an explicitly different named realm |
| HeadHunter late-home warning stays stale | 1 | late home discovery removes the named HeadHunter uncertainty only |

Only `Find.lua` and the named-detail text in `Main.lua` change in production.
The popup's existing `callHelp` add/save path is unchanged and exercised via
both direct receive and the real GBOUNTY dispatcher. `Known.lua`, `Wire.lua`,
`Share.lua` and `OpenMap.lua` are byte-identical to `2077d33`. No SavedVariables
field, dependency or send is added.

The full verification gate (`uv run --no-project --python 3.14 --with lupa==2.8
python -I test/verify.py`) exited **0**, with **771 passed, 0 failed, 71244
assertions**. Lua syntax, static/API policy, archive integrity and source
parity passed. The deterministic archive hash is recorded in
`notes/verification.json`; generated results are committed separately from
this feature. Native-client verification remains false.
