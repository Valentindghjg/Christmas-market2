--!strict
-- Playtest steps 58-59 (full mode): the progression ladder (CM2-G9a, docs/archive/plans/CM2-G9a.md).
-- Installed by RunPlaytest.execute after Steps/Map. Both steps work on the shadow S only: step 58
-- buys every ladder kind once through the real actions (with setProgression fixtures for cash
-- and prerequisites) and restores S; step 59 moves S's stand through HQ 1-4 and its lot through
-- levels 0-6 and checks the G19 clearances, then restores S's visuals.
return function(ctx: any)
	local GameConfig = ctx.GameConfig
	local HttpService = ctx.HttpService
	local NpcPath = ctx.NpcPath
	local S = ctx.S
	local act = ctx.act
	local actOk = ctx.actOk
	local addStep = ctx.addStep
	local call = ctx.call
	local check = ctx.check
	local plotFolder = ctx.plotFolder
	local snap = ctx.snap

	local Progression = require(ctx.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Progression")) :: any
	local Config = GameConfig.Progression
	local Placement = GameConfig.Placement

	type Box = { minX: number, maxX: number, minZ: number, maxZ: number }

	local function keepClear(id: string): Box
		for _, box in Placement.KeepClear do
			if box.id == id then
				return box
			end
		end
		error("KeepClear has no " .. id .. " box", 0)
	end

	local function overlaps(a: Box, b: Box): boolean
		return math.min(a.maxX, b.maxX) - math.max(a.minX, b.minX) > 0
			and math.min(a.maxZ, b.maxZ) - math.max(a.minZ, b.minZ) > 0
	end

	local function within(inner: Box, outer: Box, slack: number): boolean
		return inner.minX >= outer.minX - slack
			and inner.maxX <= outer.maxX + slack
			and inner.minZ >= outer.minZ - slack
			and inner.maxZ <= outer.maxZ + slack
	end

	local function boxText(box: Box): string
		return string.format("x %.2f..%.2f, z %.2f..%.2f", box.minX, box.maxX, box.minZ, box.maxZ)
	end

	-- Lot-frame AABB over the 8 corners of every BasePart of `root` (as step 37), or of `root`.
	local function lotBox(plot: Model, root: Instance): Box
		local center = (plot.PrimaryPart :: BasePart).Position
		local c = { x = center.X, z = center.Z }
		local box = { minX = math.huge, maxX = -math.huge, minZ = math.huge, maxZ = -math.huge }
		local parts: { BasePart } = {}
		if root:IsA("BasePart") then
			table.insert(parts, root)
		end
		for _, descendant in root:GetDescendants() do
			if descendant:IsA("BasePart") then
				table.insert(parts, descendant)
			end
		end
		for _, part in parts do
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local corner = part.CFrame:PointToWorldSpace(Vector3.new(sx, sy, sz) * part.Size / 2)
						local l = NpcPath.fromWorld(c, corner.X, corner.Z)
						box.minX, box.maxX = math.min(box.minX, l.x), math.max(box.maxX, l.x)
						box.minZ, box.maxZ = math.min(box.minZ, l.z), math.max(box.maxZ, l.z)
					end
				end
			end
		end
		check(#parts > 0, root:GetFullName() .. " has no parts")
		return box
	end

	local function summary(): any
		return actOk(S.userId, "Company.GetSummary", {})
	end

	local function setProgression(fields: any)
		call("setProgression", fields)
	end

	-- A response for failure messages: "ok data <data>" or the error code (and previousResult).
	local function responseText(response: any): string
		if type(response) ~= "table" then
			return tostring(response)
		end
		if response.ok == true then
			return "ok data " .. tostring(response.data)
		end
		local text = tostring(response.errorCode)
		if response.previousResult ~= nil then
			text ..= " (previous " .. tostring(response.previousResult) .. ")"
		end
		return text
	end

	local function expectCode(response: any, code: string, context: string)
		check(
			type(response) == "table" and response.ok == false and response.errorCode == code,
			string.format("%s: expected %s, got %s", context, code, responseText(response))
		)
	end

	local function sPlot(): Model
		local plot = plotFolder(S.plotId)
		check(
			plot ~= nil and plot:IsA("Model") and plot.PrimaryPart ~= nil,
			"no plot model for S " .. tostring(S.plotId)
		)
		return plot :: Model
	end

	local function visuals(): Instance
		local folder = sPlot():FindFirstChild("ProgressionVisuals")
		check(folder ~= nil, "S's plot has no ProgressionVisuals")
		return folder :: Instance
	end

	local function managerRow(data: any): any
		for _, role in data.staff.roles do
			if role.id == "LotManager" then
				return role
			end
		end
		error("summary has no LotManager row", 0)
	end

	-- Step 58: lot 1, parking 2 and HQ 2 and 4 bought once each, the Lot Manager once, then the
	-- workshop unlocks; replays and second requests change nothing.
	local function ladderStep(): string
		local before = snap(S.userId)
		local remembered = {
			cash = before.cash,
			reputation = before.reputation,
			lotExpansion = before.progression.lotExpansion,
			parkingTier = before.progression.parkingTier,
			hqLevel = before.progression.hqLevel,
		}
		local rememberedManager = before.staff.LotManager or 0
		local ok, failure = pcall(function()
			setProgression({ cash = 0, reputation = 0, lotExpansion = 0, parkingTier = 1, hqLevel = 1 })
			local lotNext = summary().progression.lotExpansion.next
			check(lotNext ~= nil and lotNext.target == 1, "lot offer target is not 1")
			check(lotNext.cashCost == 1200 and lotNext.ready == false, "lot offer is not $1,200 and not ready")
			expectCode(act(S.userId, "Progression.BuyLotExpansion", { level = 1 }), "InsufficientFunds", "broke lot")
			check(snap(S.userId).cash == 0, "a refused lot purchase changed cash")

			-- Lot 1: a replayed request ID and a second request charge once. The ID is unique per run:
			-- S's save keeps its recent request IDs across Play sessions (CM2-G9a A2).
			setProgression({ cash = 1200 })
			local lotRequestId = "g9_lot_1_" .. HttpService:GenerateGUID(false)
			local first = act(S.userId, "Progression.BuyLotExpansion", { level = 1 }, lotRequestId)
			if not (type(first) == "table" and first.ok == true and first.data == 1) then
				local now = snap(S.userId)
				check(
					false,
					string.format(
						"lot 1 purchase failed: %s; lotExpansion %s, hqLevel %s, cash %s, reputation %s",
						responseText(first),
						tostring(now.progression.lotExpansion),
						tostring(now.progression.hqLevel),
						tostring(now.cash),
						tostring(now.reputation)
					)
				)
			end
			local replay = act(S.userId, "Progression.BuyLotExpansion", { level = 1 }, lotRequestId)
			expectCode(replay, "DuplicateRequest", "replayed lot 1")
			check(
				replay.previousResult == "Success",
				"replayed lot 1: previousResult is " .. tostring(replay.previousResult)
			)
			expectCode(act(S.userId, "Progression.BuyLotExpansion", { level = 1 }), "AlreadyOwned", "second lot 1")
			local afterLot = snap(S.userId)
			check(afterLot.cash == 0 and afterLot.progression.lotExpansion == 1, "lot 1 not charged exactly once")
			check(sPlot():GetAttribute("LotExpansionLevel") == 1, "S's plot LotExpansionLevel is not 1")
			local world = workspace:FindFirstChild("ChristmasMarketWorld")
			local map = world and world:FindFirstChild("Map")
			local reserve = map and map:FindFirstChild("Reserve")
			local rows = reserve and reserve:FindFirstChild(S.plotId)
			check(rows ~= nil and rows:FindFirstChild("Row_1") == nil, "reserve Row_1 of S's plot is still shown")
			local fence = visuals():FindFirstChild("LotFence")
			check(fence ~= nil and fence:FindFirstChild("Back") ~= nil, "LotFence.Back is missing")

			-- Parking tier 2.
			setProgression({ cash = 600 })
			actOk(S.userId, "Progression.BuyParking", { tier = 2 })
			local spaces = 0
			for _, child in visuals():GetChildren() do
				if string.sub(child.Name, 1, 8) == "Parking_" then
					spaces += 1
				end
			end
			check(spaces == 4, spaces .. " Parking_ parts, expected 4")
			expectCode(act(S.userId, "Progression.BuyParking", { tier = 2 }), "AlreadyOwned", "second parking 2")

			-- HQ 2 (Timber Pavilion).
			setProgression({ cash = 2500, reputation = 250 })
			actOk(S.userId, "Progression.BuyHQ", { level = 2 })
			local stand = sPlot():FindFirstChild("StarterSalesTent")
			check(stand ~= nil and stand:GetAttribute("HqLevel") == 2, "StarterSalesTent HqLevel is not 2")
			check(summary().staff.capacity == 3, "staff capacity at HQ 2 is not 3")

			-- HQ 4 (Mountain Chalet), then the Lot Manager and the workshop.
			setProgression({ lotExpansion = 5, hqLevel = 3, cash = 600000, reputation = 3000 })
			actOk(S.userId, "Progression.BuyHQ", { level = 4 })
			local atFour = summary()
			check(managerRow(atFour).locked == false, "the Lot Manager is still locked at HQ 4")
			check(atFour.progression.workshop.unlocked == false, "the workshop unlocked without a Lot Manager")
			setProgression({ cash = 1250000 })
			actOk(S.userId, "Employee.Hire", { employeeId = "LotManager" })
			check(snap(S.userId).cash == 0, "the Lot Manager hire did not cost $1,250,000")
			expectCode(act(S.userId, "Employee.Hire", { employeeId = "LotManager" }), "AlreadyHired", "second hire")
			check(summary().progression.workshop.unlocked == true, "the workshop is still locked")
		end)
		setProgression(remembered)
		call("setStaff", { employeeId = "LotManager", count = rememberedManager })
		check(ok, tostring(failure))
		local restored = snap(S.userId)
		for key, value in remembered do
			local actual = if key == "cash" or key == "reputation" then restored[key] else restored.progression[key]
			check(
				actual == value,
				string.format("restore: %s is %s, expected %s", key, tostring(actual), tostring(value))
			)
		end
		check((restored.staff.LotManager or 0) == rememberedManager, "restore: LotManager differs")
		return "lot 1 once, parking 2 once, HQ 2 and 4, Lot Manager once, workshop unlocked, restored"
	end

	-- Step 59 (G19): every HQ tier stays inside the Stand box and clear of the counter, parking and
	-- the other KeepClear boxes; the fence follows each lot level. Amendment 1: every failure of
	-- HQ 1-4 and lot 0-6 is collected (each level in its own pcall) and reported after the restore.
	local function footprintStep(): string
		local WorldService = require(ctx.Services:WaitForChild("WorldService")) :: any
		local plot = sPlot()
		local standBox = keepClear("Stand")
		local failures: { string } = {}
		local function note(ok: any, message: string): boolean
			if not ok then
				table.insert(failures, message)
				return false
			end
			return true
		end
		local hqOneScale = 1
		local hqFour: Box? = nil
		for level = 1, Config.HQ.maxLevel do
			local ran, err = pcall(function()
				if not note(WorldService.applyHQVisual(S.plotId, level), "applyHQVisual refused level " .. level) then
					return
				end
				local stand = plot:FindFirstChild("StarterSalesTent")
				if not note(stand ~= nil, "no StarterSalesTent at HQ " .. level) then
					return
				end
				local box = lotBox(plot, stand :: Instance)
				note(
					within(box, standBox, 0.05),
					string.format("HQ %d exceeds Stand (%s): %s", level, boxText(standBox), boxText(box))
				)
				if level == 1 then
					local scale = (stand :: Instance):GetAttribute("FitScale")
					note(
						scale == nil or (type(scale) == "number" and scale > 0 and scale <= 1),
						"HQ 1 FitScale is " .. tostring(scale)
					)
					hqOneScale = if type(scale) == "number" then scale else 1
				else
					local footprint = Config.HQ.tiers[level].footprint
					note(
						within(box, footprint, 0.1),
						string.format("HQ %d exceeds its footprint: %s", level, boxText(box))
					)
					note((stand :: Instance):GetAttribute("HqLevel") == level, "HqLevel attribute is not " .. level)
				end
				local counter = plot:FindFirstChild("CheckoutCounter")
				if note(counter ~= nil, "S's plot has no CheckoutCounter") then
					note(
						not overlaps(box, lotBox(plot, counter :: Instance)),
						"HQ " .. level .. " overlaps the counter"
					)
				end
				for _, child in visuals():GetChildren() do
					if string.sub(child.Name, 1, 8) == "Parking_" then
						note(not overlaps(box, lotBox(plot, child)), "HQ " .. level .. " overlaps " .. child.Name)
					end
				end
				for _, id in { "Pickup", "Bays", "Spawn", "Sign", "Checkout" } do
					note(not overlaps(box, keepClear(id)), string.format("HQ %d overlaps KeepClear %s", level, id))
				end
				if level == Config.HQ.maxLevel then
					hqFour = box
				end
			end)
			note(ran, string.format("HQ %d: %s", level, tostring(err)))
		end
		for level = 0, Config.LotExpansion.maxLevel do
			local ran, err = pcall(function()
				if
					not note(
						WorldService.applyLotExpansionVisual(S.plotId, level),
						"applyLotExpansionVisual refused " .. level
					)
				then
					return
				end
				local folder = visuals()
				local pad = folder:FindFirstChild("LotExpansionPad")
				local depth = 54 + Placement.BackDepthPerLevel * level
				if not note(pad ~= nil and pad:IsA("BasePart"), string.format("level %d has no pad", level)) then
					return
				end
				note(
					math.abs((pad :: BasePart).Size.Z - depth) <= 0.01,
					string.format("level %d pad depth is not %d", level, depth)
				)
				local fence = folder:FindFirstChild("LotFence")
				if not note(fence ~= nil, string.format("level %d has no LotFence", level)) then
					return
				end
				note((fence :: Instance):GetAttribute("LotExpansionLevel") == level, "LotFence level is not " .. level)
				for _, expected in Progression.fenceBoxes(level) do
					local side = (fence :: Instance):FindFirstChild(expected.id)
					if not note(side ~= nil, string.format("level %d LotFence.%s is missing", level, expected.id)) then
						continue
					end
					for _, descendant in (side :: Instance):GetDescendants() do
						if descendant:IsA("BasePart") then
							local box = lotBox(plot, descendant)
							note(
								within(box, expected, 0.3),
								string.format("level %d %s.%s at %s", level, expected.id, descendant.Name, boxText(box))
							)
							note(not overlaps(box, standBox), string.format("level %d fence enters Stand", level))
						end
					end
				end
			end)
			note(ran, string.format("lot %d: %s", level, tostring(err)))
		end
		local progression = snap(S.userId).progression
		WorldService.applyHQVisual(S.plotId, progression.hqLevel)
		WorldService.applyLotExpansionVisual(S.plotId, progression.lotExpansion)
		if #failures > 0 then
			local shown: { string } = {}
			for index = 1, math.min(12, #failures) do
				table.insert(shown, failures[index])
			end
			local joined = table.concat(shown, "; ")
			if #failures > 12 then
				joined ..= string.format("; +%d more", #failures - 12)
			end
			check(false, string.format("%d failures: %s", #failures, joined))
		end
		local four = hqFour :: Box
		return string.format(
			"Stand x %.2f..%.2f, z %.2f..%.2f; HQ 1 scale %.3f; HQ 1-4 inside (HQ 4 x %.1f..%.1f, z %.1f..%.1f), levels 0-6 fence ok, restored",
			standBox.minX,
			standBox.maxX,
			standBox.minZ,
			standBox.maxZ,
			hqOneScale,
			four.minX,
			four.maxX,
			four.minZ,
			four.maxZ
		)
	end

	addStep("58", "PROGRESSION_LADDER", { "02" }, ladderStep)
	addStep("59", "HQ_FOOTPRINTS", { "02" }, footprintStep)
end
