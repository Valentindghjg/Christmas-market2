--!strict
-- Repeatable Studio playtest (CM2-G20). Run in the Server data model of a Play session:
--   game.ServerStorage.StudioTestHook:Invoke("runPlaytest", { mode = "full" })
--   game.ServerStorage.StudioTestHook:Invoke("runPlaytest", { mode = "soak", minutes = 10 })
-- It drives the real player and a shadow company through StudioTestHook and prints
-- PASS/FAIL/SKIP per step prefixed with [PLAYTEST]. This module is not under Cases, so the
-- unit-test runners never execute it. It touches no game service at load time.
local RunPlaytest = {}
RunPlaytest.BUILD = "cm2-g14"

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
	local PricingService = require(Services:WaitForChild("PricingService"))
	local PLAYTEST_PRICE = (PricingService.bounds(SPECIES)) :: number
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

	-- Save slots (CM2-S1) --------------------------------------------------------------------
	local SAVE_A, SAVE_B, SAVE_B2, SAVE_C = "Playtest A", "Playtest B", "Playtest B2", "Playtest C"
	local saveA, saveB, saveC = "", "", ""

	-- One Save.* request for a user (the player or a synthetic one); a rate-limited request is
	-- retried once after the window.
	local function saveActAs(userId: number, action: string, payload: any, requestId: string?): any
		local arg = { userId = userId, action = action, payload = payload, requestId = requestId }
		local response = invoke("saveAction", arg)
		if type(response) == "table" and response.errorCode == "RateLimited" then
			task.wait(61)
			response = invoke("saveAction", arg)
		end
		task.wait(ACTION_PAUSE)
		return response
	end

	local function saveAct(action: string, payload: any, requestId: string?): any
		return saveActAs(R.userId, action, payload, requestId)
	end

	local function saveActOk(action: string, payload: any, requestId: string?): any
		local response = saveAct(action, payload, requestId)
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

	local function saveRefused(action: string, payload: any, expected: string)
		local response = saveAct(action, payload)
		local code = type(response) == "table" and response.errorCode or response
		check(code == expected, string.format("%s returned %s, expected %s", action, tostring(code), expected))
	end

	local function saveList(): { any }
		return call("saves", R.userId)
	end

	local function findSave(name: string): any
		for _, entry in saveList() do
			if entry.name == name then
				return entry
			end
		end
		return nil
	end

	-- Plays a save and waits until the player is ready on it.
	local function playSave(saveId: string)
		saveActOk("Save.Play", { saveId = saveId })
		local ready = poll(function()
			local current = realPlayer()
			return current:GetAttribute("CompanyReady") == true and current:GetAttribute("ActiveSaveId") == saveId
		end, 10)
		check(ready, "save " .. saveId .. " not ready within 10 s")
		R.plotId = realPlayer():GetAttribute("PlotId")
	end

	-- Deletes a leftover save from an earlier run; a stolen test lock is cleared first.
	local function deleteLeftover(name: string): boolean
		local entry = findSave(name)
		if not entry then
			return false
		end
		call("unlockSave", { userId = R.userId, saveId = entry.saveId })
		saveActOk("Save.Delete", { saveId = entry.saveId, confirmName = name })
		return true
	end

	-- Co-op saves (CM2-S2): the shadow and a second synthetic user act through saveAction/act,
	-- so they hit the same server paths a real client would.
	local SAVE_DUO = "Playtest Duo"
	local S2 = { userId = StudioTestService.SHADOW_2_USER_ID }
	local saveDuo, duoCode = "", ""

	local function saveActAsOk(userId: number, action: string, payload: any): any
		local response = saveActAs(userId, action, payload)
		check(
			type(response) == "table" and response.ok == true,
			string.format(
				"%s for %s failed: %s",
				action,
				tostring(userId),
				tostring(type(response) == "table" and response.errorCode or response)
			)
		)
		return response.data
	end

	local function saveRefusedAs(userId: number, action: string, payload: any, expected: string)
		local response = saveActAs(userId, action, payload)
		local code = type(response) == "table" and response.errorCode or response
		check(
			code == expected,
			string.format("%s for %s returned %s, expected %s", action, tostring(userId), tostring(code), expected)
		)
	end

	local function rowOf(userId: number, saveId: string): any
		for _, entry in call("saves", userId) do
			if entry.saveId == saveId then
				return entry
			end
		end
		return nil
	end

	local function memberOf(team: any, userId: number): any
		for _, member in team.members do
			if member.userId == userId then
				return member
			end
		end
		return nil
	end

	-- One server per save and the teammate finder (CM2-S3).
	local SAVE_FAR = "Playtest Far"

	-- The raw save-to-server map value for one of the player's saves.
	local function locatorEntry(saveId: string): any
		return call("locatorEntry", { userId = R.userId, saveId = saveId }).entry
	end

	-- Deletes a leftover "Playtest Far" after clearing its fake foreign map entry.
	local function deleteFar(): boolean
		local entry = findSave(SAVE_FAR)
		if not entry then
			return false
		end
		call("clearElsewhere", { userId = R.userId, saveId = entry.saveId })
		return deleteLeftover(SAVE_FAR)
	end

	local function finderListings(userId: number): any
		return saveActAsOk(userId, "Save.FinderList", {})
	end

	-- The shadow's most recently played owned save other than the finder save.
	local function shadowOtherSave(): any
		for _, entry in call("saves", S.userId) do
			if entry.role == "Owner" and entry.saveId ~= S.finderSaveId then
				return entry
			end
		end
		return nil
	end

	-- Removes the finder save if a failed run left it: the player leaves its team, the shadow
	-- switches away and deletes it.
	local function deleteFinderSave(): boolean
		local finderSaveId = S.finderSaveId
		if finderSaveId == nil then
			return false
		end
		if rowOf(R.userId, finderSaveId) ~= nil then
			saveActOk("Save.LeaveTeam", { saveId = finderSaveId })
		end
		local row = rowOf(S.userId, finderSaveId)
		if row == nil then
			S.finderSaveId = nil
			return false
		end
		if row.active then
			local other = shadowOtherSave()
			check(other ~= nil, "shadow has no other own save")
			S.plotId = saveActAsOk(S.userId, "Save.Play", { saveId = other.saveId }).plotId
		end
		saveActAsOk(S.userId, "Save.Delete", { saveId = finderSaveId, confirmName = row.name })
		S.finderSaveId = nil
		return true
	end

	local function activeSave(): string
		local entry = findSave(SAVE_A)
		local created = entry == nil
		if entry then
			saveA = entry.saveId
		else
			saveA = saveActOk("Save.Create", { name = SAVE_A }).saveId
		end
		playSave(saveA)
		check(type(R.plotId) == "string", "no PlotId after playing " .. SAVE_A)
		return string.format("%s %s, plot %s", SAVE_A, if created then "created" else "found", tostring(R.plotId))
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
		priceToSell(S.userId)
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
		local snapshot = snap(R.userId)
		check(#snapshot.customerOrders == 0, "player still has customer orders")
		priceToSell(R.userId)
		if not soak then
			check(snapshot.staff.LotWorker == 0, "player has a Lot Worker hired")
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
		-- CM2-S3: the finder save needs the shadow's live profile, so it goes before shadowLeave.
		attempt("delete finder save", function()
			deleteFinderSave()
		end)
		attempt("shadowLeave", function()
			call("shadowLeave", nil)
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
		for _, name in { SAVE_B, SAVE_B2, SAVE_C, SAVE_DUO } do
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

	if mode == "full" then
		addStep("01", "UNIT_RUNNER", {}, function()
			local runner = require(ServerStorage:WaitForChild("UnitTest"):WaitForChild("RunUnitTest")) :: any
			local totals = runner(nil, 10)
			check(totals.failed == 0, totals.failed .. " unit test(s) failed")
			check(totals.run >= 332, "only " .. totals.run .. " unit tests ran (expected >= 332)")
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
			check(HttpService:JSONEncode(saved.bays) == HttpService:JSONEncode(after.bays), "bays changed")
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
					awaitDelivery(S.userId, data.orderId)
					placeOne(S.userId, data.bay)
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

		addStep("21", "ART_ASSETS", {}, function()
			local art = ReplicatedStorage:FindFirstChild("ArtAssets")
			check(art ~= nil, "ReplicatedStorage.ArtAssets is missing")
			local container = art :: Instance
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
			return string.format("%d blender models, %d meshes, 0 failed, 0 duplicates", models, #meshParts)
		end)

		addStep("24", "SAVE_CREATE", { "02a" }, function()
			local removed = 0
			for _, name in { SAVE_B, SAVE_B2, SAVE_C } do
				if deleteLeftover(name) then
					removed += 1
				end
			end
			local listedBefore = #saveList()
			local requestId = "playtest_create_" .. HttpService:GenerateGUID(false)
			local first = saveActOk("Save.Create", { name = SAVE_B }, requestId)
			local replay = saveActOk("Save.Create", { name = SAVE_B }, requestId)
			check(replay.saveId == first.saveId, "replayed create returned another save")
			local listedAfter = #saveList()
			check(
				listedAfter == listedBefore + 1,
				string.format("save list %d -> %d, expected +1", listedBefore, listedAfter)
			)
			saveB = first.saveId
			return string.format("%s created, replay deduplicated, %d leftover(s) removed", SAVE_B, removed)
		end)

		addStep("25", "SAVE_SWITCH", { "24" }, function()
			local snapA = snap(R.userId)
			local plotA = R.plotId
			playSave(saveB)
			check(R.plotId == plotA, string.format("PlotId %s -> %s", tostring(plotA), tostring(R.plotId)))
			local snapB = snap(R.userId)
			check(
				snapB.cash == GameConfig.StartingCash,
				string.format("B cash %d, expected %d", snapB.cash, GameConfig.StartingCash)
			)
			check(snapB.placementCount == 0, "B has " .. snapB.placementCount .. " placements")
			orderTrees(R.userId, 1)
			check(snap(R.userId).cash == GameConfig.StartingCash - UNIT_PRICE, "B order did not cost " .. UNIT_PRICE)
			playSave(saveA)
			local backA = snap(R.userId)
			for _, field in { "cash", "revision", "placementCount" } do
				check(
					snapA[field] == backA[field],
					string.format("A %s %s -> %s", field, tostring(snapA[field]), tostring(backA[field]))
				)
			end
			sameTable("A stock", snapA.stock, backA.stock)
			playSave(saveB)
			local backB = snap(R.userId).cash
			check(
				backB == GameConfig.StartingCash - UNIT_PRICE,
				string.format("B cash %d, expected %d", backB, GameConfig.StartingCash - UNIT_PRICE)
			)
			playSave(saveA)
			return string.format("same plot %s, A cash %d kept, B cash %d", tostring(R.plotId), backA.cash, backB)
		end)

		addStep("26", "SAVE_RENAME", { "24" }, function()
			saveRefused("Save.Rename", { saveId = saveB, name = "" }, "NameInvalid")
			saveActOk("Save.Rename", { saveId = saveB, name = SAVE_B2 })
			local renamed = findSave(SAVE_B2)
			check(renamed ~= nil and renamed.saveId == saveB, SAVE_B2 .. " not listed")
			saveRefused("Save.Rename", { saveId = saveB, name = "playtest a" }, "NameInUse")
			return SAVE_B .. " renamed to " .. SAVE_B2
		end)

		addStep("27", "SAVE_DELETE", { "26" }, function()
			saveRefused("Save.Delete", { saveId = saveB, confirmName = SAVE_B }, "ConfirmationMismatch")
			check(findSave(SAVE_B2) ~= nil, SAVE_B2 .. " vanished after a mismatched confirmation")
			saveRefused("Save.Delete", { saveId = saveA, confirmName = SAVE_A }, "SaveActive")
			saveActOk("Save.Delete", { saveId = saveB, confirmName = " playtest b2 " })
			check(findSave(SAVE_B2) == nil, SAVE_B2 .. " still listed after deleting")
			saveRefused("Save.Play", { saveId = saveB }, "SaveNotFound")
			return "mismatch and active refused, " .. SAVE_B2 .. " deleted"
		end)

		addStep("28", "FAIL_CLOSED", { "02a" }, function()
			saveC = saveActOk("Save.Create", { name = SAVE_C }).saveId
			playSave(saveC)
			call("lockSave", { userId = R.userId, saveId = saveC })
			call("flush", nil)
			local current = realPlayer()
			local stopped = poll(function()
				return current:GetAttribute("CompanyReady") == false
					and current:GetAttribute("CompanyError") == "SessionLocked"
			end, 5)
			check(
				stopped,
				string.format(
					"CompanyReady %s, CompanyError %s",
					tostring(current:GetAttribute("CompanyReady")),
					tostring(current:GetAttribute("CompanyError"))
				)
			)
			local refused = act(R.userId, "Supplier.PlaceOrder", { speciesId = SPECIES, sizeId = SIZE, quantity = 1 })
			check(
				type(refused) == "table" and refused.errorCode == "CompanyUnavailable",
				"order on a failed save returned "
					.. tostring(type(refused) == "table" and refused.errorCode or refused)
			)
			call("unlockSave", { userId = R.userId, saveId = saveC })
			playSave(saveA)
			saveActOk("Save.Delete", { saveId = saveC, confirmName = SAVE_C })
			return "SessionLocked shown, order refused, back on " .. SAVE_A
		end)

		-- Co-op saves (CM2-S2): the shadow is the second member, shadow 2 the third.
		addStep("29", "COOP_JOIN", { "02", "02a" }, function()
			local removed = deleteLeftover(SAVE_DUO)
			saveDuo = saveActOk("Save.Create", { name = SAVE_DUO, size = "Duo" }).saveId
			playSave(saveDuo)
			local current = realPlayer()
			check(
				current:GetAttribute("ActiveSaveRole") == "Owner",
				"ActiveSaveRole " .. tostring(current:GetAttribute("ActiveSaveRole"))
			)
			check(
				current:GetAttribute("ActiveSaveSize") == "Duo",
				"ActiveSaveSize " .. tostring(current:GetAttribute("ActiveSaveSize"))
			)
			local team = saveActOk("Save.Team", {})
			check(
				type(team.inviteCode) == "string" and string.match(team.inviteCode, "^[1-9]%d%d%d%d$") ~= nil,
				"invite code " .. tostring(team.inviteCode)
			)
			check(team.seats == 2, "seats " .. tostring(team.seats))
			duoCode = team.inviteCode
			local joined = saveActAsOk(S.userId, "Save.Join", { code = duoCode })
			check(joined.saveId == saveDuo, "joined " .. tostring(joined.saveId))
			local played = saveActAsOk(S.userId, "Save.Play", { saveId = saveDuo })
			check(
				played.plotId == R.plotId,
				string.format("shadow plot %s, owner plot %s", tostring(played.plotId), tostring(R.plotId))
			)
			team = saveActOk("Save.Team", {})
			check(#team.members == 2, #team.members .. " team members")
			local shadowMember = memberOf(team, S.userId)
			check(
				shadowMember ~= nil and shadowMember.role == "Member" and shadowMember.online == true,
				"shadow is not an online Member"
			)
			local row = rowOf(S.userId, saveDuo)
			check(row ~= nil and row.role == "Member" and row.name == nil, "shadow row is not a nameless Member row")
			return string.format(
				"code %s, shadow on plot %s%s",
				duoCode,
				tostring(R.plotId),
				if removed then ", leftover removed" else ""
			)
		end)

		addStep("30", "COOP_SHARED_CASH", { "29" }, function()
			local rStart, sStart = snap(R.userId), snap(S.userId)
			check(
				rStart.cash == sStart.cash and rStart.revision == sStart.revision,
				string.format("snapshots differ: cash %d vs %d", rStart.cash, sStart.cash)
			)
			local start = rStart.cash
			check(start >= 3 * UNIT_PRICE, string.format("Duo cash %d below three orders", start))
			orderTrees(S.userId, 1)
			local afterShadow = snap(R.userId).cash
			check(
				afterShadow == start - UNIT_PRICE,
				string.format("owner cash %d after the shadow's order", afterShadow)
			)
			local payload = { speciesId = SPECIES, sizeId = SIZE, quantity = 1 }
			local requestId = "playtest_shared_" .. HttpService:GenerateGUID(false)
			local first = act(R.userId, "Supplier.PlaceOrder", payload, requestId)
			if type(first) == "table" and first.errorCode == "SupplierOutOfStock" then
				advance(240)
				requestId = "playtest_shared_" .. HttpService:GenerateGUID(false)
				first = act(R.userId, "Supplier.PlaceOrder", payload, requestId)
			end
			check(
				type(first) == "table" and first.ok == true,
				"owner order failed: " .. tostring(type(first) == "table" and first.errorCode or first)
			)
			local rAfter, sAfter = snap(R.userId), snap(S.userId)
			check(
				rAfter.cash == start - 2 * UNIT_PRICE and sAfter.cash == rAfter.cash,
				string.format("cash owner %d, shadow %d, expected %d", rAfter.cash, sAfter.cash, start - 2 * UNIT_PRICE)
			)
			local second = act(S.userId, "Supplier.PlaceOrder", payload, requestId)
			check(
				type(second) == "table" and second.errorCode == "DuplicateRequest",
				"same request ID returned " .. tostring(type(second) == "table" and second.errorCode or second)
			)
			local cash = snap(R.userId).cash
			check(
				cash == start - 2 * UNIT_PRICE,
				string.format("cash %d, expected one debit to %d", cash, start - 2 * UNIT_PRICE)
			)
			check(snap(S.userId).cash == cash, "shadow sees another cash balance")
			return string.format("shared cash %d -> %d, duplicate refused", start, cash)
		end)

		addStep("31", "COOP_RULES", { "29" }, function()
			for _, refused in
				{
					{ "Save.RegenerateCode", {} },
					{ "Save.RemoveMember", { userId = R.userId } },
					{ "Save.SetSize", { size = "Quad" } },
					{ "Save.Rename", { saveId = saveDuo, name = "Shadow Lot" } },
					{ "Save.Delete", { saveId = saveDuo, confirmName = "Shared lot" } },
				}
			do
				saveRefusedAs(S.userId, refused[1], refused[2], "OwnerOnly")
			end
			saveRefusedAs(S2.userId, "Save.Join", { code = duoCode }, "SaveFull")
			saveRefused("Save.SetSize", { size = "Solo" }, "SizeTooSmall")
			local old = duoCode
			local renewed = saveActOk("Save.RegenerateCode", {})
			check(type(renewed.inviteCode) == "string" and renewed.inviteCode ~= old, "the new code equals the old one")
			duoCode = renewed.inviteCode
			saveRefusedAs(S2.userId, "Save.Join", { code = old }, "InviteCodeInvalid")
			saveActOk("Save.SetSize", { size = "Trio" })
			saveActAsOk(S2.userId, "Save.Join", { code = duoCode })
			saveRefused("Save.SetSize", { size = "Duo" }, "SizeTooSmall")
			saveActOk("Save.RemoveMember", { userId = S2.userId })
			saveActOk("Save.SetSize", { size = "Duo" })
			return "member actions OwnerOnly, seat limit, old code refused, resize and remove ok"
		end)

		addStep("32", "COOP_REMOVE", { "29" }, function()
			saveActOk("Save.RemoveMember", { userId = S.userId })
			local gone = invoke("snapshot", S.userId)
			check(
				type(gone) == "table" and gone.errorCode == "NoActiveSave",
				"removed shadow snapshot " .. tostring(type(gone) == "table" and gone.errorCode or gone)
			)
			check(rowOf(S.userId, saveDuo) == nil, "removed shadow still lists the Duo")
			saveRefusedAs(S.userId, "Save.Play", { saveId = saveDuo }, "SaveNotFound")
			saveActAsOk(S.userId, "Save.Join", { code = duoCode })
			saveActAsOk(S.userId, "Save.Play", { saveId = saveDuo })
			-- The owner goes elsewhere; the member keeps playing.
			playSave(saveA)
			local memberCashBefore = snap(S.userId).cash
			check(memberCashBefore >= UNIT_PRICE, string.format("Duo cash %d below one order", memberCashBefore))
			orderTrees(S.userId, 1)
			check(
				snap(S.userId).cash == memberCashBefore - UNIT_PRICE,
				"member order with the owner away did not debit once"
			)
			local team = saveActAsOk(S.userId, "Save.Team", {})
			local owner = memberOf(team, R.userId)
			check(owner ~= nil and owner.online == false, "owner not listed as offline")
			saveRefused("Save.Delete", { saveId = saveDuo, confirmName = SAVE_DUO }, "SaveInUse")
			local own = nil
			for _, entry in call("saves", S.userId) do
				if entry.role == "Owner" then
					own = entry
					break
				end
			end
			check(own ~= nil, "shadow has no own save")
			local played = saveActAsOk(S.userId, "Save.Play", { saveId = own.saveId })
			S.plotId = played.plotId
			saveActOk("Save.Delete", { saveId = saveDuo, confirmName = SAVE_DUO })
			check(rowOf(S.userId, saveDuo) == nil, "shadow still lists the deleted Duo")
			return string.format("removed and re-joined, Duo deleted, shadow back on %s", tostring(S.plotId))
		end)

		-- One server per save (CM2-S3): this Studio server holds the played save in the map.
		addStep("33", "LOCATOR_CLAIM", { "02a" }, function()
			local entry = locatorEntry(saveA)
			check(type(entry) == "table", "no map entry for " .. SAVE_A)
			check(entry.jobId == "studio", "map jobId " .. tostring(entry.jobId))
			check(entry.hostUserId == R.userId, "map hostUserId " .. tostring(entry.hostUserId))
			check(entry.releasedAt == nil, "map entry for the played save is released")
			local renewal = call("renewLocations", nil)
			check(renewal.ok == true, string.format("renewal failed for %s saves", tostring(renewal.failures)))
			check(type(renewal.renewed) == "number" and renewal.renewed >= 1, "renewed " .. tostring(renewal.renewed))
			return string.format("held by studio for %d, %d renewed", R.userId, renewal.renewed)
		end)

		-- A co-op save that another server holds: the row offers Join, Play refuses, and Studio
		-- cannot teleport.
		addStep("34", "ELSEWHERE", { "02a" }, function()
			local removed = deleteFar()
			local far = saveActOk("Save.Create", { name = SAVE_FAR, size = "Duo" }).saveId
			playSave(far)
			playSave(saveA)
			local released = locatorEntry(far)
			check(
				type(released) == "table" and released.releasedAt ~= nil,
				"map entry for " .. SAVE_FAR .. " is not released"
			)
			call("placeElsewhere", { userId = R.userId, saveId = far })
			call("lockSave", { userId = R.userId, saveId = far })
			local listed = saveActOk("Save.List", {})
			local row = nil
			for _, entry in listed.saves do
				if entry.saveId == far then
					row = entry
				end
			end
			check(row ~= nil and row.elsewhere == true, SAVE_FAR .. " row is not marked elsewhere")
			saveRefused("Save.Play", { saveId = far }, "SaveInUseElsewhere")
			saveRefused("Save.Teleport", { saveId = far }, "TeleportUnavailable")
			local cleared = call("clearElsewhere", { userId = R.userId, saveId = far })
			check(cleared.cleared == true, "clearElsewhere did not clear the entry")
			call("unlockSave", { userId = R.userId, saveId = far })
			playSave(far)
			playSave(saveA)
			saveActOk("Save.Delete", { saveId = far, confirmName = SAVE_FAR })
			return string.format(
				"elsewhere row, Play refused, Teleport unavailable in Studio%s",
				if removed then ", leftover removed" else ""
			)
		end)

		-- Teammate finder (CM2-S3): the shadow searches, the player takes the free seat.
		addStep("35", "FINDER", { "02", "02a" }, function()
			local started = saveActAsOk(S.userId, "Save.FinderStart", { size = "Duo" })
			check(started.created == true, "the shadow's search did not create a save")
			S.finderSaveId = started.saveId
			local listed = finderListings(R.userId)
			local listing = nil
			for _, candidate in listed.listings do
				if candidate.saveId == S.finderSaveId then
					listing = candidate
				end
			end
			check(listing ~= nil, "the shadow's listing is missing")
			check(listing.ownerUserId == S.userId, "listing owner " .. tostring(listing.ownerUserId))
			check(
				listing.seats == 2 and listing.taken == 1,
				string.format("seats %s, taken %s", listing.seats, listing.taken)
			)

			-- Amendment A1.8: the player's plot is the one FinderJoin returned.
			local join = saveActOk("Save.FinderJoin", { saveId = S.finderSaveId })
			local joined = poll(function()
				local current = realPlayer()
				return current:GetAttribute("PlotId") == join.plotId
					and current:GetAttribute("ActiveSaveRole") == "Member"
			end, 10)
			check(
				joined,
				string.format(
					"PlotId %s (expected %s), role %s",
					tostring(realPlayer():GetAttribute("PlotId")),
					tostring(join.plotId),
					tostring(realPlayer():GetAttribute("ActiveSaveRole"))
				)
			)
			R.plotId = join.plotId
			check(#finderListings(R.userId).listings == 0, "a full listing is still shown")
			saveRefusedAs(S2.userId, "Save.FinderJoin", { saveId = S.finderSaveId }, "ListingGone")
			saveActOk("Save.LeaveTeam", { saveId = S.finderSaveId })
			playSave(saveA)

			local again = saveActAsOk(S.userId, "Save.FinderStart", {})
			check(again.created == false and again.saveId == S.finderSaveId, "the search did not list the same save")
			check(#finderListings(R.userId).listings == 1, "the relisted save is not shown")
			saveActAsOk(S.userId, "Save.FinderStop", {})
			check(#finderListings(R.userId).listings == 0, "a stopped listing is still shown")
			local third = saveActAsOk(S.userId, "Save.FinderStart", {})
			check(third.saveId == S.finderSaveId, "the third search listed another save")
			check(#finderListings(R.userId).listings == 1, "the listing is not shown again")
			local other = shadowOtherSave()
			check(other ~= nil, "shadow has no other own save")
			S.plotId = saveActAsOk(S.userId, "Save.Play", { saveId = other.saveId }).plotId
			check(#finderListings(R.userId).listings == 0, "the listing outlived the switch")
			check(deleteFinderSave(), "the finder save was not deleted")
			return string.format(
				"listed, joined on %s, left, relisted, stopped, switched, deleted",
				tostring(join.plotId)
			)
		end)

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

			-- 3. The three reasons; nothing changes after a refusal.
			refused(stockPayload(bayIndex, 39.5, 0, 1), "OutsideLot")
			refused(stockPayload(bayIndex, 16, -10, 1), "KeepClear")
			refused(stockPayload(bayIndex, -10.6, -20, 5), "KeepClear")

			-- 4. A row of 5 lands as a whole; its replay places nothing.
			local requestId = "playtest_row_" .. HttpService:GenerateGUID(false)
			local beforeRow = snap(R.userId)
			local response = act(R.userId, "Stock.Place", stockPayload(bayIndex, -35, -20, 5), requestId)
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
			local replay = act(R.userId, "Stock.Place", stockPayload(bayIndex, -35, -20, 5), requestId)
			check(
				type(replay) == "table" and replay.errorCode == "DuplicateRequest",
				"row replay returned " .. tostring(type(replay) == "table" and replay.errorCode or replay)
			)
			check(snap(R.userId).placementCount == afterRow.placementCount, "the replay placed trees")

			-- 5. With the first tree stored back, its neighbour blocks a spot 1 stud away.
			storeOk(ids[1])
			local storedIn = bayWith(R.userId, 1)
			check(storedIn ~= nil, "the stored tree is in no bay")
			refused(stockPayload(storedIn :: number, -27.9, -20, 1), "TooClose")
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

		addStep("22", "LEAK_CHECK", { "02" }, leakCheck)
		addStep("23", "CLEANUP", {}, cleanup)
	else
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
