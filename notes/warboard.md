# PR E1 — WarBoard handshake and receive

Review baseline: `8fcbb39200a78a16408f384403205a5e5529fef0`.
Review-ruling implementation: `aabfdad53b46dd9a087b5ac01a0c03bdf1091687`.
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

## S1 — bounded decode work and all-frame memory

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

- At most **16 actual decode attempts** and **131,072 charged bytes per rolling
  10 seconds** per normalized character identity, shared across Battle.net,
  both addon prefixes and GUILD/PARTY/RAID/CHANNEL.
- Battle.net also charges a game-account-ID bucket. Changing character or
  renewing a handshake cannot reset that account's allowance.
- Remaining byte allowance is passed into inflation, not checked only after a
  full result. Successful decode charges its output length; failed inflation
  charges at least the selected remaining ceiling or actual partial output,
  whichever is larger. Invalid streams therefore do not receive free retries.
- Each decode-bucket table has at most 200 entries, with expired entries reclaimed.
  The existing input limit of 120 frames/sender/rolling minute remains separate.

### Remember every attempted payload

The new FIFO holds at most **512 payload fingerprints for 60 seconds**. A
fingerprint is encoded length plus two rolling residues, not stored payload,
decoded table or untracked player identity. It is refusal/dedupe memory, not
proof of authenticity. Entries are added after every actual decode attempt:
accepted, decoded-but-untracked, malformed, wrong-context and inflate failure.
The cache is shared across carriers and transports, so a relay flood cannot
repeat the same decompression. Hits do not refresh the first-receipt timestamp.

A hit increments both `refused` and the new `deduped` counter exposed by
`Sources.lines()` / `/le net`. Decode failures and exhausted budgets increment
`refused`. The original accepted-payload replay cache remains independently
bounded to 512 packets / 1 MiB; it prevents refreshing admitted evidence even
after short-lived hash expiry. Local tracking/context changes do not reopen an
untracked/context-refused payload before its 60-second hash expires.

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
- Distinct large frames test the 131,072-byte allowance without hash-cache help;
  distinct small frames isolate the sixteen-attempt cap across all routes.
- The fixture generator reproduces the exact bytes with Python stdlib zlib.
  Raw fixture SHA256:
  `0d2af7304b78ac751c1663e50e976c860209574226ce1ac86f499429157ece52`.

These are measured inflate-byte bounds, not wall-time claims about a live client.

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

- Final reviewer regression file on the untouched `8fcbb392` baseline:
  **`RESULT: 2 tests passed, 26 failed, 1215 assertions`**, exit 1. The two
  controls are BN-self wording and fitting normal producer payloads.
- Same regressions after implementation: all 28 pass. Combined WarBoard suite:
  **`RESULT: 86 tests passed, 0 failed, 32068 assertions`**, exit 0.
- `python3 test/warboard_mutants.py`, exit 0:
  **`RESULT: 86/86 WarBoard mutants killed`** (60 existing plus 26 added).
  Each independently changed rule has an assertion-killed mutant. The report
  [warboard-mutants.json](warboard-mutants.json) records selectors and failures;
  syntax errors, runner errors and timeouts do not count as kills.
- `python3 test/verify.py`, foreground, exit 0:
  **`RESULT: 1382 tests passed, 0 failed, 207212 assertions`**.
  Lua 5.1.5; 78 syntax files; API/send/static policy, harness selection, media,
  TOC and deterministic archive/source-parity checks all pass.
- Archive: `dist/LayerEnemies-1.1.0.zip`, 54 members, 246,601 bytes; SHA256
  `b40a76219a4c4ea7d34e00b5e9105ee5d24b98a9d6e94acf36890eb476e508cd`.
  Foundation version remains 1.1.0 until the release PR. Generated
  verification.json retains inherited legacy descriptive strings; this report
  and README specify the WarBoard behavior.
- Raw evidence: `/opt/data/cache/scratch/le-warboard-review-red-final.log`,
  `le-warboard-review-focused.log`, `le-warboard-review-mutants.log`,
  `le-warboard-review-verify.log` (all in that same scratch directory).

Changed implementation/test files: `LayerEnemies/{WarBoard,Codec,Sources}.lua`,
`README.md`, `test/{src_warboard.lua,src_warboard_review.lua,warboard_mutants.py,warboard_vectors.py}`,
and `test/fixtures/warboard-review-bomb.bin`. Regenerated test, verification and
mutant notes plus this report are a separate notes-only commit.

Self-review and a staged added-line secret/shell/eval/pickle scan found no issues.
The parent independent review is separate. No live client, remote account,
real SendGameData, fonts or native coordinate conversion was exercised:
**native checks not run (alpha, owner's decision)**.
