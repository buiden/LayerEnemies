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
