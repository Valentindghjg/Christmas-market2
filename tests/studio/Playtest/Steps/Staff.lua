--!strict
-- Playtest steps 44-47 (full mode): visible staff, energy and the break area (CM2-25/26).
-- Installed by RunPlaytest.execute after Steps/Reviews. Only the shadow S gets staff fixtures
-- (setStaff, setStaffEnergy); the real company R changes only through normal actions.
return function(ctx: any)
	local DELIVERY_WAIT = ctx.DELIVERY_WAIT
	local GameConfig = ctx.GameConfig
	local NpcPath = ctx.NpcPath
	local ReplicatedStorage = ctx.ReplicatedStorage
	local S = ctx.S
	local SIZE = ctx.SIZE
	local addStep = ctx.addStep
	local advance = ctx.advance
	local awaitDelivery = ctx.awaitDelivery
	local call = ctx.call
	local check = ctx.check
	local counterPart = ctx.counterPart
	local findOrder = ctx.findOrder
	local findStaff = ctx.findStaff
	local orderTrees = ctx.orderTrees
	local placeOne = ctx.placeOne
	local plotFolder = ctx.plotFolder
	local poll = ctx.poll
	local realPlayer = ctx.realPlayer
	local snap = ctx.snap
	local staffSnapshot = ctx.staffSnapshot
	local strayHumanoids = ctx.strayHumanoids
	local withNpcCleanup = ctx.withNpcCleanup
	local Staff = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Staff")) :: any

	local StaffConfig = GameConfig.Staff
	local POST_RADIUS = 1.5
	local SEAT_RADIUS = 2
	local PLAYER_DISTANCE = 40
	local SPOT_TOLERANCE = 0.01

	-- Lot-frame x/z of the trees S sold in steps 44 and 46 (the Lot Worker restocks one of them).
	local soldSpots: { { x: number, z: number } } = {}

	-- A lot-frame point of a plot in world space (at the lot ground's height).
	local function worldPoint(plotId: string?, p: { x: number, z: number }): Vector3
		local plot = plotFolder(plotId)
		check(plot ~= nil and plot:IsA("Model") and plot.PrimaryPart ~= nil, "plot " .. tostring(plotId) .. " missing")
		local center = ((plot :: Model).PrimaryPart :: BasePart).Position
		local w = NpcPath.toWorld({ x = center.X, z = center.Z }, p)
		return Vector3.new(w.x, center.Y, w.z)
	end

	local function flatDistance(a: Vector3, b: Vector3): number
		local dx, dz = a.X - b.X, a.Z - b.Z
		return math.sqrt(dx * dx + dz * dz)
	end

	local function rootOf(model: Model?): BasePart?
		local root = model and model:FindFirstChild("HumanoidRootPart")
		return if root and root:IsA("BasePart") then root else nil
	end

	local function staffState(role: string): string?
		local model = findStaff(S.plotId, role)
		local value = model and model:GetAttribute("StaffState")
		return if type(value) == "string" then value else nil
	end

	-- S's live (non-load) staff record of `role` in staffSnapshot, or nil.
	local function staffEntry(role: string): any
		for _, entry in staffSnapshot().staff do
			if entry.plotId == S.plotId and entry.role == role and entry.companyId ~= nil then
				return entry
			end
		end
		return nil
	end

	-- The placements of `before` that are gone in `after`, added to soldSpots.
	local function noteSold(before: any, after: any): number
		local present: { [string]: boolean } = {}
		for _, placement in after.placements do
			present[placement.placementId] = true
		end
		local count = 0
		for _, placement in before.placements do
			if not present[placement.placementId] and type(placement.x) == "number" then
				table.insert(soldSpots, { x = placement.x, z = placement.z })
				count += 1
			end
		end
		return count
	end

	local function isSoldSpot(x: number?, z: number?): boolean
		if type(x) ~= "number" or type(z) ~= "number" then
			return false
		end
		for _, spot in soldSpots do
			if math.abs(spot.x - x) <= SPOT_TOLERANCE and math.abs(spot.z - z) <= SPOT_TOLERANCE then
				return true
			end
		end
		return false
	end

	local function staffPlacements(snapshot: any): { any }
		local list = {}
		for _, placement in snapshot.placements do
			if string.sub(placement.placementId, 1, 6) == "staff:" then
				table.insert(list, placement)
			end
		end
		return list
	end

	local function bayMedium(snapshot: any): number
		local total = 0
		for _, bay in snapshot.bays do
			total += bay.counts[SIZE] or 0
		end
		return total
	end

	-- R's character stays away from S's counter, so only the Cashier can serve there.
	local function assertPlayerAway()
		local root = rootOf(realPlayer().Character)
		check(root ~= nil, "player has no HumanoidRootPart")
		local distance = ((root :: BasePart).Position - counterPart(S.plotId).Position).Magnitude
		check(distance > PLAYER_DISTANCE, string.format("player %.1f studs from S's counter", distance))
	end

	-- Step 44: a hired Cashier walks to the counter and checks out a queue of two alone.
	local function staffCashierStep(): string
		call("pauseCustomers", true)
		table.clear(soldSpots)
		local data = orderTrees(S.userId, 4)
		advance(DELIVERY_WAIT)
		awaitDelivery(S.userId, data.orderId)
		for _ = 1, 3 do
			placeOne(S.userId, data.bay)
		end
		call("setStaff", { employeeId = "Cashier", count = 1 })
		call("setStaffEnergy", { employeeId = "Cashier", energy = 100 })
		local post = worldPoint(S.plotId, NpcPath.staffPoint())
		local onDuty = poll(function()
			local root = rootOf(findStaff(S.plotId, "Cashier"))
			return staffState("Cashier") == "OnDuty"
				and root ~= nil
				and flatDistance((root :: BasePart).Position, post) <= POST_RADIUS
		end, 20)
		check(onDuty, "Staff_Cashier not OnDuty at the counter within 20 s (" .. tostring(staffState("Cashier")) .. ")")
		local cashier = findStaff(S.plotId, "Cashier") :: Model
		check(cashier:FindFirstChild("Apron") ~= nil, "Staff_Cashier has no Apron")
		assertPlayerAway()
		local before = snap(S.userId)
		call("npcVisit", { userId = S.userId, profile = 8 })
		call("npcVisit", { userId = S.userId, profile = 20 })
		local served = poll(function()
			assertPlayerAway()
			return snap(S.userId).sales >= before.sales + 2
		end, 90)
		local after = snap(S.userId)
		check(served, string.format("S sales %d -> %d within 90 s, expected +2", before.sales, after.sales))
		check(after.sales == before.sales + 2, "S sold more than the two customers")
		check(
			after.walkedOutCustomers == before.walkedOutCustomers,
			string.format("walkedOutCustomers %d -> %d", before.walkedOutCustomers, after.walkedOutCustomers)
		)
		local sold = noteSold(before, after)
		check(sold == 2, sold .. " sold spot(s) recorded, expected 2")
		return string.format("Cashier on duty, served 2 customers, sales %d -> %d", before.sales, after.sales)
	end

	-- Step 45: the break area stands at the saved spot; a tired Cashier rests and returns.
	local function staffBreakStep(): string
		local area = snap(S.userId).breakArea
		check(type(area) == "table", "S snapshot has no breakArea")
		local plot = plotFolder(S.plotId)
		local model = plot and plot:FindFirstChild("BreakArea")
		check(model ~= nil and model:IsA("Model"), "BreakArea missing on S")
		for _, name in { "Pad", "FireRing", "Embers", "Seat_1", "Seat_2", "Seat_3" } do
			local part = (model :: Model):FindFirstChild(name)
			check(part ~= nil and part:IsA("BasePart"), "BreakArea." .. name .. " missing")
		end
		check(
			(model :: Model):GetAttribute("AreaX") == area.x
				and (model :: Model):GetAttribute("AreaZ") == area.z
				and (model :: Model):GetAttribute("AreaRotation") == area.rotation,
			"BreakArea attributes differ from the save's breakArea"
		)
		local pad = (model :: Model):FindFirstChild("Pad") :: BasePart
		local centre = worldPoint(S.plotId, { x = area.x, z = area.z })
		check(flatDistance(pad.Position, centre) <= SPOT_TOLERANCE, "BreakArea.Pad is not at the saved spot")
		call("setStaffEnergy", { employeeId = "Cashier", energy = 21 })
		local seat = worldPoint(S.plotId, Staff.restPoint(area, "Cashier"))
		local resting = poll(function()
			local root = rootOf(findStaff(S.plotId, "Cashier"))
			return staffState("Cashier") == "Resting"
				and root ~= nil
				and flatDistance((root :: BasePart).Position, seat) <= SEAT_RADIUS
		end, 30)
		check(resting, "Cashier not Resting at rest point 1 within 30 s (" .. tostring(staffState("Cashier")) .. ")")
		local back = poll(function()
			local entry = staffEntry("Cashier")
			return staffState("Cashier") == "OnDuty" and entry ~= nil and entry.energy >= 99
		end, 90)
		local entry = staffEntry("Cashier")
		check(
			back,
			string.format(
				"Cashier not back OnDuty with energy >= 99 within 90 s (%s, energy %s)",
				tostring(staffState("Cashier")),
				tostring(entry and entry.energy)
			)
		)
		return string.format("rested at (%.1f, %.1f), back on duty with energy %.1f", area.x, area.z, entry.energy)
	end

	-- Step 46: the Lot Worker loads the new order and restocks sold spots from the bays. It
	-- restocks every known sold spot while a bay holds the size (Amendment 2), so only staff
	-- placements new in this step count.
	local function staffLotWorkerStep(): string
		call("pauseCustomers", true)
		local before = snap(S.userId)
		for _, spot in before.vacatedSpots do
			table.insert(soldSpots, { x = spot.x, z = spot.z })
		end
		local knownStaff: { [string]: boolean } = {}
		for _, placement in staffPlacements(before) do
			knownStaff[placement.placementId] = true
		end
		local function newStaff(snapshot: any): { any }
			local list = {}
			for _, placement in staffPlacements(snapshot) do
				if not knownStaff[placement.placementId] then
					table.insert(list, placement)
				end
			end
			return list
		end
		call("setStaff", { employeeId = "LotWorker", count = 1 })
		call("setStaffEnergy", { employeeId = "LotWorker", energy = 100 })
		local known: { [number]: boolean } = {}
		for _, order in before.customerOrders do
			known[order.orderNumber] = true
		end
		call("npcVisit", { userId = S.userId, profile = 8 })
		local orderNumber: number? = nil
		local afterSale: any = nil
		local sold = poll(function()
			local snapshot = snap(S.userId)
			if snapshot.sales <= before.sales then
				return false
			end
			afterSale = snapshot
			for _, order in snapshot.customerOrders do
				if not known[order.orderNumber] then
					orderNumber = order.orderNumber
				end
			end
			return true
		end, 90)
		check(sold, "the Cashier did not sell to the customer within 90 s")
		noteSold(before, afterSale)
		local loaded = poll(function()
			local snapshot = snap(S.userId)
			return (orderNumber == nil or findOrder(snapshot, orderNumber :: number) == nil)
				and snapshot.loadedOrders >= before.loadedOrders + 1
		end, 60)
		local afterLoad = snap(S.userId)
		check(
			loaded,
			string.format(
				"order %s not loaded within 60 s (loadedOrders %d -> %d)",
				tostring(orderNumber),
				before.loadedOrders,
				afterLoad.loadedOrders
			)
		)
		check(afterLoad.missedPickups == before.missedPickups, "missedPickups changed")
		local restocked = poll(function()
			return #newStaff(snap(S.userId)) >= 1
		end, 90)
		local final = snap(S.userId)
		local list = newStaff(final)
		check(
			restocked,
			string.format(
				"no new staff placement within 90 s (sold spots %d, bay Medium %d)",
				#soldSpots,
				bayMedium(final)
			)
		)
		for index, placement in list do
			check(
				isSoldSpot(placement.x, placement.z),
				string.format(
					"staff placement %s at (%.1f, %.1f) is not a sold spot",
					placement.placementId,
					placement.x,
					placement.z
				)
			)
			for other = index + 1, #list do
				local second = list[other]
				check(
					not (
							math.abs(second.x - placement.x) <= SPOT_TOLERANCE
							and math.abs(second.z - placement.z) <= SPOT_TOLERANCE
						),
					string.format("two staff placements at (%.1f, %.1f)", placement.x, placement.z)
				)
			end
		end
		check(
			bayMedium(final) == bayMedium(before) - #list,
			string.format(
				"S bay Medium %d -> %d with %d staff placement(s)",
				bayMedium(before),
				bayMedium(final),
				#list
			)
		)
		return string.format(
			"order %s loaded, %d restocked from the bays (Medium %d -> %d)",
			tostring(orderNumber),
			#list,
			bayMedium(before),
			bayMedium(final)
		)
	end

	-- Step 47: energy and break area are saved; letting staff go leaves nothing behind.
	local function staffSaveCleanStep(): string
		local snapshot = snap(S.userId)
		for _, role in StaffConfig.Roles do
			local energy = snapshot.staffEnergy[role]
			check(
				type(energy) == "number" and energy == math.floor(energy) and energy >= 0 and energy <= 100,
				"staffEnergy." .. role .. " is " .. tostring(energy)
			)
		end
		local area = snapshot.breakArea
		local candidate = false
		for _, spot in StaffConfig.BreakArea.Candidates do
			if spot.x == area.x and spot.z == area.z then
				candidate = true
			end
		end
		check(candidate and area.rotation == 0, "breakArea is not a candidate spot with rotation 0")
		call("setStaff", { employeeId = "LotWorker", count = 0 })
		call("setStaff", { employeeId = "Cashier", count = 0 })
		local function leftover(): string?
			local plot = plotFolder(S.plotId)
			local folder = plot and plot:FindFirstChild("Staff")
			if folder then
				for _, child in folder:GetChildren() do
					if string.sub(child.Name, 1, 6) == "Staff_" then
						return child.Name .. " still on S"
					end
				end
			end
			for _, entry in staffSnapshot().staff do
				if entry.plotId == S.plotId and entry.companyId ~= nil then
					return entry.staffId .. " still in staffSnapshot"
				end
			end
			return nil
		end
		local gone = poll(function()
			return leftover() == nil
		end, 3)
		check(gone, tostring(leftover()))
		local stray = strayHumanoids()
		check(stray == 0, stray .. " Humanoid(s) outside player characters")
		return string.format(
			"energy %d/%d saved, break area (%.1f, %.1f), staff gone",
			snapshot.staffEnergy.Cashier,
			snapshot.staffEnergy.LotWorker,
			area.x,
			area.z
		)
	end

	addStep("44", "STAFF_CASHIER", { "03" }, withNpcCleanup(staffCashierStep))
	addStep("45", "STAFF_BREAK", { "44" }, staffBreakStep)
	addStep("46", "STAFF_LOT_WORKER", { "44" }, withNpcCleanup(staffLotWorkerStep))
	addStep("47", "STAFF_SAVE_CLEAN", { "44" }, staffSaveCleanStep)
end
