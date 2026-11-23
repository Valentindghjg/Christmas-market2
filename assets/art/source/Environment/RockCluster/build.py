"""Rock Cluster (CM2-10c): three faceted rocks with snow on their tops.

blender -b --factory-startup --python assets/art/source/Environment/RockCluster/build.py -- --out assets/art/source/Environment/RockCluster/model.blend

Units are studs, Z up, front = -Y (the valley side), origin = footprint centre at ground. Values: docs/plans/CM2-10c.md;
final values also in DECISION_LOG ("CM2-10c nature art (engineering)").
"""

import sys

sys.path[:0] = ["tools/art/kit", "assets/art/source/Environment", "assets/art/source/Buildings"]
import cm2_kit as K, map_common as M  # noqa: E401, E402


# half-extents, centre
ROCKS = [((2.4, 1.8, 1.5), (-1.2, 0.3, 1.2)), ((1.6, 1.4, 1.1), (2.2, -0.8, 0.8)), ((1.0, 0.9, 0.7), (1.4, 1.4, 0.5))]


def build():
    K.seed(184)
    for size, loc in ROCKS:
        M.rock("Rock", size, loc)
    K.collider("Rock", (6.6, 4.0, 2.2), (0.1, 0, 0.8))


K.run(build, tier="B")
