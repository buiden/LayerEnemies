# Guild-intel PR 5: shared reserve and kill-ledger eviction

## Combat reserve correction (supersedes the earlier two-line ruling)

Merged PR 4 head `d7da5dba85c96858764051353d81213d1a3e9f06` into `open-gi5-r3` in local merge commit `0e6bd2b8ec08b72401d989b7f0ec8378bdbec2bd`, with starting head `9efad902bed81fd3406a87825299940307d8d7c6` as first parent. PR 4 came from a local-filesystem fetch because these are separate repositories. Only generated verification notes conflicted; they are regenerated and committed separately. Backup ref `backup-open-gi5-r3-before-combat-reserve` retains the old head. No push, GitHub write or install.

All relay families, including kills, use the same unchanged shared path. The only runtime delta from the starting head is removing the combat multiplier from `Relay.spend`'s two-token prefix reserve. It protects two own lines in peace, **one in combat**; combat relays can send when at least four tokens are available and other limits allow. Keep guild-minute reserves of three peace/two combat slots, every rate/age/dedupe/ledger limit, share-off and drop-without-queue behavior. `Wire.lua`, `OwnDeath.lua`, and `test/verify.py` are byte-unchanged. README documents relay -> K -> O losing O in combat.

### Test-first and full verification

- Added a full-bucket combat kill-forward test and 300-second sustained combat cases at 1/s and 1/4s, retaining own O=5/5. Restored the two inherited combat burst expectations from zero relays to one. The final tests were replayed against untouched starting production in a detached worktree: **50 passed, 5 failed, 4682 assertions**. All failures are missing combat relays; after the merge: **55 passed, 0 failed, 4808 assertions**.
- One initial test wrongly demanded a positive kill subtotal under mixed traffic, rather than positive total forwarding; the unchanged reviewer probe proves that stronger fairness assumption does not hold. Keep the full-bucket and kill-only positive-send checks. A second fixture issue inspected pending work before the final input's existing due+0.05s callback; advance 0.1s after the 300-second counts before checking pending emptiness. Original failed GREEN and corrected detached RED logs are retained. No production timing or limit change.
- Policy mutants **4/4 killed**; kill mutants **20/20 killed**, including restoring the oversized combat reserve (five kill-test failures); Spy mutants **7/7 killed**. Source restored and clean reruns pass: policy **23/0/2200**, kills **55/0/4808**, Spy **22/0/1852** (passed/failed/assertions).
- `python3 test/verify.py`, foreground, Lua 5.1.5: exit 0, **RESULT: 1040 tests passed, 0 failed, 99407 assertions**. Syntax/API policy, strict send gate, media/TOC/package integrity/source parity and diff whitespace checks pass.
- Archive SHA-256: `a7745dd84bcb7edb96378d0708850c2e79e62ba8d52e6e669502044efff5c806`.

### Reviewer probes

All **24 p2 sustained modes**, rerun on PR 5, match PR 4: O=5/5, zero refusals, with R=0 in every relays-off control. Relays-on results for 300 seconds:

| Family/cadence | Peace O / R | Combat O / R |
|---|---|---|
| HH, 1/s | 5/5 / 80 | 5/5 / 35 |
| HH, 1/4s | 5/5 / 75 | 5/5 / 35 |
| Spy, 1/s | 5/5 / 26 | 5/5 / 10 |
| Spy, 1/4s | 5/5 / 30 | 5/5 / 29 |
| mixed, 1/s | 5/5 / 80 | 5/5 / 35 |
| mixed, 1/4s | 5/5 / 30 | 5/5 / 29 |

`p2 kafter`: peace K=1/O=1/R=3, no refusal; combat K=1/O=0/R=1, one O refusal (accepted known limit). `p2 off`: zero guild sends; only fresh O and WE Q after enabling. No runtime errors.

| rp2 mode | Own O | R | Kill R | O refusals |
|---|---:|---:|---:|---:|
| Mixed HH 1/s, peace | 5/5 | 80 | 9 | 0 |
| Mixed HH 1/s, combat | 5/5 | 35 | 0 | 0 |
| Kill-only 1/4s, peace | 5/5 | 20 | 20 | 0 |
| Kill-only 1/4s, combat | 5/5 | 15 | 15 | 0 |

**Remaining limit:** mixed 1/s combat forwarding is active, but its kill subtotal is still zero. A separately instrumented private copy records 130 kill-budget refusals, 10 guild-reserve refusals and 10 prefix-reserve refusals. The four-attempt cap charges before shared admission; no relay-family fairness is promised. Kill-only combat sends 15, and a fresh full bucket sends one kill. Kept the owner's other-limit constraint rather than adding priority or changing charging. README records this distinction.

Unchanged `rp2` ledger/share-off probes: 260 direct kills at 12s show all 260/R=207; 300 guild kills at 1s show all 300/R=0; 300 direct kills at 0.2s show all 300/R=3. Both later new kills are visible in each case. Share off before receipt/during wait gives zero guild sends and zero replay after enabling, while local kills remain shown.

Evidence: `/opt/data/cache/scratch/gi-r3-evidence/combat-one-own/`, including `pr5-probe-results.json`, unmodified reviewer wrappers, traced-copy outcome logs, detached RED replays, mutant logs and full verify output. The p2 snippet and rp2 original are unchanged; p2 uses the previous builder's shared harness prefix.

Files changed from the old PR 5 head: `LayerEnemies/Relay.lua`, `README.md`, `test/relay_policy.lua`, `test/relay_policy_mutants.py`, `test/kills_round1.lua`, `test/kills_round2.lua`, `test/kill_mutants.py`, inherited PR 4 note, this note, `notes/test-results.txt`, `notes/verification.json`. No other runtime file changed. Final review: self-review (no subagent tool); independent review remains the parent's lane. Native checks not run (alpha, owner's decision).

## Earlier round-2 branch and implementation (historical)

`open-gi5-r3` starts at PR 4 result `a342c7f672b06edf99d42b0c53410e26e800655a`. Merge `5fce2fe66b7d68ff5ed469dbf81ad011c824c23c` has that first parent and original `open-gi5-fix` head `586e114c2d39ed554087a6074764a627bbe105db` as its second parent. The old branch is unchanged. Ledger fix: `258bb66acd55c3ac4521698e19a3bf783bff98e5`. Local commits only; no push, GitHub write or install.

- There is **one** reserve: PR 4's `Relay.spend`. O/K/F/H keep their existing accounting; kill, legacy HH, WE and Spy R lines all pass through it. Removed `noteSend`, `prefixBucket` and `relaySpend`, not merely their callers. Kill-specific four-attempt/rolling-minute and per-killer limits remain before shared admission. Share-off, age retention, retained-id once-only handling and self/victim rejection remain covered.
- Ledger still holds at most 256 ids for 3900 seconds, without replay renewal. First prune expired ids, then evict the oldest admission when a new id needs room. Original claimed event time does not determine eviction order; equal admission times break ties by key. New valid kills stay visible; a duplicate of an evicted id may relay again subject to all existing limits.
- No new change to `Wire.lua` or `OwnDeath.lua` relative to PR 4. Wire contains only PR 4's read-only minute-count/cap accessor, with no send-path change. `test/verify.py` is unchanged from both starting branches.
- PR 4's combat ruling remains: preserve two own lines (four prefix tokens). The unchanged five-token bucket cannot also fit a double-cost combat relay; those R lines are dropped, not queued. Local receipt is unaffected. See `notes/guild-intel-pr4-r3.md` for all p2 mode figures and that tradeoff.

## RED -> GREEN

Two new tests ran against untouched original PR 5 before merging: **0 passed, 2 failed, 102 assertions**, then **2 passed, 0 failed, 115 assertions** after the shared implementation:

- `Kills R2 reserve: kill dispatch uses the shared spend gate` (gate calls 0 -> 1; denied kill sends 0).
- `Kills R2 reserve: kill relays leave the guild-minute own slots` (kill R sends 1 -> 0 after 17 actual WE guild sends; own O still sends).

Three ledger tests ran before the ledger fix: **2 passed, 3 failed, 498 assertions**, then **5 passed, 0 failed, 527 assertions**. The final tests were also copied into a detached merge-head worktree and reproduced the same three RED failures:

- `Kills R2 ledger: new kill stays visible after 260 direct kills at five per minute`.
- `Kills R2 ledger: new kill stays visible after 300 guild kills at one per second`.
- `Kills R2 ledger: overflow evicts the oldest admitted id and prunes expiry first`.

The two traffic tests also assert every valid input is displayed on arrival, late kills relay after budgets recover, and the ledger remains bounded. The deterministic ledger case distinguishes admission order from claimed event age, preserves retained duplicate age/expiry and tests the exact expiry boundary.

Test fixture correction: initial late-kill names had three words and correctly failed the existing player-name grammar after eviction worked; changed only those synthetic names to valid two-word names. Detached RED replay and the overflow mutant confirm the corrected cases still catch the real bug.

Inherited tests retained with explicit owner-authorized expectation changes: two combat relay counts 1 -> 0 (own O still 1), reserve mirror constants read from the shared implementation instead of deleted PR 5 exports, and the old overflow-refusal test now requires visible overflow and permits the evicted duplicate. No limits or timing windows were loosened.

## Reviewer probes

Copied `gi5/rp2.lua` unchanged into scratch and ran from each repo root. Its first ledger log label is hardcoded "300 ... 60 s" even for other parameters; this table gives the actual NK/GAP inputs.

| Probe | Original PR 5 | Composed result |
|---|---|---|
| 260 direct kills, 12 s apart | shown=256, R=204; new kill +600s=false, +1000s=true | shown=260, R=207; both late kills=true |
| 300 guild R kills from one carrier, 1 s apart | shown=256, R=0; both late kills=false | shown=300, R=0; both late kills=true |
| 300 direct kills, 0.2 s apart | shown=256, R=3; both late kills=false | shown=300, R=3; both late kills=true |
| Sustained mixed HH, 1/s, peace | O=2/5, R=98, killR=10, 3 refusals | O=5/5, R=80, killR=9, zero refusals |
| Sustained mixed HH, 1/s, combat | O=2/5, R=48, killR=6, 3 refusals | O=5/5, R=0, killR=0, zero refusals |
| Sustained HH, 1/4s, peace/combat | O=5/5 both; R=20/15 | O=5/5 both; R=20/0 |
| Share off before/during | no guild sends, local kill shown | unchanged; no held replay after enabling |

All PR 4 `p2.lua` modes were also rerun on this composition: HH/Spy/mixed, 1s/4s, peace/combat, relays on/off all give O=5/5 with zero refusals; K-after-relays sends K=1/O=1 in both modes; share-off gives zero guild sends. No runtime/probe errors.

## Mutation and full verification

- `python3 test/kill_mutants.py --lua /opt/data/tools/lua/lua-5.1.5/src/lua`: **19/19 killed**, all compile, original bytes restored, clean rerun **52 passed, 0 failed, 4555 assertions**. The new shared-reserve bypass mutant fails both new reserve tests; restoring full-ledger refusal fails all three new ledger tests. Old mutants were mechanically retargeted to the retained shared reserve/cancellation seams, not dropped.
- `python3 test/relay_policy_mutants.py`: **4/4 killed**, clean 22-test rerun.
- `python3 test/spy_mutants.py --lua /opt/data/tools/lua/lua-5.1.5/src/lua`: **7/7 killed**, clean 22 tests, 0 failed, 1852 assertions.
- `python3 test/verify.py` in the foreground: exit 0, **RESULT: 1036 tests passed, 0 failed, 98680 assertions**. Strict send gate unchanged and passing, plus syntax/API policy, TOC/media package integrity/source parity and `git diff --check`.
- Archive SHA-256: `cb9fe01b57d24bff4756e1be8e5aef7347bfabf3f281f32b46426b5f1fd4291e`.

Evidence: `/opt/data/cache/scratch/gi-r3-evidence/` (before/after reviewer logs, shared and ledger RED/GREEN logs, detached RED replay, mutant logs, full verification). Regenerated verification notes are committed separately from source/tests.

## Files and review

Incremental to the PR 4 result, the combined PR 5 contains:

- Addon: `Find.lua`, `HeadHunter.lua`, `Known.lua`, `Main.lua`, `Record.lua`, `Relay.lua` under `LayerEnemies/` (the first five retain PR 5 behavior; Relay combines both lanes and eviction).
- `README.md`; `test/harness.lua`, `test/kill_mutants.py`, `test/kills.lua`, `test/kills_round1.lua`, new `test/kills_round2.lua`, `test/known.lua`.
- Retained `notes/guild-intel-pr5.md`, this note, regenerated `notes/test-results.txt`, `notes/verification.json`.

Relative to old PR 5, it additionally inherits PR 4's Hosts/Main/OwnDeath/Relay/Spy/Store/Wire updates, Spy/policy tests and PR 4 notes. No second reserve remains. Guildmate/nearby-ally killer acceptance and the other explicitly deferred notes are unchanged.

Final review: self-review (no subagent tool); independent review remains the parent's lane. Native checks not run (alpha, owner's decision). No claim of live-client verification.
