# Third-party provenance

## ChehulNet HELLO protocol provenance (G1)

| Author / reference | Pin | Use / rights |
|---|---|---|
| [danielcosta42](https://github.com/danielcosta42), ChehulNet and LibChehulMesh in [GuildOS v1.28.0](https://github.com/danielcosta42/guildos/releases/tag/v1.28.0) | ChehulNet v15 / LibChehulMesh v10; file SHA-256 below | **Protocol facts only, no code**. Independent receive-only guild/group HELLO parser; no library, assets, donor execution or runtime dependency. |

- `Modules/ChehulNet.lua`: `a0a69a438b1b22a761909605f691a35536595429e1beeab9e1a28afd784f8d28`.
- `Libs/LibChehulMesh.lua`: `1d973cb7afc3730ae6969b0297b778529db2c04584ad68d38cd370dd0390a5cf`.

The two files contain **no licence text of their own**. They ship inside
GuildOS and PartyLens (MIT) and Warmth (GPL-3.0); the standalone
`danielcosta42/chehulnet` repository was not publicly reachable (HTTP 404) in
the 2026-11-17 feasibility audit. This does not license the individual files
by inference: nothing from them is copied, translated, bundled or executed.

Source facts checked from the hash-matched v1.28.0 files: HELLO's positional
fields, caps delimiters and optional layer (ChehulNet 170–181, 211–246),
guild/group announcement routes (183–192), GUID field 5 (142–167), and plain
single-part bytes versus control-prefixed multipart frames (LibChehulMesh
414–434). GuildOS's latest release was rechecked and remained v1.28.0 on
2026-11-17. The tests use independently constructed wire strings.

## Source registry and Battle.net seams (PR 0b)

| Reference | Pin | Use |
|---|---|---|
| Blizzard Forever API documentation via Gethe/wow-ui-source | build 70938, `bebcb6bf309cf41b41bd74f8ca651e6a105b2676` | `BattleNetDocumentation.lua` (`GetGameAccountInfoByID`, `GetAccountInfoByID`, friend-game enumeration, `BNetGameAccountInfo`, `SendGameData`) and `ClubDocumentation.lua` (`ClubMemberInfo.bnetAccountId`); function/field facts only, independently written adapters and queue. |

No donor or library code, assets or runtime dependency. Account names, battle
tags and club notes are never read. API declarations were inspected; native
presence resolution and actual Battle.net delivery are not verified.

## Forever Layer Hop protocol provenance

| Donor | Use | Version / rights | Reuse |
|---|---|---|---|
| [Forever Layer Hop](https://www.curseforge.com/wow/addons/forever-layer-hop) | Independent `FLHNET2` receive-only decoder; direct presence in the friendly hosts list | 0.1.9; All Rights Reserved; owner-approved protocol interoperation | **protocol only, no code** |

Pinned release: `ForeverLayerHop-v0.1.9.zip`, SHA-256
`b5b3dbc608c112463bb50ddb0567c70ae2c3eb5919711b0475875001dd5092b7`.
The inspected `ForeverLayerHop.lua` SHA-256 is
`e86941e5fcef9bf88caa150c68b614bd2929e0cefe5ed27f0634b8c5f8186bc2`.
Only wire facts were read; no donor source, assets, libraries or implementation
were copied, translated, bundled or executed. LE's parser is independently
written from positional field layouts. Source references in that pinned file:
prefix/version 37/42; delimiters 957–969; decimal GUID-field-5 fingerprint
973–1008; presence 6370, 9560–9614, 9733–9755, 9925–10035; hop conversation
10079–10336; peer expiry 65. LE accepts presence only on the four routes in
its plan, not FLH's broader channel/instance routes. `WP/CQ/LQ/LO/LR/LN` are
decoded but have no action in this receive-only slice.

## Overlord receive-only wire formats

| Donor | Version / source pin | License | Use |
|---|---|---|---|
| Overlord Forever | 2.5.1, git `fd8dfd58cb5d5491faadc93e8a5e8322fdb802cb` | All Rights Reserved | **protocol only, no code**. Owner-approved, independently written `OverlordF` BF/GW/GD/EK reader; no donor code, assets or runtime dependency. |

Overlord Forever 2.5.1: wire format only, no code. The donor was read, never
executed. Protocol references: `Sync.lua`, `SyncRelay.lua`, `SyncGuild.lua`,
`GuildKillAlert.lua`, `GeneralSync.lua`, `CombatTracker.lua`, `SyncResolution.lua`.
Pinned file SHA-256 values:

- `Sync.lua`: `c641eab0bfcc9a98d1e0dcbbbb021527ce1de73963f8d9288998c5277453b3a0`
- `SyncRelay.lua`: `657224e46beb186980f3ffceb93ac4d7ed7d261e42f1425aab4080755ce641d6`
- `SyncGuild.lua`: `67faa7938439e5e94af00e927abfd261c076bff3e8e9c6041a7f295158a07601`
- `GuildKillAlert.lua`: `57b8b5b45c6aa02596f34fb8fbaf6c1b1088717d991f698706a86b01cb9cd69f`

## Offline art provenance

| Material | Use | Source / license | Shipped? |
|---|---|---|---|
| Noto Sans Arabic, variable width/weight font | Offline RAQM-shaped H2/H1/H6 headings, B2 labels and buttons | Noto Project Authors, SIL Open Font License 1.1 | Only rendered pixels; no font or shaping code |

Font source: https://github.com/google/fonts/tree/main/ofl/notosansarabic
(Font file `NotoSansArabic[wdth,wght].ttf`). Copyright 2022 The Noto Project
Authors (https://github.com/notofonts/arabic). License copy:
[tools/NotoSansArabic-OFL.txt](tools/NotoSansArabic-OFL.txt).

Pinned font SHA-256:
`63111b5b2e074dd48cc67692e0a2726d86ee94c1c37fe8598257b7b4e87e869e`.
The renderer refuses other font bytes and requires Pillow with RAQM
(HarfBuzz/FriBidi). Verified with Pillow 13.0.0. It chooses one common size
per group: headings 29px, labels 21px, buttons 19px. The headings retain
their original pixels, 190px ink box and 256x64 canvas. Labels/buttons use
128x32 canvases and a 120px ink box. Label ink is right-aligned at x=124
(exclusive), retaining four source pixels of right padding. Each label's
CallText.lua inkLeft records its alpha box's left edge in source pixels;
the 96px-wide client image uses that edge scaled by 96/128, minus a 3px gap,
to anchor the right-justified value beside the leftmost colon. Asset tests
check the alpha bounds against this metadata. All groups enforce at least
4px padding and fail on overflow. The dismiss-b shadda is retained. Output is
uncompressed bottom-left 32-bit TGA (type 2, descriptor 0x08) with a standard
footer. No client-side font dependency. The OFL does not extend its license
requirements to documents/artwork created with the font.

Rebuild (download the font above separately; do not place it in the addon):

```
python tools/render_call.py --font /path/to/NotoSansArabic.ttf --preview /path/to/previews
CALL_ART_FONT=/path/to/NotoSansArabic.ttf python -I test/render_call_test.py
python3 -I test/verify.py
```

H2, H1, H6, the three B2 labels (colon included) and help/dismiss/alternate
dismiss copy are fixed by ID from the approved call-line manuscript;
the renderer contains their logical-Unicode originals. CallText.lua holds
only the approved English and Latin client text. No donor addon code, art,
fonts, panels or sound files are copied or executed.

## Shared wire formats (independent implementations, no library code)

| Format | Source/version | License of reference | Use in LE |
|---|---|---|---|
| Raw DEFLATE | [RFC 1951](https://www.rfc-editor.org/rfc/rfc1951), sections 3.2.3-3.2.7 | Published standard | Independently written bounded decoder and stored-block encoder |
| Addon-channel escaping | [LibDeflate](https://github.com/SafeteeWoW/LibDeflate) 1.0.2-release, bundled project hash `c19f978f053ebd22950eb6f1df4445677a4b0160` | zlib | Format credit only: byte 00 maps to 01 02, byte 01 maps to 01 03 |
| AceSerializer-3.0 | [Ace3](https://www.wowace.com/projects/ace3), r1284, minor 5 | BSD-style | Format credit only: revision-1 tokens, escaping and numeric forms |
| AceComm-3.0 | Ace3 r1333, minor 14 | BSD-style | Format credit only: first/next/last/escape control bytes |
| LibSerialize | [v1.1.3 source and embedded Encoding format documentation](https://github.com/rossnichols/LibSerialize/blob/3587abd411888ab19b9e4d53fe6091e53a491fbc/LibSerialize.lua), Ross Nichols, MIT; stock source SHA256 `e4d1e7b23789961a7df50834e2313e62b5f5ce01238b652e247d29831e1e6009` | MIT | Format credit only: wire versions 1/2, all type-byte indices, counts, endianness and reference ordering |

`LayerEnemies/Codec.lua` is independent code, not copied, translated or adapted
library code. No library/donor implementation is included, executed in tests,
registered in LibStub or required at runtime. Python reference encoders/readers
in `test/codec_reference.py` are independently written from the same byte-format
facts; Python's stdlib `zlib` and `struct` supply compression and IEEE reference
vectors. No claim of executing the original libraries is made.

Network format evidence: Wanted v1.29.2 at
`4fbb231f63413ec60e6c22f36a5360cc3a24a902` (MIT; its private LibSerialize name does
not change the wire format), and WarBoard Forever 1.6.3 archive SHA256
`627a1822e00ffa28d9e073bdaa66b65fdf9ddff43caa512a0805ae0d444ed9d6`
(no application-code license found). Their source-audit section 11 illustrative
payloads are preserved as **test data**, not captured live traffic, in
`test/fixtures/codec_audits.json`, with a reproducible import command. WarBoard's
resolver no-reuse notice is unrelated to this slice: no resolver code is used.
