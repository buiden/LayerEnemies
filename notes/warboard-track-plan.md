# E2 execution ledger — PLAN.md 8.5

Authority: /opt/data/handoffs/2026-11-17-le-1.2.0/PLAN.md sections 1, 3, 8.5; audit-warboard.md 1.6.3. Base 65904e66. Local commits only.

- Preserved inherited unfinished work as 82fcf57 after its 45 tests passed (3669 assertions). Its cancellation gates, persistence, rates, server clock and disclosure contradicted the binding spec. Superseded all old rulings in this file.
- New spec tests on WIP: 16 passed, 23 failed, 2945 assertions. On detached 65904e66 with only the test file copied: 3 passed, 36 failed, 2821 assertions. Log: /opt/data/cache/scratch/le-e2-base-red.log. Three baseline passes are negative guards, not new-feature evidence.
- Pre-flight: BN.send returns admission, not API acceptance. Add completion callbacks, preserve Wire's caller frame and shared budgets; settle debt only on actual success.
- Pre-flight: disabled Sources must allow cleanup ticks and incoming H/A only when debt exists; all other traffic remains switched off.
- Ruling: tracking switch is session-only, defaults on at login. Only one new saved field is authorized and switch persistence was not specified. Existing source/share/consent settings stay saved.
- Ruling: restore every prior-session debt as closing before asking again, including still-tracked names. Conservative cleanup before a new subscription costs a possible extra FBUN, never expands FBAK scope.
- Ruling: inherited local combat/instance retirement remains, now retaining rather than dropping cleanup. Costs a fresh-start pause after local combat but avoids unwithdrawn subscriptions.
- Source check: CurseForge files page still lists Forever 1.6.3 / 9639808 as newest Forever release. No source drift requiring a new wire audit.
- Native checks not run (alpha, owner's decision). No donor code copied/executed.
