-- Map layout contract (CM2-10W): clearance, reserve, budget, hide levels, zones, determinism and
-- the art plan. Pure data; the plan tests use fake nodes, so this runs in Studio and headless.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local ArtLibrary = require(Shared:WaitForChild("ArtLibrary"))
	local GameConfig = require(Shared:WaitForChild("GameConfig"))
	local Localization = require(Shared:WaitForChild("Localization"))
	local MapLayout = require(Shared:WaitForChild("MapLayout"))
	local expect = t.expect

	-- The contract's 298 models left out the 4 benches; its triangle and MeshPart totals include them.
	-- CM2-10DW adds the 110 dressing pieces (302 -> 412 models, 149700 -> 179700, 1051 -> 1351 budget);
	-- CM2-10IW adds the 77 infrastructure pieces (412 -> 489 models, 179260 -> 203580 triangles, 1335 -> 1572 MeshParts).
	local MAX_TRIANGLES, MAX_MESHPARTS, MAX_MODELS = 219260, 1635, 532

	local function inside(box, zone)
		return box.minX >= zone.minX - 1e-9
			and box.maxX <= zone.maxX + 1e-9
			and box.minZ >= zone.minZ - 1e-9
			and box.maxZ <= zone.maxZ + 1e-9
	end

	-- A fake ArtAssets tree like ArtLibrary_Test's: every named path holds a Model.
	local function node(className)
		local value = { children = {} }
		function value:FindFirstChild(name)
			return self.children[name]
		end
		function value:IsA(name)
			return name == className
		end
		function value:GetAttribute()
			return nil
		end
		return value
	end

	local function fakeRoot(paths)
		local root = node("Folder")
		for _, path in ipairs(paths) do
			local current = root
			local segments = {}
			for segment in string.gmatch(path, "[^/]+") do
				table.insert(segments, segment)
			end
			for index, segment in ipairs(segments) do
				if current.children[segment] == nil then
					current.children[segment] = node(index == #segments and "Model" or "Folder")
				end
				current = current.children[segment]
			end
		end
		return root
	end

	local function allPaths()
		local paths = {}
		for path in pairs(MapLayout.ART) do
			table.insert(paths, path)
		end
		table.sort(paths)
		return paths
	end

	t.test("keeps every map piece 3 studs from every keep-out box on all 6 plots", function()
		local boxes = MapLayout.keepOut()
		expect.equal(#boxes, 19)
		for _, piece in ipairs(MapLayout.pieces()) do
			local footprint = MapLayout.footprint(piece)
			for _, box in ipairs(boxes) do
				local exempt = (piece.id == "CoveredBridge" and box.id == "Road")
					or (piece.group == "Reserve" and box.id == "Lot_" .. tostring(piece.plot))
				if not exempt then
					local distance = MapLayout.distance(footprint, box)
					assert(distance >= 3 - 1e-9, string.format("%s is %.3f from %s", piece.id, distance, box.id))
				end
			end
		end
	end)

	-- CM2-LOTLAY: the Cars box is the parking apron outside the front fence (plots stand at |z| 75).
	t.test("the Cars keep-out box is the parking apron", function()
		local apron = GameConfig.Placement.CarPark.Apron
		local plot = MapLayout.PLOTS[2]
		local cars
		for _, box in ipairs(MapLayout.keepOut()) do
			if box.id == "Cars_2" then
				cars = box
			end
		end
		expect.truthy(cars ~= nil)
		expect.equal(cars.minX, plot.x + apron.minX)
		expect.equal(cars.maxX, plot.x + apron.maxX)
		expect.equal(cars.minZ, -48)
		expect.equal(cars.maxZ, -16)
	end)

	t.test("keeps the 120 reserve firs inside their plot's reserve", function()
		local perPlot = {}
		for _, piece in ipairs(MapLayout.pieces()) do
			if piece.group == "Reserve" then
				expect.equal(piece.artPath, "Environment/ForestFir")
				local plot = MapLayout.PLOTS[piece.plot]
				perPlot[piece.plot] = (perPlot[piece.plot] or 0) + 1
				local footprint = MapLayout.footprint(piece)
				assert(footprint.minX >= plot.x - 40 and footprint.maxX <= plot.x + 40, piece.id .. " outside x")
				local near = plot.facing * (footprint.minZ - plot.z)
				local far = plot.facing * (footprint.maxZ - plot.z)
				assert(math.min(near, far) >= -75 and math.max(near, far) <= -30, piece.id .. " outside depth")
			end
		end
		for index = 1, 6 do
			expect.equal(perPlot[index], 20)
		end
	end)

	t.test("places the contract counts within the map budget", function()
		local counts = {}
		local pieces = MapLayout.pieces()
		for _, piece in ipairs(pieces) do
			counts[piece.artPath] = (counts[piece.artPath] or 0) + 1
		end
		for path, count in pairs(MapLayout.COUNTS) do
			expect.equal(counts[path], count)
		end
		for path in pairs(counts) do
			expect.truthy(MapLayout.COUNTS[path] ~= nil)
		end
		local triangles, meshParts, models = MapLayout.budget(pieces)
		expect.equal(models, #pieces)
		expect.truthy(triangles <= MAX_TRIANGLES)
		expect.truthy(meshParts <= MAX_MESHPARTS)
		expect.truthy(models <= MAX_MODELS)
		expect.equal(meshParts, 1572)
		expect.equal(models, 489)
		expect.equal(triangles, 203580)
	end)

	t.test("hides reserve rows only where the lot reaches them, levels 0-6", function()
		local levels = {}
		for row = 1, 4 do
			table.insert(levels, MapLayout.hideLevel(row))
		end
		expect.equal(table.concat(levels, ","), "1,2,3,4")
		local hidden = {}
		for level = 0, MapLayout.MAX_LEVEL do
			table.insert(hidden, MapLayout.hiddenRowCount(level))
		end
		expect.equal(table.concat(hidden, ","), "0,1,2,3,4,4,4")
		expect.equal(MapLayout.hiddenRowCount(2.9), 2)
		for _, piece in ipairs(MapLayout.pieces()) do
			if piece.group == "Reserve" then
				local plot = MapLayout.PLOTS[piece.plot]
				local footprint = MapLayout.footprint(piece)
				local nearEdge =
					math.max(plot.facing * (footprint.minZ - plot.z), plot.facing * (footprint.maxZ - plot.z))
				for level = 0, MapLayout.MAX_LEVEL do
					if (piece.row :: number) > MapLayout.hiddenRowCount(level) then
						assert(nearEdge <= -(27 + 8 * level) - 3 + 1e-9, piece.id .. " too close at level " .. level)
					end
				end
			end
		end
	end)

	t.test("keeps forest pieces inside their zones and apart", function()
		local solid = {}
		for _, piece in ipairs(MapLayout.pieces()) do
			local footprint = MapLayout.footprint(piece)
			local zones = nil
			if string.find(piece.id, "^ForestA_") or string.find(piece.id, "^ForestB_") or piece.group == "Rocks" then
				zones = MapLayout.ZONES
			elseif string.find(piece.id, "^GapFir_") then
				zones = MapLayout.GAP_ZONES
			end
			if zones then
				local found = false
				for _, zone in ipairs(zones) do
					found = found or inside(footprint, zone)
				end
				assert(found, piece.id .. " is outside every zone")
			end
			if piece.group == "Forest" or piece.group == "Rocks" or piece.group == "Reserve" then
				table.insert(solid, footprint)
			end
		end
		expect.equal(#solid, 120 + 32 + 40 + 30 + 24)
		-- Strict for every pair, reserve included: positive penetration on both axes is an overlap.
		for first = 1, #solid do
			for second = first + 1, #solid do
				local a, b = solid[first], solid[second]
				local depth = math.min(
					math.min(a.maxX, b.maxX) - math.max(a.minX, b.minX),
					math.min(a.maxZ, b.maxZ) - math.max(a.minZ, b.minZ)
				)
				assert(depth <= 1e-9, string.format("%s overlaps %s by %.2f", a.id, b.id, depth))
			end
		end
	end)

	t.test("generates the same layout on every call", function()
		local first = MapLayout.generate()
		local second = MapLayout.generate()
		expect.equal(#first, #second)
		for index, piece in ipairs(first) do
			local other = second[index]
			expect.equal(piece.id, other.id)
			expect.equal(piece.x, other.x)
			expect.equal(piece.z, other.z)
			expect.equal(piece.yaw, other.yaw)
			expect.equal(piece.scale, other.scale)
		end
		expect.equal(#MapLayout.pieces(), #first)
	end)

	t.test("plan uses art when the library has it", function()
		local root = fakeRoot(allPaths())
		local placements, missing = MapLayout.plan(root, ArtLibrary.find)
		expect.equal(#placements, #MapLayout.pieces())
		expect.equal(#missing, 0)
		for _, placement in ipairs(placements) do
			expect.equal(placement.mode, "Art")
			expect.truthy(placement.template ~= nil)
		end
	end)

	t.test("plan falls back or skips missing art and reports each path once", function()
		local placements, missing = MapLayout.plan(nil, ArtLibrary.find)
		local fallback, skip = {}, {}
		for _, placement in ipairs(placements) do
			local path = placement.piece.artPath
			if placement.mode == "Fallback" then
				fallback[path] = true
			elseif placement.mode == "Skip" then
				skip[path] = true
			else
				error("unexpected mode " .. placement.mode)
			end
		end
		local function size(set)
			local count = 0
			for _ in pairs(set) do
				count += 1
			end
			return count
		end
		expect.equal(size(fallback), 15)
		expect.equal(size(skip), 17)
		expect.equal(#missing, 32)
		local seen = {}
		for _, entry in ipairs(missing) do
			expect.equal(entry.code, "MissingArtAsset")
			expect.falsy(seen[entry.path])
			seen[entry.path] = true
		end

		local partial, partialMissing = MapLayout.plan(fakeRoot({ "Environment/ForestFir" }), ArtLibrary.find)
		expect.equal(#partialMissing, 31)
		for _, placement in ipairs(partial) do
			if placement.piece.artPath == "Environment/ForestFir" then
				expect.equal(placement.mode, "Art")
			else
				expect.truthy(placement.mode ~= "Art")
			end
		end
	end)

	t.test("places the 110 dressing pieces from the contract (CM2-10DW)", function()
		local byId = {}
		local lamps = 0
		for _, piece in ipairs(MapLayout.pieces()) do
			if piece.group == "Dressing" then
				expect.falsy(byId[piece.id])
				byId[piece.id] = piece
				if piece.artPath == "Props/LampPost" then
					lamps += 1
				end
			end
		end
		expect.equal(#MapLayout.DRESSING, 55)
		local total = 0
		for _ in pairs(byId) do
			total += 1
		end
		expect.equal(total, 110)
		expect.equal(lamps, 10)
		for nn = 1, 55 do
			local north = byId[string.format("Dress_%02d_N", nn)]
			local south = byId[string.format("Dress_%02d_S", nn)]
			expect.truthy(north ~= nil and south ~= nil)
			expect.equal(south.artPath, north.artPath)
			expect.equal(south.x, north.x)
			expect.equal(south.z, -north.z)
			expect.equal(south.yaw, (north.yaw + 180) % 360)
		end

		local new = {
			"Props/SnowPileA",
			"Props/SnowPileB",
			"Props/Snowman",
			"Props/Sled",
			"Props/WoodStack",
			"Props/FirBarrel",
		}
		local isNew = {}
		for _, path in ipairs(new) do
			isNew[path] = true
		end
		local paths = {}
		for _, path in ipairs(allPaths()) do
			if not isNew[path] then
				table.insert(paths, path)
			end
		end
		local placements = MapLayout.plan(fakeRoot(paths), ArtLibrary.find)
		local fallback, skip = 0, 0
		for _, placement in ipairs(placements) do
			if placement.piece.group == "Dressing" then
				local path = placement.piece.artPath
				if isNew[path] then
					local wantsFallback = path == "Props/SnowPileA"
						or path == "Props/SnowPileB"
						or path == "Props/FirBarrel"
					expect.equal(placement.mode, wantsFallback and "Fallback" or "Skip")
					if wantsFallback then
						fallback += 1
					else
						skip += 1
					end
				else
					expect.equal(placement.mode, "Art")
				end
			end
		end
		expect.equal(fallback, 62)
		expect.equal(skip, 20)
	end)

	t.test("places the 77 infrastructure pieces from the contract (CM2-10IW)", function()
		expect.equal(#MapLayout.INFRA_PAIRS, 36)
		expect.equal(#MapLayout.INFRA_SINGLES, 5)
		local byId = {}
		local total = 0
		for _, piece in ipairs(MapLayout.pieces()) do
			if piece.group == "Infrastructure" then
				expect.falsy(byId[piece.id])
				byId[piece.id] = piece
				total += 1
			end
		end
		expect.equal(total, 77)
		for nn = 1, 36 do
			local north = byId[string.format("Infra_%02d_N", nn)]
			local south = byId[string.format("Infra_%02d_S", nn)]
			expect.truthy(north ~= nil and south ~= nil)
			expect.equal(south.artPath, north.artPath)
			expect.equal(south.x, north.x)
			expect.equal(south.z, -north.z)
			expect.equal(south.yaw, (north.yaw + 180) % 360)
		end
		for nn = 37, 41 do
			expect.truthy(byId[string.format("Infra_%02d", nn)] ~= nil)
		end

		-- Footprints stay >= 1.0 from the sidewalks, approach road, square and the stream channel.
		local near = {}
		for _, top in ipairs(MapLayout.surfaceTops()) do
			if top.id == "Sidewalk_N" or top.id == "Sidewalk_S" or top.id == "ApproachRoad" or top.id == "Square" then
				table.insert(near, top)
			end
		end
		expect.equal(#near, 4)
		table.insert(near, { id = "ChannelN", minX = -236, maxX = -200, minZ = 0, maxZ = 380 })
		table.insert(near, { id = "ChannelS", minX = -236, maxX = -200, minZ = -380, maxZ = 0 })
		for _, piece in pairs(byId) do
			local footprint = MapLayout.footprint(piece)
			for _, box in ipairs(near) do
				local distance = MapLayout.distance(footprint, box)
				assert(distance >= 1.0 - 1e-9, string.format("%s is %.3f from %s", piece.id, distance, box.id))
			end
		end

		-- Signs: RS says the limit on both; RD reads Bridge on top on the north board, Village Square on the south.
		local signs = 0
		for id, piece in pairs(byId) do
			if piece.signs ~= nil then
				signs += 1
				for _, sign in ipairs(piece.signs) do
					expect.truthy(Localization.Strings.en[sign.textKey] ~= nil)
				end
			end
			if piece.artPath == "Props/RoadSignSpeed" then
				expect.equal(#piece.signs, 1)
				expect.equal(piece.signs[1].attachment, "SignFront")
				expect.equal(piece.signs[1].textKey, "mapSignSpeed")
			elseif piece.artPath == "Props/RoadSignDirection" then
				local top = if string.sub(id, -2) == "_N" then "mapSignBridge" else "mapSignVillageSquare"
				local bottom = if string.sub(id, -2) == "_N" then "mapSignVillageSquare" else "mapSignBridge"
				expect.equal(#piece.signs, 2)
				expect.equal(piece.signs[1].attachment, "SignTop")
				expect.equal(piece.signs[1].textKey, top)
				expect.equal(piece.signs[2].attachment, "SignBottom")
				expect.equal(piece.signs[2].textKey, bottom)
			else
				expect.falsy(piece.signs)
			end
		end
		expect.equal(signs, 4)

		-- A library without the 13 paths: UP, GR, ST, UB fall back (52), the other 25 are skipped.
		local isInfra = {}
		for _, path in pairs(MapLayout.INFRA_CODES) do
			isInfra[path] = true
		end
		local paths = {}
		for _, path in ipairs(allPaths()) do
			if not isInfra[path] then
				table.insert(paths, path)
			end
		end
		local placements = MapLayout.plan(fakeRoot(paths), ArtLibrary.find)
		local fallback, skip = 0, 0
		for _, placement in ipairs(placements) do
			if placement.piece.group == "Infrastructure" then
				if placement.mode == "Fallback" then
					fallback += 1
				elseif placement.mode == "Skip" then
					skip += 1
				else
					error("unexpected mode " .. placement.mode)
				end
			end
		end
		expect.equal(fallback, 52)
		expect.equal(skip, 25)
	end)

	t.test("wires neighbouring poles on each side (CM2-10IW)", function()
		local byId = {}
		for _, piece in ipairs(MapLayout.pieces()) do
			byId[piece.id] = piece
		end
		local wires = MapLayout.wires()
		expect.equal(#wires, 36)
		local seen = {}
		for _, wire in ipairs(wires) do
			local from, to = byId[wire.from], byId[wire.to]
			expect.truthy(from ~= nil and to ~= nil)
			expect.equal(from.artPath, "Props/UtilityPole")
			expect.equal(to.artPath, "Props/UtilityPole")
			local fromNn, fromSide = string.match(wire.from, "^Infra_(%d+)_([NS])$")
			local toNn, toSide = string.match(wire.to, "^Infra_(%d+)_([NS])$")
			expect.equal(fromSide, toSide)
			expect.equal(tonumber(toNn), tonumber(fromNn) + 1)
			local key = wire.from .. "/" .. wire.attachment
			expect.falsy(seen[key])
			seen[key] = true
		end
	end)

	-- CM2-FLICK: coplanar flat surfaces z-fight.
	local function flat(id, minX, maxX, minZ, maxZ, top)
		return { id = id, minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ, top = top }
	end
	local TOLERANCE, MIN_AREA = MapLayout.COPLANAR_TOLERANCE, MapLayout.COPLANAR_MIN_AREA

	-- Every flat surface of the built world: MapLayout.surfaces() plus the grounds WorldService.build adds.
	local function worldTops()
		local tops = MapLayout.surfaceTops()
		-- Values from WorldService.build: MainRoad 380 x 0.3 x 32 at y 0.2; LotGround 80 x 0.5 x 54 at y 0.3.
		table.insert(tops, flat("MainRoad", -190, 190, -16, 16, 0.35))
		for index = 1, 6 do
			local side = index <= 3 and -1 or 1
			local cx = (((index - 1) % 3) - 1) * 110
			local cz = side * 75
			table.insert(tops, flat("LotGround_" .. index, cx - 40, cx + 40, cz - 27, cz + 27, 0.55))
		end
		return tops
	end

	t.test("coplanarPairs reports only overlaps within the tolerance", function()
		local a = flat("A", 0, 10, 0, 10, 0)
		local b = flat("B", 5, 15, 5, 15, 0.01)
		local pairsFound = MapLayout.coplanarPairs({ a, b }, TOLERANCE, MIN_AREA)
		expect.equal(#pairsFound, 1)
		expect.equal(pairsFound[1].a, "A")
		expect.equal(pairsFound[1].b, "B")
		expect.equal(pairsFound[1].area, 25)
		expect.equal(math.abs(pairsFound[1].gap - 0.01) < 1e-9, true)

		local c = flat("C", 0, 10, 0, 10, 0.03)
		expect.equal(#MapLayout.coplanarPairs({ a, c }, TOLERANCE, MIN_AREA), 0)
		local d = flat("D", 10, 20, 0, 10, 0)
		expect.equal(#MapLayout.coplanarPairs({ a, d }, TOLERANCE, MIN_AREA), 0)
		local e = flat("E", 9.9, 10.9, 9.9, 10.9, 0)
		expect.equal(#MapLayout.coplanarPairs({ a, e }, TOLERANCE, MIN_AREA), 0)

		local input = { b, a }
		MapLayout.coplanarPairs(input, TOLERANCE, MIN_AREA)
		expect.equal(input[1].id, "B")
		expect.equal(input[2].id, "A")
	end)

	t.test("surfaceTops lists every Part surface", function()
		local tops = MapLayout.surfaceTops()
		expect.equal(#tops, 13)
		local byId = {}
		for _, entry in ipairs(tops) do
			byId[entry.id] = entry
		end
		expect.equal(math.abs(byId.Ground_East.top) < 1e-9, true)
		expect.falsy(byId.MainRoad)
		expect.equal(math.abs(byId.Sidewalk_N.top - 0.45) < 1e-9, true)
		expect.equal(math.abs(byId.TruckLane_Plot_01.top - 0.05) < 1e-9, true)
		expect.falsy(byId.Bank_West)
	end)

	t.test("map surfaces and world grounds have no coplanar pair", function()
		expect.equal(#MapLayout.coplanarPairs(worldTops(), TOLERANCE, MIN_AREA), 0)
	end)

	t.test("the template Baseplate would z-fight with the snow ground", function()
		local tops = worldTops()
		table.insert(tops, flat("Baseplate", -1024, 1024, -1024, 1024, 0))
		local found = {}
		for _, pair in ipairs(MapLayout.coplanarPairs(tops, TOLERANCE, MIN_AREA)) do
			if pair.a == "Baseplate" then
				found[pair.b .. "/Baseplate"] = true
			elseif pair.b == "Baseplate" then
				found[pair.a .. "/Baseplate"] = true
			end
		end
		expect.truthy(found["Ground_West/Baseplate"])
		expect.truthy(found["Ground_East/Baseplate"])
	end)
end
