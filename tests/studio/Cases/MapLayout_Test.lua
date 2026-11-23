-- Map layout contract (CM2-10W): clearance, reserve, budget, hide levels, zones, determinism and
-- the art plan. Pure data; the plan tests use fake nodes, so this runs in Studio and headless.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local ArtLibrary = require(Shared:WaitForChild("ArtLibrary"))
	local MapLayout = require(Shared:WaitForChild("MapLayout"))
	local expect = t.expect

	-- The contract's 298 models left out the 4 benches; its triangle and MeshPart totals include them.
	local MAX_TRIANGLES, MAX_MESHPARTS, MAX_MODELS = 149700, 1051, 302

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
		expect.equal(meshParts, 1051)
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
		expect.equal(size(fallback), 7)
		expect.equal(size(skip), 6)
		expect.equal(#missing, 13)
		local seen = {}
		for _, entry in ipairs(missing) do
			expect.equal(entry.code, "MissingArtAsset")
			expect.falsy(seen[entry.path])
			seen[entry.path] = true
		end

		local partial, partialMissing = MapLayout.plan(fakeRoot({ "Environment/ForestFir" }), ArtLibrary.find)
		expect.equal(#partialMissing, 12)
		for _, placement in ipairs(partial) do
			if placement.piece.artPath == "Environment/ForestFir" then
				expect.equal(placement.mode, "Art")
			else
				expect.truthy(placement.mode ~= "Art")
			end
		end
	end)
end
