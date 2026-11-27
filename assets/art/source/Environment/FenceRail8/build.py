"""Fence Rail 8 v3 (CM2-GATE): lantern post, two snowy rails and a lit garland, one 8-stud back-edge segment.

blender -b --factory-startup --python assets/art/source/Environment/FenceRail8/build.py -- --out assets/art/source/Environment/FenceRail8/model.blend
"""

import sys

sys.path[:0] = ["tools/art/kit", "assets/art/source/Environment"]
import cm2_kit as K, fence_common as F  # noqa: E401, E402

LENGTH = 8.0


def build():
    K.seed(144)
    F.post(-LENGTH / 2.0)
    F.rails(LENGTH)
    F.garland(-LENGTH / 2.0 + 0.45, LENGTH / 2.0 - 0.45, 4.6, 0.7, -0.3, 8, 0.12, 3, 0.1, 0.14)
    K.collider("Fence", (LENGTH, 0.9, 4.0), (0, 0, 2.0))


K.run(build, tier="A")
