"""Render a geometry proof exported by appearance-tests.lua, not a game screenshot."""
import json
import re
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont

items = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
root_name = sys.argv[3] if len(sys.argv) > 3 else "ConsoleExperienceConfigFrame"
root = next(item for item in items if item["name"] == root_name)
scale = 2
padding = 24
origin_x = root["x"] - padding
origin_top = root["y"] + root["h"] + padding
width = int(root["w"] + padding * 2)
height = int(root["h"] + padding * 2 + 30)
canvas = Image.new("RGBA", (width * scale, height * scale), (7, 11, 17, 255))


def box(x, y, w, h):
    return (int((x - origin_x) * scale), int((origin_top - y - h) * scale),
            int((x + w - origin_x) * scale), int((origin_top - y) * scale))


def rgba(color):
    return tuple(round(max(0, min(1, part)) * 255) for part in (color + [1])[:4])


asset_root = Path(__file__).resolve().parents[1] / 'addon' / 'Windrunner-Controller' / 'textures'
asset_cache = {}


def asset(path):
    if '\\textures\\' not in path:
        return None
    relative = path.split('\\textures\\', 1)[1].replace('\\', '/')
    target = asset_root / relative
    if not target.suffix:
        target = target.with_suffix('.tga')
    if not target.is_file():
        return None
    if target not in asset_cache:
        asset_cache[target] = Image.open(target).convert('RGBA')
    return asset_cache[target]


def paint_texture(layer, path, rect, color):
    art = asset(path)
    if art is None or rect[2] <= rect[0] or rect[3] <= rect[1]:
        return False
    art = art.resize((rect[2] - rect[0], rect[3] - rect[1]), Image.Resampling.LANCZOS)
    tint = Image.new('RGBA', art.size, rgba(color or [1, 1, 1, 1]))
    layer.alpha_composite(ImageChops.multiply(art, tint), (rect[0], rect[1]))
    return True


# A frame's textures render in layers before its child frames, irrespective of
# when a texture was created. This keeps recessed value art behind its text.
layers = {'BACKGROUND': 0, 'BORDER': 1, 'ARTWORK': 2, 'OVERLAY': 3, 'HIGHLIGHT': 4}
strata = {'BACKGROUND': 0, 'LOW': 1, 'MEDIUM': 2, 'HIGH': 3, 'DIALOG': 4,
          'FULLSCREEN': 5, 'FULLSCREEN_DIALOG': 6, 'TOOLTIP': 7}
if all('id' in item for item in items):
    children = {}
    for item in items:
        children.setdefault(item['parent'], []).append(item)
    ordered = []
    def visit(item):
        ordered.append(item)
        own = children.get(item['id'], [])
        regions = [child for child in own if child['kind'] in ('Texture', 'FontString')]
        frames = [child for child in own if child['kind'] not in ('Texture', 'FontString')]
        for child in sorted(regions, key=lambda value: layers.get(value.get('layer'), 2)):
            visit(child)
        for child in sorted(frames, key=lambda value: (strata.get(value.get('strata'), 2), value.get('level', 0))):
            visit(child)
    for item in children.get(0, []):
        visit(item)
    items = ordered


for item in items:
    rect = box(item["x"], item["y"], item["w"], item["h"])
    layer = Image.new("RGBA", canvas.size)
    draw = ImageDraw.Draw(layer)
    if item["bg"] and rect[2] > rect[0] and rect[3] > rect[1]:
        if not paint_texture(layer, item.get('bgTexture', ''), rect, item['bg']):
            draw.rectangle(rect, fill=rgba(item["bg"]))
    if item["border"] and rect[2] > rect[0] and rect[3] > rect[1]:
        draw.rectangle(rect, outline=rgba(item["border"]), width=scale)
    if item["texture"].endswith("WHITE8X8") and item["vertex"]:
        draw.rectangle(rect, fill=rgba(item["vertex"]))
    elif item['texture']:
        paint_texture(layer, item['texture'], rect, item['vertex'])
    if item["text"]:
        face = 'georgia.ttf' if 'frizqt' in item.get('font', '').lower() else 'segoeui.ttf'
        font = ImageFont.truetype('C:/Windows/Fonts/' + face, max(1, round(item["size"] * scale)))
        text = re.sub(r"\|c[0-9a-fA-F]{8}|\|r", "", item["text"])
        text = re.sub(r"\|H[^|]+\|h(.*?)\|h", r"\1", text)
        lines = []
        for paragraph in text.splitlines():
            line = ""
            for word in paragraph.split():
                candidate = (line + " " + word).strip()
                if line and draw.textlength(candidate, font=font) > max(1, rect[2] - rect[0]):
                    lines.append(line)
                    line = word
                else:
                    line = candidate
            lines.append(line)
        line_height = round(item['size'] * 1.2 * scale)
        y = rect[1]
        if item.get('valign') == 'CENTER' or (item['h'] <= 44 and item.get('valign') != 'TOP'):
            y += max(0, ((rect[3] - rect[1]) - len(lines) * line_height) / 2)
        for line in lines:
            x = rect[0]
            if item["justify"] == "CENTER":
                x += ((rect[2] - rect[0]) - draw.textlength(line, font=font)) / 2
            elif item['justify'] == 'RIGHT':
                x = rect[2] - draw.textlength(line, font=font)
            draw.text((x, y), line, font=font, fill=rgba(item["color"] or [1, 1, 1, 1]), anchor="lt")
            y += round(item["size"] * 1.2 * scale)
    if item["clip"]:
        clipping = Image.new("RGBA", canvas.size)
        clip = box(*item["clip"])
        crop = layer.crop(clip)
        clipping.paste(crop, (clip[0], clip[1]))
        layer = clipping
    if item.get('alpha', 1) != 1:
        layer.putalpha(layer.getchannel('A').point(lambda value: round(value * item['alpha'])))
    canvas = Image.alpha_composite(canvas, layer)

draw = ImageDraw.Draw(canvas)
font = ImageFont.truetype("C:/Windows/Fonts/segoeui.ttf", 11 * scale)
draw.text((padding * scale, (height - 19) * scale),
          "Layout preview from Lua-created frames · approximated fonts · in-game rendering still to verify",
          font=font, fill=(155, 168, 188, 255))
canvas = canvas.convert("RGB").resize((width, height), Image.Resampling.LANCZOS)
canvas.save(sys.argv[2])
print(sys.argv[2])
