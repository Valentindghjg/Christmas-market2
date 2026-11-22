--!strict
local Economy = require(script.Parent.Economy)
local Demand = require(script.Parent.Demand)
local GameConfig = require(script.Parent.GameConfig)
local CustomerProfile = require(script.Parent.CustomerProfile)

local CustomerSelection = {}

local function varietyFactor(state): number
	local species = {}
	local total = 0
	for _, placement in pairs(state.layout.placements) do
		if type(placement) == "table" and type(placement.speciesId) == "string" then
			species[placement.speciesId] = true
			total += 1
		end
	end
	local distinct = 0
	for _ in pairs(species) do
		distinct += 1
	end
	if total == 0 then
		return 0
	end
	return math.min(1, distinct / 3)
end

-- Returns the first stable compatible candidate and its server-computed conversion score.
function CustomerSelection.choose(state, profile)
	if type(state) ~= "table" or type(state.layout) ~= "table" or type(state.layout.placements) ~= "table" then
		return nil
	end
	local candidateIds = {}
	for placementId in pairs(state.layout.placements) do
		if state.reservations[placementId] == nil then
			table.insert(candidateIds, placementId)
		end
	end
	table.sort(candidateIds)
	local stockFactor = math.min(1, #candidateIds / GameConfig.AutoPricing.TargetDisplayStock)
	for _, placementId in ipairs(candidateIds) do
		local placement = state.layout.placements[placementId]
		local mediumPrice = state.mediumPrices[placement.speciesId]
		if type(mediumPrice) == "number" then
			local salePrice = Economy.priceForSize(mediumPrice, placement.sizeId)
			local typical = Economy.typicalPrice(placement.speciesId, placement.sizeId)
			if typical ~= nil and CustomerProfile.canPurchase(profile, placement, salePrice) then
				local score = Demand.score(salePrice / typical, state.reputation, 1, varietyFactor(state), stockFactor)
				return { placementId = placementId, salePrice = salePrice, conversionScore = score }
			end
		end
	end
	return nil
end

return CustomerSelection
