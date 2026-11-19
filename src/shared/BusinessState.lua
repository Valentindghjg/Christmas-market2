--!strict
local GameConfig = require(script.Parent.GameConfig)
local Inventory = require(script.Parent.Inventory)

local BusinessState = {}
BusinessState.SCHEMA_VERSION = 1

local function isFiniteInteger(value: unknown): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value == math.floor(value)
end

function BusinessState.new()
	return {
		schemaVersion = BusinessState.SCHEMA_VERSION,
		cash = GameConfig.StartingCash,
		reputation = GameConfig.StartingReputation,
		stock = {},
		pendingOrders = {},
		sales = 0,
		revenue = 0,
		spent = 0,
		history = {},
		mediumPrices = {
			FrasierFir = GameConfig.Trees.FrasierFir.initialMediumPrice,
			NobleFir = GameConfig.Trees.NobleFir.initialMediumPrice,
			BlueSpruce = GameConfig.Trees.BlueSpruce.initialMediumPrice,
		},
	}
end

function BusinessState.validate(state)
	if type(state) ~= "table" or state.schemaVersion ~= BusinessState.SCHEMA_VERSION then
		return false
	end
	if not isFiniteInteger(state.cash) or state.cash < 0 then
		return false
	end
	if not isFiniteInteger(state.reputation) or state.reputation < 0 then
		return false
	end
	if type(state.stock) ~= "table" or type(state.pendingOrders) ~= "table" or type(state.history) ~= "table" then
		return false
	end
	if not isFiniteInteger(state.sales) or state.sales < 0 then
		return false
	end
	if not isFiniteInteger(state.revenue) or state.revenue < 0 then
		return false
	end
	if not isFiniteInteger(state.spent) or state.spent < 0 then
		return false
	end
	for key, quantity in pairs(state.stock) do
		if
			type(key) ~= "string"
			or not isFiniteInteger(quantity)
			or quantity < 0
			or quantity > GameConfig.MaxStockPerSku
		then
			return false
		end
	end
	return true
end

function BusinessState.record(state, eventType: string, amount: number)
	local history = state.history
	table.insert(history, { kind = eventType, amount = amount, at = os.time() })
	while #history > GameConfig.MaxHistoryEntries do
		table.remove(history, 1)
	end
end

-- Cost is always obtained from GameConfig; a caller never provides it.
function BusinessState.buyStock(state, species: string, size: string, quantity: number)
	if not BusinessState.validate(state) then
		return false, "InvalidState"
	end
	if not GameConfig.Trees[species] then
		return false, "UnknownSpecies"
	end
	if not GameConfig.isValidSize(size) then
		return false, "InvalidSize"
	end
	if not isFiniteInteger(quantity) or quantity < 1 or quantity > GameConfig.MaxOrderQuantity then
		return false, "InvalidQuantity"
	end
	local unitCost = GameConfig.wholesaleFor(species, size)
	if not unitCost then
		return false, "InvalidPrice"
	end
	local cost = quantity * unitCost
	if state.cash < cost then
		return false, "InsufficientFunds"
	end
	local key = Inventory.key(species, size)
	if Inventory.count(state.stock, key) + quantity > GameConfig.MaxStockPerSku then
		return false, "Capacity"
	end
	if not Inventory.add(state.stock, key, quantity) then
		return false, "Capacity"
	end
	state.cash -= cost
	state.spent += cost
	BusinessState.record(state, "Purchase", -cost)
	return true, cost
end

function BusinessState.sellStock(state, species: string, size: string, salePrice: number)
	if not BusinessState.validate(state) then
		return false, "InvalidState"
	end
	if not GameConfig.Trees[species] then
		return false, "UnknownSpecies"
	end
	if not GameConfig.isValidSize(size) then
		return false, "InvalidSize"
	end
	if not isFiniteInteger(salePrice) or salePrice < 0 or salePrice > 100000 then
		return false, "InvalidPrice"
	end
	local key = Inventory.key(species, size)
	if not Inventory.remove(state.stock, key, 1) then
		return false, "OutOfStock"
	end
	state.cash += salePrice
	state.revenue += salePrice
	state.sales += 1
	BusinessState.record(state, "Sale", salePrice)
	return true, salePrice
end

return BusinessState
