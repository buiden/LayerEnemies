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
