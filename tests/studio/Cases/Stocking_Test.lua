--!strict
-- CM2-G14: stocking spot rules, row positions and the lot frame (Stocking.lua).
return function(t)
	local Stocking = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Stocking"))
	local expect = t.expect

	local function input(level: number?, trees: { any }?): any
		return { lotExpansion = level or 0, trees = trees or {} }
	end

	local function reason(layout, x: number, z: number): string?
		local ok, code = Stocking.check(layout, x, z, "Medium")
		if ok then
			return nil
		end
		return code
	end

	t.test("rejects a spot outside the lot", function()
		expect.equal(reason(input(), 39, 0), "OutsideLot")
		expect.equal(reason(input(0), -35, -25.5), "OutsideLot")
		expect.equal(reason(input(1), -35, -25.5), nil)
	end)

	t.test("rejects keep-clear areas", function()
		for _, spot in { { -10, 22 }, { 0, 20 }, { 30, 13 }, { 35, -10 }, { -8, -4 } } do
			expect.equal(reason(input(), spot[1], spot[2]), "KeepClear")
		end
	end)

	t.test("rejects a tree too close to another", function()
		local layout = input(0, { { x = -35, z = -13, sizeId = "Medium" } })
		expect.equal(reason(layout, -35, -8), "TooClose")
		expect.equal(reason(layout, -35, -7.4), nil)
	end)

	t.test("checks reasons in a fixed order", function()
		-- (39, 13) also lies in the Pickup box; OutsideLot comes first.
		expect.equal(reason(input(), 39, 13), "OutsideLot")
	end)

	t.test("computes row positions with gap and rotation", function()
		local straight = Stocking.rowPositions(-35, -20, 0, "Medium", 5, 0.5)
		local xs = { -35, -28.9, -22.8, -16.7, -10.6 }
		expect.equal(#straight, 5)
		for index, x in ipairs(xs) do
			expect.equal(straight[index].x, x)
			expect.equal(straight[index].z, -20)
		end
		local turned = Stocking.rowPositions(-35, -20, 90, "Medium", 5, 0.5)
		local zs = { -20, -13.9, -7.8, -1.7, 4.4 }
		expect.equal(#turned, 5)
		for index, z in ipairs(zs) do
			expect.equal(turned[index].x, -35)
			expect.equal(turned[index].z, z)
		end
	end)

	t.test("facing maps lot depth to world z", function()
		expect.equal(Stocking.facing(-75), 1)
		expect.equal(Stocking.facing(75), -1)
	end)

	-- CM2-25/26: the staff break area is a keep-clear square for trees.
	t.test("a tree may not stand in the break area", function()
		local layout = { lotExpansion = 0, trees = {}, breakArea = { x = -32, z = -20 } }
		expect.equal(reason(layout, -32, -20), "KeepClear")
		expect.equal(reason(layout, -35, -13.4), "KeepClear")
		expect.equal(reason(layout, -35, -13), nil)
		expect.equal(reason(input(), -32, -20), nil)
		local box = Stocking.breakAreaBox({ x = -32, z = -20 })
		expect.truthy(box ~= nil)
		expect.equal((box :: any).minX, -36)
		expect.equal((box :: any).maxZ, -16)
		expect.equal(Stocking.breakAreaBox({ x = 0 / 0, z = 0 }), nil)
		expect.equal(Stocking.breakAreaBox(nil), nil)
		local fromState = Stocking.layoutInput({
			layout = { placements = {} },
			progression = { lotExpansion = 1 },
			breakArea = { x = 25.5, z = -22, rotation = 90 },
		})
		expect.equal((fromState.breakArea :: any).x, 25.5)
		expect.equal((fromState.breakArea :: any).z, -22)
	end)
end
