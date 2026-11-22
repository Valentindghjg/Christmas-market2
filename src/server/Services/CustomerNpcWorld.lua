--!strict
-- The Roblox world adapter of the walking customers (CM2-N1): maps visit IDs to an avatar
-- (NpcAvatar), a visit car and a carried tree (WorldService). CustomerNpcService calls it
-- through `deps.world`; every point is in the lot frame and converted with NpcPath, so the
-- mirrored plots 4-6 are correct by construction. Unknown visit IDs are a no-op.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Localization = require(Shared:WaitForChild("Localization"))
local NpcLook = require(Shared:WaitForChild("NpcLook"))
local NpcPath = require(Shared:WaitForChild("NpcPath"))
local NpcAvatar = require(script.Parent:WaitForChild("NpcAvatar"))
local WorldService = require(script.Parent:WaitForChild("WorldService"))

local Npc = GameConfig.Customers.Npc

local CustomerNpcWorld = {}
CustomerNpcWorld.__index = CustomerNpcWorld

type Point = NpcPath.Point

function CustomerNpcWorld.new()
	local self = setmetatable({}, CustomerNpcWorld)
	-- visitId -> plot ID; the avatar and the visit car, while they exist.
	self._plots = {} :: { [string]: string }
	self._avatars = {} :: { [string]: Model }
	self._cars = {} :: { [string]: Model }
	return self
end

-- Player characters pass through walking customers (collision group PlayerCharacter).
-- Idempotent per character (attribute NpcGroupAssigned), so the CharacterAdded handler and
-- the already-spawned character (Fix round 1, F6) never connect twice.
function CustomerNpcWorld.assignPlayerCharacter(character: Model)
	if character:GetAttribute("NpcGroupAssigned") then
		return
	end
	character:SetAttribute("NpcGroupAssigned", true)
	local group = Npc.CollisionGroups.Player
	local function assign(instance: Instance)
		if instance:IsA("BasePart") then
			instance.CollisionGroup = group
		end
	end
	for _, descendant in character:GetDescendants() do
		assign(descendant)
	end
	character.DescendantAdded:Connect(assign)
end

local function centerPoint(plotId: string): (Vector3?, Point?)
	local center = WorldService.plotCenter(plotId)
	if center == nil then
		return nil, nil
	end
	return center, { x = center.X, z = center.Z }
end

-- A lot-frame point of the visit's plot at ground height, or nil.
function CustomerNpcWorld:_world(visitId: string, p: Point): Vector3?
	local plotId = self._plots[visitId]
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

function CustomerNpcWorld:_avatar(visitId: string): Model?
	local model = self._avatars[visitId]
	if model and model.Parent then
		return model
	end
	return nil
end

function CustomerNpcWorld:spawnCar(plotId: string, visitId: string, space: number, seq: number): boolean
	self._plots[visitId] = plotId
	local visitCar = WorldService.spawnVisitCar(plotId, seq, space)
	if visitCar == nil then
		return false
	end
	self._cars[visitId] = visitCar
	return true
end

function CustomerNpcWorld:adoptCar(_plotId: string, visitId: string, orderNumber: number)
	local visitCar = self._cars[visitId]
	if visitCar then
		self._cars[visitId] = nil
		WorldService.adoptVisitCar(visitCar, orderNumber)
	end
end

function CustomerNpcWorld:dismissCar(_plotId: string, visitId: string)
	local visitCar = self._cars[visitId]
	if visitCar then
		self._cars[visitId] = nil
		WorldService.dismissVisitCar(visitCar)
	end
	self:_forgetIfEmpty(visitId)
end

function CustomerNpcWorld:destroyCar(_plotId: string, visitId: string)
	local visitCar = self._cars[visitId]
	if visitCar then
		self._cars[visitId] = nil
		WorldService.destroyVisitCar(visitCar)
	end
	self:_forgetIfEmpty(visitId)
end

function CustomerNpcWorld:_forgetIfEmpty(visitId: string)
	if self._cars[visitId] == nil and self._avatars[visitId] == nil then
		self._plots[visitId] = nil
	end
end

-- `Customer_<seq>` (load tests: `LoadNpc_<seq>`) at the door, facing the lot.
function CustomerNpcWorld:spawnAvatar(plotId: string, visitId: string, seq: number, door: Point): boolean
	self._plots[visitId] = plotId
	local center, c = centerPoint(plotId)
	local folder = WorldService.customersFolder(plotId)
	if center == nil or c == nil or folder == nil then
		return false
	end
	local model = NpcAvatar.build(NpcLook.forVisit(seq))
	if model == nil then
		return false
	end
	local isLoad = string.sub(visitId, 1, 5) == "load:"
	model.Name = (if isLoad then "LoadNpc_" else "Customer_") .. seq
	model:SetAttribute("NpcVisitId", visitId)
	local w = NpcPath.toWorld(c, door)
	local position = Vector3.new(w.x, center.Y, w.z)
	-- Facing the lot: the lot frame's -z.
	local inward = NpcPath.toWorld(c, { x = door.x, z = door.z - 1 })
	local look = Vector3.new(inward.x, center.Y, inward.z)
	model:PivotTo(CFrame.lookAt(position, look))
	NpcAvatar.snapTo(model, position)
	model.Parent = folder
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
	end
	NpcAvatar.startAnimations(model)
	self._avatars[visitId] = model
	return true
end

function CustomerNpcWorld:moveTo(visitId: string, p: Point)
	local model = self:_avatar(visitId)
	local target = self:_world(visitId, p)
	if model and target then
		NpcAvatar.moveTo(model, target)
	end
end

function CustomerNpcWorld:snapTo(visitId: string, p: Point)
	local model = self:_avatar(visitId)
	local target = self:_world(visitId, p)
	if model and target then
		NpcAvatar.snapTo(model, target)
	end
end

-- The avatar's lot-frame position; nil when it is gone, unknown or dead.
function CustomerNpcWorld:position(visitId: string): Point?
	local model = self:_avatar(visitId)
	local plotId = self._plots[visitId]
	if model == nil or plotId == nil then
		return nil
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not (humanoid and humanoid.Health > 0 and root and root:IsA("BasePart")) then
		return nil
	end
	local _, c = centerPoint(plotId)
	if c == nil then
		return nil
	end
	return NpcPath.fromWorld(c, root.Position.X, root.Position.Z)
end

function CustomerNpcWorld:holdTree(visitId: string, sizeId: string?)
	local model = self:_avatar(visitId)
	if model then
		WorldService.attachNpcTree(model, sizeId)
	end
end

function CustomerNpcWorld:dropTree(visitId: string)
	local model = self:_avatar(visitId)
	if model then
		WorldService.detachNpcTree(model)
	end
end

-- "Thanks so much!" above the head (the client localizes LabelKind NpcThanks).
function CustomerNpcWorld:say(visitId: string)
	local model = self:_avatar(visitId)
	local head = model and model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		WorldService.speech(head, "NpcThanks", Localization.get("en", "npcThanks"), Npc.ThanksSeconds)
	end
end

function CustomerNpcWorld:despawn(visitId: string)
	local model = self._avatars[visitId]
	if model then
		self._avatars[visitId] = nil
		model:Destroy()
	end
	self:_forgetIfEmpty(visitId)
end

return CustomerNpcWorld
