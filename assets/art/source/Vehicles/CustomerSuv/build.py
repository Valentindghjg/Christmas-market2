"""Customer SUV (CM2-14): boxy, wheel-arch trims, spare wheel on the tailgate, roof rack.

blender -b --factory-startup --python assets/art/source/Vehicles/CustomerSuv/build.py -- --out assets/art/source/Vehicles/CustomerSuv/model.blend
"""

import sys

sys.path[:0] = ["tools/art/kit", "assets/art/source/Vehicles"]
import cm2_kit as K, vehicle_common as V  # noqa: E401, E402

K.seed(154)
K.run(lambda: V.car(V.CARS["CustomerSuv"]), tier="A")
