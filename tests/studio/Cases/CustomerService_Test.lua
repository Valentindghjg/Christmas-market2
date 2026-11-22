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

	-- CM2-N1: a walking customer who gives up releases only its own reservation.
	t.test("cancels only the owner's reservation", function()
		local state = BusinessState.new("personal:42", 42)
		state.layout.placements["placement_cancel"] =
			{ speciesId = "FrasierFir", sizeId = "Medium", transform = { x = 0, y = 0, z = 0, rotation = 0 } }
		expect.truthy(CustomerService.reserve(state, "placement_cancel", "visit:1", 100, 120))
		local cash = state.cash
		local ok, code = CustomerService.cancelReservation(state, "placement_cancel", "visit:2")
		expect.falsy(ok)
		expect.equal(code, "ReservationOwnerMismatch")
		expect.truthy(state.reservations["placement_cancel"])
		local released, none = CustomerService.cancelReservation(state, "placement_cancel", "visit:1")
		expect.truthy(released)
		expect.equal(none, nil)
		expect.equal(state.reservations["placement_cancel"], nil)
		expect.truthy(state.layout.placements["placement_cancel"])
		expect.equal(state.cash, cash)
		local again, againCode = CustomerService.cancelReservation(state, "placement_cancel", "visit:1")
		expect.falsy(again)
		expect.equal(againCode, "ReservationRequired")
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

	-- CM2-G15: reputation comes from the review after loading, never from the checkout.
	t.test("checkout earns no reputation", function()
		local state = BusinessState.new("personal:42", 42)
		state.layout.placements["placement_rep"] =
			{ speciesId = "FrasierFir", sizeId = "Medium", transform = { x = 0, y = 0, z = 0, rotation = 0 } }
		expect.truthy(CustomerService.reserve(state, "placement_rep", "customer:1", 100))
		local reputation = state.reputation
		local ok, sale = CustomerService.completeReservedSale(state, "placement_rep", "customer:1", 101)
		expect.truthy(ok)
		expect.equal(sale.reputationGain, 0)
		expect.equal(state.reputation, reputation)
	end)
end
