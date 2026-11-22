"""Supplier Truck (CM2-14): green flatbed with a wooden stake bed, headboard with string lights.

blender -b --factory-startup --python assets/art/source/Vehicles/SupplierTruck/build.py -- --out assets/art/source/Vehicles/SupplierTruck/model.blend

Front = -Y (cab), origin = footprint centre on the wheel contact plane. Built empty: CM2-14W
loads up to 9 Props/TreeBundle at CargoAnchor (deck top centre, inner bed x +-2.45, y -1.85..6.05).
"""

import sys

sys.path[:0] = ["tools/art/kit", "assets/art/source/Vehicles"]
import cm2_kit as K, vehicle_common as V  # noqa: E401, E402

DECK_TOP = 2.6


def front():
    K.box("Hood", "TruckGreen", (5.0, 1.5, 1.45), (0, -5.4, 2.675), bevel=0.15)
    K.box("Bumpers", "StoneGray", (5.4, 0.35, 0.5), (0, -6.33, 1.25), bevel=0.08)
    K.box("Grille", "MetalDark", (3.0, 0.08, 1.4), (0, -6.19, 2.2), bevel=0.03)
    for k in range(1, 5):
        K.box("Grille", "StoneGray", (2.7, 0.06, 0.07), (0, -6.24, 1.5 + 1.4 * k / 5.0))
    V.bow((0, -6.28, 2.55), scale=1.3)
    for s in (-1, 1):
        K.box("Lights", "LightWarm", (0.6, 0.1, 0.45), (s * 1.95, -6.2, 2.8))
    K.snow_cap((4.4, 1.1, 0.14), (0, -5.45, 3.4))


def cab():
    K.box("Cab", "TruckGreen", (5.4, 2.5, 3.65), (0, -3.4, 3.775), bevel=0.15)
    K.box("Skirt", "TruckGreenShade", (5.5, 2.6, 0.35), (0, -3.4, 2.125), bevel=0.06)
    # windscreen leaning back 8 degrees, side windows
    K.box("Glass", "GlassBlue", (4.6, 0.1, 1.6), (0, -4.72, 4.6), rot=(-8, 0, 0), bevel=0.03)
    for s in (-1, 1):
        K.box("Glass", "GlassBlue", (0.1, 1.6, 1.4), (s * 2.72, -3.35, 4.5), bevel=0.03)
        # mirror on an arm
        K.box("Mirrors", "MetalDark", (0.3, 0.1, 0.1), (s * 2.78, -4.4, 4.4))
        K.box("Mirrors", "MetalDark", (0.28, 0.18, 0.6), (s * 2.85, -4.4, 4.2))
        # step board under the door
        K.box("Steps", "MetalDark", (0.45, 1.4, 0.12), (s * 2.72, -3.0, 1.55))
        K.box("Steps", "MetalDark", (0.12, 0.12, 0.45), (s * 2.6, -3.0, 1.75))
        # door handle
        K.box("Steps", "MetalDark", (0.08, 0.35, 0.1), (s * 2.72, -2.6, 3.45))
    K.snow_cap((5.0, 2.2, 0.4), (0, -3.4, 5.6))


def chassis():
    K.box("Chassis", "MetalDark", (3.4, 12.4, 0.5), (0, 0, 1.25), bevel=0.05)
    for y in (-4.6, 3.6):
        for s in (-1, 1):
            K.wheel(0.95, 0.7, (s * 2.35, y, V.wheel_z(0.95)))  # flat bottom face on z = 0
    for s in (-1, 1):
        K.box("Chassis", "MetalDark", (0.6, 0.1, 0.7), (s * 2.35, 4.7, 1.6))
        K.box("Chassis", "MetalDark", (0.75, 0.12, 0.12), (s * 2.0, 4.7, 1.9))


def bed():
    K.box("BedFrame", "TruckGreenShade", (5.4, 8.3, 0.35), (0, 2.15, 2.125), bevel=0.06)
    K.planks("Deck", "WoodWarm", 7, (0.74, 8.3, 0.3), (-2.28, 2.15, DECK_TOP - 0.15), (0.76, 0, 0),
             bevel=0.03, jitter=0.05)
    # headboard: lower panel, 2 posts, top rail and 4 bars; string lights between the post tops
    K.box("Headboard", "MetalDark", (5.4, 0.2, 0.8), (0, -1.95, 3.0), bevel=0.04)
    K.box("Headboard", "MetalDark", (5.4, 0.2, 0.25), (0, -1.95, 4.675), bevel=0.04)
    for s in (-1, 1):
        K.box("Headboard", "MetalDark", (0.25, 0.25, 2.7), (s * 2.575, -1.95, 3.95), bevel=0.04)
    for x in (-1.5, -0.5, 0.5, 1.5):
        K.box("Headboard", "MetalDark", (0.15, 0.15, 1.2), (x, -1.95, 4.0))
    K.string_lights((-2.575, -1.95, 5.3), (2.575, -1.95, 5.3), 7, sag=0.3)
    # stakes and side rails
    for s in (-1, 1):
        for y in (-1.75, 0.2, 2.15, 4.1, 6.05):
            K.box("Stakes", "WoodWarmShade", (0.25, 0.25, 1.3), (s * 2.58, y, DECK_TOP + 0.65))
        for z in (3.15, 3.7):
            K.box("Rails", "WoodWarm", (0.15, 8.0, 0.3), (s * 2.62, 2.15, z), bevel=0.04)
    K.box("Rails", "WoodWarm", (5.0, 0.15, 1.2), (0, 6.2, DECK_TOP + 0.6), bevel=0.04)
    # rear
    K.box("Bumpers", "StoneGray", (5.0, 0.2, 0.4), (0, 6.4, 1.3), bevel=0.05)
    for s in (-1, 1):
        K.box("TailLights", "RoofRed", (0.5, 0.1, 0.3), (s * 2.2, 6.45, 2.1))
    # snow on the headboard top rail
    K.snow_cap((5.0, 0.22, 0.1), (0, -1.95, 4.8))


def build():
    K.seed(151)
    cab()
    front()
    chassis()
    bed()
    K.collider("Cab", (5.4, 4.35, 4.6), (0, -4.33, 3.3))
    K.collider("Bed", (5.4, 8.5, 2.3), (0, 2.25, 1.45))
    K.attachment("CargoAnchor", (0, 2.1, DECK_TOP))


K.run(build, tier="A")
