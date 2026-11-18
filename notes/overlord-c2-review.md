# C2 reviewer rulings

## Round-two M1 repair (current checkpoint)

Reviewed base: `a72c529d2c0c4d8ad87c9014293e6c5f017788d9`.
Implementation: `d5e02eb` (`fix/c2`); this separate evidence commit follows it.

The scheduler now scans past a locally refused member in the same bounded
one-directory pass, without spending either cooldown. It stops only after one
charged greeting. `Invite.name` supplies the canonical target and key, stripping
only the home-realm suffix before transport flight matching. Caps are unchanged:
one charged greeting/60 s, same canonical member no sooner than 600 s, six live
partners. Client attempts (including refusal) still spend the caps.

Tests-first, frozen base replay: only `test/src_overlord_rotation.lua` was copied
into a scratch `git archive` of the reviewed base. Real Main timers and Wire gates,
no directory-join side effects. `RESULT: 0 tests passed, 3 failed, 643 assertions`.
All three were behavioral count failures; no setup errors count as RED.

| Reviewer scenario, 40 members | Frozen base | Fixed |
|---|---|---|
| Member 1 already marked offline for 3600 s; 60 minutes | 1 greeting / 1 member | 60 / 39 reachable members |
| Member 5 returns client offline result 12; 180 minutes | 121 accepted, 124 attempted, 3 client refusals / 39 members | 177 accepted, 180 attempted, 3 client refusals / all 39 reachable members |
| Member 1 listed with own-realm suffix; 60 minutes | 0 | 60 / all 40 members |

The second case is **177 accepted, not 180**: the three actual client refusals
still consume a minute, as required. All attempt timestamps satisfy the 60/600 s
bounds. The two inherited pure rotation fixtures used invalid one-letter first
names; only those fixture spellings gained a `Dir` prefix, with every assertion
retained. New test instrumentation checks the actual Wire caller frame.

Focused GREEN: `RESULT: 36 tests passed, 0 failed, 13351 assertions`.
Full `python3 test/verify.py`: `RESULT: 1486 tests passed, 0 failed, 270182 assertions`
(exit 0; syntax, TOC/static policy, deterministic archive integrity/source parity
all PASS). Archive SHA-256:
`c8117dd1e061af88ee4f8f313bbf47fbde65fc9a4c8880357216ad95cf2f8bf9`.

Mutants rerun: **peer 54/54**, **receiver 54/54**. The new
`gate refusal blocks rotation` mutant restores the first-refusal break and is
killed by the offline rotation tests. Existing global-gap mutation anchor was
retargeted without changing its behavior. Syntax errors/timeouts are not kills.

Evidence directory: `/opt/data/cache/scratch/le-overlord-resume-evidence/`:
`c2-rotation-red-frozen.log`, `c2-peer-green.log`, `c2-peer-mutants.log`,
`c2-receiver-mutants.log`, `c2-verify.log`. Every runner executed synchronously,
with explicit 1800-second timeout. Final review: self-review (no subagent tool);
no additional must-fix found. Native checks not run (alpha, owner's decision).
Local commits/tags only; no donor code copied/executed, no push or GitHub writes.

## Historical first-round repair

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
