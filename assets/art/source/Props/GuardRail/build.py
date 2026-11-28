"""GuardRail (CM2-10I): rustic road rail of three squared timber posts and two bark logs that end
flush at x +-4 so rails chain; light end grain, snow on the logs and post tops.

blender -b --factory-startup --python assets/art/source/Props/GuardRail/build.py -- --out assets/art/source/Props/GuardRail/model.blend

Origin = footprint centre on the ground, front -Y, studs, Z up. Values: docs/plans/CM2-10I.md row 6.
"""

import math
import sys

sys.path[:0] = ["tools/art/kit"]
from mathutils import Matrix  # noqa: E402

import cm2_kit as K  # noqa: E402

HALF = 3.995  # log ends, flush with the chain neighbour at x +-4
LOG_R = 0.22


def end_grain(x, z, side):
    """One flat hexagon face (4 triangles) facing +-X, matching the log's flat-top hexagon."""
    verts = []
    for i in range(6):
        a = math.radians(30 + 60 * i)
        verts.append((x + side * 0.004, LOG_R * 0.92 * math.sin(a), z - LOG_R * 0.92 * math.cos(a)))
    face = list(range(6)) if side > 0 else list(reversed(range(6)))
    obj = K._mesh_object("EndGrain_WoodWarm", verts, [face])
    K._finish_shape(obj, "Logs", "WoodWarm", (0, 0, 0), (0, 0, 0), 0.0)


def build():
    K.seed(1206)
    for x in (-3.5, 0.0, 3.5):
        h = 2.42 + K._rng.uniform(-0.04, 0.04)
        K.box("Posts", "WoodWarm", (0.5, 0.5, h), (x, 0, h / 2.0))
        K.cone("Snow", "SnowWhite", 0.36, 0.2, 0.14, (x, 0, h + 0.07), rot=(0, 0, 45), verts=4)
    for z in (1.4, 2.1):
        log = K.cylinder("Logs", "BarkBrown", LOG_R, 2 * HALF, (0, 0, z), rot=(0, 90, 0), verts=6)
        log.data.transform(Matrix.Rotation(math.radians(30), 4, "Z"))  # flat top face
        K.snow_cap((2 * HALF - 0.5, 0.26, 0.1), (0, 0, z + LOG_R * 0.866 - 0.01))
        end_grain(-HALF, z, -1)
        end_grain(HALF, z, 1)
    K.collider("Rail", (8.0, 0.6, 2.4), (0, 0, 1.2))


K.run(build, tier="B")
