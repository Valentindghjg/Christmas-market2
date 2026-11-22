"""Hollyberry Spruce Large (CM2-12): K.run(T.build("HollyberrySpruce", "Large")); shapes in ../../tree_common.py.

blender -b --factory-startup --python assets/art/source/Trees/HollyberrySpruce/Large/build.py -- --out assets/art/source/Trees/HollyberrySpruce/Large/model.blend
"""

import sys

sys.path[:0] = ["tools/art/kit", "assets/art/source/Trees"]
import cm2_kit as K, tree_common as T  # noqa: E401, E402

K.run(lambda: T.build("HollyberrySpruce", "Large"), tier="A")
