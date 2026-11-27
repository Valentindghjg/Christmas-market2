--!strict
-- Builds ChristmasMarketWorld.Map (CM2-10W): ground, stream, roads, square, walls and the
-- placed art pieces of MapLayout, with Part fallbacks until the Blender models are imported.
-- Never requires WorldService (the part and tree helpers come in through the kit).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArtLibrary = require(Shared:WaitForChild("ArtLibrary"))
local ArtPalette = require(Shared:WaitForChild("ArtPalette"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Localization = require(Shared:WaitForChild("Localization"))
local MapLayout = require(Shared:WaitForChild("MapLayout"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))

local MapWorld = {}

export type MapKit = {
	part: (Instance, string, Vector3, Vector3, Color3, Enum.Material) -> Part,
	tree: (Instance, string, Vector3, number) -> Model,
	reportMissing: (string, string) -> (),
}

local GROUPS = { "Landmarks", "Square", "Street", "Forest", "Rocks", "Mountains" }
local NO_SHADOW_GROUPS = { Forest = true, Rocks = true, Mountains = true, Reserve = true }
local ROWS = 4

-- Reserve rows per plot, kept so the rows can leave the world and come back.
local reserves: { [string]: { folder: Folder, rows: { Model } } } = {}

local function paletteColor(key: string): Color3
	return Color3.fromRGB(table.unpack(ArtPalette[key].rgb))
end
-- Shared with WorldService (CM2-G12a), which stays under its 1500-line cap.
MapWorld.paletteColor = paletteColor

-- A night light (CM2-G12a): a warm PointLight named NightLight tagged NightLight, off on the
-- server; the client (DayNight.client.lua) switches every tagged light at night. Shared with
-- WorldService for the plot lights.
function MapWorld.nightLight(parent: Instance, spec: { range: number, brightness: number }): PointLight
	local light = Instance.new("PointLight")
	light.Name = "NightLight"
	light.Range = spec.range
	light.Brightness = spec.brightness
	light.Color = paletteColor("LightWarm")
	light.Shadows = false
	light.Enabled = false
	light.Parent = parent
	CollectionService:AddTag(light, GameConfig.DayCycle.NightLightTag)
	return light
end

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function folder(parent: Instance, name: string): Folder
	local instance = Instance.new("Folder")
	instance.Name = name
	instance.Parent = parent
	return instance
end

-- Text on a part's front face (CM2-10W): a SurfaceGui whose label comes from a string key.
local function surfaceText(target: BasePart, guiName: string, textKey: string, color: Color3)
	local sign = UiTheme.MapSign
	local gui = Instance.new("SurfaceGui")
	gui.Name = guiName
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = sign.pixelsPerStud
	gui.MaxDistance = sign.maxDistance
	gui.LightInfluence = 0
	gui.Adornee = target
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.FontFace = UiTheme.fontFace("Title")
	label.TextColor3 = color
	label.TextScaled = true
	label.Text = Localization.get("en", textKey)
	label:SetAttribute("TextKey", textKey)
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = sign.maxTextSize
	constraint.MinTextSize = sign.minTextSize
	constraint.Parent = label
	label.Parent = gui
	gui.Parent = target
end

local function flatPart(kit: MapKit, model: Model, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local instance = kit.part(model, name, size, cframe.Position, color, Enum.Material.SmoothPlastic)
	instance.CFrame = cframe
	instance.CanCollide = false
	instance.CanQuery = false
	instance.CanTouch = false
	instance.CastShadow = false
	return instance
end

-- Fallback Parts ----------------------------------------------------------------------------

local function offsetPart(
	kit: MapKit,
	model: Model,
	name: string,
	size: Vector3,
	pivot: CFrame,
	offset: Vector3,
	colorKey: string,
	material: Enum.Material
): Part
	local cframe = pivot * CFrame.new(offset)
	local instance = kit.part(model, name, size, cframe.Position, paletteColor(colorKey), material)
	instance.CFrame = cframe
	return instance
end

local function harden(model: Instance)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and string.sub(descendant.Name, 1, 7) == "Needles" then
			descendant.CanCollide = false
		end
	end
end

local function treeAt(kit: MapKit, parent: Instance, name: string, pivot: CFrame, offset: Vector3, scale: number)
	local position = (pivot * CFrame.new(offset)).Position
	return kit.tree(parent, name, position, scale)
end

local function newModel(parent: Instance, piece: MapLayout.Piece): Model
	local model = Instance.new("Model")
	model.Name = piece.id
	model:SetAttribute("MapFallback", true)
	model.Parent = parent
	return model
end

local FALLBACKS: { [string]: (MapKit, Instance, MapLayout.Piece, CFrame) -> Model } = {
	Fir = function(kit, parent, piece, pivot)
		local model = treeAt(kit, parent, piece.id, pivot, Vector3.zero, 1.2 * piece.scale)
		model:SetAttribute("MapFallback", true)
		harden(model)
		return model
	end,
	ClusterA = function(kit, parent, piece, pivot)
		local model = newModel(parent, piece)
		local scale = piece.scale
		for index, offset in { Vector3.new(-5.5, 0, -4), Vector3.new(5.5, 0, -4), Vector3.new(0, 0, 5) } do
			treeAt(kit, model, "Fir_" .. index, pivot, offset * scale, 1.5 * scale)
		end
		harden(model)
		return model
	end,
	ClusterB = function(kit, parent, piece, pivot)
		local model = newModel(parent, piece)
		local scale = piece.scale
		for index, offset in { Vector3.new(-2.9, 0, -1.5), Vector3.new(2.9, 0, 1.5) } do
			treeAt(kit, model, "Fir_" .. index, pivot, offset * scale, 1.2 * scale)
		end
		harden(model)
		return model
	end,
	VillageTree = function(kit, parent, piece, pivot)
		local model = treeAt(kit, parent, piece.id, pivot, Vector3.zero, 3.8)
		model:SetAttribute("MapFallback", true)
		harden(model)
		return model
	end,
	BridgeDeck = function(kit, parent, piece, pivot)
		local model = newModel(parent, piece)
		local deck = offsetPart(
			kit,
			model,
			"Deck",
			Vector3.new(34, 0.6, 56),
			pivot,
			Vector3.new(0, 0.05, 0),
			"WoodWarm",
			Enum.Material.WoodPlanks
		)
		model.PrimaryPart = deck
		return model
	end,
	Board = function(kit, parent, piece, pivot)
		local model = newModel(parent, piece)
		local body = offsetPart(
			kit,
			model,
			"Body",
			Vector3.new(13.6, 16.2, 0.5),
			pivot,
			Vector3.new(0, 8.1, 0),
			"WoodWarm",
			Enum.Material.WoodPlanks
		)
		local cap = offsetPart(
			kit,
			model,
			"Cap",
			Vector3.new(14, 0.4, 1),
			pivot,
			Vector3.new(0, 16.4, 0),
			"SnowWhite",
			Enum.Material.Snow
		)
		cap.CanCollide = false
		model.PrimaryPart = body
		return model
	end,
	Sign = function(kit, parent, piece, pivot)
		local model = newModel(parent, piece)
		for name, x in { Post_L = -3.5, Post_R = 3.5 } do
			offsetPart(
				kit,
				model,
				name,
				Vector3.new(0.6, 6.6, 0.6),
				pivot,
				Vector3.new(x, 3.3, 0),
				"WoodWarmShade",
				Enum.Material.WoodPlanks
			)
		end
		local board = offsetPart(
			kit,
			model,
			"Board",
			Vector3.new(8, 3.6, 0.4),
			pivot,
			Vector3.new(0, 4.6, 0),
			"WoodWarm",
			Enum.Material.WoodPlanks
		)
		local cap = offsetPart(
			kit,
			model,
			"Cap",
			Vector3.new(8.6, 0.35, 1),
			pivot,
			Vector3.new(0, 6.575, 0),
			"SnowWhite",
			Enum.Material.Snow
		)
		cap.CanCollide = false
		model.PrimaryPart = board
		return model
	end,
	-- Street lamp (CM2-G12a): the Lantern carries the night light until the art is imported.
	Lamp = function(kit, parent, piece, pivot)
		local model = newModel(parent, piece)
		local post = offsetPart(
			kit,
			model,
			"Post",
			Vector3.new(0.5, 7.6, 0.5),
			pivot,
			Vector3.new(0, 3.8, 0),
			"MetalDark",
			Enum.Material.SmoothPlastic
		)
		local lantern = offsetPart(
			kit,
			model,
			"Lantern",
			Vector3.new(1, 1, 1),
			pivot,
			Vector3.new(0, 8.15, 0),
			"LightWarm",
			Enum.Material.Neon
		)
		lantern.CanCollide = false
		local cap = offsetPart(
			kit,
			model,
			"Cap",
			Vector3.new(1.3, 0.25, 1.3),
			pivot,
			Vector3.new(0, 8.775, 0),
			"MetalDark",
			Enum.Material.SmoothPlastic
		)
		cap.CanCollide = false
		model.PrimaryPart = post
		return model
	end,
}

-- Night light of a street lamp (CM2-G12a): under the art's `Light` attachment, else the
-- fallback's Lantern, else the PrimaryPart. Off on the server; the client switches it at night.
local function addLampLight(model: Model)
	local parent: Instance? = nil
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("Attachment") and descendant.Name == "Light" then
			parent = descendant
			break
		end
	end
	if parent == nil then
		local lantern = model:FindFirstChild("Lantern")
		parent = if lantern and lantern:IsA("BasePart") then lantern else model.PrimaryPart
	end
	if parent ~= nil then
		MapWorld.nightLight(parent, GameConfig.DayCycle.LampLight)
	end
end

-- Boards and signs (both modes) -------------------------------------------------------------

local function addBoardParts(kit: MapKit, model: Model, piece: MapLayout.Piece, pivot: CFrame)
	-- Art boards carry their own Screen mesh; rename it so Board_<Key>.Screen is the unique screen Part (CM2-G12b A1).
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and (child.Name == "Screen" or child.Name == "Title") then
			child.Name = child.Name .. "Panel"
		end
	end
	model:SetAttribute("LeaderboardKey", piece.boardKey)
	local screen = flatPart(
		kit,
		model,
		"Screen",
		Vector3.new(11, 10, 0.1),
		pivot * CFrame.new(0, 8.2, -0.3),
		rgb(UiTheme.Colors.Panel)
	)
	screen:SetAttribute("LeaderboardScreen", piece.boardKey)
	local title = flatPart(
		kit,
		model,
		"Title",
		Vector3.new(10, 1.4, 0.1),
		pivot * CFrame.new(0, 15.3, -0.45),
		paletteColor("WoodWarmShade")
	)
	surfaceText(title, "TitleGui", piece.textKey :: string, rgb(UiTheme.Colors.Gold))
end

local function addSignText(kit: MapKit, model: Model, piece: MapLayout.Piece, pivot: CFrame)
	local text = flatPart(
		kit,
		model,
		"SignText",
		Vector3.new(7.4, 3, 0.05),
		pivot * CFrame.new(0, 4.6, -0.225),
		Color3.new(1, 1, 1)
	)
	text.Transparency = 1
	surfaceText(text, "SignGui", piece.textKey :: string, rgb(UiTheme.Colors.Cream))
end

-- Surfaces and walls ------------------------------------------------------------------------

local function buildSurfaces(kit: MapKit, parent: Instance)
	for _, surface in MapLayout.surfaces() do
		local size = Vector3.new(surface.sx, surface.sy, surface.sz)
		local position = Vector3.new(surface.x, surface.y, surface.z)
		local instance: BasePart
		if surface.kind == "Wedge" then
			local wedge = Instance.new("WedgePart")
			wedge.Name = surface.id
			wedge.Anchored = true
			wedge.CanCollide = true
			wedge.Size = size
			wedge.CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(surface.yaw), 0)
			wedge.Color = rgb(surface.color)
			wedge.Material = Enum.Material[surface.material]
			wedge.TopSurface = Enum.SurfaceType.Smooth
			wedge.BottomSurface = Enum.SurfaceType.Smooth
			wedge.Parent = parent
			instance = wedge
		else
			instance = kit.part(parent, surface.id, size, position, rgb(surface.color), Enum.Material[surface.material])
		end
		instance.CastShadow = false
	end
end

local function buildWalls(kit: MapKit, parent: Instance)
	for _, wall in MapLayout.walls() do
		local instance = kit.part(
			parent,
			wall.id,
			Vector3.new(wall.sx, wall.sy, wall.sz),
			Vector3.new(wall.x, wall.y, wall.z),
			Color3.new(1, 1, 1),
			Enum.Material.SmoothPlastic
		)
		instance.Transparency = 1
		instance.CanCollide = true
		instance.CanQuery = false
		instance.CanTouch = false
		instance.CastShadow = false
	end
end

-- Pieces ------------------------------------------------------------------------------------

local function placePiece(kit: MapKit, placement: MapLayout.Placement, parent: Instance)
	local piece = placement.piece
	local pivot = CFrame.new(piece.x, piece.y, piece.z) * CFrame.Angles(0, math.rad(piece.yaw), 0)
	local model: Model
	if placement.mode == "Art" then
		model = ArtLibrary.prepareClone(placement.template :: Model)
		model.Name = piece.id
		if piece.scale ~= 1 then
			model:ScaleTo(piece.scale)
		end
		model:PivotTo(pivot)
		model.Parent = parent
		if piece.paint then
			local paint = model:FindFirstChild("Paint", true)
			if paint and paint:IsA("BasePart") then
				paint.Color = rgb(piece.paint)
			end
		end
	else
		local fallback = MapLayout.ART[piece.artPath].fallback :: string
		model = FALLBACKS[fallback](kit, parent, piece, pivot)
	end
	model:SetAttribute("MapPiece", piece.id)
	if piece.artPath == "Props/LampPost" then
		addLampLight(model)
	end
	if piece.boardKey then
		addBoardParts(kit, model, piece, pivot)
	elseif piece.textKey then
		addSignText(kit, model, piece, pivot)
	end
	if NO_SHADOW_GROUPS[piece.group] then
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.CastShadow = false
			end
		end
	end
end

function MapWorld.build(world: Instance, kit: MapKit): Folder
	reserves = {}
	local map = Instance.new("Folder")
	map.Name = "Map"
	buildSurfaces(kit, folder(map, "Surfaces"))
	buildWalls(kit, folder(map, "Walls"))
	local groups: { [string]: Instance } = {}
	for _, name in GROUPS do
		groups[name] = folder(map, name)
	end
	local reserveFolder = folder(map, "Reserve")
	for index = 1, #MapLayout.PLOTS do
		local plotId = string.format("Plot_%02d", index)
		local plotFolder = folder(reserveFolder, plotId)
		plotFolder:SetAttribute("HiddenRows", 0)
		local rows: { Model } = {}
		for row = 1, ROWS do
			local model = Instance.new("Model")
			model.Name = "Row_" .. row
			model.Parent = plotFolder
			rows[row] = model
		end
		reserves[plotId] = { folder = plotFolder, rows = rows }
	end

	local placements, missing = MapLayout.plan(ArtLibrary.root(ReplicatedStorage), ArtLibrary.find)
	for _, entry in missing do
		kit.reportMissing(entry.path, entry.code)
	end
	for _, placement in placements do
		if placement.mode ~= "Skip" then
			local piece = placement.piece
			local parent: Instance
			if piece.group == "Reserve" then
				parent = reserves[string.format("Plot_%02d", piece.plot :: number)].rows[piece.row :: number]
			else
				parent = groups[piece.group]
			end
			placePiece(kit, placement, parent)
		end
	end
	map.Parent = world
	return map
end

-- Hides the reserve rows the lot now reaches and restores the others (hide levels in MapLayout).
function MapWorld.applyReserve(plotId: string, level: number): boolean
	local entry = reserves[plotId]
	if entry == nil then
		return false
	end
	local hidden = MapLayout.hiddenRowCount(level)
	for row, model in entry.rows do
		model.Parent = if row <= hidden then nil else entry.folder
	end
	entry.folder:SetAttribute("HiddenRows", hidden)
	return true
end

return MapWorld
