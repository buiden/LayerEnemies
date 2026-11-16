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

## Round 1 fixes

Review baseline: `a61d86d0265ef108f67c9f0e4d6cefe94b2dadd5` on `16549ca`.
Only follow-up commits on `gi-pr1-find20`; no push, rewrite, new send or saved
field. The other PR branches and the reviewer's files are untouched.

### Changes and regression evidence

All regressions were added before their fixes and run with only the updated
Lua tests copied into a detached clone of the review baseline. The unchanged
baseline was **771 passed, 0 failed, 71244 assertions**. With the complete
new test set on that baseline: **772 passed, 13 failed, 71893 assertions**.
The extra passing case checks index lifecycle behavior that already worked
through the old full scan; it is not counted as a red regression.

| Finding | Red on the review baseline | Correction |
|---|---|---|
| Own realm collision | `1234/84860` and `Home/ochg` both matched the wrong tracked identity; folded non-ASCII own realms did not match | Compare normalized, folded realm strings, not three-character hashes. Same-realm positives, late tracking and every inherited realm test pass. The existing alphabetic collision is intentionally closed too. |
| Poll cost | 20 tracked names, 300 cached names: **6600 entry visits** in one poll | Known indexes folded bases and own first-name aliases. A steady poll with five matching entries uses **20 lookups + 5 visits**. Expiry deadlines avoid repeated prune scans; an expiry or clock rollback performs one bounded maintenance scan. |
| Own displaced by O | Newer guild O removed own primary status; own history was also lost in another zone | Keep own and newest other evidence within the two-entry bound. Under 600 seconds in the current zone, own is primary; guild observations retain `kind=seen`, their source, age and layer claim. Both arrival orders and tracking before/after receipt pass; 599/600-second and cross-zone controls pass. |
| Hidden Ask evidence | HashScout was Ask-eligible but absent from the displayed text | Show current possible-match evidence, spotter, zone and age alongside last-known named lines in chat and UI. Its 600-second expiry is independent. |
| Long own display | Legacy 72-byte first name with a 103-byte adapter display was not located | Own display limit is 321 bytes (two bounded 160-byte adapter strings plus a space); external cache names remain at 100. Tests cover 30/160-byte second returns, late tracking, 321/322-byte bounds and retention. |
| Raid self label | The player's raid token was queued and could overwrite `own target` | Require an existing, visible, confirmed non-player member at queue and drain. Our own target keeps its original label in either event order. |
| Optional queue guards | A silent retarget named the replacement; visible-but-nonexistent member supplied evidence | Snapshot the readable target GUID and recheck it at drain; a new event can replace the snapshot. Recheck member existence. Both are covered by regression tests and mutants. |

The hash-display change also exposed an oversized card: current hash evidence,
both cached lines and an independent OpenMap position could exceed one page.
A further test failed on `626415c` (**784 passed, 1 failed**) before fixing it.
Find now grows just enough for a complete card and moves its footer controls;
other tabs restore the original height. OpenMap data and actions are unchanged.
The mock verifies all lines, position and Ask remain visible, not native font
wrapping or visual fidelity.

No existing test expectation or fixture was changed. `test/harness.lua` only
loads the new `test/round1.lua`; the four inherited PR-1 test files and the
Find20 mutation runner are byte-identical to the review baseline. All earlier
realm/oracle, hash-collision and OpenMap checks remain green. The legacy exact
own-display match is retained; the lossy first-name realm comparison is what
changed.

### Verification and scope

Native Lua 5.1.5 and the full isolated Python 3.14 / lupa 2.8 gate both report
**785 passed, 0 failed, 72650 assertions**; verify exit **0**. Syntax,
static/API policy, packaging, archive integrity and source parity pass.
Archive SHA-256: `597e7a85b67addc7bc79eb9b18e526fe7703275b4548520fc0b6df8fad7de388`.
Generated verification files are committed separately after these notes.

`Wire.lua`, `Share.lua` and `OpenMap.lua` are byte-identical to the review
baseline. Production SavedVariables assignment-set additions: **none**.
No send call or route is added. The 300-name / two-entry / 60-minute bounds,
anonymous hash uncertainty and independent OpenMap lifetime remain in force.
Native checks: **not run (alpha, owner's decision)**; no install or client
capture requested.

### Reviewer probes (same code as the final verification head)

The review scripts and boot harness were copied, unchanged, into private
scratch next to detached throwaway clones. `run_checks.py <tree> <probe>`
ran collisions, behavior, limits, matching and groups; `p1.lua` / `p2.lua`
ran from each tree root with that root as argument. The matching differential
script consumed the actual output logs. All exited 0.

| Probe / relevant line | Review baseline | Fixed code |
|---|---|---|
| collisions: `NUMERIC_OWN` | `admitted=true matched=true` | `admitted=true matched=false` |
| collisions: `NUMERIC_REPORT` | `matched=false` | `matched=false` |
| collisions: `LEGACY_COLLISION` | `tracked=Home evidence=ochg matched=true` | `tracked=Home evidence=ochg matched=false` |
| behavior: `HASH_AFTER_OLD` | `primary=HashScout ask=true`, only `last known: Seen by you ... 11 min ago` displayed | Same primary/Ask, now `possible match, seen by HashScout ... 0 s ago` **and** the old own line |
| behavior: `PERSIST` | `leak=false reloadLocation=false` | Unchanged; configuration keys unchanged |
| limits: `LONG_OWN` | `saved=1 match=false` | `saved=1 match=true` |
| limits: `CACHE` / `RETENTION` | 300 names, older arrival rejected, oldest eviction, zero at 60 minutes | Unchanged |
| limits: receive `COST` | `reports=2 tracked=20 hashes=0 indexReads=60 stable=true` | Unchanged |
| matching vs review baseline | 980 matches | 980 matches; **0 losses, 0 additions** |
| matching vs main | 719 matches | 980 matches; **0 losses, 261 additions** (the already-reviewed realm extension) |
| groups: `retarget` | `queued=true named=Birch Grove store=1` | `queued=true named= store=0` |
| groups: `member-exists-false` | `queued=true named=Cedar Vale store=1` | `queued=true named= store=0` |
| groups: positive party / raid40 | `named=Cedar Vale`; raid `source=own (party target)` | Unchanged |
| p1: `OWN then guild O +1s` | `at=12 spotter=DirectScout ask=true uiAsk=true`; own line absent | `at=11 spotter=you ask=false uiAsk=false`; `is on YOUR layer` and guild layer claim both displayed |
| p1: `COST findRows` | 8.97 ms | 0.02 ms |
| p1: `COST M.poll` | 8.54 ms | 0.10 ms |
| p2: poll at 20 tracked / 300 cached | **8.46 ms**, one F.rows call | **0.11 ms**, one F.rows call (main's five-name-cap control: 0.09 ms) |
| p2: untracked guild message | 0 F.rows calls, 0.08 ms | 0 F.rows calls, 0.10 ms |
| deterministic poll spy | 6600 visits, 0 indexed reads | 5 matching visits, 20 indexed reads; repeated poll identical |

Timings are local `os.clock()` measurements, not client FPS claims. All
behavior-order/action, limit/alert and group refusal output lines are otherwise
unchanged except the listed fixes. The original p1 `RAIDSELF` fixture does not
mark raid3 as the player: its boot mock only considers identical token strings
equal. Its label therefore stays `own (party target)`. A separate copy changes
only that fixture's `UnitIsUnit(raid3,player)` result to true: before, the party
target suffix is present; after, it is absent. The committed tests also assert
`detail=own target`, absence from the group queue and both event orders.
The reviewer's original files were not modified.

### Round-1 mutation results

Both complete runners exited 0 on separate detached copies of the final code:
**27/27 guild-intel** and **11/11 Find20** killed. Every mutant reached a
`RESULT` line, exited 1 and failed assertions; none was credited for syntax
failure. Production Lua SHA-256s matched the unmutated tree afterwards, both
copies were clean, and the restored guild-intel harness was **785/0/72650**.
No surviving mutant required a new case. Earlier runs on the pre-card-height
revision were deliberately stopped and are not used as completion evidence.

| Suite | Mutant | Failed tests |
|---|---|---:|
| guild-intel | own-realm-hash-equality | 3 |
| guild-intel | known-full-scan-restored | 1 |
| guild-intel | known-prune-every-poll | 1 |
| guild-intel | guild-displaces-own | 2 |
| guild-intel | current-hash-line-hidden | 2 |
| guild-intel | long-own-display-dropped | 2 |
| guild-intel | raid-self-relabelled | 2 |
| guild-intel | group-member-existence-ignored | 1 |
| guild-intel | group-retarget-snapshot-ignored | 1 |
| guild-intel | hash-detail-card-hidden | 1 |
| guild-intel | boundary-wipes-memory | 8 |
| guild-intel | retention-unbounded | 8 |
| guild-intel | name-cap-unbounded | 2 |
| guild-intel | ask-relayed-claim | 21 |
| guild-intel | ask-last-known | 3 |
| guild-intel | cache-saved | 4 |
| guild-intel | party-member-invisible | 2 |
| guild-intel | party-target-in-instance | 2 |
| guild-intel | party-secret-unit-accepted | 1 |
| guild-intel | realm-ignored | 13 |
| guild-intel | surname-includes-realm | 1 |
| guild-intel | realm-warning-dropped | 7 |
| guild-intel | home-realm-exemption-removed | 12 |
| guild-intel | realm-digits-refused | 18 |
| guild-intel | known-cross-realm-leak | 11 |
| guild-intel | named-hash-realm-conflict-ignored | 1 |
| guild-intel | headhunter-late-home-warning-stale | 1 |
| Find20 | rebuild-every-report | 2 |
| Find20 | cap-back-to-five | 9 |
| Find20 | saved-list-no-dedupe | 4 |
| Find20 | track-prints-all-rows | 1 |
| Find20 | no-sound-cooldown | 2 |
| Find20 | no-detail-line-limit | 1 |
| Find20 | overflow-not-counted | 1 |
| Find20 | no-realmless-name-alias | 16 |
| Find20 | located-oldest-first | 3 |
| Find20 | missing-status-stays-tall | 2 |
| Find20 | no-home-poll-rebuild | 1 |

### Unchanged limits

- A flood of 300 newer names can still evict an older tracked sighting. This
  is the requested oldest-first global cap, not a tracked-name pinning policy.
- The synthetic group probe that marks only the derived member-token string
  secret after enqueue still observes it, on both revisions. The target token,
  member API results, target GUID and target fields remain guarded. Native
  token secrecy/visibility/event semantics are not established by these mocks.
- Direct HeadHunter P/L remains outside Known in this PR. The separately noted
  stale **Reported-tab** Hop behavior is outside these Find fixes; neither
  path's action policy was changed.
