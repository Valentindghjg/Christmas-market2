"""SnowStake (CM2-10I): thin dark road-edge marker stake with a GoldAccent reflective tip.

blender -b --factory-startup --python assets/art/source/Props/SnowStake/build.py -- --out assets/art/source/Props/SnowStake/model.blend

Origin = footprint centre on the ground, front -Y, studs, Z up. Values: docs/archive/plans/CM2-10I.md row 1.
"""

import sys

sys.path[:0] = ["tools/art/kit"]
import cm2_kit as K  # noqa: E402


def build():
    K.seed(1201)
    K.cylinder("Stake", "MetalDark", 0.12, 4.0, (0, 0, 2.0), verts=6)
    # GoldAccent is the palette key nearest to the usual orange marker tip
    K.cylinder("Tip", "GoldAccent", 0.15, 0.8, (0, 0, 4.4), verts=6)
    K.cone("Tip", "GoldAccent", 0.15, 0.0, 0.2, (0, 0, 4.9), verts=6)
    K.collider("Stake", (0.3, 0.3, 5.0), (0, 0, 2.5))


K.run(build, tier="B")
