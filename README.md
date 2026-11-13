# LayerEnemies

Headless WoW Forever addon, Interface 16001, Lua 5.1.

This build provides local observation adapters, conservative classification,
bounded stores, a passive network gate, and slash-command text output. It has
no window, minimap button, map pins, or applied visual design. Those require
A/B preview approval first. It is not a complete layer roster.

## Installation and commands

Place the LayerEnemies folder directly in Interface/AddOns, then reload the
client. Neither optional source is required for startup. An absent or unloaded
source is reported as not installed; a loaded Bulo with an incompatible shape
is reported as Bulo data unavailable.

- `/le`: current layer/source, both source statuses, and opposite-faction
  players directly observed in the current observation epoch.
- `/le unclassified`: local sightings whose faction is unknown or same-faction;
  these are explicitly not confirmed enemies.
- `/le reports`: separate unverified report section and the last rejection
  reason. In this release live War Effort reports are unavailable because
  their absolute freshness cannot be established. See below.

Text rows show readable name or Unknown, class, level, zone ID, sighting age,
source and confidence. No class colours or other visual treatment are applied.
Rows are newest first, expire after ten minutes, and are never saved.

## Local observations

Target, mouseover and nameplate events supply directly readable player data.
Opposite faction requires readable UnitFactionGroup tags for both units.
Hostility is not sufficient: duels and free-for-all areas can make a friendly
player hostile. Unknown factions stay unclassified. Missing/secret names,
classes, levels and GUIDs are never coerced into strings or guessed.

Bulo Layer Forever 3.0.24 exposes its current full ID and local radar
observations. The adapter copies only its timestamp, hostility, GUID/key and
source. GetPlayerInfoByGUID is a separately documented, optional API used for
readable enrichment only; it provides no faction. Its absence, errors, or
secret returns leave fields unknown. See notes/API-EVIDENCE.md.

Bulo's protected event-bus subscription observes LFS_LAYER, LFS_RAW and
LFS_TRANSFER. A five-second heartbeat also copies radar data and checks source
shape; it becomes two seconds while the world map is shown. Bus failures fall
back to the same heartbeat. There is no OnUpdate script. Unit events and bus
refreshes are coalesced.

Without Bulo, two different uncontrolled NPC kinds with agreeing GUID fields
can establish a local inferred server ID. Confirmation of zoneUID does not
confirm the server field: the two agreeing readings must also agree on the
full raw ID before it becomes a local layer label. No startup nameplate scan
or combat-log listener is used; fresh target/mouseover/nameplate events are
needed. Until a zone and layer label are known, confirmed-layer rows are hidden.

All identifiers are scoped to the current zone. Real zone changes, world
entry, transfer events, and exact Bulo ID changes wipe the observation epoch,
identities, and pending fragments. Entries with timestamps at or before the
new epoch are rejected. Captured carried-over units remain quarantined until
their old unit token disappears or changes; this can miss sightings, but
avoids attaching old observations to a new layer. Fresh reacquisition is
covered by tests. Full raw-ID changes are deliberately treated conservatively,
even when Bulo's server-only comparator would regard them as equivalent.

Only direct events capture approximate observer coordinates. Bulo copies
carry no coordinates: the player might have moved since their timestamp.
These coordinates are not enemy locations.

## War Effort: passive, separate, fail closed

The addon registers WEFF1 and ZRAD1 prefixes but never joins channels, sends
addon messages, or requests information. It does not inspect War Effort's
local namespace or hook its functions. Its independent decoder implements
the documented C/E/H wire grammar, bounds and class-code table. No War Effort
implementation code is bundled or loaded.

For current WEFF1 traffic, admission requires loaded WarEffortScout 0.2.13,
readable initialized settings and ignore policy, non-silent mode, and readable
client ignore status. Accepted contexts are GUILD when in a guild, or the
exact faction-specific WarEffortPubA/WarEffortPubH channel when already joined
and guildOnly=false. Unknown source versions/settings fail closed. Own echoes,
ignored senders, whispers, parties, raids and other channels are rejected.
Legacy ZRAD1 is registered and decoded by the pure parser, but live collection
is unavailable because legacy-network permission is local and unexposed.

Bulo uses an NPC GUID's server field on Forever. War Effort uses its fifth
field, zoneUID. They are never equated or converted. A separate event-driven
NPC confirmation maintains our zoneUID. The report matcher requires that
zoneUID and the report map's resolved zone to match. Even with a fresh report,
this would be labelled only `reported zoneUID match (unverified)` in the
separate report section, never confirmed same-layer membership.

### Why live reports are unavailable

War Effort sends seconds within an hour, not an absolute send timestamp. A
report stamped at second 100 this hour is indistinguishable from the same
previously unseen report stamped at second 100 last hour. Receiving it now,
receiving a hello, or matching its zoneUID cannot establish freshness.

The live adapter therefore rejects otherwise plausible reports with
`freshness unavailable: hour-relative timestamp`. It records only a bounded
status/last-heard indication for permitted, syntactically valid, clock-window
traffic; it retains no enemy/report payload. Last heard means traffic arrived,
not that its sighting was fresh. There is no option to bypass this gate.

The pure reducer is fully exercised with explicit independently trusted
absolute-send-time fixtures. Those fixtures are test inputs, not evidence
available in the live protocol. Complete reassembly, freshness checks, replay
tombstones, count checks, sender/global rates and memory ceilings are
implemented. Enabling remote listings would require trustworthy freshness
information the specified sources do not provide. This is an unresolved
source limitation, not a completed live-report feature.

Three-character enemy hashes are not reversible names and can collide.
The store retains only bounded possible-identity candidates from readable
names actually observed in the same epoch. A report row always remains
Unknown; matching candidates are labelled possible identity, never asserted
as the named player. Duplicate hashes within a report are rejected rather
than silently merged. Report coordinates describe a reported cluster.

## Storage and performance limits

LayerEnemiesDB is SavedVariablesPerCharacter, currently an empty options
container reserved for future approved configuration. No sightings, names,
GUIDs, hashes, report payloads or source settings are persisted. Window
position is intentionally absent until a window is approved.

Limits: 256 local observations/identity hash buckets, at most eight candidate
names per hash, 64 reports, 64 senders, 32 incomplete reports (four per sender),
512 total pending/replay slots, nine parts, 18 enemies per part, 255 bytes per
message. Rates are 128 total messages and 24 per sender per ten seconds after
privacy admission. Incomplete assemblies expire in 15 seconds; replay
identifiers are held for 3,660 seconds. Saturation fails closed rather than
evicting replay protection. A report ID reused during that interval is
conservatively rejected. Unchanged Bulo timestamps do not allocate duplicate
observation records.

## Verification

Run from the project root:

    /opt/data/tools/lua/lua-5.1.5/src/lua test/harness.lua
    /opt/data/tools/lua/lua-5.1.5/src/lua test/benchmark.lua

Compile-check each Lua file with the matching luac -p. The strict mock client
starts frames shown, errors on unknown methods, delivers CHAT_MSG_ADDON,
models secret values, and rejects outgoing network calls. The randomized
parser test uses 5,000 deterministic malformed inputs.

Exact results, before/after CPU/allocation measurements, and remaining
real-client checks are in notes/SUMMARY.md. Offline tests are not evidence of
live client compatibility, taint safety, layer semantics or event ordering.
Everything still needs in-game verification.

Footer used in slash output and intended for any approved UI:

Only players seen by you or reported by War Effort users.
