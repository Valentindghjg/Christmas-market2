--!strict
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local CustomerService = require(game:GetService("ServerScriptService").Server.Services.CustomerService)
	local expect = t.expect

	-- Selling a displayed tree credits exactly one server-derived price.
	t.test("settles displayed tree exactly once", function()
		local state = BusinessState.new("personal:42", 42)
		state.layout.placements["placement_sale"] =
			{ speciesId = "FrasierFir", sizeId = "Medium", transform = { x = 0, y = 0, z = 0, rotation = 0 } }
		local ok, sale = CustomerService.completeSale(state, "placement_sale")
		expect.truthy(ok)
		expect.equal(sale.salePrice, 82)
		expect.equal(state.cash, 166)
		expect.equal(state.sales, 1)
		expect.falsy(CustomerService.completeSale(state, "placement_sale"))
	end)
end
