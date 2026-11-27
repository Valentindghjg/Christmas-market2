--!strict
-- The entrance gate at each lot's road edge (CM2-GATEW, docs/archive/plans/CM2-GATEW.md): the LotGate art
-- (Part fallback without it), two night lights and a name board that mirrors the lot sign. `ctx`
-- comes from WorldService.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArtLibrary = require(Shared:WaitForChild("ArtLibrary"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local LotArt = require(Shared:WaitForChild("LotArt"))
local UiTheme = require(Shared:WaitForChild("UiTheme"))
local LotArtWorld = require(script.Parent:WaitForChild("LotArtWorld"))
local MapWorld = require(script.Parent:WaitForChild("MapWorld"))

local LotGateWorld = {}

local SIGN_SIZE = Vector3.new(9.0, 2.2, 0.1)

-- The Part fallback: two posts, a beam, a name board and the attachments the art also has.
local function buildFallback(pose: CFrame): Model
	local model = Instance.new("Model")
	local function part(name: string, size: Vector3, localCentre: Vector3, key: string, canCollide: boolean)
		local instance = Instance.new("Part")
		instance.Name = name
		instance.Size = size
		instance.Anchored = true
		instance.CanCollide = canCollide
		instance.Material = Enum.Material.SmoothPlastic
		instance.Color = MapWorld.paletteColor(key)
		instance.CFrame = pose * CFrame.new(localCentre)
		instance.Parent = model
		return instance
	end
	part("PostL", Vector3.new(1.5, 15.2, 1.5), Vector3.new(-8.9, 7.6, 0), "WoodWarmShade", true)
	part("PostR", Vector3.new(1.5, 15.2, 1.5), Vector3.new(8.9, 7.6, 0), "WoodWarmShade", true)
	local beam = part("Beam", Vector3.new(19.0, 0.8, 1.1), Vector3.new(0, 13.0, 0), "WoodWarm", true)
	local board = part("Board", Vector3.new(9.0, 2.2, 0.3), Vector3.new(0, 14.65, 0), "FabricCream", false)
	for _, spec in { { "Light1", 4.1 }, { "Light2", -4.1 } } do
		local attachment = Instance.new("Attachment")
		attachment.Name = spec[1] :: string
		attachment.Position = Vector3.new(spec[2] :: number, -0.1, -0.9)
		attachment.Parent = beam
	end
	local face = Instance.new("Attachment")
	face.Name = "SignFace"
	face.Position = Vector3.new(0, 0, -0.16)
	face.Parent = board
	model.WorldPivot = pose
	return model
end

-- The transparent SignBoard at the SignFace attachment with the SurfaceGui name label.
local function buildSign(model: Model, face: Attachment)
	local tokens = UiTheme.LotGate
	local board = Instance.new("Part")
	board.Name = "SignBoard"
	board.Size = SIGN_SIZE
	board.CFrame = face.WorldCFrame
	board.Transparency = 1
	board.Anchored = true
	board.CanCollide = false
	board.CanQuery = false
	board.CanTouch = false
	board.Parent = model
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignFront"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = tokens.pixelsPerStud
	gui.LightInfluence = 0
	gui.MaxDistance = tokens.maxDistance
	gui.Adornee = board
	gui.Parent = board
	local frame = Instance.new("Frame")
	frame.Name = "Frame"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local padding = tokens.padding
	local label = Instance.new("TextLabel")
	label.Name = "Name"
	label.Position = UDim2.fromOffset(padding, padding)
	label.Size = UDim2.new(1, -2 * padding, 1, -2 * padding)
	label.BackgroundTransparency = 1
	label.FontFace = UiTheme.fontFace("Title")
	label.TextColor3 = Color3.fromRGB(table.unpack(UiTheme.Colors.DarkText))
	label.TextScaled = true
	label.TextWrapped = false
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.AutoLocalize = false
	label:SetAttribute("LabelKind", "LotSignName")
	label:SetAttribute("NameSource", "Free")
	label.Text = "Lot available"
	label.Parent = frame
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = tokens.nameMaxTextSize
	constraint.MinTextSize = tokens.nameMinTextSize
	constraint.Parent = label
end

function LotGateWorld.build(plot: Model, ctx: LotArtWorld.Ctx): Model
	local x, z = LotArt.gatePose()
	local pose = CFrame.new(ctx.lotPosition(plot, x, z, ctx.lotTop(plot) - LotArt.FENCE_BASE_DROP))
		* CFrame.Angles(0, LotArt.roadYaw(ctx.facing(plot)), 0)
	local choice = LotArt.choose(ArtLibrary.root(ReplicatedStorage), ArtLibrary.find, LotArt.PATHS.Gate)
	local model: Model
	if choice.mode == "Art" then
		model = ArtLibrary.prepareClone(choice.template)
		model:PivotTo(pose)
		model:SetAttribute("LotArtMode", "Art")
	else
		ctx.reportMissing(LotArt.PATHS.Gate, choice.code or "MissingArtAsset")
		model = buildFallback(pose)
		model:SetAttribute("LotArtMode", "Primitive")
	end
	model.Name = "LotGate"
	for _, name in { "Light1", "Light2" } do
		local attachment = model:FindFirstChild(name, true)
		if attachment and attachment:IsA("Attachment") then
			MapWorld.nightLight(attachment, GameConfig.DayCycle.GateLight)
		end
	end
	local face = model:FindFirstChild("SignFace", true)
	if face and face:IsA("Attachment") then
		buildSign(model, face)
	end
	ctx.setCollisionGroup(model, ctx.group)
	model.Parent = plot
	return model
end

-- The gate's name label (the lot sign mirrors its text here), nil when a link is missing.
function LotGateWorld.nameLabel(plot: Model): TextLabel?
	local gate = plot:FindFirstChild("LotGate")
	local board = gate and gate:FindFirstChild("SignBoard")
	local gui = board and board:FindFirstChild("SignFront")
	local frame = gui and gui:FindFirstChild("Frame")
	local label = frame and frame:FindFirstChild("Name")
	if label and label:IsA("TextLabel") then
		return label
	end
	return nil
end

return LotGateWorld
