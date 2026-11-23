"""Leaderboard Board (CM2-10b): festive wooden leaderboard with an empty cream screen under a snowy green roof.

blender -b --factory-startup --python assets/art/source/Props/LeaderboardBoard/build.py -- --out assets/art/source/Props/LeaderboardBoard/model.blend

Front = -Y (the screen faces -Y), origin = footprint centre on the ground. Units are studs, Z up.
CM2-G12 mounts an 11 x 10 screen Part at ATT_Screen and a 10 x 1.4 title Part at ATT_Title.
Values: docs/plans/CM2-10b.md; final values also in DECISION_LOG ("CM2-10b village props art").
"""

import math
import sys

sys.path[:0] = ["tools/art/kit", "assets/art/source/Buildings"]
import cm2_kit as K, hq_common as H  # noqa: E401, E402

RIDGE_Z, EAVE_Z, EAVE_Y = 17.4, 16.2, 1.5


def roof():
    """Two RoofGreen slabs with the ridge along X; the top surfaces run from the ridge to the eaves."""
    run, drop = EAVE_Y, RIDGE_Z - EAVE_Z
    angle = math.degrees(math.atan2(drop, run))
    rad = math.radians(angle)
    slab_t, snow_t, snow_len = 0.25, 0.15, 1.6
    for side in (-1, 1):
        # outward normal of this slope and the down-slope direction
        n = (side * math.sin(rad), math.cos(rad))
        d = (side * math.cos(rad), -math.sin(rad))
        mid = (side * run / 2.0, RIDGE_Z - drop / 2.0)
        rot = (-side * angle, 0, 0)
        K.box("Roof", "RoofGreen", (14.0, 1.95, slab_t),
              (0, mid[0] - n[0] * slab_t / 2.0, mid[1] - n[1] * slab_t / 2.0), rot=rot, bevel=0.04)
        # snow from the ridge down 1.6 of the 1.92 slope
        c = (d[0] * snow_len / 2.0 + n[0] * snow_t / 2.0, RIDGE_Z + d[1] * snow_len / 2.0 + n[1] * snow_t / 2.0)
        K.box("Snow", "SnowWhite", (13.8, snow_len, snow_t), (0, c[0], c[1]), rot=rot, bevel=0.08)
    # a rounded snow ridge closes the seam between the two snow layers
    H.log("Snow", "SnowWhite", "X", -6.9, 6.9, (0, RIDGE_Z + 0.06), 0.16)


def build():
    K.seed(171)
    # two six-sided log posts
    for x in (-6.4, 6.4):
        K.cylinder("Posts", "WoodWarmShade", 0.6, 16.2, (x, 0, 8.1), rot=(0, 0, 30), verts=6, bevel=0.04)
    # backboard, cream screen panel, frame bars (front faces y -0.45)
    K.box("Board", "WoodWarm", (12.4, 0.5, 12.2), (0, 0, 8.3), bevel=0.05)
    K.box("Screen", "FabricCream", (11.0, 0.1, 10.0), (0, -0.25, 8.2))
    for z in (3.0, 13.4):
        K.box("Frame", "WoodWarmShade", (11.8, 0.2, 0.4), (0, -0.35, z), bevel=0.04)
    for x in (-5.7, 5.7):
        K.box("Frame", "WoodWarmShade", (0.4, 0.2, 10.0), (x, -0.35, 8.2), bevel=0.04)
    # header plank for the title (title area 10 x 1.4)
    K.box("Board", "WoodWarm", (12.0, 0.5, 1.8), (0, -0.2, 15.3), bevel=0.05)
    roof()
    # garland across the top of the frame with red bows at both ends, gold star standing on the
    # front slope at the ridge centre (fully in front of the snow, top below the 18.0 height limit)
    chain = H.garland((-6.0, -0.5, 14.3), (6.0, -0.5, 14.3), None, None, sag=0.4)
    H.baubles(chain, "RoofRed", radius=0.2, every=6, drop=0.35)
    for x in (-6.0, 6.0):
        H.bow((x, -0.85, 14.3), "RoofRed", 1.0)
    H.star((0, -0.9, 17.15), 1.4, "GoldAccent")
    # pipeline objects
    K.collider("Board", (13.6, 1.2, 16.2), (0, 0, 8.1))
    K.attachment("Screen", (0, -0.3, 8.2))
    K.attachment("Title", (0, -0.45, 15.3))


K.run(build, tier="A")
