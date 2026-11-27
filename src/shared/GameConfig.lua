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
-- Quest board per save (CM2-G11, docs/archive/plans/CM2-G11.md, shared/QuestBoard.lua): 3 rotating
-- quests plus a bonus. Non-observed variants (15, 20, 2000, 3500, Medium 3, Large 2) are
-- PROVISIONAL; rewardReputation absent = 0.
GameConfig.Quests = {
	RotationSeconds = 14400, -- OBSERVED about 4 h ("New quests in 3h 55m"); exact length PROVISIONAL
	MaxProgress = 1000000000,
	Slots = {
		{
			{ kind = "OrderTrees", target = 10, rewardCash = 150 }, -- OBSERVED
			{ kind = "OrderTrees", target = 15, rewardCash = 150 },
			{ kind = "OrderTrees", target = 20, rewardCash = 150 },
		},
		{
			{ kind = "SalesCash", target = 2800, rewardCash = 150 }, -- OBSERVED
			{ kind = "SalesCash", target = 2000, rewardCash = 150 },
			{ kind = "SalesCash", target = 3500, rewardCash = 150 },
		},
		{
			{ kind = "SellSize", sizeId = "Small", target = 3, rewardCash = 150 }, -- OBSERVED
			{ kind = "SellSize", sizeId = "Medium", target = 3, rewardCash = 150 },
			{ kind = "SellSize", sizeId = "Large", target = 2, rewardCash = 150 },
		},
	},
	Bonus = { kind = "SellTrees", target = 15, rewardCash = 550, rewardReputation = 100 }, -- OBSERVED
}

-- Daily reward streak per player (CM2-G11, shared/DailyRewards.lua), paid into the active save.
GameConfig.DailyRewards = {
	Days = { -- OBSERVED (REFERENCE_GAME_LIVE_TEST §1.3)
		{ cash = 400, reputation = 0 },
		{ cash = 500, reputation = 0 },
		{ cash = 0, reputation = 150 },
		{ cash = 700, reputation = 0 },
		{ cash = 900, reputation = 0 },
		{ cash = 0, reputation = 300 },
		{ cash = 2500, reputation = 0 },
	},
	DaySeconds = 86400, -- UTC day (DECISION_LOG 2026-11-21)
	GroupId = 0, -- supplied by the owner; 0 hides the group bonus
	GroupMultiplier = 2, -- OWNER DECIDED (PRODUCT_SPEC "2x daily rewards")
	ClaimLimit = { limit = 5, window = 60 }, -- PROVISIONAL
	RefreshSeconds = 30, -- PROVISIONAL attribute refresh
}
-- Advent calendar per player (CM2-A1, docs/plans/CM2-A1.md, shared/AdventCalendar.lua): one
-- door per UTC day Dec 1-24, missed doors until Dec 24, each paid once into the active save.
GameConfig.Advent = {
	Month = 12,
	LastDay = 24, -- OWNER DECIDED (PRODUCT_SPEC): Dec 1-24, server UTC date
	OpenLimit = { limit = 24, window = 60 }, -- PROVISIONAL: a late joiner opens all 24
	RefreshSeconds = 30,
	DecorMaxCount = 999,
	DecorItems = {
		"AdventWreath",
		"AdventStarLantern",
		"AdventCandyLamp",
		"AdventSnowman",
		"AdventGingerbreadHut",
		"AdventReindeerSleigh",
	},
	Doors = { -- PROVISIONAL; specials Dec 6, Dec 24
		{ cash = 500 },
		{ reputation = 100 },
		{ cash = 750 },
		{ boostSeconds = 900 },
		{ decor = "AdventWreath" },
		{ cash = 3000, reputation = 250, decor = "AdventStarLantern" },
		{ cash = 1000 },
		{ reputation = 200 },
		{ cash = 1250 },
		{ boostSeconds = 1200 },
		{ decor = "AdventCandyLamp" },
		{ cash = 1500 },
		{ reputation = 300 },
		{ cash = 1750 },
		{ boostSeconds = 1800 },
		{ decor = "AdventSnowman" },
		{ cash = 2000 },
		{ reputation = 400 },
		{ cash = 2500 },
		{ boostSeconds = 2400 },
		{ decor = "AdventGingerbreadHut" },
		{ cash = 3000 },
		{ reputation = 500 },
		{ cash = 10000, reputation = 1000, decor = "AdventReindeerSleigh" },
	} :: { { cash: number?, reputation: number?, boostSeconds: number?, decor: string? } },
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
		-- Plot picker (CM2-PP, PROVISIONAL, same as Save.List).
		["Save.Plots"] = { limit = 20, window = 10 },
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

-- Early-lot demand (CM2-SALE2), all PROVISIONAL (PRODUCT_SPEC "demand tuned later", GAME_DESIGN §4/§5).
-- Interest: how much a customer wants a tree by how it matches its preferred species and size.
-- Variety: VarietySingle with one displayed species, rising linearly to 1 at VarietyFullSpecies.
-- Stock: StockBase with no unreserved tree, rising linearly to 1 at AutoPricing.TargetDisplayStock.
GameConfig.Demand = {
	Interest = { Exact = 1, SameSpecies = 0.85, SameSize = 0.75, Other = 0.65 },
	VarietySingle = 0.85,
	VarietyFullSpecies = 3,
	StockBase = 0.6,
}

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
	-- Employees a save may hire without an HQ (OBSERVED "0 / 2 hired"); an HQ sets its own
	-- employeeCapacity (CM2-25/26 part b).
	BaseCapacity = 2,
	Cashier = { hireCost = 1200, role = "Checkout", maxCount = 1, evidence = GameConfig.Evidence.Observed },
	LotWorker = {
		hireCost = 1800,
		role = "DeliveryStockingLoading",
		maxCount = 1,
		evidence = GameConfig.Evidence.Observed,
	},
	-- CM2-25/26: hireable at HQ 4 since CM2-G9a; avatar and computer job come with CM2-G9c.
	LotManager = {
		hireCost = 1250000,
		role = "OrderingAtComputer",
		maxCount = 1,
		requiredHqTier = 4,
		evidence = GameConfig.Evidence.Observed,
	},
}

-- Visible staff at work, energy and the break area (CM2-25/26, docs/archive/plans/CM2-25-26a.md). All
-- values are PROVISIONAL unless marked. Points are in the lot frame (x from the plot centre, z
-- toward the road). No wages: staff cost only the one-time hire.
GameConfig.Staff = {
	Roles = { "Cashier", "LotWorker", "LotManager" }, -- index = rest seat
	WorkingRoles = { "Cashier", "LotWorker" },
	-- The Lot Worker's carrier ID on customer orders; Roblox UserIds are >= 1 live, Studio test
	-- players <= -1 and the playtest shadows 999999999001/2.
	CarrierUserId = 0,
	MaxPerPlot = 3,
	MaxPerServer = 18, -- = 6 plots x 3
	TickSeconds = 0.25,
	EnergySaveSeconds = 15,
	RespawnSeconds = 5,
	RestMaxSeconds = 60,
	-- "Gentle" fatigue: work ~6.7 min, break ~40 s plus walks.
	Energy = { Max = 100, DrainPerSecond = 0.2, RestPerSecond = 2, TiredAt = 20, RestedAt = 100 },
	VacatedSpotCap = 20,
	LotWorkerPost = { x = 26, z = 5 }, -- faces { x = 0, z = 5 }
	BayApproachX = 26.5, -- bay z = -22 + 6 (i - 1) (WorldService BAY_FIRST_DEPTH / BAY_DEPTH_STEP)
	Pickup = { FirstX = 23, Step = 4.5, ApproachZ = 9 }, -- WorldService pickup row x 23 + 4.5 (space - 1), z 13
	-- Square HalfSize * 2 on a side; Logs and RestPoints in the area frame.
	BreakArea = {
		HalfSize = 4,
		Candidates = { { x = -32, z = -20 }, { x = -32, z = -4 }, { x = 25.5, z = -22 }, { x = -32, z = 4 } },
		Logs = { { x = 0, z = 2.4 }, { x = -2.4, z = 0 }, { x = 2.4, z = 0 } },
		RestPoints = { { x = 0, z = 3.6 }, { x = -3.6, z = 0 }, { x = 3.6, z = 0 } },
	},
	-- Uniform in our palette (ArtPalette RoofGreen, MetalDark, GoldAccent, FabricCream, RoofRed).
	Uniform = {
		Coat = { 58, 104, 88 },
		Pants = { 52, 58, 64 },
		Scarf = { 214, 170, 72 },
		Apron = { 232, 220, 196 },
		Boots = { 78, 50, 32 },
		Skin = { 234, 184, 146 },
		Beanie = { Cashier = { 214, 170, 72 }, LotWorker = { 170, 46, 46 }, LotManager = { 52, 58, 64 } },
	},
}

-- Progression ladder (CM2-G9a, docs/archive/plans/CM2-G9a.md): lot expansion, parking and HQ tiers.
-- O = OBSERVED (REFERENCE_GAME_LIVE_TEST §4.4/§4.5), P = PROVISIONAL; unmarked values are P.
local O, P = GameConfig.Evidence.Observed, GameConfig.Evidence.Provisional
GameConfig.Progression = {
	-- Index = level bought; level 0 is the Starter Lot (O). Each level adds
	-- Placement.BackDepthPerLevel of depth and Receiving.StoragePerLotExpansion storage.
	LotExpansion = {
		maxLevel = 6,
		levels = {
			{ id = "BackLot", cashCost = 1200, requiredReputation = 0, requiredHqLevel = 1, evidence = O },
			{ id = "SpruceCorner", cashCost = 5000, requiredReputation = 400, requiredHqLevel = 2, evidence = P },
			{ id = "WoodlandEdge", cashCost = 15000, requiredReputation = 600, requiredHqLevel = 2, evidence = P },
			{ id = "PineClearing", cashCost = 100000, requiredReputation = 1200, requiredHqLevel = 3, evidence = P },
			{ id = "SnowyMeadow", cashCost = 250000, requiredReputation = 2000, requiredHqLevel = 3, evidence = P },
			{ id = "ForestGlade", cashCost = 1000000, requiredReputation = 3500, requiredHqLevel = 4, evidence = P },
		},
	},
	-- Tier 2 is the last: the car lane and Npc.MaxPerPlot hold 4 spaces.
	Parking = {
		maxTier = 2,
		maxSpaces = 4,
		tiers = {
			{ spaces = 2, cashCost = 0, requiredReputation = 0, evidence = O },
			{ spaces = 4, cashCost = 600, requiredReputation = 0, evidence = O },
		},
	},
	-- Footprints and heights are the CM2-13a art targets (lot frame), centred on the stand (-8, -4).
	-- Tiers 3 and 4 map the reference's "Christmas Market Chalet" and "Christmas Lodge" (costs unseen).
	HQ = {
		maxLevel = 4,
		tiers = {
			{
				id = "SalesTent",
				cashCost = 0,
				requiredReputation = 0,
				requiredLotExpansion = 0,
				requiredParkingTier = 1,
				newSpecies = 0,
				checkoutStations = 1,
				employeeCapacity = 2, -- O
				customerPatienceBonus = 0,
				unlocksLotManager = false,
				unlocksWorkshop = false,
				footprint = { minX = -18, maxX = 2, minZ = -11, maxZ = 3 },
				eave = 7.5,
				height = 10,
				evidence = O,
			},
			{
				id = "TimberPavilion",
				cashCost = 2500, -- O
				requiredReputation = 250, -- O
				requiredLotExpansion = 1, -- O
				requiredParkingTier = 2, -- O
				newSpecies = 4, -- O
				checkoutStations = 2, -- O
				employeeCapacity = 3, -- O
				customerPatienceBonus = 0.12, -- O
				unlocksLotManager = false,
				unlocksWorkshop = false,
				footprint = { minX = -20, maxX = 4, minZ = -13, maxZ = 5 },
				eave = 8,
				height = 13,
				evidence = O,
			},
			{
				id = "AlpineHut",
				cashCost = 50000,
				requiredReputation = 1000,
				requiredLotExpansion = 3,
				requiredParkingTier = 2,
				newSpecies = 4,
				checkoutStations = 2, -- O
				employeeCapacity = 5, -- O
				customerPatienceBonus = 0.20,
				unlocksLotManager = false,
				unlocksWorkshop = false,
				footprint = { minX = -22, maxX = 6, minZ = -14, maxZ = 6 },
				eave = 8.5,
				height = 16,
				evidence = P,
			},
			{
				id = "MountainChalet",
				cashCost = 600000,
				requiredReputation = 3000,
				requiredLotExpansion = 5,
				requiredParkingTier = 2,
				newSpecies = 4,
				checkoutStations = 3,
				employeeCapacity = 6,
				customerPatienceBonus = 0.30,
				unlocksLotManager = true,
				unlocksWorkshop = true,
				footprint = { minX = -23.8, maxX = 7.8, minZ = -15.8, maxZ = 7.8 },
				eave = 13,
				height = 20,
				evidence = P,
			},
		},
	},
	-- Content is "Coming soon" (PRODUCT_SPEC): no cost, no action.
	Workshop = {
		id = "ElfWorkshop",
		requiredHqLevel = 4,
		requiresLotManager = true,
		evidence = GameConfig.Evidence.OwnerDecided,
	},
}

-- Customer cars, parking and order pickup (docs/REFERENCE_GAME_LIVE_TEST.md §3).
GameConfig.Customers = {
	-- OBSERVED: parking tier 1 holds 2 customer cars.
	BaseParkingSpaces = 2,
	-- PROVISIONAL: how long a paid customer waits at the car for the tree.
	PickupPatienceSeconds = 120,
	-- OBSERVED by arithmetic (REFERENCE header table)
	SaleReputation = 0,
	MissedPickupReputationPenalty = 1,
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
		QueuePatienceSeconds = 90, -- from entering Queued (CM2-N2); reference walk-out time not measured
		CashierCheckoutSeconds = 3, -- a hired Cashier serves the counter after this long (CM2-N2)
		CheckoutMinIntervalSeconds = 0.25, -- per-player checkout prompt interval (CM2-N2)
		WaitAtCarExtraSeconds = 10,
		DepartSeconds = 2.5,
		MaxVisitSeconds = 360,
		ReservationSeconds = 165, -- >= 20 + 1 + 20 + 117 + 3 = 161 with the HQ 4 patience (CM2-G9a)
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
			QueueSpacing = 3.5, -- slots z -11, -7.5, -4, -0.5 (CM2-N2, CM2-UVF3)
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

-- Day/night per save (CM2-G12a, docs/archive/plans/CM2-G12a.md): an 18-minute game day that runs only
-- while the save is loaded (shared/DayCycle.lua).
GameConfig.DayCycle = {
	DaySeconds = 720, -- OWNER DECIDED
	NightSeconds = 360, -- OWNER DECIDED
	DayStartClockTime = 6, -- PROVISIONAL
	NightStartClockTime = 18, -- PROVISIONAL
	NightArrivalRate = 0.5, -- PROVISIONAL
	TwilightSeconds = 30, -- PROVISIONAL
	TickSeconds = 1,
	MaxTickSeconds = 5, -- a longer server hitch counts as 5 s
	SyncSeconds = 30,
	ClientUpdateSeconds = 0.5,
	DefaultClockTime = 14, -- PROVISIONAL: a player without an active save
	NightOutdoorAmbient = { 70, 80, 110 }, -- PROVISIONAL
	NightLightTag = "NightLight",
	LampLight = { range = 16, brightness = 1.5 }, -- PROVISIONAL
	PlotLight = { range = 14, brightness = 1.2 }, -- PROVISIONAL
	GateLight = { range = 12, brightness = 1.2 }, -- PROVISIONAL (CM2-GATEW)
}

-- Four leaderboards on the village square (CM2-G12b, docs/archive/plans/CM2-G12b.md): OrderedDataStore
-- writes from a server cache (server/Services/LeaderboardService.lua).
GameConfig.Leaderboards = {
	Keys = { "CashEarned", "Reputation", "HoursPlayed", "RobuxSpent" }, -- OWNER DECIDED (boards; write/read order)
	PerSave = { CashEarned = true, Reputation = true },
	StoreFormat = "ChristmasMarket2_LB_%s_v1",
	StudioSuffix = "_Studio",
	TopCount = 10, -- OBSERVED (REFERENCE §8)
	RankDepth = 100, -- one page
	WriteIntervalSeconds = 120, -- PROVISIONAL
	MaxWritesPerFlush = 24,
	MinWriteBudget = 10,
	ReadIntervalSeconds = 180, -- PROVISIONAL
	FirstReadDelaySeconds = 5,
	PlaytimeTickSeconds = 10,
	NameMaxLength = 32,
}

-- Customer reviews, rating and likes (CM2-G15, docs/REFERENCE_GAME_LIVE_TEST.md §3.7).
GameConfig.Reviews = {
	-- PROVISIONAL: service seconds (queue + pickup) for 5, 4, 3 and 2 stars; slower is 1 star.
	StarMaxSeconds = { 30, 50, 75, 105 },
	-- Reputation by stars (index = stars): 3 stars = 6 OBSERVED, 5 stars = 9 INFERRED, rest PROVISIONAL.
	ReputationByStars = { 2, 4, 6, 8, 9 },
	RatingWindow = 50, -- PROVISIONAL
	MaxQueueSeconds = 3600, -- technical bound
	MaxLikesPerDay = 100, -- PROVISIONAL: distinct likers per lot per day
	LikeLimit = { limit = 5, window = 60 }, -- PROVISIONAL, per player
	-- PROVISIONAL: lot sign position in the lot frame.
	SignX = 23,
	SignZ = 23,
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
	MaxCartLines = 12, -- PROVISIONAL: species x sizes
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
	BackDepthPerLevel = 8, -- PROVISIONAL (CM2-G9a): 6 levels x 8 = the map reserve to depth -75
	FootprintRadius = { Small = 2.1, Medium = 2.8, Large = 3.5 }, -- display scales 0.6/0.8/1.0 x 7-stud needles
	SpacingTolerance = 0.01,
	RotationStep = 45, -- PROVISIONAL
	Gap = { Default = 0.5, Min = 0, Max = 4, Step = 0.5 }, -- Default OBSERVED ("GAP 0.5"), range PROVISIONAL
	RowMax = 10, -- PROVISIONAL
	CoordinateLimit = 200, -- protocol sanity bound
	KeepClear = { -- PROVISIONAL, lot frame {minX, maxX, minZ, maxZ}
		{ id = "Stand", minX = -24, maxX = 8, minZ = -16, maxZ = 8 }, -- every HQ tier (G3, CM2-G9a)
		{ id = "Checkout", minX = 11, maxX = 21, minZ = -18, maxZ = 1 }, -- counter, staff side, queue to slot 4 (CM2-N2)
		{ id = "Parking", minX = -29, maxX = 17, minZ = 13, maxZ = 27 }, -- 4 spaces
		{ id = "Pickup", minX = 20, maxX = 39, minZ = 10, maxZ = 16 }, -- G1 pickup row
		{ id = "Spawn", minX = -31, maxX = -25, minZ = 11, maxZ = 17 },
		{ id = "Bays", minX = 30, maxX = 40, minZ = -26, maxZ = 0 },
		{ id = "Sign", minX = 18, maxX = 28, minZ = 21, maxZ = 25 }, -- lot sign (CM2-G15)
	},
	StandFitMargin = 0.1, -- PROVISIONAL (CM2-G9a A1): HQ art fits KeepClear Stand minus this per side
	-- decorative fences, lot frame (CM2-13W: FenceRail8 + FencePost art, FenceWooden fallback);
	-- the right one gave way to the gate (CM2-GATEW)
	DecorFences = { { x = -34, z = 24 } },
	DecorFenceRadius = 5.5, -- covers the 8.6 x 0.6 art and the 10.28 x 0.34 FenceWooden fallback from its centre at any yaw
}

return GameConfig
