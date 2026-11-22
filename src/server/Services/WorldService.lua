--!strict
-- Original low-poly winter graybox built from Roblox primitives; no external assets.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArtLibrary = require(Shared:WaitForChild("ArtLibrary"))
local AssetCatalog = require(Shared:WaitForChild("AssetCatalog"))
local Economy = require(Shared:WaitForChild("Economy"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local TreeHeight = require(Shared:WaitForChild("TreeHeight"))

local WorldService = {}

local CAR_DRIVE_SECONDS = 2
local CAR_COLORS = {
	Color3.fromRGB(176, 52, 48),
	Color3.fromRGB(57, 96, 150),
	Color3.fromRGB(226, 222, 210),
	Color3.fromRGB(64, 112, 78),
	Color3.fromRGB(196, 150, 70),
	Color3.fromRGB(70, 70, 76),
}

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

-- Missing or broken art is reported once per path and server; the primitive fallback follows.
local reportedArt: { [string]: boolean } = {}
local function reportMissing(artPath: string, code: string)
	if reportedArt[artPath] then
		return
	end
	reportedArt[artPath] = true
	warn(string.format("[ART] %s %s", code, artPath))
end

-- Uses the approved art model when ArtAssets has it, while retaining a primitive
-- fallback for source-only and automated test environments.
local function salesStand(parent: Instance, position: Vector3, assetId: string?): Model
	assetId = assetId or AssetCatalog.Buildings.MarketStarter
	local artPath = "Buildings/" .. assetId
	local template, code = ArtLibrary.find(ReplicatedStorage:FindFirstChild("ArtAssets"), artPath)
	if not template then
		reportMissing(artPath, code or "MissingArtAsset")
		return tent(parent, position)
	end

	local model = ArtLibrary.prepareClone(template)
	model.Name = "StarterSalesTent"
	model.Parent = parent
	local box, size = model:GetBoundingBox()
	local targetCenter = position + Vector3.new(0, size.Y / 2, 0)
	model:PivotTo(model:GetPivot() + (targetCenter - box.Position))
	return model
end

local function cloneArt(parent: Instance, category: string, assetId: string, groundPosition: Vector3): Model?
	local artPath = category .. "/" .. assetId
	local template, code = ArtLibrary.find(ReplicatedStorage:FindFirstChild("ArtAssets"), artPath)
	if not template then
		reportMissing(artPath, code or "MissingArtAsset")
		return nil
	end

	local model = ArtLibrary.prepareClone(template)
	model.Name = assetId
	model.Parent = parent
	local box, size = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + (groundPosition + Vector3.new(0, size.Y / 2, 0) - box.Position))
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
	for speciesIndex, species in ipairs(GameConfig.SpeciesOrder) do
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
		Vector3.new(-180, 0, -104),
		Vector3.new(180, 0, -104),
		Vector3.new(-180, 0, 104),
		Vector3.new(180, 0, 104),
	}) do
		cloneArt(scenery, "Environment", AssetCatalog.Environment.StylizedRocks, position)
		cloneArt(scenery, "Environment", AssetCatalog.Environment.StylizedBushes, position + Vector3.new(8, 0, 6))
		cloneArt(scenery, "Environment", AssetCatalog.Environment.WinterLogs, position + Vector3.new(-8, 0, -6))
	end
	local marketAlley = Instance.new("Folder")
	marketAlley.Name = "ImportedMarketAlley"
	marketAlley.Parent = world
	-- The alley sits in the strip between the road (|z| <= 16) and the lots (|z| >= 48), in
	-- the gap between the plot 4 and plot 5 car lanes, so no stall stands on a parking space.
	cloneArt(marketAlley, "Buildings", AssetCatalog.Buildings.MarketGazebo, Vector3.new(-62, 0, 30))
	cloneArt(marketAlley, "Buildings", AssetCatalog.Buildings.RusticMarketStand1, Vector3.new(-76, 0, 30))
	cloneArt(marketAlley, "Buildings", AssetCatalog.Buildings.RusticMarketStand2, Vector3.new(-48, 0, 30))
	cloneArt(marketAlley, "Props", AssetCatalog.Props.MarketBench1, Vector3.new(-70, 0, 40))
	cloneArt(marketAlley, "Props", AssetCatalog.Props.MarketBench2, Vector3.new(-54, 0, 40))
	cloneArt(marketAlley, "Props", AssetCatalog.Props.MarketCart, Vector3.new(-90, 0, 30))
	cloneArt(marketAlley, "Props", AssetCatalog.Props.MarketBags, Vector3.new(-36, 0, 30))
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

function WorldService.applyLotExpansionVisual(plotId: string, level: number)
	local world = workspace:FindFirstChild("ChristmasMarketWorld")
	local plots = world and world:FindFirstChild("Plots")
	local plot = plots and plots:FindFirstChild(plotId)
	if not (plot and plot:IsA("Model") and plot.PrimaryPart) or level < 0 then
		return false
	end
	local visuals = plot:FindFirstChild("ProgressionVisuals") or Instance.new("Folder")
	visuals.Name = "ProgressionVisuals"
	visuals.Parent = plot
	local existing = visuals:FindFirstChild("LotExpansionPad")
	if existing then
		existing:Destroy()
	end
	local growth = math.min(math.floor(level), 3)
	local pad = part(
		visuals,
		"LotExpansionPad",
		Vector3.new(80 + growth * 8, 0.18, 54 + growth * 6),
		plot.PrimaryPart.Position + Vector3.new(0, -0.05, 0),
		Color3.fromRGB(224, 239, 244),
		Enum.Material.Snow
	)
	pad:SetAttribute("LotExpansionLevel", growth)
	return true
end

local function findPlot(plotId: string): Model?
	local world = workspace:FindFirstChild("ChristmasMarketWorld")
	local plots = world and world:FindFirstChild("Plots")
	local plot = plots and plots:FindFirstChild(plotId)
	if plot and plot:IsA("Model") and plot.PrimaryPart then
		return plot
	end
	return nil
end

-- Parking sits on the road-facing edge of the lot (plots south of the road face +Z).
local function parkingOffset(plot: Model, index: number): Vector3
	local towardRoad = if (plot.PrimaryPart :: BasePart).Position.Z < 0 then 1 else -1
	return Vector3.new(-24 + (index - 1) * 12, 0, towardRoad * 20)
end

function WorldService.applyParkingVisual(plotId: string, spaces: number)
	local plot = findPlot(plotId)
	if not plot or spaces < 0 then
		return false
	end
	local visuals = plot:FindFirstChild("ProgressionVisuals") or Instance.new("Folder")
	visuals.Name = "ProgressionVisuals"
	visuals.Parent = plot
	for _, child in visuals:GetChildren() do
		if string.sub(child.Name, 1, 8) == "Parking_" then
			child:Destroy()
		end
	end
	for index = 1, math.min(math.floor(spaces), 4) do
		local offset = parkingOffset(plot, index) + Vector3.new(0, 0.48, 0)
		local space = part(
			visuals,
			"Parking_" .. index,
			Vector3.new(8, 0.08, 12),
			plot.PrimaryPart.Position + offset,
			Color3.fromRGB(239, 243, 244),
			Enum.Material.Concrete
		)
		space:SetAttribute("ParkingSpace", index)
	end
	return true
end

-- A floating label. Server text is the English fallback; the client script
-- WorldLabels.client.lua localizes it from the label's attributes (LabelKind etc.).
local function billboard(adornee: BasePart, kind: string, text: string, height: number, attributes): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(190, 46)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.MaxDistance = 60
	gui.AlwaysOnTop = false
	gui.Adornee = adornee
	gui.Parent = adornee
	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "Text"
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundColor3 = Color3.fromRGB(24, 74, 50)
	textLabel.BackgroundTransparency = 0.15
	textLabel.TextColor3 = Color3.fromRGB(255, 244, 217)
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextScaled = true
	textLabel.Text = text
	textLabel:SetAttribute("LabelKind", kind)
	for key, value in pairs(attributes) do
		textLabel:SetAttribute(key, value)
	end
	Instance.new("UICorner", textLabel).CornerRadius = UDim.new(0, 8)
	textLabel.Parent = gui
	return textLabel
end

-- A server-validated interaction. The client localizes ActionText via PromptKind.
local function prompt(parent: BasePart, kind: string, actionText: string, orderNumber: number): ProximityPrompt
	local value = Instance.new("ProximityPrompt")
	value.Name = kind
	value.ActionText = actionText
	value.ObjectText = "#" .. orderNumber
	value.KeyboardKeyCode = Enum.KeyCode.E
	value.HoldDuration = 0
	value.MaxActivationDistance = GameConfig.Customers.InteractDistance - 2
	value.RequiresLineOfSight = false
	value:SetAttribute("PromptKind", kind)
	value:SetAttribute("OrderNumber", orderNumber)
	value.Parent = parent
	return value
end

local function speciesName(speciesId: string): string
	local config = GameConfig.Trees[speciesId]
	return if config then config.displayName else speciesId
end

-- Displayed trees carry a stable height and their current price (G3).
function WorldService.syncDisplayedTrees(plotId: string, placements, mediumPrices)
	local plot = findPlot(plotId)
	if not plot or type(placements) ~= "table" then
		return false
	end
	local display = plot:FindFirstChild("DisplayedTrees")
	if display then
		display:Destroy()
	end
	display = Instance.new("Folder")
	display.Name = "DisplayedTrees"
	display.Parent = plot
	local sizeScales = { Small = 0.6, Medium = 0.8, Large = 1.0 }
	for placementId, placement in pairs(placements) do
		if type(placement) == "table" and type(placement.transform) == "table" then
			local transform = placement.transform
			local scale = sizeScales[placement.sizeId] or 0.8
			local model = tree(
				display,
				"DisplayedTree_" .. placementId,
				plot.PrimaryPart.Position + Vector3.new(transform.x, 0.6, transform.z),
				scale
			)
			model:SetAttribute("PlacementId", placementId)
			model:SetAttribute("SpeciesId", placement.speciesId)
			model:SetAttribute("SizeId", placement.sizeId)
			local tenths = TreeHeight.tenthsFor(placementId, placement.sizeId) or 0
			local medium = type(mediumPrices) == "table" and mediumPrices[placement.speciesId]
			local price = if type(medium) == "number" then Economy.priceForSize(medium, placement.sizeId) else 0
			billboard(
				model.PrimaryPart :: BasePart,
				"DisplayTree",
				string.format(
					"%s · %s · %s ft · $%d",
					speciesName(placement.speciesId),
					placement.sizeId,
					TreeHeight.feetText(tenths),
					price
				),
				10 * scale,
				{
					SpeciesId = placement.speciesId,
					SizeId = placement.sizeId,
					HeightTenths = tenths,
					Price = price,
				}
			)
		end
	end
	return true
end

-- Original primitive car: body, cabin, wheels; parts anchored and offset from the pivot.
local function car(parent: Instance, name: string, pivot: CFrame, color: Color3): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	local function carPart(partName: string, size: Vector3, offset: Vector3, partColor: Color3, material)
		local value = part(model, partName, size, Vector3.zero, partColor, material)
		value.CFrame = pivot * CFrame.new(offset)
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
	for _, offset in ipairs({
		Vector3.new(-2.5, 0.75, -2.8),
		Vector3.new(2.5, 0.75, -2.8),
		Vector3.new(-2.5, 0.75, 2.8),
		Vector3.new(2.5, 0.75, 2.8),
	}) do
		local wheel =
			carPart("Wheel", Vector3.new(0.7, 1.5, 1.5), offset, Color3.fromRGB(27, 27, 27), Enum.Material.Rubber)
		wheel.Shape = Enum.PartType.Cylinder
	end
	model.PrimaryPart = body
	return model
end

-- One animation per car: a new drive cancels the previous one (no jitter, no extra loops).
local driving: { [Model]: thread } = setmetatable({}, { __mode = "k" }) :: any

-- Moves an anchored model smoothly; stops quietly if the model is removed meanwhile.
local function drive(model: Model, from: CFrame, to: CFrame, seconds: number, onDone: (() -> ())?)
	local previous = driving[model]
	if previous and coroutine.status(previous) ~= "dead" then
		task.cancel(previous)
	end
	driving[model] = task.spawn(function()
		local started = os.clock()
		while model.Parent do
			local alpha = math.min(1, (os.clock() - started) / seconds)
			model:PivotTo(from:Lerp(to, alpha))
			if alpha >= 1 then
				break
			end
			task.wait(1 / 20)
		end
		if onDone then
			onDone()
		end
	end)
end

local function roadEntry(parked: CFrame): CFrame
	return CFrame.new(parked.Position.X, parked.Position.Y, 0) * parked.Rotation
end

-- Mirrors customer orders into the world: a numbered car per order on its parking space
-- and the sold tree with an "Order #n – PICK UP" label until someone carries it.
-- callbacks.carry(orderNumber, part) and callbacks.load(orderNumber, part) receive the
-- prompt part; the caller validates ownership and reach before mutating state.
function WorldService.syncCustomerOrders(plotId: string, summary, callbacks)
	local plot = findPlot(plotId)
	if not plot then
		return false
	end
	local folder = plot:FindFirstChild("CustomerOrders")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "CustomerOrders"
		folder.Parent = plot
	end
	local center = (plot.PrimaryPart :: BasePart).Position
	local wanted = {}
	local orders = if type(summary) == "table" and type(summary.orders) == "table" then summary.orders else {}
	for _, order in ipairs(orders) do
		wanted[order.orderNumber] = order
	end

	-- Cars whose order is gone drive off; a loaded one leaves with the tree on its roof.
	local loaded = {}
	if type(summary) == "table" and type(summary.loadedNumbers) == "table" then
		for _, orderNumber in ipairs(summary.loadedNumbers) do
			loaded[orderNumber] = true
		end
	end
	for _, child in folder:GetChildren() do
		local orderNumber = child:GetAttribute("OrderNumber")
		if type(orderNumber) == "number" and not wanted[orderNumber] then
			if child:IsA("Model") and child.Name == "CustomerCar_" .. orderNumber and child.PrimaryPart then
				child.Name = "LeavingCar"
				child:SetAttribute("OrderNumber", nil)
				for _, descendant in child:GetDescendants() do
					if descendant:IsA("ProximityPrompt") or descendant:IsA("BillboardGui") then
						descendant:Destroy()
					end
				end
				if loaded[orderNumber] then
					local roofTree = tree(child, "RoofTree", Vector3.zero, 0.35)
					roofTree:PivotTo(child:GetPivot() * CFrame.new(0, 4.4, 0.6) * CFrame.Angles(math.rad(90), 0, 0))
				end
				local parked = child:GetPivot()
				drive(child, parked, roadEntry(parked), CAR_DRIVE_SECONDS, function()
					child:Destroy()
				end)
			else
				child:Destroy()
			end
		end
	end

	for orderNumber, order in pairs(wanted) do
		local carName = "CustomerCar_" .. orderNumber
		local carModel = folder:FindFirstChild(carName)
		if not carModel then
			local slot = math.clamp(order.parkingSpace, 1, 4)
			local parked = CFrame.new(center + parkingOffset(plot, slot) + Vector3.new(0, 0.6, 0))
			local color = CAR_COLORS[(orderNumber - 1) % #CAR_COLORS + 1]
			local newCar = car(folder, carName, roadEntry(parked), color)
			newCar:SetAttribute("OrderNumber", orderNumber)
			local body = newCar.PrimaryPart :: BasePart
			billboard(body, "CarNumber", "#" .. orderNumber, 6, { OrderNumber = orderNumber })
			local loadPrompt = prompt(body, "LoadOrder", "Load tree", orderNumber)
			loadPrompt.Triggered:Connect(function(player)
				if callbacks and callbacks.load then
					callbacks.load(player, orderNumber, body)
				end
			end)
			drive(newCar, roadEntry(parked), parked, CAR_DRIVE_SECONDS)
		end

		local treeName = "PickupTree_" .. orderNumber
		local pickup = folder:FindFirstChild(treeName)
		if order.carried then
			if pickup then
				pickup:Destroy()
			end
		elseif not pickup then
			-- One pickup spot per parking space, so two waiting orders never overlap. The row
			-- lies east of the sales stand (x 23..36) and clear of the checkout counter.
			local column = math.clamp(order.parkingSpace, 1, 4) - 1
			local position = center + Vector3.new(23 + column * 4.5, 0.6, if center.Z < 0 then 13 else -13)
			local scales = { Small = 0.6, Medium = 0.8, Large = 1.0 }
			local pickupTree = tree(folder, treeName, position, scales[order.sizeId] or 0.8)
			pickupTree:SetAttribute("OrderNumber", orderNumber)
			local trunk = pickupTree.PrimaryPart :: BasePart
			billboard(trunk, "PickupOrder", string.format("Order #%d · PICK UP", orderNumber), 9, {
				OrderNumber = orderNumber,
			})
			local carryPrompt = prompt(trunk, "CarryOrder", "Pick up customer tree", orderNumber)
			carryPrompt.Triggered:Connect(function(player)
				if callbacks and callbacks.carry then
					callbacks.carry(player, orderNumber, trunk)
				end
			end)
		end
	end
	return true
end

-- Returns the interaction part for a customer order on a plot (reach checks).
function WorldService.findOrderTarget(plotId: string, kind: string, orderNumber: number): BasePart?
	local plot = findPlot(plotId)
	local folder = plot and plot:FindFirstChild("CustomerOrders")
	if not folder then
		return nil
	end
	local name = if kind == "Car" then "CustomerCar_" .. orderNumber else "PickupTree_" .. orderNumber
	local model = folder:FindFirstChild(name)
	if model and model:IsA("Model") and model.PrimaryPart then
		return model.PrimaryPart
	end
	return nil
end

-- A carried tree rides on the character until it is loaded, released or expires.
function WorldService.attachCarriedTree(character: Model, orderNumber: number)
	WorldService.detachCarriedTree(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local carried = tree(character, "CarriedTree", Vector3.zero, 0.4)
	carried:SetAttribute("OrderNumber", orderNumber)
	for _, descendant in carried:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.Massless = true
		end
	end
	carried:PivotTo(root.CFrame * CFrame.new(1.5, 0, -1.2) * CFrame.Angles(0, 0, math.rad(-20)))
	for _, descendant in carried:GetDescendants() do
		if descendant:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end
end

function WorldService.detachCarriedTree(character: Model?)
	local existing = character and character:FindFirstChild("CarriedTree")
	if existing then
		existing:Destroy()
	end
end

return WorldService
