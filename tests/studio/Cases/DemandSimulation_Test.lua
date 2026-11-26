--!strict
-- CM2-SALE2 conversion simulation: sales per visit on fixed lots, PROVISIONAL targets (GAME_DESIGN §4).
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local CustomerProfile = require(Shared:WaitForChild("CustomerProfile"))
	local CustomerSelection = require(Shared:WaitForChild("CustomerSelection"))
	local GameConfig = require(Shared:WaitForChild("GameConfig"))
	local expect = t.expect

	local VISITS = 1000

	local function lot(list: { { string } })
		local state = BusinessState.new("personal:42", 42)
		for index, tree in ipairs(list) do
			state.layout.placements[string.format("t_%02d", index)] = { speciesId = tree[1], sizeId = tree[2] }
		end
		return state
	end

	-- Same rule as beginVisit: a sale when the roll is at or below the conversion score.
	local function simulate(name: string, state, seed: number): number
		local sales = 0
		for i = 1, VISITS do
			local candidate = CustomerSelection.choose(state, CustomerProfile.create(i))
			local roll = (seed * 0.1 + i * 0.61803398875) % 1
			if candidate ~= nil and roll <= candidate.conversionScore then
				sales += 1
			end
		end
		local rate = sales / VISITS
		print(string.format("[SALE2] lot=%s seed=%d sales=%d visits=%d rate=%.3f", name, seed, sales, VISITS, rate))
		return rate
	end

	local function expectRange(name: string, state, low: number, high: number)
		for seed = 1, 3 do
			local rate = simulate(name, state, seed)
			expect.truthy(rate >= low and rate <= high)
		end
	end

	t.test("one-tree starter lot converts 10-16 % (CM2-SALE2)", function()
		expectRange("one_douglas", lot({ { "DouglasFir", "Medium" } }), 0.10, 0.16)
	end)

	t.test("six Douglas Medium convert 16-23 % (CM2-SALE2)", function()
		local trees = {}
		for _ = 1, 6 do
			table.insert(trees, { "DouglasFir", "Medium" })
		end
		expectRange("six_douglas_medium", lot(trees), 0.16, 0.23)
	end)

	t.test("mixed S/M/L starter lot converts 18-25 % (CM2-SALE2)", function()
		local trees = {}
		for _, sizeId in ipairs({ "Small", "Medium", "Large" }) do
			for _ = 1, 2 do
				table.insert(trees, { "DouglasFir", sizeId })
			end
		end
		expectRange("mixed_douglas_sml", lot(trees), 0.18, 0.25)
	end)

	t.test("full assortment stays at 25-35 % (CM2-SALE2, no runaway)", function()
		local trees = {}
		for _, speciesId in ipairs(GameConfig.SpeciesOrder) do
			for _, sizeId in ipairs({ "Small", "Medium", "Large" }) do
				table.insert(trees, { speciesId, sizeId })
			end
		end
		expectRange("full_assortment", lot(trees), 0.25, 0.35)
	end)
end
