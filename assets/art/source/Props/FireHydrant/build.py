"""FireHydrant (CM2-10I): red pillar hydrant on a dark flange, pointed dome with a snow cap and a
dark nut, side outlets on +-X and a pumper outlet on -Y.

blender -b --factory-startup --python assets/art/source/Props/FireHydrant/build.py -- --out assets/art/source/Props/FireHydrant/model.blend

Origin = footprint centre on the ground, front -Y, studs, Z up. Values: docs/plans/CM2-10I.md row 2.
"""

import sys

sys.path[:0] = ["tools/art/kit"]
import cm2_kit as K  # noqa: E402


def build():
    K.seed(1202)
    K.cylinder("Base", "MetalDark", 0.55, 0.2, (0, 0, 0.1), verts=8)
    K.cylinder("Body", "RoofRed", 0.42, 1.7, (0, 0, 1.05), verts=8)
    K.cylinder("Body", "RoofRed", 0.5, 0.14, (0, 0, 1.88), verts=8)
    K.cone("Body", "RoofRed", 0.46, 0.0, 0.55, (0, 0, 2.22), verts=8)
    K.cone("Snow", "SnowWhite", 0.36, 0.0, 0.45, (0, 0, 2.33), verts=8)
    K.cylinder("Base", "MetalDark", 0.13, 0.2, (0, 0, 2.5), verts=6)
    # side outlets: one dark rod through the body, caps at x +-0.56
    K.cylinder("Base", "MetalDark", 0.14, 1.12, (0, 0, 1.45), rot=(0, 90, 0), verts=6)
    # pumper outlet on the front
    K.cylinder("Base", "MetalDark", 0.2, 0.36, (0, -0.52, 1.3), rot=(90, 0, 0), verts=6)
    K.collider("Body", (1.0, 1.0, 2.2), (0, 0, 1.1))


K.run(build, tier="B")
