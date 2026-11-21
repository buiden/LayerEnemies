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
- The initial B7 unchanged and transfer literals recorded below are historical.
  The round-1 lead rulings supersede both: no result asserts the same layer,
  and a transfer event has its own game-reported-transfer text.

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
- Focused final feature suites pass. The complete background gate and fresh
  mutation runs also pass; exact results are recorded below.
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

The corrected whole harness and gate then found one remaining historical
300-pixel unknown-page assertion in the Round1 retained-evidence test. It now
includes the same blind control as the other layout checks; its focused replay
passed. No production source changed in that last test-only correction.

## Final verification

- `heavy.sh python3 -I test/verify.py`: background run, polled to exit 0.
  `RESULT: 2534 tests passed, 0 failed, 668976 assertions`
- Syntax: 446 files, PASS. TOC/static checks and archive integrity/source parity:
  PASS. Generated evidence is in `notes/test-results.txt` and
  `notes/verification.json`.
- `python3 -I test/trust_mutants.py`: exit 0;
  `RESULT: 64/64 Trust mutants killed`. Existing rules and anchors unchanged.
- `python3 -I test/hopprobe_mutants.py`: exit 0;
  `RESULT: 25/25 HopProbe mutants killed`. Evidence is in
  `notes/hopprobe-mutants.json`. Re-anchors: none.
- README heading check: `hunks=2 version_section_hunks=0`. Only the feature
  sections Layer trust and hidden IDs, and Blind hopping and Find changed.
- ASCII additions, no private paths in added source text, no new public chat
  send, unchanged Trust/Wire/budget source and unchanged mutant runner checked.

Deferred minor: the verifier's inherited descriptive prose still describes the
known-layer hop-any route; the new mode's contract is documented in the README
feature section and this ledger. Its measured results and archive checks are fresh.

Not tested in game (alpha, owner's decision)

## Round-1 corrections

Scope: the lead's T1/T2 rulings, reviewer items 1-4 and accompanying notes.
All runtime changes followed observed assertion failures. Evidence logs are
local under `.git/blind-r1/`; the reviewer directories were read-only.

- T1/T2: unchanged says exactly `Joined NAME. No change seen; the hop may not
  have worked.` Transfer success says exactly `Joined NAME. The game reported
  a layer transfer.` The event result is a changed hop, not creature evidence.
  Unknown still says `Detecting...`. Pure text/proxy RED: 2 failures; live RED:
  2 failures. GREEN: 9 pure and 15 live tests, no failures.
- Item 1: a lone host may be picked on the click after exhaustion, while the
  last host remains excluded when another candidate exists. Preview calls
  cannot consume the exhaustion step. RED: 1 rotation failure; GREEN: 6 tests.
- Item 2: retain admitted sighting times even before the first changed result;
  compare them with the join time, not judgement time. Own, direct report and
  HeadHunter paths cover exact-join, intermediate, pre-join and delayed replay
  sightings without relying on rendering. RED: 12 failures; GREEN: 12 tests.
- Item 3: only a successfully sent whisper or an observed matching draft-send
  event arms a missed-invite result. Unsent whisper and guild drafts expire
  quietly. RED: 2 failures plus 2 sent controls; GREEN: all 4 tests.
- Item 4: keep observed invite and accepted evidence independently of the
  join watchdog. Exact results are `Accepted NAME's invite, but no group
  formed.` and `NAME invited; not accepted.` Include accept failure, auto off,
  and known acceptance converted before group formation. RED: 4 failures plus
  1 converted-acceptance failure; GREEN: all 5 tests.
- After-snapshot note: empty/unreadable evidence gives too-little, unless an
  independent transfer or stationary-player disappearance proves change.
  RED: 4 pure and 3 live failures; GREEN: 10 pure and 3 live tests.
- Tooltip note: disabled button shows its actual refusal reason. RED: 4
  failures (group, instance, pending ask, cooldown); GREEN: all 4 tests.
- Stop note: cancellation consumes converted `auto.group.blind` ownership,
  not only `blindPending`; stale timers/invites cannot resume it. RED: 1
  failure; GREEN: 1 correction test and 5 inherited lifecycle tests.
- Leave notes: blind result deadlines still run in combat, but leave waits
  for readable combat end. A third member permanently disarms that attempt,
  including a member arriving while leave is owed. RED: 8 failures; GREEN:
  all 8 tests. The existing known-mode combat policy is unchanged (16/16
  Hop combat controls). The second opinion's inherited known-mode and
  case-sensitive identity proposals are outside this fix brief.
- Creature movement note: no new creature movement or same-map gate. The
  README feature limits now explicitly distinguish this from the player's
  40-yard/same-map guard. The missing-doc assertion was RED, then GREEN.

A fresh archive of the unchanged reviewed runtime received only the augmented
Lua tests: Blind 33 passed / 38 failed; HopProbe 5 passed / 5 failed. These are
actual runs, not estimated failures. The reviewer's unmodified combat,
extra-member, converted-stop and observed-invite probes were also replayed in
private copies: 5 failures on the reviewed runtime, 5 passes on the candidate.
Unrelated exploratory expectations were not adopted as requirements.

Self-review only (no subagent review tool). The runtime diff is limited to
Find, HopAny, HopProbe, Main and UI. Frozen wire/budget/save-owner files and
TOC/version are byte-identical to the reviewed head. Existing SavedVariables
access lines are unchanged. No new public send or donor implementation.

Mutation checks:

- `RESULT: 64/64 Trust mutants killed` (exit 0).
- `RESULT: 31/31 HopProbe mutants killed` (exit 0): the original 25 are
  unchanged and still killed; six new event/text/after-snapshot rules added.
- BlindHop initially killed 16/17. The exact-join comparison mutant survived
  because later row projection could repair the count. Added a candidate-green
  primitive assertion before any projection; the rerun reports
  `RESULT: 17/17 BlindHop mutants killed` (exit 0).
- No mutant removals. Re-anchors: none; all 64 Trust and original 25 HopProbe
  definitions are byte-for-byte identical to their reviewed definitions.

The first full gate completed with `RESULT: 2572 tests passed, 0 failed,
670997 assertions`, but its collected harness lacked the final exact-join
mutant control. Its log is retained; a fresh background full gate is required
for the final augmented corpus. No runtime source changed between these gates.
The final mutation baseline is `RESULT: 72 tests passed, 0 failed, 3959
assertions` for Blind, and the pure HopProbe suite is 10/0 with 504 assertions.

README heading check on the staged candidate README:

    ok @@ -1986,3 +1986,3 @@ in: ## Layer trust and hidden IDs
    ok @@ -2012,0 +2013,81 @@ in: ## Blind hopping and Find
    hunks=2 version_section_hunks=0

Round-1 final verification (fresh background run, polled to exit 0):

- `heavy.sh python3 -I test/verify.py`
- `RESULT: 2573 tests passed, 0 failed, 671041 assertions`
- Confirmed the final exact-join mutant control appears in the full test output.
- Syntax: 298 files, PASS. TOC/static checks and archive integrity/source parity:
  PASS. Refreshed `notes/test-results.txt` and `notes/verification.json`.
- Archive SHA-256: `12ca7f2aacf4f4bb5e1790fd852a6d663e053fc111c6a7e955c321f2f8f72c03`.
- ASCII additions, no private paths, unchanged send sites and `git diff --check`:
  PASS. No version, wire, budget or SavedVariables changes.
- No open implementation questions. Not tested in game (alpha, owner's decision).

## Final lead corrections

One follow-up fix, limited to the three final review items. The production
changes are only in Main and HopProbe; README wording already states the
intended behavior and is unchanged by this fix.

- Item 1: every auto-group clear uses one helper that consumes blind pending
  ownership. Auto-off also cancels the outstanding invite. The pending record
  retains observed join time, so an orphaned expiry cannot report unformed or
  overwrite a shown result. RED: 7 failures and 6 inherited-positive exit
  controls; GREEN: all 13 cases. Auto-off covers draft, ask, accepted, joined
  and shown stages. Manual-mode controls now turn auto off before asking;
  turning it off mid-round is deliberately cancellation, not manual tracking.
- Item 2: blind groups run the existing leave guards at every roster event,
  not just the initial join. A fleeting third member permanently disarms the
  attempt before the next timer. RED: 6 failures; GREEN: 6 passes, covering
  before-result, armed and combat-wait timing for both outcomes.
- Item 3: sparse fallback uses the readability of both creature snapshots
  when the before-player count is below the existing threshold. Visible
  after-players cannot supply a missing baseline. RED: 4 pure failures and
  1 live failure; GREEN: 12 pure cases and 1 live case. Eight pure controls
  already passed the baseline, including usable player comparisons.

Unchanged reviewer repros were copied byte-for-byte into private baseline and
candidate archives; their originals were read-only. ZZ3 went from 4 passed /
7 failed to 11/0. ZZ2 went from 57/6 to 62/1: all six fleeting-member failures
are fixed. Its remaining old manual-mode expectation asks before disabling
this mode, contrary to the lead's new cancellation requirement. A separate
copy moving only that manual disable before the ask passes 63/0. The matching
repository control was migrated the same way, with no test removals. The
unchanged ZZ5 observation probes now show zero transient-member leaves, no
false unformed text, the preserved changed result, and the too-little text.
Those print-only probes are observations, not newly failing assertions.

Final augmented tests were replayed on an unchanged baseline runtime: Blind
final 6 passed / 14 failed, HopProbe final 8 passed / 4 failed. These are real
runs, separate from the already-green controls. The candidate's complete Blind
suite passes 92/0 with 4986 assertions; HopProbe passes 22/0 with 1044.

Verification, run through the heavy-job wrapper in the background and polled
to exit 0:

- `python3 -I test/verify.py`
- `RESULT: 2605 tests passed, 0 failed, 672608 assertions`
- Syntax: 299 files, PASS. TOC/static checks and archive integrity/source parity:
  PASS. All 20 Blind final and 12 HopProbe final cases appear in the full log.
- Archive SHA-256: `8ced1a74cc1e4e2302f72125aa88ba45977ed341f52e5756a0f3faebebd18df0`.
- `RESULT: 64/64 Trust mutants killed`
- `RESULT: 33/33 HopProbe mutants killed`
- `RESULT: 22/22 BlindHop mutants killed`
- Original 64 Trust, 31 HopProbe and 17 BlindHop definitions retained exactly;
  no removals and no re-anchors. Added HopProbe unreadable-baseline and
  unreadable-player-edge; BlindHop auto-off-pending, group-clear-pending,
  expiry-observed-join, retain-observed-join and roster-third-member.
- The first mutant invocation lacked a Lua executable on PATH and stopped
  before testing. The successful background rerun set LAYERENEMIES_LUA to
  the existing Lua 5.1 binary explicitly; no runner behavior was changed.

README heading check against main:

    ok @@ -1986,3 +1986,3 @@ in: ## Layer trust and hidden IDs
    ok @@ -2012,0 +2013,81 @@ in: ## Blind hopping and Find
    hunks=2 version_section_hunks=0

Scope checks: only Main/HopProbe runtime changes; all other addon files,
TOC/version, wire, budgets and SavedVariables accesses unchanged. Send, accept
and leave call sites unchanged. ASCII additions, no private paths, no donor
implementation and no public-send changes. Self-review only; native client
not run (alpha, owner's decision). No open implementation questions.
