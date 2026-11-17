# FLH batch-hop regression and route gate (R3)

## Scope and checkpoints

- Reviewed baseline: `8b8a18fe0685f8116846bc929fe28aed9950cb20`.
- Implementation/test/documentation head: `2c4f96c31eab14178bb61cb0aa2fbce02b6efd0b` on `feat/flh-membership`.
- This evidence is committed separately from implementation. Local commits only; no push, install or client operation.
- Reviewer inputs were read-only: `parent-verdict-f2-r2.txt`, `r2b.lua`, `r2c.lua`, `r2d.lua`, `gate2.py` and `gate3.py` from the review workspace. Fixtures are independent protocol facts, not donor code.

## Changes

`LayerEnemies/FLHMember.lua` and `LayerEnemies/Wire.lua`:

- A live click holds one token **and one rolling-minute slot in the actual shared budgets**. Ordinary traffic and FLH replies cannot consume it. Queries send only when capacity remains above that reservation; unsent targets are paced by the existing source tick, not Wire's general queue.
- The reservation expires at the original click deadline, even if no guest tick has run. Success, explicit stop, context cancellation and terminal failure also release it. All original global, public, per-person and hop ceilings remain in force.
- A full bucket can defer the whole query batch. Delayed first queries do not restart the 90-second window. An offline head is skipped rather than blocking every later host.
- The first valid offer is held across a send-limit refusal, without spending selection or creating invite authority. Repeated offers cannot redirect it or spend retries. An LR retries only when Wire's real budgets/pause allow it, at most **two retries after the initial attempt**. Readiness polling does not spend an attempt.
- Only successful LR delivery arms the existing selected-host invite path. Timers, LI handoffs and retries keep the original deadline. Remaining discovery stops once an offer is held.
- Terminal LR refusal or expiry while awaiting send capacity retains a row note and prints exactly once:
  `LayerEnemies: hop request to <host> could not be sent (send limit); click again`

`test/verify.py`:

- The entire private route declaration is consumed as literal tokens, including its check/net fields. No computed, extra or duplicate fields are skipped.
- Every reference to `ROUTES`, `kinds`, local `route` aliases and the function returning those aliases is covered by the reviewed read-only forms. New readers/writers/escapes fail closed.
- The alias-field iteration plant, both computed replacement forms (new prefix and FLHNET2/CHANNEL), computed declaration fields and alias escapes are rejected. All **14 earlier rejected reviewer plants** remain rejected. Comments and inert strings remain harmless.
- No prefix, route or client API exception was added. Exact gate delta: `flh-batch-gate.diff`.

## RED -> GREEN

The new final Lua file and policy tests were copied into a detached worktree of the reviewed baseline, without production edits. Logs are `flh-batch-final-red.txt` and `flh-batch-gate-final-red.txt`.

- Baseline focused Lua: **15 passed, 14 failed, 39319 assertions**. This selector includes the unchanged original explicit-batch test as a control.
- Final focused Lua: **29 passed, 0 failed, 39673 assertions** (`flh-batch-green.txt`).
- Baseline policy suite: **22 tests, 6 failing subtests**, all assertion failures (not syntax/setup failures).
- Final policy suite: **22 tests, OK** (`flh-batch-gate-green.txt`).
- The earlier vertical slices are also retained: reservation **3 RED**, retries/zero-capacity pacing **6 RED**, before their implementations. The offline-head regression introduced by pacing was caught separately before its fix; it is a passing baseline control, not claimed as an original regression.

The reviewer's actual timer-driven load cadence is reproduced in `test/src_flh_batch.lua`:

| Scenario | Reviewed baseline | Final |
|---|---:|---:|
| One ordinary whisper immediately before click, LO at +0.5 s | Query-reservation assertion fails (7 instead of 6) | Accepted; 6 immediate LQ + LR |
| Strangers' WP+CQ every 10 s; click same second; LO +0.2 s | 0/12 accepted | **12/12 accepted** |
| Same traffic, LO +1 s | 0/12 accepted | **12/12 accepted** |
| 10 offsets, 12 clicks each; strangers + own probes; LO +0.5 s | 96/120 accepted, 24 failures | **120/120 accepted, 0 failures** |
| Same 120-click sweep, own-probes-only control | 120/120 accepted | **120/120 accepted** |

Every replay independently checks **every captured client attempt**, including refusals, against an 8-token bucket refilling one token per 1.5 seconds, at most 8 at one timestamp, and at most 40 in every rolling 60-second window. No ceiling assertion failed in either baseline or candidate. Separate tests fill the shared minute ledger exactly, prevent ordinary/owed theft, check reservation release, ensure no auto-accept before successful LR, retain the selected host, bound retries, and cancel queued queries/retries for privacy, combat, instance, zone, donor-load and clock rollback.

### Deliberate inherited assertion migrations

Only requirements that changed were migrated:

1. An LQ now leaves one shared slot reserved, so the inherited R2 ordinary-after-LQ test expects 7 total occupied slots rather than 8. All other message cases still require 8.
2. A fully occupied public ledger now leaves the query click pending instead of rejecting the click; the inherited assertion still requires **zero emitted LQ** while full.
3. The former client-throttle test now requires the same selected host to retry after the existing pause. It retains the no-authority/no-acceptance checks before success.

The existing batch test additionally waits through pacing to prove that an eighth target is not merely hidden behind the initial reservation. Its one-selection mutant was retargeted to both redundant selection guards; no rule was removed.

## Mutation and portability evidence

All runners used Lua 5.1.5 and isolated copies under the configured scratch directory. Syntax errors, setup errors and timeouts are not counted as new-runner kills. Each runner restores its baseline before finishing.

| Runner | Result |
|---|---:|
| `test/flh_batch_mutants.py` | **19/19 killed** |
| `test/flh_rulings_mutants.py` | **20/20 killed** |
| `test/flh_member_mutants.py` | **52/52 killed** |
| `test/flh_mutants.py` | **39/39 killed** |
| `test/hop_fanout_mutants.py` | **63/63 caught** |

Total: **193/193**. No new mutant survived. JSON reports retain the exact catching assertions; `flh-batch-*-mutants-run.txt` records the legacy reruns.

The complete new 19-mutant run was also repeated from a copied checkout launched with `/opt/data` as its unrelated working directory. Its entire report was byte-identical to the original and preserved the report's deliberately old mtime (`flh-batch-stability.json`). Automated evidence tests also repeat a real mutant from two copied checkouts, verify unchanged source bytes, and check normalization and write-if-identical behavior (`flh-batch-portability.txt`: **4 tests, OK**).

The browser tool's outer response timed out at 420 seconds for two legacy runners despite the explicit 1800-second foreground subprocess timeout. Their original foreground processes continued; their completed reports/logs were collected, not fabricated or counted early. All other long runs used the same explicit 1800-second foreground timeout; no shell-background launches were used.

## Full verification

Command: `python3 -B test/verify.py`, with `TMPDIR=/opt/data/cache/scratch` and `LAYERENEMIES_LUA=/opt/data/tools/lua/lua-5.1.5/src/lua`.

**`RESULT: 1570 tests passed, 0 failed, 316473 assertions`**; exit **0**.

- Python gates: 11 send-policy, 22 API/route-policy, 4 mutation-evidence, 4 source-loader and 11 asset tests; all OK.
- Lua syntax, TOC/static policy, deterministic archive integrity and source parity: PASS.
- ZIP SHA-256: `c8a0ac207eebfeb69f249e9a408a3d21f1960e0c09dbb52ad851b8274a9b8d1c`.
- Added-line security scan: 645 lines, no hardcoded credential, shell-injection, eval/exec, unsafe-deserialization or SQL-interpolation pattern findings. This was a self-check, not independent review.
- Verification excerpts: `flh-batch-verify.txt`; full harness output: `test-results.txt`; package details: `verification.json`.
- Real-client/native interoperability: **not run (alpha, owner's decision)**. Offline acceptance is not proof of host delivery or native timing.
