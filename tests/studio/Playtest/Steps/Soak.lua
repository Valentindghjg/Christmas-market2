--!strict
-- Playtest soak steps 01a, 01, 02, 03, 03a, 04 and 05 (soak mode).
-- Installed by RunPlaytest.execute (CM2-RF).
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
	local shadowJoin = ctx.shadowJoin
	local snap = ctx.snap
	local snapEntryText = ctx.snapEntryText
	local strayHumanoids = ctx.strayHumanoids
	local teleport = ctx.teleport

	addStep("01a", "ACTIVE_SAVE", {}, activeSave)

	addStep("01", "SHADOW_JOIN", {}, function()
		shadowJoin(1)
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
					if
						summary
						and summary.parkingSpaces - summary.activeCustomers >= 1
						and hasDisplayedMedium(plotOf(userId))
					then
						local profile = 8 + 24 * (visitCounter % 9)
						visitCounter += 1
						invoke("visit", { userId = userId, profile = profile })
					end
				end
			end
			servePlayerOrders()
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
		if npcSnaps > 0 then
			local log = if type(endNpc.snapLog) == "table" then endNpc.snapLog else {}
			local firstNew = log[math.max(1, #log - npcSnaps + 1)]
			local entry = if firstNew ~= nil then snapEntryText(firstNew) else "no snap-log entry"
			error("walking customers snapped (" .. entry .. ") | " .. detail, 0)
		end
		check(mismatches == 0, firstMismatch .. " | " .. detail)
		check(sales >= 10, "sales below 10 | " .. detail)
		check(playerLoads >= 1, "no player load | " .. detail)
		check(workerLoads >= 1, "no Lot Worker load | " .. detail)
		check(expiries >= 1, "no expiry | " .. detail)
		return detail
	end)

	-- CM2-N1: 24 NPCs on plots 1-6 (including the mirrored ones) keep >= 55 FPS.
	addStep("03a", "NPC_LOAD", { "01" }, function()
		call("pauseCustomers", true)
		-- Fix round 1 (P2): real visits still live from soak 03 would take budget room.
		resetCustomers()
		local result = call("npcLoadTest", { seconds = 60 })
		local detail = string.format(
			"spawned %d, peak %d, %d windows, min %.1f FPS, mean %.1f FPS, snaps %d, left %d",
			result.spawned,
			result.peakLive,
			result.windows,
			result.minFps,
			result.meanFps,
			result.snaps,
			result.left
		)
		check(result.spawned == 24, "spawned is not 24 | " .. detail)
		check(result.peakLive == 24, "peak live is not 24 | " .. detail)
		check(result.minFps >= 55, "a window ran below 55 FPS | " .. detail)
		check(result.snaps == 0, "load NPCs snapped | " .. detail)
		check(result.left == 0, "load NPCs left over | " .. detail)
		return detail
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
