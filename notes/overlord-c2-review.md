# C2 reviewer rulings

Base: dc4f3fa5683483a73904cbc6cac2e9eb60681744. Local branch `fix/c2`.

- M2: real-addon-loaded detection remains Net -> Adapters.loaded. Main, Wire and BNet now deny every Overlord send, including owed replies and already queued work. Receive remains active. No new client API or SavedVariables.
- S1: NH and HA share `reply:<canonical peer>` for both admission and actual dispatch: 150 seconds, with the existing six owed replies/minute cap.
- N1: round-robin directory cursor; forty stable unanswered candidates all receive their turn within forty eligible minutes. Queue/gate refusal does not charge candidate, global greeting or actual-send cooldown. An actual client attempt still charges even if refused; no retry of a client attempt.
- Owner ruling: no off-switch withdrawal and no map answers. LE does not host maps.

## Tests first

Before each implementation: M2 0 passed / 2 failed; S1 0 / 1; N1 peer suite 30 / 3. Failures were the new behavioral assertions, not setup errors.

Copied only the final peer test file into a detached worktree at the frozen base: `RESULT: 27 tests passed, 6 failed, 12034 assertions`. Intentional assertion migration: the previous donor-loaded owed-NH permission is replaced by complete silence.

Final peer suite: `RESULT: 33 tests passed, 0 failed, 12250 assertions`.
Full `python3 test/verify.py` in foreground, subprocess timeout 1800 seconds:
`RESULT: 1483 tests passed, 0 failed, 269081 assertions` (exit 0).
TOC, syntax, static policies, deterministic archive integrity/source parity passed.
Archive SHA-256: `037ad03cba55ab9bbf35c9a736f19578b7ffa8662779bce329d8c14d170cfbdd`.

Mutants: peer 53/53; retained receiver 54/54. Eight new peer mutants cover the three donor-silence gates, shared reply gap, rotation, refused admission, refused greeting global cooldown, and Wire refusal actual cooldown. Retained receiver runner retargeting (original C3 commit b8216ea) moved down to C2, where its bounds belong. Portable scratch-copy reruns from `/opt/data`, outside either checkout, passed with identical JSON bytes and unchanged report mtimes.

Raw local logs: `/opt/data/cache/scratch/overlord-rulings-evidence/` (`c2-verify.log`, `c2-frozen-red.log`, individual RED/GREEN logs and `c2-portable.json`). A combined four-run portability call exceeded the tool's outer 420-second wait; smaller foreground reruns completed and produced the evidence above. No timeout counted as a pass or mutation kill.

Native client checks: not run (alpha, owner's decision). No donor code copied or executed. No push or GitHub writes.
