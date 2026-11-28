--!strict
-- Playtest steps 44-50 (full mode): visible staff, energy and the break area (CM2-25/26).
-- Installed by RunPlaytest.execute after Steps/Reviews. Only the shadow S gets staff fixtures
-- (setStaff, setStaffEnergy); the real company R changes only through normal actions. Steps
-- 48 and 50 (part b) check the server side here; their client UI checks (Employees tab, the
-- break-area bar and ghost) are done by the playtester in the client (docs/archive/plans/CM2-25-26b.md).
-- Step details (moved from docs/TEST_PLAN.md, CM2-FAST):
-- `44 STAFF_CASHIER` (CM2-25/26: S orders 4 Douglas Medium and places 3 (one stays in the bay);
-- with `setStaff Cashier 1` and `setStaffEnergy Cashier 100` `Staff_Cashier` in S's `Staff` folder
-- is `OnDuty` within 20 s, its root within 1.5 studs of the staff point, with an `Apron`; customers
-- 8 and 20 on S are served within 90 s (sales +2, `walkedOutCustomers` unchanged) while R's
-- character stays > 40 studs from S's counter), `45 STAFF_BREAK` (S's `BreakArea` has `Pad`,
-- `FireRing`, `Embers`, `Seat_1..3` at the save's `breakArea`; `setStaffEnergy Cashier 21` brings
-- the Cashier to `Resting` within 2 studs of rest point 1 within 30 s and back `OnDuty` with energy
-- ≥ 99 within 90 s), `46 STAFF_LOT_WORKER` (`setStaff LotWorker 1`; one customer (profile 8) on S:
-- its order is loaded within 60 s of the sale (`loadedOrders` +1 or more, `missedPickups`
-- unchanged); within 90 s at least one new `staff:` placement appears; every new `staff:` placement
-- stands at a sold spot (step 44, 46 or an earlier run's `vacatedSpots`), no two share a spot, and
-- bay Medium drops by their count), `47 STAFF_SAVE_CLEAN` (S's `staffEnergy` whole numbers 0..100,
-- `breakArea` a candidate with rotation 0; `setStaff` 0 for both removes every `Staff_*` model and
-- S's staff records within 3 s, no stray Humanoid), `48 EMPLOYEES_TAB` (CM2-25/26 part b, server
-- side: R's summary `staff` lists Cashier, Lot Worker, Lot Manager in order with the config costs,
-- `hiredCount` = R's hired staff, `capacity` 2 (or the HQ's), the Lot Manager `locked` and not
-- hired, `breakArea` = the snapshot's; the playtester checks the tab in the client: "N / 2 hired",
-- three cards, Lot Manager "Locked" and inactive with the locked line, the Cashier button "Hired",
-- "Hire" or "Not enough cash" matching R, `staffNoCashier` iff R has no Cashier, the
-- `breakAreaMove` button), `49 BREAK_AREA_MOVE` (S: with its Cashier resting (`setStaff Cashier 1`,
-- `setStaffEnergy Cashier 21`), `Staff.MoveBreakArea` to the first other free candidate is ok, S's
-- `BreakArea*` attributes follow within 2 s and the Cashier rests at the new seat within 20 s; (−14,
-- 20) `KeepClear`, (60, 0) `OutsideLot` and the 0.5-grid spot of an S tree `TooClose` leave
-- `breakArea` unchanged; the area moves back and `setStaff Cashier 0`), `50 BREAK_AREA_MODE`
-- (server side: R moves its break area to a free candidate and back through the normal action, the
-- plot follows each time; the playtester first clicks `breakAreaMove` in the client: `BreakAreaBar`
-- and `BreakAreaGhost` exist, the Lot Manager is closed; Cancel removes both and leaves `breakArea`
-- unchanged)
return function(ctx: any)
	local DELIVERY_WAIT = ctx.DELIVERY_WAIT
	local GameConfig = ctx.GameConfig
	local R = ctx.R
	local NpcPath = ctx.NpcPath
	local ReplicatedStorage = ctx.ReplicatedStorage
	local S = ctx.S
	local SIZE = ctx.SIZE
	local act = ctx.act
	local actOk = ctx.actOk
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
	local Progression = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Progression")) :: any

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

	-- Part b (CM2-25-26b) --------------------------------------------------------------------

	local ROLE_ORDER = { "Cashier", "LotWorker", "LotManager" }
	local MOVE_SYNC_SECONDS = 2
	local MOVE_REST_SECONDS = 20

	local function snapHalf(value: number): number
		return math.floor(value * 2 + 0.5) / 2
	end

	-- The break-area check input of a company: its displayed trees and its plot's lot level.
	local function layoutOf(plotId: string?, snapshot: any): any
		local trees = {}
		for _, placement in snapshot.placements do
			if type(placement.x) == "number" and type(placement.z) == "number" then
				table.insert(trees, { x = placement.x, z = placement.z, sizeId = placement.sizeId })
			end
		end
		local plot = plotFolder(plotId)
		local level = plot and plot:GetAttribute("LotExpansionLevel")
		return { lotExpansion = if type(level) == "number" then level else 0, trees = trees }
	end

	-- The first break-area candidate that differs from `current` and is free in `input`.
	local function otherCandidate(input: any, current: any): any
		for _, spot in StaffConfig.BreakArea.Candidates do
			if (spot.x ~= current.x or spot.z ~= current.z) and Staff.checkBreakArea(input, spot.x, spot.z) then
				return { x = spot.x, z = spot.z, rotation = 0 }
			end
		end
		return nil
	end

	local function sameArea(a: any, b: any): boolean
		return type(a) == "table" and type(b) == "table" and a.x == b.x and a.z == b.z and a.rotation == b.rotation
	end

	local function areaText(area: any): string
		return string.format("(%s, %s, %s)", tostring(area.x), tostring(area.z), tostring(area.rotation))
	end

	-- The plot's BreakArea attributes show `area`.
	local function plotShows(plotId: string?, area: any): boolean
		local plot = plotFolder(plotId)
		return plot ~= nil
			and plot:GetAttribute("BreakAreaX") == area.x
			and plot:GetAttribute("BreakAreaZ") == area.z
			and plot:GetAttribute("BreakAreaRotation") == area.rotation
	end

	-- Step 48 (server side): R's summary carries the Employees tab's staff table.
	local function employeesTabStep(): string
		local data = actOk(R.userId, "Company.GetSummary", {})
		local staff = data.staff
		check(type(staff) == "table" and type(staff.roles) == "table", "summary has no staff table")
		check(#staff.roles == #ROLE_ORDER, #staff.roles .. " staff roles, expected 3")
		for index, id in ROLE_ORDER do
			local entry = staff.roles[index]
			check(entry.id == id, string.format("staff role %d is %s, expected %s", index, tostring(entry.id), id))
			check(
				entry.hireCost == GameConfig.Employees[id].hireCost,
				string.format("%s hireCost %s", id, tostring(entry.hireCost))
			)
		end
		local snapshot = snap(R.userId)
		local hired = 0
		for _, role in StaffConfig.Roles do
			hired += snapshot.staff[role] or 0
		end
		check(staff.hiredCount == hired, string.format("hiredCount %s, R has %d", tostring(staff.hiredCount), hired))
		-- CM2-G9a: the capacity of R's HQ tier (R and S are HQ 1, so the Lot Manager stays locked).
		local capacity = Progression.employeeCapacity({ progression = data.plot })
		check(staff.capacity == capacity, string.format("capacity %s, expected %d", tostring(staff.capacity), capacity))
		local manager = staff.roles[3]
		check(manager.locked == true and manager.hired == false, "the Lot Manager is not locked and unhired")
		local cashier = staff.roles[1]
		check(
			(cashier.hired == true) == ((snapshot.staff.Cashier or 0) >= 1),
			"Cashier hired flag differs from the snapshot"
		)
		check(sameArea(staff.breakArea, snapshot.breakArea), "summary breakArea differs from the snapshot")
		return string.format(
			"%d / %d hired, Cashier %s, Lot Manager locked (client UI checks by the playtester)",
			hired,
			capacity,
			if cashier.hired then "hired" else "not hired"
		)
	end

	-- Step 49: S moves its break area; the resting Cashier walks to the new seat; refusals change
	-- nothing; the area moves back.
	local function breakAreaMoveStep(): string
		call("setStaff", { employeeId = "Cashier", count = 1 })
		check(
			poll(function()
				return staffEntry("Cashier") ~= nil
			end, 10),
			"S's Cashier did not appear within 10 s"
		)
		call("setStaffEnergy", { employeeId = "Cashier", energy = 21 })
		check(
			poll(function()
				return staffState("Cashier") == "Resting"
			end, 45),
			"S's Cashier not Resting within 45 s (" .. tostring(staffState("Cashier")) .. ")"
		)
		local before = snap(S.userId)
		local start = before.breakArea
		local input = layoutOf(S.plotId, before)
		local area = otherCandidate(input, start)
		check(area ~= nil, "no other free break-area candidate on S")
		actOk(S.userId, "Staff.MoveBreakArea", area)
		check(
			poll(function()
				return plotShows(S.plotId, area)
			end, MOVE_SYNC_SECONDS),
			"S's BreakArea attributes do not show " .. areaText(area) .. " within 2 s"
		)
		check(sameArea(snap(S.userId).breakArea, area), "S breakArea is not " .. areaText(area))
		local seat = worldPoint(S.plotId, Staff.restPoint(area, "Cashier"))
		local rests = poll(function()
			local root = rootOf(findStaff(S.plotId, "Cashier"))
			return staffState("Cashier") == "Resting"
				and root ~= nil
				and flatDistance((root :: BasePart).Position, seat) <= SEAT_RADIUS
		end, MOVE_REST_SECONDS)
		check(rests, "Cashier not Resting at the new seat within 20 s (" .. tostring(staffState("Cashier")) .. ")")
		local function refused(x: number, z: number, code: string)
			local response = act(S.userId, "Staff.MoveBreakArea", { x = x, z = z, rotation = 0 })
			local got = if type(response) == "table" then response.errorCode else response
			check(
				type(response) == "table" and response.ok ~= true and got == code,
				string.format(
					"move to (%s, %s) returned %s, expected %s",
					tostring(x),
					tostring(z),
					tostring(got),
					code
				)
			)
			check(sameArea(snap(S.userId).breakArea, area), "breakArea changed by a refused move (" .. code .. ")")
		end
		refused(-14, 20, "KeepClear")
		refused(60, 0, "OutsideLot")
		local probe = nil
		for _, tree in input.trees do
			local x, z = snapHalf(tree.x), snapHalf(tree.z)
			local _, code = Staff.checkBreakArea(input, x, z)
			if code == "TooClose" then
				probe = { x = x, z = z }
				break
			end
		end
		check(probe ~= nil, "no S tree for the TooClose probe (" .. #input.trees .. " trees)")
		refused(probe.x, probe.z, "TooClose")
		actOk(S.userId, "Staff.MoveBreakArea", { x = start.x, z = start.z, rotation = start.rotation })
		check(sameArea(snap(S.userId).breakArea, start), "S breakArea not restored to " .. areaText(start))
		check(
			poll(function()
				return plotShows(S.plotId, start)
			end, MOVE_SYNC_SECONDS),
			"S's BreakArea attributes not restored within 2 s"
		)
		call("setStaff", { employeeId = "Cashier", count = 0 })
		return string.format(
			"moved %s -> %s, Cashier rested there; KeepClear, OutsideLot, TooClose at (%.1f, %.1f) refused; restored",
			areaText(start),
			areaText(area),
			probe.x,
			probe.z
		)
	end

	-- Step 50 (server side): R moves its break area to a free candidate and back through the
	-- normal action; the plot follows. The bar, the ghost and Cancel are client UI checks.
	local function breakAreaModeStep(): string
		local snapshot = snap(R.userId)
		local start = snapshot.breakArea
		local area = otherCandidate(layoutOf(R.plotId, snapshot), start)
		check(area ~= nil, "no other free break-area candidate on R")
		actOk(R.userId, "Staff.MoveBreakArea", area)
		check(sameArea(snap(R.userId).breakArea, area), "R breakArea is not " .. areaText(area))
		check(
			poll(function()
				return plotShows(R.plotId, area)
			end, MOVE_SYNC_SECONDS),
			"R's BreakArea attributes do not show " .. areaText(area) .. " within 2 s"
		)
		actOk(R.userId, "Staff.MoveBreakArea", { x = start.x, z = start.z, rotation = start.rotation })
		check(sameArea(snap(R.userId).breakArea, start), "R breakArea not restored to " .. areaText(start))
		check(
			poll(function()
				return plotShows(R.plotId, start)
			end, MOVE_SYNC_SECONDS),
			"R's BreakArea attributes not restored within 2 s"
		)
		return string.format(
			"R moved %s -> %s and back (client UI checks by the playtester)",
			areaText(start),
			areaText(area)
		)
	end

	addStep("44", "STAFF_CASHIER", { "03" }, withNpcCleanup(staffCashierStep))
	addStep("45", "STAFF_BREAK", { "44" }, staffBreakStep)
	addStep("46", "STAFF_LOT_WORKER", { "44" }, withNpcCleanup(staffLotWorkerStep))
	addStep("47", "STAFF_SAVE_CLEAN", { "44" }, staffSaveCleanStep)
	addStep("48", "EMPLOYEES_TAB", { "02a" }, employeesTabStep)
	addStep("49", "BREAK_AREA_MOVE", { "03" }, breakAreaMoveStep)
	addStep("50", "BREAK_AREA_MODE", { "02a" }, breakAreaModeStep)
end
