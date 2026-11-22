--!strict
-- Authoritative receiving-bay <-> display transitions (CM2-G14, docs/plans/CM2-G14.md). Pure
-- state functions without the hands check, so the Lot Worker (CM2-25/26) can call them too.
-- Every check runs before the first mutation: a refused request changes nothing.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BusinessState = require(Shared:WaitForChild("BusinessState"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Receiving = require(Shared:WaitForChild("Receiving"))
local Stocking = require(Shared:WaitForChild("Stocking"))

local PlacementService = {}

local function finite(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function integer(value: unknown): boolean
	return finite(value) and value == math.floor(value :: number)
end

local function placementCount(state): number
	local count = 0
	for _ in pairs(state.layout.placements) do
		count += 1
	end
	return count
end

local function validInput(
	idPrefix: unknown,
	speciesId: unknown,
	sizeId: unknown,
	x: unknown,
	z: unknown,
	rotation: unknown,
	count: unknown,
	gap: unknown
): boolean
	local config = GameConfig.Placement
	if type(idPrefix) ~= "string" or #idPrefix < 1 then
		return false
	end
	if type(speciesId) ~= "string" or not GameConfig.Trees[speciesId] or not GameConfig.isValidSize(sizeId) then
		return false
	end
	if not finite(x) or not finite(z) then
		return false
	end
	if math.abs(x :: number) > config.CoordinateLimit or math.abs(z :: number) > config.CoordinateLimit then
		return false
	end
	if
		not integer(rotation)
		or (rotation :: number) < 0
		or (rotation :: number) >= 360
		or (rotation :: number) % config.RotationStep ~= 0
	then
		return false
	end
	if not integer(count) or (count :: number) < 1 or (count :: number) > config.RowMax then
		return false
	end
	if not finite(gap) or (gap :: number) < config.Gap.Min or (gap :: number) > config.Gap.Max then
		return false
	end
	local steps = (gap :: number) / config.Gap.Step
	return steps == math.floor(steps)
end

-- Places `count` trees of one size from bay `bayIndex` in a row (count 1 = a single tree).
-- All positions are validated before anything changes: all or none.
function PlacementService.stockFromBay(
	state,
	idPrefix: string,
	bayIndex: number,
	speciesId: string,
	sizeId: string,
	x: number,
	z: number,
	rotation: number,
	count: number,
	gap: number
): (boolean, any)
	if not validInput(idPrefix, speciesId, sizeId, x, z, rotation, count, gap) then
		return false, "InvalidPlacement"
	end
	local placementIds = {}
	for index = 1, count do
		local placementId = idPrefix .. ":" .. index
		-- A request ID that left the bounded replay list must never overwrite a displayed tree.
		if state.layout.placements[placementId] ~= nil then
			return false, "InvalidPlacement"
		end
		table.insert(placementIds, placementId)
	end
	local bay = if type(state.bays) == "table" then state.bays[bayIndex] else nil
	if type(bay) ~= "table" or bay.speciesId ~= speciesId then
		return false, "BayChanged"
	end
	local stored = bay.counts[sizeId]
	if type(stored) ~= "number" or stored < count then
		return false, "NotEnoughTrees"
	end
	if placementCount(state) + count > GameConfig.MaxPlacements then
		return false, "PlacementLimit"
	end
	local positions = Stocking.rowPositions(x, z, rotation, sizeId, count, gap)
	local fits, code = Stocking.checkRow(Stocking.layoutInput(state), positions, sizeId)
	if not fits then
		return false, code
	end

	if not Receiving.take(state, bayIndex, sizeId, count) then
		return false, "NotEnoughTrees"
	end
	for index, position in ipairs(positions) do
		-- A fresh table with only validated numbers; client tables never reach the save.
		state.layout.placements[placementIds[index]] = {
			speciesId = speciesId,
			sizeId = sizeId,
			transform = { x = position.x, y = 0, z = position.z, rotation = rotation },
		}
	end
	Receiving.normalize(state)
	local result = {
		placementIds = placementIds,
		bay = bayIndex,
		remaining = Receiving.view(state, 0)[bayIndex].counts,
	}
	return true, result
end

-- Store mode: one unreserved displayed tree goes back into receiving.
function PlacementService.storeBack(state, placementId: string): (boolean, any)
	local placement = state.layout.placements[placementId]
	if type(placement) ~= "table" then
		return false, "UnknownPlacement"
	end
	-- A customer holds a price lock on this tree; it is never moved.
	if state.reservations[placementId] ~= nil then
		return false, "Reserved"
	end
	local bay = Receiving.storeBay(state, placement.speciesId)
	if bay == nil then
		return false, "NoFreeBay"
	end
	if BusinessState.storageUsed(state) + 1 > BusinessState.storageCapacity(state) then
		return false, "StorageFull"
	end
	-- add() refuses a placement without a known species or size; nothing has changed then.
	if not Receiving.add(state, bay, placement.speciesId, placement.sizeId, 1) then
		return false, "UnknownPlacement"
	end
	state.layout.placements[placementId] = nil
	return true, { placementId = placementId, bay = bay }
end

return PlacementService
