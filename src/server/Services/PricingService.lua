--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local PricingService = {}

local function validInteger(value): boolean
	return type(value) == "number"
		and value == math.floor(value)
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
end

function PricingService.bounds(speciesId: string)
	local tree = GameConfig.Trees[speciesId]
	if not tree then
		return nil
	end
	return math.ceil(tree.typicalMedium * GameConfig.MinPriceMultiplier),
		math.floor(tree.typicalMedium * GameConfig.MaxPriceMultiplier)
end

function PricingService.setMediumPrice(state, speciesId: string, mediumPrice: number)
	local minimum, maximum = PricingService.bounds(speciesId)
	if not minimum or not validInteger(mediumPrice) or mediumPrice < minimum or mediumPrice > maximum then
		return false, "InvalidPrice"
	end
	state.mediumPrices[speciesId] = mediumPrice
	state.autoPricing = false
	return true, mediumPrice
end

function PricingService.setAutomatic(state, enabled: boolean)
	if type(enabled) ~= "boolean" then
		return false, "InvalidAutoPrice"
	end
	state.autoPricing = enabled
	return true, enabled
end

return PricingService
