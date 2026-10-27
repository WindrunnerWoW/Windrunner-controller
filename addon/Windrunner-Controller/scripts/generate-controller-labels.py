"""Draw bare controller symbols for the action-bar label option (Pillow)."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1] / "textures" / "controller-labels"
SIZE, SCALE = 128, 3
FONT = "C:/Windows/Fonts/segoeuib.ttf"
COLORS = {"a": (128, 209, 139), "b": (248, 115, 119),
          "x": (115, 187, 242), "y": (250, 218, 105)}
PS_COLORS = {"a": (139, 200, 242), "b": (249, 134, 139),
             "x": (235, 170, 224), "y": (123, 218, 172)}


def canvas():
    image = Image.new("RGBA", (SIZE * SCALE, SIZE * SCALE))
    return image, ImageDraw.Draw(image)


def save(image, relative):
    path = ROOT / (relative + ".tga")
    path.parent.mkdir(parents=True, exist_ok=True)
    image.resize((SIZE, SIZE), Image.Resampling.LANCZOS).save(path, compression=None)


def text(label, color):
    image, draw = canvas()
    size = 116 * SCALE
    while True:
        font = ImageFont.truetype(FONT, size)
        left, top, right, bottom = draw.textbbox((0, 0), label, font=font, stroke_width=3 * SCALE)
        if right - left <= 116 * SCALE:
            break
        size -= SCALE
    x = (SIZE * SCALE - (right - left)) / 2 - left
    y = (SIZE * SCALE - (bottom - top)) / 2 - top
    draw.text((x, y), label, font=font, fill=(*color, 255),
              stroke_width=3 * SCALE, stroke_fill=(10, 16, 23, 240))
    return image


def shape(name, color):
    image, draw = canvas()
    def line(points, width, fill):
        draw.line([(x * SCALE, y * SCALE) for x, y in points],
                  fill=fill, width=width * SCALE, joint="curve")
    for width, ink in [(15, (10, 16, 23, 240)), (9, (*color, 255))]:
        if name == "a":  # Cross
            line([(23, 23), (105, 105)], width, ink)
            line([(105, 23), (23, 105)], width, ink)
        elif name == "b":  # Circle
            draw.ellipse((16*SCALE, 16*SCALE, 112*SCALE, 112*SCALE), outline=ink, width=width*SCALE)
        elif name == "x":  # Square
            line([(20, 20), (108, 20), (108, 108), (20, 108), (20, 20)], width, ink)
        else:  # Triangle
            line([(64, 13), (116, 109), (12, 109), (64, 13)], width, ink)
    return image


for controller in ("xbox", "ps"):
    for name in ("a", "b", "x", "y"):
        save(shape(name, PS_COLORS[name]) if controller == "ps" else text(name.upper(), COLORS[name]),
             f"{controller}/{name}")
    for name in ("lb", "rb", "lt", "rt"):
        label = ({"lb": "L1", "rb": "R1", "lt": "L2", "rt": "R2"}[name]
                 if controller == "ps" else name.upper())
        save(text(label, (245, 247, 250)), f"{controller}/{name}")

arrow, draw = canvas()
points = [(64, 13), (114, 102), (14, 102)]
draw.polygon([(x*SCALE, y*SCALE) for x, y in points], fill=(245, 247, 250, 255),
             outline=(10, 16, 23, 240), width=4*SCALE)
for name, rotation in (("up", 0), ("left", 90), ("down", 180), ("right", 270)):
    save(arrow.rotate(rotation), name)
print(f"Generated 20 bare controller labels in {ROOT}")
