--!strict
-- Playtest steps 56-57 (full mode): the map in the world (CM2-10W, docs/plans/CM2-10W.md).
-- Installed by RunPlaytest.execute (CM2-RF) after Steps/Tutorial. Step 56 scans the built
-- world; step 57 moves the reserve rows of the real plot through every lot expansion level.
return function(ctx: any)
	local R = ctx.R
	local ReplicatedStorage = ctx.ReplicatedStorage
	local addStep = ctx.addStep
	local check = ctx.check
	local plotFolder = ctx.plotFolder

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local RunService = game:GetService("RunService")

	local REMOVED_NAMES = {
		SnowGround = true,
		OriginalGrayboxAssets = true,
		ImportedWinterScenery = true,
		ImportedMarketAlley = true,
	}
	local BOARD_KEYS = { "CashEarned", "Reputation", "HoursPlayed", "RobuxSpent" }

	local function mapOf(): Instance
		local world = workspace:FindFirstChild("ChristmasMarketWorld")
		local map = world and world:FindFirstChild("Map")
		check(map ~= nil, "ChristmasMarketWorld.Map is missing")
		return map :: Instance
	end

	-- Parts of the map between y 0.6 and 60 inside a world rectangle.
	local function mapParts(minX: number, maxX: number, minZ: number, maxZ: number): { BasePart }
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { mapOf() }
		local center = Vector3.new((minX + maxX) / 2, 30.3, (minZ + maxZ) / 2)
		return workspace:GetPartBoundsInBox(CFrame.new(center), Vector3.new(maxX - minX, 59.4, maxZ - minZ), params)
	end

	local function describe(parts: { BasePart }): string
		local names: { string } = {}
		for index = 1, math.min(5, #parts) do
			table.insert(names, parts[index]:GetFullName())
		end
		return table.concat(names, ", ")
	end

	-- The lot box at expansion level L in world coordinates: x cx-40..cx+49, depth
	-- -(27 + BackDepthPerLevel * L)..27 (BackDepthPerLevel 8 since CM2-G9a).
	local function lotBox(
		plot: { x: number, z: number, facing: number },
		level: number
	): (number, number, number, number)
		local near = plot.z + plot.facing * 27
		local far = plot.z - plot.facing * (27 + ctx.GameConfig.Placement.BackDepthPerLevel * level)
		return plot.x - 40, plot.x + 49, math.min(near, far), math.max(near, far)
	end

	local function textOf(parent: Instance?, partName: string, guiName: string): string?
		local part = parent and parent:FindFirstChild(partName)
		local gui = part and part:FindFirstChild(guiName)
		local label = gui and gui:FindFirstChild("Text")
		return if label and label:IsA("TextLabel") then label.Text else nil
	end

	addStep("56", "MAP_WORLD", {}, function()
		local MapLayout = require(Shared:WaitForChild("MapLayout")) :: any
		local Localization = require(Shared:WaitForChild("Localization")) :: any
		local map = mapOf()
		local world = map.Parent :: Instance

		-- (a) the legacy world placements are gone
		for _, descendant in world:GetDescendants() do
			check(
				not REMOVED_NAMES[descendant.Name] and string.match(descendant.Name, "^ForestTree%d+$") == nil,
				"legacy placement still present: " .. descendant:GetFullName()
			)
		end

		-- (b) every non-skipped, non-reserve piece is in the world once
		local placements = MapLayout.plan(ctx.ArtLibrary.root(ReplicatedStorage), ctx.ArtLibrary.find)
		local art, fallback, skip, expected = 0, 0, 0, 0
		for _, placement in placements do
			if placement.mode == "Art" then
				art += 1
			elseif placement.mode == "Fallback" then
				fallback += 1
			else
				skip += 1
			end
			if placement.mode ~= "Skip" and placement.piece.group ~= "Reserve" then
				expected += 1
			end
		end
		local reserve = map:FindFirstChild("Reserve")
		local placed = 0
		for _, descendant in map:GetDescendants() do
			if
				descendant:IsA("Model")
				and descendant:GetAttribute("MapPiece") ~= nil
				and not (reserve and descendant:IsDescendantOf(reserve))
			then
				placed += 1
			end
		end
		check(placed == expected, string.format("%d map pieces outside Reserve, plan says %d", placed, expected))

		-- (c) nothing of the map stands in a car lane, truck lane or the active lot
		local boxes: { [string]: any } = {}
		for _, box in MapLayout.keepOut() do
			boxes[box.id] = box
		end
		for index, plot in MapLayout.PLOTS do
			local plotModel = plotFolder(string.format("Plot_%02d", index))
			local level = if plotModel then (plotModel:GetAttribute("LotExpansionLevel") or 0) else 0
			local lotMinX, lotMaxX, lotMinZ, lotMaxZ = lotBox(plot, level)
			local cars, truck = boxes["Cars_" .. index], boxes["Truck_" .. index]
			for name, rect in
				{
					[string.format("Cars_%d", index)] = { cars.minX, cars.maxX, cars.minZ, cars.maxZ },
					[string.format("Truck_%d", index)] = { truck.minX, truck.maxX, truck.minZ, truck.maxZ },
					[string.format("Lot_%d level %d", index, level)] = { lotMinX, lotMaxX, lotMinZ, lotMaxZ },
				}
			do
				local parts = mapParts(rect[1], rect[2], rect[3], rect[4])
				check(#parts == 0, string.format("%s holds %d map parts: %s", name, #parts, describe(parts)))
			end
		end

		-- (d) four invisible boundary walls that collide
		local walls = map:FindFirstChild("Walls")
		local wallCount = 0
		for _, wall in if walls then walls:GetChildren() else {} do
			if string.match(wall.Name, "^BoundaryWall_") and wall:IsA("BasePart") then
				wallCount += 1
				check(wall.Transparency == 1 and wall.CanCollide, wall.Name .. " is visible or does not collide")
			end
		end
		check(wallCount == 4, wallCount .. " boundary walls, expected 4")

		-- (e) streaming
		check(workspace.StreamingEnabled, "workspace.StreamingEnabled is off")

		-- (f) no shadow cost from the many small pieces
		for _, groupName in { "Forest", "Rocks", "Mountains", "Reserve" } do
			local group = map:FindFirstChild(groupName)
			check(group ~= nil, "Map." .. groupName .. " is missing")
			for _, descendant in (group :: Instance):GetDescendants() do
				if descendant:IsA("BasePart") then
					check(not descendant.CastShadow, descendant:GetFullName() .. " casts a shadow")
				end
			end
		end

		-- (g) signs and boards carry their English text
		local street = map:FindFirstChild("Street")
		local square = map:FindFirstChild("Square")
		local welcome = textOf(street and street:FindFirstChild("Sign_Welcome"), "SignText", "SignGui")
		check(welcome == "Christmas Tree Village", "welcome sign says " .. tostring(welcome))
		for index = 1, 6 do
			local sign = street and street:FindFirstChild(string.format("Sign_Deliveries_Plot_%02d", index))
			local text = textOf(sign, "SignText", "SignGui")
			check(text == "DELIVERIES", string.format("delivery sign %d says %s", index, tostring(text)))
		end
		for _, key in BOARD_KEYS do
			local board = square and square:FindFirstChild("Board_" .. key)
			check(board ~= nil and board:FindFirstChild("Screen") ~= nil, "Board_" .. key .. " has no Screen")
			local title = textOf(board, "Title", "TitleGui")
			local expectedTitle = Localization.get("en", "board" .. key)
			check(title == expectedTitle, string.format("Board_%s title is %s", key, tostring(title)))
		end

		-- (h) the server keeps its frame rate with the map built
		local frames = 0
		local started = os.clock()
		local connection = RunService.Heartbeat:Connect(function()
			frames += 1
		end)
		task.wait(5)
		connection:Disconnect()
		local fps = frames / (os.clock() - started)
		check(fps >= 55, string.format("server heartbeat %.1f fps, expected >= 55", fps))

		return string.format(
			"pieces %d (art %d, fallback %d, skip %d), overlaps 0, walls 4, streaming on, server fps %.0f",
			#placements,
			art,
			fallback,
			skip,
			fps
		)
	end)

	addStep("57", "MAP_RESERVE", { "02a" }, function()
		local MapLayout = require(Shared:WaitForChild("MapLayout")) :: any
		local MapWorld = require(ctx.Services:WaitForChild("MapWorld")) :: any
		local WorldService = require(ctx.Services:WaitForChild("WorldService")) :: any
		local plotId: string = R.plotId
		local plotModel = plotFolder(plotId)
		check(plotModel ~= nil, "no plot folder for " .. tostring(plotId))
		local plotIndex = tonumber(string.match(plotId, "%d+")) :: number
		local plot = MapLayout.PLOTS[plotIndex]
		local reserve = mapOf():FindFirstChild("Reserve")
		local rowsFolder = reserve and reserve:FindFirstChild(plotId)
		check(rowsFolder ~= nil, "no reserve folder for " .. plotId)
		local prev = (plotModel :: Instance):GetAttribute("LotExpansionLevel") or 0

		local function expectRows(hidden: number, context: string)
			local folder = rowsFolder :: Instance
			check(
				#folder:GetChildren() == 4 - hidden,
				string.format("%s: %d rows present, expected %d", context, #folder:GetChildren(), 4 - hidden)
			)
			for row = 1, 4 do
				local present = folder:FindFirstChild("Row_" .. row) ~= nil
				check(
					present == (row > hidden),
					string.format("%s: Row_%d present=%s", context, row, tostring(present))
				)
			end
			check(folder:GetAttribute("HiddenRows") == hidden, context .. ": HiddenRows attribute is wrong")
		end

		local hiddenCounts: { number } = {}
		local ok, failure = pcall(function()
			for level = 0, MapLayout.MAX_LEVEL do
				check(MapWorld.applyReserve(plotId, level), "applyReserve refused " .. plotId)
				local hidden = MapLayout.hiddenRowCount(level)
				table.insert(hiddenCounts, hidden)
				expectRows(hidden, "level " .. level)
				local minX, maxX, minZ, maxZ = lotBox(plot, level)
				local parts = mapParts(minX, maxX, minZ, maxZ)
				check(
					#parts == 0,
					string.format("level %d lot box holds %d map parts: %s", level, #parts, describe(parts))
				)
			end
			check(WorldService.applyLotExpansionVisual(plotId, 1), "applyLotExpansionVisual(1) failed")
			expectRows(1, "applyLotExpansionVisual 1")
		end)
		check(WorldService.applyLotExpansionVisual(plotId, prev), "restoring the lot level failed")
		expectRows(MapLayout.hiddenRowCount(prev), "restored level " .. tostring(prev))
		check(ok, tostring(failure))
		return string.format("hidden %s; restored level %s", table.concat(hiddenCounts, ","), tostring(prev))
	end)
end
