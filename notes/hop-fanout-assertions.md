# Inherited #16 assertion migration

Base: `d9f0a71`. Candidate: `feat/hop-full-fanout`.

This lists every changed assertion-bearing line in the inherited hop-any section of `test/harness.lua`; unchanged assertions are not repeated. Minus lines are exact prior assertions, plus lines their replacements/additions, with source line numbers. Multiple assertions on one Lua line stay together. New tests are separate in `test/hop_fanout.lua`.

Changed assertion-bearing source lines: 77 removed, 77 added.

## -7253 +7260  test("hop-any 49 rows send exactly eight at one second intervals through 120 s",

```diff
- base:7253:     deliver("WHO_LIST_UPDATE"); eq(#sent,1); eq(#whoRead,49)
+ candidate:7260:     deliver("WHO_LIST_UPDATE"); eq(#sent,8); eq(#whoRead,49)
```

## -7256,3 +7263,3  test("hop-any 49 rows send exactly eight at one second intervals through 120 s",

```diff
- base:7256:     for i=2,8 do advance(.5); eq(#sent,i-1); advance(.5); eq(#sent,i); eq(sent[i].at-sent[i-1].at,1) end
- base:7257:     for _=1,120 do advance(1); deliver("WHO_LIST_UPDATE"); eq(#sent,8) end
- base:7258:     advance(1); yes(table.concat(log,"\n"):find("asked 8 players, no host answered",1,true))
+ candidate:7263:     for i=9,49 do advance(.5); eq(#sent,i-1); advance(.5); eq(#sent,i) end
+ candidate:7264:     for _=1,120 do advance(1); deliver("WHO_LIST_UPDATE"); eq(#sent,49) end
+ candidate:7265:     advance(1); yes(table.concat(log,"\n"):find("asked 49 players, no host answered",1,true))
```

## -7260 +7267  test("hop-any 49 rows send exactly eight at one second intervals through 120 s",

```diff
- base:7260:     eq(#sent,8); eq(#whoCalls,1); eq(#accepts,0)
+ candidate:7267:     eq(#sent,49); eq(#whoCalls,1); eq(#accepts,0)
```

## -7272,5 +7279,5  test("hop-any stop cancels and thirty second click guard is exact",function()

```diff
- base:7272:     deliver("WHO_LIST_UPDATE"); eq(#sent,1)
- base:7273:     SlashCmdList.LAYERENEMIES("hop stop"); advance(29); anyClick(N); eq(#whoCalls,1)
- base:7274:     advance(1); eq(clock-start,30); anyClick(N); eq(#whoCalls,2)
- base:7275:     deliver("WHO_LIST_UPDATE"); eq(#sent,2); no(sent[1].target==sent[2].target)
- base:7276:     SlashCmdList.LAYERENEMIES("hop stop"); advance(600); eq(#sent,2)
+ candidate:7279:     deliver("WHO_LIST_UPDATE"); eq(#sent,8)
+ candidate:7280:     SlashCmdList.LAYERENEMIES("hop stop"); advance(9); anyClick(N); eq(#whoCalls,1)
+ candidate:7281:     advance(1); eq(clock-start,10); anyClick(N); eq(#whoCalls,2)
+ candidate:7282:     deliver("WHO_LIST_UPDATE"); eq(#sent,16); no(sent[1].target==sent[9].target)
+ candidate:7283:     SlashCmdList.LAYERENEMIES("hop stop"); advance(600); eq(#sent,16)
```

## -7294,2 +7301,2  test("hop-any filters rows and prioritizes listed hosts then online guildmates",

```diff
- base:7294:     eq(#sent,4); eq(sent[1].target,"Host Peer"); eq(sent[2].target,"Guild Peer")
- base:7295:     eq(sent[3].target,"Ordinary Peer"); eq(sent[4].target,"Me-OtherRealm")
+ candidate:7301:     eq(#sent,5); eq(sent[1].target,"Host Peer"); eq(sent[2].target,"Ordinary Peer")
+ candidate:7302:     eq(sent[3].target,"Guild Peer"); eq(sent[4].target,"Me-OtherRealm"); eq(sent[5].target,"Other Zone")
```

## -7300,2 +7307,3  test("hop-any never reads a fiftieth who row",function()

```diff
- base:7300:     anyClick(N); deliver("WHO_LIST_UPDATE"); eq(#whoRead,49); eq(#sent,0)
- base:7301:     yes(table.concat(log,"\n"):find("nobody new to ask in this zone",1,true))
+ candidate:7307:     anyClick(N); deliver("WHO_LIST_UPDATE"); eq(#whoRead,49); eq(#sent,8)
+ candidate:7308:     for _=1,45 do advance(1) end; eq(#sent,49)
+ candidate:7309:     for _,v in ipairs(sent) do no(v.target=="Seeker "..abc(50)) end
```

## -7336 +7344  for _,kind in ipairs({"group","combat","instance","zone","guild","stop"}) do

```diff
- base:7336:         local N=anyFixture(); anyClick(N); deliver("WHO_LIST_UPDATE"); eq(#sent,1)
+ candidate:7344:         local N=anyFixture(); anyClick(N); deliver("WHO_LIST_UPDATE"); eq(#sent,8)
```

## -7343 +7351  for _,kind in ipairs({"group","combat","instance","zone","guild","stop"}) do

```diff
- base:7343:         advance(1); eq(#sent,1)
+ candidate:7351:         advance(1); eq(#sent,8)
```

## -7346 +7354  for _,kind in ipairs({"group","combat","instance","zone","guild","stop"}) do

```diff
- base:7346:         eq(#sent,1); eq(#whoCalls,1)
+ candidate:7354:         eq(#sent,8); eq(#whoCalls,1)
```

## -7353 +7361  for _,result in ipairs({3,4,"error"}) do

```diff
- base:7353:         sendResult=0; for _=1,600 do advance(1) end; eq(#sent,1)
+ candidate:7361:         sendResult=0; for _=1,600 do advance(1) end; eq(#sent,result==3 and 50 or 1)
```

## -7356,2 +7364,2  end

```diff
- base:7357:     local N=anyFixture(); sendResult=12; anyClick(N); deliver("WHO_LIST_UPDATE"); eq(#sent,1)
+ candidate:7365:     local N=anyFixture(); sendResult=12; anyClick(N); deliver("WHO_LIST_UPDATE"); eq(#sent,8)
```

## -7366,3 +7374,3  end

```diff
- base:7367:     local N=anyFixture(); anyClick(N); deliver("WHO_LIST_UPDATE"); eq(#sent,1)
+ candidate:7375:     local N=anyFixture(); anyClick(N); deliver("WHO_LIST_UPDATE"); eq(#sent,8)
```

## -7370,2 +7378,2  test("hop-any first asked host reply stops sends and unasked whole names do not"

```diff
- base:7370:     advance(1); eq(#sent,2)
- base:7371:     anyReply("Seeker a"); advance(121); eq(#sent,2)
+ candidate:7378:     advance(1); eq(#sent,9)
+ candidate:7379:     anyReply("Seeker a"); for _=1,41 do advance(1) end; advance(121); eq(#sent,49)
```

## -7380 +7388  test("hop-any wrong route addressee zone same layer and nonhost do not stop",fun

```diff
- base:7380:     advance(1); eq(#sent,2); advance(1); eq(#sent,3)
+ candidate:7388:     advance(1); eq(#sent,9); advance(1); eq(#sent,10)
```

## -7386,2 +7394,2  test("hop-any asked invite stops sends and autoaccepts once, no foreign alias",f

```diff
- base:7386:     deliver("PARTY_INVITE_REQUEST","Seeker b"); deliver("PARTY_INVITE_REQUEST","Seeker a-Elsewhere"); eq(#accepts,0)
- base:7387:     advance(1); eq(#sent,2)
+ candidate:7394:     deliver("PARTY_INVITE_REQUEST","Unasked Person"); deliver("PARTY_INVITE_REQUEST","Seeker a-Elsewhere"); eq(#accepts,0)
+ candidate:7395:     advance(1); eq(#sent,8)
```

## -7390 +7398  test("hop-any asked invite stops sends and autoaccepts once, no foreign alias",f

```diff
- base:7390:     advance(120); eq(#sent,2)
+ candidate:7398:     advance(120); eq(#sent,8)
```

## -7394 +7402  test("hop-any asked invite stops sends even with autoaccept disabled",function()

```diff
- base:7394:     deliver("PARTY_INVITE_REQUEST","Seeker a"); advance(120); eq(#sent,1); eq(#accepts,0)
+ candidate:7402:     deliver("PARTY_INVITE_REQUEST","Seeker a"); advance(120); eq(#sent,8); eq(#accepts,0)
```

## -7404 +7412  test("hop-any different known key in same zone leaves after three seconds",funct

```diff
- base:7404:     for _=1,600 do advance(1) end; eq(#sent,1); eq(#leaves,1)
+ candidate:7412:     for _=1,600 do advance(1) end; eq(#sent,8); eq(#leaves,1)
```

## -7430,5 +7438,4  test("hop-any no-answer table lasts six hours and a second round reaches differe

```diff
- base:7431:     eq(#sent,8); eq(N.Safe.count(N.Main.hopAnyState.quiet),8)
- base:7433:     eq(#sent,16); local seen={}; for _,v in ipairs(sent) do no(seen[v.target]); seen[v.target]=true end
+ candidate:7439:     eq(#sent,49); eq(N.Safe.count(N.Main.hopAnyState.quiet),49)
+ candidate:7441:     eq(#sent,49); local seen={}; for _,v in ipairs(sent) do no(seen[v.target]); seen[v.target]=true end
```

## -7436,3 +7443,3  test("hop-any no-answer table lasts six hours and a second round reaches differe

```diff
- base:7436:     anyClick(N); deliver("WHO_LIST_UPDATE"); eq(sent[#sent].target,"Seeker q")
- base:7438:     anyClick(N); deliver("WHO_LIST_UPDATE"); eq(sent[#sent].target,"Seeker a")
+ candidate:7443:     anyClick(N); deliver("WHO_LIST_UPDATE"); eq(#sent,49)
+ candidate:7445:     anyClick(N); deliver("WHO_LIST_UPDATE"); eq(sent[50].target,"Seeker a")
```

## -7458,2 +7465,2  test("hop-any UI is friendly-only with disabled reason and Stop state",function(

```diff
- base:7458:     yes(N.UI.hopAny.disabled); yes(N.UI.hopAny.reason:find("30 s",1,true))
- base:7459:     advance(30); N.Main.setConsent("guild"); N.UI.render(); yes(N.UI.hopAny.disabled)
+ candidate:7465:     yes(N.UI.hopAny.disabled); yes(N.UI.hopAny.reason:find("10 s",1,true))
+ candidate:7466:     advance(10); N.Main.setConsent("guild"); N.UI.render(); yes(N.UI.hopAny.disabled)
```

## -7476,2 +7483,2  test("hop-any one reserve per click and every attempted name shares Invite coold

```diff
- base:7477:     eq(calls,1); eq(#sent,8)
+ candidate:7484:     eq(calls,1); eq(#sent,49)
```

## -7486 +7493  test("hop-any replies and invites expire from last send, never renew their windo

```diff
- base:7486:     eq(#sent,2); no(N.Main.hopAnyState.round)
+ candidate:7493:     eq(#sent,49); no(N.Main.hopAnyState.round)
```

## -7494 +7501,2  for _,what in ipairs({"paused","budget"}) do

```diff
- base:7494:         eq(#sent,before); for _=1,600 do advance(1) end; eq(#sent,before)
+ candidate:7501:         eq(#sent,before); eq(N.Wire.queued(),0); for _=1,45 do advance(1) end; eq(#sent,before+(what=="budget" and 44 or 49))
```

## -7522 +7530  test("hop-any all replies and invite paths refuse own identity becoming unreadab

```diff
- base:7522:     eq(#accepts,0); eq(#sent,1); no(N.Main.hopAnyState.round)
+ candidate:7530:     eq(#accepts,0); eq(#sent,8); no(N.Main.hopAnyState.round)
```

## -7535 +7543  test("hop-any active round cannot be overwritten by an existing named hop",funct

```diff
- base:7535:     no(N.Main.hopHostTo(rows[1],shown)); eq(#sent,2); yes(N.Main.invite.pending.any)
+ candidate:7543:     no(N.Main.hopHostTo(rows[1],shown)); eq(#sent,16); yes(N.Main.invite.pending.any)
```

## -7544,5 +7552,5  test("hop-any pace resists duplicate pumps and a long clock jump never catches u

```diff
- base:7544:     local N=anyFixture(); anyClick(N); deliver("WHO_LIST_UPDATE"); eq(#sent,1)
- base:7545:     for _=1,3 do advance(.25); N.Main.hopAnyPump(); eq(#sent,1) end
- base:7546:     advance(.25); N.Main.hopAnyPump(); eq(#sent,2)
- base:7547:     advance(60); N.Main.hopAnyPump(); eq(#sent,3)
- base:7548:     SlashCmdList.LAYERENEMIES("hop stop"); advance(600); eq(#sent,3)
+ candidate:7552:     local N=anyFixture(); anyClick(N); deliver("WHO_LIST_UPDATE"); eq(#sent,8)
+ candidate:7553:     for _=1,3 do advance(.25); N.Main.hopAnyPump(); eq(#sent,8) end
+ candidate:7554:     advance(.25); N.Main.hopAnyPump(); eq(#sent,9)
+ candidate:7555:     advance(60); N.Main.hopAnyPump(); eq(#sent,17)
+ candidate:7556:     SlashCmdList.LAYERENEMIES("hop stop"); advance(600); eq(#sent,17)
```

## -7565 +7573  test("hop-any not-hosting answer removes a remembered host without a per-reply l

```diff
- base:7565:     advance(1); eq(#sent,2)
+ candidate:7573:     advance(1); eq(#sent,9)
```

## -7568 +7576  test("hop-any instance entry event cancels even if it ends before the next pump"

```diff
- base:7568:     local N=anyFixture(); anyClick(N); deliver("WHO_LIST_UPDATE"); eq(#sent,1)
+ candidate:7576:     local N=anyFixture(); anyClick(N); deliver("WHO_LIST_UPDATE"); eq(#sent,8)
```

## -7570 +7578  test("hop-any instance entry event cancels even if it ends before the next pump"

```diff
- base:7570:     advance(1); eq(#sent,1); no(N.Main.hopAnyState.round)
+ candidate:7578:     advance(1); eq(#sent,8); no(N.Main.hopAnyState.round)
```

## -7591 +7599  test("hop-any observed invite is never reported as no invite after auto-off",fun

```diff
- base:7591:     eq(#sent,1); eq(#accepts,0)
+ candidate:7599:     eq(#sent,8); eq(#accepts,0)
```

## -7603 +7611  test("hop-any offline selection fills all eight slots with online candidates",fu

```diff
- base:7603:     eq(N.Main.hopAnyState.round.count,8)
+ candidate:7611:     eq(N.Main.hopAnyState.round.count,8) -- the first round only
```

## -7612 +7620  test("hop-any rejects nonwhisper replies before changing round or host state",fu

```diff
- base:7612:         advance(1); eq(#sent,2,route)
+ candidate:7620:         advance(1); eq(#sent,9,route)
```

## -7622 +7630  test("hop-any painted Stop cancels a sending round before the next whisper",func

```diff
- base:7622:     anyClick(N,true); deliver("WHO_LIST_UPDATE"); eq(#sent,1)
+ candidate:7630:     anyClick(N,true); deliver("WHO_LIST_UPDATE"); eq(#sent,8)
```

## -7626 +7634  test("hop-any painted Stop cancels a sending round before the next whisper",func

```diff
- base:7626:     eq(#sent,1); eq(#whoCalls,1)
+ candidate:7634:     eq(#sent,8); eq(#whoCalls,1)
```

## -7631 +7639  test("hop-any live group guard stops before the roster event",function()

```diff
- base:7631:     eq(#sent,1); no(N.Main.hopAnyState.round)
+ candidate:7639:     eq(#sent,8); no(N.Main.hopAnyState.round)
```

## -7633 +7641  test("hop-any live group guard stops before the roster event",function()

```diff
- base:7633:     eq(#sent,1); eq(#whoCalls,1)
+ candidate:7641:     eq(#sent,8); eq(#whoCalls,1)
```

## -7638,2 +7646,2  test("hop-any stale painted Stop after expiry never starts another round",functi

```diff
- base:7639:     eq(#sent,8); advance(119.5); eq(N.UI.hopAny.label:GetText(),"Stop")
+ candidate:7647:     eq(#sent,49); advance(78.5); eq(N.UI.hopAny.label:GetText(),"Stop")
```

## -7643 +7651  test("hop-any stale painted Stop after expiry never starts another round",functi

```diff
- base:7643:     eq(#sent,8); no(N.Main.hopAnyState.round)
+ candidate:7651:     eq(#sent,49); no(N.Main.hopAnyState.round)
```

## -7648,2 +7656,2  test("hop-any expiry requests a next-frame repaint before the age tick",function

```diff
- base:7649:     advance(119.5); eq(N.UI.hopAny.label:GetText(),"Stop")
+ candidate:7657:     advance(78.5); eq(N.UI.hopAny.label:GetText(),"Stop")
```

## -7668,2 +7676  test("hop-any reserves the final attempt before a reentrant send edge",function(

```diff
- base:7669:     for _=1,6 do advance(1) end; eq(#sent,7)
```

## -7680 +7687  test("hop-any reserves the final attempt before a reentrant send edge",function(

```diff
- base:7680:     advance(2); eq(#sent,8,"no ninth request at the reentrant edge")
+ candidate:7687:     deliver("WHO_LIST_UPDATE"); eq(#sent,8,"no ninth request in the first round")
```

## -7683,2 +7690,3  test("hop-any reserves the final attempt before a reentrant send edge",function(

```diff
- base:7683:     for i=2,#sent do yes(sent[i].at-sent[i-1].at>=1) end
- base:7684:     advance(600); eq(#sent,8); eq(#whoCalls,1)
+ candidate:7690:     for _=1,41 do advance(1) end; eq(#sent,49)
+ candidate:7691:     local batches={}; for _,v in ipairs(sent) do batches[v.at]=(batches[v.at] or 0)+1; yes(batches[v.at]<=8) end
+ candidate:7692:     advance(121); eq(#sent,49); eq(#whoCalls,1)
```

## -7701 +7709  test("hop-any cannot dispatch again while a send is still in flight",function()

```diff
+ candidate:7709:         if not fired then fired=true; clock=clock+2; N.Main.hopAnyPump(); eq(#sent,1) end
```

## -7704,2 +7712,2  test("hop-any cannot dispatch again while a send is still in flight",function()

```diff
- base:7704:     deliver("WHO_LIST_UPDATE"); eq(#sent,1); eq(N.Main.hopAnyState.round.count,1)
- base:7705:     advance(1); eq(#sent,2); no(N.Main.error)
+ candidate:7712:     deliver("WHO_LIST_UPDATE"); eq(#sent,8); eq(N.Main.hopAnyState.round.count,8)
+ candidate:7713:     advance(1); eq(#sent,10); no(N.Main.error)
```

## -7723,12 +7731,10  test("hop-any rechecks ignore at dispatch and never trusts a skipped candidate",

```diff
- base:7723:     local N=anyFixture(); anyClick(N); deliver("WHO_LIST_UPDATE"); eq(#sent,1)
- base:7725:     advance(1); eq(#sent,1,"newly ignored candidate must not reach Wire")
- base:7726:     eq(N.Main.hopAnyState.round.count,2)
- base:7727:     no(N.Main.hopAnyState.round.asked["seeker b"]); no(N.Main.invite.asked["seeker b"])
- base:7728:     deliver("PARTY_INVITE_REQUEST","Seeker b"); eq(#accepts,0)
- base:7730:     eq(#sent,7); eq(N.Main.hopAnyState.round.count,8)
- base:7731:     for _,row in ipairs(sent) do no(row.target=="Seeker b") end
- base:7732:     for i=2,#sent do yes(sent[i].at-sent[i-1].at>=1) end
- base:7733:     SlashCmdList.LAYERENEMIES("hop stop"); no(N.Main.hopAnyState.quiet["seeker b"])
- base:7734:     advance(600); eq(#sent,7); no(N.Main.error)
+ candidate:7731:     local N=anyFixture(); anyClick(N); deliver("WHO_LIST_UPDATE"); eq(#sent,8)
+ candidate:7733:     advance(1); eq(#sent,9); eq(sent[9].target,"Seeker j")
+ candidate:7734:     no(N.Main.hopAnyState.round.asked["seeker i"]); no(N.Main.invite.asked["seeker i"])
+ candidate:7736:     eq(#sent,48)
+ candidate:7737:     for _,row in ipairs(sent) do no(row.target=="Seeker i") end
+ candidate:7738:     deliver("PARTY_INVITE_REQUEST","Seeker i"); eq(#accepts,0)
+ candidate:7739:     SlashCmdList.LAYERENEMIES("hop stop"); no(N.Main.hopAnyState.quiet["seeker i"])
+ candidate:7740:     advance(600); eq(#sent,48); no(N.Main.error)
```

## -7745,4 +7751,4  test("hop-any unreadable ignore policy at dispatch fails closed without cooldown

```diff
- base:7745:         eq(#sent,1,mode); eq(N.Main.hopAnyState.round.count,8,mode)
- base:7746:         eq(N.Safe.count(N.Main.hopAnyState.round.asked),1,mode)
- base:7747:         eq(N.Safe.count(N.Main.invite.asked),1,mode)
- base:7748:         advance(121); eq(#sent,1,mode); no(N.Main.error)
+ candidate:7751:         eq(#sent,8,mode); eq(N.Main.hopAnyState.round.count,49,mode)
+ candidate:7752:         eq(N.Safe.count(N.Main.hopAnyState.round.asked),8,mode)
+ candidate:7753:         eq(N.Safe.count(N.Main.invite.asked),8,mode)
+ candidate:7754:         advance(121); eq(#sent,8,mode); no(N.Main.error)
```
