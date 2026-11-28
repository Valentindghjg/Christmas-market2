"""RoadSignDirection (CM2-10I): squared timber post with a capped top and two warm wood arrow
boards (top points +X, bottom -X) with a notched tail, dark bark trim strips and snow on top.
The board text is added by CM2-10IW at SignTop and SignBottom (board front plane y -0.2).

blender -b --factory-startup --python assets/art/source/Props/RoadSignDirection/build.py -- --out assets/art/source/Props/RoadSignDirection/model.blend

Origin = footprint centre on the ground, front -Y, studs, Z up. Values: docs/plans/CM2-10I.md row 9.
"""

import sys

sys.path[:0] = ["tools/art/kit", "assets/art/source/Buildings"]
import cm2_kit as K, hq_common as H  # noqa: E401, E402

HALF, TIP, NOTCH, BOARD_H = 2.5, 0.45, 0.3, 0.9
FRONT, BACK = -0.2, -0.05  # board faces (0.15 thick), front 0.02 proud of the post


def arrow(z, direction):
    """Arrow board centred at x 0, height BOARD_H around z, pointing to +X (direction 1) or -X."""
    h = BOARD_H / 2.0
    d = direction
    outline = [(-d * HALF, -h), (d * (HALF - TIP), -h), (d * HALF, 0.0), (d * (HALF - TIP), h),
               (-d * HALF, h), (-d * (HALF - NOTCH), 0.0), (d * (HALF - TIP), 0.0)]
    verts = [(x, FRONT, z + dz) for x, dz in outline] + [(x, BACK, z + dz) for x, dz in outline]
    o = len(outline)
    front = [(0, 1, 6, 5), (5, 6, 3, 4), (1, 2, 6), (6, 2, 3)]
    faces = front + [tuple(o + i for i in reversed(f)) for f in front]
    rim = [0, 1, 2, 3, 4, 5]
    for i in range(len(rim)):
        a, b = rim[i], rim[(i + 1) % len(rim)]
        faces.append((a, b, o + b, o + a))
    H.mesh("Boards", "WoodWarm", verts, faces)
    # dark trim strip along the lower front edge and snow on the straight top edge
    start, end = -HALF + 0.15, HALF - TIP - 0.1
    K.box("Post", "BarkBrown", (end - start, 0.05, 0.1), (d * (start + end) / 2.0, FRONT - 0.02, z - h + 0.08))
    K.snow_cap((2 * HALF - TIP - 0.25, 0.17, 0.1), (-d * TIP / 2.0, (FRONT + BACK) / 2.0, z + h - 0.01))


def build():
    K.seed(1209)
    K.box("Post", "BarkBrown", (0.36, 0.36, 7.2), (0, 0, 3.6), bevel=0.04)
    # pyramid cap with snow
    K.cone("Boards", "WoodWarm", 0.33, 0.0, 0.22, (0, 0, 7.2 + 0.11), rot=(0, 0, 45), verts=4)
    K.cone("Snow", "SnowWhite", 0.3, 0.0, 0.2, (0, 0, 7.2 + 0.2), rot=(0, 0, 45), verts=4)
    arrow(6.4, 1)
    arrow(5.2, -1)
    # snow drift around the foot
    K.cone("Snow", "SnowWhite", 0.3, 0.18, 0.3, (0, 0, 0.15), rot=(0, 0, 45), verts=6)
    K.collider("Post", (0.4, 0.4, 7.2), (0, 0, 3.6))
    K.attachment("SignTop", (0, -0.2, 6.4))
    K.attachment("SignBottom", (0, -0.2, 5.2))


K.run(build, tier="B")
