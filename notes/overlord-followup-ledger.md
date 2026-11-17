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
- Part A gate: full verify; all Overlord mutants; separate evidence commit and move C3 tag.
- Part B: fetch main, merge --no-ff into C2, resolve semantically and verify; separate notes commit and move C2 tag. Merge updated C2 into C3 and repeat all gates; document every conflict and non-mechanical production edit in notes/overlord-main-merge.md.
- Native testing: not run (alpha, owner's decision).

Pre-flight shared interfaces: feed eligibility consumes adapter identities and cached BNet peer membership; cancellation can run inside a queued NH guard without a sender; retained stops must survive shared queue pruning; main changes may overlap both branches' transport gates. Preserve queue caps, exact-stop privacy exception, donor stand-down and C2 ordinary lanes.
