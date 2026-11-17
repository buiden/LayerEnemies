# PR 3a — Forever Layer Hop receive only

Base: `d9f0a71262d35cc59f1292757ed266ca08680eb9` (main, 1.1.0).
Implementation commit: `1b87ca978f320e88fdfb12219310f49df6498572`.
Branch: `feat/flh-receive`. Local clone: `/opt/data/cache/scratch/le-flh`.
Push URL is `DISABLED`; no push or GitHub writes. This notes/evidence change is
separate from the implementation commit. Version remains 1.1.0 with an
Unreleased README section: this is not the 1.2.0 release commit.

## Scope and wire

Approved reference: `/opt/data/handoffs/2026-11-17-le-1.2.0/PLAN.md` sections 1/5,
plus BRIEF, FEASIBILITY and GATE in that folder. The source ZIP hash matches
Forever Layer Hop 0.1.9 in the plan. Source was read only, never executed;
THIRD_PARTY.md credits **protocol only, no code**. No donor implementation,
assets or libraries were copied.

`FLH.lua:28` decodes all nine specified forms: **HI, WP, WR, CQ, CA, LQ, LO,
LR, LN**. Both separators, mixed separators, empty positions and optional
trailing metadata are supported. Numeric fields use decimal syntax; malformed,
unknown, secret, control-containing and over-255-byte lines return nil. Version
is opaque, not a compatibility gate. Presence may have map 0 / empty key but
cannot become a usable host. Valid positive decimal key spelling is retained.

Only direct **HI/WR/CA** on GUILD/PARTY/RAID/WHISPER can update hosts. Requests,
offers and refusals are parsed but cause no action. No responses, membership,
probes, channel joins, invitation handling, forwarding or new sends were added.
Runtime tests count **zero client sends and zero Wire.send attempts** from
received lines, including timer drain. Ignored/self/unreadable senders and
combat/instance ingress are dropped. Guild ingress requires guild membership.

## Integration and decisions

- `Main.lua:242` dispatches FLHNET2; `Main.lua:2103` registers receive-only.
- `Main.lua:728` accepts presence into `Hosts.flh` (`Hosts.lua:46`).
- `Hosts.lua:8,40` gives FLH its own **180 s** lifetime (expiry at >=180), with
  rollback removal and a 64-entry oldest-eviction cap. The 720 s LayerSwap
  reply cache remains independent. Host flag 0 or well-formed unknown place
  withdraws only that sender's FLH entry.
- `Main.lua:957–962` supplies the FLH cache to `Invite.collect`.
  `Invite.lua:173–191` merges by the existing full player identity key, retaining
  foreign realms, adding `flhKey`, `flhAge`, `hosts.FLH` and the source label.
  It filters current map and freshness, and preserves other sources' layer,
  zoneUID and age. `listed=true` never treats passive FLH as invitation trust.
- `Main.lua:947` labels the claim and its own receipt age; Friendly rows get
  enough additional text space, including a merged-source case. Very long keys
  are visibly abbreviated only for display.

Ruling: FLH's key is creature GUID **field 5 (zoneUID)**, whereas LE's existing
Bulo/LayerSwap layer comparator uses **field 3 (server)**. The plan calls this a
value LE already reads, but that does not establish interchangeable namespaces.
FLH is therefore separate, labelled evidence, never a server key or a LayerSwap
host capability. FLH-only rows allow the existing player-sent manual Ask flow
once own layer is known, not automatic hopping. Cost: automatic FLH hops remain
in PR 3b, as required; comparable sources may still filter a merged row as same
layer. No claim of a reliable cross-client zoneUID comparison is made.

Ruling: the explicit build instruction selects main, not the held hop fan-out
branch. This receive-only lane does not edit Hop.lua/HopAny.lua. Cost: the parent
must preserve this namespace/action boundary when composing 3b with fan-out.

Ruling: a valid non-host or unknown-place presence withdraws the prior FLH host
rather than leaving it actionable for the rest of its TTL. Malformed input does
not change or refresh it. Cost: a temporary unknown place hides that host until
the next usable presence; other protocols' data stays intact.

## Tests and evidence

Commands run from the repository root with Lua 5.1.5:

```
/opt/data/tools/lua/lua-5.1.5/src/lua test/harness.lua --flh-only
python3 test/flh_mutants.py
python3 test/verify.py
```

- Untouched baseline full gate: **1119 passed, 0 failed, 118428 assertions**.
- Test-first slices were watched fail before each implementation: missing HI
  decoder; remaining presence layouts; hop layouts; optional/empty grammar;
  dedicated cache; receive dispatch; host projection/labels; UI text space.
- Frozen baseline replay: detached worktree of d9f0a71, with only candidate
  `test/harness.lua` and `test/flh.lua` copied in, produced
  **RESULT: 0 tests passed, 26 failed, 1095 assertions**, exit 1. Failures include
  missing-module/cache APIs, not 26 distinct runtime defects. Worktree removed
  after retaining logs under `/opt/data/cache/scratch/le-flh-work/`.
- Final FLH suite: **RESULT: 26 tests passed, 0 failed, 19575 assertions**.
  Includes **5000 additional deterministic byte/structured fuzz inputs** through
  the decoder and real event dispatcher; data persistence, unknown own layer,
  cross-zone visibility, 179/180/181 s boundaries, rollback, donor-installed
  receipt, identity merging, malformed metadata and no-send behavior.
- Mutation result: **37/37 killed**, then clean 26-test rerun. Exact patches and
  reproducible isolated-copy runner: `test/flh_mutants.py`. Per-rule failures:
  `notes/flh-mutants.json`. Includes the three required mutants (host 0 accepted,
  removed length cap, 720 s expiry), plus field validation, transport, identity,
  provenance, namespace, persistence and UI guards. One initial survivor
  (removed control-byte check) needed a metadata-control case: ordinary fields'
  S.str guards had hidden the gap. That added case passed unmutated code and
  killed the exact surviving mutant; it is not claimed as a new production RED.
  An initially nonunique mutation selector was narrowed before the complete run.
- Two intermediate full runs caught old `/le hosts` text compatibility failures.
  Original assertions were left unchanged: the old reporter wording was retained
  and FLH status appended after the existing status text. Final full result:
  **RESULT: 1145 tests passed, 0 failed, 138022 assertions**, exit 0.
- `test/verify.py`, Wire.lua, Directory.lua, Hop.lua, HopAny.lua and Adapters.lua
  are byte-identical to base. The harness adds only a receive-prefix declaration,
  focused test selector and new-suite wiring; outgoing ROUTES is unchanged.
  No SavedVariables schema or write was added. Static API/send policy, Lua syntax,
  TOC parity, asset tests, git diff --check, archive integrity and source parity pass.
- Verification archive (not a release): `dist/LayerEnemies-1.1.0.zip`, 48 members,
  SHA-256 `6b48a707c74457200cab07ecf5936797ed2c6261b1878f22ca0af0ce75799056`.
  The unchanged verifier's `fuzz_inputs: 5000` describes its existing suite;
  the FLH-specific 5000 cases above are additional.

Final review: **self-review (no subagent review tool)**. Reviewed source and test
diff, exact wire facts, ingress-to-list flow, action isolation, legacy behavior,
no-send/SavedVariables constraints and static security scan. No deferred code
findings. Independent review by the parent/reviewer is still appropriate.

## Files

Implementation: `LayerEnemies/FLH.lua` (new), Hosts.lua, Invite.lua, Main.lua,
UI.lua, LayerEnemies.toc. Tests: `test/flh.lua` and `test/flh_mutants.py` (new),
harness.lua. Documentation: README.md, THIRD_PARTY.md. Separate evidence commit:
this file, flh-mutants.json, regenerated test-results.txt and verification.json.

## Live-only unknowns

**Not tested in game (alpha, owner's decision)**; no client test requested.
Actual FLH guild/group host population, native prefix/event delivery, transport
sender spelling, and font wrapping remain unverified. Passive receipt cannot
promise whispers; no membership request is made. Directory admission, answers
to LE-authored probes/presence, offer correlation and an actual FLH hop are all
PR 3b work, not claims made by this build.
