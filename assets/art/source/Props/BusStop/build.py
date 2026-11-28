"""BusStop (CM2-10I): open-front wooden shelter. Four posts at (+-3.5, +-1.5), clapboard back wall,
half-depth side walls, a bench at seat height 0.9, a green lean-to roof rising to the front with a
fascia and a snow layer, a white timetable board at x 2.6; the Light attachment sits just under the roof
(CM2-10IW adds the light).

blender -b --factory-startup --python assets/art/source/Props/BusStop/build.py -- --out assets/art/source/Props/BusStop/model.blend

Origin = footprint centre on the ground, front -Y, studs, Z up. Values: docs/archive/plans/CM2-10I.md row 10.
"""

import sys

sys.path[:0] = ["tools/art/kit", "assets/art/source/Buildings"]
import cm2_kit as K, hq_common as H  # noqa: E401, E402

HALF_W, HALF_L = 3.8, 1.8  # roof footprint (W 7.6 x L 3.6)
ROOF_BACK, ROOF_FRONT, ROOF_T = 6.6, 7.2, 0.25  # roof underside at y +1.8 and y -1.8


def roof_under(y):
    """Roof underside height at y (linear from the back edge to the front edge)."""
    t = (HALF_L - y) / (2 * HALF_L)
    return ROOF_BACK + (ROOF_FRONT - ROOF_BACK) * t


def build():
    K.seed(1210)
    # posts up to the roof underside
    for x in (-3.5, 3.5):
        for y in (-1.5, 1.5):
            top = roof_under(y)
            K.box("Frame", "WoodWarm", (0.4, 0.4, top), (x, y, top / 2.0))
    # head beams along X under the roof, front and back
    for y in (-1.5, 1.5):
        K.box("Frame", "WoodWarm", (7.4, 0.3, 0.3), (0, y, roof_under(y) - 0.15))
    # clapboard back wall (6 boards, z 0.3 .. 6.6) between the back posts, alternately set back
    for i in range(6):
        z = 0.3 + 0.525 + i * 1.04
        y = 1.5 + (0.03 if i % 2 else -0.03)
        K.box("Frame", "WoodWarm", (7.0 + K._rng.uniform(-0.05, 0.05), 0.2, 1.08), (0, y, z), rot=(4, 0, 0))
    # half-depth side walls (5 boards each, y -0.1 .. 1.5, z 0.3 .. 6.6), alternately set out
    for x in (-3.5, 3.5):
        for i in range(5):
            z = 0.3 + 0.63 + i * 1.255
            out = 0.03 if i % 2 else -0.02
            K.box("Frame", "WoodWarm", (0.2, 1.6, 1.28), (x + (out if x > 0 else -out), 0.7, z))
    # bench: two seat boards (top 0.9) on three supports
    for y in (0.68, 1.12):
        K.box("Frame", "WoodWarm", (6.0, 0.42, 0.15), (0, y, 0.825))
    for x in (-2.6, 0.0, 2.6):
        K.box("Frame", "WoodWarm", (0.22, 0.8, 0.75), (x, 0.9, 0.375))
    # timetable: white board in a green frame on the back wall front face
    K.box("Roof", "RoofGreen", (1.5, 0.08, 1.9), (2.6, 1.32, 3.5))
    K.box("Snow", "SnowWhite", (1.2, 0.06, 1.6), (2.6, 1.27, 3.5))
    # lean-to roof rising to the front, with a deeper fascia along the front edge
    top = [(-HALF_W, -HALF_L, ROOF_FRONT + ROOF_T), (HALF_W, -HALF_L, ROOF_FRONT + ROOF_T),
           (HALF_W, HALF_L, ROOF_BACK + ROOF_T), (-HALF_W, HALF_L, ROOF_BACK + ROOF_T)]
    H.slab("Roof", "RoofGreen", top, ROOF_T)
    K.box("Roof", "RoofGreen", (7.6, 0.14, 0.4), (0, -HALF_L + 0.07, ROOF_FRONT + 0.05))
    # snow layer on the roof, slightly inset at the sides and back
    snow = [(-HALF_W + 0.1, -HALF_L + 0.02, ROOF_FRONT + ROOF_T + 0.2),
            (HALF_W - 0.1, -HALF_L + 0.02, ROOF_FRONT + ROOF_T + 0.2),
            (HALF_W - 0.1, HALF_L - 0.1, ROOF_BACK + ROOF_T + 0.2),
            (-HALF_W + 0.1, HALF_L - 0.1, ROOF_BACK + ROOF_T + 0.2)]
    H.slab("Snow", "SnowWhite", snow, 0.22)
    K.collider("Back", (7.2, 0.4, 6.6), (0, 1.5, 3.3))
    K.collider("Bench", (6, 1, 1), (0, 0.9, 0.5))
    K.attachment("Light", (0, -0.2, 6.9))


K.run(build, tier="B")
