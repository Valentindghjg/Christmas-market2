"""SnowPileA (CM2-10D): long, low snow drift with two shaded lumps at its ends.

blender -b --factory-startup --python assets/art/source/Props/SnowPileA/build.py -- --out assets/art/source/Props/SnowPileA/model.blend

Origin = footprint centre on the ground, front -Y, studs, Z up. The mounds sink 0.2 into the
ground (bbox min z -0.2). Values: docs/archive/plans/CM2-10D.md.
"""

import sys

sys.path[:0] = ["tools/art/kit"]
import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import cm2_kit as K  # noqa: E402

FLOOR = -0.2


def mound(part, key, centre, radii, detail, floor=FLOOR, jitter=0.05):
    """Snow mound: icosphere scaled per axis, cut flat at floor. detail 1 = 80 triangles before the cut, 0 = 20."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=detail + 1, radius=1.0)
    for v in bm.verts:
        k = 1.0 + K._rng.uniform(-jitter, jitter)
        v.co = Vector((centre[0] + v.co.x * radii[0] * k, centre[1] + v.co.y * radii[1] * k,
                       centre[2] + v.co.z * radii[2] * k))
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0, 0, floor), plane_no=(0, 0, 1), clear_inner=True)
    mesh = bpy.data.meshes.new(part + "_" + key)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(part + "_" + key, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return K._finish_shape(obj, part, key, (0, 0, 0), (0, 0, 0), 0.0)


def build():
    K.seed(1101)
    mound("Drift", "SnowWhite", (0, 0, -0.2), (2.9, 1.9, 1.6), 1, jitter=0.03)
    # one lump in front at the left end, one behind at the right end, so both show
    for x, y in ((-2.0, -0.6), (2.0, 0.6)):
        mound("Lumps", "SnowShade", (x, y, 0.0), (1.0, 0.8, 0.66), 0, jitter=0.03)
    K.collider("Pile", (5.0, 3.0, 1.0), (0, 0, 0.5))


K.run(build, tier="B")
