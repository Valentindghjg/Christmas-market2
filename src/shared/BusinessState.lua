--!strict
local GameConfig = require(script.Parent.GameConfig)
local Inventory = require(script.Parent.Inventory)
local Receiving = require(script.Parent.Receiving)
local SaveProfile = require(script.Parent.SaveProfile)

local BusinessState = {}
BusinessState.SCHEMA_VERSION = 14

local SAVE_SIZES = { Solo = true, Duo = true, Trio = true, Quad = true }
local MEMBER_ROLES = { Owner = true, Member = true }

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

-- Schema 12 member map with only the owner. A record without a valid owner ID gets an empty
-- map, which validate() then rejects.
local function ownerOnlyMembers(ownerUserId: unknown): { [string]: string }
	if not isFiniteInteger(ownerUserId) then
		return {}
	end
	return { [SaveProfile.userIdText(ownerUserId :: number)] = "Owner" }
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

-- No customer NPC survives a reload (CM2-N1), so a freshly loaded session holds no reservation.
function BusinessState.clearReservations(state)
	if type(state.reservations) == "table" then
		state.reservations = {}
	end
end

-- Every configured species starts at its catalog default (validate() requires one price per species).
local function defaultMediumPrices(): { [string]: number }
	local prices = {}
	for speciesId in pairs(GameConfig.Trees) do
		prices[speciesId] = GameConfig.typicalMediumFor(speciesId) :: number
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
		members = { [SaveProfile.userIdText(resolvedOwnerUserId)] = "Owner" },
		inviteCode = nil,
		revision = 0,
		cash = GameConfig.StartingCash,
		reputation = GameConfig.StartingReputation,
		bays = Receiving.newBays(),
		pendingOrders = {},
		sales = 0,
		customerVisits = 0,
		abandonedCustomers = 0,
		walkedOutCustomers = 0,
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
	for speciesId in pairs(GameConfig.Trees) do
		local price = state.mediumPrices[speciesId]
		if not isFiniteInteger(price) or price < 1 then
			state.mediumPrices[speciesId] = GameConfig.typicalMediumFor(speciesId) :: number
		end
	end
end

-- Schema 13 (CM2-G14): stored stock and pending orders move into the receiving bays; trees
-- and orders that do not fit are refunded at wholesale, so no tree value is lost.
local function applyStockMigration(state)
	local refund = Receiving.migrateStock(state)
	if refund > 0 and type(state.cash) == "number" and type(state.history) == "table" then
		state.cash += refund
		BusinessState.record(state, "MigrationRefund", refund)
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
	if state.schemaVersion == 11 then
		state.schemaVersion = 12
		-- Other roles were never writable in production, so only the owner is kept.
		state.members = ownerOnlyMembers(state.ownerUserId)
		state.inviteCode = nil
	end
	if state.schemaVersion == 12 then
		state.schemaVersion = 13
		applyStockMigration(state)
	end
	if state.schemaVersion == 13 then
		state.schemaVersion = 14
		state.walkedOutCustomers = 0
	end
	if state.schemaVersion == BusinessState.SCHEMA_VERSION then
		if type(state.pendingOrders) == "table" then
			BusinessState.pruneCompletedOrders(state)
		end
		Receiving.normalize(state)
		BusinessState.clearCarried(state)
		BusinessState.clearReservations(state)
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
	state.members = ownerOnlyMembers(state.ownerUserId)
	state.inviteCode = nil
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
	state.walkedOutCustomers = 0
	state.questClaims = {}
	addSchema10Fields(state)
	backfillMediumPrices(state)
	applyStockMigration(state)
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

-- Co-op saves (schema 12, CM2-S2) ------------------------------------------------------------

-- A 5-digit invite code without a leading zero.
function BusinessState.isInviteCode(value: unknown): boolean
	return type(value) == "string" and string.match(value, "^[1-9]%d%d%d%d$") ~= nil
end

function BusinessState.seatsFor(size: unknown): number?
	if type(size) ~= "string" then
		return nil
	end
	return GameConfig.Saves.Seats[size]
end

function BusinessState.memberCount(state): number
	local count = 0
	for _ in pairs(state.members) do
		count += 1
	end
	return count
end

-- code == nil is for trusted server callers only; Save.Join always passes the typed code.
function BusinessState.addMember(state, userId: number, code: string?)
	local key = SaveProfile.userIdText(userId)
	if state.members[key] ~= nil then
		return true, { outcome = "AlreadyMember", size = state.saveSize }
	end
	if code ~= nil and (state.saveSize == "Solo" or state.inviteCode ~= code) then
		return false, "InviteCodeInvalid"
	end
	local seats = BusinessState.seatsFor(state.saveSize) or 0
	if BusinessState.memberCount(state) >= seats then
		return false, "SaveFull"
	end
	state.members[key] = "Member"
	return true, { outcome = "Joined", size = state.saveSize }
end

function BusinessState.removeMember(state, userId: number)
	local key = SaveProfile.userIdText(userId)
	local role = state.members[key]
	if role == "Owner" then
		return false, "OwnerCannotLeave"
	end
	if role == nil then
		return false, "NotAMember"
	end
	state.members[key] = nil
	return true
end

-- expected is the code the caller saw; a different current code means someone changed it.
function BusinessState.setInviteCode(state, code: string?, expected: string?)
	if code ~= nil and state.saveSize == "Solo" then
		return false, "SoloHasNoCode"
	end
	if state.inviteCode ~= expected then
		return false, "CodeChanged"
	end
	state.inviteCode = code
	return true
end

-- Returns the cleared code when the save becomes Solo, so the caller can release it.
function BusinessState.setSaveSize(state, size: unknown)
	local seats = BusinessState.seatsFor(size)
	if seats == nil then
		return false, "InvalidSize"
	end
	if size == state.saveSize then
		return true, nil
	end
	if BusinessState.memberCount(state) > seats then
		return false, "SizeTooSmall"
	end
	state.saveSize = size
	if size == "Solo" then
		local previousCode = state.inviteCode
		state.inviteCode = nil
		return true, previousCode
	end
	return true, nil
end

-- Exactly one Owner at the owner's ID, only Owner/Member roles, decimal user-ID keys, at most
-- the seats of the save size; an invite code only on Duo or larger saves.
local function validMembers(state): boolean
	if type(state.members) ~= "table" then
		return false
	end
	local owners = 0
	local count = 0
	for key, role in pairs(state.members) do
		if type(key) ~= "string" or #key < 1 or #key > 19 or string.match(key, "^%d+$") == nil then
			return false
		end
		if not MEMBER_ROLES[role] then
			return false
		end
		if role == "Owner" then
			owners += 1
		end
		count += 1
	end
	if owners ~= 1 or state.members[SaveProfile.userIdText(state.ownerUserId)] ~= "Owner" then
		return false
	end
	local seats = BusinessState.seatsFor(state.saveSize)
	if seats == nil or count > seats then
		return false
	end
	if state.inviteCode ~= nil then
		if state.saveSize == "Solo" or not BusinessState.isInviteCode(state.inviteCode) then
			return false
		end
	end
	return true
end

-- Schema 13 (CM2-G14): exactly BayCount bays {speciesId, counts}. Capacity is enforced only on
-- mutation, never here, so no save gets locked out.
local function validBays(state): boolean
	local bays = state.bays
	if type(bays) ~= "table" then
		return false
	end
	local entries = 0
	for key in pairs(bays) do
		if not isFiniteInteger(key) or key < 1 or key > Receiving.BayCount then
			return false
		end
		entries += 1
	end
	if entries ~= Receiving.BayCount then
		return false
	end
	for index = 1, Receiving.BayCount do
		local bay = bays[index]
		if type(bay) ~= "table" or type(bay.speciesId) ~= "string" or type(bay.counts) ~= "table" then
			return false
		end
		if bay.speciesId ~= "" and not GameConfig.Trees[bay.speciesId] then
			return false
		end
		for sizeId, quantity in pairs(bay.counts) do
			if
				not GameConfig.isValidSize(sizeId)
				or not isFiniteInteger(quantity)
				or quantity < 1
				or quantity > 1000
			then
				return false
			end
		end
		if bay.speciesId == "" and next(bay.counts) ~= nil then
			return false
		end
	end
	return true
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
	if not validMembers(state) then
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
	if not validBays(state) or type(state.pendingOrders) ~= "table" or type(state.history) ~= "table" then
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
	if not isFiniteInteger(state.walkedOutCustomers) or state.walkedOutCustomers < 0 then
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

-- Creates a server-priced delivery order in its own receiving bay. The trees land in the bay
-- by themselves at dueAt (reconcileDeliveries); cost is always obtained from GameConfig.
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
	-- One order = one bay (OBSERVED "Bays n/4"); a bay is busy while it holds trees or an order.
	local bay = Receiving.freeBay(state)
	if bay == nil then
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
		bay = bay,
	}
	state.bays[bay].speciesId = species
	BusinessState.record(state, "OrderPlaced", -cost)
	return true, { orderId = orderId, cost = cost, bay = bay }
end

local function isBayIndex(value: unknown): boolean
	return isFiniteInteger(value) and (value :: number) >= 1 and (value :: number) <= Receiving.BayCount
end

-- Due orders land in their bay by themselves (OBSERVED: "The player does not unload"). An
-- order without a usable bay stays pending. A completed order leaves the open-order map so
-- the saved record stays bounded; the persisted request IDs keep replay protection and the
-- history ledger keeps the audit trail.
function BusinessState.reconcileDeliveries(state, timestamp: number)
	if not BusinessState.validate(state) or not isFiniteInteger(timestamp) then
		return false, "InvalidState"
	end
	local due = {}
	for orderId, order in pairs(state.pendingOrders) do
		if type(order) == "table" and isFiniteInteger(order.dueAt) and order.dueAt <= timestamp then
			table.insert(due, { orderId = orderId, order = order })
		end
	end
	table.sort(due, function(a, b)
		if a.order.dueAt ~= b.order.dueAt then
			return a.order.dueAt < b.order.dueAt
		end
		return a.orderId < b.orderId
	end)
	local delivered = 0
	for _, entry in ipairs(due) do
		local order = entry.order
		local bay = if isBayIndex(order.bay) then order.bay else Receiving.freeBay(state)
		if bay ~= nil and Receiving.add(state, bay, order.speciesId, order.sizeId, order.quantity) then
			state.pendingOrders[entry.orderId] = nil
			BusinessState.record(state, "OrderUnloaded", 0)
			delivered += 1
		end
	end
	return true, delivered
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

-- Trees waiting in the bays plus trees already ordered count against storage.
function BusinessState.storageUsed(state): number
	local used = Receiving.storedTotal(state)
	for _, order in pairs(state.pendingOrders) do
		if type(order) == "table" and isFiniteInteger(order.quantity) then
			used += order.quantity
		end
	end
	return used
end

function BusinessState.receivingSummary(state, now: number?)
	return {
		baysUsed = Receiving.usedCount(state),
		bayCount = GameConfig.Receiving.BayCount,
		bayCapacity = GameConfig.Receiving.BayCapacity,
		storageUsed = BusinessState.storageUsed(state),
		storageCapacity = BusinessState.storageCapacity(state),
		bays = Receiving.view(state, now or 0),
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

return BusinessState
