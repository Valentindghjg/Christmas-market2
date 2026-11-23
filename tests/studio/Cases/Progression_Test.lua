--!strict
-- CM2-G9a: the progression ladder (shared/Progression.lua): config and evidence tags, the purchase
-- check against the summary rows, single-level targets, the G19 footprint and fence clearance,
-- the Elf Workshop, the HQ queue patience and the schema 18 migration.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local GameConfig = require(Shared:WaitForChild("GameConfig"))
	local MapLayout = require(Shared:WaitForChild("MapLayout"))
	local Progression = require(Shared:WaitForChild("Progression"))
	local Services = game:GetService("ServerScriptService"):WaitForChild("Server"):WaitForChild("Services")
	local ProgressionService = require(Services:WaitForChild("ProgressionService"))
	local expect = t.expect

	local Config = GameConfig.Progression
	local Placement = GameConfig.Placement
	local BUY = {
		LotExpansion = ProgressionService.buyLotExpansion,
		Parking = ProgressionService.buyParking,
		HQ = ProgressionService.buyHQ,
	}
	local KINDS = { "LotExpansion", "Parking", "HQ" }

	local function deepCopy(value)
		if type(value) ~= "table" then
			return value
		end
		local copy = {}
		for key, inner in pairs(value) do
			copy[key] = deepCopy(inner)
		end
		return copy
	end

	type Box = { minX: number, maxX: number, minZ: number, maxZ: number }

	-- Positive penetration on both axes.
	local function overlaps(a: Box, b: Box): boolean
		return math.min(a.maxX, b.maxX) - math.max(a.minX, b.minX) > 0
			and math.min(a.maxZ, b.maxZ) - math.max(a.minZ, b.minZ) > 0
	end

	local function inside(inner: Box, outer: Box): boolean
		return inner.minX >= outer.minX
			and inner.maxX <= outer.maxX
			and inner.minZ >= outer.minZ
			and inner.maxZ <= outer.maxZ
	end

	local function around(x: number, z: number, halfX: number, halfZ: number): Box
		return { minX = x - halfX, maxX = x + halfX, minZ = z - halfZ, maxZ = z + halfZ }
	end

	local function circleHits(box: Box, x: number, z: number, radius: number): boolean
		local dx = math.max(box.minX - x, 0, x - box.maxX)
		local dz = math.max(box.minZ - z, 0, z - box.maxZ)
		return dx * dx + dz * dz < radius * radius
	end

	local function keepClear(id: string): Box
		for _, box in Placement.KeepClear do
			if box.id == id then
				return box
			end
		end
		error("no KeepClear box " .. id)
	end

	local function isEvidence(value: unknown): boolean
		for _, tag in pairs(GameConfig.Evidence) do
			if tag == value then
				return true
			end
		end
		return false
	end

	t.test("ladder config has 6 levels, 2 parking tiers and 4 HQ tiers with tags", function()
		expect.equal(Config.LotExpansion.maxLevel, 6)
		expect.equal(#Config.LotExpansion.levels, 6)
		expect.equal(Config.Parking.maxTier, 2)
		expect.equal(#Config.Parking.tiers, 2)
		expect.equal(Config.HQ.maxLevel, 4)
		expect.equal(#Config.HQ.tiers, 4)
		local lotIds = {}
		for _, level in Config.LotExpansion.levels do
			expect.truthy(isEvidence(level.evidence))
			table.insert(lotIds, level.id)
		end
		expect.equal(
			table.concat(lotIds, ","),
			"BackLot,SpruceCorner,WoodlandEdge,PineClearing,SnowyMeadow,ForestGlade"
		)
		for _, tier in Config.Parking.tiers do
			expect.truthy(isEvidence(tier.evidence))
		end
		local hqIds = {}
		for _, tier in Config.HQ.tiers do
			expect.truthy(isEvidence(tier.evidence))
			table.insert(hqIds, tier.id)
		end
		expect.equal(table.concat(hqIds, ","), "SalesTent,TimberPavilion,AlpineHut,MountainChalet")
		expect.truthy(isEvidence(Config.Workshop.evidence))
		expect.equal(Config.Workshop.id, "ElfWorkshop")
		expect.equal(Config.Parking.maxSpaces, Config.Parking.tiers[Config.Parking.maxTier].spaces)
		expect.equal(Config.Parking.maxSpaces, GameConfig.Customers.Npc.MaxPerPlot)
		expect.equal(Config.Parking.tiers[1].spaces, GameConfig.Customers.BaseParkingSpaces)
	end)

	t.test("observed ladder values", function()
		local Observed = GameConfig.Evidence.Observed
		expect.equal(Config.LotExpansion.levels[1].cashCost, 1200)
		expect.equal(Config.LotExpansion.levels[1].evidence, Observed)
		expect.equal(Config.Parking.tiers[2].cashCost, 600)
		expect.equal(Config.Parking.tiers[2].spaces, 4)
		local pavilion = Config.HQ.tiers[2]
		expect.equal(pavilion.cashCost, 2500)
		expect.equal(pavilion.requiredReputation, 250)
		expect.equal(pavilion.requiredLotExpansion, 1)
		expect.equal(pavilion.requiredParkingTier, 2)
		expect.equal(pavilion.newSpecies, 4)
		expect.equal(pavilion.checkoutStations, 2)
		expect.equal(pavilion.employeeCapacity, 3)
		expect.equal(pavilion.customerPatienceBonus, 0.12)
		expect.equal(pavilion.evidence, Observed)
		expect.equal(Config.HQ.tiers[3].checkoutStations, 2)
		expect.equal(Config.HQ.tiers[3].employeeCapacity, 5)
		expect.equal(Config.HQ.tiers[1].employeeCapacity, 2)
		expect.equal(GameConfig.Employees.LotManager.hireCost, 1250000)
		expect.equal(GameConfig.Employees.LotManager.requiredHqTier, 4)
	end)

	t.test("ladder has no deadlock", function()
		local state = BusinessState.new("personal:42", 42)
		state.cash = 1e9
		state.reputation = 1e9
		local purchases = 0
		local bought = true
		while bought and purchases < 20 do
			bought = false
			for _, kind in KINDS do
				local offer = Progression.offer(state, kind)
				if offer and offer.ready then
					expect.truthy(BUY[kind](state, offer.target))
					purchases += 1
					bought = true
					break
				end
			end
		end
		expect.equal(state.progression.lotExpansion, 6)
		expect.equal(state.progression.parkingTier, 2)
		expect.equal(state.progression.hqLevel, 4)
		expect.equal(purchases, 10)
	end)

	t.test("offer rows match the purchase check", function()
		local function pavilionReady()
			local state = BusinessState.new("personal:42", 42)
			state.cash = 2500
			state.reputation = 250
			state.progression.lotExpansion = 1
			state.progression.parkingTier = 2
			return state
		end
		local fresh = BusinessState.new("personal:42", 42)
		local lotCash = BusinessState.new("personal:42", 42)
		lotCash.cash = 1200
		lotCash.reputation = 0
		local shortLot, shortParking, shortRep, shortCash =
			pavilionReady(), pavilionReady(), pavilionReady(), pavilionReady()
		shortLot.progression.lotExpansion = 0
		shortParking.progression.parkingTier = 1
		shortRep.reputation = 249
		shortCash.cash = 2499
		local states = { fresh, lotCash, shortLot, shortParking, shortRep, shortCash, pavilionReady() }
		local refusals = 0
		for _, original in states do
			for _, kind in KINDS do
				local offer = Progression.offer(original, kind)
				if offer then
					local state = deepCopy(original)
					local ok, code = BUY[kind](state, offer.target)
					expect.equal(ok == true, offer.ready)
					if not ok then
						refusals += 1
						local firstUnmet = nil
						for _, row in offer.rows do
							if not row.met then
								firstUnmet = row
								break
							end
						end
						expect.truthy(firstUnmet ~= nil)
						expect.equal(code, Progression.ROW_CODES[firstUnmet.id])
						expect.equal(state.cash, original.cash)
						expect.equal(state.progression.lotExpansion, original.progression.lotExpansion)
						expect.equal(state.progression.parkingTier, original.progression.parkingTier)
						expect.equal(state.progression.hqLevel, original.progression.hqLevel)
					end
				end
			end
		end
		expect.truthy(refusals > 0)
		local function hqCode(state)
			local _, code = ProgressionService.buyHQ(deepCopy(state), 2)
			return code
		end
		expect.equal(hqCode(shortLot), "PrerequisitesNotMet")
		expect.equal(hqCode(shortParking), "PrerequisitesNotMet")
		expect.equal(hqCode(shortRep), "InsufficientReputation")
		expect.equal(hqCode(shortCash), "InsufficientFunds")
	end)

	t.test("a purchase targets one level", function()
		local state = BusinessState.new("personal:42", 42)
		state.cash = 1e9
		state.reputation = 1e9
		state.progression.lotExpansion = 1
		local before = deepCopy(state)
		local function refused(kind: string, target: any, expected: string)
			local ok, code = BUY[kind](state, target)
			expect.falsy(ok)
			expect.equal(code, expected)
			expect.equal(state.cash, before.cash)
			expect.equal(state.spent, before.spent)
			expect.equal(state.progression.lotExpansion, before.progression.lotExpansion)
			expect.equal(state.progression.parkingTier, before.progression.parkingTier)
			expect.equal(state.progression.hqLevel, before.progression.hqLevel)
		end
		refused("LotExpansion", 1, "AlreadyOwned")
		refused("LotExpansion", 3, "NotNextLevel")
		refused("LotExpansion", 0, "InvalidLevel")
		refused("LotExpansion", 7, "InvalidLevel")
		refused("LotExpansion", 1.5, "InvalidLevel")
		refused("Parking", 1, "AlreadyOwned")
		refused("HQ", 1, "AlreadyOwned")
		refused("HQ", 3, "NotNextLevel")
	end)

	t.test("HQ footprints fit the Stand box and clear the lot at every level (G19)", function()
		local stand = keepClear("Stand")
		local path = GameConfig.Customers.Npc.Path
		local others: { Box } = {}
		for _, box in Placement.KeepClear do
			if box.id ~= "Stand" then
				table.insert(others, box)
			end
		end
		for index = 1, Config.Parking.maxSpaces do
			table.insert(others, around(path.ParkingFirstX + 12 * (index - 1), path.ParkingDepth, 4, 6))
		end
		local half = GameConfig.Staff.BreakArea.HalfSize
		for _, candidate in GameConfig.Staff.BreakArea.Candidates do
			table.insert(others, around(candidate.x, candidate.z, half, half))
		end
		for _, tier in Config.HQ.tiers do
			local footprint = tier.footprint
			expect.truthy(inside(footprint, stand))
			expect.truthy(math.abs((footprint.minX + footprint.maxX) / 2 + 8) < 1e-9)
			expect.truthy(math.abs((footprint.minZ + footprint.maxZ) / 2 + 4) < 1e-9)
			for _, box in others do
				expect.falsy(overlaps(footprint, box))
			end
			for _, fence in Placement.DecorFences do
				expect.falsy(circleHits(footprint, fence.x, fence.z, Placement.DecorFenceRadius))
			end
			for level = 0, Config.LotExpansion.maxLevel do
				local lot = { minX = -40, maxX = 40, minZ = -(27 + 8 * level), maxZ = 27 }
				expect.truthy(inside(footprint, lot))
				for _, box in Progression.fenceBoxes(level) do
					expect.falsy(overlaps(footprint, box))
				end
			end
		end
	end)

	-- CM2-G9a A1: the HQ 1 art is fitted into Stand minus StandFitMargin; every tier fits that box.
	t.test("the fitted Stand box holds every HQ footprint", function()
		local margin = Placement.StandFitMargin
		expect.equal(type(margin), "number")
		expect.truthy(margin > 0 and margin <= 0.5)
		local stand = keepClear("Stand")
		local fitted = {
			minX = stand.minX + margin,
			maxX = stand.maxX - margin,
			minZ = stand.minZ + margin,
			maxZ = stand.maxZ - margin,
		}
		for _, tier in Config.HQ.tiers do
			expect.truthy(inside(tier.footprint, fitted))
		end
	end)

	t.test("the reserve holds all levels and the fence stays clear", function()
		expect.equal(Placement.LotHalfDepth + Placement.BackDepthPerLevel * Config.LotExpansion.maxLevel, 75)
		local half = GameConfig.Staff.BreakArea.HalfSize
		local blockers: { Box } = {}
		for _, box in Placement.KeepClear do
			table.insert(blockers, box)
		end
		for _, candidate in GameConfig.Staff.BreakArea.Candidates do
			table.insert(blockers, around(candidate.x, candidate.z, half, half))
		end
		-- Reserve firs in the lot frame of their plot.
		local firs: { { row: number, box: Box } } = {}
		for _, piece in MapLayout.pieces() do
			if piece.group == "Reserve" then
				local plot = MapLayout.PLOTS[piece.plot]
				local world = MapLayout.footprint(piece)
				local z1, z2 = plot.facing * (world.minZ - plot.z), plot.facing * (world.maxZ - plot.z)
				table.insert(firs, {
					row = piece.row :: number,
					box = {
						minX = world.minX - plot.x,
						maxX = world.maxX - plot.x,
						minZ = math.min(z1, z2),
						maxZ = math.max(z1, z2),
					},
				})
			end
		end
		expect.truthy(#firs > 0)
		for level = 0, Config.LotExpansion.maxLevel do
			local hidden = MapLayout.hiddenRowCount(level)
			for _, box in Progression.fenceBoxes(level) do
				for _, blocker in blockers do
					expect.falsy(overlaps(box, blocker))
				end
				for _, fir in firs do
					if fir.row > hidden then
						expect.falsy(overlaps(box, fir.box))
					end
				end
			end
		end
	end)

	t.test("the workshop unlocks with HQ 4 and a Lot Manager", function()
		local state = BusinessState.new("personal:42", 42)
		state.progression.hqLevel = 3
		state.staff.LotManager = 1
		expect.falsy(Progression.workshop(state).unlocked)
		state.progression.hqLevel = 4
		state.staff.LotManager = 0
		local noManager = Progression.workshop(state)
		expect.falsy(noManager.unlocked)
		expect.equal(noManager.rows[1].id, "HqLevel")
		expect.equal(noManager.rows[1].have, 4)
		expect.equal(noManager.rows[1].need, 4)
		expect.equal(noManager.rows[2].id, "LotManager")
		expect.equal(noManager.rows[2].have, 0)
		expect.equal(noManager.rows[2].met, false)
		state.staff.LotManager = 1
		local open = Progression.workshop(state)
		expect.truthy(open.unlocked)
		expect.equal(open.rows[2].have, 1)
	end)

	t.test("queue patience grows with the HQ", function()
		local values = {}
		for level = 1, 4 do
			table.insert(values, Progression.queuePatienceFor(level))
		end
		expect.equal(table.concat(values, ","), "90,101,108,117")
	end)

	t.test("migrates schema 18 progression", function()
		local function migrated(old): string
			local result = Progression.migrate18(old)
			local keys = 0
			for _ in pairs(result) do
				keys += 1
			end
			expect.equal(keys, 3)
			return string.format("%s,%s,%s", result.lotExpansion, result.parkingTier, result.hqLevel)
		end
		expect.equal(migrated({ lotExpansion = 0, parkingSpaces = 0, hqTier = nil }), "0,1,1")
		expect.equal(migrated({ lotExpansion = 2, parkingSpaces = 3, hqTier = nil }), "2,2,1")
		expect.equal(migrated({ lotExpansion = 3, parkingSpaces = 4, hqTier = "ChristmasPavilion" }), "3,2,2")
		expect.equal(migrated(nil), "0,1,1")
		expect.equal(migrated("broken"), "0,1,1")
	end)
end
