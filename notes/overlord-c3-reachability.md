# C3 reachability — Step 0

Pinned donor: Overlord 2.5.4, `c821808586ab50bb4ccb5d54b146e0d7c2671734`, read-only checkout `/opt/data/profiles/aqeel/cache/scratch/le12-overlord-new/OverlordForever`. No donor code copied or executed.

**Both requested routes work in the source model, without NH.**

- A valid addressed BF/BR HR learns the origin's direct return route (including the received Battle.net account ID) before invoking the application: `SyncRelay.lua:2787-2805,2827-2834`.
- Admission accepts targeted zero-hop relay dispatch without a prior known-peer/capability requirement: `SyncLeaderboardPages.lua:277-290`. A raw same-faction whisper from a group member is also admitted, but LE uses BF so the request itself learns a route.
- Control replies call `Sync:SendWhisper`: `SyncLeaderboardPages.lua:874-876`; the subscription's HB uses the same method at `:2014-2017`.
- `Sync.lua:2803-2817` selects Relay.Send for a learned peer; `SyncRelay.lua:1285-1288` requires a recent route, not NH. Directness is checked at `:2724-2727`.
- For **same-faction group members**, the new route chooses a targeted addon WHISPER, never a group broadcast: `SyncRelay.lua:1832-1868`.
- For **opposite-faction Battle.net friends**, the route carries the inbound account ID and selects BNET BR/BF: `SyncRelay.lua:1852-1865`. No separate NH-only bridge route is needed. The request also refreshes BNet hearing (`:2752-2754`).

Capability and route are different records. Only a first-hand NH updates capability (`SyncRelay.lua:2933-2946`); HR updates the route without doing so. Unknown capability is admitted for v8 (`SyncLeaderboardPages.lua:2962-2969`), and subscription has no further capability check (`:1592-1635`). **The exact expiry is age >300, not >=300** (`SyncRelay.lua:1438-1443`), so LE must wait strictly beyond 300 seconds of silence before its first request.

This proves source-level reachability, not native delivery. The donor must still consider its own channel down and be able to serve; native checks are not run (alpha, owner's decision). The feed is not dropped.
