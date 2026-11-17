# G1 — ChehulNet receive-only HELLO

Authority: `/opt/data/handoffs/2026-11-17-le-1.2.0/PLAN.md` sections 2A, 3 and 11; FEASIBILITY ChehulNet correction. Base `67953cfe6ef436c2df20b536f6cca5f0114ec773`. Local clone/branch only; push URL DISABLED.

## Implementation ledger

- Preflight: source registry dispatch and counters are present; new suites are auto-discovered. The approved Friendly measured-card layout is reused, not redesigned. Target remains Forever Interface 16001.
- Ruling: use `ChehulNet.lua` and `test/src_chehulnet.lua`, as the delegated brief overrides the older short names in section 11.2. No compatibility alias is needed.
- Ruling: section 11 explicitly requires ally identities, overriding the generic tracked-enemies-only rule for this separate memory-only store. No `Sources.offer`, Find, Reported, relay or host-cache insertion is permitted.
- Ruling: render hints in a separate Friendly projection, never Main.candidates or hop fan-out input. Only existing actionable rows gain a display annotation; unknown allies have no action. This prevents an ally hint from becoming an invite target elsewhere.
- Ruling: minimal UI projection and one `/le layer` dispatch line are necessary shared edits beyond the TOC. Registry alone has no UI/command extension seam; receiving and ticking still use only Src.register.
- Ruling: accept six HELLO fields (legacy missing layer), reject five or fewer and eight or more. A malformed optional layer is unknown, not a malformed HELLO envelope. A valid map may remain without its UID, but neither value is an LE server key.
- Donor release page rechecked: latest GuildOS tag `v1.28.0`. Both network files downloaded as data to the external evidence directory, SHA-256 matched the plan, sender/receiver inspected, never executed or copied. Author: `danielcosta42`.

## Verification and review

- Parser slice: 1 failing case → 1 passing. Store slice: 3 new failures → all 4 passing. Registry slice: 3 new failures → all 7 passing. UI/command slice: 3 new failures → all 10 passing. Display-context regression: missing clock incorrectly asserted `other`, then passed after fail-closed clock/adapter protection.
- Frozen-base control at `67953cf`, unchanged inherited harness plus only `test/src_chehulnet.lua`: **0 passed, 13 failed**. This is the absent-feature control, not an estimated assertion count. The incremental red logs are the tool output; frozen-base output is retained in the evidence directory.
- Focused final suite: **13 passed, 0 failed, 12,870 assertions**, including 5,000 seeded inputs (random bytes plus valid-shaped traffic) through parser and real registry, and a per-parser instruction ceiling. Fuzz/live-map coverage was added green, not counted as implementation RED.
- Mutants: **49/49 killed**, each syntax-valid and run in an isolated TMPDIR copy. One initial survivor (parser's readable-scalar secret gate) was caught only after adding a direct-parser scalar-secret test; registry admission had masked it. No production change was needed. The final 49 include an additional real text-height mutant. `notes/chehulnet-mutants.json` contains rule-level assertion failures.
- First full verify: 1308 passed / 1 failed. Root cause was the old heartbeat fixture asking for the earliest timer from *any* module, now observing the registry's specified 1-second source timer rather than Main's unchanged 5/2-second heartbeat. Preserved failed output: `verify-before-heartbeat-fixture.txt`.
- Ruling: update only that existing test's callback-owner selection, retain its exact Main 5/2/5-second assertions, and additionally require Sources' 1-second timer. No production heartbeat/registry change. Narrow test red → green (1 case, 48 assertions). Cost if wrong: a wrongly attributed callback would fail the owner-specific expectation, not silently change production cadence.
- Final review: self-review (no independent reviewer tool in this subagent lane); parent review remains independent. Checked full source and glue diff against the plan, recipient identity, map/UID separation, expiry/caps, private storage, switch, measurement and all prohibited side effects. No deferred finding. The receive-only module has no send, directory, enemy projection, SavedVariables, donor loader or UI-text API reference; static gate passes.
- Final `python3 test/verify.py`: **exit 0; RESULT: 1309 tests passed, 0 failed, 188015 assertions** (inherited 1296 + 13 G1 cases). All 77 Lua files compile. Eleven verification tests, eleven API-policy tests, four harness-discovery tests and eleven media tests pass; deterministic archive integrity/source parity passes. Package remains 1.1.0 pending the release PR; SHA-256 `8b2ce2221db0d7193a470d771d7036601d8a46bdcc4d97faa4bda0e693f09181`.
- Code/docs and generated verification/mutant evidence are committed separately. `Wire.lua`, `Directory.lua`, `Sources.lua`, `Hosts.lua`, `Invite.lua`, `Find.lua` and `Reports.lua` are byte-identical to the base. Main changes only by the `/le layer` dispatch line. No push, GitHub write, install or donor execution.

Evidence logs: `/opt/data/cache/scratch/le-chehul-evidence/`. Native checks: not run (alpha, owner's decision).
