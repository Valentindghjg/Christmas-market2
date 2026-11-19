--!strict
-- Deterministic customer preferences; no client-owned customer input is trusted.
local CustomerProfile = {}

local species = { "FrasierFir", "NobleFir", "BlueSpruce" }
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
	return {
		id = "npc:" .. tostring(customerNumber),
		preferredSpeciesId = species[speciesIndex],
		preferredSizeId = sizes[sizeIndex],
		budget = 70 + ((customerNumber * 17) % 81),
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
