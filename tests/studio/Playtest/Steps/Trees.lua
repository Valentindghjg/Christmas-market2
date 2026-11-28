--!strict
-- Playtest step 64 (full mode): tree art in the world (CM2-12W, docs/archive/plans/CM2-12W.md).
-- Installed by RunPlaytest.execute after Steps/Leaderboards. Builds 12 display trees, 12 pickup
-- trees with their cars, 12 roof trees, 12 carried and 12 walking-customer trees of the four
-- species and three sizes on a free plot, and checks art mode, size, ground contact and label
-- height; then the primitive fallback and the forest.
return function(ctx: any)
	local R = ctx.R
	local S = ctx.S
	local addStep = ctx.addStep
	local check = ctx.check
	local poll = ctx.poll
	local plotFolder = ctx.plotFolder
	local ReplicatedStorage = ctx.ReplicatedStorage
	local ArtLibrary = ctx.ArtLibrary

	local TreeArt = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TreeArt") :: ModuleScript) :: any

	local SPECIES = { "DouglasFir", "FrasierFir", "NobleFir", "BlueSpruce" }
	local TOLERANCE = 0.06
	local NPC_HEIGHTS: { [string]: number } = { Small = 0.35, Medium = 0.4, Large = 0.45 }

	addStep("64", "TREE_ART", { "02a" }, function()
		local WorldService = require(ctx.Services:WaitForChild("WorldService")) :: any

		type Combo = { index: number, species: number, size: number, speciesId: string, sizeId: string, path: string }
		local combos: { Combo } = {}
		for speciesIndex, speciesId in SPECIES do
			for sizeIndex, sizeId in TreeArt.SIZES do
				table.insert(combos, {
					index = #combos + 1,
					species = speciesIndex,
					size = sizeIndex,
					speciesId = speciesId,
					sizeId = sizeId,
					path = TreeArt.path(speciesId, sizeId),
				})
			end
		end

		-- Template heights.
		local art = ArtLibrary.root(ReplicatedStorage)
		local heights: { [string]: number } = {}
		for _, combo in combos do
			local template = ArtLibrary.find(art, combo.path)
			check(template ~= nil, "missing art " .. combo.path)
			local _, size = (template :: Model):GetBoundingBox()
			heights[combo.path] = size.Y
		end

		-- A free plot: neither the player's nor the shadow's, with no display and no order objects.
		local plotId: string? = nil
		for index = 1, 6 do
			local candidate = string.format("Plot_%02d", index)
			local model = plotFolder(candidate)
			if candidate ~= R.plotId and candidate ~= S.plotId and model ~= nil then
				local display = model:FindFirstChild("DisplayedTrees")
				local orders = model:FindFirstChild("CustomerOrders")
				if
					(display == nil or #display:GetChildren() == 0)
					and (orders == nil or #orders:GetChildren() == 0)
				then
					plotId = candidate
					break
				end
			end
		end
		check(plotId ~= nil, "no free plot")
		local plotName = plotId :: string
		local plot = plotFolder(plotName) :: Instance
		local ground = plot:FindFirstChild("LotGround") :: BasePart
		check(ground ~= nil and ground:IsA("BasePart"), "no LotGround on " .. plotName)
		local top0 = ground.Position.Y + ground.Size.Y / 2

		-- Model checks ---------------------------------------------------------------------
		local function boxTop(model: Model): number
			local box, size = model:GetBoundingBox()
			return box.Position.Y + size.Y / 2
		end

		local function meshParts(model: Model): { MeshPart }
			local parts: { MeshPart } = {}
			for _, descendant in model:GetDescendants() do
				if descendant:IsA("MeshPart") then
					table.insert(parts, descendant)
				end
			end
			return parts
		end

		-- Bottom of a part's oriented box.
		local function partBottom(part: BasePart): number
			local cf = part.CFrame
			local size = part.Size
			local half = (
				math.abs(cf.RightVector.Y) * size.X
				+ math.abs(cf.UpVector.Y) * size.Y
				+ math.abs(cf.LookVector.Y) * size.Z
			) / 2
			return cf.Position.Y - half
		end

		local function lowest(model: Model): number
			local bottom = math.huge
			for _, part in meshParts(model) do
				bottom = math.min(bottom, partBottom(part))
			end
			return bottom
		end

		local function artMode(model: Model, path: string, label: string)
			check(model:GetAttribute("TreeArtMode") == "Art", label .. " is not art")
			check(
				model:GetAttribute("TreeArtPath") == path,
				label .. " has path " .. tostring(model:GetAttribute("TreeArtPath"))
			)
			check(#meshParts(model) >= 5, label .. " has fewer than 5 MeshParts")
		end

		local function artTree(model: Model, path: string, height: number, label: string)
			artMode(model, path, label)
			local _, size = model:GetBoundingBox()
			check(
				math.abs(size.Y - height) <= TOLERANCE,
				string.format("%s height %.3f, expected %.3f", label, size.Y, height)
			)
		end

		local worstGround = 0
		local minGap = math.huge

		local function grounded(model: Model, label: string)
			local deviation = math.abs(lowest(model) - top0)
			worstGround = math.max(worstGround, deviation)
			check(deviation <= TOLERANCE, string.format("%s foot %.3f off the lot top", label, deviation))
		end

		local function labelAbove(model: Model, minimum: number, label: string)
			local adornee = model.PrimaryPart :: BasePart
			local gui = adornee:FindFirstChild("Label") :: BillboardGui?
			check(gui ~= nil, label .. " has no label")
			local point = adornee.Position.Y + (gui :: BillboardGui).StudsOffsetWorldSpace.Y
			local gap = point - boxTop(model)
			minGap = math.min(minGap, gap)
			check(gap >= minimum, string.format("%s label gap %.2f below %.1f", label, gap, minimum))
		end

		-- Dummy character for the carried trees ---------------------------------------------
		local function makeDummy(): Model
			local dummy = Instance.new("Model")
			dummy.Name = "TreeArtDummy"
			local root = Instance.new("Part")
			root.Name = "HumanoidRootPart"
			root.Size = Vector3.new(2, 2, 1)
			root.Anchored = true
			root.Position = Vector3.new(ground.Position.X, top0 + 3, ground.Position.Z)
			root.Parent = dummy
			dummy.Parent = plot
			return dummy
		end

		local counts = { display = 0, pickup = 0, roof = 0, carried = 0, npc = 0 }

		local function body()
			-- (a) display trees
			local placements: { [string]: any } = {}
			for _, combo in combos do
				placements["TreeArt_" .. combo.index] = {
					speciesId = combo.speciesId,
					sizeId = combo.sizeId,
					transform = { x = -30 + 20 * (combo.species - 1), z = -20 + 8 * (combo.size - 1), rotation = 0 },
				}
			end
			check(WorldService.syncDisplayedTrees(plotName, placements, {}), "syncDisplayedTrees refused " .. plotName)
			local display = plot:FindFirstChild("DisplayedTrees") :: Instance
			for _, combo in combos do
				local model = display:FindFirstChild("DisplayedTree_TreeArt_" .. combo.index) :: Model?
				check(model ~= nil, "no display tree " .. combo.index)
				local tree = model :: Model
				local label = "display tree " .. combo.path
				artTree(tree, combo.path, heights[combo.path], label)
				grounded(tree, label)
				labelAbove(tree, 0.9, label)
				counts.display += 1
			end

			-- (b) pickup trees and their cars
			local orders: { any } = {}
			for _, combo in combos do
				table.insert(orders, {
					orderNumber = 9000 + combo.index,
					speciesId = combo.speciesId,
					sizeId = combo.sizeId,
					heightTenths = 0,
					parkingSpace = (combo.index - 1) % 4 + 1,
					expiresAt = 0,
					carried = false,
				})
			end
			check(WorldService.syncCustomerOrders(plotName, { orders = orders }, nil), "syncCustomerOrders refused (b)")
			local folder = plot:FindFirstChild("CustomerOrders") :: Instance
			for _, combo in combos do
				local model = folder:FindFirstChild("PickupTree_" .. (9000 + combo.index)) :: Model?
				check(model ~= nil, "no pickup tree " .. combo.index)
				local tree = model :: Model
				local label = "pickup tree " .. combo.path
				artTree(tree, combo.path, heights[combo.path], label)
				grounded(tree, label)
				labelAbove(tree, 1.4, label)
				counts.pickup += 1
			end
			task.wait(2.5)

			-- (c) roof trees on the leaving cars
			local numbers: { number } = {}
			for _, combo in combos do
				table.insert(numbers, 9000 + combo.index)
			end
			check(
				WorldService.syncCustomerOrders(plotName, { orders = {}, loadedNumbers = numbers }, nil),
				"syncCustomerOrders refused (c)"
			)
			for _, car in folder:GetChildren() do
				if car.Name == "LeavingCar" then
					local roof = car:FindFirstChild("RoofTree") :: Model?
					check(roof ~= nil, "a leaving car has no roof tree")
					local tree = roof :: Model
					local speciesId, sizeId = car:GetAttribute("TreeSpeciesId"), car:GetAttribute("TreeSizeId")
					local path = TreeArt.path(speciesId, sizeId)
					local label = "roof tree " .. path
					artMode(tree, path, label)
					local scale = tree:GetAttribute("TreeArtScale")
					check(type(scale) == "number", label .. " has no TreeArtScale")
					check(
						math.abs((scale :: number) * heights[path] - 4.025) <= TOLERANCE,
						string.format("%s scaled height %.3f, expected 4.025", label, (scale :: number) * heights[path])
					)
					local clearance = lowest(tree) - WorldService.carCargoTop(car :: Model).Position.Y
					check(
						clearance >= -0.05 and clearance <= 0.3,
						string.format("%s rests %.3f from the cargo anchor", label, clearance)
					)
					counts.roof += 1
				end
			end
			check(counts.roof == 12, counts.roof .. " leaving cars with a roof tree, expected 12")
			check(
				poll(function()
					for _, car in folder:GetChildren() do
						if car.Name == "LeavingCar" then
							return false
						end
					end
					return true
				end, 5),
				"a leaving car stayed on the plot"
			)

			-- (d) carried trees
			local dummy = makeDummy()
			for _, combo in combos do
				WorldService.attachCarriedTree(dummy, 9100 + combo.index, combo.speciesId, combo.sizeId)
				local carried = dummy:FindFirstChild("CarriedTree") :: Model?
				check(carried ~= nil, "no carried tree " .. combo.path)
				local tree = carried :: Model
				local label = "carried tree " .. combo.path
				artMode(tree, combo.path, label)
				local scale = tree:GetAttribute("TreeArtScale") :: number
				check(
					math.abs(scale * heights[combo.path] - 4.6) <= TOLERANCE,
					string.format("%s height %.3f, expected 4.6", label, scale * heights[combo.path])
				)
				for _, descendant in tree:GetDescendants() do
					if descendant:IsA("BasePart") then
						check(
							not descendant.Anchored and not descendant.CanCollide and descendant.Massless,
							label .. " part " .. descendant.Name .. " is anchored, collides or has mass"
						)
					end
				end
				WorldService.detachCarriedTree(dummy)
				counts.carried += 1

				WorldService.attachNpcTree(dummy, combo.sizeId, combo.speciesId)
				local walking = dummy:FindFirstChild("NpcCarriedTree") :: Model?
				check(walking ~= nil, "no walking-customer tree " .. combo.path)
				local npcTree = walking :: Model
				local npcLabel = "npc tree " .. combo.path
				artMode(npcTree, combo.path, npcLabel)
				local npcScale = npcTree:GetAttribute("TreeArtScale") :: number
				local expected = TreeArt.PRIMITIVE_TOP * NPC_HEIGHTS[combo.sizeId]
				check(
					math.abs(npcScale * heights[combo.path] - expected) <= TOLERANCE,
					string.format("%s height %.3f, expected %.3f", npcLabel, npcScale * heights[combo.path], expected)
				)
				WorldService.detachNpcTree(dummy)
				counts.npc += 1
			end

			-- (e) a species without art falls back to the primitive. FrostcrownFir/Small has no art on
			-- purpose (only Trees/FrostcrownFir/Large exists), so WorldService.reportMissing logs the
			-- expected warning "[ART] MissingArtAsset Trees/FrostcrownFir/Small" once during this step.
			WorldService.attachNpcTree(dummy, "Small", "FrostcrownFir")
			local fallback = dummy:FindFirstChild("NpcCarriedTree") :: Model?
			check(fallback ~= nil, "no fallback tree")
			local primitive = fallback :: Model
			check(primitive:GetAttribute("TreeArtMode") == "Primitive", "fallback tree is not primitive")
			check(
				primitive:GetAttribute("TreeArtPath") == "Trees/FrostcrownFir/Small",
				"fallback path is " .. tostring(primitive:GetAttribute("TreeArtPath"))
			)
			for _, name in { "Trunk", "Needles1", "Needles2", "Needles3" } do
				check(primitive:FindFirstChild(name) ~= nil, "fallback tree has no " .. name)
			end
			WorldService.detachNpcTree(dummy)
		end

		local ok, failure = pcall(body)
		WorldService.syncDisplayedTrees(plotName, {}, {})
		local leftover = plot:FindFirstChild("CustomerOrders")
		if leftover then
			leftover:Destroy()
		end
		local dummy = plot:FindFirstChild("TreeArtDummy")
		if dummy then
			dummy:Destroy()
		end
		check(ok, tostring(failure))

		-- (f) the forest and the reserve rows use art
		local world = workspace:FindFirstChild("ChristmasMarketWorld")
		local map = world and world:FindFirstChild("Map")
		check(map ~= nil, "ChristmasMarketWorld.Map is missing")
		local forestFallback = 0
		for _, groupName in { "Forest", "Reserve" } do
			local group = (map :: Instance):FindFirstChild(groupName)
			check(group ~= nil, "Map." .. groupName .. " is missing")
			for _, descendant in (group :: Instance):GetDescendants() do
				if descendant:IsA("Model") and descendant:GetAttribute("MapFallback") == true then
					forestFallback += 1
				end
			end
		end
		check(forestFallback == 0, forestFallback .. " forest or reserve models are fallbacks")

		return string.format(
			"display %d, pickup %d, roof %d, carried %d, npc %d art; fallback primitive ok; forest fallback 0; worst ground %.2f; min label gap %.1f",
			counts.display,
			counts.pickup,
			counts.roof,
			counts.carried,
			counts.npc,
			worstGround,
			minGap
		)
	end)
end
