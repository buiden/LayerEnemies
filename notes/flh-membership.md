# Forever Layer Hop F2 — membership and guest-hop gate

## Current follow-up: reviewer rulings S1–S4 / N1–N3

See [flh-review-rulings.md](flh-review-rulings.md) for the corrected shared ceilings, retained directory membership, decline/leader handling, exact route gate, README side effect and stable mutant evidence. It supersedes the historical behavior and counts below. Verified implementation: `e54229dfde9f3a960c00eba2027233cda26707ec`; evidence is committed separately.

## Historical follow-up: one owner and fair probes

- Follow-up base: `dfcd29bc6f020370313091f12d0f08ad68d2f3fe`.
- Owner fix: `7533363147faa630d183454961d9fa31e05fe315`.
- Probe fix / verified implementation: `3a99452da8fba6b518e7bef527a7b877ef219001`.
- Notes and regenerated evidence are a separate commit. Local commits only; no push, installation or GitHub writes.

This follow-up supersedes the original checkpoint's donor-loaded owed-reply exception and head-first probe scan. The historical checkpoint is retained below; regenerated `test-results.txt`, `verification.json` and `flh-member-mutants.json` now describe this follow-up.

### Owner rule and identifier provenance

`FLHMember.allowed` now refuses **every FLHNET2 send** when `A.loaded("ForeverLayerHop")` is true: HI, WR, CA, WP, LQ and LR. The same predicate is checked again by `FLHMember.authorize` inside Wire. The existing Directory/Net stand-down already prevented the read-only channel join; those modules are unchanged. Receipt, decoding and host-claim projection remain active.

The identifier is **`ForeverLayerHop`**, not its title or SavedVariables name. It comes from `ForeverLayerHop/ForeverLayerHop.toc` inside the pinned `ForeverLayerHop-v0.1.9.zip`; the TOC says title `Forever Layer Hop`, version `0.1.9`, interface `16001`. The archive was read, not executed, at `/opt/data/projects/layerenemies-review/reference-addons-web/forever-layer-hop/ForeverLayerHop-v0.1.9.zip`, with the same SHA-256 recorded in THIRD_PARTY.md: `b5b3dbc608c112463bb50ddb0567c70ae2c3eb5919711b0475875001dd5092b7`. This also matches the existing `Net.LIST.flh.standDown` identifier. The unchanged `Adapters.loaded` uses protected `C_AddOns.IsAddOnLoaded(name)`, falling back to the legacy global only when that namespace is absent.

The thirty-minute donor-loaded regression keeps Friendly open, feeds WP/CQ and HI claims, and changes our fingerprint. It asserts **zero FLH sends and zero joins**, while the received host claim stays readable. The no-donor control verifies the join and positive HI/WR/CA/WP traffic. Additional coverage denies new LQ clicks, cancels an existing query before LR, and detects a donor that loads between receiving a question and final Wire authorization.

### Probe behavior checked before changing it

The base did **not** satisfy either probe rule. Its scan restarted at the first name; with forty directory names and a real shared budget leaving two WP slots per minute, it repeatedly reached only twenty distinct names. It also wrote the 600-second per-name stamp before dispatch, including local transport-pause and per-person-budget refusals.

A bounded round-robin cursor now resumes after the last selected name, including a refused selection. The per-name stamp is set only when dispatch succeeds or reports an actual client attempt. Actual client refusal still spends the cooldown; local gate refusal leaves the name eligible for a later turn. No retry queue or enlarged caps were added. The regression drives twelve real HeadHunter public sends per minute, retains the six owed-reply slots, reaches all forty names in order before wrapping, and checks the unchanged rolling and per-name limits. Separate final-gate pause and per-person tests prove recovery before 600 seconds and that a refused target cannot monopolize the cursor.

### RED → GREEN

The untouched base membership suite first passed: `RESULT: 55 tests passed, 0 failed, 18638 assertions`.

All RED runs used a detached `dfcd29bc` worktree with **only `test/src_flh_member.lua` overlaid**; no production changes:

- Owner slice: `RESULT: 56 tests passed, 3 failed, 18856 assertions` → `RESULT: 59 tests passed, 0 failed, 18911 assertions` (`flh-owner-red.txt`).
- Round-robin slice: `RESULT: 0 tests passed, 1 failed, 384 assertions` → `RESULT: 1 tests passed, 0 failed, 407 assertions` (`flh-probe-rotation-red.txt`).
- Local-refusal slice: `RESULT: 0 tests passed, 2 failed, 105 assertions` (`flh-probe-refusal-red.txt`); both pass in the final suite.
- Final candidate tests against the frozen base: `RESULT: 56 tests passed, 6 failed, 19345 assertions` (`flh-owner-probes-red.txt`).
- Final candidate GREEN: **`RESULT: 62 tests passed, 0 failed, 19431 assertions`**.

One inherited expectation was deliberately migrated: the presence test's final donor-loaded WP reply count changes from 8 to 7 and now also supplies CQ. The old exception is exactly what the owner revoked. The new no-donor control and donor-loaded guest revocation already passed on the base; they are preserved-behavior coverage, not claimed as RED failures.

### Verification and mutants

Foreground `python3 test/verify.py`, Lua 5.1.5, `TMPDIR=/opt/data/cache/scratch`, process/tool timeout **1800 seconds**, exit 0:

```
RESULT: 1513 tests passed, 0 failed, 274629 assertions
```

Syntax (85 Lua files), TOC/static/API policy, packaging and archive/source parity all PASS. The deterministic archive SHA-256 is `729769f417c4da120d4d368bedbf4e6057bd01014678ccdebf47c8dc295e3d2f`. `test.flh_mutants_test`: 2 tests passing. The added-line security scan found no hardcoded secrets, shell execution, eval/exec or unsafe deserialization.

**52/52 membership mutants compile and are killed**, with identical 62-test baseline/final restoration. Three new rule mutants are `owner-includes-owed-replies`, `probe-round-robin`, and `probe-gate-refusal-free`. The old `stand-down` mutant was re-anchored to the unconditional guard without weakening it; existing directory mutants still cover join guards. No mutant survived, and no syntax/collection failure is counted as a kill.

Two complete mutation runs returned success. The second ran from an independent checkout whose path contains spaces, invoked from `/opt/data`, with a copy of the first report already present. Report bytes and modification time stayed unchanged; the original report also stayed unchanged. The report SHA-256 is `1c9693b04890efa869721475474414ea295dd5385b99b942b8f70dfb16130b44`; summary in `flh-owner-probes-stability.json`.

Changed runtime: `LayerEnemies/FLHMember.lua` only. Changed documentation/tests: `README.md`, `test/src_flh_member.lua`, `test/flh_member_mutants.py`; this notes-only commit records the RED logs, mutation/stability evidence, and regenerated full verification. **Native checks not run (alpha, owner's decision)**; offline results do not certify live peer interoperability.

## Historical original F2 checkpoint

**Read-only channel join: YES, `ForeverLayerHopNet`, expressly listed in PLAN.md §10.2. No channel sends.** The README membership section starts with the send table and immediately discloses the join. Directory consent, channel ownership/manual-leave, unreadable-list, two-free-slot, combat, instance and Channels-window guards remain in force.

## Scope and source

- Worktree: `/opt/data/cache/scratch/le-flh-member`; branch `feat/flh-membership`.
- Frozen base: `90d4444c`. Implementation checkpoint verified by the final full run: `ec0676284f9bf000c115f7771fbceeedfdd15d67`. This note and regenerated evidence are committed separately; no push or GitHub writes.
- Preserved previous builder's implementation in `b9fc388`; target canonicalization, composed fixtures and deterministic evidence in `034da72`; no-retry presence correction in `ec06762`.
- PLAN.md §§1, 2A, 10; GATE.md and FEASIBILITY.md; reviewed `notes/hop-fanout-review.md` and `notes/flh-receive.md`.
- Donor: Forever Layer Hop 0.1.9, archive SHA-256 `b5b3dbc608c112463bb50ddb0567c70ae2c3eb5919711b0475875001dd5092b7`. All Rights Reserved. Wire facts only; no copied/executed donor code or dependency. See THIRD_PARTY.md.

## Exact sends and caps

Every send uses the one-use synchronous authorization in `LayerEnemies/FLHMember.lua:168-187`, `Wire.lua:352-354`, then the existing Wire client call (`Wire.lua:417-419`). Builders are `FLH.lua:64-100`. No SendChatMessage, host offers/invites, peer exchange, known-name lists, guild copies of hop queries, CHANNEL or INSTANCE_CHAT sends.

| Kind | Target / authority | Cap and implementation |
|---|---|---|
| HI | GUILD and the current PARTY or RAID; verified own fingerprint, host flag 0 | First/change-driven; 1/120 seconds guild and 1/120 seconds group. PARTY/RAID share a lane. `FLHMember.lua:199-211`, `Wire.lua:311-314`. Actual client refusal spends the announcement; unchanged presence is not retried. |
| WR | WHISPER back to the canonical WP transport sender | Shares 6/rolling minute with CA, one reply per sender/60 seconds. `FLHMember.lua:189-197`, `Wire.lua:284,302-310`. |
| CA | WHISPER back to the canonical CQ transport sender | Same shared reply ledger and per-sender cooldown; no separate six-message allowance. Same locations as WR. |
| WP | WHISPER to a fresh read-only directory member | 4/rolling minute; same name once/600 seconds; at most one/tick; Friendly window open and no hop pending, including no fan-out round. `FLHMember.lua:23-29,212-224`, `Wire.lua:284-291,301-310`. |
| LQ | WHISPER to fresh current-zone FLH host claims, only from a click | Named row: one. Explicit `/le hop flh` batch: at most seven, leaving the eighth existing hop burst slot for LR. Existing invite name/click cooldowns and Wire hop ledger (8 burst, 1/s refill, 60/minute, 4/minute/target). `FLHMember.lua:104-140`, `Wire.lua:316-322`. |
| LR | WHISPER to the previously asked host whose matching LO was selected | Once/click, spent before dispatch even on client refusal. Same public and hop ledgers. `FLHMember.lua:142-163`, `Wire.lua:316-322`. |

All FLH whispers, including to guildmates, charge the existing public 20/minute and 4/minute/person ledgers (`Wire.lua:297-299,324-326`). Probes leave six public slots for owed replies (`Wire.lua:290`). Presence/replies/probes have separate small FLH ledgers; they do not consume or resize hop fan-out tokens. Nothing is queued. Existing hop fan-out remains on its original 8-then-1/s lane; tests send all 49 targets on its original cadence beside six owed FLH replies. FLH WP is prohibited during a running round.

`/le share off`, `/le net flh off`, combat, instances, unreadable identity/context and ignored/self targets stop sends. Guild only permits only GUILD presence, not group presence, whispers, directory activity or guest clicks (`FLHMember.lua:31-42`). With ForeverLayerHop loaded, originating membership stands down; the two bounded owed replies remain. Names, claims, probes, rates and status are session-only/bounded; no SavedVariables additions. The FLH switch is explicitly session-only.

## Guest hop and preserved receive rules

- `Main.lua:1494,1514` selects the FLH preview/action only when the normal known-layer host action is unavailable. A merged known-layer row retains normal LayerSwap/Bulo precedence. Outbound names are independently canonicalized (`FLHMember.lua:114-116`), without replacing displayed identity.
- `/le hop flh` is an explicit bounded guest batch (`Main.lua:2432`), not an expansion of `/le hop any`. Pending guest/ordinary hop/fan-out exclude one another (`Main.lua:830,1293`); Stop/privacy controls revoke pending authority.
- LO must match an actually successful LQ's sender, request ID, current map and asked FLH key; it must differ from our current fingerprint. Selection is spent once. Only a successful LR arms the existing Invite path for that selected canonical host (`FLHMember.lua:142-160`). Other queried hosts, pre-offer invites and foreign-realm namesakes cannot auto-accept.
- The guest lifetime is 90 seconds from the first successful LQ, within (and stricter than) the existing 120-second invite ceiling. `Main.lua:1616` rechecks before acceptance. The existing auto-accept setting, confirmed-move leave and 30-second failure leave paths are reused unchanged; FLH's target is not substituted for a server-layer key.
- FLH host provenance remains separate. Corrected the inherited FLH-only projection's general `host=true` to `false` (`Invite.lua:186`); only `hosts.FLH` authorizes guest actions. Known-layer rows remain ahead of FLH-only rows. Fingerprints stay labelled claims and never become LE layer keys.
- Timeout/status details enter the existing measured Friendly row before paging (`Main.lua:1216`). UI.lua, HopAny.lua, Auto.lua, Hosts.lua, BNet.lua and Sources.lua are unchanged from the base.

## Deliberate plan refinements and limitations

1. F2's directory join is **not an added exception**: it is expressly in §10.2. The existing readonly Directory implementation is extended, not replaced.
2. Keep FLHNET2 registration/ingress in the reviewed Main chain, per §2A. The registry gets only a prefix-less tick/counters source; no receive migration or duplicate prefix ownership.
3. No SavedVariables addition means `/le net flh` cannot persist. Reload restores on; this is stated in README.
4. A seven-query explicit batch plus one LR fits the existing eight-message hop burst instead of silently enlarging HopAny or reserving no selection slot. Ordinary `/le hop any` remains unchanged.
5. The 90-second guest timeout tightens the old invitation ceiling; it never extends it. Own-zone fingerprint, non-ambiguous context and existing known own server layer are required for safe request/leave behavior. There is no invented mapping between key namespaces.
6. All identity/BUILD fields contain LayerEnemies and its installed version, never a false FLH version. Real-client interoperability is unverified; donor identity/version checks may reject these messages and then requests time out. Donor handlers may record/introduce our own character and initiate their own peer exchange; LE ignores exchange packets and sends no other players' names.
7. This is an unreleased component PR, not the 1.2.0 release/version bump. The unchanged base TOC version produces `dist/LayerEnemies-1.1.0.zip`; it passed archive/source parity. No install or in-game verification was performed.

## RED → GREEN and assertion migration

Frozen-base RED used a detached `90d4444c` worktree with only candidate `test/harness.lua` and `test/src_flh_member.lua` overlaid, no production changes:

```
RESULT: 0 tests passed, 55 failed, 2418 assertions
```

Actual output is `notes/flh-member-red.txt`. Final membership GREEN:

```
RESULT: 55 tests passed, 0 failed, 18638 assertions
```

Two added candidate regressions were also observed RED before their fixes: home-realm merged spelling was refused by exact dispatch matching; an unchanged client-refused presence was retried after 120 seconds. Both are GREEN and mutation-protected.

Five pre-existing assertions needed migration, not production budget changes:
- Four BNet S1 fixtures assumed the old registry population: the extra FLH tick source tightened default per-source shares, or hit the registry ceiling before the queue boundary. `test/bnet_queue_fixture.lua` now uses configured shares plus live remaining admissions and explicitly reserves the expiry test's alpha replacement slot. The shared-cap test admits exactly 31 eligible frames to prove the unchanged 30-send cap. Queue limits (52 normal / 60 total), priority, fairness, expiry and pacing assertions remain exact.
- The ChehulNet composed row test expected F1's manual Ask on an FLH host. It now asserts F2's named FLH guest-hop preview while preserving hint-only no-action rows and measured paging. No production ChehulNet/UI changes.
- All those inherited tests pass unmodified on the frozen base before overlay. Final whole BNet queue suite: `RESULT: 29 tests passed, 0 failed, 2321 assertions`. All 16 BNet queue mutants compile and are killed; `notes/flh-bnet-composition.json` records the assertions.

## Final verification and mutation evidence

Foreground `python3 test/verify.py` from the repo root, Lua 5.1.5, TMPDIR under `/opt/data/cache/scratch`, 1700-second process timeout / 1800-second tool timeout; exit 0:

```
RESULT: 1506 tests passed, 0 failed, 273836 assertions
```

`notes/test-results.txt` and `notes/verification.json` are regenerated, not hand-merged. Syntax: 85 files; TOC/static/API checks PASS; archive integrity/source parity PASS. FLH fuzz: 5,000 deterministic malformed/structured frames. Python evidence tests: 2 passing; API-policy tests: 13 passing.

- Membership: **49/49 mutants killed**, restored baseline/final 55 tests; `notes/flh-member-mutants.json`.
- Receive: **39/39 mutants killed**, restored baseline/final 29 tests, 19,738 assertions; `notes/flh-mutants.json`.
- Both runners use configurable Lua/scratch, no builder checkout assertions. Lua addresses and checkout prefixes are normalized without dropping assertions; unchanged JSON is not rewritten.
- Both full mutant suites were run from an independent path containing spaces, invoked with another CWD. Their report bytes exactly match the original checkout. Real reruns and the write-if-identical path preserve bytes/mtime. See `notes/flh-evidence-stability.json` for hashes and checks.
- One long combined runner wrapper timed out at 420 seconds while its foreground child continued. It was allowed to finish, then the final suites/stability runs were repeated in bounded calls and returned success directly; no killed/partial run is counted as evidence.

## Exact test/verify.py diff from the base

No SendChatMessage or party-API ownership exception is widened. A new exact route-table checker freezes the five existing routes and adds only FLHNET2/GUILD, PARTY, RAID, WHISPER. The remaining diff updates generated verification metadata to disclose those sends.

```diff
diff --git a/test/verify.py b/test/verify.py
index 74d46bb..bbea70d 100644
--- a/test/verify.py
+++ b/test/verify.py
@@ -237,0 +238,14 @@ def check_send_policy(source, filename):
+def check_route_policy(wire):
+    """Freeze existing routes; F2 adds only FLHNET2 on these four kinds."""
+    allowed = {
+        'LayerSwap': {'WHISPER'}, 'LEGW1': {'GUILD'}, 'LFSw': {'GUILD'},
+        'WEFF1': {'GUILD', 'PARTY', 'RAID', 'WHISPER'}, 'HeadHunter': {'WHISPER'},
+        'FLHNET2': {'GUILD', 'PARTY', 'RAID', 'WHISPER'},
+    }
+    table = re.search(r'local ROUTES = \{(.*?)\n\}', wire, re.S)
+    assert table, 'missing private route table'
+    entries = re.findall(r'(\w+) = \{ kinds = \{ ([^}]+) \}', table[1])
+    actual = {prefix: set(re.findall(r'(\w+) = true', kinds)) for prefix, kinds in entries}
+    assert len(entries) == len(allowed) and actual == allowed, 'unapproved addon route'
+
+
@@ -262,0 +277 @@ def main():
+    check_route_policy(wire)
@@ -372 +387,2 @@ def main():
-                 'HeadHunter/WHISPER behind Net (both shipped on; /le net guild stops public scope)',
+                 'HeadHunter/WHISPER behind Net (both shipped on; /le net guild stops public scope); '
+                 'FLHNET2 HI on GUILD/PARTY/RAID, WR/CA/WP/LQ/LR on WHISPER through Wire, no hosting or channel sends',
```

## Changed files

Production: `Directory.lua`, `FLH.lua`, new `FLHMember.lua`, `Invite.lua`, `LayerEnemies.toc`, `Main.lua`, `Net.lua`, `Wire.lua` (all under LayerEnemies/). Documentation: README.md, THIRD_PARTY.md. Tests: API/route policy, BNet fixture and round-one assertions, ChehulNet composed row assertion, FLH receive assertions, generic harness hooks, new member suite and runner, deterministic runner tests, existing receive runner, verify.py. This evidence-only commit adds/regenerates the FLH review/RED/mutant/stability/composition notes plus full test-results/verification output.
