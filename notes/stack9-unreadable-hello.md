# Stack 9: unreadable WarBoard hello accounts

Base: `920b51749b93ae04f5265f247583b59a2b1cf2ca`.
Upstream main: `2675e03d9363d4299a02d6d60815e0d65298967c`.
Merge: `e328544b5a88b1e8edc76f3a20cd8ad4c2daaad7`.
Implementation: `3518a0e35111729b24ad7a2768a6d0e894c009bd`.
Scope: local commits on `stack/9-warboard`; no push, version bump or lower-level edits.

## Content-neutral upstream merge

Fetched `https://github.com/buiden/LayerEnemies main` and confirmed that its tree
matches `stack/8-chehul` (`b24dee293df29cd9196187e97248484b16d916f8`):
`654471959c9e4d4fae99ba6d66e76c1ef18b612b`.

The two-parent `--no-ff` merge has parents equal to the base and fetched main.
Both `git diff BASE MERGE -- LayerEnemies/` and the unrestricted diff are empty.
The complete tree is unchanged at `5ca2036fd70b6bd9cc3e8f7a1b114e4f5b59aaf7`.
Main is now an ancestor, so this branch can be proposed directly against main.

## Fix and tests first

`WarBoard.lua` now validates the live account identity before charging a readable
selection. An unreadable account advances the ring mark without being counted,
queued or charged a hello cooldown. Readable queue refusals still do not advance
the mark or spend admission cooldown. The loop remains bounded by the roster.
All selection, scan, cooldown, queue, pacing and transport caps are unchanged;
shared transport, receiving and real-addon stand-down are untouched.

Only the augmented `test/src_warboard.lua` was copied into a detached worktree of
the exact base for RED. The real adapters and shared queue remained in use.

- Reviewer scenario: 45 opposite-faction accounts, with accounts 81-102 forming
  a consecutive block of 22 unreadable character names. Before: **10/23** readable
  accounts greeted in 60 simulated minutes, **0/13** after the block. After:
  **23/23**, including **13/13** after the block.
- All-readable control: **45/45** before and after, **13/13** in the final group.
- Full added-case baseline: `1 tests passed, 4 failed, 17983 assertions`.
  Three failures show 10 rather than 20 readable selections; the fourth shows
  the reproduced 10/23 reach. None is a setup or syntax error.
- Excluding unreadable names from the count alone makes the reach cases pass,
  but the independent missing/secret/throwing-name cursor tests remain RED:
  `0 tests passed, 3 failed, 273 assertions` (mark 80 rather than 102).
- Final five cases: `5 tests passed, 0 failed, 20281 assertions`. They also check
  the exact ten-slot admission cap, readable refusal behavior, no unreadable
  cooldown, next-pass order, sixty-second scan, six-hundred-second hello gap,
  ten-per-minute WarBoard limit and shared one-second pacing.
- Focused WarBoard suite: `82 tests passed, 0 failed, 162877 assertions`.

## Full gate and mutation evidence

`python3 test/verify.py` ran in the foreground with a 1800-second subprocess
timeout, no background job, and returned exit 0 after 392.12 seconds:

```text
RESULT: 1598 tests passed, 0 failed, 424268 assertions
```

All 1593 inherited test identities are retained; exactly five were added.
Lua 5.1 syntax, static/API policy, TOC/media and archive integrity/source parity
checks pass. Archive SHA-256:
`c9990039a034a85e22c642c671a0209cc41c0903d37c2625ff1d41fd0c58b0fd`.

Exactly one new WarBoard mutant restores the old counting/cursor loop and fails
all four defect cases by assertion. The inherited refused-cursor mutant's anchor
was moved into the new identity branch without changing its behavior or selector.
Both complete runs kill **113/113** mutants, with no survivors or setup/timeouts
counted as kills. Report bytes and mtime remain identical on the second run;
report SHA-256:
`937d8b0729dd1bf54227db0c748ea2d3c17b7c43977e0137d225ecdc3e368666`.
Every inherited mutant result is unchanged apart from Lua/Python source line
numbers shifted by the additions. The runner's normalization/write logic is unchanged.

Author self-review: no independent reviewer run. Added-line security scan is
clear; verified source hashes are unchanged after full verification and mutation
runs. All eight lower refs remain exact. No implementation blocker encountered.
Native checks not run (alpha, owner's decision).

Generated test, verification and mutant notes are committed separately from the
implementation. The external stack ledger records the final head. Raw logs and
read-only audit: `/opt/data/cache/scratch/le-warboard-unreadable-evidence/`.
