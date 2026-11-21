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

	-- Only validated numbers are persisted; extra client keys cannot bloat the save.
	t.test("stores a sanitized copy of the transform", function()
		local state = BusinessState.new("personal:42", 42)
		Inventory.add(state.stock, Inventory.key("FrasierFir", "Medium"), 1)
		local transform = { x = 1, y = 0, z = 2, rotation = 90, junk = string.rep("x", 1000) }
		expect.truthy(PlacementService.place(state, "placement_2", "FrasierFir", "Medium", transform))
		local stored = state.layout.placements.placement_2.transform
		expect.equal(stored.junk, nil)
		expect.equal(stored.rotation, 90)
		expect.truthy(stored ~= transform)
	end)

	t.test("rejects positions outside the owner's lot", function()
		local state = BusinessState.new("personal:42", 42)
		Inventory.add(state.stock, Inventory.key("FrasierFir", "Medium"), 1)
		local ok, reason =
			PlacementService.place(state, "placement_3", "FrasierFir", "Medium", { x = 0, y = 0, z = 45, rotation = 0 })
		expect.falsy(ok)
		expect.equal(reason, "InvalidPlacement")
		expect.equal(Inventory.count(state.stock, Inventory.key("FrasierFir", "Medium")), 1)
	end)

	-- Picking up a reserved tree would orphan the reservation and invalidate the record.
	t.test("refuses to pick up a reserved tree", function()
		local state = BusinessState.new("personal:42", 42)
		state.layout.placements.reserved_1 = { speciesId = "FrasierFir", sizeId = "Medium" }
		state.reservations.reserved_1 = { customerId = "npc:1", expiresAt = 200, salePrice = 82 }
		local ok, reason = PlacementService.pickup(state, "reserved_1")
		expect.falsy(ok)
		expect.equal(reason, "Reserved")
		expect.truthy(BusinessState.validate(state))
	end)

	t.test("enforces the display placement cap", function()
		local GameConfig = require(Shared:WaitForChild("GameConfig"))
		local state = BusinessState.new("personal:42", 42)
		for index = 1, GameConfig.MaxPlacements do
			state.layout.placements["existing_" .. index] = { speciesId = "FrasierFir", sizeId = "Medium" }
		end
		Inventory.add(state.stock, Inventory.key("FrasierFir", "Medium"), 1)
		local ok, reason =
			PlacementService.place(state, "placement_4", "FrasierFir", "Medium", { x = 0, y = 0, z = 0, rotation = 0 })
		expect.falsy(ok)
		expect.equal(reason, "PlacementLimit")
		expect.equal(Inventory.count(state.stock, Inventory.key("FrasierFir", "Medium")), 1)
	end)
end
