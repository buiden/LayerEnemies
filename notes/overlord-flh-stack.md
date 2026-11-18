# Overlord peer and feed stacked on FLH membership (#36)

Local merges only; nothing pushed. Two levels:

- stack/12-overlord-peer = fix/c2 `a67d4afd` + FLH membership `6416fd37` (both contain main `44e41e8d`).
- stack/13-overlord-feed = fix/c3 `fa6c96d0` + stack/12.

"Mechanical merge" below means the tree `git merge-tree --write-tree` produces
(conflict markers included), or git's AUTO_MERGE tree for level 13.

## Level 12: `0f25fe7` (merge) + `eedb9c1` (anchor fix)

Mechanical tree: `dd4f82d1`. The merge commit `0f25fe7` was made by an earlier
builder and was audited here line by line against that tree before use.

### Conflict hunks

1. `LayerEnemies/Directory.lua`, D.sync membership gate. fix/c2 adds the Overlord
   gate (sharing and a known pool); 6416fd37 adds the FLH gate (sharing and
   joined-or-allowed, with its comment). Resolution: both lines, Overlord first.
2. `LayerEnemies/Directory.lua`, limited-slot channels. fix/c2:
   `wanted or overlord`; 6416fd37: `wanted or flh`. Resolution:
   `local limited=key=="wanted" or key=="overlord" or key=="flh"`, so both
   networks keep the two-free-slots rule.
3. `LayerEnemies/Wire.lua`, check(). fix/c2: the OverlordF private-flight and
   live-context gate; 6416fd37: the FLHNET2 authorize gate that returns early.
   Resolution: both blocks, each closed by its own `end`, Overlord first. FLHNET2
   still returns before the generic net checks; OverlordF still falls through to
   them as on fix/c2.
4. `test/harness.lua`: mock ROUTES table. Resolution: union (FLHNET2 and OverlordF).
5. `test/bnet_queue_fixture.lua`, F.mixed and F.fill. Resolution: FLH's
   `F.mixed(N,total)` and pool-ledger fill, with fix/c2's real shipped Overlord
   registration `OverlordF` in place of the old `OLQueue`.
6. Generated notes (`notes/overlord-mutants.json`, `notes/test-results.txt`,
   `notes/verification.json`): regenerated, not hand-merged.

### Production lines that differ from the mechanical merge

Only these, all inside the conflict hunks above:

- Directory.lua: hunk 1 (markers removed, both lines kept) and hunk 2 (the
  combined line).
- Wire.lua: hunk 3 (markers removed; one `end` added between the two blocks).
- test/verify.py (not conflicted; needed because both sides freeze Wire's
  route table exactly): `check_route_policy` also allows
  `OverlordF: GUILD/PARTY/RAID/WHISPER`, its check function text, and
  net `overlord`. The generated `sends` summary gains the Overlord peer sentence.

Unchanged and checked: FLHNET2 route, flhText, the shared 8-burst and
40-per-minute ceilings with `flhReserve` (non-zero only during an armed FLH
click; LR is exempt from it in flhBudget), the exact `ROUTES[prefix]` lookup
gate, the addon-wide debug ban, Overlord's sends, BNet shares and guard,
silence when the real Overlord is loaded, and #34's hook/pcall rules
(Main.lua and Wire.lua hooks unchanged from both parents outside the hunks).

### Test-only additions

- `test/src_overlord_flh_stack.lua` (new, earlier builder): real Overlord replies against
  FLH click flights: unarmed eight-token burst both orders; armed LR reserve
  blocks a peer reply without charging it; a cancelled click returns the token;
  a peer reply cannot take the last rolling-minute LR slot.
- `test/api_policy_test.py`: `test_composed_overlord_route_is_frozen_with_flh`.
- `eedb9c1` re-points two FLH mutant anchors made stale by the composition
  (no mutant removed, counts unchanged):
  - `flh_mutants.py` channel-presence: the FLH kind list now also occurs
    in Overlord's receive gate (`... and kind~="BNET"`, from fix/c2). The anchor
    adds FLH's next line (`then return end\n    if not M.heard`) so it hits only
    `M.flhIn`. Production unchanged; no duplicated block.
  - `flh_member_mutants.py` directory-slots: anchor moved to the combined
    limited-slot line; the mutant still drops only `flh` from it.

## Level 13: `996babb` (merge)

AUTO_MERGE tree: `f5be2caa`.

### Conflict hunks

1. `LayerEnemies/Main.lua` M.setShare. fix/c3:
   `N.BNet.cancel(nil,nil,true); M.overlordCancel()`; stack/12:
   `N.BNet.cancel(); N.FLHMember.stop("share off")`. Resolution:
   `N.OwnDeath.cancel(); N.BNet.cancel(nil,nil,true); M.overlordCancel(); if N.WarBoardTrack then N.WarBoardTrack.stop() end; N.FLHMember.stop("share off")`.
   This keeps C3's owed Overlord stops through the cancel and FLH's stop; the FLH
   stop goes last so every existing mutant anchor stays unique.
2. `LayerEnemies/Net.lua` setConsent. Resolution: C3's two lines (keep-stops
   cancel, overlordCancel) plus FLH's guild-only stop line.
3. `LayerEnemies/Net.lua` setSwitch. Resolution: C3's overlord-cancel line, FLH's
   network-off stop line, and FLH's session-aware save
   (`if not Net.LIST[key].session then save() end`).
4. `test/verify.py` sends summary: FLH's sentence followed by C3's feed sentence.
5. `test/warboard_track_mutants.py`: C3's two anchors, which still match the
   composed lines exactly once.
6. Generated notes: C3 side in the merge, regenerated in the notes commit.

### Production lines that differ from AUTO_MERGE

Only the resolved hunks 1-3 above (and the verify.py summary string, hunk 4).
No other production line differs.

## Gates, level 12

Run on clean clones, Lua 5.1.5, outer limit 1800 s (3600 s for reruns), inner pack limits unchanged.

- Full verify on `0f25fe7`: RESULT: 1988 tests passed, 0 failed, 605181 assertions; rc 0.
  `eedb9c1` changes only two mutant-pack files, which verify neither runs nor archives, so
  that run's regenerated `test-results.txt` and `verification.json` are byte-identical to the ones
  already committed in `0f25fe7`, so they are unchanged here.
- Mutant packs on `0f25fe7` (s12 run):
  - mut-chehulnet: rc 0, 129 s. RESULT: 57/57 ChehulNet mutants killed
  - mut-codec: rc 0, 95 s. 
  - mut-crowd: rc 0, 25 s. Killed 12/12 behavioral mutants; all source bytes restored.
  - mut-find20: rc 0, 8 s. MUTANTS: 11/11 killed; original source bytes restored
  - mut-flh: rc 1, 35 s. 
  - mut-flh_batch: rc 0, 65 s. 
  - mut-flh_member: rc 1, 477 s. 
  - mut-flh_rulings: rc 0, 388 s. 
  - mut-guild_intel: rc 0, 313 s. RESULT: 101 tests passed, 0 failed, 9884 assertions
  - mut-hop_fanout: rc 0, 1269 s. MUTANTS: 63/63 caught
  - mut-kill: rc 0, 166 s. RESULT: 55 tests passed, 0 failed, 4818 assertions
  - mut-overlord-shard1: rc 0, 201 s. RESULT: 9/9 mutants killed
  - mut-overlord-shard2: rc 0, 180 s. RESULT: 9/9 mutants killed
  - mut-overlord-shard3: rc 0, 184 s. RESULT: 9/9 mutants killed
  - mut-overlord-shard4: rc 0, 170 s. RESULT: 9/9 mutants killed
  - mut-overlord-shard5: rc 0, 155 s. RESULT: 9/9 mutants killed
  - mut-overlord-shard6: rc 0, 152 s. RESULT: 9/9 mutants killed
  - mut-overlord_peer: rc 0, 596 s. RESULT: 57/57 mutants killed
  - mut-presence: rc 0, 394 s. RESULT: 41/41 mutants killed; baseline/final green
  - mut-quiet: rc 0, 263 s. MUTANTS: 38/38 caught
  - mut-quiet_all: rc 0, 139 s. MUTANTS: 43/43 caught
  - mut-relay_policy: rc 0, 16 s. RESULT: 4/4 mutants killed; 24 policy tests passed, 0 failed
  - mut-source: rc 0, 61 s. RESULT: 41/41 source mutants killed
  - mut-spy: rc 0, 14 s. RESULT: 22 tests passed, 0 failed, 1852 assertions
  - mut-wanted: rc TIMEOUT, 1800 s. 
  - mut-warboard: rc 0, 153 s. RESULT: 115/115 WarBoard mutants killed
  - mut-warboard_track: rc 0, 47 s. RESULT: 113/113 WarBoard tracking mutants killed
  - mut-watch: rc 0, 113 s. Killed 19/19 behavioral mutants; all source bytes restored.
- Reruns on `eedb9c1` (one job at a time, no other runs of mine):
  - mut-flh: rc 0, RESULT: 29 tests passed, 0 failed (the channel-presence anchor fix).
  - mut-flh_member: rc 0, 1455 s, RESULT: 91 tests passed, 0 failed (the directory-slots anchor fix).
  - mut-wanted: rc 0, 1293 s (it hit the 1800 s limit under load 12-25 on the first run).
- The first-run failures of mut-flh and mut-flh_member were the two stale anchors above;
  mut-wanted was a timeout only.

## Gates, level 13 (`996babb`)

- Full verify (run by hermes alone in a separate clone): RESULT: 2154 passed, 0 failed, 38 min.
  The regenerated `test-results.txt` and `verification.json` in this commit are copied from that run.
- mut-flh_member: rc 0, 734 s, RESULT: 91 tests passed, 0 failed.
- First parallel run (load 12-25), rc 0: codec, crowd, find20, chehulnet, flh_batch, flh, guild_intel, kill.
  flh_rulings and the six Overlord receiver shards hit their inner 180 s limits; no assertion failed.
- The remaining packs are rerunning one at a time on clones of `996babb`; results go to the PR as a comment.
- README (Overlord kill feed section): two sentences on the single Battle.net frame at logout and on
  removed friends without the friend-list event, as hermes asked. No file under LayerEnemies/ or test/
  differs from `996babb`.
