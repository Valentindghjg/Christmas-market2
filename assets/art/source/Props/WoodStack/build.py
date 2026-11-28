"""WoodStack (CM2-10D): firewood pile of 4/3/2 bark logs along Y with light end grain at the
front, two holding stakes and a snow blanket on top.

blender -b --factory-startup --python assets/art/source/Props/WoodStack/build.py -- --out assets/art/source/Props/WoodStack/model.blend

Origin = footprint centre on the ground, front -Y, studs, Z up. Values: docs/plans/CM2-10D.md.
"""

import math
import sys

sys.path[:0] = ["tools/art/kit"]
import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import cm2_kit as K  # noqa: E402

R, LENGTH = 0.6, 2.2
ROWS = ((4, 0.6), (3, 1.64), (2, 2.68))


def end_grain(x, y, z, radius, twist):
    """Flat hexagon facing -Y on a log end (one face, 4 triangles; the back is never seen)."""
    verts = []
    for i in range(6):
        a = math.radians(twist + 60.0 * i)
        verts.append((radius * math.cos(a), 0.0, radius * math.sin(a)))
    obj = K._mesh_object("EndGrain_WoodWarm", verts, [tuple(range(6))])
    return K._finish_shape(obj, "EndGrain", "WoodWarm", (x, y, z), (0, 0, 0), 0.0)


def snow_blanket(centre, radii, jitter=0.04):
    """Snow mound on the top logs: half icosphere (80 triangles before the cut), bottom closed."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
    for v in bm.verts:
        k = 1.0 + K._rng.uniform(-jitter, jitter)
        v.co = Vector((centre[0] + v.co.x * radii[0] * k, centre[1] + v.co.y * radii[1] * k,
                       centre[2] + v.co.z * radii[2] * k))
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=centre, plane_no=(0, 0, 1), clear_inner=True)
    bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary])
    mesh = bpy.data.meshes.new("Snow_SnowWhite")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("Snow_SnowWhite", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return K._finish_shape(obj, "Snow", "SnowWhite", (0, 0, 0), (0, 0, 0), 0.0)


def build():
    K.seed(1105)
    for count, z in ROWS:
        for i in range(count):
            x = (i - (count - 1) / 2.0) * 1.2
            twist = K._rng.uniform(0, 60)
            dy = K._rng.uniform(-0.06, 0.06)
            K.cylinder("Logs", "BarkBrown", R, LENGTH, (x, dy, z), rot=(90, twist, 0), verts=6)
            end_grain(x, dy - LENGTH / 2.0 - 0.02, z, R * 0.82, twist)
    for x in (-2.6, 2.6):
        K.post("Logs", "BarkBrown", 3.2, (x, 0, 0), width=0.3, bevel=0.03)
        K.snow_cap((0.4, 0.4, 0.12), (x, 0, 3.2))
    snow_blanket((0, 0, 3.0), (1.55, 1.12, 0.55))  # soft mound instead of the flat cap
    K.collider("Stack", (5.4, 2.2, 3.2), (0, 0, 1.6))


K.run(build, tier="B")
