--!strict
-- Repeatable Studio playtest (CM2-G20). Run in the Server data model of a Play session:
--   game.ServerStorage.StudioTestHook:Invoke("runPlaytest", { mode = "full" })
--   game.ServerStorage.StudioTestHook:Invoke("runPlaytest", { mode = "soak", minutes = 10 })
-- It drives the real player and a shadow company through StudioTestHook and prints
-- PASS/FAIL/SKIP per step prefixed with [PLAYTEST]. This module is not under Cases, so the
-- unit-test runners never execute it. It touches no game service at load time.
local RunPlaytest = {}
RunPlaytest.BUILD = "cm2-g20-fix1"

local PREFIX = "[PLAYTEST]"
local SPECIES = "DouglasFir"
local SIZE = "Medium"
local STOCK_KEY = SPECIES .. ":" .. SIZE
local MAX_DETAIL = 200
local POLL_INTERVAL = 0.25
local ACTION_PAUSE = 0.3
local TELEPORT_PAUSE = 0.2

-- Refuses unless a Studio server with the test hook is idle. Order: Studio, server, hook, status.
function RunPlaytest.guard(
	isStudio: boolean,
	isServer: boolean,
	hookPresent: boolean,
	status: string?
): (boolean, string?)
	if not isStudio then
		return false, "NotStudio"
	end
	if not isServer then
		return false, "NotServer"
	end
	if not hookPresent then
		return false, "NoHook"
	end
	if status == "running" then
		return false, "AlreadyRunning"
	end
	return true, nil
end

local function validOptions(options: any): (string?, number?)
	if type(options) ~= "table" then
		return nil, nil
	end
	if options.mode ~= "full" and options.mode ~= "soak" then
		return nil, nil
	end
	local minutes = options.minutes
	if minutes == nil then
		minutes = 10
	end
	if type(minutes) ~= "number" or minutes ~= math.floor(minutes) or minutes < 1 or minutes > 30 then
		return nil, nil
	end
	return options.mode, minutes
end

local function execute(hook: any, mode: string, minutes: number)
	local HttpService = game:GetService("HttpService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")
	local ServerStorage = game:GetService("ServerStorage")
	local Stats = game:GetService("Stats")

	local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
	local Services = ServerScriptService:WaitForChild("Server"):WaitForChild("Services")
	local SupplierStockService = require(Services:WaitForChild("SupplierStockService"))
	local StudioTestService = require(Services:WaitForChild("StudioTestService"))
	local Customers = GameConfig.Customers

	local DELIVERY_WAIT = GameConfig.DeliverySeconds + 1
	local EXPIRY_WAIT = Customers.PickupPatienceSeconds + 1
	local WORKER_WAIT = Customers.WorkerLoadSeconds + 1
	local UNIT_PRICE = GameConfig.wholesaleFor(SPECIES, SIZE) :: number

	local startedAt = os.clock()
	local results: { { id: string, name: string, result: string, detail: string } } = {}
	local outcome: { [string]: string } = {}

	-- Result helpers -----------------------------------------------------------------------
	local function check(condition: any, message: string)
		if not condition then
			error(message, 0)
		end
	end

	local function emit(text: string)
		print(PREFIX .. " " .. text)
	end

	local function clip(text: string): string
		if #text > MAX_DETAIL then
			return string.sub(text, 1, MAX_DETAIL - 3) .. "..."
		end
		return text
	end

	local function record(id: string, name: string, result: string, detail: string)
		detail = clip(detail)
		table.insert(results, { id = id, name = name, result = result, detail = detail })
		outcome[id] = result
		if detail == "" then
			emit(string.format("%s %s %s", result, id, name))
		else
			emit(string.format("%s %s %s | %s", result, id, name, detail))
		end
	end

	-- Hook helpers -------------------------------------------------------------------------
	local function invoke(command: string, arg: any): any
		return hook:Invoke(command, arg)
	end

	local function call(command: string, arg: any): any
		local response = invoke(command, arg)
		check(
			type(response) == "table" and response.ok == true,
			string.format(
				"%s failed: %s",
				command,
				tostring(type(response) == "table" and response.errorCode or response)
			)
		)
		return response.data
	end

	local function snap(userId: number): any
		return call("snapshot", userId)
	end

	-- One authoritative action; waits afterwards so the per-action rate limit never trips.
	local function act(userId: number, action: string, payload: any, requestId: string?): any
		local response = invoke("act", { userId = userId, action = action, payload = payload, requestId = requestId })
		task.wait(ACTION_PAUSE)
		return response
	end

	local function actOk(userId: number, action: string, payload: any): any
		local response = act(userId, action, payload)
		check(
			type(response) == "table" and response.ok == true,
			string.format(
				"%s failed: %s",
				action,
				tostring(type(response) == "table" and response.errorCode or response)
			)
		)
		return response.data
	end

	local function poll(condition: () -> any, timeout: number): boolean
		local deadline = os.clock() + timeout
		while true do
			if condition() then
				return true
			end
			if os.clock() >= deadline then
				return false
			end
			task.wait(POLL_INTERVAL)
		end
	end

	-- World helpers ------------------------------------------------------------------------
	local function plotFolder(plotId: string?): Instance?
		local world = workspace:FindFirstChild("ChristmasMarketWorld")
		local plots = world and world:FindFirstChild("Plots")
		return if plotId and plots then plots:FindFirstChild(plotId) else nil
	end

	local function ordersFolder(plotId: string?): Instance?
		local plot = plotFolder(plotId)
		return plot and plot:FindFirstChild("CustomerOrders")
	end

	local function countOrderObjects(plotId: string?, prefix: string): number
		local folder = ordersFolder(plotId)
		local count = 0
		if folder then
			for _, child in folder:GetChildren() do
				if string.sub(child.Name, 1, #prefix) == prefix then
					count += 1
				end
			end
		end
		return count
	end

	local function plotClean(plotId: string?): boolean
		return countOrderObjects(plotId, "CustomerCar_") == 0
			and countOrderObjects(plotId, "PickupTree_") == 0
			and countOrderObjects(plotId, "LeavingCar") == 0
	end

	local function displayedCount(plotId: string?): number
		local plot = plotFolder(plotId)
		local display = plot and plot:FindFirstChild("DisplayedTrees")
		return if display then #display:GetChildren() else 0
	end

	local function orderPart(plotId: string?, name: string): BasePart?
		local folder = ordersFolder(plotId)
		local model = folder and folder:FindFirstChild(name)
		if model and model:IsA("Model") and model.PrimaryPart then
			return model.PrimaryPart
		end
		return nil
	end

	local function hasObject(plotId: string?, name: string): boolean
		local folder = ordersFolder(plotId)
		return folder ~= nil and folder:FindFirstChild(name) ~= nil
	end

	-- Humanoids in the world that do not belong to a connected player (walking NPCs, leaks).
	local function strayHumanoids(): number
		local count = 0
		for _, descendant in workspace:GetDescendants() do
			if descendant:IsA("Humanoid") and Players:GetPlayerFromCharacter(descendant.Parent) == nil then
				count += 1
			end
		end
		return count
	end

	local function carriedTreeOnAnyCharacter(): boolean
		for _, other in Players:GetPlayers() do
			local character = other.Character
			if character and character:FindFirstChild("CarriedTree") then
				return true
			end
		end
		return false
	end

	-- Actors -------------------------------------------------------------------------------
	local player: Player? = nil
	do
		local deadline = os.clock() + 30
		while os.clock() < deadline do
			local candidate = Players:GetPlayers()[1]
			if candidate and candidate:GetAttribute("CompanyReady") == true then
				player = candidate
				break
			end
			task.wait(POLL_INTERVAL)
		end
		if not player then
			player = Players:GetPlayers()[1]
		end
	end
	local R = {
		userId = if player then player.UserId else 0,
		plotId = if player then player:GetAttribute("PlotId") else nil,
	}
	local S = { userId = StudioTestService.SHADOW_USER_ID, plotId = nil :: any }

	local function realPlayer(): Player
		check(player ~= nil and player.Parent == Players, "no player in the session")
		return player :: Player
	end

	local function teleport(target: BasePart?)
		check(target ~= nil, "teleport target missing")
		local character = realPlayer().Character
		check(character ~= nil, "player has no character")
		local model = character :: Model
		model:PivotTo(CFrame.new((target :: BasePart).Position + Vector3.new(3, 3, 0)))
		task.wait(TELEPORT_PAUSE)
	end

	-- Order numbers are per company: the shadow's order can share a number with an open player
	-- order. The player must stand out of reach of that twin so a hit can only be a cross-plot one.
	local function assertOutOfOwnReach(number: number)
		local root = (realPlayer().Character :: Model):FindFirstChild("HumanoidRootPart")
		check(root and root:IsA("BasePart"), "player has no HumanoidRootPart")
		local rootPart = root :: BasePart
		for _, name in { "PickupTree_" .. number, "CustomerCar_" .. number } do
			local part = orderPart(R.plotId, name)
			if part then
				check(
					(rootPart.Position - part.Position).Magnitude > Customers.InteractDistance,
					"player within reach of own #" .. number
				)
			end
		end
	end

	local function prompt(kind: string, number: number)
		local response = invoke("prompt", { userId = R.userId, kind = kind, number = number })
		check(type(response) == "table" and response.ok == true, "prompt failed")
		task.wait(ACTION_PAUSE)
	end

	local function carriedTree(): Instance?
		local character = realPlayer().Character
		return character and character:FindFirstChild("CarriedTree")
	end

	local function findOrder(snapshot: any, number: number): any
		for _, order in snapshot.customerOrders do
			if order.orderNumber == number then
				return order
			end
		end
		return nil
	end

	local function pendingQuantity(snapshot: any): number
		local total = 0
		for _, order in snapshot.pendingOrders do
			total += order.quantity
		end
		return total
	end

	local function slotTransform(count: number): any
		local slot = count % 16
		return { x = 14 + (slot % 4) * 7, y = 0, z = -3 + (slot // 4) * 8, rotation = 0 }
	end

	local function visit(userId: number, profile: number): number
		return call("visit", { userId = userId, profile = profile })
	end

	local function advance(seconds: number)
		invoke("advanceClock", seconds)
	end

	-- Orders Medium Douglas Fir; one retry after a supplier restock when it is sold out.
	local function orderTrees(userId: number, quantity: number): any
		local payload = { speciesId = SPECIES, sizeId = SIZE, quantity = quantity }
		local response = act(userId, "Supplier.PlaceOrder", payload)
		if type(response) == "table" and response.errorCode == "SupplierOutOfStock" then
			advance(240)
			response = act(userId, "Supplier.PlaceOrder", payload)
		end
		check(
			type(response) == "table" and response.ok == true,
			"Supplier.PlaceOrder failed: " .. tostring(type(response) == "table" and response.errorCode or response)
		)
		return response.data
	end

	local function pendingStatus(userId: number, orderId: string): string?
		for _, order in snap(userId).pendingOrders do
			if order.orderId == orderId then
				return order.status
			end
		end
		return nil
	end

	-- A Lot Worker may unload on its own, so an order that left the pending list counts as unloaded.
	local function unloadOrder(userId: number, orderId: string)
		local ready = poll(function()
			local status = pendingStatus(userId, orderId)
			return status == nil or status == "Delivered"
		end, 8)
		check(ready, "delivery of " .. orderId .. " not Delivered within 8 s")
		if pendingStatus(userId, orderId) == nil then
			return
		end
		local response = act(userId, "Delivery.Unload", { orderId = orderId })
		if type(response) == "table" and response.ok == true then
			return
		end
		check(
			type(response) == "table" and response.errorCode == "UnknownOrder" and pendingStatus(userId, orderId) == nil,
			"Delivery.Unload failed: " .. tostring(type(response) == "table" and response.errorCode or response)
		)
	end

	local function unloadDelivered(userId: number)
		for _, order in snap(userId).pendingOrders do
			if order.status == "Delivered" then
				actOk(userId, "Delivery.Unload", { orderId = order.orderId })
			end
		end
	end

	local function placeOne(userId: number, count: number)
		actOk(userId, "Inventory.Place", { speciesId = SPECIES, sizeId = SIZE, transform = slotTransform(count) })
	end

	local function sameTable(label: string, left: any, right: any)
		local keys: { [any]: boolean } = {}
		for key in left do
			keys[key] = true
		end
		for key in right do
			keys[key] = true
		end
		for key in keys do
			check(
				left[key] == right[key],
				string.format(
					"%s.%s changed: %s -> %s",
					label,
					tostring(key),
					tostring(left[key]),
					tostring(right[key])
				)
			)
		end
	end

	-- Steps --------------------------------------------------------------------------------
	type Step = { id: string, name: string, needs: { string }, run: () -> string? }
	local steps: { Step } = {}
	local function addStep(id: string, name: string, needs: { string }, run: () -> string?)
		table.insert(steps, { id = id, name = name, needs = needs, run = run })
	end

	-- Shared between steps of one run.
	local shadowJoined = false
	local orderA, orderB, orderC = 0, 0, 0
	local pickupHome: Vector3 = Vector3.zero

	local function shadowJoin(lotWorker: number)
		local data = call("shadowJoin", nil)
		shadowJoined = true
		S.plotId = data.plotId
		check(S.plotId ~= R.plotId, "shadow plot equals player plot " .. tostring(S.plotId))
		call("setStaff", { employeeId = "LotWorker", count = lotWorker })
	end

	local function preflight(soak: boolean): string
		check(#Players:GetPlayers() == 1, "expected exactly 1 player, got " .. #Players:GetPlayers())
		local current = realPlayer()
		check(current:GetAttribute("CompanyReady") == true, "CompanyReady is not true")
		check(type(R.plotId) == "string", "player has no PlotId")
		local function busy(userId: number): boolean
			local snapshot = snap(userId)
			if #snapshot.customerOrders > 0 then
				return true
			end
			for _, order in snapshot.pendingOrders do
				if order.status == "Pending" then
					return true
				end
			end
			return false
		end
		if busy(R.userId) or busy(S.userId) then
			advance(121)
			poll(function()
				return not busy(R.userId) and not busy(S.userId)
			end, 8)
		end
		unloadDelivered(R.userId)
		unloadDelivered(S.userId)
		local snapshot = snap(R.userId)
		check(#snapshot.customerOrders == 0, "player still has customer orders")
		if not soak then
			check(snapshot.staff.LotWorker == 0, "player has a Lot Worker hired")
			check(snapshot.mediumPrices[SPECIES] <= 125, "Douglas Fir medium price above 125")
			check(snapshot.cash >= 2 * UNIT_PRICE, "cash below " .. 2 * UNIT_PRICE)
		else
			check(snapshot.cash >= UNIT_PRICE, "cash below " .. UNIT_PRICE)
		end
		check(snapshot.receiving.baysUsed < snapshot.receiving.bayCount, "no free receiving bay")
		check(snapshot.receiving.storageCapacity - snapshot.receiving.storageUsed >= 3, "storage room below 3")
		return string.format(
			"cash %d, bays %d/%d",
			snapshot.cash,
			snapshot.receiving.baysUsed,
			snapshot.receiving.bayCount
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
		local stray = strayHumanoids()
		check(stray == 0, stray .. " Humanoid(s) outside player characters")
		return "plots clean, no stray Humanoid"
	end

	local function cleanup(): string
		local errors: { string } = {}
		local function attempt(label: string, fn: () -> ())
			local ok, message = pcall(fn)
			if not ok then
				table.insert(errors, label .. ": " .. tostring(message))
			end
		end
		if shadowJoined then
			attempt("setStaff", function()
				call("setStaff", { employeeId = "LotWorker", count = 0 })
			end)
		end
		attempt("shadowLeave", function()
			call("shadowLeave", nil)
		end)
		attempt("S DisplayedTrees", function()
			check(S.plotId == nil or displayedCount(S.plotId) == 0, "S plot still shows trees")
		end)
		attempt("pauseCustomers", function()
			call("pauseCustomers", false)
		end)
		check(#errors == 0, table.concat(errors, "; "))
		return "shadow left, customers unpaused"
	end

	if mode == "full" then
		addStep("01", "UNIT_RUNNER", {}, function()
			local runner = require(ServerStorage:WaitForChild("UnitTest"):WaitForChild("RunUnitTest")) :: any
			local totals = runner(nil, 10)
			check(totals.failed == 0, totals.failed .. " unit test(s) failed")
			check(totals.run >= 142, "only " .. totals.run .. " unit tests ran (expected >= 142)")
			return string.format("%d run, %d passed", totals.run, totals.passed)
		end)

		addStep("02", "SHADOW_JOIN", {}, function()
			shadowJoin(0)
			call("pauseCustomers", true)
			return string.format("shadow plot %s, player plot %s", tostring(S.plotId), tostring(R.plotId))
		end)

		addStep("03", "PREFLIGHT", { "02" }, function()
			return preflight(false)
		end)

		local orderIds: { [number]: string } = {}
		local before: { [number]: any } = {}

		addStep("04", "ORDER", { "03" }, function()
			for _, userId in { R.userId, S.userId } do
				before[userId] = snap(userId)
				local data = orderTrees(userId, 2)
				orderIds[userId] = data.orderId
				local after = snap(userId)
				check(
					before[userId].cash - after.cash == 2 * UNIT_PRICE,
					string.format("cash delta %d, expected -%d", after.cash - before[userId].cash, 2 * UNIT_PRICE)
				)
				check(#after.pendingOrders == #before[userId].pendingOrders + 1, "pending orders did not grow by one")
			end
			return string.format("2 x %s each, cash -%d", STOCK_KEY, 2 * UNIT_PRICE)
		end)

		addStep("05", "DELIVER", { "04" }, function()
			advance(DELIVERY_WAIT)
			local ok = poll(function()
				return pendingStatus(R.userId, orderIds[R.userId]) == "Delivered"
					and pendingStatus(S.userId, orderIds[S.userId]) == "Delivered"
			end, 8)
			check(ok, "orders not Delivered within 8 s")
			return "both orders Delivered"
		end)

		addStep("06", "UNLOAD", { "05" }, function()
			for _, userId in { R.userId, S.userId } do
				local stockBefore = snap(userId).stock[STOCK_KEY] or 0
				actOk(userId, "Delivery.Unload", { orderId = orderIds[userId] })
				local stockAfter = snap(userId).stock[STOCK_KEY] or 0
				check(
					stockAfter == stockBefore + 2,
					string.format("stock %d -> %d, expected +2", stockBefore, stockAfter)
				)
			end
			return "stock +2 each"
		end)

		addStep("07", "PLACE", { "06" }, function()
			for _, userId in { R.userId, S.userId } do
				local count = snap(userId).placementCount
				placeOne(userId, count)
				placeOne(userId, count + 1)
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
			local gain = if clockNow - soldAt <= Customers.FastLoadSeconds
				then Customers.FastLoadReputation
				else Customers.SlowLoadReputation
			teleport(orderPart(R.plotId, "CustomerCar_" .. orderA))
			prompt("load", orderA)
			local after = snap(R.userId)
			check(findOrder(after, orderA) == nil, "order " .. orderA .. " still open")
			check(after.loadedOrders == first.loadedOrders + 1, "loadedOrders did not grow by one")
			check(
				after.reputation == first.reputation + gain,
				string.format("reputation %d -> %d, expected +%d", first.reputation, after.reputation, gain)
			)
			check(carriedTree() == nil, "CarriedTree left after loading")
			local ok = poll(function()
				return not hasObject(R.plotId, "CustomerCar_" .. orderA)
					and countOrderObjects(R.plotId, "LeavingCar") == 0
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
			return "foreign tree refused (order #"
				.. orderC
				.. ")"
				.. if twin then "; R has #" .. orderC .. " too" else ""
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
			return "foreign car refused (order #"
				.. orderC
				.. ")"
				.. if twin then "; R has #" .. orderC .. " too" else ""
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
			return string.format(
				"%d order(s) expired, reputation %d -> %d",
				open,
				rBefore.reputation,
				rAfter.reputation
			)
		end)

		addStep("17", "LOT_WORKER", { "07" }, function()
			call("setStaff", { employeeId = "LotWorker", count = 1 })
			local ok, message = pcall(function()
				local orderD = visit(S.userId, 32)
				local first = snap(S.userId)
				advance(WORKER_WAIT)
				local done = poll(function()
					local snapshot = snap(S.userId)
					return findOrder(snapshot, orderD) == nil and snapshot.loadedOrders == first.loadedOrders + 1
				end, 8)
				check(done, "Lot Worker did not load order " .. orderD .. " within 8 s")
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
			unloadOrder(R.userId, data.orderId)
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
			check(
				(afterSell.stock[STOCK_KEY] or 0) == (beforeSell.stock[STOCK_KEY] or 0) - 1,
				"stock did not drop by one"
			)
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
			sameTable("staff", saved.staff, after.staff)
			check(#saved.pendingOrders == #after.pendingOrders, "pending order count changed")
			check(realPlayer():GetAttribute("CompanyReady") == true, "CompanyReady is not true")
			check(realPlayer():GetAttribute("PlotId") == plotBefore, "PlotId changed")
			local ok = poll(function()
				return displayedCount(R.plotId) == after.placementCount
			end, 4)
			check(ok, "DisplayedTrees differs from placementCount after the reload")
			return string.format(
				"cash %d, revision %d, %d placements",
				after.cash,
				after.revision,
				after.placementCount
			)
		end)

		addStep("20", "SOAK_FAST", { "02" }, function()
			local workerLoads, expiries = 0, 0
			local ok, message = pcall(function()
				for cycle = 1, 6 do
					local start = snap(S.userId)
					local data = orderTrees(S.userId, 1)
					advance(DELIVERY_WAIT)
					unloadOrder(S.userId, data.orderId)
					placeOne(S.userId, snap(S.userId).placementCount)
					local number = visit(S.userId, 8 + 24 * ((cycle - 1) % 9))
					local mid = snap(S.userId)
					if cycle % 2 == 1 then
						call("setStaff", { employeeId = "LotWorker", count = 1 })
						advance(WORKER_WAIT)
						local done = poll(function()
							local snapshot = snap(S.userId)
							return findOrder(snapshot, number) == nil and snapshot.loadedOrders == mid.loadedOrders + 1
						end, 8)
						check(done, string.format("cycle %d: worker did not load order %d", cycle, number))
						workerLoads += 1
					else
						call("setStaff", { employeeId = "LotWorker", count = 0 })
						advance(EXPIRY_WAIT)
						local done = poll(function()
							local snapshot = snap(S.userId)
							return findOrder(snapshot, number) == nil
								and snapshot.missedPickups == mid.missedPickups + 1
						end, 8)
						check(done, string.format("cycle %d: order %d did not expire", cycle, number))
						expiries += 1
					end
					local clean = poll(function()
						return plotClean(S.plotId) and displayedCount(S.plotId) == snap(S.userId).placementCount
					end, 4)
					check(
						clean,
						string.format(
							"cycle %d: shadow plot not clean (start placements %d)",
							cycle,
							start.placementCount
						)
					)
				end
			end)
			call("setStaff", { employeeId = "LotWorker", count = 0 })
			check(ok, tostring(message))
			return string.format("6 cycles, %d worker loads, %d expiries, 0 leaks", workerLoads, expiries)
		end)

		addStep("21", "LEAK_CHECK", { "02" }, leakCheck)
		addStep("22", "CLEANUP", {}, cleanup)
	else
		addStep("01", "SHADOW_JOIN", {}, function()
			shadowJoin(1)
			call("pauseCustomers", false)
			return string.format("shadow plot %s, player plot %s", tostring(S.plotId), tostring(R.plotId))
		end)

		addStep("02", "PREFLIGHT", { "01" }, function()
			return preflight(true)
		end)

		addStep("03", "SOAK_REALTIME", { "02" }, function()
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
				unloadDelivered(userId)
				local snapshot = snap(userId)
				local count = snapshot.placementCount
				local stored = snapshot.stock[STOCK_KEY] or 0
				while stored > 0 and count < 6 do
					placeOne(userId, count)
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
			local detail = string.format(
				"%d s, %d samples, %d mismatches, sales %d, player loads %d, worker loads %d, expiries %d, drive-pasts %d, max active %d/%d, memory %d→%d MB",
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
				math.floor(Stats:GetTotalMemoryUsageMb())
			)
			check(mismatches == 0, firstMismatch .. " | " .. detail)
			check(sales >= 10, "sales below 10 | " .. detail)
			check(playerLoads >= 1, "no player load | " .. detail)
			check(workerLoads >= 1, "no Lot Worker load | " .. detail)
			check(expiries >= 1, "no expiry | " .. detail)
			return detail
		end)

		addStep("04", "LEAK_CHECK", { "01" }, function()
			call("pauseCustomers", true)
			advance(121)
			task.wait(8)
			return leakCheck()
		end)
		addStep("05", "CLEANUP", {}, cleanup)
	end

	-- Runner -------------------------------------------------------------------------------
	local plotText = tostring(R.plotId)
	emit(
		string.format(
			"START mode=%s player=%s (%d) plot=%s",
			mode,
			if player then player.Name else "none",
			R.userId,
			plotText
		)
	)

	for _, step in steps do
		local unmet: string? = nil
		for _, need in step.needs do
			if outcome[need] ~= "PASS" then
				unmet = need
				break
			end
		end
		if unmet then
			record(step.id, step.name, "SKIP", "needs " .. unmet)
		else
			local ok, detail = pcall(step.run)
			if ok then
				record(step.id, step.name, "PASS", if type(detail) == "string" then detail else "")
			else
				record(step.id, step.name, "FAIL", tostring(detail))
			end
		end
	end

	local passCount, failCount, skipCount = 0, 0, 0
	for _, entry in results do
		if entry.result == "PASS" then
			passCount += 1
		elseif entry.result == "FAIL" then
			failCount += 1
		else
			skipCount += 1
		end
	end
	local seconds = math.floor(os.clock() - startedAt + 0.5)
	local verdict = if failCount == 0 and skipCount == 0 then "PASS" else "FAIL"
	local summary = string.format(
		"SUMMARY mode=%s steps=%d pass=%d fail=%d skip=%d seconds=%d result=%s",
		mode,
		#results,
		passCount,
		failCount,
		skipCount,
		seconds,
		verdict
	)
	emit(summary)
	ServerStorage:SetAttribute("PlaytestSummary", summary)
	ServerStorage:SetAttribute("PlaytestReport", HttpService:JSONEncode(results))
end

function RunPlaytest.run(hook: any, options: any)
	local RunService = game:GetService("RunService")
	local ServerStorage = game:GetService("ServerStorage")
	local allowed, reason = RunPlaytest.guard(
		RunService:IsStudio(),
		RunService:IsServer(),
		hook ~= nil,
		ServerStorage:GetAttribute("PlaytestStatus")
	)
	if not allowed then
		print(string.format("%s REFUSED %s", PREFIX, tostring(reason)))
		return
	end
	local mode, minutes = validOptions(options)
	if mode == nil or minutes == nil then
		print(string.format("%s REFUSED BadOptions", PREFIX))
		return
	end
	ServerStorage:SetAttribute("PlaytestStatus", "running")
	ServerStorage:SetAttribute("PlaytestSummary", nil)
	ServerStorage:SetAttribute("PlaytestReport", nil)
	local ok, message = pcall(execute, hook, mode, minutes)
	if not ok then
		warn(string.format("%s runner error: %s", PREFIX, tostring(message)))
		ServerStorage:SetAttribute("PlaytestSummary", "SUMMARY runner error: " .. tostring(message))
	end
	ServerStorage:SetAttribute("PlaytestStatus", "done")
end

return RunPlaytest
