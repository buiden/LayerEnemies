# Guild-intel PR 3: shared watch list and on-site notice

Original round-1 history below: base `c229b9b`, branch `gi-pr3-watch`. The **Port** and **Round 1 fixes** sections at the end supersede its early-repeat policy, notice wording and verification totals. Scope: plan section 12 (tests 16–25), section 5.4 and section 6 budgets. Target remains Forever, Interface 16001; Lua 5.1. No installation, push, Wire change, or earlier-branch edit.

## Decisions and boundaries

- Ruling: the plan's opening rule says “plain names”, but 12.1 explicitly chooses six-character hashes. README preserves the quote and immediately explains the actual wire. Hashes are not secrecy. Cost if misunderstood: misleading privacy expectations.
- Ruling: `/le net guild` permits LEGW1/GUILD under existing Net/Wire policy; it disables public traffic, not guild traffic. No new network, route, recipient or dependency; no coupling to War Effort/HeadHunter switches.
- Ruling: one bounded, coalescing T snapshot queue belongs to Watch. Retry through Wire with `queue=false`, checking guild, instance and master sharing on every attempt. This prevents queued lines draining together through the three-per-minute limit and makes cancellation immediate. Cost: retries use the existing heartbeat cadence, not Wire's half-second pump. Client refusals count against the T limit too.
- Ruling: an initially empty Find list has nothing to advertise. Login/periodic T stays silent until nonempty; removing names or an explicit opt-out owes a clearing line. Cost: if a previous session published a list and then lost its saved configuration, peers retain that old list until expiry.
- List ids follow canonical full-list content, including realm changes, while shared hash sets deduplicate the same folded base. Identical-content refreshes (even with a new id) renew expiry but do not grant repeats. New/changed complete lists grant at most four unique-name early tickets, never incomplete parts.
- T timing: initial due time 20–80 s after startup; edits debounce 10 s, not before the initial delay or the prior content send plus 60 s; refresh 600 ±120 s. Policy/budget refusal retains the pending line. The existing startup/heartbeat lifecycle supplies these pumps; no new client event or uncancellable send callback.
- Opt-out clears once and continues receiving others' lists. Saved-off startup and edits while off stay silent. An owed clear waits while master sharing is off or guild sending is unavailable. `findShare` and `findNotice` are the only new saved fields. No general Find-alert switch exists at this base; the independent death-call switch is not one.
- Receiver caps include partial-only sender slots. Conflicting duplicate parts invalidate the incoming set; identical duplicates are idempotent. An expiring complete list does not erase a newer partial set's independent 120-second lifetime. Only the affected sender changes; held data never enters SavedVariables.
- Roster reads already exist in Adapters (`GetNumGuildMembers` / `GetGuildRosterInfo`). One complete membership snapshot per existing roster update removes departed senders, retains offline members, and does nothing on an unreadable/partial roster. No new roster request was added. Both guild and roster-event leave/switch paths clear held lists.
- Priority is base-name hash only, never class/level. R prioritizes due listed records and evicts an unlisted pending record first at the unchanged cap. Watch-triggered early repeats belong to guild O only, not public War Effort C+E. Normally eligible names preserve the old public path. A no-longer-listed name cannot spend a pending early ticket.

## Red/green and changed inherited tests

- Untouched `c229b9b`: `RESULT: 790 tests passed, 0 failed, 73377 assertions`.
- Initial test-first run, before any production edit: `RESULT: 791 tests passed, 28 failed, 74651 assertions`. The new-module assertions failed because Watch did not exist; the unknown-T compatibility test passed on the old decoders.
- Final expanded tests replayed against a detached `c229b9b` worktree with only the current harness and `test/watch.lua` copied in: **791 passed, 35 failed, 74959 assertions** (rc 1). The temporary worktree was removed. This is the final baseline red count, not an estimate from a mixed tree.
- Additional implementation-edge RED→GREEN: saved-off/edit silence, independent partial expiry and bounded event-only notice history (three real failures); duplicate-part behavior already passed.
- Self-review RED→GREEN: withdrawn-list tickets and early guild repeats accidentally reaching War Effort (two real failures). Mixed normal/early candidates now send only normal candidates publicly; the no-extra-public-send rule is retained.
- An additional still-fresh receipt test exercises consumption before freshness could conceal a repeat. It passed unmutated code and killed the unconsumed-ticket mutant; it is not presented as an implementation-edge red failure.
- Final full Lua 5.1 harness: **826 tests passed, 0 failed, 77194 assertions**.

The only inherited expectation changes add `findShare` and `findNotice` to the configuration-key allowlists, as explicitly authorized. No behavioral assertion or timeout was relaxed. Exact existing test names:

1. `we reports never enter LayerEnemiesDB (مانع T3 S4)`
2. `hop state clears on zone change and reload`
3. `0.4 host saved: on survives a reload and is active; one login line; no H at login`
4. `0.4 T8: Auto accept and leave: on by default, saved, /le hop auto and the toggle; off means manual`
5. `Known 4: add after receipt and a boundary finds old memory without an alert`
6. `Known 14: cache stays out of every saved table and reload starts empty`

`test/verify.py` needed no allowlist edit: it already allows the guild route and delegates SavedVariables assertions to the harness. `Wire.lua` is byte-unchanged. Base `Relay.control`, `decode`, and `decodeOwn` ignore T; this case was exercised on the frozen baseline as well as the candidate.

## Mutation evidence

`test/watch_mutants.py --lua <lua5.1> --output notes/watch-mutants.json` requires a green baseline, syntax-checks each mutation, requires its named assertion to fail, restores every source file in `finally`, hash-checks restoration, and reruns the unmodified full harness. It has no new dependency. All 14 mutants were killed on their first completed run; none survived and required a post-survival test patch.

| Mutant | Result |
|---|---|
| hash every held list per sighting | killed; 1 failed |
| accept incomplete part set | killed; 5 failed |
| no per-sender hash cap | killed; 1 failed |
| list never expires | killed; 2 failed |
| notice on relayed entries | killed; 1 failed |
| no T rate limit | killed; 1 failed |
| match by class and level | killed; 1 failed |
| find sharing-off still sends refresh | killed; 2 failed |
| master sharing-off still sends | killed; 2 failed |
| unlisted O goes first | killed; 3 failed |
| early tickets not consumed | killed; 1 failed |
| withdrawn list keeps early ticket | killed; 1 failed |
| early guild repeat leaks into War Effort | killed; 1 failed |
| unlisted relay gets last token | killed; 1 failed |

Full failure lines and restored-source SHA-256 values are in `notes/watch-mutants.json`. The unchanged crowd runner also killed **10/10** mutants and restored to `826 passed, 0 failed, 77194 assertions`; details are in `notes/watch-crowd-mutants.json`. Older Find20/guild-intel mutant runners were not rerun in full; all their normal harness tests ran in every complete candidate pass.

The first foreground mutation invocation hit the tool's outer timeout after the mutations; source restoration was verified. It was rerun as a tracked background process to completion. An intermediate crowd run was intentionally interrupted for the two self-review fixes; its `finally` restoration was hash-verified before editing, and the full crowd runner was restarted afterward. Neither interrupted run is claimed as a full pass.

## Review and native limits

Final review: self-review (no subagent review tool in this worker). Checked input validation, session-only state, caps, changed-list versus refresh semantics, priority and receipt accounting, cancellation, old-decoder compatibility and the public-send boundary. Independent review remains the parent's lane; no claim of independent approval.

Not run (alpha, owner's decision): live guild delivery/throttling under a large fight; roster completeness and event ordering; exact client login/loading/heartbeat timing. Existing guarded API surfaces are reused. Client acceptance is not proof of delivery. The design's memory figures in README are estimates, not measured allocations. No native test is being requested or made a merge gate.

## Verification artifact

Pre-commit prescribed gate: `uv run --no-project --python 3.14 --with lupa==2.8 python -I test/verify.py` returned **rc 0**, `RESULT: 826 tests passed, 0 failed, 77194 assertions`; syntax and archive/source parity passed. Archive SHA-256: `777c3f152760927b4030a00942818f5e989abd50def9723e48c0bc7738f4c26f`.

Final artifact convention: regenerate on the feature commit, then commit only `notes/test-results.txt` and `notes/verification.json` separately as `notes: regenerate verification output for this head`. These generated files record the gate RESULT and archive SHA; they are not feature source.

## Port

New branch: `gi-pr3-watch-r2`. The original feature was cherry-picked; the old notes-only tip was not.

- Merge base: `9a73aabe67bdf117b8caf94e173f8280305f4ed9`.
- First parent (PR 1 final): `e11be2c2d05fc95f08091e40465af2c72bb8b0bd`.
- Second parent (PR 2, including main): `e6e081a7443e6fd28ac533080ec8328ebabbe098`.
- Base alone: harness **970 passed / 0 failed / 100390 assertions**; prescribed Python 3.14/lupa 2.8 gate **rc 0**, same RESULT; archive `b4e335e8e78f42892c5f9fd01a55a3abf1a53e579ad1ca4bf476f78dc8ac9565`.
- Port: `b9d0c1930a974f646ae1a66f4125fe5a74ffa8fe`, from original `5b2d7b1134bf2f162a7b29cdff1af31243741eac`.
- Port alone: harness **1006 passed / 0 failed / 104207 assertions**; gate **rc 0**, same RESULT; archive `36830e47913bf42ea38227ce2f373e83e7305d971fa48e11c003a1c27bda8b0f`.

Merge resolutions kept both test-loader sets, UNIT_TARGET plus own-death events, and K reception beside T. Generated merge notes were regenerated, not hand-resolved. PR 2's listed-only O counts and independent War Effort picker/stamps were retained. Two auto-merged old public-array references were restored to the new public report's `enemies` and `count`; the port's first full run exposed these errors. Share.pick and Relay retained watch ordering. Find.lua and Known.lua are unchanged from the composed base. Wire.lua and the stricter verify.py are unchanged.

**Port test adaptation:** no PR 3 expectation changed to make the port pass. Two PR 1 UI/evidence tests (`Round1 own: a newer guild O keeps fresh own evidence primary and both lines visible`, `Round1 hash: fresh Ask provenance is visible beside the old own sighting`) now load with `findShare=false`. Their time advances legitimately cross the new T send deadline; the fixture disables that unrelated default-on traffic while retaining every UI/provenance and zero-send assertion. The first port run failed these two assertions with one T each. The original feature's saved-key allowlist additions are retained.

## Round 1 fixes

The orchestrator's later rulings are authoritative over the original early-ticket allowance.

| Finding | Fix commit | Test-first RED | GREEN full harness |
|---|---|---|---|
| M1 cooldown and fairness | `94f5b63e257143a91f01b24d0b0beb6358089c3b` | 1001 pass / 9 fail; flap 1s and 5s: expected 5 O, got 20; 30s: got 10; crowd: expected 9 identities, got 4 | 1010 / 0, 108681 assertions |
| S1 bare subcommands | `36e445af538208be752e5e0c86beaf4313722211` | 1010 / 2; both bare tokens were appended to Find | 1012 / 0, 108803 assertions |
| S2 roster admission | `9f190a98c23734a3243543009735f9b9b38b47a7` | 1013 / 1; departed sender was held again | 1014 / 0, 108910 assertions |
| Hash-only wording | `232c053e0f96b5c832cac2ba231a9e46f1188c98` | 1012 / 3; collision and ordinary notices claimed definite identity | 1015 / 0, 109017 assertions |

A separate disposable clone of the frozen port `b9d0c1930a974f646ae1a66f4125fe5a74ffa8fe`, with only the final watch tests overlaid, also reproduced **1000 tests passed / 15 failed / 107704 assertions (rc 1)** in the full harness. A narrow watch-only replay using the unchanged client fixture gave **30 passed / 15 failed / 7265 assertions**. All failures were behavioral assertions: nine M1, two S1, one S2 and three wording failures; none was a missing-module or setup error. Production modules remained those of the frozen port.

M1 removes early-repeat tickets entirely. Priority only sorts the normally eligible cohort, never changes receipt stamps or reinserts already-sent names. The same admission bug caused amplification and starvation, so they are one fix with separate regression tests and mutants. Flap tests exercise both local edits and remote T input at 1, 5 and 30 seconds. Nine continuously seen enemies (four listed) all leave, listed first, with the same nine packets over 180 seconds as base.

**Authorized PR 3 test migrations:** the old `watch 20`, early receipt, withdrawal, O locality, early budget and early-change tests now assert cooldown-respecting priority, unsent-cohort delivery and independent public admission instead of authorizing early repeats. The changed ordinary notice and sorted-attribution expectations now require uncertain wording. Timing, freshness, provenance and route restrictions were not relaxed. The new guild-reset coverage passed before S2 and is not counted as RED evidence.

S1 prints usage before the generic Find-name parser. Tests preserve existing names and switches and inspect later T payloads for leaked command hashes. S2 stores only the last complete, bounded membership snapshot, includes offline members, preserves it through unreadable updates, and discards it on guild reset. Delayed complete and partial lists from absent senders remain refused until a complete update readmits them.

**Wording decision:** every on-site watch notice is based only on the T hash-to-senders index. There is no exact-name notice path, so all notices say **“may be tracked by”**, including multiple-watcher attribution. The real `tdlojwpniv` / `lvvaasbsmb` collision (`WPokl2`) is tested. Local Find's exact-name evidence and wording are untouched.

### Reviewer probes (original tip versus rebuilt candidate)

All execution used disposable clones. Reviewer files stayed read-only; original probes were copied byte-for-byte.

| Probe | `b933280b` | Rebuilt candidate |
|---|---|---|
| Single enemy, 300s, no flap / 1s / 5s / 30s | 5 / 20 / 20 / 10 O lines | 5 / 5 / 5 / 5 |
| Astra flood, 9 enemies, four listed, 180s | 12 O, 4 identities, five missed | 9 O, 9 identities, none missed |
| No-flood nine-enemy control | 9 O, 9 identities | unchanged |
| Bare share, then bare notice | tracks both tokens | empty list; two usage messages |
| Removed sender replay | held=1, notice=1 | held=0, notice=0 |
| 300s edits/toggles | 16 T, peak 3/60s, final payload correct | unchanged |
| Notice timing at 100/159.9/160/699/700/1600 | 3/3/6/6/9/9 | same counts with qualified wording |
| Master-off, then clear owed | 0 T while off, one clear on return, no later T | unchanged |
| Astra malformed frames | 14 preserve previous lists | unchanged |
| Ten-minute T refusal | 30 attempts, one recovery, peak 3/60s | unchanged |
| Real collision | definite notice | one “may be tracked by Bob” notice |

The untouched reviewer notice counters search specifically for ` is tracked by ` and therefore print zero after the wording fix. Separate, clearly named companion copies widen only that output counter to ` tracked by `; they prove unchanged notice counts and print the new collision message. This is a probe-output adaptation, not a production or behavioral-test bypass. All Astra scenarios, including nonmember, departure, routes/self, malformed frames, saved-list sizes, retry and unchanged-body/new-id, return rc 0 with Main.error=nil and no forbidden calls.

### Current mutation evidence

All four complete runners used disposable clones of `8b7fa247f2d12fb1dd27d1f019dc412276d0fb83`. This is the final source/test tree; later commits contain only documentation and generated evidence. Every runner returned rc 0 on its completed run and all source bytes were restored. Separately, all 71 single-edit mutant variants compiled with Lua 5.1.

| Runner | Killed | Evidence |
|---|---:|---|
| `test/watch_mutants.py --lua <lua>` | 19/19 | `notes/watch-mutants.json` |
| `test/crowd_mutants.py --lua <lua>` | 12/12 | `notes/watch-crowd-mutants.json` |
| `test/guild_intel_mutants.py --lua <lua>` | 29/29 | `notes/watch-guild-intel-mutants.json` |
| `test/find20_mutants.py <lua>` | 11/11 | `notes/watch-find20-mutants.json` |
| Total | **71/71** | No surviving mutants |

| Added round-1 mutant | Required behavioral failure | Full-harness failures |
|---|---|---:|
| List churn re-arms receipt cooldowns | 1s churn: expected 5 O, got 20 | 8 |
| Unlisted sightings starve | expected 9 distinct names, got 4 | 5 |
| Bare subcommand is tracked | expected only Keep Name, got Keep Name plus share | 2 |
| Removed sender is readmitted | expected no held sender, got the departed sender | 1 |
| Hash notice claims definite identity | expected “may be tracked by”, got “is tracked by” | 3 |

**Anchor changes:** the old War Effort mutant's `local public=rep.public` anchor no longer exists after the PR 2 port; it now removes the independent public cooldown reservation and fails the updated O-locality test. The two early-ticket mutants were replaced with receipt-cooldown and withdrawn-own-list-priority mutations because the owner ruling removed early tickets altogether. Their behavioral coverage remains, against the new contract. All other watch anchors and all crowd/guild-intel/Find20 anchors matched without edits. The watch inventory remains the previous 14 coverage targets plus five explicit review-fix mutants.

The first four-way concurrent run exceeded the crowd baseline's existing 120-second timeout before any mutation. Original source restoration was verified; the failed log was preserved. Once Find20 completed, crowd was rerun with less contention and killed 12/12 without changing any timeout. The first aggregate wrapper therefore exits 1 for that archived baseline failure; the completed crowd rerun and the other three individual runners all exit 0. No timeout is counted as a killed mutant. No survivor required a new test after the mutation run.

### Current verification artifact

The prescribed Python 3.14/lupa 2.8 verification command returned **rc 0** with **RESULT: 1015 tests passed, 0 failed, 109017 assertions**. A separate direct Lua 5.1 harness run returned the same RESULT. Syntax, strict API ownership, TOC/Media allowlists and deterministic archive/source parity all pass. Current archive SHA-256: `010779e48f78809ef12c7166b117faf8efc9f5f07de18ae10dba21a6853278fa`.

The final generated verification files are committed separately after this evidence, using the required notes-only commit convention. Reviewer probes are rerun against a disposable clone of that final tip; the original versus rebuilt outputs above describe unchanged production bytes.

### Final review scope

Self-review of the composed diff: one new production Wire.send call, only LEGW1/GUILD T; SendAddonMessage remains Wire-owned; only findShare/findNotice are newly saved. PR 1 evidence and PR 2 receiver/public-lane fixes remain in the full suite. No new dependencies or native client work. Independent approval remains the parent's review lane; native checks are **not run (alpha, owner's decision)**.
