# FLH membership: review fixes and upstream-main merge

## Result and scope

- Branch: `feat/flh-membership`; local commits only, no push or live installation.
- Reviewed baseline: `a76e249c6413e9172882346ac2c16900204c1833`.
- Pre-merge tip: `aa0c206` (fixes and detached-baseline evidence).
- Fetched `https://github.com/buiden/LayerEnemies main` at
  `2675e03d9363d4299a02d6d60815e0d65298967c`.
- Merge base: `90d4444cc32d1463e98c9ede1274750bea5af98f`.
- Non-fast-forward merge / tested code head:
  `9c564ed3005045f61e1a68e74c82471e579364fc`.
- This document and regenerated evidence are a separate, notes-only commit.
  No production, test, or packaged README bytes change after that tested merge.
- Native checks: **not run (alpha, owner's decision)**. All behavioral evidence
  uses Lua 5.1.5 and the existing fake-client boundary.

## Part A: fixes, RED then GREEN

| Slice | Fix commit | Boundary verified |
| --- | --- | --- |
| Route gate | `12cde73` | The complete literal lookup RHS and following guard must match; no expression suffix replacement, unreviewed table constructor or computed subscript in `check`; forbid `debug` references in every addon module, including folded global keys. |
| Canceled in-flight LQ | `6679653` | Record a real attempted-send cooldown even when the send hook cancels the guest. Initial second and deferred sixth LQ, successful and client-throttled attempts. |
| Recursive source tick | `eeb00a3` | An in-progress query guard prevents a nested tick from consuming the target cursor. Initial first and deferred sixth LQ; all seven targets still get exactly one query. |
| Transient group join | `20bc59b` | `Main.groupCheck` cancels FLH authority on the observed join, even when the player leaves before the next tick. Initial offer, paced discovery, LR retry and selected-host phases. |
| Current host claims | `20bf55f` | Each paced target is reread from live candidates. Skip withdrawn hosts and changed/own-layer claims without spending their cooldown; preserve progress to the next host. For the same layer, send its current exact key spelling. |

`LayerEnemies/FLHMember.lua` and `LayerEnemies/Main.lua` are the only addon files
changed by these new fixes. Gate and regression changes are in `test/verify.py`,
`test/api_policy_test.py`, `test/src_flh_batch.lua` and
`test/flh_batch_mutants.py`.

The final new tests were copied, without production or checker changes, into a
detached worktree at the requested baseline. Replayed results:

- Batch RED: **24 passed, 14 failed, 3400 assertions** on `a76e249c`.
- Batch GREEN: **38 passed, 0 failed, 3840 assertions** on `20bf55f`.
- Gate RED: 25 test methods; the three new methods produced **184 failing
  subtests** (two expression replacements, two unreviewed table/subscript
  plants, and debug-access spellings across the addon files).
- Gate GREEN: **25 test methods passed**. Earlier route plants remain rejected.
- New mutants: computed new-prefix route, FLHNET2/CHANNEL expression replacement,
  debug upvalue access, canceled-attempt cooldown, recursive cursor, group-join
  revocation, and current host key. Each is independently killed.

Exact logs and inventory: `flh-review-red-green.json` and its linked `.txt` files.
The actual checker delta is `flh-review-gate.diff`; it changes source policy,
not the shipped route allowlist. The empty options default is the one existing
table-constructor exception inside `check`; the only allowed subscripts there
are the literal route lookup and kind lookup.

## Part B: complete conflict inventory

There were **two conflicted files, three conflict blocks**, all generated
verification evidence; no production or test conflict occurred.

1. `notes/test-results.txt` — one final block: the membership branch's old result
   line versus upstream's fourteen Wanted round-two test lines and old result
   line. Resolution: regenerate the complete merged test run, keeping both
   membership and Wanted tests, with the new result line below.
2. `notes/verification.json` — two blocks:
   - syntax/test/assertion counts from different parent trees;
   - archive member/byte counts and hash from different parent packages.
   Resolution: regenerate counts and package metadata from the merged tree,
   rather than selecting either parent's numbers.

The merge commit temporarily kept the branch versions of those generated files;
this separate evidence commit replaces both with the actual merged verification
output. `README.md` auto-merged cleanly: membership disclosure and upstream
Wanted replay eviction/counter semantics are both present.

### Every production line differing from the mechanical merge

**None.** `git merge-tree --write-tree aa0c206 2675e03d` produced mechanical tree
`d404d33e16ddca78e821456b2bd0bd6ebf69a304` (with the evidence conflict markers).
The following comparison is empty:

```sh
git diff d404d33e16ddca78e821456b2bd0bd6ebf69a304 9c564ed -- LayerEnemies
```

No hand-written production resolution or post-merge production adjustment was
necessary. The full addon subtree is
`bcdafe7626be6cf75b7685b6ef31860fd5537159`.

The common base already contains hop fan-out, presence, FLH receive, Overlord
receive, registry/Battle.net/Codec, Wanted and ChehulNet. The upstream-only delta
since that common base is Wanted's round-two replay-memory repair, its tests and
documentation. It was preserved byte-for-byte by the mechanical merge; none of
the previously shared features was replaced with an older side.

## Merged-head verification

Run with `TMPDIR=/opt/data/cache/scratch` and
`LAYERENEMIES_LUA=/opt/data/tools/lua/lua-5.1.5/src/lua`:

```sh
timeout 1800 python3 test/verify.py
```

**RESULT: 1598 tests passed, 0 failed, 320361 assertions**

- Syntax: 88 Lua files pass; API/route policy and Python regression suites pass.
- TOC, media allowlist, archive integrity and exact source parity pass.
- Archive: `dist/LayerEnemies-1.1.0.zip`, 56 members, 262768 bytes.
- SHA-256: `b30ee0e06e1fa9bf3154a3bfa11f09f851521862b8be6a2a6f5e672367cee582`.
- The full run includes both timer-driven 120-click offset sweeps and both
  twelve-click stranger-traffic replays, plus every new review regression.

Every mutation pack below ran against the merged code, with a separate
`timeout 1800 python3 -B test/<runner>.py` invocation. ChehulNet uses `--write`.
No syntax failure or timeout is reported as a killed mutant.

| Runner | Killed / total |
| --- | ---: |
| `flh_batch_mutants.py` | 26 / 26 |
| `flh_rulings_mutants.py` | 20 / 20 |
| `flh_member_mutants.py` | 52 / 52 |
| `flh_mutants.py` (receive) | 39 / 39 |
| `hop_fanout_mutants.py` | 63 / 63 |
| `overlord_mutants.py` | 54 / 54 |
| `wanted_mutants.py` | 84 / 84 |
| `chehulnet_mutants.py` | 57 / 57 |
| `source_mutants.py` (registry/Battle.net) | 41 / 41 |
| `codec_mutants.py` | 56 / 56 |
| `presence_mutants.py` | 41 / 41 |
| **Total** | **533 / 533** |

`flh-main-validation.json` records the tested head, upstream/base/tree IDs,
verified totals, report hashes and archive hash. Totals were checked against
each runner's declared inventory, with unique mutation names. Packs that edit
source ran in private scratch copies; exact addon-byte restoration was verified.
Existing reports were retained when the rerun produced identical bytes.

### Execution limits encountered

Commands were requested in the foreground with explicit 1800-second bounds and
no shell backgrounding. The tool transport returned early at its shorter wait
limit for full verify, hop and Wanted; their still-running bounded subprocesses
were allowed to finish and their complete logs/results were read afterward.
The terminal backend also auto-promoted the 1800-second membership request to a
tracked job despite `background=false`; it was waited to **exit 0**, not rerun
or left running. These were tool wait limits, not test or mutant timeouts.
