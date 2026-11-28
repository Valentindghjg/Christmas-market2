-- Lot and HQ art in the world: paths, yaws, fence layout and bundle maths (CM2-13W). Uses fake
-- nodes, so it runs in Studio and headless.
return function(t)
	local Shared = game:GetService("ReplicatedStorage").Shared
	local ArtLibrary = require(Shared.ArtLibrary)
	local GameConfig = require(Shared.GameConfig)
	local LotArt = require(Shared.LotArt)
	local MapLayout = require(Shared.MapLayout)
	local Progression = require(Shared.Progression)
	local NpcPath = require(Shared.NpcPath)
	local Stocking = require(Shared.Stocking)
	local expect = t.expect

	local function near(actual, expected, tolerance)
		expect.truthy(math.abs(actual - expected) < (tolerance or 1e-9))
	end

	-- A fake instance with the members ArtLibrary.find reads.
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

	local function keepClear(id)
		for _, box in ipairs(GameConfig.Placement.KeepClear) do
			if box.id == id then
				return box
			end
		end
		error("KeepClear has no " .. id)
	end

	local function overlaps(a, b)
		return a.minX < b.maxX and b.minX < a.maxX and a.minZ < b.maxZ and b.minZ < a.maxZ
	end

	t.test("maps HQ levels to the CM2-13a building paths", function()
		local ids = { "SalesTent", "TimberPavilion", "AlpineHut", "MountainChalet" }
		for level, id in ipairs(ids) do
			expect.equal(LotArt.hqPath(level), "Buildings/" .. id)
			expect.truthy(ArtLibrary.isValidPath(LotArt.hqPath(level)))
			local cx, cz = LotArt.hqCentre(level)
			near(cx, -8)
			near(cz, -4)
		end
		expect.equal(LotArt.hqLevel(0), 1)
		expect.equal(LotArt.hqLevel(9), 4)
		expect.equal(LotArt.hqLevel(0 / 0), 1)
		expect.equal(LotArt.hqLevel("x"), 1)
		expect.equal(LotArt.hqLevel(2.7), 2)
	end)

	t.test("turns fronts toward the road on every plot", function()
		expect.equal(#MapLayout.PLOTS, 6)
		for _, p in ipairs(MapLayout.PLOTS) do
			expect.equal(Stocking.facing(p.z), p.facing)
			local yaw = LotArt.roadYaw(p.facing)
			expect.truthy(math.abs(math.sin(yaw)) < 1e-9)
			-- CFrame.Angles(0, yaw, 0).LookVector.Z = -cos(yaw): model -Z points at the road.
			local lookZ = -math.cos(yaw)
			expect.truthy(lookZ * -p.z > 0)
		end
		expect.equal(LotArt.roadYaw(1), math.pi)
		expect.equal(LotArt.roadYaw(-1), 0)
	end)

	t.test("puts the counter's queue and cashier points on the config path", function()
		local queue, staff = NpcPath.queueSlot(1), NpcPath.staffPoint()
		near(LotArt.COUNTER.x, -14)
		near(LotArt.COUNTER.z, 16.5)
		for _, facing in ipairs({ 1, -1 }) do
			local yaw = LotArt.roadYaw(facing)
			local function lotPoint(modelX, modelZ)
				local wx = modelX * math.cos(yaw) + modelZ * math.sin(yaw)
				local wz = -modelX * math.sin(yaw) + modelZ * math.cos(yaw)
				return wx + LotArt.COUNTER.x, wz * facing + LotArt.COUNTER.z
			end
			local qx, qz = lotPoint(0, -3)
			near(qx, queue.x)
			near(qz, queue.z)
			local sx, sz = lotPoint(0, 2.5)
			near(sx, staff.x)
			near(sz, staff.z)
		end
	end)

	t.test("yaws fence segments along their run", function()
		for _, facing in ipairs({ 1, -1 }) do
			for _, dir in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
				local yaw = LotArt.runYaw(dir[1], dir[2], facing)
				-- Model -X after CFrame.Angles(0, yaw, 0) points along (-cos yaw, sin yaw).
				near(-math.cos(yaw), dir[1])
				near(math.sin(yaw), dir[2] * facing)
			end
		end
	end)

	t.test("lays the lot fence inside the fence boxes at every level", function()
		expect.equal(GameConfig.Placement.BackDepthPerLevel, LotArt.RAIL_LENGTH)
		for level = 0, GameConfig.Progression.LotExpansion.maxLevel do
			local pieces = LotArt.fenceSegments(level)
			expect.equal(#pieces, 27 + 2 * level)
			local boxes = {}
			for _, box in ipairs(Progression.fenceBoxes(level)) do
				boxes[box.id] = box
			end
			local posts = 0
			local points = {}
			for _, piece in ipairs(pieces) do
				local box = boxes[piece.box]
				expect.truthy(box ~= nil)
				local own = LotArt.pieceBox(piece)
				expect.truthy(own.minX >= box.minX - 0.35 and own.maxX <= box.maxX + 0.35)
				expect.truthy(own.minZ >= box.minZ - 0.35 and own.maxZ <= box.maxZ + 0.35)
				if piece.kind == "Post" then
					posts += 1
					table.insert(points, { piece.x, piece.z })
				else
					table.insert(points, { piece.x - 4 * piece.dirX, piece.z - 4 * piece.dirZ })
				end
			end
			expect.equal(posts, 2)
			for i = 1, #points do
				for j = i + 1, #points do
					local dx, dz = points[i][1] - points[j][1], points[i][2] - points[j][2]
					expect.truthy(math.sqrt(dx * dx + dz * dz) >= 0.6)
				end
			end
		end
		expect.equal(#LotArt.fenceSegments(0 / 0), 27)
		expect.equal(#LotArt.fenceSegments("x"), 27)
	end)

	t.test("leaves a centred gate gap and keeps the right side open", function()
		local lane = { minX = 43, maxX = 49, minZ = -150, maxZ = 66 }
		local opening = { minX = -8.15, maxX = 8.15, minZ = 26, maxZ = 30 }
		for level = 0, GameConfig.Progression.LotExpansion.maxLevel do
			local boxes = {}
			for _, box in ipairs(Progression.fenceBoxes(level)) do
				boxes[box.id] = box
			end
			near(boxes.FrontLeft.maxX, -9.65)
			near(boxes.FrontRight.minX, 9.65)
			near(boxes.FrontLeft.maxX, -boxes.FrontRight.minX)
			expect.equal(boxes.Left ~= nil, true)
			expect.equal(boxes.Right ~= nil, level >= 1)
			-- Amendment 1: the front runs and boxes touch the gate posts but never overlap them.
			local function overlapArea(a, b)
				local width = math.min(a.maxX, b.maxX) - math.max(a.minX, b.minX)
				local depth = math.min(a.maxZ, b.maxZ) - math.max(a.minZ, b.minZ)
				return math.max(0, width) * math.max(0, depth)
			end
			for _, post in ipairs(LotArt.gatePostBoxes()) do
				expect.truthy(overlapArea(boxes.FrontLeft, post) <= 1e-9)
				expect.truthy(overlapArea(boxes.FrontRight, post) <= 1e-9)
				for _, piece in ipairs(LotArt.fenceSegments(level)) do
					if piece.box == "FrontLeft" or piece.box == "FrontRight" then
						expect.truthy(overlapArea(LotArt.pieceBox(piece), post) <= 1e-9)
					end
				end
			end
			for _, piece in ipairs(LotArt.fenceSegments(level)) do
				local box = LotArt.pieceBox(piece)
				expect.falsy(overlaps(box, opening))
				expect.falsy(overlaps(box, lane))
				expect.falsy(overlaps(box, keepClear("Bays")))
				-- nothing stands on the right edge across the lot's depth (the delivery side)
				expect.falsy(box.maxX > 40.2 and box.maxZ > -27 + 1e-6 and box.minZ < 27)
			end
		end
	end)

	t.test("keeps decorative fences within their radius and out of the keep-clear boxes", function()
		local radius = GameConfig.Placement.DecorFenceRadius
		for _, fence in ipairs(GameConfig.Placement.DecorFences) do
			for _, piece in ipairs(LotArt.decorPieces(fence.x, fence.z)) do
				local box = LotArt.pieceBox(piece)
				for _, x in ipairs({ box.minX, box.maxX }) do
					for _, z in ipairs({ box.minZ, box.maxZ }) do
						local dx, dz = x - fence.x, z - fence.z
						expect.truthy(math.sqrt(dx * dx + dz * dz) <= radius)
					end
				end
				for _, id in ipairs({ "Sign", "Checkout", "Gate", "Spawn" }) do
					expect.falsy(overlaps(box, keepClear(id)))
				end
			end
		end
	end)

	t.test("stacks bundles three per row on the deck", function()
		local rises = { 0, 0, 0, 1, 1, 1, 2, 2, 2 }
		local offsets = { -1.2, 0, 1.2 }
		for k = 0, 8 do
			local rise, dz = LotArt.bundleOffset(k)
			near(rise, rises[k + 1])
			near(dz, offsets[k % 3 + 1])
		end
	end)

	t.test("chooses art when present and the primitive otherwise", function()
		local root = node("Folder")
		local props = node("Folder")
		root.children.Props = props
		local leaf = node("Model")
		props.children.CheckoutCounter = leaf
		local art = LotArt.choose(root, ArtLibrary.find, LotArt.PATHS.Counter)
		expect.equal(art.mode, "Art")
		expect.equal(art.template, leaf)
		expect.equal(art.code, nil)
		local missing = LotArt.choose(root, ArtLibrary.find, LotArt.PATHS.Bay)
		expect.equal(missing.mode, "Primitive")
		expect.equal(missing.code, "MissingArtAsset")
		expect.equal(missing.template, nil)
		local none = LotArt.choose(nil, ArtLibrary.find, LotArt.PATHS.Counter)
		expect.equal(none.mode, "Primitive")
		expect.equal(none.code, "MissingArtAsset")
		for _, artPath in pairs(LotArt.PATHS) do
			expect.truthy(ArtLibrary.isValidPath(artPath))
		end
	end)

	-- Euclidean gap between two lot-frame boxes (0 when they touch or overlap).
	local function gap(a, b)
		local gx = math.max(0, a.minX - b.maxX, b.minX - a.maxX)
		local gz = math.max(0, a.minZ - b.maxZ, b.minZ - a.maxZ)
		return math.sqrt(gx * gx + gz * gz)
	end

	t.test("places the gate on the road edge facing the road", function()
		local x, z = LotArt.gatePose()
		near(x, 0)
		near(z, 28)
		expect.equal(z, GameConfig.Placement.LotHalfDepth + LotArt.GATE_OFFSET)
		for _, facing in ipairs({ 1, -1 }) do
			local yaw = LotArt.roadYaw(facing)
			expect.equal(-math.cos(yaw) * facing, 1)
			near(math.sin(yaw), 0)
		end
	end)

	t.test("keeps the gate posts 2 studs clear of pads, truck and walk areas", function()
		local placement = GameConfig.Placement
		local obstacles = {
			{ minX = 43, maxX = 49, minZ = -26, maxZ = 66 }, -- truck lane
			keepClear("Sign"),
			keepClear("Spawn"),
			keepClear("Checkout"),
			keepClear("Gate"),
		}
		for i = 1, 4 do
			table.insert(obstacles, NpcPath.parkingPad(i))
		end
		local posts = LotArt.gatePostBoxes()
		expect.equal(#posts, 2)
		near(posts[1].minX, -9.65)
		near(posts[2].maxX, 9.65)
		for _, post in ipairs(posts) do
			expect.truthy(post.minZ >= placement.LotHalfDepth)
			for _, obstacle in ipairs(obstacles) do
				expect.truthy(gap(post, obstacle) >= 2)
			end
		end
	end)

	t.test("chooses the gate art or the fallback", function()
		local root = node("Folder")
		local props = node("Folder")
		root.children.Props = props
		props.children.LotGate = node("Model")
		local art = LotArt.choose(root, ArtLibrary.find, LotArt.PATHS.Gate)
		expect.equal(art.path, "Props/LotGate")
		expect.equal(art.mode, "Art")
		local missing = LotArt.choose(node("Folder"), ArtLibrary.find, LotArt.PATHS.Gate)
		expect.equal(missing.mode, "Primitive")
		expect.equal(missing.code, "MissingArtAsset")
	end)

	t.test("sizes fence pieces to the v3 post", function()
		near(LotArt.PIECE_HALF, 0.45)
		near(LotArt.RAIL_BEHIND, 4.45)
		near(LotArt.RAIL_AHEAD, 3.95)
		local post = LotArt.pieceBox({ box = "Decor", kind = "Post", x = 10, z = 5, dirX = 1, dirZ = 0 })
		near(post.maxX - post.minX, 0.9)
		near(post.maxZ - post.minZ, 0.9)
		local rail = LotArt.pieceBox({ box = "Decor", kind = "Rail", x = 10, z = 5, dirX = 1, dirZ = 0 })
		near(rail.maxX - rail.minX, 8.4)
		near(rail.maxZ - rail.minZ, 0.9)
	end)
end
