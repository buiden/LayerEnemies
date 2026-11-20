# Layer trust implementation evidence

Scope: layer plan PR 2, on PR 1. No version or SavedVariables migration. All
client behavior below is mock-tested, not native certification.

## Decisions carried into this implementation

- Blind hosting keeps inviting verified guildmates through the existing
  unconstrained LayerSwap ask. Known-mode host decisions and all Wire budgets
  remain unchanged. No marker distinguishes LE from other senders.
- Only the hop bar label changes to `layer hidden`. The click handler stays
  unchanged and refuses an untrusted own key. Blind guest hopping belongs to
  PR 3. An already-open layered fanout is stopped to prevent deferred sends.
- The plan's B1a description of the existing unknown bar text is stale:
  current main says `Detecting...`, not `layer ?`. That existing unknown text
  is retained; only the specifically requested blind label is changed.
- Current-own reads use Trust.own. Bulo snapshot admission goes through
  Trust.bulo. Record gets the live store/time context; FLHMember passes the
  trusted NPC UID to the unchanged FLH builders. WeOut stays an encoder: own
  callers omit their key when untrusted, remote rebuilds keep sender claims.
- The delayed own K contract intentionally changes from PR 1: preserve its
  death-time key only while current trust is known; unknown/blind sends it
  empty. Cached own WE sync and guild R work are checked again at send time.
- Hop contradiction compares full before/after IDs. A real suffix move with
  an unchanged server prefix must not count as a constant-ID hop.

## RED/GREEN

The initial Bulo regression failed both Bulo-only and expired-NPC-history
sessions. The exact failed output combined the visible Find status, same flag
and captured O field: expected `seen by you / false / `, got
`is on YOUR layer / true / 7086`. Separate confirmed NPC history fixed it;
the focused Layer suite then returned 156 passed, 0 failed, 9993 assertions.

Trust was implemented tests-first. Later focused RED/GREEN caught stale
cached WE sync layers, a still-running hop fanout, same-key freshness,
layered delayed replies, Wanted bridge status, source-reader projections,
extra fallback coordinates, duplicate-host triples, and same-prefix suffix
moves. Positive controls prove an owed layered report exists before masking
and that remote WeOut rebuilds preserve their original claim.

## Coverage map

- `src_trust.lua`: known/unknown/blind, 300-second expiry and rollback;
  manual controls; cold failures 19/20 and streak 9/10; churn 2/3, 600-second
  window and 10-second excuses; distinct formed hops 2/3; outdoor group
  mismatch 59/60, continuity and matching-peer negatives; immutable masking.
- `src_trust_live.lua`: real target, guild, party, invite, death and transfer
  events for zero, unparseable, churn, constant and private IDs, plus manual
  blindness. Retained pre-trigger data; no layer relation/value after trigger;
  names, zones, Find alerts/pop-up, Call window and actual O/C/H/K traffic;
  real transfer still wipes and blindness stays sticky.
- `src_trust_surfaces.lua`: hidden header, Friendly and FLH values, ChehulNet
  comparison/count, exact `/le layer` line; blind O/R/WE/HH claims, Overlord
  and host readers; Bulo source, FLH builder, Record reader, WeOut own/remote
  distinction; blind host invitations on whisper and guild-chat paths. An
  additional client-boundary probe ran the same host session with a captured
  C_PartyInfo.InviteUnit and verified both actual calls and target names
  (1 test passed, 0 failed, 54 assertions).
- `src_trust_boundary.lua`: queued own sync and R, active layered fanout,
  late LayerSwap replies, same-key freshness, and old/new source shard text.
- `test_verify.py TrustReaderTests`: token-aware section-4 grep, positive
  writes/non-own Bulo tables and planted forbidden readers. Part of verify.
- `trust_mutants.py`: syntax-checked, private-copy mutations of Trust.lua
  only. Assertion failures count as kills; syntax errors and timeouts do not.

Inherited fixtures that meant to remain known now supply fresh identity
without refreshing their sightings. Cold/expired display expectations are
migrated to hidden layers; retained source data and all non-layer assertions
remain. The full gate exposed nine further inherited expectations: the host
parser now accepts the existing unconstrained grammar; world/transfer events
clear identity and stop old fanout, while unchanged subzone/group events keep
it; source-key formatting tests explicitly establish known trust. All nine
migrated cases passed a targeted replay before the full rerun. Full verifier
output is regenerated in the usual verification notes.

Author self-review only; independent review remains the parent review lane.
Deferred minor: a later WE E enrichment in blind can set the receive diagnostic
to `duplicate`, because the masked store record is a copy. The live enemy array
is shared, so the enrichment, Find updates, and unknown layer remain intact.
A direct Store probe returned initial admission true, enrichment false/duplicate,
retained enemy count 1, layer namespace unknown. No production change made for
this diagnostic-only finding.

Not tested in game (alpha, owner's decision).
