"""Lot Gate (CM2-GATE): festive wooden entrance arch over the lot opening, matching fence v3.

blender -b --factory-startup --python assets/art/source/Props/LotGate/build.py -- --out assets/art/source/Props/LotGate/model.blend

Two lantern posts on stone plinths, a beam with a blank framed sign, a snowy lit arch on top,
a garland with bulbs and red bows along the beam. Values: docs/plans/CM2-GATE.md.
The opening between the posts stays clear: x +-8.15, z 0 .. 12.1.
"""

import math
import sys

sys.path[:0] = ["tools/art/kit", "assets/art/source/Environment"]
import cm2_kit as K, fence_common as F  # noqa: E401, E402

POST_X = 8.9
POST_W = 1.4
POST_H = 15.2
BEAM_Z = 13.0
BEAM_TOP = 13.4
SIGN_Z = 14.65
FRAME_W, FRAME_H, FRAME_BAR, FRAME_D = 9.3, 2.5, 0.15, 0.35
ARCH_SEGMENTS = 9
ARCH_END = (8.2, 14.8)
ARCH_TOP = 17.2
ANCHORS = (-8.2, -4.1, 0.0, 4.1, 8.2)
GARLAND_Z = 12.9


def posts():
    for sx in (-1, 1):
        x = sx * POST_X
        F.post(x, w=POST_W, h=POST_H)
        K.box("Plinth", "StoneGrayShade", (1.5, 1.5, 0.8), (x, 0, 0.4), bevel=0.05)
        # WoodWarm bands (secondary forms) above the plinth and under the beam, inside the 1.5 footprint
        for z in (1.15, 12.3):
            K.box("Beam", "WoodWarm", (1.5, 1.5, 0.3), (x, 0, z), bevel=0.05)


def beam_and_sign():
    K.box("Beam", "WoodWarm", (19.0, 1.1, 0.8), (0, 0, BEAM_Z), bevel=0.05)
    for sx in (-1, 1):
        K.snow_cap((3.55, 1.2, 0.15), (sx * 6.425, 0, BEAM_TOP))
    # blank sign board in a gold frame resting on the beam
    K.box("Sign", "FabricCream", (9.0, 0.3, 2.2), (0, 0, SIGN_Z), bevel=0.03)
    frame_z0 = BEAM_TOP
    K.box("Frame", "GoldAccent", (FRAME_W, FRAME_D, FRAME_BAR), (0, 0, frame_z0 + FRAME_BAR / 2.0), bevel=0.03)
    K.box("Frame", "GoldAccent", (FRAME_W, FRAME_D, FRAME_BAR),
          (0, 0, frame_z0 + FRAME_H - FRAME_BAR / 2.0), bevel=0.03)
    side_h = FRAME_H - 2.0 * FRAME_BAR
    for sx in (-1, 1):
        K.box("Frame", "GoldAccent", (FRAME_BAR, FRAME_D, side_h),
              (sx * (FRAME_W - FRAME_BAR) / 2.0, 0, frame_z0 + FRAME_H / 2.0), bevel=0.03)


def arch():
    """Nine equal-angle segments on the circle through (+-8.2, 14.8) and (0, 17.2)."""
    ex, ez = ARCH_END
    # circle centre on x = 0: (ex^2 + (ez - c)^2) = (top - c)^2
    centre_z = (ex * ex + ez * ez - ARCH_TOP * ARCH_TOP) / (2.0 * (ez - ARCH_TOP))
    radius = ARCH_TOP - centre_z
    a_end = math.atan2(ez - centre_z, ex)  # angle of the right end, measured from +X
    a_start = math.pi - a_end
    for i in range(ARCH_SEGMENTS):
        a0 = a_start + (a_end - a_start) * i / ARCH_SEGMENTS
        a1 = a_start + (a_end - a_start) * (i + 1) / ARCH_SEGMENTS
        ax, az = radius * math.cos(a0), centre_z + radius * math.sin(a0)
        bx, bz = radius * math.cos(a1), centre_z + radius * math.sin(a1)
        dx, dz = bx - ax, bz - az
        chord = math.hypot(dx, dz)
        mx, mz = (ax + bx) / 2.0, (az + bz) / 2.0
        rot = (0, -math.degrees(math.atan2(dz, dx)), 0)
        K.box("Arch", "WoodWarm", (chord + 0.1, 1.0, 0.6), (mx, 0, mz), rot=rot, bevel=0.04)
        nx, nz = mx, mz - centre_z
        n = math.hypot(nx, nz)
        nx, nz = nx / n, nz / n
        K.box("Snow", "SnowWhite", (chord + 0.08, 1.1, 0.12), (mx + 0.36 * nx, 0, mz + 0.36 * nz),
              rot=rot, bevel=0.05)
        K.ball("Bulb", "LightWarm", 0.14, (mx, -0.6, mz), detail=0)


def garland_and_bows():
    for x0, x1 in zip(ANCHORS[:-1], ANCHORS[1:]):
        F.garland(x0, x1, GARLAND_Z, 0.4, -0.7, 6, 0.16, 4, 0.12, 0.2)
    for x in ANCHORS:
        for sx, angle in ((-1, 90), (1, -90)):
            K.cone("Bow", "RoofRed", 0.3, 0.0, 0.4, (x + sx * 0.2, -0.8, GARLAND_Z), rot=(0, angle, 0), verts=4)
        K.ball("Bow", "RoofRed", 0.12, (x, -0.8, GARLAND_Z), detail=0)


def build():
    K.seed(147)
    posts()
    beam_and_sign()
    arch()
    garland_and_bows()
    # pipeline objects
    for name, sx in (("PostL", -1), ("PostR", 1)):
        K.collider(name, (1.5, 1.5, POST_H), (sx * POST_X, 0, POST_H / 2.0))
    K.collider("Header", (19.0, 1.4, 5.0), (0, 0, 15.1))
    K.attachment("SignFace", (0, -0.16, SIGN_Z))
    K.attachment("Light1", (-4.1, -0.9, GARLAND_Z))
    K.attachment("Light2", (4.1, -0.9, GARLAND_Z))


K.run(build, tier="A")
