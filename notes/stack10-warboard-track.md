# Stack 10: WarBoard tracking request

## Checkpoints and scope

- Feature: `feat/warboard-track` at `e477e99541a9ed7a01a0a4400baf879c44145b78`.
- Stack base / open PR #33 head: `stack/9-warboard` at `4ee3fbb9b1a9d00b87bc4512b06dc347b39bf606`, including main `2675e03d9363d4299a02d6d60815e0d65298967c`.
- Two-parent integration merge: `4e63e4c491ba61088064ce6625954e126c03292a`, first parent stack/9, second parent the feature head above. This report and regenerated evidence are in a subsequent notes-only commit; use that commit as the final stack/10 head.
- Local commits only. No push, GitHub write, installation or donor execution. Native checks not run (alpha, owner's decision). Author self-review; independent parent review is separate.
- Evidence: `/opt/data/cache/scratch/le-e2-delta-evidence` and `/opt/data/cache/scratch/le-stack10-evidence`. The latter freezes the original merge output, conflict list, conflict-marked production tree, complete resolution patch, lower refs and assertion inventories.

## Feature delta: tests first

The new regressions ran against detached exact base `66e82aea4945b8d789f2f862de46e220321829b6`, with only their test file copied over. See `notes/warboard-track-delta.md`.

| Fix | Production commit | Base RED | Final GREEN |
| --- | --- | --- | --- |
| Queued first fragment remains cleanup-only after a live final fragment | `4fb476ba4c5be29fa8f554fbfcbcd038dc0dcf47` | 2 failed | combat + instance pass |
| Partial assembly cannot cross resolved character/realm identity | `bece50778786c94737bddd7ed9819e196d5fcccf` | 2 failed | character + realm pass, before decode |
| Stale deferred roster preserves accepted withdrawal; genuine partial loss remains uncertain | `dfa7ba674405cdcc5f2d621be3c5d21745fe65a2` | complete delta pack: 7 failed, 0 passed | 7 passed, 0 failed, 355 assertions |

All seven delta cases also pass unchanged in the composition. Four new assertion-killed tracking mutants cover the three defects and eventless incomplete-assembly expiry. A validated stale roster neither adds an FBUN nor restarts the original silence deadline.

## Every merge conflict and its resolution

The mechanical merge reported exactly these 12 conflicted files:

| File | Resolution |
| --- | --- |
| `LayerEnemies/BNet.lua` | Three hunks combine stack/9 admission timestamps, age expiry and dynamic source shares with E2 tagged completion/cleanup metadata. Unsafe FBUN stays held; once safe, an entry older than 60 seconds expires as unsent and its retained debt may enqueue a fresh FBUN. Both priorities still obey per-source caps, 52 normal / 60 total slots, shared 30/minute and one-second pace. |
| `LayerEnemies/LayerEnemies.toc` | Keep both modules: `WarBoard.lua`, `WarBoardTrack.lua`, `ChehulNet.lua`, then UI/Main. No other load-order change. |
| `LayerEnemies/Main.lua` | Combine E2 instance-triggered tracking stop with stack/9's `hopAnySafe`, not the older unconditional hop stop. Preserve `OwnDeath.seed(...)` and the existing boundary/poll handling. |
| `LayerEnemies/WarBoard.lua` | Keep stack/9's counted donor-loaded admission refusal. Use E2's handshake permission/proof/completion closure and its donor-loaded final predicate. Charge the H admission cooldown only when `queued` is true; preserve cleanup permission release and pending A bookkeeping. The independently merged hello rotation/unreadable skip is unchanged. |
| `README.md` | Keep Wanted/Chehul and newer transport/codec disclosures; add the complete tracking-first send table and privacy/debt disclosures. Replace the obsolete future-tracking claim with a handshake-scoped statement. Explain shared caps, safe-time expiry of held cleanup, per-login six-attempt bound, and absolute LE H/A silence with real WarBoard loaded. |
| `THIRD_PARTY.md` | Retain stack/9's donor provenance sections and label the WarBoard protocol section E1/E2. |
| `test/src_warboard.lua` | Keep stack/9's queued H/A donor-load test instead of the feature's weaker stand-down case. Add a forwarding capture of the real source final predicates so E2's redundant BNet guard cannot conceal loss of the source guard. |
| `test/src_warboard_review.lua` | Keep the disclosure checks, update only the expected tracking-table/four-command wording and the now-current handshake-scoped statement. |
| `test/warboard_mutants.py` | Retain both rule sets; adapt final-source predicate, `queued` variable and README anchors to composed code. Use E2's portable diagnostic normalization/write-if-changed runner. Preserve stack/9's rotation, unreadable skip, donor silence, transport, source/presence report rules. |
| `notes/test-results.txt` | Do not splice outputs: regenerate from full composed verification. |
| `notes/verification.json` | Do not splice metadata: regenerate from full composed verification and archive. |
| `notes/warboard-mutants.json` | Do not splice mutation evidence: regenerate all composed protocol mutants. |

### Additional test adaptation, no production workaround

The first composed WarBoard run was `278 tests passed, 1 failed`: the old tracking delay fixture tried to queue thirty frames on one newly registered source. That violates stack/9's intentional per-source cap. The final fixture fills the same thirty-frame/global-minute budget using 26 alphabetic one-frame registered sources plus Wanted's four-slot share, explicitly enabling Wanted only in the isolated harness. It retains every original six-request sliding-window assertion, timing and queue expectation. No live cap, registry bound or timeout was relaxed. Invalid trial fixture names and the harness's disabled-network default were corrected before the successful run.

Tracking mutant anchors were updated only where stack/9 returns `refuse()` rather than `false`. The protocol donor-load mutant still removes only the final source guard and is killed by the strengthened real-predicate test. E2's combined transport/source donor guards remain separately mutation-tested.

## Preserved semantics and inventory

- With the real WarBoard loaded: zero LE H/A at admission and dispatch, including debt-settlement exceptions and already queued work. Receiving continues; debt recovery observes the donor's H/A exchanges, and only owed FBUN can pass its narrow cleanup gate.
- Stack/9's stable hello ring, refusal-not-cooldown rule, unreadable-account selection/cursor rule, and 45-account reach probes all pass. E2's pending-proof, per-login exhaustion, deferred inbox and seven new delta cases all pass.
- `Codec.lua` is byte-identical to stack/9, including 4097 logical values and the 15-second-idle / 120-second-total AceComm limits. `Sources.lua` retains stack/9 status support and enemy-position wording; its only feature changes are debt-aware receive/tick/unsafe-stop handling. FBLP own-versus-reported wording remains intact.
- Lower stack refs 1–9 exactly match the frozen pre-merge refs. Both feature and main are ancestors of stack/10.
- Test identity inventory: stack/9 1598, feature 1544, raw union 1748; final 1745. Exactly three superseded aliases are reconciled, with no unexplained omissions or new identities:
  1. Stack/9's absolute `no FBAK or request answer or forwarding for any application type` is replaced by E2's `no unsolicited application response or forwarding; FBAK requires verified Find target`.
  2. Feature's old Codec `sender isolation, restart, orphan and exact TTL` is covered by stack/9's `sender isolation, restart, orphan and clock rollback` plus its explicit idle/total-expiry regressions.
  3. Feature's `stand down blocks both own hellos and owed answers` is covered by stack/9's stronger `stand down cancels queued H and A when the real addon loads` and thirty-minute loaded/absent controls.
- Protocol mutant inventory: stack/9 113, feature 100, raw union 116. The same grammar mutation was renamed from `no FBAK send` to `handshake grammar cannot masquerade as FBAK`; final union is 115. All 113 feature tracking rules are retained. See `stack10-composition-audit.json` for the exact inventory and frozen refs.

## Verification on the composed production/test tree

Commands use Lua 5.1.5 at `/opt/data/tools/lua/lua-5.1.5/src/lua`, `LAYERENEMIES_LUA` set to that path and `TMPDIR=/opt/data/cache/scratch`.

- `lua test/harness.lua --only WarBoard`: `RESULT: 279 tests passed, 0 failed, 178135 assertions`.
- `lua test/harness.lua --only 'WarBoard rulings: delta'`: `RESULT: 7 tests passed, 0 failed, 355 assertions` on both heads.
- `python3 test/warboard_mutants.py`: `RESULT: 115/115 WarBoard mutants killed`, exit 0, 116.30 seconds.
- `python3 test/warboard_track_mutants.py`: `RESULT: 113/113 WarBoard tracking mutants killed`, exit 0, 27.83 seconds.
- `python3 test/verify.py`: `RESULT: 1745 tests passed, 0 failed, 436036 assertions`, exit 0, 453.60 seconds. Lua syntax, static/API/security/TOC/media checks, Python tests, archive integrity and source parity pass.
- Feature full verify: `RESULT: 1544 tests passed, 0 failed, 220706 assertions`, exit 0; feature protocol/tracking mutants 100/100 and 113/113.
- All long commands were started as foreground `subprocess.run(..., timeout=1800)`, one per tool call, never with `&`. The full-verify tool response timed out at its outer 420-second limit; the original foreground subprocess remained live, completed normally, and wrote its exit-0 `verify-run.json` at 453.60 seconds. It was not restarted or replaced with synthesized output.
- Composed archive SHA256: `cacb3a5d2b11eef2bd434b233a66b0e5f6691a5c25b060a0cebb2ebdf2e7cf7b`.
- Protocol report SHA256: `611955408022516371ea7ca3319690ec14cf8eab0b886258ba46ab9cf25282aa`.
- Tracking report SHA256: `cd705be6feecb34fd2ce5ee6f481fa29375d427b1347c5a999f70de9eea6989e`.

## Every production line differing from the mechanical merge

The baseline here is the actual conflict-marked working tree produced by `git merge --no-ff --no-commit source/warboard-track`, captured before any resolution. The following is the complete byte-comparison-derived production diff. Only `BNet.lua`, the TOC, `Main.lua` and `WarBoard.lua` differ; every other automatically merged production file is byte-identical to that snapshot. There are no post-resolution production edits. This records both alternative removal and newly combined lines rather than calling either side a clean mechanical result.

```diff
--- mechanical/LayerEnemies/BNet.lua
+++ resolved/LayerEnemies/BNet.lua
@@ -93,14 +93,9 @@
     -- Expiry, privacy and safety are rechecked even while a budget is exhausted.
     for i=#queue,1,-1 do
         local q=queue[i]
-<<<<<<< HEAD
-        if now-q.at>60 or not BN.allowed(q.net,q.id,q.prefix,q.text,q.prio) or not BN.who(q.id) then
-            refuse(q.net); table.remove(queue,i)
-=======
         if not (q.cleanup and not safe()) and
-            (not BN.allowed(q.net,q.id,q.prefix,q.text,q.prio) or not BN.who(q.id)) then
+            (now-q.at>60 or not BN.allowed(q.net,q.id,q.prefix,q.text,q.prio) or not BN.who(q.id)) then
             refuse(q.net); table.remove(queue,i); complete(q,false)
->>>>>>> source/warboard-track
         end
     end
     local keep={}
@@ -115,11 +110,7 @@
         for i,q in ipairs(queue) do
             local count=0
             for _,stamp in ipairs(times) do if stamp.net==q.net then count=count+1 end end
-<<<<<<< HEAD
-            if count<share(q.net) then
-=======
-            if count<(shares[q.net] or 30) and not (q.cleanup and not safe()) then
->>>>>>> source/warboard-track
+            if count<share(q.net) and not (q.cleanup and not safe()) then
                 table.remove(queue,i)
                 -- Optional source-owned final admission: checked exactly once at
                 -- dispatch, not while waiting on another network's budget.
@@ -165,12 +156,8 @@
     local now=S.num(S.call(GetTime))
     if not now or count>=share(net) or (prio~="owed" and normal>=52) or not schedule() then return refuse(net) end
     serial=serial+1
-<<<<<<< HEAD
-    queue[#queue+1]={net=net,id=id,prefix=prefix,text=text,prio=prio,seq=serial,at=now,still=still}
-=======
-    queue[#queue+1]={net=net,id=id,prefix=prefix,text=text,prio=prio,seq=serial,still=still,tag=tag,done=done,
+    queue[#queue+1]={net=net,id=id,prefix=prefix,text=text,prio=prio,seq=serial,at=now,still=still,tag=tag,done=done,
         cleanup=withdrawal(net,id,prefix,text,prio)==true}
->>>>>>> source/warboard-track
     return true
 end
 function BN.cancel(net,tag)
--- mechanical/LayerEnemies/LayerEnemies.toc
+++ resolved/LayerEnemies/LayerEnemies.toc
@@ -47,10 +47,7 @@
 CallUI.lua
 Wanted.lua
 WarBoard.lua
-<<<<<<< HEAD
+WarBoardTrack.lua
 ChehulNet.lua
-=======
-WarBoardTrack.lua
->>>>>>> source/warboard-track
 UI.lua
 Main.lua
--- mechanical/LayerEnemies/Main.lua
+++ resolved/LayerEnemies/Main.lua
@@ -2484,12 +2484,8 @@
     elseif event=="CHAT_MSG_SYSTEM" then guarded(M.whisperSystem,(...))
     elseif event=="PLAYER_ENTERING_WORLD" or event=="SHARD_TRANSFER" then
         if event=="PLAYER_ENTERING_WORLD" then N.OwnDeath.seed(...) end
-<<<<<<< HEAD
+        if N.WarBoardTrack and A.inInstance()~=false then N.WarBoardTrack.stop() end
         guarded(M.hopAnySafe); guarded(M.boundary,A.location()); M.queuePoll()
-=======
-        if N.WarBoardTrack and A.inInstance()~=false then N.WarBoardTrack.stop() end
-        guarded(M.hopAnyStop,"world changed"); guarded(M.boundary,A.location()); M.queuePoll()
->>>>>>> source/warboard-track
     elseif event=="ZONE_CHANGED_NEW_AREA" or event=="ZONE_CHANGED" then
         if A.location()~=M.store.zone then guarded(M.boundary,A.location(),true) end
         M.queuePoll()
--- mechanical/LayerEnemies/WarBoard.lua
+++ resolved/LayerEnemies/WarBoard.lua
@@ -78,11 +78,7 @@
 -- WarBoard's identity or gameplay implementation. LE has no gameplay rules: 0.
 local function send(st,id,cmd,ctx)
     if cmd~="H" and cmd~="A" then return refuse() end
-<<<<<<< HEAD
     if N.Adapters.loaded("WarBoard") then return refuse() end
-=======
-    if N.Adapters.loaded("WarBoard") then return false end
->>>>>>> source/warboard-track
     if not ctx.version then return refuse() end
     local text="WBF1|"..cmd.."|5|"..ctx.rs.."|LayerEnemies/"..ctx.version.."|0"
     local prio=cmd=="A" and "owed" or "own"
@@ -111,15 +107,10 @@
         st.answers[#st.answers+1]=ctx.now
     end
     local rs,faction=ctx.rs,ctx.faction
-<<<<<<< HEAD
-    local accepted=BN.send("warboard",id,"WarBoard",text,prio,function(now)
-        if N.Adapters.loaded("WarBoard") then return false end
-=======
     local peer=st.peers[id]; local hello=peer and peer.hello
     local sentAt
     permit(true)
     local queued=BN.send("warboard",id,"WarBoard",text,prio,function(now)
->>>>>>> source/warboard-track
         local live=context()
         if not live or live.rs~=rs or live.faction~=faction or not identity(id,live) or now<ctx.now or now-ctx.now>=120
             or N.Adapters.loaded("WarBoard") then return false end
@@ -148,14 +139,10 @@
             end
         end
     end)
-<<<<<<< HEAD
-    if accepted and cmd=="H" then st.hellos[id]={at=ctx.now} end
-    return accepted
-=======
+    if queued and cmd=="H" then st.hellos[id]={at=ctx.now} end
     if not queued then permit(false)
     elseif cmd=="A" and peer then peer.answerPending=true end
     return queued
->>>>>>> source/warboard-track
 end
 local Cd=N.Codec
 local function integer(v,lo,hi)
```
