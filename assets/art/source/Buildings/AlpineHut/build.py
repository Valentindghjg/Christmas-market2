"""Alpine Hut (CM2-13a, HQ tier 3): closed log hut on a stone base, slate gable roof, sales hatch.

blender -b --factory-startup --python assets/art/source/Buildings/AlpineHut/build.py -- --out assets/art/source/Buildings/AlpineHut/model.blend
"""

import math
import sys

sys.path[:0] = ["tools/art/kit", "assets/art/source/Buildings"]
import cm2_kit as K, hq_common as H  # noqa: E401, E402

BASE = 1.2
WX, WY = 11.0, 7.0  # log centre lines of the side and front/back walls
R, PITCH, OVER = 0.4, 0.75, 0.6  # log radius, course pitch, log ends past the corners
EAVE, RIDGE, SPAN, ROOF_OVER, ROOF_T, ROOF_DEPTH = 8.5, 14.5, 24.0, 1.8, 0.4, 16.0
HATCH = (-5.0, 5.0, 3.6, 7.1)  # x0, x1, sill z, top z
DOOR = (5.5, 9.5, BASE, BASE + 7.0)


def cut(x0, x1, holes):
    """Split [x0, x1] by the holes [(a, b), ...] (sorted)."""
    parts, start = [], x0
    for a, b in holes:
        if a > start:
            parts.append((start, a))
        start = max(start, b)
    if start < x1:
        parts.append((start, x1))
    return [(a, b) for a, b in parts if b - a > 0.9]


def walls():
    end = WX + OVER
    for index in range(9):  # front and back: courses 1.6 .. 7.6
        z = BASE + R + PITCH * index
        holes = [(DOOR[0] - 0.3, DOOR[1])]
        if HATCH[2] - R < z < HATCH[3] + R:
            holes.insert(0, (HATCH[0], HATCH[1] + 0.5))
        for a, b in cut(-end, end, holes):
            H.log("Logs", "BarkBrown", "X", a, b, (-WY, z), R, cap_key="BarkBrownShade",
                  ends=(a <= -end, b >= end))
        H.log("Logs", "BarkBrown", "X", -end, end, (WY, z), R, cap_key="BarkBrownShade")
    for index in range(9):  # sides, half a course higher
        z = BASE + R + PITCH * (index + 0.5)
        for sx in (-1, 1):
            H.log("Logs", "BarkBrown", "Y", -WY - OVER, WY + OVER, (sx * WX, z), R, cap_key="BarkBrownShade")
    # gable fills above the top course, vertical battens on the front one
    top = BASE + R + PITCH * 8 + R
    width = 2 * (WX + 0.4)
    height = (RIDGE - 0.45) - top - 0.35
    for sy in (-1, 1):
        K.prism("Gable", "WoodWarm", width, 0.3, height, (0, sy * WY, top))
    for x in (-8.0, -5.0, -2.0, 2.0, 5.0, 8.0):
        h = height * (1 - abs(x) / (width / 2.0)) - 0.25
        K.box("Gable", "BarkBrownShade", (0.2, 0.12, h), (x, -WY - 0.2, top + h / 2.0))
    K.box("Gable", "BarkBrownShade", (1.5, 0.12, 1.5), (0, -WY - 0.2, top + 2.0))
    K.box("Gable", "LightWarm", (1.1, 0.14, 1.1), (0, -WY - 0.22, top + 2.0))


def hatch():
    x0, x1, sill, top = HATCH
    K.box("Hatch", "WoodWarm", (x1 - x0 + 0.8, 1.6, 0.22), (0, -WY - 0.4, sill - 0.11), bevel=0.04)
    for x in (x0 - 0.25, x1 + 0.25):
        K.box("Hatch", "WoodWarm", (0.5, 0.9, top - sill + 0.4), (x, -WY, (sill + top) / 2.0 + 0.05))
    K.box("Hatch", "WoodWarm", (x1 - x0 + 1.0, 0.9, 0.4), (0, -WY, top + 0.2))
    # shutter hinged at the top, propped up 45 degrees, with two props from the sill
    length, hinge_y, hinge_z = 3.0, -WY - 0.5, top + 0.3
    d = math.sqrt(0.5)
    K.box("Shutter", "WoodWarm", (x1 - x0 + 0.4, 0.2, length),
          (0, hinge_y - d * length / 2.0, hinge_z + d * length / 2.0), rot=(45, 0, 0), bevel=0.04)
    for x in (x0 + 0.6, x1 - 0.6):
        a = (x, -WY - 0.9, sill)
        b = (x, hinge_y - d * length * 0.75, hinge_z + d * length * 0.75)
        mid = ((a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0, (a[2] + b[2]) / 2.0)
        ang = math.degrees(math.atan2(a[1] - b[1], b[2] - a[2]))
        K.box("Shutter", "BarkBrownShade", (0.14, 0.14, math.dist(a, b)), mid, rot=(ang, 0, 0))


def door():
    x0, x1, z0, z1 = DOOR
    K.planks("Door", "WoodWarm", 4, (0.96, 0.22, z1 - z0), ((x0 + 0.5), -WY - 0.05, (z0 + z1) / 2.0),
             (1.0, 0, 0), jitter=0.0)
    K.box("Door", "BarkBrownShade", (x1 - x0 + 0.6, 0.5, 0.45), ((x0 + x1) / 2.0, -WY - 0.15, z1 + 0.2))
    K.box("Door", "BarkBrownShade", (x1 - x0 - 0.4, 0.1, 0.3), ((x0 + x1) / 2.0, -WY - 0.2, z0 + 4.6))
    K.box("Step", "StoneGrayShade", (x1 - x0 + 0.6, 1.0, BASE - 0.5), ((x0 + x1) / 2.0, -8.5, (BASE - 0.5) / 2.0),
          bevel=0.05)
    H.lantern((x1 + 1.1, -WY - 0.75, 6.4), "BarkBrownShade")
    K.box("Door", "BarkBrownShade", (0.12, 0.6, 0.12), (x1 + 1.1, -WY - 0.45, 7.05))


def windows():
    for sx in (-1, 1):
        x = sx * (WX + 0.38)
        for y in (-3.2, 3.2):
            z = 4.6
            K.box("Window", "WoodWarm", (0.14, 2.5, 2.5), (x, y, z))
            K.box("Window", "LightWarm", (0.16, 2.0, 2.0), (x + sx * 0.03, y, z))
            K.box("Window", "WoodWarm", (0.4, 2.7, 0.18), (x + sx * 0.12, y, z - 1.32))
            K.snow_cap((0.42, 2.6, 0.16), (x + sx * 0.12, y, z - 1.23))
            for sy in (-1, 1):
                K.box("Window", "WoodWarm", (0.12, 1.05, 2.3), (x + sx * 0.1, y + sy * 1.85, z))


def roof():
    K.gable_roof("Roof", "RoofSlate", SPAN, ROOF_DEPTH, RIDGE - EAVE, EAVE, overhang=ROOF_OVER,
                 thickness=ROOF_T, snow=False)
    H.gable_snow(SPAN, ROOF_DEPTH, RIDGE - EAVE, EAVE, ROOF_OVER, cover=0.6)
    half = SPAN / 2.0 + ROOF_OVER
    pitch = (RIDGE - EAVE) / (SPAN / 2.0)
    ang = math.degrees(math.atan(pitch))
    slope = math.hypot(half, half * pitch)
    for sy in (-1, 1):
        y = sy * (ROOF_DEPTH / 2.0 + ROOF_OVER + 0.06)
        for sx in (-1, 1):
            cx = sx * half / 2.0
            cz = RIDGE - half / 2.0 * pitch - 0.3
            K.box("Fascia", "RoofSlateShade", (slope, 0.14, 0.5), (cx, y, cz), rot=(0, sx * ang, 0))
    # chimney (StoneGrayShade) at (8, 5), top 16.0 incl. snow
    K.box("Chimney", "StoneGrayShade", (1.6, 1.6, 6.2), (8.0, 5.0, 9.5 + 3.1))
    K.box("Chimney", "StoneGrayShade", (2.0, 2.0, 0.3), (8.0, 5.0, 15.6))
    K.snow_cap((1.9, 1.9, 0.25), (8.0, 5.0, 15.75))


def build():
    K.seed(133)
    K.box("Base", "StoneGray", (24.0, 16.0, BASE), (0, 0, BASE / 2.0), bevel=0.08)
    for sx in (-1, 1):
        for sy in (-1, 1):
            K.box("Base", "StoneGrayShade", (1.2, 1.2, 0.62), (sx * 11.45, sy * 7.45, 0.33))
            K.box("Base", "StoneGrayShade", (0.9, 0.9, 0.5), (sx * 11.6, sy * 7.6, 0.9))
    walls()
    hatch()
    door()
    windows()
    roof()
    top = H.desk((0, 5.0, BASE), 6, "BarkBrownShade")
    H.radio((2.0, 5.0, top[2]), "WoodWarm")
    # garland around the hatch (no bows) with 7 warm bulbs along its top
    x0, x1, sill, htop = HATCH
    y = -WY - 0.75
    H.garland((x0 - 0.6, y, htop + 0.1), (x1 + 0.6, y, htop + 0.1), 0, None, sag=0.35)
    for x in (x0 - 0.6, x1 + 0.6):
        H.garland((x, y, htop - 0.35), (x, y, sill + 0.3), 0, None, sag=0.0)
    K.string_lights((x0 - 0.6, y - 0.3, htop + 0.0), (x1 + 0.6, y - 0.3, htop + 0.0), 7, sag=0.35,
                    radius=0.2, wire=False)
    # pipeline objects
    K.collider("Base", (24.0, 16.0, BASE), (0, 0, BASE / 2.0))
    K.collider("Body", (2 * WX + 0.8, 2 * WY + 0.8, EAVE - BASE), (0, 0, (BASE + EAVE) / 2.0))
    K.collider("Step", (4.6, 1.0, BASE - 0.5), (7.5, -8.5, (BASE - 0.5) / 2.0))
    K.attachment("Entrance", (7.5, -8.0, 0))
    K.attachment("Computer", (0, 5.0, top[2]))
    K.attachment("Radio", (2.0, 5.0, top[2]))


K.run(build, tier="A")
