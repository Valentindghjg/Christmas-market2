--!strict
local Demand = {}

local function clamp(value: number, minimum: number, maximum: number): number
	return math.max(minimum, math.min(maximum, value))
end

-- All inputs are server-derived normalized factors in the range 0..1 except priceRatio.
-- interest (CM2-SALE2, GAME_DESIGN §4 baseSpeciesInterest) defaults to 1.
function Demand.score(
	priceRatio: number,
	reputation: number,
	seasonalFactor: number,
	varietyFactor: number,
	stockFactor: number,
	interest: number?
): number
	if priceRatio <= 0 or reputation < 0 then
		return 0
	end
	local priceFactor = clamp(1.35 - 0.7 * priceRatio, 0.1, 1)
	local reputationFactor = clamp(0.5 + reputation / 1000, 0.5, 1)
	return clamp(
		priceFactor * reputationFactor * seasonalFactor * varietyFactor * stockFactor * (interest or 1),
		0.02,
		0.95
	)
end

return Demand
