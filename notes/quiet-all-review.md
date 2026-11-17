# Quiet all: implementation and verification

> Historical evidence for the original implementation. The subsequent [review rulings](quiet-rulings-review.md) supersede its readiness, invalid-target, capacity and mode-on rules.

## Result and scope

- Base: `f901fb79` on `fix/hide-own-not-found` (the own-only filter reviewed in `quiet-whispers-review.md`).
- Implementation: `ebf17e1fc074010d5f64da2c5e5454e6edf67336`.
- Local commits only; push URL remains `DISABLED`. No push, PR, release or live installation.
- `/le quiet on|off|all` now saves a string in the existing `quietWhispers` setting. Boolean true becomes `on`, false becomes `off`; absent/invalid values default to `on`. No new saved field or saved names.
- `all` hides matching localized not-found lines regardless of addon origin, except for a matching recent outgoing chat WHISPER target. `on` remains the default own-addon-whispers-only behavior. `off` changes display only.
- `/le quiet` reports mode and scope, including unavailable-hook fallback. `/le net` prints the requested three counters and hook readiness. Names and counters are session-only.

Source references below are to the implementation commit unless marked upstream.

## Client API evidence and actual hooks

Target remains **Forever 1.60.1.70938 / Interface 16001**. Read-only source evidence is pinned to Gethe/wow-ui-source commit `bebcb6bf309cf41b41bd74f8ca651e6a105b2676`, not a moving branch:

| Evidence | Source |
| --- | --- |
| Modern chat send exists in generated documentation, arguments message / chatType / languageID / target; restricted, secret arguments allowed when untainted | [ChatInfoDocumentation.lua:564-575](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua#L564-L575) |
| Typed WHISPER path takes `GetTellTarget()` and calls `C_ChatInfo.SendChatMessage(text, type, self.languageID, target)` | [Shared/ChatFrameEditBox.lua:295-306](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_ChatFrameBase/Shared/ChatFrameEditBox.lua#L295-L306) |
| Shared edit-box file is in the UI TOC | [Blizzard_ChatFrameBase.toc:32](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_ChatFrameBase/Blizzard_ChatFrameBase.toc#L32) |
| Legacy global `SendChatMessage` forwards to the modern function | [Deprecated_ChatInfo.lua:8-9](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_DeprecatedChatInfo/Deprecated_ChatInfo.lua#L8-L9) |
| Legacy file is listed with LoadOnDemand 0 | [Blizzard_DeprecatedChatInfo.toc:5-7](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_DeprecatedChatInfo/Blizzard_DeprecatedChatInfo.toc#L5-L7) |

The addon attempts these two secure post-hooks once at startup (`Main.lua:2414`):

- `Wire.lua:167`: `pcall(_G.hooksecurefunc, C_ChatInfo, "SendChatMessage", observeChatWhisper)`.
- `Wire.lua:169`: `pcall(_G.hooksecurefunc, "SendChatMessage", observeChatWhisper)`.

Missing/non-function targets cause native hook registration to fail inside `pcall`; either successful hook is enough. No function reference is retrieved or called, and neither send function is replaced. The hook itself is protected by `pcall` (`Wire.lua:147-160`), reads only WHISPER kind/target/time, and discards message content. The session ledger (`Wire.lua:139-175`) uses the existing `Invite.name` identity rule, retains at most **16 distinct normalized keys**, expires at **10 seconds exactly**, discards future stamps after rollback, and refreshes a repeated target without adding another slot. That covers duplicate observations through the legacy-to-modern forwarding path.

If neither hook installs, `all` behaves exactly like `on`. This is printed by both `/le quiet` (`Main.lua:2267`) and `/le net` (`Main.lua:2277`). The harness exercises both APIs, each alone, both missing, missing hooksecurefunc and throwing registration. These are simulated availability tests, not claims of runtime presence on the owner's PC.

## Display versus offline bookkeeping

The manual exception is applied after existing own-whisper evidence consumption (`Wire.lua:285-304`). A manual failure can stay visible while still consuming a concurrent own receipt and marking that own target offline once. Repeated frames and subsequent pending receipts do not renew the hold.

`quiet-all-invariants.json` is a programmatic comparison with `f901fb79`: the complete markOffline/offlineUntil region, system evidence-consumption block, delivery/budget tail, and all **10** literal addon-whisper send sites are unchanged. Tests cover on/off/all, both dispatch orders, multiple pending receipts and three chat frames. Donor-loaded stand-down remains unchanged; all mode does not cause new sends or mark unrelated targets offline.

`/le net` (`Main.lua:2275`) prints exactly:

`hidden (LayerEnemies whispers): N; hidden (other addons): K; shown (your own whisper or mode): M`

N/K increment only on actual filter hides, once per decision; M counts observed matching decisions that remain visible. "Other addons" is an uncorrelated bucket, not authoritative attribution. The old internal uncorrelated count remains so inherited correlation tests still verify their original evidence rule; it is not another displayed/saved counter.

Every hidden decision now retains exact text in the existing bounded session ledger (`Wire.lua:307`); shown unowned decisions retain only numeric fingerprints. This matters because formerly unowned lines can now be hidden. A forced equal-hash/equal-length/equal-ID test exposed a shown collision overriding an earlier exact hidden decision; exact matches now take precedence (`Wire.lua:278-279`). Fingerprints cannot authorize hiding a different target's manual failure.

## Exact static-gate change

`test/verify.py:208-216` adds **nine lines** at the start of `check_send_policy`: tokenize the two exact `pcall(_G.hooksecurefunc, ..., "SendChatMessage", observeChatWhisper)` expressions above; assert their owner is `Wire.lua`; remove only those matched token spans before the existing policy checks.

The original ban remains **unchanged** at `test/verify.py:219`: `word == 'SendChatMessage'` is forbidden. There is no generic chat-send, namespace-escape or callback exemption. API lookup, bare/global/namespaced direct call, constant-index and alias calls, pcall of the send function, and inline sending callbacks are still rejected. The existing one-SendAddonMessage-access-in-deliver gate is unchanged.

`test/test_verify.py` adds three `WhisperHookPolicyTests`: owner-only registration, forbidden sends beside allowed hooks, and refusal of unrelated namespace escapes. Existing send-policy and API-owner tests still run. The older raw-text Lua check in `test/harness.lua` strips only the inert quoted `"SendChatMessage"` string in Wire before its old executable-name ban; the Python gate validates the actual registration syntax. The optional `beforeLoad` test seam configures client APIs before real addon startup, not after registration.

The inherited own-only suite changes only saved-value expectations and its displayed counter prefix, while checking the old uncorrelated count independently. Its existing offline/name/expiry/privacy assertions remain.

## Execution evidence

Lua executable: `/opt/data/tools/lua/lua-5.1.5/src/lua` (5.1.5).

- **Initial RED:** configuration tests failed before implementation (`quiet-all-red-modes.txt`: 0 passed, 2 failed). Hook/filter slice failed next (2 passed, 3 failed; `quiet-all-red-hooks.txt`). Counter/status slice failed before those changes (10 passed, 5 failed; `quiet-all-red-counters.txt`). Boundary regressions already passing at that slice are not represented as initial red. The later collision test failed on the first candidate (`quiet-all-pre-final.txt`: 41 passed, 1 failed), then passed with exact-cache precedence.
- **Final RED on the exact base:** a detached worktree at `f901fb79` received only `test/harness.lua`, `test/src_quiet_all.lua` and `test/test_verify.py`; production and verify.py stayed untouched. `--only QuietAll`: **`RESULT: 0 tests passed, 17 failed, 1040 assertions`**, exit 1. New Python policy class: 3 tests, 1 failure (modern registration rejected), exit 1. Logs: `quiet-all-red-baseline.txt`, `quiet-all-api-red-baseline.txt`. Temporary worktree removed.
- **GREEN:** final `--only Quiet` includes all 25 inherited tests plus 17 new tests: **`RESULT: 42 tests passed, 0 failed, 4331 assertions`**, exit 0 (`quiet-all-green.txt`). New Python policy class: 3 tests, OK (`quiet-all-api-green.txt`). Full verifier additionally ran all 14 send-gate tests and all 13 API-owner tests, plus harness-source and media tests.
- **New-rule mutants:** `python3 test/quiet_all_mutants.py`: **35/35 caught**, no survivors on the first complete run; results in `quiet-all-mutants.json`. Covers broad mode, manual priority, startup/both entrypoints/protected registration/once/fallback, WHISPER-only/name rule/expiry/rollback/cap/refresh, save migration/default/privacy, all counters, offline separation, exact cache safety, protected callback, status/query and unchanged send/ownership/namespace gates.
- **Inherited mutants:** `python3 test/quiet_mutants.py`: **38/38 caught** (`quiet-mutants.json`), with anchors migrated only for the approved mode/counter changes. Each Lua mutant syntax-checks and must cause a test assertion failure; policy mutants run real gate tests. All mutations use private scratch copies and restore each source between runs.
- **Full verification:** `python3 test/verify.py` executed in the foreground with a **1,800-second subprocess and tool timeout**, no background job. Exit **0**, **238.53 seconds**. Exact line: **`RESULT: 1506 tests passed, 0 failed, 262193 assertions`**. Log: `quiet-all-full-verify.txt`; generated summaries: `verification.json`, `test-results.txt`.
- Syntax: 86 Lua files PASS; static/API gates PASS; 5,000 fuzz inputs; archive integrity/source parity PASS. `git diff --check` and added-line security scan passed. No source/test/README changes after this full run.
- Local deterministic artifact: `dist/LayerEnemies-1.1.0.zip`, SHA-256 **`65fed8c148edbaf2574755b9c3ba5963ac55659a9949c67320f6f76c1cc6f6be`**. This ignored local ZIP is not published.

## Live-client unknowns and limits

**Native checks not run (alpha, owner's decision).** No owner tests or captures are requested. The pinned source shows both entrypoints, but native availability/security at addon startup, hook success, actual taint behavior, error timing versus hook completion, localization/secret behavior, event/filter ordering, stable positive IDs and interference from other addons' filters remain unverified.

A post-hook cannot protect an error delivered before that hook runs. These chat APIs also cannot distinguish human-typed normal chat from another addon's visible chat: both are conservatively protected for the same target/window. Addon-message whispers do not populate this ledger. Same-target competing failures inside the manual window all remain shown; outside it, all mode hides matching lines. Without usable IDs, independent identical failures in the same tick remain indistinguishable. These are explicit limits, not live-client success claims.
