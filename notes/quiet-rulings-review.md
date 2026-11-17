# Quiet notice review rulings: verified follow-up

## Result and scope

- Reviewed base: `b054fae86e7deacd40aaea656e6d43006386dff7` on `fix/hide-own-not-found`; PR base remains main `2675e03d`.
- Verified implementation/test/README head: `39547c984be0183435ce3b190764c35e89826ce0`. This evidence is committed separately; no source changes followed the successful full run.
- M1, S1, S2, S3 and the mode-on note are implemented. No push, GitHub write, release or installation. Origin's push URL is `DISABLED`.
- Target remains Forever 1.60.1.70938 / Interface 16001. Existing source evidence remains pinned to `bebcb6bf309cf41b41bd74f8ca651e6a105b2676`; this follow-up does not claim new native API verification.

## Rules and RED → GREEN evidence

The new regression assertions were copied, with only their harness and policy tests, into a detached worktree at **b054fae8**. Production Lua and `test/verify.py` were confirmed unchanged there. The temporary worktree was removed afterward.

| Ruling | Implemented behavior | RED on reviewed base | Final GREEN |
| --- | --- | --- | --- |
| M1 | Invalid/unreadable/unfoldable or any non-ASCII typed WHISPER target records a timestamp-only protect-everything marker for 10 seconds. No invalid name is retained. | 14 runtime cases fail | 14 pass |
| Note (`on` too) | Matching typed targets and protect-everything markers override hiding in `on` and the `all` fallback, after unchanged own-receipt/offline bookkeeping. | 3 runtime cases fail | 3 pass |
| S1 | Ready requires a successful hook for every existing entrypoint and at least one installed hook. A partial install makes `all` behave like `on`; `/le net` names the missing modern/legacy hook. Successfully installed hooks still protect their observed targets. | 2 partial-install cases fail | 2 pass; inherited each-API-alone and neither-available cases also pass |
| S2 | At 16 occupied slots all matching notices show. A 17th distinct target does not evict an earlier one; it refreshes global protection for its full 10 seconds even after recorded entries drain. | 3 runtime cases fail | 3 pass, including both `all` and `on`, 15/16 boundary, duplicate-hook refresh and exact expiry |
| S3 | Each protected registration token span occurs exactly once; Wire reserves `pcall` for unbound bare invocations. Bindings/assignments are rejected before exemption stripping. | 18 failed policy subcases across the new duplicate/missing/shadowing tests | All 12 `WhisperHookPolicyTests` pass; full send-gate suite is 23 tests, OK |

Runtime baseline: **`RESULT: 0 tests passed, 22 failed, 1012 assertions`**. Final identical behavioral assertions: **`RESULT: 22 tests passed, 0 failed, 1741 assertions`**. The complete quiet selector is **`RESULT: 64 tests passed, 0 failed, 6074 assertions`**.

M1 includes every reviewer value: `Bob2`, `B`, `Bob.`, `Bobby_x`, `Anna Maria Lee`, 40 `A` letters, `Bob-`, string `12345`, `Bob Smith ` with its trailing space, and typed `élodie` versus line `Élodie`. Additional cases cover numeric `12345`, a non-ASCII realm, secret/table/false/nil targets, a throwing validator, refresh, strict expiry, rollback and reload. Each named invalid/non-ASCII case checks the failure itself **and unrelated targets** remain shown, then checks hiding resumes at expiry. ASCII case/home-realm/foreign-realm behavior stays covered by inherited tests.

Policy negatives include a third modern or legacy registration, a fourth copy, missing spans, `local pcall`, `local function pcall`, global/member/constant-key assignments, parameters, loop bindings and multi-name declarations/assignments. Inert comments/string literals remain accepted. Baseline policy output has **19** failures because the new S1 presence-predicate acceptance test also fails on the old gate; this is separate from S3's 18 subcase failures.

Logs: `quiet-rulings-baseline-*-red.txt`, per-ruling `*-red.txt`, `quiet-rulings-review-green.txt`, `quiet-rulings-final-green.txt`, and `quiet-rulings-s3-green.txt`. Test-label quoting changed only presentation after baseline replay; no tested target or assertion was normalized.

## Exact gate diff and safety boundaries

`quiet-rulings-gate-diff.json` preserves the full `test/verify.py` diff as a JSON string: **24 added / 5 removed lines**.

1. Before removing any exempt span, Wire's token stream reserves `pcall` for bare calls. Declarations, function definitions/parameters, loop variables, assignments and member aliases cannot turn a registration into a send.
2. Each of the two existing protected `pcall(_G.hooksecurefunc, ..., "SendChatMessage", observeChatWhisper)` token spans is required **exactly once** in Wire. Another file cannot use either exemption.
3. S1 requires existence checks. Only the primitive predicates `C_ChatInfo.SendChatMessage == nil` and `_G.SendChatMessage == nil` are additionally allowed in Wire. They expose only a boolean, never a callable reference. There is no generic `type`, helper-call, send-function alias or namespace exemption. A throwing member lookup is not proof of absence and still requires a successful hook.
4. The original `SendChatMessage` reference ban, namespace-escape rejection, and single `SendAddonMessage` access in `deliver` remain in place. The older Lua raw-text guard recognizes only the corresponding inert names and primitive comparisons; the Python token gate remains authoritative.

`quiet-rulings-main-gate-comparison.json` executes the same reviewer shadowed-pcall plant against three gates: main rejects it with **`chat namespace escapes: Wire.lua`**, b054fae8 accepts it, and the candidate rejects the `pcall` binding. An unrelated chat-namespace escape still produces main's exact rejection on the candidate. This is not merely rejection by the new missing-span check: the fixture includes both required spans.

`quiet-rulings-invariants.json` verifies byte-identical own correlation/offline bookkeeping, event evidence consumption, and the complete delivery/budget tail versus b054fae8. All **10** literal addon-whisper send sites are unchanged. Added-line security scan found no secret/injection/eval/deserialization patterns. Self-review only in this builder session; no independent reviewer tool was available.

## Mutants and deterministic reports

- `python3 test/quiet_all_mutants.py`: **43/43 caught**, including explicit M1, mode-on, S1, S2 and both S3 controls. Eight follow-up controls extend the inherited 35. The obsolete “either hook” mutant is now “available hook” and still verifies a genuinely absent API does not require a hook.
- `python3 test/quiet_mutants.py`: **38/38 caught**. Original assertions remain; changed feature behavior and necessary mutation anchors are migrated, not weakened.
- Every Lua mutation syntax-checks and must produce assertion failures. Both suites succeeded on the first complete run after migration; no surviving mutants were hidden or removed.
- Both runners were rerun after the final test-label correction, and then each was run again with byte and mtime comparison. Reports normalize only nondeterministic object addresses and are not rewritten when unchanged.
- Final `quiet-all-mutants.json` SHA-256: `ec799fb06432f2ab7a5015254fd63e00d11ebea72f7f42869da77294ce18ee6c`.
- Final `quiet-mutants.json` SHA-256: `06bdd768ae825a62a478d778965858a7175b1ebe25e4ee1fb8e99d2a366acbdc`.
- `quiet-rulings-*-mutant-stability.json` records equal before/after hashes and `byte_stable: true`, `not_rewritten: true`. Runner logs are retained separately.

## Full verification and local artifact

`python3 test/verify.py`, foreground, explicit **1,800-second** subprocess/tool timeout: **exit 0 in 231.39 seconds**.

**`RESULT: 1528 tests passed, 0 failed, 263936 assertions`**

Also passed: syntax for 86 Lua files; all 23 send-gate tests; 13 API-owner tests; four harness-source tests; 11 media tests; 5,000 fuzz inputs; TOC/static gates; archive integrity/source parity; `git diff --check`. See `quiet-rulings-full-verify.txt`, its metadata JSON, regenerated `verification.json` and `test-results.txt`.

The initial full run already had 1528 passing tests but exited 1 because the literal trailing space in a **test label** appeared at the end of a generated PASS line and failed `git diff --check`. The label now quotes the target and includes its Lua type; the actual trailing-space input is unchanged. Initial output and earlier green logs containing literal trailing whitespace are preserved **byte-for-byte inside JSON strings** (`*-output.json`), not trimmed or represented as successful full runs.

Local package: `dist/LayerEnemies-1.1.0.zip`, SHA-256 **`eb470c13452166a59691ce271d82d5885a0a3d46a832d62d27ddefd4468d2402`**. Not published or installed.

## Commit slices and remaining limits

- `44ad397`: M1 protection and regressions.
- `d303f72`: typed protection in `on` with offline bookkeeping unchanged.
- `451f322`: all-existing-hooks readiness, missing-hook diagnostics and narrowly scoped presence predicates.
- `11fbeea`: full-ledger/overflow fail-open behavior and regressions.
- `96e861f`: exact-once registrations and no `pcall` bindings.
- `21e3eae`: README contracts, ruling mutants and deterministic report generation.
- `39547c9`: output-only quoting for malformed test labels.
- This report, logs and regenerated summaries are a subsequent **notes-only commit**.

**Native checks not run (alpha, owner's decision).** No owner testing is requested. Post-hook timing, native taint, API availability at startup, localization/secret behavior, IDs and other addons' filters remain unverified. Existing event decisions remain frozen across frames; a post-hook cannot retroactively change an earlier decision. Without IDs, two identical independent lines in the same tick may both hide after one own whisper; README explicitly retains that limitation. No new send or authoritative sender attribution is claimed.
