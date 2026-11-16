# Guild-intel PR 4: round-2 corrections

## Scope and result

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
