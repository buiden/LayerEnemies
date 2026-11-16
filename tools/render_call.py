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
# B2 labels, including the colon. Only the corresponding values are client text.
LABELS = {'victim': 'من ربعنا:', 'killer': 'الغريم:', 'where': 'المكان:'}
BUTTONS = {'help': 'أبشر', 'dismiss-a': 'اعذروني', 'dismiss-b': 'سكّر'}
FONT_SHA256 = '63111b5b2e074dd48cc67692e0a2726d86ee94c1c37fe8598257b7b4e87e869e'
ROOT = Path(__file__).resolve().parents[1]


def render_group(font_path, output, preview, group, lines, dimensions, max_width):
    w, h = dimensions
    probe = ImageDraw.Draw(Image.new('RGBA', dimensions))
    for size in range(48, 11, -1):
        font = ImageFont.truetype(str(font_path), size, layout_engine=ImageFont.Layout.RAQM)
        boxes = {k: probe.textbbox((0, 0), value, font=font, direction='rtl', language='ar') for k, value in lines.items()}
        if all(b[2] - b[0] <= max_width and b[3] - b[1] <= h - 8 for b in boxes.values()):
            break
    else:
        raise AssertionError('No legible common size fits the %dpx %s box' % (max_width, group))
    print(group + ': common size:', size)
    for key, line in lines.items():
        box = boxes[key]
        width, height = box[2] - box[0], box[3] - box[1]
        assert width <= max_width and height <= h - 8, (key, 'overflow', width, height)
        image = Image.new('RGBA', dimensions)
        draw = ImageDraw.Draw(image)
        draw.text(((w-width)//2-box[0], (h-height)//2-box[1]), line, font=font,
                  direction='rtl', language='ar', fill=(245, 213, 163, 255))
        ink = image.getchannel('A').getbbox()
        assert ink and ink[0] >= 4 and ink[1] >= 4 and ink[2] <= w - 4 and ink[3] <= h - 4, (key, 'padding', ink)
        assert ink[2]-ink[0] <= max_width, (key, 'ink overflow', ink)
        if group == 'labels':
            # The RTL colon is leftmost: put its ink at the four-pixel padding,
            # immediately beside the right-justified value at the image's left edge.
            aligned = Image.new('RGBA', dimensions)
            aligned.alpha_composite(image.crop(ink), (4, ink[1]))
            image = aligned
            ink = image.getchannel('A').getbbox()
        assert ink and ink[0] >= 4 and ink[1] >= 4 and ink[2] <= w - 4 and ink[3] <= h - 4, (key, 'aligned padding', ink)
        # Explicit little-endian TGA: type 2, 32-bit BGRA, bottom-left, eight alpha bits.
        header = struct.pack('<BBBHHBHHHHBB', 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 0x08)
        pixels = image.transpose(Image.Transpose.FLIP_TOP_BOTTOM).tobytes('raw', 'BGRA')
        footer = struct.pack('<II', 0, 0) + b'TRUEVISION-XFILE.\0'
        raw = header + pixels + footer
        assert len(raw) == 18 + w * h * 4 + 26
        path = output / ('call-' + key + '.tga')
        path.write_bytes(raw)
        # Independent decoder verifies channel order and vertical origin against the rendered image.
        with Image.open(path) as decoded:
            assert decoded.convert('RGBA').tobytes() == image.tobytes()
        image.save(preview / ('call-' + key + '.png'))
        background = Image.new('RGBA', image.size, (18, 20, 26, 255))
        background.alpha_composite(image)
        background.resize((w*4, h*4)).save(preview / ('call-' + key + '-inspect.png'))
        print(f'{key}: bbox width={width}px, ink width={ink[2]-ink[0]}px, ink={ink}, bytes={len(raw)}')


def render(font_path, output, preview):
    assert features.check('raqm'), 'Real RAQM shaping is required; no unshaped fallback'
    assert hashlib.sha256(font_path.read_bytes()).hexdigest() == FONT_SHA256, 'Use the pinned OFL font'
    output.mkdir(parents=True, exist_ok=True)
    preview.mkdir(parents=True, exist_ok=True)
    print('Font: Noto Sans Arabic; SIL OFL 1.1; RAQM')
    render_group(font_path, output, preview, 'headings', LINES, (256, 64), 190)
    render_group(font_path, output, preview, 'labels', LABELS, (128, 32), 120)
    render_group(font_path, output, preview, 'buttons', BUTTONS, (128, 32), 120)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--font', type=Path, required=True)
    parser.add_argument('--output', type=Path, default=ROOT / 'LayerEnemies/Media')
    parser.add_argument('--preview', type=Path, required=True)
    args = parser.parse_args()
    render(args.font, args.output, args.preview)
