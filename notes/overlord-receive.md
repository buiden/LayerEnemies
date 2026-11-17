# Overlord receive-only build evidence

## Scope and revisions

- Branch: `feat/overlord-receive`; base `d9f0a71` (main, version 1.1.0).
- Implementation commit: `d19768f178690db2e24386b4af68fb4c176f6461`.
- This evidence is committed separately after the implementation. Local commits only; origin push URL is `DISABLED`. No push, GitHub write, install or live-client operation.
- Implements PLAN.md section 1 and PR 2 from `/opt/data/handoffs/2026-11-17-le-1.2.0/`, with FEASIBILITY.md row 3 and its EK correction.
- Donor: `/opt/data/projects/layerenemies-review/reference-addons-web/OverlordForever`, pinned `fd8dfd58cb5d5491faadc93e8a5e8322fdb802cb` (2.5.1). Only protocol facts were read; donor code was never copied or executed. All Rights Reserved, owner-approved **protocol only, no code**, credited with pinned hashes in THIRD_PARTY.md.

## Result

- `GW`: enemy guild name, kills, member count, zone (or place unknown) and claimed layer in Reported and `/le reports`. One row per guild, max 32, 300-second source-age lifetime. These aggregates are not player sightings, reporters or hop records.
- `GD`: named General killer as an Overlord claim in Find, using the General claim timestamp (the wire has no death timestamp).
- `EK`: named killer from a groupmate's direct PARTY/RAID death notice. Never accepted from GUILD, WHISPER, CHANNEL or a BF wrapper.
- Both killer types require an own-list Find match or an unexpired guildmate shared-watch match before any Known write. Shared-only matches are retained for a later own-list Find lookup, not silently added to SavedVariables or a new public list. Source age is preserved; they expire at 60 minutes, never acquire a layer or Ask/Hop authority, and do not displace a fresh first-hand finding's legitimate Ask target.
- No new sends, replies, forwarding, joins, SavedVariables or membership. Tests count attempted gateway calls and actual sends separately: both zero for received input, including fuzz and partial-fragment floods.

## Enforcement map (implementation commit)

| Rule | Location |
|---|---|
| Secret/type/length/control-byte handling; bounded exact splitting; unsigned integers | `LayerEnemies/Overlord.lua:6-31` |
| Fragment ID 1–64 bytes, alphanumeric/hyphen | `LayerEnemies/Overlord.lua:33` |
| Server-age check and at most 30-second future skew | `LayerEnemies/Overlord.lua:34-36` |
| Zone references at most 40 bytes, only numeric `#` resolves | `LayerEnemies/Overlord.lua:37-44` |
| 30-second partial lifetime and rollback invalidation | `LayerEnemies/Overlord.lua:46-50` |
| Origin/ID deduplication, explicit 256-slot ring | `LayerEnemies/Overlord.lua:51-61` |
| BF 255 total / 252 after BF:, 24-part wire bound, at most 2 assembled parts, 230-byte chunks | `LayerEnemies/Overlord.lua:63-70` |
| Sender-isolated assemblies; oldest-admission eviction at 32; conflicting duplicate refused | `LayerEnemies/Overlord.lua:70-87` |
| 3,600-byte packet, exactly seven fields, ID match, broadcast target, supported kind, 120-second age | `LayerEnemies/Overlord.lua:89-95` |
| 1–4 distinct path nodes, final node equals sender | `LayerEnemies/Overlord.lua:95-108` |
| Direct 255-byte framing and GD/EK exact field validation | `LayerEnemies/Overlord.lua:110-140` |
| GW version/faction, 200-byte payload, guild max 24, kills max 9,999, members max 999, layer max 99,999,999, source age max 300 | `LayerEnemies/Overlord.lua:141-155` |
| Guild rows expire at 300 seconds, cap 32, newest per case-folded guild | `LayerEnemies/Overlord.lua:156-173` |
| Preserve secret/error vs unavailable map distinction | `LayerEnemies/Main.lua:293-316` |
| Route allowlist, no combat/instance decoding, protected optional APIs | `LayerEnemies/Main.lua:317-371` |
| Freshness, tracked-name admission, claim-only Known write | `LayerEnemies/Main.lua:350-363` |
| Claim labels and Reported-only projection with no hop record | `LayerEnemies/Main.lua:373-381`; `LayerEnemies/UI.lua:170,227-229` |
| Shared existing Find name/realm matcher | `LayerEnemies/Find.lua:148-157` |
| Existing one-hour Known lifetime and claim priority remain in force | `LayerEnemies/Known.lua:4,62-97`; `LayerEnemies/Find.lua:235-253` |
| `/le net` session counters and prefix registration | `LayerEnemies/Main.lua:2058-2059,2182` |

At most 32 partial assemblies hold bounded sender/ID metadata and a single pending chunk each (two received chunks immediately complete and remove the assembly). No fragment buffer, seen-ID ring, guild row or received killer is persisted.

## Execution evidence

Commands run from the repository root, foreground, Lua 5.1.5:

```
python3 test/verify.py
RESULT: 1148 tests passed, 0 failed, 133399 assertions
```

- Syntax: 56 Lua files passed.
- TOC/static/send/API gates: PASS; archive integrity and source parity: PASS.
- Focused suite: `lua test/harness.lua --overlord-only` -> **29 passed, 0 failed, 14952 assertions**.
- New tests include 5,000 deterministic random malformed frames, 2,000 partial-fragment flood frames, both two-part arrival orders, frame/packet boundaries, identity/path checks, stale/future timestamps, hostile/secret values, map-API throws, existing sighting priority, UI and slash projection, no-sends and no-save checks. Existing harness also keeps its original fuzz suite.
- `python3 test/overlord_mutants.py` -> **47/47 killed**, including all eight plan-listed mutants. Every mutant is syntax-checked and must fail its designated behavioral test; source bytes are restored in `finally`, then the unmutated focused suite passes. No survivor required a test-only weakening or replacement. Details: `overlord-mutants.json`.
- `git diff --check`: clean.

### RED -> GREEN

- Untouched base full gate before edits: **1119 passed, 0 failed, 118428 assertions**.
- First GW end-to-end test: **0 passed, 1 failed**, missing receive state -> **1 passed, 0 failed**.
- Fragment/path/dedupe slice: **4 passed, 6 failed** -> **10 passed, 0 failed**.
- Killer claim slice: **11 passed, 7 failed** -> **18 passed, 0 failed**.
- Bounds/diagnostics/failure guards: **22 passed, 4 failed** -> **26 passed, 0 failed**. A malformed-route test helper initially replaced `false` with the default GUILD route; corrected the helper before its red run, without changing assertions.
- Map admission before dedupe: **27 passed, 1 failed** -> **28 passed, 0 failed**.
- Final self-review found the generic zone helper collapsed secret map objects into unavailable maps. New whole-object/type/parent test: **28 passed, 1 failed** -> **29 passed, 0 failed**. Field getter exceptions needed their own protected read because the nested Layer.zone safe call otherwise swallowed them as unavailable.
- Final tests copied alone into a detached `d9f0a71` worktree (no production files copied): **1 passed, 28 failed, 1207 assertions**. The passing test is the negative untracked-ingress check; missing decoder/API failures and positive claim assertions account for the failures. The temporary worktree was removed. Full raw result: `overlord-red-base.txt`.

## Frozen gate and artifact

`test/verify.py` and `LayerEnemies/Wire.lua` are byte-identical to the base (`git diff --exit-code d9f0a71 -- ...` passed):

- verify.py SHA-256: `a6c4e07bfbaeaed3492f411e0dff44382fe1208f2d13e2d3dacfe2ade80ec67a`
- Wire.lua SHA-256: `b4597f4426fea31078d6a2012f45d3f04e8a1cea190bf768c3e8252a03a1c99e`
- Offline artifact: `dist/LayerEnemies-1.1.0.zip`, 48 members, 206177 bytes.
- Archive SHA-256: `3f5957a5317c6ffb76e125d974f7d20f1e7fad11d0726d0cf07d5efaec191f5b`.

TOC/package version deliberately stays 1.1.0: this is an unreleased 1.2.0 lane, not the version-bump/release lane. README has `Unreleased - Overlord (receive only)`. Generated verification.json retains the unchanged verifier's historical descriptive strings; the exact current Overlord behavior and extra fuzz/mutants are documented here.

## Rulings and limits

- The explicit builder instruction to branch from d9f0a71 overrides the plan's held-fix merge ordering. This lane has no who/fan-out dependency; integration merges remain caller-owned.
- GW is the plan's explicit guild-aggregate exception to the tracked-player filter; it infers no player identities or rankings.
- General claim time is not a death time: age from claimTs is deliberately conservative, so a General claim older than an hour produces no stored killer. Direct EK uses the 120-second freshness bound; GW future skew is conservatively capped at 30 seconds, stricter than the donor's inner-payload allowance.
- An empty GW zone/layer is legitimate donor data and remains unknown. Non-numeric # refs are malformed, not guessed. No donor front/capture-zone datasets are imported.
- Guild shared lists carry hashes rather than a full new Find roster. Shared-only matches are retained as claims for later tracking; the existing own-list-only Find UI remains unchanged.
- Final review: self-review (no subagent tool). The parent's independent review is still separate. No security finding or known failing test remains; no deferred code-review minors.

## Not run / not knowable offline

**Not tested in game (alpha, owner's decision)**; native testing is not a merge/release gate and no test is asked of the owner.

Unknowns: how much Overlord traffic reaches actual GUILD/PARTY/RAID, live map availability/names, platform secret-value behavior beyond the mocks, and native font/layout rendering. No traffic means no new rows; unsupported/unreadable inputs fail silent. This lane is not an Overlord relay peer and receives none of the whisper mesh or Battle.net bridge traffic.
