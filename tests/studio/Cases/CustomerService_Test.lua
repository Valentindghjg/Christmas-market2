--!strict
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local CustomerService = require(game:GetService("ServerScriptService").Server.Services.CustomerService)
	local expect = t.expect

	-- A sale is credited only after an unexpired server-side reservation.
	t.test("settles reserved displayed tree exactly once", function()
		local state = BusinessState.new("personal:42", 42)
		state.layout.placements["placement_sale"] =
			{ speciesId = "FrasierFir", sizeId = "Medium", transform = { x = 0, y = 0, z = 0, rotation = 0 } }
		local reserved, quote = CustomerService.reserve(state, "placement_sale", "customer:1", 100)
		expect.truthy(reserved)
		expect.equal(quote.salePrice, 160)
		expect.falsy(CustomerService.reserve(state, "placement_sale", "customer:2", 100))
		local ok, sale = CustomerService.completeReservedSale(state, "placement_sale", "customer:1", 101)
		expect.truthy(ok)
		expect.equal(sale.salePrice, 160)
		expect.equal(state.cash, 244)
		expect.equal(state.sales, 1)
		expect.falsy(CustomerService.completeReservedSale(state, "placement_sale", "customer:1", 101))
	end)

	t.test("expires reservation without consuming display inventory", function()
		local state = BusinessState.new("personal:42", 42)
		state.layout.placements["placement_expire"] =
			{ speciesId = "NobleFir", sizeId = "Small", transform = { x = 0, y = 0, z = 0, rotation = 0 } }
		expect.truthy(CustomerService.reserve(state, "placement_expire", "customer:1", 100, 5))
		expect.falsy(CustomerService.completeReservedSale(state, "placement_expire", "customer:1", 105))
		expect.truthy(state.layout.placements["placement_expire"])
		expect.falsy(state.reservations["placement_expire"])
	end)
end
