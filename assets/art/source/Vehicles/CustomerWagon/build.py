"""Customer Wagon (CM2-14): long flat roof, near-vertical tailgate, roof rack.

blender -b --factory-startup --python assets/art/source/Vehicles/CustomerWagon/build.py -- --out assets/art/source/Vehicles/CustomerWagon/model.blend
"""

import sys

sys.path[:0] = ["tools/art/kit", "assets/art/source/Vehicles"]
import cm2_kit as K, vehicle_common as V  # noqa: E401, E402

K.seed(153)
K.run(lambda: V.car(V.CARS["CustomerWagon"]), tier="A")
