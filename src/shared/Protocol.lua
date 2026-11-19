--!strict
-- Shared validation for untrusted client actions. The server owns all prices and state changes.
local GameConfig = require(script.Parent.GameConfig)

local Protocol = {}
Protocol.VERSION = 1
Protocol.Actions = {
	SupplierPlaceOrder = "Supplier.PlaceOrder",
	SupplierRequestQuote = "Supplier.RequestQuote",
	DeliveryUnload = "Delivery.Unload",
	InventoryPlace = "Inventory.Place",
	InventoryPickup = "Inventory.Pickup",
}

local actionSet = {
	[Protocol.Actions.SupplierPlaceOrder] = true,
	[Protocol.Actions.SupplierRequestQuote] = true,
	[Protocol.Actions.DeliveryUnload] = true,
	[Protocol.Actions.InventoryPlace] = true,
	[Protocol.Actions.InventoryPickup] = true,
}

local function isFiniteInteger(value: unknown): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value == math.floor(value)
end

local function isRequestId(value: unknown): boolean
	return type(value) == "string" and #value >= 8 and #value <= 64 and value:match("^[%w_%-]+$") ~= nil
end

local function hasOnlyKeys(payload, allowed)
	for key in pairs(payload) do
		if not allowed[key] then
			return false
		end
	end
	return true
end

function Protocol.validateRequest(request)
	if type(request) ~= "table" then
		return false, "MalformedRequest"
	end
	if request.version ~= Protocol.VERSION then
		return false, "UnsupportedVersion"
	end
	if not isRequestId(request.requestId) then
		return false, "InvalidRequestId"
	end
	if type(request.action) ~= "string" or not actionSet[request.action] then
		return false, "UnknownAction"
	end
	if type(request.payload) ~= "table" then
		return false, "MalformedPayload"
	end

	if request.action == Protocol.Actions.SupplierPlaceOrder then
		if not hasOnlyKeys(request.payload, { speciesId = true, sizeId = true, quantity = true }) then
			return false, "UnexpectedField"
		end
		if type(request.payload.speciesId) ~= "string" or not GameConfig.Trees[request.payload.speciesId] then
			return false, "UnknownSpecies"
		end
		if not GameConfig.isValidSize(request.payload.sizeId) then
			return false, "InvalidSize"
		end
		if
			not isFiniteInteger(request.payload.quantity)
			or request.payload.quantity < 1
			or request.payload.quantity > GameConfig.MaxOrderQuantity
		then
			return false, "InvalidQuantity"
		end
		return true, nil
	end
	if request.action == Protocol.Actions.SupplierRequestQuote then
		if not hasOnlyKeys(request.payload, { speciesId = true, sizeId = true }) then
			return false, "UnexpectedField"
		end
		if type(request.payload.speciesId) ~= "string" or not GameConfig.Trees[request.payload.speciesId] then
			return false, "UnknownSpecies"
		end
		if not GameConfig.isValidSize(request.payload.sizeId) then
			return false, "InvalidSize"
		end
		return true, nil
	end
	if request.action == Protocol.Actions.DeliveryUnload then
		if not hasOnlyKeys(request.payload, { orderId = true }) then
			return false, "UnexpectedField"
		end
		if
			type(request.payload.orderId) ~= "string"
			or #request.payload.orderId < 8
			or #request.payload.orderId > 80
		then
			return false, "InvalidOrderId"
		end
		return true, nil
	end
	if request.action == Protocol.Actions.InventoryPlace then
		if not hasOnlyKeys(request.payload, { speciesId = true, sizeId = true, transform = true }) then
			return false, "UnexpectedField"
		end
		if type(request.payload.speciesId) ~= "string" or not GameConfig.Trees[request.payload.speciesId] then
			return false, "UnknownSpecies"
		end
		if not GameConfig.isValidSize(request.payload.sizeId) or type(request.payload.transform) ~= "table" then
			return false, "InvalidPlacement"
		end
		return true, nil
	end
	if request.action == Protocol.Actions.InventoryPickup then
		if
			not hasOnlyKeys(request.payload, { placementId = true })
			or type(request.payload.placementId) ~= "string"
		then
			return false, "InvalidPlacementId"
		end
		return true, nil
	end

	return false, "UnknownAction"
end

function Protocol.findRequest(state, requestId: string)
	for _, record in ipairs(state.recentRequests) do
		if record.requestId == requestId then
			return record
		end
	end
	return nil
end

-- Records a request before its mutation, so replay cannot cause a second debit.
function Protocol.beginRequest(state, requestId: string, action: string, timestamp: number)
	local existing = Protocol.findRequest(state, requestId)
	if existing then
		return false, existing
	end
	local record = { requestId = requestId, action = action, at = timestamp, result = "Pending" }
	table.insert(state.recentRequests, record)
	while #state.recentRequests > GameConfig.MaxHistoryEntries do
		table.remove(state.recentRequests, 1)
	end
	return true, record
end

function Protocol.finishRequest(record, result: string)
	record.result = result
end

function Protocol.newRateLimiter(limit: number?, windowSeconds: number?)
	return {
		limit = limit or 10,
		windowSeconds = windowSeconds or 10,
		buckets = {},
	}
end

function Protocol.allowRequest(limiter, playerUserId: number, action: string, timestamp: number): boolean
	local key = tostring(playerUserId) .. ":" .. action
	local bucket = limiter.buckets[key] or {}
	local cutoff = timestamp - limiter.windowSeconds
	local kept = {}
	for _, previous in ipairs(bucket) do
		if previous > cutoff then
			table.insert(kept, previous)
		end
	end
	if #kept >= limiter.limit then
		limiter.buckets[key] = kept
		return false
	end
	table.insert(kept, timestamp)
	limiter.buckets[key] = kept
	return true
end

return Protocol
