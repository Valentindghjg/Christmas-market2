"""Fence Post v3 (CM2-GATE): the post that closes a fence run, with a lantern cap.

blender -b --factory-startup --python assets/art/source/Environment/FencePost/build.py -- --out assets/art/source/Environment/FencePost/model.blend
"""

import sys

sys.path[:0] = ["tools/art/kit", "assets/art/source/Environment"]
import cm2_kit as K, fence_common as F  # noqa: E401, E402


def build():
    K.seed(146)
    F.post(0.0)
    K.collider("Post", (0.9, 0.9, 5.0), (0, 0, 2.5))


K.run(build, tier="A")
