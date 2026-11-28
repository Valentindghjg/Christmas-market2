"""MailboxCluster (CM2-10I): three red mailboxes with half-round tops on a dark shelf and post,
dark doors on -Y, snow on each top and a dark flag on the right box.

blender -b --factory-startup --python assets/art/source/Props/MailboxCluster/build.py -- --out assets/art/source/Props/MailboxCluster/model.blend

Origin = footprint centre on the ground, front -Y, studs, Z up. Values: docs/plans/CM2-10I.md row 5.
"""

import math
import sys

sys.path[:0] = ["tools/art/kit"]
import cm2_kit as K  # noqa: E402

FLAT = 1.0 / math.cos(math.radians(22.5))  # 8-gon radius whose flat sides sit at +-1


def build():
    K.seed(1205)
    K.box("Post", "MetalDark", (0.4, 0.4, 2.6), (0, 0, 1.3))
    K.box("Post", "MetalDark", (2.8, 0.9, 0.15), (0, 0, 2.625))
    for x in (-1.0, 0.0, 1.0):
        jit = K._rng.uniform(-0.03, 0.03)
        z0 = 2.7
        K.box("Box", "RoofRed", (0.8, 1.1, 0.5), (x, 0, z0 + 0.25))
        top = z0 + 0.5
        K.cylinder("Box", "RoofRed", 0.4 * FLAT, 1.1, (x, 0, top), rot=(90, 22.5, 0), verts=8)
        K.cylinder("Snow", "SnowWhite", 0.3 * FLAT, 1.0 + jit, (x, 0.02, top + 0.15), rot=(90, 22.5, 0), verts=8)
        K.box("Post", "MetalDark", (0.44, 0.04, 0.5), (x, -0.56, z0 + 0.42))
    # flag on the right box, raised
    K.box("Post", "MetalDark", (0.06, 0.06, 1.0), (1.43, 0.2, 3.45))
    K.box("Post", "MetalDark", (0.05, 0.42, 0.26), (1.43, 0.0, 3.82))
    # diagonal brace under the shelf
    K.box("Post", "MetalDark", (0.12, 0.12, 1.1), (0.32, 0, 2.2), rot=(0, 45, 0))
    K.collider("Box", (3.0, 1.2, 1.2), (0, 0, 3.1))
    K.collider("Post", (0.4, 0.4, 2.6), (0, 0, 1.3))


K.run(build, tier="B")
