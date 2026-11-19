--!strict
local GameConfig = require(script.Parent.GameConfig)
local Inventory = require(script.Parent.Inventory)

local BusinessState = {}
BusinessState.SCHEMA_VERSION = 5

local function isFiniteInteger(value: unknown): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value == math.floor(value)
end

function BusinessState.new(companyId: string?, ownerUserId: number?)
	local resolvedCompanyId = companyId or "personal:0"
	local resolvedOwnerUserId = ownerUserId or 0
	return {
		schemaVersion = BusinessState.SCHEMA_VERSION,
		companyId = resolvedCompanyId,
		ownerUserId = resolvedOwnerUserId,
		mode = "personal",
		members = { [tostring(resolvedOwnerUserId)] = "Owner" },
		revision = 0,
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
		recentRequests = {},
		updatedAt = 0,
		layout = { placements = {} },
		reservations = {},
		staff = { Cashier = 0, LotWorker = 0 },
	}
end

local function isValidLegacyV1(state): boolean
	return type(state) == "table"
		and state.schemaVersion == 1
		and isFiniteInteger(state.cash)
		and state.cash >= 0
		and isFiniteInteger(state.reputation)
		and state.reputation >= 0
		and type(state.stock) == "table"
		and type(state.pendingOrders) == "table"
		and type(state.history) == "table"
		and isFiniteInteger(state.sales)
		and state.sales >= 0
		and isFiniteInteger(state.revenue)
		and state.revenue >= 0
		and isFiniteInteger(state.spent)
		and state.spent >= 0
end

-- Migrates the original scaffold record without changing balances or stock.
function BusinessState.migrate(state, companyId: string?, ownerUserId: number?)
	if type(state) ~= "table" then
		return nil, "InvalidState"
	end
	if state.schemaVersion == BusinessState.SCHEMA_VERSION then
		return BusinessState.validate(state) and state or nil, BusinessState.validate(state) and nil or "InvalidState"
	end
	if state.schemaVersion == 2 then
		state.schemaVersion = 3
		state.layout = { placements = {} }
	end
	if state.schemaVersion == 3 then
		state.schemaVersion = 4
		state.staff = { Cashier = 0, LotWorker = 0 }
	end
	if state.schemaVersion == 4 then
		state.schemaVersion = BusinessState.SCHEMA_VERSION
		state.reservations = {}
		return BusinessState.validate(state) and state or nil, BusinessState.validate(state) and nil or "InvalidState"
	end
	if not isValidLegacyV1(state) then
		return nil, "UnsupportedSchema"
	end
	state.schemaVersion = BusinessState.SCHEMA_VERSION
	state.companyId = companyId or "personal:0"
	state.ownerUserId = ownerUserId or 0
	state.mode = "personal"
	state.members = { [tostring(state.ownerUserId)] = "Owner" }
	state.revision = 0
	state.recentRequests = {}
	state.updatedAt = 0
	state.layout = { placements = {} }
	state.reservations = {}
	state.staff = { Cashier = 0, LotWorker = 0 }
	return state, nil
end

function BusinessState.validate(state)
	if type(state) ~= "table" or state.schemaVersion ~= BusinessState.SCHEMA_VERSION then
		return false
	end
	if type(state.companyId) ~= "string" or #state.companyId < 1 or #state.companyId > 128 then
		return false
	end
	if not isFiniteInteger(state.ownerUserId) or state.ownerUserId < 0 then
		return false
	end
	if state.mode ~= "personal" and state.mode ~= "shared" then
		return false
	end
	if type(state.members) ~= "table" or state.members[tostring(state.ownerUserId)] ~= "Owner" then
		return false
	end
	if not isFiniteInteger(state.revision) or state.revision < 0 then
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
	if type(state.recentRequests) ~= "table" or not isFiniteInteger(state.updatedAt) or state.updatedAt < 0 then
		return false
	end
	if type(state.layout) ~= "table" or type(state.layout.placements) ~= "table" then
		return false
	end
	if type(state.reservations) ~= "table" then
		return false
	end
	if
		type(state.staff) ~= "table"
		or not isFiniteInteger(state.staff.Cashier)
		or not isFiniteInteger(state.staff.LotWorker)
		or state.staff.Cashier < 0
		or state.staff.LotWorker < 0
	then
		return false
	end
	if #state.recentRequests > GameConfig.MaxHistoryEntries then
		return false
	end
	for _, request in ipairs(state.recentRequests) do
		if
			type(request) ~= "table"
			or type(request.requestId) ~= "string"
			or type(request.action) ~= "string"
			or type(request.result) ~= "string"
			or not isFiniteInteger(request.at)
			or request.at < 0
		then
			return false
		end
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
	for placementId, reservation in pairs(state.reservations) do
		if
			type(placementId) ~= "string"
			or type(reservation) ~= "table"
			or type(reservation.customerId) ~= "string"
			or #reservation.customerId < 1
			or #reservation.customerId > 128
			or not isFiniteInteger(reservation.expiresAt)
			or reservation.expiresAt < 0
			or not isFiniteInteger(reservation.salePrice)
			or reservation.salePrice < 1
			or type(state.layout.placements[placementId]) ~= "table"
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

-- Creates a server-priced delivery order. Stock stays out of storage until unloaded.
function BusinessState.placeOrder(
	state,
	requestId: string,
	species: string,
	size: string,
	quantity: number,
	timestamp: number
)
	if not BusinessState.validate(state) then
		return false, "InvalidState"
	end
	if type(requestId) ~= "string" or #requestId < 8 then
		return false, "InvalidOrderId"
	end
	if not GameConfig.Trees[species] or not GameConfig.isValidSize(size) then
		return false, "InvalidItem"
	end
	if not isFiniteInteger(quantity) or quantity < 1 or quantity > GameConfig.MaxOrderQuantity then
		return false, "InvalidQuantity"
	end
	if not isFiniteInteger(timestamp) or timestamp < 0 then
		return false, "InvalidTime"
	end
	local orderId = "order:" .. requestId
	if state.pendingOrders[orderId] then
		return false, "DuplicateOrder"
	end
	local unitCost = GameConfig.wholesaleFor(species, size)
	local cost = (unitCost or 0) * quantity
	if not unitCost or state.cash < cost then
		return false, "InsufficientFunds"
	end
	state.cash -= cost
	state.spent += cost
	state.pendingOrders[orderId] = {
		orderId = orderId,
		requestId = requestId,
		speciesId = species,
		sizeId = size,
		quantity = quantity,
		createdAt = timestamp,
		dueAt = timestamp + GameConfig.DeliverySeconds,
		status = "Pending",
	}
	BusinessState.record(state, "OrderPlaced", -cost)
	return true, { orderId = orderId, cost = cost }
end

function BusinessState.reconcileDeliveries(state, timestamp: number)
	if not BusinessState.validate(state) or not isFiniteInteger(timestamp) then
		return false, "InvalidState"
	end
	for _, order in pairs(state.pendingOrders) do
		if order.status == "Pending" and order.dueAt <= timestamp then
			order.status = "Delivered"
		end
	end
	return true, nil
end

function BusinessState.unloadOrder(state, orderId: string, timestamp: number)
	if not BusinessState.validate(state) then
		return false, "InvalidState"
	end
	BusinessState.reconcileDeliveries(state, timestamp)
	local order = state.pendingOrders[orderId]
	if type(order) ~= "table" then
		return false, "UnknownOrder"
	end
	if order.status ~= "Delivered" then
		return false, "DeliveryNotReady"
	end
	local key = Inventory.key(order.speciesId, order.sizeId)
	if Inventory.count(state.stock, key) + order.quantity > GameConfig.MaxStockPerSku then
		return false, "Capacity"
	end
	if not Inventory.add(state.stock, key, order.quantity) then
		return false, "Capacity"
	end
	order.status = "Unloaded"
	BusinessState.record(state, "OrderUnloaded", 0)
	return true, orderId
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
