# PR E1 — WarBoard handshake and receive

Base: `67953cfe6ef436c2df20b536f6cca5f0114ec773` (registry plus shared codecs).
Feature commit: `856a46f3a573f5548c7ab8ca64968df3575ceb5b`.
Local branch `feat/warboard`, clone `/opt/data/cache/scratch/le-warboard`.
Push URL is `DISABLED`; no push or GitHub write. Generated verification notes
and this report are a separate notes-only commit.

## Exact sends and caps

| Frame | Recipient | Admission and actual-attempt limits | Code |
|---|---|---|---|
| `WBF1\|H\|5\|<own ruleset>\|LayerEnemies/<own version>\|0` | Eligible opposite-faction online WoW game accounts returned by the shared resolver, same project and realm | Scan no faster than 60 s; select at most 20; one H/account/600 s | `LayerEnemies/WarBoard.lua:47-80,315-328` |
| `WBF1\|A\|5\|<own ruleset>\|LayerEnemies/<own version>\|0` | Eligible sender of protocol-5 H with a recognized ruleset; a different recognized ruleset receives our own-ruleset A but is not accepted | At most six A/rolling 60 s, both when queued and at dispatch; never answer A | `LayerEnemies/WarBoard.lua:59-72,281-302` |

The one outbound call is `BN.send` at `LayerEnemies/WarBoard.lua:64`.
WarBoard's H+A share is 10 attempts/minute (`LayerEnemies/BNet.lua:38`);
all networks share 30/rolling minute with at least one second between attempts
(`LayerEnemies/BNet.lua:83-97`). Client refusal spends an attempt. No retry.

Share off, Guild only/public off, source off, combat, instances, unknown ruleset
or unreadable account state prevent sends, including queued sends. Loading the
real WarBoard addon stops our discovery/H; owed A may still leave, under all
privacy and budget gates, as required by PLAN section 3. Stand-down never stops
read-only evidence admission. No FBAK, forwarding, snapshot, tracking request,
self-location, subscription, gameplay response, addon-channel or chat send exists.
Every WarBoard test checks both gateway attempts and actual sends against the
H/A-only grammar, even if a protected callback swallows a spy exception.

## Reads and display

- `Src.register` at `LayerEnemies/WarBoard.lua:330`: WarBoard BNet H/A/D/F and
  WarBoard/WarBoardBN addon GUILD/PARTY/RAID/CHANNEL, bounded AceComm framing.
- SHRD (`:162`): own zone/map/shard, unknown observation time, 180 s receipt
  lifetime; sequence-aware clear removes only this source's SHRD claim. The
  player has one sequence/cache spelling across direct and relayed carriers.
- FBLP (`:186`): target world coordinates, zone/subzone, shard and sentAt; explicit
  approximation survives. The native converter is `Adapters.lua:426`; HBD
  worldX/worldY become the API vector Y/X. A child-map result is converted again
  to the displayed parent zone before percentages are accepted. Text survives
  an unavailable conversion; no transform or donor map database is copied.
- FREC (`:209`): pvp_kill / witnessed_pvp_kill locate the named killer, never the
  victim. FBLC (`:245`) and supported FCBD entries (`:264`) remain cached.
  Rank/roster/reward fields are validated but not imported as counters or lists.
- All evidence goes through `Sources.lua:106-168` into existing Find.report and
  Known. Own Find entries show the existing Reported evidence line, with kind,
  source, shard text, original age or unknown, receipt age and details. Guild
  Watch-only names are admitted into session Known without adding names to our
  own Find list; there is no new guild-list UI. `UI.lua:213,218-234` already
  measures the complete details before row heights/paging; UI.lua is unchanged.
- Claims cannot replace firsthand slots, become Seen, enable Ask/Hop, produce an
  alert on a later poll, change verified kills, or rebroadcast to LE/WE/HH.
  Same-faction and untracked data are discarded. No new SavedVariables schema,
  saved names, peer book or history is introduced; existing network options
  supply the source switch.

## Audit rulings and conservative limits

1. The audit distinguishes addon version, protocol, gameplay rules and serializer
   revision. LE identifies itself as LayerEnemies/its own version, protocol 5,
   gameplay-rules version 0 (not a tracking-capability flag). It does not claim
   WarBoard's version or implement the donor reward system.
2. Donors confirm peers on A, not their first H. PLAN 8.1 explicitly allows LE
   to accept either compatible H or A. LE answers H and initiates periodic H;
   it never loops A-to-A. No packet forwarding is a peer-admission obligation.
3. SHRD sentAt is a millisecond-like sequence, and its `realm` is a surname,
   not a server realm. Preserve sequence ordering; do not fabricate observation
   seconds. A 120 s wall-skew check and 180 s receipt expiry are LE safeguards;
   severely skewed donors are intentionally dropped. Carrier-added realm
   spelling must not give a second sequence or defeat a later clear.
4. FBLP approximate coordinates may be older than its current zone labels. Keep
   both meanings explicit. Relayed transport does not turn target coordinates
   into the relay carrier's coordinates. No donor shard is treated as an LE key.
5. FREC is structurally validated location evidence, never a verified reward or
   kill ledger. No objective/reward/campaign catalog is imported. Only the two
   kill atypes are used; objective/transaction records do not become sightings.
   FBLC has no active producer in the audited release; cached input is not
   advertised as a periodic fresh feed.
6. In addition to planned 4000-byte frames, 64 parts, 16 assemblies, 90 s assembly
   lifetime and 120 frames/sender/rolling minute, LE bounds peers and sender
   buckets to 200, SHRD sequence slots to 300, dedupe to 512 encoded packets and
   1 MiB, encoded/inflated payloads to 256 KiB, and codec depth/count through the
   shared decoder. Peer authority expires after 1200 s. FREC/FBLC older than one
   hour are dropped; FBLP admits at most 120 s age/future skew. These are stricter
   local safeguards, not claims that the donor enforces them.
7. Dedupe is committed only after valid evidence is admitted. Raw bytes are kept
   only in bounded volatile transport state. Existing shared friend/community
   discovery and its ordering are reused, not the proprietary donor resolver.
   Being eligible never guarantees a donor selects us among its first 20.

## Necessary shared-file changes

- `BNet.lua`: optional sixth `BN.send(...,still)` argument. The callback is
  checked once when dispatch is budget-eligible; only literal true permits an
  attempt. This prevents a delayed cohort bypassing H/A caps. Old callers keep
  their behavior; there is still exactly one queue and send gateway.
- `Sources.lua`: optional guarded `note` (360 bytes), `tag` (16), `clear` boolean,
  `expiresAt` monotonic deadline within Known TTL, and `pos=enemy|observer`.
  `Find.lua` carries the fields; `Known.lua` honors expiry and source/type-scoped
  withdrawal while preserving firsthand slots.
- `Adapters.lua`: protected context and native world-to-map conversion only.
- `test/harness.lua`: inherited 5 s / 2 s heartbeat assertions now select Main's
  own callback, not the earliest callback from any module. First production
  source registration activates the already-existing one-second registry timer;
  Main's production cadence is unchanged.

## RED → GREEN, mutants and verification

- Baseline: `RESULT: 1296 tests passed, 0 failed, 175119 assertions`.
- Handshake before implementation: 0 passed / 11 failed (missing-source assertions).
- Receive before implementation: 23 passed / 7 failed (missing evidence).
- Location/structural corrections: 43 passed / 3 failed (relayed coordinate
  subject, child-map conversion, FREC optional-field validation).
- Final review regressions first demonstrated: 56 passed / 2 failed (cross-route
  SHRD clear and same-faction addon admission). Both then fixed.
- Final focused suite: `RESULT: 58 tests passed, 0 failed, 30767 assertions`.
  Includes 5000 deterministic hostile frames, per-input Lua instruction budgets,
  audit-section-11 opaque-pipe/reordered-fragment vectors, all send guards,
  queue delays, independent bounds, stale/secret/oversized input and measured UI.
- `python3 test/warboard_mutants.py`: `RESULT: 60/60 WarBoard mutants killed`.
  Each syntax-valid mutation has an assertion kill in
  [warboard-mutants.json](warboard-mutants.json); no syntax error, timeout or
  runner failure counted. Bounds are tested independently so a downstream cap
  cannot hide a missing upstream limit. Existing source/codec mutant suites
  were not rerun; their normal regressions are in the full harness.
- Final `python3 test/verify.py`, foreground, exit 0:
  **`RESULT: 1354 tests passed, 0 failed, 205911 assertions`**.
  Lua 5.1.5; 77 syntax files; static/send/API policy, harness-selection tests,
  media tests, TOC and deterministic archive/source parity all pass.
- Archive remains release-foundation version 1.1.0 until the release PR:
  `dist/LayerEnemies-1.1.0.zip`, SHA256
  `43240954cdd985b793e2c02aab9454b272a2ac4fcb56e2543568f89487b03542`.
  Generated verification.json has inherited legacy descriptive strings; this
  report and README's first send table specify the new WarBoard behavior.
- Raw logs: `/opt/data/cache/scratch/le-warboard-{baseline,red-handshake,red-receive,red-location,red-cross-route,focused,mutants,verify-final}.log`.

Feature files: `LayerEnemies/{WarBoard,Adapters,BNet,Sources,Find,Known}.lua`,
`LayerEnemies/LayerEnemies.toc`, `README.md`, `THIRD_PARTY.md`,
`test/{src_warboard.lua,warboard_mutants.py,warboard_vectors.py,api_policy_test.py,harness.lua}`,
`test/fixtures/warboard-bomb.bin`. Notes are committed separately.

Self-review and static security scan performed; parent independent review remains
separate. No donor code/library was copied or executed. No native client,
non-friend account resolution, live delivery, real fonts or coordinate conversion
was exercised: **native checks not run (alpha, owner's decision)**.
