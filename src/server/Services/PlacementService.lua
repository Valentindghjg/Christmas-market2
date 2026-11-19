--!strict
-- Authoritative storage/display transitions with bounded serializable transforms.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Inventory = require(Shared:WaitForChild("Inventory"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local PlacementService = {}

local function finite(value): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function validTransform(transform): boolean
	return type(transform) == "table"
		and finite(transform.x)
		and finite(transform.y)
		and finite(transform.z)
		and finite(transform.rotation)
		and transform.x >= -50
		and transform.x <= 50
		and transform.y >= -2
		and transform.y <= 5
		and transform.z >= -50
		and transform.z <= 50
		and transform.rotation >= 0
		and transform.rotation < 360
end

function PlacementService.place(state, placementId: string, speciesId: string, sizeId: string, transform)
	if type(placementId) ~= "string" or #placementId < 8 or state.layout.placements[placementId] then
		return false, "InvalidPlacementId"
	end
	if not GameConfig.Trees[speciesId] or not GameConfig.isValidSize(sizeId) or not validTransform(transform) then
		return false, "InvalidPlacement"
	end
	local key = Inventory.key(speciesId, sizeId)
	if not Inventory.remove(state.stock, key, 1) then
		return false, "OutOfStock"
	end
	state.layout.placements[placementId] = { speciesId = speciesId, sizeId = sizeId, transform = transform }
	return true, placementId
end

function PlacementService.pickup(state, placementId: string)
	local placement = state.layout.placements[placementId]
	if type(placement) ~= "table" then
		return false, "UnknownPlacement"
	end
	local key = Inventory.key(placement.speciesId, placement.sizeId)
	if not Inventory.add(state.stock, key, 1) then
		return false, "Capacity"
	end
	state.layout.placements[placementId] = nil
	return true, placementId
end

return PlacementService
