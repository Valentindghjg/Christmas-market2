--!strict
-- Playtest fixtures: shadow join, resets, NPC cleanup, preflight, leak check and cleanup.
-- Installed by RunPlaytest.execute (CM2-RF).
-- Step details (moved from docs/TEST_PLAN.md, CM2-FAST):
-- leak check (also: no `CheckoutPrompt` enabled on R's or S's plot; no live NPC, an empty
-- `<plot>.Customers`, no `VisitCar_` or `NpcCarriedTree` outside a `Staff` folder; Humanoids of
-- live NPCs and of live staff (`StaffId` in `staffSnapshot`) are not stray), cleanup (back on
-- "Playtest A", test saves including "Playtest Duo", "Playtest Far" and the finder save removed,
-- the fake map entry cleared, both synthetic users leave, no NPC left on the shadow plot within 3
-- s)
-- **Reset rule (CM2-N1 fix round 1):** `resetCustomers()` pauses customers, calls `npcReset`, lets
-- open customer orders of R (and S while joined) expire from the server clock (`snapshot.clock`, at
-- most 3 rounds of `advance(max(expiresAt) − clock + 1)`), then waits up to 8 s for clean plots, no
-- NPC objects and no reserved placement on R; it never loads an order or changes cash. It runs at
-- the start of PREFLIGHT (both modes), in soak 03a and at the start of cleanup; steps 37–40 always
-- end with it, and the step's own error wins over the reset error. CM2-ART2 Amendment 1: PREFLIGHT
-- lands in-flight deliveries of R and S (advance to the latest arrivesIn + 1), stores every tree on
-- the shadow's lot back into its bays (CM2-PT35b), sells back every tree in the shadow's bays and
-- requires 0 shadow bays in use and 0 trees on the shadow's lot; step 52 sells its Express Sleigh
-- tree back; a supplier sell-out retry advances to refreshIn + 1.
-- Request IDs in playtest steps are unique per run (`<prefix>_` .. GUID): S's save and its
-- `recentRequests` persist across Play sessions, so a fixed ID replays as `DuplicateRequest` in the
-- next run (CM2-G9a A2).
-- PREFLIGHT (03) first ends every Cash Rush (`shopClearBoosts`) and clears R's test pass overrides
-- (`shopPasses`), so manual shop checks before a run cannot double sale cash (CM2-UVF8). It also
-- sets R's Lot Worker and Cashier to 0 (`setStaff` with `userId`) and names the reset in its
-- detail.
return function(ctx: any)
	local Players = ctx.Players
	local R = ctx.R
	local S = ctx.S
	local SAVE_A = ctx.SAVE_A
	local SAVE_B = ctx.SAVE_B
	local SAVE_B2 = ctx.SAVE_B2
	local SAVE_C = ctx.SAVE_C
	local SAVE_DUO = ctx.SAVE_DUO
	local SAVE_FAR = ctx.SAVE_FAR
	local SAVE_T = ctx.SAVE_T
	local SAVE_T2 = ctx.SAVE_T2
	local UNIT_PRICE = ctx.UNIT_PRICE
	local GameConfig = ctx.GameConfig
	local act = ctx.act
	local actOk = ctx.actOk
	local advance = ctx.advance
	local call = ctx.call
	local carriedTreeOnAnyCharacter = ctx.carriedTreeOnAnyCharacter
	local check = ctx.check
	local checkoutPrompt = ctx.checkoutPrompt
	local deleteFar = ctx.deleteFar
	local deleteFinderSave = ctx.deleteFinderSave
	local deleteLeftover = ctx.deleteLeftover
	local displayedCount = ctx.displayedCount
	local findSave = ctx.findSave
	local npcObjectsLeft = ctx.npcObjectsLeft
	local npcOnPlot = ctx.npcOnPlot
	local npcSnapshot = ctx.npcSnapshot
	local playSave = ctx.playSave
	local plotClean = ctx.plotClean
	local poll = ctx.poll
	local priceToSell = ctx.priceToSell
	local realPlayer = ctx.realPlayer
	local snap = ctx.snap
	local staffSnapshot = ctx.staffSnapshot
	local strayHumanoids = ctx.strayHumanoids

	-- Shared between steps of one run.
	local shadowJoined = false

	local function shadowJoin(lotWorker: number)
		local data = call("shadowJoin", nil)
		shadowJoined = true
		S.plotId = data.plotId
		check(S.plotId ~= R.plotId, "shadow plot equals player plot " .. tostring(S.plotId))
		call("setStaff", { employeeId = "LotWorker", count = lotWorker })
		priceToSell(S.userId)
	end

	-- The companies whose customers a reset clears: R, and S while the shadow is joined.
	local function resetUsers(): { number }
		local users = { R.userId }
		if shadowJoined then
			table.insert(users, S.userId)
		end
		return users
	end

	-- Fix round 1 (P1, P4): lets open customer orders expire from the server's own clock
	-- (snapshot.clock), at most 3 rounds per company. It never loads an order or changes cash;
	-- an expiry only adds missedPickups and the reputation penalty.
	local function expireOrders()
		for _, userId in resetUsers() do
			for _ = 1, 3 do
				local snapshot = snap(userId)
				if #snapshot.customerOrders == 0 then
					break
				end
				local latest = -math.huge
				for _, order in snapshot.customerOrders do
					if type(order.expiresAt) == "number" then
						latest = math.max(latest, order.expiresAt)
					end
				end
				local clock = if type(snapshot.clock) == "number" then snapshot.clock else 0
				advance(math.clamp(latest - clock + 1, 1, 3600))
				poll(function()
					return #snap(userId).customerOrders == 0
				end, 8)
			end
		end
	end

	-- Fix round 1 (P1): removes every walking customer at once, expires the open customer
	-- orders and waits until both plots are clean. Customers stay paused.
	local function resetCustomers()
		call("pauseCustomers", true)
		call("npcReset", nil)
		expireOrders()
		local function leftover(): string?
			if not plotClean(R.plotId) then
				return tostring(R.plotId) .. " order objects"
			end
			if not plotClean(S.plotId) then
				return tostring(S.plotId) .. " order objects"
			end
			local npcLeft = npcObjectsLeft({ R.plotId, S.plotId })
			if npcLeft ~= nil then
				return npcLeft
			end
			for _, placement in snap(R.userId).placements do
				if placement.reserved then
					return placement.placementId .. " reserved"
				end
			end
			return nil
		end
		local clean = poll(function()
			return leftover() == nil
		end, 8)
		if not clean then
			error("reset: " .. tostring(leftover()), 0)
		end
	end

	-- Fix round 1 (P3): the NPC steps always end with a reset, so a failure leaves no waiting
	-- visit, car or order behind. The step's own error wins over the reset error.
	local function withNpcCleanup(fn: () -> string?): () -> string?
		return function()
			local ok, detail = pcall(fn)
			local resetOk, resetError = pcall(resetCustomers)
			if not ok then
				error(detail, 0)
			end
			if not resetOk then
				error(resetError, 0)
			end
			return detail
		end
	end

	-- CM2-ART2 A1: lands the in-flight deliveries of one company by advancing the server clock
	-- past the latest arrival. Returns how many bays had a delivery on the way.
	local function settleDeliveries(userId: number): number
		local count, latest = 0, 0
		for _, bay in snap(userId).bays do
			if bay.arriving > 0 then
				count += 1
				latest = math.max(latest, bay.arrivesIn)
			end
		end
		if count == 0 then
			return 0
		end
		advance(math.clamp(latest + 1, 1, 86400))
		local landed = poll(function()
			for _, bay in snap(userId).bays do
				if bay.arriving > 0 then
					return false
				end
			end
			return true
		end, 8)
		check(landed, "deliveries still arriving 8 s after the clock advance")
		return count
	end

	-- CM2-ART2 A1: sells back every tree in the shadow's bays so each run starts with 0 bays
	-- used. Never touches R. Returns the sold-back list or "none".
	local function drainShadowBays(): string
		local stock = snap(S.userId).stock
		local keys: { string } = {}
		for key, count in stock do
			if count > 0 then
				table.insert(keys, key)
			end
		end
		table.sort(keys)
		local parts: { string } = {}
		for _, key in keys do
			local count = stock[key]
			local speciesId, sizeId = string.match(key, "^(.-):(.+)$")
			check(speciesId ~= nil and sizeId ~= nil, "unreadable stock key " .. key)
			local left = count
			while left > 0 do
				local chunk = math.min(left, GameConfig.MaxOrderQuantity)
				actOk(S.userId, "Supplier.SellBack", { speciesId = speciesId, sizeId = sizeId, quantity = chunk })
				left -= chunk
			end
			table.insert(parts, string.format("%s x%d", key, count))
		end
		return if #parts == 0 then "none" else table.concat(parts, ", ")
	end

	-- CM2-PT35b: stores every tree on the shadow's lot back into its bays, so each run starts with
	-- an empty shadow lot (steps 20, 44 and 52 leave trees, and the shadow keeps one Solo save).
	-- Never touches R. Returns the stored count.
	local function clearShadowLot(): number
		local stored = 0
		for _, placement in snap(S.userId).placements do
			local response = act(S.userId, "Stock.Store", { placementId = placement.placementId })
			if
				type(response) == "table"
				and (response.errorCode == "NoFreeBay" or response.errorCode == "StorageFull")
			then
				drainShadowBays()
				actOk(S.userId, "Stock.Store", { placementId = placement.placementId })
			else
				check(
					type(response) == "table" and response.ok == true,
					"Stock.Store failed: " .. tostring(type(response) == "table" and response.errorCode or response)
				)
			end
			stored += 1
			task.wait(1)
		end
		return stored
	end

	-- CM2-UVF8 A1: sets R's Lot Worker and Cashier to 0 (manual checks may leave them) and names the reset.
	local function resetPlayerStaff(): string
		local before = snap(R.userId).staff
		local notes: { string } = {}
		for _, id in { "LotWorker", "Cashier" } do
			local count = before[id] or 0
			if count ~= 0 then
				call("setStaff", { userId = R.userId, employeeId = id, count = 0 })
				table.insert(notes, string.format("%s %d->0", id, count))
			end
		end
		if #notes > 0 then
			check(
				poll(function()
					for _, entry in staffSnapshot().staff do
						if entry.plotId == R.plotId and (entry.role == "LotWorker" or entry.role == "Cashier") then
							return false
						end
					end
					return true
				end, 5),
				"R's staff NPCs still present 5 s after the staff reset"
			)
		end
		return if #notes == 0 then "none" else table.concat(notes, ", ")
	end

	local function preflight(soak: boolean): string
		resetCustomers()
		-- CM2-UVF8: manual shop checks may leave a Cash Rush or a pass override on R; sales steps expect x1 cash.
		call("shopClearBoosts", nil)
		call("shopPasses", { userId = R.userId, passes = {} })
		local staffReset = if soak then "skipped" else resetPlayerStaff()
		-- CM2-G12a: every run starts in the morning; call() checks each response is ok.
		call("setDay", { userId = R.userId, elapsed = 0 })
		if shadowJoined then
			call("setDay", { userId = S.userId, elapsed = 0 })
		end
		settleDeliveries(R.userId)
		local drained = "none"
		local cleared = 0
		if shadowJoined then
			settleDeliveries(S.userId)
			cleared = clearShadowLot()
			drained = drainShadowBays()
			check(snap(S.userId).receiving.baysUsed == 0, "shadow bays not empty after the drain")
			check(snap(S.userId).placementCount == 0, "shadow lot not empty after the clear")
		end
		check(#Players:GetPlayers() == 1, "expected exactly 1 player, got " .. #Players:GetPlayers())
		local current = realPlayer()
		check(current:GetAttribute("CompanyReady") == true, "CompanyReady is not true")
		check(type(R.plotId) == "string", "player has no PlotId")
		local snapshot = snap(R.userId)
		check(snapshot.purchases.boosts.CashX2 == 0, "Cash Rush time left on R after shopClearBoosts")
		check(#snapshot.customerOrders == 0, "player still has customer orders")
		priceToSell(R.userId)
		if not soak then
			check(snapshot.staff.LotWorker == 0, "player has a Lot Worker hired after the staff reset")
			check(snapshot.staff.Cashier == 0, "player has a Cashier hired after the staff reset")
			check(snapshot.cash >= 2 * UNIT_PRICE, "cash below " .. 2 * UNIT_PRICE)
		else
			check(snapshot.cash >= UNIT_PRICE, "cash below " .. UNIT_PRICE)
		end
		check(snapshot.receiving.baysUsed < snapshot.receiving.bayCount, "no free receiving bay")
		check(snapshot.receiving.storageCapacity - snapshot.receiving.storageUsed >= 3, "storage room below 3")
		if not shadowJoined then
			return string.format(
				"cash %d, bays %d/%d, no shadow, staff reset: %s",
				snapshot.cash,
				snapshot.receiving.baysUsed,
				snapshot.receiving.bayCount,
				staffReset
			)
		end
		return string.format(
			"cash %d, bays %d/%d, shadow bays 0/%d, sold back %s, shadow lot cleared %d, staff reset: %s",
			snapshot.cash,
			snapshot.receiving.baysUsed,
			snapshot.receiving.bayCount,
			snapshot.receiving.bayCount,
			drained,
			cleared,
			staffReset
		)
	end

	local function leakCheck(): string
		local ok = poll(function()
			return plotClean(R.plotId) and plotClean(S.plotId)
		end, 4)
		check(ok, "plot objects left over (R or S)")
		local rSnap, sSnap = snap(R.userId), snap(S.userId)
		check(
			displayedCount(R.plotId) == rSnap.placementCount,
			string.format("R DisplayedTrees %d vs placementCount %d", displayedCount(R.plotId), rSnap.placementCount)
		)
		check(
			displayedCount(S.plotId) == sSnap.placementCount,
			string.format("S DisplayedTrees %d vs placementCount %d", displayedCount(S.plotId), sSnap.placementCount)
		)
		check(not carriedTreeOnAnyCharacter(), "a CarriedTree is left on a character")
		-- CM2-N1: no walking customer and none of its objects is left.
		local npcCount = npcSnapshot().count
		check(npcCount == 0, npcCount .. " walking customer(s) still alive")
		local npcLeft = npcObjectsLeft({ R.plotId, S.plotId })
		check(npcLeft == nil, tostring(npcLeft))
		local stray = strayHumanoids()
		check(stray == 0, stray .. " Humanoid(s) outside player characters")
		-- CM2-N2: no counter prompt stays enabled without a customer at the counter.
		for _, plotId in { R.plotId, S.plotId } do
			check(not checkoutPrompt(plotId).Enabled, "checkout prompt still enabled on " .. tostring(plotId))
		end
		return "plots clean, no NPC left, no stray Humanoid"
	end

	local function cleanup(): string
		local errors: { string } = {}
		local function attempt(label: string, fn: () -> ())
			local ok, message = pcall(fn)
			if not ok then
				table.insert(errors, label .. ": " .. tostring(message))
			end
		end
		-- Fix round 1 (P2): no walking customer, waiting car or open order survives the run.
		attempt("reset customers", resetCustomers)
		if shadowJoined then
			attempt("setStaff", function()
				call("setStaff", { employeeId = "LotWorker", count = 0 })
				call("setStaff", { employeeId = "Cashier", count = 0 })
			end)
			-- CM2-46a Amendment 1: no Cash Rush time or test pass survives the run.
			attempt("shop boosts", function()
				call("shopClearBoosts", nil)
				call("shopPasses", { userId = S.userId, passes = {} })
			end)
		end
		-- CM2-S3: the finder save needs the shadow's live profile, so it goes before shadowLeave.
		attempt("delete finder save", function()
			deleteFinderSave()
		end)
		attempt("shadowLeave", function()
			call("shadowLeave", nil)
		end)
		-- CM2-N1: the shadow's walking customers leave with it.
		attempt("shadow NPCs", function()
			if S.plotId ~= nil then
				local gone = poll(function()
					return npcOnPlot(S.plotId) == 0
				end, 3)
				check(gone, "a walking customer is still on the shadow plot 3 s after shadowLeave")
			end
		end)
		attempt("shadow2Leave", function()
			call("shadow2Leave", nil)
		end)
		attempt("S DisplayedTrees", function()
			check(S.plotId == nil or displayedCount(S.plotId) == 0, "S plot still shows trees")
		end)
		attempt("pauseCustomers", function()
			call("pauseCustomers", false)
		end)
		-- CM2-S1: end on Playtest A and remove the saves this run created.
		attempt("play " .. SAVE_A, function()
			local entry = findSave(SAVE_A)
			if entry and not entry.active then
				playSave(entry.saveId)
			end
		end)
		for _, name in { SAVE_B, SAVE_B2, SAVE_C, SAVE_DUO, SAVE_T, SAVE_T2 } do
			attempt("delete " .. name, function()
				deleteLeftover(name)
			end)
		end
		attempt("delete " .. SAVE_FAR, function()
			deleteFar()
		end)
		check(#errors == 0, table.concat(errors, "; "))
		return "shadow left, customers unpaused, test saves removed"
	end

	ctx.shadowJoin = shadowJoin
	ctx.resetUsers = resetUsers
	ctx.expireOrders = expireOrders
	ctx.resetCustomers = resetCustomers
	ctx.withNpcCleanup = withNpcCleanup
	ctx.preflight = preflight
	ctx.leakCheck = leakCheck
	ctx.cleanup = cleanup
end
