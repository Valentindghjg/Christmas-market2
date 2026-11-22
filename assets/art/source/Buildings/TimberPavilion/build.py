"""Timber Pavilion (CM2-13a, HQ tier 2): open timber frame on a stone plinth, stepped green hip roof.

blender -b --factory-startup --python assets/art/source/Buildings/TimberPavilion/build.py -- --out assets/art/source/Buildings/TimberPavilion/model.blend
"""

import sys

sys.path[:0] = ["tools/art/kit", "assets/art/source/Buildings"]
import cm2_kit as K, hq_common as H  # noqa: E401, E402

FLOOR = 0.6
POSTS = [(x, y) for y in (-7.0, 7.0) for x in (-10.0, 0.0, 10.0)]
FOOT_TOP = FLOOR + 1.3
BEAM_Z = 8.2  # beam centre; 0.8 square, so its top meets the roof underside
BEAM_BOTTOM = BEAM_Z - 0.4
# hip roof: eave half sizes, eave and ridge heights (top surface of band 0), ridge half length
ROOF_A, ROOF_B, EAVE_Z, RIDGE_Z, RIDGE_R, ROOF_T = 11.7, 8.7, 8.0, 12.6, 3.0, 0.3
BANDS = (0.0, 0.36, 0.68)
STEP = 0.12
# Amendment 1: r 0.35 / spacing 0.65, maxTriangles 4000
GARLAND_SPACING, GARLAND_RADIUS = 0.65, 0.35


def hip(f0, lift, thick, key, part):
    """Hip roof shell from slope fraction f0 up to the ridge, raised by lift."""
    def at(f, sx, sy):
        return (sx * (ROOF_A + (RIDGE_R - ROOF_A) * f), sy * ROOF_B * (1 - f),
                EAVE_Z + (RIDGE_Z - EAVE_Z) * f + lift)
    lo = [at(f0, -1, -1), at(f0, 1, -1), at(f0, 1, 1), at(f0, -1, 1)]
    r0, r1 = (-RIDGE_R, 0.0, RIDGE_Z + lift), (RIDGE_R, 0.0, RIDGE_Z + lift)
    top = lo + [r0, r1]
    bot = [(p[0], p[1], p[2] - thick) for p in top]
    verts = top + bot
    faces = [(0, 1, 5, 4), (1, 2, 5), (2, 3, 4, 5), (3, 0, 4),
             (10, 11, 7, 6), (11, 7, 8), (11, 10, 9, 8), (10, 6, 9),
             (0, 6, 7, 1), (1, 7, 8, 2), (2, 8, 9, 3), (3, 9, 6, 0)]
    H.mesh(part, key, verts, faces)


def roof():
    for index, f0 in enumerate(BANDS):
        hip(f0, STEP * index, ROOF_T, "RoofGreen", "Roof")
        if index >= 1:  # snow on the upper two bands, leaving a green lip at each step
            hip(f0 + 0.06, STEP * index + 0.01, 0.11, "SnowWhite", "Snow")
    z = EAVE_Z - ROOF_T / 2.0
    for sy in (-1, 1):
        K.box("Fascia", "RoofGreenShade", (2 * ROOF_A + 0.24, 0.12, 0.42), (0, sy * (ROOF_B + 0.06), z))
    for sx in (-1, 1):
        K.box("Fascia", "RoofGreenShade", (0.12, 2 * ROOF_B, 0.42), (sx * (ROOF_A + 0.06), 0, z))


def frame():
    for x, y in POSTS:
        K.box("Footings", "StoneGray", (1.3, 1.3, 1.3), (x, y, FLOOR + 0.65))
        K.post("Posts", "WoodWarmShade", BEAM_BOTTOM - FOOT_TOP, (x, y, FOOT_TOP), width=0.9)
        # 45 degree knee braces into the beams
        dirs = [(-1 if x > 0 else 1, 0)] if x != 0 else [(-1, 0), (1, 0)]
        if x != 0:
            dirs.append((0, -1 if y > 0 else 1))
        for dx, dy in dirs:
            c = (x + dx * 1.05, y + dy * 1.05, BEAM_BOTTOM - 0.6)
            K.box("Braces", "WoodWarm", (0.3, 0.3, 1.75), c, rot=(-45 * dy, 45 * dx, 0))
    for y in (-7.0, 7.0):
        K.box("Beams", "WoodWarm", (21.0, 0.8, 0.8), (0, y, BEAM_Z), bevel=0.05)
    for x in (-10.0, 10.0):
        K.box("Beams", "WoodWarm", (0.8, 15.0, 0.8), (x, 0, BEAM_Z), bevel=0.05)


def railing(a, b, count):
    """Railing 1.1 high between two floor points along X or Y: two rails plus balusters."""
    along_x = abs(b[0] - a[0]) > abs(b[1] - a[1])
    length = abs(b[0] - a[0]) if along_x else abs(b[1] - a[1])
    cx, cy = (a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0
    for z, h in ((FLOOR + 1.0, 0.2), (FLOOR + 0.35, 0.16)):
        size = (length, 0.24, h) if along_x else (0.24, length, h)
        K.box("Railing", "WoodWarm", size, (cx, cy, z))
    for k in range(count):
        t = (k + 1) / (count + 1)
        p = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
        K.box("Railing", "WoodWarm", (0.18, 0.18, 0.9), (p[0], p[1], FLOOR + 0.6))


def build():
    K.seed(132)
    K.box("Plinth", "StoneGray", (22.0, 16.0, FLOOR), (0, 0, FLOOR / 2.0), bevel=0.08)
    frame()
    roof()
    for sx in (-10.0, 10.0):
        railing((sx, -6.35), (sx, 6.35), 4)
    for x0, x1 in ((-9.35, -0.65), (0.65, 9.35)):
        railing((x0, 7.0), (x1, 7.0), 3)
    H.counter(-6.0, 5.0, -7.4, FLOOR, 4, "RoofRed")
    top = H.desk((0, 6.2, FLOOR), 7)
    H.computer((-1.5, top[1], top[2]))
    H.radio((2.2, top[1], top[2]), "WoodWarmShade")
    # garland on the front and both side beams, lanterns under the front beam
    H.garland((-10.5, -7.72, 7.75), (10.5, -7.72, 7.75), 5, "RoofRed", sag=0.7,
              spacing=GARLAND_SPACING, radius=GARLAND_RADIUS)
    for sx in (-1, 1):
        H.garland((sx * 10.72, -7.5, 7.75), (sx * 10.72, 7.5, 7.75), 5, "RoofRed", sag=0.7,
                  spacing=GARLAND_SPACING, radius=GARLAND_RADIUS, facing="X" if sx > 0 else "-X")
    for x in (-7.5, -2.5, 2.5, 7.5):
        H.lantern((x, -7.0, BEAM_BOTTOM - 1.15), "WoodWarmShade")
        K.box("Lantern", "WoodWarmShade", (0.06, 0.06, 0.5), (x, -7.0, BEAM_BOTTOM - 0.25))
    # pipeline objects
    K.collider("Plinth", (22.0, 16.0, FLOOR), (0, 0, FLOOR / 2.0))
    for index, (x, y) in enumerate(POSTS):
        K.collider("Post%d" % (index + 1), (1.3, 1.3, BEAM_BOTTOM - FLOOR), (x, y, (FLOOR + BEAM_BOTTOM) / 2.0))
    for sx in (-10.0, 10.0):
        K.collider("RailSide%s" % ("L" if sx < 0 else "R"), (0.3, 12.7, 1.1), (sx, 0, FLOOR + 0.55))
    K.collider("RailBack", (18.7, 0.3, 1.1), (0, 7.0, FLOOR + 0.55))
    K.collider("Counter", (11.0, 1.4, 3.6), (-0.5, -7.45, FLOOR + 1.8))
    K.collider("Desk", (7.0, 0.9, 3.2), (0, 6.2, FLOOR + 1.6))
    K.attachment("Entrance", (7.0, -8.0, 0))
    K.attachment("Computer", (-1.5, 6.2, top[2]))
    K.attachment("Radio", (2.2, 6.2, top[2]))


K.run(build, tier="A")
