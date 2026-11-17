# PR D1 — Wanted receive only

Authority: `/opt/data/handoffs/2026-11-17-le-1.2.0/PLAN.md` sections 2A, 3, 7.1;
`audit-wanted.md`, Wanted v1.29.2 commit `4fbb231f63413ec60e6c22f36a5360cc3a24a902`.
Base: `67953cfe6ef436c2df20b536f6cca5f0114ec773`.
Local clone `/opt/data/cache/scratch/le-wanted`, branch `feat/wanted-receive`, push URL DISABLED.
Round-1 follow-up base: `108fb6f0cb1c8f46e3c61dd392ed1b6522f7c51a`. Owner rulings
S1/S2/S3/N6 supersede the original receive bounds below. Reviewer verdict and
probes under `/opt/data/profiles/mani/cache/scratch/d120` were read only.

## Delivered

- `Wanted.lua` registers WNTD/WNTDB/WNTDP through Src.register. Independent pure
  payload/frame/record decoders plus protected registry lifecycle callbacks.
- E/S guild/channel sightings; R/F kill/death/assist/claim/bounty/spotted on
  guild/channel/whisper. Only Src.offer admits tracked names or live guild Watch
  matches to existing Known/Find claims. Same-faction participants omitted.
- Witness vs relay vs cache provenance, observed vs receipt time, observer
  percentages converted to normalized map coordinates. Measured Find Reported
  details say seen near observer; source layer text is never an LE layer/action.
- Anonymous BNet L map/layer counts in `/le net wanted`, max across carriers;
  live identity via BNet.who only. H/A/N and fast-path/control tags ignored.
- Existing Directory handles consent, standby, ownership and a conservative
  passive WantedNet<faction> join with two slots free; D1 has no roster scan.
- Zero outgoing messages, responses, requests, relays, invitations, version claim,
  signing implementation or persistent evidence/name cache. No new save fields;
  the existing nets switch mechanism is reused. No donor code/library execution
  or copying. Codec.lua, Wire.lua, BNet.lua, Adapters.lua and UI.lua unchanged.

## Scope rulings and costs

1. Wanted is numbered multipart, not AceComm (audit §3). Use addonDecode →
   inflate → lsRead and a small numbered assembler; reject AceComm controls.
   Cost: unrelated AceComm traffic is intentionally unsupported.
2. Audit §5 routes E/S only on guild/channel; whisper carries R/F. Decode
   delivered whisper records as unverified claims without creating a D2 link or
   answering anything. R's origin must equal sender outside whisper; carried R
   and every F are relayed, even if an F carrier happens to be the origin.
   Cost: D1 does not cause strangers to send data and is not an authenticated peer.
3. No signature or chain verification was requested. Require a sound outer
   envelope, scalar data and exact lowercase Adler-32; all records remain claims.
   Bounty uses seenAt, claim uses killT; missing/stale/future time is refused.
   Other records use record t (assist has no independent death timestamp).
4. Incoming 1.29.x accepts any numeric patch, including .0 and later patches;
   version text remains bounded to 32 bytes. Other minors/majors and suffixes are
   refused. No outgoing v. Sender zone text never reaches the offer projection;
   only the map-derived zone is displayed. Missing/invalid maps drop coordinates,
   unresolved maps show no zone, and there is no free-text fallback. Mapless
   evidence can remain place-unknown. Ambiguous spotted GUID/name bindings fail
   silent. Cost: free-text-only place descriptions are deliberately lost.
5. The inherited registry had counters but no per-network status callback or
   `/le net <name>` query. Add protected optional status and filtered lines, plus
   exactly one generic Main.net command branch. No event/heartbeat wiring changes.
6. Activating the first real registered source exposes two foundation-test
   assumptions. The heartbeat test now selects Main-owned timers, still asserting
   5/2/5 seconds; the queue test reuses the real Wanted registration, still proving
   its four-per-minute limit. No harness loading/mock behavior or assertion values
   changed. The source test file remains auto-discovered.
7. Src.offer feeds Find's measured Reported detail, not the separate zone-local
   Reported tab. Guild-Watch-only input is retained in Known but creates no own
   Find row. Preserve this established projection rather than invent a new board.
   This inherited product-surface limitation is also explicit in README.

## Bounds

- WNTD: physical 255 bytes, chunk 240, 12 parts, two unfinished per canonical
  sender **across all addon routes**; independent stream keys still include route.
- WNTDP: physical 3800 bytes, chunk 3784, eight parts, two unfinished per game ID.
- Shared unfinished cap 16, eight reserved for guild; channel/whisper/BNet
  together occupy at most eight. GUILD remains the only supported guild/group
  route: PARTY/RAID were not enabled by this ruling. Expiry exactly 30 seconds
  from first part, no refresh
  by duplicates; tag/total/content conflicts fail closed; rollback refuses intake.
- Encoded payload <=30272 bytes, inflate <=65536, codec nesting <=8 and logical
  values <=4096. Batches S15 / R10 / F8; record data <=64 scalar fields, strings
  <=512, live seq 1000001..2147483647. No original records retained after dispatch.
- Locations expire at 3600 seconds from observation (receipt only for E/S), reject
  any future wire time. Replay ledger <=512, <=32 per canonical transport sender
  across addon routes and packet/record kinds, <=256 non-guild (256 guild-reserved).
  Record origins cannot multiply a carrier's allowance. Refuse on any full quota,
  no live eviction: a busy sender may wait up to one hour for its own quota to
  expire; this preserves duplicate age but does not freeze other senders.
- Rate identities <=128 **per lane** (guild, whisper, channel, BNet), idle expiry
  120s, fixed minute caps addon60 per sender per route / BNet30 per game ID. WNTD
  tags/routes/basic shapes and numbered BNet shapes validate before sender entry
  admission; valid-shaped bad payloads still spend decode budget. L <=20 carriers
  ×12 rows, counts<=200, expiry600s.
- Existing Known remains <=300 identities. No unbounded sender/name tables.

## Original implementation RED → GREEN and controls (pre-round-1)

- Vertical slices observed RED then GREEN: missing sighting registration;
  assembly/fragmented sightings/faction veto (three failures); records and
  provenance/spotted (three); BNet summaries/identity/multipart (three);
  passive join and inbound rate limits (two); retained same-faction evidence;
  hash refusal counters; no passive roster scan; separate location field names;
  cross-route per-sender assembly capacity.
- Extra validation and mutation cases were added as green coverage, not claimed
  as independent feature REDs. No mutant survived the first 59-mutant run; three
  additional self-review rules were added and the complete final run killed all.
- Frozen-base negative control: detached `67953cf`, copied only src_wanted.lua
  and its constructed fixture. Actual result: **3 passed, 22 failed**, 2953
  assertions, exit1. The three passing cases are absence-safe rejection tests.
  Log: `/opt/data/cache/scratch/le-wanted-red.log`.
- `test/src_wanted.lua`: 25 cases, auto-loaded. Independent section-11 sighting
  and BNet vectors; Python-zlib/independent-serializer record vector with Adler32
  `a4804737`; 64KiB exact boundary, bomb/depth/truncation checks. 5000 deterministic
  fuzz inputs exercise decode/join/record and real event dispatch with instruction
  limits; no errors, no instruction trips or attempted sends.
- `python3 test/wanted_mutants.py`: **62/62 killed**, syntax-valid, real assertion
  failures only; no timeout or compile failure counts as a kill. Named rules and
  failures are generated in `notes/wanted-mutants.json`. No other mutant suites run.

## Original verification (108fb6f0; superseded by round-1 below)

`python3 test/verify.py` from repo root, foreground, exit0:

`RESULT: 1321 tests passed, 0 failed, 195800 assertions`

Syntax: 78 files PASS. Static/TOC/send policy and archive/source parity PASS.
API policy: 11 tests PASS (includes Wanted ownership/no-send/shared-codec policy).
The harness adds 25 tests to the inherited 1296; no inherited case removed.
Archive remains foundation version `dist/LayerEnemies-1.1.0.zip`, SHA256:
`aff997fa0041a321a6b41978cca87108cd4ca0f1999cfd653310dfb50d684587`.
Full log: `/opt/data/cache/scratch/le-wanted-verify.log`.

Final review: self-review (no independent reviewer tool in this subagent lane),
including all parser bounds, runtime claims, exact changed Main/harness hunks,
namespace isolation, silent later sound polling and source policy. Found and
fixed passive roster discovery, location-field aliasing and cross-route stream
capacity with observed RED→GREEN. Parent review remains independent.
Native checks **not run (alpha, owner's decision)**. No push or GitHub write.

## Round-1 fixes (S1, S2, S3, N6, N7)

Only `LayerEnemies/Wanted.lua` changes production behavior in this follow-up.
Shared registry, UI, codec, wire, BNet and membership behavior remain unchanged.
The Wanted README section documents the new bounds and their trade-offs.

- **S1:** independent 128-entry guild/whisper/channel/BNet rate tables; malformed
  or unsupported WNTD frames consume no sender entry. Basic parsing precedes
  allocation, while valid-shaped failed decodes still consume their rate budget.
- **S2:** the free-zone-text path is removed from both sightings and records.
  Offer projection carries map only; shared code derives the displayed zone.
  Bidi/control text cannot enter that projection. Missing/invalid/unresolved map
  IDs never fall back to the sender's wording; mapless evidence stays unknown.
- **S3:** two open assemblies per canonical sender, 16 global, eight guild-reserved;
  replay memory 512 global, 32 per transport sender, 256 guild-reserved. Sender
  ownership crosses addon routes and packet/record kinds; forged origins cannot
  multiply quota. No live replay identity is evicted. Expiry releases quotas.
- **N6:** any numeric patch in exactly 1.29.x, including .0 and multi-digit patches;
  old/other minors, majors and suffixes remain refused. No outgoing version claim.
- **N7:** mutant output normalizes Lua object addresses and writes only changed
  evidence. A Python regression proves identical bytes and unchanged mtime for
  reruns differing only in table addresses (observed RED before the writer fix).

### Reviewer reproduction and tests-first evidence

The reviewer's original `src_zzmani2.lua`, `src_zzmani3.lua` and `src_zzmani5.lua`
were copied byte-for-byte into private base/candidate snapshots, never edited.
`/opt/data/cache/scratch/wanted-r1-replay.py` executes them and asserts candidate
outcomes; all selected probes exited 0 without their swallowed-error marker.
Logs: `/opt/data/cache/scratch/wanted-review-{base,candidate}-{rates,replay,text,busy,streams}.log`.

| Review scenario | 108fb6f0 | Candidate |
| --- | --- | --- |
| 300 channel users, three hello frames/second, 15 minutes | 45/75 guild sightings | 75/75 |
| 128 junk senders refreshed every 100 seconds, 10 minutes | 0/20 guild sightings | 20/20 |
| Four channel holders, renewed every 29 seconds; five-frame guild S | 9/20 | 20/20 |
| One sender, 60 sightings/minute for 12 minutes, then another guildmate | 512 replay IDs, old map 100 | 32 flood IDs, new guild sighting map 200, age 0 |
| Sender text including bidi, conflicting or missing map | free text in Find details | map-derived zone only; no text fallback |

The five-frame regression asserts the actual serialized fragment count and uses
15 distinct zone-field values exactly as the corrected reviewer probe does.
The earlier six-identical-sightings fixture serialized into one frame; that setup
failure was corrected before implementation and is not counted as a behavior RED.

`test/src_wanted_round1.lua` adds 15 cases. The final file copied alone into a
fresh detached `108fb6f0cb1c8f46e3c61dd392ed1b6522f7c51a` worktree returned:

`RESULT: 1 tests passed, 14 failed, 796 assertions` (exit 1)

Four S1, three S2, six S3 and one N6 behavior failures were observed before their
respective implementations. The extra BNet assembly-owner case passes on the
base: it closes a mutation coverage gap, not a newly discovered baseline bug.
Frozen RED log: `/opt/data/cache/scratch/wanted-r1-frozen-final-red.log`.
Candidate focused run: `RESULT: 40 tests passed, 0 failed, 23469 assertions` (exit 0).
Log: `/opt/data/cache/scratch/wanted-r1-final-focused.log`.

Inherited test migrations are limited to the approved rules: flat rate/expiry
fixtures now address route/owner metadata; four-assembly expectations become two;
the global assembly-bound test explicitly uses guild reserve eligibility;
free-text/missing-map expectations become map-only/unknown-zone expectations;
1.29.3 moves from refused to accepted. The datagram-limit case uses an untracked
name so the new replay quota cannot mask its original 60-decode assertion.
No unrelated cases or protections were removed.

The original 62 mutant rules were retained with updated anchors; nine rules add
shape-before-allocation, independent rate tables, free-text rejection at each
projection, guild assembly/replay reserves, carrier-owned replay quota and later
1.29 patches. A BNet call-site owner mutant survived the first partial run; its
new dispatch regression killed it. Complete run: **71/71 killed**; only real Lua
assertion failures after syntax validation count. Initial direct tool calls hit
the harness's outer 420-second tool deadline; these partial runs are not reported
as complete gates. Long gates run in the foreground of a tracked PTY shell,
without `&`, with durable exit results.

The unchanged reviewer stress case with 20 guildmates, one sighting every seven
seconds for 70 minutes, remains 597/600 (global 512-entry lifetime capacity).
These fixes isolate individual/public pressure; they do not promise unlimited
traffic or eliminate the documented full-global-ledger refusal.

### Round-1 final verification

Code/tests/README commit: `fac5151ec7cd107e357556c98ab800be19e2be8d`, parent
`108fb6f0cb1c8f46e3c61dd392ed1b6522f7c51a`. Verification notes are committed
separately on top, as requested. No push, release, installation or client action.

`python3 test/verify.py`, foreground, exit 0:

`RESULT: 1336 tests passed, 0 failed, 198612 assertions`

- Lua 5.1.5 syntax: **79 files PASS**. Static/TOC/send policy PASS.
- API policy 11 tests; verifier 11; source-discovery 4; call-assets 11: all PASS.
- Archive integrity/source parity PASS; no production files outside Wanted.lua
  changed. README content outside the Wanted section is byte-identical to base.
- Five independent vectors PASS (record hash `a4804737`, inflate boundary 65536).
- **71/71 mutants killed on two complete runs.** The repeat returned exit 0;
  `notes/wanted-mutants.json` bytes **and mtime were unchanged**. Evidence SHA256:
  `4722858094a195e87e7129b963a380901094d398d500a86603e1b70e60023178`.
- Stable-evidence Python regression: **1 passed**, exit 0.
- Full log: `/opt/data/cache/scratch/wanted-r1-verify.log`; durable gate results:
  `/opt/data/cache/scratch/wanted-r1-gates.json`; repeat mutants log:
  `/opt/data/cache/scratch/wanted-r1-mutants-repeat.log`.
- Foundation-version archive remains `dist/LayerEnemies-1.1.0.zip`, SHA256:
  `e6edfe21e62d0ca1a777b8bd52cd38dc796ca196f2872230f0c2db619334e689`.

Self-review covered the complete production diff, scope isolation, changed
assertion contracts and mutation survivors. Parent's independent review/stack
merge remain outside this builder lane. Native checks **not run (alpha, owner's
decision)**; no in-game or installed-client verification is claimed.
