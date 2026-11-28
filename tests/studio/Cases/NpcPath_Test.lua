--!strict
-- CM2-N1: lot-frame points, obstacles and routes of walking customers.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local GameConfig = require(Shared:WaitForChild("GameConfig"))
	local LotArt = require(Shared:WaitForChild("LotArt"))
	local NpcPath = require(Shared:WaitForChild("NpcPath"))
	local Staff = require(Shared:WaitForChild("Staff"))
	local expect = t.expect

	local function near(actual: number, expected: number)
		expect.truthy(math.abs(actual - expected) < 1e-6)
	end

	local function samePoint(actual, x: number, z: number)
		expect.truthy(actual ~= nil)
		near(actual.x, x)
		near(actual.z, z)
	end

	t.test("door, aisle and queue points follow the layout", function()
		samePoint(NpcPath.door(1), -10, 33)
		samePoint(NpcPath.door(4), 26, 33)
		samePoint(NpcPath.parkingSpot(1), -13.5, 40)
		samePoint(NpcPath.parkingSpot(4), 22.5, 40)
		local entryX = { -1.5, 1.5, -3.5, 3.5 }
		for space = 1, 4 do
			near(NpcPath.aisle(space).z, 20)
			near(NpcPath.aisle(space).x, entryX[space])
		end
		samePoint(NpcPath.queueSlot(1), -14, 19.5)
		samePoint(NpcPath.queueSlot(2), -14, 23)
		samePoint(NpcPath.queueSlot(3), -10.5, 23)
		samePoint(NpcPath.queueSlot(4), -7, 23)
		samePoint(NpcPath.staffPoint(), -14, 14)
	end)

	-- CM2-UVF3: queued customers carry their tree in front, so the spots keep a clear gap,
	-- and every spot stays inside the Checkout keep-clear box (no tree is stocked there).
	t.test("queue spots keep a 3-stud gap", function()
		local checkout
		for _, box in ipairs(GameConfig.Placement.KeepClear) do
			if box.id == "Checkout" then
				checkout = box
			end
		end
		expect.truthy(checkout ~= nil)
		for index = 1, 3 do
			expect.truthy(NpcPath.distance(NpcPath.queueSlot(index), NpcPath.queueSlot(index + 1)) >= 3)
		end
		-- CM2-LOTLAY: the L stays 1 stud off the entrance path (KeepClear Gate) and nears the gate.
		local gate
		for _, box in ipairs(GameConfig.Placement.KeepClear) do
			if box.id == "Gate" then
				gate = box
			end
		end
		expect.truthy(gate ~= nil)
		local previous = math.huge
		for index = 1, 4 do
			local slot = NpcPath.queueSlot(index)
			expect.truthy(slot.x - 1 >= checkout.minX and slot.x + 1 <= checkout.maxX)
			expect.truthy(slot.z - 1 >= checkout.minZ and slot.z + 1 <= checkout.maxZ)
			local dx = math.max(gate.minX - slot.x, 0, slot.x - gate.maxX)
			local dz = math.max(gate.minZ - slot.z, 0, slot.z - gate.maxZ)
			expect.truthy(math.max(dx, dz) >= 1)
			local toGate = NpcPath.distance(slot, { x = 0, z = 27 })
			expect.truthy(toGate < previous)
			previous = toGate
		end
	end)

	t.test("route is direct when nothing is in the way", function()
		local route = NpcPath.route(NpcPath.aisle(1), NpcPath.aisle(4), 0)
		expect.equal(#route, 1)
		samePoint(route[1], NpcPath.aisle(4).x, NpcPath.aisle(4).z)
	end)

	t.test("route bends around the sales stand", function()
		local from = { x = -35, z = -5 }
		local to = NpcPath.queueSlot(4)
		local route = NpcPath.route(from, to, 0)
		expect.truthy(#route >= 2)
		local boxes = NpcPath.obstacles()
		local previous = from
		for _, p in ipairs(route) do
			expect.truthy(NpcPath.segmentClear(previous, p, boxes))
			previous = p
		end
		samePoint(route[#route], to.x, to.z)
	end)

	t.test("route never leaves the walk area", function()
		for _, x in ipairs({ -35, -10, 25 }) do
			for _, z in ipairs({ -24, -20, 0, 8 }) do
				local p = { x = x, z = z }
				for space = 1, 4 do
					for _, point in ipairs(NpcPath.route(NpcPath.door(space), p, 0)) do
						expect.truthy(NpcPath.inWalkArea(point, 0))
					end
				end
				for _, point in ipairs(NpcPath.route(p, NpcPath.queueSlot(4), 0)) do
					expect.truthy(NpcPath.inWalkArea(point, 0))
				end
			end
		end
	end)

	t.test("an end inside an obstacle is pushed to its edge", function()
		local route = NpcPath.route(NpcPath.aisle(1), { x = -8, z = 5 }, 0)
		samePoint(route[#route], -8, 11.01)
	end)

	t.test("a start inside an obstacle walks out first", function()
		local direct = NpcPath.route({ x = -8, z = 9 }, { x = -8, z = 20 }, 0)
		expect.equal(#direct, 2)
		samePoint(direct[1], -8, 11.01)
		samePoint(direct[2], -8, 20)

		local slot = NpcPath.queueSlot(1)
		local around = NpcPath.route({ x = -8, z = 9 }, slot, 0)
		expect.truthy(#around >= 3)
		samePoint(around[1], -8, 11.01)
		samePoint(around[#around], slot.x, slot.z)
		local boxes = NpcPath.obstacles()
		for index = 2, #around do
			expect.truthy(NpcPath.segmentClear(around[index - 1], around[index], boxes))
		end
	end)

	t.test("approach sits beside the tree", function()
		samePoint(NpcPath.approach({ x = -30, z = -20, sizeId = "Medium" }, 0), -30, -16.4)
		expect.equal(NpcPath.approach({ sizeId = "Medium" }, 0), nil)
	end)

	t.test("lot to world mirrors depth on plots 4-6", function()
		local south = { x = 0, z = -75 }
		local north = { x = 110, z = 75 }
		local slot = NpcPath.queueSlot(1)
		samePoint(NpcPath.toWorld(south, slot), -14, -55.5)
		samePoint(NpcPath.toWorld(north, slot), 96, 55.5)
		for _, c in ipairs({ south, north }) do
			local w = NpcPath.toWorld(c, slot)
			samePoint(NpcPath.fromWorld(c, w.x, w.z), slot.x, slot.z)
		end
	end)

	-- CM2-25/26 Amendment 3: the queue legs end on the slots; from the lower left the route to slot 2
	-- passes the Stand corner first (the counter sits at the HQ front since CM2-LOTLAY).
	t.test("routes end exactly at queue slots 1 and 2", function()
		local starts = { { -35, -9.4 }, { 25.5, -11.4 }, { 26.4, -22 }, { 11.5, 9.6 }, { 25.5, 2.6 } }
		for _, from in ipairs(starts) do
			for slotIndex = 1, 2 do
				local slot = NpcPath.queueSlot(slotIndex)
				local route = NpcPath.route({ x = from[1], z = from[2] }, slot, 0)
				samePoint(route[#route], slot.x, slot.z)
			end
		end
		local left = NpcPath.route({ x = -35, z = -9.4 }, NpcPath.queueSlot(2), 0)
		expect.truthy(#left >= 2)
		samePoint(left[#left - 1], -27, 11)
	end)

	-- Raw (uninflated) geometry a customer must not cross: the fence pieces, the gate posts, Stand,
	-- Bays and the counter body.
	local function rawObstacles(level: number): { any }
		local list: { any } = {}
		for _, piece in ipairs(LotArt.fenceSegments(level)) do
			table.insert(list, LotArt.pieceBox(piece))
		end
		for _, post in ipairs(LotArt.gatePostBoxes()) do
			table.insert(list, post)
		end
		for _, box in ipairs(GameConfig.Placement.KeepClear) do
			if box.id == "Stand" or box.id == "Bays" then
				table.insert(list, box)
			end
		end
		table.insert(list, GameConfig.Customers.Npc.Path.Counter)
		return list
	end

	-- CM2-LOTLAY: door -> entry -> trees -> queue 4..1 -> door, and the Lot Worker's pickup -> door.
	t.test("every leg goes through the gate and crosses no fence", function()
		local trees = {
			{ x = -30, z = 20, sizeId = "Large" },
			{ x = 30, z = 20, sizeId = "Medium" },
			{ x = -30, z = -20, sizeId = "Small" },
		}
		for _, level in ipairs({ 0, 6 }) do
			local raw = rawObstacles(level)
			local function walk(from, to)
				local previous = from
				for _, p in ipairs(NpcPath.route(from, to, level)) do
					expect.truthy(NpcPath.segmentClear(previous, p, raw))
					previous = p
				end
			end
			for space = 1, 4 do
				local chain = { NpcPath.door(space), NpcPath.aisle(space) }
				for _, tree in ipairs(trees) do
					table.insert(chain, NpcPath.approach(tree, level))
				end
				for slot = 4, 1, -1 do
					table.insert(chain, NpcPath.queueSlot(slot))
				end
				table.insert(chain, NpcPath.door(space))
				for index = 2, #chain do
					walk(chain[index - 1], chain[index])
				end
				walk(Staff.pickupApproach(space), NpcPath.door(space))
			end
		end
	end)

	-- CM2-LOTLAY: the cars stand outside the front fence, the doors on the apron side of the pads.
	t.test("parking pads lie outside the fence and their doors are walkable", function()
		local apron = GameConfig.Placement.CarPark.Apron
		local postMaxZ = LotArt.gatePostBoxes()[1].maxZ
		local obstacles = NpcPath.obstacles()
		local pads = {}
		for space = 1, 4 do
			local pad = NpcPath.parkingPad(space)
			pads[space] = pad
			expect.equal(pad.id, "Pad" .. space)
			expect.truthy(pad.minX >= apron.minX and pad.maxX <= apron.maxX)
			expect.truthy(pad.minZ >= apron.minDepth and pad.maxZ <= apron.maxDepth)
			expect.truthy(pad.minZ >= postMaxZ + 5)
			local door = NpcPath.door(space)
			expect.truthy(door.z < pad.minZ)
			expect.truthy(door.z <= GameConfig.Placement.LotHalfDepth + GameConfig.Placement.FrontApronDepth)
			for _, box in ipairs(obstacles) do
				expect.falsy(door.x > box.minX and door.x < box.maxX and door.z > box.minZ and door.z < box.maxZ)
			end
		end
		for first = 1, 4 do
			for second = first + 1, 4 do
				local a, b = pads[first], pads[second]
				local gapX = math.max(a.minX - b.maxX, b.minX - a.maxX)
				local gapZ = math.max(a.minZ - b.maxZ, b.minZ - a.maxZ)
				expect.truthy(math.max(gapX, gapZ) >= 2)
			end
		end
	end)
end
