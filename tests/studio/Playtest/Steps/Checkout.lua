--!strict
-- Playtest step 41 (full mode): manual checkout and queue (CM2-N2, CM2-UVF3).
-- Installed by RunPlaytest.execute after Steps/Npc (it uses npcVisit and ensureDouglas).
return function(ctx: any)
	local ACTION_PAUSE = ctx.ACTION_PAUSE
	local NpcPath = ctx.NpcPath
	local R = ctx.R
	local SIZE = ctx.SIZE
	local SPECIES = ctx.SPECIES
	local actOk = ctx.actOk
	local addStep = ctx.addStep
	local check = ctx.check
	local checkoutPrompt = ctx.checkoutPrompt
	local counterPart = ctx.counterPart
	local displayedCount = ctx.displayedCount
	local emit = ctx.emit
	local ensureDouglas = ctx.ensureDouglas
	local findNpc = ctx.findNpc
	local invoke = ctx.invoke
	local npcSnapshot = ctx.npcSnapshot
	local npcVisit = ctx.npcVisit
	local plotFolder = ctx.plotFolder
	local poll = ctx.poll
	local prompt = ctx.prompt
	local snap = ctx.snap
	local teleport = ctx.teleport
	local withNpcCleanup = ctx.withNpcCleanup

	-- The plot centre of R in world X/Z.
	local function plotCenter(): { x: number, z: number }
		local plot = plotFolder(R.plotId)
		check(plot ~= nil and plot:IsA("Model") and plot.PrimaryPart ~= nil, "player plot has no PrimaryPart")
		local position = ((plot :: Model).PrimaryPart :: BasePart).Position
		return { x = position.X, z = position.Z }
	end

	-- The HumanoidRootPart of a walking customer on R's plot, or nil.
	local function rootOf(visitId: string): BasePart?
		local plot = plotFolder(R.plotId)
		local customers = plot and plot:FindFirstChild("Customers")
		if customers then
			for _, model in customers:GetChildren() do
				if model:IsA("Model") and model:GetAttribute("NpcVisitId") == visitId then
					local root = model:FindFirstChild("HumanoidRootPart")
					return if root and root:IsA("BasePart") then root else nil
				end
			end
		end
		return nil
	end

	local function horizontal(a: Vector3, x: number, z: number): number
		local dx, dz = a.X - x, a.Z - z
		return math.sqrt(dx * dx + dz * dz)
	end

	local function stateOf(visitId: string): string?
		local customer = findNpc(npcSnapshot(), visitId)
		return if customer then customer.state else nil
	end

	local function checkoutStep(): string?
		-- 1. The manual path needs a save without a Cashier.
		local first = snap(R.userId)
		check(first.staff.Cashier == 0, "player has a Cashier hired; manual checkout needs a save without one")

		-- 2. Trees in the queue and counter area go back to receiving (the Checkout box grew).
		for _, placement in first.placements do
			local x, z = placement.x, placement.z
			if type(x) == "number" and type(z) == "number" and x >= 7.5 and x <= 24.5 and z >= -21.5 and z <= 4.5 then
				actOk(R.userId, "Stock.Store", { placementId = placement.placementId })
			end
		end

		-- 3. Two Douglas Fir on display.
		ensureDouglas(2)
		local shown = poll(function()
			return displayedCount(R.plotId) == snap(R.userId).placementCount
		end, 4)
		check(shown, "DisplayedTrees differs from placementCount before the walk")
		local start = snap(R.userId)

		-- 4. A queue of two: one at the counter, one queued.
		local one = npcVisit(8)
		local two = npcVisit(20)
		local counterId: string? = nil
		local waitingId: string? = nil
		local queued = poll(function()
			local stateOne, stateTwo = stateOf(one), stateOf(two)
			if stateOne == "CheckingOut" and stateTwo == "Queued" then
				counterId, waitingId = one, two
				return true
			elseif stateTwo == "CheckingOut" and stateOne == "Queued" then
				counterId, waitingId = two, one
				return true
			end
			return false
		end, 120)
		check(
			queued,
			string.format(
				"no queue of 2 within 120 s (%s %s, %s %s)",
				one,
				tostring(stateOf(one)),
				two,
				tostring(stateOf(two))
			)
		)
		local counter, waiting = counterId :: string, waitingId :: string

		-- 5. CM2-UVF3: the queued customer stands at slot 2, clear of the counter customer, and
		-- the counter customer stands upright.
		local c = plotCenter()
		local slot2 = NpcPath.toWorld(c, NpcPath.queueSlot(2))
		local atSlot = poll(function()
			local root = rootOf(waiting)
			return root ~= nil and horizontal(root.Position, slot2.x, slot2.z) <= 1.5
		end, 10)
		check(atSlot, waiting .. " not at queue slot 2 within 10 s")
		local counterRoot, waitingRoot = rootOf(counter), rootOf(waiting)
		check(counterRoot ~= nil and waitingRoot ~= nil, "a queued customer has no HumanoidRootPart")
		local counterPosition = (counterRoot :: BasePart).Position
		local gap = horizontal((waitingRoot :: BasePart).Position, counterPosition.X, counterPosition.Z)
		check(gap >= 3, string.format("queue gap %.2f", gap))
		local up = (counterRoot :: BasePart).CFrame.UpVector.Y
		check(up >= 0.98, string.format("checkout avatar tilted (UpVector.Y %.3f)", up))

		-- 6. The prompt shows the counter customer's tree and the reserved price.
		local counterVisit = findNpc(npcSnapshot(), counter)
		check(counterVisit ~= nil, counter .. " vanished at the counter")
		local p1 = counterVisit.salePrice
		check(type(p1) == "number", counter .. " has no salePrice")
		local value = checkoutPrompt()
		check(value.Enabled, "checkout prompt not enabled with a customer at the counter")
		check(
			value:GetAttribute("SpeciesId") == SPECIES,
			"prompt SpeciesId " .. tostring(value:GetAttribute("SpeciesId"))
		)
		check(value:GetAttribute("SizeId") == SIZE, "prompt SizeId " .. tostring(value:GetAttribute("SizeId")))
		check(
			value:GetAttribute("Price") == p1,
			string.format("prompt Price %s, reserved %d", tostring(value:GetAttribute("Price")), p1)
		)
		local tenths = value:GetAttribute("HeightTenths")
		check(type(tenths) == "number" and tenths > 0, "prompt HeightTenths " .. tostring(tenths))
		check(
			string.find(value.ObjectText, "Douglas Fir", 1, true) ~= nil
				and string.find(value.ObjectText, "$" .. p1, 1, true) ~= nil,
			"prompt ObjectText " .. value.ObjectText
		)

		-- 7. Capture hold (playtester screenshots, V2).
		teleport(counterPart())
		if ctx.holdSeconds > 0 then
			emit("HOLD 41 checkout queue ready for capture")
			task.wait(ctx.holdSeconds)
		end

		-- 8. Out of reach: nothing happens.
		local plot = plotFolder(R.plotId)
		local spawn = plot and plot:FindFirstChild("Spawn")
		check(spawn ~= nil and spawn:IsA("BasePart"), "player plot has no Spawn")
		teleport(spawn :: BasePart)
		prompt("checkout", 0)
		check(snap(R.userId).sales == start.sales and stateOf(counter) == "CheckingOut", "checkout worked out of reach")

		-- 9. Double trigger in the same frame: exactly one sale at the reserved price.
		teleport(counterPart())
		local responses = 0
		for _ = 1, 2 do
			task.spawn(function()
				invoke("prompt", { userId = R.userId, kind = "checkout", number = 0 })
				responses += 1
			end)
		end
		local answered = poll(function()
			return responses == 2
		end, 3)
		check(answered, "double trigger: " .. responses .. " of 2 prompt responses within 3 s")
		task.wait(ACTION_PAUSE)
		local afterFirst = snap(R.userId)
		check(
			afterFirst.sales == start.sales + 1,
			string.format("double trigger: sales %d -> %d, expected +1", start.sales, afterFirst.sales)
		)
		check(
			afterFirst.cash == start.cash + p1,
			string.format("double trigger: cash %d -> %d, expected +%d", start.cash, afterFirst.cash, p1)
		)
		local counterState = stateOf(counter)
		check(
			counterState == "WalkingToCar" or counterState == "WaitingAtCar",
			counter .. " in " .. tostring(counterState) .. " after checkout"
		)

		-- 10. The queued customer moves up and is checked out next.
		local movedUp = poll(function()
			return stateOf(waiting) == "CheckingOut"
		end, 15)
		check(movedUp, waiting .. " not CheckingOut within 15 s (" .. tostring(stateOf(waiting)) .. ")")
		task.wait(ACTION_PAUSE)
		local waitingVisit = findNpc(npcSnapshot(), waiting)
		check(waitingVisit ~= nil and type(waitingVisit.salePrice) == "number", waiting .. " has no salePrice")
		local p2 = waitingVisit.salePrice
		prompt("checkout", 0)
		local final = snap(R.userId)
		check(final.sales == start.sales + 2, string.format("sales %d -> %d, expected +2", start.sales, final.sales))
		check(
			final.cash == start.cash + p1 + p2,
			string.format("cash %d -> %d, expected +%d", start.cash, final.cash, p1 + p2)
		)
		local npcs = npcSnapshot()
		local firstOrder, secondOrder = findNpc(npcs, counter), findNpc(npcs, waiting)
		check(
			firstOrder ~= nil
				and secondOrder ~= nil
				and type(firstOrder.orderNumber) == "number"
				and type(secondOrder.orderNumber) == "number"
				and firstOrder.orderNumber < secondOrder.orderNumber,
			string.format(
				"order numbers not in join order (%s, %s)",
				tostring(firstOrder and firstOrder.orderNumber),
				tostring(secondOrder and secondOrder.orderNumber)
			)
		)

		-- 11. Nobody at the counter: the prompt hides.
		local hidden = poll(function()
			return not checkoutPrompt().Enabled
		end, 2)
		check(hidden, "checkout prompt still enabled with nobody at the counter")

		return string.format(
			"queue of 2 checked out: +$%d +$%d, sales +2; out of reach and double trigger refused; gap %.1f, up %.3f",
			p1,
			p2,
			gap,
			up
		)
	end
	addStep("41", "CHECKOUT_MANUAL", { "03" }, withNpcCleanup(checkoutStep))
end
