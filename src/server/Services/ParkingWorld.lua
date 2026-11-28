--!strict
-- The customer car park of a plot (CM2-PARK, docs/plans/CM2-PARK.md): builds ParkingArt's bays
-- (Parking_<space> with LineL, LineR, Stop) and fixtures (CarPark_DriveL/R, CarPark_Sign,
-- CarPark_Lamp_<k>) into ProgressionVisuals. Quality tier B, anchored Parts only; the helpers
-- (part, lotPosition, lotTop, facing) are WorldService's FENCE_HELPERS.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local ParkingArt = require(Shared:WaitForChild("ParkingArt"))
local MapWorld = require(script.Parent:WaitForChild("MapWorld"))

local ParkingWorld = {}

local function buildPart(plot: Model, parent: Instance, spec: ParkingArt.Spec, top: number, helpers): BasePart
	local instance = helpers.part(
		parent,
		spec.name,
		Vector3.new(spec.size[1], spec.size[2], spec.size[3]),
		helpers.lotPosition(plot, spec.x, spec.z, top + spec.dy),
		Color3.fromRGB(spec.rgb[1], spec.rgb[2], spec.rgb[3]),
		(Enum.Material :: any)[spec.material]
	)
	instance.CanCollide = spec.collide
	return instance
end

-- Rebuilds the car park for `spaces` spaces; 0 spaces (a released plot) shows nothing.
function ParkingWorld.build(plot: Model, visuals: Instance, spaces: number, helpers)
	for _, child in visuals:GetChildren() do
		if string.sub(child.Name, 1, 8) == "Parking_" or string.sub(child.Name, 1, 8) == "CarPark_" then
			child:Destroy()
		end
	end
	local n = math.clamp(math.floor(spaces), 0, GameConfig.Progression.Parking.maxSpaces)
	if n == 0 then
		return
	end
	local top = helpers.lotTop(plot)
	for space = 1, n do
		local bay = ParkingArt.bay(space)
		local pad = buildPart(plot, visuals, bay.pad, top, helpers)
		pad:SetAttribute("ParkingSpace", space)
		for _, mark in bay.marks do
			buildPart(plot, pad, mark, top, helpers)
		end
	end
	for _, fixture in ParkingArt.fixtures(helpers.facing(plot), n) do
		local model = Instance.new("Model")
		model.Name = fixture.name
		model.Parent = visuals
		for _, spec in fixture.parts do
			local instance = buildPart(plot, model, spec, top, helpers)
			if spec.name == fixture.lightPart then
				MapWorld.nightLight(instance, GameConfig.DayCycle.LampLight)
			end
		end
	end
end

return ParkingWorld
