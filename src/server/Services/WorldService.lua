--!strict
-- Original low-poly winter graybox built from Roblox primitives; no external assets.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArtLibrary = require(Shared:WaitForChild("ArtLibrary"))
local AssetCatalog = require(Shared:WaitForChild("AssetCatalog"))
local Economy = require(Shared:WaitForChild("Economy"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Stocking = require(Shared:WaitForChild("Stocking"))
local TreeHeight = require(Shared:WaitForChild("TreeHeight"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))

local WorldService = {}

-- Receiving bays (CM2-G14) in the lot frame: x from the plot centre, z the depth toward the road.
local BAY_X = 35
local BAY_FIRST_DEPTH = -22
local BAY_DEPTH_STEP = 6
local TRUCK_X = 46
local TRUCK_START_DEPTH = 66
local MAX_BUNDLES = 9
local STRUCTURE_GROUP = GameConfig.Customers.Npc.CollisionGroups.Structure

-- The counter prompt's handler (CM2-N2): main.server validates the player and serves the
-- customer at the counter.
local checkoutHandler: ((Player, string) -> ())? = nil

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

-- Lot trees pass through walking customers (CM2-N1, collision group LotTree), and so do the
-- lot structures: stand, counter and receiving bays (Fix round 1, collision group LotStructure).
local function setCollisionGroup(model: Instance, group: string)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = group
		end
	end
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

-- Levels the art's yaw to the nearest half turn of its largest part (CM2-N1 fix round 2),
-- so a Studio-only template's rotation cannot tilt the stall out of KeepClear `Stand`.
local function levelArt(model: Model)
	local ref: BasePart? = nil
	local bestArea = -math.huge
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local area = descendant.Size.X * descendant.Size.Z
			if area > bestArea then
				bestArea = area
				ref = descendant
			end
		end
	end
	if ref == nil then
		return
	end
	local right = ref.CFrame.RightVector
	local delta = ArtLibrary.levelYaw(right.X, right.Z)
	if math.abs(delta) > 1e-4 then
		local c = model:GetBoundingBox().Position
		model:PivotTo(CFrame.new(c) * CFrame.Angles(0, delta, 0) * CFrame.new(c):Inverse() * model:GetPivot())
	end
	if model.PrimaryPart == nil then
		model.WorldPivot = CFrame.new(model:GetPivot().Position)
	end
end

-- Uses the approved art model when ArtAssets has it, while retaining a primitive
-- fallback for source-only and automated test environments.
local function salesStand(parent: Instance, position: Vector3, assetId: string?): Model
	assetId = assetId or AssetCatalog.Buildings.MarketStarter
	local artPath = "Buildings/" .. assetId
	local template, code = ArtLibrary.find(ReplicatedStorage:FindFirstChild("ArtAssets"), artPath)
	if not template then
		reportMissing(artPath, code or "MissingArtAsset")
		local fallback = tent(parent, position)
		setCollisionGroup(fallback, STRUCTURE_GROUP)
		return fallback
	end

	local model = ArtLibrary.prepareClone(template)
	model.Name = "StarterSalesTent"
	model.Parent = parent
	levelArt(model)
	local box, size = model:GetBoundingBox()
	local targetCenter = position + Vector3.new(0, size.Y / 2, 0)
	model:PivotTo(model:GetPivot() + (targetCenter - box.Position))
	setCollisionGroup(model, STRUCTURE_GROUP)
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
	-- CM2-N2: the player checks out the customer at the counter; enabled only while one waits.
	local checkoutPrompt = Instance.new("ProximityPrompt")
	checkoutPrompt.Name = "CheckoutPrompt"
	checkoutPrompt.ActionText = "Check Out"
	checkoutPrompt.ObjectText = ""
	checkoutPrompt.KeyboardKeyCode = Enum.KeyCode.E
	checkoutPrompt.HoldDuration = 0
	checkoutPrompt.MaxActivationDistance = GameConfig.Customers.InteractDistance - 2
	checkoutPrompt.RequiresLineOfSight = false
	checkoutPrompt.Enabled = false
	checkoutPrompt:SetAttribute("PromptKind", "Checkout")
	checkoutPrompt.Parent = base
	local plotId = parent:GetAttribute("PlotId")
	checkoutPrompt.Triggered:Connect(function(player: Player)
		if checkoutHandler and type(plotId) == "string" then
			checkoutHandler(player, plotId)
		end
	end)
	model.PrimaryPart = base
	setCollisionGroup(model, STRUCTURE_GROUP)
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

-- A floating label. Server text is the English fallback; the client script
-- WorldLabels.client.lua localizes it from the label's attributes (LabelKind etc.).
-- CM2-UVF2: fixed text size and a per-kind box from UiTheme.WorldLabels (no TextScaled).
local function billboard(
	adornee: BasePart,
	kind: string,
	text: string,
	layoutId: string,
	height: number,
	attributes
): TextLabel
	local layout = UiTheme.WorldLabels[layoutId]
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(layout.w, layout.h)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.MaxDistance = layout.maxDistance
	gui.AlwaysOnTop = false
	gui.Adornee = adornee
	gui.Parent = adornee
	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "Text"
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundColor3 = Color3.fromRGB(table.unpack(UiTheme.Colors.Panel))
	textLabel.BackgroundTransparency = 0.15
	textLabel.TextColor3 = Color3.fromRGB(table.unpack(UiTheme.Colors.Cream))
	textLabel.Font = Enum.Font[UiTheme.Fonts.Bold]
	textLabel.TextScaled = false
	textLabel.TextSize = layout.textSize
	textLabel.TextWrapped = layout.wrap
	textLabel.TextTruncate = Enum.TextTruncate.None
	textLabel.Text = text
	textLabel:SetAttribute("LabelKind", kind)
	for key, value in pairs(attributes) do
		textLabel:SetAttribute(key, value)
	end
	Instance.new("UICorner", textLabel).CornerRadius = UDim.new(0, UiTheme.CornerRadius.Button)
	textLabel.Parent = gui
	return textLabel
end

-- +1 when the plot's road side is +Z (plots south of the road), else -1.
local function plotFacing(plot: Model): number
	return Stocking.facing((plot.PrimaryPart :: BasePart).Position.Z)
end

-- A lot-frame point (x from the centre, z toward the road) at world height y. The plot centre
-- is the lot ground's X/Z, so a saved layout is plot-independent.
local function lotPosition(plot: Model, x: number, z: number, y: number): Vector3
	local center = (plot.PrimaryPart :: BasePart).Position
	return Vector3.new(center.X + x, y, center.Z + plotFacing(plot) * z)
end

-- Turns a model built for a +Z road side half around its bounding-box centre on -Z plots.
local function faceRoad(model: Model?, facing: number)
	if model == nil or facing ~= -1 then
		return
	end
	local c = model:GetBoundingBox()
	model:PivotTo(
		CFrame.new(c.Position) * CFrame.Angles(0, math.pi, 0) * (CFrame.new(c.Position):Inverse() * model:GetPivot())
	)
end

local function bayDepth(index: number): number
	return BAY_FIRST_DEPTH + (index - 1) * BAY_DEPTH_STEP
end

-- The receiving area with four bays, a label and a stocking prompt on each (CM2-G14).
local function buildReceiving(plot: Model)
	local folder = Instance.new("Folder")
	folder.Name = "Receiving"
	folder.Parent = plot
	part(
		folder,
		"ReceivingArea",
		Vector3.new(8, 0.3, 26),
		lotPosition(plot, BAY_X, -13, 0.6),
		Color3.fromRGB(92, 127, 139),
		Enum.Material.Concrete
	)
	for index = 1, GameConfig.Receiving.BayCount do
		local bay = part(
			folder,
			"Bay_" .. index,
			Vector3.new(5, 0.6, 5),
			lotPosition(plot, BAY_X, bayDepth(index), 1.05),
			Color3.fromRGB(150, 111, 70),
			Enum.Material.WoodPlanks
		)
		bay:SetAttribute("BayIndex", index)
		billboard(bay, "BayFree", "Free bay", "Bay", UiTheme.WorldLabels.Bay.height, { BayIndex = index })
		local stockPrompt = Instance.new("ProximityPrompt")
		stockPrompt.Name = "StockBay"
		stockPrompt.ActionText = "Stock"
		stockPrompt.KeyboardKeyCode = Enum.KeyCode.E
		stockPrompt.HoldDuration = 0
		stockPrompt.MaxActivationDistance = GameConfig.Customers.InteractDistance - 2
		stockPrompt.RequiresLineOfSight = false
		stockPrompt.Enabled = false
		stockPrompt:SetAttribute("PromptKind", "StockBay")
		stockPrompt:SetAttribute("BayIndex", index)
		stockPrompt.Parent = bay
	end
	setCollisionGroup(folder, STRUCTURE_GROUP)
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
		-- Plots 4-6 mirror the layout so the lot frame (depth toward the road) matches the world.
		local facing = plotFacing(plot)
		local spawn = part(
			plot,
			"Spawn",
			Vector3.new(4, 0.2, 4),
			lotPosition(plot, -28, 14, 0.7),
			Color3.fromRGB(69, 132, 82),
			Enum.Material.Grass
		)
		spawn.Transparency = 0.35
		faceRoad(salesStand(plot, lotPosition(plot, -8, -4, 0.6)), facing)
		faceRoad(checkout(plot, lotPosition(plot, 16, -14, 0.6)), facing)
		cloneArt(plot, "Environment", AssetCatalog.Environment.FenceWooden, lotPosition(plot, -34, 24, 0.6))
		cloneArt(plot, "Environment", AssetCatalog.Environment.FenceWooden, lotPosition(plot, 34, 24, 0.6))
		buildReceiving(plot)
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
	faceRoad(salesStand(plot, lotPosition(plot, -8, -4, 0.6), assetId), plotFacing(plot))
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
	-- CM2-G14: the lot grows backwards (away from the road) by BackDepthPerLevel per level.
	local pad = part(
		visuals,
		"LotExpansionPad",
		Vector3.new(80, 0.18, 54 + 6 * growth),
		plot.PrimaryPart.Position + Vector3.new(0, -0.05, plotFacing(plot) * (-3 * growth)),
		Color3.fromRGB(224, 239, 244),
		Enum.Material.Snow
	)
	pad:SetAttribute("LotExpansionLevel", growth)
	plot:SetAttribute("LotExpansionLevel", growth)
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
	local path = GameConfig.Customers.Npc.Path
	local towardRoad = if (plot.PrimaryPart :: BasePart).Position.Z < 0 then 1 else -1
	return Vector3.new(path.ParkingFirstX + (index - 1) * path.ParkingStep, 0, towardRoad * path.ParkingDepth)
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

-- One animation per car or truck: a new drive cancels the previous one (no jitter, no extra loops).
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

local function finiteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Displayed trees carry a stable height and their current price (G3). Positions are in the
-- lot frame (CM2-G14); a reserved tree shows RESERVED. A tree a walking customer carries
-- (hidden[placementId], CM2-N1) keeps its model, invisible and without a label, so the
-- displayed count still equals the placement count.
function WorldService.syncDisplayedTrees(plotId: string, placements, mediumPrices, reservations, hidden)
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
		local transform = if type(placement) == "table" then placement.transform else nil
		if type(transform) == "table" and finiteNumber(transform.x) and finiteNumber(transform.z) then
			local scale = sizeScales[placement.sizeId] or 0.8
			local model =
				tree(display, "DisplayedTree_" .. placementId, lotPosition(plot, transform.x, transform.z, 0.6), scale)
			local rotation = if finiteNumber(transform.rotation) then transform.rotation else 0
			model:PivotTo(model:GetPivot() * CFrame.Angles(0, math.rad(rotation), 0))
			local reserved = type(reservations) == "table" and reservations[placementId] ~= nil
			model:SetAttribute("PlacementId", placementId)
			model:SetAttribute("SpeciesId", placement.speciesId)
			model:SetAttribute("SizeId", placement.sizeId)
			model:SetAttribute("LotX", transform.x)
			model:SetAttribute("LotZ", transform.z)
			model:SetAttribute("Reserved", reserved)
			setCollisionGroup(model, GameConfig.Customers.Npc.CollisionGroups.Tree)
			if type(hidden) == "table" and hidden[placementId] == true then
				model:SetAttribute("NpcCarried", true)
				for _, descendant in model:GetDescendants() do
					if descendant:IsA("BasePart") then
						descendant.Transparency = 1
						descendant.CanCollide = false
						descendant.CanQuery = false
					end
				end
				continue
			end
			local tenths = TreeHeight.tenthsFor(placementId, placement.sizeId) or 0
			local medium = type(mediumPrices) == "table" and mediumPrices[placement.speciesId]
			local price = if type(medium) == "number" then Economy.priceForSize(medium, placement.sizeId) else 0
			local label = billboard(
				model.PrimaryPart :: BasePart,
				"DisplayTree",
				string.format(
					"%s · %s · %s ft · $%d",
					speciesName(placement.speciesId),
					placement.sizeId,
					TreeHeight.feetText(tenths),
					price
				),
				"DisplayTree",
				UiTheme.WorldLabels.DisplayTree.height * scale,
				{
					SpeciesId = placement.speciesId,
					SizeId = placement.sizeId,
					HeightTenths = tenths,
					Price = price,
				}
			)
			if reserved then
				label:SetAttribute("Reserved", true)
				label.Text = "RESERVED"
			end
		end
	end
	return true
end

local function bayCount(view, sizeId: string): number
	local counts = if type(view) == "table" and type(view.counts) == "table" then view.counts else {}
	local value = counts[sizeId]
	return if type(value) == "number" then value else 0
end

local function setBayAttributes(target: Instance, view)
	target:SetAttribute("SpeciesId", view.speciesId)
	target:SetAttribute("CountSmall", bayCount(view, "Small"))
	target:SetAttribute("CountMedium", bayCount(view, "Medium"))
	target:SetAttribute("CountLarge", bayCount(view, "Large"))
	target:SetAttribute("Arriving", view.arriving)
	target:SetAttribute("ArrivesIn", view.arrivesIn)
end

-- min(total, 9) log bundles on the pallet, rebuilt only when the total changes.
local function syncBundles(bay: BasePart, total: number)
	local bundles = bay:FindFirstChild("Bundles")
	if bundles and bundles:GetAttribute("Total") == total then
		return
	end
	if bundles then
		bundles:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = "Bundles"
	model:SetAttribute("Total", total)
	for k = 0, math.min(total, MAX_BUNDLES) - 1 do
		local bundle = part(
			model,
			"Bundle",
			Vector3.new(4, 1, 1),
			bay.Position + Vector3.new(0, 0.8 + (k // 3), -1.2 + (k % 3) * 1.2),
			Color3.fromRGB(23, 83, 52),
			Enum.Material.Grass
		)
		bundle.Shape = Enum.PartType.Cylinder
		bundle.CanCollide = false
	end
	model.Parent = bay
end

local function truckStart(plot: Model): CFrame
	return CFrame.new(lotPosition(plot, TRUCK_X, TRUCK_START_DEPTH, 2)) * CFrame.Angles(0, math.pi / 2, 0)
end

-- Mirrors the receiving bays into the world (CM2-G14): attributes for the client, the label
-- kind and fallback text, the stocking prompt, tree bundles and the delivery truck, which pulls
-- in during the last TruckPullInSeconds of a countdown. bays == nil means all bays are empty
-- and no truck.
function WorldService.syncReceiving(plotId: string, bays)
	local plot = findPlot(plotId)
	local folder = plot and plot:FindFirstChild("Receiving")
	if not (plot and folder) then
		return false
	end
	local receivingConfig = GameConfig.Receiving
	local pullInBay: number? = nil
	for index = 1, receivingConfig.BayCount do
		local view = if type(bays) == "table" and type(bays[index]) == "table" then bays[index] else nil
		view = view
			or {
				speciesId = "",
				counts = { Small = 0, Medium = 0, Large = 0 },
				total = 0,
				arriving = 0,
				arrivesIn = -1,
			}
		local bay = folder:FindFirstChild("Bay_" .. index)
		if bay and bay:IsA("BasePart") then
			local small, medium, large = bayCount(view, "Small"), bayCount(view, "Medium"), bayCount(view, "Large")
			local total = small + medium + large
			local arrivesIn = if type(view.arrivesIn) == "number" then view.arrivesIn else -1
			local name = speciesName(view.speciesId)
			local sizesText = string.format("%d Small · %d Medium · %d Large", small, medium, large)
			setBayAttributes(bay, view)
			local gui = bay:FindFirstChild("Label")
			local label = gui and gui:FindFirstChild("Text")
			if label and label:IsA("TextLabel") then
				setBayAttributes(label, view)
				if arrivesIn >= 0 then
					label:SetAttribute("LabelKind", "BayArriving")
					label.Text = string.format("Delivery arriving %d:%02d", arrivesIn // 60, arrivesIn % 60)
				elseif total > 0 then
					label:SetAttribute("LabelKind", "BayContents")
					label.Text = if total == 1
						then name .. " · 1 tree"
						else string.format("%s · %d trees", name, total)
				else
					label:SetAttribute("LabelKind", "BayFree")
					label.Text = "Free bay"
				end
			end
			local stockPrompt = bay:FindFirstChild("StockBay")
			if stockPrompt and stockPrompt:IsA("ProximityPrompt") then
				setBayAttributes(stockPrompt, view)
				stockPrompt.Enabled = total > 0
				stockPrompt.ActionText = "Stock " .. name
				stockPrompt.ObjectText = sizesText
			end
			syncBundles(bay, total)
			if pullInBay == nil and arrivesIn >= 0 and arrivesIn <= receivingConfig.TruckPullInSeconds then
				pullInBay = index
			end
		end
	end

	local activeTruck: Model? = nil
	for _, child in plot:GetChildren() do
		if child.Name == "DeliveryTruck" and child:IsA("Model") then
			if bays == nil then
				child:Destroy()
			elseif child:GetAttribute("Leaving") ~= true then
				activeTruck = child
			end
		end
	end
	if pullInBay ~= nil then
		if activeTruck == nil then
			local newTruck = truck(plot, Vector3.zero)
			newTruck.Name = "DeliveryTruck"
			local start = truckStart(plot)
			local stop = CFrame.new(lotPosition(plot, TRUCK_X, bayDepth(pullInBay), 2)) * start.Rotation
			newTruck:PivotTo(start)
			drive(newTruck, start, stop, receivingConfig.TruckPullInSeconds)
		end
	elseif activeTruck ~= nil then
		local leaving = activeTruck
		leaving:SetAttribute("Leaving", true)
		drive(leaving, leaving:GetPivot(), truckStart(plot), receivingConfig.TruckLeaveSeconds, function()
			leaving:Destroy()
		end)
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

local function roadEntry(parked: CFrame): CFrame
	return CFrame.new(parked.Position.X, parked.Position.Y, 0) * parked.Rotation
end

-- The parked pose of a car on parking space `space` (1..4).
local function parkedAt(plot: Model, space: number): CFrame
	local center = (plot.PrimaryPart :: BasePart).Position
	return CFrame.new(center + parkingOffset(plot, math.clamp(space, 1, 4)) + Vector3.new(0, 0.6, 0))
end

-- The "#n HERE" billboard and the LoadOrder prompt of an order car; added only when missing,
-- so an adopted visit car (CM2-N1) is decorated once.
local function decorateCar(carModel: Model, orderNumber: number, callbacks)
	local body = carModel.PrimaryPart
	if not body then
		return
	end
	if body:FindFirstChild("Label") == nil then
		billboard(
			body,
			"CarNumber",
			"#" .. orderNumber,
			"CarNumber",
			UiTheme.WorldLabels.CarNumber.height,
			{ OrderNumber = orderNumber }
		)
	end
	if body:FindFirstChild("LoadOrder") == nil then
		local loadPrompt = prompt(body, "LoadOrder", "Load tree", orderNumber)
		loadPrompt.Triggered:Connect(function(player)
			if callbacks and callbacks.load then
				callbacks.load(player, orderNumber, body)
			end
		end)
	end
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
		if carModel and carModel:IsA("Model") then
			-- A walking customer's adopted visit car (CM2-N1) or an existing order car.
			decorateCar(carModel, orderNumber, callbacks)
		elseif not carModel then
			local parked = parkedAt(plot, order.parkingSpace)
			local color = CAR_COLORS[(orderNumber - 1) % #CAR_COLORS + 1]
			local newCar = car(folder, carName, roadEntry(parked), color)
			newCar:SetAttribute("OrderNumber", orderNumber)
			decorateCar(newCar, orderNumber, callbacks)
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
			setCollisionGroup(pickupTree, GameConfig.Customers.Npc.CollisionGroups.Tree)
			local trunk = pickupTree.PrimaryPart :: BasePart
			local pickupLayout = UiTheme.WorldLabels.PickupOrder
			billboard(
				trunk,
				"PickupOrder",
				string.format("Order #%d · PICK UP", orderNumber),
				"PickupOrder",
				pickupLayout.height + (if column % 2 == 0 then pickupLayout.stagger else 0),
				{ OrderNumber = orderNumber }
			)
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

-- Walking customers (CM2-N1) ----------------------------------------------------------------

-- The top centre of the plot's lot ground (lot-frame origin at ground height), or nil.
function WorldService.plotCenter(plotId: string): Vector3?
	local plot = findPlot(plotId)
	if not plot then
		return nil
	end
	local ground = plot.PrimaryPart :: BasePart
	return ground.Position + Vector3.new(0, ground.Size.Y / 2, 0)
end

-- Manual checkout (CM2-N2) ------------------------------------------------------------------

function WorldService.setCheckoutHandler(handler: ((Player, string) -> ())?)
	checkoutHandler = handler
end

local function checkoutBase(plotId: string): BasePart?
	local plot = findPlot(plotId)
	local counter = plot and plot:FindFirstChild("CheckoutCounter")
	local base = counter and counter:FindFirstChild("CounterBase")
	if base and base:IsA("BasePart") then
		return base
	end
	return nil
end

-- The part a player must stand near to check out (server reach check).
function WorldService.checkoutTarget(plotId: string): BasePart?
	return checkoutBase(plotId)
end

-- Shows the tree of the customer at the counter on the plot's CheckoutPrompt, or hides the
-- prompt (info nil). info = {speciesId, sizeId, heightTenths, price}. False without a prompt.
function WorldService.setCheckoutPrompt(plotId: string, info): boolean
	local base = checkoutBase(plotId)
	local value = base and base:FindFirstChild("CheckoutPrompt")
	if not (value and value:IsA("ProximityPrompt")) then
		return false
	end
	if info ~= nil then
		value:SetAttribute("SpeciesId", info.speciesId)
		value:SetAttribute("SizeId", info.sizeId)
		value:SetAttribute("HeightTenths", info.heightTenths)
		value:SetAttribute("Price", info.price)
		value.ObjectText = string.format(
			"%s · %s · %s ft · $%d",
			speciesName(info.speciesId),
			info.sizeId,
			TreeHeight.feetText(info.heightTenths),
			info.price
		)
		value.Enabled = true
	else
		value.Enabled = false
		value.ObjectText = ""
		value:SetAttribute("SpeciesId", nil)
		value:SetAttribute("SizeId", nil)
		value:SetAttribute("HeightTenths", nil)
		value:SetAttribute("Price", nil)
	end
	return true
end

-- `<plot>.Customers`, where the walking customers' avatars live; nil without the plot.
function WorldService.customersFolder(plotId: string): Folder?
	local plot = findPlot(plotId)
	if not plot then
		return nil
	end
	local folder = plot:FindFirstChild("Customers")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Customers"
		folder.Parent = plot
	end
	return folder :: Folder
end

local function ordersFolder(plot: Model): Folder
	local folder = plot:FindFirstChild("CustomerOrders")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "CustomerOrders"
		folder.Parent = plot
	end
	return folder :: Folder
end

-- A walking customer's car `VisitCar_<seq>` drives onto parking space `space`.
function WorldService.spawnVisitCar(plotId: string, seq: number, space: number): Model?
	local plot = findPlot(plotId)
	if not plot then
		return nil
	end
	local parked = parkedAt(plot, space)
	local color = CAR_COLORS[(seq - 1) % #CAR_COLORS + 1]
	local visitCar = car(ordersFolder(plot), "VisitCar_" .. seq, roadEntry(parked), color)
	drive(visitCar, roadEntry(parked), parked, CAR_DRIVE_SECONDS)
	return visitCar
end

-- At the sale the visit car becomes the order's car; syncCustomerOrders then decorates it
-- instead of spawning a second one.
function WorldService.adoptVisitCar(visitCar: Model, orderNumber: number)
	if visitCar.Parent == nil then
		return
	end
	visitCar.Name = "CustomerCar_" .. orderNumber
	visitCar:SetAttribute("OrderNumber", orderNumber)
end

-- A visit car without a sale leaves as LeavingCar and is destroyed off the lot.
function WorldService.dismissVisitCar(visitCar: Model)
	if visitCar.Parent == nil then
		return
	end
	visitCar.Name = "LeavingCar"
	local parked = visitCar:GetPivot()
	drive(visitCar, parked, roadEntry(parked), CAR_DRIVE_SECONDS, function()
		visitCar:Destroy()
	end)
end

function WorldService.destroyVisitCar(visitCar: Model)
	visitCar:Destroy()
end

local NPC_TREE_SCALES = { Small = 0.35, Medium = 0.4, Large = 0.45 }

-- The tree a walking customer carries: welded to the root, massless and non-colliding.
function WorldService.attachNpcTree(model: Model, sizeId: string?)
	WorldService.detachNpcTree(model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local carried = tree(model, "NpcCarriedTree", Vector3.zero, NPC_TREE_SCALES[sizeId or ""] or 0.4)
	for _, descendant in carried:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
			descendant.CollisionGroup = GameConfig.Customers.Npc.CollisionGroups.Tree
		end
	end
	carried:PivotTo(root.CFrame * CFrame.new(0, 0.2, -1.4) * CFrame.Angles(0, 0, math.rad(-15)))
	for _, descendant in carried:GetDescendants() do
		if descendant:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end
end

function WorldService.detachNpcTree(model: Model)
	local existing = model:FindFirstChild("NpcCarriedTree")
	if existing then
		existing:Destroy()
	end
end

-- A short speech billboard ("Thanks so much!", OBSERVED) removed after `seconds`.
function WorldService.speech(adornee: BasePart, kind: string, text: string, seconds: number)
	local label = billboard(adornee, kind, text, "Speech", UiTheme.WorldLabels.Speech.height, {})
	local gui = label.Parent :: BillboardGui
	gui.Name = "Speech"
	Debris:AddItem(gui, seconds)
end

return WorldService
