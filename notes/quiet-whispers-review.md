# Own offline-whisper notices: diagnosis and local verification

## Scope and result

- Baseline: `2675e03d9363d4299a02d6d60815e0d65298967c` (`main`). Branch: `fix/hide-own-not-found`.
- Implementation commits: `94779af` (filter, controls, counters, regressions) and `3ed626d63bb5e83f0363bf714473fe0a756d9130` (distinct saved switch name and remaining configuration allowlists).
- This report and execution logs are committed separately from implementation. Local commits only; origin's push URL is `DISABLED`. No GitHub writes, no push, no live installation.
- Added default-on `/le quiet on|off`, saved as the per-character boolean `LayerEnemiesDB.quietWhispers`, and `/le net` output: `offline whisper notices hidden: N; from other addons or you: M`.
- Neither counter nor any additional player-name list is saved. Counters reset on reload. Uncorrelated notices keep bounded numeric fingerprint/length metadata for deduplication, not their names/text.
- No new sends. A programmatic baseline comparison found all **10** literal `Wire.send(..., "WHISPER", ...)` call sites unchanged (`quiet-whisper-senders.json`). Network/host coexistence policies and send budgets were not modified.

All source citations below are relative to the repository and refer to implementation head `3ed626d` unless explicitly labeled baseline.

## Why the yellow line was visible

Baseline `LayerEnemies/Wire.lua:172-219` only compiled the localized `ERR_CHAT_PLAYER_NOT_FOUND_S`, matched it to recent whisper attempts, and called `markOffline`. Its comment explicitly said there was no chat filter. Baseline `LayerEnemies/Main.lua:2115-2121` observed the system event and suppressed HeadHunter work; observing an event does not prevent a chat frame displaying it. This was a missing display filter, not evidence that spaced names failed to match.

The owner's additional facts matter: real HeadHunter 1.2.3, LayerSwap 1.14.26, BuloLayerForever 3.0.28 and WarEffortScout 1.6.6 are also loaded and can send their own whispers. The checks below are based on addon names, not these version numbers. We cannot infer which addon caused an individual identical system line from its text.

## Sender inventory and frequency before the offline hold

Every listed sender can race a logout: channel membership, recent traffic, a roster or a cached host is not proof the target will remain online when the game delivers the whisper. These are upper bounds/eligibility periods, not claims that the owner actually sent at those rates.

| LayerEnemies sender | Offline-capable target and frequency | Source |
| --- | --- | --- |
| HeadHunter `N` hello/reply | Directory or recently heard peer. Normally one actual hello per full peer identity per session, globally paced every 2 s. Only local throttle/pause refusals retry: at most 8 scheduling attempts inside 120 s, exponential backoff up to 30 s; an actual client attempt is terminal. The bounded 2,000-entry told set can reset. | `Main.lua:2090-2100`; `HhNet.lua:10-17,139-207` |
| HeadHunter `E`, `Q:h`, `Q:p` | `E` forwarding selects up to three known plus discovery peers, with selector cap 6 selections/target/60 s. `Q:h` is once after startup's 20 s, to up to five known plus discovery peers. `Q:p` goes once to the best offer after a 5 s collection period. Still-subject-to-logout targets are rechecked for freshness where directory-selected. | `Main.lua:2076-2087,2122-2144`; `HhNet.lua:243-295,351-381` |
| HeadHunter `O`, `S`, `H` | Responses to recent requesters. An `O` offer is at most once/requester/300 s, delayed up to 3 s; a served `S` pull at most once/requester/300 s, holding up to 10 records plus end marker, packed into frames paced 2 s apart. `H` at most once/player/600 s. | `Main.lua:2087,2148-2174`; `HhNet.lua:297-349,397-407` |
| War Effort sync `C/E` | Delayed answer to a requester who may leave during the 0–60 s startup delay or answer sequence. One accepted job/requester/600 s, up to three retained reports, individual frames no faster than 5 s overall. | `Main.lua:1899`; `WeNet.lua:10-12,30-78` |
| War Effort join-off `K` | Reply to a recent requester, at most once/target/60 s. | `Main.lua:1901-1913`; `WeNet.lua:80-89` |
| War Effort embassy `P` greeting/keepalive | Directory candidates and remembered partners. One initial greeting globally every 60–90 s; per-target presence gate 150 s. After no answer for 30 s, candidate is left alone for 1,800 s. Partner keepalive is every 300 s. | `Main.lua:1994`; `WeEmb.lua:13-17,94-98,141-176` |
| War Effort `P` answer | Vouched recent sender; 150 s per target, or 10 s for a previously live partner; at most 6 greeting answers/minute globally. | `Main.lua:2001`; `WeEmb.lua:213-231` |
| War Effort `W` forward | Recently heard foreign-guild partner. A new `C`, its first `E`, and `H` at most once/origin/partner/600 s; shared forward bucket bursts 6 and refills 0.2/s. | `Main.lua:2033`; `WeEmb.lua:20-21,245-274` |
| Guild-host `LayerSwap` reply | Reactive automatic `same`/`heard` response to a guild requester, possibly after waiting up to 5 s for a fresh roster. One handled request/target/60 s; Wire permits one host reply/6 s globally. Hosting is opt-in, not an autonomous probe. | `Main.lua:737,876-914`; `GuildHost.lua:9,62-80`; `Wire.lua:17-20` |
| Explicit LayerSwap hop | Not an unsolicited background sender. Named hop sends one request after a click: 60 s/target and 10 s overall. Hop-any sends a bounded fanout after a click (49 WHO rows, at most 8 attempts/1 s round, 45 rounds); an unknown-layer responder can be reasked once at the +3/+10 s fallback stage. Hop-any Wire cap is 4/target/60 s. Candidates can disappear after WHO/host lookup. | `Hop.lua:144-166`; `Invite.lua:10,225-229`; `Main.lua:1393`; `HopAny.lua:97-117,139-179`; `Wire.lua:103-106,416-425` |

The two HeadHunter paths and five War Effort paths above group the same ten actual call sites saved in the inventory JSON (one HeadHunter helper serves several message types).

Shared limits further reduce those rates: ordinary public network whispers are capped at 4/target/60 s and 20 total/60 s; HeadHunter catch-up instead has 16 frames/requester/300 s while retaining the global public limit (`Wire.lua:80-98,284-305`). Checked online guildmates are not classified as public (`Wire.lua:349-358`), but prefix/global budgets still apply. Combat halves minute caps; non-click sends are stopped in instances.

**After an attributable failure:** `Wr.OFFLINE` is **3,600 s** (`Wire.lua:96`), enforced before any send at `Wire.lua:411`. A synchronous TargetOffline return (`12`) or the existing correlated system observer marks it. Repeated display callbacks do not renew it. Existing exception: explicit hop-any requests to a *known* host use a **600 s** retry hold; ordinary whispers to that same target still retain 3,600 s (`Wire.lua:163-170,407-411`). A mere silent peer does not automatically establish this offline hold.

## Coexistence with the real addons — unchanged, read-only diagnosis

| LE sender | Still sends with donor loaded? | Exact check / absence |
| --- | --- | --- |
| HeadHunter network | **No.** Real `HeadHunter` makes LE receive-only on this network. | `Net.lua:15,70-74`; every `HeadHunter` route carries `net="hh"` at `Wire.lua:75` and goes through `Net.allowed` at `Wire.lua:354-358`. Additional hello gate: `Main.lua:2092`. |
| War Effort | **No whisper sends.** Real `WarEffortScout` stands down the network. The unrelated pre-existing `D|` guild-withdrawal exception is not a whisper. | `Net.lua:14,70-74`; route at `Wire.lua:74`, check at `Wire.lua:354-358`; guild-only withdrawal exception at `Wire.lua:351-354`. |
| Explicit LayerSwap hop / hop-any | **Yes, if clicked and other existing eligibility/budget gates pass. There is no donor-loaded stand-down check for these requests.** | `Hop.lua:144-158`, `Main.lua:1393`; `Wire.lua:71` has no `net`/donor gate, unlike its network routes. `HopAny` checks consent/state, not donor presence. |
| Guild host | **No** beside either `LayerSwap` or `BuloLayerForever`. | Donor list `Main.lua:736`; `M.hostBlocked` calls `A.loaded` at `Main.lua:738-740`; `M.hostRequest` refuses before responding at `Main.lua:876-877`. |

`Adapters.lua:323-326` uses protected `C_AddOns.IsAddOnLoaded`, falling back to `IsAddOnLoaded` only when the namespace is unavailable. With the owner's stated loaded set and normally functioning detection, automatic HeadHunter/War Effort sends and guild-host replies should already be stood down; LE's explicitly requested hop traffic can still occur. That makes a blanket claim that every visible offline line came from LE incorrect. The new filter deliberately does not suppress all four addons' errors.

## Name diagnosis (tests on the unchanged baseline)

**No name-matching bug was found; no permissive normalization change was made.** All three new name regressions pass on baseline as well as the fix (`test/src_quiet.lua:45-71`).

- `who` delegates to `Invite.name` (`Wire.lua:128`). That rule preserves the single space in `First Surname`, folds case, strips only our own realm, and retains a foreign suffix (`Invite.lua:48-64`). The actual canonical target is passed to the API and recorded (`Wire.lua:338-343,363-371`).
- `First Surname-TestRealm` is sent as `First Surname` and its bare localized error matches. `FirstSurname` is a different identity and does not match.
- `First Surname-7105` is recorded with its foreign suffix and only a correspondingly qualified error matches. A bare error is deliberately not guessed to be foreign. When a home and foreign namesake both exist, even a consumed namesake stays in the original lifetime/cap so a later bare error remains ambiguous (`Wire.lua:132-143,232-242`).
- Surnames containing `.`, `%`, `[ ]`, or `+` are **invalid under the existing letters-only character-name rule**, refused before any client send. They cannot act as Lua patterns or match a valid target. Tests explicitly check those values and a valid name afterward. This is rejection, not support for invalid names.
- `localizedPattern` escapes all template literals, accepts exactly one `%s` or `%1$s`, and anchors the whole message (`Wire.lua:175-195`). The name is captured as data, not interpolated into a pattern. There is no English fallback.

## Filter and diagnostics rules

- One registration attempt at startup (`Main.lua:2408`, `Wire.lua:264-267`), guarded through `Safe.call`. Its callback is also protected with `pcall` and returns false on exceptions (`Wire.lua:253-262`).
- Requires readable localized matching text and an unconsumed eligible *actual* whisper receipt. The original lifetime is **strictly less than 30 s**, capped at **64 attempts** (`Wire.lua:130-143`). Local rejection, queued-only work, missing APIs, throwing/secret/unrecognized client results cannot authorize hiding. Accepted `0`, legacy `true`, and TargetOffline `12` can (`Wire.lua:369-385`).
- `noticed` consumes the display receipt once; existing `consumed` still prevents renewing the offline stamp. This also handles a synchronous TargetOffline return followed by its system line and multiple already-pending attempts (`Wire.lua:158-160,237-243`).
- Shared bounded decisions use a positive integer event `lineID`, otherwise identical text within the same `GetTime()` tick (`Wire.lua:197-250`). Event-before-filter, filter-before-event, and three chat frames produce one offline update and consistent hide/show decisions. A later distinct line cannot spend the same receipt. Main forwards arg11 (`Main.lua:2116-2117,2479`).
- `hidden: N` counts lines actually hidden, not observer-only events or frame calls. M counts supported localized notices without eligible unconsumed own display evidence, even with quiet off. Other system messages, unreadable values and missing templates do not count. Uncorrelated names are not retained. Tests cover expiry, capacity, rollback, all these exclusions and diagnostics privacy.
- M is **uncorrelated**, not proof of another sender: late, ambiguous or duplicate failures can count there. Identical concurrent whispers by another addon or the player to our pending target cannot be authoritatively attributed. Without usable line IDs, identical independent failures in one tick are indistinguishable. Numeric fingerprint collisions can undercount unmatched events, never authorize hiding.

## Gate changes

- Smallest API-policy change: one mapping at `test/verify.py:87`: `API_OWNERS['ChatFrame_AddMessageEventFilter'] = 'Wire.lua'`. No global allow, send-policy relaxation, or broad chat capture.
- `test/api_policy_test.py:102-109` accepts that API in Wire only, rejects it in Main/Adapters/Sources, and exercises direct, `_G.field`, and concatenated `_G[...]` spellings.
- Configuration-only assertions in `test/harness.lua`, `test/kills.lua`, `test/overlord.lua`, `test/known.lua`, and `test/watch.lua` allow just the new `quietWhispers` boolean. Existing bans on saved session target/quiet tables remain intact.
- The first full run caught five failures: two existing assertions explicitly reserve `LayerEnemiesDB.quiet` as absent (HopAny's session-only suppression map), plus three not-yet-updated configuration allowlists. Renaming the saved switch to `quietWhispers` and updating those allowlists fixed them; no hop behavior was changed. The initial failed log is retained rather than represented as a passing run.

## Test and mutation evidence

Commands use Lua 5.1.5 at `/opt/data/tools/lua/lua-5.1.5/src/lua`.

- **RED on baseline:** final regression files copied into a detached temporary worktree at `2675e03d`; `test/harness.lua --only Quiet` exits 1: `RESULT: 3 tests passed, 22 failed, 1095 assertions`. The three passing tests are the name diagnosis. Filter, controls, counters and new semantics fail. API-owner test exits 1 with nine failed ownership subcases. Both initial and final-baseline logs are retained.
- **GREEN:** same selector at implementation head: `RESULT: 25 tests passed, 0 failed, 2007 assertions`. API policy suite: 13 tests, OK. See `quiet-green.txt` and `quiet-api-green.txt`.
- **Mutants:** `python3 test/quiet_mutants.py`: **38/38 caught**, independently applied to scratch copies, restored between runs. Lua mutants must syntax-check and fail assertions, not merely crash on invalid syntax. Full per-rule failures are in `quiet-mutants.json`; `test/quiet_mutants.py:13-51` is the reproducible rule list. Includes ownership, registration once/protection, callback fail-open, event-only, own receipt, one-line consumption, no offline renewal, separate display/offline state, full realm/spaces/invalid punctuation, secrets, exact localization/no fallback, original expiry/caps/rollback, ID/tick idempotence, both counters/privacy, accepted/synchronous/legacy results, switch/default/save, and no persisted names. The initial registration-once mutant survived until a direct second registration attempt was added to the test; the final run catches it.
- **Full verification:** `python3 test/verify.py`, foreground with 1,800 s subprocess/tool timeout, exit **0**, 232.37 s. Exact line: **`RESULT: 1489 tests passed, 0 failed, 259860 assertions`**. Syntax (85 Lua files), API/static gates, 5,000 fuzz inputs, archive integrity/source parity all PASS. See `quiet-full-verify.txt`, updated `verification.json` and `test-results.txt`.
- Full verifier generated `dist/LayerEnemies-1.1.0.zip`; SHA-256 recorded by verifier: `db0b6a70bd8ee4eaa18b1a83b10c076b2e24266c2bc20d6bc1e9f414199eda1e`. This is a local artifact, not a release or live-tested build.
- `git diff --check` passed. Source send-site comparison passed. No code changed after the successful full run.

## Source evidence versus live-client unknowns

Read-only reference snapshot: Gethe/wow-ui-source `forever`, commit `bebcb6bf309cf41b41bd74f8ca651e6a105b2676`; its `version.txt` is `1.60.1.70938`.

- [Deprecated alias](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_DeprecatedChatInfo/Deprecated_ChatFrame.lua#L51): `ChatFrame_AddMessageEventFilter = ChatFrameUtil.AddMessageEventFilter`.
- [Filter registration/dispatch](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_ChatFrameBase/Shared/ChatFrameFilters.lua#L202-L214): registration and dispatch pass chat frame, event and payload.
- [System event payload](https://github.com/Gethe/wow-ui-source/blob/bebcb6bf309cf41b41bd74f8ca651e6a105b2676/Interface/AddOns/Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua#L2452-L2473): text is arg1; lineID is arg11 and declared never-secret. Text can be secret in messaging lockdown. This declaration also labels the event synchronous; it does not establish its actual timing relative to `SendAddonMessage` returning.

**No live client was used.** Still unknown on the owner's build 70938: whether the deprecated registration alias is loaded/usable at our startup, which return codes and localized strings occur for these failures, whether a failure can arrive before the send call returns and its receipt is recorded, actual event/filter ordering, whether distinct failures have distinct stable positive line IDs across all chat frames, and interactions with other addons' filters. Early/unrecorded or unsupported cases deliberately fail open. The harness simulates both observer/filter orders and multiple frames; it is not proof of native behavior or of which installed addon emitted a particular error. A live three-chat-frame test, quiet on/off, own and unrelated offline targets, same-target competing sends, and `/reload` is still required before a release claim.
