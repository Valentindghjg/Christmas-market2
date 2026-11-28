"""Snowman (CM2-10D): three snow balls, dark top hat, coal eyes and buttons, stick arms,
red scarf and a carrot nose. Faces -Y.

blender -b --factory-startup --python assets/art/source/Props/Snowman/build.py -- --out assets/art/source/Props/Snowman/model.blend

Origin = footprint centre on the ground, front -Y, studs, Z up. The bottom ball is cut flat at
z 0 so the snowman stands on the ground. Values: docs/archive/plans/CM2-10D.md.
"""

import math
import sys

sys.path[:0] = ["tools/art/kit"]
import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import cm2_kit as K  # noqa: E402

FLOOR = 0.0


def mound(part, key, centre, radii, detail, floor=FLOOR, jitter=0.05):
    """Snow ball: icosphere scaled per axis, cut flat at floor. detail 1 = 80 triangles before the cut, 0 = 20."""
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


def on_surface(centre, radius, x, z, inset=0.03):
    """Point on the -Y side of a ball at height z and offset x."""
    dz = z - centre[2]
    return (x, centre[1] - math.sqrt(max(radius * radius - x * x - dz * dz, 0.0)) + inset, z)


def stick(part, key, start, angle_from_up, side, length, radius=0.07):
    """4-sided stick from start, tilted in the XZ plane (angle_from_up degrees, side -1 or 1)."""
    a = math.radians(angle_from_up)
    d = (side * math.sin(a), 0.0, math.cos(a))
    mid = tuple(start[i] + d[i] * length / 2.0 for i in range(3))
    K.cylinder(part, key, radius, length, mid, rot=(0, side * angle_from_up, 0), verts=4)
    return tuple(start[i] + d[i] * length for i in range(3))


def build():
    K.seed(1103)
    base, torso, head = (0, 0, 1.2), (0, 0, 2.9), (0, 0, 4.3)
    mound("Body", "SnowWhite", base, (1.3, 1.15, 1.3), 1, jitter=0.03)
    mound("Body", "SnowWhite", torso, (0.95, 0.95, 0.95), 1, jitter=0.03)
    mound("Body", "SnowWhite", head, (0.7, 0.7, 0.7), 1, jitter=0.02)
    # top hat
    K.cylinder("Coal", "MetalDark", 0.8, 0.1, (0, 0, 4.9), verts=8)
    K.cylinder("Coal", "MetalDark", 0.55, 0.8, (0, 0, 5.35), verts=8)
    # eyes and buttons
    for x in (-0.25, 0.25):
        K.ball("Coal", "MetalDark", 0.09, on_surface(head, 0.7, x, 4.45), detail=0)
    for z in (3.2, 2.85, 2.5):
        K.ball("Coal", "MetalDark", 0.09, on_surface(torso, 0.95, 0, z), detail=0)
    # stick arms, 34 degrees above horizontal, each with one twig
    for side in (-1, 1):
        start = (side * 0.55, 0, 3.0)
        end = stick("Coal", "MetalDark", start, 56, side, 1.4)
        fork = tuple(start[i] * 0.3 + end[i] * 0.7 for i in range(3))
        stick("Coal", "MetalDark", fork, 15, side, 0.4, radius=0.05)
    # scarf ring with a tail at the front left, carrot nose pointing -Y
    K.cylinder("Scarf", "RoofRed", 0.75, 0.3, (0, 0, 3.6), verts=8)
    K.box("Scarf", "RoofRed", (0.3, 0.1, 0.8), (-0.35, -0.72, 3.2), rot=(8, 0, -10))
    K.cone("Scarf", "RoofRed", 0.12, 0.0, 0.6, (0, -0.88, 4.3), rot=(90, 0, 0), verts=6)
    K.collider("Body", (2.4, 2.4, 4.6), (0, 0, 2.3))


K.run(build, tier="B")
