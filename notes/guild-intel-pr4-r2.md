# Guild-intel PR 4: round-1 corrections

## Outcome and scope

- Isolated clone: `/opt/data/cache/scratch/gi4-fix`, branch `gi-pr4-spy-r2`.
- Started at `91448cb6e70a58ba349dac767b8ba6a7592b097a`. Source repository and reviewer originals remained read-only. Local commits only; origin's push URL is `DISABLED`.
- `/le share off` now stops guild traffic, including own sightings, all Spy/HeadHunter/War Effort relays, host discovery/answers and War Effort guild membership/embassy traffic. Receipt is unchanged. Switching off cancels pending relays immediately; dispatch also checks the switch. Queued guild embassy sends check it at dispatch.
- Relays leave two of Wire's five LEGW1 prefix tokens for own lines. Relay maintains a conservative prefix-budget mirror (one token per two seconds; double cost in combat). Existing O/F/H authors and upstream's new K author charge it before dispatch; refused attempts still count. Pending clears and backward clocks never refill it. Wire retains every existing global, minute, route and client limit.
- No new send call, prefix, route or SavedVariables field in these fixes. `Main.lua` still has 20 `N.Wire.send` sites, Hosts and Relay one each; upstream's K author still has one. `Wire.lua` and `test/verify.py` are byte-identical to fetched main `601e421f5d1078a0e03bfeeff72e91b4804aa9df`, not to the older start revision: their only changes came from main.
- Non-ASCII capitalization, foreign-realm identity and different-origin stand-down observations remain unchanged, as ruled by the owner.

## Merges (no rebase)

| Merge commit | Other parent | Conflicts resolved |
|---|---|---|
| `e567232345e09d57a41d526e7c7049b5f3951c33` | `4e29ccfa88950cfcc82d5f7d0240bbc2243c90d7` (`origin/gi-pr1-find20`) | `test/harness.lua`, `notes/test-results.txt`, `notes/verification.json` |
| `6ca9d348cc96727ed72b07cbeb15977e4dbef473` | `601e421f5d1078a0e03bfeeff72e91b4804aa9df` (fetched upstream main) | `LayerEnemies/Main.lua`, `README.md`, `test/harness.lua`, `notes/test-results.txt`, `notes/verification.json` |

Both sides' test loaders were retained. Main retains `UNIT_TARGET` and all new death events/cancellation hooks. Share text combines the new policy with K-death behavior. Generated notes were regenerated from the combined suite in separate notes commits, not treated as source conflict evidence.

## RED -> GREEN evidence

Original baseline: `python3 test/verify.py` under native Lua 5.1.5 returned `RESULT: 793 tests passed, 0 failed, 73102 assertions`.

The initial 13 policy tests were run against a detached `91448cb6` worktree containing only the new tests/harness overlay: **1 passed, 12 failed, 641 assertions**. The passing case was the sharing-on control. The following names all failed for the requested behavioral reason, then passed after the fixes (all have prefix `Guild relay policy: `):

- `share off silences own, Spy and HeadHunter before receipt`
- `share off silences own, Spy and HeadHunter during wait`
- `share off silences own, Spy and HeadHunter saved off`
- `off then on cancels pending relays but allows fresh observations`
- `saved share off also silences guild membership and host discovery`
- `Spy burst reserves own O capacity out of combat`
- `Spy burst reserves own O capacity in combat`
- `HeadHunter burst reserves own O capacity out of combat`
- `HeadHunter burst reserves own O capacity in combat`
- `mixed burst reserves own O capacity out of combat`
- `mixed burst reserves own O capacity in combat`
- `earlier guild control lines count against the relay reserve`

After the main merge, two additional test-first integration cases (`merged K author preserves the reserve out of combat` / `in combat`) failed on the merged code: peaceful relays consumed 3 rather than 2 tokens' worth; combat O was refused. Charging the K author before its existing Wire call made both pass. These are RED on the merge, not on the original revision where K does not exist.

A subsequent `clear and clock rollback cannot refill the reserve` guard passed immediately; it is not counted as an initial RED. Final focused suite: **16 passed, 0 failed, 1170 assertions**.

Two inherited relay-burst expectations changed solely for the owner's reserve policy: 5 sends -> 3, and the reason becomes `own reserve`. The Spy burst test now separately asserts six allowance stamps (including reserve refusals) and three actual Wire calls. Existing Spy limits were not loosened.

## Verification and mutations

- Final command, from repository root: `python3 test/verify.py` (native `/opt/data/tools/lua/lua-5.1.5/src/lua`). Exit 0: **`RESULT: 969 tests passed, 0 failed, 91462 assertions`**.
- Unchanged main send gate: zero false positives. Syntax, API policy, TOC/media allowlists, package integrity/source parity and `git diff --check` pass.
- `python3 test/relay_policy_mutants.py`: **2/2 killed**. `relay-ignores-share-off` removes the overlapping offer/dispatch/cancellation guards together: 4 failing tests. `spend-own-reserve` sets only the reserve to zero: 10 failing tests. Both compile; source bytes are restored in `finally`; the clean suite is rerun.
- Original `test/spy_mutants.py --lua /opt/data/tools/lua/lua-5.1.5/src/lua`: **7/7 killed**, clean focused result 22 passed, 0 failed, 1852 assertions.
- Frozen old decoder remains byte-identical to `16549ca:LayerEnemies/Relay.lua`, SHA-256 `24b4010cc267684a75cd0d16d9df68cb80629a13f7f934fe1a2a4250af10d273`.
- Archive: `dist/LayerEnemies-1.0.1.zip`, SHA-256 `2fa356abb97a190a0c8fc93dcd60ce9fab6076727047a1d90acd15c604e16db8`.

## Frozen reviewer probes, before / after

Reviewer Lua probes were executed unchanged apart from the old-decoder fixture path; only scratch wrappers/logs were written.

| Probe | Before | After |
|---|---|---|
| Spy share-off before / during / saved | 1 relay and 1 attempt in each mode | 0 relays and 0 attempts in each mode |
| HH share-off | 1 relay | 0 relays (sharing-on control stays 1) |
| Four five-Spy-relay bursts before O | R=20, O=0/4, 4 refusals | R=12, O=4/4, 0 refusals |
| Four five-HH-relay bursts before O | R=20, O=0/4, 4 refusals | R=12, O=4/4, 0 refusals |

All ten final reviewer probe suites completed with zero runtime/probe errors: 33 route cases, 44 malformed cases, 2000 fuzz inputs, loop/old-reader/provenance/rate/memory controls included. Unicode-case and different-origin notes still reproduce unchanged.

Evidence logs and replay scripts: `/opt/data/cache/scratch/gi4-fix-evidence/` (`all-red-91448cb6.log`, `share-red.log`, `k-integration-red.log`, `mutants-final.log`, `spy-mutants-final.log`, `final-verify.log`, `before-*`, `after-*`).

## Files and remaining checks

Correction-specific files: `LayerEnemies/Main.lua`, `LayerEnemies/Hosts.lua`, `LayerEnemies/Relay.lua`, `LayerEnemies/OwnDeath.lua` (integration accounting only), `README.md`, `test/harness.lua`, `test/spy_relay.lua`, new `test/relay_policy.lua`, new `test/relay_policy_mutants.py`, this note, regenerated `notes/test-results.txt` and `notes/verification.json`. Other changed files are the retained upstream/base merges.

Self-review completed; independent round-2 review remains the parent's lane. No push, GitHub write, installation or live-client action. Native-client checks: **not run (alpha, owner's decision)**. Offline tests do not establish live-client behavior.
