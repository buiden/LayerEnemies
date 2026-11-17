# Stack 9: WarBoard hello reach review correction

Base: `e70924fa2ed3c34442a24ff42340ec6236be20ce` (`stack/9-warboard`).
Implementation: `0f35c1eee70a9af4e8c676f1b57af085cec93b01`.
Scope: local commits only; all eight lower stack refs remain frozen. No push,
GitHub write, version bump, new transport, or native-client test.

## Changes

- S1: charge the 600-second H admission cooldown only when `BN.send` accepts
  the frame. Admission refusal leaves the account eligible for a later scan,
  never an immediate retry. Accepted frames retain the existing admission and
  actual-dispatch cooldowns even when later dropped/refused.
- S1: deduplicate eligible account IDs and sort them numerically; select at most
  20 per scan, resuming strictly after the last accepted hello. Roster reordering,
  wraparound, and removal of the previous account preserve progress. Queue
  refusal cannot advance the cursor. The 60-second scan cadence is unchanged.
- N1/N2: describe every eligible online opposite-faction Battle.net friend or
  community-member account, not preidentified WarBoard users. Scope the
  tracking-request statement to this part. The rest of the handshake paragraph
  and the original publication-side-effect disclosure are preserved verbatim.
- N3: source and presence mutant reports use the same failure normalization as
  the WarBoard runner (verified identical function AST): randomized traceback
  checkout roots and Lua object addresses only. Identical JSON is not rewritten.
  Real narrow mutant runs test both bytes and mtime twice, through the full Lua
  harness; diagnostics retain traceback/assertion details but omit elapsed time.

## RED -> GREEN

A detached worktree of the exact reviewed base received only the new/updated
regression tests. All **13 selected regression identities failed** for the
expected assertions: `0 passed, 13 failed, 71703 assertions`. All 13 pass in the
final full verification. This includes the existing README case with its newly
required wording; the full suite adds 12 test identities overall.

| Rule | RED | GREEN |
|---|---|---|
| Queue refusal spends no H cooldown | 0/1/49 | 1/0/229 |
| Stable round-robin after last admitted account | 0/1/210 | 1/0/665 |
| Sixty-minute reach, four roster sizes, alone and with contention | 0/8/71432 on base | 8/0/99295 |
| README recipients and tracking scope | Separate missing-recipient and missing-scope assertions | 1/0/12 |
| Actual source/presence evidence reruns | 2 Python tests failed on differing Lua addresses | 2 Python tests passed |

Counts above are passed/failed/assertions for Lua cases. With only the cooldown
fix applied, 12/20-account cases already passed, but all four 25/40-account cases
still failed (only the first 20 reached); rotation independently fixes that limit.

| Online accounts | Base, alone | Fixed, alone | Base, mixed | Fixed, mixed |
|---|---|---|---|---|
| 12 | 10/12 | 12/12 | 4/12 | 12/12 |
| 20 | 10/20 | 20/20 | 4/20 | 20/20 |
| 25 | 10/25 | 25/25 | 4/25 | 25/25 |
| 40 | 10/40 | 40/40 | 4/40 | 40/40 |

Mixed runs offer 20 normal frames from other registered sources and six real
owed WarBoard answers every minute. Every run checks all-account reach, 600-second
H dispatch gaps, at most 20 selections/scan, 60-second scans, 10 WarBoard attempts
and 30 shared attempts per rolling minute, six answers/minute, and one-second
pacing. Mixed controls deliver all 360 owed answers, prove answers precede older
normal traffic/discovery, and actually reach the shared 30/minute ceiling.
Existing tests retain admission cooldown, delayed dispatch, eight owed-only slots,
queue age, privacy/stand-down, and all protocol/receive limits.

The inherited discovery test's old no-later-reconsideration assertions contradicted
S1 and were migrated, not its caps: initial 20 selections/10 admissions remain
exact, followed by 25 unique greetings before a repeat. A temporary second-cycle
attempt-count expectation was corrected from 75 to 60: only the first two
admitted cohorts had become eligible again. No production change was made for
that fixture correction; its final test passes with 1740 assertions.

## Full verification and mutants

`python3 test/verify.py` completed in the foreground with a 1800-second subprocess
timeout, no background shell/job, exit 0:

```text
RESULT: 1591 tests passed, 0 failed, 394371 assertions
```

Lua 5.1 syntax, static/API policy, TOC/media checks, archive integrity and source
parity all pass. Archive SHA-256:
`7c9177aecd92751a5da2690d0f944454995e9dee6c55d8c4559f5f87180b97e1`.

- WarBoard: **111/111 killed**, including ten added S1/N1/N2/N3 rule mutants.
  Existing alternative-send mutant anchor migrated to the accepted-return local;
  its behavior and target assertion are unchanged. No survivors or syntax/setup
  failures counted as kills.
- Source: **41/41 killed**.
- Presence: **41/41 killed**, baseline/final green.
- All three complete runners executed twice; all three JSON reports are identical
  in both bytes and mtime on the second run. SHA-256 values:
  - WarBoard: `7216601c6abbb69e1fca486a5202d8fb4fcbc47953582d2216daaa7b4d95a6ec`
  - Source: `5ba18ee37902a516b6a483c1f29f2b8aa797f8b36515cdce0848ea2ce9edde0e`
  - Presence: `9a1853e2ee7c611a2c2dd3ba89e2a6d5a06ebe795b60cb1f3b7ad3a15915cf7c`

The batched source/presence tool response hit its outer 420-second limit; its
foreground worker continued and completed. Read-back of the saved final summary
confirmed each run's exit 0 and both stability comparisons. No duplicate run was
started. The full verification itself returned normally.

Author self-review: only WarBoard production code changed; no caps, transport or
other source behavior changed. Static added-line security checks passed; the
README paragraph exactly matches the two approved substitutions. Native client
not run (alpha, owner's decision). No remaining blocker.

Raw evidence: `/opt/data/cache/scratch/le-warboard-reach-evidence/` (detached-base
RED logs, incremental RED/GREEN logs, full verification, both complete mutant
runs and JSON stability summaries). Generated reports are committed separately
from the implementation.
