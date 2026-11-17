# FLH F2 review rulings — corrected membership gate

## Scope and checkpoints

- Reviewed base: `f865f58c2581a2b5ae7a672d093205e1ec6e3711`, branch `feat/flh-membership`.
- Verified implementation/test head: `e54229dfde9f3a960c00eba2027233cda26707ec`.
- Runtime corrections: `36e699f` (S1/S2), `b788fbf` (S3/N2).
- Route/evidence/README changes: `f5e72f8`; baseline-compatible evidence regression: `4a195cd`; deterministic timestamp-granularity check: `e54229d`.
- Review input: `parent-verdict-flh-member.txt` and read-only probes 3, 4 and 6 in the reviewer's F2 folder. These rulings supersede earlier F2 budget/negative-response statements in `flh-membership.md`.
- Local commits only. No push, installation or GitHub writes. Native checks **not run (alpha, owner's decision)**.

## Implemented rulings

**S1 — shared ceilings.** All six membership sends (HI, WR, CA, WP, LQ, LR) now check and spend Wire's existing global eight-token bucket (1/1.5 s refill) and rolling 40/60 s ledger. The existing public 20/minute, per-person four/minute, six-reply, four-probe, presence and guest caps remain additional restrictions. No global constant was changed. Probes leave six shared tokens, six shared minute slots and six public slots for owed WR/CA; neither kind bypasses the overall ceiling. A local budget refusal does not spend a sender/probe cooldown. Existing hop-any's separate lane and fan-out cadence are unchanged.

The reviewer cases reproduce exactly on the frozen base: eight ordinary plus six replies sends **14**, and forty ordinary in 59 seconds plus replies sends **46**. The corrected boundary admits **8** and **40**, respectively. Reverse-order membership-before-ordinary traffic, each of the six message kinds, clock rollback, exact minute expiry, probe priority and cooldown recovery are covered.

**S2 — retain directory membership.** Joining retains the full permission/safety gate. Once joined, combat/instances stop reads and sends, not membership. Actual join/leave counts over twenty 30-second fights with 60 seconds between are **1 join / 0 leaves**, the same as HeadHunter. The equivalent instance-cycle test also passes. A privacy/owner leave requested while unsafe is deferred until safe; sends are refused immediately. Manual channel ownership and stand-down rules remain unchanged.

**S3 — host responses.** A selected host's matching LD, LA, HQ, bare LN or LN with a reason cancels both guest state and armed invite authority. One fixed-text status line reports declined / didn't answer / queued you; duplicate responses do not print again. A host invite afterward is not accepted. Wrong ID, sender, realm or route cannot cancel someone else's click.

**N2 — leader hand-off.** `LI|id|S|leader` from the selected, successfully requested host replaces (not widens) pending invite authority with that exact validated whole leader identity. It cannot create authority without a successful LR or reset the original 90-second deadline. Missing/invalid/self leaders authorize nobody. Bare LI is only acknowledgement, and cannot undo a prior hand-off. Tests cover a foreign-realm leader, wrong senders/IDs/routes, failed LR, 89/90/91-second boundaries and decline after hand-off.

**S4 — exact route policy.** The allow-list is unchanged: FLHNET2 is GUILD/PARTY/RAID/WHISPER only, with the other five prefixes preserved. `verify.py` now tokenizes the table, requires unique literal approved keys with `true` values and complete route sets, and freezes the private table's read-only access sites. It rejects CHANNEL=1, bracket/concatenated/dynamic keys, duplicates, aliases and later table assignments. Comments and inert strings do not create references. No send/party API ownership exception was added. Exact gate diff: `flh-rulings-gate.diff`.

**N1 — accepted side effect.** README explicitly says another-realm Forever Layer Hop clients may introduce our name, realm, map and layer on their own realm's channel, as for any FLH user. LE itself sends no channel messages or other players' names.

**N3 — stable evidence.** The hop-fanout runner normalizes Lua object addresses and checkout paths, uses a sorted deterministic JSON writer, skips identical writes and verifies restoration of its baseline. Lua and scratch paths are configurable; mutation copies never edit the working addon.

## RED → GREEN

All new tests were copied onto a detached **f865f58c** worktree before their corresponding runtime/gate/runner fix. No production file in that worktree changed. Inherited assertions were not weakened or migrated.

| Slice | Frozen-base RED | Corrected result |
|---|---|---|
| S1 shared ceilings and probe priority | 11 failed | All 11 pass |
| S2 retention / deferred unsafe leave | 4 failed | All 4 pass |
| S3 cancellation and one status line | 5 failed | All 5 pass |
| N2 hand-off checks | 4 failed, 3 already passed | All 7 pass |
| Final new Lua suite, including correlation controls | 4 passed, **25 failed**, 1,829 assertions | **29 passed, 0 failed, 2,222 assertions** |
| Python route/README/evidence regressions | 21 test methods; **16 failing subtests/assertions**, no errors | **21 methods pass** |

The four base-passing Lua tests are preserved-boundary controls, not counted as RED. The final decline-after-LI case also fails on the base because its decline handling is missing; it is not an extra independent hand-off RED. A first combined Python replay exposed an obsolete runner-argument fixture rather than a production failure; the test was made compatible with both runner signatures and the frozen-base replay repeated without errors. That setup error is not counted.

Logs: `flh-rulings-s1-red.txt`, `-s2-red.txt`, `-s3-red.txt`, `-n2-red.txt`, `-s4-red.txt`, `-n3-red.txt`, `flh-rulings-final-red.txt`, and `flh-rulings-python-red.txt`. The Python summary omits the full README embedded in an assertion traceback; the raw output remains in external scratch.

Full membership suite: **91 passed, 0 failed, 21,653 assertions**. Existing receive suite: **29 passed, 0 failed, 19,738 assertions**.

## Full verification

Final `python3 test/verify.py` ran **foreground**, subprocess/tool timeout **1800 seconds**, Lua 5.1.5, scratch under `/opt/data/cache/scratch`, exit **0**:

```text
RESULT: 1542 tests passed, 0 failed, 276851 assertions
```

Lua syntax (86 files), TOC/static/API policy, Python policy/evidence tests and archive/source parity pass. Regenerated `test-results.txt` and `verification.json` contain the real output. Archive SHA-256:

```text
5595e4bf370e241adff6c4340efd27547a04653b7b659b8da5ef3e964ea7151c
```

## Mutation evidence

- New ruling controls: **20/20 killed**, including at least one per S1–S4 and N1–N3 rule, in `flh-rulings-mutants.json`.
- Existing membership controls: **52/52 killed**, in `flh-member-mutants.json`.
- Existing receive controls: **39/39 killed**, in `flh-mutants.json`.
- Existing hop-fanout controls: **63/63 caught**, in `hop-fanout-mutants.json`.
- Mutants compile; syntax errors, incomplete collections and timeouts are not kills. Every suite restores its positive baseline. There are **no final survivors**. One N3 writer mutant survived the first relocated run because two writes shared a filesystem timestamp tick. The test now pins an old mtime, making any rewrite observable without sleeping; all twenty ruling mutants were repeated and killed. No runtime fix was needed for that test-quality issue.
- All four reports were rerun from an independent checkout with spaces in its path, launched from `/opt/data` with relative scratch. **Bytes and mtimes stayed unchanged** in both the original and relocated copies. The corrected twenty-mutant rerun also retained its report exactly. Per-report hashes/checks: `flh-rulings-stability.json`.
- The added-line security scan found no hardcoded secrets, shell injection, eval/exec or unsafe deserialization; `flh-rulings-security.json`.
- Some long mutation-tool wrappers timed out at 420 seconds despite larger requested limits. Their process state/logs were inspected rather than crediting partial output; complete results were recovered/replayed. The full verification calls themselves returned exit 0 directly.

## Source and files

Pinned donor source SHA-256 remained `e86941e5fcef9bf88caa150c68b614bd2929e0cefe5ed27f0634b8c5f8186bc2`; release 0.1.9 archive hash remains as in THIRD_PARTY.md. Only wire facts were read (LI producer/receiver, LD/LA/HQ), never donor code executed or copied.

Runtime files: `Directory.lua`, `FLH.lua`, `FLHMember.lua`, `Wire.lua`. Documentation: README. Tests/gates: new `src_flh_rulings.lua` and `flh_rulings_mutants.py`, existing API/evidence tests and mutation runners, `verify.py`. This notes-only commit records RED logs, the exact gate diff, mutation reports and regenerated verification evidence separately from those implementation commits.
