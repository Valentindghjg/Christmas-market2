--!strict
return function(t)
	local PlotService = require(
		game:GetService("ServerScriptService")
			:WaitForChild("Server")
			:WaitForChild("Services")
			:WaitForChild("PlotService")
	)
	local expect = t.expect

	-- Each save (holder) receives one distinct plot and may safely reclaim it.
	t.test("allocates distinct plots", function()
		local plots = PlotService.new({ "PlotA", "PlotB" })
		local first = plots:claim("save:42_a")
		local second = plots:claim("save:77_b")
		expect.equal(first, "PlotA")
		expect.equal(second, "PlotB")
		expect.equal(plots:claim("save:42_a"), "PlotA")
		expect.truthy(plots:owns("save:42_a", "PlotA"))
		expect.falsy(plots:owns("save:42_a", "PlotB"))
		expect.equal(plots:getPlot("save:77_b"), "PlotB")
		expect.equal(plots:freeCount(), 0)
		local none, reason = plots:claim("save:99_c")
		expect.equal(none, nil)
		expect.equal(reason, "NoPlotsAvailable")
		local invalid, invalidReason = plots:claim("")
		expect.equal(invalid, nil)
		expect.equal(invalidReason, "InvalidHolder")
	end)

	-- Released plots become available without leaking ownership.
	t.test("releases plots on leave", function()
		local plots = PlotService.new({ "PlotA" })
		expect.equal(plots:claim("save:42_a"), "PlotA")
		expect.truthy(plots:release("save:42_a"))
		expect.falsy(plots:release("save:42_a"))
		expect.equal(plots:getPlot("save:42_a"), nil)
		expect.equal(plots:claim("save:77_b"), "PlotA")
	end)

	-- A switched save keeps its plot when it is free; otherwise config order decides.
	t.test("prefers the requested free plot", function()
		local plots = PlotService.new({ "PlotA", "PlotB", "PlotC" })
		expect.equal(plots:claim("save:1_a", "PlotB"), "PlotB")
		expect.equal(plots:claim("save:2_b", "PlotB"), "PlotA")
		expect.equal(plots:claim("save:3_c", "PlotX"), "PlotC")
		expect.equal(plots:freeCount(), 0)
	end)
end
