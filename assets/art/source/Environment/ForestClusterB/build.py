"""Forest Cluster B (CM2-10c): patch of three firs with two snowy rocks.

blender -b --factory-startup --python assets/art/source/Environment/ForestClusterB/build.py -- --out assets/art/source/Environment/ForestClusterB/model.blend

Units are studs, Z up, front = -Y (the valley side), origin = footprint centre at ground. Values: docs/plans/CM2-10c.md;
final values also in DECISION_LOG ("CM2-10c nature art (engineering)").
"""

import sys

sys.path[:0] = ["tools/art/kit", "assets/art/source/Environment", "assets/art/source/Buildings"]
import cm2_kit as K, map_common as M  # noqa: E401, E402


# (x, y), top height, base radius
FIRS = [((-2.5, 1.5), 20.0, 4.6), ((4.0, -3.0), 14.0, 3.4), ((3.5, 4.2), 11.0, 2.8)]
# centre, radius, snow cap size
ROCKS = [((-5.0, -4.5, 0.5), 1.0, (1.3, 1.2, 0.3)), ((6.5, -5.8, 0.4), 0.8, (1.0, 0.95, 0.26))]


def build():
    K.seed(183)
    for index, ((x, y), top, radius) in enumerate(FIRS, start=1):
        M.fir(top, radius, (x, y, 0), tiers=3, verts=7)
        K.collider("Trunk%d" % index, (1.4, 1.4, 6), (x, y, 3))
    for (x, y, z), r, cap in ROCKS:
        ball = K.ball("Rock", "StoneGray", r, (x, y, z), detail=0)
        # the ball's lowest vertex would sit at z - r below ground; flatten it onto the ground (bboxMin y 0)
        for v in ball.data.vertices:
            v.co.z = max(v.co.z, -z)
        K.snow_cap(cap, (x, y, z + r * 0.72))


K.run(build, tier="B")
