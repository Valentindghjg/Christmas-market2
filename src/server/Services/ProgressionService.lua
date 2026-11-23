--!strict
-- Lot expansion, parking and HQ purchases (CM2-G9a). Each buys one explicit target through
-- Progression.check, so a second request for an owned level is refused (AlreadyOwned) and the
-- cash is debited exactly once. A replayed request ID never reaches these functions.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local BusinessState = require(Shared:WaitForChild("BusinessState"))
local Progression = require(Shared:WaitForChild("Progression"))

local Config = GameConfig.Progression

local ProgressionService = {}

local function spend(state, cost: number, event: string)
	if state.cash < cost then
		return false, "InsufficientFunds"
	end
	state.cash -= cost
	state.spent += cost
	BusinessState.record(state, event, -cost)
	return true, nil
end

-- Checks, debits cashCost once with `event` and sets the saved field to target.
local function buy(state, kind: string, target: unknown, cost: (number) -> number, event: string, field: string)
	local ok, code = Progression.check(state, kind, target)
	if not ok then
		return false, code
	end
	local level = target :: number
	local spent, spendError = spend(state, cost(level), event)
	if not spent then
		return false, spendError
	end
	state.progression[field] = level
	return true, level
end

function ProgressionService.buyLotExpansion(state, level: unknown)
	return buy(state, "LotExpansion", level, function(target)
		return Config.LotExpansion.levels[target].cashCost
	end, "LotExpansion", "lotExpansion")
end

function ProgressionService.buyParking(state, tier: unknown)
	return buy(state, "Parking", tier, function(target)
		return Config.Parking.tiers[target].cashCost
	end, "Parking", "parkingTier")
end

function ProgressionService.buyHQ(state, level: unknown)
	return buy(state, "HQ", level, function(target)
		return Config.HQ.tiers[target].cashCost
	end, "HQUpgrade", "hqLevel")
end

return ProgressionService
