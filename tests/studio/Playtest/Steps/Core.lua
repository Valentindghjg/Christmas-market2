--!strict
-- Playtest steps 01, 02a, 02, 03 and 04-21 (full mode).
-- Installed by RunPlaytest.execute (CM2-RF).
return function(ctx: any)
	local Customers = ctx.Customers
	local DELIVERY_WAIT = ctx.DELIVERY_WAIT
	local EXPIRY_WAIT = ctx.EXPIRY_WAIT
	local HttpService = ctx.HttpService
	local R = ctx.R
	local ReplicatedStorage = ctx.ReplicatedStorage
	local S = ctx.S
	local SIZE = ctx.SIZE
	local SPECIES = ctx.SPECIES
	local STOCK_KEY = ctx.STOCK_KEY
	local ServerStorage = ctx.ServerStorage
	local SupplierStockService = ctx.SupplierStockService
	local UNIT_PRICE = ctx.UNIT_PRICE
	local act = ctx.act
	local activeSave = ctx.activeSave
	local addStep = ctx.addStep
	local advance = ctx.advance
	local assertOutOfOwnReach = ctx.assertOutOfOwnReach
	local awaitDelivery = ctx.awaitDelivery
	local call = ctx.call
	local carriedTree = ctx.carriedTree
	local check = ctx.check
	local countOrderObjects = ctx.countOrderObjects
	local displayedCount = ctx.displayedCount
	local findOrder = ctx.findOrder
	local hasObject = ctx.hasObject
	local isPending = ctx.isPending
	local orderPart = ctx.orderPart
	local orderTrees = ctx.orderTrees
	local placeOne = ctx.placeOne
	local plotClean = ctx.plotClean
	local plotFolder = ctx.plotFolder
	local poll = ctx.poll
	local preflight = ctx.preflight
	local prompt = ctx.prompt
	local realPlayer = ctx.realPlayer
	local sameTable = ctx.sameTable
	local shadowJoin = ctx.shadowJoin
	local snap = ctx.snap
	local teleport = ctx.teleport
	local visit = ctx.visit
	local Reviews = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Reviews")) :: any
	local ReputationByStars = ctx.GameConfig.Reviews.ReputationByStars

	local orderA, orderB, orderC = 0, 0, 0
	local pickupHome: Vector3 = Vector3.zero

	addStep("01", "UNIT_RUNNER", {}, function()
		local runner = require(ServerStorage:WaitForChild("UnitTest"):WaitForChild("RunUnitTest")) :: any
		local totals = runner(nil, 10)
		check(totals.failed == 0, totals.failed .. " unit test(s) failed")
		check(totals.run >= 418, "only " .. totals.run .. " unit tests ran (expected >= 418)")
		return string.format("%d run, %d passed", totals.run, totals.passed)
	end)

	addStep("02a", "ACTIVE_SAVE", {}, activeSave)

	addStep("02", "SHADOW_JOIN", {}, function()
		shadowJoin(0)
		call("pauseCustomers", true)
		return string.format("shadow plot %s, player plot %s", tostring(S.plotId), tostring(R.plotId))
	end)

	addStep("03", "PREFLIGHT", { "02" }, function()
		return preflight(false)
	end)

	local orderIds: { [number]: string } = {}
	local orderBays: { [number]: number } = {}
	local before: { [number]: any } = {}

	addStep("04", "ORDER", { "03" }, function()
		for _, userId in { R.userId, S.userId } do
			before[userId] = snap(userId)
			local data = orderTrees(userId, 2)
			orderIds[userId] = data.orderId
			orderBays[userId] = data.bay
			check(type(data.bay) == "number", "order has no receiving bay")
			local after = snap(userId)
			check(
				before[userId].cash - after.cash == 2 * UNIT_PRICE,
				string.format("cash delta %d, expected -%d", after.cash - before[userId].cash, 2 * UNIT_PRICE)
			)
			check(#after.pendingOrders == #before[userId].pendingOrders + 1, "pending orders did not grow by one")
		end
		return string.format("2 x %s each, cash -%d", STOCK_KEY, 2 * UNIT_PRICE)
	end)

	-- CM2-G14: the order lands in its own bay by itself (no unload step).
	addStep("05", "DELIVER", { "04" }, function()
		advance(DELIVERY_WAIT)
		local function landed(userId: number): boolean
			local snapshot = snap(userId)
			local bay = snapshot.bays[orderBays[userId]]
			return not isPending(snapshot, orderIds[userId]) and bay ~= nil and bay.counts[SIZE] == 2
		end
		local ok = poll(function()
			return landed(R.userId) and landed(S.userId)
		end, 8)
		check(ok, "orders not in their bays within 8 s")
		return string.format("bays %d (R) and %d (S) hold 2 each", orderBays[R.userId], orderBays[S.userId])
	end)

	addStep("06", "BAY_VIEW", { "05" }, function()
		for _, userId in { R.userId, S.userId } do
			local plotId = if userId == R.userId then R.plotId else S.plotId
			local plot = plotFolder(plotId)
			local receiving = plot and plot:FindFirstChild("Receiving")
			local bayPart = receiving and receiving:FindFirstChild("Bay_" .. orderBays[userId])
			check(bayPart ~= nil, "Bay_" .. orderBays[userId] .. " missing on " .. tostring(plotId))
			local part = bayPart :: Instance
			local expected = snap(userId).bays[orderBays[userId]].counts[SIZE]
			local shown = poll(function()
				return part:GetAttribute("SpeciesId") == SPECIES and part:GetAttribute("CountMedium") == expected
			end, 4)
			check(
				shown,
				string.format(
					"Bay_%d shows %s x%s, expected %s x%d",
					orderBays[userId],
					tostring(part:GetAttribute("SpeciesId")),
					tostring(part:GetAttribute("CountMedium")),
					SPECIES,
					expected
				)
			)
		end
		return "bay attributes match the snapshot"
	end)

	addStep("07", "PLACE", { "06" }, function()
		for _, userId in { R.userId, S.userId } do
			local count = snap(userId).placementCount
			placeOne(userId, orderBays[userId])
			placeOne(userId, orderBays[userId])
			local after = snap(userId)
			check(
				after.placementCount == count + 2,
				string.format("placementCount %d -> %d", count, after.placementCount)
			)
		end
		local ok = poll(function()
			return displayedCount(R.plotId) == snap(R.userId).placementCount
				and displayedCount(S.plotId) == snap(S.userId).placementCount
		end, 4)
		check(ok, "DisplayedTrees count differs from placementCount")
		return "2 trees placed each"
	end)

	addStep("08", "SALE", { "07" }, function()
		local first = snap(R.userId)
		orderA = visit(R.userId, 8)
		orderB = visit(R.userId, 32)
		check(orderA < orderB, string.format("orders not ascending: %d, %d", orderA, orderB))
		local after = snap(R.userId)
		check(after.sales == first.sales + 2, string.format("sales %d -> %d", first.sales, after.sales))
		local cashDelta = after.cash - first.cash
		check(
			cashDelta == after.revenue - first.revenue and cashDelta > 0,
			string.format("cash +%d vs revenue +%d", cashDelta, after.revenue - first.revenue)
		)
		check(after.placementCount == first.placementCount - 2, "placementCount did not drop by 2")
		local ok = poll(function()
			return hasObject(R.plotId, "CustomerCar_" .. orderA)
				and hasObject(R.plotId, "CustomerCar_" .. orderB)
				and hasObject(R.plotId, "PickupTree_" .. orderA)
				and hasObject(R.plotId, "PickupTree_" .. orderB)
		end, 3)
		check(ok, "cars or pickup trees missing within 3 s")
		pickupHome = (orderPart(R.plotId, "PickupTree_" .. orderA) :: BasePart).Position
		return string.format("orders #%d,#%d cash +%d", orderA, orderB, cashDelta)
	end)

	addStep("09", "CARRY", { "08" }, function()
		teleport(orderPart(R.plotId, "PickupTree_" .. orderA))
		prompt("carry", orderA)
		local order = findOrder(snap(R.userId), orderA)
		check(order and order.carried, "order " .. orderA .. " not carried")
		local tree = carriedTree()
		check(tree and tree:GetAttribute("OrderNumber") == orderA, "character has no CarriedTree for " .. orderA)
		local gone = poll(function()
			return not hasObject(R.plotId, "PickupTree_" .. orderA)
		end, 3)
		check(gone, "PickupTree_" .. orderA .. " still in the world")
		return "order #" .. orderA .. " carried"
	end)

	addStep("10", "HANDS_FULL", { "09" }, function()
		teleport(orderPart(R.plotId, "PickupTree_" .. orderB))
		prompt("carry", orderB)
		local snapshot = snap(R.userId)
		local second, first = findOrder(snapshot, orderB), findOrder(snapshot, orderA)
		check(second and not second.carried, "order " .. orderB .. " was carried despite full hands")
		check(first and first.carried, "order " .. orderA .. " no longer carried")
		return "second tree refused"
	end)

	addStep("11", "RESPAWN", { "09" }, function()
		local oldCharacter = realPlayer().Character
		call("respawn", R.userId)
		local ok = poll(function()
			local character = realPlayer().Character
			if not character or character == oldCharacter or not character:FindFirstChild("HumanoidRootPart") then
				return false
			end
			local order = findOrder(snap(R.userId), orderA)
			return order ~= nil and not order.carried and orderPart(R.plotId, "PickupTree_" .. orderA) ~= nil
		end, 3)
		check(ok, "order " .. orderA .. " not released with its pickup tree within 3 s")
		local tree = orderPart(R.plotId, "PickupTree_" .. orderA) :: BasePart
		local drift = (tree.Position - pickupHome).Magnitude
		check(drift <= 0.05, string.format("pickup tree moved %.3f studs", drift))
		check(carriedTree() == nil, "new character still has a CarriedTree")
		return "tree back at its pickup spot"
	end)

	addStep("12", "WRONG_CAR", { "11" }, function()
		teleport(orderPart(R.plotId, "PickupTree_" .. orderA))
		prompt("carry", orderA)
		local first = snap(R.userId)
		check(findOrder(first, orderA).carried, "order " .. orderA .. " not carried again")
		teleport(orderPart(R.plotId, "CustomerCar_" .. orderB))
		prompt("load", orderB)
		local after = snap(R.userId)
		check(findOrder(after, orderA).carried, "order " .. orderA .. " no longer carried")
		check(findOrder(after, orderB) ~= nil, "order " .. orderB .. " vanished")
		check(after.loadedOrders == first.loadedOrders, "loadedOrders changed at the wrong car")
		return "wrong car refused"
	end)

	addStep("13", "LOAD", { "12" }, function()
		local first = snap(R.userId)
		local soldAt = findOrder(first, orderA).expiresAt - Customers.PickupPatienceSeconds
		local clockNow = call("clock", nil)
		-- CM2-G15: the review's stars set the gain; a load that crosses a star boundary while
		-- this step runs may land one bracket lower (+2 s tolerance).
		local gain = ReputationByStars[Reviews.starsFor(clockNow - soldAt)]
		local lateGain = ReputationByStars[Reviews.starsFor(clockNow - soldAt + 2)]
		teleport(orderPart(R.plotId, "CustomerCar_" .. orderA))
		prompt("load", orderA)
		local after = snap(R.userId)
		check(findOrder(after, orderA) == nil, "order " .. orderA .. " still open")
		check(after.loadedOrders == first.loadedOrders + 1, "loadedOrders did not grow by one")
		check(
			after.reputation == first.reputation + gain or after.reputation == first.reputation + lateGain,
			string.format(
				"reputation %d -> %d, expected +%d or +%d",
				first.reputation,
				after.reputation,
				gain,
				lateGain
			)
		)
		gain = after.reputation - first.reputation
		check(carriedTree() == nil, "CarriedTree left after loading")
		local ok = poll(function()
			return not hasObject(R.plotId, "CustomerCar_" .. orderA) and countOrderObjects(R.plotId, "LeavingCar") == 0
		end, 4)
		check(ok, "car " .. orderA .. " or LeavingCar still present after 4 s")
		return string.format("order #%d loaded, reputation +%d", orderA, gain)
	end)

	addStep("14", "ISOLATION_CARRY", { "08" }, function()
		orderC = visit(S.userId, 8)
		local ready = poll(function()
			return hasObject(S.plotId, "PickupTree_" .. orderC)
		end, 3)
		check(ready, "shadow pickup tree missing")
		local sBefore, rBefore = snap(S.userId), snap(R.userId)
		teleport(orderPart(S.plotId, "PickupTree_" .. orderC))
		assertOutOfOwnReach(orderC)
		local twin = findOrder(rBefore, orderC)
		prompt("carry", orderC)
		local sAfter, rAfter = snap(S.userId), snap(R.userId)
		check(sAfter.revision == sBefore.revision, "shadow revision changed")
		local shadowOrder = findOrder(sAfter, orderC)
		check(shadowOrder and not shadowOrder.carried, "shadow order " .. orderC .. " was carried")
		check(rAfter.revision == rBefore.revision, "player revision changed")
		if twin then
			check(not findOrder(rAfter, orderC).carried, "player order #" .. orderC .. " was carried")
		end
		check(carriedTree() == nil, "player carries a tree from the shadow plot")
		return "foreign tree refused (order #" .. orderC .. ")" .. if twin then "; R has #" .. orderC .. " too" else ""
	end)

	addStep("15", "ISOLATION_LOAD", { "13", "14" }, function()
		teleport(orderPart(R.plotId, "PickupTree_" .. orderB))
		prompt("carry", orderB)
		check(findOrder(snap(R.userId), orderB).carried, "player did not carry order " .. orderB)
		local sBefore, rBefore = snap(S.userId), snap(R.userId)
		teleport(orderPart(S.plotId, "CustomerCar_" .. orderC))
		assertOutOfOwnReach(orderC)
		local twin = findOrder(rBefore, orderC) ~= nil
		prompt("load", orderC)
		local sAfter, rAfter = snap(S.userId), snap(R.userId)
		if twin then
			check(findOrder(rAfter, orderC) ~= nil, "player order #" .. orderC .. " was loaded")
		end
		check(findOrder(rAfter, orderB).carried, "order " .. orderB .. " no longer carried by the player")
		local shadowOrder = findOrder(sAfter, orderC)
		check(shadowOrder and not shadowOrder.carried, "shadow order " .. orderC .. " changed")
		check(sAfter.revision == sBefore.revision, "shadow revision changed")
		check(sAfter.loadedOrders == sBefore.loadedOrders, "shadow loadedOrders changed")
		check(rAfter.loadedOrders == rBefore.loadedOrders, "player loadedOrders changed")
		return "foreign car refused (order #" .. orderC .. ")" .. if twin then "; R has #" .. orderC .. " too" else ""
	end)

	addStep("16", "EXPIRY", { "08" }, function()
		local rBefore = snap(R.userId)
		local open = #rBefore.customerOrders
		advance(EXPIRY_WAIT)
		local ok = poll(function()
			return #snap(R.userId).customerOrders == 0 and #snap(S.userId).customerOrders == 0
		end, 8)
		check(ok, "customer orders still open 8 s after the clock advance")
		local rAfter = snap(R.userId)
		check(
			rAfter.missedPickups == rBefore.missedPickups + open,
			string.format("missedPickups %d -> %d, expected +%d", rBefore.missedPickups, rAfter.missedPickups, open)
		)
		local expectedReputation = math.max(0, rBefore.reputation - open * Customers.MissedPickupReputationPenalty)
		check(
			rAfter.reputation == expectedReputation,
			string.format("reputation %d, expected %d", rAfter.reputation, expectedReputation)
		)
		local clean = poll(function()
			return plotClean(R.plotId) and plotClean(S.plotId)
		end, 4)
		check(clean, "plot objects left after expiry")
		check(carriedTree() == nil, "CarriedTree left after expiry")
		return string.format("%d order(s) expired, reputation %d -> %d", open, rBefore.reputation, rAfter.reputation)
	end)

	addStep("17", "LOT_WORKER", { "07" }, function()
		call("setStaff", { employeeId = "LotWorker", count = 1 })
		local ok, message = pcall(function()
			local orderD = visit(S.userId, 32)
			local first = snap(S.userId)
			-- CM2-25/26: the visible Lot Worker walks to the tree and carries it to the car.
			local done = poll(function()
				local snapshot = snap(S.userId)
				return findOrder(snapshot, orderD) == nil and snapshot.loadedOrders == first.loadedOrders + 1
			end, 45)
			check(done, "Lot Worker did not load order " .. orderD .. " within 45 s")
			local clean = poll(function()
				return plotClean(S.plotId)
			end, 4)
			check(clean, "shadow plot objects left after the worker load")
			return orderD
		end)
		call("setStaff", { employeeId = "LotWorker", count = 0 })
		check(ok, tostring(message))
		return "order #" .. tostring(message) .. " loaded by the Lot Worker"
	end)

	addStep("18", "SELL_BACK", { "03" }, function()
		local first = snap(R.userId)
		local data = orderTrees(R.userId, 1)
		local afterOrder = snap(R.userId)
		check(first.cash - afterOrder.cash == UNIT_PRICE, "order cost differs from " .. UNIT_PRICE)
		advance(DELIVERY_WAIT)
		awaitDelivery(R.userId, data.orderId)
		local beforeSell = snap(R.userId)
		local payload = { speciesId = SPECIES, sizeId = SIZE, quantity = 1 }
		local requestId = "playtest_sellback_" .. HttpService:GenerateGUID(false)
		local response = act(R.userId, "Supplier.SellBack", payload, requestId)
		check(
			type(response) == "table" and response.ok == true,
			"Supplier.SellBack failed: " .. tostring(response and response.errorCode)
		)
		local expected = SupplierStockService.refundFor(SPECIES, SIZE) :: number
		check(
			response.data.refund == expected,
			string.format("refund %s, expected %d", tostring(response.data.refund), expected)
		)
		local afterSell = snap(R.userId)
		check(afterSell.cash == beforeSell.cash + expected, "cash did not rise by the refund")
		check((afterSell.stock[STOCK_KEY] or 0) == (beforeSell.stock[STOCK_KEY] or 0) - 1, "stock did not drop by one")
		local replay = act(R.userId, "Supplier.SellBack", payload, requestId)
		check(
			type(replay) == "table" and replay.errorCode == "DuplicateRequest",
			"replay was not rejected as DuplicateRequest"
		)
		check(snap(R.userId).cash == afterSell.cash, "cash changed on the replay")
		return string.format("refund %d, replay rejected", expected)
	end)

	addStep("19", "REJOIN", { "03" }, function()
		local saved = snap(R.userId)
		local plotBefore = realPlayer():GetAttribute("PlotId")
		call("rejoin", R.userId)
		local after = snap(R.userId)
		for _, field in
			{
				"cash",
				"reputation",
				"revision",
				"revenue",
				"sales",
				"placementCount",
				"loadedOrders",
				"missedPickups",
			}
		do
			check(
				saved[field] == after[field],
				string.format("%s %s -> %s", field, tostring(saved[field]), tostring(after[field]))
			)
		end
		sameTable("stock", saved.stock, after.stock)
		check(HttpService:JSONEncode(saved.bays) == HttpService:JSONEncode(after.bays), "bays changed")
		sameTable("staff", saved.staff, after.staff)
		check(#saved.pendingOrders == #after.pendingOrders, "pending order count changed")
		check(realPlayer():GetAttribute("CompanyReady") == true, "CompanyReady is not true")
		check(realPlayer():GetAttribute("PlotId") == plotBefore, "PlotId changed")
		local ok = poll(function()
			return displayedCount(R.plotId) == after.placementCount
		end, 4)
		check(ok, "DisplayedTrees differs from placementCount after the reload")
		return string.format("cash %d, revision %d, %d placements", after.cash, after.revision, after.placementCount)
	end)

	addStep("20", "SOAK_FAST", { "02" }, function()
		local workerLoads, expiries = 0, 0
		local ok, message = pcall(function()
			for cycle = 1, 6 do
				ctx.phase(string.format("cycle %d order", cycle))
				local start = snap(S.userId)
				local data = orderTrees(S.userId, 1)
				ctx.phase(string.format("cycle %d delivery", cycle))
				advance(DELIVERY_WAIT)
				awaitDelivery(S.userId, data.orderId)
				ctx.phase(string.format("cycle %d place", cycle))
				placeOne(S.userId, data.bay)
				ctx.phase(string.format("cycle %d visit", cycle))
				local number = visit(S.userId, 8 + 24 * ((cycle - 1) % 9))
				local mid = snap(S.userId)
				if cycle % 2 == 1 then
					ctx.phase(string.format("cycle %d worker", cycle))
					call("setStaff", { employeeId = "LotWorker", count = 1 })
					-- CM2-25/26: the visible Lot Worker walks the order to the car.
					local done = poll(function()
						local snapshot = snap(S.userId)
						return findOrder(snapshot, number) == nil and snapshot.loadedOrders == mid.loadedOrders + 1
					end, 45)
					check(done, string.format("cycle %d: worker did not load order %d", cycle, number))
					workerLoads += 1
				else
					ctx.phase(string.format("cycle %d expiry", cycle))
					call("setStaff", { employeeId = "LotWorker", count = 0 })
					advance(EXPIRY_WAIT)
					local done = poll(function()
						local snapshot = snap(S.userId)
						return findOrder(snapshot, number) == nil and snapshot.missedPickups == mid.missedPickups + 1
					end, 8)
					check(done, string.format("cycle %d: order %d did not expire", cycle, number))
					expiries += 1
				end
				ctx.phase(string.format("cycle %d clean", cycle))
				local clean = poll(function()
					return plotClean(S.plotId) and displayedCount(S.plotId) == snap(S.userId).placementCount
				end, 4)
				check(
					clean,
					string.format("cycle %d: shadow plot not clean (start placements %d)", cycle, start.placementCount)
				)
			end
		end)
		ctx.phase("staff off")
		call("setStaff", { employeeId = "LotWorker", count = 0 })
		check(ok, tostring(message))
		return string.format("6 cycles, %d worker loads, %d expiries, 0 leaks", workerLoads, expiries)
	end)

	addStep("21", "ART_ASSETS", {}, function()
		local art = ctx.ArtLibrary.root(ReplicatedStorage)
		check(art ~= nil, "ReplicatedStorage.ArtAssets is missing")
		local container = art :: Instance
		-- A Studio place can hold a leftover ArtAssets with only empty subfolders (CM2-10W);
		-- folders without assets are ignored, as in ArtLibrary.root (CM2-ART2).
		local folders, withAssets, ignored = 0, 0, 0
		for _, child in ReplicatedStorage:GetChildren() do
			if child.Name == "ArtAssets" then
				folders += 1
				if ctx.ArtLibrary.hasAssets(child) then
					withAssets += 1
				else
					ignored += 1
				end
			end
		end
		check(withAssets <= 1, "two ArtAssets folders with assets")
		if folders > 1 and ignored > 0 then
			warn(
				string.format(
					"%s 21 ART_ASSETS ignoring %d ArtAssets folder(s) without assets; delete the leftover in Studio and save (PC-7 step 4)",
					ctx.PREFIX,
					ignored
				)
			)
		end
		local duplicates: { string } = {}
		local function scanNames(folder: Instance)
			local seen: { [string]: boolean } = {}
			for _, child in folder:GetChildren() do
				if seen[child.Name] then
					table.insert(duplicates, folder:GetFullName() .. "/" .. child.Name)
				end
				seen[child.Name] = true
			end
		end
		scanNames(container)
		local meshParts: { Instance } = {}
		local models = 0
		for _, descendant in container:GetDescendants() do
			if descendant:IsA("Folder") then
				scanNames(descendant)
			elseif descendant:IsA("Model") and descendant:GetAttribute("ArtSource") == "blender" then
				models += 1
				for _, inner in descendant:GetDescendants() do
					if inner:IsA("MeshPart") then
						table.insert(meshParts, inner)
					end
				end
			end
		end
		check(#duplicates == 0, "duplicate ArtAssets names: " .. table.concat(duplicates, ", "))
		local failed: { string } = {}
		if #meshParts > 0 then
			game:GetService("ContentProvider"):PreloadAsync(meshParts, function(contentId: string, status)
				if status ~= Enum.AssetFetchStatus.Success then
					table.insert(failed, string.format("%s %s", contentId, tostring(status)))
				end
			end)
		end
		check(#failed == 0, "meshes failed to load: " .. table.concat(failed, ", "))
		return string.format(
			"%d blender models, %d meshes, 0 failed, 0 duplicates, %d ArtAssets folders, %d without assets ignored",
			models,
			#meshParts,
			folders,
			ignored
		)
	end)
end
