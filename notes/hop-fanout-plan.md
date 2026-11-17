# Hop full fan-out implementation plan

Approved scope: owner's 2026-11-17 builder brief; Forever 1.60.1 / interface 16001 / Lua 5.1. Base d9f0a71 (1.1.0). Local commits only; origin push URL disabled. No version bump or saved player names. Independent implementation, donor code read only.

Architecture: HopAny owns one click's ordered queue and bounded retries; Main owns event/dispatch guards; Adapters owns a temporary WHO UI lease; Wire has a separately admitted hop-any budget. Named Hop, Ask guild, accept/leave timing and other network budgets stay unchanged.

Evidence: layerswap.md sections 6–8 read completely (requester, discovery, trust). Donor LayerSwap.lua 2462–2499/2617–2694 describes UI ownership and late WHO release; 3370–3398 describes +3/+10 unknown-host retry. Existing HopAny.lua:6/75–85 caps at 8 and filters other zones; Main.lua:1084–1104 dispatches once per tick; Wire.lua:93–95 limits prefix 5/2s, all 8/1.5s/40min, public 20min/4 per target. Adapters.lua:4 explicitly forbids UI manipulation, intentionally reversed here.

## Slices (test first)
- [x] Queue/Wire: first 49 raw WHO rows, host/same-zone/rest ordering, 8 attempts per 1s round, 45-round ceiling, throttle retains head; dedicated hop-any 8-token burst/1s refill/60min, no loosening other kinds or named hops. Preserve single Wire send site.
- [x] Lifecycle: 10s click boundary, stop/invite/group/world/zone cancellation, session skip 6h/cap300, known offline 600s, unknown-host +3/+10 re-ask once without exclusions; keep autoaccept/leave authorization.
- [x] WHO UI lease: pcall-guard optional frames/APIs, unregister while pending, restore registrations on exits. A short-lived event guard swallows late results after timeout/stop until 30s; a secure SendWho hook yields immediately to the player's query. Restore routing/scripts on result/error/reload/deadline. Never hide a player-opened window.
- [x] Migrate #16 expectations explicitly; document every changed assertion. Add one mutation per rule and run tests on frozen main for honest RED counts.
- [x] Update README numbers/What is sent; full python3 test/verify.py foreground. Commit code/tests/docs, then regenerated notes separately.

Review focus: reentrant sends and replacement generations; delayed WHO and manual query ownership; optional/erroring UI APIs; recent-name vs offline ledgers; scope markers must not open other prefixes/requests.

Not verified: native Forever event order/taint, SetWhoToUi behavior, actual server token refill/throttles and successful transfers. Native testing not run (alpha, owner's decision).

## Completion evidence

Code/tests/README: `aa21a7432451ecc26b95941995bb829e1c83c1ca`. Full verify: **1163 passed, 0 failed, 121584 assertions**. New tests on frozen main: **15 passed / 29 failed**, candidate: **44 passed / 0 failed**. Mutants: **54/54 caught**. See [review](hop-fanout-review.md), [exact inherited assertion changes](hop-fanout-assertions.md) and regenerated JSON/test results; notes follow the implementation in a separate local commit. No push.
