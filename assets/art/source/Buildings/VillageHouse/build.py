"""Village House (CM2-10b): snowy alpine two-storey house for the village square (not enterable).

blender -b --factory-startup --python assets/art/source/Buildings/VillageHouse/build.py -- --out assets/art/source/Buildings/VillageHouse/model.blend

Front = -Y (gable, door and wreath face -Y), origin = footprint centre on the ground. Units are
studs, Z up. Every wall shape is named `Paint` (one MeshPart that CM2-10W recolours per house).
Values: docs/plans/CM2-10b.md; final values also in DECISION_LOG ("CM2-10b village props art").
"""

import math
import sys

sys.path[:0] = ["tools/art/kit", "assets/art/source/Buildings"]
import cm2_kit as K, hq_common as H  # noqa: E401, E402

WALL_X, WALL_Y = 9.8, 7.8  # wall faces (walls 19.6 x 15.6, z 2..12)
FLOOR, TOP, BELT = 2.0, 12.0, 7.0
WIN_W, WIN_H, FRAME = 2.2, 2.4, 0.25
WIN_Z = (3.5, 8.0)  # window bottoms (lower and upper storey)


def brace(x0, z0, x1, z1, y):
    """Diagonal 0.3 x 0.3 timber in the front wall plane from (x0, z0) to (x1, z1)."""
    length = math.hypot(x1 - x0, z1 - z0)
    angle = math.degrees(math.atan2(x1 - x0, z1 - z0))
    K.box("Timber", "WoodWarmShade", (0.3, 0.2, length), ((x0 + x1) / 2.0, y, (z0 + z1) / 2.0), rot=(0, angle, 0))


def front_window(x, z0, shutters=True, sill_snow=True):
    """LightWarm window on the front wall (0.05 proud), WoodWarmShade frame with a deeper sill,
    RoofRed shutters on both sides."""
    y = -WALL_Y
    cz = z0 + WIN_H / 2.0
    K.box("Window", "LightWarm", (WIN_W, 0.1, WIN_H), (x, y, cz))
    half_w = WIN_W / 2.0 + FRAME / 2.0
    for sx in (-1, 1):
        K.box("Timber", "WoodWarmShade", (FRAME, 0.2, WIN_H + 2 * FRAME), (x + sx * half_w, y - 0.05, cz))
    K.box("Timber", "WoodWarmShade", (WIN_W + 2 * FRAME, 0.2, FRAME), (x, y - 0.05, z0 + WIN_H + FRAME / 2.0))
    K.box("Timber", "WoodWarmShade", (WIN_W + 0.8, 0.5, FRAME), (x, y - 0.2, z0 - FRAME / 2.0), bevel=0.04)
    if sill_snow:
        K.snow_cap((WIN_W + 0.6, 0.4, 0.12), (x, y - 0.22, z0))
    if shutters:
        off = WIN_W / 2.0 + FRAME + 0.5
        for sx in (-1, 1):
            K.box("Shutters", "RoofRed", (1.0, 0.15, WIN_H), (x + sx * off, y - 0.08, cz), bevel=0.03)


def side_window(side, z0):
    """LightWarm window on the side wall x = side * WALL_X at y 0, with a WoodWarmShade frame."""
    x = side * WALL_X
    cz = z0 + WIN_H / 2.0
    K.box("Window", "LightWarm", (0.1, WIN_W, WIN_H), (x, 0, cz))
    half_w = WIN_W / 2.0 + FRAME / 2.0
    for sy in (-1, 1):
        K.box("Timber", "WoodWarmShade", (0.2, FRAME, WIN_H + 2 * FRAME), (x + side * 0.05, sy * half_w, cz))
    for z in (z0 - FRAME / 2.0, z0 + WIN_H + FRAME / 2.0):
        K.box("Timber", "WoodWarmShade", (0.2, WIN_W + 2 * FRAME, FRAME), (x + side * 0.05, 0, z))


def wreath(cx, y, cz):
    for index in range(8):
        ang = math.radians(90 + 45 * index)
        K.ball("Wreath", "NeedleGreen", 0.4, (cx + 1.2 * math.cos(ang), y, cz + 1.2 * math.sin(ang)), detail=0)
    H.bow((cx, y - 0.35, cz - 1.2), "RoofRed", 0.9)


def build():
    K.seed(172)
    # walls first, so the FabricCream MeshPart is named Paint
    K.box("Paint", "FabricCream", (2 * WALL_X, 2 * WALL_Y, TOP - FLOOR), (0, 0, (FLOOR + TOP) / 2.0), bevel=0.05)
    # stone plinth and two front steps
    K.box("Plinth", "StoneGray", (20.0, 16.0, 2.0), (0, 0, 1.0), bevel=0.15)
    K.box("Steps", "StoneGrayShade", (6.0, 0.8, 0.7), (0, -9.2, 0.35), bevel=0.05)
    K.box("Steps", "StoneGrayShade", (6.0, 0.8, 1.35), (0, -8.4, 0.675), bevel=0.05)
    # half-timbering: corner posts, belt beam (split round the door), braces on the upper front
    for sx in (-1, 1):
        for sy in (-1, 1):
            # top at 11.8 so the post corners stay under the roof slab at the eaves
            K.box("Timber", "WoodWarmShade", (0.6, 0.6, 9.8), (sx * WALL_X, sy * WALL_Y, 6.9), bevel=0.04)
    for sx in (-1, 1):
        K.box("Timber", "WoodWarmShade", (7.9, 0.4, 0.4), (sx * 6.15, -WALL_Y - 0.1, BELT), bevel=0.04)
        K.box("Timber", "WoodWarmShade", (0.4, 2 * WALL_Y, 0.4), (sx * (WALL_X + 0.1), 0, BELT), bevel=0.04)
    K.box("Timber", "WoodWarmShade", (2 * WALL_X, 0.4, 0.4), (0, WALL_Y + 0.1, BELT), bevel=0.04)
    for sx in (-1, 1):
        brace(sx * 9.35, BELT + 0.2, sx * 8.75, TOP - 0.2, -WALL_Y - 0.1)
        brace(sx * 2.6, BELT + 0.2, sx * 3.4, TOP - 0.2, -WALL_Y - 0.1)
    # attic gable and slate roof with snow on its upper part
    K.prism("Gable", "WoodWarm", 2 * WALL_X, 2 * WALL_Y, 8.0, (0, 0, TOP))
    K.gable_roof("Roof", "RoofSlate", 20.0, 16.0, 8.0, TOP, overhang=1.6, thickness=0.4, snow=False)
    H.gable_snow(20.0, 16.0, 8.0, TOP, 1.6, cover=0.6)
    # stone chimney with a snow cap (its foot sits inside the roof on the low side too)
    K.box("Chimney", "StoneGray", (2.0, 2.0, 7.0), (5.0, 3.0, 18.5), bevel=0.06)
    K.box("Snow", "SnowWhite", (2.4, 2.4, 0.3), (5.0, 3.0, 22.15), bevel=0.1)
    # front: door with a frame, wreath above it, windows with shutters
    K.box("Door", "WoodWarm", (4.0, 0.3, 7.0), (0, -WALL_Y - 0.05, FLOOR + 3.5), bevel=0.04)
    for sx in (-1, 1):
        K.box("Timber", "WoodWarmShade", (0.35, 0.4, 7.2), (sx * 2.15, -WALL_Y - 0.1, FLOOR + 3.6), bevel=0.04)
    K.box("Timber", "WoodWarmShade", (4.8, 0.45, 0.4), (0, -WALL_Y - 0.12, FLOOR + 7.2), bevel=0.04)
    K.snow_cap((4.6, 0.4, 0.12), (0, -WALL_Y - 0.15, FLOOR + 7.4))
    K.box("Timber", "WoodWarmShade", (0.5, 0.1, 0.5), (1.3, -WALL_Y - 0.25, FLOOR + 3.4))  # door handle
    wreath(0, -WALL_Y - 0.25, 11.0)  # clear of the door lintel and its snow
    for x in (-6.0, 6.0):
        for z0 in WIN_Z:
            front_window(x, z0)
    front_window(0, 13.3, shutters=False)  # attic window in the front gable
    # sides: two windows each at y 0; back wall plain with the belt beam
    for side in (-1, 1):
        for z0 in WIN_Z:
            side_window(side, z0)
    # pipeline objects
    K.collider("Body", (20.0, 16.0, 12.0), (0, 0, 6.0))
    K.attachment("Entrance", (0, -9.6, 0))


K.run(build, tier="A")
