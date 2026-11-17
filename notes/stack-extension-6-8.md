# Stack extension: registry, Wanted, ChehulNet

Local-only integration on updated `stack/5-overlord` (`08133f01608e1df1926c78e26fd68e4fb3f90d3c`). Levels 1–5 remain frozen. Every level uses a two-parent `--no-ff` merge, regenerates `notes/test-results.txt` and `notes/verification.json`, and runs the complete foreground gate. No push, GitHub write, installation or donor execution. Package stays 1.1.0 pending the release lane; native checks not run (alpha, owner's decision).

Evidence: `/opt/data/cache/scratch/le-stack-6-8-evidence/`; machine ledger: `/opt/data/cache/scratch/le-120-stack-ledger.json`.

## Level 6: source registry

Source: `d7f6d9c9cc0493373cf11c593ef8ee4d3dfd1aed` from the old stack/5 lineage.

- Conflicts: `notes/test-results.txt`, `notes/verification.json`, `test/api_policy_test.py`. Regenerate both generated notes. Union the API-owner set, retaining presence's `GetAccountInfoByID` and the registry's additional game-account enumeration APIs; all remain adapter-owned.
- Production auto-merge preserves the updated presence readers, hop/WHO fixes, FLH host isolation and measured Overlord/pool admission. Registry ownership still refuses all 14 legacy prefixes. No migration of presence, FLH or Overlord to registry callbacks.
- One inherited registry test failed: `BNet: independent peer readers need no presence zone and read no account names` expected zero raw `bnFriends()` rows. Updated presence deliberately returns an index-only withdrawal marker for a visited incomplete friend so old evidence can be removed. Treating that marker as admitted presence was a stale test assumption, not a production bug.
- Test-only correction in `test/src_bnet_peers.lua`: assert the exact one-key `{index=1}` marker, then assert zero accepted presence through the real `Presence.accept` boundary. All other inherited assertions retained; production presence behavior unchanged. Focused peer suite RED 4 passed / 1 failed / 317 assertions, then GREEN 5 / 0 / 320.
- Focused checks: Sources 13/0/1028, queue 29/0/2332, presence 26/0/11002, Overlord 34/0/17044, prior stack composition 3/0/251 (passed/failed/assertions).
- `python3 test/verify.py`: **rc 0; RESULT: 1389 tests passed, 0 failed, 214126 assertions**. Static/API policy, syntax, TOC and deterministic archive/source parity pass.
- Archive SHA256: `7c45161dc09085cd67a2205f4f6b68c06cd254d043ad19de5fd894678e7a3d77`.

Ruling: retain the updated withdrawal contract and move the legacy zero-evidence assertion to its actual admission boundary, rather than remove withdrawal markers or relax evidence requirements. Cost if wrong: missing or malformed markers now fail exact shape assertions, and any zoneless presence admission fails the retained zero-evidence assertion.

## Level 7: Wanted receive

Source: `108fb6f0cb1c8f46e3c61dd392ed1b6522f7c51a` (built on the earlier registry).

- Conflicts: both generated verification notes and `test/src_bnet_queue.lua`. Regenerate notes; combine Wanted's real-registration reuse with the corrected four-frame admission cap and explicit fifth-frame refusal. Do not restore the old five-frame admission expectation.
- The complete queue subset initially failed 13 cases (16 passed / 13 failed / 1707 assertions). Root cause: queue fixtures assumed an empty registry, registered Wanted again, and computed default shares from synthetic sources only. `loadAddon` also disables shipped send lanes, whereas synthetic registrations are added after that isolation step.
- Test-only correction: add `test/bnet_queue_fixture.lua`; reuse Wanted's actual registration/counters and explicitly restore its shipped lane inside queue tests; include all registered sources in the independent `max(1,floor(30/count))` expectation. Fill capacity cases using eligible real sources instead of assuming one source may hold 30 frames. No production queue/codec change, no disabling or replacing production registrations, no assertion relaxation.
- Exact contractual boundaries still exercised: 30 attempted sends per rolling minute, one-second pace/no catch-up, 52 normal plus eight owed slots, absolute 60, configured 4/8/10 shares, 32 registered sources, sixty-second frame lifetime, priority/privacy/cancellation and caller-frame checks. The rolling-cap tests explicitly establish eligible queued work beyond 30 before asserting refusal. Four parameterized default-share test names now say requested default sources rather than falsely claiming the registry contains only those sources; all cases retained.
- Intermediate fixture run: 24/5/2076 exposed the harness's shipped-lane isolation; final corrected queue subset **29/0/2339**. All source mutants **41/41 killed** on this composition, including all three queue ruling mutants; no survivors or assertion weakening.
- Wanted **25/0/20657** and Codec **30/0/34567**. Wanted uses its numbered assembler and rejects AceComm controls. Shared AceComm tests confirm **15-second idle and 120-second total** expiration. The newer codec and queue implementation remain byte-identical to the registry input.
- `python3 test/verify.py`: **rc 0; RESULT: 1414 tests passed, 0 failed, 234815 assertions**. All static/API, syntax, TOC and archive/source parity gates pass.
- Archive SHA256: `20eccf445b80bcb2fb955d782383c24b2fa333ffbe94d423e461651e131aadc9`.

Ruling: update queue fixtures to the actual composed registration state, not the production fairness policy. Cost if wrong: exact cap, excess-admission, overflow/expiry and behavioral mutation assertions fail; the suite no longer relies on an empty shipping registry.
