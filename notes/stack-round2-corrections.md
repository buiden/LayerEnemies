# Stack reviewer corrections (local only)

Scope: levels 3–8; `stack/1-ui` b62875efa22564c7a72a833ff4854e7880850be2 and
`stack/2-hop` a7a65e4f5a9c6db986ed140329ffb4c720965299 remain frozen. Forward
integration uses two-parent `--no-ff` merges, with no push or GitHub write.
Evidence: `/opt/data/cache/scratch/le-stack-round2-evidence` and the sibling
`le-120-stack-ledger.json` (`stack_round2`). Native checks not run (alpha,
owner's decision); UI geometry uses width-aware harness metrics.

## Level 3: presence

- `Presence: measured presence cards keep several per page without overlap`:
  RED 26 passed / 1 failed / 11067 assertions (12px text got a 56px box),
  GREEN 27 / 0 / 11334. Remove both the 56px text minimum and the fixed card
  surcharge; retain other card floors and measure the complete presence line.
  Six names, community/friend labels, short/wrapped zones, all pages reachable,
  three short cards per page, no overlap, buttons clear, and pooled shrinkage.
- `Presence: only online community members resolve Battle.net accounts`:
  RED 27 / 1 / 11529 (50 lookups instead of 5 in the first tick),
  GREEN 28 / 0 / 13142. Gate Online/Away/Busy before reading account ID or
  Battle.net APIs; 100 online out of 1000 members now means 100 lookups, not
  1000. Offline rereads still withdraw prior evidence immediately.
- `PresenceMutantPortability.test_relocated_clone_with_relative_tmpdir`:
  RED on the owner-scratch assertion; GREEN after honoring standard tempfile
  selection. Exercises the actual CLI from a relocated clone and unrelated cwd
  with a relative TMPDIR, plus cleanup and full mutant results.
- Initial mutation run: 37/38 killed. The new adapter gate masked the legacy
  pure `accept Offline` mutant. Added an independent pure-admission assertion
  to the unchanged target test; it passes unmutated, so this is coverage
  strengthening, not a new production RED. All 38 old mutants are retained;
  three new layout/lookup mutants added. Final: **41/41 killed**. Exactly one
  legacy mutant was caught only after adding coverage.
- Full `python3 test/verify.py`: **1247 passed, 0 failed, 140773 assertions**;
  syntax/static/package/source parity all pass. Archive SHA256:
  `d4599ab650391b7ee9425d5033655da0fdd7ba6a3639735f0bab8463db222bd8`.

Rulings: reuse the assigned clone/ledger and retain previous evidence; implement
this explicit reviewer UI correction directly; keep the existing 1.1.0 package
version while preparing the 1.2.0 stack. No inherited assertion weakened.

## Level 4: forward merge from corrected presence

Only `notes/test-results.txt` and `notes/verification.json` conflicted; regenerated
both. Production, tests and README auto-merged. Full verify: **1276 passed,
0 failed, 160562 assertions**, all syntax/static/package/source parity gates pass.

## Level 5: forward merge and Overlord diagnostic

Only the two generated verification notes conflicted; regenerated both. Added
pool text to the existing Overlord session line without changing admission:
known `global/pve/rpg/rpv/hc`, otherwise `pool unknown (receiving nothing)`.

- `Overlord: net diagnostic shows the currently detected pool on the Overlord line`
- `Overlord: net diagnostic explains unknown pool receives nothing and updates on recovery`

Both failed before the change: **34 passed / 2 failed / 17129 assertions**;
then **36 / 0 / 17171**. Tests cover all five tags, missing/partial/throwing rule
reads, missing enum and live recovery without receipt or counter changes.
Two diagnostic mutants supplement the unchanged 52 legacy cases.
Full verify: **1316 passed, 0 failed, 178092 assertions**, with all static,
syntax and package/source parity checks green.

## Level 6: forward merge onto source registry

Conflicts: `Main.lua` and the two generated verification notes. Main's resolution
retains both the pool-aware Overlord line and the following `Sources.lines()`
loop; no diagnostic was dropped. Generated notes regenerated. Full verify:
**1393 passed, 0 failed, 216396 assertions**, all static/syntax/package gates pass.

## Level 7: forward merge before Wanted follow-up

Only generated verification notes conflicted; regenerated both. Full verify of
this intermediate composition: **1418 passed, 0 failed, 237085 assertions**,
all static/syntax/package/source parity checks green.

### Wanted round-1 merge

Merged exact source `8da62639d5220f474da3cb45c6ef17d4902da642` (including
`fac5151` behavior changes). Only the generated verification notes conflicted;
regenerated both, no code/test resolution necessary. Source fixes add isolated
rate lanes, guild-reserved/per-carrier bounded assembly and replay, map-only
zone projection, numeric 1.29.x patches and stable mutant evidence.

Focused Wanted: **40 passed, 0 failed, 23469 assertions**; Python evidence
regression: **1 passed**. Full verify: **1433 passed, 0 failed, 239897 assertions**,
all static/syntax/package checks pass. Source's own RED evidence remains in
`notes/wanted-receive.md`; no additional production fix was needed in the stack.

## Level 8: first forward merge before ChehulNet follow-up

Conflicts were generated notes only: test results, verification, and Wanted
mutation evidence. Retained the incoming round-1 Wanted evidence (to regenerate
on the final composition); regenerated full verification notes. Full verify:
**1446 passed, 0 failed, 252783 assertions**, all static/syntax/package gates pass.

A later owner instruction requires an additional six-name mixed Wanted,
presence and Overlord geometry test at levels 7 and 8; that follow-up is below.

### Later owner instruction: six mixed Find cards

`Stack: six mixed Wanted presence and Overlord cards use measured heights and page without overlap`
was added at level 7 and will run unchanged at level 8. Real numbered Wanted
frames populate all six names, then newer Overlord events replace two claims;
real community scans supply presence, in both arrival orders. Wanted and
Overlord share one retained Reported slot, so the board contains four Wanted
and two Overlord claims, not fabricated simultaneous duplicate claim slots.
Every page must show at least two complete cards; all six must be reachable,
nonoverlapping, measured exactly, with complete claim text and no Ask action.

- Actual behavior RED: **3 passed / 1 failed / 332 assertions**, 24px claim text
  occupied an assumed 44px box even after the presence floor fix.
- Fix only presence-bearing Find cards: measure their complete detail strings
  and use the ordinary card floor instead of summed evidence-slot estimates.
  Unrelated Find-only, Friendly and Reported floors remain unchanged.
- GREEN: **4 / 0 / 665**. Full verify: **1434 / 0 / 240311** (all gates pass).
- Two initial fixture failures were corrected before that behavior RED: Wanted
  IDs permit at most three characters, and Overlord integer timestamps must be
  newer than Wanted's fractional receipt before replacing its claim. No assertion
  was removed or weakened. Failed fixture logs are retained separately.
- The presence card-surcharge mutant now injects the same old floor at the
  minimum-height entry, so the new early mixed-card branch cannot mask it.

Level 8 second forward merge: combined both history sections of this note and
regenerated the two verification files. Code auto-merged. Full verify:
**1447 passed, 0 failed, 253197 assertions**, including the mixed-card test.

## Level 8: ChehulNet round-1 and final gates

Merged exact `a147b3988f792b33c9b3b7007269a4c84440e6ca` (including
`f0c0cf0` behavior changes). Code/README auto-merged; conflicts were generated
ChehulNet mutation evidence and the two verification notes. Retained incoming
round-1 mutation evidence, then regenerated it on the completed stack.
ChehulNet module and its Lua tests equal the source revision exactly. Wanted
module and its source tests also remain exact. The UI is the union of ChehulNet's
separate measured hint section and the stack's measured Find changes.

- ChehulNet focused: **16 / 0 / 14766**; evidence-runner Python tests: **3 pass**.
- Mixed Find geometry on the final level 8: **4 / 0 / 665**, unchanged test from 7.
- Full verify, repeated after integration: **1450 passed, 0 failed, 255093 assertions**.
  1450 = original 1427 + presence 2 + pool 2 + Wanted 15 + ChehulNet 3 + mixed 1.
  Static, syntax, TOC, API/send policy, deterministic archive/source parity pass.
  Final archive SHA256: `9e7686d7f9934cc5bc6d854487df647d3a4e95d15696d13c8f8510228373cb1d`.
- Final mutants: **presence 41/41, Overlord 54/54, Wanted 71/71,
  ChehulNet 57/57, source 41/41: 264/264 killed**.
- Final quick regressions: **hop 184/0/13199; FLH 28/0/19690;
  UI layout 9/0/1253; stack 4/0/665**.

### Runner issues resolved without production or assertion weakening

The composed adapter contains two friend caps. Presence's legacy bare-text
mutation anchor was no longer unique. Scoped it to the presence reader's
`local r,reason=presenceRead` loop, preserving the exact 200-to-201 boundary and
its target test; all 41 mutants then completed. The initial anchor error log is
retained and is not counted as a killed mutant.

The first parallel Wanted run hit the terminal tool's 420-second wrapper limit,
not a mutant failure. Confirmed that process had exited, retained its partial
log, reran the unchanged suite as a tracked job, and waited for exit 0: 71/71.
All full `verify.py` gates ran foreground, never detached.

The new portability probe originally reran the entire mutation suite and passed
at level 3, but exceeded its unchanged 180-second wrapper limit on the larger
stack under concurrent host tests. Separated runner portability from rule
coverage: the relocated/unrelated-cwd/relative-TMPDIR test invokes the real CLI
entrypoint with one real mutant, baseline/final harness runs and cleanup checks.
Retained every assertion and the timeout, added exact one-mutant inventory, and
kept the complete 41-mutant gate separate. Restoring the original owner-scratch
restriction in a private copy still fails this exact probe; corrected probe
passes in 13.355s. No production/test contract was relaxed to hide a failure.

Final review: author self-review (no subagent tool); parent review remains
independent. Added-line security patterns clean. Only Adapters, Main, UI, Wanted
and ChehulNet production files changed from the original level 8. Verifier,
inherited harness, Codec/BNet/Wire/Sources/Find/Known/Overlord/Presence are
unchanged. No native checks (alpha, owner's decision), push or GitHub write.
