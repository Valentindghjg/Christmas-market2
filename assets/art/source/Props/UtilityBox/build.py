"""UtilityBox (CM2-10I): green street cabinet on a shade plinth, two shade doors on -Y with
handles, a shade rain cap and snow on top.

blender -b --factory-startup --python assets/art/source/Props/UtilityBox/build.py -- --out assets/art/source/Props/UtilityBox/model.blend

Origin = footprint centre on the ground, front -Y, studs, Z up. Values: docs/plans/CM2-10I.md row 4.
"""

import sys

sys.path[:0] = ["tools/art/kit"]
import cm2_kit as K  # noqa: E402


def build():
    K.seed(1204)
    K.box("Plinth", "RoofGreenShade", (2.5, 1.5, 0.25), (0, 0, 0.125))
    K.box("Cabinet", "RoofGreen", (2.4, 1.4, 2.9), (0, 0, 1.7), bevel=0.05)
    K.box("Plinth", "RoofGreenShade", (2.6, 1.6, 0.16), (0, 0, 3.23))
    K.snow_cap((2.45, 1.45, 0.16), (0, 0, 3.31))
    for x in (-0.56, 0.56):
        K.box("Plinth", "RoofGreenShade", (1.0, 0.06, 2.4), (x, -0.69, 1.7))
        K.box("Plinth", "RoofGreenShade", (0.08, 0.12, 0.4), (x * 0.25, -0.74, 1.8))
    K.collider("Box", (2.4, 1.4, 3.2), (0, 0, 1.6))


K.run(build, tier="B")
