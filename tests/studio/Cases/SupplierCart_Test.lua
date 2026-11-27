--!strict
-- CM2-SUP: supplier cart validation, cost, bay packing and the client limits (maxAdd).
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local GameConfig = require(Shared:WaitForChild("GameConfig"))
	local SupplierCart = require(Shared:WaitForChild("SupplierCart"))
	local expect = t.expect

	local function line(speciesId: string, sizeId: string, quantity: any): { [string]: any }
		return { speciesId = speciesId, sizeId = sizeId, quantity = quantity }
	end

	-- Cart X: Douglas S1 M2 + Fraser S1 M1 = 5 trees, $133.
	local function cartX(): { any }
		return {
			line("DouglasFir", "Small", 1),
			line("DouglasFir", "Medium", 2),
			line("FrasierFir", "Small", 1),
			line("FrasierFir", "Medium", 1),
		}
	end

	local function rejects(lines: unknown, code: string)
		local result, reason = SupplierCart.normalize(lines)
		expect.equal(result, nil)
		expect.equal(reason, code)
	end

	t.test("normalizes and rejects bad carts", function()
		rejects(nil, "InvalidCart")
		rejects("lines", "InvalidCart")
		rejects({}, "InvalidCart")
		rejects({ [1] = line("DouglasFir", "Small", 1), [3] = line("DouglasFir", "Medium", 1) }, "InvalidCart")
		rejects({ name = line("DouglasFir", "Small", 1) }, "InvalidCart")
		local thirteen = {}
		for _ = 1, GameConfig.Supplier.MaxCartLines + 1 do
			table.insert(thirteen, line("DouglasFir", "Small", 1))
		end
		rejects(thirteen, "InvalidCart")
		local priced = line("DouglasFir", "Small", 1)
		priced.unitCost = 0
		rejects({ priced }, "UnexpectedField")
		rejects({ "DouglasFir" }, "UnexpectedField")
		rejects({ line("Pine", "Small", 1) }, "InvalidItem")
		rejects({ line("DouglasFir", "Huge", 1) }, "InvalidItem")
		for _, quantity in ipairs({ 0, -1, 1.5, 0 / 0, math.huge, 101, "2" }) do
			rejects({ line("DouglasFir", "Small", quantity) }, "InvalidQuantity")
		end
		rejects({ line("DouglasFir", "Small", 60), line("DouglasFir", "Medium", 41) }, "InvalidQuantity")
		rejects({ line("DouglasFir", "Small", 1), line("DouglasFir", "Small", 2) }, "DuplicateLine")

		local input = {
			line("FrasierFir", "Medium", 1),
			line("DouglasFir", "Medium", 2),
			line("FrasierFir", "Small", 1),
			line("DouglasFir", "Small", 1),
		}
		local result, reason = SupplierCart.normalize(input)
		expect.equal(reason, nil)
		local lines = result :: { SupplierCart.Line }
		expect.equal(#lines, 4)
		local expected = {
			{ "DouglasFir", "Small", 1 },
			{ "DouglasFir", "Medium", 2 },
			{ "FrasierFir", "Small", 1 },
			{
				"FrasierFir",
				"Medium",
				1,
			},
		}
		for index, want in ipairs(expected) do
			expect.equal(lines[index].speciesId, want[1])
			expect.equal(lines[index].sizeId, want[2])
			expect.equal(lines[index].quantity, want[3])
			-- Only tables the server built are kept.
			for _, original in ipairs(input) do
				expect.truthy(lines[index] ~= original)
			end
		end
	end)

	t.test("packs one species per bay, at most 9 each", function()
		local lines = SupplierCart.normalize({
			line("DouglasFir", "Small", 4),
			line("DouglasFir", "Medium", 7),
			line("FrasierFir", "Large", 2),
		}) :: { SupplierCart.Line }
		local groups = SupplierCart.pack(lines)
		expect.equal(#groups, 3)
		expect.equal(groups[1].speciesId, "DouglasFir")
		expect.equal(groups[1].total, 9)
		expect.equal(#groups[1].lines, 2)
		expect.equal(groups[1].lines[1].sizeId, "Small")
		expect.equal(groups[1].lines[1].quantity, 4)
		expect.equal(groups[1].lines[2].sizeId, "Medium")
		expect.equal(groups[1].lines[2].quantity, 5)
		expect.equal(groups[2].speciesId, "DouglasFir")
		expect.equal(groups[2].total, 2)
		expect.equal(#groups[2].lines, 1)
		expect.equal(groups[2].lines[1].sizeId, "Medium")
		expect.equal(groups[2].lines[1].quantity, 2)
		expect.equal(groups[3].speciesId, "FrasierFir")
		expect.equal(groups[3].total, 2)
		expect.equal(groups[3].lines[1].sizeId, "Large")
		expect.equal(groups[3].lines[1].quantity, 2)
		expect.equal(SupplierCart.baysNeeded(lines), 3)
	end)

	t.test("costs wholesale times quantity", function()
		local lines = SupplierCart.normalize(cartX()) :: { SupplierCart.Line }
		expect.equal(SupplierCart.cost(lines), 133)
		expect.equal(SupplierCart.total(lines), 5)
		local counts = { ["DouglasFir:Small"] = 1, ["DouglasFir:Medium"] = 2, ["FrasierFir:Small"] = 1 }
		counts["FrasierFir:Medium"] = 1
		counts["NobleFir:Large"] = 0
		local fromCounts = SupplierCart.fromCounts(counts)
		expect.equal(#fromCounts, 4)
		expect.equal(fromCounts[1].sizeId, "Small")
		expect.equal(fromCounts[4].speciesId, "FrasierFir")
		expect.equal(SupplierCart.cost(fromCounts), 133)
		local free, capacity = SupplierCart.deliveryArea(counts, 2)
		expect.equal(free, 13)
		expect.equal(capacity, 18)
		local none, zero = SupplierCart.deliveryArea(counts, 0)
		expect.equal(none, 0)
		expect.equal(zero, 0)
	end)

	t.test("maxAdd takes the tightest limit", function()
		local function stockOf(value: number): { [string]: number }
			local stock = {}
			for _, speciesId in ipairs(GameConfig.SpeciesOrder) do
				for _, sizeId in ipairs(GameConfig.SizeIds) do
					stock[speciesId .. ":" .. sizeId] = value
				end
			end
			return stock
		end
		local function limits(overrides: { [string]: any }): SupplierCart.Limits
			local value = { cash = 100000, freeBays = 4, storageFree = 1000, stock = stockOf(100) }
			for key, override in pairs(overrides) do
				value[key] = override
			end
			return value :: any
		end
		-- Supplier stock minus what the cart already holds.
		local lowStock = stockOf(100)
		lowStock["DouglasFir:Small"] = 5
		expect.equal(
			SupplierCart.maxAdd({ ["DouglasFir:Small"] = 2 }, "DouglasFir", "Small", limits({ stock = lowStock })),
			3
		)
		-- MaxOrderQuantity (100) minus the cart total.
		expect.equal(
			SupplierCart.maxAdd({ ["DouglasFir:Small"] = 95 }, "DouglasFir", "Medium", limits({ freeBays = 20 })),
			5
		)
		-- Free delivery storage minus the cart total.
		expect.equal(
			SupplierCart.maxAdd({ ["DouglasFir:Small"] = 4 }, "DouglasFir", "Medium", limits({ storageFree = 10 })),
			6
		)
		-- Cash left after the cart, in whole trees (Douglas small $21).
		expect.equal(SupplierCart.maxAdd({}, "DouglasFir", "Small", limits({ cash = 100 })), 4)
		expect.equal(
			SupplierCart.maxAdd({ ["DouglasFir:Small"] = 1 }, "DouglasFir", "Small", limits({ cash = 100 })),
			3
		)
		-- Bays: 9 per free bay not needed by the other species, minus this species' trees.
		expect.equal(
			SupplierCart.maxAdd(
				{ ["FrasierFir:Small"] = 5, ["DouglasFir:Small"] = 4 },
				"DouglasFir",
				"Medium",
				limits({ freeBays = 2 })
			),
			5
		)
		expect.equal(
			SupplierCart.maxAdd({ ["FrasierFir:Small"] = 10 }, "DouglasFir", "Medium", limits({ freeBays = 2 })),
			0
		)
		-- Never negative.
		expect.equal(SupplierCart.maxAdd({ ["DouglasFir:Small"] = 5 }, "DouglasFir", "Small", limits({ cash = 0 })), 0)
		expect.equal(
			SupplierCart.maxAdd(
				{ ["DouglasFir:Small"] = 8 },
				"DouglasFir",
				"Small",
				limits({ stock = lowStock, storageFree = 2, freeBays = 0 })
			),
			0
		)
	end)

	-- CM2-SUPQ: the Qty label follows every clamp or clear of the sell-back quantity.
	t.test("applySellQty writes the clamped quantity to the row label", function()
		local label = { Text = "1" }
		local sellQty: { [string]: number } = { ["DouglasFir:Small"] = 1 }
		-- Sold 1 of 1: nothing remains, the label reads 0 and the entry is gone.
		expect.equal(SupplierCart.applySellQty(sellQty, "DouglasFir:Small", 0, label), 0)
		expect.equal(label.Text, "0")
		expect.equal(sellQty["DouglasFir:Small"], nil)
		-- Sold 2 of 5 with quantity 2 selected earlier: 3 remain, quantity 2 stays valid.
		sellQty["DouglasFir:Small"] = 5
		expect.equal(SupplierCart.applySellQty(sellQty, "DouglasFir:Small", 3, label), 3)
		expect.equal(label.Text, "3")
		expect.equal(sellQty["DouglasFir:Small"], 3)
		sellQty["DouglasFir:Small"] = 2
		expect.equal(SupplierCart.applySellQty(sellQty, "DouglasFir:Small", 3, label), 2)
		expect.equal(label.Text, "2")
		-- A negative bound never produces a negative label.
		expect.equal(SupplierCart.applySellQty(sellQty, "DouglasFir:Small", -4, label), 0)
		expect.equal(label.Text, "0")
	end)
end
