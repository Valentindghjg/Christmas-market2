--!strict
local GameConfig = require(script.Parent.GameConfig)
local Inventory = require(script.Parent.Inventory)

local BusinessState = {}
BusinessState.SCHEMA_VERSION = 11

local SAVE_SIZES = { Solo = true, Duo = true, Trio = true, Quad = true }

local function defaultSaveName(): string
	return string.format(GameConfig.Saves.DefaultNameFormat, 1)
end

-- Schema 11: a save name of 1 to NameMaxLength code points in valid UTF-8.
local function isValidSaveName(value: unknown): boolean
	if type(value) ~= "string" then
		return false
	end
	local length = utf8.len(value)
	return length ~= nil and length >= 1 and length <= GameConfig.Saves.NameMaxLength
end

local function isFiniteInteger(value: unknown): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value == math.floor(value)
end

-- Supplier stock starts at the configured base so a fresh company can order at once;
-- the first server refresh then rolls real availability.
function BusinessState.newSupplier()
	local stock = {}
	for speciesId in pairs(GameConfig.Trees) do
		for _, sizeId in ipairs(GameConfig.SizeIds) do
			stock[Inventory.key(speciesId, sizeId)] = GameConfig.Supplier.BaseStock[sizeId]
		end
	end
	return { refreshAt = 0, stock = stock, demand = {} }
end

-- Fields added in schema 10 (customer pickup orders, parking, supplier stock pool).
local function addSchema10Fields(state)
	state.customerOrders = {}
	state.nextOrderNumber = 1
	state.loadedOrders = 0
	state.missedPickups = 0
	state.drivePastCustomers = 0
	state.supplier = BusinessState.newSupplier()
end

-- Config limits can shrink between builds; trim instead of locking the player out.
local function normalizeSchema10(state)
	if type(state.supplier) == "table" and type(state.supplier.stock) == "table" then
		for key, quantity in pairs(state.supplier.stock) do
			if type(quantity) == "number" and quantity == quantity then
				state.supplier.stock[key] = math.clamp(math.floor(quantity), 0, 1000)
			end
		end
	end
	if type(state.customerOrders) == "table" then
		local numbers = {}
		for _, order in pairs(state.customerOrders) do
			if type(order) == "table" and type(order.orderNumber) == "number" then
				table.insert(numbers, order.orderNumber)
			end
		end
		table.sort(numbers)
		for index = GameConfig.Customers.MaxOpenCustomerOrders + 1, #numbers do
			state.customerOrders[tostring(numbers[index])] = nil
		end
	end
end

-- Nobody carries a tree in a freshly loaded session.
function BusinessState.clearCarried(state)
	if type(state.customerOrders) ~= "table" then
		return
	end
	for _, order in pairs(state.customerOrders) do
		if type(order) == "table" then
			order.carriedBy = nil
		end
	end
end

-- Every configured species starts at its catalog default (validate() requires one price per species).
local function defaultMediumPrices(): { [string]: number }
	local prices = {}
	for speciesId, tree in pairs(GameConfig.Trees) do
		prices[speciesId] = tree.initialMediumPrice
	end
	return prices
end

-- Envelope fields (_session, _deletedAt, _migratedTo, _migratedAt, _migratedFrom) belong to
-- PersistenceService; validate() ignores them.
function BusinessState.new(companyId: string?, ownerUserId: number?, saveName: string?)
	local resolvedCompanyId = companyId or "personal:0"
	local resolvedOwnerUserId = ownerUserId or 0
	return {
		schemaVersion = BusinessState.SCHEMA_VERSION,
		companyId = resolvedCompanyId,
		ownerUserId = resolvedOwnerUserId,
		saveName = saveName or defaultSaveName(),
		saveSize = "Solo",
		mode = "personal",
		members = { [tostring(resolvedOwnerUserId)] = "Owner" },
		revision = 0,
		cash = GameConfig.StartingCash,
		reputation = GameConfig.StartingReputation,
		stock = {},
		pendingOrders = {},
		sales = 0,
		customerVisits = 0,
		abandonedCustomers = 0,
		revenue = 0,
		spent = 0,
		history = {},
		mediumPrices = defaultMediumPrices(),
		autoPricing = false,
		recentRequests = {},
		updatedAt = 0,
		layout = { placements = {} },
		reservations = {},
		staff = { Cashier = 0, LotWorker = 0 },
		progression = { lotExpansion = 0, parkingSpaces = 0, hqTier = nil },
		questClaims = {},
		customerOrders = {},
		nextOrderNumber = 1,
		loadedOrders = 0,
		missedPickups = 0,
		drivePastCustomers = 0,
		supplier = BusinessState.newSupplier(),
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

-- `validate(state) and nil or "InvalidState"` always yields "InvalidState", so the
-- result pair is spelled out explicitly.
local function validated(state)
	if BusinessState.validate(state) then
		return state, nil
	end
	return nil, "InvalidState"
end

local function sales(state): number
	return if isFiniteInteger(state.sales) and state.sales > 0 then state.sales else 0
end

-- Restores any missing or corrupt per-species medium price from the catalog default.
local function backfillMediumPrices(state)
	if type(state.mediumPrices) ~= "table" then
		state.mediumPrices = {}
	end
	for speciesId, tree in pairs(GameConfig.Trees) do
		local price = state.mediumPrices[speciesId]
		if not isFiniteInteger(price) or price < 1 then
			state.mediumPrices[speciesId] = tree.initialMediumPrice
		end
	end
end

-- Migrates the original scaffold record without changing balances or stock.
function BusinessState.migrate(state, companyId: string?, ownerUserId: number?)
	if type(state) ~= "table" then
		return nil, "InvalidState"
	end
	if state.schemaVersion ~= 1 then
		backfillMediumPrices(state)
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
		state.schemaVersion = 5
		state.reservations = {}
	end
	if state.schemaVersion == 5 then
		state.schemaVersion = 6
		state.autoPricing = false
	end
	if state.schemaVersion == 6 then
		state.schemaVersion = 7
		state.progression = { lotExpansion = 0, parkingSpaces = 0, hqTier = nil }
	end
	if state.schemaVersion == 7 then
		state.schemaVersion = 8
		-- validate() requires visits >= sales; records with past sales must stay loadable.
		state.customerVisits =
			math.max(isFiniteInteger(state.customerVisits) and state.customerVisits or 0, sales(state))
		state.abandonedCustomers = 0
	end
	if state.schemaVersion == 8 then
		state.schemaVersion = 9
		state.questClaims = {}
	end
	if state.schemaVersion == 9 then
		state.schemaVersion = 10
		addSchema10Fields(state)
	end
	if state.schemaVersion == 10 then
		state.schemaVersion = 11
		if not isValidSaveName(state.saveName) then
			state.saveName = defaultSaveName()
		end
		state.saveSize = "Solo"
	end
	if state.schemaVersion == BusinessState.SCHEMA_VERSION then
		if type(state.pendingOrders) == "table" then
			BusinessState.pruneCompletedOrders(state)
		end
		BusinessState.clearCarried(state)
		normalizeSchema10(state)
		return validated(state)
	end
	if not isValidLegacyV1(state) then
		return nil, "UnsupportedSchema"
	end
	state.schemaVersion = BusinessState.SCHEMA_VERSION
	state.companyId = companyId or "personal:0"
	state.ownerUserId = ownerUserId or 0
	state.saveName = defaultSaveName()
	state.saveSize = "Solo"
	state.mode = "personal"
	state.members = { [tostring(state.ownerUserId)] = "Owner" }
	state.revision = 0
	state.autoPricing = false
	state.recentRequests = {}
	state.updatedAt = 0
	state.layout = { placements = {} }
	state.reservations = {}
	state.staff = { Cashier = 0, LotWorker = 0 }
	state.progression = { lotExpansion = 0, parkingSpaces = 0, hqTier = nil }
	state.customerVisits = sales(state)
	state.abandonedCustomers = 0
	state.questClaims = {}
	addSchema10Fields(state)
	backfillMediumPrices(state)
	return validated(state)
end

local DEMAND_TAGS = { High = true, Low = true }

local function validSupplier(supplier): boolean
	if
		type(supplier) ~= "table"
		or not isFiniteInteger(supplier.refreshAt)
		or supplier.refreshAt < 0
		or type(supplier.stock) ~= "table"
		or type(supplier.demand) ~= "table"
	then
		return false
	end
	for key, quantity in pairs(supplier.stock) do
		if type(key) ~= "string" or not isFiniteInteger(quantity) or quantity < 0 or quantity > 1000 then
			return false
		end
	end
	for key, tag in pairs(supplier.demand) do
		if type(key) ~= "string" or not DEMAND_TAGS[tag] then
			return false
		end
	end
	return true
end

local function validCustomerOrders(state): boolean
	if type(state.customerOrders) ~= "table" or not isFiniteInteger(state.nextOrderNumber) then
		return false
	end
	if state.nextOrderNumber < 1 then
		return false
	end
	local count = 0
	for key, order in pairs(state.customerOrders) do
		count += 1
		if
			type(key) ~= "string"
			or type(order) ~= "table"
			or not isFiniteInteger(order.orderNumber)
			or key ~= tostring(order.orderNumber)
			or order.orderNumber < 1
			or order.orderNumber >= state.nextOrderNumber
			or not GameConfig.Trees[order.speciesId]
			or not GameConfig.isValidSize(order.sizeId)
			or not isFiniteInteger(order.heightTenths)
			or not isFiniteInteger(order.salePrice)
			or order.salePrice < 0
			or not isFiniteInteger(order.soldAt)
			or not isFiniteInteger(order.expiresAt)
			or order.expiresAt < order.soldAt
			or not isFiniteInteger(order.parkingSpace)
			or order.parkingSpace < 1
			or (order.carriedBy ~= nil and not isFiniteInteger(order.carriedBy))
		then
			return false
		end
	end
	return count <= GameConfig.Customers.MaxOpenCustomerOrders
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
	if not isValidSaveName(state.saveName) or not SAVE_SIZES[state.saveSize] then
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
	if type(state.autoPricing) ~= "boolean" then
		return false
	end
	if type(state.mediumPrices) ~= "table" then
		return false
	end
	for speciesId in pairs(GameConfig.Trees) do
		local price = state.mediumPrices[speciesId]
		if not isFiniteInteger(price) or price < 1 then
			return false
		end
	end
	if
		type(state.progression) ~= "table"
		or not isFiniteInteger(state.progression.lotExpansion)
		or state.progression.lotExpansion < 0
		or not isFiniteInteger(state.progression.parkingSpaces)
		or state.progression.parkingSpaces < 0
		or (state.progression.hqTier ~= nil and type(state.progression.hqTier) ~= "string")
	then
		return false
	end
	if type(state.questClaims) ~= "table" then
		return false
	end
	for questId, claimed in pairs(state.questClaims) do
		if type(questId) ~= "string" or claimed ~= true then
			return false
		end
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
		or state.staff.Cashier > GameConfig.Employees.Cashier.maxCount
		or state.staff.LotWorker > GameConfig.Employees.LotWorker.maxCount
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
	if
		not isFiniteInteger(state.customerVisits)
		or state.customerVisits < state.sales
		or not isFiniteInteger(state.abandonedCustomers)
		or state.abandonedCustomers < 0
	then
		return false
	end
	if not isFiniteInteger(state.revenue) or state.revenue < 0 then
		return false
	end
	for _, counter in ipairs({ state.loadedOrders, state.missedPickups, state.drivePastCustomers }) do
		if not isFiniteInteger(counter) or counter < 0 then
			return false
		end
	end
	if not validSupplier(state.supplier) or not validCustomerOrders(state) then
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
	if BusinessState.openOrderCount(state) >= GameConfig.MaxOpenOrders then
		return false, "TooManyOpenOrders"
	end
	-- Each open order occupies one receiving bay until it is unloaded.
	if BusinessState.openOrderCount(state) >= GameConfig.Receiving.BayCount then
		return false, "NoFreeBay"
	end
	if quantity > GameConfig.Receiving.BayCapacity then
		return false, "BayCapacity"
	end
	if BusinessState.storageUsed(state) + quantity > BusinessState.storageCapacity(state) then
		return false, "StorageFull"
	end
	local supplierKey = Inventory.key(species, size)
	if Inventory.count(state.supplier.stock, supplierKey) < quantity then
		return false, "SupplierOutOfStock"
	end
	local unitCost = GameConfig.wholesaleFor(species, size)
	local cost = (unitCost or 0) * quantity
	if not unitCost or state.cash < cost then
		return false, "InsufficientFunds"
	end
	state.supplier.stock[supplierKey] -= quantity
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
	local delivered = 0
	for _, order in pairs(state.pendingOrders) do
		if order.status == "Pending" and order.dueAt <= timestamp then
			order.status = "Delivered"
			delivered += 1
		end
	end
	return true, delivered
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
	-- A completed order leaves the open-order map so the saved record stays
	-- bounded; replay protection is provided by the persisted request IDs and the
	-- history ledger keeps the audit trail.
	state.pendingOrders[orderId] = nil
	BusinessState.record(state, "OrderUnloaded", 0)
	return true, orderId
end

function BusinessState.openOrderCount(state): number
	local count = 0
	for _ in pairs(state.pendingOrders) do
		count += 1
	end
	return count
end

-- Delivery storage grows with each lot expansion (OBSERVED 30, +10 per level).
function BusinessState.storageCapacity(state): number
	local level = if type(state.progression) == "table" then state.progression.lotExpansion else 0
	return GameConfig.Receiving.BaseStorage + level * GameConfig.Receiving.StoragePerLotExpansion
end

-- Trees waiting in storage plus trees already ordered count against storage.
function BusinessState.storageUsed(state): number
	local used = 0
	for _, quantity in pairs(state.stock) do
		used += quantity
	end
	for _, order in pairs(state.pendingOrders) do
		if type(order) == "table" and isFiniteInteger(order.quantity) then
			used += order.quantity
		end
	end
	return used
end

function BusinessState.receivingSummary(state)
	local used = BusinessState.openOrderCount(state)
	return {
		baysUsed = math.min(used, GameConfig.Receiving.BayCount),
		bayCount = GameConfig.Receiving.BayCount,
		bayCapacity = GameConfig.Receiving.BayCapacity,
		storageUsed = BusinessState.storageUsed(state),
		storageCapacity = BusinessState.storageCapacity(state),
	}
end

-- Removes orders unloaded by schema versions that kept completed orders forever.
function BusinessState.pruneCompletedOrders(state): number
	local removed = 0
	for orderId, order in pairs(state.pendingOrders) do
		if type(order) == "table" and order.status == "Unloaded" then
			state.pendingOrders[orderId] = nil
			removed += 1
		end
	end
	return removed
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
