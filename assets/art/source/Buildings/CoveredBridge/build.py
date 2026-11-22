"""Covered Bridge (CM2-10a): red covered wooden bridge with a snowy slate roof over the stream.

blender -b --factory-startup --python assets/art/source/Buildings/CoveredBridge/build.py -- --out assets/art/source/Buildings/CoveredBridge/model.blend

Length along Y, front portal at -Y, origin = deck centre at z 0 (deck top z 0.35). Units are
studs, Z up. Values: docs/plans/CM2-10a.md; final values also in DECISION_LOG
("CM2-10 map layout and landmarks").
"""

import math
import sys

sys.path[:0] = ["tools/art/kit", "assets/art/source/Buildings", "assets/art/source/Trees"]
import cm2_kit as K, hq_common as H  # noqa: E401, E402

DECK_TOP = 0.35
HALF = 24.0  # deck and walls y -24..24, portals at y +-24
WALL_X, WALL_T = 14.3, 0.4
BANDS = ((DECK_TOP, 3.6), (9.6, 12.6))  # board bands; the window band 3.6..9.6 holds the truss
BOARD_W = 2.0  # wall board width along Y (24 per band and side)
OPEN_X, OPEN_TOP = 11.0, 12.35  # portal opening x -11..11, z 0.35..12.35
GABLE_X = 14.5
ROOF_W, ROOF_D, ROOF_H, EAVE, ROOF_OVER, ROOF_T = 29.0, 50.0, 7.0, 12.6, 1.5, 0.4
PITCH = ROOF_H / (ROOF_W / 2.0)
TRUSS_Z = (3.6, 9.6)


def board(part, key, x0, x1, y0, y1, z0, top0, top1):
    """Board prism with a straight bottom at z0 and a top running from top0 (at x0) to top1 (at x1)."""
    verts = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
             (x0, y0, top0), (x1, y0, top1), (x1, y1, top1), (x0, y1, top0)]
    faces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    return H.mesh(part, key, verts, faces)


def abutments():
    for s in (-1, 1):
        K.box("Abutment", "StoneGray", (34.0, 4.0, 4.0 + DECK_TOP), (0, s * 26.0, (-4.0 + DECK_TOP) / 2), bevel=0.3)
        K.box("Abutment", "StoneGray", (34.0, 6.0, 4.05), (0, s * 21.0, (-4.0 + 0.05) / 2), bevel=0.3)
        K.box("Plinth", "StoneGrayShade", (34.2, 10.2, 0.6), (0, s * 23.0, -3.7), bevel=0.1)
        # snow drifts on the outer edges of the approach tops (the walkway stays clear)
        for side in (-1, 1):
            K.box("Snow", "SnowWhite", (2.6 + K._rng.uniform(-0.2, 0.2), 3.6, 0.6),
                  (side * 15.5, s * 26.0, DECK_TOP + 0.3), bevel=0.12)


def span():
    for x in (-10.0, 0.0, 10.0):
        K.box("Beam", "WoodWarmShade", (1.2, 37.0, 1.4), (x, 0, -0.65), bevel=0.05)
    K.planks("Deck", "WoodWarm", 24, (30.0, 1.95, 0.3), (0, -HALF + 1.0, DECK_TOP - 0.15), (0, 2.0, 0),
             bevel=0, jitter=0.04)


def walls():
    count = int(round(2 * HALF / BOARD_W))
    for side in (-1, 1):
        x = side * WALL_X
        for z0, z1 in BANDS:
            for k in range(count):
                y = -HALF + BOARD_W * (k + 0.5)
                off = 0.06 if k % 2 else -0.06  # alternate boards stand out a little: board seams read
                K.box("Wall", "RoofRed", (WALL_T, BOARD_W - 0.04, z1 - z0 + K._rng.uniform(-0.04, 0.04)),
                      (x + side * off, y, (z0 + z1) / 2), bevel=0)
        K.box("Skirt", "RoofRedShade", (WALL_T + 0.25, 2 * HALF + 0.4, 0.65), (x, 0, DECK_TOP + 0.325), bevel=0.04)
        # Howe truss in the window band: posts every 8, chords, one diagonal per panel
        z0, z1 = TRUSS_Z
        for k in range(7):
            K.box("Truss", "WoodWarmShade", (0.6, 0.6, z1 - z0), (x, max(-HALF + 0.5, min(HALF - 0.5, -HALF + 8.0 * k)), (z0 + z1) / 2))  # end posts sit inside the portals
        for zc in (z0 + 0.3, z1 - 0.3):
            K.box("Truss", "WoodWarmShade", (0.6, 2 * HALF, 0.6), (x, 0, zc))
        dz = (z1 - 0.6) - (z0 + 0.6)
        length = math.hypot(8.0, dz)
        angle = math.degrees(math.atan2(dz, 8.0))
        for k in range(6):
            yc = -HALF + 8.0 * k + 4.0
            sign = 1 if k % 2 == 0 else -1
            K.box("Truss", "WoodWarmShade", (0.45, length, 0.5), (x, yc, (z0 + z1) / 2), rot=(sign * angle, 0, 0))


def portal(s):
    y0, y1 = s * (HALF - 0.2), s * (HALF + 0.2)
    ya, yb = min(y0, y1), max(y0, y1)
    under = ROOF_T / math.cos(math.atan(PITCH)) + 0.05  # roof slab underside below its top line

    def roof_line(x):
        return EAVE + ROOF_H - under - abs(x) * PITCH

    # side boards next to the opening, then the gable boards above it, up to the roof
    for side in (-1, 1):
        for x0, x1 in ((OPEN_X, 12.8), (12.8, GABLE_X)):
            board("Portal", "RoofRed", side * x0, side * x1, ya, yb, DECK_TOP, OPEN_TOP, OPEN_TOP)
    n = 15
    for k in range(n):
        x0 = -GABLE_X + 2 * GABLE_X * k / n
        x1 = -GABLE_X + 2 * GABLE_X * (k + 1) / n
        board("Portal", "RoofRed", x0 + 0.02, x1 - 0.02, ya, yb, OPEN_TOP, roof_line(x0), roof_line(x1))
    # WoodWarm trim 0.5 around the opening (outside it, so the clear opening stays 22 x 12)
    for side in (-1, 1):
        K.box("Trim", "WoodWarm", (0.5, 0.7, OPEN_TOP - DECK_TOP + 0.5),
              (side * (OPEN_X + 0.25), s * HALF, (DECK_TOP + OPEN_TOP + 0.5) / 2))
    K.box("Trim", "WoodWarm", (2 * OPEN_X + 1.0, 0.7, 0.5), (0, s * HALF, OPEN_TOP + 0.25))
    # outer face: two lanterns and a wreath with a red bow
    face = s * (HALF + 0.2)
    for side in (-1, 1):
        H.lantern((side * 12.5, face + s * 0.31, 9.0), "WoodWarmShade")
    for k in range(10):
        a = math.radians(90 + 36 * k)
        K.ball("Wreath", "NeedleGreen", 0.55, (1.8 * math.cos(a), face + s * 0.45, 15.2 + 1.8 * math.sin(a)), detail=0)
    H.bow((0, face + s * 0.9, 15.2 - 1.8), "RoofRed", 1.1)


def build():
    K.seed(161)
    abutments()
    span()
    walls()
    for s in (-1, 1):
        portal(s)
    K.gable_roof("Roof", "RoofSlate", ROOF_W, ROOF_D, ROOF_H, EAVE, overhang=ROOF_OVER, thickness=ROOF_T, snow=False)
    H.gable_snow(ROOF_W, ROOF_D, ROOF_H, EAVE, ROOF_OVER, cover=0.6)

    K.collider("Deck", (34, 56, 0.6), (0, 0, 0.05))
    K.collider("AbutFront", (34, 10, 3.75), (0, -23, -2.125))
    K.collider("AbutBack", (34, 10, 3.75), (0, 23, -2.125))
    K.collider("WallL", (0.8, 48, 12.3), (-14.3, 0, 6.5))
    K.collider("WallR", (0.8, 48, 12.3), (14.3, 0, 6.5))
    K.attachment("PortalFront", (0, -28, DECK_TOP))
    K.attachment("PortalBack", (0, 28, DECK_TOP))


K.run(build, tier="A")
