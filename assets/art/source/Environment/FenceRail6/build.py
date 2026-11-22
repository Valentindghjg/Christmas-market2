"""Fence Rail 6 (CM2-13b): start post plus two snowy rails, one 6-stud side-edge segment.

blender -b --factory-startup --python assets/art/source/Environment/FenceRail6/build.py -- --out assets/art/source/Environment/FenceRail6/model.blend
"""

import sys

sys.path[:0] = ["tools/art/kit", "assets/art/source/Environment"]
import cm2_kit as K, fence_common as F  # noqa: E401, E402

LENGTH = 6.0


def build():
    K.seed(145)
    F.post(-LENGTH / 2.0)
    F.rails(LENGTH)
    K.collider("Fence", (LENGTH, 0.6, 3.2), (0, 0, 1.6))


K.run(build, tier="B")
