"""RoadSignSpeed (CM2-10I): dark metal post with a round red sign facing -Y and a white face
(the limit number is added by CM2-10IW at SignFront), snow on the disc top and at the foot.

blender -b --factory-startup --python assets/art/source/Props/RoadSignSpeed/build.py -- --out assets/art/source/Props/RoadSignSpeed/model.blend

Origin = footprint centre on the ground, front -Y, studs, Z up. Values: docs/plans/CM2-10I.md row 8.
"""

import math
import sys

sys.path[:0] = ["tools/art/kit"]
import cm2_kit as K  # noqa: E402

SIGN_Z = 6.0
DISC_R = 1.05
SIDES = 10


def build():
    K.seed(1208)
    K.cylinder("Post", "MetalDark", 0.13, 6.9, (0, 0, 3.45), verts=6)
    # red disc (back at y -0.09) and white face whose front is the SignFront plane (y -0.25)
    K.cylinder("Sign", "RoofRed", DISC_R, 0.12, (0, -0.15, SIGN_Z), rot=(90, 18, 0), verts=SIDES)
    K.cylinder("Snow", "SnowWhite", 0.8, 0.04, (0, -0.23, SIGN_Z), rot=(90, 18, 0), verts=SIDES)
    # snow on the flat top edge of the 10-gon (turned 18 degrees: edge between the 72 and 108 degree vertices)
    top = SIGN_Z + DISC_R * math.sin(math.radians(72))
    width = 2 * DISC_R * math.cos(math.radians(72))
    K.snow_cap((width + 0.06, 0.16, 0.11), (0, -0.15, top - 0.01))
    # snow drift around the foot
    K.cone("Snow", "SnowWhite", 0.28, 0.12, 0.28, (0, 0, 0.14), verts=6)
    K.collider("Post", (0.4, 0.4, 6.9), (0, 0, 3.45))
    K.attachment("SignFront", (0, -0.25, SIGN_Z))


K.run(build, tier="B")
