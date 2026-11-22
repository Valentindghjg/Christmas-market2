"""Shared builder for the CM2-12 trees (4 starter species x 3 sizes, 2 special trees).

Each Trees/<Species>/<Size>/build.py calls build("<Species>", "<Size>") through K.run.
Geometry: stacked star-rimmed cones (star_cone) with a dark inner core, a snow band on
every tier, a leader, a six-sided trunk with a root flare, plus a per-species accent
(frost undersides, gold topper, berry clusters). Units are studs, Z up, front = -Y,
origin = trunk foot. Values: docs/plans/CM2-12.md; final values also in DECISION_LOG.
"""

import math

import bmesh
import cm2_kit as K

# Size classes: total height H (incl. leader/topper), class radius R, model seed offset.
SIZES = {
    "Small": {"H": 6.0, "R": 1.9},
    "Medium": {"H": 8.0, "R": 2.5},
    "Large": {"H": 10.0, "R": 3.1},
}
SPECIAL_SIZE = {"H": 10.4, "R": 3.3}

# Species table (plan CM2-12). r: factor x class R, or "abs" for an absolute radius.
# tiers: per size. t: visible trunk / H. taper: radius loss bottom -> top tier.
# overlap: tier height x n / crown. p, inner: star rim points and notch ratio.
# droop: point drop as a fraction of tier height (negative = tips turn up).
# snow: snow band as a fraction of tier height. accent: extra parts.
SPECIES = {
    "DouglasFir": {
        "needle": "NeedleGreen", "core": "NeedleGreenShade", "r": 1.0,
        "tiers": {"Small": 4, "Medium": 5, "Large": 6},
        "t": 0.138, "taper": 0.75, "overlap": 1.15, "p": 9, "inner": 0.88,
        "droop": 0.102, "snow": 0.40, "leader": 0.10, "trunk_top": None, "accent": None, "seed": 101,
    },
    "FrasierFir": {
        "needle": "NeedleDeep", "core": "NeedleDeepShade", "r": 0.85,
        "tiers": {"Small": 5, "Medium": 6, "Large": 7},
        "t": 0.10, "taper": 0.80, "overlap": 1.19, "p": 8, "inner": 0.82,
        "droop": -0.06, "snow": 0.345, "leader": 0.10, "trunk_top": None, "accent": "frost", "seed": 202,
    },
    "NobleFir": {
        "needle": "NeedleSage", "core": "NeedleSageShade", "r": 1.0,
        "tiers": {"Small": 3, "Medium": 4, "Large": 5},
        "t": 0.14, "taper": 0.70, "overlap": 0.85, "p": 7, "inner": 0.70,
        "droop": -0.04, "snow": 0.40, "leader": 0.10, "trunk_top": 0.85, "accent": None, "seed": 303,
    },
    "BlueSpruce": {
        "needle": "NeedleBlue", "core": "NeedleBlueShade", "r": 1.0,
        "tiers": {"Small": 5, "Medium": 6, "Large": 7},
        "t": 0.08, "taper": 0.82, "overlap": 1.11, "p": 11, "inner": 0.86,
        "droop": 0.0, "snow": 0.2875, "leader": 0.14, "trunk_top": None, "accent": None, "seed": 404,
    },
    "FrostcrownFir": {
        "needle": "NeedleSilver", "core": "NeedleSilverShade", "r": "abs",
        "tiers": {"Large": 6}, "special": True,
        "t": 0.10, "taper": 0.75, "overlap": 1.15, "p": 9, "inner": 0.78,
        "droop": 0.10, "snow": 0.5175, "leader": 0.10, "trunk_top": None, "accent": "frost+topper", "seed": 505,
    },
    "HollyberrySpruce": {
        "needle": "NeedleDeep", "core": "NeedleDeepShade", "r": "abs",
        "tiers": {"Large": 7}, "special": True,
        "t": 0.08, "taper": 0.82, "overlap": 1.11, "p": 11, "inner": 0.86,
        "droop": 0.0, "snow": 0.345, "leader": 0.10, "trunk_top": None, "accent": "berries", "seed": 606,
    },
}

R_TOP = 0.15  # top ring radius of a tier, as a fraction of its rim radius
SNOW_FROM = 0.5  # snow band starts at this fraction of the tier height
SNOW_SCALE = 1.04
SNOW_LIFT = 0.06  # studs above the tier surface
FROST_DEPTH = 0.12  # frost underside depth, fraction of tier height
FROST_INNER = 0.88  # frost skirt narrows to this fraction of the rim radius
CORE_RATIO = 0.55
TOPPER_SIZE = 1.0  # star across (studs)
TOPPER_THICK = 0.3
TOPPER_LIFT = 0.45  # star centre above the leader tip
BERRY_R = 0.16
BERRY_CLUSTERS = (2, 2, 2, 2, 1, 1)  # clusters per tier, bottom tier first (tiers 1-6)


def star_cone(part, key, R, r_top, depth, loc, twist, p, inner, droop, cap_bottom=True, rot=(0, 0, 0)):
    """Star-rimmed cone: a bottom ring of 2p vertices (points at radius R, lowered by
    droop x depth; notches at R x inner), a top ring of p vertices at r_top above the
    points, closed top and (unless cap_bottom=False, for hidden bottoms) closed bottom."""
    K._check(part, key)
    verts = []
    for k in range(2 * p):
        a = twist + k * math.pi / p
        if k % 2 == 0:
            verts.append((R * math.cos(a), R * math.sin(a), -droop * depth))
        else:
            verts.append((R * inner * math.cos(a), R * inner * math.sin(a), 0.0))
    for j in range(p):
        a = twist + j * 2 * math.pi / p
        verts.append((r_top * math.cos(a), r_top * math.sin(a), depth))
    b = lambda k: k % (2 * p)  # noqa: E731
    t = lambda j: 2 * p + j % p  # noqa: E731
    faces = []
    for j in range(p):
        faces.append((b(2 * j), b(2 * j + 1), t(j)))
        faces.append((b(2 * j + 1), b(2 * j + 2), t(j + 1), t(j)))
    faces.append(tuple(t(j) for j in range(p)))
    if cap_bottom:
        faces.append(tuple(b(2 * j + 1) for j in reversed(range(p))))  # inner p-gon
        for j in range(p):
            faces.append((b(2 * j + 1), b(2 * j), b(2 * j - 1)))  # one ear per point
    obj = K._mesh_object("%s__%s" % (part, key), verts, faces)
    if cap_bottom:  # closed: let bmesh confirm outward normals; open bands keep the CCW winding above
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(obj.data)
        bm.free()
    return K._finish_shape(obj, part, key, loc, rot, 0)


def _tier_band(tier, f0, f1, scale, lift):
    """Star band hugging a tier's side surface between height fractions f0 and f1."""
    Ri, h, p, inner, droop = tier["R"], tier["h"], tier["p"], tier["inner"], tier["droop"]
    outer0 = Ri * (1 - (1 - R_TOP) * f0)
    notch0 = Ri * inner * (1 - f0) + Ri * R_TOP * math.cos(math.pi / p) * f0
    outer1 = Ri * (1 - (1 - R_TOP) * f1)
    depth = (f1 - f0) * h
    # tier point edge at f0 sits droop*h*(1-f0) below the notch line
    band_droop = droop * h * (1 - f0) / depth
    return {
        "R": outer0 * scale, "r_top": outer1 * scale, "depth": depth,
        "z": tier["z"] + f0 * h + lift, "inner": notch0 / outer0,
        "droop": band_droop, "twist": tier["twist"], "p": p,
    }


def _ridge_point(tier, radius, angle, lift):
    """Point on the upper surface of a tier, along the ridge of the star point at angle."""
    Ri, h, droop = tier["R"], tier["h"], tier["droop"]
    f = (Ri - radius) / ((1 - R_TOP) * Ri)
    z = tier["z"] - droop * h + f * (1 + droop) * h + lift
    return (radius * math.cos(angle), radius * math.sin(angle), z)


def _topper(centre):
    """Faceted 5-point gold star, upright, facing -Y, with a short gold stem."""
    outer, inner_r = TOPPER_SIZE / 2, TOPPER_SIZE / 2 * 0.45
    cx, cy, cz = centre
    verts = []
    for k in range(10):
        a = math.pi / 2 + k * math.pi / 5
        r = outer if k % 2 == 0 else inner_r
        verts.append((cx + r * math.cos(a), cy, cz + r * math.sin(a)))
    verts.append((cx, cy - TOPPER_THICK / 2, cz))  # front apex
    verts.append((cx, cy + TOPPER_THICK / 2, cz))  # back apex
    faces = []
    for k in range(10):
        faces.append((k, (k + 1) % 10, 10))
        faces.append(((k + 1) % 10, k, 11))
    K._check("Topper", "GoldAccent")
    obj = K._mesh_object("Topper__GoldAccent", verts, faces)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    K._finish_shape(obj, "Topper", "GoldAccent", (0, 0, 0), (0, 0, 0), 0)


def build(species, size):
    sp = SPECIES[species]
    cls = SPECIAL_SIZE if sp.get("special") else SIZES[size]
    H = cls["H"]
    R = cls["R"] if sp["r"] == "abs" else cls["R"] * sp["r"]
    n = sp["tiers"][size]
    p, inner, droop, taper = sp["p"], sp["inner"], sp["droop"], sp["taper"]
    accent = sp["accent"] or ""
    K.seed(sp["seed"] + list(SIZES).index(size))

    tip = H - (TOPPER_LIFT + TOPPER_SIZE / 2 if "topper" in accent else 0.0)
    leader_h = sp["leader"] * H
    crown_top = tip - 0.85 * leader_h  # leader base sinks 15% into the top tier
    h_guess = (crown_top - sp["t"] * H) / n * sp["overlap"]
    base = sp["t"] * H + max(droop, 0.0) * h_guess  # bottom points end at t x H
    crown = crown_top - base
    h = crown / n * sp["overlap"]
    step = (crown - h) / (n - 1)

    tiers = []
    for i in range(n):
        tiers.append({
            "R": R * (1 - taper * i / (n - 1)), "h": h, "z": base + i * step,
            "p": p, "inner": inner, "droop": droop,
            "twist": K._rng.uniform(0, 2 * math.pi / p),
        })

    # trunk and root flare
    trunk_top = (sp["trunk_top"] or 0.0) * H or base + 0.5 * crown
    K.cylinder("Trunk", "BarkBrown", 0.11 * R, trunk_top, (0, 0, trunk_top / 2), verts=6)
    K.cone("RootFlare", "BarkBrownShade", 0.2 * R, 0.11 * R, 0.04 * H, (0, 0, 0.02 * H), verts=6)
    # dark core under and inside each tier
    for tier in tiers:
        depth = tier["h"] * 1.12
        K.cone("NeedlesCore", sp["core"], CORE_RATIO * tier["R"], 0.0, depth,
               (0, 0, tier["z"] - 0.12 * tier["h"] + depth / 2), verts=8)
    # needle tiers and leader
    for tier in tiers:
        star_cone("Needles", sp["needle"], tier["R"], R_TOP * tier["R"], tier["h"], (0, 0, tier["z"]),
                  tier["twist"], p, inner, droop)
    K.cone("Leader", sp["needle"], 0.12 * R, 0.0, leader_h, (0, 0, tip - leader_h / 2), verts=6)
    # snow band on every tier (its bottom lies inside the tier)
    for tier in tiers:
        s = _tier_band(tier, SNOW_FROM, SNOW_FROM + sp["snow"], SNOW_SCALE, SNOW_LIFT)
        star_cone("Snow", "SnowWhite", s["R"], s["r_top"], s["depth"], (0, 0, s["z"]), s["twist"], p,
                  s["inner"], s["droop"], cap_bottom=False)
    # accents
    if "frost" in accent:
        # silvery underside: the tier rim mirrored downwards (flipped about X)
        for tier in tiers:
            fd = FROST_DEPTH * tier["h"]
            star_cone("Frost", "NeedleFrost", tier["R"], FROST_INNER * tier["R"], fd, (0, 0, tier["z"]), -tier["twist"],
                      p, inner, -droop * tier["h"] / fd, cap_bottom=False, rot=(180, 0, 0))
    if "topper" in accent:
        centre = (0, 0, tip + TOPPER_LIFT)
        K.cylinder("Topper", "GoldAccent", 0.06, TOPPER_LIFT + 0.1, (0, 0, tip - 0.1 + (TOPPER_LIFT + 0.1) / 2),
                   verts=6)
        _topper(centre)
    if "berries" in accent:
        golden = math.pi * (3 - math.sqrt(5))
        k = 0
        for i, count in enumerate(BERRY_CLUSTERS):
            tier = tiers[i]
            for _ in range(count):
                point = int(round(k * golden / (2 * math.pi / p) + i * 3)) % p
                angle = tier["twist"] + point * 2 * math.pi / p
                rc = tier["R"] - 0.32
                cx, cy, cz = _ridge_point(tier, rc, angle, BERRY_R * 0.7)
                tx, ty = -math.sin(angle), math.cos(angle)  # tangent
                for m in range(3):
                    a = m * 2 * math.pi / 3 + 0.5
                    off_t, off_z = 0.15 * math.cos(a), 0.13 * math.sin(a)
                    K.ball("Berries", "RoofRed", BERRY_R,
                           (cx + tx * off_t, cy + ty * off_t, cz + off_z), detail=0)
                k += 1

    K.collider("Tree", (1.1 * R, 1.1 * R, H), (0, 0, H / 2))
    K.attachment("TreeBase", (0, 0, 0))
