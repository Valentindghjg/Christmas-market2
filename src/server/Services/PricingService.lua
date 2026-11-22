--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Economy = require(Shared:WaitForChild("Economy"))

local PricingService = {}

local function validInteger(value): boolean
	return type(value) == "number"
		and value == math.floor(value)
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
end

-- Manual price bounds around the benchmark (GameConfig.typicalMediumFor, CM2-G7).
function PricingService.bounds(speciesId: string)
	local typical = GameConfig.typicalMediumFor(speciesId)
	if typical == nil then
		return nil
	end
	return math.ceil(typical * GameConfig.MinPriceMultiplier), math.floor(typical * GameConfig.MaxPriceMultiplier)
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
-- Returns only the species whose price actually changed, so an idle scheduler tick does
-- not dirty the company record or trigger a DataStore write.
function PricingService.applyAutomatic(state)
	if state.autoPricing ~= true then
		return false, "AutoPricingDisabled"
	end
	local updated = {}
	for speciesId in pairs(GameConfig.Trees) do
		local typical = GameConfig.typicalMediumFor(speciesId) :: number
		local minimum, maximum = PricingService.bounds(speciesId)
		local stockPressure = math.min(displayedCount(state, speciesId) / GameConfig.AutoPricing.TargetDisplayStock, 1)
		local target = math.floor(typical * (1 - stockPressure * GameConfig.AutoPricing.MaxDiscountFraction) + 0.5)
		local price = math.max(minimum :: number, math.min(maximum :: number, target))
		if state.mediumPrices[speciesId] ~= price then
			state.mediumPrices[speciesId] = price
			updated[speciesId] = price
		end
	end
	return true, updated
end

-- Names how a medium price compares with the benchmark (GameConfig.Pricing.SentimentPercent).
function PricingService.sentiment(mediumPrice: number, typicalMedium: number): string
	local percent = GameConfig.Pricing.SentimentPercent
	local p = mediumPrice * 100
	if p <= typicalMedium * percent.Bargain then
		return "Bargain"
	elseif p <= typicalMedium * percent.Fair then
		return "Fair"
	elseif p <= typicalMedium * percent.Pricey then
		return "Pricey"
	end
	return "TooHigh"
end

function PricingService.marginPercent(price: number, wholesale: number): number
	if price < 1 then
		return 0
	end
	return math.floor((price - wholesale) * 100 / price + 0.5)
end

-- Presentation-safe pricing table for Company.GetSummary (CM2-G7). Reads the state only.
function PricingService.summary(state)
	local species = {}
	for _, speciesId in ipairs(GameConfig.SpeciesOrder) do
		local mediumPrice = state.mediumPrices[speciesId]
		local typicalMedium = GameConfig.typicalMediumFor(speciesId) :: number
		local wholesaleMedium = GameConfig.wholesaleFor(speciesId, "Medium") :: number
		local minPrice, maxPrice = PricingService.bounds(speciesId)
		local sizes = {}
		for _, sizeId in ipairs(GameConfig.SizeIds) do
			local price = Economy.priceForSize(mediumPrice, sizeId)
			local wholesale = GameConfig.wholesaleFor(speciesId, sizeId) :: number
			table.insert(sizes, { sizeId = sizeId, price = price, wholesale = wholesale, profit = price - wholesale })
		end
		table.insert(species, {
			speciesId = speciesId,
			mediumPrice = mediumPrice,
			minPrice = minPrice,
			maxPrice = maxPrice,
			typicalMedium = typicalMedium,
			wholesaleMedium = wholesaleMedium,
			marginMedium = mediumPrice - wholesaleMedium,
			marginPercent = PricingService.marginPercent(mediumPrice, wholesaleMedium),
			sentiment = PricingService.sentiment(mediumPrice, typicalMedium),
			sizes = sizes,
		})
	end
	return { automatic = state.autoPricing == true, species = species }
end

return PricingService
