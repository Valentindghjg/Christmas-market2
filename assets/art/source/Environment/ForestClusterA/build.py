"""Forest Cluster A (CM2-10c): patch of five firs of varied heights.

blender -b --factory-startup --python assets/art/source/Environment/ForestClusterA/build.py -- --out assets/art/source/Environment/ForestClusterA/model.blend

Units are studs, Z up, front = -Y (the valley side), origin = footprint centre at ground. Values: docs/plans/CM2-10c.md;
final values also in DECISION_LOG ("CM2-10c nature art (engineering)").
"""

import sys

sys.path[:0] = ["tools/art/kit", "assets/art/source/Environment", "assets/art/source/Buildings"]
import cm2_kit as K, map_common as M  # noqa: E401, E402


# (x, y), top height, base radius, needle key, tiers
FIRS = [
    ((-3.0, 2.0), 28.0, 6.0, "NeedleGreen", 4),
    ((6.0, -4.0), 22.0, 5.0, "NeedleGreenShade", 4),
    ((-6.0, -6.5), 18.0, 4.2, "NeedleGreen", 3),
    ((6.5, 6.0), 15.0, 3.6, "NeedleGreenShade", 3),
    ((-8.0, 7.5), 12.0, 3.0, "NeedleGreen", 3),
]
# y of the third fir -6 -> -6.5 (plan latitude) so the hexagon footprints meet the L contract
# the tiers=3 build had 700 triangles (<= 800), so the two tallest firs use tiers=4 (plan rule)


def build():
    K.seed(182)
    for index, ((x, y), top, radius, key, tiers) in enumerate(FIRS, start=1):
        M.fir(top, radius, (x, y, 0), tiers=tiers, verts=6, needle_key=key)
        K.collider("Trunk%d" % index, (1.4, 1.4, 6), (x, y, 3))


K.run(build, tier="B")
