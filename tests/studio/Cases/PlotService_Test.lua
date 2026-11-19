--!strict
return function(t)
	local PlotService = require(
		game:GetService("ServerScriptService")
			:WaitForChild("Server")
			:WaitForChild("Services")
			:WaitForChild("PlotService")
	)
	local expect = t.expect

	-- Each player receives one distinct plot and may safely reclaim it.
	t.test("allocates distinct plots", function()
		local plots = PlotService.new({ "PlotA", "PlotB" })
		local first = plots:claim(42)
		local second = plots:claim(77)
		expect.equal(first, "PlotA")
		expect.equal(second, "PlotB")
		expect.equal(plots:claim(42), "PlotA")
		expect.truthy(plots:owns(42, "PlotA"))
		expect.falsy(plots:owns(42, "PlotB"))
	end)

	-- Released plots become available without leaking ownership.
	t.test("releases plots on leave", function()
		local plots = PlotService.new({ "PlotA" })
		expect.equal(plots:claim(42), "PlotA")
		expect.truthy(plots:release(42))
		expect.equal(plots:claim(77), "PlotA")
	end)
end
