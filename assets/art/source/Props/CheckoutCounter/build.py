"""Checkout Counter (CM2-13b): festive plank till with register, garland, bows and two lanterns.

blender -b --factory-startup --python assets/art/source/Props/CheckoutCounter/build.py -- --out assets/art/source/Props/CheckoutCounter/model.blend

Fills the 5 x 2 Path.Counter box; customers queue at -Y (ATT_Checkout1), the cashier stands at +Y.
"""

import math
import sys

sys.path[:0] = ["tools/art/kit"]
import cm2_kit as K  # noqa: E402

BODY_TOP = 3.5
TOP_Z = 3.7  # top board 3.5-3.7
FRONT = -0.8  # front face of the body
REG = (0.6, 0.2)  # register centre


def wedge(part, key, x0, x1, y0, y1, z0, z_front, z_back):
    """Box from x0..x1, y0..y1 whose top slopes from z_front (at y0) up to z_back (at y1)."""
    verts = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
             (x0, y0, z_front), (x1, y0, z_front), (x1, y1, z_back), (x0, y1, z_back)]
    faces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    obj = K._mesh_object("%s__%s" % (part, key), verts, faces)
    return K._finish_shape(obj, part, key, (0, 0, 0), (0, 0, 0), 0.0)


def body():
    K.box("Base", "WoodWarmShade", (4.4, 1.4, 0.3), (0, 0, 0.15))
    K.box("Body", "WoodWarm", (4.3, 1.3, BODY_TOP - 0.3), (0, 0, (BODY_TOP + 0.3) / 2.0))
    for x in (-2.15, 2.15):
        for y in (-0.65, 0.65):
            K.box("Frame", "WoodWarmShade", (0.3, 0.3, BODY_TOP - 0.3), (x, y, (BODY_TOP + 0.3) / 2.0))
    # front frame rails and vertical planks between them
    for z in (0.52, 3.3):
        K.box("Frame", "WoodWarmShade", (4.0, 0.16, 0.22), (0, FRONT + 0.08, z))
    count, width = 8, 0.47
    for index in range(count):
        x = -1.89 + index * 0.54
        h = 2.5 + K._rng.uniform(-0.1, 0.1)
        K.box("Body", "WoodWarm", (width, 0.1, h), (x, FRONT + 0.1, 0.63 + h / 2.0), bevel=0.03)
    # back (cashier side): a shelf under the top
    K.box("Frame", "WoodWarmShade", (3.6, 0.35, 0.12), (0, 0.66, 2.5))
    # top board
    K.box("Top", "WoodWarmShade", (5.0, 2.0, 0.2), (0, 0, (BODY_TOP + TOP_Z) / 2.0), bevel=0.05)


def register():
    x, y = REG
    K.box("Register", "MetalDark", (1.4, 0.9, 0.24), (x, y, TOP_Z + 0.12), bevel=0.03)
    K.box("Drawer", "GoldAccent", (0.4, 0.04, 0.05), (x, y - 0.46, TOP_Z + 0.12))  # cash drawer pull
    wedge("Register", "MetalDark", x - 0.62, x + 0.62, y - 0.4, y + 0.25, TOP_Z + 0.22, TOP_Z + 0.27, TOP_Z + 0.4)
    # raised customer display at the back, facing -Y
    K.box("Register", "MetalDark", (0.74, 0.12, 0.4), (x, y + 0.32, TOP_Z + 0.45))
    K.box("Display", "LightWarm", (0.6, 0.03, 0.25), (x, y + 0.25, TOP_Z + 0.5))


def bow(x, z):
    """Ribbon bow on the front face: two loops, a knot and two tails."""
    y = FRONT - 0.06
    for side in (-1, 1):
        loop = K.cone("Bow", "RoofRed", 0.2, 0.03, 0.3, (x + side * 0.17, y, z), rot=(0, -side * 90, 0), verts=4)
        loop.scale = (1.0, 0.5, 1.0)  # flat against the planks; stays inside the 2-stud depth
        K.box("Bow", "RoofRed", (0.09, 0.05, 0.42), (x + side * 0.1, y, z - 0.25), rot=(0, side * 18, 0))
    K.box("Bow", "RoofRed", (0.14, 0.12, 0.14), (x, y, z))


def garland():
    """Two sagging swags of needle balls just under the top board, gold baubles at the low points."""
    y, top, sag = -0.82, 3.3, 0.3
    ends = [(-2.3, 0.0), (0.0, 2.3)]
    for x0, x1 in ends:
        n = 8
        for k in range(0 if x0 < 0 else 1, n + 1):  # the swags share the middle ball
            t = k / n
            x = x0 + (x1 - x0) * t
            z = top - sag * math.sin(math.pi * t)
            K.ball("Garland", "NeedleGreen", 0.18, (x, y, z), detail=0)
    for x, z in ((-2.3, 2.96), (-1.15, 2.7), (0.0, 2.96), (1.15, 2.7), (2.3, 2.96)):
        K.ball("Bauble", "GoldAccent", 0.14, (x, -0.84, z), detail=0)


def lantern_post(x):
    y = 0.75
    K.post("Frame", "WoodWarmShade", 0.8, (x, y, TOP_Z), width=0.3)
    z0 = TOP_Z + 0.8
    K.box("Lantern", "MetalDark", (0.36, 0.36, 0.05), (x, y, z0 + 0.025))
    for dx in (-0.15, 0.15):
        for dy in (-0.15, 0.15):
            K.box("Lantern", "MetalDark", (0.05, 0.05, 0.28), (x + dx, y + dy, z0 + 0.19))
    K.box("Lamp", "LightWarm", (0.24, 0.24, 0.26), (x, y, z0 + 0.18))
    K.cone("Lantern", "MetalDark", 0.28, 0.04, 0.14, (x, y, z0 + 0.4), rot=(0, 0, 45), verts=4)
    K.cone("Snow", "SnowWhite", 0.2, 0.03, 0.12, (x, y, 5.0 - 0.06), rot=(0, 0, 45), verts=4)


def build():
    K.seed(141)
    body()
    register()
    bow(-1.6, 2.3)
    bow(1.6, 2.3)
    garland()
    for x in (-2.3, 2.3):
        lantern_post(x)
    K.snow_cap((0.75, 0.7, 0.15), (-2.05, 0.5, TOP_Z))
    K.collider("Counter", (5.0, 2.0, 3.7), (0, 0, 1.85))
    K.attachment("Checkout1", (0, -3.0, 0))
    K.attachment("CashierStand", (0, 2.5, 0))
    K.attachment("Register", (REG[0], REG[1], TOP_Z + 0.32))


K.run(build, tier="A")
