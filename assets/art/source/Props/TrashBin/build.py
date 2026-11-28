"""TrashBin (CM2-10I): green flared bin on a dark foot ring, two dark bands, front slot, dark lid with
a snow cap. Faces -Y.

blender -b --factory-startup --python assets/art/source/Props/TrashBin/build.py -- --out assets/art/source/Props/TrashBin/model.blend

Origin = footprint centre on the ground, front -Y, studs, Z up. Values: docs/plans/CM2-10I.md row 3.
"""

import math
import sys

sys.path[:0] = ["tools/art/kit"]
import cm2_kit as K  # noqa: E402


def build():
    K.seed(1203)
    K.cylinder("Frame", "MetalDark", 0.7, 0.16, (0, 0, 0.08), rot=(0, 0, 22.5), verts=8)
    K.cone("Bin", "RoofGreen", 0.65, 0.75, 2.2, (0, 0, 1.26), rot=(0, 0, 22.5), verts=8)
    K.cylinder("Frame", "MetalDark", 0.745, 0.12, (0, 0, 1.95), rot=(0, 0, 22.5), verts=8)
    K.cylinder("Frame", "MetalDark", 0.69, 0.12, (0, 0, 0.62), rot=(0, 0, 22.5), verts=8)
    # throw-in slot, nearly flush with the front face
    face = (0.65 + 0.1 * (2.18 - 0.16) / 2.2) * math.cos(math.radians(22.5))
    K.box("Frame", "MetalDark", (0.42, 0.06, 0.18), (0, -face, 2.18))
    K.cone("Frame", "MetalDark", 0.78, 0.55, 0.25, (0, 0, 2.485), rot=(0, 0, 22.5), verts=8)
    K.cone("Snow", "SnowWhite", 0.57, 0.28, 0.2, (0, 0, 2.7), rot=(0, 0, 22.5), verts=8)
    K.collider("Bin", (1.4, 1.4, 2.6), (0, 0, 1.3))


K.run(build, tier="B")
