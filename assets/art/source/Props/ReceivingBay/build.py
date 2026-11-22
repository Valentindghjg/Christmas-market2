"""Receiving Bay (CM2-13b): a 5 x 5 wooden pallet with corner stakes; tree bundles rest on its deck.

blender -b --factory-startup --python assets/art/source/Props/ReceivingBay/build.py -- --out assets/art/source/Props/ReceivingBay/model.blend

Deck top at 0.80 (today's bay top above lot ground); ATT_BundleBase sits there.
"""

import sys

sys.path[:0] = ["tools/art/kit"]
import cm2_kit as K  # noqa: E402

DECK_TOP = 0.80
STAKE = 2.27  # corner stake centres; band and snow cap stay inside the 5 x 5 footprint


def build():
    K.seed(142)
    rows = (-2.1, 0.0, 2.1)
    # nine blocks, three stringers along X on top of them
    for x in rows:
        for y in rows:
            K.box("Block", "WoodWarmShade", (0.7, 0.7, 0.35), (x, y, 0.175))
    for y in rows:
        K.box("Block", "WoodWarmShade", (5.0, 0.7, 0.15), (0, y, 0.425))
    # deck: seven boards, top at 0.80
    K.planks("Deck", "WoodWarm", 7, (4.9, 0.62, 0.3), (0, -2.19, DECK_TOP - 0.15), (0, 0.73, 0), jitter=0.08)
    # corner stakes with a red band and a snow cap
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * STAKE, sy * STAKE
            K.post("Stake", "WoodWarmShade", 1.65, (x, y, DECK_TOP), width=0.35, bevel=0.0)
            K.box("Band", "RoofRed", (0.41, 0.41, 0.3), (x, y, 1.9))
            K.snow_cap((0.45, 0.45, 0.15), (x, y, 2.45))
    # snow drifts on two deck corners, clear of the bundle rows (|y| <= 1.7)
    K.snow_cap((0.58, 0.44, 0.17), (-1.6, -2.15, DECK_TOP))
    K.snow_cap((0.5, 0.42, 0.15), (1.65, 2.16, DECK_TOP))
    K.collider("Pallet", (5.0, 5.0, 0.8), (0, 0, 0.4))
    K.attachment("BundleBase", (0, 0, DECK_TOP))


K.run(build, tier="A")
