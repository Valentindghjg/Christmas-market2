"""Mountain Ridge (CM2-10c): long faceted ridge with three summits.

blender -b --factory-startup --python assets/art/source/Environment/MountainRidge/build.py -- --out assets/art/source/Environment/MountainRidge/model.blend

Units are studs, Z up, front = -Y (the valley side), origin = footprint centre at ground (base sunk to z -12). Values: docs/plans/CM2-10c.md;
final values also in DECISION_LOG ("CM2-10c nature art (engineering)").
"""

import sys

sys.path[:0] = ["tools/art/kit", "assets/art/source/Environment", "assets/art/source/Buildings"]
import cm2_kit as K, map_common as M  # noqa: E401, E402


SPEC = {
    "part": "Mountain",
    "width": 300.0,
    "length": 150.0,
    "step": 12.5,
    "summits": [(-75.0, 0.0, 112.0, 110.0, 75.0), (37.5, 0.0, 92.0, 95.0, 70.0), (112.5, 0.0, 82.0, 60.0, 55.0)],
    "snow_line": 51.0,  # plan 60.0, lowered 15 % in review so the caps read as snow
}


def build():
    K.seed(186)
    M.heightfield(SPEC)
    K.collider("Core", (20, 20, 20), (0, 0, 10))


K.run(build, tier="B")
