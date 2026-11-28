"""FireStation (CM2-10I): village fire station. A cream hall 22 x 16 x 9 on a stone base with its gable
front on -Y, two red sectional bay doors 7 x 8 under timber lintels, a round gold-and-red star emblem
in the front gable, a slate roof (ridge along Y) with deep eaves and snow, a side door and two lit
windows on -X, two lit windows on +X, a stone apron to y -10 with cleared snow banks, and a bell
tower 4 x 4 at (8.5, 5.5) with an open belfry, a gold bell and a pyramid roof to z 22.

blender -b --factory-startup --python assets/art/source/Buildings/FireStation/build.py -- --out assets/art/source/Buildings/FireStation/model.blend

Origin = footprint centre on the ground, front -Y, studs, Z up. Values: docs/plans/CM2-10I.md row 13.
"""

import math
import sys

sys.path[:0] = ["tools/art/kit", "assets/art/source/Buildings"]
import cm2_kit as K, hq_common as H  # noqa: E401, E402

HX, HY = 11.0, 8.0  # hall wall faces (22 x 16)
PLINTH, TOP = 0.3, 9.0
ROOF_H, ROOF_OVER, ROOF_T = 5.0, 1.0, 0.45
ROOF_DEPTH = 18.0  # 16 walls + 2 extra so the roof reaches y +-10 with the 1.0 overhang
BAY_W, BAY_H, BAY_X = 7.0, 8.0, 4.25
TX, TY, TW = 8.5, 5.5, 4.0  # tower centre and width
BELFRY0, BELFRY1, TOWER_TOP = 14.2, 17.2, 18.0
WIN_W, WIN_H, WIN_Z = 2.2, 2.6, 3.2  # window width, height, bottom


def bay_door(cx):
    """Red sectional door 7 x 8: dark backing, four panels with a row of dark glass in the third,
    a timber lintel with snow on top and a dark handle bar."""
    y = -HY
    K.box("Metal", "MetalDark", (BAY_W, 0.1, BAY_H), (cx, y - 0.11, PLINTH + BAY_H / 2.0))
    ph = BAY_H / 4.0
    for k in range(4):
        z = PLINTH + ph * (k + 0.5)
        K.box("Doors", "RoofRed", (BAY_W - 0.2, 0.2, ph - 0.12), (cx, y - 0.25, z), bevel=0.03)
    gz = PLINTH + ph * 2.5
    for k in range(4):
        gx = cx - BAY_W / 2.0 + 0.95 + k * (BAY_W - 1.9) / 3.0
        K.box("Metal", "MetalDark", (1.2, 0.06, 0.8), (gx, y - 0.37, gz))
    K.box("Metal", "MetalDark", (1.6, 0.12, 0.14), (cx, y - 0.4, PLINTH + 1.0))
    # frame posts and lintel
    for s in (-1, 1):
        K.box("Trim", "WoodWarm", (0.3, 0.36, BAY_H), (cx + s * (BAY_W / 2.0 + 0.15), y - 0.12, PLINTH + BAY_H / 2.0))
    K.box("Trim", "WoodWarm", (BAY_W + 1.0, 0.5, 0.55), (cx, y - 0.2, PLINTH + BAY_H + 0.27), bevel=0.04)
    K.snow_cap((BAY_W + 0.8, 0.42, 0.12), (cx, y - 0.22, PLINTH + BAY_H + 0.55))


def side_window(side, yc):
    """Lit window on the side wall x = side * HX: red frame, stone sill with snow."""
    x = side * HX
    cz = WIN_Z + WIN_H / 2.0
    K.box("Window", "LightWarm", (0.1, WIN_W, WIN_H), (x + side * 0.02, yc, cz))
    for s in (-1, 1):
        K.box("Doors", "RoofRed", (0.2, 0.25, WIN_H + 0.5), (x + side * 0.06, yc + s * (WIN_W / 2.0 + 0.125), cz))
    K.box("Doors", "RoofRed", (0.2, WIN_W + 0.5, 0.25), (x + side * 0.06, yc, WIN_Z + WIN_H + 0.125))
    K.box("Doors", "RoofRed", (0.12, 0.12, WIN_H), (x + side * 0.06, yc, cz))  # mullion
    K.box("Stone", "StoneGray", (0.5, WIN_W + 0.7, 0.25), (x + side * 0.2, yc, WIN_Z - 0.125), bevel=0.04)
    K.snow_cap((0.42, WIN_W + 0.5, 0.12), (x + side * 0.2, yc, WIN_Z))


def side_door(yc):
    """Timber side door 4 x 7 on the -X wall with a red frame, a snowy lintel and a stone step."""
    x = -HX
    K.box("Trim", "WoodWarm", (0.3, 4.0, 7.0), (x - 0.06, yc, PLINTH + 3.5), bevel=0.04)
    for s in (-1, 1):
        K.box("Doors", "RoofRed", (0.4, 0.35, 7.2), (x - 0.12, yc + s * 2.17, PLINTH + 3.6))
    K.box("Doors", "RoofRed", (0.5, 4.8, 0.4), (x - 0.15, yc, PLINTH + 7.2), bevel=0.04)
    K.snow_cap((0.45, 4.6, 0.12), (x - 0.17, yc, PLINTH + 7.4))
    K.box("Metal", "MetalDark", (0.12, 0.2, 0.6), (x - 0.26, yc + 1.4, PLINTH + 3.4))
    K.box("Stone", "StoneGray", (1.1, 5.0, 0.3), (x - 0.55, yc, 0.15), bevel=0.05)


def emblem(cx, y, cz):
    """Round emblem: gold rim, red disc, gold star (no text)."""
    K.cylinder("Gold", "GoldAccent", 1.4, 0.1, (cx, y + 0.02, cz), rot=(90, 0, 0), verts=10)
    K.cylinder("Doors", "RoofRed", 1.18, 0.16, (cx, y - 0.06, cz), rot=(90, 0, 0), verts=10)
    H.star((cx, y - 0.2, cz), 1.6, "GoldAccent", depth=0.1)


def tower():
    """Bell tower 4 x 4 at (TX, TY): cream shaft rising out of the roof, stone cornice, open belfry
    on four timber corner posts with a gold bell on a dark yoke, timber top band, slate pyramid
    roof with snow and a gold finial."""
    h = TW / 2.0
    K.box("Walls", "FabricCream", (TW, TW, BELFRY0 - TOP), (TX, TY, (TOP + BELFRY0) / 2.0))
    K.box("Doors", "RoofRed", (TW + 0.12, TW + 0.12, 0.4), (TX, TY, BELFRY0 - 0.9))  # red band
    K.box("Stone", "StoneGray", (TW + 0.5, TW + 0.5, 0.35), (TX, TY, BELFRY0 + 0.1), bevel=0.05)
    K.snow_cap((TW + 0.4, TW + 0.4, 0.14), (TX, TY, BELFRY0 + 0.27))
    for sx in (-1, 1):
        for sy in (-1, 1):
            K.box("Trim", "WoodWarm", (0.7, 0.7, BELFRY1 - BELFRY0), (TX + sx * (h - 0.35), TY + sy * (h - 0.35), (BELFRY0 + BELFRY1) / 2.0))
    K.box("Trim", "WoodWarm", (TW + 0.2, TW + 0.2, TOWER_TOP - BELFRY1), (TX, TY, (BELFRY1 + TOWER_TOP) / 2.0), bevel=0.04)
    # yoke and bell
    K.box("Metal", "MetalDark", (TW - 0.8, 0.3, 0.3), (TX, TY, BELFRY1 - 0.35))
    K.box("Metal", "MetalDark", (0.3, 0.3, 0.4), (TX, TY, BELFRY1 - 0.7))
    K.cone("Gold", "GoldAccent", 0.95, 0.45, 1.3, (TX, TY, BELFRY1 - 1.5), verts=8)
    K.cylinder("Gold", "GoldAccent", 1.02, 0.18, (TX, TY, BELFRY1 - 2.12), verts=8)
    # pyramid roof (overhang 0.6) with snow on its upper part and a gold finial
    half = h + 0.6
    K.cone("Roof", "RoofSlate", half * math.sqrt(2), 0.0, 4.0, (TX, TY, TOWER_TOP + 2.0), rot=(0, 0, 45), verts=4)
    z0 = TOWER_TOP + 1.5
    snow_half = half * (TOWER_TOP + 4.0 - z0) / 4.0 + 0.1
    K.cone("Snow", "SnowWhite", snow_half * math.sqrt(2), 0.0, TOWER_TOP + 4.15 - z0, (TX, TY, (z0 + TOWER_TOP + 4.15) / 2.0), rot=(0, 0, 45), verts=4)
    K.ball("Gold", "GoldAccent", 0.25, (TX, TY, TOWER_TOP + 4.25), detail=0)


def build():
    K.seed(1213)
    # walls stop 0.2 under the eave line so their top corners stay inside the roof slabs
    K.box("Walls", "FabricCream", (2 * HX, 2 * HY, TOP - 0.2 - PLINTH), (0, 0, (PLINTH + TOP - 0.2) / 2.0), bevel=0.05)
    K.box("Stone", "StoneGray", (2 * HX + 0.4, 2 * HY + 0.4, PLINTH), (0, 0, PLINTH / 2.0), bevel=0.06)
    K.box("Stone", "StoneGray", (2 * HX + 0.2, 2 * HY + 0.2, 1.0), (0, 0, PLINTH + 0.5))  # base band
    # stone corner pilasters and a centre pier between the bays
    for sx in (-1, 1):
        for sy in (-1, 1):
            K.box("Stone", "StoneGray", (0.8, 0.8, TOP - 0.6 - PLINTH), (sx * (HX - 0.3), sy * (HY - 0.3), (PLINTH + TOP - 0.6) / 2.0))
    K.box("Stone", "StoneGray", (1.0, 0.3, TOP - PLINTH), (0, -HY - 0.05, (PLINTH + TOP) / 2.0))
    # timber wall plates under the eaves
    # (the side plates sit 0.9 under the wall top and the gable plates stop short of the corners,
    # so none pokes through the roof slabs)
    for sy in (-1, 1):
        K.box("Trim", "WoodWarm", (2 * HX - 0.3, 0.35, 0.4), (0, sy * (HY + 0.08), TOP - 0.35), bevel=0.03)
    for sx in (-1, 1):
        K.box("Trim", "WoodWarm", (0.35, 2 * HY + 0.3, 0.4), (sx * (HX + 0.08), 0, TOP - 1.1), bevel=0.03)
    # front: two bay doors, emblem in the gable, dark downpipes at the corners
    for s in (-1, 1):
        bay_door(s * BAY_X)
        K.box("Metal", "MetalDark", (0.22, 0.22, TOP - 1.0), (s * (HX - 0.05), -HY - 0.35, (TOP - 1.0) / 2.0 + 0.1))
    emblem(0.0, -HY - 0.05, 11.2)
    # sides: side door and two windows on -X, two windows on +X (clear of the tower)
    side_door(-4.0)
    for yc in (1.6, 5.4):
        side_window(-1, yc)
    for yc in (-4.6, -0.6):
        side_window(1, yc)
    # gable (0.3 low so its slopes stay inside the roof slabs), slate roof with deep eaves and snow
    K.prism("Gable", "FabricCream", 2 * HX, 2 * HY, ROOF_H, (0, 0, TOP - 0.3))
    K.gable_roof("Roof", "RoofSlate", 2 * HX, ROOF_DEPTH, ROOF_H, TOP, overhang=ROOF_OVER, thickness=ROOF_T, snow=False)
    H.gable_snow(2 * HX, ROOF_DEPTH, ROOF_H, TOP, ROOF_OVER, cover=0.62, segments=7)
    tower()
    # stone apron to y -10 with cleared snow banks on both sides
    K.box("Stone", "StoneGray", (2 * HX - 1.0, 2.0, 0.12), (0, -HY - 1.0, 0.06))
    for s in (-1, 1):
        K.box("Snow", "SnowWhite", (1.6, 2.0, 0.7), (s * (HX - 0.2), -HY - 1.0, 0.35), bevel=0.12)
    # pipeline objects
    K.collider("Hall", (22, 16, 9), (0, 0, 4.5))
    K.collider("Tower", (4.4, 4.4, 18), (TX, TY, 9))


K.run(build, tier="A")
