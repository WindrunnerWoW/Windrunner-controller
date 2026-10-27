"""Build original, tintable Vanilla UI art. No external images or fonts required."""
from pathlib import Path
import math
import random
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1] / 'textures' / 'ui'
ROOT.mkdir(parents=True, exist_ok=True)
SCALE = 4

def save(name, image):
    image.save(ROOT / (name + '.tga'), compression=None)

random.seed(41)
surface = Image.new('RGBA', (256, 256))
for y in range(256):
    for x in range(256):
        light = 226 + 22 * math.exp(-((x - 70) / 240) ** 2 - ((y - 10) / 140) ** 2)
        tone = round(light + random.uniform(-2, 2))
        surface.putpixel((x, y), (tone, tone, tone, 255))
save('surface', surface)

button = Image.new('RGBA', (128, 32))
for y in range(32):
    tone = round(255 - y * 1.4)
    for x in range(128):
        button.putpixel((x, y), (tone, tone, tone, 255))
save('button', button)

for name, power in [('wash', 2), ('rule', .7)]:
    img = Image.new('RGBA', (256, 32))
    for x in range(256):
        for y in range(32):
            alpha = (1 - x / 256) ** power
            if name == 'wash':
                alpha *= .55 + .45 * (1 - y / 32)
            img.putpixel((x, y), (255, 255, 255, round(alpha * 255)))
    save(name, img)

shadow = Image.new('RGBA', (128, 128))
for y in range(128):
    for x in range(128):
        distance = min(x, y, 127 - x, 127 - y)
        alpha = round(180 * min(1, distance / 9) ** 2)
        shadow.putpixel((x, y), (0, 0, 0, alpha))
save('shadow', shadow)

def drawing(size=64):
    image = Image.new('RGBA', (size * SCALE, size * SCALE))
    return image, ImageDraw.Draw(image)

def line(draw, points, width=1.5, fill=(255, 255, 255, 255)):
    draw.line([(round(x * SCALE), round(y * SCALE)) for x, y in points], fill=fill,
              width=round(width * SCALE), joint='curve')

def polygon(draw, points, fill=(255, 255, 255, 255)):
    draw.polygon([(round(x * SCALE), round(y * SCALE)) for x, y in points], fill=fill)

def ellipse(draw, bounds, width=1.5):
    draw.ellipse(tuple(round(v * SCALE) for v in bounds), outline='white', width=round(width * SCALE))

def finish(name, image, size=64):
    save(name, image.resize((size, size), Image.Resampling.LANCZOS))

# A wind-cut wing, with separate feather ribbons and an inset compass diamond.
img, draw = drawing(128)
polygon(draw, [(18, 30), (62, 46), (109, 19), (80, 51), (61, 57)])
polygon(draw, [(23, 48), (60, 63), (101, 42), (79, 68), (59, 74)])
polygon(draw, [(30, 66), (58, 80), (89, 66), (72, 88), (58, 93)])
line(draw, [(19, 95), (47, 112), (75, 107)], 1.5, (255, 255, 255, 160))
polygon(draw, [(104, 81), (111, 92), (104, 103), (97, 92)])
finish('crest', img, 128)

img, draw = drawing(32)
polygon(draw, [(13, 9), (21, 16), (13, 23)])
finish('chevron', img, 32)
img, draw = drawing(32)
polygon(draw, [(16, 9), (22, 16), (16, 23), (10, 16)])
finish('diamond', img, 32)

img, draw = drawing(256)
for radius in [117, 122]:
    ellipse(draw, (128 - radius, 128 - radius, 128 + radius, 128 + radius), .65)
for index in range(60):
    angle = math.radians(index * 6 - 90)
    major = index % 5 == 0
    inner, outer = (112, 123) if major else (119, 122)
    line(draw, [(128 + math.cos(angle) * inner, 128 + math.sin(angle) * inner),
                (128 + math.cos(angle) * outer, 128 + math.sin(angle) * outer)], 1 if major else .5)
finish('dial', img, 256)

for name in ['controller', 'appearance', 'help', 'interface', 'bars', 'bindings', 'profiles', 'gameplay']:
    img, draw = drawing(32)
    if name == 'controller':
        line(draw, [(7, 11), (11, 9), (21, 9), (25, 11), (28, 23), (24, 25), (20, 20), (12, 20), (8, 25), (4, 23), (7, 11)], 1.5)
        line(draw, [(8, 15), (14, 15)]); line(draw, [(11, 12), (11, 18)])
        ellipse(draw, (21, 13, 23, 15), 1); ellipse(draw, (24, 16, 26, 18), 1)
    elif name == 'appearance':
        line(draw, [(7, 26), (11, 17), (25, 5), (27, 11), (16, 24), (7, 26)], 1.5)
        line(draw, [(7, 26), (21, 12)]); line(draw, [(14, 20), (13, 16)]); line(draw, [(18, 16), (23, 17)])
    elif name == 'help':
        line(draw, [(16, 8), (7, 5), (5, 6), (5, 24), (16, 27), (27, 24), (27, 6), (25, 5), (16, 8), (16, 27)])
        line(draw, [(8, 12), (12, 13)], 1); line(draw, [(20, 13), (24, 12)], 1)
        line(draw, [(8, 17), (12, 18)], 1); line(draw, [(20, 18), (24, 17)], 1)
    elif name == 'interface':
        for y, x in [(8, 12), (16, 22), (24, 10)]:
            line(draw, [(5, y), (27, y)], 1)
            draw.rectangle((int((x - 2) * SCALE), int((y - 3) * SCALE), int((x + 2) * SCALE), int((y + 3) * SCALE)), fill='white')
    elif name == 'bars':
        for x, height in [(7, 9), (15, 16), (23, 22)]:
            line(draw, [(x, 27), (x, 27 - height), (x + 3, 27 - height), (x + 3, 27)], 1.5)
        line(draw, [(4, 28), (29, 28)], 1)
    elif name == 'bindings':
        line(draw, [(4, 10), (28, 10), (28, 25), (4, 25), (4, 10)], 1.5)
        for x in [9, 16, 23]:
            for y in [14, 19]:
                line(draw, [(x - 1, y), (x + 1, y)], 2)
        line(draw, [(16, 10), (16, 5), (23, 5)], 1)
    elif name == 'profiles':
        line(draw, [(8, 5), (27, 5), (27, 22)], 1)
        line(draw, [(5, 8), (24, 8), (24, 25)], 1)
        line(draw, [(3, 11), (21, 11), (21, 28), (3, 28), (3, 11)], 1.5)
        line(draw, [(7, 17), (17, 17)], 1); line(draw, [(7, 22), (14, 22)], 1)
    else:
        ellipse(draw, (5, 5, 27, 27), 1)
        polygon(draw, [(20, 9), (18, 18), (9, 23), (13, 13)])
        line(draw, [(16, 2), (16, 5)], 1); line(draw, [(16, 27), (16, 30)], 1)
    finish('nav-' + name, img, 32)

print(f'Generated {len(list(ROOT.glob("*.tga")))} original UI textures in {ROOT}')
