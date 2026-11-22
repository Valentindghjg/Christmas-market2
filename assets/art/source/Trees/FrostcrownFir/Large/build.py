"""Frostcrown Fir Large (CM2-12): K.run(T.build("FrostcrownFir", "Large")); shapes in ../../tree_common.py.

blender -b --factory-startup --python assets/art/source/Trees/FrostcrownFir/Large/build.py -- --out assets/art/source/Trees/FrostcrownFir/Large/model.blend
"""

import sys

sys.path[:0] = ["tools/art/kit", "assets/art/source/Trees"]
import cm2_kit as K, tree_common as T  # noqa: E401, E402

K.run(lambda: T.build("FrostcrownFir", "Large"), tier="A")
