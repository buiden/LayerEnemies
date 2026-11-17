# C2/C3 execution ledger

Authority: /opt/data/handoffs/2026-11-17-le-1.2.0/PLAN.md, audit-overlord-peer.md, owner's builder overrides. Base 90d4444cc32d1463e98c9ede1274750bea5af98f. Target Forever Interface 16001. No donor code execution/copy, no installation, push or GitHub writes.

Pre-flight: C3 consumes C2 direct validated routes; unknown campaign epoch must never produce a request. Keep Main's inherited Overlord prefix ownership. Tick-only registration enables BN.send and Src.offer. Existing UI measured detail path is sufficient; no new UI widgets.

Ruling: SR has no truthful empty-map wire answer. The audited producer Sync.lua:6058 emits zero pages for an empty store. Do not fabricate neutral zones or an invented empty ACK; record the request and send no map data. The plan's 'never ignored' map request sentence cannot be fulfilled by this protocol with no store. Leaderboard comparison requests can truthfully answer zero/zero, unsupported requests can receive HA R.

Ruling: owner privacy overrides C3's switch-off stop message. Share off / Guild only / network off sends absolutely nothing, including HR X. Cancel subscription locally; donor expires its lease. Voluntary unsubscribe while enabled may use HR X under the same source gap.

C2 RED before production edits: lua test/harness.lua --only 'Overlord peer:' -> 0 passed, 4 failed, 168 assertions (missing long fragments, receive routes and peer).

## C2 delivered evidence

- Implementation commit: `6fa930b`.
- Final fixtures copied onto detached base `90d4444`: **1 passed, 27 failed, 11157 assertions**, exit 1. Base worktree removed afterward. GREEN: **28 passed, 0 failed, 11790 assertions**.
- `python3 test/verify.py`: **1478 tests passed, 0 failed, 268621 assertions**; 11 send-policy + 13 API-policy + 4 archive + 11 codec Python tests OK. Archive SHA-256 `22846c9436906e9ac708deb2cbccf4a59fec4399a08fc4c3c7d7d2e5fa7c66da`.
- New mutation runner: **45/45 killed**, syntax-valid behavioral assertions only; repeated from another working directory with a relative TMPDIR, byte-identical report SHA-256 `edcf03514083f581d86bf19616982d7af4573739ec3fe142639c21e7353c13fd`.
- `test/verify.py` and its sender allowlist/gate were **not changed**. New sends remain in Main through the Wire gate; Battle.net always uses BN.send. Added pure-state/transport tests to api_policy_test.py, a dispatch-only Wire flight check, and optional BN.send delivery guard. New eight-frame source required shared-queue fixture allocation changes, not quota changes.
- Pin audit: 2.5.4 HEAD and tag both `c821808586ab50bb4ccb5d54b146e0d7c2671734`. C1 omissions settled: WHISPER BF, R2 BR/BF Battle.net, 24-part reassembly, 2000 dedupe entries, pool-suffixed channel names/two-free-slot threshold. GW/GD/EK grammar remains compatible; GeneralSync/GuildKillAlert/RealmPools changes relative to the C1 reference are memory instrumentation only. CombatTracker also changes implementation but EK `zone,x,y,victim,class` remains the same.
- Only direct NH/HA answers; no SR response, forwarding, helper advertisement, claim publication or saved peer names. README is the send-table authority. Native validation not run (alpha, owner's decision).
