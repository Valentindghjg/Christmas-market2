--!strict
-- The Roblox world adapter of the staff (CM2-25/26): maps staff IDs to a uniformed avatar
-- (NpcAvatar) in the plot's Staff folder and builds the Part-made break area. StaffNpcService
-- calls it through `deps.world`; every point is in the lot frame and converted with NpcPath,
-- so the mirrored plots 4-6 are correct by construction. Unknown staff IDs are a no-op.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArtPalette = require(Shared:WaitForChild("ArtPalette"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local NpcLook = require(Shared:WaitForChild("NpcLook"))
local NpcPath = require(Shared:WaitForChild("NpcPath"))
local Staff = require(Shared:WaitForChild("Staff"))
local NpcAvatar = require(script.Parent:WaitForChild("NpcAvatar"))
local WorldService = require(script.Parent:WaitForChild("WorldService"))

local STRUCTURE_GROUP = GameConfig.Customers.Npc.CollisionGroups.Structure

local StaffNpcWorld = {}
StaffNpcWorld.__index = StaffNpcWorld

type Point = NpcPath.Point

function StaffNpcWorld.new()
	local self = setmetatable({}, StaffNpcWorld)
	-- staffId -> plot ID and the avatar, while it exists.
	self._plots = {} :: { [string]: string }
	self._avatars = {} :: { [string]: Model }
	return self
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

local function centerPoint(plotId: string): (Vector3?, Point?)
	local center = WorldService.plotCenter(plotId)
	if center == nil then
		return nil, nil
	end
	return center, { x = center.X, z = center.Z }
end

local function staffFolder(plotId: string): Folder?
	local plot = findPlot(plotId)
	if plot == nil then
		return nil
	end
	local folder = plot:FindFirstChild("Staff")
	if folder == nil then
		folder = Instance.new("Folder")
		folder.Name = "Staff"
		folder.Parent = plot
	end
	return folder :: Folder
end

-- A lot-frame point of the staff member's plot at ground height, or nil.
function StaffNpcWorld:_world(staffId: string, p: Point): Vector3?
	local plotId = self._plots[staffId]
	if plotId == nil then
		return nil
	end
	local center, c = centerPoint(plotId)
	if center == nil or c == nil then
		return nil
	end
	local w = NpcPath.toWorld(c, p)
	return Vector3.new(w.x, center.Y, w.z)
end

function StaffNpcWorld:_avatar(staffId: string): Model?
	local model = self._avatars[staffId]
	if model and model.Parent then
		return model
	end
	return nil
end

local function rootOf(model: Model?): BasePart?
	local root = model and model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- `Staff_<role>` (load tests: `StaffLoad_<seq>`) at `at`, facing `faceTo`.
function StaffNpcWorld:spawnAvatar(plotId: string, staffId: string, role: string, at: Point, faceTo: Point): boolean
	self._plots[staffId] = plotId
	local center, c = centerPoint(plotId)
	local folder = staffFolder(plotId)
	if center == nil or c == nil or folder == nil then
		self._plots[staffId] = nil
		return false
	end
	local model = NpcAvatar.build(NpcLook.forStaff(role))
	if model == nil then
		self._plots[staffId] = nil
		return false
	end
	local seq = string.match(staffId, "^staffload:(%d+)$")
	model.Name = if seq then "StaffLoad_" .. seq else "Staff_" .. role
	model:SetAttribute("StaffId", staffId)
	model:SetAttribute("StaffRole", role)
	model:SetAttribute("StaffState", "")
	local w = NpcPath.toWorld(c, at)
	local position = Vector3.new(w.x, center.Y, w.z)
	local f = NpcPath.toWorld(c, faceTo)
	local look = Vector3.new(f.x, center.Y, f.z)
	if (look - position).Magnitude > 0.1 then
		model:PivotTo(CFrame.lookAt(position, look))
	else
		model:PivotTo(CFrame.new(position))
	end
	NpcAvatar.snapTo(model, position)
	model.Parent = folder
	local root = rootOf(model)
	if root then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
	NpcAvatar.startAnimations(model)
	self._avatars[staffId] = model
	return true
end

function StaffNpcWorld:moveTo(staffId: string, p: Point)
	local model = self:_avatar(staffId)
	local target = self:_world(staffId, p)
	if model and target then
		NpcAvatar.moveTo(model, target)
	end
end

function StaffNpcWorld:snapTo(staffId: string, p: Point)
	local model = self:_avatar(staffId)
	local target = self:_world(staffId, p)
	if model and target then
		NpcAvatar.snapTo(model, target)
	end
end

-- The avatar's lot-frame position; nil when it is gone, unknown or dead.
function StaffNpcWorld:position(staffId: string): Point?
	local model = self:_avatar(staffId)
	local plotId = self._plots[staffId]
	if model == nil or plotId == nil then
		return nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = rootOf(model)
	if not (humanoid and humanoid.Health > 0 and root) then
		return nil
	end
	local _, c = centerPoint(plotId)
	if c == nil then
		return nil
	end
	return NpcPath.fromWorld(c, root.Position.X, root.Position.Z)
end

-- Turns the avatar upright toward a lot-frame point.
function StaffNpcWorld:face(staffId: string, p: Point)
	local root = rootOf(self:_avatar(staffId))
	local target = self:_world(staffId, p)
	if target == nil or root == nil then
		return
	end
	local position = root.Position
	local dx, dz = target.X - position.X, target.Z - position.Z
	if math.sqrt(dx * dx + dz * dz) < 0.1 then
		return
	end
	root.AssemblyAngularVelocity = Vector3.zero
	root.CFrame = CFrame.lookAt(position, Vector3.new(target.X, position.Y, target.Z))
end

function StaffNpcWorld:holdTree(staffId: string, sizeId: string?, speciesId: string?)
	local model = self:_avatar(staffId)
	if model then
		WorldService.attachNpcTree(model, sizeId, speciesId)
	end
end

function StaffNpcWorld:dropTree(staffId: string)
	local model = self:_avatar(staffId)
	if model then
		WorldService.detachNpcTree(model)
	end
end

-- Stationary staff (OnDuty, Idle, Resting) keep an anchored root (CM2-25/26 performance).
function StaffNpcWorld:setAnchored(staffId: string, on: boolean)
	local root = rootOf(self:_avatar(staffId))
	if root == nil then
		return
	end
	if on then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.Anchored = true
	else
		root.Anchored = false
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
end

function StaffNpcWorld:setState(staffId: string, state: string)
	local model = self:_avatar(staffId)
	if model then
		model:SetAttribute("StaffState", state)
	end
end

function StaffNpcWorld:despawn(staffId: string)
	local model = self._avatars[staffId]
	if model then
		self._avatars[staffId] = nil
		model:Destroy()
	end
	self._plots[staffId] = nil
end

-- Break area (Parts, small decor) ---------------------------------------------------------------

local function paletteColor(key: string): Color3
	return Color3.fromRGB(table.unpack(ArtPalette[key].rgb))
end

local function paletteMaterial(key: string): Enum.Material
	local material = (Enum.Material :: any)[ArtPalette[key].material]
	return if material then material else Enum.Material.SmoothPlastic
end

local function decor(
	parent: Instance,
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	cframe: CFrame,
	paletteKey: string
): Part
	local value = Instance.new("Part")
	value.Name = name
	value.Shape = shape
	value.Size = size
	value.CFrame = cframe
	value.Color = paletteColor(paletteKey)
	value.Material = paletteMaterial(paletteKey)
	value.Anchored = true
	value.CanTouch = false
	value.CollisionGroup = STRUCTURE_GROUP
	value.TopSurface = Enum.SurfaceType.Smooth
	value.BottomSurface = Enum.SurfaceType.Smooth
	value.Parent = parent
	return value
end

local function validArea(area: any): boolean
	return type(area) == "table"
		and type(area.x) == "number"
		and type(area.z) == "number"
		and type(area.rotation) == "number"
		and area.x == area.x
		and area.z == area.z
end

-- Rebuilds the plot's campfire break area at `area` {x, z, rotation}; nil removes it. The plot
-- attributes BreakAreaX/Z/Rotation let the stocking preview keep trees out of it.
function StaffNpcWorld.syncBreakArea(plotId: string, area: any)
	local plot = findPlot(plotId)
	if plot == nil then
		return
	end
	local existing = plot:FindFirstChild("BreakArea")
	if existing then
		existing:Destroy()
	end
	local center, c = centerPoint(plotId)
	if not validArea(area) or center == nil or c == nil then
		plot:SetAttribute("BreakAreaX", nil)
		plot:SetAttribute("BreakAreaZ", nil)
		plot:SetAttribute("BreakAreaRotation", nil)
		return
	end
	local breakConfig = GameConfig.Staff.BreakArea
	local function at(offset: Point, y: number): Vector3
		local w = NpcPath.toWorld(c :: Point, Staff.toLot(area, offset))
		return Vector3.new(w.x, (center :: Vector3).Y + y, w.z)
	end
	local origin = { x = 0, z = 0 }
	local model = Instance.new("Model")
	model.Name = "BreakArea"
	model:SetAttribute("AreaX", area.x)
	model:SetAttribute("AreaZ", area.z)
	model:SetAttribute("AreaRotation", area.rotation)
	local side = breakConfig.HalfSize * 2
	local pad = decor(
		model,
		"Pad",
		Enum.PartType.Block,
		Vector3.new(side, 0.1, side),
		CFrame.new(at(origin, 0.05)),
		"SnowShade"
	)
	pad.CanCollide = false
	decor(
		model,
		"FireRing",
		Enum.PartType.Cylinder,
		Vector3.new(0.5, 3.2, 3.2),
		CFrame.new(at(origin, 0.25)) * CFrame.Angles(0, 0, math.rad(90)),
		"StoneGray"
	)
	local embers = decor(
		model,
		"Embers",
		Enum.PartType.Block,
		Vector3.new(1.2, 0.4, 1.2),
		CFrame.new(at(origin, 0.45)),
		"LightWarm"
	)
	embers.CanCollide = false
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 5
	fire.Color = paletteColor("LightWarm")
	fire.SecondaryColor = paletteColor("RoofRed")
	fire.Parent = embers
	local light = Instance.new("PointLight")
	light.Range = 12
	light.Brightness = 1.2
	light.Color = paletteColor("LightWarm")
	light.Parent = embers
	for index, log in ipairs(breakConfig.Logs) do
		local lot = Staff.toLot(area, log)
		local dx, dz = lot.x - area.x, lot.z - area.z
		local turn = if math.abs(dx) < math.abs(dz) then CFrame.identity else CFrame.Angles(0, math.rad(90), 0)
		decor(
			model,
			"Seat_" .. index,
			Enum.PartType.Cylinder,
			Vector3.new(4, 1, 1),
			CFrame.new(at(log, 0.5)) * turn,
			"BarkBrown"
		)
	end
	model.PrimaryPart = pad
	model.Parent = plot
	plot:SetAttribute("BreakAreaX", area.x)
	plot:SetAttribute("BreakAreaZ", area.z)
	plot:SetAttribute("BreakAreaRotation", area.rotation)
end

return StaffNpcWorld
