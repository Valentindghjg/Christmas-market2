"""Shared customer-car builder for CM2-14 (Customer Hatchback, Wagon, SUV).

Each Vehicles/<Car>/build.py imports this module as V next to the kit (cm2_kit as K) and calls
K.run(lambda: V.car(V.CARS["<ID>"]), tier="A"). Units are studs, Z up, front = -Y, origin =
footprint centre on the wheel contact plane. Values: docs/plans/CM2-14.md; final values also in
DECISION_LOG ("CM2-14 vehicle art").

Every CarPaint shape has the part name Paint and the body is built first, so each car has one
MeshPart Paint__CarPaint that CM2-14W recolours from CAR_COLORS.
"""

import math

import bmesh
import bpy
import cm2_kit as K

W = 4.6  # body width
WHEEL_X, WHEEL_W = 2.05, 0.6
MIRROR_X = 2.5  # outer face of the mirrors
CABIN_FRONT_TAPER = 0.69  # windscreen about 24 degrees off vertical

CARS = {
    # L, wheel r, axles y, sill z, belt z, cabin y (from, to), roof z, rack length, plus own detail
    "CustomerHatchback": {
        "L": 8.0, "r": 0.7, "axles": (-2.6, 2.6), "sill": 0.5, "belt": 2.0,
        "cabin": (-1.0, 3.7), "roof": 3.55, "rack": 3.2,
        "rear_taper": 1.55 * math.tan(math.radians(15)),  # rear hatch leaning 15 degrees
        "half_top": 1.8, "rear_inset": 0.0, "arch_trim": False, "spare": False, "rocker": True,
        "spoiler": True, "grille_slats": True,
    },
    "CustomerWagon": {
        "L": 9.0, "r": 0.75, "axles": (-3.0, 3.0), "sill": 0.55, "belt": 2.05,
        "cabin": (-1.2, 4.3), "roof": 3.55, "rack": 4.0,
        "rear_taper": 0.12,  # long flat roof, near-vertical tailgate
        "half_top": 1.85, "rear_inset": 0.0, "arch_trim": False, "spare": False, "rocker": True,
        "spoiler": False, "grille_slats": True,
    },
    "CustomerSuv": {
        "L": 9.0, "r": 0.85, "axles": (-3.0, 3.0), "sill": 0.8, "belt": 2.5,
        "cabin": (-1.0, 4.0), "roof": 4.15, "rack": 3.6,
        "rear_taper": 0.25,  # boxy
        "half_top": 1.95, "rear_inset": 0.2,  # body ends 0.2 early so the spare wheel stays inside L
        "arch_trim": True, "spare": True, "rocker": False,
        "spoiler": False, "grille_slats": False,  # budget: slats go first on the SUV
    },
}


# ---------------------------------------------------------------- mesh helpers

def mesh(part, key, verts, faces, bevel=0.0):
    """Free closed mesh in world coordinates, normals recalculated, registered with the kit."""
    K._check(part, key)
    obj = K._mesh_object("%s__%s" % (part, key), verts, faces)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()
    return K._finish_shape(obj, part, key, (0, 0, 0), (0, 0, 0), bevel)


def extrude_x(part, key, profile, x0, x1, bevel=0.0):
    """Side profile [(y, z), ...] (one closed polygon) pushed across X from x0 to x1."""
    n = len(profile)
    verts = [(x0, y, z) for y, z in profile] + [(x1, y, z) for y, z in profile]
    faces = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))]
    faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    return mesh(part, key, verts, faces, bevel)


def loft(part, key, bottom, top, bevel=0.0):
    """Six-sided solid between two horizontal rectangles, each (half_x, y0, y1, z)."""
    def rect(hx, y0, y1, z):
        return [(-hx, y0, z), (hx, y0, z), (hx, y1, z), (-hx, y1, z)]
    verts = rect(*bottom) + rect(*top)
    faces = [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    return mesh(part, key, verts, faces, bevel)


def lerp(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def face_point(c, u, v):
    """Bilinear point on a quad face c = (bottom-a, bottom-b, top-b, top-a)."""
    return lerp(lerp(c[0], c[1], u), lerp(c[3], c[2], u), v)


def panel(part, key, c, u0, u1, v0, v1, outward, proud=0.05, depth=0.06):
    """Thin plate on face c (see face_point) between u0..u1 and v0..v1, standing proud of it.
    outward is a rough outward direction used to orient the face normal."""
    pts = [face_point(c, u0, v0), face_point(c, u1, v0), face_point(c, u1, v1), face_point(c, u0, v1)]
    e1 = [c[1][i] - c[0][i] for i in range(3)]
    e2 = [c[3][i] - c[0][i] for i in range(3)]
    n = (e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0])
    length = math.sqrt(sum(a * a for a in n))
    n = tuple(a / length for a in n)
    if sum(n[i] * outward[i] for i in range(3)) < 0:
        n = tuple(-a for a in n)
    front = [tuple(p[i] + n[i] * proud for i in range(3)) for p in pts]
    back = [tuple(p[i] - n[i] * depth for i in range(3)) for p in pts]
    faces = [(0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    return mesh(part, key, front + back, faces)


def wheel_z(r):
    """Wheel centre height: K.wheel is a 10-sided prism with a flat face at the bottom, so the
    centre sits at the apothem and that face rests on the contact plane z = 0."""
    return r * math.cos(math.pi / 10)


def arch_angles(zc, ra, sill, segments=7):
    """Angles (front to rear, over the top) where an arch of radius ra around the wheel centre
    (height zc) meets the sill line."""
    a0 = math.asin(max(-1.0, min(1.0, (sill - zc) / ra)))
    start, end = math.pi - a0, a0
    return [start + (end - start) * k / segments for k in range(segments + 1)]


def arch_band(part, key, side, axle, zc, ra, sill, width=0.2, x_in=0.04, x_out=0.08):
    """Wheel-arch trim: a band of width `width` following the arch on one body side."""
    hx = W / 2.0
    xs = (side * (hx - x_in), side * (hx + x_out))
    angles = arch_angles(zc, ra, sill, segments=3)
    ring = [(axle + ra * math.cos(a), zc + ra * math.sin(a)) for a in angles]
    ring += [(axle + (ra + width) * math.cos(a), zc + (ra + width) * math.sin(a)) for a in reversed(angles)]
    n, m = len(ring), len(angles)
    verts = [(xs[0], y, z) for y, z in ring] + [(xs[1], y, z) for y, z in ring]
    faces = [(i, i + 1, n - 2 - i, n - 1 - i) for i in range(m - 1)]  # inner side, as quads
    faces += [(n + d for d in f) for f in faces]
    faces = [tuple(f) for f in faces]
    faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    mesh(part, key, verts, faces)


def wheel(radius, width, loc, key="MetalDark", hub_key="StoneGray", axis="X"):
    """K.wheel without the inner hub cap (it sits inside the body; saves 28 triangles).
    The inner cap is the one nearer the car centre (x = 0 for axis X, the tailgate for Y)."""
    K.wheel(radius, width, loc, key=key, hub_key=hub_key, axis=axis)
    coord = 0 if axis == "X" else 1
    inner_first = loc[coord] >= 0  # K.wheel adds tyre, hub at -offset, hub at +offset
    _, _, obj = K._shapes.pop(-2 if inner_first else -1)
    bpy.data.objects.remove(obj, do_unlink=True)


def bow(loc, scale=1.0):
    """Small RoofRed ribbon bow facing -Y: knot, two loops, two tails."""
    x, y, z = loc
    s = scale
    K.box("Bow", "RoofRed", (0.16 * s, 0.1, 0.16 * s), (x, y, z))
    for side in (-1, 1):
        K.box("Bow", "RoofRed", (0.3 * s, 0.08, 0.2 * s), (x + side * 0.2 * s, y + 0.01, z + 0.05 * s),
              rot=(0, side * -25, 0))
        K.box("Bow", "RoofRed", (0.09 * s, 0.07, 0.26 * s), (x + side * 0.1 * s, y + 0.01, z - 0.18 * s),
              rot=(0, side * 20, 0))


# ---------------------------------------------------------------- the car

def car(spec):
    L, r, sill, belt, roof = spec["L"], spec["r"], spec["sill"], spec["belt"], spec["roof"]
    y0, y1 = spec["cabin"]
    hx = W / 2.0
    y_nose = -(L / 2.0 - 0.2)
    y_tail = L / 2.0 - 0.2 - spec["rear_inset"]
    ra = r + 0.12
    zc = wheel_z(r)
    H = roof + 0.45

    # -- lower body (Paint, built first): side profile with wheel arches, bonnet sloping 0.3
    profile = [(y_nose, sill)]
    for axle in spec["axles"]:
        for ang in arch_angles(zc, ra, sill):
            profile.append((axle + ra * math.cos(ang), zc + ra * math.sin(ang)))
    profile += [(y_tail, sill), (y_tail, belt), (y0, belt), (y_nose, belt - 0.3)]
    extrude_x("Paint", "CarPaint", profile, -hx, hx, bevel=0.15)

    # -- cabin (Paint), tapered at both ends and toward the roof
    hb, ht = hx - 0.15, spec["half_top"]
    ft, rt = CABIN_FRONT_TAPER, spec["rear_taper"]
    loft("Paint", "CarPaint", (hb, y0, y1, belt), (ht, y0 + ft, y1 - rt, roof), bevel=0.12)

    # -- mirrors (Paint) on MetalDark arms, outer face at x +-2.5
    for s in (-1, 1):
        K.box("Paint", "CarPaint", (0.25, 0.18, 0.3), (s * (MIRROR_X - 0.125), y0 + 0.4, belt + 0.32))
        K.box("Mirrors", "MetalDark", (0.3, 0.1, 0.1), (s * (hb + 0.08), y0 + 0.4, belt + 0.25))

    # -- wheels (tyres MetalDark, hubs StoneGray)
    for axle in spec["axles"]:
        for s in (-1, 1):
            wheel(r, WHEEL_W, (s * WHEEL_X, axle, zc))

    # -- glass: windscreen, rear glass, two side windows per side (0.05 proud)
    front = ((-hb, y0, belt), (hb, y0, belt), (ht, y0 + ft, roof), (-ht, y0 + ft, roof))
    rear = ((-hb, y1, belt), (hb, y1, belt), (ht, y1 - rt, roof), (-ht, y1 - rt, roof))
    panel("Glass", "GlassBlue", front, 0.07, 0.93, 0.12, 0.88, (0, -1, 0.3))
    panel("Glass", "GlassBlue", rear, 0.1, 0.9, 0.18, 0.86, (0, 1, 0.3))
    for s in (-1, 1):
        side = ((s * hb, y0, belt), (s * hb, y1, belt), (s * ht, y1 - rt, roof), (s * ht, y0 + ft, roof))
        panel("Glass", "GlassBlue", side, 0.06, 0.47, 0.14, 0.86, (s, 0, 0))
        panel("Glass", "GlassBlue", side, 0.53, 0.94, 0.14, 0.86, (s, 0, 0))

    # -- bumpers and grille (MetalDark), bow (RoofRed)
    bz = sill + 0.1
    K.box("Bumpers", "MetalDark", (W, 0.35, 0.45), (0, -(L / 2.0 - 0.175), bz), bevel=0.08)
    rear_depth = L / 2.0 - y_tail
    K.box("Bumpers", "MetalDark", (W, rear_depth + 0.05, 0.45), (0, L / 2.0 - (rear_depth + 0.05) / 2.0, bz),
          bevel=0.0 if spec["spare"] else 0.08)  # the SUV's deep rear step stays sharp (budget)
    g0, g1 = sill + 0.38, belt - 0.42
    K.box("Grille", "MetalDark", (2.0, 0.08, g1 - g0), (0, y_nose - 0.03, (g0 + g1) / 2.0))
    for k in range(1, 3) if spec["grille_slats"] else ():
        z = g0 + (g1 - g0) * k / 3.0
        K.box("Grille", "StoneGray", (1.8, 0.06, 0.06), (0, y_nose - 0.08, z))
    bow((0, y_nose - 0.12, (g0 + g1) / 2.0), scale=0.9)

    # -- lights
    for s in (-1, 1):
        K.box("Lights", "LightWarm", (0.8, 0.1, 0.35), (s * 1.6, y_nose - 0.03, belt - 0.62))
        K.box("TailLights", "RoofRed", (0.6, 0.1, 0.4), (s * 1.65, y_tail + 0.03, belt - 0.4))
        # dark surround so the red lights read on every paint colour
        K.box("TailLights", "MetalDark", (0.76, 0.06, 0.56), (s * 1.65, y_tail + 0.02, belt - 0.4))

    # -- own details
    if spec["arch_trim"]:
        for axle in spec["axles"]:
            for s in (-1, 1):
                arch_band("ArchTrim", "MetalDark", s, axle, zc, ra, sill)
    if spec["rocker"]:
        # MetalDark rocker strip along the sill between the wheel arches
        a_front, a_rear = spec["axles"]
        reach = ra * math.cos(arch_angles(zc, ra, sill)[-1])
        y_a, y_b = a_front + reach + 0.05, a_rear - reach - 0.05
        for s in (-1, 1):
            K.box("Rocker", "MetalDark", (0.1, y_b - y_a, 0.22), (s * (hx + 0.02), (y_a + y_b) / 2.0, sill + 0.13))
    if spec["spare"]:
        # spare wheel on the tailgate: plain 10-sided tyre and an outer hub (budget)
        sy = y_tail + 0.17
        K.cylinder("Wheels", "MetalDark", 0.7, 0.3, (0, sy, belt - 0.05), rot=(90, 0, 0), verts=10)
        K.cylinder("Wheels", "StoneGray", 0.32, 0.05, (0, sy + 0.17, belt - 0.05), rot=(90, 0, 0), verts=8)

    # -- roof rack (MetalDark): 2 rails on 4 feet, 2 crossbars, top at H
    top0, top1 = y0 + ft, y1 - rt
    yc = (top0 + top1) / 2.0
    rack = spec["rack"]
    rx = ht - 0.3
    for s in (-1, 1):
        K.box("Rack", "MetalDark", (0.15, rack, 0.15), (s * rx, yc, H - 0.075))
        for e in (-1, 1):
            foot_h = H - 0.15 - roof + 0.05
            K.box("Rack", "MetalDark", (0.22, 0.3, foot_h), (s * rx, yc + e * (rack / 2.0 - 0.25),
                                                            roof - 0.05 + foot_h / 2.0))
    for e in (-1, 1):
        K.box("Rack", "MetalDark", (2 * rx + 0.15, 0.15, 0.15), (0, yc + e * (rack / 2.0 - 0.55), H - 0.075))

    if spec["spoiler"]:
        # small roof spoiler over the leaning hatch
        K.box("Paint", "CarPaint", (2 * ht - 0.3, 0.5, 0.12), (0, y1 - rt + 0.12, roof + 0.2), rot=(-8, 0, 0))
        for s in (-1, 1):
            K.box("Paint", "CarPaint", (0.12, 0.3, 0.22), (s * (ht - 0.35), y1 - rt + 0.05, roof + 0.08))

    # -- snow: roof (under the rack) and bonnet
    K.snow_cap((2 * ht - 0.25, top1 - top0 - 0.25, 0.12), (0, yc, roof))
    bonnet = y0 - y_nose
    slope = math.degrees(math.atan2(0.3, bonnet))
    K.box("Snow", "SnowWhite", (W - 0.7, bonnet - 0.55, 0.12),
          (0, (y0 + y_nose) / 2.0 + 0.1, belt - 0.15 + 0.07), rot=(slope, 0, 0), bevel=0.05)

    # -- pipeline objects
    h = roof - 0.3
    K.collider("Body", (W, L, h), (0, 0, 0.3 + h / 2.0))
    K.attachment("CargoAnchor", (0, yc, H))
