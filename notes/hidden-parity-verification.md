# Hidden equality parity: PR A evidence

Scope: hidden-build equality evidence, rules-tag grammar, estimated pacing and
removal of both guild chat draft paths. No version bump. No PR B, channel-send
implementation, new wire route, message type, transport budget or host cap.
Donor sources were read only; no donor code was copied or executed.

## Initial candidate changes and regression gates

The table and full-gate receipt below describe the reviewed pre-correction
candidate. The review follow-up receipt supersedes its save/restore, peer
adoption, hour-window and active-search presentation rules.

| Plan area | Implementation | Focused green result |
| --- | --- | --- |
| 3.3 grammar | One optional trailing `r<digits>` before coordinates; unknown numbers ignored; misplaced/duplicate rules rejected. Zone-only requests are accepted because every clause after the zone is optional in the specified grammar. Existing reply shapes are unchanged. | 10 parser tests, 513 assertions |
| 3.1 adoption | Hidden-only, valid full ID, live-zone match, no NPC zoneUID; confirmed peer aliases only. | 1 adoption test, 64 assertions |
| 3.1 lifetime | No 300-second expiry; stray transfers, zone changes and login drop evidence. Reload requires the same identity/zone and age at most 120 seconds. Creature readers remain no-ops. | 5 lifetime tests, 604 assertions |
| 3.2 verdicts | Fresh matched reply plus host-led transfer adopts; phase nil gives same, sharding gives refusal; missing, secret, throwing or other-zone reads use the existing proxy path. | 16 verdict tests, 825 assertions |
| 3.2 WHO handoff | Preserve the matched reply and probe across closing the search and entering the host group, in auto and manual modes. | 2 WHO handoff tests, 106 assertions |
| 3.3 hosting | Token-backed hidden host replies on the existing route; exact token/peer-alias exclusions; tag-less invitation; no-token behavior unchanged. | 1 host test, 64 assertions |
| 3.5 equality | Full equality only. Hidden numeric consumers remain masked, including WE, Overlord, ChehulNet, own death and layer-tagged sightings. UI shows shared-with-host or hidden, never the token number. | 3 equality tests, 381 assertions |
| 3.4 pacing | Estimated 10 transfers per back-to-back 3600-second window; 900-second refusal hold; character/reload binding, rollback/corrupt-save guards, combat admission and visible wait text. | 4 pacing tests, 213 assertions |
| 3.7 removal | No guild chat send/draft; no-host click uses WHO; incoming guild chat and existing guild addon routes retained. | 4 guild tests, 230 assertions |
| 5.9 policy | Phase API owned by Adapters only; chat-send policy unchanged; live-source guild-draft and send-policy checks. | 32 Python policy tests, all OK |
| 5.10 regression | Unrelated numeric behavior retained. Old guild-dependent assertions now verify removal rather than requiring deleted drafts. | Trust: 105 tests / 6583 assertions; Blind: 92 tests / 4965 assertions |

All listed focused Lua suites have zero failures. The complete feature suite
has 46 passing tests. Feature RED receipts include rejected rules, a false
transfer alias, a dropped WHO probe in both modes, corrupt-save admission,
zone-only grammar, missing wait text and policy failures. The new mutant report
records assertion-level negative controls for adoption, lifetime, verdict,
hosting, equality, pacing and policy guards. One initial policy mutant survived
because the unit gate did not scan live sources for chat sends; the live-source
check was added and the final run killed 44/44.

## Removed guild chat paths

- `Hop.guildLine`, `Hop.guildBlindLine`, `Hop.guildRequest`, `Hop.GUILD`, and
  `st.guildAsk`, including its reservation/cooldown bookkeeping.
- `M.guildAsk` and the `Ask guild (chat)` preview/button.
- The `blind-guild` preview, rotation branch, draft and its pending arm.
- The GUILD draft-sent hook arm and our own guild-request reply/claim window
  (`M.layerswapGuild`).

The guild ask option is removed, not renamed or moved into a different draft.
Known hosts still use their existing non-guild routes; with no known host the
click runs WHO. Guild addon messages (including LEGW1 and LFSw), incoming guild
chat host discovery, and guild-only addon-whisper hosting remain. Existing
read-only chat-send observation hooks remain; they do not send chat.

## State and wire limits

The only new saved fields are `LayerEnemiesDB.layerToken` (3.1: ID, zone,
character, timestamp, alias) and `LayerEnemiesDB.hopLimit` (3.4: character,
window start, at most ten move timestamps, hold). No new SavedVariables global.
No change to transport budgets, host cooldown/cap, existing network routes or
message kinds. Hidden requests add `r2` only behind pacing/combat admission,
and add `not <full token>` only when one is held. No private creature token.

## Full verification

The full candidate gate ran in the background through the shared heavy-job
wrapper, using Lua 5.1.5. It exited zero:

```
RESULT: 2776 tests passed, 0 failed, 683405 assertions
```

The Python gate groups also completed successfully (46, 32, 4, 4 and 11 tests).
The native game client was not tested. The phase/transfer timing and numerical
game limits remain donor-derived assumptions, not measurements by this project.

## Mutation anchor changes

No existing mutant IDs were removed.

- Trust `mask-in-blind`: re-anchored to the new masked predicate.
- Blind `find-join-time`: scoped to the unchanged proxy-success branch.
- Blind `invite-observed`: re-anchored to the new shared observation block.
- Blind `leave-third-member`: scoped to the auto-tick group guard.
- Hotfix `build-read-unguarded`: re-anchored to the hidden reader's early return.

The long sweep was stopped at the requested review boundary. Its completed
results and partial Overlord coverage are preserved in the review follow-up
receipt; they are not a claim that every full pack completed.

## Citation discrepancy requiring a ruling

Section 3.1's blanket old-token alias wording conflicts with the equality-only
rule and the cited donor behavior: the cited alias is retained after a no-move
peer join, not after transferring to another layer. The alias-on-transfer part
was stopped. This implementation retains aliases for confirmed peer adoption
only and clears the old equivalence after a transfer. Planner/reviewer
confirmation is still required. Other inspected citations matched the stated
behavior, allowing for moved line numbers.
