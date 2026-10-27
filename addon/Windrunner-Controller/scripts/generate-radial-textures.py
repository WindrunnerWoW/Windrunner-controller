"""Build the neutral, alpha-edged wheel art used by the Vanilla radial menu.

Requires Pillow and numpy. Run from any directory; output is rooted to this file.
All runtime assets are uncompressed, power-of-two, 32-bit TGA textures.
"""

from pathlib import Path

import numpy as np
from PIL import Image


OUTPUT = Path(__file__).resolve().parents[1] / "textures" / "radial"
OUTPUT.mkdir(parents=True, exist_ok=True)


def coordinates(size):
    y, x = np.mgrid[:size, :size]
    x = (x + 0.5 - size / 2) / (size / 2)
    y = (y + 0.5 - size / 2) / (size / 2)
    return np.hypot(x, y), np.arctan2(x, -y)


def ramp(value, edge, feather):
    return np.clip((value - edge) / feather + 0.5, 0, 1)


def save(name, alpha, shade=1):
    size = alpha.shape[0]
    pixels = np.empty((size, size, 4), dtype=np.uint8)
    pixels[:, :, :3] = np.clip(np.asarray(shade) * 255, 0, 255).astype(np.uint8)[..., None]
    pixels[:, :, 3] = np.clip(alpha * 255, 0, 255).astype(np.uint8)
    Image.fromarray(pixels).save(OUTPUT / f"{name}.tga", compression=None)


radius, angle = coordinates(128)
feather = 2 / 128
save("disc", 1 - ramp(radius, 0.95, feather))
save("ring", ramp(radius, 0.86, feather) * (1 - ramp(radius, 0.94, feather)))
save("glow", np.exp(-((radius - 0.79) / 0.11) ** 2) * (1 - ramp(radius, 0.98, feather)))

radius, angle = coordinates(512)
feather = 2 / 512
inner, outer = 94 / 176, 0.985
annulus = ramp(radius, inner, feather) * (1 - ramp(radius, outer, feather))
step = 2 * np.pi / 12
sector_angle = (angle + step / 2) % step - step / 2
boundary_distance = step / 2 - np.abs(sector_angle)
gaps = ramp(boundary_distance * radius, 0.004, feather)
shade = 0.84 + 0.16 * np.clip((outer - radius) / (outer - inner), 0, 1)
save("wheel", annulus * gaps, shade)

outer_edge = 1 - ramp(np.abs(radius - (outer - 0.006)), 0.004, feather)
inner_edge = 1 - ramp(np.abs(radius - (inner + 0.006)), 0.004, feather)
dividers = (1 - ramp(boundary_distance * radius, 0.002, feather)) * 0.55
save("wheel-border", annulus * np.maximum(np.maximum(outer_edge, inner_edge), dividers))

selected = 1 - ramp(np.abs(angle), step / 2 - 0.012, feather)
save("sector", annulus * selected * (0.65 + 0.35 * np.clip((radius - inner) / (outer - inner), 0, 1)))
print(f"Generated six radial textures in {OUTPUT}")
