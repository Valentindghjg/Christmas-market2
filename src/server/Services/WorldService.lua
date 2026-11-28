--!strict
-- Original low-poly winter graybox built from Roblox primitives; no external assets.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArtLibrary = require(Shared:WaitForChild("ArtLibrary"))
local AssetCatalog = require(Shared:WaitForChild("AssetCatalog"))
local Economy = require(Shared:WaitForChild("Economy"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local LotArt = require(Shared:WaitForChild("LotArt"))
local NpcPath = require(Shared:WaitForChild("NpcPath"))
local Stocking = require(Shared:WaitForChild("Stocking"))
local TreeArt = require(Shared:WaitForChild("TreeArt"))
local TreeHeight = require(Shared:WaitForChild("TreeHeight"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local VehicleArt = require(Shared:WaitForChild("VehicleArt"))
local LotArtWorld = require(script.Parent:WaitForChild("LotArtWorld"))
local LotFenceWorld = require(script.Parent:WaitForChild("LotFenceWorld"))
local LotGateWorld = require(script.Parent:WaitForChild("LotGateWorld"))
local MapWorld = require(script.Parent:WaitForChild("MapWorld"))
local ParkingWorld = require(script.Parent:WaitForChild("ParkingWorld"))
local VehicleWorld = require(script.Parent:WaitForChild("VehicleWorld"))

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
	local template, code = ArtLibrary.find(ArtLibrary.root(ReplicatedStorage), artPath)
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
	-- CM2-G9a A1/A3: art larger than KeepClear Stand minus StandFitMargin per side shrinks uniformly.
	local stand, margin = LotFenceWorld.keepClearBox("Stand"), GameConfig.Placement.StandFitMargin
	local sizeX, sizeZ = LotFenceWorld.worldExtents(model)
	local maxX, maxZ = stand.maxX - stand.minX - 2 * margin, stand.maxZ - stand.minZ - 2 * margin
	local scale = ArtLibrary.fitScale(sizeX, sizeZ, maxX, maxZ)
	if scale < 1 then
		model:ScaleTo(model:GetScale() * scale)
	end
	model:SetAttribute("FitScale", scale)
	local box, size = model:GetBoundingBox()
	local targetCenter = position + Vector3.new(0, size.Y / 2, 0)
	model:PivotTo(model:GetPivot() + (targetCenter - box.Position))
	setCollisionGroup(model, STRUCTURE_GROUP)
	return model
end

local function cloneArt(parent: Instance, category: string, assetId: string, groundPosition: Vector3): Model?
	local artPath = category .. "/" .. assetId
	local template, code = ArtLibrary.find(ArtLibrary.root(ReplicatedStorage), artPath)
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
	textLabel.TextColor3 = Color3.fromRGB(table.unpack(UiTheme.Colors.DarkText))
	textLabel.FontFace = UiTheme.fontFace("Title")
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

-- Top surface height of the plot's lot ground (CM2-12W: the foot of every lot tree).
local function lotTop(plot: Model): number
	local ground = plot.PrimaryPart :: BasePart
	return ground.Position.Y + ground.Size.Y / 2
end

-- What LotArtWorld needs from this module (CM2-13W).
local ART_CTX: LotArtWorld.Ctx = {
	lotPosition = lotPosition,
	lotTop = lotTop,
	facing = plotFacing,
	setCollisionGroup = setCollisionGroup,
	group = STRUCTURE_GROUP,
	reportMissing = reportMissing,
}

-- What VehicleWorld needs from this module (CM2-14W).
local VEHICLE_CTX: VehicleWorld.Ctx = { part = part, reportMissing = reportMissing }

-- Height of a model's bounding-box top above baseY.
local function treeTop(model: Model, baseY: number): number
	local box, size = model:GetBoundingBox()
	return box.Position.Y + size.Y / 2 - baseY
end

-- A tree of one world role (CM2-12W): the CM2-12 art when ArtAssets has Trees/<Species>/<Size>,
-- else the primitive tree. `base` is the foot of the tree.
local function buildTree(
	root: Instance?,
	parent: Instance,
	name: string,
	role: string,
	speciesId: string?,
	sizeId: string?,
	base: Vector3,
	yaw: number
): Model
	local choice = TreeArt.choose(root, ArtLibrary.find, role, speciesId, sizeId)
	local model: Model
	if choice.mode == "Art" then
		model = ArtLibrary.prepareClone(choice.template)
		model.Name = name
		model.Parent = parent
		local _, size = model:GetBoundingBox()
		local scale = TreeArt.artScale(role, sizeId, size.Y)
		if scale ~= 1 then
			model:ScaleTo(scale)
		end
		model:PivotTo(CFrame.new(base) * CFrame.Angles(0, math.rad(yaw), 0))
		model:SetAttribute("TreeArtScale", scale)
	else
		reportMissing(choice.path, choice.code or "MissingArtAsset")
		model = tree(parent, name, base, choice.primitiveScale)
		if yaw ~= 0 then
			model:PivotTo(model:GetPivot() * CFrame.Angles(0, math.rad(yaw), 0))
		end
	end
	model:SetAttribute("TreeArtMode", choice.mode)
	model:SetAttribute("TreeArtPath", choice.path)
	return model
end

-- A label above the tree top: `UiTheme.WorldLabels[layoutId].height` studs above it, plus stagger.
local function labelTree(
	model: Model,
	baseY: number,
	kind: string,
	text: string,
	layoutId: string,
	stagger: number,
	attributes
): TextLabel
	local adornee = model.PrimaryPart :: BasePart
	local height = TreeArt.labelOffset(
		treeTop(model, baseY),
		adornee.Position.Y - baseY,
		UiTheme.WorldLabels[layoutId].height,
		stagger
	)
	return billboard(adornee, kind, text, layoutId, height, attributes)
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

-- The checkout counter (CM2-13W): the CM2-13b art when ArtAssets has it, with today's CounterBase as
-- an invisible gameplay anchor (prompt, size, position); else the primitive counter and register.
local function buildCounter(plot: Model): Model
	local position = lotPosition(plot, LotArt.COUNTER.x, LotArt.COUNTER.z, 0.6)
	local baseSize = Vector3.new(5, 3, 2)
	local baseColor = Color3.fromRGB(107, 68, 38)
	local model = LotArtWorld.counter(plot, ART_CTX)
	local base: Part
	local lightParent: BasePart
	if model then
		base =
			part(model, "CounterBase", baseSize, position + Vector3.new(0, 1.5, 0), baseColor, Enum.Material.WoodPlanks)
		base.Transparency = 1
		base.CanCollide = false
		lightParent = base
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") and descendant.Name == "Register" then
				lightParent = descendant
				break
			end
		end
		model:SetAttribute("LotArtMode", "Art")
	else
		model = Instance.new("Model")
		model.Name = "CheckoutCounter"
		model.Parent = plot
		base =
			part(model, "CounterBase", baseSize, position + Vector3.new(0, 1.5, 0), baseColor, Enum.Material.WoodPlanks)
		lightParent = part(
			model,
			"Register",
			Vector3.new(1.5, 0.7, 1),
			position + Vector3.new(0, 3.35, 0),
			Color3.fromRGB(40, 48, 51),
			Enum.Material.Metal
		)
		model.PrimaryPart = base
		faceRoad(model, plotFacing(plot))
		model:SetAttribute("LotArtMode", "Primitive")
	end
	MapWorld.nightLight(lightParent, GameConfig.DayCycle.PlotLight) -- CM2-G12a
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
	local plotId = plot:GetAttribute("PlotId")
	checkoutPrompt.Triggered:Connect(function(player: Player)
		if checkoutHandler and type(plotId) == "string" then
			checkoutHandler(player, plotId)
		end
	end)
	setCollisionGroup(model, STRUCTURE_GROUP)
	return model
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
		-- CM2-13W: the deck art stands on the lot ground; Bay_<i> stays as the invisible anchor.
		local art =
			LotArtWorld.bay(folder, plot, index, lotPosition(plot, BAY_X, bayDepth(index), lotTop(plot)), ART_CTX)
		if art then
			bay.Transparency = 1
		end
		bay:SetAttribute("LotArtMode", if art then "Art" else "Primitive")
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

local paletteColor = MapWorld.paletteColor

local function uiColor(key: string): Color3
	return Color3.fromRGB(table.unpack(UiTheme.Colors[key]))
end

-- One line of the lot sign: a transparent TextLabel between scale heights top and bottom.
local function signLine(parent: Instance, name: string, top: number, bottom: number, color: string): TextLabel
	local padding = UiTheme.LotSign.padding
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = UDim2.new(0, padding, top, 0)
	label.Size = UDim2.new(1, -2 * padding, bottom - top, 0)
	label.FontFace = UiTheme.fontFace("Title")
	label.TextColor3 = uiColor(color)
	label.Text = ""
	label.Parent = parent
	return label
end

-- One face of the lot sign board: name, rating and likes (CM2-G15).
local function signFace(board: BasePart, name: string, face: Enum.NormalId)
	local tokens = UiTheme.LotSign
	local gui = Instance.new("SurfaceGui")
	gui.Name = name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = tokens.pixelsPerStud
	gui.LightInfluence = 0
	gui.MaxDistance = tokens.maxDistance
	gui.Adornee = board
	gui.Parent = board
	local frame = Instance.new("Frame")
	frame.Name = "Frame"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = uiColor("Panel")
	frame.BorderSizePixel = 0
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0, UiTheme.CornerRadius.Panel)
	frame.Parent = gui
	local nameLabel = signLine(frame, "Name", 0.04, 0.44, "GoldText")
	nameLabel.TextScaled = true
	nameLabel.TextWrapped = false
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.AutoLocalize = false
	nameLabel:SetAttribute("LabelKind", "LotSignName")
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = tokens.nameMaxTextSize
	constraint.MinTextSize = tokens.nameMinTextSize
	constraint.Parent = nameLabel
	local rating = signLine(frame, "Rating", 0.46, 0.72, "DarkText")
	rating.TextSize = tokens.lineTextSize
	rating:SetAttribute("LabelKind", "LotSignRating")
	local likes = signLine(frame, "Likes", 0.72, 0.98, "DarkText")
	likes.TextSize = tokens.lineTextSize
	likes:SetAttribute("LabelKind", "LotSignLikes")
end

-- The Part-built lot sign at the front of the lot (CM2-G15): two posts, a board with the
-- company name, the rating and the likes on both faces, a snow cap and the Like prompt.
local function lotSign(plot: Model)
	local model = Instance.new("Model")
	model.Name = "LotSign"
	model.Parent = plot
	local facing = plotFacing(plot)
	local function at(x: number, y: number): Vector3
		return lotPosition(plot, GameConfig.Reviews.SignX + x, GameConfig.Reviews.SignZ, y)
	end
	local smooth = Enum.Material.SmoothPlastic
	part(model, "Post_L", Vector3.new(0.6, 6.6, 0.6), at(-3.5, 3.85), paletteColor("WoodWarmShade"), smooth)
	part(model, "Post_R", Vector3.new(0.6, 6.6, 0.6), at(3.5, 3.85), paletteColor("WoodWarmShade"), smooth)
	local boardCenter = at(0, 5.1)
	local board = part(model, "Board", Vector3.new(8, 4, 0.4), boardCenter, paletteColor("WoodWarm"), smooth)
	board.CFrame = CFrame.lookAt(boardCenter, boardCenter + Vector3.new(0, 0, facing))
	local capCenter = at(0, 7.25)
	local cap = part(model, "Cap", Vector3.new(8.6, 0.3, 0.8), capCenter, paletteColor("SnowWhite"), smooth)
	cap.CFrame = CFrame.lookAt(capCenter, capCenter + Vector3.new(0, 0, facing))
	cap.CanCollide = false
	MapWorld.nightLight(cap, GameConfig.DayCycle.PlotLight) -- CM2-G12a
	signFace(board, "SignFront", Enum.NormalId.Front)
	signFace(board, "SignBack", Enum.NormalId.Back)
	local likePrompt = Instance.new("ProximityPrompt")
	likePrompt.Name = "LikePrompt"
	likePrompt.ActionText = "Like"
	likePrompt.ObjectText = "Lot sign"
	likePrompt.KeyboardKeyCode = Enum.KeyCode.E
	likePrompt.HoldDuration = 0
	likePrompt.RequiresLineOfSight = false
	likePrompt.MaxActivationDistance = GameConfig.Customers.InteractDistance - 2
	likePrompt.Enabled = false
	likePrompt:SetAttribute("PromptKind", "LikeLot")
	likePrompt:SetAttribute("PlotId", plot.Name)
	likePrompt.Parent = board
	model.PrimaryPart = board
	setCollisionGroup(model, STRUCTURE_GROUP)
	WorldService.setLotSign(plot.Name, nil)
end

-- HQ tiers 2-4 (CM2-G9a): Part primitives of the CM2-13a footprints; the fallback when the HQ art is missing.
-- Palette keys floor, frame, roof per level.
local HQ_COLORS = {
	[2] = { "StoneGray", "WoodWarmShade", "RoofGreen" },
	[3] = { "StoneGray", "BarkBrown", "RoofSlate" },
	[4] = { "StoneGrayShade", "WoodWarm", "RoofRed" },
}

-- Built in the lot frame with lotPosition, so it needs no faceRoad: the counter and the front
-- roof half face the road on every plot.
local function hqPrimitive(plot: Model, level: number): Model
	local tier = GameConfig.Progression.HQ.tiers[level]
	local f = tier.footprint
	local w, d = f.maxX - f.minX, f.maxZ - f.minZ
	local cx, cz = (f.minX + f.maxX) / 2, (f.minZ + f.maxZ) / 2
	local colors = HQ_COLORS[level]
	local model = Instance.new("Model")
	model.Name = "StarterSalesTent" -- step 37 and CM2-13W read this name for every tier
	model.Parent = plot
	local function add(name: string, size: Vector3, x: number, z: number, y: number, key: string): Part
		return part(model, name, size, lotPosition(plot, x, z, y), paletteColor(key), Enum.Material.SmoothPlastic)
	end
	model.PrimaryPart = add("HqFloor", Vector3.new(w, 0.6, d), cx, cz, 0.9, colors[1])
	local wall = tier.eave - 1.2
	local wallY = 1.2 + wall / 2
	for _, x in { f.minX + 0.4, f.maxX - 0.4 } do
		for _, z in { f.minZ + 0.4, f.maxZ - 0.4 } do
			add("Post", Vector3.new(0.8, wall, 0.8), x, z, wallY, colors[2])
		end
	end
	if level >= 3 then
		add("WallBack", Vector3.new(w - 1.6, wall, 0.6), cx, f.minZ + 0.3, wallY, colors[2])
		add("WallLeft", Vector3.new(0.6, wall, d - 1.6), f.minX + 0.3, cz, wallY, colors[2])
		add("WallRight", Vector3.new(0.6, wall, d - 1.6), f.maxX - 0.3, cz, wallY, colors[2])
	end
	add("Counter", Vector3.new(w / 2, 3.6, 1.2), cx, f.maxZ - 0.6, 3, "WoodWarm")
	local rise = tier.height - tier.eave
	local facing = plotFacing(plot)
	for _, half in { { name = "RoofFront", side = 1 }, { name = "RoofBack", side = -1 } } do
		local roof =
			add(half.name, Vector3.new(w, rise, d / 2), cx, cz + half.side * d / 4, tier.eave + rise / 2, colors[3])
		roof.Shape = Enum.PartType.Wedge
		local c = roof.Position
		roof.CFrame = CFrame.lookAt(c, c + Vector3.new(0, 0, facing * half.side))
		roof.CanCollide = false
	end
	setCollisionGroup(model, STRUCTURE_GROUP)
	return model
end

-- The stand of one HQ level (CM2-13W): the CM2-13a art of its tier; without it the sales tent
-- (level 1) or the Part primitive (levels 2-4).
local function buildHQ(plot: Model, level: number): Model
	local hq = LotArt.hqLevel(level)
	local model = LotArtWorld.hq(plot, hq, ART_CTX)
	if model == nil then
		if hq == 1 then
			model = salesStand(plot, lotPosition(plot, -8, -4, 0.6))
			faceRoad(model, plotFacing(plot))
		else
			model = hqPrimitive(plot, hq)
		end
		model:SetAttribute("HqArtMode", "Primitive")
		model:SetAttribute("HqArtPath", LotArt.hqPath(hq))
	end
	model:SetAttribute("HqLevel", hq)
	model:SetAttribute("HqTier", GameConfig.Progression.HQ.tiers[hq].id)
	return model
end

-- CM2-FLICK: the Studio template's Baseplate (top y 0) z-fights with MapLayout's snow ground;
-- the Rojo/release place has none. Records what it removed on the world folder.
local function removeDefaultBaseplate(world: Folder)
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		world:SetAttribute(
			"RemovedBaseplate",
			string.format(
				"top %.2f size %gx%gx%g",
				baseplate.Position.Y + baseplate.Size.Y / 2,
				baseplate.Size.X,
				baseplate.Size.Y,
				baseplate.Size.Z
			)
		)
		baseplate:Destroy()
	end
end

function WorldService.build()
	local existing = workspace:FindFirstChild("ChristmasMarketWorld")
	if existing then
		return existing
	end
	local world = Instance.new("Folder")
	world.Name = "ChristmasMarketWorld"
	world.Parent = workspace
	removeDefaultBaseplate(world)

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
		local spawn = part(
			plot,
			"Spawn",
			Vector3.new(4, 0.2, 4),
			-- CM2-FLICK: top 0.90 keeps the spawn pad above the lot ground (top 0.55).
			lotPosition(plot, -28, 14, 0.8),
			Color3.fromRGB(69, 132, 82),
			Enum.Material.Grass
		)
		spawn.Transparency = 0.35
		buildHQ(plot, 1)
		buildCounter(plot)
		for _, fence in GameConfig.Placement.DecorFences do
			if LotArtWorld.decorFence(plot, fence.x, fence.z, ART_CTX) == nil then
				local decor = Instance.new("Model")
				decor.Name = "DecorFence"
				decor:SetAttribute("LotArtMode", "Primitive")
				decor.Parent = plot
				cloneArt(
					decor,
					"Environment",
					AssetCatalog.Environment.FenceWooden,
					lotPosition(plot, fence.x, fence.z, 0.6)
				)
			end
		end
		buildReceiving(plot)
		LotGateWorld.build(plot, ART_CTX)
		lotSign(plot)
	end

	MapWorld.build(world, { part = part, tree = tree, reportMissing = reportMissing })
	return world
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

-- The lot fence's builders (CM2-G9a, LotFenceWorld).
local FENCE_HELPERS = {
	part = part,
	lotPosition = lotPosition,
	lotTop = lotTop,
	facing = plotFacing,
	paletteColor = paletteColor,
	setCollisionGroup = setCollisionGroup,
	group = STRUCTURE_GROUP,
	reportMissing = reportMissing,
}

-- The stand of HQ level 1-4 (CM2-G9a): the sales tent art at 1, a Part primitive above.
function WorldService.applyHQVisual(plotId: string, level: number): boolean
	local plot = findPlot(plotId)
	if not plot then
		return false
	end
	local existing = plot:FindFirstChild("StarterSalesTent")
	if existing then
		existing:Destroy()
	end
	buildHQ(plot, level)
	plot:SetAttribute("HqLevel", LotArt.hqLevel(level))
	return true
end

function WorldService.applyLotExpansionVisual(plotId: string, level: number)
	local plot = findPlot(plotId)
	if not plot or level < 0 then
		return false
	end
	local visuals = plot:FindFirstChild("ProgressionVisuals") or Instance.new("Folder")
	visuals.Name = "ProgressionVisuals"
	visuals.Parent = plot
	local existing = visuals:FindFirstChild("LotExpansionPad")
	if existing then
		existing:Destroy()
	end
	local growth = math.clamp(math.floor(level), 0, GameConfig.Progression.LotExpansion.maxLevel)
	local depth = GameConfig.Placement.BackDepthPerLevel
	-- CM2-G14: the lot grows backwards (away from the road) by BackDepthPerLevel per level.
	local pad = part(
		visuals,
		"LotExpansionPad",
		Vector3.new(80, 0.18, 54 + depth * growth),
		(plot.PrimaryPart :: BasePart).Position + Vector3.new(0, -0.05, plotFacing(plot) * (-(depth / 2) * growth)),
		Color3.fromRGB(224, 239, 244),
		Enum.Material.Snow
	)
	pad:SetAttribute("LotExpansionLevel", growth)
	plot:SetAttribute("LotExpansionLevel", growth)
	LotFenceWorld.build(plot, visuals, growth, FENCE_HELPERS)
	MapWorld.applyReserve(plotId, growth)
	return true
end

-- Parking sits outside the front fence (CM2-LOTLAY; plots south of the road face +Z).
local function parkingOffset(plot: Model, index: number): Vector3
	local spot = NpcPath.parkingSpot(index)
	local towardRoad = if (plot.PrimaryPart :: BasePart).Position.Z < 0 then 1 else -1
	return Vector3.new(spot.x, 0, towardRoad * spot.z)
end

function WorldService.applyParkingVisual(plotId: string, spaces: number)
	local plot = findPlot(plotId)
	if not plot or spaces < 0 then
		return false
	end
	local visuals = plot:FindFirstChild("ProgressionVisuals") or Instance.new("Folder")
	visuals.Name = "ProgressionVisuals"
	visuals.Parent = plot
	-- CM2-PARK: bays (pad, lines, wheel stop) and the car park fixtures (ParkingWorld).
	ParkingWorld.build(plot, visuals, spaces, FENCE_HELPERS)
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
	local artRoot = ArtLibrary.root(ReplicatedStorage)
	for placementId, placement in pairs(placements) do
		local transform = if type(placement) == "table" then placement.transform else nil
		if type(transform) == "table" and finiteNumber(transform.x) and finiteNumber(transform.z) then
			local rotation = if finiteNumber(transform.rotation) then transform.rotation else 0
			local base = lotPosition(plot, transform.x, transform.z, lotTop(plot))
			local model = buildTree(
				artRoot,
				display,
				"DisplayedTree_" .. placementId,
				"Display",
				placement.speciesId,
				placement.sizeId,
				base,
				rotation
			)
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
			local label = labelTree(
				model,
				base.Y,
				"DisplayTree",
				string.format(
					"%s · %s · %s ft · $%d",
					speciesName(placement.speciesId),
					placement.sizeId,
					TreeHeight.feetText(tenths),
					price
				),
				"DisplayTree",
				0,
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
	local count = math.min(total, MAX_BUNDLES)
	if count > 0 and LotArtWorld.bundles(model, bay, count, ART_CTX) then
		model:SetAttribute("LotArtMode", "Art")
	elseif count > 0 then
		model:SetAttribute("LotArtMode", "Primitive")
		for k = 0, count - 1 do
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
	end
	model.Parent = bay
end

local function truckStart(plot: Model): CFrame
	return CFrame.new(lotPosition(plot, TRUCK_X, TRUCK_START_DEPTH, VehicleArt.ROAD_TOP))
		* CFrame.Angles(0, VehicleArt.truckYaw(plotFacing(plot)), 0)
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
	local pullInArriving: any = nil
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
				pullInArriving = view.arriving
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
			local start = truckStart(plot)
			local stop = CFrame.new(lotPosition(plot, TRUCK_X, bayDepth(pullInBay), VehicleArt.TRUCK_LANE_TOP))
				* start.Rotation
			local newTruck = VehicleWorld.truck(plot, start, VEHICLE_CTX)
			VehicleWorld.loadCargo(newTruck, pullInArriving, VEHICLE_CTX)
			drive(newTruck, start, stop, receivingConfig.TruckPullInSeconds)
		end
	elseif activeTruck ~= nil then
		local leaving = activeTruck
		leaving:SetAttribute("Leaving", true)
		VehicleWorld.unloadCargo(leaving)
		drive(leaving, leaving:GetPivot(), truckStart(plot), receivingConfig.TruckLeaveSeconds, function()
			leaving:Destroy()
		end)
	end
	return true
end

local function roadEntry(parked: CFrame): CFrame
	return CFrame.new(parked.X, VehicleArt.ROAD_TOP, 0) * parked.Rotation
end

-- The parked pose of a car on parking space `space` (1..4).
local function parkedAt(plot: Model, space: number): CFrame
	local center = (plot.PrimaryPart :: BasePart).Position
	local spot = center + parkingOffset(plot, math.clamp(space, 1, 4))
	return CFrame.new(spot.X, lotTop(plot) + VehicleArt.PARKING_RISE, spot.Z)
		* CFrame.Angles(0, VehicleArt.carYaw(plotFacing(plot)), 0)
end

-- The "#n HERE" billboard and the LoadOrder prompt of an order car; added only when missing,
-- so an adopted visit car (CM2-N1) is decorated once.
local function decorateCar(carModel: Model, orderNumber: number, callbacks)
	local body = carModel.PrimaryPart
	if not body then
		return
	end
	if body:FindFirstChild("Label") == nil then
		local lift = if carModel:GetAttribute("VehicleArtMode") == "Art" then VehicleArt.CAR_LABEL_LIFT else 0
		billboard(
			body,
			"CarNumber",
			"#" .. orderNumber,
			"CarNumber",
			UiTheme.WorldLabels.CarNumber.height + lift,
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

-- The sold tree on a leaving car's roof (CM2-12W): species and size come from the car's
-- TreeSpeciesId / TreeSizeId attributes; art lies along the car's +Z, settled so its lowest part is
-- ROOF_CLEARANCE above the anchor and welded to the car's PrimaryPart (CM2-14WR).
local function settleOnRoof(roof: Model, topY: number)
	local lowest = math.huge
	for _, descendant in roof:GetDescendants() do
		if descendant:IsA("BasePart") then
			local cf, size = descendant.CFrame, descendant.Size
			lowest = math.min(
				lowest,
				VehicleArt.boxBottom(
					cf.Position.Y,
					size.X,
					size.Y,
					size.Z,
					cf.RightVector.Y,
					cf.UpVector.Y,
					cf.LookVector.Y
				)
			)
		end
	end
	if lowest < math.huge then
		roof:PivotTo(CFrame.new(0, VehicleArt.roofLift(lowest, topY), 0) * roof:GetPivot())
	end
end

local function weldToCar(roof: Model, carModel: Model)
	local root = carModel.PrimaryPart
	if root == nil then
		return
	end
	for _, descendant in roof:GetDescendants() do
		if descendant:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Name = "RoofWeld"
			weld.Part0 = root
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end
end

local function attachRoofTree(carModel: Model, artRoot: Instance?)
	local speciesAttr, sizeAttr = carModel:GetAttribute("TreeSpeciesId"), carModel:GetAttribute("TreeSizeId")
	local speciesId = if type(speciesAttr) == "string" then speciesAttr else nil
	local sizeId = if type(sizeAttr) == "string" then sizeAttr else nil
	local roof = buildTree(artRoot, carModel, "RoofTree", "Roof", speciesId, sizeId, Vector3.zero, 0)
	for _, descendant in roof:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
		end
	end
	local top = VehicleWorld.cargoTop(carModel)
	if roof:GetAttribute("TreeArtMode") ~= "Art" then
		roof:PivotTo(top * CFrame.new(0, VehicleArt.ROOF_PRIMITIVE_LIFT, 0) * CFrame.Angles(math.rad(90), 0, 0))
	else
		local _, size = roof:GetBoundingBox()
		roof:PivotTo(top * CFrame.new(0, math.max(size.X, size.Z) / 2, -size.Y / 2) * CFrame.Angles(math.rad(90), 0, 0))
	end
	settleOnRoof(roof, top.Y)
	weldToCar(roof, carModel)
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
	local artRoot = ArtLibrary.root(ReplicatedStorage)
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
					local roofOk, roofErr = pcall(attachRoofTree, child, artRoot)
					if not roofOk then
						warn(string.format("[ART] RoofBuildFailed %s #%d: %s", plotId, orderNumber, tostring(roofErr)))
					end
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
			carModel:SetAttribute("TreeSpeciesId", order.speciesId)
			carModel:SetAttribute("TreeSizeId", order.sizeId)
			decorateCar(carModel, orderNumber, callbacks)
		elseif not carModel then
			local parked = parkedAt(plot, order.parkingSpace)
			local newCar = VehicleWorld.car(folder, carName, roadEntry(parked), orderNumber, VEHICLE_CTX)
			newCar:SetAttribute("OrderNumber", orderNumber)
			newCar:SetAttribute("TreeSpeciesId", order.speciesId)
			newCar:SetAttribute("TreeSizeId", order.sizeId)
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
			local pickupOk, pickupErr = pcall(function()
				local column = math.clamp(order.parkingSpace, 1, 4) - 1
				local base = Vector3.new(
					center.X + 23 + column * 4.5,
					lotTop(plot),
					center.Z + (if center.Z < 0 then 13 else -13)
				)
				local pickupTree =
					buildTree(artRoot, folder, treeName, "Pickup", order.speciesId, order.sizeId, base, 0)
				pickupTree:SetAttribute("OrderNumber", orderNumber)
				setCollisionGroup(pickupTree, GameConfig.Customers.Npc.CollisionGroups.Tree)
				local trunk = pickupTree.PrimaryPart :: BasePart
				local pickupLayout = UiTheme.WorldLabels.PickupOrder
				labelTree(
					pickupTree,
					base.Y,
					"PickupOrder",
					string.format("Order #%d · PICK UP", orderNumber),
					"PickupOrder",
					if column % 2 == 0 then pickupLayout.stagger else 0,
					{ OrderNumber = orderNumber }
				)
				local carryPrompt = prompt(trunk, "CarryOrder", "Pick up customer tree", orderNumber)
				carryPrompt.Triggered:Connect(function(player)
					if callbacks and callbacks.carry then
						callbacks.carry(player, orderNumber, trunk)
					end
				end)
			end)
			if not pickupOk then
				local partial = folder:FindFirstChild(treeName)
				if partial then
					partial:Destroy()
				end
				warn(string.format("[ART] PickupBuildFailed %s #%d: %s", plotId, orderNumber, tostring(pickupErr)))
			end
		end
	end
	return true
end

-- Where cargo rests on a vehicle (CM2-14W): the CargoAnchor, the primitive roof rack top or a fallback.
WorldService.carCargoTop = VehicleWorld.cargoTop

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
function WorldService.attachCarriedTree(character: Model, orderNumber: number, speciesId: string?, sizeId: string?)
	WorldService.detachCarriedTree(character)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local carried = buildTree(
		ArtLibrary.root(ReplicatedStorage),
		character,
		"CarriedTree",
		"Carried",
		speciesId,
		sizeId,
		Vector3.zero,
		0
	)
	carried:SetAttribute("OrderNumber", orderNumber)
	for _, descendant in carried:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.Massless = true
		end
	end
	local pose = root.CFrame * CFrame.new(1.5, 0, -1.2) * CFrame.Angles(0, 0, math.rad(-20))
	if carried:GetAttribute("TreeArtMode") == "Art" then
		pose = pose * CFrame.new(0, -TreeArt.pivotDrop("Carried", sizeId), 0)
	end
	carried:PivotTo(pose)
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

export type LotSignView = {
	nameText: string,
	nameSource: string,
	ownerName: string?,
	ratingTenths: number?,
	reviewCount: number,
	likes: number,
}

local function lotSignBoard(plotId: string): BasePart?
	local plot = findPlot(plotId)
	local sign = plot and plot:FindFirstChild("LotSign")
	local board = sign and sign:FindFirstChild("Board")
	if board and board:IsA("BasePart") then
		return board
	end
	return nil
end

-- Writes a view (or the free-lot text for nil) to both faces of the plot's lot sign
-- (CM2-G15). Attributes are set before Text, so the client re-localizes from fresh values.
-- False when the plot or its sign is missing.
function WorldService.setLotSign(plotId: string, view: LotSignView?): boolean
	local board = lotSignBoard(plotId)
	if not board then
		return false
	end
	for _, faceName in ipairs({ "SignFront", "SignBack" }) do
		local gui = board:FindFirstChild(faceName)
		local frame = gui and gui:FindFirstChild("Frame")
		local nameLabel = frame and frame:FindFirstChild("Name")
		local rating = frame and frame:FindFirstChild("Rating")
		local likes = frame and frame:FindFirstChild("Likes")
		if
			not (nameLabel and nameLabel:IsA("TextLabel"))
			or not (rating and rating:IsA("TextLabel"))
			or not (likes and likes:IsA("TextLabel"))
		then
			return false
		end
		if view == nil then
			nameLabel:SetAttribute("NameSource", "Free")
			nameLabel:SetAttribute("OwnerName", nil)
			nameLabel.Text = "Lot available"
			rating:SetAttribute("Active", false)
			rating:SetAttribute("RatingTenths", nil)
			rating:SetAttribute("ReviewCount", nil)
			rating.Text = ""
			likes:SetAttribute("Active", false)
			likes:SetAttribute("Likes", nil)
			likes.Text = ""
		else
			nameLabel:SetAttribute("NameSource", view.nameSource)
			nameLabel:SetAttribute("OwnerName", view.ownerName)
			nameLabel.Text = view.nameText
			rating:SetAttribute("Active", true)
			rating:SetAttribute("RatingTenths", view.ratingTenths)
			rating:SetAttribute("ReviewCount", view.reviewCount)
			rating.Text = if view.reviewCount == 0 or view.ratingTenths == nil
				then "No reviews yet"
				else string.format("★ %.1f", (view.ratingTenths :: number) / 10)
			likes:SetAttribute("Active", true)
			likes:SetAttribute("Likes", view.likes)
			likes.Text = string.format("Likes: %d", view.likes)
		end
	end
	local likePrompt = board:FindFirstChild("LikePrompt")
	if likePrompt and likePrompt:IsA("ProximityPrompt") then
		likePrompt.Enabled = view ~= nil
	end
	-- CM2-GATEW: the gate's name board mirrors the sign's front name.
	local plot = findPlot(plotId)
	local gate = plot and LotGateWorld.nameLabel(plot)
	local front = board:FindFirstChild("SignFront")
	local source = front and front:FindFirstChild("Frame")
	local sourceName = source and source:FindFirstChild("Name")
	if gate and sourceName then
		gate:SetAttribute("NameSource", sourceName:GetAttribute("NameSource"))
		gate:SetAttribute("OwnerName", sourceName:GetAttribute("OwnerName"))
		gate.Text = (sourceName :: TextLabel).Text
	end
	return true
end

-- CM2-PP: the lot sign's public name text (the broadcast-filtered save name or "<user>'s Tree
-- Lot") for the plot picker; nil while the sign shows "Lot available" or is missing.
function WorldService.lotSignName(plotId: string): string?
	local board = lotSignBoard(plotId)
	local gui = board and board:FindFirstChild("SignFront")
	local frame = gui and gui:FindFirstChild("Frame")
	local nameLabel = frame and frame:FindFirstChild("Name")
	if not (nameLabel and nameLabel:IsA("TextLabel")) then
		return nil
	end
	local source = nameLabel:GetAttribute("NameSource")
	if source == nil or source == "Free" or nameLabel.Text == "" then
		return nil
	end
	return nameLabel.Text
end

-- The part a player must stand near to like the lot (server reach check, CM2-G15).
function WorldService.lotSignTarget(plotId: string): BasePart?
	return lotSignBoard(plotId)
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
	local visitCar = VehicleWorld.car(ordersFolder(plot), "VisitCar_" .. seq, roadEntry(parked), seq, VEHICLE_CTX)
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

-- The tree a walking customer carries: welded to the root, massless and non-colliding.
function WorldService.attachNpcTree(model: Model, sizeId: string?, speciesId: string?)
	WorldService.detachNpcTree(model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local carried = buildTree(
		ArtLibrary.root(ReplicatedStorage),
		model,
		"NpcCarriedTree",
		"NpcCarried",
		speciesId,
		sizeId,
		Vector3.zero,
		0
	)
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
	local pose = root.CFrame * CFrame.new(0, 0.2, -1.4) * CFrame.Angles(0, 0, math.rad(-15))
	if carried:GetAttribute("TreeArtMode") == "Art" then
		pose = pose * CFrame.new(0, -TreeArt.pivotDrop("NpcCarried", sizeId), 0)
	end
	carried:PivotTo(pose)
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
