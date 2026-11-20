# Layer plan PR 1 - A1 to A5

Base: 19a1b41c94ee77aa30e2c6a7564850383e0c8da4 (combat-hop fix).
Scope: LE-LAYER-PLAN.md section 5.1 only. No Trust/blind-hop implementation,
new route/line/field, dependencies, saved state, version bump or release-section edits.
Not tested in game (alpha, owner's decision).

## Inspection and citation alignment

Read the corrected plan, README reference chapters, current sources, test/harness.lua,
test/verify.py and notes/hop-combat.md. This tree has no CI config; the README's
full local gate is python3 -I test/verify.py.
No semantic citation mismatches for A1-A5 were found; old line numbers moved.
FLH and ChehulNet already reject the four zero forms; they are regression controls.
README changes are in the observation and layer-key reference chapters, not release notes.

## Changes

- A1: Layer.lua:4,41,64 and Main.lua:129-150. Expire the NPC confirmation/raw key
  and cached Bulo key at 300 seconds without a valid read, on the poll tick.
  Invalid NPC reads do not refresh the clock. Expiry is not a crossing.
  Cover a late first read before the heartbeat, including the no-timer fallback.
- A2: Layer.lua:5,14,21, Wanted.lua:35,289 and Overlord.lua:212. Zero is unknown
  in each namespace. FLH.lua:12 and ChehulNet.lua:19 retain their existing guards.
- A3: Relay.lua:117,429; OwnDeath.lua:43; Protocol.lua:40,65,145;
  HeadHunter.lua:75; Overlord.lua:203; WarBoard.lua:365; Wanted.lua:35.
  Preserve otherwise valid records with a separable malformed layer. Identity-layer
  SHRD and Wanted bridge records remain strict. Invalid non-layer data still drops.
  OwnDeath.lua:83 and Wire.lua:46 keep outgoing K validation strict.
- A4: GuildHost.lua:72 and Main.lua:1161. Pass ambiguity to the host snapshot;
  drop before recording the request, replying or inviting.
- A5: Main.lua:5,48,84,96,120,138,215,2675,3036. Wipe only for readable zone
  changes, world entry, shard transfer, or confirmed changes within ten seconds of
  group join/leave. Other confirmed changes update the key and bounded session-only
  churn timestamps without a wipe. Donor notifications alone and unreadable maps
  do not prove a crossing. Both NPC and Bulo namespaces participate. A crossing
  preserves the new NPC confirmation clock and blocks a stale held donor ID.

## Red/green evidence

Final six new test files were overlaid on a git archive of the exact base, with
base production code and inherited harness unchanged. Every failure below was a
behavior assertion, not a missing API/setup error. Extracted base files were removed
before the full gate; logs remain under .git/layer-evidence/.

| Fix | Base RED (passed / failed / assertions) | Candidate GREEN |
| --- | --- | --- |
| A1 | 0 / 4 / 187 | 4 / 0 / 198 |
| A2 | 13 / 12 / 1151 | 25 / 0 / 1177 |
| A3 | 2 / 29 / 1430 | 31 / 0 / 1642 |
| A4 | 0 / 2 / 91 | 2 / 0 / 114 |
| A5 | 12 / 14 / 1408 | 26 / 0 / 1623 |

The initial implementation cycles were also red-first. Follow-up edge cases caught
post-group confirmation-clock loss, a stale Bulo/NPC fingerprint, late-read expiry,
and donor precedence masking NPC changes. The A5 tests cover both group transitions
at +9/+10/+11 seconds, real zone/transfer/world events, retained records and a real
pending own-death send (survives rotation, cancels on transfer).

Inherited assertions that explicitly required whole-record rejection or raw-ID wipes
were migrated to A3/A5, retaining non-layer rejection and real-boundary controls.
Long hop/FLH budget fixtures now refresh real NPC observations so A1 expiry cannot
mask their original deadlines and send-count assertions. The FLH replay still admits
12/12 clicks at both delays and 120/120 in both offset sweeps.

Full gate, through the shared heavy wrapper: python3 -I test/verify.py, exit 0.
RESULT: 2321 tests passed, 0 failed, 655235 assertions
Python gate suites also report OK (43, 30, 4, 4 and 11 tests).
The successful output is .git/layer-evidence/verify-green.txt. Generated verification
notes were copied there and restored to the base in the working tree to avoid
changing release-owned generated evidence. No Trust/HopProbe mutants apply to PR 1.

Final review: self-review (no nested reviewer tool). Added product lines contain no
private paths, credentials, non-ASCII text, dependencies or SendChatMessage. TOC,
version, route table and budgets are unchanged. The only Wire edit preserves strict
outgoing K validation after relaxing receive-side layer handling.

## Section 4 own-key inventory for PR 2

Search: .bulo, .zoneUID, Layer.server/L.server and npcs.raw/current; then trace
own.server and own-key encoder arguments. Raw scan: 61 matches; most are in the
section 9 files or are not own-key reads. No direct store.bulo/store.zoneUID or
Layer.server call exists outside the section 9 files and Layer.lua/Trust.lua.
The additional equivalent readers outside that list are:

- Adapters.lua:387-388,403: Bulo namespace current read, validation and snapshot.
  This is an input adapter, not a trusted own-key consumer.
- Record.lua:123-128: own.server in the record relation comparator.
- FLH.lua:82-92: c.key in the shared outgoing builder and its local own alias.
- WeOut.lua:28-30: layer argument in C encoding (own reports or rebuilt reports).
- WeOut.lua:39-42: t.layer in H encoding (own hello or rebuilt hello).

The last two files consume caller-projected keys; PR 2 should gate the own caller
without erasing historical received-report fields. Adapters.lua:414 is a function
declaration, and :654-655 are peer-list .bulo fields, not own keys. Incoming FLH
ownKey means the remote requester's key, not this player's. Full raw inventory:
.git/layer-evidence/own-key-grep.json. These extra files need the architect's PR 2
inventory; they are not changed by this PR.

## PR body draft

Fix layer-key expiry, zero handling and degraded-layer decoding (plan PR 1, A1-A5).

- Expire stale own keys at 300 seconds without discarding observations.
- Treat all four zero forms as unknown; preserve valid names/positions when only a
  separable received layer is malformed; retain identity and non-layer validation.
- Keep guild hosting silent while ambiguous.
- Restrict state wipes to real boundaries, including confirmed key changes within
  ten seconds of a group transition; retain other changes as bounded churn evidence.
- Keep outgoing grammar, routes, budgets, version and SavedVariables unchanged.

Validation: 88 focused regressions pass; base replay has 61 behavior failures.
Full python3 -I test/verify.py: 2321 tests passed, 0 failed, 655235 assertions.
Not tested in game (alpha, owner's decision).
Trust state, hidden UI and blind hopping remain separate later PRs.

## Open questions

None blocking PR 1. Carry the additional reader inventory into PR 2.
