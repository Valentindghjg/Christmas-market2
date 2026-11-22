--!strict
-- Deterministic customer preferences; no client-owned customer input is trusted.
-- Budgets follow the size benchmark (Economy.typicalPrice, CM2-G7): 85-155 % of the typical
-- price of the preferred species and size (PROVISIONAL until CM2-N1).
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
		patienceSeconds = 12 + ((customerNumber * 7) % 19),
	}
end

function CustomerProfile.canPurchase(profile, placement, salePrice: number): boolean
	return type(profile) == "table"
		and type(placement) == "table"
		and type(profile.preferredSpeciesId) == "string"
		and type(profile.preferredSizeId) == "string"
		and type(profile.budget) == "number"
		and type(salePrice) == "number"
		and placement.speciesId == profile.preferredSpeciesId
		and placement.sizeId == profile.preferredSizeId
		and salePrice <= profile.budget
end

return CustomerProfile
