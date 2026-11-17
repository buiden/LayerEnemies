# C3 completion — NH-free kill feed

This is the current C3 evidence, superseding the unavailable-feed and no-stop
policy recorded in `overlord-c3-review.md`. Scope is PLAN section 6.5 plus the
owner's explicit NH silence, busy answer and stop rulings.

## Checkpoints

- WIP saved first as `61ce7b3`, after `140 tests passed, 0 failed, 51118 assertions`.
- Verified C2: `b39fbedf7bfa5901333160d9b8bfe51d15bab776`, implementation `d5e02eb`.
  Its full result: `1486 tests passed, 0 failed, 270182 assertions`; peer 54/54 and
  receiver 54/54 mutants. The separate C2 notes commit/tag remains openable.
- C2 forward-merged into C3 as `df5c8bb`; only generated verification notes
  conflicted. Retained the old C3 generated notes until regeneration, not a
  hand-merged test total. Final verifier metadata corrected in `0a325fa`.
- This separate evidence commit follows the final tested code and moves the C3
  tag. No push, GitHub writes, donor execution or donor code copying.

## Sends, caps and suppression

All locations below are in `LayerEnemies/` at the final code revision.

| Send | Exact body and destination | Bound / implementation |
|---|---|---|
| Request | `HR 8:V:<E>:<nonce>:1:LK:0:0:<opposite faction>`; nonce ends `f`; selected same-faction group member via WHISPER or current Battle.net friend | At most two sources, `OverlordFeed.lua:69`; strictly more than 300 s of silence, `:84-86`; one request/keep per 200 s both admission and dispatch, `:259-277` |
| Keep | `HR 8:K:<E>` to the same source after a live accepted HA/HB | Same 200 s gap, `OverlordFeed.lua:262-277` |
| Stop | `HR 8:X:<E>` to a source whose request was successfully sent | Once per cancellation, owed, best effort, no retry; `OverlordFeed.lua:88-112` |
| Busy answer | `HA <v>:R:<E>:<nonce>:<seq>` to a direct addressed HR requester | Shared canonical `reply:` gap with NH: 150 s, `OverlordPeer.lua:107-119`; six owed frames/minute at admission and actual dispatch, `:34,58` |
| Presence | `NH LayerEnemies <installed TOC version>`, never a capability suffix | `OverlordFeed.lua:9`; C2 guild/group/bridge/greeting caps remain in `OverlordPeer.lua:124-169` and README |

The envelope remains `BF:<id>:1:1:<pool>|<id>|<at>|<target>|<own name>|<kind>|<payload>`
for addon messages and `R2:Forever_<pool>_<faction>:BR:<packet>` for Battle.net
(`OverlordPeer.lua:62-68`). Nothing is forwarded or sent to CHANNEL.

A selected source hears **no NH**: not a periodic/account greeting, not an owed
whisper answer, and not a whole guild/group broadcast when the source belongs
to that audience. Unreadable rosters suppress that whole lane conservatively.
Selection occurs before owed NH (`OverlordPeer.lua:106`), and suppression applies
at both emission (`:69`) and final queued dispatch (`:30`). Source name/account
and shared-lane checks are `OverlordFeed.lua:74-86`. The quiet clock begins at
selection, even after a reload, must be strictly >300 s before the first ask,
and resets after removal/replacement. Silence continues for the whole selection.
Non-source peers keep C2 presence. No ranking capability is advertised.

Shared transport caps are unchanged: Battle.net Overlord 8/minute within the
all-network 30/minute and one/second (`BNet.lua:38,92`); addon whispers 20/minute,
four/minute/target, guild 20/minute (`Wire.lua:100`), with the existing reserves.

Stops cover unsubscribe, network off, share off, Guild only, source departure /
unfriending, invalidated route/epoch and best-effort logout (`Main.lua:2576`).
Only exact outstanding stop bytes can cross privacy/off switches
(`Main.lua:483-494`, `BNet.lua:51-52`, `Wire.lua:297-313`). Combat, instance,
unknown pool/identity and real-Overlord-loaded gates still silence every send.
Pending stops are discarded after 60 s without retry. Remote delivery is not
proved; the donor's subscription TTL is 900 s, distinct from the 200 s keep.

## Reachability and limitations

Step 0 is preserved in `overlord-c3-reachability.md`: donor 2.5.4 pin
`c821808586ab50bb4ccb5d54b146e0d7c2671734`, read-only source. A valid targeted
HR teaches its return route before application dispatch, including the Battle.net
account ID. Thus NH-free replies are reachable for both same-faction group
members and opposite-faction friends in the independent source model. The donor
forgets NH only at **age >300**, not at exactly 300. No donor code was run.

Only tracked opposite-faction names become relayed, time-unknown location claims,
with no layer or Ask/Hop authority, no ranking store and no new saved schema.
Epochs are validated per source/pool, never guessed from the clock. The donor
must consider its own custom channel down and be able to serve; silence is normal.
Native client checks: **not run (alpha, owner's decision)**.

## Fresh verification

- Post-merge focused suite: `RESULT: 143 tests passed, 0 failed, 52703 assertions`.
  C2's three real-timer probes still pass: marked offline 60 accepted / 39 distinct;
  natural offline 177 accepted, 180 attempted, three client refusals / 39 distinct;
  own-realm-qualified 60 accepted / 40 distinct. Attempt gaps remain >=60/600 s.
- Final `python3 test/verify.py`, Lua 5.1.5:
  **`RESULT: 1553 tests passed, 0 failed, 290032 assertions`**, exit 0.
  Syntax (89 files), TOC/static/API policy and archive integrity/source parity PASS.
- Deterministic archive: `dist/LayerEnemies-1.1.0.zip` (TOC version intentionally
  unchanged by this local feature task); SHA-256
  `b16ec8b82dddcdb3e613e98c877f1bdd5913b16d82a1fb0e2d1a66bb88ad7ce2`.
- All Overlord mutation runners rerun on C3: **peer 54/54**, **receiver 54/54**,
  **feed 63/63**, **reachability 28/28**. Every row in all four generated reports
  is killed; no syntax errors, setup exceptions or timeouts count as kills.
- The new reachability runner was also run by absolute path from `/opt/data`
  against an isolated copied checkout, with `--write`: 28/28, exit 0, report
  bytes and mtime unchanged.

All long runs used foreground `subprocess.run(timeout=1800)` inside a tool call
requesting 1800 s, one runner per call. The C3 receiver RPC hit an outer 420 s
wait despite that setting; its original foreground child remained alive. Waited
for that same child without relaunching it, then read its complete 54/54 result.
No worker/test was abandoned and the timeout was not counted as success.

Evidence is in `/opt/data/cache/scratch/le-overlord-resume-evidence/`:
`c3-merged-focused.log`, `c3-{peer,receiver,feed,reachability}-mutants.log`,
`c3-final-verify.log`, `c3-final-verify-status.json`, and
`c3-reachability-portable.{log,json}`. The first full C3 run exposed stale
verification prose saying the feed was unavailable; the metadata was corrected
and the entire gate rerun, without changing addon behavior or test assertions.

Final review: self-review (no subagent tool), against PLAN 6.5, README send table,
transport admission/dispatch, stop hooks and source-selection boundaries. No
additional must-fix found; native delivery remains explicitly unverified.
