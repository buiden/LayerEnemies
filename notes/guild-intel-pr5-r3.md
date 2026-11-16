# Guild-intel PR 5: shared reserve and kill-ledger eviction

## Branch and implementation

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
