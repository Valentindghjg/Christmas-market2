--!strict
-- Playtest helpers: constants, services, result, hook, world and walking-customer helpers, actors.
-- Installed by RunPlaytest.execute (CM2-RF).
return function(ctx: any)
	local PREFIX = ctx.PREFIX
	local hook = ctx.hook
	local outcome = ctx.outcome
	local results = ctx.results

	local SPECIES = "DouglasFir"
	local SIZE = "Medium"
	local STOCK_KEY = SPECIES .. ":" .. SIZE
	local MAX_DETAIL = 200
	local POLL_INTERVAL = 0.25
	local ACTION_PAUSE = 0.3
	local TELEPORT_PAUSE = 0.2

	local HttpService = game:GetService("HttpService")
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ServerScriptService = game:GetService("ServerScriptService")
	local ServerStorage = game:GetService("ServerStorage")
	local Stats = game:GetService("Stats")

	local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
	local NpcPath = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("NpcPath"))
	local ArtLibrary = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ArtLibrary"))
	local Services = ServerScriptService:WaitForChild("Server"):WaitForChild("Services")
	local SupplierStockService = require(Services:WaitForChild("SupplierStockService"))
	local PricingService = require(Services:WaitForChild("PricingService"))
	local PLAYTEST_PRICE = (PricingService.bounds(SPECIES)) :: number
	local StudioTestService = require(Services:WaitForChild("StudioTestService"))
	local Customers = GameConfig.Customers

	local DELIVERY_WAIT = GameConfig.DeliverySeconds + 1
	local EXPIRY_WAIT = Customers.PickupPatienceSeconds + 1
	local WORKER_WAIT = Customers.WorkerLoadSeconds + 1
	local UNIT_PRICE = GameConfig.wholesaleFor(SPECIES, SIZE) :: number

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

	-- New saves start at the typical price (CM2-G7); the fixed visit profiles must always
	-- afford the playtest tree, so the run sets the lowest allowed Douglas Fir price.
	local function priceToSell(userId: number)
		actOk(userId, "Pricing.SetMediumPrice", { speciesId = SPECIES, mediumPrice = PLAYTEST_PRICE })
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

	-- Walking customers (CM2-N1) ---------------------------------------------------------------
	-- The ten states of a customer who buys and waits at the car.
	local NPC_FULL_PATH = {
		"Arriving",
		"WalkingIn",
		"Browsing",
		"WalkingToTree",
		"PickingUp",
		"WalkingToQueue",
		"Queued",
		"CheckingOut",
		"WalkingToCar",
		"WaitingAtCar",
	}
	-- States in which the visit holds its reservation.
	local NPC_RESERVED_STATES = {
		WalkingToTree = true,
		PickingUp = true,
		WalkingToQueue = true,
		Queued = true,
		CheckingOut = true,
	}

	local function npcSnapshot(): any
		return call("npcSnapshot", nil)
	end

	-- Fix round 1 (P6, P7): one snap-log entry as "visit state@(x,z)->(goalX,goalZ)".
	local function snapEntryText(entry: any): string
		local function number(value: any): string
			return if type(value) == "number" then string.format("%.1f", value) else "?"
		end
		return string.format(
			"%s %s@(%s,%s)->(%s,%s)",
			tostring(entry.visitId),
			tostring(entry.state),
			number(entry.x),
			number(entry.z),
			number(entry.goalX),
			number(entry.goalZ)
		)
	end

	-- The snap-log entries of one visit, appended to a snap FAIL.
	local function snapLogOf(visitId: string): string
		local log = npcSnapshot().snapLog
		local parts: { string } = {}
		if type(log) == "table" then
			for _, entry in log do
				if entry.visitId == visitId then
					table.insert(parts, snapEntryText(entry))
				end
			end
		end
		return if #parts > 0 then table.concat(parts, "; ") else "no snap-log entry"
	end

	local function findNpc(snapshot: any, visitId: string): any
		for _, visit in snapshot.visits do
			if visit.visitId == visitId then
				return visit
			end
		end
		return nil
	end

	local function npcOnPlot(plotId: string?): number
		local count = 0
		for _, visit in npcSnapshot().visits do
			if visit.plotId == plotId then
				count += 1
			end
		end
		return count
	end

	-- NPC objects left behind: avatars in a plot's Customers folder, visit cars, carried trees.
	local function npcObjectsLeft(plotIds: { string? }): string?
		for _, plotId in plotIds do
			local plot = plotFolder(plotId)
			local customers = plot and plot:FindFirstChild("Customers")
			if customers and #customers:GetChildren() > 0 then
				return tostring(plotId) .. ".Customers is not empty"
			end
		end
		for _, descendant in workspace:GetDescendants() do
			if string.sub(descendant.Name, 1, 9) == "VisitCar_" or descendant.Name == "NpcCarriedTree" then
				return descendant.Name .. " left in the world"
			end
		end
		return nil
	end

	-- Humanoids in the world that belong neither to a connected player nor to a live walking
	-- customer (leaks).
	local function strayHumanoids(): number
		local live: { [string]: boolean } = {}
		local response = invoke("npcSnapshot", nil)
		if type(response) == "table" and response.ok == true then
			for _, visit in response.data.visits do
				live[visit.visitId] = true
			end
		end
		local count = 0
		for _, descendant in workspace:GetDescendants() do
			if descendant:IsA("Humanoid") and Players:GetPlayerFromCharacter(descendant.Parent) == nil then
				local owner = descendant.Parent
				local visitId = owner and owner:GetAttribute("NpcVisitId")
				if not (type(visitId) == "string" and live[visitId]) then
					count += 1
				end
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
		-- CM2-S1: a joined player has a readable profile; a save is played by ACTIVE_SAVE.
		local deadline = os.clock() + 30
		while os.clock() < deadline do
			local candidate = Players:GetPlayers()[1]
			if candidate and candidate:GetAttribute("ProfileReady") == true then
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
	-- finderSaveId: the save the shadow's teammate search created (step 35, CM2-S3).
	local S = { userId = StudioTestService.SHADOW_USER_ID, plotId = nil :: any, finderSaveId = nil :: any }

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

	-- CM2-G14: single-tree stocking spots in the lot frame, clear of every keep-clear box.
	local SLOTS: { { x: number, z: number } } = {}
	for _, z in { -13, -6, 1, 8 } do
		for _, x in { -35, -28 } do
			table.insert(SLOTS, { x = x, z = z })
		end
	end
	for _, z in { -1, 6 } do
		for _, x in { 11.5, 18.5, 25.5 } do
			table.insert(SLOTS, { x = x, z = z })
		end
	end
	local SLOT_SPACING = 5.6

	local function visit(userId: number, profile: number): number
		return call("visit", { userId = userId, profile = profile })
	end

	local function advance(seconds: number)
		invoke("advanceClock", seconds)
	end

	-- Orders Medium Douglas Fir; one retry after a supplier restock when it is sold out. The
	-- returned data carries the order's receiving bay (data.bay, CM2-G14).
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

	local function isPending(snapshot: any, orderId: string): boolean
		for _, order in snapshot.pendingOrders do
			if order.orderId == orderId then
				return true
			end
		end
		return false
	end

	-- CM2-G14: a due delivery lands in its bay by itself within a delivery pass.
	local function awaitDelivery(userId: number, orderId: string)
		local landed = poll(function()
			return not isPending(snap(userId), orderId)
		end, 8)
		check(landed, "delivery of " .. orderId .. " still pending after 8 s")
	end

	-- The lowest bay index holding at least n Medium Douglas Fir, or nil.
	local function bayWith(userId: number, n: number): number?
		for _, bay in snap(userId).bays do
			if bay.speciesId == SPECIES and bay.counts[SIZE] >= n then
				return bay.index
			end
		end
		return nil
	end

	-- The first slot at least SLOT_SPACING from every displayed tree.
	local function freeSlot(userId: number): { x: number, z: number }?
		local placements = snap(userId).placements
		for _, slot in SLOTS do
			local free = true
			for _, placement in placements do
				if type(placement.x) == "number" and type(placement.z) == "number" then
					local dx, dz = placement.x - slot.x, placement.z - slot.z
					if math.sqrt(dx * dx + dz * dz) < SLOT_SPACING then
						free = false
						break
					end
				end
			end
			if free then
				return slot
			end
		end
		return nil
	end

	local function stockPayload(bay: number, x: number, z: number, count: number): any
		return {
			bay = bay,
			speciesId = SPECIES,
			sizeId = SIZE,
			x = x,
			z = z,
			rotation = 0,
			count = count,
			gap = 0.5,
		}
	end

	-- One Medium Douglas Fir from `bay` onto the first free slot.
	local function placeOne(userId: number, bay: number)
		local slot = freeSlot(userId)
		check(slot ~= nil, "no free stocking slot")
		local spot = slot :: { x: number, z: number }
		actOk(userId, "Stock.Place", stockPayload(bay, spot.x, spot.z, 1))
	end

	-- Medium Douglas Fir in the bays plus on the lot.
	local function douglasTotal(snapshot: any): number
		local total = 0
		for _, bay in snapshot.bays do
			if bay.speciesId == SPECIES then
				total += bay.counts[SIZE]
			end
		end
		for _, placement in snapshot.placements do
			if placement.speciesId == SPECIES and placement.sizeId == SIZE then
				total += 1
			end
		end
		return total
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

	ctx.SPECIES = SPECIES
	ctx.SIZE = SIZE
	ctx.STOCK_KEY = STOCK_KEY
	ctx.MAX_DETAIL = MAX_DETAIL
	ctx.POLL_INTERVAL = POLL_INTERVAL
	ctx.ACTION_PAUSE = ACTION_PAUSE
	ctx.TELEPORT_PAUSE = TELEPORT_PAUSE
	ctx.HttpService = HttpService
	ctx.Players = Players
	ctx.ReplicatedStorage = ReplicatedStorage
	ctx.ServerScriptService = ServerScriptService
	ctx.ServerStorage = ServerStorage
	ctx.Stats = Stats
	ctx.GameConfig = GameConfig
	ctx.NpcPath = NpcPath
	ctx.ArtLibrary = ArtLibrary
	ctx.Services = Services
	ctx.SupplierStockService = SupplierStockService
	ctx.PricingService = PricingService
	ctx.PLAYTEST_PRICE = PLAYTEST_PRICE
	ctx.StudioTestService = StudioTestService
	ctx.Customers = Customers
	ctx.DELIVERY_WAIT = DELIVERY_WAIT
	ctx.EXPIRY_WAIT = EXPIRY_WAIT
	ctx.WORKER_WAIT = WORKER_WAIT
	ctx.UNIT_PRICE = UNIT_PRICE
	ctx.check = check
	ctx.emit = emit
	ctx.clip = clip
	ctx.record = record
	ctx.invoke = invoke
	ctx.call = call
	ctx.snap = snap
	ctx.act = act
	ctx.actOk = actOk
	ctx.priceToSell = priceToSell
	ctx.poll = poll
	ctx.plotFolder = plotFolder
	ctx.ordersFolder = ordersFolder
	ctx.countOrderObjects = countOrderObjects
	ctx.plotClean = plotClean
	ctx.displayedCount = displayedCount
	ctx.orderPart = orderPart
	ctx.hasObject = hasObject
	ctx.NPC_FULL_PATH = NPC_FULL_PATH
	ctx.NPC_RESERVED_STATES = NPC_RESERVED_STATES
	ctx.npcSnapshot = npcSnapshot
	ctx.snapEntryText = snapEntryText
	ctx.snapLogOf = snapLogOf
	ctx.findNpc = findNpc
	ctx.npcOnPlot = npcOnPlot
	ctx.npcObjectsLeft = npcObjectsLeft
	ctx.strayHumanoids = strayHumanoids
	ctx.carriedTreeOnAnyCharacter = carriedTreeOnAnyCharacter
	ctx.player = player
	ctx.R = R
	ctx.S = S
	ctx.realPlayer = realPlayer
	ctx.teleport = teleport
	ctx.assertOutOfOwnReach = assertOutOfOwnReach
	ctx.prompt = prompt
	ctx.carriedTree = carriedTree
	ctx.findOrder = findOrder
	ctx.pendingQuantity = pendingQuantity
	ctx.SLOTS = SLOTS
	ctx.SLOT_SPACING = SLOT_SPACING
	ctx.visit = visit
	ctx.advance = advance
	ctx.orderTrees = orderTrees
	ctx.isPending = isPending
	ctx.awaitDelivery = awaitDelivery
	ctx.bayWith = bayWith
	ctx.freeSlot = freeSlot
	ctx.stockPayload = stockPayload
	ctx.placeOne = placeOne
	ctx.douglasTotal = douglasTotal
	ctx.sameTable = sameTable
end
