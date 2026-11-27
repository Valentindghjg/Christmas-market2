"""Shared parts for the lot fence v3 (FenceRail8, FenceRail6, FencePost) and the lot gate.

Each Environment/<Model>/build.py and Props/LotGate/build.py imports this module as F next to the
kit (cm2_kit as K). Units are studs, Z up, front = -Y, origin = ground pivot.
Values: docs/plans/CM2-GATE.md (v2: docs/plans/CM2-13b.md).
A rail segment of length L has its origin at the segment centre, its start post at x = -L/2
and its rails running to x = +L/2, where the next segment's post (or a FencePost) closes it.
All fence wood is WoodWarmShade (a second wood colour does not fit in 4 MeshParts).
"""

import math

import cm2_kit as K

POST_W = 0.9
POST_H = 4.9
RAIL_Y, RAIL_Z = 0.4, 0.55
RAIL_CENTRES = (1.8, 3.6)
WOOD = "WoodWarmShade"


def post(x, w=POST_W, h=POST_H):
    """Square WoodWarmShade post at x (w x w x h), crowned by a lantern cap."""
    K.box("Post", WOOD, (w, w, h), (x, 0, h / 2.0), bevel=0.04)
    lantern_cap(x, w, h)


def lantern_cap(x, w, base_z):
    """Lantern on a post top; every part stays inside the w x w square.
    Plate, glowing LightWarm cube with 4 corner bars, pyramid roof and a snow pyramid."""
    plate_h = 0.15
    K.box("Post", WOOD, (w, w, plate_h), (x, 0, base_z + plate_h / 2.0), bevel=0.03)
    glow_z0 = base_z + plate_h
    glow_h = 0.5 * w
    K.box("Glow", "LightWarm", (0.55 * w, 0.55 * w, glow_h), (x, 0, glow_z0 + glow_h / 2.0))
    bar = 0.1 * w
    off = 0.3 * w
    for sx in (-1, 1):
        for sy in (-1, 1):
            K.box("Post", WOOD, (bar, bar, glow_h), (x + sx * off, sy * off, glow_z0 + glow_h / 2.0))
    roof_z0 = glow_z0 + glow_h
    roof_r = w / 2.0 * math.sqrt(2.0)
    roof_h = 0.35 * w
    K.cone("Post", WOOD, roof_r, 0.0, roof_h, (x, 0, roof_z0 + roof_h / 2.0), rot=(0, 0, 45), verts=4)
    snow_h = 0.3 * w
    snow_z0 = roof_z0 + roof_h / 2.0
    K.cone("Snow", "SnowWhite", roof_r * 0.86, 0.0, snow_h, (x, 0, snow_z0 + snow_h / 2.0),
           rot=(0, 0, 45), verts=4)


def rails(length):
    """Two rails from x = -L/2 to just short of +L/2, each tilted a little about Y,
    with a snow strip on the top rail over 85 % of the length."""
    span = length - 0.05  # ends inside the next post
    cx = -length / 2.0 + span / 2.0
    for index, z in enumerate(RAIL_CENTRES):
        tilt = K._rng.uniform(-1.5, 1.5)
        K.box("Rail", WOOD, (span, RAIL_Y, RAIL_Z), (cx, 0, z), rot=(0, tilt, 0), bevel=0.04)
        if index == len(RAIL_CENTRES) - 1:
            lift = RAIL_Z / 2.0 + 0.06
            a = math.radians(tilt)
            shift = K._rng.uniform(-0.04, 0.04) * length
            K.box("Snow", "SnowWhite", (0.85 * length, RAIL_Y + 0.06, 0.12),
                  (cx + shift * math.cos(a) + lift * math.sin(a), 0, z - shift * math.sin(a) + lift * math.cos(a)),
                  rot=(0, tilt, 0), bevel=0.05)


def garland(x0, x1, z, sag, y, segments, radius, bulbs, bulb_r, drop):
    """Sagging NeedleGreen garland from x0 to x1 at height z (z(t) = z - sag*4t(1-t)) in the
    plane y, made of 6-sided cylinders, with LightWarm bulbs hanging drop below the curve."""

    def point(t):
        return x0 + (x1 - x0) * t, z - sag * 4.0 * t * (1.0 - t)

    for i in range(segments):
        ax, az = point(i / segments)
        bx, bz = point((i + 1) / segments)
        dx, dz = bx - ax, bz - az
        chord = math.hypot(dx, dz)
        K.cylinder("Garland", "NeedleGreen", radius, chord + 0.04, ((ax + bx) / 2.0, y, (az + bz) / 2.0),
                   rot=(0, math.degrees(math.atan2(dx, dz)), 0), verts=6)
    for k in range(1, bulbs + 1):
        bx, bz = point(k / (bulbs + 1))
        K.ball("Bulb", "LightWarm", bulb_r, (bx, y, bz - drop), detail=0)
