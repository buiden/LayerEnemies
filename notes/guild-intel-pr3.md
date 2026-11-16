# Guild-intel PR 3: shared watch list and on-site notice

Base: `c229b9b`; branch: `gi-pr3-watch`. Scope: plan section 12 (tests 16–25), section 5.4 and section 6 budgets. Target remains Forever, Interface 16001; Lua 5.1. No installation, push, Wire change, or earlier-branch edit.

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
