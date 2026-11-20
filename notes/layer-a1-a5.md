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

## Review round 2

Reviewed base: 3dbb2203cde1905f23fd5b2f0c4d78afeb37817e.
One follow-up commit; no new protocol, route, budget, SavedVariables or version.
The original evidence above describes the prior commit, not this follow-up.

- MUST 1 / consumer coverage: Store.lua:51 retains ownKey alongside ownAt and
  ownSource, including through a Bulo refresh. Find.lua:184,240,260 and
  Known.lua:9 retain the full observation key, and Main.lua:1444 supplies the
  current key. Find compares full keys rather than server prefixes or the old
  layerKnown flag. Main.lua:2269 only emits a layer when every own sighting in
  that cohort matches the current full key. Expiry/mismatch keeps the names,
  shows "seen by you" and sends empty O / zero C. K remains death-time evidence.
- MUST 2: Main.lua:9,51,106,118 keeps lastConfirmedKey privately across expiry,
  clears it at a real boundary, and uses it only for change detection. Expiry
  between a group join/leave and confirmation no longer hides the crossing.
- A3 outer guards: Overlord.lua:21,117,152,180,211 share GW field validation
  through direct/fragmented wrappers. Only its separable layer may contain
  controls; envelope fields and other payload kinds stay strict. Wanted.lua:163
  retains original layer bytes through the checksum before place drops that
  field. Oversize packets, bad checksums/non-layer fields and identity-layer
  Wanted bridge records still drop; WarBoard SHRD is untouched.
- Churn counting: Main.lua:87 counts every confirmed unexplained change outside
  the group window, even within ten seconds of a boundary. First learning after
  a real boundary and same-key refreshes do not count.

### Round 2 red/green

Final four new test files were overlaid on a git archive of the exact reviewed
base, with its production code and inherited harness unchanged. All listed RED
failures are behavior assertions. The temporary extraction was removed; logs
are retained under .git/layer-round2/.

| Item / test file | Base passed / failed / assertions | Candidate passed / failed / assertions |
| --- | --- | --- |
| MUST 1 / src_layer_provenance.lua | 5 / 11 / 962 | 16 / 0 / 1008 |
| MUST 2 / src_layer_expiry_crossing.lua | 4 / 8 / 710 | 12 / 0 / 734 |
| Churn / src_layer_churn_count.lua | 2 / 4 / 306 | 6 / 0 / 318 |
| A3 / src_layer_outer_guards.lua | 13 / 19 / 2886 | 32 / 0 / 3059 |

MUST 1 asserts Find status/rendered text and actual O sends for NPC server and
zoneUID rotations, Bulo rotations (including equal server prefixes), a change
thirty seconds after joining, and expiry. It also covers Bulo refreshes, old
Find history, real C sends with mixed-age cohorts, reacquisition, and unchanged
pending K layer fields. MUST 2 covers NPC/Bulo, join/leave, same-key recovery,
and changes inside/outside the window. A3 covers control bytes 0, 1, 10, 13, 31
and 127 through real direct/fragmented GW and compressed/checksummed Wanted
records, plus pipe layers and strict non-layer/envelope/identity controls.

Inherited fixture updates preserve their assertions: pure Find cases now pass
an explicit current key; the OpenMap own-sighting control establishes one;
the long Round1 precedence fixture keeps readable Bulo evidence. The sole
behavior expectation migration is seen unknown 03c: a Bulo refresh no longer
promotes an earlier unknown own sighting's outgoing O layer.

The first full gate caught an Overlord packet-level rejection regression for
control bytes outside the layer. That failure is preserved in
.git/layer-round2/verify-first-failed.txt. Shared GW field validation fixes it
without changing the inherited assertion. The focused Overlord suite then
reported 36 tests passed, 0 failed, 19066 assertions; outer guards remained
32 tests passed, 0 failed, 3059 assertions.

Final full gate (`python3 -I test/verify.py` through the required two-slot wrapper):
RESULT: 2387 tests passed, 0 failed, 660364 assertions
Exit 0; Lua syntax, static/TOC checks and archive/source parity PASS. The five
Python test groups (43, 30, 4, 4 and 11 tests) also report OK. Full output is in
.git/layer-round2/verify-green.txt. Generated test-results and verification.json
are preserved there separately; their tracked copies are restored to keep this
follow-up scoped.

Self-review: no new non-ASCII characters, private paths, credentials or execution
hooks. Wire.lua, OwnDeath.lua, TOC/version and test/verify.py are unchanged.
README additions are in Local observations and Layer keys reference chapters.
Unchanged schemas/caps do not imply identical sends: valid unknown-layer
records can still use existing forwarding. No new forwarding route was added.

## Open questions

None blocking PR 1. Carry the additional reader inventory and the settled churn
counting contract into PR 2. Trust state, hidden UI and blind hopping remain
separate later PRs.

## PR body draft

Fix layer-key expiry, zero handling and degraded-layer decoding (plan PR 1, A1-A5).

- Expire stale own keys at 300 seconds, treating zero forms as unknown.
- Preserve valid names/positions when only a separable received layer is bad,
  including outer GW/Wanted envelopes; retain checksum, identity and size guards.
- Keep guild hosting silent while ambiguous and restrict wipes to real boundaries.
- Bind own sightings to their original full key. Rotation/expiry cannot claim a
  new layer in Find or actual O/C output; K keeps its death-time layer.
- Detect group-window crossings across expiry and count later unexplained changes
  even immediately after a boundary, excluding first learning and same-key refresh.
- Keep wire formats, routes, budgets, version and SavedVariables unchanged.
  Preserved unknown-layer records may still use existing safe forwarding.

Validation: 66 follow-up regressions pass; exact reviewed-base replay has 42
behavior failures. Full python3 -I test/verify.py: 2387 tests passed, 0 failed,
660364 assertions (exit 0); Python gates, syntax/static checks and archive parity PASS.
Trust state, hidden UI and blind hopping remain separate later PRs.
Not tested in game (alpha, owner's decision)
