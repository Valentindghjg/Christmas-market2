"""Customer Hatchback (CM2-14): short nose, rear hatch leaning 15 degrees, roof rack.

blender -b --factory-startup --python assets/art/source/Vehicles/CustomerHatchback/build.py -- --out assets/art/source/Vehicles/CustomerHatchback/model.blend
"""

import sys

sys.path[:0] = ["tools/art/kit", "assets/art/source/Vehicles"]
import cm2_kit as K, vehicle_common as V  # noqa: E401, E402

K.seed(152)
K.run(lambda: V.car(V.CARS["CustomerHatchback"]), tier="A")
