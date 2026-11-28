"""FirBarrel (CM2-10D): wooden half barrel with two raised hoops, a snowy soil top and a small
three-tier fir with snow on each tier.

blender -b --factory-startup --python assets/art/source/Props/FirBarrel/build.py -- --out assets/art/source/Props/FirBarrel/model.blend

Origin = footprint centre on the ground, front -Y, studs, Z up. Values: docs/plans/CM2-10D.md.
"""

import sys

sys.path[:0] = ["tools/art/kit"]
import cm2_kit as K  # noqa: E402

TIERS = ((1.2, 1.8, 3.6), (0.95, 2.9, 4.7), (0.65, 4.0, 6.0))  # radius, bottom z, top z
TIP = 0.12  # top radius as a fraction of the tier radius


def build():
    K.seed(1106)
    K.cone("Barrel", "WoodWarm", 1.05, 1.2, 0.9, (0, 0, 0.45), verts=8)
    K.cone("Barrel", "WoodWarm", 1.2, 1.05, 0.9, (0, 0, 1.35), verts=8)
    for z in (0.25, 1.55):
        K.cylinder("Barrel", "WoodWarm", 1.15, 0.15, (0, 0, z), verts=8)  # no bevel: 360-triangle budget
    K.cylinder("Snow", "SnowWhite", 1.0, 0.1, (0, 0, 1.75), verts=8)
    for radius, z0, z1 in TIERS:
        twist = K._rng.uniform(0, 360.0 / 7)
        depth = z1 - z0
        K.cone("Needles", "NeedleGreen", radius, radius * TIP, depth, (0, 0, (z0 + z1) / 2.0),
               rot=(0, 0, twist), verts=7)
        # snow collar, 0.3 high, starting where the tier is 0.7 of its radius wide
        zs = z0 + depth * 0.3 / (1.0 - TIP)

        def radius_at(z, radius=radius, z0=z0, depth=depth):
            return radius * (1.0 - (1.0 - TIP) * (z - z0) / depth) * 1.08

        K.cone("Snow", "SnowWhite", radius_at(zs), radius_at(zs + 0.3), 0.3, (0, 0, zs + 0.15),
               rot=(0, 0, twist), verts=7)
    K.collider("Barrel", (2.4, 2.4, 1.8), (0, 0, 0.9))


K.run(build, tier="B")
