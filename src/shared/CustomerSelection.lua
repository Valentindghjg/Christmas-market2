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
-- priceTolerance (CM2-46a, Evergreen VIP): the customer judges salePrice / priceTolerance
-- against its budget and the Demand price ratio; the candidate keeps the real salePrice.
function CustomerSelection.choose(state, profile, priceTolerance: number?)
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
	local tolerance = 1
	if type(priceTolerance) == "number" and priceTolerance > 0 and priceTolerance ~= math.huge then
		tolerance = priceTolerance
	end
	for _, placementId in ipairs(candidateIds) do
		local placement = state.layout.placements[placementId]
		local mediumPrice = state.mediumPrices[placement.speciesId]
		if type(mediumPrice) == "number" then
			local salePrice = Economy.priceForSize(mediumPrice, placement.sizeId)
			local typical = Economy.typicalPrice(placement.speciesId, placement.sizeId)
			local judged = salePrice / tolerance
			if typical ~= nil and CustomerProfile.canPurchase(profile, placement, judged) then
				local score = Demand.score(judged / typical, state.reputation, 1, varietyFactor(state), stockFactor)
				return { placementId = placementId, salePrice = salePrice, conversionScore = score }
			end
		end
	end
	return nil
end

return CustomerSelection
