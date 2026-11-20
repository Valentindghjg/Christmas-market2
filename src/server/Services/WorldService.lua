--!strict
-- Original low-poly winter graybox built from Roblox primitives; no external assets.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AssetCatalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AssetCatalog"))

local WorldService = {}

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	local instance = Instance.new("Part")
	instance.Name = name
	instance.Anchored = true
	instance.CanCollide = true
	instance.Size = size
	instance.Position = position
	instance.Color = color
	instance.Material = material
	instance.TopSurface = Enum.SurfaceType.Smooth
	instance.BottomSurface = Enum.SurfaceType.Smooth
	instance.Parent = parent
	return instance
end

local function tree(parent: Instance, name: string, position: Vector3, scale: number): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	local trunk = part(
		model,
		"Trunk",
		Vector3.new(1.2, 5, 1.2) * scale,
		position + Vector3.new(0, 2.5 * scale, 0),
		Color3.fromRGB(94, 60, 37),
		Enum.Material.Wood
	)
	for index = 1, 3 do
		local cone = part(
			model,
			"Needles" .. index,
			Vector3.new((8 - index) * scale, 3 * scale, (8 - index) * scale),
			position + Vector3.new(0, (4 + index * 2) * scale, 0),
			Color3.fromRGB(23, 83, 52),
			Enum.Material.Grass
		)
		cone.Shape = Enum.PartType.Cylinder
		cone.Orientation = Vector3.new(0, 0, 90)
	end
	model.PrimaryPart = trunk
	model:SetAttribute("TreeBase", true)
	return model
end

local function tent(parent: Instance, position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "StarterSalesTent"
	model.Parent = parent
	local floor = part(
		model,
		"TentFloor",
		Vector3.new(18, 0.4, 14),
		position,
		Color3.fromRGB(112, 76, 48),
		Enum.Material.WoodPlanks
	)
	for _, offset in ipairs({
		Vector3.new(-8, 4, -6),
		Vector3.new(8, 4, -6),
		Vector3.new(-8, 4, 6),
		Vector3.new(8, 4, 6),
	}) do
		part(
			model,
			"Pole",
			Vector3.new(0.6, 8, 0.6),
			position + offset,
			Color3.fromRGB(249, 238, 214),
			Enum.Material.Wood
		)
	end
	local roof = part(
		model,
		"FestiveRoof",
		Vector3.new(19, 1, 15),
		position + Vector3.new(0, 8, 0),
		Color3.fromRGB(173, 38, 43),
		Enum.Material.Fabric
	)
	roof.Shape = Enum.PartType.Wedge
	model.PrimaryPart = floor
	return model
end

-- Uses the approved imported market model when Studio has it, while retaining a
-- primitive fallback for source-only and automated test environments.
local function salesStand(parent: Instance, position: Vector3, assetId: string?): Model

	local art = ReplicatedStorage:FindFirstChild("ArtAssets")
	local buildings = art and art:FindFirstChild("Buildings")
	assetId = assetId or AssetCatalog.Buildings.MarketStarter
	local template = buildings and buildings:FindFirstChild(assetId)
	if not (template and template:IsA("Model")) then
		return tent(parent, position)
	end

	local model = template:Clone()
	model.Name = "StarterSalesTent"
	model.Parent = parent
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = true
		end
	end
	local box, size = model:GetBoundingBox()
	local targetCenter = position + Vector3.new(0, size.Y / 2, 0)
	model:PivotTo(model:GetPivot() + (targetCenter - box.Position))
	model:SetAttribute("ArtAssetId", assetId)
	return model
end

local function cloneArt(
	parent: Instance,
	category: string,
	assetId: string,
	groundPosition: Vector3
): Model?
	local art = ReplicatedStorage:FindFirstChild("ArtAssets")
	local folder = art and art:FindFirstChild(category)
	local template = folder and folder:FindFirstChild(assetId)
	if not (template and template:IsA("Model")) then
		return nil
	end

	local model = template:Clone()
	model.Name = assetId
	model.Parent = parent
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = true
		end
	end
	local box, size = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + (groundPosition + Vector3.new(0, size.Y / 2, 0) - box.Position))
	model:SetAttribute("ArtAssetId", assetId)
	return model
end

local function checkout(parent: Instance, position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "CheckoutCounter"
	model.Parent = parent
	local base = part(
		model,
		"CounterBase",
		Vector3.new(5, 3, 2),
		position + Vector3.new(0, 1.5, 0),
		Color3.fromRGB(107, 68, 38),
		Enum.Material.WoodPlanks
	)
	part(
		model,
		"Register",
		Vector3.new(1.5, 0.7, 1),
		position + Vector3.new(0, 3.35, 0),
		Color3.fromRGB(40, 48, 51),
		Enum.Material.Metal
	)
	model.PrimaryPart = base
	return model
end

local function truck(parent: Instance, position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "SupplierTruck"
	model.Parent = parent
	local body = part(
		model,
		"TruckBody",
		Vector3.new(12, 3, 5),
		position + Vector3.new(0, 2, 0),
		Color3.fromRGB(198, 42, 42),
		Enum.Material.Metal
	)
	part(
		model,
		"Cab",
		Vector3.new(4, 3.5, 5),
		position + Vector3.new(-4, 4.2, 0),
		Color3.fromRGB(243, 239, 224),
		Enum.Material.Metal
	)
	for _, offset in ipairs({
		Vector3.new(-4, 0.7, -2.6),
		Vector3.new(-4, 0.7, 2.6),
		Vector3.new(4, 0.7, -2.6),
		Vector3.new(4, 0.7, 2.6),
	}) do
		local wheel = part(
			model,
			"Wheel",
			Vector3.new(1.5, 1.5, 0.6),
			position + offset,
			Color3.fromRGB(27, 27, 27),
			Enum.Material.Rubber
		)
		wheel.Shape = Enum.PartType.Cylinder
		wheel.Orientation = Vector3.new(90, 0, 0)
	end
	model.PrimaryPart = body
	return model
end

function WorldService.build()
	local existing = workspace:FindFirstChild("ChristmasMarketWorld")
	if existing then
		return existing
	end
	local world = Instance.new("Folder")
	world.Name = "ChristmasMarketWorld"
	world.Parent = workspace

	part(
		world,
		"SnowGround",
		Vector3.new(420, 2, 300),
		Vector3.new(0, -1, 0),
		Color3.fromRGB(238, 246, 250),
		Enum.Material.Snow
	)
	part(
		world,
		"MainRoad",
		Vector3.new(380, 0.3, 32),
		Vector3.new(0, 0.2, 0),
		Color3.fromRGB(54, 58, 61),
		Enum.Material.Asphalt
	)
	part(
		world,
		"CenterLine",
		Vector3.new(380, 0.1, 0.5),
		Vector3.new(0, 0.4, 0),
		Color3.fromRGB(244, 190, 58),
		Enum.Material.Neon
	)

	local plots = Instance.new("Folder")
	plots.Name = "Plots"
	plots.Parent = world
	for index = 1, 6 do
		local side = index <= 3 and -1 or 1
		local column = ((index - 1) % 3) - 1
		local center = Vector3.new(column * 110, 0, side * 75)
		local plot = Instance.new("Model")
		plot.Name = string.format("Plot_%02d", index)
		plot:SetAttribute("PlotId", plot.Name)
		plot.Parent = plots
		local ground = part(
			plot,
			"LotGround",
			Vector3.new(80, 0.5, 54),
			center + Vector3.new(0, 0.3, 0),
			Color3.fromRGB(224, 239, 244),
			Enum.Material.Snow
		)
		ground.CanCollide = true
		plot.PrimaryPart = ground
		part(
			plot,
			"DeliveryBay",
			Vector3.new(16, 0.3, 10),
			center + Vector3.new(27, 0.6, 14),
			Color3.fromRGB(92, 127, 139),
			Enum.Material.Concrete
		)
		local spawn = part(
			plot,
			"Spawn",
			Vector3.new(4, 0.2, 4),
			center + Vector3.new(-28, 0.7, 14),
			Color3.fromRGB(69, 132, 82),
			Enum.Material.Grass
		)
		spawn.Transparency = 0.35
		salesStand(plot, center + Vector3.new(-8, 0.6, -4))
		checkout(plot, center + Vector3.new(16, 0.6, -14))
		cloneArt(plot, "Environment", AssetCatalog.Environment.FenceWooden, center + Vector3.new(-34, 0.6, 24))
		cloneArt(plot, "Environment", AssetCatalog.Environment.FenceWooden, center + Vector3.new(34, 0.6, 24))
		cloneArt(plot, "Props", AssetCatalog.Props.CrateWooden, center + Vector3.new(25, 0.6, 10))
		cloneArt(plot, "Props", AssetCatalog.Props.BarrelWooden, center + Vector3.new(29, 0.6, 10))
		cloneArt(plot, "Props", AssetCatalog.Props.DeliveryPackage1, center + Vector3.new(25, 0.6, 14))
		cloneArt(plot, "Props", AssetCatalog.Props.DeliveryPackage2, center + Vector3.new(29, 0.6, 14))
	end

	local assets = Instance.new("Folder")
	assets.Name = "OriginalGrayboxAssets"
	assets.Parent = world
	for speciesIndex, species in ipairs({ "FrasierFir", "NobleFir", "BlueSpruce" }) do
		for sizeIndex, size in ipairs({ "Small", "Medium", "Large" }) do
			tree(
				assets,
				species .. "_" .. size,
				Vector3.new(-170 + speciesIndex * 20, 0, 80 + sizeIndex * 18),
				0.6 + sizeIndex * 0.2
			)
		end
	end
	truck(world, Vector3.new(-165, 0, 12))
	for index = 1, 24 do
		local x = -190 + ((index * 37) % 370)
		local z = index % 2 == 0 and -125 or 125
		tree(world, "ForestTree" .. index, Vector3.new(x, 0, z), 0.8)
	end

	local scenery = Instance.new("Folder")
	scenery.Name = "ImportedWinterScenery"
	scenery.Parent = world
	for _, position in ipairs({
		Vector3.new(-150, 0, -120),
		Vector3.new(-40, 0, -120),
		Vector3.new(70, 0, -120),
		Vector3.new(150, 0, -120),
		Vector3.new(-150, 0, 120),
		Vector3.new(-40, 0, 120),
		Vector3.new(70, 0, 120),
		Vector3.new(150, 0, 120),
	}) do
		cloneArt(scenery, "Environment", AssetCatalog.Environment.PineTreeGroup, position)
	end
	for _, position in ipairs({
		Vector3.new(-180, 0, -104), Vector3.new(180, 0, -104),
		Vector3.new(-180, 0, 104), Vector3.new(180, 0, 104),
	}) do
		cloneArt(scenery, "Environment", AssetCatalog.Environment.StylizedRocks, position)
		cloneArt(scenery, "Environment", AssetCatalog.Environment.StylizedBushes, position + Vector3.new(8, 0, 6))
		cloneArt(scenery, "Environment", AssetCatalog.Environment.WinterLogs, position + Vector3.new(-8, 0, -6))
	end
	local marketAlley = Instance.new("Folder")
	marketAlley.Name = "ImportedMarketAlley"
	marketAlley.Parent = world
	cloneArt(marketAlley, "Buildings", AssetCatalog.Buildings.MarketGazebo, Vector3.new(0, 0, 52))
	cloneArt(marketAlley, "Buildings", AssetCatalog.Buildings.RusticMarketStand1, Vector3.new(-26, 0, 52))
	cloneArt(marketAlley, "Buildings", AssetCatalog.Buildings.RusticMarketStand2, Vector3.new(26, 0, 52))
	cloneArt(marketAlley, "Props", AssetCatalog.Props.MarketBench1, Vector3.new(-10, 0, 34))
	cloneArt(marketAlley, "Props", AssetCatalog.Props.MarketBench2, Vector3.new(10, 0, 34))
	cloneArt(marketAlley, "Props", AssetCatalog.Props.MarketCart, Vector3.new(-44, 0, 52))
	cloneArt(marketAlley, "Props", AssetCatalog.Props.MarketBags, Vector3.new(44, 0, 52))
	return world
end

function WorldService.applyHQVisual(plotId: string, hqTier: string?)
	local world = workspace:FindFirstChild("ChristmasMarketWorld")
	local plots = world and world:FindFirstChild("Plots")
	local plot = plots and plots:FindFirstChild(plotId)
	if not (plot and plot:IsA("Model") and plot.PrimaryPart) then
		return false
	end
	local existing = plot:FindFirstChild("StarterSalesTent")
	if existing then
		existing:Destroy()
	end
	local assetId = hqTier == "ChristmasPavilion" and AssetCatalog.Buildings.MarketPavilion
		or AssetCatalog.Buildings.MarketStarter
	salesStand(plot, plot.PrimaryPart.Position + Vector3.new(-8, 0.6, -4), assetId)
	return true
end

return WorldService
