# Stack reviewer corrections (local only)

Scope: levels 3–8; `stack/1-ui` b62875efa22564c7a72a833ff4854e7880850be2 and
`stack/2-hop` a7a65e4f5a9c6db986ed140329ffb4c720965299 remain frozen. Forward
integration uses two-parent `--no-ff` merges, with no push or GitHub write.
Evidence: `/opt/data/cache/scratch/le-stack-round2-evidence` and the sibling
`le-120-stack-ledger.json` (`stack_round2`). Native checks not run (alpha,
owner's decision); UI geometry uses width-aware harness metrics.

## Level 3: presence

- `Presence: measured presence cards keep several per page without overlap`:
  RED 26 passed / 1 failed / 11067 assertions (12px text got a 56px box),
  GREEN 27 / 0 / 11334. Remove both the 56px text minimum and the fixed card
  surcharge; retain other card floors and measure the complete presence line.
  Six names, community/friend labels, short/wrapped zones, all pages reachable,
  three short cards per page, no overlap, buttons clear, and pooled shrinkage.
- `Presence: only online community members resolve Battle.net accounts`:
  RED 27 / 1 / 11529 (50 lookups instead of 5 in the first tick),
  GREEN 28 / 0 / 13142. Gate Online/Away/Busy before reading account ID or
  Battle.net APIs; 100 online out of 1000 members now means 100 lookups, not
  1000. Offline rereads still withdraw prior evidence immediately.
- `PresenceMutantPortability.test_relocated_clone_with_relative_tmpdir`:
  RED on the owner-scratch assertion; GREEN after honoring standard tempfile
  selection. Exercises the actual CLI from a relocated clone and unrelated cwd
  with a relative TMPDIR, plus cleanup and full mutant results.
- Initial mutation run: 37/38 killed. The new adapter gate masked the legacy
  pure `accept Offline` mutant. Added an independent pure-admission assertion
  to the unchanged target test; it passes unmutated, so this is coverage
  strengthening, not a new production RED. All 38 old mutants are retained;
  three new layout/lookup mutants added. Final: **41/41 killed**. Exactly one
  legacy mutant was caught only after adding coverage.
- Full `python3 test/verify.py`: **1247 passed, 0 failed, 140773 assertions**;
  syntax/static/package/source parity all pass. Archive SHA256:
  `d4599ab650391b7ee9425d5033655da0fdd7ba6a3639735f0bab8463db222bd8`.

Rulings: reuse the assigned clone/ledger and retain previous evidence; implement
this explicit reviewer UI correction directly; keep the existing 1.1.0 package
version while preparing the 1.2.0 stack. No inherited assertion weakened.

## Level 4: forward merge from corrected presence

Only `notes/test-results.txt` and `notes/verification.json` conflicted; regenerated
both. Production, tests and README auto-merged. Full verify: **1276 passed,
0 failed, 160562 assertions**, all syntax/static/package/source parity gates pass.
