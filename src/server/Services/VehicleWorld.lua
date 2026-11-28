--!strict
-- Builds the supplier truck, the customer cars and the truck's tree-bundle cargo in the world
-- (CM2-14W, docs/archive/plans/CM2-14W.md): the CM2-14 art when ArtAssets has it, else today's primitives.
-- Poses are CFrames at ground level (the model pivot is the footprint centre on the wheel plane).
-- `ctx` comes from WorldService.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArtLibrary = require(Shared:WaitForChild("ArtLibrary"))
local LotArt = require(Shared:WaitForChild("LotArt"))
local VehicleArt = require(Shared:WaitForChild("VehicleArt"))

local VehicleWorld = {}

export type Ctx = {
	part: (Instance, string, Vector3, Vector3, Color3, Enum.Material) -> Part,
	reportMissing: (string, string) -> (),
}

local BUNDLE_COLOR = Color3.fromRGB(23, 83, 52)

-- Looks `path` up; reports a missing or broken path and returns nil then.
local function findArt(path: string, ctx: Ctx): Model?
	local choice = LotArt.choose(ArtLibrary.root(ReplicatedStorage), ArtLibrary.find, path)
	if choice.mode ~= "Art" then
		ctx.reportMissing(path, choice.code or "MissingArtAsset")
		return nil
	end
	return choice.template :: Model
end

local function mark(model: Model, kind: string, mode: string, path: string)
	model:SetAttribute("VehicleKind", kind)
	model:SetAttribute("VehicleArtMode", mode)
	model:SetAttribute("VehicleArtPath", path)
end

local function primitiveTruck(parent: Instance, pose: CFrame, ctx: Ctx): Model
	local model = Instance.new("Model")
	model.Name = "DeliveryTruck"
	local body = ctx.part(
		model,
		"TruckBody",
		Vector3.new(5, 3, 12),
		Vector3.new(0, 2, 0),
		Color3.fromRGB(198, 42, 42),
		Enum.Material.Metal
	)
	ctx.part(
		model,
		"Cab",
		Vector3.new(5, 3.5, 4),
		Vector3.new(0, 4.2, -4),
		Color3.fromRGB(243, 239, 224),
		Enum.Material.Metal
	)
	for _, side in { -1, 1 } do
		for _, along in { -1, 1 } do
			local wheel = ctx.part(
				model,
				"Wheel",
				Vector3.new(0.6, 1.5, 1.5),
				Vector3.new(side * 2.6, 0.75, along * 4),
				Color3.fromRGB(27, 27, 27),
				Enum.Material.Rubber
			)
			wheel.Shape = Enum.PartType.Cylinder
		end
	end
	model.PrimaryPart = body
	body.PivotOffset = CFrame.new(0, -2, 0)
	model:PivotTo(pose)
	model.Parent = parent
	return model
end

-- The supplier truck `DeliveryTruck` at `pose` (ground level, cab toward -Z of the pose).
function VehicleWorld.truck(parent: Instance, pose: CFrame, ctx: Ctx): Model
	local path = VehicleArt.TRUCK_PATH
	local template = findArt(path, ctx)
	if template == nil then
		local model = primitiveTruck(parent, pose, ctx)
		mark(model, "Truck", "Primitive", path)
		return model
	end
	local model = ArtLibrary.prepareClone(template)
	model.Name = "DeliveryTruck"
	model:PivotTo(pose)
	model.Parent = parent
	mark(model, "Truck", "Art", path)
	return model
end

local function primitiveCar(parent: Instance, name: string, pose: CFrame, color: Color3, ctx: Ctx): Model
	local model = Instance.new("Model")
	model.Name = name
	local function carPart(partName: string, size: Vector3, offset: Vector3, partColor: Color3, material: Enum.Material)
		local value = ctx.part(model, partName, size, offset, partColor, material)
		value.CanCollide = false
		value.CastShadow = true
		return value
	end
	local body = carPart("Body", Vector3.new(5, 1.8, 9), Vector3.new(0, 1.6, 0), color, Enum.Material.SmoothPlastic)
	carPart(
		"Cabin",
		Vector3.new(4.4, 1.6, 4.6),
		Vector3.new(0, 3.3, 0.6),
		Color3.fromRGB(168, 205, 222),
		Enum.Material.Glass
	)
	carPart(
		"RoofRack",
		Vector3.new(4, 0.2, 4.2),
		Vector3.new(0, 4.2, 0.6),
		Color3.fromRGB(40, 40, 44),
		Enum.Material.Metal
	)
	for _, offset in
		{
			Vector3.new(-2.5, 0.75, -2.8),
			Vector3.new(2.5, 0.75, -2.8),
			Vector3.new(-2.5, 0.75, 2.8),
			Vector3.new(2.5, 0.75, 2.8),
		}
	do
		local wheel =
			carPart("Wheel", Vector3.new(0.7, 1.5, 1.5), offset, Color3.fromRGB(27, 27, 27), Enum.Material.Rubber)
		wheel.Shape = Enum.PartType.Cylinder
	end
	model.PrimaryPart = body
	body.PivotOffset = CFrame.new(0, -1.6, 0)
	model:PivotTo(pose)
	model.Parent = parent
	return model
end

-- A customer car `name` at `pose` (ground level, nose toward -Z of the pose), styled by car number `n`:
-- body and colour from VehicleArt.carStyle. Car parts never collide.
function VehicleWorld.car(parent: Instance, name: string, pose: CFrame, n: number, ctx: Ctx): Model
	local path, colourIndex = VehicleArt.carStyle(n)
	local rgb = VehicleArt.CAR_COLORS[colourIndex]
	local color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
	local template = findArt(path, ctx)
	if template == nil then
		local model = primitiveCar(parent, name, pose, color, ctx)
		mark(model, "Car", "Primitive", path)
		return model
	end
	local model = ArtLibrary.prepareClone(template)
	model.Name = name
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
		end
	end
	local paint = model:FindFirstChild("Paint", true)
	if paint ~= nil and paint:IsA("BasePart") then
		paint.Color = color
	else
		ctx.reportMissing(path .. "/Paint", "InvalidArtAsset")
	end
	model:PivotTo(pose)
	model.Parent = parent
	mark(model, "Car", "Art", path)
	return model
end

-- Where cargo rests on a vehicle: the CargoAnchor of the art, the primitive car's RoofRack top, else
-- the pivot plus the fallback offset of the vehicle kind.
function VehicleWorld.cargoTop(model: Model): CFrame
	local root = model.PrimaryPart
	if root ~= nil then
		local anchor = root:FindFirstChild("CargoAnchor", true)
		if anchor ~= nil and anchor:IsA("Attachment") then
			return anchor.WorldCFrame
		end
	end
	local rack = model:FindFirstChild("RoofRack")
	if rack ~= nil and rack:IsA("BasePart") then
		return rack.CFrame * CFrame.new(0, rack.Size.Y / 2, 0)
	end
	local fallback = if model:GetAttribute("VehicleKind") == "Truck"
		then VehicleArt.TRUCK_CARGO_FALLBACK
		else VehicleArt.CAR_CARGO_FALLBACK
	return model:GetPivot() * CFrame.new(fallback[1], fallback[2], fallback[3])
end

-- Up to nine tree bundles on the truck bed in a Model `Cargo`; nothing for an empty load.
function VehicleWorld.loadCargo(truck: Model, arriving: any, ctx: Ctx)
	local count = VehicleArt.cargoCount(arriving)
	if count == 0 then
		return
	end
	local old = truck:FindFirstChild("Cargo")
	if old ~= nil then
		old:Destroy()
	end
	local template = findArt(LotArt.PATHS.Bundle, ctx)
	local cargo = Instance.new("Model")
	cargo.Name = "Cargo"
	cargo:SetAttribute("Bundles", count)
	cargo:SetAttribute("VehicleArtMode", if template ~= nil then "Art" else "Primitive")
	local top = VehicleWorld.cargoTop(truck)
	for k = 0, count - 1 do
		local rise, dz = VehicleArt.bundleOffset(k)
		local pose = top * CFrame.new(0, rise, dz)
		if template ~= nil then
			local bundle = ArtLibrary.prepareClone(template)
			bundle.Name = "Bundle"
			bundle:PivotTo(pose)
			bundle.Parent = cargo
			for _, descendant in bundle:GetDescendants() do
				if descendant:IsA("BasePart") then
					descendant.CanCollide = false
					descendant.CanQuery = false
				end
			end
		else
			local bundle =
				ctx.part(cargo, "Bundle", Vector3.new(4, 1, 1), Vector3.zero, BUNDLE_COLOR, Enum.Material.Grass)
			bundle.Shape = Enum.PartType.Cylinder
			bundle.CFrame = pose * CFrame.new(0, 0.5, 0)
			bundle.CanCollide = false
		end
	end
	cargo.Parent = truck
end

-- Removes the cargo (the truck leaves empty).
function VehicleWorld.unloadCargo(truck: Model)
	local cargo = truck:FindFirstChild("Cargo")
	if cargo ~= nil then
		cargo:Destroy()
	end
end

return VehicleWorld
