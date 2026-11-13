# LayerEnemies implementation summary

## Delivered

- Addon folder: /opt/data/projects/layer-enemies/LayerEnemies
- Local package: /opt/data/projects/layer-enemies/dist/LayerEnemies-0.1.0-headless.zip
- Interface 16001; Lua 5.1; SavedVariablesPerCharacter LayerEnemiesDB.
- Nine modules: Safe, Hash, Layer, Protocol, Store, Reports, Adapters, Invite,
  Main. Hidden event dispatcher only. Commands: `/le`, `/le unclassified`,
  `/le reports`, `/le hosts`, `/le ask <number>`. Public function
  `LE.AskInvite(name)`.
- Own event-driven sightings and protected Bulo snapshots with optional,
  separately source-verified GUID enrichment. Only readable unit factions
  establish opposite faction. Hostility alone never does.
- Conservative epoch invalidation for zone/world/transfer/raw-ID changes,
  carried-unit quarantine/reacquisition, ten-minute expiry, bounded memory,
  observer-only positions, and possible-not-unique hash identity annotations.
- Nothing was pushed, published, uploaded, or installed in a client. No
  third-party addon code, source archives, credentials, or saved sightings are
  bundled.

## Owner decisions applied in this round

### 1. War Effort reports ON, dated by time of receipt

- A complete C/E report for the current zone is stored with the time it was
  received and listed under "Reported, not confirmed" for 600 seconds.
- Kept: every privacy gate (loaded WarEffortScout 0.2.13, readable settings,
  silent mode, source and client ignore lists, guild/public channel rules, own
  echo), replay tombstones (3,660 s), duplicate/conflicting fragment rejection,
  enemy-count check, sender/global rates and all caps. Hello (H) lines are
  heard but store nothing. Legacy ZRAD1 still fails closed.
- The wire stamp must be within 30 s behind or 5 s ahead of the server clock.
  The 5 s forward allowance exists only in receipt mode.
- Reports only need the current zone. The reporter's zoneUID is shown as same,
  other (number) or unknown; it is never treated as a layer key.
- Reports never enter "seen by you" and never yield a map candidate.
- The strict reducer mode (trusted absolute send time, exact zoneUID match)
  is unchanged and still tested.

Limits that follow from this decision (also in README):

- A packet replayed after its 61-minute tombstone has expired, at the same
  second of a later hour, is accepted and shown as fresh. Tested and asserted
  as a known limit ("receipt mode: replay tombstones hold for an hour, then
  the documented limit").
- Replay memory is not saved. After a reload or relog a packet replayed inside
  the 30 s stamp window is accepted.
- A report is a claim by another client. Nothing verifies the sighting, the
  class/level, or that the reporter is where they say.
- The earlier summary's statement that no receipt-time workaround was added
  no longer holds; it was replaced on the owner's instruction.

### 2. Ask for invite

- One layer-key helper (`Layer.key`, `Layer.same`): the server part of a
  creature GUID. Used for every comparison in the invite flow.
- Candidates, read-only, each inside a protected call, same zone only:
  War Effort report senders (by name, layer unknown, 600 s), Bulo
  `Guild.list` (younger than 720 s), LayerSwap `LayerSwapDB.book` (younger
  than 900 s, not marked gone).
- Excluded: self, own layer key, other zone, stale, more than 5 s in the
  future, secret/unreadable/non-name keys. Bulo/LayerSwap candidates need the
  own layer to be known.
- One row per name; the newer claim decides the layer. Order: reporters,
  hosts, newest. 512 entries scanned per source, 40 rows returned.
- `LE.AskInvite(name)` and `/le ask <n>` only prefill the chat box
  (ChatFrameUtil.OpenChat, else ChatFrame_OpenChat, else the line is printed).
  The user presses Enter. 60 s per name, 10 s overall, refused while grouped.
- After an ask, a group join within 300 s starts a 60 s watch of the own
  layer key and prints the moved / still-on-your-layer message. Unknown
  earlier layer, unconfirmed new layer and zone change each get their own
  message instead of a claim.
- The addon contains no call that sends chat or addon messages, invites,
  accepts or leaves. Checked statically and at runtime in every test.

Implementation choices not specified by the owner: the 300 s join window, the
two-minute validity of a `/le hosts` list, the 512/40 caps, the 5 s future
tolerance, refusing an ask while grouped, and opening the chat box one frame
after the slash command.

### 3. Previews only

- notes/preview-A.html and notes/preview-A.png: stacked sections, one
  scrolling window in a classic gold-bordered panel.
- notes/preview-B.html and notes/preview-B.png: three tabs with counters in a
  flat compact panel; the picture shows the window on each tab.
- Both show the layer header, "Seen by you", "Reported, not confirmed" with
  Unknown Mage 40 and an "Ask <reporter> for invite" button, "Friendly players
  on other layers" with source tags, layer, age and "Ask for invite", and the
  footer. No window, pin or style was built into the addon.
- Rendering: the plain `chrome --headless --screenshot` command did not finish
  on this machine (it timed out with no file written in every flag
  combination tried, last checked with a 30 s limit). The
  PNGs were captured from the same Chromium binary in headless mode through
  its DevTools screenshot call on local ports 9347 and 9348, at 2x scale.
  Port 9222 was not used.

## Exact executed verification

Command: python3 test/verify.py

- Lua interpreter: Lua 5.1.5.
- luac -p: 11 of 11 Lua files passed (9 addon modules, harness, benchmark).
- Strict mock harness: 68 tests passed, 0 failed, 6,846 assertions.
  Previous round: 44 tests, 6,219 assertions. 24 tests were added and one
  earlier test was rewritten for the receipt-time decision.
- Deterministic malformed-wire fuzzing: 5,000 inputs, included in those counts.
- TOC manifest/source-file parity: passed.
- Static check: none of SendAddonMessage, JoinChannelByName, SendChatMessage,
  COMBAT_LOG_EVENT_UNFILTERED, InviteUnit, LeaveParty, AcceptGroup,
  C_PartyInfo, RunMacroText, SetText or OnUpdate appears in addon code.
- Runtime check: the harness fails any test in which a send, invite, accept
  or leave function is reached.
- git diff --check: passed during verification.
- Local ZIP: 11 members; CRC test and byte-for-byte source/README parity passed.
- Package SHA-256:
  4585fab11e099c05a8c1ad37aa38e4cc2f06c2a1f91ac1be5637b8c17225b3b5

Machine-readable result: notes/verification.json.
Full real test stdout: notes/test-results.txt.
The harness is simulated client execution, not real-client testing.

New test areas: layer-key helper; receipt-time dating, ten-minute expiry,
replay tombstones and the later-hour replay limit, stamp window with forward
tolerance, duplicates/conflicts/count mismatch, privacy gates and caps in
receipt mode, other-zoneUID labelling and transfer wipe; candidates from each
source when absent, wrong shape, throwing, secret, stale, future, other zone,
same layer and self; host preference; one row per name across sources;
bounded scans; chat-box route, legacy route and each print fallback;
per-name and overall cooldowns; refusal of unlisted, unreadable and injected
names; `/le hosts` numbering and `/le ask`; after-join success through Bulo
and through two NPC kinds, timeout, late join, unknown layer, zone change;
asking a War Effort reporter; no send/invite/accept/leave in source or at
runtime; nothing about asks saved.

Earlier test areas are unchanged and still pass: Bulo presence/shape,
subscription failure, sighting copy and expiry, epochs and quarantine, zone
handling, faction/duel/secret handling, GUID enrichment, NPC confirmation,
hash vectors, C/E/H grammar, fragments, strict-mode freshness, tombstones,
floods, channel and ignore policy, hash identities, sorting, SavedVariables
privacy, map candidate selection, dispatcher and timer pacing, fuzzing.

## Offline CPU/allocation measurement

Same 256-entry fixture, GC stopped during each measurement; allocations are
transient allocated KB, not retained heap. "Now" was run after this round.

                                     Before        After         Now
Unchanged Bulo snapshot, ms/call      0.322515      0.211905      0.205610
Unchanged Bulo snapshot, KB/call    100.288521      0.288345      0.282954
256-entry prune, ms/call              0.011279      0.010601      0.010865
256-entry prune, KB/call              0.000000      0.000000      0.000000

Friend lists are read only on `/le hosts`, `/le ask` and `LE.AskInvite`, not
on the heartbeat; candidate collection itself was not benchmarked.
These are short Linux/Lua 5.1 microbenchmarks; timing noise is expected.
They are not WoW addon CPU measurements or frame-rate evidence.
Raw earlier results: notes/benchmark-before.txt and benchmark-after.txt.
Reproduce: /opt/data/tools/lua/lua-5.1.5/src/lua test/benchmark.lua.

## Not verified in the real client

No Forever client was run. Everything below is unverified in game.

Ask for invite:

1. That ChatFrameUtil.OpenChat or ChatFrame_OpenChat exists on Interface
   16001, takes (text, chatFrame), and leaves the prefilled whisper in the box
   when called from a timer one frame after a slash command. Also whether the
   call is blocked or tainted in combat.
2. That `/w Name-Realm text` typed by the user reaches a player on a
   connected realm, and that War Effort sender names arrive in that form.
3. That GROUP_ROSTER_UPDATE fires on joining and IsInGroup returns true at
   that moment.
4. That joining a group moves the player to the leader's layer, how long it
   takes, and that it only works inside one zone. These come from the owner's
   and the reference addons' measurements, not from a test here.
5. The shapes of `BuloLayerForever.Guild.list` (3.0.24) and
   `LayerSwapDB.book` (LayerSwap 1.14.18) as loaded in the client, and that
   their zone values equal this addon's zone ID for the same place. They were
   read from source only. A mismatch hides candidates; it cannot add wrong ones.
6. That a War Effort reporter is still on the reported layer and in the zone
   when asked. A reporter may have moved, logged off or changed layer.
7. The moved / still-on-your-layer messages against a real transfer,
   including the case without Bulo where two NPC kinds must be seen first.

War Effort reports:

8. That War Effort sends at the moment of sighting, so receipt time is a fair
   sighting time. This is the owner's premise; delayed or queued sends would
   make rows look newer than they are.
9. Clock rounding between clients (the 5 s forward tolerance), the
   CHAT_MSG_ADDON argument shapes, sender normalization and ignore-list
   readiness.
10. Replay behaviour in practice: later-hour and post-reload replays are
    accepted by design and shown as unconfirmed.

Carried over from the earlier round:

11. Loading, taint and secret-value behaviour, event support and order, timer
    availability, addon metadata, GUID API results, position APIs.
12. Layer semantics: that the creature GUID server part identifies a layer,
    same-server raw suffix changes, and how zoneUID relates to layers. Needs
    paired clients.
13. Window, class colours, layout, saved position and WorldMapFrame pins are
    not implemented. Store.mapCandidates is a tested data selector only.
14. The list is never a complete layer population. Hash collisions and
    unauthenticated senders remain limits of the report source.

## Engineering lessons kept local to this project

- Modulo-hour stamps cannot give absolute freshness. Receipt time is now used
  by owner decision; keep such rows in their own unconfirmed section and state
  the replay limit instead of hiding it.
- Apply privacy gates before decoding/admitting report state. Missing settings
  are not permission; unknown legacy-network enablement stays unavailable.
- Compare layers through one key helper. Never compare a zoneUID with a
  server key.
- Read foreign tables inside one protected call and drop the whole source on
  any surprise; a half-read list is worse than none.
- A slash command runs inside the chat box's own send, which then clears the
  box. Open the prefilled box one frame later.
- Reserve a cooldown only when the ask is accepted, so a refusal costs nothing.
- Check the eighth GetPlayerInfoByGUID return only after checking the actual
  Forever-era API declaration. Never derive faction from its race return.
- Tombstone timed-out and epoch-invalidated assemblies, not just completed
  ones; otherwise replayed fragments can restart old assemblies.
- Skip unchanged Bulo timestamps before allocating copied observations.
- Do not claim map-rendering tests when only a headless selector was exercised.
- On this machine `chrome --headless --screenshot` hangs; capture through the
  DevTools screenshot call on a free local port instead.

All edits and generated artifacts were confined to this project. Reference
addon and skill files were read-only. Shared skills were not modified because
this run restricted work to the project directory.
