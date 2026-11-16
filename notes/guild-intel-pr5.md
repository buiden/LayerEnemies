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

Pending relay slice, mutants, full gate and read-only merge checks.
