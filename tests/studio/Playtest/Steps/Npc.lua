--!strict
-- Playtest steps 37-40 (full mode) and their helpers: walking customers (CM2-N1). Since
-- CM2-N2 the player checks out the customer at the counter by prompt (serveCounter).
-- Installed by RunPlaytest.execute (CM2-RF).
return function(ctx: any)
	local ArtLibrary = ctx.ArtLibrary
	local Customers = ctx.Customers
	local DELIVERY_WAIT = ctx.DELIVERY_WAIT
	local GameConfig = ctx.GameConfig
	local NPC_FULL_PATH = ctx.NPC_FULL_PATH
	local NPC_RESERVED_STATES = ctx.NPC_RESERVED_STATES
	local NpcPath = ctx.NpcPath
	local POLL_INTERVAL = ctx.POLL_INTERVAL
	local R = ctx.R
	local SIZE = ctx.SIZE
	local SPECIES = ctx.SPECIES
	local addStep = ctx.addStep
	local advance = ctx.advance
	local awaitDelivery = ctx.awaitDelivery
	local bayWith = ctx.bayWith
	local call = ctx.call
	local check = ctx.check
	local displayedCount = ctx.displayedCount
	local findNpc = ctx.findNpc
	local findOrder = ctx.findOrder
	local hasObject = ctx.hasObject
	local npcObjectsLeft = ctx.npcObjectsLeft
	local npcOnPlot = ctx.npcOnPlot
	local npcSnapshot = ctx.npcSnapshot
	local orderPart = ctx.orderPart
	local orderTrees = ctx.orderTrees
	local placeOne = ctx.placeOne
	local plotFolder = ctx.plotFolder
	local poll = ctx.poll
	local prompt = ctx.prompt
	local realPlayer = ctx.realPlayer
	local serveCounter = ctx.serveCounter
	local snap = ctx.snap
	local snapLogOf = ctx.snapLogOf
	local strayHumanoids = ctx.strayHumanoids
	local teleport = ctx.teleport
	local withNpcCleanup = ctx.withNpcCleanup

	-- Walking customers (CM2-N1) -----------------------------------------------------------
	local function npcVisit(profile: number): string
		return call("npcVisit", { userId = R.userId, profile = profile })
	end

	local function findPlacement(snapshot: any, placementId: string?): any
		for _, placement in snapshot.placements do
			if placement.placementId == placementId then
				return placement
			end
		end
		return nil
	end

	local function displayedTree(placementId: string?): Instance?
		local plot = plotFolder(R.plotId)
		local display = plot and plot:FindFirstChild("DisplayedTrees")
		return if display and placementId then display:FindFirstChild("DisplayedTree_" .. placementId) else nil
	end

	-- Horizontal distance from the visit's avatar to its car door, or nil without an avatar.
	local function doorDistance(visitId: string, space: number): number?
		local plot = plotFolder(R.plotId)
		local customers = plot and plot:FindFirstChild("Customers")
		if not (plot and plot:IsA("Model") and plot.PrimaryPart and customers) then
			return nil
		end
		local center = (plot.PrimaryPart :: BasePart).Position
		local door = NpcPath.toWorld({ x = center.X, z = center.Z }, NpcPath.door(space))
		for _, model in customers:GetChildren() do
			if model:IsA("Model") and model:GetAttribute("NpcVisitId") == visitId then
				local position = model:GetPivot().Position
				local dx, dz = position.X - door.x, position.Z - door.z
				return math.sqrt(dx * dx + dz * dz)
			end
		end
		return nil
	end

	-- The player loads order `number` with prompts (teleport, carry, load), as in step 13;
	-- within 5 s the waiting customer is gone.
	local function loadAndAwaitDeparture(visitId: string, number: number)
		local ready = poll(function()
			return orderPart(R.plotId, "PickupTree_" .. number) ~= nil
		end, 3)
		check(ready, "PickupTree_" .. number .. " missing")
		teleport(orderPart(R.plotId, "PickupTree_" .. number))
		prompt("carry", number)
		teleport(orderPart(R.plotId, "CustomerCar_" .. number))
		prompt("load", number)
		check(findOrder(snap(R.userId), number) == nil, "order " .. number .. " still open after loading")
		local gone = poll(function()
			return findNpc(npcSnapshot(), visitId) == nil
		end, 5)
		check(gone, visitId .. " still present 5 s after its tree was loaded")
	end

	-- One wave of buying customers: each walks the full path, waits at its car and leaves
	-- once a player loads its tree.
	local function npcWave(profiles: { number })
		local ids: { string } = {}
		local seen: { [string]: { reserved: boolean, carried: boolean } } = {}
		for _, profile in profiles do
			local visitId = npcVisit(profile)
			table.insert(ids, visitId)
			seen[visitId] = { reserved = false, carried = false }
		end
		local waiting: { [string]: any } = {}
		local deadline = os.clock() + 150
		while true do
			-- CM2-N2: the player checks out the customer at the counter.
			serveCounter()
			local npcs = npcSnapshot()
			local rSnap = snap(R.userId)
			local all = true
			for _, visitId in ids do
				local customer = findNpc(npcs, visitId)
				check(customer ~= nil, visitId .. " vanished before WaitingAtCar")
				if customer.state == "WaitingAtCar" then
					waiting[visitId] = customer
				else
					all = false
					local placement = findPlacement(rSnap, customer.placementId)
					-- A placement already sold in between the two snapshots is skipped.
					if NPC_RESERVED_STATES[customer.state] and placement ~= nil then
						check(
							placement.reserved,
							visitId .. " in " .. customer.state .. " but its tree is not reserved"
						)
						local model = displayedTree(customer.placementId)
						if model and model:GetAttribute("Reserved") == true then
							seen[visitId].reserved = true
						end
						if model and model:GetAttribute("NpcCarried") == true then
							seen[visitId].carried = true
						end
					end
				end
			end
			if all then
				break
			end
			check(os.clock() < deadline, table.concat(ids, ", ") .. " not all WaitingAtCar within 150 s")
			task.wait(POLL_INTERVAL)
		end
		local rSnap = snap(R.userId)
		for _, visitId in ids do
			local customer = waiting[visitId]
			local history = table.concat(customer.history, ">")
			check(#customer.history == #NPC_FULL_PATH, visitId .. " history " .. history)
			for index, state in NPC_FULL_PATH do
				check(customer.history[index] == state, visitId .. " history " .. history)
			end
			check(customer.snaps == 0, visitId .. " snapped " .. customer.snaps .. " time(s): " .. snapLogOf(visitId))
			check(seen[visitId].reserved, visitId .. ": its tree never showed Reserved")
			check(seen[visitId].carried, visitId .. ": its tree was never NpcCarried")
			local order = findOrder(rSnap, customer.orderNumber)
			check(
				order ~= nil and order.parkingSpace == customer.space,
				string.format(
					"%s: order #%s space %s, visit space %d",
					visitId,
					tostring(customer.orderNumber),
					tostring(order and order.parkingSpace),
					customer.space
				)
			)
			local carName = "CustomerCar_" .. tostring(customer.orderNumber)
			check(hasObject(R.plotId, carName), carName .. " missing")
			local visitCarName = "VisitCar_" .. tostring(string.match(visitId, "^visit:(%d+)$"))
			check(not hasObject(R.plotId, visitCarName), visitCarName .. " left over")
			local distance = doorDistance(visitId, customer.space)
			check(
				distance ~= nil and distance <= 3,
				string.format("%s is %s studs from its door", visitId, tostring(distance))
			)
		end
		for _, visitId in ids do
			loadAndAwaitDeparture(visitId, waiting[visitId].orderNumber)
		end
	end

	-- R shows at least n unreserved Medium Douglas Fir: order, deliver and place the missing
	-- ones. Returns the number placed.
	local function ensureDouglas(n: number): number
		local function unreservedDouglas(): number
			local count = 0
			for _, placement in snap(R.userId).placements do
				if placement.speciesId == SPECIES and placement.sizeId == SIZE and not placement.reserved then
					count += 1
				end
			end
			return count
		end
		local need = math.max(0, n - unreservedDouglas())
		if need > 0 then
			local inBays = 0
			for _, bay in snap(R.userId).bays do
				if bay.speciesId == SPECIES then
					inBays += bay.counts[SIZE]
				end
			end
			if inBays < need then
				local data = orderTrees(R.userId, need - inBays)
				advance(DELIVERY_WAIT)
				awaitDelivery(R.userId, data.orderId)
			end
			task.wait(10) -- stay under the per-action rate limit after ROW_FILL
			for _ = 1, need do
				local bay = bayWith(R.userId, 1)
				check(bay ~= nil, "no bay with a Medium Douglas Fir")
				placeOne(R.userId, bay :: number)
			end
		end
		return need
	end

	-- Fix round 1 (P6): every plot's stand fits its KeepClear box and passes walking
	-- customers through (LotStructure); the player's character is in PlayerCharacter.
	local function checkStandsAndCharacter()
		local stand: any = nil
		for _, box in GameConfig.Placement.KeepClear do
			if box.id == "Stand" then
				stand = box
			end
		end
		check(stand ~= nil, "KeepClear has no Stand box")
		local groups = Customers.Npc.CollisionGroups
		for index = 1, 6 do
			local plotId = string.format("Plot_%02d", index)
			local plot = plotFolder(plotId)
			local tent = plot and plot:FindFirstChild("StarterSalesTent")
			check(
				plot ~= nil and plot:IsA("Model") and plot.PrimaryPart ~= nil and tent ~= nil and tent:IsA("Model"),
				plotId .. " has no StarterSalesTent"
			)
			local center = ((plot :: Model).PrimaryPart :: BasePart).Position
			local c = { x = center.X, z = center.Z }
			-- Fix round 2 (G3): lot-frame AABB over every part's 8 corners.
			local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
			local ref: BasePart? = nil
			local bestArea = -math.huge
			for _, d in (tent :: Model):GetDescendants() do
				if d:IsA("BasePart") then
					for _, sx in { -1, 1 } do
						for _, sy in { -1, 1 } do
							for _, sz in { -1, 1 } do
								local corner = d.CFrame:PointToWorldSpace(Vector3.new(sx, sy, sz) * d.Size / 2)
								local l = NpcPath.fromWorld(c, corner.X, corner.Z)
								minX, maxX = math.min(minX, l.x), math.max(maxX, l.x)
								minZ, maxZ = math.min(minZ, l.z), math.max(maxZ, l.z)
							end
						end
					end
					local area = d.Size.X * d.Size.Z
					if area > bestArea then
						bestArea = area
						ref = d
					end
				end
			end
			check(ref ~= nil, plotId .. " stand has no parts")
			check(
				minX >= stand.minX - 0.5
					and maxX <= stand.maxX + 0.5
					and minZ >= stand.minZ - 0.5
					and maxZ <= stand.maxZ + 0.5,
				string.format("%s stand exceeds KeepClear (x %.1f..%.1f, z %.1f..%.1f)", plotId, minX, maxX, minZ, maxZ)
			)
			local rv = (ref :: BasePart).CFrame.RightVector
			local delta = ArtLibrary.levelYaw(rv.X, rv.Z)
			check(
				math.abs(delta) <= math.rad(1),
				string.format("%s stand not lot-aligned (%.1f deg)", plotId, math.deg(delta))
			)
			for _, descendant in (tent :: Model):GetDescendants() do
				if descendant:IsA("BasePart") then
					check(
						descendant.CollisionGroup == groups.Structure,
						"stand part not LotStructure (" .. plotId .. " " .. descendant.Name .. ")"
					)
				end
			end
		end
		local character = realPlayer().Character
		check(character ~= nil, "player has no character")
		for _, descendant in (character :: Model):GetDescendants() do
			if descendant:IsA("BasePart") then
				check(
					descendant.CollisionGroup == groups.Player,
					"player character not in PlayerCharacter (" .. descendant.Name .. ")"
				)
			end
		end
	end

	local function npcWalkStep(): string?
		-- PREFLIGHT's reset left no NPC, waiting car or open order (Fix round 1, P1-P3).
		checkStandsAndCharacter()
		local need = ensureDouglas(4)
		local shown = poll(function()
			return displayedCount(R.plotId) == snap(R.userId).placementCount
		end, 4)
		check(shown, "DisplayedTrees differs from placementCount before the walk")
		local start = snap(R.userId)
		npcWave({ 8, 20 })
		npcWave({ 32 })
		local final = snap(R.userId)
		check(final.sales == start.sales + 3, string.format("sales %d -> %d, expected +3", start.sales, final.sales))
		local clean = poll(function()
			return npcObjectsLeft({ R.plotId }) == nil
		end, 4)
		check(clean, tostring(npcObjectsLeft({ R.plotId })))
		for _, placement in final.placements do
			check(not placement.reserved, placement.placementId .. " is still reserved")
		end
		return string.format("3 customers walked, paid and left; sales +3, %d tree(s) placed", need)
	end
	addStep("37", "NPC_WALK", { "03" }, withNpcCleanup(npcWalkStep))

	local function npcGiveUpStep(): string?
		-- (a) Profile 5 wants Fraser Fir: nothing matches, the customer walks out.
		local startSnap = snap(R.userId)
		local first = npcVisit(5)
		local history: { string } = {}
		local goneFirst = poll(function()
			local customer = findNpc(npcSnapshot(), first)
			if customer then
				history = customer.history
				return false
			end
			return true
		end, 45)
		check(goneFirst, first .. " still present after 45 s")
		local n = #history
		check(
			n >= 3 and history[n - 2] == "Browsing" and history[n - 1] == "WalkingOut" and history[n] == "Departing",
			first .. " history " .. table.concat(history, ">")
		)
		local afterFirst = snap(R.userId)
		check(
			afterFirst.customerVisits == startSnap.customerVisits + 1,
			string.format("customerVisits %d -> %d", startSnap.customerVisits, afterFirst.customerVisits)
		)
		check(
			afterFirst.abandonedCustomers == startSnap.abandonedCustomers + 1,
			string.format("abandonedCustomers %d -> %d", startSnap.abandonedCustomers, afterFirst.abandonedCustomers)
		)

		-- (b) Profile 8 gives up while carrying its tree.
		local second = npcVisit(8)
		local placementId: string? = nil
		local carrying = poll(function()
			local customer = findNpc(npcSnapshot(), second)
			if customer and (customer.state == "PickingUp" or customer.state == "WalkingToQueue") then
				placementId = customer.placementId
				return true
			end
			return false
		end, 60)
		check(carrying, second .. " never reached PickingUp or WalkingToQueue")
		call("npcGiveUp", second)
		local released = poll(function()
			local placement = findPlacement(snap(R.userId), placementId)
			local model = displayedTree(placementId)
			return placement ~= nil
				and not placement.reserved
				and not (model ~= nil and model:GetAttribute("NpcCarried") == true)
		end, 3)
		check(released, tostring(placementId) .. " still reserved or hidden 3 s after giving up")
		local goneSecond = poll(function()
			return findNpc(npcSnapshot(), second) == nil
		end, 30)
		check(goneSecond, second .. " still present 30 s after giving up")
		local final = snap(R.userId)
		check(final.sales == afterFirst.sales, string.format("sales %d -> %d", afterFirst.sales, final.sales))
		return "no-stock walk-out counted, give-up released " .. tostring(placementId)
	end
	addStep("38", "NPC_GIVE_UP", { "03" }, withNpcCleanup(npcGiveUpStep))

	local function npcRejoinStep(): string?
		local visitId = npcVisit(8)
		local reserved = poll(function()
			local customer = findNpc(npcSnapshot(), visitId)
			return customer ~= nil and NPC_RESERVED_STATES[customer.state] == true
		end, 60)
		check(reserved, visitId .. " never reserved its tree")
		call("rejoin", R.userId)
		local clean = poll(function()
			if npcOnPlot(R.plotId) ~= 0 or npcObjectsLeft({ R.plotId }) ~= nil then
				return false
			end
			local snapshot = snap(R.userId)
			for _, placement in snapshot.placements do
				if placement.reserved then
					return false
				end
			end
			return displayedCount(R.plotId) == snapshot.placementCount and strayHumanoids() == 0
		end, 5)
		check(
			clean,
			string.format(
				"after rejoin: %d visit(s) on the plot, %s, %d stray Humanoid(s)",
				npcOnPlot(R.plotId),
				tostring(npcObjectsLeft({ R.plotId })),
				strayHumanoids()
			)
		)
		return "the rejoin removed the customer, its car and the reservation"
	end
	addStep("39", "NPC_REJOIN_CLEANUP", { "03" }, withNpcCleanup(npcRejoinStep))

	-- Fix round 1 (P5): a customer from the live arrival loop (not npcVisit) buys a tree.
	local function npcRealArrivalStep(): string?
		ensureDouglas(2)
		local known: { [string]: boolean } = {}
		for _, customer in npcSnapshot().visits do
			known[customer.visitId] = true
		end
		local start = snap(R.userId)
		call("npcNextArrival", { userId = R.userId, profile = 8 })
		call("pauseCustomers", false)
		local visitId: string? = nil
		local arrived = poll(function()
			for _, customer in npcSnapshot().visits do
				if not known[customer.visitId] and customer.plotId == R.plotId and customer.customerNumber == 8 then
					visitId = customer.visitId
					return true
				end
			end
			return false
		end, 12)
		call("pauseCustomers", true)
		check(arrived and visitId ~= nil, "no live arrival with customer number 8 within 12 s")
		local id = visitId :: string
		local customer: any = nil
		local waiting = poll(function()
			-- CM2-N2: the player checks out the customer at the counter.
			serveCounter()
			customer = findNpc(npcSnapshot(), id)
			check(customer ~= nil, id .. " vanished before WaitingAtCar")
			return customer.state == "WaitingAtCar"
		end, 150)
		check(waiting, id .. " not WaitingAtCar within 150 s")
		local history = table.concat(customer.history, ">")
		check(#customer.history == #NPC_FULL_PATH, id .. " history " .. history)
		for index, state in NPC_FULL_PATH do
			check(customer.history[index] == state, id .. " history " .. history)
		end
		check(customer.snaps == 0, id .. " snapped " .. customer.snaps .. " time(s): " .. snapLogOf(id))
		local number = customer.orderNumber
		check(type(number) == "number", id .. " has no order number")
		loadAndAwaitDeparture(id, number)
		local final = snap(R.userId)
		check(
			final.sales >= start.sales + 1,
			string.format("sales %d -> %d, expected at least +1", start.sales, final.sales)
		)
		return "live arrival bought order #" .. tostring(number)
	end
	addStep("40", "NPC_REAL_ARRIVAL", { "03" }, withNpcCleanup(npcRealArrivalStep))

	-- CM2-N2: step 41 (Steps/Checkout.lua) uses these.
	ctx.npcVisit = npcVisit
	ctx.ensureDouglas = ensureDouglas
end
