# Hopper combat fix

Base: `3e8e23c9b7820b321485a44753b8ca3c4186a546` (PR #46, 1.2.5 hop bar).
No version bump or new release-notes section: the repository has no per-PR
changelog requirement. The existing behavior documentation and generated
verification notes are updated instead. No CI configuration, AGENTS or
CONTRIBUTING file is present; the README's gate is `python3 -I test/verify.py`.

## Policy and scope

Hoppers can request, accept, leave and click again in combat, with the existing
cooldowns, identity checks and group-ownership rules. Combat-start events do
not cancel the clicked round. Instances and unreadable instance state still
refuse hops. Regression testing also exposed missing instance checks on the
old named-host/report request path; those now use the same live instance
refusal before sending or reserving a request.

Guild hosts still never invite in combat. No host policy or party API owner
changed. All addon sends still belong to Wire; there are no new routes,
dependencies, saved fields, chat sends or secure-action workarounds.

FLH's exception is only click-owned guest LQ/LR and correlated responses. Its
presence, directory probes and owed membership replies stay paused. The
source tick permits this one guest lifecycle, not every source. FLH was
previously wholly blocked in combat, so its separate budget path had hardcoded
cost one. It now applies the existing Wire policy: cost two, halved minute
caps, and two tokens reserved for the single LR slot. No ceiling is increased.

## Combat-gate map

Locations below refer to the base commit so removed lines remain reproducible.
All paths are under `LayerEnemies/`. Combat-related comments are not separate
gates. Some owner-supplied line references had moved or were unrelated feeds.

| Base location | Decision | Role / reason |
| --- | --- | --- |
| `HopAny.lua:15` | Remove | Hopper click refusal; combat is permitted. |
| `UI.lua:506` | Remove | Hopper bar's unconditional `In combat` status hid the real ready/cooldown state. |
| `Main.lua:1750` | Remove combat context | Hopper no longer needs combat as an admission condition; live instance remains. |
| `Main.lua:1795-1796` | Remove combat only | Hopper live pump/WHO/invite guard; group, instance, zone and identity still checked. |
| `Main.lua:2076` | Remove combat only | Hopper accepts only its already-authorized invite; group/instance checks remain. |
| `Main.lua:2122,2126,2140` | Remove | Hopper success/failure leave no longer waits for combat end. Instance and host-led group checks remain. |
| `Main.lua:2979-2981` | Remove hop cancellation only | Combat-start must retain hop-any/FLH; WarBoard retirement remains. |
| `Main.lua:1248` | Narrow | Mixed FLH ingress: live guest WHISPER responses continue; no new membership presence in combat. |
| `FLHMember.lua:35` | Narrow | Mixed FLH send admission: only guest LQ/LR WHISPER allowed in combat; instances/identity/privacy/stand-down unchanged. |
| `Sources.lua:79` | Narrow | Mixed source tick: only FLH guest work continues; other sources and WarBoard remain paused. |
| `GuildHost.lua:72` | Keep | Host-side combat/instance refusal, including unreadable combat. |
| `Main.lua:1114` | Keep | Host snapshot passes live combat into GuildHost; host help at 1062 stays accurate. |
| `Wire.lua:369-380,392-409,596-606` | Keep | Shared and hop send budgets still charge two tokens and halve minute caps in combat. FLH budget at 442-485 now follows the same policy. |
| `Main.lua:305` | Keep | Unrelated Find/friend-presence scan, not hopping. |
| `Main.lua:478,483,486,561` | Keep | Unrelated Overlord send/stop/receive gates, not hopper or guild hosting. |
| `Wire.lua:521` | Keep | Overlord transport combat refusal, unrelated to hop requests. |
| `Sources.lua:117` | Keep | Incoming tracking evidence admission, not the hop request path. |
| `Adapters.lua:425` | Keep | WarBoard client snapshot; not hopper. |
| `Adapters.lua:555` | Keep | Overlord feed group-membership snapshot; not hopper's `A.party()`. |
| `Adapters.lua:596-599` | Keep | Shared fail-closed combat reader still used by hosting and non-hop sources. |
| `Directory.lua:68,98` | Keep | Channel join/leave/read safety; guest hops use already-known host claims, no new directory exception. |
| `BNet.lua:7` | Keep | Battle.net source send gate, not hopping. |
| `ChehulNet.lua:92` | Keep | Unrelated tracking network safety. |
| `Wanted.lua:19` | Keep | Unrelated Wanted source safety. |
| `OverlordFeed.lua:142` | Keep | Deferred feed-stop accounting via `stopPaused`, not hop-any Stop. |
| `Relay.lua:27` | Keep | Combat budget reserve calculation, not hop refusal. |

## Pinned Forever API audit

Resolved `https://api.github.com/repos/Gethe/wow-ui-source/commits/forever` to
`3d8abb1da73acd38e412e24fb3f99454a6392346`; `version.txt:1` is
**1.60.1.70959**, interface family 16001. This source mirror is newer than the
repository's older 70938 evidence. No client installation was inspected.

All following paths are relative to `Interface/AddOns/` at that exact pin:
https://github.com/Gethe/wow-ui-source/tree/3d8abb1da73acd38e412e24fb3f99454a6392346/Interface/AddOns

| Call / operation | Pinned source evidence and restrictions |
| --- | --- |
| `C_PartyInfo.InviteUnit` | `Blizzard_APIDocumentationGenerated/PartyInfoDocumentation.lua:357-367`: `RequiresValidInviteTarget=true`, `SecretArguments="AllowedWhenUntainted"`; no `HasRestrictions`, protected flag or combat predicate in this declaration. This is the HOST call, not the hopper call. Host refusal remains. |
| `C_PartyInfo.LeaveParty` | Same file `:484-493`: optional category, `SecretArguments="AllowedWhenUntainted"`; no `HasRestrictions`, protected flag or combat predicate. May require confirmation for PartySync; the addon does not bypass it. |
| Legacy `InviteUnit` / `LeaveParty` | Not called by this addon: `Wire.partyCall` resolves the names inside `C_PartyInfo` only. No global fallback was introduced. Missing legacy generated declarations are not a claim that native globals are available or removed. |
| `AcceptGroup` | Not declared in generated API docs at this pin. Loaded `Blizzard_StaticPopup_Game/GameDialogDefs.lua:1309-1334` calls it at `:1319`, then marks `inviteAccepted=1`. `OnHide` declines only if that mark is absent. `Blizzard_StaticPopup_Game.toc:4-11` loads this shared definition/XML, with Camelot additions at line 7. No combat gate or secure-action attribute appears on this ordinary invite button. Supplemental API reference: https://warcraft.wiki.gg/wiki/API:AcceptGroup (event-handler example, no protected/hardware restriction label). This is source evidence, not a native permission probe. |
| `StaticPopup_FindVisible`, `StaticPopup_Hide` | `Blizzard_StaticPopup/StaticPopup.lua:156-168,450-462`: ordinary Lua lookup and `dialog:Hide()`. **Important:** generated `SimpleFrameAPIDocumentation.lua:687-694` marks frame Hide `IsProtectedFunction=true`; that matters for protected frames, not every plain frame. The actual popup chain is `Blizzard_StaticPopup_Game/GameDialog.xml:3,51,78,348-367`, `Blizzard_SharedXML/Mainline/SharedUIPanelTemplates.xml:510`, `Blizzard_SharedXML/LayoutFrame.xml:3,105`, and `Blizzard_AccessibilityTemplates/UserScaledElementTemplates.xml:3`: plain Frame/Button templates, no SecureActionButton/SecureHandler inheritance or protected attribute. Existing accepted-mark-before-hide behavior is retained, with no protected-frame workaround. |
| `C_FriendList.SendWho` | `Blizzard_APIDocumentationGenerated/FriendListDocumentation.lua:330-342`: `HasRestrictions=true`, `RequiresFriendList=true`, `SecretArguments="AllowedWhenUntainted"`. Do NOT describe it as unrestricted. Loaded `Blizzard_GroupFinder_VanillaStyle.toc:4-5,26-27` selects the Camelot UI; `Mainline/WhoList.lua:176-190` calls SendWho from Enter/click handlers, not a combat-deferred action. Supplemental https://warcraft.wiki.gg/wiki/API:C_FriendList.SendWho labels the restriction `#hwevent`, not `#nocombat`. The existing direct hardware-click/slash stack remains mandatory; no timer starts WHO and no hardware restriction is bypassed. |
| WHO reads/routing | `FriendListDocumentation.lua:171-180,202-217,395-404`: GetNumWhoResults, GetWhoInfo, SetWhoToUi. GetWhoInfo has `MayReturnNothing=true`; the latter two have `SecretArguments="AllowedWhenUntainted"`, no combat/protected predicate. `SimpleFrameAPIDocumentation.lua:740-756,969-981,1019-1034,1598-1613` covers event/visibility checks and registration restoration. Visibility may be secret; existing safe reads/pcalls remain. No WHO window is hidden or given a replacement OnEvent. |
| Addon whisper | `Blizzard_APIDocumentationGenerated/ChatInfoDocumentation.lua:516-533`: SendAddonMessage, `SecretArguments="NotAllowed"`, no combat/protected flag. Validated plain payloads still cross only Wire; costs and throttles remain. |
| Chat drafts (not chat sends) | `Blizzard_ChatFrameBase/Shared/ChatFrameUtil.lua:367-385,448-506,511-512,531-562`: SendTell, OpenChat, GetActiveWindow and activation only prepare the edit box. `Blizzard_DeprecatedChatInfo/Deprecated_ChatFrame.lua:74` aliases the legacy OpenChat name. `Blizzard_APIDocumentationGenerated/SimpleEditBoxAPIDocumentation.lua:446-455` marks Insert `SecretArguments="AllowedWhenUntainted"`; `:668-675` marks SetFocus with the ScriptedInput forbidden-aspect check, not a combat ban. Existing plain-text draft/error handling is unchanged; the player must press Enter, and no chat-send API is invoked. |
| Timer, clocks, map/unit readers | `UITimerDocumentation.lua:11-20` (After), `SystemTimeDocumentation.lua:57-65` (GetTime), `MapDocumentation.lua:49-63,312-326,437-452` (map, info, position), `UnitDocumentation.lua:1192-1205,2039-2054,2489-2504` (exists, leader, name). No combat prohibition is declared on these readers/timer. Map info may return nothing; unit names/leader identity may be secret. All prior nil/secret/unknown group, map, identity and party checks remain. Read-only addon metadata, cached host lists and local chat/UI display do not gain send authority. |

Conclusion: no combat-prohibited action was identified on this hopper path
under the pinned declarations and actual plain-frame template chain. WHO's
hardware restriction and protected-frame Hide rules are real and remain
respected. Absence of a flag is not a native runtime proof. **Not tested in
game** (alpha, owner's decision); server hopping, native taint and dispatch
order remain unverified, with no request for a player test or capture.

## Regression evidence

The new `test/src_hop_combat.lua` runs in the unchanged discovered-source
harness. Each behavior slice ran red before its implementation. The final
new test file was also copied alone onto a detached worktree of the exact
base (all production files unchanged):

    RESULT: 4 tests passed, 12 failed, 929 assertions

Candidate targeted result:

    RESULT: 16 tests passed, 0 failed, 1090 assertions

The four baseline passes are instance controls for hop-any/bar/FLH plus the
host-combat negative/positive control. The two manual instance failures
revealed the old missing guard; the other failures reproduce hopper combat
refusal, cancellation, invite refusal and deferred leave. One early FLH test
fixture forgot the harness's disabled ship flag; it was corrected and the
final red replay above uses the corrected fixture, not that setup failure.

Eight compiling behavioral mutations were killed by these tests: remove host
combat refusal; reintroduce hopper pump combat refusal; cancel at combat start;
refuse acceptance in combat; remove normal Wire cost two; remove FLH cost two;
stop the FLH combat tick; remove the named-instance guard. No surviving mutant
was counted as killed. Legacy tests of the intentionally replaced combat
policy now assert continuation. The old priority test explicitly allowed a
named hop inside an instance; it now expects refusal while retaining both
Find-host discovery sends and the relay refusal. All other guard assertions
remain.

The full README verification gate, `python3 -I test/verify.py`, passed with
exit status 0 on the final candidate (default eight harness shards):

    RESULT: 2233 tests passed, 0 failed, 649130 assertions

Its Python suites also passed: `test_verify.py` (43), `api_policy_test.py`
(30), `flh_mutants_test.py` (4), `harness_sources_test.py` (4), and
`call_assets_test.py` (11). Syntax checks passed for 119 Lua files; API/route,
TOC, media and package source-parity checks passed. The broader `--only combat`
harness replay passed 88 tests with 8140 assertions.

The gate regenerated `notes/test-results.txt` and `notes/verification.json`.
The generated result describes combat acceptance accurately; package version
and release sections are not advanced. Local deterministic ZIP SHA-256:
`fc29faf6e08ed5ca6df3b71f8653636232b0d906d7b916cdcf8115216416c2db`.
