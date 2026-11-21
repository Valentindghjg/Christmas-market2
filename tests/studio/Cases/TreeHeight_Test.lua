--!strict
-- G3: every displayed tree has a stable height inside its size class.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local GameConfig = require(Shared:WaitForChild("GameConfig"))
	local TreeHeight = require(Shared:WaitForChild("TreeHeight"))
	local expect = t.expect

	t.test("heights stay inside the observed size ranges", function()
		for _, sizeId in ipairs(GameConfig.SizeIds) do
			local range = GameConfig.TreeHeightTenths[sizeId]
			for index = 1, 200 do
				local tenths = TreeHeight.tenthsFor("placement:" .. index, sizeId)
				expect.truthy(tenths ~= nil and tenths >= range.min and tenths <= range.max)
			end
		end
	end)

	t.test("the same tree always gets the same height", function()
		expect.equal(
			TreeHeight.tenthsFor("placement:abc123", "Medium"),
			TreeHeight.tenthsFor("placement:abc123", "Medium")
		)
	end)

	t.test("heights vary between trees", function()
		local seen = {}
		local distinct = 0
		for index = 1, 50 do
			local tenths = TreeHeight.tenthsFor("tree_" .. index, "Large") :: number
			if not seen[tenths] then
				seen[tenths] = true
				distinct += 1
			end
		end
		expect.truthy(distinct >= 5)
	end)

	t.test("formats feet with one decimal", function()
		expect.equal(TreeHeight.feetText(72), "7.2")
		expect.equal(TreeHeight.feetText(50), "5.0")
		expect.equal(TreeHeight.tenthsFor("x", "Huge"), nil)
	end)
end
