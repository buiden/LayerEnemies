# Layer trust round-3 corrections

Scope: lead rulings A-E, one fix commit on the reviewed tip. No wire fields,
routes or budgets changed; version 1.2.6 and SavedVariables remain unchanged.
No donor code. New text is ASCII and contains no private paths.

## Observed RED/GREEN

Every runtime correction followed a failing regression. The final regression
files were also replayed against a detached copy of the unchanged reviewed
runtime. The RED totals below are that replay, not estimates.

| Item | Correction | Reviewed runtime RED | Candidate GREEN |
|---|---|---|---|
| A | Track joins by normalized member identity from readable rosters; peer claims must postdate both joins. Removed/unreadable members lose admission history. | 2 passed, 4 failed, 286 assertions | 6 passed, 0 failed, 292 assertions |
| B | Repeated full transition keys coalesce without an elapsed-time limit. A different intervening key remains a distinct change. | 3 passed, 2 failed, 247 assertions | 5 passed, 0 failed, 255 assertions |
| C | At dispatch, zero the own C/H layer if it differs from the current trusted server key. Do not rebuild historical evidence onto another layer. | 10 passed, 2 failed, 683 assertions | 12 passed, 0 failed, 684 assertions |
| D | A readable-again notice requires an automatic blind ON actually printed in this session; consume the pair and cancel it on manual controls. | 3 passed, 6 failed, 446 assertions | 9 passed, 0 failed, 453 assertions |

The independent review's eight mock-client repros were copied without changing
any assertions. RED: `RESULT: 3 tests passed, 5 failed, 462 assertions`.
GREEN: `RESULT: 8 tests passed, 0 failed, 464 assertions`.

E was small enough to include: Find alerts return the current poll's projected
rows and the final popup refresh uses them. Early poll group checks defer
feedback/repaint until poll finalization; event-time changes still refresh immediately. No persistent
cache or polling-state flag was added. The reviewer expiry-cost repro moved
from 2 Find calls / 10 visits / 40 lookups to 1 / 5 / 20, within its unchanged
25-operation cap. Stable polls remain 1 / 5 / 20. Existing held-popup tests
retain the name, map action, generation and original close deadline.

## Boundaries and fixture migrations

- A covers a later peer join, equal-time claim, fresh claim, peer leave/rejoin,
  members already present at our join, and absent/equal/newer peer admission.
  Existing pure group fixtures now explicitly supply the peer join timestamp;
  no old threshold, freshness or continuity assertion was relaxed.
- B covers 0, 10, 10.1 and 30-second confirmations and Bulo X / NPC Y / NPC X.
  The obsolete expectation that a 10.1-second confirmation counts twice was
  migrated. The same-source guard now follows the same-key rule; rollback and
  distinct-key controls remain.
- C fills the real four-per-target whisper budget before queued own C/H move
  from trusted 7086 to trusted 9000, without expiry. The delivered old layer is
  zero. Same-key positives, unknown/blind masking, all nonlayer bytes, remote C
  and remote R claims remain covered. Reviewer expiry/recovery-to-9000 H now
  reaches the captured client send with zero, not stale 7086.
- D covers ordinary expiry, zone and Bulo recovery, unprinted pending blind ON,
  manual cancellation, cooldown edges and consumed pairs. Blind remains sticky:
  notifier positive-pair tests explicitly simulate an automatic clear and do
  not claim that a new production auto-clear path exists.

## Mutation inventory

All 56 inherited mutant IDs remain. Eight new entries cover peer admission,
its strict edge, dispatch key equality, reintroduced corroboration delay caps,
and required/emitted/consumed/manually-cleared notice pairs.

Seven inherited entries are re-anchored: `we-own-only`, `we-known-control`,
`coalesce-source`, `coalesce-window-edge`, `coalesce-window-late`,
`notice-manual`, and `notice-recovery`. The old corroboration source/window
mutants now reintroduce the rejected restriction rather than mutate a removed
condition. The other re-anchors target the same guard in its new spelling.
No mutant was removed. The first sweep killed 63/64; `notice-manual` survived
because the existing manual cancellation control also changed trust state,
which independently cancelled pending feedback. Added a same-state `blind off`
control: unmutated notice suite 10/0, 503 assertions; the exact unchanged mutant
fails 0/1, 49 assertions with an unwanted recovery line. This supplemental
mutant control is not included in the feature RED column. Final rerun:
`RESULT: 64/64 Trust mutants killed`, exit 0. All 56 inherited IDs remain killed.
Focused baseline: `RESULT: 94 tests passed, 0 failed, 5546 assertions`.

## Final verification

Both long gates ran in supervised background jobs through the shared heavy-job
wrapper, with their actual exit codes and logs read after completion.

- `python3 -I test/verify.py`: exit 0;
  `RESULT: 2491 tests passed, 0 failed, 666543 assertions`.
- Python verifier/API/mutant-harness/source-harness/assets suites:
  46/30/4/4/11 tests, all OK.
- Lua 5.1.5 syntax: 144 files PASS; 5000 fuzz inputs; TOC/static checks PASS;
  1.2.6 archive integrity and source parity PASS.
- Archive SHA-256:
  `3f31f07271c1e170a9f2b0786ebeddd8b90e0dd0ca4720753a0727b49b7ac6a0`.
- ASCII, private-path and unsafe-code addition scans PASS. TOC, Wire, Net,
  Protocol, WeOut and Share are byte-identical to the reviewed tip.
- README edits are confined to the existing layer-trust feature section.
  The version-section checker is also run against final HEAD before reporting.

The first full gate already passed (2490/0, 666493 assertions); it was rerun
in full after adding the same-state manual-cancellation mutant control.

Author self-review only; independent release review belongs to the parent
lane. Native client testing not run (alpha, owner's decision).
