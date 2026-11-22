"""Tree Bundle (CM2-13b): a netted fir lying along X, the delivery bundle on a receiving bay.

blender -b --factory-startup --python assets/art/source/Props/TreeBundle/build.py -- --out assets/art/source/Props/TreeBundle/model.blend

Origin = bottom centre (the body's lowest edge touches z 0), long axis X, butt end at -X.
"""

import sys

sys.path[:0] = ["tools/art/kit"]
import cm2_kit as K  # noqa: E402

AXIS_Z = 0.5  # body axis height: the widest radius 0.5 touches the ground
ALONG_X = (0, 90, 0)  # a kit cone/cylinder along Z turned so -Z becomes -X
BODY = [(-1.6, 0.45), (-0.6, 0.5), (2.0, 0.15)]  # (x, radius) profile of the netted crown


def radius_at(x):
    for (x0, r0), (x1, r1) in zip(BODY, BODY[1:]):
        if x0 <= x <= x1:
            return r0 + (r1 - r0) * (x - x0) / (x1 - x0)
    raise ValueError(x)


def build():
    K.seed(143)
    for (x0, r0), (x1, r1) in zip(BODY, BODY[1:]):
        K.cone("Needles", "NeedleGreen", r0, r1, x1 - x0, ((x0 + x1) / 2.0, 0, AXIS_Z), rot=ALONG_X)
    for x in (-1.2, -0.4, 0.4, 1.2):
        K.cylinder("Net", "FabricCream", radius_at(x) + 0.04, 0.12, (x, 0, AXIS_Z), rot=ALONG_X)
    K.cylinder("Trunk", "BarkBrown", 0.15, 0.4, (-1.8, 0, AXIS_Z), rot=ALONG_X)


K.run(build, tier="B")
