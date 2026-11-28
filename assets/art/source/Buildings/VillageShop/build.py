"""VillageShop (CM2-10I): two-storey village store and post office. Cream walls 20 x 14 x 12 on a
stone plinth with shade half-timbering, a slate roof with its ridge along X (eaves to the street) and a
front cross gable carrying a gold post-horn emblem on a red disc, a 6-wide lit shop window and a
4 x 7 door under a red and cream striped awning (to y -9), three upper front windows with window
boxes, one window on each side, a stone chimney to z 20 and snow on every upward face.

blender -b --factory-startup --python assets/art/source/Buildings/VillageShop/build.py -- --out assets/art/source/Buildings/VillageShop/model.blend

Origin = footprint centre on the ground, front -Y, studs, Z up. Values: docs/plans/CM2-10I.md row 12.
"""

import math
import sys

sys.path[:0] = ["tools/art/kit", "assets/art/source/Buildings"]
import cm2_kit as K, hq_common as H  # noqa: E401, E402

HX, HY = 10.0, 7.0  # wall faces (walls 20 x 14)
PLINTH, TOP, BELT = 0.6, 12.0, 8.75
KNEE = 0.8  # cream knee band between the wall top and the roof base, keeps the eaves over the windows
ROOF_BASE, ROOF_H, ROOF_T = TOP + KNEE, 5.2, 0.45
OVER_FRONT, OVER_BACK = 1.0, 1.9  # eave overhangs (the back one balances the awning for centring)
GABLE_LEN = 1.4  # main roof overhang past the gable ends (X)
PITCH = ROOF_H / HY
RIDGE = ROOF_BASE + ROOF_H
WIN_W, WIN_H, FRAME = 2.2, 2.3, 0.25
UPPER_Z = 9.35  # upper window bottoms
DOOR_X, SHOP_X = 4.6, -4.0
CROSS_W, CROSS_H = 6.0, 3.3  # front cross gable
AWN_W, AWN_D, AWN_TILT, AWN_Z = 16.0, 2.15, 24.0, 8.35


def roof_x(part, key, length, thick):
    """Two slabs with the ridge along X at RIDGE over the walls (span 2 HY); the front slab reaches
    OVER_FRONT, the back slab OVER_BACK past the eaves and GABLE_LEN past the gable ends."""
    angle = math.degrees(math.atan(PITCH))
    rad = math.radians(angle)
    for side, over in ((-1, OVER_FRONT), (1, OVER_BACK)):
        run = HY + over
        slope = math.hypot(run, run * PITCH)
        y = side * run / 2.0 - side * math.sin(rad) * thick / 2.0
        z = RIDGE - run / 2.0 * PITCH - math.cos(rad) * thick / 2.0
        K.box(part, key, (length, slope, thick), (0, y, z), rot=(-side * angle, 0, 0), bevel=0.05)


def snow_x(x0, x1, side, reach, segments, thick=0.32, edge=(True, True)):
    """Snow slab on the roof_x side `side` (-1 front, 1 back) from the ridge down to `reach` studs
    (horizontal, +-jitter) over x0..x1, with a soft scalloped lower edge (hq_common.gable_snow
    turned to a ridge along X)."""
    xs = [x0 + (x1 - x0) * k / segments for k in range(segments + 1)]
    reaches = [reach + K._rng.uniform(-0.3, 0.35) for _ in xs]
    reaches[0] = reaches[-1] = reach
    n = len(xs)
    top = [(x, 0.0, RIDGE + 0.02 + thick) for x in xs]
    top += [(x, side * u, RIDGE - u * PITCH + 0.02 + thick) for u, x in zip(reaches, xs)]
    verts = top + [(p[0], p[1], p[2] - thick) for p in top]
    b = 2 * n
    faces = []
    for k in range(n - 1):
        faces.append((k, k + 1, n + k + 1, n + k))
        faces.append((b + k, b + n + k, b + n + k + 1, b + k + 1))
        faces.append((n + k, n + k + 1, b + n + k + 1, b + n + k))
        faces.append((k + 1, k, b + k, b + k + 1))
    faces.append((0, n, b + n, b))
    faces.append((n - 1, b + n - 1, b + 2 * n - 1, 2 * n - 1))
    H.mesh("Snow", "SnowWhite", verts, faces)


def awning():
    """Striped awning (RoofRed / FabricCream, red at both ends) sloping down to the front, with a
    pointed valance, a snow strip along its upper half and two shade brackets."""
    stripes = 9
    sw = AWN_W / stripes
    t = math.radians(AWN_TILT)
    back_y = -HY - 0.02
    cy = back_y - AWN_D / 2.0 * math.cos(t)
    cz = AWN_Z - AWN_D / 2.0 * math.sin(t)
    fy = back_y - AWN_D * math.cos(t)
    fz = AWN_Z - AWN_D * math.sin(t)
    for index in range(stripes):
        key = "RoofRed" if index % 2 == 0 else "FabricCream"
        x = -AWN_W / 2.0 + sw * (index + 0.5)
        K.box("Awning", key, (sw, AWN_D, 0.12), (x, cy, cz), rot=(AWN_TILT, 0, 0), bevel=0.02)
        H.pennant("Awning", key, (x - sw / 2.0, fy - 0.02, fz), (x + sw / 2.0, fy - 0.02, fz), (x, fy - 0.02, fz - 0.55))
    # snow on the upper part: centre 0.55 down the slope, lifted onto the top face
    d = 0.55
    ny, nz = -math.sin(t), math.cos(t)
    K.box("Snow", "SnowWhite", (AWN_W - 0.5, 1.0, 0.14),
          (0, back_y - d * math.cos(t) + ny * 0.13, AWN_Z - d * math.sin(t) + nz * 0.13), rot=(AWN_TILT, 0, 0), bevel=0.05)
    for sx in (-1, 1):
        K.box("Timber", "WoodWarmShade", (0.22, 1.9, 0.22), (sx * (AWN_W / 2.0 - 0.4), cy + 0.05, cz - 0.2), rot=(AWN_TILT, 0, 0))


def beam(x0, z0, x1, z1, y, width=0.3):
    """Timber in the front wall plane from (x0, z0) to (x1, z1)."""
    length = math.hypot(x1 - x0, z1 - z0)
    angle = math.degrees(math.atan2(x1 - x0, z1 - z0))
    K.box("Timber", "WoodWarmShade", (width, 0.2, length), ((x0 + x1) / 2.0, y, (z0 + z1) / 2.0), rot=(0, angle, 0))


def frame(cx, cz, w, h, y, depth=0.2, axis="Y"):
    """Shade frame round a w x h opening centred on (cx, cz) in the wall plane at y (axis Y) or
    x (axis X; cx is then the y centre)."""
    def put(u, z, su, sz):
        if axis == "Y":
            K.box("Timber", "WoodWarmShade", (su, depth, sz), (u, y, z))
        else:
            K.box("Timber", "WoodWarmShade", (depth, su, sz), (y, u, z))
    for s in (-1, 1):
        put(cx + s * (w / 2.0 + FRAME / 2.0), cz, FRAME, h + 2 * FRAME)
    put(cx, cz + h / 2.0 + FRAME / 2.0, w + 2 * FRAME, FRAME)


def upper_window(x):
    """Lit upper front window with a shade frame and a WoodWarm window box topped with snow."""
    y = -HY
    cz = UPPER_Z + WIN_H / 2.0
    K.box("Window", "LightWarm", (WIN_W, 0.1, WIN_H), (x, y - 0.02, cz))
    frame(x, cz, WIN_W, WIN_H, y - 0.06)
    K.box("Timber", "WoodWarmShade", (0.12, 0.14, WIN_H), (x, y - 0.08, cz))  # mullion
    K.box("Boxes", "WoodWarm", (WIN_W + 0.6, 0.6, 0.55), (x, y - 0.32, UPPER_Z - 0.2), bevel=0.04)
    K.snow_cap((WIN_W + 0.5, 0.5, 0.16), (x, y - 0.32, UPPER_Z + 0.07))


def side_window(side):
    """Lit window on a side wall (lower storey, y -1.5) with a shade frame and a snowy sill."""
    x = side * HX
    cz, yc = 3.9, -1.5
    K.box("Window", "LightWarm", (0.1, WIN_W, WIN_H), (x + side * 0.02, yc, cz))
    frame(yc, cz, WIN_W, WIN_H, x + side * 0.06, axis="X")
    K.box("Timber", "WoodWarmShade", (0.5, WIN_W + 0.7, 0.22), (x + side * 0.2, yc, cz - WIN_H / 2.0 - 0.11), bevel=0.04)
    K.snow_cap((0.42, WIN_W + 0.5, 0.12), (x + side * 0.2, yc, cz - WIN_H / 2.0))


def shop_front():
    """Shop window 6 x 4 (three panes) on a WoodWarm riser, and the 4 x 7 door with a lit pane."""
    y = -HY
    # shop window
    sw, sh, sz = 6.0, 4.0, 1.7
    cz = sz + sh / 2.0
    K.box("Window", "LightWarm", (sw, 0.1, sh), (SHOP_X, y - 0.02, cz))
    frame(SHOP_X, cz, sw, sh, y - 0.06)
    for dx in (-1, 1):
        K.box("Timber", "WoodWarmShade", (0.16, 0.16, sh), (SHOP_X + dx * sw / 6.0, y - 0.08, cz))
    K.box("Boxes", "WoodWarm", (sw + 0.5, 0.3, sz - PLINTH), (SHOP_X, y - 0.12, (PLINTH + sz) / 2.0), bevel=0.04)
    K.box("Timber", "WoodWarmShade", (sw + 0.9, 0.55, 0.22), (SHOP_X, y - 0.26, sz - 0.11), bevel=0.04)
    K.snow_cap((sw + 0.7, 0.45, 0.12), (SHOP_X, y - 0.28, sz))
    # door 4 x 7 with a lit pane, frame, gold handle and a stone step
    K.box("Boxes", "WoodWarm", (4.0, 0.3, 7.0), (DOOR_X, y - 0.06, PLINTH + 3.5), bevel=0.04)
    K.box("Window", "LightWarm", (1.6, 0.06, 2.2), (DOOR_X, y - 0.23, PLINTH + 5.0))
    K.box("Timber", "WoodWarmShade", (2.0, 0.08, 0.2), (DOOR_X, y - 0.25, PLINTH + 3.8))
    for dx in (-1, 1):
        K.box("Timber", "WoodWarmShade", (0.35, 0.4, 7.25), (DOOR_X + dx * 2.17, y - 0.1, PLINTH + 3.62), bevel=0.04)
    K.box("Timber", "WoodWarmShade", (4.8, 0.45, 0.4), (DOOR_X, y - 0.12, PLINTH + 7.2), bevel=0.04)
    K.box("Gold", "GoldAccent", (0.18, 0.2, 0.5), (DOOR_X - 1.4, y - 0.3, PLINTH + 3.3))
    K.box("Step", "StoneGray", (5.0, 1.1, 0.32), (DOOR_X, y - 0.55, 0.16), bevel=0.06)


def post_horn(cx, y, cz):
    """Gold post horn (a coiled ring with a flared bell, no text) on a red disc facing -Y."""
    K.cylinder("Disc", "RoofRed", 1.1, 0.14, (cx, y, cz), rot=(90, 0, 0), verts=10)
    K.cylinder("Gold", "GoldAccent", 1.28, 0.08, (cx, y + 0.05, cz), rot=(90, 0, 0), verts=10)
    major, minor, seg, sides = 0.45, 0.1, 8, 4
    fy = y - 0.07 - minor
    verts, faces = [], []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        for j in range(sides):
            b = 2 * math.pi * j / sides + math.pi / 4
            r = major + minor * math.cos(b)
            verts.append((cx - 0.2 + r * math.cos(a), fy + minor * math.sin(b), cz + 0.12 + r * math.sin(a)))
    for i in range(seg):
        for j in range(sides):
            a, b = i * sides + j, i * sides + (j + 1) % sides
            c, d = ((i + 1) % seg) * sides + (j + 1) % sides, ((i + 1) % seg) * sides + j
            faces.append((a, b, c, d))
    H.mesh("Gold", "GoldAccent", verts, faces)
    # bell flaring out to +X from the bottom of the coil, mouthpiece to -X at its top
    K.cone("Gold", "GoldAccent", 0.11, 0.35, 0.7, (cx + 0.4, fy, cz - 0.33), rot=(0, 90, 0), verts=8)
    K.cone("Gold", "GoldAccent", 0.09, 0.05, 0.4, (cx - 0.4, fy, cz + 0.57), rot=(0, -90, 0), verts=6)


def build():
    K.seed(1212)
    K.box("Walls", "FabricCream", (2 * HX, 2 * HY, TOP - PLINTH), (0, 0, (PLINTH + TOP) / 2.0), bevel=0.05)
    K.box("Plinth", "StoneGray", (2 * HX + 0.4, 2 * HY + 0.4, PLINTH), (0, 0, PLINTH / 2.0), bevel=0.1)
    # half-timbering: corner posts, belt beam above the awning, wall plate, braces on the upper storey
    for sx in (-1, 1):
        for sy in (-1, 1):
            K.box("Timber", "WoodWarmShade", (0.6, 0.6, TOP - PLINTH), (sx * HX, sy * HY, (PLINTH + TOP) / 2.0))
    for sy in (-1, 1):
        K.box("Timber", "WoodWarmShade", (2 * HX, 0.4, 0.4), (0, sy * (HY + 0.1), BELT), bevel=0.04)
        K.box("Timber", "WoodWarmShade", (2 * HX + 0.2, 0.3, 0.35), (0, sy * (HY + 0.08), TOP), bevel=0.03)
    for sx in (-1, 1):
        K.box("Timber", "WoodWarmShade", (0.4, 2 * HY, 0.4), (sx * (HX + 0.1), 0, BELT), bevel=0.04)
        K.box("Timber", "WoodWarmShade", (0.3, 2 * HY, 0.35), (sx * (HX + 0.08), 0, TOP), bevel=0.03)
        beam(sx * 9.2, BELT + 0.2, sx * 8.2, TOP - 0.2, -HY - 0.1)
        beam(sx * 3.9, BELT + 0.2, sx * 2.9, TOP - 0.2, -HY - 0.1)
        # side walls: one diagonal brace each on the upper storey
        length = math.hypot(4.0, TOP - BELT - 0.4)
        ang = math.degrees(math.atan2(4.0, TOP - BELT - 0.4))
        K.box("Timber", "WoodWarmShade", (0.2, 0.3, length), (sx * (HX + 0.1), 3.0, (BELT + TOP) / 2.0), rot=(ang, 0, 0))
    # lower front: shop window, door and the awning (back edge on the wall at z 8.35, front at y -9)
    shop_front()
    awning()
    # upper front windows and one window per side
    for x in (-6.5, 0.0, 6.5):
        upper_window(x)
    for side in (-1, 1):
        side_window(side)
    # knee band, attic gable ends (ridge along X) and the slate roof with snow
    K.box("Walls", "FabricCream", (2 * HX, 2 * HY, KNEE), (0, 0, TOP + KNEE / 2.0))
    # the gable prisms sit 0.3 / 0.2 low so their slopes stay inside the roof slabs (no z-fighting)
    K.prism("Gable", "FabricCream", 2 * HY, 2 * HX, ROOF_H, (0, 0, ROOF_BASE - 0.3), rot=(0, 0, 90))
    for sx in (-1, 1):
        K.box("Timber", "WoodWarmShade", (0.2, 0.35, ROOF_H - 0.4), (sx * (HX + 0.1), 0, ROOF_BASE + (ROOF_H - 0.4) / 2.0))
    roof_x("Roof", "RoofSlate", 2 * HX + 2 * GABLE_LEN, ROOF_T)
    half = HX + GABLE_LEN - 0.15
    cut = CROSS_W / 2.0 + 0.7
    snow_x(-half, -cut, -1, (HY + OVER_FRONT) * 0.62, 3)
    snow_x(cut, half, -1, (HY + OVER_FRONT) * 0.62, 3)
    snow_x(-cut, cut, -1, 1.5, 2)
    snow_x(-half, half, 1, (HY + OVER_BACK) * 0.6, 7)
    # front cross gable over the middle with the post-horn emblem; its ridge runs into the main roof
    K.prism("Gable", "FabricCream", CROSS_W, 5.0, CROSS_H, (0, -HY + 2.5, ROOF_BASE - 0.2))
    K.gable_roof("Roof", "RoofSlate", CROSS_W, 4.8, CROSS_H, ROOF_BASE, overhang=0.5, thickness=0.35, center=(0, -HY + 2.6))
    K.box("Timber", "WoodWarmShade", (CROSS_W, 0.25, 0.3), (0, -HY - 0.08, ROOF_BASE + 0.15))
    post_horn(0.0, -HY - 0.08, ROOF_BASE + 1.4)
    # stone chimney with a snow cap (top at z 20)
    K.box("Chimney", "StoneGray", (1.6, 1.6, 5.0), (6.0, 2.6, 17.2), bevel=0.06)
    K.box("Chimney", "StoneGray", (1.9, 1.9, 0.3), (6.0, 2.6, 19.55))
    K.box("Snow", "SnowWhite", (1.8, 1.8, 0.3), (6.0, 2.6, 19.82), bevel=0.1)
    # pipeline objects
    K.collider("Body", (20, 14, 12), (0, 0, 6))
    K.attachment("Light", (0, -8.0, 7.2))


K.run(build, tier="A")
