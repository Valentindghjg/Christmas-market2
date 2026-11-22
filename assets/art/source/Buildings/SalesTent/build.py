"""Sales Tent (CM2-13a, HQ tier 1): plank deck, gored pyramid canopy, counter, desk, string lights.

blender -b --factory-startup --python assets/art/source/Buildings/SalesTent/build.py -- --out assets/art/source/Buildings/SalesTent/model.blend
"""

import sys

sys.path[:0] = ["tools/art/kit", "assets/art/source/Buildings"]
import cm2_kit as K, hq_common as H  # noqa: E401, E402

FLOOR = 0.4
EAVE_X, EAVE_Y, EAVE_Z, APEX_Z, CLOTH = 9.7, 6.7, 7.5, 9.8, 0.15


def canopy():
    apex = (0.0, 0.0, APEX_Z)
    c = [(-EAVE_X, -EAVE_Y), (EAVE_X, -EAVE_Y), (EAVE_X, EAVE_Y), (-EAVE_X, EAVE_Y)]
    gores = []
    for index in range(4):
        a, b = c[index], c[(index + 1) % 4]
        m = ((a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0)
        gores += [(a, m), (m, b)]
    ray = {}  # snow reach per seam, shared by the two gores that meet there
    for index, (p, q) in enumerate(gores):
        key = "RoofRed" if index % 2 == 0 else "FabricCream"
        H.slab("Canopy", key, [apex, (p[0], p[1], EAVE_Z), (q[0], q[1], EAVE_Z)], CLOTH)
        # snow on the upper ~45 % of the gore, its lower edge bulging into two soft drips
        fp = ray.setdefault(p, 0.43 + K._rng.uniform(-0.03, 0.03))
        fq = ray.setdefault(q, 0.43 + K._rng.uniform(-0.03, 0.03))
        s = [(0.0, 0.0, APEX_Z + 0.22)]
        for t, f in ((0.0, fp), (0.33, None), (0.67, None), (1.0, fq)):
            if f is None:
                f = fp + (fq - fp) * t + K._rng.uniform(0.04, 0.09)
            x, y = p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t
            s.append((x * f, y * f, APEX_Z + (EAVE_Z - APEX_Z) * f + 0.2))
        H.slab("Snow", "SnowWhite", s, 0.22)
    # valance: 0.9-wide triangles hanging 0.8 under the eave
    z = EAVE_Z - CLOTH
    count = 0
    for index in range(4):
        a, b = c[index], c[(index + 1) % 4]
        length = abs(b[0] - a[0]) + abs(b[1] - a[1])
        n = max(1, round(length / 0.9))
        nx, ny = (0, -1) if index == 0 else (1, 0) if index == 1 else (0, 1) if index == 2 else (-1, 0)
        for k in range(n):
            t0, t1 = k / n, (k + 1) / n
            p0 = (a[0] + (b[0] - a[0]) * t0 + nx * 0.03, a[1] + (b[1] - a[1]) * t0 + ny * 0.03, z)
            p1 = (a[0] + (b[0] - a[0]) * t1 + nx * 0.03, a[1] + (b[1] - a[1]) * t1 + ny * 0.03, z)
            tip = ((p0[0] + p1[0]) / 2.0, (p0[1] + p1[1]) / 2.0, z - 0.8)
            H.pennant("Valance", "RoofRedShade" if count % 2 == 0 else "FabricCreamShade", p0, p1, tip)
            count += 1


def build():
    K.seed(131)
    # plank deck 18 x 12 x 0.4
    K.planks("Deck", "WoodWarmShade", 8, (18.0, 1.44, FLOOR), (0, -5.25, FLOOR / 2.0), (0, 1.5, 0),
             bevel=0.03, jitter=0.1)
    # poles and canopy
    for x in (-8.6, 8.6):
        for y in (-5.6, 5.6):
            K.post("Poles", "WoodWarm", 7.25, (x, y, FLOOR), width=0.5)
    canopy()
    # back cloth wall with a wooden top rail
    K.box("BackWall", "FabricCream", (17.0, 0.2, 5.0), (0, 5.6, FLOOR + 2.5), bevel=0.04)
    K.box("BackWall", "WoodWarm", (17.2, 0.3, 0.25), (0, 5.6, FLOOR + 5.05), bevel=0.04)
    # counter (opening x 4.4..8.4 = entrance), desk, computer, radio
    H.counter(-7.6, 4.4, -5.2, FLOOR, 3, "RoofRed")
    top = H.desk((0, 4.6, FLOOR), 6)
    H.computer((-1.2, top[1], top[2]))
    H.radio((2.0, top[1], top[2]), "WoodWarmShade")
    # string lights on the front eave and both sides
    K.string_lights((-EAVE_X, -6.82, 7.3), (EAVE_X, -6.82, 7.3), 11, sag=0.5, radius=0.22)
    for x in (-9.72, 9.72):
        K.string_lights((x, -EAVE_Y, 7.3), (x, EAVE_Y, 7.3), 9, sag=0.5, radius=0.22)
    # pipeline objects
    K.collider("Deck", (18.0, 12.0, FLOOR), (0, 0, FLOOR / 2.0))
    for index, (x, y) in enumerate(((-8.6, -5.6), (8.6, -5.6), (-8.6, 5.6), (8.6, 5.6))):
        K.collider("Pole%d" % (index + 1), (0.5, 0.5, 7.25), (x, y, FLOOR + 3.625))
    K.collider("BackWall", (17.0, 0.3, 5.2), (0, 5.6, FLOOR + 2.6))
    K.collider("Counter", (12.0, 1.4, 3.6), (-1.6, -5.25, FLOOR + 1.8))
    K.collider("Desk", (6.0, 0.9, 3.2), (0, 4.6, FLOOR + 1.6))
    K.attachment("Entrance", (6.4, -6.0, 0))
    K.attachment("Computer", (-1.2, 4.6, top[2]))
    K.attachment("Radio", (2.0, 4.6, top[2]))


K.run(build, tier="A")
