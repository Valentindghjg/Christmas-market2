"""Sign Board (CM2-10b): wooden two-post sign with a snowy cap (welcome sign, DELIVERIES signs).

blender -b --factory-startup --python assets/art/source/Props/SignBoard/build.py -- --out assets/art/source/Props/SignBoard/model.blend

Front = -Y (the board face, y -0.2), origin = footprint centre on the ground. Units are studs, Z up.
CM2-10W puts the text on a 7.4 x 3.0 area at ATT_SignFront. Values: docs/plans/CM2-10b.md; final
values also in DECISION_LOG ("CM2-10b village props art").
"""

import sys

sys.path[:0] = ["tools/art/kit", "assets/art/source/Buildings"]
import cm2_kit as K  # noqa: E402


def build():
    K.seed(173)
    # posts sit behind the board face (y -0.15..0.45), so the text area stays clear
    for x in (-3.5, 3.5):
        K.box("Posts", "WoodWarmShade", (0.6, 0.6, 6.6), (x, 0.15, 3.3))
    K.box("Board", "WoodWarm", (8.0, 0.4, 3.6), (0, 0, 4.6), bevel=0.04)
    # snow cap overhanging the board, with a soft mound on top
    K.box("Snow", "SnowWhite", (8.6, 1.0, 0.35), (0, 0, 6.575), bevel=0.08)
    K.snow_cap((7.0, 0.7, 0.15), (0, 0.02, 6.75))
    # pipeline objects
    K.collider("Sign", (8.0, 0.6, 6.4), (0, 0, 3.2))
    K.attachment("SignFront", (0, -0.2, 4.6))


K.run(build, tier="B")
