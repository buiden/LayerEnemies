# Third-party provenance

## Receive-only wire formats

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
