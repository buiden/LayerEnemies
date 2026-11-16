# Guild-intel PR 2: round-1 corrections

Reviewed start: `9d8d84e61c69fd6e07b82ce1a0e84e3bc6e33091`.
This correction record supersedes the count and War Effort conclusions in
`guild-intel-pr2.md`; the original report remains as historical evidence.

## Fixes

- M1 (`62b9d90`): non-final O attempts count only the names actually fitted,
  recomputed after byte trimming. Only the final attempt can claim the still
  unlisted overflow. An unchanged receiver therefore adds 4 + 4 + 5 for a
  13-enemy snapshot, or 4 + 4 + 22 for 30. Interrupted or expired bursts can
  under-report a snapshot; they do not pre-claim the pending names in every
  packet. No receiver behavior or O field order changed.
- M2 (`c675d15`): War Effort selection uses a separate session-only eligibility
  lane, retaining the existing 3-second settle, 15-second pace and 60-second
  per-enemy cooldown. It reserves the whole public cohort before dispatch,
  as the original single-report picker did, rather than inheriting the
  staggered O acknowledgments. Cancellation keeps both lanes' cooldowns;
  public reservations never mark unsent guild names shared. New enemies can
  still form a separate public report inside another enemy's cooldown.

## Test-first evidence

Only the augmented test file was copied into a detached checkout of the
reviewed start; production files remained at that SHA for both RED runs.

| Fix | New regression names in `test/crowd.lua` | RED | GREEN |
| --- | --- | --- | --- |
| M1 | `crowd receiver: 5/9/13/30 enemies keep their exact displayed total` (four named cases) | 6 / 15 / 27 / 78 displayed | 5 / 9 / 13 / 30 |
| M1 | `crowd receiver: byte-trimmed lines count only their own names` | 12 for five enemies | 5 |
| M2 | `crowd War Effort fight: 6/13 enemies produce five pairs in five minutes` (two named cases) | 9 / 13 pairs | 5 / 5 |
| M2 | `crowd War Effort cooldown: unguilded/guild line refused/share off/on keeps enemy dedupe` (three named cases) | 2 pairs inside 60 s | 1; repeats allowed at exactly 60 s |

M1 RED: `702 tests passed, 5 failed, 66800 assertions`; M1 GREEN:
`707 tests passed, 0 failed, 66805 assertions`.
The cumulative RED on the reviewed start had 10 intended failures:
`703 tests passed, 10 failed, 73449 assertions`. The per-enemy new-arrival
characterization already passed on that start and is not counted as RED.
M2 GREEN: `713 tests passed, 0 failed, 73885 assertions`.

Each fix has a compiling behavioral mutant in `test/crowd_mutants.py`:
restore remaining-backlog counts on every line; remove the independent
public cooldown reservation. Each was killed by its named regression and
followed by a passing full harness with source bytes restored. The complete
merged-tree mutation run killed **12/12**, including all ten inherited mutants,
then restored exact source bytes and passed the 859-test harness again.
An initial foreground mutation run hit the tool timeout; its active mutation
was restored before further edits, and the full run completed in an isolated
worktree. The final evidence is not the interrupted partial run.

## Merge and compatibility

Current upstream main was fetched as
`601e421f5d1078a0e03bfeeff72e91b4804aa9df` and merged (not rebased) in
`ca40ca356b445fc4def09538ad20004a4e230740`.
Conflicts: `LayerEnemies/Main.lua`, `notes/test-results.txt`, and
`notes/verification.json`. Main retains both the crowd cancellation and
`OwnDeath.cancel()` hooks. Both test suites are retained. Historical generated
notes were retained at merge, then regenerated for the combined tree in a
separate notes commit.

Byte comparisons confirmed:
- The old-receiver encoder fixture, O decoder and receiver Store are unchanged
  from the reviewed start.
- `test/verify.py`, `Wire.lua` and the TOC match upstream main exactly. The
  Wire/TOC changes from the reviewed start come exclusively from that merge.
- Main still has the same 20 `N.Wire.send` sites; the fixes add none.
- The unchanged stricter send gate accepts all 34 addon Lua files with zero
  false positives. No gate exception or weakening was added.

## Independent reviewer probes replayed

The original `p.lua` and second-opinion `probe.lua` bodies were executed
unchanged with the harness client mock prefix against the old and merged
sources. Current main was also replayed at its exact fetched SHA.

| Probe | Reviewed start | Fixed + merged | Current main |
| --- | --- | --- | --- |
| Receiver, 13 real enemies | 27 displayed | 13 displayed | 13 displayed |
| Receiver, 30 real enemies | 78 displayed | 30 displayed | 30 displayed |
| Five-minute fight, 6 enemies | 9 C+E pairs | 5 pairs, counts 6 | 5 pairs |
| Five-minute fight, 13 enemies | 13 C+E pairs | 5 pairs, counts 13 | 5 pairs |
| Unguilded / O refused | pairs at 103 and 148 | only 103 | only 103 (original review) |
| Share off/on | pairs at 103 and 118 | only 103 | only 103 (original review) |

The second-opinion pack went from `14 passed, 1 failed` to
`15 passed, 0 failed, 7527 assertions`. Its cooldown probe now reports zero
repeated hashes inside 60 seconds. Burst caps, O name cooldowns, freshness
44/45/>45, oldest-fitted age, cancellation, refusal receipts, no O queue,
explicit-age encoder vectors and the sustained-fight O limits remain passing.

## Verification and limits

Executed from the repository root using native Lua 5.1.5:

    python3 test/verify.py
    RESULT: 859 tests passed, 0 failed, 89676 assertions

Exit 0. Python verifier tests: 11 passed; API policy tests: 5 passed; asset
checks: 11 passed. Syntax, unchanged send policy, TOC parity, archive contents,
source parity and fuzz checks passed. Generated evidence is in
`test-results.txt`, `verification.json`, and `crowd-mutants.json`.

Native checks: **not run (alpha, owner's decision)**. Live delivery and guild
chat throttling remain unverified. The pre-existing all-invalid-name snapshot
still sends no O line; this was a reviewer note, not one of the two must-fixes.
No installation, push, release or GitHub write was performed.
