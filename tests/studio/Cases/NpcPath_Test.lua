--!strict
-- CM2-N1: lot-frame points, obstacles and routes of walking customers.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local GameConfig = require(Shared:WaitForChild("GameConfig"))
	local NpcPath = require(Shared:WaitForChild("NpcPath"))
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
		samePoint(NpcPath.door(1), -20.5, 20)
		samePoint(NpcPath.door(4), 15.5, 20)
		for space = 1, 4 do
			near(NpcPath.aisle(space).z, 12)
			near(NpcPath.aisle(space).x, NpcPath.door(space).x)
		end
		samePoint(NpcPath.queueSlot(1), 16, -11)
		samePoint(NpcPath.queueSlot(4), 16, -0.5)
		samePoint(NpcPath.staffPoint(), 16, -16.5)
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
		for index = 1, 4 do
			local slot = NpcPath.queueSlot(index)
			expect.truthy(slot.x - 1 >= checkout.minX and slot.x + 1 <= checkout.maxX)
			expect.truthy(slot.z - 1 >= checkout.minZ and slot.z + 1 <= checkout.maxZ)
		end
	end)

	t.test("route is direct when nothing is in the way", function()
		local route = NpcPath.route(NpcPath.aisle(1), NpcPath.aisle(4), 0)
		expect.equal(#route, 1)
		samePoint(route[1], NpcPath.aisle(4).x, NpcPath.aisle(4).z)
	end)

	t.test("route bends around the sales stand", function()
		local from = NpcPath.aisle(1)
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

	t.test("route never leaves the lot", function()
		for _, x in ipairs({ -35, -10, 25 }) do
			for _, z in ipairs({ -24, -20, 0, 8 }) do
				local p = { x = x, z = z }
				for space = 1, 4 do
					for _, point in ipairs(NpcPath.route(NpcPath.door(space), p, 0)) do
						expect.truthy(NpcPath.inLot(point, 0))
					end
				end
				for _, point in ipairs(NpcPath.route(p, NpcPath.queueSlot(4), 0)) do
					expect.truthy(NpcPath.inLot(point, 0))
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

		local slot = NpcPath.queueSlot(4)
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
		samePoint(NpcPath.toWorld(south, slot), 16, -86)
		samePoint(NpcPath.toWorld(north, slot), 126, 86)
		for _, c in ipairs({ south, north }) do
			local w = NpcPath.toWorld(c, slot)
			samePoint(NpcPath.fromWorld(c, w.x, w.z), slot.x, slot.z)
		end
	end)
end
