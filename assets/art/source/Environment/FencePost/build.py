"""Fence Post (CM2-13b): the post that closes a fence run.

blender -b --factory-startup --python assets/art/source/Environment/FencePost/build.py -- --out assets/art/source/Environment/FencePost/model.blend
"""

import sys

sys.path[:0] = ["tools/art/kit", "assets/art/source/Environment"]
import cm2_kit as K, fence_common as F  # noqa: E401, E402


def build():
    K.seed(146)
    F.post(0.0)
    K.collider("Post", (0.6, 0.6, 4.0), (0, 0, 2.0))


K.run(build, tier="B")
