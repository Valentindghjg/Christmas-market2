--!strict
-- Deterministic customer preferences; no client-owned customer input is trusted.
-- Budgets are 85-155 % (`budgetPercent`) of the benchmark (Economy.typicalPrice, CM2-G7); the same
-- percent applies to any tree the customer considers (CM2-SALE2, PROVISIONAL).
local GameConfig = require(script.Parent.GameConfig)
local Economy = require(script.Parent.Economy)

local CustomerProfile = {}

-- Douglas Fir is appended so existing profile numbers keep their species (tests and
-- StudioTestHook); CM2-N1 replaces this cycle with real customer preferences.
local species = { "FrasierFir", "NobleFir", "BlueSpruce", "DouglasFir" }
local sizes = { "Small", "Medium", "Large" }

local function positiveInteger(value: unknown): boolean
	return type(value) == "number" and value == math.floor(value) and value > 0
end

function CustomerProfile.create(customerNumber: number)
	if not positiveInteger(customerNumber) then
		return nil
	end
	local speciesIndex = ((customerNumber - 1) % #species) + 1
	local sizeIndex = ((math.floor((customerNumber - 1) / #species)) % #sizes) + 1
	local preferredSpeciesId = species[speciesIndex]
	local preferredSizeId = sizes[sizeIndex]
	local Budget = GameConfig.Pricing.BudgetPercent
	local percent = Budget.Min + ((customerNumber * 17) % (Budget.Max - Budget.Min + 1))
	local budget = ((Economy.typicalPrice(preferredSpeciesId, preferredSizeId) :: number) * percent + 50) // 100
	return {
		id = "npc:" .. tostring(customerNumber),
		preferredSpeciesId = preferredSpeciesId,
		preferredSizeId = preferredSizeId,
		budget = budget,
		budgetPercent = percent,
		patienceSeconds = 12 + ((customerNumber * 7) % 19),
	}
end

-- The profile's budget for any tree: its budget percent applied to that tree's benchmark.
function CustomerProfile.budgetFor(profile, speciesId: unknown, sizeId: unknown): number?
	if type(profile) ~= "table" or type(profile.budgetPercent) ~= "number" then
		return nil
	end
	local typical = Economy.typicalPrice(speciesId, sizeId)
	if typical == nil then
		return nil
	end
	return (typical * profile.budgetPercent + 50) // 100
end

-- How much the customer wants this tree, by the match with its preferred species and size.
function CustomerProfile.interestIn(profile, placement): number
	if type(profile) ~= "table" or type(placement) ~= "table" then
		return 0
	end
	local Interest = GameConfig.Demand.Interest
	local sameSpecies = placement.speciesId == profile.preferredSpeciesId
	local sameSize = placement.sizeId == profile.preferredSizeId
	if sameSpecies and sameSize then
		return Interest.Exact
	elseif sameSpecies then
		return Interest.SameSpecies
	elseif sameSize then
		return Interest.SameSize
	end
	return Interest.Other
end

-- Soft preference (CM2-SALE2): any known tree within the budget scaled to its own benchmark;
-- interestIn weighs the match.
function CustomerProfile.canPurchase(profile, placement, salePrice: number): boolean
	if type(profile) ~= "table" or type(placement) ~= "table" or type(salePrice) ~= "number" then
		return false
	end
	local budget = CustomerProfile.budgetFor(profile, placement.speciesId, placement.sizeId)
	return budget ~= nil and salePrice <= budget
end

return CustomerProfile
