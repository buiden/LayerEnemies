# C3 reviewer rulings — corrected engine, feed unavailable

Base for this separately openable C3: corrected C2 `a72c529d2c0c4d8ad87c9014293e6c5f017788d9` (`fix/c2`, `le-1.2.0-c2-overlord-peer`). C3 is on `fix/c3`; production/test/doc commit verified below: `d4c16ad8c88bc9ef6ee5deadd433eeb42c886ba1`. The following evidence-only commit is the C3 head/tag. Original C3 `cef328ac` is retained by `backup/overlord-c3-review`; only its implementation commit was rebuilt, not its obsolete evidence claims.

## M1: honest capability decision

**The feed remains unreachable, deliberately.** Shipping NH is `LayerEnemies 1.1.0` (the installed TOC version), capability suffix empty, parsed by the donor as **5**. No feed HR request or keep-alive is emitted. `Q.available=false` is a fixed ship gate, not a player option. Most feed fixtures explicitly lift it to test the dormant engine; those passes must not be described as live interoperability.

The donor is Overlord 2.5.4, `c821808586ab50bb4ccb5d54b146e0d7c2671734`. A read-only `git ls-remote` recheck found both upstream HEAD and tag 2.5.4 still at that commit. Donor source was read, never executed or copied. The test-side capability parser was independently written as a chain walk, with positive and negative vectors and assertions on the actual emitted NH payload.

| Token | Meaning, from donor source | Implemented by LE? |
|---|---|---|
| `~lp6` | Paged leaderboard protocol 6, including multi-stream page exchange: `SyncRelay.lua:69,2843-2844`; `SyncLeaderboardPages.lua:2943-2947,3011-3027` | No |
| `~lr` | Protocol 7: race on ranking rows: `SyncRelay.lua:2662-2663`; `SyncLeaderboardPages.lua:2943` | No ranking exchange; a race-aware feed parser alone is insufficient |
| `~ld` | Protocol 8: differential ranking exchange, fingerprint/list/data operations: `SyncRelay.lua:2664`; `SyncLeaderboardPages.lua:2544-2714` | No |

The cumulative **`~ld~lr~lp6`** chain reaches 8 (`SyncRelay.lua:2843-2851`). `~lp8` reads as 5. `lr` means ranking race support, **not relay**. These tokens do not themselves impose transport forwarding, but they are also not standalone permission to consume a feed. An always-busy responder plus an empty comparison does not implement the claimed page protocols.

PLAN section 6 is a tracked-name/location feed client, not a general ranking synchronization host. Its truthful-empty-answer duty does not authorize an unimplemented page-capability claim. Per the owner ruling, do not expand into ranking fingerprint/page synchronization merely to force admission: use the fail-closed alternative and report the unavailable feature. The donor drops a known capability below 8 before subscription (`SyncLeaderboardPages.lua:2962-2967,3031-3092`; audit line 84 and sections 6.7/7.1). No false capability was substituted.

Also corrected an honesty defect in the owed HA path: `HA S ...:0:0` claims equality, not simply an empty local store. It is now used only for requester count/hash zero; a nonempty requester gets bounded `HA R` instead.

## S2–S4

- **S2:** only exact thirteen-field owner K with valid race, sex, matching bucket epoch, class, faction, owner, level and other bounded fields can teach E. Race and sex precede bucket/level. Missing fields, 12-field garbage tails, extra fields, bad race/sex and mismatching bucket are rejected. This intentionally rejects the donor's optional shorter K, per the owner ruling (`SyncAux.lua:2010-2021`).
- **S3:** optional feed identity race is a validated donor string, including `o2`, `Skyborne3`, `h0`, `Orc2`, not an integer. Malformed/unknown race strings remain rejected. Full identity followed by compact update is exercised (`SyncAux.lua:1824-1896`; `SyncLeaderboardPages.lua:1831-1840`).
- **S4:** successful queued HR receipt uses current dispatch context, including fresh BNet identity/route context. An intervening accepted NH can refresh the route without the stale enqueue clock discarding the eventual feed answer. Failed sends and changed/invalid routes still grant no lease.

README and THIRD_PARTY document these limits. No off-switch stop message; no map answers (LE does not host). **Source correction to the supplied rationale:** the donor keeps subscriptions for **900 s**, not 200 s; 200 s is its keep-alive interval (`SyncLeaderboardPages.lua:151,2048`). The no-stop decision is retained, local state cancels immediately, and this shipping build opens no remote feed subscription anyway.

## Tests first: observed RED, then GREEN

Logs are under `/opt/data/cache/scratch/overlord-rulings-evidence/`.

| Rule | Valid-fixture pre-fix result | Passing evidence |
|---|---|---|
| S2 | `c3-s2-red.log`: 0 passed, 1 failed, 83 assertions (12-field K taught E) | `c3-s2-green.log`: 33 passed, 0 failed, 16980 assertions |
| S3 | `c3-s3-red.log`: 0 passed, 1 failed, 42 assertions (`o2` rejected) | Combined S2/S3/S4 suite below, then full verify |
| S4 | `c3-s4-red-valid-wire.log`: 0 passed, 1 failed, 46 assertions (successful receipt lost) | `c3-s234-green.log`: 108 passed, 0 failed, 49258 assertions |
| M1 | `c3-m1-red.log`: 35 passed, 2 failed, 17558 assertions (false suffix, request still emitted) | Final Overlord suite below |
| HA honesty | `c3-honest-answer-red-valid-fixture.log`: 0 passed, 1 failed, 43 assertions (false S equality) | Final Overlord suite below |

The first S4 experiment accidentally supplied a fractional wire timestamp, so NH was refused before refreshing the route. It is **not** RED evidence. The corrected fixture floors wall time and asserts that route time changed before checking the receipt. An earlier HA experiment used an absent helper and is also excluded; the cited RED uses a complete valid context.

Final Overlord suite: `RESULT: 111 tests passed, 0 failed, 49402 assertions` (`c3-m1-green.log`).

Copied only the final feed test file into a detached worktree at original C3 `cef328ac`: `RESULT: 4 tests passed, 34 failed, 1810 assertions` (`c3-frozen-red.log`). This is a compatibility regression comparison, **not 34 independent bug proofs**: many later failures cascade from replacing old invalid K fixtures with strict thirteen-field owner records. The isolated sequential RED runs above establish the individual defects.

## Full verification and mutation evidence

`python3 test/verify.py` ran in the foreground with a subprocess timeout of 1800 s, Lua 5.1.5:

`RESULT: 1521 tests passed, 0 failed, 286706 assertions` — exit 0 (`c3-verify.log`, `c3-verify-status.json`).

TOC, Lua syntax, static/API policies, build, archive integrity/source parity all passed. Regenerated `notes/test-results.txt`, `notes/verification.json`. Archive: `dist/LayerEnemies-1.1.0.zip`, SHA-256 `8261a0843ef2d25f20df4ff84726afd3409ab1caca28fcf12d1581c53e29e396`.

Mutants: retained peer **53/53**, receiver **54/54**, feed **63/63** killed. New feed mutants cover exact K arity, missing race, garbage short tail, race validity, sex validity, race-string acceptance and rejection, fresh receipt context, fail-closed gate, and false HA equality. The capability suffix mutant is retargeted to the actual shipping empty suffix. Each mutation matches one exact source anchor; syntax errors/timeouts are not kills.

All three runners were also run from `/opt/data` against an isolated copied checkout, with `--write`. Reports matched the main checkout byte-for-byte, and an unchanged report retained its mtime. See `c3-feed-portable.json` and `c3-peer-portable.json`. The peer+receiver portability wrapper exceeded the tool's outer 420-second wait, but its foreground child finished: the final JSON records both exit codes 0 and byte/mtime checks true; no matching child remained. No timeout was counted as a pass.

C2's independently verified checkpoint remains unchanged: `RESULT: 1483 tests passed, 0 failed, 269081 assertions`, peer 53/53 and receiver 54/54 mutants. See `notes/overlord-c2-review.md` at its tag.

Native client checks: **not run (alpha, owner's decision)**. No claim of working live feed, no donor execution/copy, no SavedVariables additions, no push and no GitHub writes.
