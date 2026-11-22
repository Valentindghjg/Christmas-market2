"""Village Tree (CM2-10a): the big decorated fir on the village square, in a stone planter.

blender -b --factory-startup --python assets/art/source/Environment/VillageTree/build.py -- --out assets/art/source/Environment/VillageTree/model.blend

Units are studs, Z up, front = -Y, origin = trunk foot. Values: docs/plans/CM2-10a.md;
final values also in DECISION_LOG ("CM2-10 map layout and landmarks").
"""

import math
import sys

sys.path[:0] = ["tools/art/kit", "assets/art/source/Buildings", "assets/art/source/Trees"]
import cm2_kit as K, hq_common as H, tree_common as T  # noqa: E401, E402

PLANTER_R, PLANTER_TOP_R, PLANTER_H = 15.0, 14.2, 1.2
MOUND_R, MOUND_H = 13.8, 0.6
TRUNK_R, TRUNK_H = 1.8, 8.0
# canopy tiers: rim radius, base z, height, star points
TIERS = [
    (13.0, 6.0, 10.0, 9),
    (11.2, 12.5, 9.5, 9),
    (9.2, 19.0, 9.0, 8),
    (7.2, 25.5, 8.5, 8),
    (5.2, 32.0, 8.0, 7),
    (3.2, 38.0, 8.0, 7),
]
INNER, DROOP, SNOW = 0.84, 0.08, 0.40
SNOW_FROM = 0.35  # lower than tree_common (0.5): the tiers overlap more, so the band must start lower to show
BAUBLES_PER_TIER = (8, 7, 6, 5, 4, 2)  # 32 on the rims
BAUBLE_KEYS = ("RoofRed", "GoldAccent", "GlassBlue")
BULBS, TURNS, BULB_Z = 48, 3, (7.0, 40.0)
STAR_Z, STAR_SIZE, STAR_DEPTH = 46.0, 4.0, 0.6


def ring(radius, z, sides=12):
    """Polygon with a vertex on +X and +Y, so a 12-gon spans exactly 2r in X and Y."""
    return [(radius * math.cos(2 * math.pi * k / sides), radius * math.sin(2 * math.pi * k / sides), z)
            for k in range(sides)]


def frustum(part, key, r0, r1, z0, z1, bevel):
    bottom, top = ring(r0, z0), ring(r1, z1)
    n = len(bottom)
    faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
    faces += [(k, (k + 1) % n, n + (k + 1) % n, n + k) for k in range(n)]
    return H.mesh(part, key, bottom + top, faces, bevel)


def rim_radius(tier, angle):
    """Radius of a tier's star rim along the ray at angle (ray / polygon-edge intersection)."""
    R, p, twist = tier["R"], tier["p"], tier["twist"]
    pts = []
    for k in range(2 * p):
        a = twist + k * math.pi / p
        r = R if k % 2 == 0 else R * INNER
        pts.append((r * math.cos(a), r * math.sin(a)))
    dx, dy = math.cos(angle), math.sin(angle)
    best = 0.0
    for k in range(2 * p):
        (x1, y1), (x2, y2) = pts[k], pts[(k + 1) % (2 * p)]
        ex, ey = x2 - x1, y2 - y1
        den = dx * ey - dy * ex
        if abs(den) < 1e-9:
            continue
        t = (x1 * ey - y1 * ex) / den
        u = (x1 * dy - y1 * dx) / den
        if t > 0 and -1e-6 <= u <= 1 + 1e-6:
            best = max(best, t)
    return best


def surface_radius(tiers, angle, z):
    """Outermost canopy surface radius at height z along angle (snow band included)."""
    best = 0.0
    for tier in tiers:
        f = (z - tier["z"]) / tier["h"]
        if 0.0 <= f <= 1.0:
            r = rim_radius(tier, angle) * (1 - f) + T.R_TOP * tier["R"] * f
            if SNOW_FROM <= f <= SNOW_FROM + SNOW:
                r = r * T.SNOW_SCALE + T.SNOW_LIFT
            best = max(best, r)
    return best


def build():
    K.seed(162)
    # stone planter with a snow mound
    frustum("Planter", "StoneGray", PLANTER_R, PLANTER_TOP_R, 0.0, PLANTER_H, 0.1)
    frustum("Mound", "SnowWhite", MOUND_R, MOUND_R - 2.6, PLANTER_H - 0.05, PLANTER_H + MOUND_H, 0.1)
    ground = PLANTER_H + MOUND_H

    # trunk and four root wedges on the mound
    K.cylinder("Trunk", "BarkBrown", TRUNK_R, TRUNK_H, (0, 0, TRUNK_H / 2), verts=8)
    for k in range(4):
        a = math.radians(45 + 90 * k)
        t = (-math.sin(a), math.cos(a))
        c, s = math.cos(a), math.sin(a)
        base = TRUNK_R - 0.2
        verts = [
            (base * c + 0.7 * t[0], base * s + 0.7 * t[1], ground - 0.1),
            (base * c - 0.7 * t[0], base * s - 0.7 * t[1], ground - 0.1),
            (3.4 * c, 3.4 * s, ground - 0.1),
            ((TRUNK_R - 0.05) * c, (TRUNK_R - 0.05) * s, ground + 1.8),
        ]
        H.mesh("RootFlare", "BarkBrownShade", verts, [(0, 1, 2), (0, 2, 3), (1, 3, 2), (0, 3, 1)])

    tiers = []
    for R, z, h, p in TIERS:
        tiers.append({"R": R, "z": z, "h": h, "p": p, "inner": INNER, "droop": DROOP,
                      "twist": K._rng.uniform(0, 2 * math.pi / p)})
    # dark cores, needle tiers, snow bands (as tree_common.build)
    for tier in tiers:
        depth = tier["h"] * 1.12
        K.cone("NeedlesCore", "NeedleDeepShade", T.CORE_RATIO * tier["R"], 0.0, depth,
               (0, 0, tier["z"] - 0.12 * tier["h"] + depth / 2), verts=8)
    for tier in tiers:
        T.star_cone("Needles", "NeedleDeep", tier["R"], T.R_TOP * tier["R"], tier["h"], (0, 0, tier["z"]),
                    tier["twist"], tier["p"], INNER, DROOP)
    for tier in tiers:
        s = T._tier_band(tier, SNOW_FROM, SNOW_FROM + SNOW, T.SNOW_SCALE, T.SNOW_LIFT)
        T.star_cone("Snow", "SnowWhite", s["R"], s["r_top"], s["depth"], (0, 0, s["z"]), s["twist"], s["p"],
                    s["inner"], s["droop"], cap_bottom=False)

    # baubles hanging under the star points of each rim
    index = 0
    for tier, count in zip(tiers, BAUBLES_PER_TIER):
        p = tier["p"]
        for j in range(count):
            point = int(round(j * p / count + tiers.index(tier) * 0.5)) % p
            a = tier["twist"] + point * 2 * math.pi / p
            r = tier["R"] - 0.35
            z = tier["z"] - DROOP * tier["h"] - 0.75
            K.ball("Baubles", BAUBLE_KEYS[index % 3], 0.8, (r * math.cos(a), r * math.sin(a), z), detail=0)
            index += 1

    # light bulbs on a 3-turn spiral, 0.3 outside the canopy surface
    for k in range(BULBS):
        f = k / (BULBS - 1)
        z = BULB_Z[0] + f * (BULB_Z[1] - BULB_Z[0])
        a = -math.pi / 2 + f * TURNS * 2 * math.pi
        r = surface_radius(tiers, a, z) + 0.3
        K.ball("Lights", "LightWarm", 0.4, (r * math.cos(a), r * math.sin(a), z), detail=0)

    # gold star: one facing -Y plus a copy turned 90 degrees about Z
    H.star((0, 0, STAR_Z), STAR_SIZE, "GoldAccent", depth=STAR_DEPTH)
    second = H.star((0, 0, STAR_Z), STAR_SIZE, "GoldAccent", depth=STAR_DEPTH)
    second.rotation_euler = (0, 0, math.radians(90))

    K.collider("Planter", (30, 30, 1.2), (0, 0, 0.6))
    K.collider("Trunk", (4, 4, 20), (0, 0, 10))
    K.attachment("TreeBase", (0, 0, 0))
    K.attachment("Star", (0, 0, STAR_Z))


K.run(build, tier="A")
