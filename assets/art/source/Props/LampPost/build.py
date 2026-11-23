"""Lamp Post (CM2-10b): dark iron street lamp with a warm lantern and a snowy cap.

blender -b --factory-startup --python assets/art/source/Props/LampPost/build.py -- --out assets/art/source/Props/LampPost/model.blend

Origin = foot centre on the ground, Z up, units are studs (rotationally symmetric; front -Y).
CM2-G12 adds a PointLight at ATT_Light. Values: docs/plans/CM2-10b.md; final values also in
DECISION_LOG ("CM2-10b village props art").
"""

import sys

sys.path[:0] = ["tools/art/kit", "assets/art/source/Buildings"]
import cm2_kit as K  # noqa: E402


def build():
    K.seed(174)
    # foot and eight-sided post
    K.box("Post", "MetalDark", (1.0, 1.0, 0.6), (0, 0, 0.3))
    K.box("Snow", "SnowWhite", (0.9, 0.9, 0.08), (0, 0, 0.64))
    K.cylinder("Post", "MetalDark", 0.22, 7.0, (0, 0, 4.1), verts=8)
    # lantern: bottom plate, four corner bars, warm glass, four-sided cap (turned 45 degrees so
    # its corners stay inside the 1.2 footprint)
    K.box("Post", "MetalDark", (1.0, 1.0, 0.15), (0, 0, 7.675))
    for sx in (-1, 1):
        for sy in (-1, 1):
            K.box("Post", "MetalDark", (0.12, 0.12, 1.1), (sx * 0.44, sy * 0.44, 8.15))
    K.box("Glass", "LightWarm", (0.8, 0.8, 1.0), (0, 0, 8.15))
    K.cone("Post", "MetalDark", 0.8, 0.1, 0.25, (0, 0, 8.825), rot=(0, 0, 45), verts=4)
    # snow on the cap, slightly overhanging its slope
    K.cone("Snow", "SnowWhite", 0.6, 0.12, 0.15, (0, 0, 8.885), rot=(0, 0, 45), verts=4)
    # pipeline objects
    K.collider("Post", (0.6, 0.6, 7.6), (0, 0, 3.8))
    K.attachment("Light", (0, 0, 8.15))


K.run(build, tier="B")
