--!strict
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local Service = require(game:GetService("ServerScriptService").Server.Services.CustomerSimulationService)
	local expect = t.expect

	t.test("reserves and settles an eligible deterministic visit", function()
		local state = BusinessState.new("personal:42", 42)
		state.layout.placements.fir = { speciesId = "FrasierFir", sizeId = "Small" }
		local started, visit = Service.beginVisit(state, 1, 100, 0)
		expect.truthy(started)
		expect.equal(visit.placementId, "fir")
		expect.truthy(Service.completeVisit(state, visit, 101))
		expect.equal(state.sales, 1)
	end)

	t.test("does not reserve a failed conversion", function()
		local state = BusinessState.new("personal:42", 42)
		state.layout.placements.fir = { speciesId = "FrasierFir", sizeId = "Small" }
		expect.falsy(Service.beginVisit(state, 1, 100, 1))
		expect.equal(state.reservations.fir, nil)
	end)
end
