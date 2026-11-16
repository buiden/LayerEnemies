# Guild-intel PR 2: crowd sharing

Scope: audit A4/A5, section 5.1, tests 5/6 and the crowd mutation from the
guild-intel plan. Branch `gi-pr2-crowd` starts at `origin/main`,
`16549ca40b7cbf2cc59617e43f9c96057ab8799d`. No PR 1 dependency: Share/Relay are
untouched there; the Main, README and harness edits are in independent hunks.

## Contract and decisions

- `Sh.FRESH=45`, `Sh.EVERY=15`, `Sh.AGAIN=60`, three-second settle retained.
- The first slot snapshots eligible own-sighting keys. Each subsequent slot
  rechecks the current store, own timestamp, zone and name cooldown, and
  sends only unsent candidates from that snapshot. Nine short names use
  consecutive packets of 4, 4 and 1.
- Relay returns the exact fitted entry list, including byte-limit trimming.
  Share stamps only those entries after Wire accepts the O line. Invalid
  identities, names over the byte budget and refused sends are not marked
  shared. Duplicate observed identities cannot bypass the name cooldown.
- Ruling: a burst is at most **three attempts**, not an unlimited queue. After
  the third, unsent overflow (including name 13) is dropped without a shared
  stamp. Only a new own observation after that close may start another burst.
  This conservatively bounds failed attempts too. Cost: large crowds or long
  names need further observations; one snapshot need not deliver every name.
- Ruling: an O line has one age, not one per enemy. Use the actual **oldest
  fitted own timestamp** for mixed-age lines, recomputed at each send and
  after trimming. Cost: younger names in a mixed line look conservatively
  older, never newer. A single sighting waiting 30 seconds carries age 30.
- Slot reservation happens before Wire, including failed attempts. Nothing
  is queued; duplicate/fractional pumps, cancel/re-enable and boundaries
  cannot reset the 15-second or 60-second guards.
- Share-off, world/zone/layer boundaries and the existing guild-reset path
  cancel the snapshot. The store reset still discards old-zone observations.
  A same-guild event or temporary unreadable guild-name blink is not a
  transition and preserves the burst, matching existing cancellation rules.
- O follow-up slots do not generate additional War Effort C+E reports; those
  remain at burst start with the existing reader/network/position guards.
- No new timer, dependency, prefix, route, recipient or SavedVariables field.
  Burst/cancellation tables are session-only and bounded by the store's
  256 entries; old skipped keys are discarded at each cancellation.
  `Wire.lua`, the TOC and `test/verify.py` are unchanged. `O|1` field order,
  encoding, four-name cap and 255-byte cap are unchanged; old receivers need
  no update. Explicit-age encoder golden vectors remain byte-identical.

## Red/green evidence

Baseline Lua 5.1.5 run on untouched main:

    RESULT: 683 tests passed, 0 failed, 64043 assertions

Before production edits, only `test/crowd.lua` and its harness registration
were overlaid on a detached main worktree. The new tests produced assertion
failures, not Lua load errors:

    RESULT: 684 tests passed, 14 failed, 65170 assertions

Fourteen of the initial fifteen new cases failed; the existing zone/world
reset behavior already passed. The temporary base worktree was removed.

A later review found cancellation could accumulate skipped keys across
stores while sharing was off. Its test was added before that correction:

    RESULT: 698 tests passed, 1 failed, 65938 assertions

The failure was `expected 256, got 512`. Clearing obsolete cancellation keys
fixed it. Three additional guard-characterization cases passed when added
(quick off/on cooldowns, guild-name blink and cross-zone name cooldown); they
are not counted as red failures.

Final standalone harness and verification gate:

    RESULT: 702 tests passed, 0 failed, 66176 assertions

`test/verify.py` exit code: 0, using Python 3.14 with lupa 2.8. Syntax,
TOC/static API ownership, package integrity/source parity, assets and fuzz
checks passed. Archive SHA-256:

    9e26113e988ca8d2ca6eeb45b9de8f634f7154a6015de9c9dcb58801cfd658da

The generated `notes/test-results.txt` and `notes/verification.json` are
regenerated and committed separately after the feature commit.

## Existing test changes (exhaustive)

1. `e4c: an enemy re-seen every second is reported 3 s after its first sighting`
   — fixture-only migration: its stale probe moves from age 20 to 46, and its
   later observation/settle probes move from 40/43 to 60/63. No assertion
   expectation changes; age 20 is no longer stale with the required window.
2. `21e 56dbb3c: with Bulo refreshing every second, our own sightings still go out`
   — final O count changes **2 → 3**: the last genuine own sighting remains
   within 45 seconds when the next 60-second cooldown ends. The new assertion
   checks that third line's actual age against the last own observation and
   requires age <=45. Bulo-only refreshes still cannot prolong eligibility.

All other existing expected values are unchanged.

## Behavioral mutants

Run from the project root (the Lua path is caller-supplied):

    python test/crowd_mutants.py --lua /path/to/lua5.1 --output notes/crowd-mutants.json

Every mutant compiles, fails its named assertion and restores exact source
bytes in `finally`; the runner also executes a clean final harness. Ten of
ten killed, none surviving. The JSON evidence records the failure, complete
suite result and restored source hashes.

| Mutant | Killing test (`test/crowd.lua`) |
|---|---|
| All recent marked shared | crowd 5: nine enemies use consecutive 4,4,1 slots without repeats |
| Freshness back to 15 | crowd 6: a sighting waiting 30 seconds keeps its real age |
| More than one O per 15 seconds | crowd rate: duplicate and fractional pumps never open an early slot |
| Fourth line allowed | crowd cap: no fourth line for a 13-plus snapshot even at age 45 |
| Repeated name inside 60 seconds | crowd repeat: a new arrival never pulls a recently sent name along |
| Age field not the real age | crowd 6: a sighting waiting 30 seconds keeps its real age |
| Byte-trimmed entries marked shared | crowd packing: byte-trimmed names wait for the next slot |
| Refused send marked shared | crowd refusal: no shared stamp on a refused send and retry still waits 15 seconds |
| Cancelled snapshot can reopen | crowd switch: share off cancels the remaining snapshot without resetting pace |
| Cancelled stores accumulate | crowd cancel memory: repeated boundaries keep skipped keys bounded to the current store |

## Review and limits

Self-review only (no nested reviewer tool): checked the diff, receipt/packing
alignment, slot reservation, freshness boundaries, memory bounds, cancel
paths and unchanged transport ownership. The final gate and mutation suite
exercise actual Main/Store/Relay/Wire code through mocked client APIs.

Native checks: **not run (alpha, owner's decision)**. Actual guild-wide chat
throttling during a large fight and live delivery remain unknown. Wire
acceptance is not proof of delivery. Nothing was installed or pushed.
