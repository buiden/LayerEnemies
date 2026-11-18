# Overlord C3 follow-up (before upstream merge)

Base: `2eff0188`. Production/test commits end at `1ec72db8`.

## Changes

- Full canonical character + realm identities from guild rows, party UnitName's name/realm pair and Battle.net game accounts. Realm display spaces/hyphens/apostrophes normalize consistently. No readable realm means no eligible source. Different-realm namesakes remain distinct. The selected source's qualified whisper identity is also NH-silent; remembered hearing is bound to the game-account identity, not just its bare wire name.
- Every Main context carries the sender, including contexts constructed inside queued NH guards. All 31 party-join offsets 100–130 seconds, with a second unselected friend, deliver exactly one X.
- `BN_FRIEND_LIST_SIZE_CHANGED` invalidates the peer cache and immediately reevaluates sources and pumps the shared transport. Removal cannot use the old 30-second eligibility cache.
- Stops remain owed through combat/instance pauses, including stops queued immediately before the pause. They resume in a 60-second safe-delivery window; shared budgets and donor stand-down remain enforced, and a successful stop is not repeated. Pending queue membership avoids duplicate admission. Native/client-refused delivery cannot be guaranteed.
- Actual NH clocks are retained across pool and own-character changes and returns.
- Busy HA only answers addressed protocol-8 HR V; protocol 5–7 and 9 controls are silent.

## Evidence

`test/src_overlord_followup.lua` executes the actual adapters, Main, queue and mocked client boundary. Its final unchanged copy on a detached worktree of `2eff0188` gives:

`RESULT: 37 tests passed, 23 failed, 3500 assertions`

No setup/syntax failures counted. See `overlord-followup-final-red.txt`. The earlier frozen 58-test pack is retained separately in `overlord-followup-red.txt` (37 pass, 21 fail). The final pack adds two independently reproduced realm/whisper identity cases. In the original guild scenario, the old head leaked 3 NH in 1800 seconds while selected; the new head selects it zero times and leaks zero NH. Positive isolated/different-realm namesake controls remain eligible and ordinary C2 guild/group traffic remains positive.

Current Overlord-focused run: `RESULT: 211 tests passed, 0 failed, 39933 assertions`.
Full `python3 test/verify.py`: `RESULT: 1656 tests passed, 0 failed, 296079 assertions`.
Syntax, TOC/static policy and deterministic archive parity: PASS. Native: not run (alpha, owner's decision).

Follow-up mutants: 8/8 killed; reachability mutants: 48/48 killed. Each new defect has a behavioral mutant. Two redundant-protection mutants initially survived after deferred-stop recovery was added: sender availability and retaining exact queued stops. Added immediate-queue and byte-identity assertions killed them; these added assertions pass on the corrected code and are not claimed as extra original defect failures. One live-account mutation anchor became non-unique after identity capture; it was scoped to the eligibility function without changing the mutant behavior.

Existing pure fixtures now include the realm that real game-account adapters already require; existing expectations/ceilings remain unchanged. Pure audience fixtures use the same full key as the adapters. The external API schema is pinned to the existing Forever source `bebcb6bf309cf41b41bd74f8ca651e6a105b2676`; `BNetGameAccountInfo.realmName` is nullable and fails closed here.

## Upstream transition

The requested fetch returned `5b8545532d82fdbfd716eb5267616c5efdf4e9bc`, not anticipated `2675e03d`. The expected commit is its ancestor; main has since merged WarBoard and tracking. Ruling: merge actual fetched main, retaining its WarBoard behavior, rather than silently pretending the older expected revision is current main. All work remains local; no push.
