# LayerEnemies

## 1.2.1 - "On my way" and the found pop-up

**New send:** one hidden addon message on `LEGW1` to `GUILD`, `G|1|<zone>|<victim, hex>`.
It is sent only when you press the help button on a Call pop-up: once per call,
at most one per 10 s and six per 10 minutes. Share off, not in a guild, or being in
an instance sends nothing. No chat text is typed for you and nothing is saved.
Older LayerEnemies versions ignore the line.

- **On my way.** Guildmates on 1.2.1 see one chat line: "LayerEnemies: <helper> is
  coming to help <victim> (<zone>)." The player who died sees
  "LayerEnemies: COMING: <helper> is on the way." and hears the alert sound.
  There is no separate whisper: calls only come from guildmates, so the guild
  line already reaches the victim.
- **Found pop-up.** When a tracked enemy is found, a small window shows the name,
  level and class if known, zone, age and source, with **Show on map** (the same
  waypoint as the Call help button) and **Dismiss**. It closes after 30 s, never
  opens in an instance, and opens at most once per tracked name per 2 minutes.
  `/le found on|off` (on by default, saved as one setting). It sends nothing.

Not tested on a live client: not run (alpha, owner's decision).

## 1.2.0 at a glance

Everything since 1.1.0, with the sections below and the reference chapters
holding the detail:

- **Window:** text no longer overlaps; Find cards measure their real height.
- **Hop to another layer** works like LayerSwap: one click (or `/le hop any`)
  reads the first 49 Who results with the Who window kept hidden, then asks
  those players for an invite with hidden addon whispers.
- **New sources you can read without sending anything:** your Battle.net
  communities and friends (`online (community)` / `online (friend)` in Find),
  Forever Layer Hop hosts, Overlord rampages and killer claims, Wanted
  sightings and kill records, and ChehulNet guildmates on other layers (shown
  as hints). These are claims from other addons, not confirmed sightings.
- **`/le quiet on|all|off`** hides the "No player named ..." lines caused by
  LayerEnemies' own addon whispers (`on`, the default), by any addon (`all`),
  or none (`off`). A name you whispered yourself stays visible for 10 seconds.
- **WarBoard (sends):** to read WarBoard, LayerEnemies sends WarBoard's hello
  and answer over Battle.net to eligible opposite-faction friends and community
  members online in WoW, under its own name and version. A real WarBoard client
  then treats you as a new peer and shares your profile, kill streak and board
  with its Battle.net contacts.
- **WarBoard tracking request (sends, on by default):** for a player on your
  own Find list, LayerEnemies asks that player's WarBoard client to broadcast
  its position every 15 seconds, and withdraws the request when you stop.
  Those broadcasts go to the whole WarBoard network with your character's name
  on the hunter list: **anyone running WarBoard, including the tracked player,
  can see that you are tracking them.** `/le warboard track off` turns it off
  for the session.
- **Forever Layer Hop membership (sends on `FLHNET2`):** your presence to guild
  and group, owed replies, and guest hop requests to Forever Layer Hop hosts.
  You are never offered as a host.
- **Overlord (sends on `OverlordF`):** your presence to guild, group,
  Battle.net friends and Overlord directory members, owed answers, and the
  kill feed request. To be served the feed,
  **LayerEnemies does not announce itself to the player it asks**: it asks at
  most two Battle.net friends, relies on not having been heard by them, and
  claims no capability it lacks.
- **Every send** stops with `/le share off`, Guild only or its network switch
  (`/le net <name> off`); only an owed withdrawal (WarBoard `FBUN`, the Overlord
  feed stop) may still go after those. Combat and instances block every send.
  The full send tables are in the sections below and in **What is sent**.
- **Upgrade notes:** saved settings carry over. 1.2.0 adds two saved fields:
  the `/le quiet` mode and any WarBoard withdrawals still owed at logout.
- Not tested in game (alpha, owner's decision).

## 1.2.0 - Overlord kill feed

| What LE sends | To whom | Maximum rate / condition |
|---|---|---|
| `HR 8:V:<E>:<nonce>:1:LK:0:0:<opposite faction>`; nonce ends `f` | At most two selected Battle.net friends of either faction, via Battle.net only | Unanswered requests back off: 200, 400, 800, 1600, then 1800 s; any valid HA/HB reply resets to 200 s; first request obeys the NH clock below |
| `HR 8:K:<E>` | The same live feed sources | Shares that 200 s gap; only after an accepted reply/feed |
| `HR 8:X:<E>` | Each source to which a request actually went | Once per cancellation, owed priority; retained through combat/instances, no duplicate after success |
| `HA 8:R:<E>:<nonce>:<seq>` (busy, no ranking profile) | Direct addressed protocol-8 HR V requester only | Shared NH/HA 150 s gap per peer; six owed frames/minute |
| Own `NH`, `LayerEnemies <installed TOC version>` with **no suffix** | Non-source peers only | C2 limits below; never to a selected source's name or account, including owed replies |

To be served the feed, LayerEnemies does not announce itself to the player it asks. Overlord serves peers it has not heard from, and refuses those it knows run an older protocol. LayerEnemies claims no capability it lacks; it relies on not having been heard.

The owner approved this intentional use of the unknown-requester window. The
first request itself teaches the donor a return route before dispatch, including
its Battle.net account ID; NH is not required for the reply. See
`notes/overlord-c3-reachability.md` for pinned source lines.

Feed sources are Battle.net friends only. Guild and group members remain ordinary
C2 peers: the feed never suppresses guild, party or raid presence. A friend in
our guild or group is ineligible; an unreadable or incomplete roster means it
might be there, so no friend is selected until that roster is readable. The
same full character-plus-realm key applies to guild rows, party units and game
accounts; realm display spaces and the home realm are normalized. Unreadable
realm identity fails closed, and a foreign-realm namesake stays distinct,
including Battle.net character names and whisper recipients. Targeted NH to a
selected source's name or account is suppressed at admission and actual dispatch.

A source must have been heard first-hand under Overlord over Battle.net at least
once this session in our pool, and the game must show that exact game account
online in Forever now. Hearing need not repeat within 300 s. Before each request
or keep, **more than 300 s must have passed since our last NH on any route that
could reach it** (account, whisper, guild or group). Never sent this session means
no artificial wait. The per-account NH clock survives pool and own-character
changes and returns. Any actual NH to that audience restarts the clock, including
an unexpected send after selection. A source's validated campaign epoch is kept
for the session, never guessed, and replaced only by new source evidence. The
session hearing cache is capped at 200 identities; it is not a saved peer list.
This session-only rule does not guarantee that a donor has forgotten a prior
session's NH immediately after a reload; a refusal is handled by the backoff.

Stops are attempted on unsubscribe, source departure/unfriending, `/le net
overlord off`, share off, Guild only, epoch/route invalidation and logout.
Local leases cancel immediately. Only the exact outstanding stop can cross the
privacy/off switches; combat, instances, unknown pool/identity and real-Overlord
stand-down still silence **all** sends, including stops. Combat/instance stops
remain owed and are queued when safe, within 60 s after the fight/instance ends
under available transport budgets. Local refusal or queue pruning may be retried
only in that 60 s safe window; successful stops are never repeated. Logout pumps
the existing queue once, subject to its
normal budgets; delivery is not guaranteed. At logout only one Battle.net frame
can leave, so if a feed stop and a WarBoard withdrawal are both pending, the
stop goes and the withdrawal stays owed until that character logs in again.
Without the client's friend-list event, a removed friend is dropped within
about 21 s and receives nothing but the stop in the meantime. The donor's subscription expires
900 s after its last renewal, not 200 s. 200 s is the keep-alive interval.
Battle.net uses `BN.send` and Wire's client-call boundary: eight frames/minute
inside the shared 30/minute, one/second limit. Whispers share Wire's 20/minute
and four/minute/target limits. Stops share the six owed frames/minute budget.

The feed is useful only while the donor considers its own custom channel down
and can serve. Silence/busy responses are normal. LE never advertises ranking
capabilities (`~lp6`, `~lr`, `~ld` or any other suffix), never serves a ranking,
forwards packets, fabricates kills or hosts maps. A zero comparison is an honest
local count/hash, not a claim of page-service capability. Only addressed HR V requests get a bounded busy HA
rather than a claim of equality, and only for protocol 8. Older protocol versions
get nothing. HR F, K and X get no reply; neither do unknown HR kinds.

Epochs stay source/pool scoped and never come from the clock: only an exact
validated **13-field owner K** (race, sex, matching `B<E>`, level included), or
well-formed addressed v8 `HR V LK`, can establish E. An intervening NH while a
request waits in the queue cannot invalidate a successful receipt through stale
context. Unsent/failed requests grant no feed lease. Full `k` rows accept donor
race strings (`o2`, `Skyborne3`); compact `s` rows require a prior full identity.
Only tracked opposite-faction names become relayed, time-unknown location claims,
with no layer and no Ask/Hop. Nothing is saved. Bounds: 600 bytes/feed, 48 rows,
250 bytes/row, 64 identities/source, 240 rows and 14,400 bytes/minute/source;
global 480 rows and 28,800 bytes/minute survive source churn.

Tests: `lua test/harness.lua --only 'Overlord'`; portable mutant runners
`test/overlord_peer_mutants.py`, `test/overlord_feed_mutants.py`,
`test/overlord_reachability_mutants.py`; full `python3 test/verify.py`.
The test-side donor model is independently written from source. Every test
emission is checked for capability claims. No donor code copied or executed.
Native checks **not run (alpha, owner's decision)**. This section supersedes
the previous deliberately unreachable C3 and its no-stop decision.

## 1.2.0 - Overlord direct peer

| What LE sends | To whom | Maximum rate | Stops when |
|---|---|---|---|
| Own `NH` (one `BF`) | Guild | Once/120 s with a heard listener; once/600 s alone | Any stop below |
| Own `NH` (one `BF`) | Current party or raid | On joining, then once/120 s, shared group gap | Any stop below |
| Own `NH` (`R2` + `BR`) | Up to five live Battle.net friends plus two rotating unheard friends | One cycle/120 s; once/120 s per account | Any stop below |
| Owed targeted `NH` | Direct whisper sender addressing us | Once/150 s per peer; six owed answers/minute total | Any stop below |
| Own targeted `NH` greeting | Read-only Overlord directory members | One/minute, six live partners; same candidate no sooner than 600 s | Any stop below |
| `HA R` (busy: no ranking profile), including a zero-count/hash request | Direct addressed whisper/Battle.net requester only | One shared NH/HA 150 s gap per peer, sharing the six owed answers/minute | Any stop below |

**All ordinary sends stop** with `/le share off`, Guild only (`/le net guild`),
`/le net overlord off`, combat, instances, or an unreadable ruleset pool,
local character or own addon version. C3 adds only the bounded stop exception
through privacy/off switches described above; hardware/identity gates remain.
When the real Overlord addon is loaded, **every Overlord send stops**, including
NH replies, HA answers, greetings and feed requests on guild, group, whisper and
Battle.net. Queued work is also refused at dispatch. LE still receives traffic.
Battle.net uses `BN.send`: **eight frames/minute**, inside the shared
30/minute and one/second queue. Addon messages use Wire; stranger whispers share
its **20/minute**, four/minute/target budget. Own Overlord announcements use the
low-priority reserve so ordinary LE guild traffic keeps priority within the
shared **20 guild frames/minute**. Owed responses are attempted immediately;
there is no retry of a client attempt or addon backlog. Directory greetings
rotate round-robin: with forty stable unanswered reachable members all get a turn
within forty eligible minutes, not just the first ten. A local queue/gate refusal
spends no candidate or minute cooldown: the same tick skips that member and scans
on, at most one directory pass and one charged greeting. An actual client attempt,
including a refused send, does consume the cooldown. Names use the shared canonical
rule (only our own realm suffix is stripped), so equivalent spellings share a
candidate cooldown. LE never greets or addresses an Overlord whisper or Battle.net
message to its own character, including Unicode case and own-realm variants.
Queue guards recheck pool, identity, privacy and actual
per-target gaps at dispatch. A successful send is not proof of delivery.

LE identifies itself as **`LayerEnemies <its installed TOC version>`**, never as
Overlord. C2 advertises no capability, rank, map digest or helper flag. It does
not forward packets, keep a leaderboard, host, invite, or save discovered names.
The existing network switch map is reused; no new SavedVariables or schema.
The map protocol has **no truthful empty answer**: an empty store produces zero
`ZA` pages in 2.5.4 (`Sync.lua:6058`). LE therefore sends no map answer rather than
inventing zones or an unsupported acknowledgement. This narrows the plan's
“always answer map requests” sentence; leaderboard emptiness is representable.

Receive adds **WHISPER BF and Battle.net R2 BR/BF**, including opposite-faction
friends; legacy unbanded Battle.net traffic is not accepted. Own/foreign/unknown
pool isolation is checked before retaining partials (inner pool at assembly).
`GW` remains a guild alert in Reported; `GD` remains a tracked-name killer claim
in Find; direct `EK` remains party/raid only. No new evidence gets a layer or Ask/
Hop authority. Other packet kinds can establish a route, not a location. Read-only
channel discovery uses `OverlordF` / `OverlordFE` / `OverlordFRP` /
`OverlordFRPP` / `OverlordFHC`, never CHANNEL sends, and joins only when two slots
remain free afterward. Only LE-owned joins are left; manual leaves are respected.

Memory/work limits: **24 parts, 3,600 assembled bytes, four streams/sender,
64 streams total (16 reserved for guild), 65,536 held bytes (16,384 reserved for
guild), 120 s total / 30 s idle**; repeated parts do not extend idle time.
Before parsing: per sender 120 frames and 14,400 bytes/10 s across addon routes;
Battle.net also has an account bucket. Overall 640 frames / 128,000 bytes/10 s,
public ceiling 512 / 96,000, 128 sender buckets with 32 guild-reserved. Route table
128/96 public, 300 s; dedupe ring 2,000 origin+ID entries. All state is session-only.

Protocol-only, no donor code or library copied or executed: **Overlord 2.5.4**,
`c821808586ab50bb4ccb5d54b146e0d7c2671734`, All Rights Reserved.
Tests: `lua test/harness.lua --only 'Overlord peer:'`,
`python3 test/overlord_peer_mutants.py [--write]`, `python3 test/verify.py`.
Mutation reports are byte-stable, read-only unless `--write`, and run in isolated
scratch copies. Native checks **not run (alpha, owner's decision)**.
This section supersedes the historical receive-only send/fragment limits below.

## 1.2.0 - quiet not-found notices, including other addons

`/le quiet on|off|all` controls the client's localized **"No player named ..."**
system line. `/le quiet` prints the current mode and what it hides.

- **`on` (default):** hide only notices correlated with LayerEnemies' own addon
  whispers, unless protected by a recent typed whisper as described below. An
  actual addon whisper to that exact player in the last **30 seconds** accounts
  for at most one notice; at most 64 recent attempts are retained.
- **`all`:** hide these lines **whichever addon caused them**, with the same
  typed-whisper protection as `on`.
- **`off`:** keep all notices visible. Offline bookkeeping still runs.

In both `on` and `all`, a typed whisper protects that name's not-found lines for
**10 seconds**, even if LayerEnemies also whispered the same player. If the
typed target cannot be validated or folded by LayerEnemies' name rule, is
unreadable, or contains **any non-ASCII byte**, a timestamp-only
**protect-everything marker** keeps **every** not-found line visible for 10
seconds instead. This includes typos such as `Bob2`, a trailing space, and
`élodie` followed by an error spelling `Élodie`; no Unicode case folding is
attempted.

The session-only typed ledger holds at most **16 distinct validated ASCII
names**; repeated whispers refresh one slot. While all 16 slots are occupied,
**all not-found lines stay visible**. Overflow never evicts an existing target:
it refreshes the protect-everything marker, so untracked overflow whispers keep
their full 10 seconds of protection even after tracked entries drain. Protection
expires at 10 seconds exactly (or on clock rollback/reload); notices themselves
do not refresh it.

The existing per-character `quietWhispers` setting now saves one of `on`, `off`,
or `all`. Older `true`/`false` settings migrate to `on`/`off`; missing or invalid
values default to `on`. No target names, message contents or counters are saved.

The typed-whisper exception uses **secure post-hooks**, not replacement send
functions, on the modern chat-send entrypoint and its legacy alias when each is
available. LayerEnemies **never calls either chat-send function**. `all` is ready
only when **every existing entrypoint** was successfully hooked (and at least
one exists). If any required hook fails, `all` behaves like `on`; `/le quiet`
and `/le net` say so, and `/le net` names the missing hook. Any successfully
installed hook still protects the whispers it observes in the fallback mode.
Hooks observe only `WHISPER`, not say/guild/channel/Battle.net chat. A normal
visible chat whisper sent programmatically by another addon is conservatively
protected too: these APIs cannot prove that a human typed it. Addon-message
whispers do not create a typed-whisper exception.

Spaced Forever names are preserved, case folding is **ASCII-only**, and only the home realm is
stripped, and foreign realm suffixes remain part of the identity. In `on`, a bare
name shared by recent addon targets on different realms is ambiguous and stays
visible. `all` matches every supported localized not-found line, not just valid
addon targets. Other system messages, secret/unreadable text and unsupported or
missing localization are never hidden. Unavailable/throwing filter APIs fail
open. This changes no send policy, budget or existing offline hold in any mode.

`/le net` shows:

`hidden (LayerEnemies whispers): N; hidden (other addons): K; shown (your own whisper or mode): M`

These session counters reset on reload. N and K count actual filter hides; M
counts observed matching notices classified to stay visible. "Other addons"
means **not correlated with an eligible LayerEnemies whisper**, not proven
attribution: late/ambiguous/duplicate errors can count there too. Multiple chat
frames and the system observer share one decision, using a positive line ID or,
without one, identical text in the same `GetTime()` tick. Changes of mode or
manual-whisper state do not change a decision already made for that event.
Hidden decisions retain exact text in the existing bounded session ledger;
shown, uncorrelated diagnostics keep only numeric fingerprints. Fingerprints
never authorize hiding. Without IDs, identical independent failures in one tick
cannot be distinguished: **one addon whisper followed by two identical lines in
the same tick can hide both**. With distinct IDs, or in later ticks, a second
line cannot reuse that own-whisper receipt in `on`.

With the real **HeadHunter** or **WarEffortScout** loaded, LayerEnemies already
stands down its respective network sends. Guild hosting already stands down
beside **LayerSwap** or **BuloLayerForever**; explicit LayerEnemies hop requests
can still send. Those policies are unchanged. Use `all`, not `on`, to also hide
the other addons' not-found lines.

Source evidence: Forever `1.60.1.70938`, pinned UI commit
`bebcb6bf309cf41b41bd74f8ca651e6a105b2676`. Its typed-whisper path calls
`C_ChatInfo.SendChatMessage`; the loaded compatibility file also defines
`SendChatMessage`. Native hook availability, taint behavior, exact error timing
relative to the post-hook, stable line IDs and other addons' filters are **not
live-tested (alpha, owner's decision)**. An error delivered before the post-hook
cannot yet be recognized as a manual whisper. No live installation was made.

## 1.2.0 - Wanted (receive only)

Reads Wanted 1.29.x (protocol audited at v1.29.2) without Wanted installed;
**no greetings, replies, requests, relays, invites, addon-message sends,
Battle.net sends or outgoing version claim**.
No new SavedVariables fields, record ledger, signing keys or saved player names.
The existing `/le net wanted on|off` switch defaults on. If Wanted itself is
loaded, passive membership stands down but incoming data still work.

- `WNTD` **E/S** on guild or channel: tracked enemy sightings. Find's measured
  **Reported** detail says **seen near observer**; percentage coordinates belong
  to the observer, not the enemy. Observation time stays unknown; age is receipt
  age. Known same-faction GUIDs are refused. E/S on whisper are not donor formats.
- `WNTD` **R/F** on guild, channel or whisper: `kill`, `death`, `assist`, `claim`,
  `bounty` and `spotted`. Named participants are matched against your Find list
  or a live guild Watch; known friendly participants are omitted. Direct R has
  witness provenance only when origin equals the transport sender; F and carried
  R are relayed. All are **unverified claims**, not authenticated records: Adler-32
  is checked, Ed25519 and chain authority are not. Bounty last-seen information is
  cached, aged from `seenAt`; claims use `killT`, other records use record `t`.
  `spotted` has only a GUID and is used only if existing tracked Find evidence
  already binds it to one name. No new GUID-to-name cache is created.
- Sender-supplied zone text is **never displayed**. Only a zone resolved from the
  map ID is shown; absent, invalid or unresolved maps show no zone, with no text
  fallback. Coordinates without a valid map ID are discarded.
- `WNTDB` whole / `WNTDP` numbered **L** summaries: anonymous opposite-faction
  counts, only from a live same-realm game account resolved through BNet. View
  map/layer counts with `/le net wanted`; overlapping carriers use max, not sum.
  They never identify or locate a player. H/A/N and all other bridge kinds are
  ignored. A silent new listener is not normally sent bridge data until D2's
  handshake exists; D1 does not initiate it.
- A conservative read-only join of `WantedNetAlliance` / `WantedNetHorde` uses
  the existing Directory ownership/consent checks and leaves two channel slots
  free. No roster scans or directory names are collected for D1. If the channel
  is unavailable, guild and any already-delivered whisper records still work.
  Channel migration/password/control messages and all fast-path whispers are
  ignored, never answered. No location becomes an LE layer, Ask/Hop target, sound
  (including later alert polls) or outgoing relay.

Named evidence uses the existing `Sources.offer` → Known/Find claim projection,
not a new board or a kill list. It appears in Find's existing measured Reported
line, **not** the separate zone-local Reported tab. Guild-Watch-only matches are
retained by the shared registry in session Known; they do not add saved Find
names or new rows of their own. This is the existing registry projection.

Limits (deliberately stricter than the donor where needed): WNTD 255 bytes/frame,
240-byte chunks, 12 parts; WNTDP 3800 bytes/frame, 3784-byte chunks, eight parts.
**Two unfinished messages per canonical sender across addon routes** (or BNet
game ID), **16 assemblies globally, eight reserved for guild traffic**; channel,
whisper and BNet together may occupy at most eight. Thirty seconds total lifetime.
Encoded payload at most 30272 bytes, inflation at most 65536 bytes; shared codec depth 8 / 4096 logical values. Batches: 15 sightings,
10 R records, eight F records. Records: 64 scalar data fields, 512 bytes/string,
live sequence 1000001–2147483647, valid ID/hash; no nested data. WNTD versions
1.29.x with any numeric patch (including 1.29.0 and later patches; version text
at most 32 bytes). Other majors/minors and version suffixes are refused; this
receive policy is never advertised. No timestamped location at least one hour
old or ahead of server time is accepted. No-time sightings expire one hour after first receipt. Session
replay ledger: **512 identities, at most 32 per canonical carrier across addon
routes and packet/record kinds; 256 reserved for guild**. Claimed record origins
do not get their own carrier quota. Expired IDs are pruned first. New accepted
evidence evicts the **oldest remembered ID** from a full sender quota, then from
the non-guild pool if full, then globally if still full; it is never refused just
because replay memory is full. Admission order breaks same-clock ties; duplicate
IDs still remembered are dropped without refreshing age or order. Invalid or
untracked input cannot evict live IDs. `/le net wanted` shows **Wanted replay:
evicted=N**, counting each live ID displaced (not expiry or a refusal).
Trade-off: an evicted sighting ID can be accepted again before its original hour
expires; timestamped records still retain their original observation/expiry time.
Other receive-rate and assembly limits remain. Rate ledgers: **128 identities each for guild,
whisper, channel and Battle.net**, with 120-second idle expiry; 60 addon datagrams
per sender per route / 30 Battle.net datagrams per game ID per fixed minute.
WNTD tag/route and basic fragment shape validate before taking a sender entry;
malformed numbered Battle.net fragments also take no entry. L: 20 carriers ×
12 rows, counts clamped at 200, expiry at 600 seconds. Decoder/record/offer/budget
and protected-call failures contribute refusals; ignored tags and pending
fragments need not. Every store is session-only and bounded.

Protocol difference from the plan shorthand: Wanted uses its own **numbered
fragments, not AceComm**. The shared `addonDecode`, `inflate`, `lsRead` are used;
AceComm control bytes are rejected, not mistaken for Wanted framing. The audit's
E/S producer is guild/channel only; PARTY/RAID remain unsupported. The guild
reserves do not add new group routes. Mapless evidence stays place-unknown;
missing bounty `seenAt`, unresolved spotted GUIDs and unreadable
faction/identity/time fail silent.

Registry addition: optional `status() -> {string,...}` on `Sources.register` and
`Sources.lines(name)` support opt-in diagnostics (240 lines, 160 bytes/line,
protected and sanitized). `/le net` remains one counter line per network; one
new generic command branch dispatches `/le net <registered source>`. The existing
addon/BNet event wiring, heartbeat and UI measuring/rendering code are unchanged.

Reproduce: `lua test/harness.lua --only Wanted:`, `python3 test/wanted_vectors.py`,
`python3 test/wanted_mutants.py`, `python3 -B test/wanted_mutants_test.py`,
`python3 test/verify.py`. Mutation evidence normalizes Lua object addresses and
is not rewritten when unchanged. Round-1 regressions reproduce the 300-user
channel flood (75/75 guild sightings), 128 junk senders (20/20), and renewed
assembly holds (20/20 five-frame guild messages). Round-2 S4 regressions show all
120 sightings at one/minute for two hours, all 60 at one/20 seconds, and all 360
at that faster cadence for two hours; retained duplicates still drop. Pool and
counter tests cover sender/public/global eviction, shared carrier ownership,
oldest ordering, exact expiry and invalid-input isolation. Fixtures are
constructed from the audit, Python zlib and an independent serializer, not live captures.
**Native checks not run (alpha, owner's decision)**. This is D1 only, not D2.

## 1.2.0 - ChehulNet hello (receive only)

LE independently reads **ChehulNet v15 / LibChehulMesh v10**, as shipped in
GuildOS v1.28.0. No donor addon is required and no code is copied. Only plain
`ChehulNet` **GUILD, PARTY and RAID** HELLOs are accepted. This is an **ally**
source: the game's sender identifies the player; the line carries class,
level and an optional map / zoneUID, never coordinates or an enemy name.

- **Friendly (the hop window):** allies reporting another layer of your
  current zone appear **after all host rows** in their own subsection titled
  **Guildmates on other layers (hints)**. These guild/group hints show their
  name and receipt age, have **no Ask or Hop button**, and **do not count in
  the Friendly tab total**. Whisper them yourself; a GuildOS user is not
  necessarily an LE-compatible host. If an already listed host has the same
  whole identity, its existing row instead gains **other layer (ChehulNet
  claim)**, with the independent HELLO receipt age. Existing host capabilities,
  server key, source and freshness are unchanged. Both the heading and complete
  card text are measured before paging; the heading stays with the first
  visible hint, including when scrolling within the subsection.
- `/le layer` prints the number of distinct zoneUIDs reported for your current
  zone and names **at most eight** allies reporting **same layer as you**,
  followed by one **and N more** line if others remain. Comparisons require
  the exact same map and your own zoneUID reading. An unknown own reading,
  ambiguous layer, stale map context or unreadable clock permits no relation.
  A HELLO is a claim from that player's client, not independently verified
  location or a guarantee that an invitation will move you.
- **Never an LE layer key:** ChehulNet sends creature-GUID field 5 (zoneUID),
  not the field-3 server key used by LE. No comparison across maps and no
  assignment to your own layer. These rows never enter Find, Reported,
  sightings, host books, invite eligibility or hop fan-out. No alerts or sound,
  including later polling. Only previously known hosts retain their actions.
- Session-only memory: **200 players**, oldest receipt evicted at capacity,
  refreshed by a new accepted HELLO. Expiry is **400 seconds** from receipt,
  also on clock rollback. Nothing stores player names in SavedVariables.
  Ages are receipt ages; the wire has no observation timestamp (`time unknown`).
- Decoder limit: **255 bytes, six or seven pipe-separated fields**. `CHN1`
  and `H` must match exactly. A missing legacy layer field is accepted; five
  or fewer fields, extra fields, controls and multipart frames are ignored.
  Caps containing colons/commas do not move the layer field. Whole decimal
  levels 1–255 and map/UID values 1–99,999,999 are supported; invalid optional
  values stay unknown. Unknown classes stay unknown. Secrets, ignored/own
  senders and unreadable identity/context fail silently. No decoding in combat
  or instances. No guild/group roster scan is needed.
- `/le net chehulnet off|on` controls receipt/display (default **on**, switch
  saved). Off hides held data; on can show still-fresh held data. `/le net`
  includes `chehulnet: heard / accepted / sent / refused`; sent remains zero.
  Guild-only consent and having a ChehulNet-family addon installed do not stop
  this passive reader. There is no membership or outgoing stand-down work.

**No new sends, channel joins of either faction, whisper replies, peer
exchange, relay, discovery or subscriptions.** The rejected other-faction
member-list channel is not implemented. Warmth camp announcements are ignored.
The existing Wire route allowlist and all other sources stay unchanged.

Offline tests: `test/src_chehulnet.lua` (including 5,000 deterministic fuzz
inputs), `python3 -B test/chehulnet_mutants_test.py`,
`python3 test/chehulnet_mutants.py`, and `python3 test/verify.py`.
The mutant runner is read-only by default; pass `--write` only to replace
`notes/chehulnet-mutants.json` with new review evidence.
[Provenance](THIRD_PARTY.md) and [build evidence](notes/chehulnet-hello.md) pin
the source. Target: Forever Interface 16001; package version
1.2.0. **Native checks not run (alpha, owner's decision)**:
live traffic availability, transport name spelling, UID semantics and native
text rendering remain unverified. If no HELLO arrives, nothing new appears.

## 1.2.0 - WarBoard tracking request

| What LE sends | To whom | How often and when it stops |
|---|---|---|
| `WBF1\|D\|<encoded FBAK>` first ask | Only a uniquely resolved character on **your own Find list**, directly to that one live game account after a compatible WarBoard A handshake; target GUID/name from the client API only | **3 tries, at least 6 seconds apart**, then FBUN and **300 seconds idle** if no position arrives; never Watch-only or untracked names; at most 20 active targets |
| `FBAK` renewal | That same confirmed account only | Only while its newest position is **45–300 seconds old**, at most once per **45 seconds** per target. Past 300 seconds: FBUN, idle, retry after 300 seconds or a new handshake. Dead/in-instance silence does not accelerate requests |
| `WBF1\|D\|<encoded FBUN>` | The same target GUID with an outstanding request, including a restored debt, through a currently confirmed account | **Sent, unverified** after each accepted call; at most **3 attempts per 10-minute window**, at least **60 seconds apart**, at most **6 FBUN attempts per debt per login**, including failures. Stops: Find removal/clear, tracking off, share off, Guild only, WarBoard source off, stand-down, give-up, best effort logout. Also retires requests on local combat/instance entry. Cleanup survives those switches and waits until out of combat/instance |
| All kinds, including existing H/A | **Only `BN.send`**, prefix `WarBoard`; never guild/group/channel/chat forwarding | **6 FBAK/rolling minute**, within **10 WarBoard attempts/minute**, **30 shared/minute**, **one/second**. Owed A answers first, FBUN before own traffic. Budgets may delay attempts; failures spend them |

This asks the tracked player's WarBoard client to broadcast its position to WarBoard peers every 15 seconds, as a WarBoard hunter's client does.

Those broadcasts go to the whole WarBoard network and carry a hunter list with your character's name; anyone running WarBoard, including the tracked player, can see that you are tracking them.

Tracking is **on by default at login**. `/le warboard track on|off` changes it
for this session; `/le net warboard` shows the switch and caps. The existing
saved source/share/consent switches also stop requests. Identity fields say
`LayerEnemies/<our own version>` and carry our real character name/GUID and
faction. `sentAt` is an integer from **GetServerTime**, never a local-clock
fallback; unreadable identity, ruleset or server time means no send.

WarBoard never expires a subscriber. Its **FBUN** has no `targetName` and removes
only our own `hunterGuid`. The only new saved field is per-character
`LayerEnemiesDB.warboardOwed`: a dense, deduplicated, oldest-first array of **at
most 40 target GUID strings**, oldest out, with an optional `attempts[guid]`
map of integers 0–6 for those same GUIDs. Login/reload resets those counts to
zero once, reopening six attempts for each retained debt. No names, accounts, zones, timestamps, locations or
hunter roster are saved there. Older GUID-only lists remain readable.

Debt is recorded in memory before an attempted request, but written to disk
**only at logout or reload**. A client crash before that save loses new debt;
then **no FBUN follows** for that lost debt and the target can keep broadcasting.
A crash can also lose unsaved attempt counts. A saved debt waits for **that
character's next login**; an alt on the same Battle.net account cannot settle it.
At login, debts are withdrawn once a matching live client account is handshaken,
even if tracking/source/share is off or the name is no longer on Find.
Still-tracked debts must settle before new asks too.

Queue admission never settles debt. An accepted FBUN client call leaves it
**sent, unverified**: a later, validated direct FBLP from that target without our
GUID in its hunter roster clears it. If a later roster still lists us, LE
invalidates the confirmation used by that send and resends FBUN after a fresh
exchange. A newer, unused confirmation is retained, even if another roster
arrives before the resend. Otherwise the debt clears after
**15 minutes** from an accepted call with no subsequent FBLP listing us. Silence
is a fallback, not proof of delivery. Three failed attempts pause the window;
it reopens every **10 minutes**, with at least 60 seconds between attempts.
At **6 FBUN attempts** in that login (failures included), LE stops sending FBUN
and debt-settlement H/A, retains the debt, and blocks new asks for it. Each
login/reload reopens six attempts; toggling tracking or privacy does not reset
them. A later excluding roster can still clear it; the silence fallback remains
available only for an accepted send that no later roster contradicted. The target
may remain subscribed until a later successful login's cleanup, indefinitely if
no usable exchange occurs, or if the 40-entry oldest-out limit evicts its debt;
LE does not claim success on those paths.

Entering combat or an instance retires the request, but FBUN waits until safe;
the **target may keep broadcasting** for that entire time. No scans or sends
occur in combat/instances. Queued FBUN gets fresh server time at dispatch and
must have handshake confirmation newer than the target's latest H (including
an H observed while waiting), so a target reload cannot reuse an old confirmation.
Known-account data received while unsafe is held in a bounded inbox (128 frames,
256 KiB total), including multipart rosters, and validated before silence can
settle debt. Receipt-time age checks and current-account GUID validation both
apply. This inbox is cleanup-only, not delayed Find evidence. Overflow or input
that cannot be revalidated invalidates that account's silence fallback rather
than claiming withdrawal succeeded; no account scans or sends occur while unsafe.

The **debt-settlement exception** permits only H, A in answer to that account's
H, and the concrete outstanding FBUN, only to live client-resolved accounts in
the owed list. H/A pass these gates only while a withdrawal needs a handshake:
not while merely waiting to verify an accepted FBUN, nor after six attempts.
These may pass share off, WarBoard source off or Guild only; nothing else goes to anyone under those
settings. A generic `owed` priority does not bypass the gates. With the real
WarBoard addon loaded, LE sends **no H or A**: the real addon answers. LE instead
refreshes cleanup confirmation only from an observed valid **H from the target**,
which the real addon answers. The target's A alone does not confirm us at the
target and cannot authorize FBUN or a silence-based settlement. If no target H
or still-fresh established confirmation is available, cleanup waits. All these
frames retain the same rate/safety limits. A genuine confirmation under **20
minutes** old can authorize a new FBAK when tracking and the ordinary send
settings are on; confirmation is not categorically restricted to cleanup.
No cancellation delivery acknowledgement exists: an accepted API call is not
proof of remote delivery. Non-friend account visibility, remote community-roster
acceptance and logout delivery remain unverified and fail silent.

Positions use the existing Find path whether or not we asked: own-client,
relayed, cached and approximate wording remain honest, with no Ask/Hop authority,
new sound or guild relay. No donor code was copied or run. See
[implementation and assertion migrations](notes/warboard-track.md).
Native checks: **not run (alpha, owner's decision)**.

## 1.2.0 - WarBoard

| What LE sends | To whom | Maximum frequency |
|---|---|---|
| `WBF1\|H\|5\|<own ruleset>\|LayerEnemies/<own version>\|0` | Eligible online opposite-faction WoW game accounts on the same realm and client project | At most 20 accounts selected per scan; scans at most once per 60 seconds; at most one H per account per 600 seconds, checked both when queued and when dispatched |
| `WBF1\|A\|5\|<own ruleset>\|LayerEnemies/<own version>\|0` | An eligible account that sent a valid protocol-5 H (including a recognized, different ruleset, so it can reject us) | At most 6 A frames per rolling 60 seconds, at both admission and dispatch; A never answers A |
| Tracking request/cancel | See the E2 send table above | FBAK/FBUN only under the tracking rules; still no forwarding or ordinary-addon/chat send |

**Why the handshake is needed**

WarBoard only sends its data—a player's zone and shard, positions, and kill records—over Battle.net to peers that have completed its hello/answer exchange. A client that never answers a hello receives nothing at all, so reading WarBoard is impossible without it. LayerEnemies sends only that hello and answer, under its own name and version, to every eligible opposite-faction Battle.net friend or community member account that is online in WoW. When LayerEnemies completes the handshake, a real WarBoard client treats it as a new peer and shares its profile, kill streak and board snapshot with its Battle.net contacts, as it does for any WarBoard user. This handshake does not request a position broadcast; the tracking-request section above does.

H, A, FBAK and FBUN use **only the shared Battle.net queue**: together at most 10
WarBoard send attempts/minute and at most **30 attempts/minute across all
networks**, with at least one second between attempts.
WarBoard may hold at most **10 queued frames** across H/A/FBAK/FBUN; eight of
all networks' shared 60 slots are owed-only. Frames older than 60 seconds are
dropped; an unsafe queued FBUN is held until safe, then expired/revalidated
without discarding its durable debt, which can enqueue a fresh withdrawal.
Selection of 20 accounts does not promise 20 sends. Scans rotate in stable
account-ID order, starting after the last accepted hello or unreadable account.
Unreadable identities do not consume the selection cap. A queue refusal does
not spend the 600-second hello cooldown: the account can be reconsidered on a
later scan, without an immediate retry. Accepted frames still keep their
cooldown even if later dropped or refused at dispatch. Owed answers go before
new hellos. Normal H/A and all FBAK stop with `/le share off`, public networks
off (**Guild only**), or the WarBoard source switch off. Only debt-settlement
H/A and FBUN have the narrow exception above. Combat/instances block every send.
Loading the real WarBoard addon stops all LE H/A and discovery, including queued
handshakes; receiving and reading continue, and only owed FBUN can still be sent.
Queued frames
recheck consent, current account eligibility, ruleset and their caps at dispatch;
unknown rulesets are silent. The final `0` is LE's gameplay-rules version (LE
implements none of WarBoard's scoring rules). Discovery itself does not request
a location broadcast; the E2 tracking feature above does.

The independent WarBoard Forever **1.6.3** protocol reader accepts confirmed
`WBF1|D|...` Battle.net traffic and bounded fragments, plus `WarBoard` and
`WarBoardBN` guild/group/channel traffic. Only your Find names and guild Watch
names are admitted through the source registry. No name or peer is saved.

All unauthenticated guild/group/channel routes together share **192 KiB of charged
inflate work per rolling 10 seconds**. Channel traffic can spend at most 128 KiB,
reserving **64 KiB for guild/party/raid**. Confirmed Battle.net peers have separate
account budgets, outside that aggregate pool. Channel-only senders may occupy
only 100 of the 200 input-name slots, so strangers cannot fill the guild's room.

Each normalized sender still has a **128 KiB/10-second** byte limit across routes;
Battle.net also retains its account limit. Only decodes charged **over 2 KiB**
spend the **16 expensive attempts/10 seconds**. After those attempts, decoding
still permits up to 2 KiB per frame, within every byte limit: a burst of 119 small
SHRD reports from one confirmed account is accepted. The separate 120 incoming
frames/sender/rolling minute limit and 2–96 KiB per-type inflate ceilings remain.

A 512-entry, 60-second hash memory suppresses repeated decode failures and decoded
outcomes, **except untracked-name refusals**: adding that name to Find allows the
same previously refused frame immediately. Accepted copies retain replay protection;
`/le net` counts duplicates as both refused and deduped. Unfinished assemblies
remain limited to two per account/sender as well as 16 globally.

- **SHRD:** the sender's own zone and shard. Same-faction
  records are ignored. Its millisecond-like sequence is used for ordering and
  clock-skew checks, never displayed as an observation time; the hint expires
  180 seconds after receipt. An accepted clear removes only WarBoard's SHRD
  evidence, not other evidence for that player.
- **FBLP:** the target's current or explicitly approximate held position,
  zone/subzone and shard. Rank and hunter roster are validated, not imported. World
  coordinates become a map pin only when the client converts them safely to
  that displayed map; otherwise the textual zone still appears. Relays say
  "reported position"; only a matching Battle.net sender/subject says "own position".
- **FREC:** killer-zone hints only, with the record age preserved. The victim
  is never attributed the killer's position. **FBLC / FCBD** location entries
  remain cached; FBLC has no live producer in the audited release. There is no
  leaderboard import.

Accepted hints feed Find's existing **Reported** evidence line and measured row
builder, with source/provenance, location, detail, observation age (or unknown)
and receipt age. Bridge or different-carrier traffic stays relayed; batch hints
stay cached. It never becomes Seen, changes a verified kill count, creates a
sound/alert, enables a hop, hides firsthand evidence, or gets rebroadcast to
LE/WE/HH. SHRD remains zone-only, without a fabricated pin. No live WarBoard
client or native coordinate conversion has been verified; harness geometry is
not a screenshot claim. See [provenance](THIRD_PARTY.md) and
[test evidence and audit rulings](notes/warboard.md).

## 1.2.0 - source registry (no behaviour change)

PR 0b adds extension seams, **no registered source, no new discovery scan and no
Battle.net send**. Presence, Forever Layer Hop and Overlord keep their built
readers and `Main.lua` wiring; OpenMap's Battle.net path is unchanged. A future
source must explicitly register and request work before this queue does anything.

Developer interfaces and integration rules:

- `N.Sources.register{ name, prefixes, onAddon, onBNet, tick, counters } -> bool`.
  Names are lower-case letters (32 bytes); at most 32 sources, 8 prefixes per
  source, 16 bytes per prefix. Registration is atomic and refuses duplicate names,
  duplicate prefixes and every prefix already owned by Main's chain. It copies
  the descriptor; the supplied counter table exposes `heard/accepted/sent/refused/deduped`.
  `onAddon(prefix,text,dist,sender)`, `onBNet(prefix,text,gameAccountId)` and
  `tick(now)` are optional protected callbacks. No callback exception becomes a
  runtime-status error. `/le net <name> on|off` uses the existing saved switches;
  `/le net` appends registered source counters after existing diagnostics.
- `N.Sources.owns(prefix) -> bool`, `addon(prefix,text,dist,sender) -> bool`,
  `bnet(prefix,text,gameAccountId) -> bool`, `tick(now)`, `start()` and
  `lines() -> {string}` are Main's dispatch/lifecycle seams. `has(name)`,
  `enabled(name)`, `authorized(name,prefix)` and `count(name,counter)` are shared
  admission/accounting helpers. A separate **1-second** timer starts only after
  registration: Main's actual inherited heartbeat is 2/5 seconds, not 1 second.
  Its extra `Sources.tick(now)` call is deduplicated against that timer.
- `N.Sources.offer(ev) -> bool`, where
  `ev={name,guid,faction,zone,map,x,y,shard,at,got,kind,net,via}`. `kind` is
  `self|witness|relayed|cached`; `net` is a registered source name. **Times are
  monotonic `GetTime()` seconds**: convert wire/server timestamps in the source.
  `at=nil` means unknown, displayed as such; `got` defaults to receipt time.
  Own Find names use existing name/realm matching (bare names wildcard, explicit
  conflicting realms refuse, missing realm stays labelled unconfirmed). A live
  guild Watch hash also admits the claim; hashes are not proof of exact identity.
  Untracked input never enters Known. Map-percent coordinates must be in `[0,1]`,
  supplied as a pair with a map; `zone` may be a zone name or UI map ID. Metadata
  and original/receipt times survive in Known. Source shard text never becomes
  an LE layer. All these unverified network observations use the existing claim
  slot, with their precise evidence kind retained in `evidenceKind` and detail;
  no new `row.heard`, Ask/Hop target, relay or sound (including later alert polls).
  `self` positions are labelled enemy, other positions observer. A source with
  only online-zone presence uses `Presence.note`, not this sighting gate.
- `N.BNet.peers(now) -> {{id,name,realm,faction,friend,club}}`: on-demand cache,
  30 seconds, friends first, unique game IDs, returned as copies. Requires online
  WoW, this project, `isInCurrentRegion=true`, readable character identity. No
  account names or battle tags. Up to 200 friends / 10 games each; existing
  club bounds remain 20 communities / 1,000 members each. No scans in combat or
  instances. `N.BNet.who(gameAccountId) -> {name,realm,faction}|nil` re-reads live
  client identity; it never trusts an inbound frame's claimed identity.
- New adapters: `A.clubPeer(clubId,memberId) -> bnetAccountId|nil`,
  `A.bnGame(gameAccountId) -> {id,name,realm,faction}|nil`,
  `A.bnAccount(bnetAccountId) -> {id,name,realm,faction}|nil`, and
  `A.bnFriendGames() -> {identity}|nil`, using the existing `presenceRead` guard.
  The four presence readers are byte-for-byte unchanged; peer readers need no zone.
- `N.BNet.send(net,gameAccountId,prefix,text,prio) -> bool`: true means **queued**,
  not delivered. `prio="owed"|"own"` (default own); owed first, FIFO ties. One
  60-entry queue, **one frame/second, 30 attempted frames/rolling minute across
  all networks**, no catch-up burst. Overlord/Wanted/WarBoard shares are 8/4/10
  per minute. Other registered sources get `max(1, floor(30 / registered sources))`
  each; legacy networks outside Sources do not count. The same share caps each
  network's queued frames (both priorities combined): an excess request returns
  false immediately, not a held backlog. New registrations tighten future
  admissions and dispatch shares without evicting already-admitted work.
  **At most 52 queued frames may be normal (`own`): eight slots are owed-only.**
  Owed answers still obey their network's admission and dispatch caps and the
  absolute 60-entry queue bound. Frames **older than 60 seconds from admission**
  are dropped before dispatch, even when a budget is exhausted; exact age 60
  is still eligible. Unsafe queued FBUN waits until safe before this check;
  expiry completes it as unsent, retaining the debt for a fresh attempt.
  Admission requires a readable monotonic clock. Expired/invalidated work,
  admission refusals and refused/failed client calls increment the source's
  `refused` counter and are not retried by BNet itself. WarBoardTrack alone
  retries owed FBUN: 3 attempts per 10-minute window, 60 seconds apart, at most
  6 actual attempts per debt per login. Privacy is checked at admission and
  dispatch. Share off, Guild only and network off block normal sends; the
  debt-settlement exception above allows only H, A answering that owed account's
  H, and FBUN to accounts still owed cleanup. With real WarBoard loaded LE
  sends no H/A. Combat, instances and unavailable live identity block all sends.
  Share/consent/switch off cancels normal held work even if switched on before
  the next timer; owed cleanup survives. Other networks retain their existing
  stand-down answer policy.
  A registered source may send only its prefixes; the reserved exception is a
  future tick-only `overlord` registration sending `OverlordF` without taking its
  existing receiver. Nothing registers that source here.
- Queue internals: `BNet.pump(now)`, `cancel([net])`, `queued() -> count`,
  `allowed(net,id,prefix,text,prio) -> bool` and
  `dispatching(net,id,prefix,text,prio,fn) -> bool`. `Wire.bnet` has the same six
  arguments as `dispatching` and invokes the client only during that private
  delivery. It cannot bypass queue admission. There is exactly one
  `C_BattleNet.SendGameData` lookup, in BNet's local `deliver`; the actual call
  occurs in Wire's caller frame. `verify.py` permits this one lookup only there;
  all legacy BN sends and all other files remain forbidden. The existing
  `SendAddonMessage` route gate is unchanged.

**Future source files** load immediately before `UI.lua` in the TOC. Add tests as
`test/src_<name>.lua`; the harness discovers them in sorted order and passes its
shared fixture table. Use `lua test/harness.lua --only '<literal substring>'` or
`--only=<substring>`; empty/no matches and unknown arguments fail closed. Old
`--x-only` spellings remain compatibility aliases for existing mutant scripts.
Use `python3 test/source_mutants.py` for this seam's mutants only.

**Measured rows, not appended text:** source details belong in the existing Find
report/detail projection (`Main.findDetails`) before `UI.refresh` builds
`layouts[e]`. That pass measures with `U.measure`, computes `subHeight`, place /
presence heights and `layout.height`, then paginates. Rendering consumes only the
measured strings. A future extra line must be prepared and measured in that same
pass, never appended after `rowHeight`/paging or by a source's own `SetText` call.
No UI code or appearance is changed by this seam.

Forever Interface 16001; API declarations checked at build 70938, commit
`bebcb6bf309cf41b41bd74f8ca651e6a105b2676`. **Native checks not run (alpha, owner's
decision)**; a readable API identity or accepted send is not proof of live peer
availability or transport delivery.

## 1.2.0 - Forever Layer Hop membership

| Send (`FLHNET2`) | Route and target | Trigger | Hard limit |
|---|---|---|---|
| `HI`, host flag **0** | GUILD; PARTY or RAID | First verified own identity after login, then own fingerprint changes | 1 per 120 s for guild; 1 per 120 s for group (PARTY/RAID share a lane) |
| `WR`, host flag **0** | WHISPER back to a `WP` sender | Owed reply | WR + CA share 6 per rolling minute and 1 per sender per 60 s |
| `CA`, host flag **0** | WHISPER back to a `CQ` sender | Owed reply | Same shared reply caps as WR |
| `WP`, host flag **0** | WHISPER to a name from the read-only `ForeverLayerHopNet` directory | Friendly hop window open, no other hop pending | 4 per rolling minute; each name once per 600 s; at most 1 per tick; **none during a hop-any round** |
| `LQ` | WHISPER to fresh, same-zone FLH host claims | Explicit row click / `/le hop host N`; `/le hop flh` selects a bounded batch | Named click: 1. Batch: at most 7; sends only available shared capacity minus one reserved LR token/rolling-minute slot, then paces unsent queries inside the original 90 s; existing hop click/name cooldowns and Wire hop caps apply |
| `LR` | WHISPER to the asked host whose matching `LO` was selected | Same click, first valid offer within 90 s | One selected host; only success spends the selection. A send-limit refusal waits for budget/pause clearance and retries at most twice within the original click window |

The LR reservation is shared with ordinary LE traffic and FLH replies; it never increases any ceiling. It is released after a successful LR, cancellation/final refusal, or the original 90-second deadline. Once an offer is held, remaining discovery stops rather than contacting extra hosts. Duplicate offers do not redirect the host, renew the window or consume retries. If the LR cannot finally be sent, the row retains a send-limit note and chat prints exactly once: `LayerEnemies: hop request to <host> could not be sent (send limit); click again`.

**Read-only directory join:** F2 joins `ForeverLayerHopNet` only for its member list, as explicitly approved in plan section 10.2. It never sends to that channel (or any channel), never joins at Guild only, never re-joins after a manual leave, and never leaves a channel the player joined. The existing channel-slot, combat, instance and Channels-window guards apply to joins and reads. Once joined, it stays joined through combat and instances; only sends/probes pause. Privacy/owner changes leave our channel when out of combat and instances.

All six kinds go through **Wire** and count toward its existing **8-at-once shared bucket (1 token per 1.5 s)** and **40 per rolling minute** ceiling. FLH whispers, including those to guildmates, also share the existing **20/minute public budget** and **4/minute per-person budget**. Probes leave six shared tokens, six shared minute slots and six public slots for owed replies, and rotate round-robin over eligible directory names. A probe refused by the local send gate does not spend its 600-second name cooldown; an actual client attempt does, even if the client refuses it. Separate reply/probe/presence ledgers only tighten those ceilings; they are not extra allowances. Membership does not spend hop-any tokens, so the existing hop-any fan-out keeps its separate 8-then-1/s cadence. Guest LQ/LR additionally use that unchanged hop ledger (8 burst, 1/s refill, 60/minute, 4/minute per target); no FLH sends are queued or automatically retried.

`/le share off`, `/le net flh off`, combat, instances and unverifiable live state silence all FLH sends. **Guild only** retains guild presence but permits no group presence, whispers, probes, guest requests or directory join. `/le net flh on|off` is a **session-only** switch: reload restores on, without a new SavedVariables field.

**Donor loaded:** when the real `ForeverLayerHop` addon is loaded, LayerEnemies sends **nothing on FLHNET2** (no HI, WR/CA owed replies, WP probes or LQ/LR) and does not join `ForeverLayerHopNet`. Incoming FLH data are still received and read. The real addon alone owns this player's outgoing state, so two clients cannot overwrite each other's state at peers.

Identity and `BUILD` fields say **LayerEnemies and its installed version**, never an FLH version. The outgoing fingerprint is our verified current-zone NPC GUID field 5, not our server-layer key. Unknown or ambiguous own fingerprints defer presence and replies rather than guessing. Incoming FLH keys remain labelled claims; they never become a general host flag or a LayerSwap/Bulo layer key. Known-layer rows still sort first.

Guest requests correlate the id, sender, zone and requested fingerprint. An unsolicited, same-fingerprint, wrong-zone or late offer grants no authority. Only the selected host is armed for the existing invite acceptance path after LR succeeds; pre-offer invites, other queried hosts and foreign-realm namesakes are not auto-accepted. A matching `LI|id|S|leader` from that host replaces invite authority with **only that named leader**, without extending the same 90-second window; a hand-off without a valid leader accepts nobody. `LD` (declined), `LA` (didn't answer), `HQ` (queued) and `LN` (with or without a reason) from the selected host cancel the click and print one status line. `/le hop stop`, privacy changes or movement revoke the request. The existing confirmed-move/failure leave rules are unchanged. This guest session expires at 90 seconds from its first successful LQ (also narrowing invite acceptance below the existing 120-second ceiling). A 90-second timeout is shown in the measured Friendly row. `/le hop any` keeps its existing fan-out; `/le hop flh` is an explicit separate guest action and cannot overlap it.

**Never sent:** host offers (`LO`), host invites, `PX`/`PR`/`PI`, other players' name lists, chat messages, channel messages, guild copies of hop queries, or invented FLH identity. No saved names or new SavedVariables. Memory is bounded (64 host claims, probe names, reply/probe rate entries and status rows; at most 7 guest targets). Donor code is All Rights Reserved: protocol facts only, independently written code; pin and attribution in `THIRD_PARTY.md`. Real-client interoperability remains unverified; a peer that rejects our honest identity simply times out. A real Forever Layer Hop client on another realm that hears our messages may introduce our name, realm, map and layer on its own realm's channel, as it does for any Forever Layer Hop user; this is an accepted membership side effect. LE ignores peer-exchange messages and discloses no other players.

The API ownership gate is unchanged: only Wire calls SendAddonMessage or party APIs; SendChatMessage remains forbidden. `test/verify.py` adds an exact route-table allow-list containing the five existing prefixes unchanged plus **FLHNET2 on GUILD/PARTY/RAID/WHISPER only**. No other API exception is added. The route gate consumes one complete literal declaration (no computed fields), freezes every private table/route alias access, and rejects both field-iteration writes and computed replacement routes. See `notes/flh-batch-hop.md`, `test/src_flh_batch.lua` and `test/flh_batch_mutants.py` for the batch-load replay, shared-ceiling assertions and portable RED/GREEN/mutation evidence; `notes/flh-membership.md` and `test/src_flh_member.lua` retain the original membership coverage (including 5,000 deterministic fuzz frames).

## 1.2.0 - Forever Layer Hop receive-only

This is the historical F1 checkpoint. F2 above supersedes its no-send/no-hop restriction, not its receive validation or fingerprint provenance rules.

Without Forever Layer Hop installed, LE listens on `FLHNET2` for the direct
`HI`, `WR` and `CA` presence lines on GUILD, PARTY, RAID and WHISPER. Only
an explicit host flag of `1` with a readable map and fingerprint adds a host.
Flag `0` or a well-formed unknown place removes that sender's previous FLH
host. Other sources for the same player are left alone. Malformed and unknown
lines are silently ignored, as are ignored players, our own echo, combat and
instance traffic, and unreadable identity/context.

Hosts appear in **Friendly** and `/le hosts` for your current zone, labelled
**Forever Layer Hop** and **FLH key … (claim, … ago)**. This is same-faction
host presence, not an enemy sighting. The decimal fingerprint is GUID field 5
(zoneUID), **not** the field-3 server key used by LayerSwap/Bulo. LE keeps it
separate: no invented server layer, no same/other-layer inference from FLH,
and no promotion to a LayerSwap host. If another source already lists the
same whole player name, the row keeps that source's server layer and age,
with the FLH claim and its age alongside it. Long fingerprints are abbreviated
with `...` in the display only; their stored spelling is unchanged.

FLH presence is session-only, bounded to 64 hosts, and removed at **180 seconds**
from receipt (also on clock rollback). Unknown own layer still shows the host
with the existing action-disabled hint. An FLH-only row has the existing manual
**Ask for invite** flow once your layer is known; it does not offer an automatic
FLH hop. Same-layer filtering from other, comparable sources still applies.

**No new sends, joins, scans or SavedVariables.** Registration is for receive
only; the outgoing route allowlist is unchanged. The decoder also understands
`WP`, `CQ`, `LQ`, `LO`, `LR` and `LN`, but none is answered, used to select an
invite, or added as a host in this slice. Both `|` and `:` delimiters work;
empty positions stay in place and optional `KEY=value` metadata is ignored.
Lines over 255 bytes, invalid numeric fields and non-decimal fingerprints are
refused. The version string is not a compatibility gate.

In practice this slice hears guild/group broadcasts: it sends no discovery or
membership traffic, so it cannot expect unsolicited whisper answers. Automatic
FLH membership and hop requests belong to PR 3b, after hop fan-out integration.
Protocol interoperation only, no donor code copied; see [THIRD_PARTY.md](THIRD_PARTY.md).
**Not tested in game (alpha, owner's decision).** Actual host availability,
Forever transport-name spelling and native text layout remain unverified.


WoW Forever addon 1.2.0, Interface 16001, Lua 5.1.

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

## 1.2.0 - Battle.net community and friend presence

Find now reads the Battle.net communities you already belong to and your
Battle.net friends. It adds `online (community)` or `online (friend)`, a zone,
and the age of our read. Presence text uses its measured height, so a one-line
presence-only card is as compact as a normal one-line card and wrapped zones
still fit without overlapping. Mixed Find cards also measure the complete
claim text before placing presence; assumed per-claim boxes do not add empty
space. It joins nothing and sends nothing: no new addon
messages, chat, Battle.net data, presence subscriptions, or `/who` by name.
There is no per-community Watch button. No donor addon or donor code is used.

- Reads start every 300 seconds while your personal Find list is nonempty,
  and when you open the Find tab/window. Tab switches and window reopens share
  a forced-refresh limit of once per 60 seconds. An active scan is not duplicated.
  No roster reads in combat or an instance, or when either safety check is
  unreadable; an in-progress scan stops at its next tick.
- At most the first 20 subscribed club entries are inspected. Only Battle.net
  communities are read, never guild/character clubs. This is intentional:
  character communities are same-faction. Each community contributes
  at most 1,000 member IDs, with at most 50 member-info reads per timer tick.
  The friend reader checks at most 200 accounts and only accepts online game
  accounts whose `wowProjectID` equals this client's `WOW_PROJECT_ID`.
- A readable character name, realm, zone, and opposite faction are required.
  A community member's `bnetAccountId` is used only for
  `C_BattleNet.GetAccountInfoByID`; offline, mobile, unknown and unreadable member
  presence are skipped before any account lookup. Its `gameAccountInfo` supplies the character,
  realm (`realmName` or `realmDisplayName`), zone and faction. It must be online
  in `WoW`, and community presence must be Online, Away, or Busy. A club member's
  display name is never a character match. Account IDs are not saved or printed;
  no account names, battle tags or member notes are read. Missing, secret,
  malformed, or erroring resolution fails silently, without a fallback name.
  Same-faction matches are deliberately dropped: a namesake must never become
  an enemy claim. The friend route keeps its existing online/project gate.
- Your personal `Name-Realm` entries require that realm; a bare `Name` accepts
  any realm. OpenMap's existing exact matching is unchanged. Guildmates' shared
  watch hashes can also produce **possible guild watch match** rows, never
  definite identity claims: those lists omit realms and can collide. One
  current character is retained per shared hash, removed when the hash is no
  longer shared. Shared lists alone do not start scans with an empty personal
  Find list. Their rows do not change your saved personal list.
- Presence adds no layer, coordinates, reporter, Ask or Hop target. Existing
  sightings and OpenMap positions keep their own status, age and actions.
  A reread replaces that source's old evidence immediately, including offline,
  non-WoW, incomplete or unreadable character results. Only sources not visited
  keep their old evidence until 660 seconds (or a backwards clock). A source
  token is session-only (club/member pair or friend-list slot); no account
  identity is retained. Other-source evidence is not withdrawn by that token.
  Read age is **not** a guarantee of the server's presence freshness.
- A newly read match can print one local chat notice per name per 600 seconds,
  through Find's existing three-lines-per-ten-seconds burst throttle. No sound.
  All presence data and notice history are session-only; no new SavedVariables
  player names. Nothing is fed to the guild, relay, host or sighting stores.

`/le presence` prints counts only: clubs read, community members read,
resolved to a character, with a zone, opposite faction, matches (all sources),
secret refusal flag and refusal count. Resolution requires a valid character
and realm; zone and opposite-faction counts show the later admission stages.
Thus zero matches is distinguishable from nothing resolvable. The community
stage counts exclude friends; matches explicitly includes both sources. No
names or zones are printed, and the diagnostic never starts a scan itself.

The target remains Forever, Interface 16001. Contracts were checked against
`Gethe/wow-ui-source@bebcb6bf309cf41b41bd74f8ca651e6a105b2676`, build
`1.60.1.70938`. **Not tested in game (alpha, owner's decision).** Whether
opposite-faction community accounts resolve to characters/zones/factions without
a subscription, how fresh those fields are, and live chat-lockdown restrictions
remain unknown. Released in 1.2.0.

## 1.2.0 - Overlord (receive only)

Independent reader of **Overlord Forever 2.5.1** (`OverlordF`), with no donor
addon required or code copied. No new sends, replies, presence, forwarding,
channel joins, SavedVariables or membership. `Wire.lua` and the verification
send gate are unchanged. Reception works with or without Overlord installed.

- **Reported / `/le reports`:** opposite-faction `GW` guild rampages show
  `guild <name>: <kills> kills by <members> in <zone>, layer <n> (Overlord claim)`.
  One row per guild, at most 32, expiring 300 seconds from the source timestamp;
  zone/layer changes do not erase them. Only `#<uiMapID>` can resolve a place.
  `@front`, capture-zone IDs and unresolved maps say **place unknown**; an empty
  layer stays unknown. A claimed layer never creates a Hop or host target.
- **Find:** `GD` names a General's killer; `EK` names a groupmate's killer.
  Only killers matching your Find list or an unexpired guildmate shared watch
  list enter session memory. Own-list matches appear as **named as killer
  (claim)**, with zone and source age, for at most 60 minutes. Shared-list-only
  matches are retained for Find if you add that name; they do not add names to
  your saved list or create a general enemy board. Existing first-hand evidence
  and its legitimate Ask target retain priority; these claims never grant Ask.
- GUILD reads **BF relay fragments only**. PARTY/RAID also read direct `GW`,
  `GD`, `EK`. `EK` is direct group traffic only, never a guild/relay kill feed.
  WHISPER, CHANNEL, Battle.net bridges and all other payloads are ignored.
- Frame limits: 255-byte whole line (252 after `BF:`), 64-byte alphanumeric/
  hyphen ID, integer `1 <= part <= count <= 24`, and 230-byte chunks. We accept
  only one or two parts: 32 pending assemblies, oldest evicted at capacity,
  30-second lifetime from the first part (duplicates do not extend it).
  Completed assemblies are removed. Sender and ID isolate each assembly.
- Packets have exactly seven pipe-separated fields, matching envelope ID,
  broadcast target `*`, 1–4 distinct path nodes ending in the transport sender,
  and at most 3,600 bytes (our two-part receive limit is tighter). Age 120 seconds
  is accepted; 121 is refused; future skew is limited to 30 seconds. The packet
  pool must exactly match our readable ruleset pool: PvP `global`, PvE `pve`,
  RP `rpg`, RP-PvP `rpv`, or Hardcore `hc`. Game rules and explicit realm-name
  labels determine it; an unknown pool is never guessed as PvP. While our pool
  is unknown, all Overlord receipt (including direct group lines and partial
  fragments) is silently refused. `GD`'s payload pool must also match. An
  origin/ID ring remembers the last 256 accepted packets.
- `GW` payloads are capped at 200 bytes, guild names at 24, kills 50–9,999,
  members 5–999, layer 0–99,999,999, and zone references at 40 bytes. Its source
  timestamp may be 300 seconds old. We conservatively cap future skew at 30
  seconds for all three payloads, stricter than Overlord's GW payload allowance.
  `EK` admission is limited to 120 seconds old. `GD` carries **General claim
  time, not death time**; we preserve that conservative age and discard it at
  60 minutes rather than invent a recent killing time. Relayed GD must still
  pass the separate 120-second envelope check. Small accepted future skew is
  clamped to receipt time, never displayed as a negative age.
- Nothing is decoded/scanned in combat or instances. Unreadable gates, secret
  values, malformed fields, controls, oversized or stale lines fail silently.
  `/le net` adds **Overlord session: lines / taken / refused** counters and
  the currently detected pool tag, or **pool unknown (receiving nothing)** when
  detection is unavailable. These counters count eligible transport lines,
  accepted payloads and refusals; waiting
  fragments and duplicate packets do not count as taken or refused.

Offline coverage: `test/overlord.lua`, `test/overlord_mutants.py`, and the
unchanged `python3 test/verify.py`. No native test is a gate: **not tested in game
(alpha, owner's decision)**. Traffic availability, live map resolution and
native rendering remain unknown. If no guildmate/groupmate runs Overlord (or
its messages never arrive), nothing new appears; the counter stays at zero.

## 1.2.0 - Hop to another layer: up to 49 players per click

**Hop to another layer** asks up to **49 players per click**, with
**10 seconds between clicks**. One zone WHO query supplies the names; a hidden
**Who window is suppressed** while our query is handled. A Who window already
open when you click Hop is left registered and shows the hop's query result,
just as it does with LayerSwap. Known hosts go first,
then same-zone names, then the remaining WHO rows. These are real hidden
invite requests, including to players not known to run a layer addon.

The click owns at most **45 rounds**, **1 second apart**, **8 attempts per
round**. Its dedicated Wire allowance permits 8 initially, then about 1 per
second (60 per minute). A fan-out throttle retains the head for the next
round and pauses ordinary LayerSwap whispers for 30 seconds. A client throttle
on a named hop or reply stops this click's fan-out; a new click is needed after
the prefix pause.
Same-zone hosts that answer with an unknown layer may be re-asked once without
an exclusion after the queue finishes (+3 seconds, or +10 if a known
alternative-layer host is still being given time). No additional WHO query
starts automatically. Existing Hop, Hop via <name>, Ask guild and auto
accept/leave behavior are unchanged. No saved field or version bump.

## Shared codecs (1.2.0; used by WarBoard, WarBoard tracking and Wanted)

`LayerEnemies/Codec.lua` provides independent, pure-Lua wire codecs through the
addon-local `N.Codec` table. This foundation does not register a prefix, send a
message, create a queue, or change `Main.lua`. No LibStub or donor installation is
required. The public interface is:

- `inflate(bytes, maxOut?) -> string | nil`: raw RFC 1951 stored/fixed/dynamic
  blocks; default/hard output limit 262144 bytes. A caller may lower it, including
  to zero. Compressed input is limited to 262169 bytes. Trailing streams/bytes,
  invalid trees, distances, repeats and truncations are refused. A 4194304-token
  work budget charges bit reads, output, tree entries and 1024 tokens per block;
  an otherwise valid stream can also be refused by that budget.
- `deflateStored(bytes) -> string | nil`: input <=262144 bytes; valid raw stored
  blocks of at most 65535 bytes, output <=262169 bytes. No compressor is needed
  for the planned sends. Highly incompressible output from *other* encoders may
  exceed the compressed-input ceiling even when its decoded size would fit.
- `addonEncode(bytes)` / `addonDecode(bytes) -> string | nil`: LibDeflate addon
  channel byte escaping (`00 -> 01 02`, `01 -> 01 03`). Both input and output are
  capped at 262144 bytes. Literal NUL and invalid/truncated escape pairs are
  rejected on decode; this is binary escaping, not Base64.
- `aceRead(text)` / `aceWrite(table)`: AceSerializer revision 1, used by WarBoard.
  Reads return a table or nil; writes return bytes or nil.
- `lsRead(bytes)` / `lsWrite(table)`: LibSerialize version 1 output, versions 1
  and 2 input, used by Wanted. Readers handle every type-byte family, IEEE
  binary64, compact integers, arrays/maps/mixed tables, string/table references.
  The minimal writer emits maps, references and exact decimal float forms;
  byte ordering is not canonical.
- `aceCommJoin(st, key, text) -> whole | nil` and
  `aceCommSplit(bytes) -> frames | nil`: AceComm first/next/last/escape controls.
  Keep one plain `st` per transport consumer and set `st.now` to monotonic seconds
  before **every** join. A missing/invalid clock refuses input; rollback drops
  pending streams. Use an unambiguous key containing the **full sender, prefix
  and distribution**, without realm stripping. Keys <=256 bytes, frames <=255
  bytes, 16 concurrent streams per state, 32768 assembled bytes/stream, 256
  fragments, and a 30-second **total** lifetime (not idle timeout). First replaces
  that key's old stream; orphan continuations are ignored; completion releases
  capacity. Reserved controls clear only that sender's stream. Split returns
  physical frames but sends nothing. Nil means pending **or** refused.

Serializer limits apply on both sides: one root table, 262144 input/output and
expanded string bytes, table nesting 8, 2048 entries/table, 4096 total logical
values (including keys and the root). Wire values are separately capped at 4096.
Acyclic aliases and table keys are supported; cycles, metatables, non-finite
numbers, unrepresentable 56-bit integer payloads, duplicate keys and trailing
values are refused. This is an intentionally bounded network-envelope subset,
not a drop-in arbitrary-object library. Ace formatting whitespace is accepted;
other permissive upstream malformed-input behavior is not reproduced. All public
functions return nil rather than propagating malformed-input errors. Secret
checks use the existing `Safe.secret` boundary; no direct client APIs are called.

Both audited network formats use raw DEFLATE and addon escaping. Zlib/gzip and
EncodeForPrint are not needed here; WarBoard's printable campaign import/export
is outside this network slice. [Format credits](THIRD_PARTY.md) and
[implementation evidence](notes/shared-codecs.md) identify the exact sources.

Offline checks (Lua 5.1 path may be set with `LAYERENEMIES_LUA`):

```sh
python3 test/codec_vectors.py
python3 test/codec_check.py
python3 test/codec_mutants.py
python3 test/verify.py
```

The codec gate includes independent Python format/zlib vectors, constructed audit
payloads, malformed inputs and bombs, 5000 seeded random inputs per public
function, mutation checks, and an offline 4000-byte/16.667-ms frame-budget test.
The existing send-policy gate is unchanged. Native-client testing was not run
(alpha, owner's decision); offline results are not in-client timing claims.

## 1.1.0 at a glance

Everything since 1.0.1, with the sections below and the reference chapters
holding the detail:

- **Find:** names match without regard to case; up to 20 names; realm names
  (`Name-Realm`, `First Last-Realm`); a one-hour session memory with
  `last known` lines; a `Seen by you, layer unknown` state; a tracked player's
  self-shared OpenMap position (cross-faction) on its own line.
- **Guild death calls:** a call popup under the minimap when a guild death
  names an enemy killer (Guild Bounty, Wall of Shame, or a guildmate's `K`
  line); on by default, `/le call off` turns it off. Your own PvP death shares
  one `K` line with your guild.
- **Hop to another layer:** one click (or `/le hop any`) may send up to 8
  hidden addon requests for an invite, including to players not known to run a
  layer addon.
- **Guild intelligence:** crowds are shared in up to three lines without
  repeats or inflated counts; Spy sightings heard in your group and HeadHunter
  kill records from the HeadHunter network are relayed to the guild as claims; a shared watch list tells
  you when a guildmate may be tracking the player you just saw.
- **New guild messages (all on the existing LEGW1 GUILD route):** `K` (own
  death), `R|1|spy|seen`, `R|1|hh|kill` / `killi`, and `T|1` (watch list as
  6-character hashes). `/le share off` stops every guild send, relays and the
  watch list included. Relays leave room for one of your own lines (two out
  of combat).
- **Upgrade notes:** saved settings carry over. An older client keeps only the
  first five Find names and drops realm-qualified ones. Older clients ignore
  the new message kinds.
- Not tested in game (alpha).

## 1.1.0 - shared watch list and on-site notice

**Rule for review:** "LayerEnemies now sends each member's Find names to
the guild on LEGW1. This is a new kind of guild send. Guild route only, plain names, default on,
with a per-user opt-out."

**Wire clarification:** the approved compact format below sends **six-character
hashes**, not plain names. The quoted rule records the new sharing policy; hashes
are not secrecy: a guildmate can test a guessed name against a list.

Your up-to-20 Find names are shared only on **LEGW1 / GUILD**. The hash is the
32-bit `Hash.hash3` loop encoded as six little-endian base-62 digits, applied to
`Find.fold(name)` **without its realm**. The name you actually see is what the
notice prints. **The same name on another realm also matches for notices and
forwarding priority. Your own Find rows retain their strict realm rules.** Class
and level never establish a match.

- `/le find share off` sends one clearing line when guild sending is available,
  then stops list refreshes. `/le find share on` resumes. Find still works locally,
  and you still use other guildmates' lists. Saved per character as `findShare`,
  default on; a saved off choice stays silent after reload.
- `/le find notice off` silences the on-site chat line; `on` restores it. Saved as
  `findNotice`, default on. It does not change your list sharing or Find alerts.
- Bare `/le find share` and `/le find notice` show `on|off` usage; neither adds a
  player name or advertises a hash.
- `/le share off` also prevents T sends, including an owed clearing line; it waits
  until sharing resumes. No T in an instance or outside a readable guild. Existing
  Wire rules still apply. `/le net guild` permits this guild-only route: it is not
  a blanket guild-send prohibition and does not require either public network.

The line is `T|1|<id>|<part>|<parts>|<hash6><hash6>...`. Its two-character id changes
with content. Up to 39 hashes fit per line; 20 distinct base names fit in one
`1|1` line. `T|1|<id>|0|0|` clears the sender. Same-base realm variants need only
one shared hash. A receiver accepts up to 100 hashes in three parts, replacing
only a complete set. A new id replaces an incomplete set; incomplete sets expire
at 120 seconds. Malformed, fourth-part or over-cap sets discard only that incoming
set, not the previous complete list. At most 200 sender slots (including partial
sets) are held. The hash-to-senders lookup is updated on changes, never rebuilt
per sighting.

Lists and notice history are **session-only**. Complete lists expire 25 minutes
after their last complete refresh, disappear on clear or guild leave/switch, and
are removed when a complete roster update no longer lists their sender. Further
T lines from absent senders are refused until a complete update lists them again.
Offline members remain; an unreadable roster proves neither departure nor
readmission and preserves the last complete snapshot. A reload starts with
no held lists. Older clients ignore T; there is no request for others' lists.

A nonempty list is sent 20–80 seconds after login, 10 seconds after the last edit
(no earlier than its initial login delay; at most one content send per 60 seconds),
and every 10 minutes with ±120 seconds of jitter. Ten quick adds coalesce into one
send. An initially empty list is silent; removing names sends a clear. T has a
hard **three actual attempts per sliding minute** limit, including client refusals.
A blocked T waits in one bounded, coalescing owner queue and retries through Wire;
it is not a dropped forward or a second, independently draining Wire queue.

Listed enemies (your own or a guildmate's) go first among eligible names in O
bursts. List changes and refreshes never bypass the **60-second per-enemy
cooldown** or put already sent names back ahead of an unsent cohort. Nine
continuously seen enemies, four listed, still all leave in the three-line burst;
list churn cannot starve the other five. War Effort C+E retains its independent
per-enemy cooldowns and public admission path. O stays at one line per 15 seconds
and three attempts per burst. Listed R relays go first and lose pending/bucket
contention last; their caps and stand-down stay unchanged.

When you yourself see a guildmate's tracked enemy, one quiet chat line says:
`LayerEnemies: <name> may be tracked by <guildmate>` (or `and N others`). All
on-site notices use hash-only evidence: collisions and same-base names on other
realms cannot prove an exact identity. There is no exact-name notice path; local
Find's exact-name matching remains unchanged. At most one notice per name per
ten minutes, three per sliding minute overall; never in an instance,
for your own tracked names, or from reported/relayed sightings. No sound, frame,
map pin, ask, or hop is added by this notice.

**Budgets:** Wire is unchanged: 20 GUILD sends/minute within 40 overall, five-token
prefix burst refilling one per two seconds, eight-token overall burst refilling
one per 1.5 seconds, queue cap 40; combat doubles cost and halves minute caps.
T normally uses one line per ten minutes (0.5% of the guild cap), one in a send
minute (5%), at most three (15%). O remains at most four/minute. The planned
combined budget with the separate Spy/kill relay lanes is 4 O + 6 Spy R + 4 kill R
+ 1 T = 15/20 (17/20 at the T hard limit); those two relay additions are not part
of this change. Thirty simultaneous logins spread 30 T lines over about a minute,
then average three/minute guild-wide; 100 members average ten/minute. Memory
estimates from the design, not measured: ~250 KB at 200×20 hashes, under 40 KB for
30 members, ~1.2 MB at the hard receiver caps. The last complete membership
snapshot adds at most 1,000 canonical sender keys (the existing adapter cap);
it is session-only and is discarded on guild reset.

Native delivery/throttling and roster completeness: **not run (alpha, owner's
decision)**. Client acceptance is not a delivery acknowledgement.

## 1.1.0 - Hop to another layer

**Changed rule:** "one hop request to one host ... No retry, no fan-out"
previously applied to every hop. One **Hop to another layer** click may now
send up to **8 requests to players not known to run any layer addon**.
There is still no retry, timer-started search, automatic second round or
request without a click. Existing Hop, Hop via <name> and Ask guild actions
keep their single-target / player-sent behavior. This bounded exception is
reviewed on its own, independently of other feature changes.

## 1.1.0 - guild death calls and own-death sharing

**Call popups and their sound are ON by default for both new and existing
users.** Turn them off with `/le call off` or the window's **Call: on/off**
button; `/le call on` turns them back on. The per-character choice survives
reload. This is independent of Share and the network switches.

A Guild Bounty death with a killer class, or a Wall of Shame death whose
killer is an opposite-faction player in your current local seen store, can
show a call under the minimap. A class-less Guild Bounty death needs that
same local proof. Unknown/creature killers, Forever Told sightings, your own
death and HeadHunter D frames never trigger your own popup. A guildmate's
validated LEGW1 K1 own-death line can also trigger it: two LayerEnemies-only
guildmates need no incident addon. No death line is answered, relayed or made
an ask/invite candidate. Receiving a line never adds a name or location to
Find automatically; only On my way can add a full killer name.

New send: K own-death line, LEGW1/GUILD, share switch, 1 per 120 s.

After PLAYER_DEAD, snapshot the zone, position and known layer, then try the
optional C_DeathRecap at 0.3, 1 and 2 seconds. Only a player-type AND hostile
source proven opposite faction qualifies: a current local seen entry by GUID
or exact name, or an unambiguous original Alliance/Horde race returned by
GetPlayerInfoByGUID. Neutral/custom races are unknown. A directly seen
same-faction source stays refused even if its race metadata disagrees.
Missing/secret required fields, empty recap, mob-only, fall, drowning and
same-faction duel deaths send nothing, without errors or target guessing.
Every death records the recap row fingerprint, even when it cannot send: at
death, at 0.3/1/2 s for every death (these record-only looks keep running after
a cancel such as share off, a zone change or leaving the guild), and again on
revive (whatever recap is held then belongs to the death that ended). Rows are
owned one by one: a row's identity is its source GUID, source name and
timestamp (damage, overkill and flags are ignored, so an old row shown again
with edited numbers stays old), and a row first seen on an earlier death can
never name the killer, whatever else is in the set. Repeated PLAYER_DEAD events
before PLAYER_ALIVE or PLAYER_UNGHOST are the same death: they do not restart
its snapshot, retries or incomplete-recap suppression.
Rows already seen on an earlier death in this session are refused; every
PLAYER_ENTERING_WORLD also marks the held recap as old (login, reload and
loading screens, not only the first world entry). Stale or ineligible rows
leave the remaining retries active, so only a fresh qualifying set in the
window can send.

Known limits (a missed line is accepted; a false killer is not):
- Environmental killing blows (falling, drowning, fatigue, lava, or another
  readable row without a source GUID/name) are not announced, even if a player
  hit appears in the same recap. Once recorded, that killing blow keeps its own
  death silent even if a later look omits it; it does not suppress the next death.
- Two deaths within 2 s: the first death's record-only look can take the
  second death's rows, so the second death sends nothing.
- A genuinely new death whose row matches an old row's source and timestamp
  exactly is treated as old and sends nothing.
- A genuinely new death whose killing row is not stamped later than every
  earlier death's recorded rows (a recap clock that runs backwards) sends
  nothing.
- Rows visible only between two looks (for example from 0.1 to 0.2 s after an
  unannounced death) are never recorded. If they come back at the next death
  and no row on record from an earlier death is stamped at or after them, they
  are taken as that death's rows. Recap timing on the live client is unknown,
  so this is not fully closed.
- After a death whose recap held a row that could not be read, or more than
  256 rows, all following deaths stay silent until the next login or `/reload`.
  The cost is deliberate: after one unreadable recap, no later own-death line
  is sent until you relog or reload, even for a genuinely new killer. Loading
  screens do not restore death lines, whether their recap is empty,
  unavailable, fully readable or shows only other rows. Other rows at death B
  cannot prove that death A's hidden row is gone, so a newly readable A row
  cannot name death C's killer.
  Every PLAYER_ENTERING_WORLD still records visible recap rows as old, but
  only one with readable login/reload flags (isInitialLogin or isReloadingUi
  true) clears previous suppression. Missing, secret or unreadable flags do
  not clear it. If that login/reload seed itself has unreadable or excess
  rows, suppression starts again. Revive, ordinary zone/instance loading
  screens, zone-change and SHARD_TRANSFER events never clear it.
- Not covered: a recap that first appears after revive, or a death before the
  first world-entry seed.
- Across a relog or /reload: memory starts empty, so a hidden row from a death
  before the relog that the login/reload seed cannot see (recap empty,
  unavailable, or showing only other rows) and that becomes readable at a later
  death can be named. Closing this would need saved state; whether a recap
  survives a relog on the live client is unknown.

The
session history holds at most 256 recap rows; at the cap the oldest-stamped row
is forgotten. The highest recap timestamp ever recorded is kept and never goes
down. When a death starts it is fixed for that death: a row the new death sees
for the first time, stamped at or below it, happened before this death began.
It is recorded as old and never names a killer, even if the cap has forgotten
the original row. Only recap timestamps are compared with each other; no
client clock is used. A readable row with a nil or empty source GUID or name
is still recorded, using its timestamp and whichever source fields exist (not
amounts). It is readable and never names a killer; an ordinary environmental
hit does not make a death incomplete or silence later deaths. A row
whose identity fields cannot be read (secret or erroring), or whose timestamp
is missing or not a readable number, is never recorded, owned or named; the
readable rows of the same recap are still recorded. A secret/erroring overkill
read on a no-source row also makes that row unreadable. A recap longer than
256 rows names nothing. Because an unrecorded row could come back readable,
following deaths treat every row they see first as old until the next login
or `/reload`. Any incomplete look, including a retry or revive read, keeps
this suppression across loading screens for the rest of the Lua session;
complete later deaths never clear it. Each seed records visible rows as old
without discarding the recorded history or lowering its timestamp high-water
mark. Nothing is saved.
Known misses: an enemy pet alone (no owner resolution), empty/late recaps,
and unavailable faction/identity data. Accepted over-count: a mob landing
the last hit while an enemy player was hitting counts as PvP.

The full killer name is sent only when our seen store has it for that GUID;
otherwise the recap name is marked partial (`p`), shown but never added to
Find. An unusable killer identity may be omitted. There is no second send
switch: `/le share off` cancels pending death work too; `/le call off` only
stops the local popup/sound. Share remains on by default. Guild/zone changes
and resurrection cancel retries; callbacks later than 2.5 seconds are dropped.
One send attempt per qualifying death, never queued or retried after Wire or
the client refuses it. Limits count client refusals too and are session-only.

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
names are not added. It does not immediately send a message or ask for an invite;
adding a Find name schedules the shared-list update described above.

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
combat/taint behavior. Also unverified on 70938: recap fields
(sourceGUID/sourceName/sourceFlags/overkill/timestamp), player/duel/pet
sourceFlags values, recap readiness within two seconds and overkill semantics.
The pinned API declares an empty DeathRecapEventInfo structure, not those
fields; offline fixtures do not establish their runtime availability.

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
Seven addon-message prefixes are allowed: LayerSwap, LFSw, LEGW1, WEFF1,
HeadHunter, FLHNET2 and OverlordF. Battle.net sends use two prefixes, WarBoard
and OverlordF, and also pass Wire.lua. The FLHNET2, OverlordF and WarBoard
sends are listed in their 1.2.0 sections above. Two scopes matter for your settings: guild scope
(guild, party and raid lines, and whispers to guildmates online in your roster)
and public scope (whispers to anyone else, and the two public channels joined
for reading). `/le net guild` turns normal public sends and both channel joins
off; guild scope keeps working. The sole automatic public-send exception is
WarBoard debt settlement: H, A answering an owed account's H, and its FBUN, only
while that account is owed cleanup (no LE H/A with real WarBoard loaded). A
Hop you click still whispers that one host. **Hop to another layer is refused
in guild-only mode**, including a round already in progress.

- A zone `/who` search: only from the **Hop to another layer** button or
  `/le hop any`, one `C_FriendList.SendWho` in the click's own call stack,
  using the localized `WHO_TAG_ZONE` and your live zone name. It waits up to
  5 seconds for results. The Who window is suppressed using temporary event
  ownership and `SetWhoToUi(true)` where available. A late result is swallowed
  for up to 30 seconds; a manual `/who` takes priority and displays normally.
  No class/race rotation. Missing search APIs/localization refuse the action;
  missing optional UI APIs fall back to the prior behavior (no UI guarantee).
- LayerSwap prefix, WHISPER: the existing Hop button, `/le hop <number>`
  and `/le hop host <number>` still send one request to one host, with no
  retry or fan-out. **Hop to another layer** instead asks up to 49 players
  from one WHO result: at most 8 attempts per 1-second round, at most 45
  rounds, with a 10-second click cooldown. Wire gives only these requests an
  8-message burst, 1 token/second refill, 60/minute and 4/minute per target;
  other messages' budgets are unchanged. Throttling keeps the unsent head;
  there is no Wire queue. The initial line is
  `inv layer <LS <zone> not <ownServer>-0 <x>,<y>>` (position in percent).
  An unknown-layer same-zone `h` responder can get one fallback attempt,
  `inv layer <LS <zone> <x>,<y>>`, without exclusion, after the queue (+3/+10 s).
  That fallback is spent even if throttled. No visible chat is sent.
  While you host for your guild, also the answer to a guildmate's
  request: `same` or `heard <name>|<layer>|<zone>|<h or ->`, at most one per 6
  seconds. Wire refuses any other text on this route.
- LFSw prefix, GUILD: Bulo's one-letter question `Q`, only from the Find hosts
  button or `/le hosts find`, at most once per 60 seconds. Bulo users in the
  guild answer with their own layer line. Our own Bulo `L` line is never sent,
  and an incoming `Q` is never answered.
- LEGW1 prefix, GUILD: enemies your own client saw (an `O|1` line: zone, your
  position, layer if known, up to four names within 255 bytes). After the
  existing 3-second settle, a crowd uses up to three consecutive 15-second
  slots: nine names go as 4, 4 and 1, without repeats within 60 seconds,
  even when a shared watch list changes.
  Only names actually fitted in a client-accepted line are marked shared.
  Own sightings remain eligible through age 45 seconds; older pending names
  are dropped. The age is computed at each send from the actual own sighting,
  not from a Bulo refresh or the burst start. The single age field dates the
  oldest included sighting when their times differ.
  A burst snapshots the eligible names at its first slot. After three attempts,
  any overflow (including a 13th name or names displaced by the byte limit) is
  dropped, not marked shared; a new own observation after that burst closes
  can start another burst, still at most one O per 15 seconds. Refused sends
  consume a slot too; no O is queued. `/le share off`, a guild leave/switch,
  or a world/zone/layer reset cancels the remaining snapshot without resetting
  the send or name cooldowns. Older receivers need no update: the `O|1` format
  and its four-name/255-byte limits are unchanged.
  `/le share off` stops all guild sends, including the relays below.
  Also a relay of a report you heard
  first-hand in your party, raid or whispers, so guildmates running
  LayerEnemies see both. A relay waits a
  random 0.5-2.5 seconds and is not sent when a guildmate's copy arrives first.
  Guild membership, guild name and instance state are read when it is offered
  and again when it is due; not in a guild, another guild, in an instance, or
  unreadable means it is dropped. Sharing is checked at receipt and dispatch;
  switching off discards pending relays even if switched back on before their
  timer fires. Each non-kill report id is sent about once per 120
  seconds: the 120 seconds count from when it is offered, before the random
  wait, and only while the id is remembered (256 ids; a flood of more ids can
  let one repeat). At
  most 128 offers wait at once. Wire permits 5 quick prefix sends, then one
  per 2 seconds. One shared conservative `Relay.spend` mirror counts all
  O/K/F/H/R attempts. Every R kind leaves two tokens: two own lines out of
  combat, one in combat. Combat relays can send with at least four tokens,
  subject to the other limits. A relay followed by K then O can lose the O
  in combat; only one own line is reserved. Relays also leave the final three
  guild-minute slots in peace, two in combat, across every prefix. Earlier own/control
  traffic reduces the token allowance too; refused attempts are not refunded.
  Budget refusals are dropped, not queued. From 0.4.0 the same route carries two short lines older
  versions ignore: `F|1` ("which LayerEnemies hosts are on?", from the Find
  hosts click, at most once per 60 seconds) and `H|1|<server key>|<zone>` (a
  host's answer: once when you turn hosting on and once in answer to an `F`,
  1 to 6 seconds later, at most once per 60 seconds, only while hosting).
  Own-death K1 is also GUILD-only, behind Share and the same Wire prefix/global
  budgets and pauses, never in an instance (including BG/arena), even at click
  priority. At most one per 120 seconds and five per rolling 30 minutes.
  WEFF1/HeadHunter stand-down rules are unchanged; LEGW1 is our protocol and
  has no donor stand-down or public-network switch.

  `K|1|<zone>|<x3>|<y3>|<layer>|<age>|<conf>|<nameHex>:<CLASS>:<level>:<f|p>`

  Zone is uiMapID; x/y are both empty or 0.000-1.000; layer is the O-line key
  or empty; age is 0-120 seconds; conf is `e` for a recap player killing blow
  or `h` for a hostile player hit with another finisher. The killer item may
  be empty; class/level can be unknown. Other versions are silently ignored.
  Receivers require a checked online guild member, refuse killer=sender and
  own echoes under the existing full-name rule. Base 1.0.1 was separately
  tested to drop unknown K lines without an error or side effects.
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

Send budgets in Wire.lua, plus the stricter relay allowance above, are spent
before the client is asked: each prefix 5
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
  saved). Off stops all guild sends, including your O and K own-death lines,
  every Spy, HeadHunter and War Effort relay, host questions/answers and
  network guild traffic. Pending relays and death retries are cancelled
  immediately and cannot replay when re-enabled. Queued guild embassy lines
  are dropped if sharing is off at dispatch. Your War Effort reports, waiting
  sync answers and queued own embassy lines also stop; you still receive
  everyone else's.
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

The number after the "-" (the zoneUID) is never used as a server-layer key.
The receive-only ChehulNet exception compares that GUID-field-5 reading only
within the same map, while your reading is confirmed and unambiguous, for
the separate ally hints described above; other layer-key paths are unchanged.
War Effort 1.6.x sends its own layer field;
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
queue. All guild relays leave **two tokens** in the five-token LEGW1 bucket
(refill is one per two seconds): two own lines out of combat, **one own line
in combat**. A combat relay costs two tokens, so it can send with at least
four tokens when the other limits allow it. Known limit: a relay followed
immediately by the rare K death line (or a watch-list T line) and then O can
delay the O in combat by one 15-second slot; the reserve protects one own line,
not two back to back. Refused relays are dropped,
not queued. The relay gate accounts for other LEGW1 authors too, conservatively
spending refused attempts. Relays also leave the last **three guild-minute
slots out of combat, two in combat**, using Wire's actual count across every
prefix. Wire's send path and existing shared/minute caps are unchanged.
`/le share off` stops every relay,
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
time evicted first), with at most three entries per folded name: your own
sighting, the newest other first-hand observation, and the newest reported
claim. Relays and death claims cannot erase a guild O sighting, even when
your own sighting is retained too. It is never a general enemy list,
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
show its own sighting, another first-hand line and a claim, for example:

    Seen by Birch Scout in Ashenvale, 4 min ago, layer 7085 (their claim)
    Reported: named as killer in Durotar, 12 min ago (death, claim)

At 600 seconds each line is prefixed `last known` and offers no Ask/Hop;
at 3600 seconds it is removed. Adding old evidence does not alert. A fresh
first-hand finding has action/alert priority over a claim, but both remain
visible. Your own sighting remains primary over a newer guild observation
while under 600 seconds old, in your current zone and still valid for your
current layer (known at sighting time, with no intervening boundary). Each
line keeps its own time and layer label. Guild O lines are first-hand; R lines and indirect
envelopes are claims and never authorize asking their origin. A fresh hash
finding is displayed alongside last-known named lines, including its possible
match warning, spotter and age, so the evidence behind Ask remains visible.
GBOUNTY and WALLOFSHAME killer names are claims in any zone, with victim
coordinates when supplied.
Direct HeadHunter P/L keeps its legacy ten-minute/boundary Find path outside
the named cache; indirect HH reports still use the relayed category.

### HeadHunter kill records

A victim's D record inside an E envelope supplies location evidence for its
fully named killer, whether HeadHunter is also loaded (stand-down) or LE is
its own mesh member. Find shows `killed <victim>`, `victim-reported`, zone,
real age and the **victim's** coordinates, as a HeadHunter claim. It adds
`via relay` when the whisper carrier differs from the victim, and `(inferred)`
only for inferred confidence; exact confidence adds no extra label.
Simulated records, incomplete names/GUIDs, mismatched author/victim and other
factions are dropped. A killer matching ourselves or the victim under the
whole-name rule is rejected on both direct and guild receive paths. No
class/level guesses; assists are ignored.

D never creates a row on the Reported tab, a per-enemy count, a kill list,
a kill-based ordering, or a Call popup. Its private HeadHunter layer is never
stored or shown. It cannot authorize Ask/Hop, even if the victim is a known
host. Catch-up stays the age of the original event, is labelled `last known`
after 10 minutes and expires at 60 minutes; adding an old name does not alert.

Only D heard by **WHISPER** and still under 300 seconds old is offered to the
guild, including in stand-down. It uses the existing `LEGW1` GUILD route:
`R|1`, source `hh`, kind `kill` (exact) or `killi` (inferred), origin = victim,
one fully named killer, victim coordinates, unknown layer and original age.
Older clients reject these unknown kinds as invalid and ignore the line.
The existing random 0.5–2.5-second wait and guild-copy stand-down apply.
The same source/victim/record id is offered only once across all carriers
while retained, not again after the legacy 120-second memory. Duplicate guild
copies cannot reset Find's age. The separate session ledger keeps at most 256
identities for the 60-minute evidence lifetime plus 300 seconds of accepted
future skew. It drops expired ids first; if still full, it evicts the oldest
admitted id so a new kill is always shown locally. A rare duplicate of an
evicted id may be relayed again; it still obeys every send limit. The ledger is
never saved. `/le share off` stops these relays too, not local receipt.
Kill relays use the same `Relay.spend` token and guild-minute reserve as Spy,
War Effort and legacy HeadHunter relays, with no separate reserve to bypass it.
They can send in combat while leaving room for one own line, not both K and O.
Shared admission gives no relay family priority over another; mixed traffic
can still spend the kill-attempt budget without sending a kill relay.
Freshness is checked again at send time. At most **4 kill-forward attempts
per rolling minute**, and **one per whole killer name per 60 seconds**;
foreign realms are distinct. These are `forward` priority: over budget or
throttled means dropped, never queued/retried ahead of own sightings or clicks.
Catch-up records at 300 seconds or older and all non-whisper records stay
local. Received guild kills remain Find-only claims and are never forwarded
again or turned into Ask/Hop targets. No new prefix, route or recipient is
added; nothing is sent on HeadHunter's prefix in stand-down.

`/le net` also prints memory-only HeadHunter session diagnostics in both
modes: admitted P/L/E frames, inner E records by kind, accepted full-name kill
records read, those under 300 seconds, and those successfully relayed to the
guild. Counts are receive events (duplicates included), not unique kills;
Decoder-rejected D records appear only in the inner-kind tally. Counters obey the
existing receive policy and 6-frame-per-sender/10-second limit, survive zone
changes, reset on reload, and never enter SavedVariables or `hhNet.history`.

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
zone/name/position and own identity, no ask or hop still open, working
localized WHO APIs, and **10 seconds between hop-any clicks**, including
stopped clicks; the cooldown restarts at the first accepted whisper, not at
each later target. Unknown group, combat or instance state refuses. The shared
10-second overall ask cooldown is reserved once; the shared 60-second
per-name cooldown still applies to initial requests. Other asks/hops are
refused until this round ends or you stop it.

Only the first **49 WHO rows** are read, minus yourself, duplicates and
unreadable/ignored names. Known hosts come first (even with unknown layer),
then same-zone names, then other-zone rows in the game's order. Known book
peers bypass the six-hour nonresponder skip; a known offline peer waits
**600 seconds**, other offline/nonresponding targets wait **6 hours**.
The skip list stays **session-only, capped at 300 names**, never saved.
Repeated clicks can see the same first 49; there is no class rotation.

The **Who window is suppressed**: before the query we request UI routing and
temporarily unregister WHO_LIST_UPDATE on hidden who frames. **Visible windows
are left alone**, including their event registrations; no OnEvent script is
replaced. Registrations return after result dispatch. Timeout, Stop and other
cancellations retain only the event-unregister late-result guard until the
first late answer or 30 seconds from the query; errors/logout release it too.
A player's own `/who` immediately restores registrations, takes ownership and
cancels our pending query, so its result displays normally. Already open
windows are never hidden. Missing optional UI APIs retain the old behavior
rather than blocking the action.

Nothing is whispered before WHO answers. The click owns up to **45 rounds**,
**one second apart**, with **at most 8 attempts per round**. A fresh Wire
bucket allows eight initially, then about one per second: all 49 names take
about **41 seconds** in the offline harness without competing traffic.
A fan-out throttle/pause keeps the target at the head for the next round;
an offline name is skipped. A client throttle on a named hop or reply on the
LayerSwap prefix instead stops this click, even after the pause expires. A
fan-out client throttle also gives named hops/replies their usual 30-second
prefix pause, without stopping its own next-round retry. Other send errors
stop the search. A host reply alone does not stop the queue. An invite from
any not-known-failed host, Stop, joining a group, combat, entering an instance,
a real zone-map/world change, or a guild-only switch cancels unsent work.
Subzone events, roster updates while ungrouped, and loading events that return
to the same zone do **not** cancel fan-out or its pending auto-accept. Existing
unreadable-state guards still fail closed.
**Sent requests cannot be recalled; a late invite can still arrive.** An
unasked invite is never auto-accepted or declined. Failed hop hosts are
remembered for 600 seconds; their invites do not end the queue.

After the queue ends, unknown-layer same-zone `h` responders are each eligible
for one fallback attempt without an exclusion. Checks start at **+3/+10 s**;
a known alternative-layer host gets until +10 to invite. Attempts stay bounded
at eight per second. A fallback refusal is not retried. Any invite or other
cancellation prevents the remaining fallback work.

Replies are read only on WHISPER from names successfully asked, for 120
seconds after the first successful initial send (the invite-wait start). Names include surnames and
foreign realms. `same` / not-hosting answers are summarized, not printed per
reply. Nonresponders are recorded when the round closes; replies clear that
suppression. Unknown-host hints and failed-hop history are also bounded and
session-only; reload clears them. No player names are added to SavedVariables.

These are hidden addon whispers, not chat. Native Forever UI event order,
`SetWhoToUi`, real server throttling (~1 whisper/s), visibility to players
without an addon, and account spam/silence limits are **not verified** (alpha,
owner's decision). Multiple hosts may invite before cancellation; no rate
limit eliminates that race. No stranger-hosting behavior is added here.

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

LayerEnemiesDB is SavedVariablesPerCharacter. It stores options, up to 20
explicitly tracked names (typed or chosen with On my way), and window position.
Target GUIDs are persisted **only in `warboardOwed`**, with bounded withdrawal
attempt counts as described above. It never persists sightings, other unselected
identities, hashes, locations, report payloads, asked names or alert history.
Besides those three it holds
`guildHost` (hosting for your guild) and `autoHop` (Auto accept and leave),
`consent` ("guild" after `/le net guild`, "public" after `/le net public`,
absent until either: public), `nets` (one
switch per network), `share` (sharing your sightings and own PvP deaths), `call` (death popup/sound),
`findShare` and `findNotice` (shared-list and on-site notice switches, default on),
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

New send: K own-death line, LEGW1/GUILD, share switch, 1 per 120 s.

The K probes exercise actual PLAYER_DEAD, delayed recap reads, Wire and the
Call popup boundary, including 120-second/30-minute limits, secret/missing
fields, faction proof, partial identity, BG/arena refusal, cancellation,
caller-frame enforcement and all other routes remaining forbidden. No
combat-log event is registered. No donor code is copied or executed.

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
