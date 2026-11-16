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
