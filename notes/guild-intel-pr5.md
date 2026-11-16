# Guild intelligence PR 5: kill records

Base: `a61d86d0265ef108f67c9f0e4d6cefe94b2dadd5` (PR 1). Branch: `gi-pr5-kills`.
Scope: plan sections 0, 4.1, 5.3, 6, tests 11/12/12a/12b. No push or installation.

## Ledger and interface decisions

- Clean base: 771 tests passed, 0 failed, 71244 assertions.
- Decode slice RED: new tests run in a detached checkout of the exact base, with only the harness and kill test added: 773 passed, **10 failed**, 72060 assertions. Two rejection-only cases already passed. A later counter fixture used an unavailable snapshot helper; replaced that helper call with the production summary for the boundary comparison (not included in the base failure count).
- Pre-flight: D must pass the existing HH read path, not HhNet; Known needs an enum addition; Record needs distinct kill kinds; guild receive must bypass Store just like direct D.
- Ruling: retain the legacy P/L Find lifetime and source behavior. Only D enters the new HeadHunter claim source. This avoids broadening this lane into unrelated P/L changes.
- Ruling: use `kill`/`killi` as internal Record kinds too; derive the victim text and inference from origin/kind rather than saving donor records. No extra Known fields beyond the existing detail field are needed.
- Ruling: D at age 3600 is expired, matching Known's exclusive 60-minute bound. Future skew up to 300 seconds is clamped to receipt, as for existing HH records; larger skew is dropped.
- Ruling: only confidence e/i is accepted; s (sim) and unknown confidence are dropped. Incomplete flags are never repaired, and player names are validated by the existing whole-name rule. The cost of strict rejection is losing malformed or future-format records, rather than misidentifying a killer.
- Counter semantics: admitted P/L/E frames after the existing receive policy/rate gate; uppercase record kinds in structurally valid E envelopes (including ignored/rejected content); read = decoded, full-name, same-faction, retention-valid D records; fresh = those under 300 seconds; relayed = successful guild send. Repeats count as receive events, not unique kills. No per-enemy statistics.

## Existing tests changed

- `Known source scope: existing HeadHunter P and L keep the legacy Find path`: the enum-rejection assertion is replaced by accepting a HeadHunter claim in a separate pure cache. The P/L ingestion, uncached projection, ask behavior and boundary assertions remain unchanged. The enum was explicitly deferred from PR 1 to this lane.

## Protocol evidence and native limits

Read-only inspection of HeadHunter Sync/Protocol.lua death/enemy grammar and Sync/Reports.lua author-victim guard; no donor Lua executed or copied. Plan section 7 records byte-identical Sync files across 1.1.1/1.2.1/1.2.2. Fixtures are invented identities.

Target remains Forever, existing TOC interface 16001 and Lua 5.1; no new client APIs.
Native checks not run (alpha, owner's decision): actual D volume in LE-only mode, guild throttling under a large fight, real client map availability and Find rendering. Offline tests cannot establish these. No native capture or client testing requested.

## Verification

- Decode slice GREEN and first feature commit: `eaaad01071cc468300098665cb702ea304127d14`, 783 passed, 0 failed, 72428 assertions.
- Relay slice RED against that feature commit: 785 passed, **12 failed**, 73138 assertions. Two new defensive cases already passed before relay support.
- Full augmented test pack replayed on a fresh detached `a61d86d` checkout (only harness, kills.lua and frozen fixture copied; original Known test unchanged): **773 passed, 24 failed, 72661 assertions**. This is the reported base red count, not a sum estimated from slices.
- Relay feature commit: `f2e142b79ba55c2defa5cede8dfaf9f49af60a3b`. Test-only follow-up: `f5fabd67b1037c71351e3c654819e6b18b4057b8` (mutate actual D layer all the way to Find text, not just a decoded field; keep runner output in ignored logs).
- Candidate harness: **RESULT: 797 tests passed, 0 failed, 73531 assertions** (26 new cases, all inherited test identities retained).
- `test/verify.py` with Python 3.14 and lupa 2.8: **rc 0**, same harness RESULT. It exercises the counter/cache SavedVariables checks through the harness in addition to existing static/API/package gates.
- Archive SHA256: `fe16fa6e8029deb1e4f2b43c3b6dd2c49e5b218e391f45a68211cf574afe6c68`.
- Frozen old decoder is byte-identical to `git show 16549ca:LayerEnemies/Relay.lua`; SHA256 `24b4010cc267684a75cd0d16d9df68cb80629a13f7f934fe1a2a4250af10d273`. It rejects both new kinds as `invalid`.
- Wire.lua byte-identical to PR 1. No new prefix, route, recipient, dependency or saved field. Static sender policy remains Wire-only. Privacy diff scan: zero matching changed lines.
- Final review: self-review (no subagent tool). Full source diff reviewed for identity validation, retained age, claim-only presentation, layer suppression, relay limits and memory-only counters; no outstanding important findings. This does not replace the parent/reviewer's independent gate.

### Relay and integration rulings

- Ruling: enforce the rolling four-per-minute and name cooldown at dispatch, spending an attempt before Wire. A Wire refusal cannot reopen the budget. Pending wait is not a retry queue; all due refusals are dropped. This is stricter than counting only successful sends, at the cost of fewer relays during throttling.
- Ruling: the existing HH raw mesh carrier remains unchanged; no decoded D layer enters Record, Known, Find or the guild line. Mesh membership/history is never used as the read source or diagnostic counter.
- Ruling: one immutable original killer per relay, no hash-only, count-bearing, multi-enemy or layer-bearing kill line accepted. Overlong lines without the killer are dropped rather than truncated into nameless evidence.
- Native unknowns remain as above; nothing installed, pushed, or requested from a client.

### Mutation results

Runner: `python test/kill_mutants.py --lua <Lua-5.1-executable>`. Every mutation is restored byte-for-byte in `finally`; baseline and final harness must be green. It also requires the named new regression to fail (12a stand-down specifically for the mesh-gate mutant).

| Mutant | Failed tests | Result |
|---|---:|---|
| Relay old D (offer and dispatch age gates removed) | 2 | killed |
| D behind hhMesh/Net allowance | 27 | killed; 12a stand-down failed |
| Match incomplete killer | 2 | killed |
| Store and show the actual D layer in Find text | 3 | killed |
| Ask allowed on relayed kill | 24 | killed |
| Accept sim | 3 | killed |
| Ignore author/victim mismatch | 1 | killed |
| Remove kill rate cap | 1 | killed |
| Relay non-whisper catch-up | 1 | killed |

Nine of nine killed on first execution against their existing tests; zero survivors needed additional cases. The layer mutant was later strengthened from decoded storage to the full display path; the same existing tests caught it. Final restored harness: 797 passed, 0 failed, 73531 assertions.

### Read-only merge checks

Initial feature-head checks (`git merge-tree --write-tree`, no branch/index changes):

- `gi-pr3-watch` at `b933280b6d53a58c970de927c1a00c244c6f29bd`: conflict in `test/harness.lua` (both append suite registrations).
- `gi-pr4-spy` at `91448cb6e70a58ba349dac767b8ba6a7592b097a`: conflicts in `LayerEnemies/Main.lua`, `LayerEnemies/Relay.lua`, `test/harness.lua`. Combine both relay admissions/kinds and both suite registrations when integrating; do not choose one side wholesale.
- With regenerated evidence staged, a temporary commit-tree object (no branch moved) gives the final conflict inventory: PR 3 adds `notes/test-results.txt` and `notes/verification.json` to its harness conflict; PR 4 adds those two generated files to its Main/Relay/harness conflicts. Generated evidence must be rerun after integration, not selected from either side.
- No conflict resolution or integration testing of these combined branches was performed. Both checks return rc 1 because of the named conflicts; PR 1–4 and main refs were left untouched.

## Reviewer round-1 fixes and owner rulings

This section supersedes the original self-review conclusion above. Work is local
only in `/opt/data/cache/scratch/gi5-fix`, branch `gi-pr5-kills-r2`; no push,
GitHub write, installation or client test. The source clone and reviewer probe
files remained read-only. Original reviewed head: `403ed162c267434e0ebf4a3235ff9a35b20c2e0f`.

### Integration

- Base merge: `dda155e5f0be0c4c0b5d77cb91c91e711430c203`, merging
  `4e29ccfa88950cfcc82d5f7d0240bbc2243c90d7` (`origin/gi-pr1-find20`). Conflicts:
  `test/harness.lua`, `notes/test-results.txt`, `notes/verification.json`.
  Both test registrations retained. Merged harness: 811 passed, 0 failed.
- Main merge: `a38bd048cf3e405d2d665023610f4f9de5c91260`, merging fetched
  `601e421f5d1078a0e03bfeeff72e91b4804aa9df` from
  `https://github.com/buiden/LayerEnemies main`. Conflicts: `LayerEnemies/Main.lua`,
  `test/harness.lua`, and the same generated notes. Kept UNIT_TARGET and all
  three own-death events, and both sides' test suites. Unchanged main verifier
  passed immediately: 957 tests, 0 failed, 90728 assertions.
- The merge resolutions retained historical generated notes temporarily; this
  separate notes commit regenerates them from the tested combined source.

### Fixes

- **S1**, `df875b1`: both HH and guild ingress reject killer=self and
  killer=victim using existing whole-name identity. Foreign-realm namesakes
  still work; no guildmate/faction inference or Unicode identity redesign.
- **M1/S2**, `84b4382`: source/victim/record id has one session event across
  carriers. Find admission and forwarding are separate flags, so a guild copy
  cancels a pending relay but cannot renew the shown age. The ledger is capped
  at 256; full means refuse a new identity, not evict a live one. It retains
  identities for Known's lifetime plus allowed future skew (3600 + 300 s),
  covering the entire 300-second relay life as well as delayed guild replay.
  This intentionally trades new kill evidence under saturation for bounded,
  non-reopening deduplication. No saved data was added.
- **M2**, `6dc5e47` plus `ac1a0ec`: a conservative mirror accounts every
  LEGW1 attempt (O/K/F/H/R), with Wire's capacity 5, one token per 2 s and
  double combat cost. Only R requires two tokens left afterwards: its
  full-bucket burst is 5 - 2 = 3. Earlier own/control traffic reduces that
  allowance too. Refused attempts are not refunded, so this can understate
  Wire's available capacity but cannot overstate it. Each of the four
  non-relay send sites accounts immediately before its existing Wire call;
  the OwnDeath change is accounting only. Wire and send-call counts are
  untouched. The test pins mirrored capacity/refill to actual Wire source.
  Self-review found an independent three-token relay bucket insufficient
  after prior own traffic; the added regression failed both the original
  head and the first implementation before this accounting correction.
- **Share ruling**, `a55b139`: off blocks new relay offers, clears pending
  relays immediately (including off/on before the timer), and rechecks at
  dispatch. Receiving still works. Existing own O/K and War Effort sharing
  guards remain; README and the switch feedback now mention guild relays.
- Owner-deferred behavior is unchanged: +300 s future timestamps remain
  accepted, indirect authors remain claims, accented/Cyrillic cooldown
  identity remains as before, and the raw HeadHunter mesh is unchanged.

### Test-first evidence

Each defect slice was run against an isolated detached `403ed162` worktree:
only `test/kills_round1.lua` and its registration were added, preserving all
original tests and production source. The cumulative defect pack gives
**797 passed, 19 failed, 74342 assertions** on that exact original head;
every failure is the expected behavior mismatch, not a setup/collection error.
The same 19 regressions pass after the fixes. Two later green-first defensive
checks cover ledger saturation/expiry and reserve refill/rollback; they are
not counted as test-first RED failures.

RED -> GREEN names (prefix `Kills R1 `):

- `S1: HeadHunter rejects ourselves and killer equals victim`
- `S1: guild rejects ourselves and killer equals victim`
- `M1: one D id across carriers for its lifetime skew=0`
- `M1: one D id across carriers for its lifetime skew=-300`
- `S2: identical guild kill preserves age at 240 seconds`
- `S2: identical guild killi preserves age at 240 seconds`
- `M1: guild and whisper carriers share identity and stand-down`
- `M1: kill id survives legacy relay history eviction`
- `M2: mixed relay burst leaves two own tokens`
- `M2: real own sighting survives mixed burst combat=false`
- `M2: real own sighting survives mixed burst combat=true`
- `M2: legacy relay burst leaves two own tokens`
- `M2: real own sighting survives legacy burst combat=false`
- `M2: real own sighting survives legacy burst combat=true`
- `M2: earlier own traffic also counts against the prefix reserve`
- `share: off before receipt sends nothing on LEGW1`
- `share: off while pending sends nothing on LEGW1`
- `share: off then on while pending sends nothing on LEGW1`
- `share: off at dispatch sends nothing on LEGW1`

One inherited assertion migration is intentional: `relay drops instead of
queueing when the bucket is empty` now expects 3 initial R sends (not 5),
`own reserve` rather than Wire throttle, and 4 after a later new record (not 6).
Its pending-empty, no-retry and refill checks are retained. This is required
by the owner's reserve ruling, not a regression hidden by removing a test.

### Independent probes before / after

Copied the supplied `so-gi5/reproduce.py` and `probes.lua` into this job's
scratch evidence directory before executing them. Baseline copy is unchanged;
after-copy changes only SOURCE/COMMITS to select this clone's fixed production
head and the original reviewed head. Lua probe bodies are byte-identical.
Command: `python3 -I -B <copy>/reproduce.py probe all`.

| Probe | 403ed162 | Fixed source |
|---|---|---|
| Same D, other carriers +121/+242 | 3 relays | 1 relay |
| Identical guild kill at +240 | age 240 -> 0 | age 240 -> 240 |
| Four kills + one HH relay, real own O | R=5, O_at_slot=0 | R=3, O_at_slot=1 |
| Five legacy relays, real own O | R=5, O_at_slot=0 | R=3, O_at_slot=1 |
| Self killer / victim killer | located=true, relay=1 | located=false, relay=0 |
| Guild self-killer | located=true | located=false |
| Share off in kill scenario | kill_sends=1 | kill_sends=0 |
| 300-frame flood | max sliding 60 s=4 | max sliding 60 s=3 (4-attempt cap intact) |
| Frozen receiver | kill/killi invalid | kill/killi invalid |

All probe cases complete with no Main.error. Guildmate/nearby-ally acceptance,
indirect attribution, single future records, Unicode cooldown behavior and
raw HH mesh forwarding remain unchanged as ruled. Replaying a future record
now retains the first clamped receipt timestamp instead of refreshing it.

### Verification and artifacts

- Native Lua 5.1.5 is available at `/opt/data/tools/lua/lua-5.1.5/src/lua`;
  no install or venv was needed.
- `python3 test/verify.py`: **rc 0; RESULT: 978 tests passed, 0 failed,
  92464 assertions**. Main's stricter send checker is byte-identical and
  produces zero false positives. Static/API/package/source-parity checks pass.
- Archive SHA256: `7bec00142b058b78ddcb245e9cd2cddccc1a6c5112fd56400f9a5ed793bf1e3e`.
- Wire.lua and verify.py are byte-identical to fetched main. TOC is unchanged
  after the merge (PR 1's Known module and main's OwnDeath module both retained).
  Frozen receiver SHA256 remains
  `24b4010cc267684a75cd0d16d9df68cb80629a13f7f934fe1a2a4250af10d273`.
  HeadHunter.lua is byte-identical to 403ed162. Send call counts equal the
  post-merge tree: Hop 1, Hosts 1, Main 20, OwnDeath 1, Relay 1. No changed
  LayerEnemiesDB line in the fix production delta.
- **17/17 mutants killed by their expected regression**, native Lua 5.1.
  The original 9 remain, plus `repeat-kill-id`, `short-kill-memory`,
  `refresh-guild-kill-age`, `kill-self`, `kill-victim`, `spend-own-reserve`,
  `forget-own-prefix-traffic`, `share-off-relays`. The final mutation run
  uses an isolated focused harness: the unchanged real helper prelude,
  snapshot helper, and complete original `kills.lua`/`kills_round1.lua`
  registrations. Baseline and restored source: **47 passed, 0 failed,
  4027 assertions**. Addon source and individual test files are byte-checked
  against this branch afterwards; full combined verification is separate
  above. Reproduce with `python3 -I -B
  /opt/data/cache/scratch/gi5-evidence/focused_mutants.py` using a fresh
  destination, or run the checked-in `test/kill_mutants.py --lua <lua>`
  directly for the slower full-harness mutation run. An earlier full-harness
  run also killed the then-existing 16/16 before the accounting follow-up.
- Evidence root: `/opt/data/cache/scratch/gi5-evidence/` (slice RED/GREEN logs,
  `verify-final.log`, `static.json`, `mutants-final.log`, baseline
  `so-gi5/probe-all.log`, fixed `so-gi5-after/probe-all.log`). Final mutation
  work uses `/opt/data/cache/scratch/gi5-mutants-final/`, never this branch's
  source. The focused-harness preparation is preserved in `focused_mutants.py`.
- Native client checks not run (alpha, owner's decision). No real messages
  sent and no installation performed. Independent round-2 review remains
  the parent's gate.

### Files changed

Fix delta after both merges: `LayerEnemies/Main.lua`, `LayerEnemies/Relay.lua`,
`LayerEnemies/OwnDeath.lua` (accounting only), `README.md`, `test/harness.lua`, `test/kill_mutants.py`, new
`test/kills_round1.lua`; this separate notes update changes
`notes/guild-intel-pr5.md`, `notes/test-results.txt`, `notes/verification.json`.

Additional inherited merge changes relative to 403ed162:
`LayerEnemies/Call.lua`, `LayerEnemies/Find.lua`, `LayerEnemies/Known.lua`,
`LayerEnemies/LayerEnemies.toc`, new `LayerEnemies/OwnDeath.lua`,
`LayerEnemies/UI.lua`, `LayerEnemies/Wire.lua`, `notes/guild-intel-pr1.md`,
`test/guild_intel_mutants.py`, new `test/own_death.lua`, new `test/round1.lua`,
`test/test_verify.py`, `test/verify.py`.
