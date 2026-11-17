# Quiet / upstream main semantic merge

## Result and scope

- Branch: `fix/hide-own-not-found`.
- Quiet parent: `4fbfe7ca91cd6cd7072991764163aef3e314f3d0` (reviewed PR #34 head).
- Upstream main parent: `5b8545532d82fdbfd716eb5267616c5efdf4e9bc` (WarBoard handshake/read plus tracking).
- Merge base: `2675e03d9363d4299a02d6d60815e0d65298967c`.
- Merge commit: `5e70ba8a65677df7976e21268bf7e770bac6b300`, with those two parents in the order above. Created with `git merge --no-ff --no-commit`, then committed after verification.
- This audit is a separate notes-only follow-up commit. No push, GitHub write, installation or release was performed.

Both reviewed behaviors are retained. Quiet keeps its saved `quietWhispers` modes (`on`, `off`, `all`), `/le quiet`, `/le net` counters and hook diagnostics, `CHAT_MSG_SYSTEM` filter, both secure post-hook registrations, startup registrations and full system-event arguments. WarBoard keeps its source switch, handshake/read path, tracking commands/status, stop-path withdrawals, saved `warboardOwed` sanitation and all queue/receipt/confirmation rules.

## Every conflict hunk

There were **8 conflicted files and 12 conflict hunks**. Ranges below refer to the original merge-conflicted working files, including markers, before any resolution. They are not post-resolution line numbers.

| File / hunk | Original lines | Resolution |
| --- | --- | --- |
| `LayerEnemies/Main.lua`, 1 | 2261–2275 | Keep the complete `M.quiet(command)` body and the complete `M.warboardTrack(on)` body as adjacent top-level functions. Insert the missing `end` between them; the common trailing `end` closes `M.warboardTrack`. Neither body changes. |
| `test/harness.lua`, 1 | 1173–1177 | In the War Effort SavedVariables privacy test, use one exact key allowlist containing both `quietWhispers` and main's table-typed, at-most-40-entry `warboardOwed` condition. Preserve all pre-existing allowed keys and the `guildHost` boolean assertion. |
| `test/harness.lua`, 2 | 2075–2079 | Apply the same exact key union to hop-state reload cleanup; retain its original allowed keys and `guildHost` boolean assertion. |
| `test/harness.lua`, 3 | 3457–3461 | Apply the same exact key union to saved guild-host reload; retain the separate `guildHost` boolean assertion. |
| `test/harness.lua`, 4 | 3605–3609 | Apply the same exact key union to saved auto-hop settings; keep the forbidden-call assertion. |
| `test/kills.lua`, 1 | 145–149 | Keep `quietWhispers=true` and the original `warboardOwed=type(LayerEnemiesDB.warboardOwed)=="table" and #LayerEnemiesDB.warboardOwed<=40` entry in one allowlist. Keep all other keys, rejection checks and recursive session-memory checks unchanged. |
| `test/known.lua`, 1 | 25–29 | Same two-field union in `dbCheck`; retain every other allowed key and the recursive privacy checks. |
| `test/overlord.lua`, 1 | 429–433 | Same two-field union in the session-statistics privacy test; retain every other allowed key and the session-state exclusions. |
| `test/watch.lua`, 1 | 335–339 | Same two-field union in the watch privacy test; keep snapshot equality and saved find-share/find-notice assertions. |
| `notes/test-results.txt`, 1 | 1531–1864 | Discard the conflicting generated output and regenerate the entire file with the merged full harness through `python3 test/verify.py`. Neither parent's results were spliced together. |
| `notes/verification.json`, 1 | 3–15 | Regenerate syntax/test/assertion counts from the merged full verification run, rather than choosing either parent's counts. |
| `notes/verification.json`, 2 | 20–34 | Regenerate archive membership, byte sizes and SHA256 from the actual merged deterministic package. No hand-edited package metadata. |

All eight settings-allowlist hunks were programmatically checked against main's exact hunk plus only the quiet key. No wildcard, arbitrary-key acceptance, relaxed debt cap or extra saved field was introduced. Main's debt sanitizer and both feature-specific privacy suites remain intact. `README.md` and `test/api_policy_test.py` auto-merged, retaining both sides' additions without manual edits.

## Production versus mechanical union: complete inventory

For this comparison, the mechanical union is Git's literal three-way `git merge-file --union -p` output, with quiet as ours, the merge base as base and upstream main as theirs. A file added only on main is taken verbatim from main. This was independently reconstructed for every `LayerEnemies/*.lua` file and `test/verify.py`: **47 files**. It exactly matched the snapshot made by concatenating ours then theirs in each original production conflict and retaining Git's automatic resolutions elsewhere.

**Exactly one production line differs from that literal union:**

| Resolved location | Change | Why |
| --- | --- | --- |
| `LayerEnemies/Main.lua:2270` | Insert `end` immediately before `function M.warboardTrack(on)` | The literal union retains two function starts but only one shared closing `end`. Both command handlers must be independent top-level functions. |

```diff
@@ -2267,6 +2267,7 @@
         or state=="all" and not N.Wire.whisperObserverReady() and " - your own typed-whisper protection unavailable; all behaves like on (LayerEnemies whispers only)."
         or state=="all" and " - hide all localized not-found lines except after your own typed whisper (10 seconds)."
         or " - all offline whisper notices stay visible."))
+end
 function M.warboardTrack(on)
     N.WarBoardTrack.set(on)
     M.say("WarBoard tracking: "..(on and "on" or "off").." (this session; /le warboard track on|off)")
```

The literal-union `Main.lua` failed Lua 5.1 syntax checking with:

```text
'end' expected (to close 'function' at line 2261) near '<eof>'
```

The resolved file passed the same `luac -p` check. There are **no other production deviations**, no command-body rewrites and no edits to `test/verify.py`.

Byte comparisons also confirm:

- `LayerEnemies/Wire.lua` and `test/verify.py` are unchanged from the quiet parent.
- `LayerEnemies/WarBoard.lua` and `LayerEnemies/WarBoardTrack.lua` are unchanged from upstream main.
- All other production files match the mechanical union exactly.

### Strict-gate compatibility

**No upstream file tripped the stricter quiet gate.** The initial scan of every resolved addon module except then-conflicted `Main.lua` reported an empty failure list. After resolving Main, both API ownership and send-policy checks passed on **all 46 addon Lua modules**, including `WarBoard.lua`, `WarBoardTrack.lua`, `BNet.lua`, `Adapters.lua` and `Sources.lua`.

No gate exception or production workaround was needed. Exact-once hook spans, exact-once complete presence statements and the prohibition on rebinding `pcall`/`hooksecurefunc` in any addon file are retained. The full gate also ran its all-module guard-binding regression tests on the expanded module set.

## Fresh verification

All commands ran in `/opt/data/cache/scratch/le-notfound` with:

```text
TMPDIR=/opt/data/cache/scratch
LAYERENEMIES_LUA=/opt/data/tools/lua/lua-5.1.5/src/lua
```

Every mutant runner and the full verifier ran synchronously in the foreground with an explicit **1800-second timeout**, one long command per tool call; no background shell job was used.

| Command | Actual result | Exit |
| --- | --- | --- |
| `lua test/harness.lua --only Quiet` using the interpreter above | 64 tests passed, 0 failed, 6081 assertions | 0 |
| `python3 test/quiet_mutants.py` | 38/38 caught | 0 |
| `python3 test/quiet_all_mutants.py` | 43/43 caught | 0 |
| `python3 test/warboard_mutants.py` | 115/115 killed | 0 |
| `python3 test/warboard_track_mutants.py` | 113/113 killed | 0 |
| `python3 test/verify.py` | 1809 tests passed, 0 failed, 442147 assertions | 0 |
| `git diff --check` and `git diff --cached --check` before merge commit | No whitespace errors | 0 |

**309/309 mutants caught; no survivors.** Their generated JSON reports were byte-identical to the corresponding existing parent reports, so no report rewrite was necessary. The verifier regenerated `notes/test-results.txt` and `notes/verification.json`.

The full verifier also passed 31 source-gate tests, 14 API-policy tests, 4 harness-discovery tests and 11 asset tests; Lua syntax checks covered 96 files, and TOC/package integrity and source parity passed.

Exact full-harness result:

```text
RESULT: 1809 tests passed, 0 failed, 442147 assertions
```

The merged PASS-name multiset was compared programmatically with upstream main's PASS names plus the quiet-only names relative to the common base: **1809 expected, zero missing, zero extra**. Parent generated logs contain 1464 tests at the base, 1528 on quiet and 1745 on upstream main. All 64 quiet additions and all upstream tests remain represented; the green total is not hiding a dropped loader.

Package: `dist/LayerEnemies-1.1.0.zip`, 57 members, 279692 bytes.

```text
SHA256 a0093a97d2ae52ea49d63a8eff40d12f8ac2d4b0eea2a84df4c044c56f45ef4c
```

Native client testing: **not run (alpha, owner's decision)**. No native compatibility or visual verification is claimed.
