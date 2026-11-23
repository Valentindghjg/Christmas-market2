"""Bench (CM2-10b): park bench with dark iron side frames, wooden slats and a little snow.

blender -b --factory-startup --python assets/art/source/Props/Bench/build.py -- --out assets/art/source/Props/Bench/model.blend

The sitter faces -Y; origin = footprint centre on the ground. Units are studs, Z up. No Seat
(out of scope). Values: docs/plans/CM2-10b.md; final values also in DECISION_LOG
("CM2-10b village props art").
"""

import math
import sys

sys.path[:0] = ["tools/art/kit", "assets/art/source/Buildings"]
import cm2_kit as K  # noqa: E402

LEAN = 10.0  # back lean in degrees
BACK_Y0, BACK_Z0 = 0.62, 1.6  # foot of the back uprights


def back_y(z):
    return BACK_Y0 + (z - BACK_Z0) * math.tan(math.radians(LEAN))


def build():
    K.seed(175)
    # side frames: leg plate, armrest, leaning back upright
    for x in (-2.2, 2.2):
        K.box("Frame", "MetalDark", (0.2, 1.6, 1.5), (x, -0.1, 0.75))
        # armrest reaches the upright at the back and rests on a short front support
        K.box("Frame", "MetalDark", (0.2, 1.5, 0.15), (x, -0.1, 2.0))
        K.box("Frame", "MetalDark", (0.2, 0.15, 0.5), (x, -0.75, 1.725))
        length = 2.9 - BACK_Z0
        mid = BACK_Z0 + length / 2.0
        K.box("Frame", "MetalDark", (0.2, 0.15, length), (x, back_y(mid), mid), rot=(-LEAN, 0, 0))
    # seat slats on the leg plates, back slats on the uprights
    for y in (-0.6, -0.1, 0.4):
        K.box("Slats", "WoodWarm", (4.96, 0.45, 0.15), (0, y, 1.575))
    for z in (2.0, 2.55):
        K.box("Slats", "WoodWarm", (4.96, 0.12, 0.4), (0, back_y(z) - 0.135, z), rot=(-LEAN, 0, 0))
    # snow on the top back slat and on one seat end
    # (the thin strip on the top slat stays unbevelled to keep the 240-triangle budget)
    K.box("Snow", "SnowWhite", (4.7, 0.16, 0.1), (0, back_y(2.75) - 0.17, 2.79))
    K.snow_cap((1.3, 1.2, 0.12), (1.6, -0.12, 1.65))
    # pipeline objects
    K.collider("Seat", (5.0, 1.6, 1.6), (0, -0.1, 0.8))


K.run(build, tier="B")
