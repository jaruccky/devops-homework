#!/usr/bin/env python3
"""Render actual saved terminal output into PNGs; no expected output is invented."""
import argparse
from pathlib import Path
import textwrap
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--input-dir', type=Path, default=root / 'evidence')
parser.add_argument('--output-dir', type=Path, default=root / 'screenshots')
args = parser.parse_args()
out = args.output_dir
out.mkdir(parents=True, exist_ok=True)
font_path = '/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf'
try:
    font = ImageFont.truetype(font_path, 16)
except OSError:
    font = ImageFont.load_default(size=16)
for source in sorted(args.input_dir.glob('*.txt')):
    lines = [f'Saved terminal output: {source.name}', '']
    for line in source.read_text().splitlines():
        lines.extend(textwrap.wrap(line, width=116, replace_whitespace=False) or [''])
    # Split long transcripts into pages rather than silently cutting content.
    for index, start in enumerate(range(0, len(lines), 65), start=1):
        page = lines[start:start + 65]
        canvas = Image.new('RGB', (1160, 40 + 24 * len(page)), '#111827')
        draw = ImageDraw.Draw(canvas)
        for number, line in enumerate(page):
            draw.text((20, 20 + number * 24), line, font=font, fill='#d1fae5')
        suffix = f'-{index}' if len(lines) > 65 else ''
        canvas.save(out / f'{source.stem}{suffix}.png')
