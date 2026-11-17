# PR E1 — WarBoard handshake and receive

Round-2 review baseline: `04fdf7a83f8fde65ef3834b6e40a49adf49cee3d`.
Round-2 implementation: `98ba5668361b92e21ea3f3f904e1d4cdcb8e55a7`.
Prior round-1 baseline: `8fcbb39200a78a16408f384403205a5e5529fef0`;
implementation: `aabfdad53b46dd9a087b5ac01a0c03bdf1091687`.
Original feature: `856a46f3a573f5548c7ab8ca64968df3575ceb5b`, on registry/codecs
base `67953cfe6ef436c2df20b536f6cca5f0114ec773`.
Local branch `feat/warboard`, clone `/opt/data/cache/scratch/le-warboard`.
Push URL is `DISABLED`; no push or GitHub write. Generated verification notes
and this report are committed separately from implementation and tests.

## Exact sends and consent

| Frame | Recipient | Admission and actual-attempt limits |
|---|---|---|
| `WBF1\|H\|5\|<own ruleset>\|LayerEnemies/<own version>\|0` | Eligible opposite-faction online WoW game accounts returned by the shared resolver, same project and realm | Scan no faster than 60 s; select at most 20; one H/account/600 s |
| `WBF1\|A\|5\|<own ruleset>\|LayerEnemies/<own version>\|0` | Eligible sender of protocol-5 H with a recognized ruleset; a different recognized ruleset receives our own-ruleset A but is not accepted | At most six A/rolling 60 s, both when queued and at dispatch; never answer A |

The only outbound call remains `BN.send` in `WarBoard.lua`'s local `send`.
WarBoard's H+A share is 10 attempts/minute; all networks share 30/rolling minute
with at least one second between attempts. Client refusal spends an attempt.
There is no retry. Share off, Guild only/public off, source off, combat,
instances, unknown ruleset or unreadable account state prevent sends, including
queued sends. Loading the real WarBoard addon stops discovery/H; owed A may
still leave under every privacy and budget gate. Stand-down does not stop
read-only evidence admission.

There is no FBAK, forwarding, snapshot, tracking request, self-location,
subscription, gameplay response, addon-channel or chat send. Every original
WarBoard test checks both gateway attempts and actual sends against the H/A-only
grammar, including protected callbacks that could otherwise swallow a spy error.

The owner-requested plain line is directly below README's send table:

When LayerEnemies completes the handshake, a real WarBoard client treats it as a new peer and shares its profile, kill streak and board snapshot with its Battle.net contacts, as it does for any WarBoard user; LayerEnemies never asks anyone to broadcast their position.

This discloses the remote new-peer publication side effect without inventing an
LE data send or a request to begin location tracking.

## S1 — bounded decode work and replay memory

### Per-type inflation ceilings

These bounds cover the supported location producer schemas, not arbitrary extra
Ace fields or every non-location ledger page. String budgets allow worst-case
**two-byte Ace escaping for each source byte**, array indices, field names,
numbers, table tags and envelope metadata. The positive fixtures fill string
fields with `~` to force expansion, include 80-byte `av` and `senderName` fields,
and test both `t`-first and `t`-last envelope orders.

| Type | `maxOut` bytes | Size of expanded stress fixture | Sizing reason |
|---|---:|---:|---|
| SHRD | 2,048 | 1,337 | One identity and location: name/surname 36 each, GUID 80, zone 100, shard 12 digits, optional objId 160, plus numbers/flags/envelope. No list. |
| FBLP | 40,960 | 37,583 | Up to 100 roster rows, each with 80-byte GUID and name plus faction: the two escaped identity fields alone consume 32,000 bytes. Row syntax, target identity, two 100-byte zone labels, coordinates and envelope fit in the remaining allowance. |
| FREC | 73,728 | 68,166 | Up to 200 unique cleared IDs of 160 bytes: worst-case escaping contributes up to 64,000 bytes. Allow all bounded optional record strings, array indices, numeric fields and envelope as well. |
| FBLC | 2,048 | 971 | One 80-byte target GUID/name pair, 100-byte zone, faction, timestamp and envelope; no list. |
| FCBD | 98,304 | 63,572 | At most 40 normal supported cached-location entries. The largest useful normal producer is `witnessed_kills`, with id, killer identity, victim GUID, witness identity, zone, counters and empty cleared-ID list. Reserve over 2 KiB per entry plus page/relay metadata; `bounty_locations` is smaller. |

FCBD's `activity` producer selects objective/bounty transaction records, which LE
does not use as kill sightings. Arbitrary combinations of 40 full FREC
200-cleared-ID records are **not** a normal witnessed-kill location page. Such
oversized pages, ignored extension fields and irrelevant ledger bulk are
intentionally refused rather than restoring the old 262,144-byte inflate cap.
The record and producer field reasoning follows the read-only WarBoard 1.6.3
audit sections 4, 5.1, 5.3 and 5.6; no donor implementation was copied or run.

`t` is inside the compressed Ace table and Lua table iteration order is not
fixed. `W.decode` therefore starts at the largest supported ceiling (98,304),
further limited by the sender's remaining allowance. An incremental top-level
Ace-token observer lowers output/work ceilings as soon as the actual envelope
`t` appears. Nested `t` values cannot select or raise a ceiling. If `t` is late,
work already performed is still charged, and the final per-type size check
refuses oversized output. Unknown types are refused. Neither type order gets
the former 262,144-byte WarBoard inflation allowance.

`Codec.inflate(raw,maxOut,policy)` adds an optional lowering-only streaming
policy and a second return value for committed output bytes, including partial
output before failure. Stored blocks are observed in slices; compressed literals
and backreferences are observed before committing output. A policy also bounds
codec work to `4096 + 32 * maxOut`, under the shared global work ceiling. Callers
without a policy keep the prior codec limits and first-return contract.

### Sender/account budget

- At most **16 expensive decode attempts** and **131,072 charged bytes per rolling
  10 seconds** per normalized character identity, shared across Battle.net,
  both addon prefixes and GUILD/PARTY/RAID/CHANNEL. Round 2 counts only decodes
  charged over 2,048 bytes as expensive. At the attempt limit, a frame still gets
  a maximum 2,048-byte decode allowance, reduced by every remaining byte budget.
  Thus small parsed frames do not spend expensive attempts, and small reports
  remain eligible after sixteen large frames. Calls can exceed sixteen; their
  actual and conservatively charged output remains byte-bounded.
- Battle.net also charges a game-account-ID bucket. Changing character or
  renewing a handshake cannot reset that account's allowance.
- Remaining byte allowance is passed into inflation, not checked only after a
  full result. Successful decode charges its output length; failed inflation
  charges at least the selected remaining ceiling or actual partial output,
  whichever is larger. Invalid streams therefore do not receive free retries.
- Each decode-bucket table has at most 200 entries, with expired entries reclaimed.
  The existing input limit of 120 frames/sender/rolling minute remains separate.

### Replay memory excludes untracked-name refusals

The new FIFO holds at most **512 payload fingerprints for 60 seconds**. A
fingerprint is encoded length plus two rolling residues, not stored payload,
decoded table or untracked player identity. It is refusal/dedupe memory, not
proof of authenticity. Entries remember admitted, malformed, wrong-context and
inflate-failed frames, but round 2 leaves **untracked-name refusals uncached**.
Adding the name to Find therefore permits the exact same previously refused
SHRD/FBLP/FREC/FBLC or wholly untracked FCBD immediately. Successfully admitted
batches retain whole-payload replay protection. No decoded tables or untracked
names are retained. The cache is shared across carriers and transports. Hits do
not refresh the first-receipt timestamp; untracked retries still spend all byte
budgets and the separate input-frame limit.

A hit increments both `refused` and the new `deduped` counter exposed by
`Sources.lines()` / `/le net`. Decode failures and exhausted budgets increment
`refused`. The original accepted-payload replay cache remains independently
bounded to 512 packets / 1 MiB; it prevents refreshing admitted evidence even
after short-lived hash expiry. Context refusals remain cached for 60 seconds;
local tracking refusals do not. Later copies of a newly admitted frame cannot
refresh its receipt time.

### The actual reviewer bomb, not a fabricated failure

`test/fixtures/warboard-review-bomb.bin` is the reviewer's raw-DEFLATE payload:
350 compressed bytes, **603 addon-encoded bytes**, or 610 including `WBF1|D|`.
The regression first proves **262,006 output bytes and successful Ace parsing
with the former 262,144 limit**. Only then does it reset the forwarding inflate
meter and deliver the flood through real receive paths.

- One confirmed BN account, 130 copies: **1 inflate, 1,892 actual output bytes**,
  130 refusals. The handshake leaves 119 input slots: one decode and **118
  dedupe hits**; the remaining frames fail the existing frame budget.
- Twenty addon senders, 40 copies each: **1 inflate, 1,892 actual output bytes**,
  **800 refusals and 799 dedupe hits**. Each encoded copy uses real AceComm parts.
- Distinct large frames test the 131,072-byte allowance without hash-cache help.
  Round 2 migrates the attempt-cap fixtures to work above 2 KiB, tests the small
  allowance after the cap, and preserves all cross-route/account/expiry checks.
- The fixture generator reproduces the exact bytes with Python stdlib zlib.
  Raw fixture SHA256:
  `0d2af7304b78ac751c1663e50e976c860209574226ce1ac86f499429157ece52`.

These are measured inflate-byte bounds, not wall-time claims about a live client.

## S4 / N7 / N8 / N9 — round-2 owner rulings

### Aggregate work and reserved capacity

All unauthenticated routes share **196,608 charged inflate bytes (192 KiB) per
rolling 10 seconds**. CHANNEL has an additional **131,072-byte (128 KiB)** ceiling,
leaving **65,536 bytes (64 KiB)** that channel strangers cannot consume. GUILD,
PARTY and RAID use the same total, across both prefixes. Confirmed Battle.net
peers retain their sender/account budgets outside this aggregate pool; a renewed
handshake or character change does not reset the account budget.

The aggregate limit is two full 98,304-byte no-type bomb allowances. At the
reviewer's approximately 21 ms per such bomb this is **about 42 ms of equivalent
inflate work per 10 seconds**, well below the requested approximately 100 ms.
This is a cap-sizing estimate, **not a measured client-time guarantee**. Tests
assert output and charged bytes, never wall time. Remaining aggregate allowance
reaches the real inflater before expansion. Charges expire individually at
10 seconds; a FIFO with explicit head/tail indices avoids scans of every prior
sender and Lua's undefined length for tables with holes. Equal-time charges are
coalesced, without turning the rolling window into a fixed window.

At most **100 channel-only identities** may occupy the existing **200-entry
input table**, leaving 100 slots for group/BN input. A real group/BN input
promotes its row out of the channel-only count. The existing canonical per-name
rate checks remain shared across addon prefixes/routes; this input reservation
also prevents channel-only names from filling the 200-name decode table. The
input table expires idle rows at 60 seconds, decode tables at 10 seconds.

### Reproductions and honest controls

`test/fixtures/warboard-round2-bomb.bin` is byte-identical to reviewer `nt0.bin`:
298 raw bytes, 551 addon-encoded bytes, **558 bytes with WBF1 D header**; it
inflates to 262,027 bytes and parses under the former 262,144 ceiling. The stdlib
zlib generator reproduces it; SHA256:
`b1d57045e351985c7575f7a737eb342a3bc4737f4c5ccd30b93d434e439dd8d6`.
Two empty nonfinal RFC1951 stored blocks vary only ignored padding, yielding
1,024 distinct compressed streams of the same output. Every attack variant
still takes three real AceComm frames. The 800-payload test proves uniqueness,
so replay caching cannot hide aggregate-budget defects.

| Receive-path workload | Actual inflate calls | Actual committed output | Charged output |
|---|---:|---:|---:|
| 20 GUILD senders × 40 distinct bombs | 3 | 195,891 bytes | 196,608 bytes |
| 230 CHANNEL senders × one distinct bomb | 2 | 130,594 bytes | 131,072 bytes |
| 119 valid SHRD from one confirmed account in one second | 119 | 21,896 bytes | 21,896 bytes |

After the channel flood, a fresh guildmate's valid SHRD and a confirmed BN
account's valid SHRD are both admitted immediately. Orphan continuation floods
isolate sender-table pressure without inflation and still admit fresh GUILD,
PARTY, RAID and BN senders. A separate mixed-route test exhausts the aggregate
pool then proves confirmed BN still has room. Guild/group attackers can exhaust
their own aggregate pool; the reserved share protects against **channel** abuse,
not against arbitrary abuse from every group route.

The 119-report control accepts **all 119**, not just sixteen. Separate controls
prove that twenty cheap reports leave all sixteen expensive attempts available,
small reports remain eligible after expensive attempts, and sustained sub-2-KiB
frames still exhaust the unchanged 128-KiB byte limit. The independent
120-incoming-frames/rolling-minute gate remains (the handshake uses one slot).

Only three inherited regression bodies changed their assertions/fixtures:
expensive attempt identity/expiry, BN character-switch accounting, and the
owner-reversed untracked-frame caching policy. Other inherited assertions and
production modules are unchanged; neither Codec.lua nor Sources.lua changed.

## S2 — assembly ownership

Battle.net keeps the existing **16-global** unfinished-stream limit and adds
**two per game account**, with the original 90-second first-part lifetime.
Completion, count conflict and expiry release slots; duplicate parts cannot
refresh age. One account starting 16 unfinished streams every 90 seconds now
holds at most two. In the exact ten-minute starvation scenario, the other
account successfully stores **20 of 20** fresh two-part SHRD reports (baseline
stored zero).

The separate shared AceComm pool retains its own 16-global / 30-second limits.
An optional owner argument gives WarBoard **two unfinished streams per normalized
sender across both prefixes and all addon routes**. Stream identity still
includes full sender, prefix and distribution, preventing cross-route joins.
Other codec callers omit the owner and retain their existing contract.

The original global-16 regression now spreads streams over multiple accounts so
the new owner cap cannot hide a broken global bound. Existing accepted-cache
and frame-size tests similarly avoid masking by the new decode limits.

## S3 — relayed position wording

All ordinary-addon FBLP, including a same-named guild/group/channel carrier,
says **reported position** and remains relayed. Battle.net FBLP about a third
player also says **reported position**. Only a matching subject on an
authenticated eligible Battle.net carrier retains **own position**.

The coordinate subject remains the named enemy, not the relay. Approximation,
zone/subzone, native conversion fallback and provenance are preserved. The
regressions inspect the actual Find details and evidence kind on all four addon
routes, BN third-party and the positive BN-self control.

## Unchanged evidence/privacy behavior

SHRD uses its millisecond-like sentAt only for sequence/skew checks, not a
fabricated observation time; receipt life is 180 seconds and clear is scoped to
this source/type. FREC locates the killer, not the victim. FBLC/FCBD stay cached;
FBLC has no active producer in the audited version. FBLP's old held coordinates
may coexist with current zone labels, with approximation explicitly retained.

Find names and guild Watch-only names enter the existing Reported/Known path;
untracked and same-faction data are discarded. Claims cannot replace firsthand
slots, become Seen, enable Ask/Hop, alter verified kills, create alerts, or
rebroadcast to LE/WE/HH. There is no new SavedVariables schema, saved player
history or peer book. Existing shared resolver ordering is unchanged; eligible
accounts are not guaranteed selection among the first 20.

## RED → GREEN, mutants and full verification

- Final `test/src_warboard_round2.lua` and its fixture/portable-runner helper on
  an untouched detached `04fdf7a8` worktree:
  **`RESULT: 0 tests passed, 15 failed, 1536 assertions`**, exit 1.
  The production files and old mutant runner in that worktree were not changed.
  The first aggregate, sender-slot, honest-burst, untracked and portability
  regressions were also observed RED before implementing their guards.
- Candidate combined WarBoard suites:
  **`RESULT: 101 tests passed, 0 failed, 33829 assertions`**, exit 0.
  All fifteen round-2 regressions pass, alongside the original and round-1 tests.
- `python3 -B test/warboard_mutants.py`, exit 0:
  **`RESULT: 98/98 WarBoard mutants killed`** (86 retained/migrated plus 12 new).
  [warboard-mutants.json](warboard-mutants.json) records the exact rule, selector
  and assertion failure for each. Lua and Python mutations are syntax checked;
  timeout, syntax failure and outer-runner exceptions are not kills.
- Initial mutant run classified the portable-runner case as survived (97/98),
  although the Lua assertion did fail: its multiline Python diagnostic placed
  `expected ...` on a different line. Making that test's diagnostic single-line
  exposed the existing assertion to the unchanged classifier; all 98 then passed.
  No behavioral assertion was weakened and no production guard changed for it.
- The portability regression executes a real mutation from a relocated checkout
  containing spaces, an unrelated working directory and a relative TMPDIR. It
  checks the relocated report and scratch cleanup. The actual runner now uses
  `tempfile.gettempdir()` without the owner-scratch assertion.
- `python3 test/verify.py`, **foreground**, exit 0:
  **`RESULT: 1397 tests passed, 0 failed, 208973 assertions`**.
  Lua 5.1.5; 79 syntax files; API/send/static policy, harness selection, media,
  TOC and deterministic archive/source-parity checks all pass.
- Archive: `dist/LayerEnemies-1.1.0.zip`, 54 members, 247,633 bytes; SHA256
  `baaf3c3b66218a1a8719b96e91dbbb642387f9608fffad4aec0887948b66e316`.
  Foundation version remains 1.1.0 until the release PR. Generated
  verification.json retains inherited legacy descriptive strings; this report
  and README specify the WarBoard behavior.
- Logs under `/opt/data/cache/scratch/`: `le-warboard-r2-red-final.log`,
  `le-warboard-r2-focused.log`, `le-warboard-r2-mutants.log` (first run),
  `le-warboard-r2-mutants-final.log`, `le-warboard-r2-verify.log`.

Round-2 implementation/test changes are limited to `LayerEnemies/WarBoard.lua`,
the README WarBoard section, `test/src_warboard_review.lua`,
`test/src_warboard_round2.lua`, `test/warboard_mutants.py`,
`test/warboard_mutants_portability_test.py`, `test/warboard_vectors.py`, and
`test/fixtures/warboard-round2-bomb.bin`. Regenerated test, verification and mutant
notes plus this report are committed separately. Local commits only; no push.

Self-review and an added-line credential/shell/eval/pickle scan found no issues;
there are zero added outbound call lines. The parent independent review remains
separate. The multi-owner 16-slot assembly saturation noted in N6 and the direct
literal-heavy decoder performance noted in N10 were outside these owner rulings
and are unchanged. No live client, remote account, real SendGameData, fonts or
native coordinate conversion was exercised:
**native checks not run (alpha, owner's decision)**.
