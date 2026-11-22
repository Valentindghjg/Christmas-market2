"""Shared parts for the CM2-13b lot fence (FenceRail8, FenceRail6, FencePost).

Each Environment/<Model>/build.py imports this module as F next to the kit (cm2_kit as K).
Units are studs, Z up, front = -Y, origin = ground pivot. Values: docs/plans/CM2-13b.md.
A rail segment of length L has its origin at the segment centre, its start post at x = -L/2
and its rails running to x = +L/2, where the next segment's post (or a FencePost) closes it.
"""

import math

import cm2_kit as K

POST_W = 0.6
POST_H = 3.7
CAP_TOP = 4.0
SNOW_TOP = 4.1
RAIL_Y, RAIL_Z = 0.35, 0.5
RAIL_CENTRES = (1.4, 2.8)


def post(x):
    """Square post at x: body to 3.7, pyramid cap to 4.0 (WoodWarmShade), snow cap to 4.1."""
    K.box("Post", "WoodWarmShade", (POST_W, POST_W, POST_H), (x, 0, POST_H / 2.0), bevel=0.04)
    half_diag = POST_W / 2.0 * math.sqrt(2.0)
    cap_h = CAP_TOP - POST_H
    K.cone("Post", "WoodWarmShade", half_diag, 0.0, cap_h, (x, 0, POST_H + cap_h / 2.0), rot=(0, 0, 45), verts=4)
    # snow: a smaller, softer pyramid over the upper cap, its foot just above the cap's midline
    snow_h = 0.27
    K.cone("Snow", "SnowWhite", half_diag * 0.86, 0.06, snow_h, (x, 0, SNOW_TOP - snow_h / 2.0),
           rot=(0, 0, 45), verts=4)


def rails(length):
    """Two WoodWarm rails from x = -L/2 to just short of +L/2, each tilted a little about Y,
    with a snow strip on the top rail over 85 % of the length."""
    span = length - 0.05  # ends inside the next post; keeps the bbox within -L/2 - 0.3 .. +L/2
    cx = -length / 2.0 + span / 2.0
    for index, z in enumerate(RAIL_CENTRES):
        tilt = K._rng.uniform(-1.5, 1.5)
        K.box("Rail", "WoodWarm", (span, RAIL_Y, RAIL_Z), (cx, 0, z), rot=(0, tilt, 0), bevel=0.04)
        if index == len(RAIL_CENTRES) - 1:
            lift = RAIL_Z / 2.0 + 0.06
            a = math.radians(tilt)
            shift = K._rng.uniform(-0.04, 0.04) * length
            K.box("Snow", "SnowWhite", (0.85 * length, 0.4, 0.12),
                  (cx + shift * math.cos(a) + lift * math.sin(a), 0, z - shift * math.sin(a) + lift * math.cos(a)),
                  rot=(0, tilt, 0), bevel=0.05)
