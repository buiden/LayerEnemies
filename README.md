# LayerEnemies

WoW Forever addon 1.0.1, Interface 16001, Lua 5.1.

Find a tracked enemy through your own sightings or possible War Effort hash
matches, then hop: ask a host on that layer for an invite. Find can also show
a tracked player's last self-shared OpenMap position, separately from sightings. Approved design B is
implemented as a movable dark window with Seen by you, Reported, Friendly and
Find tabs. It starts hidden. No minimap button or automatic map pins. This is not a
complete layer roster or a global player locator. Since 0.3.0 it is not
passive: it sends the addon messages listed under "What is sent", and from
0.4.0 it can host for your guild (off unless you turn it on, see "Hosting for
your guild"). It has had one live trial (0.3.0, two guildmates in one zone on
different layers): the player without Bulo or LayerSwap could not see the
host, because their own layer stayed unknown and neither addon announces its
hosts unprompted. 0.3.1 and 0.4.0 answer that (hosts listed while your layer is
unknown, a direct hop to a host, Find hosts, a guild-chat request, guild
hosting); none of that has been tried live yet (see the last section).

1.0.0 joins the War Effort and HeadHunter networks as a member (public
networks are ON by default; `/le net guild` limits everything to your guild
and group), shares your own sightings with your guild (`/le share off` stops
it), and reads the Spy family and three guild incident addons. At the first
login it prints once:

    LayerEnemies: public networks ON (War Effort, HeadHunter…). /le net guild to limit to guild only.

Every network has its own switch (`/le net`, and the switches at the bottom
of the window). Nothing of 1.0.0 has been tried on a live client yet; the
checklist is at the end.

## Next release: Hop to another layer

**Changed rule:** "one hop request to one host ... No retry, no fan-out"
previously applied to every hop. One **Hop to another layer** click may now
send up to **8 requests to players not known to run any layer addon**.
There is still no retry, timer-started search, automatic second round or
request without a click. Existing Hop, Hop via <name> and Ask guild actions
keep their single-target / player-sent behavior. This bounded exception is
reviewed on its own, independently of other feature changes.

## Unreleased - guild death calls (receive-only)

**Call popups and their sound are ON by default for both new and existing
users.** Turn them off with `/le call off` or the window's **Call: on/off**
button; `/le call on` turns them back on. The per-character choice survives
reload. This is independent of Share and the network switches.

A Guild Bounty death with a killer class, or a Wall of Shame death whose
killer is an opposite-faction player in your current local seen store, can
show a call under the minimap. A class-less Guild Bounty death needs that
same local proof. Unknown/creature killers, Forever Told sightings, your own
death and HeadHunter D frames never trigger it. This feature sends nothing:
it does not detect your own death, announce a death, reply, invite or relay.
Two LayerEnemies-only guildmates cannot generate these incident lines yet.

One popup at a time: at most one per victim per 180 seconds and one overall
per 20 seconds, accepting events no older than 120 seconds. The incident
protocols have no timestamp, so their age starts at receipt. Copies for the
same victim within 60 seconds are one event; a matching killer/zone copy
with coordinates improves the shown event without another sound or extending
its lifetime. The latest admitted event replaces the old one. Each closes
after 30 seconds, with x, Escape, or **Not now** closing it earlier. No zone
mute. Popups are plain frames, allowed in combat but never in instances
(or when instance status is unreadable).

**On my way** tries a waypoint and super-tracking for the displayed victim's
zone/coordinates; if unavailable or refused, it prints one location line.
It also offers the displayed full killer name to Find if a slot is available
(maximum 20), including realm-qualified full killers (`First Last-Realm` or
`First Last-1234`). Realm spaces and hyphens are removed; the base and casing
are kept as typed. A full list stays unchanged with an explanation; partial
names are not added. It does not send a message or ask for an invite.

Three Arabic headings, three fixed detail labels and three button labels
ship as pre-rendered images. Each detail row puts its label image on the
right, with the ink aligned to the image's right padding. The client-text
value is right-justified three pixels left of the colon, using each label's
scaled ink-left metadata rather than the canvas edge. Killer level/class
stay with the value. One English body sentence
appears under the rows. Help uses the abshir image; dismiss defaults to
i3dhirooni, with sakkir also included. In CallText.lua, changing DISMISS from
"dismiss_a" to "dismiss_b" switches only the button image and its fallback.
Latin heading transliteration is always shown under the heading image.
`/le call art off` hides all call images, enlarges the Latin heading and
uses English labels (One of ours:, Killer:, Where:) left-to-right, with
On my way / Not now buttons (Close for sakkir). A nil art field in CallText.lua
uses the same fallback without requesting a texture. `/le call art on`
restores images; the switch is saved across reload. No Arabic text,
font or shaping library runs in the client. Unsupported dynamic characters
above U+024F are shown as `?` on this popup. B4's "last seen" line is eligible
only through age 30 seconds. Art source and OFL font details: THIRD_PARTY.md.

Not tested on a live Forever client: these exact TGAs' alpha/orientation,
readability at client scale and placement clear of other minimap frames;
waypoint/super-track permission; actual Wall of Shame creature-death traffic;
combat/taint behavior. Death-recap timing, fields and player/duel/pet flags
remain outside this receive-only change.

## 1.0.1 — own identity, guild sightings and whisper lifecycle

- Guild O sightings preserve the full observed name when Forever returns first
  name and surname separately. Find matches that full identity, not a first-name
  alias. An invalid full display name is omitted, not replaced with its first
  name. The O1 format stays compatible with 1.0.0 receivers; the observing
  sender needs the update. Up to four names still fit within 255 bytes, with
  whole trailing entries removed when necessary, never shortened identities.
  Find remains a passive watch, not a request for a remote scan. One enemy can
  use this LE-to-LE guild path; the War Effort path still requires at least two.
- Own echoes now use one full-name resolver when Forever returns first name
  and surname separately, or an already-combined name. Your home-realm suffix
  is folded; a different surname or foreign realm is still a different player.
  Unreadable or ambiguous own identity fails closed at receive/list boundaries.
  The same identity is used for host candidates, replies addressed to you and
  directory self-exclusion; your own raid unit is not an outside-guild peer.
- Includes the merged invalid-whisper lifecycle fix: recent localized
  player-not-found feedback shares the existing one-hour offline suppression;
  ambiguous identities are not guessed, chat errors stay visible, terminal
  hello failures stop retrying, and stale directory candidates expire. See the
  existing budget and directory sections below for exact limits.
- No new send routes or network defaults. Local sightings remain separate from
  other players' reports. Matching class, level or a short enemy hash never
  proves identity: independent hash-only reports still say Unknown, including
  collisions.

Reload after updating to clear old session-only reports. The fixes have offline
regression coverage; their live-client identity and message behavior still need
validation (items 25–27 below). War Effort's compatibility hello version
stays fixed at 1.0.0; it is not the addon's release version.

## What is sent

Every addon message and the one party invite go through one file (Wire.lua).
Five prefixes are allowed. Two scopes matter for your settings: guild scope
(guild, party and raid lines, and whispers to guildmates online in your roster)
and public scope (whispers to anyone else, and the two public channels joined
for reading). `/le net guild` turns every public send and both channel joins
off; guild scope keeps working. Guild only stops all automatic public sends; a
Hop you click still whispers that one host. **Hop to another layer is refused
in guild-only mode**, including a round already in progress.

- A zone `/who` search: only from the **Hop to another layer** button or
  `/le hop any`, one `C_FriendList.SendWho` in the click's own call stack,
  using the localized `WHO_TAG_ZONE` and your live zone name. It waits up to
  5 seconds for results. No class/race rotation, UI unhooking or who-window
  hiding. Missing APIs or localization refuse the action; no English fallback.
- LayerSwap prefix, WHISPER: the existing Hop button, `/le hop <number>`
  and `/le hop host <number>` still send one request to one host, with no
  retry or fan-out. **Hop to another layer** instead sends at most 8 requests
  from that click's zone-who results, no faster than one per second, through
  the same Wire budgets and without a queue. Its exact line is
  `inv layer <LS <zone> not <ownServer>-0 <x>,<y>>` (position in percent).
  While you host for your guild, also the answer to a guildmate's
  request: `same` or `heard <name>|<layer>|<zone>|<h or ->`, at most one per 6
  seconds. Wire refuses any other text on this route.
- LFSw prefix, GUILD: Bulo's one-letter question `Q`, only from the Find hosts
  button or `/le hosts find`, at most once per 60 seconds. Bulo users in the
  guild answer with their own layer line. Our own Bulo `L` line is never sent,
  and an incoming `Q` is never answered.
- LEGW1 prefix, GUILD: enemies your own client saw (an O line: zone, your
  position, layer if known, up to four names). An O goes 3 seconds after the
  first sighting of an enemy not shared in the last 60 seconds, at most one
  per 15 seconds, and lists everyone your own client saw in the last 15
  seconds, so a name can repeat in the next O 15 seconds later. `/le share off`
  stops all guild sends, including the relays below. Also a relay of a report you heard
  first-hand in your party, raid or whispers, so guildmates running
  LayerEnemies see both. A relay waits a
  random 0.5-2.5 seconds and is not sent when a guildmate's copy arrives first.
  Guild membership, guild name and instance state are read when it is offered
  and again when it is due; not in a guild, another guild, in an instance, or
  unreadable means it is dropped. Each report id is sent about once per 120
  seconds: the 120 seconds count from when it is offered, before the random
  wait, and only while the id is remembered (256 ids; a flood of more ids can
  let one repeat). At
  most 128 offers wait at once. A local budget allows 5 quick sends, then one
  per 2 seconds. From 0.4.0 the same route carries two short lines older
  versions ignore: `F|1` ("which LayerEnemies hosts are on?", from the Find
  hosts click, at most once per 60 seconds) and `H|1|<server key>|<zone>` (a
  host's answer: once when you turn hosting on and once in answer to an `F`,
  1 to 6 seconds later, at most once per 60 seconds, only while hosting).
- WEFF1 prefix (War Effort network; its switch, `/le net wareffort on|off`;
  never while War Effort itself is loaded, never in an instance):
  - GUILD: our hello `H|1.0.0|<map>|<layer>|1|19|0|0|<stamp>||<class>|<level>|<public>`
    (followed by `|0|1` while your layer key is ambiguous) 10 seconds after login, then every 180-190 seconds (an identical one not
    within 30 seconds; a guildmate's `Q` gets one at most every 10 seconds).
    It tells guildmates your map, layer, class and level, never your name
    or position. One `Q` about 15 seconds after login (at most two
    attempts). Your own sighting as War Effort's `C` and `E` lines, only for
    two or more enemies seen together and only while a War Effort user's
    hello was heard on the guild in the last 600 seconds (`/le share off`
    stops it). Embassy lines (below): `D` (the foreign guilds we link to)
    and `G` (a partner's line passed into your guild: at most 10 reports a
    minute, each a `C` with the `E` lines that belong to it, and at most 6
    hellos a minute, one per origin per 600 seconds).
  - PARTY and RAID: the same hello when the group has players outside your
    guild (at most once per 175 seconds), and the same `C` and `E` rule.
  - WHISPER, guild scope: to a guildmate's sync request `Y`, our own last
    three reports (`C` marked as a sync answer, then `E`), only those sent
    to War Effort, within the age asked, one line per 5 seconds, each
    requester once per 600 seconds, at most five waiting; to a `J` (a layer
    request), `K` saying "off", once per 60 seconds per player. `/le share
    off` drops waiting sync answers and the reports kept for them.
  - WHISPER, public scope: the same `K` to a `J` from a player outside your
    guild, while public networks are on.
  - WHISPER, public scope (embassy, see "War Effort network"): `P` presence
    to players of other guilds in the War Effort channel (one new one a
    minute, answers at most 6 a minute, keepalive every 300 seconds), and
    `W` forwards to the partner chosen for them (0.2 a second, burst 6): our
    guild's reports (C and its first E) and hellos (each guildmate's, and
    ours, at most once per 600 seconds). A W names its origin, so a partner
    sees the reporter's name with the report or hello. With `/le share off`
    our own W lines, also ones still queued, are not sent.
- HeadHunter prefix, WHISPER only (HeadHunter network; its switch,
  `/le net headhunter on|off`; public scope; never while HeadHunter itself is
  loaded, never in an instance): our hello `1<A|H>N:LayerEnemies` once per
  peer per session (hellos and replies one every 2 seconds at most), forwards of HeadHunter's
  envelopes with only the hop count raised (to 3 known peers and 1 unknown,
  never the author or the carrier, at most 6 a minute per peer, never past
  hop 5, a queued forward dropped once the envelope is over 600 seconds old),
  catch-up `Q:h` after 20 seconds to up to 5 known peers plus 1 unknown one,
  and one `Q:p` to the
  biggest offer, `O` and `S` answers to other members' catch-up (each
  requester once per 300 seconds; no `O` while we hold nothing; `O` states the
  number a pull then gets; `S` only to a
  known peer of our faction heard within 3600 seconds, the newest 10 records
  that fit plus the end
  marker, one frame about every 2 seconds), and `H` with
  our home server once per 600 seconds per asker. We never author `P`, `L`
  or `D`: HeadHunter has no honest line for a sighting of ours.

Budgets, all in Wire.lua and spent before the client is asked: each prefix 5
at once then one per 2 seconds; all sends 8 at once, then one per 1.5 seconds
and never more than 40 a minute; GUILD 20 a minute; public whispers 20 a minute
in total and 4 a minute to one player (a catch-up answer instead has its own 16
frames per requester, still inside the 20). In combat every send costs double and
every minute cap is halved. A client throttle pauses that prefix 30 seconds;
an offline player is skipped for an hour. A queue of 40 lines waits for budget
(clicks first, then our own lines, answers owed, embassy and guild relay lines,
catch-up answers, and other HeadHunter lines last); full, the oldest line of
the lowest rank goes first, and when every queued line ranks above or equal to
the new one, the new line is refused. A catch-up answer (10 records and the end
marker, one frame about every 2 seconds) ranks above mesh forwards so it ends
inside HeadHunter's 60-second give-up. Hellos are never queued. Only local
budget or pause refusals retry, with exponential backoff up to 30 seconds,
at most 8 attempts and a 120-second deadline from the first attempt. A client
refusal, invalid target or offline result ends that hello; new peers get a
turn ahead of retries. Successful hellos remain at least 2 seconds apart. Embassy
and HeadHunter lines leave a reserve (2 sends of the shared
bucket, 10 of the 40 a minute, 5 of the guild's 20; halved in combat), so our
own lines still go under a busy mesh.

A localized player-not-found system error marks a destination offline only
when it matches an actual addon whisper from the last 30 seconds (at most
64 attempts retained). Correlation uses the full name, including surnames
and foreign realms; a bare error is ignored if recent realm identities are
ambiguous, and is never guessed to mean a foreign realm. A matched failure
consumes its suppression evidence, but the retained identity still counts for
ambiguity until its original expiry or eviction; repeated errors do not renew
suppression. The same one-hour window as a synchronous offline result applies
across prefixes and to queued lines (at most 256 offline identities). No chat
errors are hidden or saved.
Only the existing name rule's local-realm suffix is removed at send time.

Channels (Directory.lua): with public networks on, the addon joins the
HeadHunter channel `HeadHunterSync` and War Effort's channel for your realm and
faction, only to read who is in them (the peers and embassy candidates). It
never sends to a channel. A channel you already had is read and never joined or
left by the addon; one the addon joined (confirmed by the client's own join
notice) is left when public networks or that network are switched off. No
join in an instance or combat, or before the client's channel list is filled;
a channel you leave by hand is not joined again that session. A successful
empty roster clears directory-only HeadHunter candidates; a failed scan is
not an empty roster. Directory snapshots and their candidates expire after
600 seconds without a successful refresh. Directly heard peers instead expire
after 3600 seconds without activity. Queued directory-selected queries and
forwards recheck candidate freshness. Fresh validated roster/incoming names
can update outgoing spelling; different identities sharing HeadHunter's
compact comparison key never inherit each other's peer state.

Party calls, all in Wire.lua:

- `C_PartyInfo.InviteUnit`: while you host for your guild, a guildmate's
  request can get one invite (see "Hosting for your guild"). At most one per
  10 seconds, 6 per 10 minutes and one per name per minute.
- `AcceptGroup` and `C_PartyInfo.LeaveParty`: with "Auto accept and leave"
  on, the invite of the host your own hop asked is accepted, and that group
  is left after the move (see "Auto accept and leave"). At most one of each
  per 10 seconds.

Received only, never sent: `[Spy]`, `ForeverSpy1`, `FSENT03`, `GBOUNTY`,
`WALLOFSHAME`, `FTold1` and `OpenMapLoc`. The OpenMap listener sends no hello,
reply or position on any route, including Battle.net. Nothing on LFSw but `Q`, and the addon never sends
chat, sends to a channel, joins any channel but the two above, declines
invites, accepts any other invite, leaves any other group, or removes or
converts group members. HeadHunter and LEGW1 messages of an unknown version are
ignored. A War Effort hello is
judged by its minor number, not its version text: a known minor (13 to 19)
gives a server key even when the version string is unusual, and an unknown
minor is accepted but its reports keep an unknown layer.

## Installation and commands

Place the LayerEnemies folder directly in Interface/AddOns, then reload the
client. No optional source is required for startup. An absent or unloaded
source is reported as not installed; a loaded source with an incompatible
shape is reported as data unavailable.

- `/le`: toggle the window.
- `/le list`: current layer/source, source statuses, the War Effort embassy
  state (or why it is off), the network level, each network, whether your
  sightings are shared, and directly observed opposite-faction players, even
  while your layer is unknown. Rows seen without a layer say "layer unknown
  when seen", including after you learn your layer. Up to eight recent own
  sightings from the zone just left follow the live rows, labelled with the
  old zone and "previous zone". Reports are counted separately, never mixed in.
- `/le net`: the network level (public or guild only) and each network, with
  the reason when one is off (switched off, the real addon loaded, guild
  only, not in this version). `/le net guild` and `/le net public` set the
  level; `/le net wareffort on|off` (or `we`) and `/le net headhunter on|off`
  (or `hh`) set each network. All saved.
- `/le share on|off`: share sightings and enable guild sends (on by default,
  saved). Off stops all guild sends, including your O lines, every Spy,
  HeadHunter and War Effort relay, host questions/answers and network guild
  traffic. Pending relays and queued guild embassy lines are dropped, not
  replayed when re-enabled. Your War Effort reports, waiting sync answers
  and queued own embassy lines also stop; you still receive everyone else's.
- Window switches, on every tab: Share, Call, Guild only, War Effort and
  HeadHunter (the same settings as the commands).
- `/le call on|off`: guild death popups and sound (default on).
  `/le call art on|off`: all Arabic call images (default on); heading Latin stays visible.
- `/le find <name>`: add a tracked enemy (maximum 20). Accepts `Name`,
  `Name-Realm`, `First Last` and `First Last-Realm`, including numeric realms
  such as `Name-1234`. `/le find` clears all tracked names.
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
- `/le hop host <number>` and the "Hop via <name>" button on a Friendly row ask
  that host directly (one hop request per click, see "Hop"). The list from
  `/le hosts` is valid for two minutes.
- `/le hop <number>` and the Hop buttons on report rows send the hop request
  described below.
- `/le hosts find` and the "Find hosts" button on the Friendly tab ask the
  guild once (Bulo's `Q` and LayerEnemies' `F|1`), at most once per 60
  seconds. Hosts that answer appear in `/le hosts` and on the Friendly tab.
- `/le hop any`: one bounded zone search for another layer (Friendly tab).
  `/le hop stop` or its Stop button cancels the round; a sent request cannot
  be recalled. Refused in guild-only mode.
- `/le hop auto on`, `/le hop auto off` and the "Auto" toggle on the Friendly
  tab: Auto accept and leave (on by default, saved; see below).
- `/le host on`, `/le host off`, `/le host` and the Host toggle on the Friendly
  tab: hosting for your guild (see below). The setting is saved and stays on
  after login and reload until you turn it off.

Text rows show readable name or Unknown, class, level, zone ID, age, source
and confidence. The window adds class colours and invite buttons. Use the
mouse wheel over its body to scroll longer lists. Only visible row frames are
allocated, then reused. Ages refresh at 1 Hz only while the window is shown;
there is no OnUpdate script. Drag the panel to save its position per character.
The zone view expires local sightings after ten minutes. Named Find evidence
is kept for one hour in session memory; neither is saved.

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
needed. A readable zone is required; knowing your layer is not.

"Seen by you" includes opposite-faction players seen while your layer was
unknown, labelled "layer unknown". Learning your layer keeps those rows,
without assigning them the new layer. A fresh sighting replaces the old row
with the then-known layer; a Bulo copy can also replace it, but only when the
copy's observation time is later than when you learned the layer. An older or
same-time copy leaves the row unknown. Bulo refreshes keep the earlier own-sighting
time and do not upgrade Find's earlier "seen by you, layer unknown" location.
Without a replacement, the row expires ten minutes after the original sighting.
Such unknown-layer rows are not map candidates. Reports and possible identity
matches are still cleared when your layer is learned. Sharing uses the existing
unknown-layer value whenever any enemy in a report was seen without a layer:
an empty field in the guild O line, or 0 in War Effort's C line. The message
formats and send routes are unchanged.

On a real, readable zone change, "Seen by you" also keeps the newest eight
opposite-faction players your own client saw in the zone just left, for two
minutes from each sighting (not from the crossing). They follow live rows,
labelled with the old zone and "previous zone", and count in the tab title.
A fresh sighting of the same player hides the carried row. A second crossing
replaces this history with only sightings from the zone just left. Bulo-only
copies and unreadable or same-faction sightings are not carried. These plain
name/class/level/zone/time copies have no layer or position, are never shared,
and never feed map candidates, hop or ask. Find now independently retains
the original named sighting in its session cache; these display-only copies
are not replayed into it. World entry, shard transfer,
a real layer change, an NPC zoneUID change or an unreadable zone clears them.
Learning your layer in the new zone keeps them until their original expiry.
They are not saved.

Active identifiers are scoped to the current zone. Real zone changes, world
entry, transfer events, and exact Bulo ID changes wipe the observation epoch,
identities, reports and pending fragments; only real zone crossings keep the
separate display-only previous-zone copies above. Entries with timestamps at or
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

## War Effort network

The addon reads War Effort 1.6.x traffic on WEFF1 and, from 1.0.0, takes part
as a member (what it sends is listed under "What is sent"). It does not inspect
War Effort's local namespace or hook its functions; no War Effort install is
needed. Its independent decoder implements the C (cluster), E (enemy list), H
(hello), Q, Y, J, P, D and W lines, plus one level of G (guild) and X
(party/raid) wrapping; any other type letter is ignored. No War Effort code is
bundled or loaded. With War Effort itself loaded, the addon sends nothing on
WEFF1 and runs no embassy (two senders on one character would collide); it
still reads.

Accepted routes: GUILD carries C, E, H, G, Q, Y and D; PARTY and RAID carry C,
E, H and X; WHISPER carries J, P and W. Channels and other routes are ignored.

Embassy (War Effort's link between guilds): with public networks on, in a
guild whose id the client gives (`C_Club.GetGuildClubId`), on a realm with a
War Effort channel name, the addon greets its share of the War Effort channel's
players from other guilds (a share elected among guildmates heard on the
guild), keeps those who answer as partners, and lists the partner guilds in
one `D` line. For each report, one guildmate is elected (War Effort's own
score) to forward it as `W` to one partner; a guildmate's report goes out only
if that guildmate's own hello said public. A partner's `W` comes into the guild
as `G` once and is shown as a relayed report; it is never passed on to another
partner. A presence counts only from a player in the War Effort channel, one we
greeted in the last 10 minutes, or a partner we already have; anyone else gets
no answer and no W of theirs is taken. Wrapped lines (W out, G in) are rebuilt
from the fields we read, so nothing else a sender added travels on. A
guildmate's "public" counts for up to and including 600 seconds after their last hello. A queued W
is dropped if the embassy stops, the guild's forwarding seat moves to another
guildmate, or the origin's public lapses. When the embassy stops (public
networks off, the War Effort switch off, War Effort loaded) one `D|` takes our
links back within seconds, through the guild budget, and our partners are dropped. `/le list` says "War Effort embassy: off (<why>)" when it cannot run,
e.g. "no War Effort channel on this realm (all-digit realm name)". Messages are 1 to 255
bytes from a fixed character set. Own echoes (your name, with or without your
realm), ignored senders, and a wrapper naming its own sender as the origin
are dropped. Reporters are compared by full name and realm.

### How long reports are listed

Rows expire by the origin's time (receipt minus the age a report carries):
HeadHunter after 300 seconds; War Effort, guildmates' own O lines and the Spy
family after 600 seconds; the guild incident addons after 900 seconds. A
guild-relayed copy lives as long as a direct one. One sighting heard twice
across networks (a guildmate's O line and its War Effort C) is one row: the
first-hand copy wins, then the copy with more names. A real zone change drops reports from the old zone. Each row
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

## HeadHunter network

With public networks on, the addon is a member of HeadHunter's whisper mesh:
the peers are the players in `HeadHunterSync`, each greeted once a session with
an honest hello naming LayerEnemies. Envelopes are carried on as HeadHunter
does (same world: region and ruleset; hop 1 to 5; at most 600 seconds old and
300 seconds ahead; never our own; another faction only for the kinds HeadHunter
allows), each one once (a ring of 4000 keys). After login it asks up to five
peers what they hold, pulls from the one with the most, and serves its own
held records (those carried in envelopes and pulled, the newest 300, this
session only; from the other faction only the kinds HeadHunter allows) byte for
byte to others who ask. A peer counts as known for 3600 seconds after it was
last heard. It forwards less than HeadHunter does
under load (the budgets above), and drops the oldest forward when its queue is
full.

## Spy family and guild incidents

**Spy-family sightings from party/raid are now relayed to the guild.** This
reverses the earlier "never relayed" rule. Each copy uses the existing
`LEGW1`/GUILD route as `R|1`, source `spy`, kind `seen`: one named enemy,
zone, no layer (`ns=unknown`), with the Spy user as origin, never us.
Sightings heard on GUILD are not relayed: guildmates already hear them.

A copy waits a random 0.5–2.5 seconds; a guildmate's copy heard during the
wait cancels ours. At most 6 Spy relay attempts per rolling minute per
client, and each full enemy name at most once per 60 seconds across all
three family sources and observers. These are `forward` priority and never
queue. All guild relays leave **two of the five LEGW1 prefix tokens** for our
own lines (one send costs two tokens in combat; refill is one per two seconds).
The relay gate accounts for other LEGW1 authors too, conservatively spending
refused attempts, and drops a relay that would consume the reserve. Wire
retains its existing shared/minute limits. `/le share off` stops every relay,
including ones already waiting; turning sharing back on does not replay them.
Instance, guild-only record sharing and the existing 128-pending cap still
refuse relays; the guild/instance context is checked again after the wait.
The caps count refused Wire attempts too, so nothing retries later.

Receivers keep them as **relayed claims**, not first-hand sightings. Find
can show a reported location, but the relayed Spy origin is never an ask
or hop target. Older clients (the 1.0.x/previous decoder) ignore the line:
unknown `src=spy` is invalid and nothing is stored. No protocol version
bump. Spy's stable observer/enemy identity can refresh after 60 seconds;
an older relayed copy cannot replace newer evidence.

The donor prefixes below remain receive-only; no message is sent on them.

- Spy Forever (`[Spy]`, guild, party, raid): one enemy, its class and level,
  the sender's map and position (shown as the observer's position).
- Forever Spy (`ForeverSpy1`, party, raid): one enemy and the sender's zone.
- Forever Sentinel PVP (`FSENT03`, party, raid): one enemy, class, level, zone
  and age.
- PvP Guild Bounty (`GBOUNTY` D, guild): the sender died to this player, with
  the victim's position when it is on the zone map itself.
- Wall of Shame (`WALLOFSHAME` D, guild): the sender's own death and the
  killer as the game named it (a creature can show too; environment deaths
  do not).
- Forever Told (`FTold1` S, guild): a wanted player seen, by zone.

Spy and Sentinel's "First-Last" become "First Last"; a part after a hyphen is a
realm only when it is all digits. The row and the enemy are keyed by the
folded name (our own realm stripped), so "First-Last" and "First-Last-<our
realm>" are one row. The sender's name is read the same way: our own line in
any spelling is refused, and the rate limit counts one sender once. Zone names
are looked up on the map (the zones of our continent and of the world map; the
table is kept only once both lookups gave data); a name two zones share is not
used. One row per sender and enemy (a newer line replaces it), 6 lines per
sender per 10 seconds over these six prefixes. Guild incidents are never
relayed. No received row is sent as our own sighting, and nothing is ever
sent on these prefixes. The parsed Spy-family formats have no faction or
friendly flag: existing validation and self-name rejection apply, but a
claimed enemy's faction is not independently verified.

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

Find holds up to 20 names. Adding a name prints only that name's row. The Find
heading shows `Find (3 located / 20)`; names with a sighting or shared position
come first, newest first, followed by unlocated names alphabetically. Unlocated
rows have a single compact status line. Mouse-wheel paging and individual Clear
buttons remain; the Track field is not a filter.

The session lookup is built on list changes and once when the home realm first
becomes readable, not on every report. The first 20 saved entries are validated
and deduplicated by folded full identity: `Name`, `Name-A` and `Name-B` are three
entries. No saved-data migration is needed. **Downgrade warning:** an older
client drops `First Last-Realm` and `Name-1234` entries; clients from before the
20-name limit also keep and save only the first five, losing names 6–20.

Find accepts a one-word base or a two-word Forever base plus `-Realm`. It splits
at the first hyphen, removes spaces and hyphens from the realm, and keeps the
base and casing as typed for display and saving (`First Last-Area 52` becomes
`First Last-Area52`). New spellings allow up to 36 bytes per base word and a
1–40-byte realm of letters, digits, apostrophes or high bytes; total input is
at most 100 bytes. All old accepted spellings retain their previous result.

A tracked base without a realm matches named evidence from any realm or none.
An explicit realm matches only that realm after normalizing and case folding;
a different explicit realm never matches. Realm-less named evidence can locate
a qualified entry, but its status says `realm not confirmed`, unless the typed
realm is our home realm. These rules also apply when reading session memory.
Single-word own sightings keep the previous first-name and hash-based realm
checks. A two-word own sighting uses a realm only if its display name explicitly
carries one; the second `UnitName` return may be a surname, not a true realm.
OpenMap keeps its separate exact-identity matching rules.

An enemy sighting is available only when you see the target yourself, or a report naming or
hashing him reaches you (War Effort, HeadHunter, the Spy family and guild
incident addons, or a guild relay; one enemy entry is enough, the rest of the
list need not arrive). There is no
server lookup, discovery broadcast, request to another addon, or background
scan of the world. A session cache remembers named sightings even before
you track them, including other zones. Adding a name shows that memory.
The cache is private to this session, bounded to 300 names (oldest newest-slot
time evicted first), with at most two entries per folded name: your own
sighting when available (otherwise the newest first-hand observation), plus
the newest other observation or claim. It is never a general enemy list,
kill count, ranking, SavedVariables field or donor-cache import. Own displays
can contain two adapter name strings, up to 321 bytes; other cached names
remain capped at 100 bytes, so legacy first-name matches are not discarded.

Visible party/raid members' target changes (`UNIT_TARGET` for `party1`–`party4`
or `raid1`–`raid40`) also enter the existing unit queue as `own (party target)`.
Both queueing and observation require an existing, visible member, confirmed
not to be the player, and a confirmed non-instance state. Our own raid token
is excluded, so our target keeps its ordinary `own target` label. A queued
group target must still have the same readable GUID at drain; a replacement
needs its own target-change event. Missing, throwing or secret API values
refuse the observation. The queue remains bounded; no new timer or send is
added. These are ordinary own sightings, including the existing O-share path.
Forever event delivery, target readability and same-area semantics still need
native confirmation.

A readable opposite-faction target/mouseover/nameplate/group-target event with a matching
name says `is on YOUR layer` only if your layer was known when it was seen
and no boundary has occurred since; otherwise it remains a historical
sighting, or says `seen by you, layer unknown` when no layer was known. A Bulo-only GUID enrichment
is not enough to generate this exact-name finding. War Effort sends only a
three-character enemy hash, so a match says `possible match, seen by <spotter>`
and includes class, level, zone and age. Different players can share the same
hash. It is probable, never certain; ask the spotter to confirm the identity.
Own single-word realm checks compare normalized, folded realm strings, not
these lossy hashes; colliding realm hashes cannot identify a different player.

The key is the source's exact lower-case name, a hyphen, then lower-case realm
with spaces/hyphens removed. Both home/explicit-realm and empty-realm forms
are checked. On Forever, the inspected detector passes UnitName's second
return into its realm argument even when that return is a surname. A tracked
`First Surname` therefore also checks the `first-surname` wire key. With an
explicit realm, `First Surname-Realm` checks exactly (First, Surname),
("First Surname", Realm) and ("First Surname", ""), each in the existing spelling
variants; it never substitutes the home realm or includes `-Realm` in the
surname. Hash matches remain possible, never confirm the realm, and carry the
uncertainty note for qualified entries even when that realm is our home.
Display name and hashing conventions were verified from source, not from a
live client. The original code's realm terminology is not proof of a real
realm. Whether any source supplies a surname character's true realm, and which
representation `UnitName` returns on build 70938, still need native validation.

Find offers `Ask <spotter> for invite` through the same manual helper. If a
fresh Bulo/LayerSwap claim puts that spotter on your current server key, it
says `already on your layer` and hides the ask; while your key is ambiguous it
says "probably" and the ask stays. Your own sightings do the same. Other-zone
findings instead say `travel to <zone> first` and cannot be asked from Find.
A finding that came only from a guild relay says `possible match, seen in a
relayed report`, without a name to ask and without an ask button.

A first finding prints a chat alert and attempts a raid-warning sound. It
re-alerts only after five minutes or when a new zone is reported. Across tracked
names, sound plays at most once per 10 seconds. A 10-second window prints up to
three detailed alerts; additional alerts are counted in one summary at the end
of that window, such as `LayerEnemies: 2 more tracked names located, see Find`.
Sound API failure is harmless. Named evidence survives world, zone and layer
boundaries for 60 minutes from its observation time. Each tracked name can
show both lines, for example:

    Seen by Birch Scout in Ashenvale, 4 min ago, layer 7085 (their claim)
    Reported: named as killer in Durotar, 12 min ago (death, claim)

At 600 seconds each line is prefixed `last known` and offers no Ask/Hop;
at 3600 seconds it is removed. Adding old evidence does not alert. A fresh
first-hand finding has action/alert priority over a claim, but both remain
visible. Your own sighting remains primary over a newer guild observation
while under 600 seconds old and in your current zone; both lines keep their
own times and layer labels. Guild O lines are first-hand; R lines and indirect
envelopes are claims and never authorize asking their origin. A fresh hash
finding is displayed alongside last-known named lines, including its possible
match warning, spotter and age, so the evidence behind Ask remains visible.
GBOUNTY and WALLOFSHAME killer names are claims in any zone, with victim
coordinates when supplied.
Direct HeadHunter P/L keeps its legacy ten-minute/boundary Find path outside
the five-source cache; indirect HH reports still use the relayed category.
HeadHunter D decoding and a HeadHunter cache source are not part of this change. No new send or relay is added.

Coordinates are text only, labelled observer or victim, never cache-driven
map pins. Only our own sightings and guild O lines carry a server-layer
claim. Other sources cannot confer a layer. Boundaries invalidate an old
own sighting's current-layer certainty without erasing the evidence.
War Effort hash-only matches retain their existing ten-minute/boundary path;
a hash never becomes a named cache entry. Pending report fragments still
reset at boundaries. Reload starts with empty evidence and alert history;
only the configured watchlist survives. Removing a name hides its evidence,
but re-adding it may find the still-retained session memory.

### OpenMap shared positions (receive only)

A tracked full name can also have an independent shared-position line:

    last shared position (OpenMap): Durotar 42,57 · 20 s ago · enemy faction

Only senders already on your Find list are read; a first name alone does not
match a Forever surname character. Matching uses Find's case folding and the
existing home-realm name rule; a foreign realm remains a different identity.
Nothing is kept, counted or logged for other senders. No friend roster,
BattleTag or account name is read or retained.

`OpenMapLoc` positions are received on GUILD, WHISPER and, when the client
supports its event and lookup, Battle.net game data. A Battle.net lookup must
give a readable character name and realm; missing or inconsistent identity
is not guessed. Only Battle.net can supply the optional faction label:
`enemy faction` or `your faction`, omitted when unreadable. GUILD and WHISPER
positions have unknown faction. A character heard on more than one route
has one place; the latest received position wins.

Named evidence (or a live hash match) still owns the row's status, layer, Ask/Hop eligibility and
alerts, exactly as without a shared position. The OpenMap line has its own
zone, coordinates and age, even if they disagree with the sighting. It never
carries a layer. With no retained sighting, status is `shared position`, and the
OpenMap line stands alone with no Ask, Hop, same-layer claim or alert. Shared
positions never enter the enemy store and are never re-shared or relayed,
including an opposite-faction friend's private position. They appear only
on Find rows and tracked-name command output, not in sighting alerts.

Named evidence keeps its independent one-hour lifetime; the shared position
expires after 150 seconds without a new line. An OpenMap withdrawal (`L0`)
clears only the place. Boundaries erase neither named memory nor shared
positions. Removing a tracked name clears its shared position and hides its
evidence; reloading keeps only the configured watchlist, never either location. There is at most one place per tracked
name (20 total), with a 64-byte incoming-line limit. Find cards with shared
positions are taller; scroll with the mouse wheel to see the other names.

OpenMap sharing is off by default in OpenMap. Its sharing guildmates
broadcast without a hello, so LayerEnemies alone can hear them. Non-guild
character friends and Battle.net friends are sent positions only after the
sharer has heard OpenMap from them: those routes depend on OpenMap running
locally to exchange its hello. LayerEnemies sends none, never answers H1/H2,
and does not read OpenMap's internals. Battle.net is faction-blind in the
donor's code; cross-faction GUILD/WHISPER delivery is not established. No
OpenMap install is required for LayerEnemies to load or for the guild route.

Format credit: `OpenMapLoc` is from OpenMap (MIT, OpenMap contributors);
this independent parser includes no OpenMap code or assets.

## Hop: asking for an invite

### Hop to another layer (no host needs to be known)

Use **Hop to another layer** on the Friendly tab or `/le hop any`. Your
own layer must be known and unambiguous. This is separate from the existing
single-host actions below: without LayerSwap's local book, their list is
mostly guild-only; `/who` lets this action ask players outside that list.
A disabled button explains the guard in its tooltip; during a round it says
**Stop**. `/le hop stop` does the same thing.

Guards: public mode, ungrouped, out of combat and instances, readable live
zone/name/position and own identity, no ask or hop still open, no outstanding
who query, working localized who APIs, and at least **30 seconds between
hop-any clicks**. Unknown group, combat or instance state refuses. A click
reserves Invite's shared 10-second overall cooldown once; every attempted
name is stamped for its shared 60-second per-name rule. Other asks/hops are
refused until this round ends or you stop it.

Only the first **49 who rows** are read. Other-zone rows, yourself,
duplicates, ignored/unreadable names, recently asked names, Wire's one-hour
offline names and this session's six-hour non-answerers are skipped. Listed
hosts on other layers come first, then online guildmates, then the game's
order. Only the first 8 eligible names are kept. This is not a continuous
scan: in crowded zones repeated clicks can see the same first 49 players.
There is no class rotation in this version.

Nothing is whispered before the who answer. Sends stop permanently at the
first asked player's hosting reply for another key in this zone, an invite
from an asked player, group/combat/instance/zone change, guild-only switch,
Wire refusal/throttle/pause/error, Stop, or the eighth attempt. An offline
result skips that name and still consumes one of the 8 attempts. No retry or
second round is automatic. **Sent requests cannot be recalled; a late invite
can still arrive.** An invite from an unasked player is never auto-accepted
or declined.

Replies are read only on WHISPER, only from names actually sent a request,
for 120 seconds after the last successful send. Names include surnames and
foreign realms. `same` / not-hosting answers are summarized as a count, not
one line per reply. A host's answer stops sends even if its invite never
comes; the timeout says so. Without a host the summary says how many were
asked and invites you to click again. Names that never answered are skipped
for **6 hours**, session only, **300 names maximum** (oldest evicted), never
saved. Answered hosts retain only the shared 60-second ask cooldown. Reload
clears the suppression table.

These are hidden addon whispers, not chat. What a player without the addon
actually sees, server throttling and whether stranger addon whispers count
toward account spam/silence limits are **not verified**. Hosts pay their own
invite budget; two hosts may answer before the first reply stops our round.
Stop-on-first-answer and one-second pacing reduce, but cannot eliminate,
that race. No stranger-hosting or response behavior is added here.

### Existing single-target and guild actions

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
unreadable names.

While your own layer is not known yet, Bulo and LayerSwap entries are still
listed with their layer, so a host is visible even with no layer addon of your
own, but they cannot be hopped to or asked: `/le list`, `/le hosts`, the
window's layer line and the Friendly tab say "Your layer is not known yet:
target or mouse over two different kinds of NPC within 15 seconds." Readings
of two different NPC kinds that agree within 15 seconds give your layer. A
report row's Hop and `/le hop <number>` are refused with the same message, and
nothing is drafted, not even a whisper to the report's War Effort origin.

A Friendly row with a layer from Bulo or LayerSwap shows "Hop via <name>"
(`/le hop host <number>` in chat): the same single request, the same limits and
the same "what was shown is what is asked" rule as a report row's Hop, aimed at
that host's layer. A row whose layer, host flag or LayerSwap uid changed since
it was shown sends nothing. A Bulo user without the host flag is asked too,
and the tooltip says "not hosting; may not answer".
A War Effort origin row keeps "Ask for invite" (the chat whisper);
`/le hop host` on such a row points to `/le ask <number>`.

When a host answers your request with LayerSwap's `heard <you>|<layer>|<zone>|h`
(the asked player only, by whisper, within 120 seconds), the addon remembers
them as a LayerSwap host on that layer for 12 minutes (at most 64 names), used
only when LayerSwap itself is not installed. A `-` answer (not hosting)
removes them. Nothing is sent for this.

When nobody on a report's layer is known and everything else allows a hop,
the row offers "Ask guild (chat)": the click puts LayerSwap's own guild request
into your chat box,

    /g inv layer <LS <zone> want <server>-0 <x>,<y>>

and you press Enter; the addon sends nothing itself. Every guild member sees
the line, and any LayerSwap or Bulo host on that layer who reads guild chat may
invite you, so more than one may answer. One guild ask per 60 seconds, within
the 10-second overall limit below. For 120 seconds after your own guild ask, a
LayerSwap `heard <you>|<layer>|<zone>|h` answer on GUILD is remembered like a
whispered one.

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

## Auto accept and leave

On by default and saved (`LayerEnemiesDB.autoHop`); `/le hop auto off` or the
Auto toggle on the Friendly tab turns it off, and then invites and groups are
left to you.

Accept: when an invite arrives, it is accepted only if your own hop asked for
it (a Hop button, `/le hop`, `/le hop host`, `/le hop any` or "Ask guild (chat)"; not
`/le ask`), within 120 seconds of that ask, from the player you asked (whole
name, realm included; for the guild ask, a guild member online in your
roster), while you are not grouped, not in an instance and not in combat
(unreadable counts as in combat). One accept per ask. The client's invite
popup is hidden as accepted. Any other invite is left to you. Chat says
"accepted <host>'s invite".

Leave: only the group joined through that accepted invite, and only while
the host leads it, it is not a raid and you do not lead it; otherwise the
addon stops watching and never leaves. When your server key, learned after
joining (two NPC kinds agreeing, or Bulo), becomes the target layer, chat
says "moved to layer X, leaving the group" and the group is left 3 seconds
later. With no move within 30 seconds of joining, the group is left and chat
says "hop failed: <host> could not move you".
For hop-any there is no wanted key: success means a known key different from
the key you left, in the same zone (including a key learned before the group
update). The same lead/raid/instance/combat checks apply. An unknown or
unchanged key is not success; returning to the old key cancels the pending
success leave. A zone change cancels automatic tracking.

## Hosting for your guild

Off until you turn it on with `/le host on` or the Host toggle on the Friendly
tab. It refuses to turn on, and says why, while LayerSwap or BuloLayerForever
is loaded (they host already), when the client has no `C_PartyInfo.InviteUnit`,
or when you are not in a guild. Turning it on asks the server for a fresh guild
roster and sends one `H` line. While it is on, the window shows "Hosting for
your guild (stays on after reload)" on every tab.

The setting is saved (`LayerEnemiesDB.guildHost`, true or false) and stays on
across login and reload until `/le host off` or the toggle turns it off. At
login, while it is on, one chat line says so: "LayerEnemies: hosting for your
guild is ON (/le host off to stop)." If it cannot run then (LayerSwap or Bulo
loaded, no `C_PartyInfo.InviteUnit`, not in a guild), it stays saved as on but
inactive, answers nothing, and the line says why; the window shows "Hosting is
on but inactive: <why>". When guild data arrives after login, it becomes
active then, with one line. Nothing is sent at login: the `H` line goes out
only from turning it on or in answer to an `F`. Hosting acts only while your
guild's name is readable and equal to the guild seen this session; when the
name blinks unreadable it goes inactive, and the next request or `F` checks
again: readable and equal makes it active at once, otherwise a guild roster is
asked (at most once per 15 seconds).

A guildmate's request is the LayerSwap whisper line above. It is answered only
when all of these hold, in this order (a failure before the guild check gets no
answer at all):

- the line is exactly `inv layer <LS <zone> want <d>-<d>[ <x>,<y>]>` or
  `... not <d>-<d>[ not <d>-<d>]...`, at most 255 bytes;
- the sender is not you and not on your ignore list, and has not asked in the
  last 60 seconds;
- your live map zone is the request's zone, your own layer is known, and you
  are not in an instance or in combat (unreadable counts as in combat);
- the sender is in your guild roster exactly once and online (unreadable or
  ambiguous counts as no). A roster older than 120 seconds is refreshed first
  (at most once per 15 seconds) and the request waits up to 5 seconds for it;
  a newer request replaces a waiting one.

Then: `want` your layer gets `heard <name>|<your layer>|<zone>|h` and one
invite; `want` another layer gets `heard ...|-` with your real layer, so their
list corrects itself; your layer as the first `not` gets `same`; your layer as
a later `not` gets nothing. No invite (and `heard ...|-`) while you are in a
raid, in a party you do not lead, in a party with someone this feature did not
invite, at five with pending invites, while your own hop request waits, within
10 seconds of the last invite, or after 6 invites in 10 minutes. Each invite
prints one line with the name. Guests are never removed. `/le host` shows the state and the invites of the
last 10 minutes.

## Storage and performance limits

LayerEnemiesDB is SavedVariablesPerCharacter. It stores options, up to five
explicitly tracked names (typed or chosen with On my way), and window position. It never persists
sightings, unselected identities, GUIDs, hashes, locations, report payloads,
asked names, alert history or source settings. Besides those three it holds
`guildHost` (hosting for your guild) and `autoHop` (Auto accept and leave),
`consent` ("guild" after `/le net guild`, "public" after `/le net public`,
absent until either: public), `nets` (one
switch per network), `share` (sharing your sightings), `call` (death popup/sound),
`callArt` (call images; both call settings default on), `netNotice` (the
first-login line was shown) and `weReportId` (War Effort's report id, which
must keep rising across sessions, 1 to 65535). Reloading keeps your watchlist,
not its locations. Epoch boundaries clear sighting locations; OpenMap shared
positions instead keep their independent 150-second lifetime. Your own server key and its
30-minute "ambiguous" window are not saved either: after /reload the window is
gone, and a new one starts only at the next qualifying layer change.

Hop-any adds only session state: at most 8 selected/asked names per round and
300 non-answerer timestamps, expired after 6 hours and never written to the
save. Its 1-second pump ends with the round; it cannot start another search.

Limits: 256 local observations/identity hash buckets, at most eight candidate
names per hash, 64 reports per source (War Effort, HeadHunter, guild relays;
one report can show as several rows), 256 remembered relay ids, 255 bytes per
message. Held enemy lists: 200 entries per origin and
256 in total, for 15 seconds. Report-id order is remembered for 512 origins
for an hour. Receive rates per sender per ten seconds: 6 War Effort messages
(20 for G/X/W wrappers), 6 HeadHunter frames we read (P, L, E, and by whisper
N, Q, O, S, H; other types are ignored without counting), 6 Spy-family and
incident lines, 12 LEGW1; excess is dropped silently, and
each rate table holds at most 512 senders. Unchanged Bulo timestamps do not allocate duplicate
observation records. Friend lists are read for hosts/asks, tracked-target
status/alerts, and shown-window refreshes. The UI reuses at most six row
frames; its hidden timer stops after any already-queued callback returns.
Call uses one reusable popup, a 64-victim bounded session history with expiry and
generation-guarded close/age timers. Turning Call off clears its event/history.

## Verification

Run from the project root:

    python3 -I test/verify.py

It compile-checks each Lua file with luac -p, checks the TOC, runs the strict
mock harness with the Lua 5.1 binary (`LAYERENEMIES_LUA` overrides its path;
whatever binary is given is trusted to run the harness, and at least one test
must pass) and builds the local package. The mock client starts frames
shown, errors on unknown methods, delivers CHAT_MSG_ADDON, models secret
values, and fails any test that reaches a decline or chat call, a party
call other than `C_PartyInfo.InviteUnit`, `AcceptGroup` or
`C_PartyInfo.LeaveParty`, one of those from anywhere but Wire.lua, a hidden
invite popup not marked as accepted, or an addon message sent from anywhere
but Wire.lua or on any route but LayerSwap/WHISPER, LEGW1/GUILD, LFSw/GUILD,
WEFF1 (GUILD, PARTY, RAID, WHISPER) and HeadHunter/WHISPER. verify.py also
fails if `InviteUnit`, `AcceptGroup` or `LeaveParty` appears outside Wire.lua
or more than once, if a channel join, leave or roster select appears outside
Directory.lua or more than once, or if a HeadHunter frame of a type we never
send (anything but N, E, Q, O, S, H) is built. Both `C_BattleNet.SendGameData`
and `BNSendGameData` are forbidden; the harness also traps both calls and
permits registering `OpenMapLoc` but never sending on it.
Who calls are checked at runtime by walking to the first Lua caller, with a
file-local Adapters allowlist; SendWho must also be in the click stack.
Hop-any Wire calls are allowed only from Main's round pump, not merely any
caller with the right route. Tests cover 49 rows / 8 sends over the full
reply window, 30-second click spacing, cancellation, and ten idle minutes
without a further send. Existing single-host tests remain in the suite.
The randomized parser test uses 5,000 deterministic malformed inputs.
The package includes exactly the TOC's Lua files, TOC, README and nine
named Media TGAs: call-h1/h2/h6, call-victim/killer/where, and
call-help/dismiss-a/dismiss-b. Extra files or folders, including strays
inside Media, fail the gate. The header gate requires type 2, 32-bit,
bottom-left 0x08: headings are 256x64 / 65,580 bytes and labels/buttons are
128x32 / 16,428 bytes. All nine total 295,308 unpacked bytes. Headings draw
at 192x48, labels/buttons at 96x24; each group has one offline font size.
Alpha padding (at least four pixels) and ink width are checked too. Call
source and the strict frame mock enforce the Latin client-text boundary.
`test/call_assets_test.py` attacks the allowlist, header and text gate.
`tools/render_call.py` is offline tooling, not shipped; its overflow and
reproducibility probes are in `test/render_call_test.py` (see THIRD_PARTY.md).

Current results are in notes/test-results.txt and notes/verification.json,
both written by verify.py. notes/SUMMARY.md is the 0.2.0 summary, including
its CPU/allocation measurements; its counts are historical. Offline tests are not evidence of live client
compatibility, taint safety, layer semantics or event ordering. Everything
still needs in-game verification.

### Hop-any provenance

LayerSwap 1.14.20 (Adam5288) is listed as All Rights Reserved and its package
has no license grant. Only its request/reply wire format is used here: **no
LayerSwap code or bundled libraries are copied or executed**. Who handling
is original code written against the game's FriendList API declaration at
wow-ui-source `70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e`
(`FriendListDocumentation.lua`: SendWho, GetNumWhoResults, GetWhoInfo,
WhoInfo.fullName/area and WHO_LIST_UPDATE). The declaration marks SendWho
restricted; it does not prove a native click or slash command will work.

## Not tested on a live client

### Hop-any native checklist (two same-faction characters on different layers)

1. On Forever build 70938, does restricted SendWho answer from both the
   Friendly button click and `/le hop any`? Check taint/errors as well.
2. Does a who answer open the game's who window or print rows to chat?
   **No Blizzard frames are hidden, unhooked or changed for this feature.**
   Leave any who-window mitigation for a separate decision after observing it.
3. How does the server throttle `/who`, including other addons/manual searches
   while our 5-second search is outstanding? Results have no query identifier;
   an overlapping search's update cannot be attributed with certainty.
4. Does a LayerSwap/Bulo host invite a non-guild asker running only
   LayerEnemies? The asker does not need a known host or donor installed.
5. Does a player without a layer addon see any chat/UI or other side effect
   from the hidden request? Do not assume the offline mock proves invisibility.
6. Are who results same-faction only? WhoInfo has no faction field. If other
   factions appear, what does an addon whisper to them return?
7. How quickly does a host's `heard` arrive; can two hosts invite before the
   next one-second pump? Confirm only an asked name can auto-accept once.
8. Does WhoInfo.area equal the live map zone name in buildings/subzones?
   Check the Friendly button/tooltip layout with the native UI as well.
9. Does leaving 3 seconds after a confirmed new key keep the new layer?
   Check unchanged/unknown key failure at 30 seconds and stop/combat/instance
   behavior. Account spam/silence treatment is also unknown, not a safe-rate
   guarantee.

### Earlier native unknowns

Apart from the one 0.3.0 trial described at the top (host discovery failed for
a player without Bulo or LayerSwap), everything above is checked against a
mock client only. Still open (items 16 on are new in 1.0.0; the checklist
after the list is the order to try them in):

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
6. 0.3.1: a host listed while your layer is unknown (Bulo's guild line heard
   before any NPC reading), and the hint clearing after two NPC readings.
7. 0.3.1: `/le hop host <number>` and "Hop via <name>" producing an invite from
   a Bulo host and from a LayerSwap host (the `want <server>-0` and
   `want <server>-<uid>` forms).
8. 0.3.1: a LayerSwap host's `heard …|h` reply being remembered and listed for
   12 minutes, and a `-` reply removing it.
9. 0.4.0: does `C_PartyInfo.InviteUnit` work on Forever 1.60.1 when called from
   an addon-message event rather than a click? Guild hosting depends on it.
10. 0.4.0: the guild roster on Forever: `GetGuildRosterInfo` return order and
    name format, `GUILD_ROSTER_UPDATE` after `C_GuildInfo.GuildRoster()`, and
    the server's limit on roster requests.
11. 0.4.0: Find hosts: Bulo hosts answering `Q` within 6 seconds, and a
    LayerEnemies host answering `F|1` with `H`, both listed and hoppable.
12. 0.4.0: "Ask guild (chat)": the `/g` line drafted correctly, and a
    LayerSwap or Bulo host on that layer inviting from it.
13. 0.4.0: two LayerEnemies guildmates, one hosting: the request, the
    `heard`/`same` reply, one invite, the 60-second and 10-second limits, and
    no invite in combat or in a raid.
14. 0.4.0: a saved-on host after `/reload` and after a fresh login: the ON
    line, and whether guild data is ready at login or the host turns active
    on the first guild roster update.
15. 0.4.0: Auto accept and leave: does `AcceptGroup` work from
    `PARTY_INVITE_REQUEST` on 1.60.1, does the popup close without declining,
    does `C_PartyInfo.LeaveParty` leave from a timer, and does leaving 3
    seconds after the move keep you on the new layer? Also the 30-second
    failure leave, and that an invite from anyone else stays untouched.
16. Names: the CHAT_MSG_ADDON sender format on Forever 1.60.1 (bare "First
    Last" for your realm? "First Last-<digits>" for others?) and the
    `GetGuildRosterInfo` name format; the guild host, the invite and every
    network read both through one name rule. Whether two hidden realms can
    hold the same name, and whether `InviteUnit("First Last-7105")` works.
17. `GetRealmName` and `GetNormalizedRealmName` on Forever: an all-digit realm
    name gives War Effort no ruleset tag, so no War Effort channel name (for
    War Effort itself as for us) and no embassy.
18. Directory: what `JoinChannelByName` returns (nil, false or empty counts as
    no join); whether `CHAT_MSG_CHANNEL_NOTICE` YOU_JOINED or YOU_CHANGED
    arrives for our join, with which name fields (only that notice makes a
    channel ours, so only then is it ever left); when the channel list is
    filled after login; whether a new channel shows in it at once or after
    `CHANNEL_UI_UPDATE`; that a hand-left channel is not rejoined.
19. War Effort's reaction to our hello: does War Effort list us as a guild
    reader (minor 19) and start sending C/E to our groups; does the fixed
    version 1.0.0 never trigger its update notice; does a guild Y get our
    whispered C (sync marker) and E, shown in its window; does a J get
    `K|id|2`.
20. Embassy: `C_Club.GetGuildClubId` on Forever (without it the embassy stays
    off and `/le list` says why); `UnitName("player")`'s second return (our
    election name uses it as the surname, as War Effort does); a partner's W
    arriving as G in the guild; at most two forwarded reports a minute per
    partner (the 4-a-minute whisper cap).
21. HeadHunter: our world tag (region from `GetCurrentRegion`, ruleset from
    `C_GameRules` or the realm name) and whether HeadHunter takes our
    forwards; our hello listed by HeadHunter; catch-up offers and pulls
    between us and a HeadHunter client.
22. Spy family and incidents: Spy's and Sentinel's real name field ("First-
    Last"?); Forever Spy's and Sentinel's zone names found by
    `C_Map.GetMapChildrenInfo`; how often Wall of Shame names a creature.
23. Guild relay hops: the `R|1` relay format has no upstream hop field, so a
    relayed record shows one hop (a format change would break 0.3 and 0.4
    guildmates).
24. Guild changes on a live client: the order of `PLAYER_GUILD_UPDATE` and
    `GUILD_ROSTER_UPDATE` after leaving or joining, the guild name blinking
    unreadable, and the roster request limit.
25. Invalid-whisper feedback: the live localized `ERR_CHAT_PLAYER_NOT_FOUND_S`
    template and asynchronous `CHAT_MSG_SYSTEM` timing/name format. Matching
    requires a single `%s` or `%1$s` placeholder and readable text within 30
    seconds of an actual call; absent/unsupported templates, secret text,
    late errors and realm-stripped foreign names deliberately do not match.
    A manual whisper error for the same recently attempted identity cannot
    be distinguished from an addon error, so it may also stop our sends but
    is never hidden. The server's zero-member roster readiness and accepted
    target spelling still need client validation. No camera/FPS fix is claimed.
26. Own identity: the readable first/second returns of `UnitName("player")`
    and the actual home realm on Forever. Confirm split and already-combined
    forms do not create a self-reported row, while an independent guild
    reporter remains visible. A reload clears old session-only rows; existing
    rows from before the update are not a receive test. A surname equal to a
    realm in a single-word split is deliberately ambiguous and fails closed.
27. Guild full names: with LE on two guildmates, enable sharing on the updated
    observer and add the exact full-name Find watch on the receiver before a
    fresh enemy target or mouseover. Verify the full name arrives, including
    from another zone (Find, not the current-zone Reported tab). Re-observe
    after the repeat cooldown for a second trial. This does not test a
    War Effort-only observer's two-enemy threshold or establish why any earlier
    donor-only sighting was absent.

28. OpenMap guild reception with only LayerEnemies installed: a guildmate
    enables OpenMap sharing, you track their full name and wait about a minute.
    Verify the surname sender spelling, displayed zone/coordinates and Clear.
    Check map-name lookup for the uiMapIDs encountered (`zone <id>` is the fallback).
29. OpenMap Battle.net reception with both addons running locally: track an
    opposite-faction BN friend's full name, check the place and `enemy faction`
    label. The event, game-account lookup, Forever `characterName`/`realmName`
    spelling and readable `factionName` remain unverified here; missing surname
    or realm means no exact match. Check which route supplied the place. With
    OpenMap disabled locally, expect guild positions only. Cross-faction
    WHISPER/GUILD delivery is not assumed; record the route if it occurs.
30. Find's two-tier card wrapping and scrolling on the native client: a
    sighting plus a shared position, different zones/ages, and each expiring
    separately. Shared-position lines must never display a layer or inherit
    enemy actions, including when a pooled row is reused.

Live-test checklist for the PR build (two characters in one guild, A and B,
then a War Effort and a HeadHunter user if one is around; if a network fails
its part, its constant is turned off before release):

1. Login on A: the public-networks line once; `/le list` and `/le net` show
   both networks on (or why not); the realm name and `/le list`'s embassy
   line (items 17, 20).
2. Channels: `HeadHunterSync` and the War Effort channel joined, the join
   notice seen, both left by `/le net guild` and joined again by `/le net
   public`; a channel left by hand stays left (item 18).
3. Names: A and B whisper and see each other's LEGW1 lines; note the sender
   names printed by `/le reports` and the roster names (item 16).
4. Own sightings: A targets an enemy; B's Reported tab shows A's O line within
   about 3 seconds; `/le share off` on A stops it.
5. Hosting: A hosts (`/le host on`), B hops through the guild: one invite from
   `InviteUnit` on an addon-message event; B's Auto accept takes it from
   `PARTY_INVITE_REQUEST`, and B leaves by `LeaveParty` from a timer 3 seconds
   after the move (items 9, 15); a guild change on A makes hosting inactive.
6. War Effort: with a War Effort user in the guild, its window lists A; A's C
   and E show there; no update notice; a Y and a J answered (item 19).
7. HeadHunter: with a HeadHunter user, its peer list shows LayerEnemies;
   envelopes forwarded and catch-up served (item 21).
8. Spy family: a guildmate with Spy targets an enemy; A and B show the row
   with "observer's position" (item 22).

Footer used in slash output and the window:

Only players seen by you or reported by other players' addons.
