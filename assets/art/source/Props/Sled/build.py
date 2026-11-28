"""Sled (CM2-10D): red runners curling up at the front, five wooden slats, a front bar and a
little snow on the seat. The curl points -Y.

blender -b --factory-startup --python assets/art/source/Props/Sled/build.py -- --out assets/art/source/Props/Sled/model.blend

Origin = footprint centre on the ground, front -Y, studs, Z up. Everything is shifted by OY in y
so the curl and the rear end sit symmetric about the origin. Values: docs/plans/CM2-10D.md.
"""

import math
import sys

sys.path[:0] = ["tools/art/kit"]
import cm2_kit as K  # noqa: E402

OY = 0.2


def bar(part, key, p0, p1, x, thick):
    """Square bar from p0 to p1 (both (y, z)) in the YZ plane at x."""
    dy, dz = p1[0] - p0[0], p1[1] - p0[1]
    length = math.hypot(dy, dz)
    angle = math.degrees(math.atan2(dz, dy))
    mid = (x, (p0[0] + p1[0]) / 2.0 + OY, (p0[1] + p1[1]) / 2.0)
    K.box(part, key, (thick, length + thick * 0.6, thick), mid, rot=(angle, 0, 0))


def build():
    # bevel only on the front bar and the snow: the 300-triangle budget allows no more
    K.seed(1104)
    for x in (-0.75, 0.75):
        K.box("Runners", "RoofRed", (0.15, 3.6, 0.15), (x, OY, 0.08))
        bar("Runners", "RoofRed", (-1.8, 0.08), (-2.1, 0.55), x, 0.15)
        bar("Runners", "RoofRed", (-2.1, 0.55), (-1.95, 1.1), x, 0.15)
        for y in (-1.2, 0.0, 1.2):
            K.box("Runners", "RoofRed", (0.12, 0.12, 0.5), (x, y + OY, 0.35))
    K.planks("Seat", "WoodWarm", 5, (1.74, 0.55, 0.1), (0, -1.4 + OY, 0.6), (0, 0.7, 0), bevel=0.0,
             jitter=0.03)
    K.box("Seat", "WoodWarm", (1.66, 0.14, 0.14), (0, -1.95 + OY, 1.05), bevel=0.03)
    K.snow_cap((1.4, 1.6, 0.18), (0, 0.8 + OY, 0.62))  # sunk a little into the slats
    K.collider("Sled", (1.8, 4.4, 0.8), (0, 0, 0.4))


K.run(build, tier="B")
