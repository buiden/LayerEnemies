# PR 1 round-2 follow-up

Reviewed baseline: `4e29ccfa88950cfcc82d5f7d0240bbc2243c90d7`.
Code/test commit: `32e31bd5690bbcaf4af0644ceb68b055fe826fbc`.
Local branch: `gi-pr1-find20-r3`. No push or GitHub write.

## Corrections and unchanged scope

- Known now has independent `own`, other first-hand `seen` (guild O/Spy), and
  `reported` claim slots. A relay or death claim cannot overwrite the guild O
  when own evidence is retained. All three keep their own observation times.
  The cap is still 300 names and retention is still 3600 seconds per slot.
  Index maintenance, expiry deadlines, rollback and oldest-newest-slot eviction
  include the own slot. These are session fields, not SavedVariables.
- Own summary priority now requires a known layer and the current Find epoch,
  as well as age below 600 seconds and the current zone. A layer change or an
  unknown-at-sighting layer cannot suppress the current guild Ask target.
- The requested note is unchanged: a 599-second own sighting valid for the
  current layer stays primary beside a zero-second guild sighting in Durotar.
- Find projects the retained second first-hand detail independently of claims.
  Main adds that detail to its existing formatter; UI includes its height in
  the existing card calculation. Each is a one-line plumbing change, so own,
  guild and relay/death details remain visible rather than hiding one to fit
  the old two-slot layout. A hash line and OpenMap place can coexist with all
  three. No transport, alert, map-action or send route is added.
- `Wire.lua`, `Share.lua`, `OpenMap.lua` and `test/verify.py` are byte-identical
  to the reviewed baseline. SavedVariables references/assignments are
  unchanged. Inherited tests are byte-identical; the harness only gains the
  new `round2.lua` loader. The old own-displacement mutant is retargeted to the
  new slot expression without changing its failure criterion.

This supersedes the round-1 notes' two-entry bound and age/zone-only priority.
README now describes the three independently retained entries and layer gate.

## Test-first evidence

The new tests were run against a detached `4e29ccfa` worktree with only the
new test file and harness loader copied in. Production files there stayed
unchanged. The complete final test set on that baseline returned:

`RESULT: 788 tests passed, 6 failed, 73349 assertions` (exit 1).

The final candidate and regenerated verification notes returned:

`RESULT: 794 tests passed, 0 failed, 74757 assertions` (exit 0).

The six baseline RED → candidate GREEN names are:

- `Round2 relayed: guild O survives a newer claim beside own history`
- `Round2 death: guild O survives a newer claim beside own history`
- `Round2 retention: own guild and claim expire independently without refreshing O`
- `Round2 own: layer change releases priority to guild O`
- `Round2 own: unknown layer never takes priority over guild O`
- `Round2 UI: own guild claim current hash and OpenMap all fit`

The three additional controls were already green on the baseline: claims
without an own entry, the intended 599-second cross-zone priority, and
own-slot eviction/rollback indexing. They are not counted as RED failures.
The relay/death tests cover both own/O arrival orders, tracking before/after
receipt, and own ages of 601 and 201 seconds. They use the real O/R and
GBOUNTY dispatcher, check primary/Ask/text/UI, and assert zero sends.

A separate test-first height check failed three new cases before adding the
retained detail to `knownHeight`; text presence alone did not prove room for
that line. The focused final new suite is **9 passed, 0 failed, 2107 assertions**.

## Reviewer probe replay

The reviewer scripts were copied to private scratch; original review files
and source repository were left read-only. `reproduce.py` was changed only to
point its scratch directory and source at this clone. Unmodified
`wire_regressions.lua` was run on archived head/base and on the candidate.

For own at 1000, DirectScout O at 1500, R at 1601:

```text
Before: WIRE third-relay source=relayed spotter=RelayScout age=0 same=false ask=false uiAsk=false slots=own/relayed
After:  WIRE third-relay source=guild spotter=DirectScout age=101 same=false ask=true uiAsk=true slots=guild/relayed
```

Afterwards the text contains DirectScout, the 601-second own history, and the
separately labelled relay claim. The layer-change case changes from own /
Ask false to DirectScout / Ask true. The other-zone case remains own /
age 599 / same true / Ask false. All these probes report `error=nil sends=0`.
The separate evidence probe also retains DirectScout beside death claims,
realm-qualified evidence and tracking after receipt.

Additional unchanged reviewer probes: matching output is byte-identical to
`4e29ccfa` (**980 matches**); realms report **52 own comparisons, 0 mismatches**;
UI maximum probe reaches **20/20 cards**, with 20 current lines, no errors or
sends, independent expiry and restored non-Find frame dimensions.

## Mutation gates

The complete runners use separate frozen scratch trees, never the working
source. `test/find20_mutants.py` completed **11/11 killed**, exit 0;
`test/guild_intel_mutants.py` completed **29/29 killed**, exit 0. Every mutant
reached a harness result line and exited 1 with assertion failures, not a
syntax/load error. The restored guild-intel harness was **794/0/74757**.

Both added mutants are killed specifically by new Round2 tests:

| Added mutant | Failed tests | New tests that kill it |
|---|---:|---|
| `guild-shares-claim-slot` | 6 | Both relay/death regressions, retention, layer-change, unknown-layer and all-detail UI |
| `own-priority-ignores-layer` | 2 | Layer-change and unknown-layer regressions |

No survivor required a new test. SHA-256 inventories confirm every Lua source
and test byte was restored in both trees and matches the committed candidate.
The combined results are in `gi1-r3-evidence/mutants-summary.json`; full
per-mutant outputs remain in the two `mutants-*` scratch trees.

## Full verification and limits

`python3 test/verify.py` was run from the repository root, both before and
after the code commit, with Lua 5.1.5. Both exited 0 with **794/0/74757**.
Syntax, static/API policy, media, archive integrity and source parity pass.
Deterministic archive SHA-256 on both runs:
`5eb8ecc965141851567a21d51782e5919ae79d3d80ddeeeb89d995e835795ced`.
Generated `test-results.txt` and `verification.json` belong to the separate
notes commit, not the code/test commit.

Evidence/logs and reproducible scratch copies:
`/opt/data/cache/scratch/gi1-r3-evidence/`.
Native checks: **not run (alpha, owner's decision)**. No installation or
client capture was requested. Mock height checks do not certify native font
wrapping or client API delivery.
