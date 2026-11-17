# Stack 9: WarBoard loaded-addon silence

Base: `3ae8ffaa49e2f10c38e91a8d6678f351b47b0a3e` (`stack/9-warboard`).
Implementation: `1b9f293c9dae1984920189cb60576f625d513c8a`.
Scope: local commits only; levels 1-8 frozen; no push, version bump or native-client test.

## Owner ruling and implementation

While the real WarBoard addon is loaded, LayerEnemies sends **nothing** on its
network: neither H nor A. Receiving and reading continue. Two clients answering
for one player can otherwise overwrite the real addon's peer state remotely.

The shared Battle.net transport intentionally permits owed answers during generic
stand-down. Keep that policy unchanged for other sources. WarBoard now checks the
existing `N.Adapters.loaded("WarBoard")` adapter both before queue admission and
inside its final dispatch predicate. The adapter uses `C_AddOns.IsAddOnLoaded`
with the existing legacy fallback, not the presence of a donor saved table.
Discovery and all receive paths remain unchanged. The README's former owed-A
exception is replaced by one line stating full send silence and continued reads.

## Tests first: frozen-base RED -> GREEN

Only `test/src_warboard.lua` was copied into a detached worktree of the exact
base before production changed. The two stand-down regression cases failed for
actual A sends, not setup or syntax errors:

- Queued H and A, then donor load: expected no client sends, got one A.
- Thirty simulated minutes of incoming H: **0 H / 180 A** on the base, versus
  the required **0 H / 0 A**. All 30 fresh BN SHRD payloads still reached Find.
- Combined RED: `0 tests passed, 2 failed, 4784 assertions`.
- Admission-only intermediate: `1 tests passed, 1 failed, 4430 assertions`;
  new traffic was silent, but a previously queued A still sent. This independently
  demonstrated the need for the final dispatch check.
- Combined GREEN: `2 tests passed, 0 failed, 4569 assertions`.

The loaded-addon scenario also requires zero queue submissions and zero discovery
scans, reads matching H and A, refuses other-ruleset peer membership, and covers
incoming H from both matching and different rulesets. The transition case proves
queued H/A are dropped, cancelled work does not revive, and a fresh request can
be answered after the loaded flag is cleared. Existing addon-route stand-down
receive tests remain unchanged.

The identical donor-absent control passes on both the frozen base and the fix:
**3 H / 180 A**, 30 scans and 30 freshly admitted BN SHRD payloads over thirty
minutes; `1 tests passed, 0 failed, 5105 assertions` in each run.

The old test `stand down blocks own hellos but preserves owed answers` explicitly
contradicted the new owner ruling and was replaced by the queued-load regression.
Every other inherited test identity is retained; two additional identities cover
the loaded and absent thirty-minute cases. Focused WarBoard suite:
`77 tests passed, 0 failed, 142596 assertions`.

## Verification and mutation evidence

`python3 test/verify.py` completed in the foreground with a 1800-second subprocess
timeout, no background job, exit 0 after 320.03 seconds:

```text
RESULT: 1593 tests passed, 0 failed, 403987 assertions
```

Lua 5.1 syntax, static/API policy, TOC/media checks and archive integrity/source
parity passed. Archive SHA-256:
`24fe0a7d456907b0ebd54ad01eca8b5cab1e88b21c2ebc8ed697fab99d2a8fc7`.

Exactly one new mutant removes the final donor-loaded dispatch guard. It is
assertion-killed by the queued-load regression (expected 0 sends, got 1). All
**112/112 WarBoard mutants** were killed on two complete runs; no survivors,
syntax errors or timeouts were counted as kills. The existing stand-down mutant
is still caught by the explicit zero-discovery assertion. Report bytes and mtime
are unchanged on the second run; report SHA-256:
`955cf53237ff72818aa95bb64e4bb0cd15f66b97a21e0b659ec01164b05709a0`.

Author self-review: only `LayerEnemies/WarBoard.lua` changed in production (two
loaded checks). Shared transport, other sources, receive code and package version
are unchanged; static added-line security scan is clear. Verified source hashes
are unchanged since the full gate. No blocker encountered. Native checks not run
(alpha, owner's decision).

Raw logs and audit: `/opt/data/cache/scratch/le-warboard-standdown-evidence/`.
Generated test, verification and mutant notes are committed separately from the
implementation. The external stack ledger records the final head and evidence.
