# PR 0b — source registry and Battle.net seams

Authority: PLAN.md sections 2A and 4, on stack base `cac89528f890dad9416ef9fc6fdd474d8baaabf5`.
Local clone `/opt/data/cache/scratch/le-pr0b`, branch `feat/source-registry`, push URL `DISABLED`.

## Result

- No source is registered in production. No new scan, Battle.net send, protocol answer, join, relay, Ask or Hop action is initiated by this PR.
- Sources owns only future prefixes. All 14 existing prefix registrations and the complete existing dispatch chain remain; OpenMap's Battle.net function and all four presence reader bodies were compared byte-for-byte with the base. Presence, FLH and Overlord are not migrated.
- New `Sources.lua` and `BNet.lua`; new peer-only readers and `bnGame`/`bnAccount` resolvers in Adapters. Find/Known retain provenance and allow only registered new source names; registry claims cannot trigger a later sound poll.
- New generic literal `--only <substring>` / `--only=<substring>` filter and sorted `test/src_*.lua` discovery. Existing feature selectors remain compatibility aliases. No existing feature mutant suite was run or rewritten.
- README includes `Unreleased - source registry (no behaviour change)`, every public signature/return and the measured UI row integration rule. UI.lua is unchanged. THIRD_PARTY cites pinned Blizzard API declarations, not donor code.

## Exact primary interfaces

- `Src.register{ name, prefixes, onAddon, onBNet, tick, counters } -> bool`.
- `onAddon(prefix,text,dist,sender)`, `onBNet(prefix,text,gameAccountId)`, `tick(now)`.
- `Src.owns(prefix) -> bool`; `Src.addon(prefix,text,dist,sender) -> bool`; `Src.bnet(prefix,text,gameAccountId) -> bool`; `Src.tick(now)`.
- `Src.offer(ev) -> bool`, `ev={name,guid,faction,zone,map,x,y,shard,at,got,kind,net,via}`. `kind=self|witness|relayed|cached`; all times monotonic, unknown `at` remains unknown, no fabricated LE layer. Find's existing matcher or live guild Watch admits storage. Precise evidence kind is retained while the existing claim projection keeps network observations non-actionable and silent.
- `BN.peers(now) -> {{id,name,realm,faction,friend,club}}`; `BN.who(gameAccountId) -> {name,realm,faction}|nil`.
- `BN.send(net,gameAccountId,prefix,text,prio) -> bool` (queued, not delivered). `prio=owed|own`, default own. One 60-entry queue, at most 52 normal frames (8 owed-only slots); one attempt/second, 30 attempts/rolling minute shared across nets, owed first. Overlord/Wanted/WarBoard admission and dispatch shares 8/4/10; unconfigured sources use `max(1, floor(30 / registered sources))`. Both priorities count toward a network's queued cap. Excess admission returns false; frames older than 60 seconds at dispatch drop and increment `refused`. Failures spend a slot and are never retried. Share off/public off/network off cancel pending work; combat/instance and unreadable identity fail closed again at dispatch. See the round-1 ruling below for exact boundaries and registration changes.
- `A.clubPeer(clubId,memberId) -> bnetAccountId|nil`.
- `A.bnGame(gameAccountId)`, `A.bnAccount(bnetAccountId) -> {id,name,realm,faction}|nil`.
- `A.bnFriendGames() -> {identity}|nil`.
- Lifecycle/accounting helpers and the private-delivery predicate are documented in README; they do not register any production source.

## Gate change

`test/verify.py::check_send_policy` now allows exactly one `SendGameData` reference, **only in BNet.lua's single local `deliver` function**. `SendAddonMessage` remains restricted to Wire's single existing `deliver`. Legacy `BN*Send*` and chat APIs are still forbidden. BNet acquires the modern API; `Wire.bnet(net,id,prefix,text,prio,fn)` executes it through Wire's Lua caller frame, after privacy/admission checks and a matching private in-flight delivery. The harness checks that frame and source-owned prefixes. Tests reject an extra API reference, moved lookup, wrong file and direct trampoline bypass. The production client API body was exercised with both success and refused-send spies.

## Plan rulings / necessary glue

1. The actual inherited heartbeat is 2/5 seconds, not the plan's claimed 1 second. Keep it unchanged; start a separate 1-second callback only after a source registers. Main's added tick call is deduplicated. Cost: one extra timer for future registered sources, none in this PR's shipped state.
2. Retain old selectors as aliases of the generic filter, rather than break already-gated mutant scripts. New source tests require no harness edit.
3. Known's fixed source allowlist otherwise discards every new source. Admit registered source names and carry observed/received time plus event metadata through the existing Find.report/Known path; do not introduce row.heard. Suppress only this new provenance at Find.alert, leaving built sources unchanged.
4. A future tick-only `overlord` source can send on reserved `OverlordF` through BN.send without registering or stealing that existing receive prefix. No such source is registered here. This is the narrow bridge needed by C2's adopted in-place wiring contract.
5. API ownership follows section 2A: lookup in BNet, actual invocation in Wire. No general send exemption or route widening.

## RED → GREEN and verification

- Untouched stack harness: `RESULT: 1250 tests passed, 0 failed, 163546 assertions`.
- Incremental red runs: harness discovery/filter 4 Python failures; source registry 6 Lua failures; offer gate 5; peer readers 5; BNet queue 11; send-policy ownership 1 Python failure. Follow-up tests caught later-poll sound, direct Wire bypass and throwing timer access before those fixes. Readable-scalar secret coverage was added as an additional green test and then proved by mutation.
- Frozen-base negative control: detached `cac89528`, candidate harness plus only the four PR0b source test files: `0 passed / 13 failed` Sources, `0 / 5` peers, `0 / 12` queue — **30 failures on absent feature**, not an estimated red count.
- Before codec merge: `python3 test/verify.py` exit 0, **1280 passed, 0 failed, 165741 assertions**.
- `python3 test/source_mutants.py`: **38/38 killed**, syntax-valid mutants; no surviving mutant, no syntax/timeout counted as a kill. Includes generic filter and test auto-loader mutants. `notes/source-mutants.json` records each rule and failure.
- Final combined `python3 test/verify.py`: exit 0, **RESULT: 1296 tests passed, 0 failed, 175119 assertions**. Syntax: 75 files. Send/static policy, 11 verification tests, 10 API-policy tests, 4 generic-harness tests, 11 media tests and deterministic package/source parity all pass.
- Archive (still foundation version 1.1.0): SHA256 `7f6c7c97d7d1d38cbf9c0ae9c8a1dc03c55788cc19b6e1249f33708466c556fe`.

## Codec integration

Merged committed `feat/shared-codecs` head `ea5007723ef4074cdd091f9577ac3a280dd2d260`. `LayerEnemies/Codec.lua` is byte-identical to that commit. Moved its TOC line after Adapters, immediately before Sources, as section 2A requires. Added `test/src_codec.lua` and optional shared-harness callbacks in `test/codec.lua`; standalone operation is retained. All 16 codec cases now contribute to the normal harness and support `--only Codec:`. README conflicts kept both independent feature sections; generated verification notes were not hand-merged.

`python3 test/codec_check.py` on the merged tree: PASS; 16 cases / 9359 assertions, 50000 fuzz inputs, 257 inflate + 257 stored-writer comparisons, 524 serializer comparisons, 1000 mutated streams. Codec mutant results are inherited from its author; no codec mutant suite was rerun here.

Final review: self-review of the full diff (no independent reviewer tool in this subagent lane); parent review remains independent. Native checks: **not run (alpha, owner's decision)**. No push, GitHub write or donor execution. Evidence logs are in `/opt/data/cache/scratch/le-pr0b-evidence/`.

## Round-1 fix — Battle.net queue S1

Applied the owner's three queue rulings to base `dc1613cb9a239eb9c82e46b4a361417f799c7339` in local code/tests/README commit `ddb79347cef9a50c07f1273b0c0c60e8a52864ff`. Review source: `/opt/data/profiles/mani/cache/scratch/b120/parent-verdict-pr0b.txt`, S1 and notes. The earlier verification and archive values above describe the original seam; the results below supersede them. Generated evidence and this note are committed separately from the fix.

### Queue contract

1. **Admission cap:** count all queued frames for that network, across game IDs and both priorities. Refuse the next frame immediately at its per-minute share (Overlord 8, Wanted 4, WarBoard 10), without scheduling or queuing it. The default policy chosen here is `max(1, floor(30 / registered source count))`, reused at dispatch; built legacy networks do not count. New registrations tighten future admissions and dispatch, without retroactively evicting accepted frames. Dispatch/cancellation releases admission slots.
2. **Owed reserve:** only 52 normal frames can be held inside the 60-entry queue, leaving eight slots exclusively for owed answers. Count normal occupancy, not total occupancy, so an owed-first arrival order does not waste usable normal slots. Owed still obeys the per-network cap, global queue bound and dispatch budgets; priority does not bypass those limits.
3. **Age:** admission requires a readable monotonic `GetTime()` and stores that timestamp. At every pump, drop frames with age **greater than 60 seconds**, before pace or rolling-budget checks, incrementing the source's existing `refused` counter once. Exact age 60 remains eligible. No retry or catch-up burst; both priorities expire identically.

No change to the single SendGameData lookup, Wire caller-frame ownership, safety/privacy checks, production registration, peers, codec, source evidence or UI. Reviewer notes N1–N5 are not additional behavior changes in this fix.

### Tests and evidence

- Added `test/src_bnet_queue_round1.lua` with **17 cases**: configured/default caps, default dispatch share, mixed configured/default global budget, reserve and arrival-order boundaries, the reviewer's 1,000-frame flood, sustained replenishment, exact age 60, delayed normal/owed expiry, expiry while budgets are closed and unreadable clocks.
- The reviewer scenario admits only four Wanted frames from 1,000 attempts; another source's normal frame and owed answer are admitted and dispatched. Continued flooding checks actual send timestamps against each source's rolling share, the shared 30/minute budget, one-second spacing, per-frame age and no retries. A later 900-second advance produces no old backlog.
- New tests ran before the corresponding production changes. Final frozen-base control used a detached **dc1613cb** worktree with only the new test file copied in: **RESULT: 2 tests passed, 15 failed, 1069 assertions** (exit 1). The two passing controls preserve the existing global cap and mixed-priority queue utilization; they are not claimed as red failures.
- Candidate `lua test/harness.lua --only 'BNet queue: S1'`: **RESULT: 17 tests passed, 0 failed, 1563 assertions**. All queue cases: **RESULT: 29 tests passed, 0 failed, 2332 assertions**.
- Exactly three inherited queue cases needed ruling-specific fixture/expectation changes: refill freed slots rather than prequeue 40 frames; reject Wanted's fifth queued frame; reduce a single default source's cap from 60 to 15 when two sources are registered. Preserve all original test identities and privacy, secret, caller-frame, failure, pacing and budget checks. The long-pause pacing probe now keeps fresh work under the new lifetime rather than expecting a 500-second-old frame to send.
- `python3 test/source_mutants.py`: **RESULT: 41/41 source mutants killed**. Added one mutant per ruling: remove per-network admission cap, let normal frames use all 60 slots, and remove the 60-second expiry. All three fail behavioral assertions; no syntax/setup error or timeout counts as a kill. The prior privacy mutant was retargeted to remove only its privacy checks while preserving expiry. No surviving mutant; no other feature mutant suite was run. Full per-mutant failures are in `notes/source-mutants.json`.
- Full foreground `python3 test/verify.py`: **exit 0; RESULT: 1327 tests passed, 0 failed, 201847 assertions**. Syntax: **76 files**. Static/API ownership, 11 verification tests, 10 API-policy tests, four generic-harness tests, 11 media tests and deterministic package/source parity pass. Counts were independently parsed from `notes/test-results.txt` and matched to `notes/verification.json`.
- Archive SHA256: `2677e74836b8fdad5438da7be85b28ff63d23870161e8519c150cfc1e218a035` (`dist/LayerEnemies-1.1.0.zip`, version unchanged).

Evidence: `/opt/data/cache/scratch/le-pr0b-queue-round1-evidence/` (frozen-base red, incremental and final focused runs, source mutants, full verify output and summary). Diff/security self-review passed; independent parent review remains separate. Native checks: **not run (alpha, owner's decision)**. Local commits only; no push or installation.
