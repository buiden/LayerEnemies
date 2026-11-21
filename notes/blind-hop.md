# Blind hop implementation ledger

Scope: layer plan section 6 B1-B10 and section 7 item 2, PR 3 only.
Base verified equal to origin/main before edits. Version, saved schema and Wire
budgets are frozen. All tests use mocks; no donor source is copied.

## Audit and interfaces

- Trust.state/own are the PR 2 authority; every unknown/blind guest path must
  avoid layered requests and layer comparisons. Known hopping stays intact.
- Existing HopAny fallback uses the unconstrained LayerSwap whisper. Guild
  chat and manual whispers remain drafts armed by the existing send events.
- B1a citation correction already ruled by the owner: keep unknown
  `Detecting...`; blind is `layer hidden`.
- B9 is already implemented by PR 2: guild membership and existing host gates
  remain; unconstrained requests invite with no layer-valued reply, no addon
  filter. Add positive/negative regression coverage, not a new host protocol.
- B10's safety check also exists in PR 2; preserve it and add the required
  click-again wording and event-time cancellation.
- Other cited hop routes, invite correlation and leave guards still match
  their cited behavior after line movement. No unsupported citation used.
- Literal B7 text includes `you may be on the same layer`, despite the next
  sentence's blanket ban on that phrase. Preserve the required literal; do
  not introduce same/other-layer assertions elsewhere.
- Ruling: a transfer event uses B7's creatures-changed success text (there is
  no sixth event-specific text). It proves only the configured proxy; it
  does not certify that observed creatures changed. Owner can choose a
  different literal in a later wording change.

## Implementation and evidence

- B1/B1a: one blind button on every tab; exact tooltip, hidden-layer bar and
  blind click. Unknown keeps Detecting. Table sources retain network labels.
- B2/B3/B4: one ask per click, session-only 200-name rotation, alternate
  networks, last-host exclusion, oldest-try restart after the exact exhausted
  message. Existing fallback packet and player-sent guild/whisper drafts only.
- B5/B8: existing correlated acceptance and leader/instance/manual-leave gates;
  cancellation disarms pending invitations and old timers. No blind answer
  creates a sixth result message.
- B6/B7: pure snapshot classifier; 5/15/30 second checks, named thresholds,
  NPC-plus-spawn equality, unreadable-creature fallback, strict 40-yard 3D
  movement test, and the five literal results. No GUID field is displayed.
- B9: inherited implementation left unchanged; positive unconstrained and
  negative layer-named/no-same tests pass on the base as well as the candidate.
- B10: immediate round cancellation on trust loss and exact click-again text;
  stale blind-painted clicks cannot silently become known-layer fanout.
- Find: only changed hops increment the session count; admitted sightings
  reset it at ingress, including between hops without UI rendering. The line
  is part of the existing measured-row builder. No sighting format changes.

Tests were written and run before their implementation. A final replay copied
only the five new Lua test files onto an unchanged base runtime in a private
archive under the evidence directory:

- Blind: 2 passed, 32 failed, 1537 assertions. The inherited B9 behavior and
  the existing painted-target refusal are positive controls, not feature RED.
- HopProbe: 0 passed, 9 failed, 395 assertions (module absent on base).
- Focused feature suites passed before the full gate. Final full verification
  and fresh mutation runs are in progress; the final results are recorded below.
- Initial HopProbe mutants: 22/25 killed. Added baseline-green controls for
  after-unparsed, spawn-identity and snapshot-cap; then 25/25 killed. These
  three added controls are not claimed as newly failing production behavior.
- Existing Trust mutants: 64/64 killed; no IDs, cases or anchors changed.

## Final review

Self-review (no subagent tool), not independent review. Source and route scope
checks found no version, SavedVariables, Wire, public-send or donor-code changes.

The first full verify failed the strict global-write bytecode gate: the larger
Main chunk moved the literal owned LE key beyond the compiler's inline-key
range. The export now runs at the same execution point in a small local
function, keeping its key literal in bytecode. The ownership gate is unchanged;
its focused check passes. A separately attempted Python gate run timed out and
is not counted as a pass; the background full verify reruns that gate.

The next full gate completed its Python checks but reported 2512 passing and
21 failing Lua cases. Review separated actual regressions from intentionally
changed unknown-state behavior:

- Fixed the known-bar preview sentinel; existing Hop bar and combat suites
  now pass without changed assertions.
- Preserved the old card capacity by adding the blind control's 26 pixels to
  the page, not subtracting it from row space. Existing paging, mixed-source
  and geometry checks retain their assertions; the explicit unknown-page
  height/offset checks now include that control.
- Preserved numbered-command list freshness checks before blind delegation;
  the original zone-change/stale-list regression is unchanged.
- Added and observed a failing real-join deadline test. A known group that
  loses trust now schedules the remaining checks against its original join
  time; its 30-second leave deadline is unchanged. The new test passes.
- Migrated the old unknown-host/report refusal cases to the specified single
  unconstrained ask and hidden per-row controls. Their known-mode controls,
  cooldown and no-repeat assertions remain. The Overlord pooled-action test
  now explicitly establishes known trust; unknown coverage asserts hidden
  row actions plus the single blind control. No tests were removed.
- A direct whole-harness run and a fresh background full gate follow these
  corrections. The strict guards and all existing mutant definitions remain.

Full verification: pending.

Not tested in game (alpha, owner's decision)
