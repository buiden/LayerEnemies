# C3 correction — PLAN 6.5.1 / Battle.net friends only

This is the current policy and evidence. It supersedes the source-selection,
whole-lane suppression and selection-time quiet clock in the historical
`overlord-c3-completion.md`. The owner's Battle.net-only override is narrower
than PLAN 6.5.1's mention of group presence as an online check.

## Checkpoints and scope

- C2 reviewed base: `b39fbedf7bfa5901333160d9b8bfe51d15bab776`.
- C2 self-silence implementation: `0094df7`; separately committed evidence/tag:
  **`9af42790247faeb90bb9f30a156cf5952823b812`** (`fix/c2`,
  `le-1.2.0-c2-overlord-peer`). See `overlord-c2-self.md`.
- C3 reviewed base / frozen RED checkout:
  `7d7287dfe8f942dd7798ce7d1c21bb723886e445`.
- C2 was forward-merged as `6606c77`. C3 implementation slices: `f07e138`
  (isolated Battle.net selection and actual-NH clock), `46d76c6` (one owed stop),
  `5276977` (backoff / HR policy / README), `177496d` (approved fixture migration
  and logout closure), **`d52babc27e01eccf84b079e4ca88b50da1a6927f`**
  (bounded retained hearing and mutation coverage). Final test-pack commit:
  **`93ab76abf49389913051861385b9838d8250af30`** adds same-faction/first-K
  reachability and club-only exclusion controls without changing production code.
- This separate notes commit is the C3 tag target. Local commits only: no push,
  GitHub writes, donor execution or donor code copying. No new saved fields.

## Current rules

1. The single `OverlordPeer.key` combines the existing Unicode fold with the
   existing own-realm canonical target. Self-targets are refused at admission
   and queued dispatch. Guild snapshots, party units, whisper targets,
   Battle.net character names and feed keys use that same source identity.
2. Feed sources are **Battle.net friends only**, of either faction. A guild/group
   member is ineligible, and unreadable/incomplete membership means no friend is
   known to be outside it. Ordinary C2 guild/party/raid presence is not suppressed.
   Selected source names/accounts cannot receive targeted NH, including owed NH
   and previously queued NH. Queued requests recheck current eligibility too.
3. A source needs first-hand Battle.net Overlord hearing at least once this session
   in our pool, a currently online matching Forever game account, and a validated
   source campaign epoch before a request. Hearing does not expire after 300 s.
   The retained hearing cache is bounded at 200 without bypassing C2's 128/96
   route ceilings.
4. The quiet interval is **strictly more than 300 s since an actual NH that could
   reach that account**, through BNET, WHISPER, GUILD or PARTY/RAID. There is no
   selection-time wait when none was sent this session. A completed unexpected
   NH restarts the interval. Uncertain shared audiences are conservative.
5. Repeated privacy cancellations preserve only the exact validated owed X for
   an opened session. They neither erase it nor create another. Hardware,
   identity, donor-loaded and expiry gates still apply; delivery is best effort.
   Logout closes ordinary admission before pumping that existing queue once.
6. Silent-source request gaps are 200, 400, 800, 1600, then 1800 s (capped).
   Valid HA R/S/P and HB reset the delay to 200 s. Active keeps share the 200 s
   request/keep gap. Only addressed HR V receives bounded busy HA; HR F/K/X and
   unsupported kinds receive none. README and verifier metadata state this.

## RED -> GREEN

The immutable reviewed C3 base received only the new regression fixture for RED.
All failures below are valid-fixture assertion failures, not setup errors. The
machine-readable original failure lines, probes and matching final PASS names
are in `overlord-c3-r2-red-green.json`; final expanded coverage is reported
separately rather than substituted for the initial RED totals. The original combined
fixture was replayed on the frozen base: **5 passed, 27 failed, 1774 assertions**.
It is preserved verbatim in `overlord-c3-r2-baseline.lua.txt` (SHA-256
`5845fbfe7cab7537a52c9642d72ef76a9a5b4eb334b2b6389d7e43cf12226936`).
To reproduce, open a detached worktree at the reviewed base, copy that file to
`test/src_overlord_revision.lua`, and run the harness with `--only "Overlord revision:"`.
The temporary RED worktree was removed after preserving the fixture.

| Rule family | Initial RED | Final behavior |
|---|---|---|
| C2 self | 0 passed / 4 failed / 168 assertions | All four own-name cases send 0 self greetings; the other directory peer still gets 1; admission and dispatch stay silent |
| C3 M + clock | 1 passed / 16 failed / 874 assertions | Every former failure passes; all four reviewer leak paths closed under the revised source policy |
| S1 stop | 4 passed / 4 failed / 380 assertions | All eight BNET/legacy-WHISPER cancellation combinations send exactly 1 X, with no later retry |
| S2 backoff | 0 passed / 5 failed / 306 assertions | 34 requests in 7000 s becomes 7; HA R/S/P and HB each reset the delay |
| S3 truth | 0 passed / 2 failed / 214 assertions | HR V gets busy HA; F/K/X/T get none; exact README promise and source/backoff table pass |
| Retained-hearing route cap | 0 passed / 1 failed / 43 assertions on the intermediate candidate | Restoring cached peers admits 96 public routes instead of 200; retained hearing remains capped at 200 |

### Reviewer leak figures (900 seconds each)

- Guild Élan Scout, Ølaf Scout, Борис Скаут: each **2 NH to a selected source -> 0**.
- Grouped with unreadable party units: **8 -> 0**.
- `Name-OwnRealm` party unit: **8 -> 0**.
- Group peer also a realm-qualified Battle.net friend: **8 -> 0**.
- These audible/possibly audible friends now have **0 selected ticks**. Guild
  lanes still send **2 NH**, group lanes **8 NH** during the same runs. Ordinary
  C2 presence is not being disabled to obtain the zero-leak result.
- An isolated eligible Unicode/own-realm Battle.net alias is positively selected,
  receives real HR requests, and hears **0 NH over 900 s**. A same-faction
  Battle.net friend also starts from a first-hand owner K alone and stays NH-free;
  an online club-only account is never selected or requested.
- Each of the four actual-NH route callbacks blocks the next request for the
  restarted 300 s. Exact-age 300 dispatch is refused; strictly later is admitted.
  A never-announced friend starts immediately. One first-hand hearing remains
  usable for 7000 s while the account stays online; 600 s sparse hearing works.
- S1 BNET repeated share-off, triple share-off, share-off/network-off and
  share-off/Guild-only each change **0 X -> 1 X**. The four legacy-WHISPER cleanup
  controls remain **1 X**; no new whisper source is selected.
- S2 measured gaps: **200,400,800,1600,1800,1800**. Receipt checks are separate
  from incoming presence, which does not erase silent-source backoff.

## Verification

All commands use Lua 5.1.5 at
`/opt/data/tools/lua/lua-5.1.5/src/lua` and the repository root.

- C2 full `python3 test/verify.py`:
  **`RESULT: 1490 tests passed, 0 failed, 270362 assertions`**.
  Syntax 87 files, TOC/static/API and archive integrity/source parity PASS.
- C3 final focused `lua test/harness.lua --only Overlord`:
  **`RESULT: 186 tests passed, 0 failed, 55170 assertions`**.
  The new revision family contributes 38 passing tests.
- C3 full `python3 test/verify.py`, exit 0:
  **`RESULT: 1596 tests passed, 0 failed, 292499 assertions`**.
  Syntax **91 files**, TOC/static/API and archive integrity/source parity PASS.
- C3 archive `dist/LayerEnemies-1.1.0.zip`, SHA-256:
  **`73372430a5f8e75c6cfaf0599c99c92b46dc92b36c0b93591d5c0b7618b01019`**.
  The TOC version is intentionally unchanged by this local feature correction.

### Mutation controls

- C2 checkpoint: peer **57/57**, receiver **54/54**.
- C3: peer **57/57**, receiver **54/54**, feed **63/63**, reachability/lifecycle
  **48/48**: **222/222 behavioral kills**, no survivors.
- The reachability runner includes an independent mutant for each M/clock/S1/S2/S3
  rule, plus retained-hearing and route-bound controls. Removed whole-lane
  suppression/fresh-hearing rules were replaced by their approved opposites.
- One live-account mutant initially survived because the shared queue also drops
  offline sends. The added assertion checks that the offline account is no longer
  selected *before dispatch*; the unmutated case passes and the mutant now fails.
  This is added mutant coverage, not a claimed new production RED.
- Peer, feed and reachability runners were rerun by absolute path from `/opt/data`
  against `/opt/data/cache/scratch/le-c3-portable-g_6lbua3`, with `--write`.
  Each exits 0, matches the original report byte-for-byte, and preserves a report
  mtime deliberately pinned to `1000000000000000000` ns. The unchanged receiver
  runner uses the same tested portable reporting function.
- All long commands launched foreground with explicit subprocess timeout 1800 s
  and tool timeout 1800 s, one command per call. The receiver tool RPC hit its
  external 420 s wait; the original child remained alive. It was not relaunched:
  its completed log reports **54/54**, its generated report contains 54 killed
  rows, and the final status file records **exit 0** (1253.449 s). The original
  PID is gone. No timeout was counted as a mutant kill.

Logs are `/opt/data/cache/scratch/le-c2-final-verify.log`,
`le-c3-{M,S1,S2,S3,memory}-red.log`, `le-c3-final-focused.log`,
`le-c3-final-verify.log`, `le-c3-{peer,feed}-mutants.log`, `le-c3-receiver-mutants-final.log`,
`le-c3-reach-mutants-final.log`, and `le-c3-{peer,feed,reach}-portable.log`.

Native checks: **not run (alpha, owner's decision)**. Source-model reachability
and offline client-boundary tests do not claim real remote delivery.
