# LayerEnemies implementation summary

## Delivered

- Addon folder: /opt/data/projects/layer-enemies/LayerEnemies
- Local package: /opt/data/projects/layer-enemies/dist/LayerEnemies-0.1.0-headless.zip
- Interface 16001; Lua 5.1; SavedVariablesPerCharacter LayerEnemiesDB.
- Pure safety/hash/layer/protocol/store/reassembly modules with thin adapters
  and hidden event dispatcher. `/le`, `/le unclassified`, `/le reports` print
  current state without a visible window or minimap button.
- Own event-driven sightings and protected Bulo snapshots with optional,
  separately source-verified GUID enrichment. Only readable unit factions
  establish opposite faction. Hostility alone never does.
- Conservative epoch invalidation for zone/world/transfer/raw-ID changes,
  carried-unit quarantine/reacquisition, ten-minute expiry, bounded memory,
  observer-only positions, and possible-not-unique hash identity annotations.
- Passive privacy-gated WEFF1 listener and independent C/E/H decoder.
  Complete report reducer exists and is tested with explicit absolute-time
  evidence. Live reporting is deliberately unavailable: the source only
  supplies ambiguous seconds-within-hour timestamps. Legacy ZRAD1 is
  registered but live access also fails closed on unexposed legacy permission.
- No third-party addon code, source archives, credentials, or saved sightings
  are bundled. Nothing was pushed, published, uploaded, or installed in a client.

## Exact executed verification

Command: python3 test/verify.py

- Lua interpreter: Lua 5.1.5.
- luac -p: 10 of 10 Lua files passed (8 addon modules, harness, benchmark).
- Strict mock harness: 44 tests passed, 0 failed, 6,219 assertions.
- Deterministic malformed-wire fuzzing: 5,000 inputs, included in those counts.
- TOC manifest/source-file parity: passed.
- Static check: no outgoing addon/chat/channel-join calls, forbidden combat-log
  subscription, or OnUpdate in addon code.
- git diff --check: passed during verification.
- Local ZIP: 10 members; CRC test and byte-for-byte source/README parity passed.
- Package SHA-256:
  d1ee0ce741d485ce8cc3ae1f34802d0a3ee22ab33f722cd487b2d0f9c866a4b7

Machine-readable result: notes/verification.json.
Full real test stdout: notes/test-results.txt.
Repeat verification/package command: python3 test/verify.py.
The harness is simulated client execution, not real-client testing.

Test areas include absent/present/incompatible Bulo; protected subscription
failure/polling; sighting copying and expiry; full/raw layer invalidation;
transfer epochs and stale carried-unit quarantine; reacquisition; real-zone vs
child-map changes; missing map API; faction/duel/secret handling; optional GUID
API returns; NPC GUID namespaces/distinct-kind confirmation/caps; hash vectors;
strict C/E/H fields; fragment order, conflict, duplicate, count and timeout;
stale/future/hour-ambiguous stamps; replay and epoch tombstones; floods/caps;
CHAT_MSG_ADDON own echoes/wrong channels; source/client ignore, guild-only,
silent and unsupported privacy settings; source membership; live report
fail-closed behavior; possible hash identities/collisions; independent report
classification; deterministic sorting; SavedVariables privacy; map candidate
zone filtering; hidden dispatcher and timer pacing; same-frame enrichment;
foreign getter errors; unchanged observation allocation; malformed-input fuzz.

## Offline CPU/allocation measurement

Captured before and after eliminating duplicate observation-table allocation
for unchanged Bulo timestamps. Same 256-entry fixture, GC stopped during each
measurement; allocations are transient allocated KB, not retained heap.

                                     Before             After
Unchanged Bulo snapshot, ms/call      0.322515           0.211905
Unchanged Bulo snapshot, KB/call    100.288521           0.288345
256-entry prune, ms/call             0.011279           0.010601
256-entry prune, KB/call             0.000000           0.000000

These are short Linux/Lua 5.1 microbenchmarks; timing noise is expected.
They are not WoW addon CPU measurements or frame-rate evidence.
Raw iterations/results: notes/benchmark-before.txt and benchmark-after.txt.
Reproduce: /opt/data/tools/lua/lua-5.1.5/src/lua test/benchmark.lua.

## Not completed / not verified

1. Live War Effort enemy listings cannot meet strict freshness guarantees with
   the described wire format. An unseen previous-hour replay is identical to
   a fresh packet. No hello/receipt-time workaround or bypass option was added.
   The pure reducer's trusted absolute timestamp is explicitly a test fixture;
   no production source provides it. Consequently `/le reports` has no live
   rows in this release. Do not market remote listing as completed.
2. Window, class colours, layout, saved window position, and real WorldMapFrame
   canvas pins are intentionally unimplemented pending A/B preview approval.
   notes/UI-PENDING.md records semantics, not an applied design. Map tests
   prove only the data selector's zone/position eligibility, not actual pins.
3. No real Forever client was available/run. Loading, actual taint/secret-value
   behavior, event support/order, timer availability, addon metadata and
   settings lifecycle, GUID API availability/results, ignore-list readiness,
   sender normalization, CHAT_MSG_ADDON channel argument shape, player/NPC
   visibility and position APIs all require in-game verification.
4. Bulo server IDs and War Effort zoneUIDs remain distinct source assumptions.
   Paired clients must verify actual layer/zone/transfer semantics, including
   same-server raw suffix changes and different zoneUIDs on a single layer.
   A matching zoneUID never proves same-layer membership.
5. This is only an observation list, never a complete layer population. Event-
   driven bootstrap and carried-unit quarantine deliberately miss some data
   instead of guessing. Bulo-only hostility without readable unit faction is
   classified as unknown even if GUID name/class lookup succeeds.
6. Future remote listings would still be reports, not independently verified
   enemy identities/factions. Hash collisions and source authenticity remain
   limitations even if absolute freshness becomes available.

## Engineering lessons kept local to this project

- Absolute freshness cannot be reconstructed from modulo-hour timestamps.
  Preserve that blocker explicitly rather than adding increasingly elaborate
  receipt-time or hello heuristics.
- Apply privacy gates before decoding/admitting report state. Missing settings
  are not permission; unknown legacy-network enablement stays unavailable.
- Check the eighth GetPlayerInfoByGUID return only after checking the actual
  Forever-era API declaration. Never derive faction from its race return.
- An own unit event in the same frame as a Bulo copy may add classification
  without changing the timestamp. Preserve that safe same-frame upgrade.
- Tombstone timed-out and epoch-invalidated assemblies, not just completed
  ones; otherwise replayed fragments can restart old assemblies.
- Skip unchanged Bulo timestamps before allocating copied observations. Never
  reuse table objects already retained by the observation store.
- Do not claim map-rendering tests when only a headless selector was exercised.

All edits and generated artifacts were confined to this project. Reference
addon and skill files were read-only. Shared skills were not modified because
this run explicitly restricted work to the project directory.
