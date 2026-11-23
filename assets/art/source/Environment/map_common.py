"""Shared shapes for the CM2-10c nature art: mountain heightfields, faceted rocks and firs sized by top.

Units are studs, Z up, front = -Y (the valley side), origin = footprint centre at ground.
Values: docs/plans/CM2-10c.md; final values also in DECISION_LOG ("CM2-10c nature art").
"""

import math

import cm2_kit as K
import hq_common as H

BASE_Z = -12.0  # mountains are sunk 12 studs below the ground
FOOT_SNOW_Z = 4.0  # faces below this centroid height are the snowy foot


# ---------------------------------------------------------------- firs

def fir_top_factor(tiers):
    """Top of K.fir divided by its height argument (trunk 0.14 h, tier height crown / tiers x 1.35)."""
    return 0.14 + 0.86 * ((tiers - 1) / tiers + 1.35 / tiers)


def fir(top, base_radius, loc, tiers, verts, needle_key="NeedleGreen"):
    """K.fir whose highest point is exactly `top` (the kit's height argument is the crown start scale)."""
    K.fir(top / fir_top_factor(tiers), base_radius, loc, tiers=tiers, needle_key=needle_key, verts=verts)


# ---------------------------------------------------------------- rocks

_PHI = (1.0 + math.sqrt(5.0)) / 2.0
_ICO_VERTS = [(-1, _PHI, 0), (1, _PHI, 0), (-1, -_PHI, 0), (1, -_PHI, 0),
              (0, -1, _PHI), (0, 1, _PHI), (0, -1, -_PHI), (0, 1, -_PHI),
              (_PHI, 0, -1), (_PHI, 0, 1), (-_PHI, 0, -1), (-_PHI, 0, 1)]
_ICO_FACES = [(0, 11, 5), (0, 5, 1), (0, 1, 7), (0, 7, 10), (0, 10, 11), (1, 5, 9), (5, 11, 4),
              (11, 10, 2), (10, 7, 6), (7, 1, 8), (3, 9, 4), (3, 4, 2), (3, 2, 6), (3, 6, 8),
              (3, 8, 9), (4, 9, 5), (2, 4, 11), (6, 2, 10), (8, 6, 7), (9, 8, 1)]


def _unit(v):
    n = math.sqrt(v[0] ** 2 + v[1] ** 2 + v[2] ** 2)
    return (v[0] / n, v[1] / n, v[2] / n)


def _sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def _normal(a, b, c):
    return _unit(_cross(_sub(b, a), _sub(c, a)))


def icosphere1():
    """Unit icosahedron subdivided once: 42 vertices, 80 faces wound outward.
    The edge midpoints include the six axis points (+-X, +-Y, +-Z)."""
    verts = [_unit(v) for v in _ICO_VERTS]
    cache = {}

    def mid(i, j):
        key = (min(i, j), max(i, j))
        if key not in cache:
            a, b = verts[i], verts[j]
            verts.append(_unit(((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2)))
            cache[key] = len(verts) - 1
        return cache[key]

    faces = []
    for a, b, c in _ICO_FACES:
        ab, bc, ca = mid(a, b), mid(b, c), mid(c, a)
        faces += [(a, ab, ca), (b, bc, ab), (c, ca, bc), (ab, bc, ca)]
    return verts, faces


def rock(part, size, loc, jitter=0.12, keys=("SnowWhite", "StoneGray", "StoneGrayShade")):
    """Faceted rock: icosphere (80 faces) scaled by the half-extents `size`, centred on loc, each
    vertex jittered by +-jitter (K.seed). The six axis points keep their exact extent, so the rock's
    bounding box is exactly loc +- size. Faces: normal z > 0.6 snow, normal z < -0.1 shade, else stone;
    one mesh per key."""
    unit, faces = icosphere1()
    verts = []
    for v in unit:
        axis_point = max(abs(v[0]), abs(v[1]), abs(v[2])) > 0.999
        f = 1.0 if axis_point else 1.0 + K._rng.uniform(-jitter, jitter)
        verts.append(tuple(loc[a] + v[a] * size[a] * f for a in range(3)))
    groups = {}
    for face in faces:
        n = _normal(*(verts[i] for i in face))
        if n[2] > 0.6:
            key = keys[0]
        elif n[2] < -0.1:
            key = keys[2]
        else:
            key = keys[1]
        groups.setdefault(key, []).append(face)
    for key, group in groups.items():
        # the icosphere is wound outward; bmesh recalc flipped isolated faces on small patches (CM2-10c review)
        _emit(part, key, verts, group, recalc=False)


# ---------------------------------------------------------------- mountains

def _emit(part, key, verts, faces, recalc):
    """One mesh for `faces` (indices into verts) with only the vertices it uses."""
    remap, local = {}, []
    out = []
    for face in faces:
        new = []
        for i in face:
            if i not in remap:
                remap[i] = len(local)
                local.append(verts[i])
            new.append(remap[i])
        out.append(tuple(new))
    return H.mesh(part, key, local, out, recalc=recalc)


def summit_height(x, y, summits):
    best = 0.0
    for xs, ys, h, ax, by in summits:
        d = min(1.0, math.sqrt(((x - xs) / ax) ** 2 + ((y - ys) / by) ** 2))
        best = max(best, h * (1.0 - d) ** 1.3)
    return best + BASE_Z


def heightfield(spec):
    """Faceted mountain as an open surface (normals up). spec: width, length, step, summits
    [(xs, ys, h, ax, by)], snow_line, part. Interior vertices jitter x, y +-0.25 step and z +-3;
    rim vertices lie on the base and summit vertices stay exact; no vertex drops below the base.
    Cells whose four corners all have formula height at the base are dropped."""
    w, l, s = spec["width"], spec["length"], spec["step"]
    nx, ny = int(round(w / s)), int(round(l / s))
    summits = spec["summits"]
    peaks = {(xs, ys) for xs, ys, _, _, _ in summits}
    verts, base = [], []
    for j in range(ny + 1):
        for i in range(nx + 1):
            x, y = -w / 2 + i * s, -l / 2 + j * s
            z = summit_height(x, y, summits)
            base.append(abs(z - BASE_Z) < 1e-9)
            rim = i in (0, nx) or j in (0, ny)
            if rim:
                z = BASE_Z  # the open surface ends at the sunk base, so no cut edge shows above ground
            peak = any(abs(x - px) < 1e-6 and abs(y - py) < 1e-6 for px, py in peaks)
            if not rim and not peak:
                x += K._rng.uniform(-0.25, 0.25) * s
                y += K._rng.uniform(-0.25, 0.25) * s
                z = max(BASE_Z, z + K._rng.uniform(-3.0, 3.0))  # never below the sunk base
            verts.append((x, y, z))
    for px, py in peaks:
        if not any(abs(v[0] - px) < 1e-6 and abs(v[1] - py) < 1e-6 for v in verts):
            raise ValueError("summit (%s, %s) is not a grid vertex" % (px, py))

    def index(i, j):
        return j * (nx + 1) + i

    groups = {}
    for j in range(ny):
        for i in range(nx):
            a, b, c, d = index(i, j), index(i + 1, j), index(i + 1, j + 1), index(i, j + 1)
            if base[a] and base[b] and base[c] and base[d]:
                continue
            # counter-clockwise seen from above; the diagonal alternates
            tris = [(a, b, c), (a, c, d)] if (i + j) % 2 == 0 else [(a, b, d), (b, c, d)]
            for tri in tris:
                p = [verts[k] for k in tri]
                n = _normal(*p)
                zc = (p[0][2] + p[1][2] + p[2][2]) / 3.0
                if zc < FOOT_SNOW_Z:
                    key = "SnowWhite"
                elif zc >= spec["snow_line"]:
                    key = "SnowWhite" if n[0] <= 0 else "SnowShade"
                else:
                    key = "MountainRock" if n[0] <= 0 else "MountainRockShade"
                groups.setdefault(key, []).append(tri)
    for key, faces in groups.items():
        _emit(spec.get("part", "Mountain"), key, verts, faces, recalc=False)
