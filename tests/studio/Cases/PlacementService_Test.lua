--!strict
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local Inventory = require(Shared:WaitForChild("Inventory"))
	local PlacementService = require(game:GetService("ServerScriptService").Server.Services.PlacementService)
	local expect = t.expect

	t.test("moves one tree between storage and display", function()
		local state = BusinessState.new("personal:42", 42)
		local key = Inventory.key("FrasierFir", "Medium")
		Inventory.add(state.stock, key, 1)
		expect.truthy(
			PlacementService.place(state, "placement_1", "FrasierFir", "Medium", { x = 0, y = 0, z = 0, rotation = 0 })
		)
		expect.equal(Inventory.count(state.stock, key), 0)
		expect.truthy(PlacementService.pickup(state, "placement_1"))
		expect.equal(Inventory.count(state.stock, key), 1)
	end)
end
