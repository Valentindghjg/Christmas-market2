"""Forest Fir (CM2-10c): single background fir for the lot reserve and the plot gaps.

blender -b --factory-startup --python assets/art/source/Environment/ForestFir/build.py -- --out assets/art/source/Environment/ForestFir/model.blend

Units are studs, Z up, front = -Y (any side), origin = trunk foot. Values: docs/plans/CM2-10c.md;
final values also in DECISION_LOG ("CM2-10c nature art (engineering)").
"""

import sys

sys.path[:0] = ["tools/art/kit", "assets/art/source/Environment", "assets/art/source/Buildings"]
import cm2_kit as K, map_common as M  # noqa: E401, E402


def build():
    K.seed(181)
    M.fir(16.0, 4.5, (0, 0, 0), tiers=3, verts=7)
    K.collider("Trunk", (1.4, 1.4, 6), (0, 0, 3))
    K.attachment("TreeBase", (0, 0, 0))


K.run(build, tier="B")
