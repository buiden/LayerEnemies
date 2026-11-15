# LayerEnemies

WoW Forever addon 0.3.0, Interface 16001, Lua 5.1.

Find a tracked enemy through your own sightings or possible War Effort hash
matches, then hop: ask a host on that layer for an invite. Approved design B is
implemented as a movable dark window with Seen by you, Reported, Friendly and
Find tabs. It starts hidden. No minimap button or map pins. This is not a
complete layer roster or a global player locator. 0.3.0 is no longer passive:
it sends two kinds of addon message, listed under "What is sent". It has had
one live trial (0.3.0, two guildmates in one zone on different layers): the
player without Bulo or LayerSwap could not see the host, because their own layer
stayed unknown and neither addon announces its hosts unprompted. 0.3.1 answers
that with hosts listed while your layer is unknown, a direct hop to a host and
remembered LayerSwap replies; none of that has been tried live yet (see the
last section).

## What is sent

Every addon message goes through one file (Wire.lua), on exactly two routes:

- LayerSwap prefix, WHISPER: one hop request to one host, only when you click
  a Hop button or run `/le hop <number>`. No retry, no fan-out.
- LEGW1 prefix, GUILD: enemies your own client saw (an O line: zone, your
  position, layer if known, up to four names; at most one per 15 seconds),
  and a relay of a report you heard first-hand in your party, raid or
  whispers, so guildmates running LayerEnemies see both. A relay waits a
  random 0.5-2.5 seconds and is not sent when a guildmate's copy arrives first.
  Guild membership, guild name and instance state are read when it is offered
  and again when it is due; not in a guild, another guild, in an instance, or
  unreadable means it is dropped. Each report id is sent about once per 120
  seconds: the 120 seconds count from when it is offered, before the random
  wait, and only while the id is remembered (256 ids; a flood of more ids can
  let one repeat). At
  most 128 offers wait at once. A local budget allows 5 quick sends, then one
  per 2 seconds.

Nothing is ever sent on WEFF1, HeadHunter or LFSw, and the addon never sends
chat, joins channels, invites, accepts invites or leaves a group. HeadHunter
and LEGW1 messages of an unknown version are ignored. A War Effort hello is
judged by its minor number, not its version text: a known minor (13 to 19)
gives a server key even when the version string is unusual, and an unknown
minor is accepted but its reports keep an unknown layer.

## Installation and commands

Place the LayerEnemies folder directly in Interface/AddOns, then reload the
client. No optional source is required for startup. An absent or unloaded
source is reported as not installed; a loaded source with an incompatible
shape is reported as data unavailable.

- `/le`: toggle the window.
- `/le list`: current layer/source, source statuses and directly observed
  opposite-faction players. Reports are counted separately, never mixed in.
- `/le find <name>`: add a tracked enemy (maximum five). Names may include a
  Forever surname or an explicit `-Realm`. `/le find` clears all tracked names.
  The Find tab also has a Track field and individual Clear buttons.
- `/le unclassified`: local sightings whose faction is unknown or same-faction;
  these are explicitly not confirmed enemies.
- `/le reports`: the separate section "Reported, not confirmed" and the status
  of the last report heard (why it was dropped, or "new"). See below for what a
  report does and does not prove.
- `/le hosts`: numbered list of friendly players in your zone who may be on
  another layer, with source and age (see "Hop" for who is listed).
- `/le ask <number>`: puts a whisper to that player into your chat box. You
  press Enter. The list from `/le hosts` is valid for two minutes.
- `/le hop <number>` and the Hop buttons on report rows send the hop request
  described below.

Text rows show readable name or Unknown, class, level, zone ID, age, source
and confidence. The window adds class colours and invite buttons. Use the
mouse wheel over its body to scroll longer lists. Only visible row frames are
allocated, then reused. Ages refresh at 1 Hz only while the window is shown;
there is no OnUpdate script. Drag the panel to save its position per character.
Sightings expire after ten minutes and are never saved.

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
7086-7 and 7086-55 have the same server key and 7086 and 7102 do not. An equal
server key is the best evidence available, not proof of the same layer.
Unreadable or malformed IDs have no key and never compare equal.

Your own key comes only from a confirmed reading (Bulo's full ID or two
agreeing NPC kinds). When NPC readings show a new full ID with the same server
key, two layers of this zone share it, and your key is ambiguous for 30
minutes (a Bulo ID change does not start this window). While it is
ambiguous, a report on an equal key shows the relation as unknown (a
different key still reads "other"), and Find, `/le hosts` and the layer
check say "probably" where they would otherwise say "on your layer".

The number after the "-" (the zoneUID) is private to each player and is never
compared across sources. War Effort 1.6.x sends its own layer field;
it is treated as a server key only when the reporter's hello announced a
version that uses one (minor 13 to 19) and the value is not 0. Otherwise the
report's layer is unknown.

## War Effort: read-only, reported not confirmed

The addon reads War Effort 1.6.x traffic on WEFF1 and never sends on it. It
does not inspect War Effort's local namespace or hook its functions, and the
0.2.13 requirement is gone: no War Effort install is needed. Its independent
decoder implements the C (cluster), E (enemy list) and H (hello) lines, plus
one level of G (guild) and X (party/raid) wrapping; any other type letter is
ignored. No War Effort code is bundled or loaded. The legacy ZRAD1 prefix is
no longer registered.

Accepted routes: GUILD carries C, E, H and G; PARTY and RAID carry C, E, H and
X. Whispers, channels and other routes are ignored. Messages are 1 to 255
bytes from a fixed character set. Own echoes (your name, with or without your
realm), ignored senders, and a wrapper naming its own sender as the origin
are dropped. Reporters are compared by full name and realm.

### How long reports are listed

A War Effort report is listed under "Reported, not confirmed" for ten minutes
from receipt; a HeadHunter report for five minutes. A guild-relayed copy is
dated from its origin (receipt minus the age it carries) and lives as long as
a direct one. A real zone change drops reports from the old zone. Each row
shows the reporter ("via <name>" when someone else carried the message) and
the age; `/le reports` also shows how the reported layer relates to yours:
same, other, or unknown.

Reports can be partial. A cluster line whose enemy list has not arrived (or
never will) still shows, with a row such as "3 not listed". An enemy list is
held for 15 seconds waiting for its cluster line; one heard before a zone
change never attaches to a cluster line after it.

HeadHunter (party, raid and whisper traffic only) adds fight and wanted rows,
direct or inside a checked forwarding envelope. They never carry a usable
layer, so they can never be hopped to. The inner record's own time must be
within 300 seconds of the server clock; an envelope's first-sent time is
checked for form only.

What this does not prove:

- Nothing checks that the reporter saw anything. A report is a claim by
  another player's client.
- A War Effort report id must be newer than the last one from the same origin
  (kept for an hour); a reload starts with no memory, so a replay after a
  reload can be accepted. HeadHunter and guild-relayed reports only drop an
  identical id; an older id is accepted.
- An equal layer field is not proof of the same layer (see Layer keys).

Reports never enter the "seen by you" list and never produce a map candidate.

War Effort's three-character enemy hashes are not reversible names and can
collide. The store retains only bounded possible-identity candidates from
readable names actually observed in the same epoch. A War Effort row remains
Unknown; matching candidates are labelled possible identity, never asserted
as the named player. A HeadHunter row carries the name the reporter claimed
(shown by `/le reports`; the window title still says Unknown and the class).
War Effort coordinates describe a reported cluster, HeadHunter coordinates
the reporter's position.

## Finding a tracked player

A target can only be located when you see him yourself, or a report naming or
hashing him reaches you (War Effort, HeadHunter or a guild relay; one enemy
entry is enough, the rest of the list need not arrive). There is no
server lookup, discovery broadcast, request to another addon, or background
scan of the world. Enter the name before a report arrives; current-zone
reports already retained can also be matched when adding a name.

A readable opposite-faction target/mouseover/nameplate event with a matching
name says `is on YOUR layer`, with zone and age. A Bulo-only GUID enrichment
is not enough to generate this exact-name finding. War Effort sends only a
three-character enemy hash, so a match says `possible match, seen by <spotter>`
and includes class, level, zone and age. Different players can share the same
hash. It is probable, never certain; ask the spotter to confirm the identity.

The key is the source's exact lower-case name, a hyphen, then lower-case realm
with spaces/hyphens removed. Both home/explicit-realm and empty-realm forms
are checked. On Forever, the inspected detector passes UnitName's second
return into its realm argument even when that return is a surname. A tracked
`First Surname` therefore also checks the `first-surname` wire key. Display
name and hashing conventions were verified from source, not from a live
client. The original code's realm terminology is not proof of a real realm.

Find offers `Ask <spotter> for invite` through the same manual helper. If a
fresh Bulo/LayerSwap claim puts that spotter on your current server key, it
says `already on your layer` and hides the ask; while your key is ambiguous it
says "probably" and the ask stays. Your own sightings do the same. Other-zone
findings instead say `travel to <zone> first` and cannot be asked from Find.
A finding that came only from a guild relay says `possible match, seen in a
relayed report`, without a name to ask and without an ask button.

A first finding prints a chat alert and attempts a raid-warning sound. It
re-alerts only after five minutes or when a new zone is reported. Sound API
failure is harmless. Findings expire after ten minutes; a direct sighting
has priority over a possible report until it expires. Only the newest
possible spotter is retained for each name; this is not a spotter history.
World/zone/layer boundaries wipe findings and pending report fragments,
not tracked names. Re-entering a zone needs fresh observations. Alerts and
locations are never persisted, so a reload starts a new alert session.

## Hop: asking for an invite

Joining the group of a player on another layer is expected to move you to
that layer; this has not been tested on a live client (see the last
section). A report row with a known server key that is not yours gets a Hop
button. The label says what a click will do; when the button is disabled, its
tooltip gives the reason (you are grouped or that is unreadable, your map
zone is unreadable or not the report's zone, its layer is unknown or yours
already, or nobody on it is known). `/le reports` numbers the same rows for
`/le hop <number>`; the numbers end after two minutes or at a zone change.

Who is asked, in order: a Bulo host on that layer, a LayerSwap host, another
Bulo user, then the report's War Effort origin (also the origin named inside a
War Effort G or X wrapper). When a player is in both Bulo's list and the
LayerSwap book, each source ranks by its own host flag (a Bulo non-host who is
a LayerSwap host ranks as a LayerSwap host); `/le hosts` marks the player as
host if either source does. Bulo and LayerSwap users get one LayerSwap-format
request by addon whisper:

    inv layer <LS <zone> want <server>-<uid> <x>,<y>>

`<uid>` is the host's own zoneUID when the player's freshest entry is a
LayerSwap book entry, 0 otherwise (a fresher Bulo entry, which has none, wins
the merge); the
position is your map position in percent and is left out when unknown. That
is one whisper per click, with no retry. A click acts only on the player and
mode the row showed: if the pick has changed by then, nothing is sent ("hosts
changed, check again") and the row is redrawn. Whether the host's addon
answers with an invite has not been tested yet. A reply is read for 120
seconds, on WHISPER, from the asked player only (whole name; another realm is
another player). A War Effort origin has no host addon known to answer, so the
button opens a whisper for you to send:

    /w <name> Hi! Could you invite me to your layer please?

Origins of guild-relayed (LEGW1) copies are never asked, neither here nor from
Find: they were in someone else's group and may be strangers.

`/le hosts` lists friendly players you could ask: War Effort origins in your
zone whose layer is not known to be yours, Bulo's guild list
(`BuloLayerForever.Guild.list`, or the LFSw guild lines when Bulo is not
installed; never sent by this addon), and the LayerSwap book
(`LayerSwapDB.book`, entries younger than 15 minutes). Left out: yourself,
anyone on your server key (while it is ambiguous they stay, marked probably),
other zones, stale entries, entries dated more than five seconds ahead and
unreadable names. Bulo and LayerSwap entries need your own layer to be known.
`/le ask <number>` and `LE.AskInvite(name)` open the whisper above for you to
send. The foreign tables are read inside protected calls and never written.

Limits: one ask per name per 60 seconds and one per 10 seconds overall,
because players get silenced for invite spam; a request that failed to send
still counts. Asking is refused while you are in a group or the group state is
unreadable.

After an ask, when you join a group within five minutes, the addon watches
your own layer key for 60 seconds and says `Moved to layer X` when it changes.
Whether leaving the group keeps you on the new layer is not confirmed, so it
tells you to stay grouped if unsure. If nothing changes it says `Still on your
layer - leave, wait a minute, try again.` (`Probably still on your layer`
while your key is ambiguous). If your layer cannot be confirmed it keeps
checking for up to 180 seconds, then says so. A zone change cancels the check.

## Storage and performance limits

LayerEnemiesDB is SavedVariablesPerCharacter. It stores options, up to five
explicitly entered tracked names, and window position. It never persists
sightings, discovered identities, GUIDs, hashes, locations, report payloads,
asked names, alert history or source settings. Reloading keeps your watchlist,
not its locations. Epoch boundaries also clear locations. Your own server key and its
30-minute "ambiguous" window are not saved either: after /reload the window is
gone, and a new one starts only at the next qualifying layer change.

Limits: 256 local observations/identity hash buckets, at most eight candidate
names per hash, 64 reports per source (War Effort, HeadHunter, guild relays;
one report can show as several rows), 256 remembered relay ids, 255 bytes per
message. Held enemy lists: 200 entries per origin and
256 in total, for 15 seconds. Report-id order is remembered for 512 origins
for an hour. Receive rates per sender per ten seconds: 6 War Effort messages
(20 for G/X wrappers), 6 HeadHunter P/L/E frames (other HeadHunter types are
ignored without counting), 12 LEGW1; excess is dropped silently, and
each rate table holds at most 512 senders. Unchanged Bulo timestamps do not allocate duplicate
observation records. Friend lists are read for hosts/asks, tracked-target
status/alerts, and shown-window refreshes. The UI reuses at most six row
frames; its hidden timer stops after any already-queued callback returns.

## Verification

Run from the project root:

    python3 test/verify.py

It compile-checks each Lua file with luac -p, checks the TOC, runs the strict
mock harness with the Lua 5.1 binary (`LAYERENEMIES_LUA` overrides its path;
whatever binary is given is trusted to run the harness, and at least one test
must pass) and builds the local package. The mock client starts frames
shown, errors on unknown methods, delivers CHAT_MSG_ADDON, models secret
values, and fails any test that reaches an invite, accept, leave, join or chat
call, or an addon message sent from anywhere but Wire.lua or on any route but
LayerSwap/WHISPER and LEGW1/GUILD.
The randomized parser test uses 5,000 deterministic malformed inputs.

Current results are in notes/test-results.txt and notes/verification.json,
both written by verify.py. notes/SUMMARY.md is the 0.2.0 summary, including
its CPU/allocation measurements; its counts are historical. Offline tests are not evidence of live client
compatibility, taint safety, layer semantics or event ordering. Everything
still needs in-game verification.

## Not tested on a live client

Apart from the one 0.3.0 trial described at the top (host discovery failed for
a player without Bulo or LayerSwap), everything above is checked against a
mock client only. Still open:

1. Does `inv layer <LS zone want S-0 x,y>` by addon whisper produce an invite
   from a LayerSwap 1.14.20 host and from a Bulo 3.0.25 host? Also with the
   full `S-U`. The hop depends on this.
2. After accepting, does your server key change, and does leaving the group
   keep the new layer?
3. Does `C_ChatInfo.SendAddonMessage` to WHISPER work from a button click with
   a "Given Family" target name, and what does an offline target return?
4. Does LEGW1 on GUILD deliver between two guildmates, and does HeadHunter
   whisper traffic reach a second addon registered on the same prefix?
5. The same-zone swap test (Bulo id before and after a transfer).

Footer used in slash output and the window:

Only players seen by you or reported by other players' addons.
