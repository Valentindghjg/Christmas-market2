--!strict
-- Customer avatars (CM2-N1). Roblox only: never required by headless tests.
--
-- One template comes from the default Roblox R15 body (HumanoidDescription.new(), no catalog
-- asset IDs, no asset loads per NPC). Each customer is a clone coloured from the own palette
-- (GameConfig.Customers.Npc.Look) with a beanie, an optional pompom and a scarf built from
-- our own Parts. Staff (CM2-25/26) reuse build(look) with a uniform look.
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local Npc = GameConfig.Customers.Npc
local Groups = Npc.CollisionGroups

local NpcAvatar = {}

-- Parts and instances the template drops: scripts and the default clothing and colours.
local STRIPPED_CLASSES = { "BodyColors", "Shirt", "Pants", "ShirtGraphic" }

local COAT_PARTS = {
	"UpperTorso",
	"LowerTorso",
	"LeftUpperArm",
	"LeftLowerArm",
	"RightUpperArm",
	"RightLowerArm",
}
local HAND_PARTS = { "LeftHand", "RightHand" }
local LEG_PARTS = { "LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg" }
local FOOT_PARTS = { "LeftFoot", "RightFoot" }

local DISABLED_STATES = {
	Enum.HumanoidStateType.Dead,
	Enum.HumanoidStateType.FallingDown,
	Enum.HumanoidStateType.Ragdoll,
	Enum.HumanoidStateType.Climbing,
	Enum.HumanoidStateType.Swimming,
	Enum.HumanoidStateType.Seated,
}

local template: Model? = nil
local templateTried = false
local animationWarned = false

local function rgb(value: { number }): Color3
	return Color3.fromRGB(value[1], value[2], value[3])
end

-- Idempotent: registers the four groups and makes CustomerNpc pass through itself, lot
-- trees, player characters and the lot structures (stand, counter, bays; Fix round 1).
function NpcAvatar.registerCollisionGroups()
	for _, name in ipairs({ Groups.Npc, Groups.Tree, Groups.Player, Groups.Structure }) do
		if not PhysicsService:IsCollisionGroupRegistered(name) then
			PhysicsService:RegisterCollisionGroup(name)
		end
	end
	PhysicsService:CollisionGroupSetCollidable(Groups.Npc, Groups.Npc, false)
	PhysicsService:CollisionGroupSetCollidable(Groups.Npc, Groups.Tree, false)
	PhysicsService:CollisionGroupSetCollidable(Groups.Npc, Groups.Player, false)
	PhysicsService:CollisionGroupSetCollidable(Groups.Npc, Groups.Structure, false)
end

-- The default R15 body, built once (lazily, in pcall).
local function getTemplate(): Model?
	if templateTried then
		return template
	end
	templateTried = true
	local ok, result = pcall(function()
		-- Instance.new("HumanoidDescription") equals HumanoidDescription.new() (selene's std
		-- does not know the latter): the default body, no catalog asset IDs.
		local description = Instance.new("HumanoidDescription")
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or typeof(result) ~= "Instance" or not result:IsA("Model") then
		warn("[ChristmasMarket2] NpcTemplateFailed: " .. tostring(result))
		return nil
	end
	local model = result :: Model
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") or table.find(STRIPPED_CLASSES, descendant.ClassName) ~= nil then
			descendant:Destroy()
		end
	end
	model.Name = "CustomerTemplate"
	template = model
	return model
end

local function paint(model: Model, names: { string }, color: Color3)
	for _, name in ipairs(names) do
		local bodyPart = model:FindFirstChild(name)
		if bodyPart and bodyPart:IsA("BasePart") then
			bodyPart.Color = color
		end
	end
end

-- An own, welded, massless, non-colliding cloth part.
local function cloth(parent: BasePart, name: string, size: Vector3, cframe: CFrame, color: Color3, shape): Part
	local value = Instance.new("Part")
	value.Name = name
	value.Shape = shape or Enum.PartType.Block
	value.Size = size
	value.CFrame = cframe
	value.Color = color
	value.Material = Enum.Material.Fabric
	value.Anchored = false
	value.Massless = true
	value.CanCollide = false
	value.CanQuery = false
	value.CanTouch = false
	value.TopSurface = Enum.SurfaceType.Smooth
	value.BottomSurface = Enum.SurfaceType.Smooth
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = parent
	weld.Part1 = value
	weld.Parent = value
	value.Parent = parent.Parent
	return value
end

-- A coloured customer clone; nil when the template is unavailable.
function NpcAvatar.build(look): Model?
	local source = getTemplate()
	if source == nil then
		return nil
	end
	local model = source:Clone()
	model.Name = "Customer"
	local head = model:FindFirstChild("Head")
	local torso = model:FindFirstChild("UpperTorso")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not (head and head:IsA("BasePart") and torso and torso:IsA("BasePart") and humanoid) then
		model:Destroy()
		return nil
	end
	paint(model, { "Head" }, rgb(look.skin))
	paint(model, COAT_PARTS, rgb(look.coat))
	paint(model, HAND_PARTS, rgb(look.scarf))
	paint(model, LEG_PARTS, rgb(look.pants))
	paint(model, FOOT_PARTS, rgb(look.boots))

	-- Beanie (with an optional pompom) and scarf: own Parts.
	local headSize = head.Size
	local beanieHeight = headSize.Y * 0.45
	local beanieCFrame = head.CFrame * CFrame.new(0, headSize.Y * 0.38, 0)
	cloth(
		head,
		"Beanie",
		Vector3.new(headSize.X * 1.08, beanieHeight, headSize.Z * 1.08),
		beanieCFrame,
		rgb(look.beanie)
	)
	if look.pompom then
		cloth(
			head,
			"Pompom",
			Vector3.new(0.45, 0.45, 0.45),
			beanieCFrame * CFrame.new(0, beanieHeight / 2, 0),
			rgb(look.beanie),
			Enum.PartType.Ball
		)
	end
	local torsoSize = torso.Size
	cloth(
		torso,
		"Scarf",
		Vector3.new(torsoSize.X * 0.75, 0.35, torsoSize.Z * 1.15),
		torso.CFrame * CFrame.new(0, torsoSize.Y * 0.42, 0),
		rgb(look.scarf)
	)
	cloth(
		torso,
		"ScarfTail",
		Vector3.new(0.35, 0.9, 0.12),
		torso.CFrame * CFrame.new(torsoSize.X * 0.2, torsoSize.Y * 0.15, -torsoSize.Z * 0.58),
		rgb(look.scarf)
	)
	-- Staff (CM2-25/26): a welded apron over the uniform coat.
	if look.apron then
		cloth(
			torso,
			"Apron",
			Vector3.new(torsoSize.X * 0.8, torsoSize.Y * 0.9, 0.12),
			torso.CFrame * CFrame.new(0, -torsoSize.Y * 0.05, -torsoSize.Z * 0.55),
			rgb(look.apron)
		)
	end

	pcall(function()
		model:ScaleTo(look.scale)
	end)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CollisionGroup = Groups.Npc
		end
	end
	humanoid.WalkSpeed = Npc.WalkSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	for _, state in ipairs(DISABLED_STATES) do
		humanoid:SetStateEnabled(state, false)
	end
	if humanoid:FindFirstChildOfClass("Animator") == nil then
		Instance.new("Animator").Parent = humanoid
	end
	return model
end

function NpcAvatar.moveTo(model: Model, worldPosition: Vector3)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:MoveTo(worldPosition)
	end
end

-- Puts the avatar on the ground at worldPosition (Y = ground height), keeping its rotation.
function NpcAvatar.snapTo(model: Model, worldPosition: Vector3)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root and root:IsA("BasePart")) then
		return
	end
	local height = worldPosition.Y + humanoid.HipHeight + root.Size.Y / 2
	model:PivotTo(CFrame.new(worldPosition.X, height, worldPosition.Z) * model:GetPivot().Rotation)
end

-- Roblox's first-party default R15 walk and idle, played on the server. Walk plays while
-- Humanoid.Running reports speed > 0.5. Without animations the NPC glides.
function NpcAvatar.startAnimations(model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not (humanoid and animator) then
		return
	end
	local ok, tracks = pcall(function()
		local walk = Instance.new("Animation")
		walk.AnimationId = Npc.Animations.Walk
		local idle = Instance.new("Animation")
		idle.AnimationId = Npc.Animations.Idle
		local walkTrack = animator:LoadAnimation(walk)
		local idleTrack = animator:LoadAnimation(idle)
		walkTrack.Looped = true
		idleTrack.Looped = true
		return { walk = walkTrack, idle = idleTrack }
	end)
	if not ok or type(tracks) ~= "table" then
		if not animationWarned then
			animationWarned = true
			warn("[ChristmasMarket2] NpcAnimationFailed: " .. tostring(tracks))
		end
		return
	end
	local walking: boolean? = nil
	local function show(isWalking: boolean)
		if walking == isWalking then
			return
		end
		walking = isWalking
		if isWalking then
			tracks.idle:Stop(0.2)
			tracks.walk:Play(0.2)
		else
			tracks.walk:Stop(0.2)
			tracks.idle:Play(0.2)
		end
	end
	show(false)
	humanoid.Running:Connect(function(speed: number)
		show(speed > 0.5)
	end)
end

return NpcAvatar
