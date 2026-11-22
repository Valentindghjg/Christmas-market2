"""Mountain Chalet (CM2-13a, HQ tier 4): stone ground floor, timber upper floor with balcony, red gable roof.

blender -b --factory-startup --python assets/art/source/Buildings/MountainChalet/build.py -- --out assets/art/source/Buildings/MountainChalet/model.blend
"""

import math
import sys

sys.path[:0] = ["tools/art/kit", "assets/art/source/Buildings"]
import cm2_kit as K, hq_common as H  # noqa: E401, E402

BX, BY = 13.0, 9.0  # body half sizes (26 x 18)
GROUND, UPPER = 7.5, 13.0  # top of the stone floor, eave
RIDGE, ROOF_OVER, ROOF_T = 18.0, 2.5, 0.5
WINDOW = (-3.5, 8.5, 3.6, 7.1)  # sales window x0, x1, sill z, top z
DOOR = (-11.0, -6.0, 0.0, 7.0)
BALCONY_D = 1.8


def ground_floor():
    K.box("Stone", "StoneGray", (2 * BX, 2 * BY, GROUND), (0, 0, GROUND / 2.0), bevel=0.08)
    # quoins: alternating long and short blocks on every corner
    for sx in (-1, 1):
        for sy in (-1, 1):
            for k in range(5):
                z = 0.75 + k * 1.4
                lx, ly = (1.4, 0.9) if k % 2 == 0 else (0.9, 1.4)
                K.box("Stone", "StoneGrayShade", (lx, ly, 1.1),
                      (sx * (BX - lx / 2.0 + 0.08), sy * (BY - ly / 2.0 + 0.08), z))
    # sales window: sill, frame, warm interior panel, two mullions
    x0, x1, sill, top = WINDOW
    cx, w = (x0 + x1) / 2.0, x1 - x0
    K.box("Window", "LightWarm", (w, 0.1, top - sill), (cx, -BY - 0.02, (sill + top) / 2.0))
    K.box("Window", "WoodWarm", (w + 0.8, 1.0, 0.24), (cx, -BY - 0.4, sill - 0.12), bevel=0.04)
    K.box("Window", "WoodWarmShade", (w + 0.6, 0.3, 0.45), (cx, -BY - 0.1, top + 0.2))
    for x in (x0 - 0.15, x1 + 0.15):
        K.box("Window", "WoodWarmShade", (0.4, 0.3, top - sill), (x, -BY - 0.1, (sill + top) / 2.0))
    for x in (cx - w / 6.0, cx + w / 6.0):
        K.box("Window", "WoodWarmShade", (0.22, 0.16, top - sill), (x, -BY - 0.06, (sill + top) / 2.0))
    # double door with frame and two lanterns
    d0, d1, z0, z1 = DOOR
    K.planks("Door", "WoodWarm", 4, (1.18, 0.2, z1 - z0), (d0 + 0.65, -BY - 0.06, (z0 + z1) / 2.0),
             (1.23, 0, 0), jitter=0.0)
    K.box("Door", "WoodWarmShade", (d1 - d0 + 0.8, 0.3, 0.45), ((d0 + d1) / 2.0, -BY - 0.12, z1 + 0.2))
    for x in (d0 - 0.2, d1 + 0.2):
        K.box("Door", "WoodWarmShade", (0.4, 0.3, z1 - z0), (x, -BY - 0.12, (z0 + z1) / 2.0))
    for x in (d0 - 1.0, d1 + 1.0):
        H.lantern((x, -BY - 0.45, 5.6), "WoodWarmShade")
        K.box("Door", "WoodWarmShade", (0.1, 0.45, 0.1), (x, -BY - 0.22, 6.25))


def upper_floor():
    h = UPPER - GROUND
    K.box("Upper", "WoodWarmShade", (2 * BX - 0.1, 2 * BY - 0.1, h), (0, 0, GROUND + h / 2.0))
    # vertical boards on the front and both sides
    K.planks("Boards", "WoodWarm", 20, (1.22, 0.12, h - 0.7), (-BX + 0.65, -BY - 0.02, GROUND + h / 2.0),
             (1.3, 0, 0), bevel=0.0, jitter=0.05)
    for sx in (-1, 1):  # sides: a board face with dark battens
        K.box("Boards", "WoodWarm", (0.12, 2 * BY - 0.3, h - 0.7), (sx * (BX + 0.02), 0, GROUND + h / 2.0))
        for k in range(6):
            y = -BY + 1.5 + 3.0 * k
            K.box("Beams", "WoodWarmShade", (0.2, 0.25, h - 0.7), (sx * (BX + 0.1), y, GROUND + h / 2.0))
    # beams: floor band, top band, corner posts
    for z in (GROUND + 0.25, UPPER - 0.4):
        for sy in (-1, 1):
            K.box("Beams", "WoodWarmShade", (2 * BX + 0.3, 0.3, 0.5), (0, sy * (BY + 0.05), z))
        for sx in (-1, 1):
            K.box("Beams", "WoodWarmShade", (0.3, 2 * BY + 0.3, 0.5), (sx * (BX + 0.05), 0, z))
    # three windows with warm panes and open shutters
    for x in (-7.5, 0.0, 7.5):
        z = GROUND + h / 2.0 + 0.1
        K.box("UpWindow", "WoodWarmShade", (2.9, 0.2, 3.4), (x, -BY - 0.1, z))
        K.box("UpWindow", "LightWarm", (2.5, 0.22, 3.0), (x, -BY - 0.12, z))
        K.box("UpWindow", "WoodWarmShade", (0.18, 0.26, 3.0), (x, -BY - 0.13, z))
        for sx in (-1, 1):
            K.box("UpWindow", "WoodWarmShade", (1.2, 0.14, 3.2), (x + sx * 2.1, -BY - 0.2, z))


def balcony():
    y = -BY - BALCONY_D / 2.0
    K.box("Balcony", "WoodWarmShade", (2 * BX + 0.4, BALCONY_D, 0.4), (0, y, GROUND - 0.2), bevel=0.05)
    for x in (-10.5, -3.5, 3.5, 10.5):
        K.box("Balcony", "WoodWarmShade", (0.4, BALCONY_D - 0.2, 0.4), (x, y + 0.1, GROUND - 0.75),
              rot=(-25, 0, 0))
    # railing of cut-out boards: wide and narrow boards alternate, the gaps read as cut-outs
    yr = -BY - BALCONY_D + 0.15
    K.planks("Railing", "WoodWarm", 17, (0.6, 0.12, 1.0), (-BX + 0.2, yr, GROUND + 0.55), (1.6, 0, 0),
             bevel=0.0)
    K.planks("Railing", "WoodWarm", 16, (0.26, 0.12, 1.0), (-BX + 1.0, yr, GROUND + 0.55), (1.6, 0, 0),
             bevel=0.0)
    for z, hh in ((GROUND + 1.15, 0.2), (GROUND + 0.1, 0.16)):
        K.box("Railing", "WoodWarm", (2 * BX + 0.4, 0.22, hh), (0, yr, z), bevel=0.03)
    for sx in (-1, 1):
        K.box("Railing", "WoodWarm", (0.22, BALCONY_D - 0.2, 0.2), (sx * (BX + 0.1), y + 0.05, GROUND + 1.15))
        K.planks("Railing", "WoodWarm", 2, (0.12, 0.5, 1.0), (sx * (BX + 0.1), y - 0.3, GROUND + 0.55),
                 (0, 0.8, 0), bevel=0.0)
    K.snow_cap((2 * BX + 0.3, 0.28, 0.14), (0, yr, GROUND + 1.25))
    # garland along the balcony with gold baubles instead of bows
    points = H.garland((-BX, yr - 0.3, GROUND + 1.15), (BX, yr - 0.3, GROUND + 1.15), 0, None, sag=0.45,
                       spacing=0.5)
    H.baubles(points, "GoldAccent", radius=0.18, every=6, drop=0.35)


def roof():
    span = 2 * BX
    K.gable_roof("Roof", "RoofRed", span, 2 * BY, RIDGE - UPPER, UPPER, overhang=ROOF_OVER,
                 thickness=ROOF_T, snow=False)
    H.gable_snow(span, 2 * BY, RIDGE - UPPER, UPPER, ROOF_OVER, cover=0.55)
    half = span / 2.0 + ROOF_OVER
    pitch = (RIDGE - UPPER) / (span / 2.0)
    ang = math.degrees(math.atan(pitch))
    slope = math.hypot(half, half * pitch)
    for sy in (-1, 1):
        for sx in (-1, 1):
            K.box("Fascia", "RoofRedShade", (slope, 0.16, 0.6),
                  (sx * half / 2.0, sy * (BY + ROOF_OVER + 0.07), RIDGE - half / 2.0 * pitch - 0.38),
                  rot=(0, sx * ang, 0))
    # gable fills with the gold star in the front one
    height = (RIDGE - 0.55) - UPPER - 0.1
    for sy in (-1, 1):
        K.prism("Gable", "WoodWarm", span, 0.3, height, (0, sy * BY, UPPER))
    H.star((0, -BY - 0.25, UPPER + 2.0), 1.6, "GoldAccent")
    # chimney (StoneGray) at (-8, 5), top 20.0 incl. snow
    K.box("Chimney", "StoneGray", (1.8, 1.8, 5.5), (-8.0, 5.0, 14.0 + 2.75))
    K.box("Chimney", "StoneGrayShade", (2.2, 2.2, 0.3), (-8.0, 5.0, 19.6))
    K.snow_cap((2.1, 2.1, 0.25), (-8.0, 5.0, 19.75))


def build():
    K.seed(134)
    ground_floor()
    upper_floor()
    balcony()
    roof()
    top = H.desk((0, 6.0, 0.0), 7)
    H.radio((2.2, 6.0, top[2]), "WoodWarmShade")
    # pipeline objects
    K.collider("Body", (2 * BX, 2 * BY, UPPER), (0, 0, UPPER / 2.0))
    K.collider("Balcony", (2 * BX + 0.4, BALCONY_D, 1.7), (0, -BY - BALCONY_D / 2.0, GROUND + 0.45))
    K.collider("Sill", (WINDOW[1] - WINDOW[0] + 0.8, 1.0, 0.3), ((WINDOW[0] + WINDOW[1]) / 2.0, -BY - 0.4,
                                                              WINDOW[2] - 0.15))
    K.attachment("Entrance", ((DOOR[0] + DOOR[1]) / 2.0, -BY, 0))
    K.attachment("Computer", (0, 6.0, top[2]))
    K.attachment("Radio", (2.2, 6.0, top[2]))


K.run(build, tier="A")
