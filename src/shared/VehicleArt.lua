--!strict
-- Vehicle art in the world (CM2-14W, docs/plans/CM2-14W.md): which art path the truck and each customer
-- car use, their yaws, the cargo count and where each tree bundle lies on the truck bed, and how the
-- roof tree settles on the cargo anchor (CM2-14WR). Pure data and maths; VehicleWorld clones the models. All values are PROVISIONAL and visual.
local LotArt = require(script.Parent.LotArt)

local VehicleArt = {}

VehicleArt.TRUCK_PATH = "Vehicles/SupplierTruck"
VehicleArt.CAR_PATHS = { "Vehicles/CustomerHatchback", "Vehicles/CustomerWagon", "Vehicles/CustomerSuv" }
-- Body colours as {r, g, b}, the order the primitive cars used.
VehicleArt.CAR_COLORS = {
	{ 176, 52, 48 },
	{ 57, 96, 150 },
	{ 226, 222, 210 },
	{ 64, 112, 78 },
	{ 196, 150, 70 },
	{ 70, 70, 76 },
}
VehicleArt.MAX_BUNDLES = 9
VehicleArt.ROAD_TOP = 0.35
VehicleArt.TRUCK_LANE_TOP = 0.05 -- top of TruckLane_Plot_*
VehicleArt.PARKING_RISE = 0.27 -- lot top 0.55 to the parking slab top 0.82
VehicleArt.CAR_LABEL_LIFT = 1.6
VehicleArt.ROOF_PRIMITIVE_LIFT = 1.7
VehicleArt.ROOF_CLEARANCE = 0.05 -- the roof tree's lowest point above the cargo anchor
-- Cargo offsets from the pivot as {x, y, z} (plain numbers: the headless runner has no Vector3).
VehicleArt.TRUCK_CARGO_FALLBACK = { 0, 3.5, 2 }
VehicleArt.CAR_CARGO_FALLBACK = { 0, 4.3, 0.6 }

local function isFinite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- The art path and the colour index (1..6) of car number `n`: 3 bodies x 6 colours = 18 looks.
function VehicleArt.carStyle(n: any): (string, number)
	local m = 1
	if isFinite(n) then
		m = math.max(1, math.floor(n))
	end
	local colour = (m - 1) % #VehicleArt.CAR_COLORS + 1
	local body = ((m - 1) + (m - 1) // 6) % #VehicleArt.CAR_PATHS + 1
	return VehicleArt.CAR_PATHS[body], colour
end

-- The truck's cab (model -Z) faces the road.
function VehicleArt.truckYaw(facing: number): number
	return LotArt.roadYaw(facing)
end

-- A parked car's nose (model -Z) points into the lot, away from the road.
function VehicleArt.carYaw(facing: number): number
	if facing == 1 then
		return 0
	end
	return math.pi
end

-- How many bundles the truck brings: floor(x) clamped to 0..MAX_BUNDLES, 0 for anything else.
function VehicleArt.cargoCount(x: any): number
	if not isFinite(x) then
		return 0
	end
	return math.clamp(math.floor(x), 0, VehicleArt.MAX_BUNDLES)
end

-- Bundle k relative to the cargo anchor: the rise above it and the offset along z. Six bundles lie
-- in the bottom row, three on top; they lie along the anchor's X.
function VehicleArt.bundleOffset(k: number): (number, number)
	if not isFinite(k) then
		return 0, 0
	end
	if k <= 5 then
		return 0, (k - 2.5) * 1.2
	end
	return 1.0, (k - 7) * 1.2
end

-- The lowest world Y of an oriented box: its centre minus the half extent along world Y. Anything
-- non-finite gives math.huge, so the part never counts as the lowest.
function VehicleArt.boxBottom(
	centerY: any,
	sizeX: any,
	sizeY: any,
	sizeZ: any,
	rightY: any,
	upY: any,
	lookY: any
): number
	if
		isFinite(centerY)
		and isFinite(sizeX)
		and isFinite(sizeY)
		and isFinite(sizeZ)
		and isFinite(rightY)
		and isFinite(upY)
		and isFinite(lookY)
	then
		return centerY - (math.abs(rightY) * sizeX + math.abs(upY) * sizeY + math.abs(lookY) * sizeZ) / 2
	end
	return math.huge
end

-- How far to raise the roof tree so its lowest point is ROOF_CLEARANCE above the cargo anchor.
function VehicleArt.roofLift(lowestY: any, cargoTopY: any): number
	if isFinite(lowestY) and isFinite(cargoTopY) then
		return cargoTopY + VehicleArt.ROOF_CLEARANCE - lowestY
	end
	return 0
end

return VehicleArt
