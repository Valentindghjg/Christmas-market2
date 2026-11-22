"""Noble Fir Small (CM2-12): K.run(T.build("NobleFir", "Small")); shapes in ../../tree_common.py.

blender -b --factory-startup --python assets/art/source/Trees/NobleFir/Small/build.py -- --out assets/art/source/Trees/NobleFir/Small/model.blend
"""

import sys

sys.path[:0] = ["tools/art/kit", "assets/art/source/Trees"]
import cm2_kit as K, tree_common as T  # noqa: E401, E402

K.run(lambda: T.build("NobleFir", "Small"), tier="A")
