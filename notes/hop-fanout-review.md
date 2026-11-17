# Hop full fan-out: review and verification

Base: `d9f0a71` (main, 1.1.0). Branch: `feat/hop-full-fanout`. Code/tests/README commit: `aa21a7432451ecc26b95941995bb829e1c83c1ca`; verification notes are the following separate commit. Local commits only; origin push URL is `DISABLED`. No version bump, new addon files, or SavedVariables fields. LayerSwap study sections 6–8 were read; implementation is independent, not copied from the reference addon.

## Delivered behavior

One explicit click issues one localized zone WHO query. Only the first 49 raw rows are read, then self, duplicates, unreadable/ignored/recently asked/suppressed names are removed. Known hosts sort first, same-zone rows second, and remaining rows last. Only names in this WHO result are candidates; a book cannot manufacture a target.

A click owns at most 45 rounds, one second apart, at most eight attempts per round. A fresh dedicated Wire bucket sends eight immediately and replenishes one per second: the 49-target success fixture finishes 41 seconds after its first send. A throttled initial target remains at the queue head. There is no Wire-queued hop work that can survive cancellation. At most one initial request is accepted per target; the explicit unknown-layer fallback is the sole re-ask exception.

Ten seconds must pass after the first accepted whisper (or click if no whisper was accepted), and an existing ask must first finish or be stopped. Hosting replies do not stop fan-out. Any readable, not-known-failed inviter does, without gaining auto-accept authority. Stop/slash stop, group events, world/zone transitions and existing live guards cancel unsent work. Auto-accept still needs an actually asked whole-name identity; named Hop, Hop via name, Ask guild and accept/leave timing are unchanged. Failed-hop history uses the whole realm-qualified key, not the display label.

Nonresponders remain session-only for six hours, with the existing 300-name cap. Known book peers bypass that suppression unless offline; their offline cooldown is 600 seconds. Other Wire offline checks stay one hour. Same-zone unknown-layer `h` responders get one unconstrained fallback attempt at the post-queue +3/+10 checks, never another WHO query; a known alternative-layer answer delays the fallback until +10. Fallback refusals are spent, not retried. Reply/invite lifetime is 120 seconds from the first accepted initial whisper.

## Exact constants and scope

| Module / constant | Before | After |
|---|---|---|
| HopAny `CAP` | 8 total attempts/click | 8 attempts/round |
| HopAny `PACE` | 1 second between individual attempts | 1 second between rounds |
| HopAny `CLICK` | 30 seconds | 10 seconds |
| HopAny `WHO`, `REPLY` | 5, 120 seconds | 5, 120 seconds (reply window now starts at first send) |
| HopAny `ROWS` | literal first-49 read | named 49, same raw-row bound |
| HopAny `ROUNDS` | absent | 45 |
| HopAny `SKIP`, `MAX_SKIP` | 21600 seconds, 300 | unchanged |
| HopAny `FAILED` | absent | 600 seconds |
| HopAny `FALLBACK`, `FALLBACK_LATE` | absent | 3, 10 seconds |
| Adapters `WHO_LATE` | absent | 30 seconds |
| Wire `HOP_CAP` | absent; hop shared ordinary limits | 8 tokens |
| Wire `HOP_REFILL` | absent | 1 second/token |
| Wire `HOP_MINUTE` | absent | 60 attempts/rolling minute |
| Wire `HOP_ONE` | absent | 4 attempts/target/rolling minute |
| Wire `HOP_PAUSE` | absent; shared `PAUSE=30` | 1 second for this hop lane |

**No existing Wire budget constant changed.** `PREFIX_CAP=5`, `PREFIX_REFILL=2`, `ALL_CAP=8`, `ALL_REFILL=1.5`, `ALL_MINUTE=40`, `GUILD_MINUTE=20`, `PUBLIC_MINUTE=20`, `PUBLIC_ONE=4`, `QUEUE_MAX=40`, `PAUSE=30`, `OFFLINE=3600` stay unchanged, as do reserves, catch-up, accept/invite/leave and other message-kind budgets. There was no separate combined 10-second window to enlarge. The new budget is admitted only for `LayerSwap` / `WHISPER`, `prio="click"`, `hopAny=true`, and a validated request/fallback. Named hops, replies, sightings, relays, War Effort and HeadHunter never use it. Ordinary budgets neither fund nor are consumed by the new lane. Throttle results 3/8 share the hop-only one-second pause; unrelated traffic retains the 30-second pause. The known-peer 600-second offline override is optional and confined to this lane.

## Who UI ownership and restoration

- `LayerEnemies/Adapters.lua:4–100`: temporary session lease. Optional methods/frames are protected with `pcall`; missing timer or secure-hook/restoration support does not acquire unsafe UI state.
- `Adapters.lua:13–17,99,113–123`: request `C_FriendList.SetWhoToUi(true)` before our `SendWho`. `FriendsFrame`, `LFGWhoListFrame`, and `WhoFrame` are inspected without hiding any window.
- `Adapters.lua:81–97`: only a previously registered frame with the required restore methods is detached from `WHO_LIST_UPDATE`; its prior OnEvent script is retained. A guard protects against arbitrary frame-dispatch order.
- `Adapters.lua:19–58`: registrations return on result/timeout/stop. A result releases scripts/routing on the next frame, so frames after our dispatcher cannot display the same event. Stop/timeout leave only the bounded late-result guard; the first late event or 30-second deadline releases it. Prior unregistered/visible state is preserved, and a script replaced by another addon is not overwritten.
- `Adapters.lua:65–80`: a secure post-hook observes a player's `SendWho`, releases our lease and cancels our pending work. It never replaces the API. Manual queries during pending/late states and after completion are tested.
- `Main.lua:1042–1058,1071–1093,1319–1324,2157–2178`: timer/error, Stop, WHO, invite, group, world/zone and reload/logout paths release the lease. Query errors release it in `Adapters.lua:121–122`; guarded dispatcher errors clean up at `Main.lua:6–13`.

Optional missing APIs retain the prior behavior rather than promising suppression. Native event/taint behavior cannot be certified by these mocks.

## Tests and honest RED → GREEN

Commands use `/opt/data/tools/lua/lua-5.1.5/src/lua` and run from the repository root.

- New focused tests: **44**. Frozen-base execution in detached worktree `/opt/data/cache/scratch/le-hop-fanout-red`, with only the candidate harness/new test file copied in: **15 passed, 29 failed, 2324 assertions**. Raw log: `/opt/data/cache/scratch/le-hop-baseline-red-final.log`. Some failures are missing newly introduced state helpers; baseline-compatible negative tests already passed and are not called red.
- Candidate new tests: **44 passed, 0 failed, 2891 assertions** (`--hop-fanout-only`). Raw log: `/opt/data/cache/scratch/le-hop-focused-green.log`.
- Added realm-identity regression during final review first produced **43 passed, 1 failed, 2890 assertions** before the one-line fix; log `/opt/data/cache/scratch/le-hop-failed-realm-red.log`. It verifies the real accepted-invite/group/failure path and prevents a foreign host from poisoning its home-realm namesake.
- Inherited #16 plus focused tests: the unmutated baseline in `notes/hop-fanout-mutants.json` records **134 passed, 0 failed**. Every changed inherited assertion is enumerated verbatim in [hop-fanout-assertions.md](hop-fanout-assertions.md): 77 removed and 77 replacement/added assertion-bearing lines in 47 diff hunks. No unrelated harness case was migrated.
- New tests cover row bounds/dedup/order, 49 actual sends, per-round/round-total caps, throttled head, cooldown/first-send lifetime, cancellation, session/known/offline skip boundaries, fallback eligibility/timing/once, exact SavedVariables equality, independent Wire budgets, and WHO result/timeout/stop/invite/error/reload/manual/optional-API/event-order restoration.
- `test/hop_fanout_mutants.py`: **54/54 caught**, every mutant syntax-checked in an independent scratch copy. Full rule names and failing assertions are in `notes/hop-fanout-mutants.json`; raw output `/opt/data/cache/scratch/le-hop-mutants-final.log`. No surviving mutant in the final run.
- Full `python3 test/verify.py`, foreground, exit **0**: **RESULT: 1163 tests passed, 0 failed, 121584 assertions**. Lua syntax: 55 files; 5000 fuzz inputs; TOC/static/send gate, archive integrity/source parity and media tests passed. Raw log: `/opt/data/cache/scratch/le-hop-verify-final.log`.
- Archive remains `dist/LayerEnemies-1.1.0.zip`, SHA-256 `c19e5043f46a8fe0fb574f8f893bfe4f019954f1275f6e63e95b0f5bf7d35aa2`.

## Minimal gate-rule changes

`test/verify.py` replaces the blanket no-WHO-UI-symbol rule with **Adapters-only ownership** of `SetWhoToUi`, `FriendsFrame`, `LFGWhoListFrame`, `WhoFrame`; the token-aware owner check covers those symbols too. `test/api_policy_test.py` checks rejection outside Adapters and acceptance inside it. The send gate itself is not weakened: only `test/test_verify.py`'s mutation anchor is updated for `deliver(..., hop)`. Its dormant-extra-send mutation remains rejected. The generated behavior description is updated from 8/30/no-retry to the approved rules. Visible chat sends remain banned.

## Files and limits of evidence

Production: `LayerEnemies/Adapters.lua`, `HopAny.lua`, `Main.lua`, `Wire.lua`. Documentation: `README.md`, plan/review/assertion notes. Tests: `test/harness.lua`, new `test/hop_fanout.lua`, new `test/hop_fanout_mutants.py`, `test/verify.py`, `test/test_verify.py`, `test/api_policy_test.py`. Regenerated evidence is committed separately: `notes/test-results.txt`, `notes/verification.json`, `notes/hop-fanout-mutants.json`.

Not run (alpha, owner's decision): live Forever UI event order/taint and manual `/who`, whether SetWhoToUi alone suffices, real server throttling/delivery at approximately one whisper/second, visibility to clients without an addon, account spam/silence enforcement and successful layer transfers. API acceptance is not proof of delivery. No push or GitHub write was performed.
