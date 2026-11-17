# PR E2 — WarBoard tracking request and mandatory withdrawal

Authority: `/opt/data/handoffs/2026-11-17-le-1.2.0/PLAN.md` sections 1, 3 and 8.5;
`audit-warboard.md`, WarBoard Forever 1.6.3. Reviewed E1 base: `65904e66`.
Clone: `/opt/data/cache/scratch/le-warboard-track`, branch `feat/warboard-track`.
Local commits only: no push, GitHub write, donor execution or donor code copied.

## Exact sends, recipients, caps and stop rules

Both new types are `WBF1|D|` followed by `addonEncode(deflateStored(aceWrite(envelope)))`.
Envelope: `{t="FBAK"|"FBUN", v=5, rs=<our ruleset>, av="LayerEnemies/"..<our version>, senderName=<our character>, d=<payload>}`.
FBAK payload: `{targetGuid, targetName, hunterGuid, hunterName, hunterFaction, faction, sentAt}`.
FBUN payload: the same **without targetName**. `faction == hunterFaction`.
`sentAt` is a readable positive integer from `GetServerTime`, not `time()` or a fallback.

| Send | Recipient and reason | Limits and stops | Implementation |
|---|---|---|---|
| FBAK first ask | Exactly one current client-resolved game account for an unambiguous name on the player's own Find list; compatible confirmed A peer, opposite faction, not ignored | 3 attempts, at least 6 s apart; after the third unsuccessful wait, FBUN then 300 s idle; at most 20 active targets | `LayerEnemies/WarBoardTrack.lua:53-75,129-169,172-218` |
| FBAK renewal | Same target/account; only newest accepted direct target FBLP affects renewal | Position age 45–300 s, at least 45 s since the last ask; over 300 s sends FBUN and idles 300 s, or until a handshake **after the stop** | `LayerEnemies/WarBoardTrack.lua:103-108,129-132,178-183,196-202` |
| FBUN | Outstanding target GUID, rediscovered through a currently confirmed account; no Find membership required for cleanup | One accepted withdrawal per stop; at most 3 actual attempts, at least 60 s apart on failure; unresolved debt survives login | `LayerEnemies/WarBoardTrack.lua:77-102,133-168,187-215` |
| All FBAK | Only `BN.send("warboard", ..., "WarBoard", ...)` | 6 per rolling minute at both admission and actual dispatch, inside 10 WarBoard attempts/minute and 30 shared/minute; one attempt/second | `LayerEnemies/WarBoardTrack.lua:10-12,133-169`; `LayerEnemies/BNet.lua:39,79-119` |

Stop paths: Find removal/clear (`Find.lua:87-108`), tracking off
(`WarBoardTrack.lua:102`), share off (`Main.lua:2189-2192`), Guild only
(`Net.lua:53-56`), source off (`Net.lua:61-69`), stand-down or lost eligibility
(`WarBoardTrack.lua:49-60,177-183`), initial/renewal give-up
(`WarBoardTrack.lua:181-183`), and best-effort logout (`Main.lua:2430-2433`).
Quick off/on cannot erase an already-created withdrawal obligation.

Cleanup also retires on local combat/instance entry. It remains held while unsafe;
no scan or send occurs in combat/instances. Already queued FBUN survives cancellation
and unsafe pumps (`BNet.lua:83-88,102,144-150`); cleanup created while unsafe waits in
tracking state for a safe enqueue. Owed H/A answers precede FBUN; FBUN precedes own
traffic (`BNet.lua:94-98`). Shared budgets still apply to cleanup.

Only the exact private outstanding FBUN passes the share/Guild-only/source-off and
stand-down exception (`WarBoardTrack.lua:121-128`; `BNet.lua:41-56`). The string
`"owed"` alone does not bypass anything. Disabled WarBoard receives only H/A while
debt exists and keeps ticking cleanup (`Sources.lua:65-85`). No new H/A or FBAK
privacy exception was introduced. Client API acquisition remains solely in BNet's
existing delivery function, invoked through Wire's existing caller frame.

`targetGuid` comes only from `A.bnGame(id,true)` reading client `playerGuid`, via
`BN.who(id,true)` (`Adapters.lua:225-239`; `BNet.lua:154-158`). No received frame can
set request/withdrawal identity. Own identity and integer server time are read in
`Adapters.lua:427-444`. Identity, eligibility, rate and clock are rechecked at
actual dispatch. The envelope is re-encoded then so queued cleanup never sends
an old `sentAt`.

## Saved field and lifecycle

The only added saved field is per-character:

```lua
LayerEnemiesDB.warboardOwed = { "Player-123-00000002", ... }
```

Dense, unique, oldest-first target GUID strings only; maximum 40, oldest out.
GUID syntax is `^Player%-%d+%-%x+$`, length at most 80. The loader discards malformed
values, nonnumeric keys and duplicates. No account IDs, names, zones, clocks,
locations, hunter roster, peer state or tracking switch are saved in this field.
Existing user-authored Find names remain in their pre-existing `tracked` field.

Main owns the field (`Main.lua:2334`); tracking mutates only that shared list
(`WarBoardTrack.lua:9-44`). Debt is added **before the actual FBAK client call**,
including ambiguous failures. A successful queue admission does not settle it:
only a completion reporting an accepted FBUN client call removes it (apart from
explicit oldest-out eviction/sanitization). Three failed FBUN attempts leave the
GUID saved for another login. Eviction also removes the corresponding session
record, so a bounded saved list cannot hide an unbounded forgotten-debt map.

At login all restored debts close before new asks, including still-tracked names.
A matching confirmed client account may have a new account ID or renamed character;
GUID equality, not a saved name, finds it. A missing/secret/offline identity fails
silent. API acceptance is **not** a remote delivery acknowledgement.

`/le warboard track on|off` is on at each login and session-only; `/le net warboard`
prints its state and rates. Existing saved source/share/consent controls remain.

## Exact assertion migrations from reviewed E1

No original test case was deleted. All inherited E1 behavioral tests and the full
suite run. The inherited builder's 45-test E2 file is preserved in WIP `82fcf57`,
then replaced with independent specification tests; its green result was not
accepted as proof because it encoded the wrong cancellation and persistence rules.

| File / assertion | Exact migration |
|---|---|
| `test/src_warboard.lua`, `checkSends` | Replaced H/A-only / "NEVER FBAK" grammar assertion with truthful H/A **or** decoded FBAK/FBUN. New helper requires confirmed peer, live client target GUID, own hunter identity/faction, protocol/ruleset and LE version; FBAK additionally requires own Find and enabled tracking. Actual route must still be BN. |
| `test/src_warboard.lua`, `setup` gateway spy | Same conditional grammar replaces the H/A-only attempted-send check; unauthorized prefix/network still increments `badSend`, asserted zero even if protected callbacks swallow errors. |
| `test/src_warboard.lua`, `no FBAK or request answer or forwarding for any application type` | Renamed to `no unsolicited application response or forwarding; FBAK requires verified Find target`. Body and zero-send assertions retained; unsolicited application frames do not authorize asks. Positive/negative tracking authorization is covered separately in E2. |
| `test/src_warboard_review.lua`, README literal | Removed only the obsolete semicolon clause `LayerEnemies never asks anyone to broadcast their position.`; retained the full new-peer publication disclosure. |
| `test/src_warboard_review.lua`, README placement | Changed preceding marker from `**Nothing else**` to `| Tracking request/cancel |`, following marker from `Both H and A` to `H, A, FBAK and FBUN use`; still requires the disclosure immediately in the handshake send section. E2 tests separately pin its send-table-first order and both mandated consequence sentences. |
| `test/harness.lua:1168` — `we reports never enter LayerEnemiesDB` | Added only `(k=="warboardOwed" and type(LayerEnemiesDB[k])=="table" and #LayerEnemiesDB[k]<=40)` to saved-key allowlist. Existing report-value scans unchanged. |
| `test/harness.lua:2059` — `hop state clears on zone change and reload` | Same one-field, type-and-cap-checked allowlist addition; old cleanup assertions unchanged. |
| `test/harness.lua:3437` — host saved/on test | Same one-field allowlist addition; guildHost type/behavior assertions unchanged. |
| `test/harness.lua:3581` — Auto accept and leave saved test | Same one-field allowlist addition; forbidden-call and behavior assertions unchanged. |
| `test/kills.lua:145` | Added `warboardOwed=type(LayerEnemiesDB.warboardOwed)=="table" and #LayerEnemiesDB.warboardOwed<=40` to saved-key allowlist; recursive evidence checks unchanged. |
| `test/known.lua:25` | Same allowlist addition; existing evidence-isolation checks unchanged. |
| `test/overlord.lua:320` | Same allowlist addition; counter and recursive save checks unchanged. |
| `test/watch.lua:335` | Same allowlist addition; before/after save snapshot and switch persistence checks unchanged. |
| `test/api_policy_test.py` | Added tracking-module static API/send checks, rejects `_G`, `C_Timer`, `CreateFrame`, `Wire`, `LayerEnemiesDB`, `UnitGUID`, `GetTime` in tracking, and requires exactly one `BN.send(` call. No existing send-policy assertion weakened. |
| `test/warboard_mutants.py` | Updated final-source-predicate anchor for the new completion path; renamed `no FBAK send` to `handshake grammar cannot masquerade as FBAK`; updated no-forward selector to the renamed case; updated README literal to the approved disclosure. Same behavioral invariants, all 98 killed. |

`test/verify.py` is unchanged: the existing one-owner/one-client-send-site checks
cover the new file automatically. SavedVariable allowlist changes are precisely
those eight assertion sites above; no boolean `warboardTrack` is accepted or saved.
E2's saved-data tests compare every other saved key before/after an active request
and received position, and pin exact dense GUID-only content, sanitation and caps.

## Verification evidence

- Preserved WIP: `82fcf57`; independent tests: `f473c76`; lifecycle rewrite:
  `7add70a`; bounds/mutants: `f033564`; final handshake correction: `6b57dca`.
- Initial independent tests against inherited WIP: **16 passed, 23 failed,
  2945 assertions**. Initial frozen E1 base: **3 passed, 36 failed, 2821 assertions**.
- Final test file copied alone into detached `65904e66`: **5 passed, 53 failed,
  3880 assertions**, exit 1 (`/opt/data/cache/scratch/le-e2-base-red-current.log`).
  The five negative guards already pass on E1; do not count them as feature RED.
- Candidate: **58 tracking tests pass**. Combined WarBoard command:
  `lua test/harness.lua --only 'WarBoard'` → **159 passed, 0 failed,
  39616 assertions** (`/opt/data/cache/scratch/le-e2-focused-final.log`).
- Self-review found a handshake-before-stop loophole: the regression first failed
  with `expected 1, got 2`, then passes after comparing handshake time with stop
  time, not the initial handshake. The matching mutant reproduces that exact failure.
- `python3 test/verify.py`, foreground, subprocess timeout 1750 s / tool timeout
  1800 s, exit **0**: **RESULT: 1455 tests passed, 0 failed, 214806 assertions**.
  Full log: `/opt/data/cache/scratch/le-e2-verify-current.log`. Syntax, TOC/static
  policies, verify tests, API policy, harness discovery, media and package/source
  parity all pass. `notes/test-results.txt` and `notes/verification.json` regenerated.
- `python3 -B test/warboard_track_mutants.py`: **64/64 killed**. Every result is a
  real assertion failure; syntax errors, empty collection and timeouts do not count.
  `notes/warboard-track-mutants.json` SHA-256:
  `a8331595e38a56e771e63bdb395828ee682dc532f79e2a0bd133204cb243912d`.
  Repeated execution leaves **bytes and mtime unchanged**. A relocated checkout
  containing spaces, unrelated working directory and relative TMPDIR yields the
  same bytes and cleans scratch. `notes/warboard-mutants.json`: **98/98 E1 killed**.
- Added-line security scan: no hardcoded secrets, shell-injection or unsafe
  deserialization matches; `git diff --check` passes.
- Deterministic local archive `dist/LayerEnemies-1.1.0.zip` SHA-256:
  `243625edcbe3a0c45f6947ae267352b314f3574d6354de8eb9057e72c5b45468`.
  The lane retains the foundation's 1.1.0 TOC/package version; 1.2.0 versioning is
  left to the release integration, with this feature documented as Unreleased.

## Rulings / differences from the literal plan

1. **Session-only tracking toggle**, default on each login. Only one new saved
   field is authorized, and switch persistence is unspecified. Cost if unwanted:
   track-off must be repeated after login; saved source/share/consent switches remain.
2. **Close every restored debt**, not just no-longer-tracked/off targets, before
   asking again. This conservatively clears uncertain prior-session subscriptions.
   Cost: one extra cleanup and a delayed first ask for still-tracked targets.
3. **Retain local combat/instance retirement** from the inherited builder, rather
   than simply suspending an active request. Owed cleanup is now held, not lost.
   Cost: a fresh-start pause after local combat/instances; this is stricter than
   the plan's no-scan/no-send safety boundary.
4. **A confirmation is required for new requests**; H alone can create E1 receive
   state but does not prove the target received our answer. This conservative
   interpretation may reduce reach until an A arrives; expired A cannot be revived
   by an H. A fresh post-stop handshake can shorten renewal give-up idle as specified.

No gameplay records, snapshots, forwards, guild relay, own positions, Ask/Hop
authority or evidence storage are added. E1's Find admission and honest position
wording are retained. Audit section 11 has no constructed FBAK, so the new tests
pin complete field layout and independent Ace text, and round-trip our own writers
through our addon/raw-DEFLATE/Ace readers instead of claiming canonical compressor
bytes. Whether the target accepts hunters outside its community roster remains
unknown and fails silent; no extra roster access or fallback is invented.

Final review: **self-review (no independent reviewer tool in this subagent lane)**;
parent review remains independent. No deferred minor fixes. Native checks:
**not run (alpha, owner's decision)**. Harness success is not client delivery proof.

## Changed files

- Runtime: `LayerEnemies/{Adapters,BNet,Find,Main,Net,Sources,WarBoard,WarBoardTrack}.lua`
  and `LayerEnemies/LayerEnemies.toc`.
- Documentation: `README.md`, `THIRD_PARTY.md`, `notes/warboard-track.md`,
  `notes/warboard-track-plan.md`.
- Tests: `test/{harness,kills,known,overlord,watch,src_warboard,src_warboard_review,src_warboard_track}.lua`,
  `test/{api_policy_test,warboard_mutants,warboard_track_mutants}.py`.
- Generated evidence (separate commit): `notes/test-results.txt`,
  `notes/verification.json`, `notes/warboard-mutants.json`,
  `notes/warboard-track-mutants.json`.
