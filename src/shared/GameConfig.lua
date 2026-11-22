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
GameConfig.DeliverySeconds = 30 -- OBSERVED: actual ETA 25–31 s (REFERENCE §3.2); was 60 PROVISIONAL
-- Persistence cadence. Mutations only mark a session dirty; a flush writes dirty
-- sessions at most once per SaveFlushSeconds, and every session is re-saved at
-- least once per AutosaveSeconds to renew its lock. If no save has succeeded for
-- SaveFailClosedSeconds the session stops accepting mutations, well before
-- another server could take over the SessionLockSeconds lock.
GameConfig.SaveFlushSeconds = 15
GameConfig.AutosaveSeconds = 60
GameConfig.SessionLockSeconds = 120
GameConfig.SaveFailClosedSeconds = 90
-- Final save on unload (CM2-R5, PROVISIONAL). A failed final save is retried after each
-- delay in turn (8 attempts, 78 s of waits), never past SaveFailClosedSeconds after the
-- unload began, and never past ShutdownSeconds after shutdown began (BindToClose waits 25 s).
GameConfig.UnloadRetry = {
	DelaysSeconds = { 2, 4, 8, 16, 16, 16, 16 },
	ShutdownSeconds = 18,
}
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
	-- Save-to-server map (CM2-S3, PROVISIONAL): a MemoryStore HashMap entry per played save.
	-- The TTL stays below SessionLockSeconds; renewal every 30 s tolerates two misses.
	LocatorTtlSeconds = 90,
	LocatorRenewSeconds = 30,
	LocatorReleasedTtlSeconds = 30,
	LocatorAttempts = 2,
	LocatorListLookups = 8,
	LocatorCacheSeconds = 15,
	LocatorMapName = "CM2_SaveServers_v1",
	-- Teammate finder (CM2-S3): the size of a save created by a search.
	FinderDefaultSize = "Duo",
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
		-- Cross-server join and teammate finder (CM2-S3).
		["Save.Teleport"] = { limit = 3, window = 60 },
		["Save.FinderStart"] = { limit = 3, window = 300 },
		["Save.FinderStop"] = { limit = 5, window = 60 },
		["Save.FinderList"] = { limit = 20, window = 10 },
		["Save.FinderJoin"] = { limit = 5, window = 60 },
	},
}

local validSizes = { Small = true, Medium = true, Large = true }

-- Price benchmark and pricing panel (CM2-G7, docs/REFERENCE_GAME_LIVE_TEST.md §4.3).
GameConfig.Pricing = {
	BenchmarkMultiplier = 5, -- OBSERVED for Douglas, Fraser and Blue Spruce (exactly 5 x medium wholesale); PROVISIONAL extrapolation for species without an observed card
	-- OBSERVED typical medium prices that differ from the 5 x rule (REFERENCE_GAME_LIVE_TEST §4.3, CM2-G7a).
	TypicalMediumOverride = { NobleFir = 184 } :: { [string]: number },
	Steps = { -5, -1, 1, 5 }, -- OBSERVED price buttons
	SentimentPercent = { Bargain = 85, Fair = 110, Pricey = 130 }, -- PROVISIONAL, above Pricey = TooHigh
	BudgetPercent = { Min = 85, Max = 155 }, -- PROVISIONAL customer budget vs the size benchmark
}

-- OBSERVED supplier row order, which is also the unlock order of the starter species
-- (docs/REFERENCE_GAME_LIVE_TEST.md §4.1). Every key of GameConfig.Trees appears here once.
GameConfig.SpeciesOrder = { "DouglasFir", "FrasierFir", "NobleFir", "BlueSpruce" }

GameConfig.Trees = {
	-- Wholesale per species and size and the rarity are OBSERVED (docs/REFERENCE_GAME_LIVE_TEST.md §4.1).
	-- The typical retail price: GameConfig.typicalMediumFor (5 x medium wholesale, or an OBSERVED override; CM2-G7, CM2-G7a).
	-- Species IDs are stable save keys: "FrasierFir" keeps its ID; only the display name is "Fraser Fir".
	DouglasFir = {
		displayName = "Douglas Fir",
		rarity = "Common",
		evidence = GameConfig.Evidence.Observed,
		wholesale = { Small = 21, Medium = 28, Large = 41 },
	},
	FrasierFir = {
		displayName = "Fraser Fir",
		rarity = "Uncommon",
		evidence = GameConfig.Evidence.Observed,
		wholesale = { Small = 24, Medium = 32, Large = 46 },
	},
	NobleFir = {
		displayName = "Noble Fir",
		rarity = "Rare",
		evidence = GameConfig.Evidence.Observed,
		wholesale = { Small = 28, Medium = 37, Large = 54 },
	},
	BlueSpruce = {
		displayName = "Blue Spruce",
		rarity = "Uncommon",
		evidence = GameConfig.Evidence.Observed,
		wholesale = { Small = 32, Medium = 42, Large = 61 },
	},
}

function GameConfig.isValidSize(size: unknown): boolean
	return type(size) == "string" and validSizes[size] == true
end

function GameConfig.typicalMediumFor(speciesId: unknown): number?
	if type(speciesId) ~= "string" then
		return nil
	end
	local tree = GameConfig.Trees[speciesId]
	if not tree then
		return nil
	end
	local override = GameConfig.Pricing.TypicalMediumOverride[speciesId]
	if override ~= nil then
		return override
	end
	return tree.wholesale.Medium * GameConfig.Pricing.BenchmarkMultiplier
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
	-- Walking customer NPCs (CM2-N1). All values are PROVISIONAL unless marked. Every point
	-- is in the lot frame (x from the plot centre, z toward the road).
	Npc = {
		MaxPerPlot = 4, -- = Progression.Parking.maxSpaces
		MaxPerServer = 24, -- = 6 plots x 4
		ArrivalIntervalSeconds = 5,
		TickSeconds = 0.2,
		WalkSpeed = 10,
		ArriveRadius = 1.5,
		ReissueSeconds = 2,
		Clearance = 3, -- Fix round 1: covers the ~2.1-stud half-width of a scaled R15 avatar
		CounterClearance = 1.5, -- keeps queue slot 1 (z -11) outside the counter box (maxZ -11.5)
		CornerRadius = 1, -- intermediate waypoints advance within this radius (Fix round 1)
		CarArriveSeconds = 2.5,
		LegTimeoutSeconds = 20,
		BrowseSeconds = 6,
		PickUpSeconds = 1,
		QueuePatienceSeconds = 60,
		AutoCheckoutSeconds = 3,
		WaitAtCarExtraSeconds = 10,
		DepartSeconds = 2.5,
		MaxVisitSeconds = 360,
		ReservationSeconds = 120,
		ThanksSeconds = 3, -- the "Thanks so much!" text is OBSERVED
		LoadSeconds = 60, -- default length of a load-test run (Amendment 1)
		Path = {
			ParkingFirstX = -24,
			ParkingStep = 12,
			ParkingDepth = 20,
			DoorOffsetX = 3.5,
			AisleDepth = 12, -- Fix round 1: the inflated Stand box ends at z 11
			QueueX = 16,
			QueueFirstDepth = -11,
			QueueSpacing = 2.2,
			StaffDepth = -16.5,
			ApproachGap = 0.8,
			Counter = { minX = 13.5, maxX = 18.5, minZ = -15, maxZ = -13 }, -- counter body 5 x 2 at (16, -14)
		},
		Look = { -- RGB, own palette
			Skin = { { 255, 220, 190 }, { 234, 184, 146 }, { 198, 140, 98 }, { 141, 94, 62 }, { 96, 64, 44 } },
			Coat = {
				{ 170, 46, 46 },
				{ 46, 107, 69 },
				{ 57, 96, 150 },
				{ 214, 170, 72 },
				{ 122, 78, 44 },
				{ 232, 220, 196 },
				{ 88, 60, 120 },
			},
			Pants = { { 52, 58, 64 }, { 70, 70, 76 }, { 40, 52, 84 }, { 96, 72, 52 } },
			Scarf = { { 226, 222, 210 }, { 170, 46, 46 }, { 46, 107, 69 }, { 214, 170, 72 }, { 57, 96, 150 } }, -- also mittens
			Beanie = { { 170, 46, 46 }, { 240, 244, 248 }, { 46, 107, 69 }, { 57, 96, 150 }, { 214, 170, 72 } },
			Boots = { 78, 50, 32 },
			Scales = { 0.92, 0.96, 1.0, 1.04 },
		},
		-- Roblox's first-party default R15 animations.
		Animations = { Walk = "rbxassetid://507777826", Idle = "rbxassetid://507766388" },
		CollisionGroups = {
			Npc = "CustomerNpc",
			Tree = "LotTree",
			Player = "PlayerCharacter",
			Structure = "LotStructure", -- stand, counter and receiving bays (Fix round 1)
		},
	},
}

-- Receiving bays hold delivered stock until it is stocked onto the lot.
GameConfig.Receiving = {
	BayCount = 4, -- OBSERVED
	BayCapacity = 9, -- INFERRED from the "x / 9 free" order panel
	BaseStorage = 30, -- OBSERVED starter-lot delivery storage
	StoragePerLotExpansion = 10, -- OBSERVED (+10 for expansion 1)
	-- CM2-G14: deliveries land in their bay by themselves at dueAt.
	DeliveryPassSeconds = 1, -- PROVISIONAL
	TruckPullInSeconds = 5, -- PROVISIONAL, visual
	TruckLeaveSeconds = 3, -- PROVISIONAL, visual
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

-- Stocking spots in the lot frame (CM2-G14): x is the offset from the plot centre, z the
-- depth toward the road (+ = toward the road). The lot ground is 80 x 54 studs (WorldService).
GameConfig.Placement = {
	LotHalfWidth = 40,
	LotHalfDepth = 27, -- the 80 x 54 LotGround
	BackDepthPerLevel = 6, -- PROVISIONAL until CM2-G9 (lot grows backwards)
	FootprintRadius = { Small = 2.1, Medium = 2.8, Large = 3.5 }, -- display scales 0.6/0.8/1.0 x 7-stud needles
	SpacingTolerance = 0.01,
	RotationStep = 45, -- PROVISIONAL
	Gap = { Default = 0.5, Min = 0, Max = 4, Step = 0.5 }, -- Default OBSERVED ("GAP 0.5"), range PROVISIONAL
	RowMax = 10, -- PROVISIONAL
	CoordinateLimit = 200, -- protocol sanity bound
	KeepClear = { -- PROVISIONAL, lot frame {minX, maxX, minZ, maxZ}
		{ id = "Stand", minX = -24, maxX = 8, minZ = -16, maxZ = 8 }, -- starter stand box (G3)
		{ id = "Checkout", minX = 11, maxX = 21, minZ = -18, maxZ = -4 }, -- counter, staff side, queue
		{ id = "Parking", minX = -29, maxX = 17, minZ = 13, maxZ = 27 }, -- 4 spaces
		{ id = "Pickup", minX = 20, maxX = 39, minZ = 10, maxZ = 16 }, -- G1 pickup row
		{ id = "Spawn", minX = -31, maxX = -25, minZ = 11, maxZ = 17 },
		{ id = "Bays", minX = 30, maxX = 40, minZ = -26, maxZ = 0 },
	},
}

return GameConfig
