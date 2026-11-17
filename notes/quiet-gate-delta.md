# Quiet gate delta: exact presence statements and immutable guards

## Outcome and scope

Reviewed base: `8bb8e133232f311f8664d3dd41dca9f664b78b6a`. Verified implementation head: `c640864121bdbd26fba01fa93c6cdc08b7d11fe8`.

- `test/verify.py` now exempts only the two complete presence statements at `Wire.lua:176-177`, token-exact and exactly once each, with an RHS-end check. Operator/member prefixes, extra predicates, missing/extra copies and longer RHS expressions are refused. The two existing protected hook spans remain exactly-once exemptions; every other executable `SendChatMessage` reference remains forbidden.
- Guard checks run before any exemption is stripped, in **every addon Lua module**, not only Wire. Both `pcall` and `hooksecurefunc` are reserved: bare calls are allowed; `hooksecurefunc` also permits the existing `_G` call, `pcall` argument and `S.clean` inspection forms. Other references, including aliases and all declaration/assignment/binding forms, fail closed. Constant-key spellings are folded before this check.
- All **44 shipped Lua modules** pass unchanged. No runtime, README, send-route or package-content change was needed. No push, release or installation was performed.
- This supersedes the comparison-only exemption claim in the earlier `quiet-rulings-review.md`; an inner `== nil` token run was not safe because concatenation/arithmetic can invoke a metamethod first.

## Tests first: RED to GREEN

Only the augmented `test/test_verify.py` was copied to a detached worktree of the reviewed base. Its bytes match the candidate's final test file; the baseline gate and addon sources were unchanged. Command in each tree: `python3 -I -B test/test_verify.py`.

- RED on the exact base: **31 test methods, 423 failed subcases, 0 errors**. These are subcase failures, not 423 separate test methods.
- GREEN on the candidate: **31 test methods, OK**. The full verifier independently repeats this suite.
- The five exact reviewer forms are covered: modern concat, modern add, less-than, legacy concat and the prefixed `o.C_ChatInfo` member. A separate Lua 5.1 fake-function sentinel proves concat/add make **two calls**, without invoking a client send API.
- Each exact presence statement is tested for a third copy, removal, altered return prefixes and extended RHS expressions; standalone additional comparisons are forbidden. The old broad-comparison positive fixture was deliberately replaced with the exact-statement contract, while existing hook-focused fixtures now contain both required statements.
- All six requested direct assignment spellings are tested against every shipped module. Additional cases cover single/long/escaped/concatenated global keys, both positions in multiple assignments, locals, function declarations, parameters and loop variables, including Wire. Real calls and inert comments/strings remain positive controls.
- Initial presence-only cycle: 17 failing subcases to 26 test methods OK. Guard cycle: 396 failing subcases to 17 focused test methods OK. Further RHS-boundary tests first exposed 10 failures in the initial exact-prefix implementation; the final combined base replay and GREEN counts above include them.

The machine-readable evidence includes the per-method RED counts and the complete gate diff: **36 added / 17 removed lines** in `test/verify.py` versus the reviewed base. Full local logs and their hashes are recorded there; the tests and commands reproduce them without the reviewer's scratch files.

## Verification

`python3 -B test/verify.py`: foreground, explicit 1800-second tool/subprocess timeout, exit 0.

**`RESULT: 1528 tests passed, 0 failed, 263936 assertions`**

Also passed: 31 policy test methods, 13 API-owner tests, four harness-source tests, 11 media tests, syntax for 86 Lua files, 5,000 fuzz inputs, TOC/static checks, archive integrity/source parity and `git diff --check`.

- `python3 -B test/quiet_all_mutants.py`: **43/43 caught**.
- `python3 -B test/quiet_mutants.py`: **38/38 caught**.
- Both mutant runners used foreground execution and explicit 1800-second tool/subprocess timeouts. The changed guard invalidated one old mutation anchor; its preflight failed first, then the anchor was migrated to disable only the `pcall` reservation. Its existing assertions still catch it. No mutant or assertion was removed.

The regenerated `verification.json` and `test-results.txt` are byte-identical to the reviewed base. `quiet-all-mutants.json` changes only the expected renamed predicate-test diagnostics. The local archive is unchanged: SHA-256 `eb470c13452166a59691ce271d82d5885a0a3d46a832d62d27ddefd4468d2402`.

## Local commits and limits

- `65a3c019a9e74062f5d2b7fe505619fbc1833a06`: exact presence exemptions and first RED/GREEN tests.
- `c640864121bdbd26fba01fa93c6cdc08b7d11fe8`: addon-wide guard reservation, RHS boundary regression and mutation-anchor maintenance.
- This report, machine-readable evidence and regenerated mutant diagnostics are a subsequent **notes-only commit**.

Native checks not run (alpha, owner's decision). This is an offline source-policy correction, not new evidence of native taint or chat-entrypoint behavior.
