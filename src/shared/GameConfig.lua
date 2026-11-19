--!strict
local GameConfig = {}

GameConfig.StartingCash = 84
GameConfig.StartingReputation = 90
GameConfig.SizeMultipliers = { Small = 0.8, Medium = 1.0, Large = 1.3 }
GameConfig.MaxOrderQuantity = 100
GameConfig.MaxStockPerSku = 100000
GameConfig.MaxHistoryEntries = 100
-- Fallback only; a server ConfigService value will supersede this when configured.
GameConfig.DeliverySeconds = 60
GameConfig.PersonalPlotIds = { "Plot_01", "Plot_02", "Plot_03", "Plot_04", "Plot_05", "Plot_06" }

local validSizes = { Small = true, Medium = true, Large = true }

GameConfig.Trees = {
	-- Medium wholesale values are screenshot-observed. Small and Large wholesale
	-- values are provisional balance values and must be tuned through playtests.
	FrasierFir = {
		displayName = "Frasier Fir",
		wholesale = { Small = 26, Medium = 32, Large = 42 },
		typicalMedium = 80,
		initialMediumPrice = 82,
	},
	NobleFir = {
		displayName = "Noble Fir",
		wholesale = { Small = 30, Medium = 37, Large = 48 },
		typicalMedium = 92,
		initialMediumPrice = 96,
	},
	BlueSpruce = {
		displayName = "Blue Spruce",
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
	Cashier = { hireCost = 1200, role = "Checkout" },
	LotWorker = { hireCost = 1800, role = "DeliveryStockingLoading" },
}

GameConfig.HQ = {
	ChristmasPavilion = {
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

return GameConfig
