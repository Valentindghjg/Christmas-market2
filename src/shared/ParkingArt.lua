--!strict
-- The customer car park outside the front fence (CM2-PARK, docs/plans/CM2-PARK.md): pure part
-- specs of the parking bays (pad, side lines, wheel stop) and the fixtures (drive slabs, "P" sign,
-- two lamps). Quality tier B. Every spec is in the lot frame (x from the plot centre, z toward
-- the road); a part's centre height is lotTop + dy. ParkingWorld builds them; no Roblox types.
local GameConfig = require(script.Parent.GameConfig)
local VehicleArt = require(script.Parent.VehicleArt)

local ParkingArt = {}

export type Spec = {
	name: string,
	size: { number },
	x: number,
	z: number,
	dy: number,
	rgb: { number },
	material: string,
	collide: boolean,
}
export type Fixture = { name: string, parts: { Spec }, lightPart: string? }
export type Box = { id: string, minX: number, maxX: number, minZ: number, maxZ: number }

local ASPHALT = { 54, 58, 61 }
local WHITE = { 240, 244, 248 }
local METAL = { 52, 58, 64 }
local BLUE = { 36, 92, 168 }
local STOP = { 214, 170, 72 }
local LAMP = { 255, 214, 140 }

local function carPark()
	return GameConfig.Placement.CarPark
end

local function spec(
	name: string,
	size: { number },
	x: number,
	z: number,
	dy: number,
	rgb: { number },
	material: string,
	collide: boolean
): Spec
	return { name = name, size = size, x = x, z = z, dy = dy, rgb = rgb, material = material, collide = collide }
end

-- The pad of parking space `space` and its marks (LineL, LineR, Stop), which sit 0.01 above it.
function ParkingArt.bay(space: number): { pad: Spec, marks: { Spec } }
	local park = carPark()
	local x, d, r = park.X[space], park.Depth, VehicleArt.PARKING_RISE
	local length = park.PadLength
	local lineX = park.PadWidth / 2 - 0.3
	return {
		pad = spec("Parking_" .. space, { park.PadWidth, 0.9, length }, x, d, r - 0.45, ASPHALT, "Asphalt", true),
		marks = {
			spec("LineL", { 0.3, 0.06, length - 1 }, x - lineX, d, r + 0.04, WHITE, "SmoothPlastic", false),
			spec("LineR", { 0.3, 0.06, length - 1 }, x + lineX, d, r + 0.04, WHITE, "SmoothPlastic", false),
			spec("Stop", { 4, 0.3, 0.5 }, x, d - length / 2 + 1.25, r + 0.16, STOP, "Concrete", false),
		},
	}
end

-- The drive slabs (CarPark_DriveL always, CarPark_DriveR from 2 spaces: CM2-PARK Amendment 1),
-- the "P" sign and the two lamps, in this order. `facing` is the plot's Stocking.facing: the
-- letter offsets keep the "P" readable from the road (viewer's right). Each drive reaches the
-- road edge with its top 0.02 below the pads (no coplanar seam); the corridor x -10..10 in front
-- of the gate stays free.
function ParkingArt.fixtures(facing: number, spaces: number): { Fixture }
	local park = carPark()
	local d, r = park.Depth, VehicleArt.PARKING_RISE
	local sign = park.Fixtures.Sign
	local smooth = "SmoothPlastic"
	local driveZ = d + park.PadLength / 2 + 6.5
	local fixtures: { Fixture } = {
		{
			name = "CarPark_DriveL",
			parts = { spec("Slab", { 16, 0.9, 13 }, -18, driveZ, r - 0.47, ASPHALT, "Asphalt", true) },
		},
	}
	if spaces >= 2 then
		table.insert(fixtures, {
			name = "CarPark_DriveR",
			parts = { spec("Slab", { 16, 0.9, 13 }, 18, driveZ, r - 0.47, ASPHALT, "Asphalt", true) },
		})
	end
	table.insert(fixtures, {
		name = "CarPark_Sign",
		parts = {
			spec("Post", { 0.3, 5.6, 0.3 }, sign.x, sign.z, 2.2, METAL, smooth, true),
			spec("Board", { 2.4, 2.4, 0.2 }, sign.x, sign.z + 0.25, 4.0, BLUE, smooth, false),
			spec("LetterStem", { 0.35, 1.7, 0.1 }, sign.x + facing * -0.35, sign.z + 0.4, 4.0, WHITE, smooth, false),
			spec("LetterBowl", { 0.9, 0.95, 0.1 }, sign.x + facing * 0.1, sign.z + 0.4, 4.375, WHITE, smooth, false),
			spec("LetterHole", { 0.3, 0.35, 0.1 }, sign.x + facing * 0.15, sign.z + 0.46, 4.375, BLUE, smooth, false),
		},
	})
	for k, lamp in park.Fixtures.Lamps do
		table.insert(fixtures, {
			name = "CarPark_Lamp_" .. k,
			parts = {
				spec("Post", { 0.3, 8.6, 0.3 }, lamp.x, lamp.z, 3.7, METAL, smooth, true),
				spec("Arm", { 0.2, 0.2, 1.8 }, lamp.x, lamp.z + 0.9, 7.9, METAL, smooth, false),
				spec("Head", { 0.9, 0.35, 0.9 }, lamp.x, lamp.z + 1.7, 7.65, LAMP, "Neon", false),
			},
			lightPart = "Head",
		})
	end
	return fixtures
end

-- The fixtures' ground footprints in the lot frame (Sign, Lamp_1, Lamp_2; for CM2-TRAFFIC).
function ParkingArt.footprints(): { Box }
	local fixtures = carPark().Fixtures
	local sign = fixtures.Sign
	local boxes: { Box } = {
		{ id = "Sign", minX = sign.x - 1.2, maxX = sign.x + 1.2, minZ = sign.z - 0.5, maxZ = sign.z + 0.5 },
	}
	for k, lamp in fixtures.Lamps do
		table.insert(boxes, {
			id = "Lamp_" .. k,
			minX = lamp.x - 0.5,
			maxX = lamp.x + 0.5,
			minZ = lamp.z - 0.5,
			maxZ = lamp.z + 0.5,
		})
	end
	return boxes
end

return ParkingArt
