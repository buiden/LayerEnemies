# Protocol provenance

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

# Offline art provenance

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
