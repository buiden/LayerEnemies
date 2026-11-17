# 1.2.0 stack review corrections (local only)

The reviewed hop head `640c24766f5a7816e431a08c8a1ffe0474e3af08` was merged into
`stack/2-hop`, with pause-before-WHO admission and the open-Who-window README
clarification. Changes were forward-merged through levels 3, 4 and 5 with
`--no-ff`. `stack/1-ui` remains exactly
`b62875efa22564c7a72a833ff4854e7880850be2`.

FLH fixes on level 4 preserve a listed player's general host flag and place
layerless FLH-only claims below real layer rows. The regression retains a
300-second-old LayerSwap host after 100 fresh FLH senders and successfully
sends the previously displayed Hop-via request. Existing War Effort reporter
ordering is retained; broad known-layer-first sorting would alter it needlessly.

Overlord fixes on level 5 remove both special height floors. The old 140px text
minimum produced a 198px rendered card after composition, despite the nominal
184px row minimum. The ordinary fixture now uses the normal measured 82px
Reported card, shows at least three rampages per page, reaches all 32, and has
no overlapping cards or inherited actions. Existing long-text measurement tests
still cover expanded pages.

Overlord admission compares canonical pool tags exactly, before evidence or
seen-ID admission. A readable ruleset or explicit realm label determines
`global`/`pve`/`rpg`/`rpv`/`hc`; unknown is never assumed PvP. Unknown local pool
blocks all traffic before assembly, including direct group GW/GD/EK. GD's inner
pool is also checked. The protocol facts were read, not executed or copied,
from Overlord 2.5.1 RealmPools.lua at
`fd8dfd58cb5d5491faadc93e8a5e8322fdb802cb`. Exact equality deliberately excludes
the donor's old geographic aliases. Positive fixtures declare readable PvP
rules and the `global` pool; inherited assertions are retained.

## Test-first evidence

Counts are passed / failed / assertions. Logs are in
`/opt/data/cache/scratch/le-stack-review-evidence/`.

- `Hop fanout: active named pause refuses click before WHO` and
  `Hop fanout: active reply pause refuses click before WHO`:
  `hop-red-click.log` **91 / 2 / 7814** -> `hop-green-click.log`
  **93 / 0 / 7830**. Tests exercise refusal, no WHO call or pending state, and
  exact 30-second recovery. An initial direct accepted-call fixture hit the
  harness's hardware-click trap; the authorized click helper was used and
  RED replayed before restoring the production guard.
- `FLH: claim never promotes a listed nonhost or changes hop-any priority`:
  `flh-host-red.log` **26 / 1 / 19622** -> `flh-host-green.log`
  **27 / 0 / 19633**.
- `FLH: 100 fresh claims cannot evict a known-layer host or invalidate Hop via`:
  `flh-rank-red.log` **27 / 1 / 19682** -> `flh-rank-green.log`
  **28 / 0 / 19689**.
- `Overlord: 32 rampages use normal measured Reported rows with several per page and no overlap`:
  `overlord-height-red.log` **29 / 1 / 15001** ->
  `overlord-height-green.log` **30 / 0 / 15710**.
- Pool-rule tests: `foreign packet pools are refused before evidence or dedupe`;
  `unknown own pool accepts no wrapped direct or partial traffic and recovers without reload`;
  `pool detection maps readable rules and explicit realm fallback without a PvP guess`;
  `GD foreign payload pool is refused on both direct and wrapped routes`.
  `overlord-pool-red.log` **30 / 4 / 15879** ->
  `overlord-pool-green.log` **34 / 0 / 17044**.

## Full verification per touched level

Every row is `python3 test/verify.py`, foreground, exit **0**, **0 failed**.
Both generated test/verification notes were regenerated at each gate.

| Step | Branch | Passed | Assertions | Evidence log |
|---|---|---:|---:|---|
| A2 | stack/2-hop | 1218 | 127516 | a2-verify.log |
| A3 | stack/3-presence | 1245 | 138630 | a3-verify.log |
| A4 | stack/4-flh | 1272 | 158304 | a4-verify.log |
| A5 | stack/5-overlord | 1305 | 173615 | a5-verify.log |
| B4 | stack/4-flh | 1274 | 158418 | b4-verify.log |
| B5 | stack/5-overlord | 1307 | 173729 | b5-verify.log |
| C5 | stack/5-overlord | 1312 | 175821 | c5-verify.log |
| FLH coverage follow-up | stack/4-flh | 1274 | 158419 | b4-final-verify.log |
| Final composition | stack/5-overlord | 1312 | 175822 | final5-verify.log |

All merges had generated-note conflicts only: `notes/test-results.txt` and
`notes/verification.json`; the last forward merge also conflicted in
`notes/flh-mutants.json`. They were regenerated, never manually combined.
Production code and test merges had no conflicts.

## Final mutations and audit

Final runs on level 5: **hop 63/63**, **FLH 39/39**, **Overlord 52/52** killed
(**154/154**). Each new rule has a mutant. Logs are `final5-*-mutants.log`;
structured results are the corresponding three `notes/*-mutants.json` files.

One legacy FLH UI mutant had an obsolete pre-composition anchor. After anchor
migration it survived because measured text still fit with a smaller minimum.
The existing FLH layout test now explicitly checks the retained 60px minimum.
That assertion passes the unchanged implementation; it is coverage, not a new
production RED. The exact mutant then died and all 39 passed. This follow-up
was also committed on level 4 and forward-merged, so the runner works on both
levels. First-run evidence remains in `final-flh-mutants-first.log` and
`flh-mutants-first.json`. No new-rule mutant survived.

Author self-review (no subagent review tool): no added-line security scan
matches; `test/verify.py` and `test/api_policy_test.py` unchanged; Wire.lua
exactly matches the reviewed hop source. Final syntax, static API/send policy,
TOC/file parity, assets, archive integrity/source parity and whitespace checks
passed. Mutant runners restored production bytes exactly.

Final archive SHA-256:
`e3bbc27cc09ac8792b62808e554a229260046a0e125ac7b4f1484e6a442f7655`.
The package/TOC remains 1.1.0 pending the separate 1.2.0 release step.
No pushes, GitHub writes or installs. Native checks not run (alpha, owner's
decision). Full heads, merge parents and latest state are in the external ledger
`/opt/data/cache/scratch/le-120-stack-ledger.json`.
