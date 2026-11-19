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

local function displayedCount(state, speciesId: string): number
	local count = 0
	for _, placement in pairs(state.layout.placements) do
		if type(placement) == "table" and placement.speciesId == speciesId then
			count += 1
		end
	end
	return count
end

-- Applies a bounded, stock-sensitive server target. Reserved sales carry their locked price.
function PricingService.applyAutomatic(state)
	if state.autoPricing ~= true then
		return false, "AutoPricingDisabled"
	end
	local updated = {}
	for speciesId, tree in pairs(GameConfig.Trees) do
		local minimum, maximum = PricingService.bounds(speciesId)
		local stockPressure = math.min(displayedCount(state, speciesId) / GameConfig.AutoPricing.TargetDisplayStock, 1)
		local target =
			math.floor(tree.typicalMedium * (1 - stockPressure * GameConfig.AutoPricing.MaxDiscountFraction) + 0.5)
		local price = math.max(minimum :: number, math.min(maximum :: number, target))
		state.mediumPrices[speciesId] = price
		updated[speciesId] = price
	end
	return true, updated
end

return PricingService
