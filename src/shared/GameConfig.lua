--!strict
local GameConfig = {}

-- Bump when a saved balance value needs a migration; evidence distinguishes
-- screenshot-observed values from provisional tuning choices.
GameConfig.VERSION = 1
GameConfig.Evidence = {
	Observed = "OBSERVED",
	OwnerDecided = "OWNER_DECIDED",
	Provisional = "PROVISIONAL",
}

GameConfig.StartingCash = 84
GameConfig.StartingReputation = 90
GameConfig.SizeIds = { "Small", "Medium", "Large" }
GameConfig.SizeMultipliers = { Small = 0.8, Medium = 1.0, Large = 1.3 } -- OBSERVED
GameConfig.MaxOrderQuantity = 100
GameConfig.MaxStockPerSku = 100000
GameConfig.MaxHistoryEntries = 100
GameConfig.MinPriceMultiplier = 0.5
GameConfig.MaxPriceMultiplier = 2.5
-- Fallback only; a server ConfigService value will supersede this when configured.
GameConfig.DeliverySeconds = 60
GameConfig.AutosaveSeconds = 60
GameConfig.CustomerReservationSeconds = 30
GameConfig.AutoPricingIntervalSeconds = 3
GameConfig.CustomerVisitIntervalSeconds = 5
GameConfig.MaxCustomerVisitsPerTick = 3
GameConfig.Quests = {
	FirstSale = { metric = "sales", target = 1, rewardCash = 50 },
	SalesFive = { metric = "sales", target = 5, rewardCash = 150 },
}
GameConfig.AutoPricing = {
	TargetDisplayStock = 5,
	MaxDiscountFraction = 0.15,
}
GameConfig.PersonalPlotIds = { "Plot_01", "Plot_02", "Plot_03", "Plot_04", "Plot_05", "Plot_06" }

local validSizes = { Small = true, Medium = true, Large = true }

GameConfig.Trees = {
	-- Medium wholesale values are screenshot-observed. Small and Large wholesale
	-- values are provisional balance values and must be tuned through playtests.
	FrasierFir = {
		displayName = "Frasier Fir",
		evidence = GameConfig.Evidence.Observed,
		wholesale = { Small = 26, Medium = 32, Large = 42 },
		typicalMedium = 80,
		initialMediumPrice = 82,
	},
	NobleFir = {
		displayName = "Noble Fir",
		evidence = GameConfig.Evidence.Observed,
		wholesale = { Small = 30, Medium = 37, Large = 48 },
		typicalMedium = 92,
		initialMediumPrice = 96,
	},
	BlueSpruce = {
		displayName = "Blue Spruce",
		evidence = GameConfig.Evidence.Observed,
		wholesale = { Small = 34, Medium = 42, Large = 55 },
		typicalMedium = 105,
		initialMediumPrice = 105,
	},
}

function GameConfig.isValidSize(size: unknown): boolean
	return type(size) == "string" and validSizes[size] == true
end

function GameConfig.wholesaleFor(species: unknown, size: unknown): number?
	if type(species) ~= "string" or not GameConfig.isValidSize(size) then
		return nil
	end
	local tree = GameConfig.Trees[species]
	return tree and tree.wholesale[size] or nil
end

GameConfig.Employees = {
	Cashier = { hireCost = 1200, role = "Checkout", maxCount = 1, evidence = GameConfig.Evidence.Observed },
	LotWorker = {
		hireCost = 1800,
		role = "DeliveryStockingLoading",
		maxCount = 1,
		evidence = GameConfig.Evidence.Observed,
	},
}

GameConfig.HQ = {
	ChristmasPavilion = {
		evidence = GameConfig.Evidence.Observed,
		cashCost = 2500,
		requiredReputation = 250,
		requiredLotExpansion = 1,
		requiredParkingSpaces = 4,
		unlockedTreeCount = 4,
		checkoutStations = 2,
		employeeCapacity = 3,
		customerPatienceBonus = 0.12,
	},
}

GameConfig.Progression = {
	LotExpansion = { cashCost = 750, requiredReputation = 50, maxLevel = 3, evidence = GameConfig.Evidence.Provisional },
	Parking = { cashCost = 200, maxSpaces = 4, evidence = GameConfig.Evidence.Provisional },
}

GameConfig.Placement = {
	MinX = -50,
	MaxX = 50,
	MinY = -2,
	MaxY = 5,
	MinZ = -50,
	MaxZ = 50,
	MinRotation = 0,
	MaxRotationExclusive = 360,
}

return GameConfig
