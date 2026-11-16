"""Offline only. Pillow 13 + RAQM (HarfBuzz/FriBidi), Noto Sans Arabic OFL 1.1.

Usage: python tools/render_call.py --font NotoSansArabic.ttf --preview PREVIEW_DIR
No font or shaping code is packaged with the addon. See THIRD_PARTY.md.
"""
import argparse
import hashlib
from pathlib import Path
import struct
from PIL import Image, ImageDraw, ImageFont, features

# Approved logical-Unicode copy from LINES.md by ID; never reverse strings manually.
LINES = {
    'h2': 'ما يداويها إلا الدم',
    'h1': 'الفزعة يا عيال',
    'h6': 'دمنا ما يروح هدر',
}
FONT_SHA256 = '63111b5b2e074dd48cc67692e0a2726d86ee94c1c37fe8598257b7b4e87e869e'
ROOT = Path(__file__).resolve().parents[1]


def render(font_path, output, preview):
    assert features.check('raqm'), 'Real RAQM shaping is required; no unshaped fallback'
    assert hashlib.sha256(font_path.read_bytes()).hexdigest() == FONT_SHA256, 'Use the pinned OFL font'
    output.mkdir(parents=True, exist_ok=True)
    preview.mkdir(parents=True, exist_ok=True)
    probe = ImageDraw.Draw(Image.new('RGBA', (256, 64)))
    for size in range(48, 11, -1):
        font = ImageFont.truetype(str(font_path), size, layout_engine=ImageFont.Layout.RAQM)
        boxes = {k: probe.textbbox((0, 0), value, font=font, direction='rtl', language='ar') for k, value in LINES.items()}
        if all(b[2] - b[0] <= 190 and b[3] - b[1] <= 56 for b in boxes.values()):
            break
    else:
        raise AssertionError('No legible common size fits the 190px box')
    print('Font: Noto Sans Arabic; SIL OFL 1.1; RAQM; common size:', size)
    for key, line in LINES.items():
        box = boxes[key]
        width, height = box[2] - box[0], box[3] - box[1]
        assert width <= 190, (key, 'overflow', width)
        image = Image.new('RGBA', (256, 64))
        draw = ImageDraw.Draw(image)
        draw.text(((256-width)//2-box[0], (64-height)//2-box[1]), line, font=font,
                  direction='rtl', language='ar', fill=(245, 213, 163, 255))
        ink = image.getchannel('A').getbbox()
        assert ink and ink[0] >= 4 and ink[1] >= 4 and ink[2] <= 252 and ink[3] <= 60, (key, 'padding', ink)
        assert ink[2]-ink[0] <= 190, (key, 'ink overflow', ink)
        # Explicit little-endian TGA: type 2, 32-bit BGRA, bottom-left, eight alpha bits.
        header = struct.pack('<BBBHHBHHHHBB', 0, 0, 2, 0, 0, 0, 0, 0, 256, 64, 32, 0x08)
        pixels = image.transpose(Image.Transpose.FLIP_TOP_BOTTOM).tobytes('raw', 'BGRA')
        footer = struct.pack('<II', 0, 0) + b'TRUEVISION-XFILE.\0'
        raw = header + pixels + footer
        assert len(raw) == 65580
        path = output / ('call-' + key + '.tga')
        path.write_bytes(raw)
        # Independent decoder verifies channel order and vertical origin against the rendered image.
        with Image.open(path) as decoded:
            assert decoded.convert('RGBA').tobytes() == image.tobytes()
        image.save(preview / ('call-' + key + '.png'))
        background = Image.new('RGBA', image.size, (18, 20, 26, 255))
        background.alpha_composite(image)
        background.resize((1024, 256)).save(preview / ('call-' + key + '-inspect.png'))
        print(f'{key}: bbox width={width}px, ink width={ink[2]-ink[0]}px, ink={ink}, bytes={len(raw)}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--font', type=Path, required=True)
    parser.add_argument('--output', type=Path, default=ROOT / 'LayerEnemies/Media')
    parser.add_argument('--preview', type=Path, required=True)
    args = parser.parse_args()
    render(args.font, args.output, args.preview)
