--!strict
-- CM2-UVF2: world label priority and overlap resolution.
return function(t)
	local LabelDeclutter =
		require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("LabelDeclutter"))
	local expect = t.expect

	local function entry(x: number, priority: number, depth: number, shown: boolean?)
		return { box = { x = x, y = 0, w = 100, h = 30 }, priority = priority, depth = depth, shown = shown == true }
	end

	t.test("nearer label wins an overlap", function()
		local result = LabelDeclutter.resolve({ entry(0, 1, 10), entry(50, 1, 20) })
		expect.equal(result[1], true)
		expect.equal(result[2], false)
	end)

	t.test("higher priority wins although farther", function()
		local pickup = LabelDeclutter.Priority.PickupOrder
		local tree = LabelDeclutter.Priority.DisplayTree
		local result = LabelDeclutter.resolve({ entry(0, tree, 10), entry(50, pickup, 30) })
		expect.equal(result[1], false)
		expect.equal(result[2], true)
	end)

	t.test("labels that do not overlap all show", function()
		local result = LabelDeclutter.resolve({ entry(0, 1, 5), entry(200, 1, 5), entry(400, 1, 5) })
		expect.equal(result[1], true)
		expect.equal(result[2], true)
		expect.equal(result[3], true)
	end)

	t.test("a hidden label does not block", function()
		-- A and B overlap, B and C overlap, A and C do not.
		local result = LabelDeclutter.resolve({ entry(0, 1, 1), entry(80, 1, 2), entry(160, 1, 3) })
		expect.equal(result[1], true)
		expect.equal(result[2], false)
		expect.equal(result[3], true)
	end)

	t.test("a shown label keeps its place within the bias", function()
		local near = LabelDeclutter.resolve({ entry(0, 1, 11, true), entry(50, 1, 10) })
		expect.equal(near[1], true)
		expect.equal(near[2], false)
		local far = LabelDeclutter.resolve({ entry(0, 1, 13, true), entry(50, 1, 10) })
		expect.equal(far[1], false)
		expect.equal(far[2], true)
	end)

	t.test("five stacked tree labels show one", function()
		local entries = {}
		for index = 1, 5 do
			entries[index] = {
				box = { x = 0, y = (index - 1) * 10, w = 220, h = 44 },
				priority = LabelDeclutter.Priority.DisplayTree,
				depth = 4 + index,
				shown = false,
			}
		end
		local result = LabelDeclutter.resolve(entries)
		local count = 0
		for index, value in ipairs(result) do
			if value then
				count += 1
				expect.equal(index, 1)
			end
		end
		expect.equal(count, 1)
	end)

	t.test("priorityFor maps kinds", function()
		expect.truthy(
			LabelDeclutter.priorityFor("DisplayTree", true) > LabelDeclutter.priorityFor("DisplayTree", false)
		)
		expect.truthy(
			LabelDeclutter.priorityFor("BayArriving", false) > LabelDeclutter.priorityFor("BayContents", false)
		)
		expect.equal(LabelDeclutter.priorityFor("Nope", false), 0)
		expect.equal(LabelDeclutter.priorityFor(nil, false), 0)
	end)
end
