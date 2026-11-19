--!strict
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local QuestService = require(game:GetService("ServerScriptService").Server.Services.QuestService)
	local expect = t.expect

	t.test("claims completed quest exactly once", function()
		local state = BusinessState.new("personal:42", 42)
		state.sales = 1
		expect.truthy(QuestService.claim(state, "FirstSale"))
		expect.equal(state.cash, 134)
		expect.falsy(QuestService.claim(state, "FirstSale"))
	end)
end
