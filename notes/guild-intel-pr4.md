# Guild-intel PR 4: Spy relay

Spy-family sightings from party/raid are now relayed to the guild. This reverses the earlier lane C1 "never relayed" rule; donor prefixes remain receive-only.

## Scope and baseline

- Branch: `gi-pr4-spy`, stacked on `a61d86d0265ef108f67c9f0e4d6cefe94b2dadd5` (PR 1).
- PRs 1, 2 and 3 remain untouched. No push, install, or client action.
- Baseline Lua 5.1 harness: 771 tests passed, 0 failed, 71244 assertions.
- Target remains the existing Forever addon, TOC 16001. No new client APIs.
- Requirements: plan A7/A13, 5.2, 6, 8 cases 7–10 and PR split row 4.

## Decisions and integration checks

- Receiving `R|1|spy|seen` uses Known source `relayed`, not `spy`: PR 1 uses `spy` for a directly heard observer and `relayed` for an untrusted third-party claim. Existing Find ask/hop gates remain unchanged.
- All three family sources normalize only on the guild wire to `spy`; local rows keep their donor labels. The parser's enemy hash must not replace the named enemy in the relay.
- Group-only Spy input becomes relay-eligible (`share=public` record metadata); GUILD remains `share=guild`. This does not enable any public-network send, donor-prefix send, route or recipient.
- Shared interface: Main offers parser records; Relay supplies stable family-normalized keys so guild copies cancel pending sends. Existing Wire forward sends remain nonqueued.
- Ruling: Spy parser formats carry no faction/friendly flag. Preserve parser checks and self-identity refusal; do not infer faction from race or claim that incoming enemy assertions are independently verified.
- Ruling: caps apply to dispatch attempts in a rolling 60-second window, including local Wire refusals, with preflight refusal too. A stand-down spends no send allowance. This is stricter than successful-send-only accounting and cannot burst across minute boundaries.
- Ruling: retain Spy's stable observer/enemy identity for stand-down, use a 60-second Spy dedupe window, and allow newer relayed Spy sightings to refresh the same row. Otherwise the generic 120-second dedupe and duplicate store path suppress permitted fresh evidence. Older copies must not regress the row.

## Tests and verification

- Initial test-first RED on a detached `a61d86d` worktree, with only new tests/harness copied in: `RESULT: 773 tests passed, 17 failed, 72506 assertions` (rc 1). All 771 inherited tests passed.
- Three additional coverage cases (all-family stand-down, cross-zone delivery, simultaneous-name/clock/memory bounds) were added after the first implementation; they passed the unmutated candidate immediately. The final complete test set replayed on a fresh detached base gives `RESULT: 773 tests passed, 20 failed, 72632 assertions` (rc 1). Do not count those three as initial test-first failures.
- GREEN full Lua 5.1 harness: `RESULT: 793 tests passed, 0 failed, 73102 assertions` (rc 0).
- Focused runner: `lua test/harness.lua --spy-relay-only` gives 22 passed, 0 failed, 1853 assertions. The default harness and verification gate still run every test.
- Gate: `uv run --no-project --python 3.14 --with lupa==2.8 python -I test/verify.py` returns rc 0 and the same full RESULT. Static ownership/TOC, syntax, package parity, API-policy and asset tests pass.
- Archive SHA-256: `4f5eb4f309b2a1fddc0044f3d69cf2d8335b188dab85f710287d1aedeeb3ff19`.
- `Wire.lua`, `test/verify.py` and the TOC are byte-identical to PR 1. No new prefix/route/recipient, dependencies, SavedVariables fields or donor-prefix sends.
- Frozen old decoder: `test/fixtures/relay_16549ca.lua`, byte-identical to `16549ca:LayerEnemies/Relay.lua`, SHA-256 `24b4010cc267684a75cd0d16d9df68cb80629a13f7f934fe1a2a4250af10d273`. Test 9 executes it through the actual receive path and proves neither Store nor Known/Find retains the Spy line.

### Inherited tests changed

No inherited expectation or assertion changed. One title was corrected:

- `1.0 C1: the same enemy again from one observer is one row; 6 lines per sender per 10 s; nothing is ever sent` now ends `donor prefixes remain receive-only`. Its unchanged assertions prohibit sends on the three donor prefixes, not LEGW1. The old title overstated the rule this PR reverses.

A relay test's source-list comment was updated to stop claiming only `we` and `hh` are supported. Harness changes otherwise add the test loader and opt-in focused-run argument. A new per-name test fixture initially failed because its simulated numeric home realm disagreed with its mocked player identity; both reads now consistently use the numeric realm, with no assertion weakened.

### Mutants

`python test/spy_mutants.py --lua <Lua-5.1-executable>` runs all 22 Spy cases against each mutation, requires an unchanged test inventory, restores exact source bytes in `finally`, reruns the clean focused suite, and prints this table. Logs stay in ignored `build-spy-*.log` files.

| Mutant | Failed tests | Result |
|---|---:|---|
| Relay Spy heard on GUILD | 1 | KILLED |
| No six-per-minute cap | 2 | KILLED |
| No 60-second per-name limit | 2 | KILLED |
| Origin set to us | 10 | KILLED |
| Layer included | 1 | KILLED |
| Relayed Spy origin askable | 1 | KILLED |
| Stand-down ignored | 2 | KILLED |

All seven were caught on the first mutant run, before the three extra coverage cases. No surviving mutant prompted a test change.

## Review and merge check

Final review: self-review (no reviewer subagent tool). The parent/reviewer still supplies independent review. Checked source/provenance separation, alias names, rolling caps at offer and dispatch, stale refresh, delayed context, nonqueueing, unchanged send ownership and no saved-data growth. No deferred code findings.

Read-only `git merge-tree --write-tree` against PR 3 `b933280b6d53a58c970de927c1a00c244c6f29bd` (base `a61d86d`) returns rc 1, not a clean merge:

- `test/harness.lua`: both PRs append their separate test-file loader at the same location. Keep both the watch and Spy loader blocks when integrating.
- With regenerated verification output included: `notes/test-results.txt` and `notes/verification.json` also conflict; regenerate them after integration rather than choosing either branch's evidence.
- `Main.lua`, `Relay.lua` and README auto-merge without content conflicts. This is a merge check only, not a combined-branch behavioral verification. No other branch or worktree was changed.

The changed-line privacy scan is zero after correcting a synthetic assertion message that accidentally matched the supplied substring expression. Final commit-range scan is repeated at delivery.

## Native unknowns

Not run (alpha, owner's decision): live Spy-family usage in groups, delivery/order of simultaneous guild copies, client throttle behavior, and native UI. No live-client validation requested. Offline results establish source behavior only.
