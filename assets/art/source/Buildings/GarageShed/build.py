"""GarageShed (CM2-10I): clapboard wooden garage (walls 8 x 7.4 x 5.5) on a stone plinth, shade
corner posts, a green gable roof along Y with snow (top about 9), a green two-leaf barn door 5 x 5 on
-Y with shade frames and cross braces, a dark sliding-door track, a small dark window on each side,
a diamond gable vent, a stone apron in front of the door and snow drifts at the front corners.

blender -b --factory-startup --python assets/art/source/Buildings/GarageShed/build.py -- --out assets/art/source/Buildings/GarageShed/model.blend

Origin = footprint centre on the ground, front -Y, studs, Z up. Values: docs/plans/CM2-10I.md row 11.
Quality B; asset.json tier A only because the plan's budget (1400 / 6) exceeds the tier B cap.
"""

import math
import sys

sys.path[:0] = ["tools/art/kit", "assets/art/source/Buildings"]
import cm2_kit as K, hq_common as H  # noqa: E401, E402

HX, HY = 4.0, 3.7  # wall faces (walls 8 x 7.4)
PLINTH, TOP = 0.4, 5.5
BOARDS = 6
DOOR_W, DOOR_H = 5.0, 5.0


def board_rows():
    """(z centre, height, outward offset) for the clapboard rows from the plinth to the wall top."""
    h = (TOP - PLINTH) / BOARDS
    return [(PLINTH + h * (i + 0.5), h + 0.06, 0.03 if i % 2 else -0.01) for i in range(BOARDS)]


def side_walls():
    for side in (-1, 1):
        for z, h, out in board_rows():
            if z + h / 2.0 > TOP - 0.1:  # keep the top board under the eave slab (it would poke through)
                z, h = z - 0.12, h - 0.24
            K.box("Walls", "WoodWarm", (0.2, 2 * HY + K._rng.uniform(-0.04, 0.04), h),
                  (side * (HX - 0.1 + out), 0, z))
    for z, h, out in board_rows():
        top_row = z + h / 2.0 > TOP - 0.1
        cut = 0.3 if top_row else 0.0  # top row ends stay under the eave slab
        K.box("Walls", "WoodWarm", (2 * HX - 2 * cut + K._rng.uniform(-0.04, 0.04), 0.2, h), (0, HY - 0.1 + out, z))
        # front: boards left and right of the door opening
        for side in (-1, 1):
            x0, x1 = DOOR_W / 2.0, HX - cut
            K.box("Walls", "WoodWarm", (x1 - x0, 0.2, h), (side * (x0 + x1) / 2.0, -HY + 0.1 - out, z))


def door_leaf(side):
    """One RoofGreen leaf (2.5 wide) of three boards, with a shade frame and a diagonal brace."""
    w = DOOR_W / 2.0
    cx = side * w / 2.0
    y = -HY - 0.02
    z0 = PLINTH
    for k in range(3):
        bx = cx - w / 2.0 + w / 6.0 + k * w / 3.0
        K.box("Door", "RoofGreen", (w / 3.0 - 0.02, 0.16, DOOR_H - 0.06), (bx, y + (0.02 if k == 1 else 0), z0 + DOOR_H / 2.0))
    fy = y - 0.12
    K.box("Trim", "WoodWarmShade", (w, 0.1, 0.3), (cx, fy, z0 + 0.15))
    K.box("Trim", "WoodWarmShade", (w, 0.1, 0.3), (cx, fy, z0 + DOOR_H - 0.15))
    K.box("Trim", "WoodWarmShade", (0.3, 0.1, DOOR_H), (cx + side * (w / 2.0 - 0.15), fy, z0 + DOOR_H / 2.0))
    # diagonal brace from the inner bottom to the outer top
    dx, dz = w - 0.5, DOOR_H - 0.6
    length = math.hypot(dx, dz)
    angle = math.degrees(math.atan2(dx, dz)) * side
    K.box("Trim", "WoodWarmShade", (0.28, 0.08, length), (cx, fy, z0 + DOOR_H / 2.0), rot=(0, angle, 0))
    # handle on the meeting edge
    K.box("Metal", "MetalDark", (0.1, 0.12, 0.7), (side * 0.35, fy - 0.06, z0 + 2.4))


def side_window(side):
    """Small dark window on a side wall with a shade frame and a snowy sill."""
    x = side * (HX + 0.03)
    z, wy, wz = 3.4, 1.6, 1.2
    K.box("Metal", "MetalDark", (0.08, wy, wz), (x, 0.6, z))
    for dy in (-1, 1):
        K.box("Trim", "WoodWarmShade", (0.12, 0.22, wz + 0.44), (x + side * 0.03, 0.6 + dy * (wy / 2.0 + 0.11), z))
    K.box("Trim", "WoodWarmShade", (0.12, wy + 0.44, 0.22), (x + side * 0.03, 0.6, z + wz / 2.0 + 0.11))
    K.box("Trim", "WoodWarmShade", (0.3, wy + 0.6, 0.18), (x + side * 0.1, 0.6, z - wz / 2.0 - 0.09))
    K.snow_cap((0.26, wy + 0.5, 0.1), (x + side * 0.1, 0.6, z - wz / 2.0))


def build():
    K.seed(1211)
    # stone plinth and a sloped apron in front of the door
    K.box("Stone", "StoneGray", (2 * HX + 0.3, 2 * HY + 0.3, PLINTH), (0, 0, PLINTH / 2.0), bevel=0.06)
    K.box("Stone", "StoneGray", (DOOR_W + 0.6, 0.7, PLINTH * 0.6), (0, -HY - 0.45, PLINTH * 0.3 + 0.07), rot=(-10, 0, 0))
    side_walls()
    # shade corner posts over the board ends
    for sx in (-1, 1):
        for sy in (-1, 1):
            # top at 5.3, under the eave slab
            K.box("Trim", "WoodWarmShade", (0.5, 0.5, 5.3 - PLINTH), (sx * (HX - 0.15), sy * (HY - 0.15), (PLINTH + 5.3) / 2.0), bevel=0.04)
    # gable ends and roof (ridge along Y at z 9 incl. slab), snow on both slopes
    K.prism("Walls", "WoodWarm", 2 * HX, 2 * HY, 3.4, (0, 0, TOP))
    K.gable_roof("Roof", "RoofGreen", 2 * HX, 2 * HY + 0.6, 3.5, TOP, overhang=0.42, thickness=0.3, snow=False)
    H.gable_snow(2 * HX, 2 * HY + 0.6, 3.5, TOP, 0.42, cover=0.78)
    # diamond vent in the front gable
    K.box("Trim", "WoodWarmShade", (0.95, 0.12, 0.95), (0, -HY - 0.04, TOP + 1.55), rot=(0, 45, 0))
    K.box("Metal", "MetalDark", (0.6, 0.12, 0.6), (0, -HY - 0.08, TOP + 1.55), rot=(0, 45, 0))
    # header beam over the door and the dark sliding-door track with two hangers
    K.box("Trim", "WoodWarmShade", (DOOR_W + 0.9, 0.3, 0.45), (0, -HY - 0.05, PLINTH + DOOR_H + 0.2), bevel=0.04)
    K.box("Metal", "MetalDark", (DOOR_W + 1.4, 0.12, 0.14), (0, -HY - 0.28, PLINTH + DOOR_H + 0.05))
    for side in (-1, 1):
        door_leaf(side)
        K.box("Metal", "MetalDark", (0.14, 0.06, 0.4), (side * 1.25, -HY - 0.3, PLINTH + DOOR_H - 0.1))
        side_window(side)
        # snow drift at the front corner
        K.cone("Snow", "SnowWhite", 0.75, 0.3, 0.42, (side * (HX - 0.45), -HY - 0.02, 0.21), rot=(0, 0, 11), verts=8)
    K.collider("Body", (8, 7.4, 5.5), (0, 0, 2.75))


K.run(build, tier="A")
