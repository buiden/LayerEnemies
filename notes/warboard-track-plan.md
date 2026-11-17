# PR E2 — WarBoard tracking request implementation plan

Authority: owner builder brief (overrides PLAN.md D1/8.2's old no-FBAK decision); audit-warboard.md §§4,5.1,6,8.3. Base 65904e6674af82c72f89f7c7f762510f19e8e058. Local clone only; no push.

## Decisions and interfaces
- Protocol-only Lua 5.1. Keep E1 decoder/fuzz and H/A budgets; add WarBoardTrack.lua, driven before W.tick's 60-second discovery gate.
- Direct target only: compatible handshaken peer, matching own Find entry, live client-resolved GUID/name/faction. No guessed GUID, no relay fan-out, no Watch-only target. Refuse ambiguous multiple accounts for one tracked name. At most 20 live/closing records total.
- FBAK: WBF1|D| + addonEncode(deflateStored(aceWrite({t='FBAK',v=5,rs=own ruleset,av='LayerEnemies/'..own version,senderName=own character,d={targetGuid,targetName,hunterGuid,hunterName,hunterFaction,faction,sentAt}}))). FBUN same except no targetName. Send only through BN.send on WarBoard.
- Own cap: 2 FBAK/rolling 60 seconds and one/name/45 seconds at admission AND actual attempt; no six-second five-attempt retry burst. FBUN at most 2/rolling 60 seconds. All four application slots share E1's 10/minute WarBoard and shared 30/minute/1-per-second queue; A remains owed priority, application frames own priority. Counters/cooldowns survive toggles/removal.
- Renew only if a direct accepted FBLP is stale 45..300 seconds, or no direct location exists and current target client presence is verified. Fresh FBLP does not renew; donor subscribers do not expire.
- Stop hooks: Find removal, share off, guild-only, source off, combat/instance events, logout, track off; drop tagged queued requests synchronously. Recheck all eligibility at dispatch. Preserve session cleanup records for already-attempted requests and send FBUN when the existing public/shared/outdoor/noncombat/confirmed-identity gates allow. Logout drops queue/state: no bypass/flush/retry or saved names. Cancellation delivery cannot be guaranteed; disclose donor's persistent subscription.
- Ruling: privacy/safety rules forbid FBUN while share/source/public is off, in combat/instance, or after logout. Do not bypass those rules to promise impossible instant remote cancellation. Try cleanup under permitted conditions; keep it session-only and bounded. Cost: target may keep broadcasting after failed/blocked cancellation, including logout.
- Ruling: resolve GUID from live Battle.net identity only, not unverified application claims or cached Find rows. Cost: a target with an unavailable GUID cannot be requested even if a wire record mentions one.
- Saved boolean warboardTrack (default true, false opts out) follows existing configuration sanitation. No new saved names/identities; existing Find configuration stays unchanged. /le warboard track on|off and /le net warboard status.

## Execution checklist
- [ ] Tracer 1: exact request and live identity tests RED on base; encode and queue GREEN.
- [ ] Tracer 2: renewal/caps/ambiguity/Watch/stop/switch/cleanup tests RED; guards and hooks GREEN.
- [ ] Migrate only obsolete no-FBAK grammar/documentation assertions, enumerate every edit; fuzz bytes unchanged.
- [ ] Add portable rule mutants; syntax-valid assertion kills only; byte-stable report.
- [ ] README send table first, exact consequence sentence; protocol provenance and stop limitations.
- [ ] Frozen-base RED run, full verify (foreground), mutation rerun stability, review diff; local implementation commit followed by regenerated-notes commit.

Native checks: not run (alpha, owner's decision). No donor code executed or copied. Self-review in this builder lane; parent supplies independent review.
