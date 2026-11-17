# FLH membership: upstream catch-up merges

## Merge 1: WarBoard handshake/read and tracking

- Branch: `feat/flh-membership`; pre-merge head `b90bbbb422549171b22095ef2176188fb1808179`.
- Fetched main: `5b8545532d82fdbfd716eb5267616c5efdf4e9bc`; common base `2675e03d9363d4299a02d6d60815e0d65298967c`.
- Tested non-fast-forward merge: `49b100d0806bf57a80d55a3dd76584fe9ac8f722`.
- Mechanical `git merge-tree --write-tree` tree: `c06eb3dea99b5a0f5f82e2e8c49e6ef774ca00e4`.
- Local commits only: no push, GitHub write or game installation.
- Native checks: **not run (alpha, owner's decision)**.

### Complete conflict-hunk inventory

9 files, 38 conflict blocks. Line numbers refer to the saved, conflict-marked worktree immediately after merge.

| File | Hunk | Original line | Resolution |
| --- | ---: | ---: | --- |
| `LayerEnemies/Main.lua` | 1 | 2240 | Union both share-off cancellations: OwnDeath and BNet, FLH guest authority, then WarBoard tracking; keep Directory.sync. |
| `LayerEnemies/Net.lua` | 1 | 59 | Keep upstream BNet + WarBoard cancellation and branch FLH cancellation before saving non-public consent. |
| `LayerEnemies/Net.lua` | 2 | 72 | Keep upstream per-network BNet/WarBoard cancellation, branch FLH stop, and the session-only switch exclusion from saved nets. |
| `notes/chehulnet-mutants.json` | 1 | 6 | Regenerated the entire report with its corresponding complete mutant runner; old assertion counts, failure lines and object addresses were not hand-merged. |
| `notes/chehulnet-mutants.json` | 2 | 17 | Regenerated the entire report with its corresponding complete mutant runner; old assertion counts, failure lines and object addresses were not hand-merged. |
| `notes/chehulnet-mutants.json` | 3 | 28 | Regenerated the entire report with its corresponding complete mutant runner; old assertion counts, failure lines and object addresses were not hand-merged. |
| `notes/chehulnet-mutants.json` | 4 | 39 | Regenerated the entire report with its corresponding complete mutant runner; old assertion counts, failure lines and object addresses were not hand-merged. |
| `notes/chehulnet-mutants.json` | 5 | 57 | Regenerated the entire report with its corresponding complete mutant runner; old assertion counts, failure lines and object addresses were not hand-merged. |
| `notes/chehulnet-mutants.json` | 6 | 68 | Regenerated the entire report with its corresponding complete mutant runner; old assertion counts, failure lines and object addresses were not hand-merged. |
| `notes/chehulnet-mutants.json` | 7 | 79 | Regenerated the entire report with its corresponding complete mutant runner; old assertion counts, failure lines and object addresses were not hand-merged. |
| `notes/chehulnet-mutants.json` | 8 | 144 | Regenerated the entire report with its corresponding complete mutant runner; old assertion counts, failure lines and object addresses were not hand-merged. |
| `notes/presence-mutants.json` | 1 | 36 | Regenerated the entire report with its corresponding complete mutant runner; old assertion counts, failure lines and object addresses were not hand-merged. |
| `notes/presence-mutants.json` | 2 | 60 | Regenerated the entire report with its corresponding complete mutant runner; old assertion counts, failure lines and object addresses were not hand-merged. |
| `notes/presence-mutants.json` | 3 | 72 | Regenerated the entire report with its corresponding complete mutant runner; old assertion counts, failure lines and object addresses were not hand-merged. |
| `notes/presence-mutants.json` | 4 | 112 | Regenerated the entire report with its corresponding complete mutant runner; old assertion counts, failure lines and object addresses were not hand-merged. |
| `notes/presence-mutants.json` | 5 | 147 | Regenerated the entire report with its corresponding complete mutant runner; old assertion counts, failure lines and object addresses were not hand-merged. |
| `notes/presence-mutants.json` | 6 | 159 | Regenerated the entire report with its corresponding complete mutant runner; old assertion counts, failure lines and object addresses were not hand-merged. |
| `notes/presence-mutants.json` | 7 | 172 | Regenerated the entire report with its corresponding complete mutant runner; old assertion counts, failure lines and object addresses were not hand-merged. |
| `notes/presence-mutants.json` | 8 | 235 | Regenerated the entire report with its corresponding complete mutant runner; old assertion counts, failure lines and object addresses were not hand-merged. |
| `notes/presence-mutants.json` | 9 | 247 | Regenerated the entire report with its corresponding complete mutant runner; old assertion counts, failure lines and object addresses were not hand-merged. |
| `notes/presence-mutants.json` | 10 | 259 | Regenerated the entire report with its corresponding complete mutant runner; old assertion counts, failure lines and object addresses were not hand-merged. |
| `notes/presence-mutants.json` | 11 | 284 | Regenerated the entire report with its corresponding complete mutant runner; old assertion counts, failure lines and object addresses were not hand-merged. |
| `notes/presence-mutants.json` | 12 | 306 | Regenerated the entire report with its corresponding complete mutant runner; old assertion counts, failure lines and object addresses were not hand-merged. |
| `notes/presence-mutants.json` | 13 | 334 | Regenerated the entire report with its corresponding complete mutant runner; old assertion counts, failure lines and object addresses were not hand-merged. |
| `notes/presence-mutants.json` | 14 | 425 | Regenerated the entire report with its corresponding complete mutant runner; old assertion counts, failure lines and object addresses were not hand-merged. |
| `notes/presence-mutants.json` | 15 | 437 | Regenerated the entire report with its corresponding complete mutant runner; old assertion counts, failure lines and object addresses were not hand-merged. |
| `notes/source-mutants.json` | 1 | 125 | Regenerated the entire report with its corresponding complete mutant runner; old assertion counts, failure lines and object addresses were not hand-merged. |
| `notes/source-mutants.json` | 2 | 136 | Regenerated the entire report with its corresponding complete mutant runner; old assertion counts, failure lines and object addresses were not hand-merged. |
| `notes/source-mutants.json` | 3 | 147 | Regenerated the entire report with its corresponding complete mutant runner; old assertion counts, failure lines and object addresses were not hand-merged. |
| `notes/source-mutants.json` | 4 | 158 | Regenerated the entire report with its corresponding complete mutant runner; old assertion counts, failure lines and object addresses were not hand-merged. |
| `notes/source-mutants.json` | 5 | 206 | Regenerated the entire report with its corresponding complete mutant runner; old assertion counts, failure lines and object addresses were not hand-merged. |
| `notes/test-results.txt` | 1 | 1399 | Regenerated the complete unfiltered merged Lua run, including both FLH and WarBoard suites; neither parent test/result block was selected. |
| `notes/test-results.txt` | 2 | 1608 | Regenerated the complete unfiltered merged Lua run, including both FLH and WarBoard suites; neither parent test/result block was selected. |
| `notes/verification.json` | 1 | 3 | Regenerated actual merged syntax/test/assertion counts and deterministic package metadata with test/verify.py; no parent numbers retained as merged evidence. |
| `notes/verification.json` | 2 | 20 | Regenerated actual merged syntax/test/assertion counts and deterministic package metadata with test/verify.py; no parent numbers retained as merged evidence. |
| `notes/wanted-mutants.json` | 1 | 727 | Regenerated the entire report with its corresponding complete mutant runner; old assertion counts, failure lines and object addresses were not hand-merged. |
| `test/bnet_queue_fixture.lua` | 1 | 28 | Keep the branch total argument, dynamic fair shares and alpha owed-slot reservation; use main's real WarBoard prefix and shipped-source registration. |
| `test/bnet_queue_fixture.lua` | 2 | 53 | Keep the branch weak-key reusable pool and dynamic remaining capacities; use main's real WarBoard prefix. Both configured-share accounting and the 32-source ceiling remain exercised. |

### Every production line differing from the mechanical merge

The exact complete diff below covers `LayerEnemies/*.lua` and `test/verify.py`. Only the three conflict resolutions in Main.lua and Net.lua differ; no other production or checker lines were adjusted.
FLHMember.lua, Directory.lua and Wire.lua remain byte-for-byte from the membership branch. Upstream WarBoard.lua, WarBoardTrack.lua, BNet.lua, Codec.lua and Sources.lua remain byte-for-byte from main. The saved warboardOwed and /le warboard command paths auto-merged.
The unchanged stricter checker was run across **every** merged addon file. All passed: no upstream file tripped the debug/API/send gate; no exemption, debug rename or route relaxation was needed. API policy tests: 26 passed.

```diff
diff --git a/LayerEnemies/Main.lua b/LayerEnemies/Main.lua
index b3bfa63..ebb45a2 100644
--- a/LayerEnemies/Main.lua
+++ b/LayerEnemies/Main.lua
@@ -2237,11 +2237,7 @@ function M.setFindNotice(on)
 end
 function M.sharing() return not S.tab(LayerEnemiesDB) or LayerEnemiesDB.share~=false end
 function M.setShare(on)
-<<<<<<< b90bbbb422549171b22095ef2176188fb1808179
-    if not on then N.OwnDeath.cancel(); N.BNet.cancel(); N.FLHMember.stop("share off") end
-=======
-    if not on then N.OwnDeath.cancel(); N.BNet.cancel(); if N.WarBoardTrack then N.WarBoardTrack.stop() end end
->>>>>>> 5b8545532d82fdbfd716eb5267616c5efdf4e9bc
+    if not on then N.OwnDeath.cancel(); N.BNet.cancel(); N.FLHMember.stop("share off"); if N.WarBoardTrack then N.WarBoardTrack.stop() end end
     if S.tab(LayerEnemiesDB) then LayerEnemiesDB.share=on==true end
     N.Directory.sync()
     -- Off cancels all pending guild relays as well as our sync answers. Queued guild/own embassy lines
diff --git a/LayerEnemies/Net.lua b/LayerEnemies/Net.lua
index 8bc1e42..e5149ca 100644
--- a/LayerEnemies/Net.lua
+++ b/LayerEnemies/Net.lua
@@ -56,12 +56,8 @@ function Net.why(key)
 end
 function Net.setConsent(level)
     if not Net.CONSENT[level] then return false end
-<<<<<<< b90bbbb422549171b22095ef2176188fb1808179
-    if level~="public" and N.BNet then N.BNet.cancel() end
-    if level~="public" and N.FLHMember then N.FLHMember.stop("guild only") end
-=======
     if level~="public" and N.BNet then N.BNet.cancel(); if N.WarBoardTrack then N.WarBoardTrack.stop() end end
->>>>>>> 5b8545532d82fdbfd716eb5267616c5efdf4e9bc
+    if level~="public" and N.FLHMember then N.FLHMember.stop("guild only") end
     state.consent = level; save()
     if N.Directory then N.Directory.sync() end
     return true
@@ -69,17 +65,12 @@ end
 function Net.switch(key) return state.switches[key] ~= false end
 function Net.setSwitch(key, on)
     if not Net.LIST[key] then return false end
-<<<<<<< b90bbbb422549171b22095ef2176188fb1808179
-    if on~=true and N.BNet then N.BNet.cancel(key) end
-    if key=="flh" and on~=true then N.FLHMember.stop("network off") end
-    state.switches[key] = on == true; if not Net.LIST[key].session then save() end
-=======
     if on~=true and N.BNet then
         N.BNet.cancel(key)
         if key=="warboard" and N.WarBoardTrack then N.WarBoardTrack.stop() end
     end
-    state.switches[key] = on == true; save()
->>>>>>> 5b8545532d82fdbfd716eb5267616c5efdf4e9bc
+    if key=="flh" and on~=true then N.FLHMember.stop("network off") end
+    state.switches[key] = on == true; if not Net.LIST[key].session then save() end
     if N.Directory then N.Directory.sync() end
     return true
 end
```

### Test-only integration repairs

- `test/bnet_queue_fixture.lua`: combined dynamic membership-aware queue capacity with real shipped WarBoard registration, prefix and public counters; no production source was disabled or replaced.
- `test/source_mutants.py`: refreshed two stale anchors for the new cleanup-aware dispatch condition and separate deliver result; kept the same privacy and failed-send mutations.
- `test/codec_mutants.py`: refreshed the bounded inflater maxWork and AceComm owner-bearing stream anchors; the latter mutation preserves owner metadata.
- `test/warboard_track_mutants.py`: refreshed share-off cancellation anchor while leaving the FLH stop intact in the tracking mutant.
- `test/find20_mutants.py` and `test/guild_intel_mutants.py`: refreshed two pre-existing stale UI measurement anchors without changing production UI.
- Crowd, Find20, watch and guild-intel mutant runners now select their existing relevant suites instead of rerunning the entire growing addon harness for every mutation. The crowd baseline actually exceeded its old 120-second subprocess timeout. The guild-intel alias in `test/harness.lua` includes Round1, Round2, Known, PartyTargets and Realm names; every declared mutation still has an assertion kill. **Full verify remains unfiltered and unchanged.**
- No assertion, mutant or production guard was removed. Syntax errors, missing anchors and timeouts were not counted as kills.

### Fresh verification and complete mutant inventory

**RESULT: 1879 tests passed, 0 failed, 498575 assertions**
- `timeout 1800 python3 test/verify.py`: exit 0; 98 Lua syntax files, TOC/static gates and archive/source parity pass.
- Archive `dist/LayerEnemies-1.1.0.zip`: 58 members; SHA-256 `9d52b12f56660f0d038225514e9fdfafe53a9c9bebadd5c728198dc5a7a2bc37`.
- All Python `*_test.py` suites: **56 tests, OK**, with the documented pinned Noto font. Initial discovery lacked CALL_ART_FONT; fetching and hash-checking the documented bytes resolved that environment prerequisite without source edits.

| Runner | Killed / declared |
| --- | ---: |
| `chehulnet_mutants.py` | 57 / 57 |
| `codec_mutants.py` | 56 / 56 |
| `crowd_mutants.py` | 12 / 12 |
| `find20_mutants.py` | 11 / 11 |
| `flh_batch_mutants.py` | 26 / 26 |
| `flh_member_mutants.py` | 52 / 52 |
| `flh_mutants.py` | 39 / 39 |
| `flh_rulings_mutants.py` | 20 / 20 |
| `guild_intel_mutants.py` | 29 / 29 |
| `hop_fanout_mutants.py` | 63 / 63 |
| `kill_mutants.py` | 20 / 20 |
| `overlord_mutants.py` | 54 / 54 |
| `presence_mutants.py` | 41 / 41 |
| `relay_policy_mutants.py` | 4 / 4 |
| `source_mutants.py` | 41 / 41 |
| `spy_mutants.py` | 7 / 7 |
| `wanted_mutants.py` | 84 / 84 |
| `warboard_mutants.py` | 115 / 115 |
| `warboard_track_mutants.py` | 113 / 113 |
| `watch_mutants.py` | 19 / 19 |
| **Total (20 packs)** | **863 / 863** |

Every runner executed in a private scratch copy with an explicit foreground `timeout 1800` command and subprocess timeout=1800; source hashes were checked after restoration and against the real checkout. The tool transport returned at its own 420-second wait cap for Wanted, membership, fan-out and verify; their existing bounded foreground subprocesses completed and their exit/result files were read, without relaunching or shell backgrounding.
Generated reports and this document are committed separately from the merge code. The merge index temporarily retained the branch versions of conflicted generated reports; this notes-only commit replaces them with real regenerated results. Imported main documentation stays in the merge. `flh-main-merge-2-validation.json` records inventories and hashes.

## Merge 2: quiet-whisper main catch-up

- Completed merge 1 and its notes-only commit `09d4a526157f614a3986e6ac0f2d5cbc7515f45e` before fetching the requested new main.
- Upstream `44e41e8d90617325aa6df1407b180ad1671cbaa5`; common base `5b8545532d82fdbfd716eb5267616c5efdf4e9bc`.
- Tested non-fast-forward merge: `7693da55d5543cc9b7a054fcb5a55b6989330faa`.
- Mechanical tree: `3f99c9612de9bd46032996af78dba7a0049b24f1`.

### Complete conflict-hunk inventory

2 files, 3 blocks; all generated evidence. **No production, verifier, test or allowlist conflict occurred.**

| File | Hunk | Original line | Resolution |
| --- | ---: | ---: | --- |
| `notes/test-results.txt` | 1 | 1998 | Regenerated the complete unfiltered merged test results, keeping every FLH, WarBoard, tracking and quiet suite. |
| `notes/verification.json` | 1 | 3 | Regenerated merged syntax/test/assertion counts and deterministic archive metadata; neither parent's numbers were selected. |
| `notes/verification.json` | 2 | 20 | Regenerated merged syntax/test/assertion counts and deterministic archive metadata; neither parent's numbers were selected. |

### Production-versus-mechanical result and combined gates

**No differences.** The complete comparison is empty:

```sh
git diff 3f99c9612de9bd46032996af78dba7a0049b24f1 7693da55d5543cc9b7a054fcb5a55b6989330faa -- 'LayerEnemies/*.lua' test/verify.py
```

- Wire.lua auto-merged the CHAT_MSG_SYSTEM filter and both secure post-hooks with the existing FLHNET2 routes and shared-ceiling LR token/minute reservation.
- Main.lua auto-merged quietWhispers loading, startup registration and `/le quiet` while retaining WarBoard owed cleanup and command handling plus all FLH membership cancellation/guest paths.
- The full verifier retains the **entire exact ROUTES[prefix] lookup**, route-table/alias/computed-key restrictions and addon-wide debug ban from the branch. AST comparisons confirm `check_route_policy` and `check_api_policy` are unchanged from the pre-quiet branch.
- `check_send_policy` is AST-identical to quiet main: both exact-once secure-hook registrations, both complete exact-once presence statements and all-addon pcall/hooksecurefunc binding rejection remain intact. Filter API ownership stays Wire-only.
- Every new main file and the combined Wire.lua passed the stricter checker without a production fix or new gate exception. Existing saved-data allowlists auto-merged quietWhispers alongside bounded warboardOwed; no saved peer evidence was introduced by this merge.
- No further test-runner repair was needed: every mutation anchor was preflighted, and all 22 complete packs ran again on this exact code.

### Final verification

**RESULT: 1943 tests passed, 0 failed, 504686 assertions**
- `timeout 1800 python3 test/verify.py`: **exit 0**. Includes 31 full static/TOC/secure-hook gate regressions and 27 API/route-policy tests, all passing.
- Lua syntax: **100 files PASS**; TOC/static ownership, archive integrity and exact packaged-source parity PASS.
- All separately discovered Python `*_test.py` suites: **57 tests, OK**, including the pinned-font renderer.
- Archive: `dist/LayerEnemies-1.1.0.zip`; **58 members**, **289863 bytes**.
- Archive SHA-256: `adc6f29f88f084f6ee4cf0edced80e4ded41f333e41f317dfef0b8874d4b3a97`.

| Runner | Killed / declared |
| --- | ---: |
| `chehulnet_mutants.py` | 57 / 57 |
| `codec_mutants.py` | 56 / 56 |
| `crowd_mutants.py` | 12 / 12 |
| `find20_mutants.py` | 11 / 11 |
| `flh_batch_mutants.py` | 26 / 26 |
| `flh_member_mutants.py` | 52 / 52 |
| `flh_mutants.py` | 39 / 39 |
| `flh_rulings_mutants.py` | 20 / 20 |
| `guild_intel_mutants.py` | 29 / 29 |
| `hop_fanout_mutants.py` | 63 / 63 |
| `kill_mutants.py` | 20 / 20 |
| `overlord_mutants.py` | 54 / 54 |
| `presence_mutants.py` | 41 / 41 |
| `quiet_all_mutants.py` | 43 / 43 |
| `quiet_mutants.py` | 38 / 38 |
| `relay_policy_mutants.py` | 4 / 4 |
| `source_mutants.py` | 41 / 41 |
| `spy_mutants.py` | 7 / 7 |
| `wanted_mutants.py` | 84 / 84 |
| `warboard_mutants.py` | 115 / 115 |
| `warboard_track_mutants.py` | 113 / 113 |
| `watch_mutants.py` | 19 / 19 |
| **Total (22 packs)** | **944 / 944** |

Every declared inventory and unique mutation name was counted programmatically, and every saved report hash was read back. All runners exited 0, and their private-copy addon bytes matched the real checkout after restoration. No surviving mutant or timed-out mutant execution is counted as a kill.
The same explicit foreground 1800-second command bounds were used. Tool transport timeouts again left bounded subprocesses running; their actual completion files and logs were read without duplicate launches. A standalone early gate command hit a 180-second tool limit; the final full verify reran the entire 31-test gate suite successfully in its 1800-second invocation.
This section and refreshed generated evidence are a separate notes-only commit after the tested merge. See `flh-main-merge-2-quiet-validation.json` for the final inventories, parent/tree IDs, gate-equality proofs and hashes. Native testing remains **not run (alpha, owner's decision)**. No push, PR, GitHub write or installation was performed.
