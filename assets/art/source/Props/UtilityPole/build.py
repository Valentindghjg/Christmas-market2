"""UtilityPole (CM2-10I): tapered timber pole with a cross-arm along Y, two diagonal braces, stone
insulators at the wire attachments, climbing pegs and snow on the top, the arm and the foot.

blender -b --factory-startup --python assets/art/source/Props/UtilityPole/build.py -- --out assets/art/source/Props/UtilityPole/model.blend

Origin = footprint centre on the ground, front -Y, studs, Z up. Values: docs/plans/CM2-10I.md row 7.
"""

import math
import sys

sys.path[:0] = ["tools/art/kit"]
import cm2_kit as K  # noqa: E402

POLE_H = 17.6
ARM_Z = 16.6
ARM_T = 0.36


def build():
    K.seed(1207)
    # tapered pole r 0.45 -> 0.36, 8 sides, a little twist so it is not perfectly regular
    K.cone("Pole", "BarkBrown", 0.45, 0.36, POLE_H, (0, 0, POLE_H / 2.0), rot=(0, 0, 22.5), verts=8)
    K.cone("Snow", "SnowWhite", 0.42, 0.0, 0.3, (0, 0, POLE_H + 0.15), rot=(0, 0, 22.5), verts=8)
    # cross-arm along Y with two braces down to the pole
    K.box("Pole", "BarkBrown", (ARM_T, 3.0, ARM_T), (0, 0, ARM_Z))
    K.snow_cap((0.3, 2.9, 0.12), (0, 0, ARM_Z + ARM_T / 2.0))
    for side in (-1, 1):
        y0, z0 = side * 0.36, ARM_Z - 1.15
        y1, z1 = side * 1.0, ARM_Z - ARM_T / 2.0
        length = math.hypot(y1 - y0, z1 - z0) + 0.1
        angle = math.degrees(math.atan2(y1 - y0, z1 - z0))
        K.box("Pole", "BarkBrown", (0.16, 0.16, length), (0, (y0 + y1) / 2.0, (z0 + z1) / 2.0), rot=(-angle, 0, 0))
        # stone insulator on the arm top; its top is the wire attachment (z 17.1)
        K.cone("Insulator", "StoneGray", 0.19, 0.1, 0.42, (0, side * 1.2, 17.1 - 0.21), verts=6)
    # climbing pegs, alternating sides along Y
    for index, z in enumerate((6.5, 8.3, 10.1, 11.9)):
        side = -1 if index % 2 == 0 else 1
        K.box("Insulator", "StoneGray", (0.09, 0.62, 0.09), (0, side * 0.55, z + K._rng.uniform(-0.05, 0.05)))
    # snow drift around the foot
    K.cone("Snow", "SnowWhite", 0.5, 0.36, 0.35, (0, 0, 0.175), rot=(0, 0, 22.5), verts=8)
    K.collider("Pole", (0.8, 0.8, 17.6), (0, 0, 8.8))
    K.attachment("WireA", (0, -1.2, 17.1))
    K.attachment("WireB", (0, 1.2, 17.1))


K.run(build, tier="B")
