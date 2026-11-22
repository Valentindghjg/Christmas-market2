"""Fence Rail 8 (CM2-13b): start post plus two snowy rails, one 8-stud back-edge segment.

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
    K.collider("Fence", (LENGTH, 0.6, 3.2), (0, 0, 1.6))


K.run(build, tier="B")
