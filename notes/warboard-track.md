# PR E2 — WarBoard tracking request and mandatory withdrawal

Authority: `/opt/data/handoffs/2026-11-17-le-1.2.0/PLAN.md` sections 1, 3 and 8.5;
`audit-warboard.md`, WarBoard Forever 1.6.3. Reviewed E1 base: `65904e66`.
Clone: `/opt/data/cache/scratch/le-warboard-track`, branch `feat/warboard-track`.
Local commits only: no push, GitHub write, donor execution or donor code copied.

## Round-2 rulings correction (e1bc2239 baseline)

Authority: the parent's M1/S1/S2/S3/N1/N2 rulings and the read-only verdict
`/opt/data/profiles/mani/cache/scratch/t2/parent-verdict-e2-r2.txt` plus probes 5–8.
The rest of this note is historical evidence unless explicitly updated here.
The original e1bc2239 source is frozen in `/opt/data/cache/scratch/le-e2-r3-base`.
All regressions use an independent target model: a target's A answers our H,
but only our A confirms us at the target. No donor code was copied or executed.
Donor 1.6.3 `Services/WarBoard_ForeverComm.lua:1164–1192` was read directly.

- M1: H/A's private exception uses `needsHandshake` at admission and dispatch,
  not mere debt membership. Six exhausted attempts and sent-unverified debt
  permit no exceptional H/A under share off, source off or Guild only.
- S1: record the proof actually used by FBUN. A listing invalidates that proof,
  not a newer unused exchange; repeated rosters cannot wipe the waiting resend's
  fresh confirmation. The send-time comparison also preserves a confirmation
  newer than an out-of-order roster.
- S2: with real WarBoard loaded, only observed target H refreshes cleanup proof;
  A-only traffic does not. Unsafe H retains its receipt timestamp: resuming after
  20 minutes cannot manufacture a fresh confirmation. LE never sends donor-owned H/A.
- S3: each character login/reload resets retained debts to six fresh attempts,
  still three per 600-second window and at least 60 seconds apart. The bounded
  per-character GUID array/attempts map remains; toggles do not reset counters.
- N1: a genuine confirmation under 20 minutes old permits FBAK while tracking
  and ordinary send settings are enabled. An answered H alone is not a received-A
  confirmation; that narrower existing test remains, with corrected wording.
- N2: defer known-account data while unsafe, at most 128 frames / 262144 bytes.
  Check rosters with their original receipt-time age and current account GUID
  before silence settlement. No unsafe account scans/sends, no delayed Find
  admission. Overflow/unvalidatable input invalidates the account's silence
  fallback rather than declaring success. Existing decode/fragment/rate caps stay.

Ruling: bounded-inbox overflow fails closed by retaining uncertainty — otherwise
any finite queue could silently lose the only roster contradicting withdrawal.
Cost: extra bounded retries or waiting for a later login, never fabricated success.

Tests-first evidence so far (against e1bc2239 unless noted): M1 0/6 → 6/0,
120 A per two hours → 0 for all three stop settings; S1 20/4 → 24/0,
donor timings 13/15 → 15/15 and own offset 313 delayed 603 → 315 seconds;
S2 1/4 → 5/0, A-only FBUN 1 → 0; S3 0/3 → 3/0, saved count 6 → 0
at login with six new bounded attempts and working-client recovery.
N2 0/4 → 4/0. The additional stale unsafe-H case separately failed on 5311971
(`expected 0, got 1`) before preserving its age. N1 runtime reuse already passed.
Logs use `/opt/data/cache/scratch/le-e2-r3-*.log`.

Assertion migrations: `test/src_warboard_debt.lua` replaces the permanent
six-attempt/reload assertion with next-login recovery, changes restored count
6 to 0, and renames the answered-H-only negative test without changing its
behavior. All other inherited tests remain unchanged. Mutant anchors track the
same receiver guards after deferred-context refactoring; obsolete permanent
exhaustion mutants now enforce the owner's per-login bound. New ruling mutants
cover each correction plus inbox bounds and age. Final reports/verify notes are
committed separately after execution, as recorded below.

### Final round-2 correction evidence

- Final independent ruling file on untouched **e1bc2239**: **24 passed, 26 failed,
  3365 assertions** (50 collected cases, all failures are assertions). Per family:
  M1 0/6; S1 20/4; S2 1/5; S3 1/3; N2 1/7; N1 1/1. The already-green controls
  and later mutation-strengthening cases are not claimed as original RED.
  Log: `/opt/data/cache/scratch/le-e2-r3-final-50-base-red.log`.
- Candidate: **50/50 ruling cases**, **241 total WarBoard cases**. Donor-loaded
  offset sweep **15/15** withdraws at offset+1 seconds, with no LE H/A. Own
  offset 313 now withdraws at **315**, not **603**, seconds; other own offsets
  remain offset+2. The reviewer's log, not its informal 303→603 shorthand, is
  the timing authority. Newer delayed roster confirmation is retained too.
- M1: **120 A / two hours → 0** after exhaustion in each privacy mode, plus
  **1 → 0** while only sent-unverified debt remains. Next login grants six fresh
  attempts by S3, then closes the exception again; two hours of 60-second H
  prompts after that second exhaustion also produce zero H/A/FBUN/FBAK.
- S2: A-only safe/combat/instance confirmations produce **0 FBUN and retained
  debt after 15-minute silence**, rather than one rejected FBUN and false
  settlement. Real target H produces prompt withdrawal with zero rejection.
  An already established, still-fresh exchange withdraws within five seconds
  when the real addon loads. A relogged A-only peer (even one that remotely
  remembers us) must now wait for target H: LE cannot infer that hidden remote
  state from A. Unsafe H older than 20 minutes also waits for new H.
- S3: each of two failed logins permits **6** attempts, preserving **3/600 s**
  and **60 s** spacing. Toggling does not reopen; the next working login sends
  **1** FBUN and settles. GUID ownership remains per character.
- N2: listed rosters held through **1000-second** combat/instance waits veto
  silence; excluding multipart rosters held **300 seconds** settle before the
  fallback deadline. Inbox byte/frame overflow retains uncertainty; current
  GUID changes cannot settle; receipt rollback keeps input held. The rollback
  case independently failed on a1e637b (`expected 1, got 0`) then passed.
- **`python3 test/verify.py`**, foreground subprocess timeout **1800 s**, exit **0**:
  **RESULT: 1537 tests passed, 0 failed, 220351 assertions**.
  Log: `/opt/data/cache/scratch/le-e2-r3-verify-final.log`. Syntax, policy, harness
  discovery, media, TOC and archive/source parity pass. No send/rate cap increased.
- Mutants: **100/100 E1**, **109/109 tracking**, all assertion kills. Two inherited
  mutants initially survived: the queued-answer fixture no longer queued an A
  under corrected M1, and proof expiry masked the six-attempt limit. Added a
  contradictory roster plus an actual queue assertion to the former, and fresh
  donor H after exhaustion to the latter; unchanged limits now kill both.
- Both complete runners were rerun from `le-e2-r3-portable/different checkout`,
  an unrelated CWD, and relative TMPDIR. The seeded reports retained identical
  **bytes and mtime**; scratch was cleaned. E1 SHA-256:
  `9424ae5921b95459fa8214295f5554c8f3f51ed832224d83db44764cafbc0f2c`.
  Tracking SHA-256:
  `052a25b74fb6440a2acdd114058c3fdcf8fc70a7becf8f64af4b3b30e840d3ea`.
- Archive `dist/LayerEnemies-1.1.0.zip` SHA-256:
  `eb9d44898bccb9d32843804fad14e661e9e5125cd74db4007d05ec0ecf0b492c`.
  Release integration still owns the version bump. Generated verification and
  mutation notes are committed separately from runtime/test/documentation fixes.
- Added-line security scan: no credential, shell-execution or unsafe-deserialization
  matches. `git diff --check` passes. No donor execution, installation or publication.

Changed runtime: `WarBoard.lua`, `WarBoardTrack.lua`, `Adapters.lua`, `Sources.lua`.
New test: `test/src_warboard_rulings.lua`; migrated tests: `src_warboard_debt.lua`;
mutant runners: `warboard_mutants.py`, `warboard_track_mutants.py`; README and
both tracking notes updated. The only additional inherited fixture change is
`M1 queued handshakes stand down when real addon loads`, described above.

Final review is self-review in this subagent; parent review is independent.
Native checks: not run (alpha, owner's decision). Local commits only; no push.

## Historical review correction checkpoint (a4dfbc40 baseline)

Owner M1/M2/S1/S2/S3/N1/N2 supersede the earlier acceptance rules below.
Frozen baseline `/opt/data/cache/scratch/le-e2-r2-base`: all four unchanged
`src_zzmani*.lua` probes reproduced M1 expired/disabled handshakes, M2 target
reload rejection, and S1 terminal retry exhaustion. They print observations,
not assertion verdicts; their unconditional PASS labels are not evidence.
New `test/src_warboard_debt.lua`: **1 passed, 25 failed, 1398 assertions** on
untouched a4dfbc40. S3 already passed; all new protocol failures are assertion
failures. Logs: `/opt/data/cache/scratch/le-e2-r2-{red,reviewer-red}.log`.

Ruling: a true lifetime six-attempt cap requires durable attempt accounting.
Keep the existing per-character GUID array and add an optional bounded
`warboardOwed.attempts[guid] = count` map inside that same field (no other saved
field). Legacy GUID-only saves load with zero attempts. This narrowly supersedes
the old GUID-only-content rule; without it, relog would silently reset the cap.
No names, accounts, positions, rosters or clocks are persisted. At the bound keep
the debt, stop sends, and accept only later excluding-roster proof (or an already
uncontradicted accepted send's 15-minute silence). The cap is conservative: failed
client calls consume attempts too. Crash-before-save limitations also apply to
attempt counts.

Work sequence: tests/baseline, handshake and verification, retry/persistence,
documentation/legacy assertion migrations, mutants, full verify, separate evidence
commit. Local commits only; no donor execution/copy or publication.

## Current correction result (supersedes the first-round record below)

Runtime commits: `7ffa85d`, `72ac02c`, `c46d1e8`; tests/bounds: `378a07a`, `1d00129`.
The original source/probes stayed frozen in the detached a4dfbc40 worktree.

- **M1:** debt-owned private H/A permissions pass share/source/Guild-only gates,
  with current-account GUID validation at admission and dispatch. No generic
  priority bypass. Once debt clears the exception ends. Real WarBoard owns all
  H/A when loaded; LE sends neither, including already queued handshakes. Valid
  owed-account H/A observations refresh cleanup confirmation. Known-account
  observations heard while unsafe are deferred for identity/rules validation on
  safe resumption, without scanning or sending while unsafe. An answered H alone
  is separate from received-A eligibility; a genuine recent received-A
  confirmation remains reusable for new requests under ordinary send settings.
- **M2:** each target H invalidates cleanup proof. An accepted answer after that
  H (or donor-owned observation) establishes later proof; queued FBUN rechecks it.
  Accepted FBUN remains sent-unverified. Only a later valid direct target roster
  excluding our hunter GUID, or 900 seconds after an uncontradicted accepted
  call, clears debt. Inclusion invalidates silence fallback and requires a new
  exchange before retry. Untracked/ignored/source-off targets still get cleanup
  roster inspection; it does not admit evidence into Find or forward anything.
- **S1:** three failed client attempts pause only the current 600-second window;
  later windows reopen, with the existing 60-second spacing. All attempts,
  failed ones included, count toward **six over the debt's life**. At six, retain
  debt across relog and forbid new asks/FBUN; later excluding-roster evidence can
  settle it. Silence clears only an accepted send not contradicted by a roster.
  The target can remain subscribed indefinitely at the bound. Persisted bounded
  `warboardOwed.attempts` accounting is the explicit schema ruling above.
- **S2/S3/N1:** README now states the precise exception, disk writes only at
  logout/reload, lost new debt/no FBUN after a crash before saving, per-character
  next-login ownership, and continued target broadcasts during combat/instances.
  GUID persistence is limited to warboardOwed; no account IDs, names, positions,
  rosters or clocks were added. Legacy GUID-only saves load with zero attempts.
- **N2:** E1 runner normalizes random traceback prefixes/object addresses and
  skips identical report writes. Real repeated runs of both runners preserve
  report bytes **and mtime**, not merely normalized comparisons.

### Executed evidence

- Initial ruling regressions on untouched **a4dfbc40**: **1 pass / 25 failures /
  1398 assertions**. All 25 were actual assertion failures; S3 was already green.
  Final `src_warboard_debt.lua`: **32 cases**, all green. Four later boundary /
  adversarial cases were added while green and are not claimed as initial RED.
  The donor-unsafe observation case separately failed on `1d00129` with
  `expected 1, got 0`, then passed on `72ac02c`. An answered H without a received
  A was incorrectly promoted to new-request eligibility on `72ac02c`
  (`expected 0, got 3`) and corrected on `c46d1e8`; its mutant restores that
  specific promotion. A genuine recent received-A confirmation remains reusable.
- The N2 real relocated-run test failed before the runner fix with
  `AssertionError: evidence bytes/mtime changed on rerun`; it now passes.
- Focused WarBoard suite: **191 tests passed, 0 failed, 41546 assertions**.
- Final **`python3 test/verify.py`**, foreground subprocess timeout **1800 s**,
  exit **0**: **RESULT: 1487 tests passed, 0 failed, 216736 assertions**.
  Log: `/opt/data/cache/scratch/le-e2-r2-verify-eligibility.log`. All syntax, static/API
  policy, harness discovery, media, TOC and archive/source parity checks pass.
  Earlier full runs also passed; they are superseded by this post-fix run.
- **100/100 E1 mutants** and **96/96 tracking mutants killed**, assertion failures
  only (no timeout/syntax/empty-collection kills). Original 64 tracking rules
  retained with migrated anchors; 32 new rule mutants added. N2 adds two E1 rules.
  One inherited retry-window mutant initially survived because the old 180-second
  observation ended just before a fourth attempt; extending it to 300 seconds
  exposes that violation. Two new privacy/stand-down mutants needed combined
  guard removal to bypass deliberate defense in depth, not weakened assertions.
- Added-line security scan: no hardcoded credentials, shell execution or unsafe
  deserialization matches. `git diff --check` passes.
- Final archive `dist/LayerEnemies-1.1.0.zip` SHA-256:
  `97734af060fa0b5c509fbf0a3fa5af1841f68fd2b25b7831ec32bc324ce3c051`.
  Integration still owns the 1.2.0 version bump. No push or donor-code execution.

### Reviewer probe readback

All four original `src_zzmani*.lua` files were copied unchanged into private
scratch worktrees, never edited in the reviewer's profile. Baseline observations
reproduced each reported M1/M2/S1 failure. The candidate complete run reports
22 cases / zero harness failures, but those probes swallow errors and primarily
print OBS rows: **the rows, not their PASS labels, are the evidence**.

- Share/source/Guild-only relog H-only cases: one FBUN, zero remote subscribers,
  debt zero after the 30-minute run. Donor-loaded relog: one FBUN, **zero H/A**,
  zero subscribers/debt.
- 600/1300-second combat waits with target H prompts: one FBUN; subscriptions
  and debt gone by the end, including the formerly stuck privacy modes.
- Target reload while FBUN waits (share/source/Guild-only/track off): one A then
  one FBUN, **zero rejected frames**, zero subscribers. Debt is correctly still
  present at 400 seconds, not falsely cleared on the client call; the assertion
  ports separately verify clearing after roster proof/900 seconds.
- Ten-minute client failure: three attempts initially, **four total** after
  recovery in the same session, target unsubscribed and debt zero. Next-login
  cleanup is no longer needed in that successful recovery case.
- The original donor-loaded 30-minute instance probe sends **no fresh target
  handshake at all**, including during the wait. It correctly remains pending:
  LE must not invent a confirmation or send its own H/A. New assertion ports
  cover real target prompts during and after the wait. No-handshake, unavailable
  identity, unknown ruleset and actual logout remain fail-closed waits.

Logs: `/opt/data/cache/scratch/le-e2-r2-reviewer-{red,complete}.log`;
private candidate checkout `/opt/data/cache/scratch/le-e2-r2-probes`.
One complete-probe attempt hit a 180-second tool timeout; the unchanged command
was rerun to completion with 600 seconds, not counted as a pass on timeout.

### Exact changed-test ledger for this correction

`test/src_warboard.lua`: **stand down blocks both own hellos and owed answers**
replaces the old owed-A permission, per M1b; it also pins Net's stand-down gate.
No other E1 test body changed.

`test/src_warboard_track.lua`: its helper now **seeds already-confirmed unit
fixture state**, rather than fabricating unsolicited A messages. These tests do
not claim to exercise a handshake. All 58 cases using that shared helper are
listed below. New debt integration tests use an independent target model that
receives H, replies A, sends its own gated H, and refuses data until it has
received A. The impossible source-off injected-A test is replaced by target H
and actual LE answer/FBUN behavior. Stop/unsafe cases now require retained debt
until verification; retry exhaustion expects reopened windows; restart/idle
cases supply excluding-roster proof before a new request may start. Exact-wire,
budgets, identity, privacy, persistence and timing assertions otherwise remain.

- `WarBoard track: exact FBAK and FBUN audit fields and codec round trip`
- `WarBoard track: remove sends exactly one owed FBUN through stop gates`
- `WarBoard track: remove cancels an unsent ask without creating debt`
- `WarBoard track: clear sends exactly one owed FBUN through stop gates`
- `WarBoard track: clear cancels an unsent ask without creating debt`
- `WarBoard track: track sends exactly one owed FBUN through stop gates`
- `WarBoard track: track cancels an unsent ask without creating debt`
- `WarBoard track: share sends exactly one owed FBUN through stop gates`
- `WarBoard track: share cancels an unsent ask without creating debt`
- `WarBoard track: guild sends exactly one owed FBUN through stop gates`
- `WarBoard track: guild cancels an unsent ask without creating debt`
- `WarBoard track: source sends exactly one owed FBUN through stop gates`
- `WarBoard track: source cancels an unsent ask without creating debt`
- `WarBoard track: standdown sends exactly one owed FBUN through stop gates`
- `WarBoard track: standdown cancels an unsent ask without creating debt`
- `WarBoard track: logout sends exactly one owed FBUN through stop gates`
- `WarBoard track: logout cancels an unsent ask without creating debt`
- `WarBoard track: combat holds cleanup until safe including an already queued FBUN`
- `WarBoard track: instance holds cleanup until safe including an already queued FBUN`
- `WarBoard track: FBUN refused and throwing client retries three times sixty seconds apart`
- `WarBoard track: accepted FBUN remains unverified until roster proof not queue admission`
- `WarBoard track: reload login settles GUID only with answered target H even source off`
- `WarBoard track: logout in combat retains owed list and login while tracked cleans before asking`
- `WarBoard track: only new saved field is bounded dense target GUID list oldest out`
- `WarBoard track: switch defaults on is session only and status states limits`
- `WarBoard track: only own Find names never shared Watch or untracked`
- `WarBoard track: confirmation rules identity expiry and ambiguous accounts fail closed`
- `WarBoard track: GUID only from live client never a received frame`
- `WarBoard track: dispatch rechecks live GUID own identity scope and rules`
- `WarBoard track: server time integer mandatory and not local wall clock`
- `WarBoard track: first asks three attempts six seconds apart then FBUN and 300 second idle`
- `WarBoard track: fresh positions then renewal 45 to 300 seconds only and 45 apart`
- `WarBoard track: newest position controls renewal and old out of order data cannot refresh`
- `WarBoard track: past 300 seconds sends FBUN idle until 300 pause or new handshake`
- `WarBoard track: six FBAK per rolling minute admission and dispatch max twenty targets`
- `WarBoard track: owed A before FBUN before FBAK within ten frame WarBoard share`
- `WarBoard track: positions remain honest Find evidence and never new guild relay`
- `WarBoard track: rollback stays silent and tagged cancellation preserves other targets and A`
- `WarBoard track: README send table first exact consequences and persistent debt`
- `WarBoard track: active request and received evidence save only target GUID no other metadata`
- `WarBoard track: no generic owed bypass for H FBAK foreign net or invented FBUN`
- `WarBoard track: server clock unreadable at dispatch does not send or forget cleanup`
- `WarBoard track: missing own name GUID faction version or rules never asks`
- `WarBoard track: failed FBAK spends three attempts and still owes FBUN`
- `WarBoard track: all actual request attempts respect six after shared queue delay`
- `WarBoard track: same GUID debt cannot be redirected by a received forged position`
- `WarBoard track: restored forty debt bound oldest out on the next attempted request`
- `WarBoard track: remove quick stop resume cannot erase withdrawal obligation`
- `WarBoard track: clear quick stop resume cannot erase withdrawal obligation`
- `WarBoard track: track quick stop resume cannot erase withdrawal obligation`
- `WarBoard track: share quick stop resume cannot erase withdrawal obligation`
- `WarBoard track: guild quick stop resume cannot erase withdrawal obligation`
- `WarBoard track: source quick stop resume cannot erase withdrawal obligation`
- `WarBoard track: six forty-five and sixty second exact admission boundaries`
- `WarBoard track: H cannot revive an expired A confirmation`
- `WarBoard track: renewal exact forty-five second per target boundary`
- `WarBoard track: twenty active targets even when corrupted Find holds twenty one`
- `WarBoard track: handshake before stale give-up cannot bypass the subsequent idle pause`

New `test/src_warboard_debt.lua` cases (all are real assertion tests):

- `WarBoard debt: M1 share relog settles from target H only`
- `WarBoard debt: M1 share combat 30 minute stop recovers`
- `WarBoard debt: M1 share instance 30 minute stop recovers`
- `WarBoard debt: M1 source relog settles from target H only`
- `WarBoard debt: M1 source combat 30 minute stop recovers`
- `WarBoard debt: M1 source instance 30 minute stop recovers`
- `WarBoard debt: M1 guild relog settles from target H only`
- `WarBoard debt: M1 guild combat 30 minute stop recovers`
- `WarBoard debt: M1 guild instance 30 minute stop recovers`
- `WarBoard debt: M1 donor relog settles from target H only`
- `WarBoard debt: M1 donor combat 30 minute stop recovers`
- `WarBoard debt: M1 donor instance 30 minute stop recovers`
- `WarBoard debt: M2 share target reload during combat reanswers latest H`
- `WarBoard debt: M2 source target reload during combat reanswers latest H`
- `WarBoard debt: M2 guild target reload during combat reanswers latest H`
- `WarBoard debt: M2 track target reload during combat reanswers latest H`
- `WarBoard debt: M2 accepted send retained until later roster excludes hunter`
- `WarBoard debt: M2 source off and removed Find still observes cleanup roster`
- `WarBoard debt: M2 listed roster rehandshakes then resends lost withdrawal`
- `WarBoard debt: M2 missing roster silence clears only at fifteen minute boundary`
- `WarBoard debt: M2 stale relayed malformed or wrong account roster cannot settle`
- `WarBoard debt: S1 failed sends reopen after ten minutes three per window`
- `WarBoard debt: M2 lifetime six attempt bound survives reload with debt retained`
- `WarBoard debt: M2 continuous listed rosters prevent quiet clearing at resend bound`
- `WarBoard debt: S3 per character save waits for original hunter login`
- `WarBoard debt: M1 exception cannot reach another account while debt remains`
- `WarBoard debt: M2 latest safe H supersedes queued withdrawal and failed answer`
- `WarBoard debt: M1 donor observes owed H during unsafe wait without LE answer`
- `WarBoard debt: M1 answered H without received A does not grant normal request eligibility`
- `WarBoard debt: M1 queued handshakes stand down when real addon loads`
- `WarBoard debt: M2 saved attempts sanitize only retained target GUIDs`
- `WarBoard debt: S2 N1 README states cleanup limitations without crash guarantee`

Other changed tests/runners:
- `test/warboard_mutants_portability_test.py::main`: actual repeated relocated
  runner execution checks byte/mtime stability, plus path/address normalization.
  The existing `WarBoard R2: portable mutant runner accepts relocated checkout
  cwd and scratch` harness case executes it, unchanged.
- `test/warboard_mutants.py`: only migrated send anchor, deterministic diagnostic
  normalization/write behavior, and two N2 mutants; all prior 98 rules remain.
- `test/warboard_track_mutants.py`: migrated anchors/selectors for revised state
  and documentation, retained all original 64 rules and added 32 correction rules.
- `test/verify.py`, API-policy tests and all eight saved-key allowlist tests are
  unchanged in this correction. The bounded attempts map is inside warboardOwed,
  not a new top-level saved key.

Final review: **self-review (no independent reviewer tool in this subagent)**.
Parent review remains independent. Native checks:
**not run (alpha, owner's decision)**. Offline acceptance does not guarantee
network delivery, silence-based settlement, crash durability or remote broadcast
cessation at an exhausted/evicted debt.

## Historical first-round record

The following records a4dfbc40 and earlier only. Its accepted-call settlement,
GUID-only contents, session-terminal retries and no-handshake-exception wording
are explicitly superseded above; preserve it for original E1 assertion provenance.

## Exact sends, recipients, caps and stop rules (historical E2 first round)

Both new types are `WBF1|D|` followed by `addonEncode(deflateStored(aceWrite(envelope)))`.
Envelope: `{t="FBAK"|"FBUN", v=5, rs=<our ruleset>, av="LayerEnemies/"..<our version>, senderName=<our character>, d=<payload>}`.
FBAK payload: `{targetGuid, targetName, hunterGuid, hunterName, hunterFaction, faction, sentAt}`.
FBUN payload: the same **without targetName**. `faction == hunterFaction`.
`sentAt` is a readable positive integer from `GetServerTime`, not `time()` or a fallback.

| Send | Recipient and reason | Limits and stops | Implementation |
|---|---|---|---|
| FBAK first ask | Exactly one current client-resolved game account for an unambiguous name on the player's own Find list; compatible confirmed A peer, opposite faction, not ignored | 3 attempts, at least 6 s apart; after the third unsuccessful wait, FBUN then 300 s idle; at most 20 active targets | `LayerEnemies/WarBoardTrack.lua:53-75,129-169,172-218` |
| FBAK renewal | Same target/account; only newest accepted direct target FBLP affects renewal | Position age 45–300 s, at least 45 s since the last ask; over 300 s sends FBUN and idles 300 s, or until a handshake **after the stop** | `LayerEnemies/WarBoardTrack.lua:103-108,129-132,178-183,196-202` |
| FBUN | Outstanding target GUID, rediscovered through a currently confirmed account; no Find membership required for cleanup | One accepted withdrawal per stop; at most 3 actual attempts, at least 60 s apart on failure; unresolved debt survives login | `LayerEnemies/WarBoardTrack.lua:77-102,133-168,187-215` |
| All FBAK | Only `BN.send("warboard", ..., "WarBoard", ...)` | 6 per rolling minute at both admission and actual dispatch, inside 10 WarBoard attempts/minute and 30 shared/minute; one attempt/second | `LayerEnemies/WarBoardTrack.lua:10-12,133-169`; `LayerEnemies/BNet.lua:39,79-119` |

Stop paths: Find removal/clear (`Find.lua:87-108`), tracking off
(`WarBoardTrack.lua:102`), share off (`Main.lua:2189-2192`), Guild only
(`Net.lua:53-56`), source off (`Net.lua:61-69`), stand-down or lost eligibility
(`WarBoardTrack.lua:49-60,177-183`), initial/renewal give-up
(`WarBoardTrack.lua:181-183`), and best-effort logout (`Main.lua:2430-2433`).
Quick off/on cannot erase an already-created withdrawal obligation.

Cleanup also retires on local combat/instance entry. It remains held while unsafe;
no scan or send occurs in combat/instances. Already queued FBUN survives cancellation
and unsafe pumps (`BNet.lua:83-88,102,144-150`); cleanup created while unsafe waits in
tracking state for a safe enqueue. Owed H/A answers precede FBUN; FBUN precedes own
traffic (`BNet.lua:94-98`). Shared budgets still apply to cleanup.

Only the exact private outstanding FBUN passes the share/Guild-only/source-off and
stand-down exception (`WarBoardTrack.lua:121-128`; `BNet.lua:41-56`). The string
`"owed"` alone does not bypass anything. Disabled WarBoard receives only H/A while
debt exists and keeps ticking cleanup (`Sources.lua:65-85`). No new H/A or FBAK
privacy exception was introduced. Client API acquisition remains solely in BNet's
existing delivery function, invoked through Wire's existing caller frame.

`targetGuid` comes only from `A.bnGame(id,true)` reading client `playerGuid`, via
`BN.who(id,true)` (`Adapters.lua:225-239`; `BNet.lua:154-158`). No received frame can
set request/withdrawal identity. Own identity and integer server time are read in
`Adapters.lua:427-444`. Identity, eligibility, rate and clock are rechecked at
actual dispatch. The envelope is re-encoded then so queued cleanup never sends
an old `sentAt`.

## Saved field and lifecycle

The only added saved field is per-character:

```lua
LayerEnemiesDB.warboardOwed = { "Player-123-00000002", ... }
```

Dense, unique, oldest-first target GUID strings only; maximum 40, oldest out.
GUID syntax is `^Player%-%d+%-%x+$`, length at most 80. The loader discards malformed
values, nonnumeric keys and duplicates. No account IDs, names, zones, clocks,
locations, hunter roster, peer state or tracking switch are saved in this field.
Existing user-authored Find names remain in their pre-existing `tracked` field.

Main owns the field (`Main.lua:2334`); tracking mutates only that shared list
(`WarBoardTrack.lua:9-44`). Debt is added **before the actual FBAK client call**,
including ambiguous failures. A successful queue admission does not settle it:
only a completion reporting an accepted FBUN client call removes it (apart from
explicit oldest-out eviction/sanitization). Three failed FBUN attempts leave the
GUID saved for another login. Eviction also removes the corresponding session
record, so a bounded saved list cannot hide an unbounded forgotten-debt map.

At login all restored debts close before new asks, including still-tracked names.
A matching confirmed client account may have a new account ID or renamed character;
GUID equality, not a saved name, finds it. A missing/secret/offline identity fails
silent. API acceptance is **not** a remote delivery acknowledgement.

`/le warboard track on|off` is on at each login and session-only; `/le net warboard`
prints its state and rates. Existing saved source/share/consent controls remain.

## Exact assertion migrations from reviewed E1

No original test case was deleted. All inherited E1 behavioral tests and the full
suite run. The inherited builder's 45-test E2 file is preserved in WIP `82fcf57`,
then replaced with independent specification tests; its green result was not
accepted as proof because it encoded the wrong cancellation and persistence rules.

| File / assertion | Exact migration |
|---|---|
| `test/src_warboard.lua`, `checkSends` | Replaced H/A-only / "NEVER FBAK" grammar assertion with truthful H/A **or** decoded FBAK/FBUN. New helper requires confirmed peer, live client target GUID, own hunter identity/faction, protocol/ruleset and LE version; FBAK additionally requires own Find and enabled tracking. Actual route must still be BN. |
| `test/src_warboard.lua`, `setup` gateway spy | Same conditional grammar replaces the H/A-only attempted-send check; unauthorized prefix/network still increments `badSend`, asserted zero even if protected callbacks swallow errors. |
| `test/src_warboard.lua`, `no FBAK or request answer or forwarding for any application type` | Renamed to `no unsolicited application response or forwarding; FBAK requires verified Find target`. Body and zero-send assertions retained; unsolicited application frames do not authorize asks. Positive/negative tracking authorization is covered separately in E2. |
| `test/src_warboard_review.lua`, README literal | Removed only the obsolete semicolon clause `LayerEnemies never asks anyone to broadcast their position.`; retained the full new-peer publication disclosure. |
| `test/src_warboard_review.lua`, README placement | Changed preceding marker from `**Nothing else**` to `| Tracking request/cancel |`, following marker from `Both H and A` to `H, A, FBAK and FBUN use`; still requires the disclosure immediately in the handshake send section. E2 tests separately pin its send-table-first order and both mandated consequence sentences. |
| `test/harness.lua:1168` — `we reports never enter LayerEnemiesDB` | Added only `(k=="warboardOwed" and type(LayerEnemiesDB[k])=="table" and #LayerEnemiesDB[k]<=40)` to saved-key allowlist. Existing report-value scans unchanged. |
| `test/harness.lua:2059` — `hop state clears on zone change and reload` | Same one-field, type-and-cap-checked allowlist addition; old cleanup assertions unchanged. |
| `test/harness.lua:3437` — host saved/on test | Same one-field allowlist addition; guildHost type/behavior assertions unchanged. |
| `test/harness.lua:3581` — Auto accept and leave saved test | Same one-field allowlist addition; forbidden-call and behavior assertions unchanged. |
| `test/kills.lua:145` | Added `warboardOwed=type(LayerEnemiesDB.warboardOwed)=="table" and #LayerEnemiesDB.warboardOwed<=40` to saved-key allowlist; recursive evidence checks unchanged. |
| `test/known.lua:25` | Same allowlist addition; existing evidence-isolation checks unchanged. |
| `test/overlord.lua:320` | Same allowlist addition; counter and recursive save checks unchanged. |
| `test/watch.lua:335` | Same allowlist addition; before/after save snapshot and switch persistence checks unchanged. |
| `test/api_policy_test.py` | Added tracking-module static API/send checks, rejects `_G`, `C_Timer`, `CreateFrame`, `Wire`, `LayerEnemiesDB`, `UnitGUID`, `GetTime` in tracking, and requires exactly one `BN.send(` call. No existing send-policy assertion weakened. |
| `test/warboard_mutants.py` | Updated final-source-predicate anchor for the new completion path; renamed `no FBAK send` to `handshake grammar cannot masquerade as FBAK`; updated no-forward selector to the renamed case; updated README literal to the approved disclosure. Same behavioral invariants, all 98 killed. |

`test/verify.py` is unchanged: the existing one-owner/one-client-send-site checks
cover the new file automatically. SavedVariable allowlist changes are precisely
those eight assertion sites above; no boolean `warboardTrack` is accepted or saved.
E2's saved-data tests compare every other saved key before/after an active request
and received position, and pin exact dense GUID-only content, sanitation and caps.

## Verification evidence

- Preserved WIP: `82fcf57`; independent tests: `f473c76`; lifecycle rewrite:
  `7add70a`; bounds/mutants: `f033564`; final handshake correction: `6b57dca`.
- Initial independent tests against inherited WIP: **16 passed, 23 failed,
  2945 assertions**. Initial frozen E1 base: **3 passed, 36 failed, 2821 assertions**.
- Final test file copied alone into detached `65904e66`: **5 passed, 53 failed,
  3880 assertions**, exit 1 (`/opt/data/cache/scratch/le-e2-base-red-current.log`).
  The five negative guards already pass on E1; do not count them as feature RED.
- Candidate: **58 tracking tests pass**. Combined WarBoard command:
  `lua test/harness.lua --only 'WarBoard'` → **159 passed, 0 failed,
  39616 assertions** (`/opt/data/cache/scratch/le-e2-focused-final.log`).
- Self-review found a handshake-before-stop loophole: the regression first failed
  with `expected 1, got 2`, then passes after comparing handshake time with stop
  time, not the initial handshake. The matching mutant reproduces that exact failure.
- `python3 test/verify.py`, foreground, subprocess timeout 1750 s / tool timeout
  1800 s, exit **0**: **RESULT: 1455 tests passed, 0 failed, 214806 assertions**.
  Full log: `/opt/data/cache/scratch/le-e2-verify-current.log`. Syntax, TOC/static
  policies, verify tests, API policy, harness discovery, media and package/source
  parity all pass. `notes/test-results.txt` and `notes/verification.json` regenerated.
- `python3 -B test/warboard_track_mutants.py`: **64/64 killed**. Every result is a
  real assertion failure; syntax errors, empty collection and timeouts do not count.
  `notes/warboard-track-mutants.json` SHA-256:
  `a8331595e38a56e771e63bdb395828ee682dc532f79e2a0bd133204cb243912d`.
  Repeated execution leaves **bytes and mtime unchanged**. A relocated checkout
  containing spaces, unrelated working directory and relative TMPDIR yields the
  same bytes and cleans scratch. `notes/warboard-mutants.json`: **98/98 E1 killed**.
- Added-line security scan: no hardcoded secrets, shell-injection or unsafe
  deserialization matches; `git diff --check` passes.
- Deterministic local archive `dist/LayerEnemies-1.1.0.zip` SHA-256:
  `243625edcbe3a0c45f6947ae267352b314f3574d6354de8eb9057e72c5b45468`.
  The lane retains the foundation's 1.1.0 TOC/package version; 1.2.0 versioning is
  left to the release integration, with this feature documented as Unreleased.

## Rulings / differences from the literal plan

1. **Session-only tracking toggle**, default on each login. Only one new saved
   field is authorized, and switch persistence is unspecified. Cost if unwanted:
   track-off must be repeated after login; saved source/share/consent switches remain.
2. **Close every restored debt**, not just no-longer-tracked/off targets, before
   asking again. This conservatively clears uncertain prior-session subscriptions.
   Cost: one extra cleanup and a delayed first ask for still-tracked targets.
3. **Retain local combat/instance retirement** from the inherited builder, rather
   than simply suspending an active request. Owed cleanup is now held, not lost.
   Cost: a fresh-start pause after local combat/instances; this is stricter than
   the plan's no-scan/no-send safety boundary.
4. **A confirmation is required for new requests**; H alone can create E1 receive
   state but does not prove the target received our answer. This conservative
   interpretation may reduce reach until an A arrives; expired A cannot be revived
   by an H. A fresh post-stop handshake can shorten renewal give-up idle as specified.

No gameplay records, snapshots, forwards, guild relay, own positions, Ask/Hop
authority or evidence storage are added. E1's Find admission and honest position
wording are retained. Audit section 11 has no constructed FBAK, so the new tests
pin complete field layout and independent Ace text, and round-trip our own writers
through our addon/raw-DEFLATE/Ace readers instead of claiming canonical compressor
bytes. Whether the target accepts hunters outside its community roster remains
unknown and fails silent; no extra roster access or fallback is invented.

Final review: **self-review (no independent reviewer tool in this subagent lane)**;
parent review remains independent. No deferred minor fixes. Native checks:
**not run (alpha, owner's decision)**. Harness success is not client delivery proof.

## Changed files

- Runtime: `LayerEnemies/{Adapters,BNet,Find,Main,Net,Sources,WarBoard,WarBoardTrack}.lua`
  and `LayerEnemies/LayerEnemies.toc`.
- Documentation: `README.md`, `THIRD_PARTY.md`, `notes/warboard-track.md`,
  `notes/warboard-track-plan.md`.
- Tests: `test/{harness,kills,known,overlord,watch,src_warboard,src_warboard_review,src_warboard_track}.lua`,
  `test/{api_policy_test,warboard_mutants,warboard_track_mutants}.py`.
- Generated evidence (separate commit): `notes/test-results.txt`,
  `notes/verification.json`, `notes/warboard-mutants.json`,
  `notes/warboard-track-mutants.json`.
