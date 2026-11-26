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
	local D = GameConfig.Demand
	return math.min(1, D.VarietySingle + (1 - D.VarietySingle) * (distinct - 1) / (D.VarietyFullSpecies - 1))
end

-- The unreserved displayed placement IDs, sorted (a stable pick order).
local function unreservedIds(state): { string }
	local candidateIds = {}
	for placementId in pairs(state.layout.placements) do
		if state.reservations[placementId] == nil then
			table.insert(candidateIds, placementId)
		end
	end
	table.sort(candidateIds)
	return candidateIds
end

-- Returns the highest-scoring compatible candidate (ties: first sorted ID) and its server-computed
-- conversion score. CM2-SALE2: compatible means within the budget for that tree; the score includes
-- the customer's interest.
-- priceTolerance (CM2-46a, Evergreen VIP): the customer judges salePrice / priceTolerance
-- against its budget and the Demand price ratio; the candidate keeps the real salePrice.
function CustomerSelection.choose(state, profile, priceTolerance: number?)
	if type(state) ~= "table" or type(state.layout) ~= "table" or type(state.layout.placements) ~= "table" then
		return nil
	end
	local candidateIds = unreservedIds(state)
	local base = GameConfig.Demand.StockBase
	local stockFactor = math.min(1, base + (1 - base) * #candidateIds / GameConfig.AutoPricing.TargetDisplayStock)
	local variety = varietyFactor(state)
	local tolerance = 1
	if type(priceTolerance) == "number" and priceTolerance > 0 and priceTolerance ~= math.huge then
		tolerance = priceTolerance
	end
	local best = nil
	local bestScore = -1
	for _, placementId in ipairs(candidateIds) do
		local placement = state.layout.placements[placementId]
		local mediumPrice = state.mediumPrices[placement.speciesId]
		if type(mediumPrice) == "number" then
			local salePrice = Economy.priceForSize(mediumPrice, placement.sizeId)
			local typical = Economy.typicalPrice(placement.speciesId, placement.sizeId)
			local judged = salePrice / tolerance
			if typical ~= nil and CustomerProfile.canPurchase(profile, placement, judged) then
				local interest = CustomerProfile.interestIn(profile, placement)
				local score = Demand.score(judged / typical, state.reputation, 1, variety, stockFactor, interest)
				if score > bestScore then
					bestScore = score
					best = { placementId = placementId, salePrice = salePrice, conversionScore = score }
				end
			end
		end
	end
	return best
end

-- CM2-SALE1 tutorial customer: the first unreserved displayed tree (sorted placement IDs)
-- with a numeric medium price and a valid size, at its current sale price. No preference,
-- budget or Demand check; conversionScore 1 converts every roll in [0, 1].
function CustomerSelection.chooseGuaranteed(state)
	if type(state) ~= "table" or type(state.layout) ~= "table" or type(state.layout.placements) ~= "table" then
		return nil
	end
	for _, placementId in ipairs(unreservedIds(state)) do
		local placement = state.layout.placements[placementId]
		if type(placement) == "table" then
			local mediumPrice = state.mediumPrices[placement.speciesId]
			if type(mediumPrice) == "number" and Economy.typicalPrice(placement.speciesId, placement.sizeId) ~= nil then
				return {
					placementId = placementId,
					salePrice = Economy.priceForSize(mediumPrice, placement.sizeId),
					conversionScore = 1,
				}
			end
		end
	end
	return nil
end

return CustomerSelection
