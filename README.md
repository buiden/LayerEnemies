# LayerEnemies

Headless WoW Forever addon, Interface 16001, Lua 5.1.

This build provides local observation adapters, conservative classification,
bounded stores, a passive network gate, a manual ask-for-invite helper and
slash-command text output. It has no window, minimap button, map pins, or
applied visual design. Two static previews of the planned window are in
notes/ and await approval. It is not a complete layer roster.

## Installation and commands

Place the LayerEnemies folder directly in Interface/AddOns, then reload the
client. No optional source is required for startup. An absent or unloaded
source is reported as not installed; a loaded source with an incompatible
shape is reported as data unavailable.

- `/le`: current layer/source, source statuses, and opposite-faction players
  directly observed in the current observation epoch. If War Effort reports
  exist, one line says how many; they are never mixed into this list.
- `/le unclassified`: local sightings whose faction is unknown or same-faction;
  these are explicitly not confirmed enemies.
- `/le reports`: the separate section "Reported, not confirmed" and the last
  rejection reason. See below for what a report does and does not prove.
- `/le hosts`: numbered list of friendly players known to be on another layer
  in your zone, with source and age.
- `/le ask <number>`: puts a whisper to that player into your chat box. You
  press Enter. The list from `/le hosts` is valid for two minutes.

Text rows show readable name or Unknown, class, level, zone ID, age, source
and confidence. No class colours or other visual treatment are applied.
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
identities, reports and pending fragments. Entries with timestamps at or
before the new epoch are rejected. Captured carried-over units remain
quarantined until their old unit token disappears or changes; this can miss
sightings, but avoids attaching old observations to a new layer. Fresh
reacquisition is covered by tests. Full raw-ID changes are deliberately
treated conservatively for the observation epoch.

Only direct events capture approximate observer coordinates. Bulo copies
carry no coordinates: the player might have moved since their timestamp.
These coordinates are not enemy locations.

## Layer keys

A layer is compared by one key: the server part of a creature GUID, the number
before the "-" in an ID such as 7086-7. Bulo Layer Forever and LayerSwap both
use that number. One helper produces and compares it for every source, so
7086-7 and 7086-55 are the same layer and 7086 and 7102 are not. Unreadable
or malformed IDs have no key and never compare equal.

War Effort's fifth field, zoneUID, is a different namespace. It is never
converted to a layer key.

## War Effort: passive, separate, reported not confirmed

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

### Reports are dated by when they reach you

War Effort sends a report when the sighting happens, so the time of receipt is
used as the time of the sighting. A complete report (cluster line plus all of
its enemy lines) for your current zone is listed under "Reported, not
confirmed" for ten minutes from receipt and then dropped. A zone change,
world entry or layer transfer drops all reports at once.

Each row shows Unknown, class, level, the reporter, the age since receipt and
how the reporter's zoneUID relates to yours: same, other (with the number), or
unknown while yours has not been confirmed. Reports for another zone, with
zoneUID 0, with a wrong enemy count, or with duplicate hashes are rejected.

What this does not prove:

- The wire stamp is only seconds within an hour. It must lie within 30 seconds
  behind, or 5 seconds ahead of, the server clock, but it cannot show which
  hour it was sent in. A report ID is remembered for 61 minutes and rejected
  if seen again in that time. After that, an old packet replayed at the same
  second of a later hour is accepted and shown as fresh. This is a known
  limit of the wire format, and the reason the section stays unconfirmed.
- The addon restarts with an empty replay memory. A packet replayed after a
  reload or relog, inside the 30 second stamp window, is accepted.
- Nothing checks that the reporter saw anything. A report is a claim by
  another player's client.
- A matching zoneUID is not proof of the same layer, and a different one is
  not proof of a different layer.

Reports never enter the "seen by you" list and never produce a map candidate.

The pure reducer also keeps its strict mode, used with explicit trusted
absolute send times in tests only: no evidence means rejection.

Three-character enemy hashes are not reversible names and can collide.
The store retains only bounded possible-identity candidates from readable
names actually observed in the same epoch. A report row always remains
Unknown; matching candidates are labelled possible identity, never asserted
as the named player. Report coordinates describe a reported cluster.

## Asking for an invite

Joining the group of a player on another layer moves you to that layer.
`/le hosts` lists friendly players you could ask, from three read-only
sources. Only players in your own zone are listed, because an invite from
another zone moves nobody.

- War Effort reporter: the sender of a live report in your zone whose zoneUID
  is not confirmed equal to yours. They saw the reported enemies, so they are
  where those enemies are. Their layer key is not known; they are listed by
  name, first. Fresh for ten minutes.
- Bulo guild list (`BuloLayerForever.Guild.list`): layer key, zone, host flag
  and time. Entries of 12 minutes or older are ignored.
- LayerSwap book (`LayerSwapDB.book`): layer ID, zone, host flag and time.
  The book keeps entries for days; only entries younger than 15 minutes are
  used, and entries marked gone are ignored.

Left out: yourself, anyone whose layer key equals yours, other zones, stale
entries, entries dated more than five seconds ahead of your clock, and names
that are secret, unreadable or not a plain character name. Bulo and LayerSwap entries need your own layer to be known;
until then nobody can be called "on another layer". Bulo entries whose zone is
a zone name instead of a map ID do not match and are skipped.

A player appears once. When two lists disagree, the newer entry decides the
layer. Order: War Effort reporters, then hosts, then newest. At most 512
entries per source are examined and 40 rows returned. The foreign tables are
read inside protected calls and never written; any unexpected shape discards
that source for that call.

`/le ask <number>` or `LE.AskInvite(name)` opens the chat box with

    /w <name> Hi! Could you invite me to your layer please? I'll leave right after.

and you press Enter. The addon never sends chat or addon messages, never
invites, never accepts an invite and never leaves a group. If the client has
neither ChatFrameUtil.OpenChat nor ChatFrame_OpenChat, or the call fails, the
line is printed for you to type. `LE.AskInvite` only accepts a name that is
on the current list.

Limits: one ask per name per 60 seconds and one ask per 10 seconds overall,
because players get silenced for invite spam. A refused ask does not count.
Asking is refused while you are already in a group.

After an ask, when you join a group within five minutes, the addon watches
your own layer key for 60 seconds:

- `Moved to layer X - safe to leave the group.` when your confirmed layer key
  changes. If X is not the layer the player was listed on, a second line says
  so.
- `Still on your layer - leave, wait a minute, try again.` when it is
  unchanged after 60 seconds.
- If your layer was not known before or cannot be confirmed afterwards, the
  addon says that instead of claiming a move. Without Bulo, a new layer is
  confirmed only after you target or mouse over two different NPC kinds.
- A zone change cancels the check.

## Storage and performance limits

LayerEnemiesDB is SavedVariablesPerCharacter, currently an empty options
container reserved for future approved configuration. No sightings, names,
GUIDs, hashes, report payloads, asked names or source settings are persisted.
Window position is intentionally absent until a window is approved.

Limits: 256 local observations/identity hash buckets, at most eight candidate
names per hash, 64 reports, 64 senders, 32 incomplete reports (four per sender),
512 total pending/replay slots, nine parts, 18 enemies per part, 255 bytes per
message. Rates are 128 total messages and 24 per sender per ten seconds after
privacy admission. Incomplete assemblies expire in 15 seconds; replay
identifiers are held for 3,660 seconds. Saturation fails closed rather than
evicting replay protection. A report ID reused during that interval is
conservatively rejected. Unchanged Bulo timestamps do not allocate duplicate
observation records. Friend lists are read only on `/le hosts`, `/le ask`
and `LE.AskInvite`, never on the heartbeat.

## Verification

Run from the project root:

    python3 test/verify.py

It compile-checks each Lua file with luac -p, checks the TOC, runs the strict
mock harness and builds the local package. The mock client starts frames
shown, errors on unknown methods, delivers CHAT_MSG_ADDON, models secret
values, and fails any test that reaches a send, invite, accept or leave call.
The randomized parser test uses 5,000 deterministic malformed inputs.

Exact results, CPU/allocation measurements, and remaining real-client checks
are in notes/SUMMARY.md. Offline tests are not evidence of live client
compatibility, taint safety, layer semantics or event ordering. Everything
still needs in-game verification.

Footer used in slash output and intended for any approved UI:

Only players seen by you or reported by War Effort users.
