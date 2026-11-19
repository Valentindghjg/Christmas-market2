--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local BusinessState = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BusinessState"))

local ProgressionService = {}

local function spend(state, cost: number, event: string)
	if state.cash < cost then
		return false, "InsufficientFunds"
	end
	state.cash -= cost
	state.spent += cost
	BusinessState.record(state, event, -cost)
	return true, nil
end

function ProgressionService.buyLotExpansion(state)
	local config = GameConfig.Progression.LotExpansion
	if state.progression.lotExpansion >= config.maxLevel then
		return false, "MaxLevel"
	end
	if state.reputation < config.requiredReputation then
		return false, "InsufficientReputation"
	end
	local ok, errorCode = spend(state, config.cashCost, "LotExpansion")
	if not ok then
		return false, errorCode
	end
	state.progression.lotExpansion += 1
	return true, state.progression.lotExpansion
end

function ProgressionService.buyParking(state)
	local config = GameConfig.Progression.Parking
	if state.progression.parkingSpaces >= config.maxSpaces then
		return false, "MaxParking"
	end
	local ok, errorCode = spend(state, config.cashCost, "Parking")
	if not ok then
		return false, errorCode
	end
	state.progression.parkingSpaces += 1
	return true, state.progression.parkingSpaces
end

function ProgressionService.buyHQ(state, hqId: string)
	local config = GameConfig.HQ[hqId]
	if not config or state.progression.hqTier ~= nil then
		return false, "InvalidHQ"
	end
	if state.reputation < config.requiredReputation then
		return false, "InsufficientReputation"
	end
	if
		state.progression.lotExpansion < config.requiredLotExpansion
		or state.progression.parkingSpaces < config.requiredParkingSpaces
	then
		return false, "PrerequisitesNotMet"
	end
	local ok, errorCode = spend(state, config.cashCost, "HQUpgrade")
	if not ok then
		return false, errorCode
	end
	state.progression.hqTier = hqId
	return true, hqId
end

return ProgressionService
