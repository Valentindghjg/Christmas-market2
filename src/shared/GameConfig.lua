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
-- Background music (CM2-MUSIC, docs/plans/CM2-MUSIC.md, docs/AUDIO.md, shared/MusicSettings.lua):
-- Christmas tracks from Roblox's licensed music library in a loop and a saved per-player music
-- volume. TrackIds OWNER DECIDED; every other value PROVISIONAL.
GameConfig.Music = {
	-- OWNER DECIDED 2026-11-28; provenance docs/AUDIO.md
	TrackIds = { 9047801895, 140169923347660, 119871365837884, 1838667168 } :: { number },
	DefaultVolume = 0.5,
	TrackVolume = 0.5, -- per Sound; heard = TrackVolume x setting
	VolumeStep = 0.1,
	FadeInSeconds = 3,
	FadeOutSeconds = 3,
	GapSeconds = 2,
	GroupTweenSeconds = 0.25,
	SettingWaitSeconds = 10,
	SendDebounceSeconds = 0.75,
	SetLimit = { limit = 6, window = 30 },
}
-- Falling snow around the camera (CM2-V2-SNOW, client/Snow.client.lua). All PROVISIONAL.
GameConfig.Snow = {
	Enabled = true,
	Rate = 60, -- particles per second
	MaxParticles = 600, -- budget: Rate x LifetimeMax must stay within it
	LifetimeMin = 5,
	LifetimeMax = 7,
	SpeedMin = 5,
	SpeedMax = 8,
	Size = 0.25,
	Transparency = 0.1,
	AreaSize = 90, -- studs, square
	HeightAbove = 30, -- studs over the camera
	MinQualityLevel = 4, -- graphics quality 1 to 3 turns snow off
	Texture = "rbxasset://textures/particles/sparkles_main.dds",
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
-- HQ level -> required parking tier. PROVISIONAL, owner to confirm (DECISION_LOG 2026-11-28 amendment); change only this line.
local HQ_PARKING_GATE = { 1, 2, 3, 4 }
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
	-- OWNER DECIDED 2026-11-28 (CM2-PARK): one space per tier; tier 4 is the last (Npc.MaxPerPlot is 4).
	Parking = {
		maxTier = 4,
		maxSpaces = 4,
		tiers = {
			{ spaces = 1, cashCost = 0, requiredReputation = 0, evidence = GameConfig.Evidence.OwnerDecided },
			{ spaces = 2, cashCost = 400, requiredReputation = 0, evidence = GameConfig.Evidence.OwnerDecided },
			{ spaces = 3, cashCost = 1200, requiredReputation = 0, evidence = GameConfig.Evidence.OwnerDecided },
			{ spaces = 4, cashCost = 4200, requiredReputation = 0, evidence = GameConfig.Evidence.OwnerDecided },
		},
	},
	HqParkingGate = HQ_PARKING_GATE,
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
				requiredParkingTier = HQ_PARKING_GATE[1], -- P
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
				requiredParkingTier = HQ_PARKING_GATE[2], -- P
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
				requiredParkingTier = HQ_PARKING_GATE[3], -- P
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
				requiredParkingTier = HQ_PARKING_GATE[4], -- P
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
	-- OWNER DECIDED 2026-11-28 (CM2-PARK): parking tier 1 holds 1 customer car (replaces the observed 2).
	BaseParkingSpaces = 1,
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
		CounterClearance = 1.5, -- keeps queue slot 1 (z 19.5) outside the counter box (maxZ 17.5)
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
			StaffDepth = 14, -- the cashier behind the counter (CM2-LOTLAY: counter at the HQ front)
			-- CM2-LOTLAY (PROVISIONAL): the queue is an L toward the gate; slot 1 = art Checkout1
			QueueSlots = { { x = -14, z = 19.5 }, { x = -14, z = 23 }, { x = -10.5, z = 23 }, { x = -7, z = 23 } },
			EntryX = { -1.5, 1.5, -3.5, 3.5 }, -- the entry point inside the gate, per parking space
			EntryDepth = 20,
			ApproachGap = 0.8,
			Counter = { minX = -16.5, maxX = -11.5, minZ = 15.5, maxZ = 17.5 }, -- counter body 5 x 2 at (-14, 16.5), facing the road
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
	NightLightTag = "NightLight",
	LampLight = { range = 16, brightness = 1.5 }, -- PROVISIONAL
	PlotLight = { range = 14, brightness = 1.2 }, -- PROVISIONAL
	GateLight = { range = 12, brightness = 1.2 }, -- PROVISIONAL (CM2-GATEW)
}

-- Light and colour pass (CM2-VIBE1, docs/plans/CM2-VIBE1.md), all PROVISIONAL engineering look values.
-- Static + Day.Lighting + Day.CM2* mirror the `Lighting` node of default.project.json and
-- release.project.json (a headless check keeps them equal); the client blends Day -> Night through
-- shared/LightingBlend.lua by DayCycle.nightBlend. Colours are { r, g, b } 0-255.
GameConfig.Lighting = {
	EffectsMinQualityLevel = 4, -- quality 1-3: Bloom and SunRays off (as Snow)
	Classes = {
		CM2Atmosphere = "Atmosphere",
		CM2ColorCorrection = "ColorCorrectionEffect",
		CM2Bloom = "BloomEffect",
		CM2SunRays = "SunRaysEffect",
	},
	Static = {
		Technology = "Future",
		GlobalShadows = true,
		ShadowSoftness = 0.25,
		Brightness = 2.2,
		EnvironmentDiffuseScale = 0.6,
		EnvironmentSpecularScale = 0.4,
	},
	Day = {
		Lighting = {
			Ambient = { 90, 95, 110 },
			OutdoorAmbient = { 150, 145, 140 },
			ExposureCompensation = -0.15,
		},
		CM2Atmosphere = {
			Density = 0.25,
			Offset = 0.2,
			Color = { 222, 228, 238 },
			Decay = { 170, 190, 215 },
			Glare = 0.4,
			Haze = 1.2,
		},
		CM2ColorCorrection = {
			Brightness = 0.02,
			Contrast = 0.12,
			Saturation = 0.22,
			TintColor = { 255, 244, 230 },
		},
		CM2Bloom = { Intensity = 0.3, Size = 24, Threshold = 1.3 },
		CM2SunRays = { Intensity = 0.08, Spread = 0.6 },
	},
	Night = {
		Lighting = {
			Ambient = { 60, 70, 100 },
			OutdoorAmbient = { 70, 80, 110 },
			ExposureCompensation = 0.35,
		},
		CM2Atmosphere = {
			Density = 0.3,
			Offset = 0.15,
			Color = { 60, 70, 100 },
			Decay = { 40, 50, 80 },
			Glare = 0,
			Haze = 0.8,
		},
		CM2ColorCorrection = {
			Brightness = 0.04,
			Contrast = 0.08,
			Saturation = 0.05,
			TintColor = { 215, 225, 255 },
		},
		CM2Bloom = { Intensity = 0.7, Size = 28, Threshold = 0.9 },
		CM2SunRays = { Intensity = 0, Spread = 0.6 },
	},
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
	RecentOrders = 4, -- PROVISIONAL: order rows shown and Delivered entries kept per session (4 bays)
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
		{ id = "Checkout", minX = -18, maxX = -5.5, minZ = 13, maxZ = 25 }, -- counter, staff side, queue L (CM2-LOTLAY)
		{ id = "Gate", minX = -5.5, maxX = 5.5, minZ = 13, maxZ = 27 }, -- the entrance path from the gate (CM2-LOTLAY)
		{ id = "Pickup", minX = 20, maxX = 39, minZ = 10, maxZ = 16 }, -- G1 pickup row
		{ id = "Spawn", minX = -31, maxX = -25, minZ = 11, maxZ = 17 },
		{ id = "Bays", minX = 30, maxX = 40, minZ = -26, maxZ = 0 },
		{ id = "Sign", minX = 18, maxX = 28, minZ = 21, maxZ = 25 }, -- lot sign (CM2-G15)
	},
	StandFitMargin = 0.1, -- PROVISIONAL (CM2-G9a A1): HQ art fits KeepClear Stand minus this per side
	-- CM2-LOTLAY (PROVISIONAL): the centred gate in the front fence (lot frame x, post centre from the pivot)
	Gate = { X = 0, PostX = 8.9, PostHalf = 0.75 },
	FrontApronDepth = 8, -- the NPC router may walk up to LotHalfDepth + this (z 35)
	-- Customer parking outside the front fence (CM2-LOTLAY); CM2-PARK/TRAFFIC read only this table.
	-- Space 1 is nearest the gate; X per space, Depth = pad centre, DoorDepth = the car door.
	-- CM2-PARK Amendment 1 (owner: 2 spaces left of the gate, 2 right; positions PROVISIONAL):
	-- spaces 1/3 left inner/outer, 2/4 right; the corridor x -10..10 in front of the gate stays free.
	CarPark = {
		X = { -13.5, 13.5, -22.5, 22.5 },
		Depth = 40,
		PadWidth = 7, -- car body 4.6
		PadLength = 12,
		DoorOffsetX = 3.5,
		DoorDepth = 33,
		Apron = { minX = -26, maxX = 26, minDepth = 27, maxDepth = 59 },
		-- PROVISIONAL (CM2-PARK): inside the inflated gate-fence obstacles, so no NPC route passes,
		-- and fence-side of the pads, so no car.
		Fixtures = { Sign = { x = -21.5, z = 30.5 }, Lamps = { { x = -13.5, z = 30.5 }, { x = 13.5, z = 30.5 } } },
	},
	-- decorative fences, lot frame (CM2-13W); none since CM2-LOTLAY (the fence runs are the front runs)
	DecorFences = {},
	DecorFenceRadius = 5.5, -- covers the 8.6 x 0.6 art and the 10.28 x 0.34 FenceWooden fallback from its centre at any yaw
}

-- Snow emission rate for a graphics quality level (0 = Automatic counts as full; 1 to 3 is off).
function GameConfig.snowRate(qualityLevel: number): number
	local snow = GameConfig.Snow
	if not snow.Enabled or (qualityLevel >= 1 and qualityLevel < snow.MinQualityLevel) then
		return 0
	end
	return snow.Rate
end

return GameConfig
