# Overlord follow-up ledger

Spec: /opt/data/handoffs/2026-11-17-le-1.2.0/PLAN.md sections 6.5/6.5.1 and delegated M, S1, S2, n1–n3 requirements.
Base: fix/c3 2eff0188; lower branch fix/c2 9af42790. Local commits only; no push.
Reviewer scenarios: read-only /opt/data/profiles/mani/cache/scratch/c4/p9.lua and parent-verdict-overlord-r2.txt.

- Preflight: inherited Overlord revision suite 38 passed, 0 failed, 2222 assertions.
- M: reproduce foreign-realm guild friend and positive/unknown-identity controls through actual adapters and Main.
- S1: reproduce all 31 party-join offsets with a second unselected friend; preserve cancellation in senderless dispatch contexts.
- S2: invalidate cached friend eligibility on BN_FRIEND_LIST_SIZE_CHANGED and stop an active removed friend immediately.
- n1: retain owed stops through unsafe contexts, with at most 60 safe seconds to deliver, no duplicate successful stop.
- n2: retain actual NH accounting across pool/own-character round trips.
- n3: answer only protocol-8 addressed HR V.
- Part A gate: complete. Full verify: `RESULT: 1656 tests passed, 0 failed, 296079 assertions`; follow-up mutants 8/8 and reachability mutants 48/48. Separate evidence commit and C3 tag moved before upstream merge.
- Part B gate: complete against requested main `44e41e8d`. C2 full verify 1849 passed/0 failed/542339 assertions, all 420 mutants killed. Verified C2 merged --no-ff into C3; C3 full verify 2015 passed/0 failed/570000 assertions, all 539 mutants killed. Receiver C3 rules were rerun in six exact-disjoint shards after the monolithic foreground timeout; all expected rules occur once and all shards exited 0. Every conflict and production departure from AUTO_MERGE is recorded in notes/overlord-main-merge.md and its full-resolution diffs. Evidence commits remain separate and checkpoint tags are moved locally.
- Native testing: not run (alpha, owner's decision).

Pre-flight shared interfaces: feed eligibility consumes adapter identities and cached BNet peer membership; cancellation can run inside a queued NH guard without a sender; retained stops must survive shared queue pruning; main changes may overlap both branches' transport gates. Preserve queue caps, exact-stop privacy exception, donor stand-down and C2 ordinary lanes.
