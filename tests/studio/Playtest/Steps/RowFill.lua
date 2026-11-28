--!strict
-- Playtest step 36 (full mode): row fill (CM2-G14).
-- Installed by RunPlaytest.execute (CM2-RF).
-- Step details (moved from docs/TEST_PLAN.md, CM2-FAST):
-- `36 ROW_FILL` (CM2-G14: `OutsideLot`, `KeepClear` and a blocked row change nothing; a row of 5
-- lands as a whole (CM2-25/26: at x −24.4, z −20, clear of every break-area candidate; TooClose
-- probe at x −19.3) and its replay is `DuplicateRequest`; `TooClose`; store back ×5 and a second
-- store is `UnknownPlacement`; the Douglas Medium total is unchanged)
return function(ctx: any)
	local DELIVERY_WAIT = ctx.DELIVERY_WAIT
	local HttpService = ctx.HttpService
	local R = ctx.R
	local SIZE = ctx.SIZE
	local UNIT_PRICE = ctx.UNIT_PRICE
	local act = ctx.act
	local actOk = ctx.actOk
	local addStep = ctx.addStep
	local advance = ctx.advance
	local awaitDelivery = ctx.awaitDelivery
	local bayWith = ctx.bayWith
	local breakAreaCovers = ctx.breakAreaCovers
	local check = ctx.check
	local displayedCount = ctx.displayedCount
	local douglasTotal = ctx.douglasTotal
	local orderTrees = ctx.orderTrees
	local poll = ctx.poll
	local snap = ctx.snap
	local stockPayload = ctx.stockPayload

	-- CM2-25/26 Amendment 1: the row line clears every break-area candidate and the Stand box.
	local ROW_X = -24.4
	local ROW_Z = -20
	local PROBE_X = -19.3

	-- CM2-G14: the three spot reasons, a row fill of 5 (all or none), replay protection and
	-- store mode without duplication. The trees stay in R's bay for the next run.
	addStep("36", "ROW_FILL", { "08" }, function()
		local function refused(payload: any, expected: string)
			local beforeRefusal = snap(R.userId)
			local response = act(R.userId, "Stock.Place", payload)
			local code = type(response) == "table" and response.errorCode or response
			check(code == expected, string.format("Stock.Place returned %s, expected %s", tostring(code), expected))
			local afterRefusal = snap(R.userId)
			check(afterRefusal.placementCount == beforeRefusal.placementCount, "a refused place changed placements")
			check(
				HttpService:JSONEncode(afterRefusal.bays) == HttpService:JSONEncode(beforeRefusal.bays),
				"a refused place changed the bays"
			)
		end
		local function storeOk(placementId: string)
			actOk(R.userId, "Stock.Store", { placementId = placementId })
		end

		-- 1. A failed earlier run may have left trees on the row line.
		local cleared = 0
		for _, placement in snap(R.userId).placements do
			if placement.z == -20 and not placement.reserved then
				storeOk(placement.placementId)
				cleared += 1
			end
		end
		if cleared > 0 then
			task.wait(10) -- stay under the per-action rate limit
		end

		-- 2. Five Medium Douglas Fir in one bay.
		if bayWith(R.userId, 5) == nil then
			check(snap(R.userId).cash >= 5 * UNIT_PRICE, "cash below " .. 5 * UNIT_PRICE)
			local data = orderTrees(R.userId, 5)
			advance(DELIVERY_WAIT)
			awaitDelivery(R.userId, data.orderId)
		end
		local bay = bayWith(R.userId, 5)
		check(bay ~= nil, "no bay with 5 Medium Douglas Fir")
		local bayIndex = bay :: number
		local start = snap(R.userId)
		local startTotal = douglasTotal(start)
		for _, x in { -24.4, -18.3, -12.2, -6.1, 0, PROBE_X } do
			check(not breakAreaCovers(start.breakArea, x, ROW_Z), "R's break area covers the row line at x " .. x)
		end

		-- 3. The three reasons; nothing changes after a refusal.
		refused(stockPayload(bayIndex, 39.5, 0, 1), "OutsideLot")
		refused(stockPayload(bayIndex, -10, 22, 1), "KeepClear")
		refused(stockPayload(bayIndex, 10, -20, 5), "KeepClear")

		-- 4. A row of 5 lands as a whole; its replay places nothing.
		local requestId = "playtest_row_" .. HttpService:GenerateGUID(false)
		local beforeRow = snap(R.userId)
		local response = act(R.userId, "Stock.Place", stockPayload(bayIndex, ROW_X, ROW_Z, 5), requestId)
		check(
			type(response) == "table" and response.ok == true,
			"row fill failed: " .. tostring(type(response) == "table" and response.errorCode or response)
		)
		local ids = response.data.placementIds
		check(#ids == 5, #ids .. " placement IDs")
		local afterRow = snap(R.userId)
		check(afterRow.placementCount == beforeRow.placementCount + 5, "placementCount did not grow by 5")
		check(
			afterRow.bays[bayIndex].counts[SIZE] == beforeRow.bays[bayIndex].counts[SIZE] - 5,
			"the bay did not lose 5 trees"
		)
		local shown = poll(function()
			return displayedCount(R.plotId) == snap(R.userId).placementCount
		end, 4)
		check(shown, "DisplayedTrees differs from placementCount after the row fill")
		local replay = act(R.userId, "Stock.Place", stockPayload(bayIndex, ROW_X, ROW_Z, 5), requestId)
		check(
			type(replay) == "table" and replay.errorCode == "DuplicateRequest",
			"row replay returned " .. tostring(type(replay) == "table" and replay.errorCode or replay)
		)
		check(snap(R.userId).placementCount == afterRow.placementCount, "the replay placed trees")

		-- 5. With the first tree (x -24.4) stored back, the second (x -18.3) blocks PROBE_X, 1 stud away.
		storeOk(ids[1])
		local storedIn = bayWith(R.userId, 1)
		check(storedIn ~= nil, "the stored tree is in no bay")
		refused(stockPayload(storedIn :: number, PROBE_X, ROW_Z, 1), "TooClose")
		for index = 2, 5 do
			storeOk(ids[index])
		end

		-- 6. A stored tree cannot be stored twice.
		local again = act(R.userId, "Stock.Store", { placementId = ids[2] })
		check(
			type(again) == "table" and again.errorCode == "UnknownPlacement",
			"second store returned " .. tostring(type(again) == "table" and again.errorCode or again)
		)

		-- 7. No tree was created or lost.
		local finalTotal = douglasTotal(snap(R.userId))
		check(finalTotal == startTotal, string.format("Douglas Medium total %d -> %d", startTotal, finalTotal))
		return string.format("3 reasons, row of 5 and replay, store back x5, total %d kept", finalTotal)
	end)
end
