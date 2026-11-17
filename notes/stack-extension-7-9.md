# Stack extension: Wanted replay fix and WarBoard

Local integration only; no push or GitHub writes. Levels 1–6 are unchanged.
The package remains 1.1.0 while this prepares the 1.2.0 stack.

## Heads and full verification

| Level | Head / merge inputs | `python3 test/verify.py` |
|---|---|---|
| 7 | `697c91ad5c4129910406074dcd09866e58a6295f` — previous level 7 + Wanted `cd51d866233e04499af4cad16310c8848b02606e` | **1448 passed, 0 failed, 243052 assertions; rc 0** |
| 8 | `b24dee293df29cd9196187e97248484b16d916f8` — previous level 8 + updated level 7 | **1464 passed, 0 failed, 257834 assertions; rc 0** |
| 9 | This merge — updated level 8 + WarBoard `65904e6674af82c72f89f7c7f762510f19e8e058` | **1579 passed, 0 failed, 294043 assertions; rc 0** |

All merges use `--no-ff`; each touched level has regenerated verification notes.
All full gates ran in the foreground. Level 9 archive SHA-256:
`f41f321080b234d7ad1d4a02f3d3bc9854ef156d00872ea02b47e42117648f55`.

## Conflicts and resolutions

- Level 7: `notes/test-results.txt`, `notes/verification.json`; regenerated.
- Level 8: those two notes and `notes/wanted-mutants.json`; retained incoming
  replay-fix evidence, regenerated verification, then reran mutants on level 9.
- Level 9: `BNet.lua`, `Codec.lua`, `Sources.lua`, the TOC, README,
  `THIRD_PARTY.md`, `test/api_policy_test.py`, `test/harness.lua`, and the two
  generated verification notes.
  - BNet queue entries retain **both** admission time and final source predicate.
    Per-network admission, **52 normal + 8 owed-only / 60 total** slots,
    **60-second age**, WarBoard **10/minute**, and shared **30/minute** remain.
  - Codec retains streaming inflation limits/meter and per-sender assembly
    ownership, alongside the newer **15-second idle / 120-second total** limits.
  - Sources retains filtered status diagnostics, new deduped counters and
    WarBoard position/expiry/tag/withdrawal metadata.
  - All module, documentation, attribution and API-owner additions are retained.
    The stronger Main/Sources heartbeat assertions are unchanged.

## Composition fixes and evidence

### Coordinate subject is not transport provenance

Wanted's non-self coordinate wording was being applied to relayed WarBoard
**enemy** coordinates. Sources now omits “seen near observer” when the explicit
coordinate subject is `enemy`; Wanted observer coordinates retain that wording.
WarBoard itself remains byte-identical to its reviewed source.

Real mixed Wanted/FBLP ingress through BN self, BN third-party, GUILD, PARTY,
RAID and CHANNEL: **RED 1 passed / 5 failed / 380 assertions → GREEN 6 / 0 / 480**.
The tests also inspect complete, measured, reachable Find cards and zero sends.
Only the matching BN subject says “own position”; all relays say “reported
position”. The new mutant restoring the false observer label is killed.

### Queue fixtures must exercise the composed registry

Unchanged baselines failed: WarBoard **98/3/30546**, BNet **22/7/2024**. Fixtures
assumed duplicate WarBoard registration, 30 queued frames from one default
source, and 20 immediate WarBoard admissions. Reuse the shipped source/prefix
and real diagnostic counters; saturate global limits with eligible independent
sources. No production cap or assertion boundary was relaxed.

The old 20-queued assertion contradicted the required ten-slot admission cap.
It is replaced by separate exact assertions for **20 selections**, **10 queue
admissions**, and **no retry** after refusal, retaining the actual-send cooldown
checks. A scan does not guarantee every selected peer receives a hello. Real
H/A tests additionally exercise all eight reserved slots and the exact 60-second
boundary, plus older-frame refusal. BNet is **29/0/2321**; the WarBoard-focused
run before the final Python-wrapper test was **114/0/36190**.

The first full gate caught ChehulNet's unchanged immediate-before-UI contract.
Move WarBoard **before ChehulNet**, rather than weakening that policy assertion.
API policy: **13 tests passed**; complete final gate green as above.

### Handshake explanation and deterministic evidence

README has one **Why the handshake is needed** paragraph directly under the
send table. It explains the hello/answer data gate, LE's own identity and
opposite-faction friend/community recipients, the remote profile/kill-streak/
board publication side effect, and no tracking or position-broadcast request.
The prior disclosure sentence is retained once. Explanation test:
**RED 0/1/4**, then green in the composed/full suites.

Actual portability-mutant reruns initially changed random traceback paths.
Normalize only checkout prefixes and Lua object addresses, preserving test
filename, line, assertion and traceback; do not rewrite identical reports.
The real two-run Python regression was **RED 1 failed → GREEN 1 passed**, and
is now exercised by the full Lua harness. Multiple complete WarBoard reruns
also preserve bytes **and mtime**. Report SHA-256:
`4d17a7ecbe083ddf73011fa7c573b0add1456a4a752938396927b8e0b338b3b8`.

## Final exact-tree mutants and quick regressions

| Mutant suite | Killed | Exit |
|---|---:|---:|
| Source | 41/41 | 0 |
| Wanted | 84/84 | 0 |
| ChehulNet | 57/57 | 0 |
| WarBoard | 101/101 | 0 |
| **Total** | **283/283** | **0** |

No survivors. Three new WarBoard mutants cover coordinate-subject composition,
real-H reserve protection and real H/A frame age. All inherited mutants remain.
The Wanted observer-label anchor follows the stricter composed condition;
its behavioral removal and target assertions are unchanged.

The terminal wrapper interrupted an initial Wanted run after 420 seconds;
that is not a test result. Its partial log is preserved. The unchanged complete
runner then passed 84/84. Following the final TOC ordering correction, four
isolated 21-rule batches reran the **entire exact ordered inventory** using the
unchanged runner, with unique/count/order assertions before aggregation.

| Final quick suite | Passed / failed / assertions |
|---|---|
| Hop | 184 / 0 / 13199 |
| FLH | 28 / 0 / 19690 |
| Overlord | 36 / 0 / 17171 |
| Presence | 28 / 0 / 13145 |
| Stack composition | 11 / 0 / 1147 |
| UI layout | 9 / 0 / 1253 |

## Audit and handoff

Author self-review (no subagent reviewer tool). Added-line security scan clear;
all inherited level-8 test identities remain. Wanted, ChehulNet, Wire, Main,
UI, the legacy harness and verifier are unchanged from updated level 8;
WarBoard is unchanged from its supplied source. Six frozen refs are exact.
No deferred findings. **Native checks not run (alpha, owner's decision).**

Full logs, preserved failures and final batch evidence:
`/opt/data/cache/scratch/le-stack-7-9-evidence/`.
Stack ledger: `/opt/data/cache/scratch/le-120-stack-ledger.json`.
