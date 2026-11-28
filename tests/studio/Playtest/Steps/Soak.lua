--!strict
-- Playtest soak steps 01a, 01, 02, 03, 03a, 03b, 04 and 05 (soak mode).
-- CM2-47: `03b HQ2_MIRROR` puts HQ level 2 on a free north and a free south plot and compares
-- their art shape, lot-frame position and road facing, then restores both levels.
-- Installed by RunPlaytest.execute (CM2-RF).
-- Step details (moved from docs/TEST_PLAN.md, CM2-FAST):
-- `{ mode = "soak", minutes = 10 }` runs the literal real-time soak (7 steps: `01a ACTIVE_SAVE`
-- first, no clock advance until its final drain; `03 SOAK_REALTIME` runs with customers unpaused
-- (CM2-25/26 Amendment 2: a forced visit without a free space becomes the next arrival (roll 0)
-- through `npcNextArrival`, counted as `next-arrival <n>` after `forced`) and fails when a walking
-- customer snaps (`npc snaps <n>` in its detail); CM2-N2 Amendment 1: its detail adds, per company,
-- the deltas of sales, visits, abandoned, walked out and drive-pasts and `at counter` (distinct
-- non-load visits seen in `CheckingOut` on that plot, one `npcSnapshot` per 5-s tick), for R also
-- `served` and `refused` with the first refusal (`serveCounter` returns `none`, `served`,
-- `handsFull` when the player held a customer's tree, else `refused`), for S `cashier` (its hired
-- Cashier count at the end), and `forced <ok>/<tries>` for the forced visits; after the mismatch
-- check it fails with "shadow lost its Cashier" unless S still has 1 Cashier, "S customers walked
-- out despite the Cashier" when S counted a walk-out, and "R checkout refused (<first refusal>)"
-- when a counter prompt sold nothing; `03a NPC_LOAD` pauses and resets customers and runs
-- `npcLoadTest {seconds = 60, staff = true}`: PASS when 24 NPCs are spawned and live on plots 1–6,
-- 12 load staff are spawned (`staffSpawned` 12, `peakStaff` ≥ 12), every 5-s window ≥ 55 FPS, 0
-- snaps (customers and staff) and none left; `04 LEAK_CHECK` waits up to 180 s for every walking
-- customer to leave, expiring open orders from the server clock while one waits at its car, without
-- an NPC reset).
return function(ctx: any)
	local R = ctx.R
	local S = ctx.S
	local SIZE = ctx.SIZE
	local SPECIES = ctx.SPECIES
	local STOCK_KEY = ctx.STOCK_KEY
	local Stats = ctx.Stats
	local UNIT_PRICE = ctx.UNIT_PRICE
	local act = ctx.act
	local activeSave = ctx.activeSave
	local addStep = ctx.addStep
	local bayWith = ctx.bayWith
	local call = ctx.call
	local check = ctx.check
	local cleanup = ctx.cleanup
	local countOrderObjects = ctx.countOrderObjects
	local displayedCount = ctx.displayedCount
	local expireOrders = ctx.expireOrders
	local invoke = ctx.invoke
	local leakCheck = ctx.leakCheck
	local minutes = ctx.minutes
	local npcSnapshot = ctx.npcSnapshot
	local orderPart = ctx.orderPart
	local pendingQuantity = ctx.pendingQuantity
	local placeOne = ctx.placeOne
	local plotFolder = ctx.plotFolder
	local preflight = ctx.preflight
	local prompt = ctx.prompt
	local resetCustomers = ctx.resetCustomers
	local serveCounter = ctx.serveCounter
	local shadowJoin = ctx.shadowJoin
	local snap = ctx.snap
	local snapEntryText = ctx.snapEntryText
	local strayHumanoids = ctx.strayHumanoids
	local teleport = ctx.teleport

	addStep("01a", "ACTIVE_SAVE", {}, activeSave)

	addStep("01", "SHADOW_JOIN", {}, function()
		shadowJoin(1)
		-- CM2-N2: the shadow's hired Cashier serves its counter; the player serves R's by prompt.
		call("setStaff", { employeeId = "Cashier", count = 1 })
		call("pauseCustomers", false)
		return string.format("shadow plot %s, player plot %s", tostring(S.plotId), tostring(R.plotId))
	end)

	addStep("02", "PREFLIGHT", { "01" }, function()
		return preflight(true)
	end)

	addStep("03", "SOAK_REALTIME", { "02" }, function()
		-- Fix round 1 (P4): PREFLIGHT's reset paused customers; the soak runs with arrivals.
		call("pauseCustomers", false)
		local startNpc = npcSnapshot()
		local snapsBefore = startNpc.customerSnaps or 0
		local totalSeconds = minutes * 60
		local startClock = os.clock()
		local startR, startS = snap(R.userId), snap(S.userId)
		local memoryStart = Stats:GetTotalMemoryUsageMb()
		local companies = { R.userId, S.userId }
		local samples, mismatches = 0, 0
		local firstMismatch = ""
		local maxActive, maxSpaces = 0, 0
		local visitCounter = 0
		-- CM2-N2 Amendment 1: per-plot diagnostics of the counter and the forced visits.
		local seen: { [string]: { [string]: boolean } } = {}
		local served, refused = 0, 0
		local firstRefusal = "-"
		local forced, tries = 0, 0
		-- CM2-25/26 Amendment 2: forced visits without a free space become the next arrival.
		local nextArrivals = 0

		local function summaryOf(userId: number): any
			return invoke("customerOrders", userId)
		end

		local function hasDisplayedMedium(plotId: string?): boolean
			local plot = plotFolder(plotId)
			local display = plot and plot:FindFirstChild("DisplayedTrees")
			if display then
				for _, tree in display:GetChildren() do
					if tree:GetAttribute("SpeciesId") == SPECIES and tree:GetAttribute("SizeId") == SIZE then
						return true
					end
				end
			end
			return false
		end

		local function plotOf(userId: number): string?
			return if userId == R.userId then R.plotId else S.plotId
		end

		local function trackActive(userId: number)
			local summary = summaryOf(userId)
			if summary then
				maxActive = math.max(maxActive, summary.activeCustomers)
				maxSpaces = math.max(maxSpaces, summary.parkingSpaces)
			end
		end

		local function stockAndPlace(userId: number)
			local snapshot = snap(userId)
			local count = snapshot.placementCount
			local stored = snapshot.stock[STOCK_KEY] or 0
			while stored > 0 and count < 6 do
				local bay = bayWith(userId, 1)
				if bay == nil then
					break
				end
				placeOne(userId, bay)
				count += 1
				stored -= 1
			end
		end

		local function orderMore(userId: number)
			local snapshot = snap(userId)
			local quantity = math.min(
				4 - (snapshot.placementCount + (snapshot.stock[STOCK_KEY] or 0) + pendingQuantity(snapshot)),
				math.floor(snapshot.cash / UNIT_PRICE),
				9
			)
			if quantity > 0 then
				-- A refusal (bays, storage, supplier stock) just skips this round.
				act(userId, "Supplier.PlaceOrder", { speciesId = SPECIES, sizeId = SIZE, quantity = quantity })
			end
		end

		local function servePlayerOrders()
			local snapshot = snap(R.userId)
			for _, order in snapshot.customerOrders do
				if order.orderNumber % 2 == 0 and not order.carried then
					local number = order.orderNumber
					local tree = orderPart(R.plotId, "PickupTree_" .. number)
					local car = orderPart(R.plotId, "CustomerCar_" .. number)
					if tree and car then
						teleport(tree)
						prompt("carry", number)
						teleport(car)
						prompt("load", number)
					end
				end
			end
		end

		local function sample(): string?
			for _, userId in companies do
				local plotId = plotOf(userId)
				local snapshot = snap(userId)
				local summary = summaryOf(userId)
				local uncarried = 0
				for _, order in snapshot.customerOrders do
					if not order.carried then
						uncarried += 1
					end
				end
				local label = if userId == R.userId then "R" else "S"
				if countOrderObjects(plotId, "CustomerCar_") ~= #snapshot.customerOrders then
					return label .. " cars differ from orders"
				end
				if countOrderObjects(plotId, "PickupTree_") ~= uncarried then
					return label .. " pickup trees differ from uncarried orders"
				end
				if countOrderObjects(plotId, "LeavingCar") > 4 then
					return label .. " more than 4 leaving cars"
				end
				if displayedCount(plotId) ~= snapshot.placementCount then
					return label .. " DisplayedTrees differ from placementCount"
				end
				if summary.activeCustomers > summary.parkingSpaces then
					return label .. " active customers exceed parking"
				end
			end
			if strayHumanoids() > 0 then
				return "stray Humanoid in the world"
			end
			return nil
		end

		local ticks = totalSeconds // 5
		for tick = 1, ticks do
			for _, userId in companies do
				stockAndPlace(userId)
			end
			if (tick - 1) % 6 == 0 then
				for _, userId in companies do
					orderMore(userId)
				end
			end
			if tick % 4 == 0 then
				for _, userId in companies do
					local summary = summaryOf(userId)
					if summary and hasDisplayedMedium(plotOf(userId)) then
						local profile = 8 + 24 * (visitCounter % 9)
						visitCounter += 1
						local response = invoke("visit", { userId = userId, profile = profile })
						tries += 1
						if type(response) == "table" and response.ok == true then
							forced += 1
						elseif type(response) == "table" and response.errorCode == "NoParking" then
							call("npcNextArrival", { userId = userId, profile = profile })
							nextArrivals += 1
						end
					end
				end
			end
			servePlayerOrders()
			local result = serveCounter()
			if result == "served" then
				served += 1
			elseif result == "handsFull" or result == "refused" then
				refused += 1
				if firstRefusal == "-" then
					firstRefusal = result
				end
			end
			for _, entry in npcSnapshot().visits do
				if not entry.loadTest and entry.state == "CheckingOut" and type(entry.plotId) == "string" then
					local plotSeen = seen[entry.plotId] or {}
					seen[entry.plotId] = plotSeen
					plotSeen[entry.visitId] = true
				end
			end
			for _, userId in companies do
				trackActive(userId)
			end
			if tick % 6 == 0 then
				samples += 1
				local problem = sample()
				if problem then
					mismatches += 1
					if firstMismatch == "" then
						firstMismatch = string.format("sample %d: %s", samples, problem)
					end
				end
			end
			local wait = startClock + tick * 5 - os.clock()
			if wait > 0 then
				task.wait(wait)
			end
		end

		local endR, endS = snap(R.userId), snap(S.userId)
		local sales = (endR.sales - startR.sales) + (endS.sales - startS.sales)
		local playerLoads = endR.loadedOrders - startR.loadedOrders
		local workerLoads = endS.loadedOrders - startS.loadedOrders
		local expiries = (endR.missedPickups - startR.missedPickups) + (endS.missedPickups - startS.missedPickups)
		local drivePasts = (endR.drivePastCustomers - startR.drivePastCustomers)
			+ (endS.drivePastCustomers - startS.drivePastCustomers)
		-- Fix round 1 (P7): walking customers of the live loop never snap.
		local endNpc = npcSnapshot()
		local npcSnaps = (endNpc.customerSnaps or 0) - snapsBefore
		local detail = string.format(
			"%d s, %d samples, %d mismatches, sales %d, player loads %d, worker loads %d, expiries %d, drive-pasts %d, max active %d/%d, memory %d→%d MB, npc snaps %d",
			math.floor(os.clock() - startClock + 0.5),
			samples,
			mismatches,
			sales,
			playerLoads,
			workerLoads,
			expiries,
			drivePasts,
			maxActive,
			maxSpaces,
			math.floor(memoryStart),
			math.floor(Stats:GetTotalMemoryUsageMb()),
			npcSnaps
		)
		local function seenOn(plotId: string?): number
			local plotSeen = if plotId then seen[plotId] else nil
			local count = 0
			if plotSeen then
				for _ in plotSeen do
					count += 1
				end
			end
			return count
		end
		detail ..= string.format(
			" | R sales %d visits %d abandoned %d walked out %d drive-pasts %d at counter %d served %d refused %d (%s) | S sales %d visits %d abandoned %d walked out %d drive-pasts %d at counter %d cashier %d | forced %d/%d next-arrival %d",
			endR.sales - startR.sales,
			endR.customerVisits - startR.customerVisits,
			endR.abandonedCustomers - startR.abandonedCustomers,
			endR.walkedOutCustomers - startR.walkedOutCustomers,
			endR.drivePastCustomers - startR.drivePastCustomers,
			seenOn(R.plotId),
			served,
			refused,
			firstRefusal,
			endS.sales - startS.sales,
			endS.customerVisits - startS.customerVisits,
			endS.abandonedCustomers - startS.abandonedCustomers,
			endS.walkedOutCustomers - startS.walkedOutCustomers,
			endS.drivePastCustomers - startS.drivePastCustomers,
			seenOn(S.plotId),
			endS.staff.Cashier,
			forced,
			tries,
			nextArrivals
		)
		ctx.emit("DETAIL 03 " .. detail)
		if npcSnaps > 0 then
			local log = if type(endNpc.snapLog) == "table" then endNpc.snapLog else {}
			local firstNew = log[math.max(1, #log - npcSnaps + 1)]
			local entry = if firstNew ~= nil then snapEntryText(firstNew) else "no snap-log entry"
			error("walking customers snapped (" .. entry .. ") | " .. detail, 0)
		end
		check(mismatches == 0, firstMismatch .. " | " .. detail)
		check(endS.staff.Cashier == 1, "shadow lost its Cashier | " .. detail)
		check(
			endS.walkedOutCustomers - startS.walkedOutCustomers == 0,
			"S customers walked out despite the Cashier | " .. detail
		)
		check(refused == 0, "R checkout refused (" .. firstRefusal .. ") | " .. detail)
		check(sales >= 10, "sales below 10 | " .. detail)
		check(playerLoads >= 1, "no player load | " .. detail)
		check(workerLoads >= 1, "no Lot Worker load | " .. detail)
		check(expiries >= 1, "no expiry | " .. detail)
		return detail
	end)

	-- CM2-N1: 24 NPCs on plots 1-6 (including the mirrored ones) keep >= 55 FPS; CM2-25/26
	-- adds 12 walking load staff (2 per plot).
	addStep("03a", "NPC_LOAD", { "01" }, function()
		call("pauseCustomers", true)
		-- Fix round 1 (P2): real visits still live from soak 03 would take budget room.
		resetCustomers()
		local result = call("npcLoadTest", { seconds = 60, staff = true })
		local detail = string.format(
			"spawned %d, peak %d, staff %d (peak %d), %d windows, min %.1f FPS, mean %.1f FPS, snaps %d, left %d",
			result.spawned,
			result.peakLive,
			result.staffSpawned,
			result.peakStaff,
			result.windows,
			result.minFps,
			result.meanFps,
			result.snaps,
			result.left
		)
		check(result.spawned == 24, "spawned is not 24 | " .. detail)
		check(result.peakLive == 24, "peak live is not 24 | " .. detail)
		check(result.staffSpawned == 12, "staff spawned is not 12 | " .. detail)
		check(result.peakStaff >= 12, "staff peak is below 12 | " .. detail)
		check(result.minFps >= 55, "a window ran below 55 FPS | " .. detail)
		check(result.snaps == 0, "load NPCs snapped | " .. detail)
		check(result.left == 0, "load NPCs left over | " .. detail)
		return detail
	end)

	-- CM2-47: HQ level 2 on one mirrored (north, Plot_04..06) and one road-side (south,
	-- Plot_01..03) plot that belong to neither R nor S has the same art shape, sits at the lot
	-- frame centre and faces the road (replaces the blocked road capture). Both levels are
	-- restored afterwards.
	addStep("03b", "HQ2_MIRROR", { "01" }, function()
		local WorldService = require(ctx.Services:WaitForChild("WorldService")) :: any
		local Shared = ctx.ReplicatedStorage:WaitForChild("Shared")
		local LotArt = require(Shared:WaitForChild("LotArt")) :: any
		local Stocking = require(Shared:WaitForChild("Stocking")) :: any

		local function firstFree(ids: { string }): string?
			for _, plotId in ids do
				if plotId ~= R.plotId and plotId ~= S.plotId then
					return plotId
				end
			end
			return nil
		end

		local northId = firstFree({ "Plot_04", "Plot_05", "Plot_06" })
		local southId = firstFree({ "Plot_01", "Plot_02", "Plot_03" })
		check(northId ~= nil, "no free plot among Plot_04..06")
		check(southId ~= nil, "no free plot among Plot_01..03")
		local ids = { northId :: string, southId :: string }
		local plots: { Model } = {}
		local levels: { number } = {}
		for index, plotId in ids do
			local plot = plotFolder(plotId)
			check(plot ~= nil and plot:IsA("Model") and plot.PrimaryPart ~= nil, plotId .. " is missing")
			plots[index] = plot :: Model
			local level = (plot :: Instance):GetAttribute("HqLevel")
			levels[index] = if type(level) == "number" then level else 1
		end

		local partCount, worst = 0, 0
		local function measure()
			for _, plotId in ids do
				check(WorldService.applyHQVisual(plotId, 2) == true, "applyHQVisual refused " .. plotId)
			end
			local pivots: { CFrame } = {}
			local parts: { { BasePart } } = {}
			for index, plotId in ids do
				local plot = plots[index]
				local c = (plot.PrimaryPart :: BasePart).Position
				local facing = Stocking.facing(c.Z)
				local hq = plot:FindFirstChild("StarterSalesTent")
				check(hq ~= nil and hq:IsA("Model"), plotId .. " StarterSalesTent is missing")
				local tent = hq :: Model
				check(
					tent:GetAttribute("HqLevel") == 2,
					plotId .. " HqLevel is " .. tostring(tent:GetAttribute("HqLevel"))
				)
				check(
					tent:GetAttribute("HqArtMode") == "Art",
					plotId .. " HqArtMode is " .. tostring(tent:GetAttribute("HqArtMode"))
				)
				local pivot = tent:GetPivot()
				local cx, cz = LotArt.hqCentre(2)
				local lx, lz = pivot.Position.X - c.X, (pivot.Position.Z - c.Z) * facing
				check(
					math.abs(lx - cx) <= 0.1 and math.abs(lz - cz) <= 0.1,
					string.format("%s HQ2 at lot (%.2f, %.2f), expected (%.2f, %.2f)", plotId, lx, lz, cx, cz)
				)
				check(
					pivot.LookVector.Z * facing >= 0.999,
					string.format("%s HQ2 does not face the road (look z %.3f)", plotId, pivot.LookVector.Z)
				)
				local counter = plot:FindFirstChild("CheckoutCounter")
				check(counter ~= nil and counter:IsA("Model"), plotId .. " CheckoutCounter is missing")
				check(
					(counter :: Model):GetPivot().LookVector.Z * facing >= 0.999,
					plotId .. " CheckoutCounter does not face the road"
				)
				pivots[index] = pivot
				local list: { BasePart } = {}
				for _, descendant in tent:GetDescendants() do
					if descendant:IsA("BasePart") then
						table.insert(list, descendant)
					end
				end
				parts[index] = list
			end
			check(
				#parts[1] == #parts[2],
				string.format("HQ2 part counts differ: north %d, south %d", #parts[1], #parts[2])
			)
			partCount = #parts[1]
			for position = 1, partCount do
				local north, south = parts[1][position], parts[2][position]
				check(
					north.Name == south.Name,
					string.format(
						"HQ2 part %d is %s on the north plot, %s on the south plot",
						position,
						north.Name,
						south.Name
					)
				)
				local a = pivots[1]:ToObjectSpace(north.CFrame)
				local b = pivots[2]:ToObjectSpace(south.CFrame)
				local offset = (a.Position - b.Position).Magnitude
				worst = math.max(worst, offset)
				check(
					offset <= 0.05 and a.LookVector:Dot(b.LookVector) >= 0.999 and a.UpVector:Dot(b.UpVector) >= 0.999,
					string.format(
						"HQ2 part %d (%s) differs between the plots (%.3f studs)",
						position,
						north.Name,
						offset
					)
				)
			end
		end

		local measured, measureError = pcall(measure)
		local restoreError: string? = nil
		for index, plotId in ids do
			local restored, applied = pcall(WorldService.applyHQVisual, plotId, levels[index])
			if (not restored or applied ~= true) and restoreError == nil then
				restoreError = "restoring HQ level of " .. plotId .. " failed"
			end
		end
		if not measured then
			error(measureError, 0)
		end
		check(restoreError == nil, restoreError or "")
		return string.format("north %s south %s parts %d worst %.3f", ids[1], ids[2], partCount, worst)
	end)

	addStep("04", "LEAK_CHECK", { "01" }, function()
		call("pauseCustomers", true)
		-- Fix round 1 (P4): orders expire from the server clock; no npcReset here, so this
		-- step still proves that natural visits end.
		expireOrders()
		-- Walking customers finish their visits; a waiting one leaves when its order expires.
		local deadline = os.clock() + 180
		while true do
			local snapshot = npcSnapshot()
			if snapshot.count == 0 then
				break
			end
			check(os.clock() < deadline, snapshot.count .. " walking customer(s) still alive after 180 s")
			for _, customer in snapshot.visits do
				if customer.state == "WaitingAtCar" then
					expireOrders()
					break
				end
			end
			task.wait(5)
		end
		task.wait(8)
		return leakCheck()
	end)
	addStep("05", "CLEANUP", {}, cleanup)
end
