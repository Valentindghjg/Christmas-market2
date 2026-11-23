"""Mountain Peak (CM2-10c): faceted snowy main peak with a side summit.

blender -b --factory-startup --python assets/art/source/Environment/MountainPeak/build.py -- --out assets/art/source/Environment/MountainPeak/model.blend

Units are studs, Z up, front = -Y (the valley side), origin = footprint centre at ground (base sunk to z -12). Values: docs/plans/CM2-10c.md;
final values also in DECISION_LOG ("CM2-10c nature art (engineering)").
"""

import sys

sys.path[:0] = ["tools/art/kit", "assets/art/source/Environment", "assets/art/source/Buildings"]
import cm2_kit as K, map_common as M  # noqa: E401, E402


SPEC = {
    "part": "Mountain",
    "width": 220.0,
    "length": 180.0,
    "step": 10.0,
    "summits": [(10.0, 0.0, 162.0, 110.0, 90.0), (-60.0, 30.0, 104.0, 50.0, 40.0)],
    "snow_line": 81.0,  # plan 95.0, lowered 15 % in review so the caps read as snow
}


def build():
    K.seed(185)
    M.heightfield(SPEC)
    K.collider("Core", (20, 20, 20), (0, 0, 10))


K.run(build, tier="B")
