"""Shared parts for the CM2-13a HQ tiers (Sales Tent, Timber Pavilion, Alpine Hut, Mountain Chalet).

Each Buildings/<Tier>/build.py imports this module as H next to the kit (cm2_kit as K).
Units are studs, Z up, front = -Y, origin = ground pivot. Values: docs/plans/CM2-13a.md;
final values also in DECISION_LOG ("CM2-13a HQ art").
"""

import math

import bmesh
import cm2_kit as K
from mathutils import Vector


# ---------------------------------------------------------------- mesh helpers

def mesh(part, key, verts, faces, bevel=0.0, recalc=True):
    """Free mesh in world coordinates, registered with the kit (joined per palette key)."""
    K._check(part, key)
    obj = K._mesh_object("%s__%s" % (part, key), verts, faces)
    if recalc:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(obj.data)
        bm.free()
        obj.data.update()
    return K._finish_shape(obj, part, key, (0, 0, 0), (0, 0, 0), bevel)


def slab(part, key, top, thick, bevel=0.0):
    """Closed solid: the polygon `top` (3D points, any winding) pushed down by thick in Z."""
    n = len(top)
    verts = [tuple(p) for p in top] + [(p[0], p[1], p[2] - thick) for p in top]
    faces = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))]
    faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    return mesh(part, key, verts, faces, bevel)


def pennant(part, key, a, b, c):
    """Flat triangle seen from both sides (valance flags)."""
    return mesh(part, key, [a, b, c], [(0, 1, 2), (0, 2, 1)], recalc=False)


def log(part, key, axis, start, end, centre, radius, cap_key=None, sides=6, ends=(True, True)):
    """Six-sided log from start to end along axis "X" or "Y" (no end faces); centre is the
    (other horizontal, z) position. cap_key adds a darker end disc on both ends."""
    def point(t, ang):
        u, v = centre[0] + radius * math.cos(ang), centre[1] + radius * math.sin(ang)
        return (t, u, v) if axis == "X" else (u, t, v)

    angles = [math.radians(30 + 60 * k) for k in range(sides)]
    verts = [point(start, a) for a in angles] + [point(end, a) for a in angles]
    faces = [(k, (k + 1) % sides, sides + (k + 1) % sides, sides + k) for k in range(sides)]
    obj = mesh(part, key, verts, faces, recalc=False)
    # side faces of an X log point outward with this order; a Y log is mirrored, so flip it
    if axis == "Y":
        for poly in obj.data.polygons:
            poly.flip()
    if cap_key:
        for t, sign, wanted in ((start, -1, ends[0]), (end, 1, ends[1])):
            if not wanted:
                continue
            ring = [point(t + sign * 0.02, a) for a in angles]
            disc = mesh("LogEnds", cap_key, ring, [tuple(range(sides))], recalc=False)
            normal = Vector((sign, 0, 0)) if axis == "X" else Vector((0, sign, 0))
            if disc.data.polygons[0].normal.dot(normal) < 0:
                disc.data.polygons[0].flip()
    return obj


# ---------------------------------------------------------------- HQ parts (plan table)

def desk(loc, width, body_key="WoodWarmShade"):
    """Desk 0.9 deep, top at loc z + 3.2 (WoodWarm top, body in body_key); loc = floor point
    under its centre. Returns the desk-top centre point."""
    x, y, z = loc
    K.box("Desk", body_key, (width - 0.3, 0.75, 3.0), (x, y + 0.03, z + 1.5), bevel=0.04)
    K.box("Desk", "WoodWarm", (width, 0.9, 0.2), (x, y, z + 3.1), bevel=0.04)
    return (x, y, z + 3.2)


def computer(loc):
    """Monitor 1.4 x 0.2 x 1.0 on a stand plus keyboard (MetalDark), screen 1.2 x 0.8 facing -Y
    (LightWarm); loc = desk-top point under the monitor."""
    x, y, z = loc
    K.box("Computer", "MetalDark", (0.6, 0.4, 0.06), (x, y + 0.15, z + 0.03))
    K.box("Computer", "MetalDark", (0.16, 0.16, 0.5), (x, y + 0.15, z + 0.3))
    K.box("Computer", "MetalDark", (1.4, 0.2, 1.0), (x, y + 0.1, z + 1.0), bevel=0.04)
    K.box("Computer", "LightWarm", (1.2, 0.04, 0.8), (x, y - 0.01, z + 1.0))
    K.box("Computer", "MetalDark", (1.1, 0.35, 0.06), (x, y - 0.3, z + 0.03))


def radio(loc, body_key):
    """Radio box 1.0 x 0.5 x 0.6 in body_key with a LightWarm dial; loc = its foot point."""
    x, y, z = loc
    K.box("Radio", body_key, (1.0, 0.5, 0.6), (x, y, z + 0.3), bevel=0.06)
    K.box("Radio", "LightWarm", (0.45, 0.04, 0.18), (x - 0.15, y - 0.26, z + 0.38))
    K.box("Radio", body_key, (0.06, 0.06, 0.5), (x + 0.35, y + 0.12, z + 0.85))  # antenna


def bow(loc, key, size=0.7, facing="-Y"):
    """Ribbon bow of two small prisms meeting at loc (loops point left and right)."""
    w = size / 2.0
    for side in (-1, 1):
        if facing in ("-Y", "Y"):
            c = (loc[0] + side * w / 2.0, loc[1], loc[2])
            K.prism("Bows", key, size * 0.75, 0.16, w, c, rot=(0, -side * 90, 0))
        else:
            c = (loc[0], loc[1] + side * w / 2.0, loc[2])
            K.prism("Bows", key, size * 0.75, 0.16, w, c, rot=(0, -side * 90, 90))


def chain_points(start, end, spacing, sag):
    a, b = Vector(start), Vector(end)
    count = max(2, int(round((b - a).length / spacing)) + 1)
    points = []
    for index in range(count):
        t = index / (count - 1)
        p = a.lerp(b, t)
        p.z -= sag * 4.0 * t * (1.0 - t)
        points.append(p)
    return points


def garland(start, end, bows, bow_key, sag=0.5, spacing=0.45, radius=0.3, facing="-Y", bow_size=0.7):
    """Sagging chain of K.ball detail 0 (NeedleGreen) from start to end; `bows` bows in bow_key
    spread along it (None = no bows). Returns the chain points."""
    points = chain_points(start, end, spacing, sag)
    for p in points:
        K.ball("Garland", "NeedleGreen", radius, tuple(p), detail=0)
    if bow_key and bows:
        for index in range(bows):
            t = (index + 0.5) / bows
            p = Vector(start).lerp(Vector(end), t)
            p.z -= sag * 4.0 * t * (1.0 - t)
            off = Vector((0, -radius - 0.05, 0)) if facing == "-Y" else Vector((radius + 0.05, 0, 0)) \
                if facing == "X" else Vector((-radius - 0.05, 0, 0))
            bow(tuple(p + off), bow_key, bow_size, facing)
    return points


def baubles(points, key, radius=0.18, every=6, drop=0.35):
    """Small balls hanging under every n-th chain point (K.ball detail 0)."""
    for index in range(every // 2, len(points), every):
        p = points[index]
        K.ball("Baubles", key, radius, (p.x, p.y, p.z - drop), detail=0)


def lantern(loc, frame_key):
    """Lantern: frame 0.5 x 0.5 x 0.8 in frame_key (cap, base, crossed bars, hanger) around a
    LightWarm core 0.3 cube; loc = centre."""
    x, y, z = loc
    K.box("Lantern", frame_key, (0.62, 0.62, 0.14), (x, y, z + 0.4))
    K.box("Lantern", frame_key, (0.5, 0.5, 0.1), (x, y, z - 0.38))
    K.box("Lantern", frame_key, (0.5, 0.06, 0.7), (x, y, z))
    K.box("Lantern", frame_key, (0.06, 0.5, 0.7), (x, y, z))
    K.box("Lantern", "LightWarm", (0.34, 0.34, 0.6), (x, y, z))
    K.box("Lantern", frame_key, (0.06, 0.06, 0.3), (x, y, z + 0.6))


def counter(x0, x1, y, floor_z, bows, bow_key):
    """Front counter from x0 to x1, 1.2 deep, centred on y, top at floor_z + 3.6: WoodWarm planks
    (jitter 0.12), WoodWarmShade top board, `bows` bows on the -Y face. Returns the top z."""
    length, cx = x1 - x0, (x0 + x1) / 2.0
    top = floor_z + 3.6
    body = top - 0.2 - floor_z
    count = 4
    h = body / count
    K.planks("Counter", "WoodWarm", count, (length - 0.2, 1.1, h - 0.06), (cx, y, floor_z + h / 2.0),
             (0, 0, h), bevel=0.03, jitter=0.12)
    K.box("Counter", "WoodWarmShade", (length, 1.4, 0.2), (cx, y - 0.05, top - 0.1), bevel=0.05)
    for x in (x0 + 0.25, x1 - 0.25):
        K.box("Counter", "WoodWarmShade", (0.4, 1.2, body), (x, y - 0.02, floor_z + body / 2.0))
    if bow_key and bows:
        for index in range(bows):
            x = x0 + length * (index + 0.5) / bows
            bow((x, y - 0.66, top - 0.85), bow_key, 1.1)
    return top


def star(loc, size, key, facing="-Y", depth=0.2):
    """Flat 5-point star (size = tip-to-tip across) facing -Y; loc = centre."""
    r_out, r_in = size / 2.0, size / 2.0 * 0.45
    ring = []
    for index in range(10):
        ang = math.radians(90 + 36 * index)
        r = r_out if index % 2 == 0 else r_in
        ring.append((loc[0] + r * math.cos(ang), loc[2] + r * math.sin(ang)))
    front = [(u, loc[1] - depth / 2.0, v) for u, v in ring]
    back = [(u, loc[1] + depth / 2.0, v) for u, v in ring]
    verts = [(loc[0], loc[1] - depth / 2.0 - 0.12, loc[2])] + front + back + [(loc[0], loc[1] + depth / 2.0, loc[2])]
    faces = []
    for index in range(10):
        a, b = 1 + index, 1 + (index + 1) % 10
        faces.append((0, a, b))
        faces.append((21, 11 + (index + 1) % 10, 11 + index))
        faces.append((a, 11 + index, 11 + (index + 1) % 10, b))
    return mesh("Star", key, verts, faces)


def gable_snow(span, depth, height, base_z, overhang, cover=0.55, segments=6, thick=0.3):
    """Snow on the upper part of a K.gable_roof (call it with snow=False): one slab per side from
    the ridge down to `cover` of the slope, with a soft scalloped lower edge."""
    run = span / 2.0 + overhang
    pitch = height / (span / 2.0)
    half = depth / 2.0 + overhang - 0.12
    ridge = base_z + height
    for side in (-1, 1):
        ys = [-half + 2 * half * k / segments for k in range(segments + 1)]
        reach = [run * (cover + K._rng.uniform(-0.03, 0.05)) for _ in ys]
        reach[0] = reach[-1] = run * cover
        top_r = [(side * 0.0, y, ridge + 0.02 + thick) for y in ys]
        top_l = [(side * u, y, ridge - u * pitch + 0.02 + thick) for u, y in zip(reach, ys)]
        n = len(ys)
        pts = top_r + top_l
        verts = pts + [(p[0], p[1], p[2] - thick) for p in pts]
        b = 2 * n
        faces = []
        for k in range(n - 1):
            faces.append((k, k + 1, n + k + 1, n + k))  # top
            faces.append((b + k, b + n + k, b + n + k + 1, b + k + 1))  # bottom
            faces.append((n + k, n + k + 1, b + n + k + 1, b + n + k))  # lower edge
            faces.append((k + 1, k, b + k, b + k + 1))  # ridge edge
        faces.append((0, n, b + n, b))
        faces.append((n - 1, b + n - 1, b + 2 * n - 1, 2 * n - 1))
        mesh("Snow", "SnowWhite", verts, faces)
