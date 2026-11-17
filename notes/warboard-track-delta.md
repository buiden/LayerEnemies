# WarBoard tracking: deferred-frame delta

Reviewed base: `66e82aea4945b8d789f2f862de46e220321829b6`.
Reviewer input (read-only): `/opt/data/profiles/mani/cache/scratch/t3/parent-verdict-e2-delta.txt`.
Local commits only; no push, install or donor execution.

## Corrections

- `4fb476b`: a multipart assembly retains receipt context from any debt-inbox part. A later live final part can process the roster for cleanup but cannot create Find evidence. Both combat and instance paths covered; the existing README's “cleanup-only, not delayed Find evidence” promise now holds across this boundary.
- `bece507`: assemblies retain resolved canonical character key and faction. A different character/realm on the same account discards the old chunks rather than completing them under the newly admitted peer. The tests establish the new handshake before completing the old frame and require zero decoder calls, then prove a fresh frame remains usable.
- `dfa7ba6`: a fully validated cleanup roster is processed input even if its timestamp is older than the accepted withdrawal. It is not a lost-input signal and therefore cannot erase the accepted mark or cause another FBUN. Retained partials likewise are not loss; their original 90-second expiry, invalid assembly disposal, or an invalid completed frame still retain uncertainty. Expiration runs before silence settlement, including eventless safe ticks.

Only `LayerEnemies/WarBoard.lua` changes in production. No settings, wire fields, SavedVariables, transport budgets or native API ownership changed. Tests are in `test/src_warboard_rulings.lua`; four additional behavioral mutants are in `test/warboard_track_mutants.py` (one per reported defect plus incomplete-assembly expiry).

## Reproducible evidence

Evidence directory: `/opt/data/cache/scratch/le-e2-delta-evidence`.
The detached `/opt/data/cache/scratch/le-e2-delta-base` is the exact reviewed base; only the updated regression test file was copied into it before each production fix. All RED failures are intended assertions, not setup errors.

- Cleanup provenance RED: **0 passed, 2 failed, 98 assertions**; initial GREEN: **2 passed, 0 failed, 100 assertions**.
- Identity binding RED: **0 passed, 2 failed, 96 assertions**; GREEN: **2 passed, 0 failed, 104 assertions**.
- Final exact-base delta pack: **0 passed, 7 failed, 336 assertions** (`all-red.log`).
- Final delta pack: **7 passed, 0 failed, 355 assertions**. Includes direct and multipart stale rosters (one FBUN only), and incomplete cleanup before/at the unchanged 90-second expiry.
- Existing deferred-inbox suite: **8 passed, 0 failed, 397 assertions**, including overflow, source-off, long wait, GUID change and rollback.
- All WarBoard/tracking tests: `RESULT: 248 tests passed, 0 failed, 45516 assertions` (`all-warboard.log`).
- Protocol mutants: `RESULT: 100/100 WarBoard mutants killed`.
- Tracking mutants: `RESULT: 113/113 WarBoard tracking mutants killed`; includes all 109 inherited rules plus four additions, no survivors. Tracking report SHA256: `8dc8eeb5ab2b1265ae80156b38e943c5f656d2ae8ddc72a43ee005bb617c0423`.
- Full `python3 test/verify.py`: `RESULT: 1544 tests passed, 0 failed, 220706 assertions`, exit 0; foreground subprocess timeout 1800 seconds, 283.33 seconds elapsed.
- Archive SHA256: `d4c33f64a00b589e31dffd81ae4cfd8fa4a1d077dbed0b747d776e2aa79deed1`.

Generated evidence and this report are committed separately from production fixes. Author self-review only; independent parent review remains separate. Native checks not run (alpha, owner's decision). Composition onto PR #33 is a separate stack/10 checkpoint.
