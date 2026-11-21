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

## Progress

- Probe RED: pending.
- Rotation, UI/event wiring, Find count, mutants and full verify: pending.

Not tested in game (alpha, owner's decision)
