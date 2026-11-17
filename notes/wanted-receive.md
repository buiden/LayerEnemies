# PR D1 — Wanted receive only

Authority: `/opt/data/handoffs/2026-11-17-le-1.2.0/PLAN.md` sections 2A, 3, 7.1;
`audit-wanted.md`, Wanted v1.29.2 commit `4fbb231f63413ec60e6c22f36a5360cc3a24a902`.
Base: `67953cfe6ef436c2df20b536f6cca5f0114ec773`.
Local clone `/opt/data/cache/scratch/le-wanted`, branch `feat/wanted-receive`, push URL DISABLED.

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
4. Conservative release admission is incoming 1.29.0–1.29.2 only. No outgoing v.
   Stricter GUID/finite map/location/array/field ceilings are documented in README.
   Coordinates without map keep zone only. Ambiguous spotted GUID/name bindings
   and missing location are refused. Cost: some permissive donor inputs are lost.
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

- WNTD: physical 255 bytes, chunk 240, 12 parts, four unfinished per canonical
  sender **across all addon routes**; independent stream keys still include route.
- WNTDP: physical 3800 bytes, chunk 3784, eight parts, two unfinished per game ID.
- Shared unfinished cap 16; expiry exactly 30 seconds from first part, no refresh
  by duplicates; tag/total/content conflicts fail closed; rollback refuses intake.
- Encoded payload <=30272 bytes, inflate <=65536, codec nesting <=8 and logical
  values <=4096. Batches S15 / R10 / F8; record data <=64 scalar fields, strings
  <=512, live seq 1000001..2147483647. No original records retained after dispatch.
- Locations expire at 3600 seconds from observation (receipt only for E/S), reject
  any future wire time. Replay ledger <=512; refuse on full, no live eviction.
- Rate identities <=128, idle expiry120s, fixed minute caps addon60 / BNet30 before
  decode/resolution. L <=20 carriers ×12 rows, counts<=200, expiry600s.
- Existing Known remains <=300 identities. No unbounded sender/name tables.

## RED → GREEN and controls

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

## Final verification

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
