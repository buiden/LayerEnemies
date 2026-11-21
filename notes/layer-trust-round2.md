# Layer trust round-2 correction evidence

Scope: the seven lead rulings, one fix commit on the reviewed tip. No push,
version change, SavedVariables change, wire shape/route change or budget change.
No donor code. All new text is ASCII. Native game checks not run (alpha,
owner's decision).

## RED/GREEN

The regression files were written and observed failing before their production
fixes. The final versions were also replayed on a detached worktree of the
reviewed tip; the RED columns below are that unchanged-runtime replay, not
estimated failures. New pure guard tests are supplementary mutant controls,
not counted as behavioral RED evidence.

| Item | Change | Reviewed-tip RED | Candidate GREEN |
|---|---|---|---|
| 1 | Queued own embassy C/H are projected again by the queue callback at dispatch; remote C stays 9000. | RESULT: 5 tests passed, 4 failed, 505 assertions | RESULT: 9 tests passed, 0 failed, 507 assertions |
| 2 | Group contradictions require post-join peer claims and matching post-join NPC confirmation. O/K use origin age, not delivery time. | RESULT: 2 tests passed, 10 failed, 618 assertions | RESULT: 12 tests passed, 0 failed, 634 assertions |
| 3 | Hop contradictions require a matching post-join NPC read, not a cached key or Bulo refresh. | RESULT: 1 tests passed, 3 failed, 224 assertions | RESULT: 4 tests passed, 0 failed, 271 assertions |
| 4 | Same-full-key Bulo/NPC corroboration within EXCUSE_WINDOW counts once; later/distinct changes still count. | RESULT: 1 tests passed, 2 failed, 145 assertions | RESULT: 3 tests passed, 0 failed, 153 assertions |
| 5 | Open found popups repaint live status on polls and event-time trust transitions; lifetime, identity and map action stay fixed. | RESULT: 1 tests passed, 4 failed, 299 assertions | RESULT: 5 tests passed, 0 failed, 317 assertions |
| 6 | Guild R rebuilds retain the sender layer in unknown/blind. The old opposite boundary assertions and README policy are corrected. | RESULT: 0 tests passed, 2 failed, 100 assertions | RESULT: 2 tests passed, 0 failed, 110 assertions |
| 7 | Automatic changes print local reason/recovery lines once per transition with a named ten-second limit. Manual controls add no second notice. | RESULT: 2 tests passed, 3 failed, 245 assertions | RESULT: 5 tests passed, 0 failed, 254 assertions |

The independent reviewer's queue, transport and held-UI probes were executed
without rewriting their assertions: 6/0 (338 assertions), 6/0 (317), and 5/0
(317), respectively. Own queued C/H reached the captured client API with zero
in unknown/blind; remote C and R retained 9000. The Bulo corroboration sequence
now counted 1, 1, 2 and stayed known after its second actual change.

## Fixture migrations and extra boundaries

- The two inherited pure contradiction tests and two live trigger fixtures now
  provide explicit post-join NPC reads/peer claims. Thresholds and negative
  cases stay; pure hop controls now have known own state because they read it.
- Group tests include stale, equal-time and fresh claims/reads, Bulo-only
  refresh, and O/K delivery after join carrying pre-join or equal-time ages.
- The popup regression also proves a guild event repaints before the next poll,
  rather than hiding the popup or resetting its timer.
- The queue callback may return refreshed bytes; Wire still validates those
  bytes through its unchanged route checks and spends unchanged budgets.

## Rulings

- Blind remains sticky, as the plan requires. No new automatic blind-clear
  algorithm is introduced. The transition notifier supports recovery; the real
  automatic recovery test is unknown (expiry) to known (fresh NPC reads).
- The reviewed claim-age rule applies to the observation's carried age, not
  just packet reception; otherwise a delayed O/K could falsely become fresh.

## Mutation inventory

All 31 inherited Trust mutant tuples and anchors are unchanged; none removed.
Added 25 guards for queued own/remote payloads, NPC/peer freshness,
corroboration identity/window and local notice transitions/rate limits.
Re-anchors: none. The first run killed 53/56; the three survivors were
`npc-key-match`, `notice-manual`, and `notice-once`. Added controls for a donor
change following a mismatched NPC, manual cancellation of a rate-limited
pending notice, and a repeated poll beyond the notice cooldown. These controls
pass on the unmutated candidate; they are not counted as feature RED tests.
Final rerun: `RESULT: 56/56 Trust mutants killed`. All 31 inherited mutants
remain killed. The three initially surviving new guards were killed after
those additional controls. Focused baseline: `RESULT: 78 tests passed, 0
failed, 4720 assertions`.

## Verification

The first complete gate reached `RESULT: 2466 tests passed, 1 failed, 665256
assertions`. The unchanged Round1 polling cost test caught the popup status
callback rescanning Find on initial render and stable refreshes: 35 visits +
140 lookups exceeded its 25-operation cap. Reused the already projected status
until the own trust key changes; the cap and original test are unchanged.
Focused RED: `RESULT: 0 tests passed, 1 failed, 73 assertions`; GREEN:
`RESULT: 1 tests passed, 0 failed, 96 assertions`. Trust regressions after that
fix: `RESULT: 78 tests passed, 0 failed, 4720 assertions`.

Final background gate, via the shared heavy-job wrapper:

- `python3 -I test/verify.py`: exit 0; `RESULT: 2467 tests passed, 0 failed,
  665279 assertions`.
- Python verifier/API/harness/assets checks: 46/30/4/4/11 tests, all OK.
- Lua 5.1.5 syntax: 142 files PASS; 5000 fuzz inputs; TOC/static checks PASS;
  1.2.6 archive integrity and source parity PASS.
- Post-correction mutation sweep: `RESULT: 56/56 Trust mutants killed`.
- Independent unchanged queue/transport/held-UI replay after the cost fix:
  6/0, 6/0, 5/0, with 338/317/317 assertions.
- ASCII/private-path/security addition checks PASS; unchanged TOC, Net,
  WeOut, Protocol and Share; Wire diff confined to its queue pump. Trust is
  127 lines. No inherited mutant removed or re-anchored.

README index-tree preflight against the PR base (the same README bytes are
committed; the checker is also run on final HEAD before reporting):

```text
ok @@ -1880,1 +1880,2 @@ in: ## Local observations
ok @@ -1937,0 +1939,67 @@ in: ## Layer trust and hidden IDs
hunks=2 version_section_hunks=0
```
Final review: author self-review (no subagent tool); the independent review lane
belongs to the parent. No additional reviewer was fabricated.
