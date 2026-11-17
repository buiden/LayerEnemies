# E2 execution ledger — PLAN.md 8.5

## Round-2 correction on e1bc2239 (current)

- Frozen baseline: `/opt/data/cache/scratch/le-e2-r3-base`; reviewer files read-only.
- 946d487: M1 six assertion failures → all green; exception requires pending withdrawal.
- fb788bf: S1 four assertion failures → all green; donor 15/15, own offset 313 at 315s not 603s.
- dbbfcae: S2 four assertion failures → all green; A-only cannot confirm donor-owned cleanup.
- cb7b249: S3 three assertion failures → all green; six bounded attempts reopen each login.
- 5311971: N2 four assertion failures → all green; bounded unsafe roster inbox, current-GUID validation.
- Self-review adds unsafe H age preservation, README precision, inherited assertion migrations,
  per-ruling mutants and separate regenerated evidence. See `notes/warboard-track.md`.
- Ruling: queue overflow/unvalidatable held input retains uncertainty rather than silence success;
  this can delay cleanup but never reports a lost contradictory roster as withdrawal proof.
- dcc7e6f: deferred ingress rollback RED → GREEN; held evidence cannot drain before the clock guard.
- Final frozen e1bc2239 ruling pack: 24 passed / 26 assertion failures / 3365 assertions; candidate 50/50.
- Final full verify: 1537 passed / 0 failed / 220351 assertions, foreground timeout 1800 s.
- Final mutants: E1 100/100, tracking 109/109; relocated real reruns preserve report bytes and mtime.
- Self-review only in this subagent; parent review independent. Evidence commits remain separate.
- No publication, install, donor execution or native client tests.

## Historical first-round ledger (superseded where above differs)

Authority: /opt/data/handoffs/2026-11-17-le-1.2.0/PLAN.md sections 1, 3, 8.5; audit-warboard.md 1.6.3. Base 65904e66. Local commits only.

- Preserved inherited unfinished work as 82fcf57 after its 45 tests passed (3669 assertions). Its cancellation gates, persistence, rates, server clock and disclosure contradicted the binding spec. Superseded all old rulings in this file.
- New spec tests on WIP: 16 passed, 23 failed, 2945 assertions. On detached 65904e66 with only the test file copied: 3 passed, 36 failed, 2821 assertions. Log: /opt/data/cache/scratch/le-e2-base-red.log. Three baseline passes are negative guards, not new-feature evidence.
- Pre-flight: BN.send returns admission, not API acceptance. Add completion callbacks, preserve Wire's caller frame and shared budgets; settle debt only on actual success.
- Pre-flight: disabled Sources must allow cleanup ticks and incoming H/A only when debt exists; all other traffic remains switched off.
- Ruling: tracking switch is session-only, defaults on at login. Only one new saved field is authorized and switch persistence was not specified. Existing source/share/consent settings stay saved.
- Ruling: restore every prior-session debt as closing before asking again, including still-tracked names. Conservative cleanup before a new subscription costs a possible extra FBUN, never expands FBAK scope.
- Ruling: inherited local combat/instance retirement remains, now retaining rather than dropping cleanup. Costs a fresh-start pause after local combat but avoids unwithdrawn subscriptions.
- Source check: CurseForge files page still lists Forever 1.6.3 / 9639808 as newest Forever release. No source drift requiring a new wire audit.
- Native checks not run (alpha, owner's decision). No donor code copied/executed.
- Ruling: new FBAK requires an A-confirmed peer; an H alone permits E1 receiving but not tracking. Cost: conservative reach until A, rather than acting before our handshake answer is known to the target.
- Lifecycle/rates complete: 7add70a; bounded debt/state and behavior mutants: f033564.
- Final review: self-review (no independent reviewer tool in this subagent lane). Fixed pre-stop handshake incorrectly bypassing a later stale give-up: regression RED (`expected 1, got 2`) then GREEN; commit 6b57dca. No deferred minor fixes.
- Final detached-base RED at 65904e66: 5 passed, 53 failed, 3880 assertions; only final test file copied. Candidate: 58 tracking tests; combined WarBoard 159 passed, 0 failed, 39616 assertions.
- E2 mutants complete: 64/64 killed; rerun bytes and mtime unchanged; relocated clone with spaces/unrelated CWD/relative TMPDIR produces identical JSON and cleans scratch. E1 mutants 98/98 killed.
- Full foreground verify complete: python3 test/verify.py, 1750-second subprocess timeout / 1800-second tool timeout, exit 0; RESULT: 1455 tests passed, 0 failed, 214806 assertions. Log /opt/data/cache/scratch/le-e2-verify-current.log. Generated notes are committed separately.
- Final report and every inherited assertion migration: notes/warboard-track.md. Archive SHA-256 243625edcbe3a0c45f6947ae267352b314f3574d6354de8eb9057e72c5b45468. Local-only 1.1.0 foundation package; 1.2.0 version bump belongs to release integration.
