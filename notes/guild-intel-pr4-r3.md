# Guild-intel PR 4: round-2 corrections

## Combat reserve correction (supersedes the earlier two-line ruling)

Owner ruling: keep **two prefix tokens** reserved in both modes, protecting two own lines in peace and **one own line in combat**. A combat relay costs two tokens and can now send at four or more available tokens, subject to every other unchanged limit. Keep the last three guild-minute slots in peace/two in combat, share-off and drop-without-queue behavior. Only `Relay.spend`'s prefix admission expression changes; `Wire.lua`, `OwnDeath.lua` and `test/verify.py` are byte-unchanged from the starting head `a342c7f672b06edf99d42b0c53410e26e800655a`.

Known limit, explicitly accepted: relay -> rare K death line -> O in combat can send R=1/K=1 but drop O=0. One own line is reserved, not both; no retry or queue is added. README and the real K-then-O test now state that limit instead of suppressing all combat relays.

### Test-first and verification

- Baseline policy: **22 passed, 0 failed, 1726 assertions**. Added an explicit full-bucket combat-send test, required nonzero relays in the 300-second sustained HH cases (1/s and 1/4s, own O still 5/5), restored three combat burst relay expectations from zero to one, and migrated the K-then-O expectation to the accepted limit.
- Before the source edit: **16 passed, 7 failed, 1754 assertions**; each failure was an expected missing combat relay. After the minimal fix: **23 passed, 0 failed, 2200 assertions**.
- Policy mutants: **4/4 killed**. The former one-line-reserve mutant is inverted: restoring the oversized reserve fails seven tests. Share-off, token-reserve removal and minute-reserve removal mutants remain.
- `python3 test/verify.py`, foreground, Lua 5.1.5: exit 0, **RESULT: 985 tests passed, 0 failed, 94599 assertions**. Syntax/API policy, strict send gate, media/TOC/package integrity/source parity and `git diff --check` pass.
- Archive SHA-256: `e4f4aae4a9b78423c06b1fc4d0ca4a4fc1306dbc41b58ea6791e3cc71f164147`.

### Reviewer p2 probes, 300 seconds per sustained mode

All **24** sustained combinations (HH/Spy/mixed, 1s/4s, peace/combat, relays off/on) give **O=5/5, zero refusals**. With relays off R=0 in every mode. Relays-on counts:

| Family/cadence | Peace O / R | Combat O / R |
|---|---|---|
| HH, 1/s | 5/5 / 80 | 5/5 / 35 |
| HH, 1/4s | 5/5 / 75 | 5/5 / 35 |
| Spy, 1/s | 5/5 / 26 | 5/5 / 10 |
| Spy, 1/4s | 5/5 / 30 | 5/5 / 29 |
| mixed, 1/s | 5/5 / 80 | 5/5 / 35 |
| mixed, 1/4s | 5/5 / 30 | 5/5 / 29 |

`kafter`: peace K=1/O=1/R=3, no refusal; combat K=1/O=0/R=1, one O refusal (documented limit). `off`: zero guild sends; enabling permits only a fresh O and WE Q, not held relays. No runtime errors.

Evidence: `/opt/data/cache/scratch/gi-r3-evidence/combat-one-own/`, including raw logs, machine-checked mode counts and `pr4-probe-results.json`. Reused the previous builder's probe wrappers: p2's body is byte-identical to the reviewer snippet with the shared harness prepended; rp2 is byte-identical in full. Initial overly strict whole-file p2 comparison stopped the runner before execution; corrected only wrapper validation after confirming the unchanged snippet and exact shared harness prefix. Reviewer originals are untouched.

Changed source/test/docs: `LayerEnemies/Relay.lua`, `README.md`, `test/relay_policy.lua`, `test/relay_policy_mutants.py`. This note and regenerated `notes/test-results.txt` / `notes/verification.json` are committed separately. Final review: self-review (no subagent tool); independent review remains the parent's lane. Native checks not run (alpha, owner's decision). Local commits only; no push, GitHub write or install.

## Earlier round-2 scope and result (historical)

Started from `f43c837ddd92f0f6530b392a05f4c4103f90dcbf` on `open-gi4-fix`; existing commits preserved. Local commits only, no push or GitHub writes. Reviewer originals under the mani profile were read-only; copied probes and logs are in `/opt/data/cache/scratch/gi-r3-evidence/`.

- `Relay.spend` leaves the last three guild-minute slots out of combat and two in combat, across all prefixes. The five-token conservative prefix mirror still accounts for O/K/F/H and refuses without queuing.
- `Wire.lua` changes **only** by adding read-only `Wire.guildMinute(now)` (current rolling count and combat-adjusted cap). Inspection does not mutate/prune/spend; future stamps still count on rollback. No send-path, cap, route or queue changes. `test/verify.py` is unchanged.
- Ruling: the explicit relay -> K -> O combat acceptance case needs capacity for two own lines, not merely two tokens. Reserve two tokens in peace and four in combat. With Wire's unchanged five-token bucket and double-cost sends, combat guild relays cannot fit and are dropped, not deferred. Receipt/local display stays active. This cost is documented rather than hiding it behind a 5/5 O result. Three inherited combat-burst relay-count expectations change from one to zero; all O expectations remain.

## Test-first evidence

`test/harness.lua --relay-policy-only` baseline: 16 passed, 0 failed, 1170 assertions. Five minute-cap tests failed before the implementation (16 passed, 5 failed, 1617 assertions), then all 21 passed. New names, with prefix `Guild relay policy: `:

- `sustained HH keeps all five own O slots combat=false every=1`: 2 -> 5 O.
- `sustained HH keeps all five own O slots combat=true every=1`: 2 -> 5 O.
- `sustained HH keeps all five own O slots combat=true every=4`: 1 -> 5 O.
- `minute reserve includes other prefixes combat=false`: 18 instead of 17 sends -> relay dropped.
- `minute reserve includes other prefixes combat=true`: 9 instead of 8 sends -> relay dropped.

The separate test `combat relay burst cannot steal K then O capacity` then failed with O=0 and passed after scaling the prefix reserve with combat cost. Read-only accessor expiry/rollback assertions were added to the existing minute cases (not counted as new RED tests).

One initially flawed other-prefix setup allowed automatic WE traffic and accidentally passed in combat. The corrected setup disables WE between explicit sends, asserts exactly 8/17 prefilled slots, then fails for the intended 9th/18th relay send. The original and corrected logs are retained.

`python3 test/relay_policy_mutants.py`: **4/4 killed** and clean 22-test rerun. New mutants: removing the minute gate fails 2 tests; restoring the one-combat-line prefix reserve fails 4, including the new K-then-O regression. Existing share-off and prefix-reserve mutants also die. Source bytes restored in finally.

## Reviewer probes (copied verbatim)

`p2.lua sustain` was run for HH, Spy and mixed families, both 1-second and 4-second cadence, with/without relays and combat: **all after results O=5/5, zero refusals**.

| Family/cadence | Peace O before -> after (R before -> after) | Combat O before -> after (R before -> after) |
|---|---|---|
| HH, 1/s | 2 -> 5 (98 -> 80) | 2 -> 5 (48 -> 0) |
| HH, 1/4s | 5 -> 5 (75 -> 75) | 1 -> 5 (49 -> 0) |
| Spy, 1/s | 5 -> 5 (26 -> 26) | 5 -> 5 (10 -> 0) |
| Spy, 1/4s | 5 -> 5 (30 -> 30) | 5 -> 5 (29 -> 0) |
| mixed, 1/s | 2 -> 5 (98 -> 80) | 2 -> 5 (48 -> 0) |
| mixed, 1/4s | 5 -> 5 (30 -> 30) | 5 -> 5 (29 -> 0) |

`kafter`: peace remains K=1/O=1/R=3; combat K=1/O=0/R=1 -> K=1/O=1/R=0. `off`: still zero guild sends, with only a fresh O and WE Q after enabling. No probe runtime errors.

## Verification and files

`python3 test/verify.py`, foreground, native Lua 5.1.5: exit 0, **RESULT: 984 tests passed, 0 failed, 94125 assertions**. Strict send gate, syntax/API policy, package integrity/source parity and diff whitespace checks pass. Archive SHA-256: `5daccff94389866d4878177971afc21696ca9d578d3531fb291ad8883cc19d8a`.

Correction files: `LayerEnemies/Relay.lua`, `LayerEnemies/Wire.lua` (accessor only), `README.md`, `test/relay_policy.lua`, `test/relay_policy_mutants.py`. Notes committed separately: this file, regenerated `notes/test-results.txt`, `notes/verification.json`.

Final review: self-review (no subagent tool); parent retains independent review. Native checks not run (alpha, owner's decision). No installation or other external writes.
