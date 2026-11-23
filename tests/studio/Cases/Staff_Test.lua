--!strict
-- CM2-25/26: staff energy, the break area and the points staff walk to (Staff.lua).
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local GameConfig = require(Shared:WaitForChild("GameConfig"))
	local NpcPath = require(Shared:WaitForChild("NpcPath"))
	local Staff = require(Shared:WaitForChild("Staff"))
	local expect = t.expect
	local Candidates = GameConfig.Staff.BreakArea.Candidates

	local function near(actual: number, expected: number)
		assert(math.abs(actual - expected) < 1e-9, string.format("expected %s, got %s", expected, actual))
	end

	local function input(trees: { any }?): any
		return { lotExpansion = 0, trees = trees or {} }
	end

	local function reason(layout, x: number, z: number): string?
		local ok, code = Staff.checkBreakArea(layout, x, z)
		if ok then
			return nil
		end
		return code
	end

	t.test("energy drains on shift and recovers while resting", function()
		near(Staff.stepEnergy(50, 1, false), 49.8)
		near(Staff.stepEnergy(50, 1, true), 52)
		near(Staff.stepEnergy(50, 10, false), 48)
		near(Staff.stepEnergy(0.1, 1, false), 0)
		near(Staff.stepEnergy(99.5, 1, true), 100)
		local energy = Staff.newEnergy()
		for _, role in ipairs(GameConfig.Staff.Roles) do
			expect.equal(energy[role], 100)
		end
	end)

	t.test("tired and rested thresholds", function()
		expect.truthy(Staff.isTired(20))
		expect.falsy(Staff.isTired(21))
		expect.truthy(Staff.isRested(100))
		expect.falsy(Staff.isRested(99.9))
	end)

	t.test("default break area takes the first free candidate", function()
		local state = BusinessState.new("save:42_x", 42)
		local first = Staff.defaultBreakArea(state)
		expect.equal(first.x, Candidates[1].x)
		expect.equal(first.z, Candidates[1].z)
		expect.equal(first.rotation, 0)
		state.layout.placements.blocker = {
			speciesId = "DouglasFir",
			sizeId = "Medium",
			transform = { x = Candidates[1].x, y = 0, z = Candidates[1].z, rotation = 0 },
		}
		local second = Staff.defaultBreakArea(state)
		expect.equal(second.x, Candidates[2].x)
		expect.equal(second.z, Candidates[2].z)
		for index, candidate in ipairs(Candidates) do
			state.layout.placements["blocker_" .. index] = {
				speciesId = "DouglasFir",
				sizeId = "Small",
				transform = { x = candidate.x, y = 0, z = candidate.z, rotation = 0 },
			}
		end
		local fallback = Staff.defaultBreakArea(state)
		expect.equal(fallback.x, Candidates[1].x)
		expect.equal(fallback.z, Candidates[1].z)
		expect.truthy(fallback ~= Staff.defaultBreakArea(state))
	end)

	t.test("every candidate fits the lot and clears keep-clear boxes and fences", function()
		expect.equal(#Candidates, 4)
		for _, candidate in ipairs(Candidates) do
			local ok, code = Staff.checkBreakArea(input(), candidate.x, candidate.z)
			expect.truthy(ok)
			expect.equal(code, nil)
		end
	end)

	t.test("rest points rotate with the area", function()
		local area = { x = -32, z = -20, rotation = 90 }
		local rotated = Staff.toLot(area, { x = 0, z = 3.6 })
		near(rotated.x, -32 + 3.6)
		near(rotated.z, -20)
		local seat = Staff.restPoint(area, "Cashier")
		near(seat.x, -32 + 3.6)
		near(seat.z, -20)
		local straight = Staff.restPoint({ x = -32, z = -20, rotation = 0 }, "LotWorker")
		near(straight.x, -32 - 3.6)
		near(straight.z, -20)
		local half = Staff.toLot({ x = 0, z = 0, rotation = 180 }, { x = 0, z = 3.6 })
		near(half.x, 0)
		near(half.z, -3.6)
	end)

	t.test("the Cashier post matches the CashierStand attachment", function()
		local counter = GameConfig.Customers.Npc.Path.Counter
		local counterZ = (counter.minZ + counter.maxZ) / 2
		local post = NpcPath.staffPoint()
		expect.equal(post.x, 16)
		expect.equal(post.z, counterZ - 2.5)
		expect.equal(post.z, -16.5)
		local pickup = Staff.pickupApproach(3)
		expect.equal(pickup.x, 32)
		expect.equal(pickup.z, 9)
		expect.equal(Staff.pickupApproach(9).x, 36.5)
		local bay = Staff.bayApproach(2)
		expect.equal(bay.x, 26.5)
		expect.equal(bay.z, -16)
	end)

	t.test("checkBreakArea reports each refusal", function()
		expect.equal(reason(input(), 37, 0), "OutsideLot")
		expect.equal(reason(input(), -32, -24), "OutsideLot")
		expect.equal(reason({ lotExpansion = 1, trees = {} }, -32, -24), nil)
		-- The Stand box, and a decor fence (x -34, z 24, radius 5.5) clear of every box.
		expect.equal(reason(input(), 0, 0), "KeepClear")
		expect.equal(reason(input(), -35, 23), "KeepClear")
		expect.equal(reason(input({ { x = -32, z = -13.5, sizeId = "Medium" } }), -32, -20), "TooClose")
		expect.equal(reason(input({ { x = -32, z = -13.5, sizeId = "Small" } }), -32, -20), nil)
		expect.equal(reason(input(), 0 / 0, 0), "InvalidBreakArea")
		expect.equal(reason(input(), -32, math.huge), "InvalidBreakArea")
	end)

	-- CM2-25/26 part b: Staff.MoveBreakArea's rule.
	t.test("moveBreakArea saves a valid spot and refuses others", function()
		local state = BusinessState.new("save:42_x", 42)
		local ok, area = Staff.moveBreakArea(state, -32, -4, 90)
		expect.truthy(ok)
		expect.equal(area.x, -32)
		expect.equal(area.z, -4)
		expect.equal(area.rotation, 90)
		expect.equal(state.breakArea.x, -32)
		expect.equal(state.breakArea.z, -4)
		expect.equal(state.breakArea.rotation, 90)
		expect.truthy(area ~= state.breakArea)
		local saved = state.breakArea
		local function refused(x: number, z: number, expected: string)
			local moved, code = Staff.moveBreakArea(state, x, z, 180)
			expect.falsy(moved)
			expect.equal(code, expected)
			expect.truthy(state.breakArea == saved)
			expect.equal(state.breakArea.x, -32)
			expect.equal(state.breakArea.z, -4)
			expect.equal(state.breakArea.rotation, 90)
		end
		refused(0, 0, "KeepClear")
		refused(37, 0, "OutsideLot")
		state.layout.placements.blocker = {
			speciesId = "DouglasFir",
			sizeId = "Medium",
			transform = { x = -32, y = 0, z = -13.5, rotation = 0 },
		}
		refused(-32, -20, "TooClose")
		-- The same spot again is fine.
		expect.truthy(Staff.moveBreakArea(state, -32, -4, 90))
	end)
end
