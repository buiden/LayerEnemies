# Offline art provenance

| Material | Use | Source / license | Shipped? |
|---|---|---|---|
| Noto Sans Arabic, variable width/weight font | Offline RAQM-shaped H2/H1/H6 headings | Noto Project Authors, SIL Open Font License 1.1 | Only rendered pixels; no font or shaping code |

Font source: https://github.com/google/fonts/tree/main/ofl/notosansarabic
(Font file `NotoSansArabic[wdth,wght].ttf`). Copyright 2022 The Noto Project
Authors (https://github.com/notofonts/arabic). License copy:
[tools/NotoSansArabic-OFL.txt](tools/NotoSansArabic-OFL.txt).

Pinned font SHA-256:
`63111b5b2e074dd48cc67692e0a2726d86ee94c1c37fe8598257b7b4e87e869e`.
The renderer refuses other font bytes and requires Pillow with RAQM
(HarfBuzz/FriBidi). Verified with Pillow 13.0.0. It chooses one common size
from the longest heading, checks the 190px ink box and at least 4px padding,
and writes uncompressed bottom-left 32-bit 256x64 TGA files with a standard
footer. No client-side font dependency. The OFL does not extend its license
requirements to documents/artwork created with the font.

Rebuild (download the font above separately; do not place it in the addon):

```
python tools/render_call.py --font /path/to/NotoSansArabic.ttf --preview /path/to/previews
python3 -I test/verify.py
```

H2, H1 and H6 copy is fixed by ID from the approved call-line manuscript;
the renderer contains their logical-Unicode originals. CallText.lua holds
only the approved English and Latin client text. No donor addon code, art,
fonts, panels or sound files are copied or executed.
