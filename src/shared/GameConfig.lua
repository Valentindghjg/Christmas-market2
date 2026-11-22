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
-- PROVISIONAL caps that bound the saved record size and server-side display models.
GameConfig.MaxOpenOrders = 20
GameConfig.MaxPlacements = 100
GameConfig.MinPriceMultiplier = 0.5
GameConfig.MaxPriceMultiplier = 2.5
-- Fallback only; a server ConfigService value will supersede this when configured.
GameConfig.DeliverySeconds = 60
-- Persistence cadence. Mutations only mark a session dirty; a flush writes dirty
-- sessions at most once per SaveFlushSeconds, and every session is re-saved at
-- least once per AutosaveSeconds to renew its lock. If no save has succeeded for
-- SaveFailClosedSeconds the session stops accepting mutations, well before
-- another server could take over the SessionLockSeconds lock.
GameConfig.SaveFlushSeconds = 15
GameConfig.AutosaveSeconds = 60
GameConfig.SessionLockSeconds = 120
GameConfig.SaveFailClosedSeconds = 90
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

-- Save slots per player (CM2-S1). All values are PROVISIONAL engineering choices.
GameConfig.Saves = {
	-- The spec says unlimited; this technical cap bounds the profile size and the DataStore
	-- storage quota and lies far above realistic use.
	MaxSavesPerPlayer = 50,
	NameMaxLength = 24,
	NamePayloadMaxBytes = 100,
	DefaultNameFormat = "Tree Lot %d",
	MaxPlotTeleports = 3,
	LoadAttempts = 5,
	RecentCreates = 10,
	-- Co-op saves (CM2-S2): seats per save size are OWNER DECIDED (PRODUCT_SPEC).
	Seats = { Solo = 1, Duo = 2, Trio = 3, Quad = 4 },
	-- 5-digit invite codes are OWNER DECIDED; no leading zero is PROVISIONAL.
	InviteCodeMin = 10000,
	InviteCodeMax = 99999,
	InviteClaimAttempts = 8, -- PROVISIONAL
	SharedEntryName = "Shared lot", -- PROVISIONAL
	JoinFailureLimit = { limit = 10, window = 3600 }, -- wrong codes per player
	JoinServerFailureLimit = { limit = 60, window = 60 }, -- wrong codes per server
	RateLimits = {
		["Save.List"] = { limit = 20, window = 10 },
		["Save.Create"] = { limit = 5, window = 60 },
		["Save.Rename"] = { limit = 5, window = 60 },
		["Save.Delete"] = { limit = 5, window = 60 },
		["Save.Play"] = { limit = 10, window = 60 },
		["Save.Join"] = { limit = 5, window = 60 },
		["Save.LeaveTeam"] = { limit = 5, window = 60 },
		["Save.Team"] = { limit = 20, window = 10 },
		["Save.RemoveMember"] = { limit = 10, window = 60 },
		["Save.RegenerateCode"] = { limit = 3, window = 60 },
		["Save.SetSize"] = { limit = 5, window = 60 },
	},
}

local validSizes = { Small = true, Medium = true, Large = true }

-- OBSERVED supplier row order, which is also the unlock order of the starter species
-- (docs/REFERENCE_GAME_LIVE_TEST.md §4.1). Every key of GameConfig.Trees appears here once.
GameConfig.SpeciesOrder = { "DouglasFir", "FrasierFir", "NobleFir", "BlueSpruce" }

GameConfig.Trees = {
	-- Wholesale per species and size and the rarity are OBSERVED (docs/REFERENCE_GAME_LIVE_TEST.md §4.1).
	-- typicalMedium and initialMediumPrice are PROVISIONAL until CM2-G7 (benchmark = wholesale x 5).
	-- Species IDs are stable save keys: "FrasierFir" keeps its ID; only the display name is "Fraser Fir".
	DouglasFir = {
		displayName = "Douglas Fir",
		rarity = "Common",
		evidence = GameConfig.Evidence.Observed,
		wholesale = { Small = 21, Medium = 28, Large = 41 },
		typicalMedium = 70,
		initialMediumPrice = 72,
	},
	FrasierFir = {
		displayName = "Fraser Fir",
		rarity = "Uncommon",
		evidence = GameConfig.Evidence.Observed,
		wholesale = { Small = 24, Medium = 32, Large = 46 },
		typicalMedium = 80,
		initialMediumPrice = 82,
	},
	NobleFir = {
		displayName = "Noble Fir",
		rarity = "Rare",
		evidence = GameConfig.Evidence.Observed,
		wholesale = { Small = 28, Medium = 37, Large = 54 },
		typicalMedium = 92,
		initialMediumPrice = 96,
	},
	BlueSpruce = {
		displayName = "Blue Spruce",
		rarity = "Uncommon",
		evidence = GameConfig.Evidence.Observed,
		wholesale = { Small = 32, Medium = 42, Large = 61 },
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

-- Customer cars, parking and order pickup (docs/REFERENCE_GAME_LIVE_TEST.md §3).
GameConfig.Customers = {
	-- OBSERVED: parking tier 1 holds 2 customer cars.
	BaseParkingSpaces = 2,
	-- PROVISIONAL: how long a paid customer waits at the car for the tree.
	PickupPatienceSeconds = 120,
	-- PROVISIONAL: loading within this many seconds counts as fast service.
	FastLoadSeconds = 30,
	-- OBSERVED shape (+6 slow / +9 fast); scaled to this game's reputation curve.
	SlowLoadReputation = 1,
	FastLoadReputation = 2,
	MissedPickupReputationPenalty = 1,
	-- PROVISIONAL: a hired Lot Worker needs this long to carry a tree to the car.
	WorkerLoadSeconds = 15,
	-- Server-side reach check for carry/load interactions, in studs.
	InteractDistance = 16,
	MaxOpenCustomerOrders = 8,
}

-- Receiving bays hold delivered stock until it is stocked onto the lot.
GameConfig.Receiving = {
	BayCount = 4, -- OBSERVED
	BayCapacity = 9, -- INFERRED from the "x / 9 free" order panel
	BaseStorage = 30, -- OBSERVED starter-lot delivery storage
	StoragePerLotExpansion = 10, -- OBSERVED (+10 for expansion 1)
}

-- Finite supplier stock that refreshes on a timer (docs/REFERENCE_GAME_LIVE_TEST.md §4.1).
GameConfig.Supplier = {
	RefreshSeconds = 240, -- OBSERVED ~4 minutes
	BaseStock = { Small = 15, Medium = 12, Large = 7 }, -- OBSERVED typical availability
	StockVariance = 0.3, -- PROVISIONAL
	HighDemandChance = 0.25, -- PROVISIONAL
	LowDemandChance = 0.1, -- PROVISIONAL
	SellBackFraction = 0.25, -- OBSERVED
	RecommendedPerSpecies = { Small = 1, Medium = 2 }, -- OBSERVED recommended-order shape
}

-- OBSERVED size ranges in tenths of a foot; each displayed tree gets a stable height inside its range.
GameConfig.TreeHeightTenths = {
	Small = { min = 50, max = 60 },
	Medium = { min = 70, max = 80 },
	Large = { min = 90, max = 100 },
}

-- Offsets from the plot centre. The lot ground is 80 x 54 studs (WorldService), so
-- the bounds keep displayed trees on the owner's lot instead of neighbouring land.
GameConfig.Placement = {
	MinX = -38,
	MaxX = 38,
	MinY = -2,
	MaxY = 5,
	MinZ = -25,
	MaxZ = 25,
	MinRotation = 0,
	MaxRotationExclusive = 360,
}

return GameConfig
