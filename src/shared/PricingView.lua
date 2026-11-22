--!strict
-- Pure text and step helpers for the Lot Manager's Pricing tab (CM2-G7). Every number shown
-- comes from the server's Company.GetSummary `pricing` table; the client only clamps a step
-- target into the server-reported bounds before sending it.
local GameConfig = require(script.Parent.GameConfig)

local PricingView = {}

export type Format = (key: string, ...any) -> string

PricingView.SENTIMENT_KEYS = {
	Bargain = "pricingSentimentBargain",
	Fair = "pricingSentimentFair",
	Pricey = "pricingSentimentPricey",
	TooHigh = "pricingSentimentTooHigh",
}

local function isNumber(value: unknown): boolean
	return type(value) == "number"
end

-- The size entry with this sizeId, when it carries a numeric price and profit.
local function sizeEntry(sizes: { any }, sizeId: string): any
	for _, size in ipairs(sizes) do
		if type(size) == "table" and size.sizeId == sizeId and isNumber(size.price) and isNumber(size.profit) then
			return size
		end
	end
	return nil
end

-- Card texts for one PricingEntry, or nil when the entry is incomplete.
function PricingView.card(entry: any, format: Format)
	if type(entry) ~= "table" then
		return nil
	end
	local speciesId = entry.speciesId
	local tree = if type(speciesId) == "string" then GameConfig.Trees[speciesId] else nil
	if tree == nil then
		return nil
	end
	if
		not isNumber(entry.mediumPrice)
		or not isNumber(entry.typicalMedium)
		or not isNumber(entry.wholesaleMedium)
		or not isNumber(entry.marginMedium)
		or not isNumber(entry.marginPercent)
	then
		return nil
	end
	local sentimentKey = if type(entry.sentiment) == "string" then PricingView.SENTIMENT_KEYS[entry.sentiment] else nil
	if sentimentKey == nil or type(entry.sizes) ~= "table" then
		return nil
	end
	local small = sizeEntry(entry.sizes, "Small")
	local medium = sizeEntry(entry.sizes, "Medium")
	local large = sizeEntry(entry.sizes, "Large")
	if small == nil or medium == nil or large == nil then
		return nil
	end
	return {
		name = tree.displayName,
		sentiment = format(sentimentKey),
		wholesaleTypical = format("pricingWholesaleTypical", entry.wholesaleMedium, entry.typicalMedium),
		margin = format("pricingMargin", entry.marginMedium, entry.marginPercent),
		sizes = format(
			"pricingSizes",
			small.price,
			small.profit,
			medium.price,
			medium.profit,
			large.price,
			large.profit
		),
		price = format("pricingPrice", entry.mediumPrice),
	}
end

function PricingView.autoText(automatic: any, format: Format): string
	return format(if automatic == true then "pricingAutoOn" else "pricingAutoOff")
end

function PricingView.ruleText(format: Format): string
	local multipliers = GameConfig.SizeMultipliers
	return format("pricingRule", math.floor(multipliers.Small * 100 + 0.5), math.floor(multipliers.Large * 100 + 0.5))
end

function PricingView.stepTarget(current: number, delta: number, minPrice: number, maxPrice: number): number
	return math.clamp(current + delta, minPrice, maxPrice)
end

function PricingView.errorText(errorCode: unknown, format: Format): string
	if errorCode == "InvalidPrice" or errorCode == "UnknownSpecies" then
		return format("pricingErrorInvalid")
	elseif errorCode == "RateLimited" then
		return format("saveErrorRateLimited")
	elseif errorCode == "ConnectionError" then
		return format("connectionError")
	end
	return format("errorStatus", tostring(errorCode))
end

return PricingView
