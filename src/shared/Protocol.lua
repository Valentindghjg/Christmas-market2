--!strict
-- Shared validation for untrusted client actions. The server owns all prices and state changes.
local GameConfig = require(script.Parent.GameConfig)
local SaveProfile = require(script.Parent.SaveProfile)

local Protocol = {}
Protocol.VERSION = 1
Protocol.Actions = {
	SupplierPlaceOrder = "Supplier.PlaceOrder",
	SupplierRequestQuote = "Supplier.RequestQuote",
	DeliveryUnload = "Delivery.Unload",
	InventoryPlace = "Inventory.Place",
	InventoryPickup = "Inventory.Pickup",
	PricingSetMediumPrice = "Pricing.SetMediumPrice",
	PricingSetAuto = "Pricing.SetAuto",
	EmployeeHire = "Employee.Hire",
	ProgressionBuyLotExpansion = "Progression.BuyLotExpansion",
	ProgressionBuyParking = "Progression.BuyParking",
	ProgressionBuyHQ = "Progression.BuyHQ",
	CompanyGetSummary = "Company.GetSummary",
	QuestClaim = "Quest.Claim",
	OrderCarry = "Order.Carry",
	OrderLoad = "Order.Load",
	OrderRelease = "Order.Release",
	SupplierSellBack = "Supplier.SellBack",
}

local actionSet = {
	[Protocol.Actions.OrderCarry] = true,
	[Protocol.Actions.OrderLoad] = true,
	[Protocol.Actions.OrderRelease] = true,
	[Protocol.Actions.SupplierSellBack] = true,
	[Protocol.Actions.SupplierPlaceOrder] = true,
	[Protocol.Actions.SupplierRequestQuote] = true,
	[Protocol.Actions.DeliveryUnload] = true,
	[Protocol.Actions.InventoryPlace] = true,
	[Protocol.Actions.InventoryPickup] = true,
	[Protocol.Actions.PricingSetMediumPrice] = true,
	[Protocol.Actions.PricingSetAuto] = true,
	[Protocol.Actions.EmployeeHire] = true,
	[Protocol.Actions.ProgressionBuyLotExpansion] = true,
	[Protocol.Actions.ProgressionBuyParking] = true,
	[Protocol.Actions.ProgressionBuyHQ] = true,
	[Protocol.Actions.CompanyGetSummary] = true,
	[Protocol.Actions.QuestClaim] = true,
}

-- Save-slot actions travel through their own remote (Remotes.SaveAction).
Protocol.SaveActions = {
	List = "Save.List",
	Create = "Save.Create",
	Rename = "Save.Rename",
	Delete = "Save.Delete",
	Play = "Save.Play",
	-- Co-op saves (CM2-S2).
	Join = "Save.Join",
	LeaveTeam = "Save.LeaveTeam",
	Team = "Save.Team",
	RemoveMember = "Save.RemoveMember",
	RegenerateCode = "Save.RegenerateCode",
	SetSize = "Save.SetSize",
}

local saveActionSet = {}
for _, action in pairs(Protocol.SaveActions) do
	saveActionSet[action] = true
end

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

local function isFiniteNumber(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local TRANSFORM_KEYS = { x = true, y = true, z = true, rotation = true }

local function isOrderNumber(value: unknown): boolean
	return isFiniteInteger(value) and (value :: number) >= 1 and (value :: number) < 2 ^ 31
end

local function hasOnlyKeys(payload, allowed)
	for key in pairs(payload) do
		if not allowed[key] then
			return false
		end
	end
	return true
end

-- Envelope checks shared by business and save requests.
local function validateEnvelope(request, actions): (boolean, string?)
	if type(request) ~= "table" then
		return false, "MalformedRequest"
	end
	if request.version ~= Protocol.VERSION then
		return false, "UnsupportedVersion"
	end
	if not isRequestId(request.requestId) then
		return false, "InvalidRequestId"
	end
	if type(request.action) ~= "string" or not actions[request.action] then
		return false, "UnknownAction"
	end
	if type(request.payload) ~= "table" then
		return false, "MalformedPayload"
	end
	return true, nil
end

function Protocol.validateRequest(request)
	local envelopeOk, envelopeError = validateEnvelope(request, actionSet)
	if not envelopeOk then
		return false, envelopeError
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
	if request.action == Protocol.Actions.CompanyGetSummary then
		if not hasOnlyKeys(request.payload, {}) then
			return false, "UnexpectedField"
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
		local transform = request.payload.transform
		if not GameConfig.isValidSize(request.payload.sizeId) or type(transform) ~= "table" then
			return false, "InvalidPlacement"
		end
		if
			not hasOnlyKeys(transform, TRANSFORM_KEYS)
			or not isFiniteNumber(transform.x)
			or not isFiniteNumber(transform.y)
			or not isFiniteNumber(transform.z)
			or not isFiniteNumber(transform.rotation)
		then
			return false, "InvalidPlacement"
		end
		return true, nil
	end
	if request.action == Protocol.Actions.InventoryPickup then
		if
			not hasOnlyKeys(request.payload, { placementId = true })
			or type(request.payload.placementId) ~= "string"
			or #request.payload.placementId > 96
		then
			return false, "InvalidPlacementId"
		end
		return true, nil
	end
	if request.action == Protocol.Actions.PricingSetMediumPrice then
		if not hasOnlyKeys(request.payload, { speciesId = true, mediumPrice = true }) then
			return false, "UnexpectedField"
		end
		if type(request.payload.speciesId) ~= "string" or not GameConfig.Trees[request.payload.speciesId] then
			return false, "UnknownSpecies"
		end
		if not isFiniteInteger(request.payload.mediumPrice) then
			return false, "InvalidPrice"
		end
		return true, nil
	end
	if request.action == Protocol.Actions.PricingSetAuto then
		if not hasOnlyKeys(request.payload, { enabled = true }) or type(request.payload.enabled) ~= "boolean" then
			return false, "InvalidAutoPrice"
		end
		return true, nil
	end
	if request.action == Protocol.Actions.EmployeeHire then
		if
			not hasOnlyKeys(request.payload, { employeeId = true })
			or (request.payload.employeeId ~= "Cashier" and request.payload.employeeId ~= "LotWorker")
		then
			return false, "UnknownEmployee"
		end
		return true, nil
	end
	if
		request.action == Protocol.Actions.ProgressionBuyLotExpansion
		or request.action == Protocol.Actions.ProgressionBuyParking
	then
		if not hasOnlyKeys(request.payload, {}) then
			return false, "UnexpectedField"
		end
		return true, nil
	end
	if request.action == Protocol.Actions.ProgressionBuyHQ then
		if not hasOnlyKeys(request.payload, { hqId = true }) or request.payload.hqId ~= "ChristmasPavilion" then
			return false, "InvalidHQ"
		end
		return true, nil
	end
	if request.action == Protocol.Actions.OrderCarry or request.action == Protocol.Actions.OrderRelease then
		if not hasOnlyKeys(request.payload, { orderNumber = true }) then
			return false, "UnexpectedField"
		end
		if not isOrderNumber(request.payload.orderNumber) then
			return false, "InvalidOrderNumber"
		end
		return true, nil
	end
	if request.action == Protocol.Actions.OrderLoad then
		if not hasOnlyKeys(request.payload, { orderNumber = true, carNumber = true }) then
			return false, "UnexpectedField"
		end
		if not isOrderNumber(request.payload.orderNumber) or not isOrderNumber(request.payload.carNumber) then
			return false, "InvalidOrderNumber"
		end
		return true, nil
	end
	if request.action == Protocol.Actions.SupplierSellBack then
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
	if request.action == Protocol.Actions.QuestClaim then
		if
			not hasOnlyKeys(request.payload, { questId = true })
			or type(request.payload.questId) ~= "string"
			or not GameConfig.Quests[request.payload.questId]
		then
			return false, "InvalidQuest"
		end
		return true, nil
	end

	return false, "UnknownAction"
end

local function isNameText(value: unknown): boolean
	return type(value) == "string" and #value <= GameConfig.Saves.NamePayloadMaxBytes
end

local function isSaveSize(value: unknown): boolean
	return type(value) == "string" and GameConfig.Saves.Seats[value] ~= nil
end

local function isInviteCode(value: unknown): boolean
	return type(value) == "string" and string.match(value, "^[1-9]%d%d%d%d$") ~= nil
end

local function isUserId(value: unknown): boolean
	return isFiniteInteger(value) and (value :: number) >= 1 and (value :: number) <= 2 ^ 53
end

local SAVE_PAYLOAD_KEYS = {
	[Protocol.SaveActions.List] = {},
	[Protocol.SaveActions.Create] = { name = true, size = true },
	[Protocol.SaveActions.Rename] = { saveId = true, name = true },
	[Protocol.SaveActions.Delete] = { saveId = true, confirmName = true },
	[Protocol.SaveActions.Play] = { saveId = true },
	[Protocol.SaveActions.Join] = { code = true },
	[Protocol.SaveActions.LeaveTeam] = { saveId = true },
	[Protocol.SaveActions.Team] = {},
	[Protocol.SaveActions.RemoveMember] = { userId = true },
	[Protocol.SaveActions.RegenerateCode] = {},
	[Protocol.SaveActions.SetSize] = { size = true },
}

-- Save-slot requests (CM2-S1) use the same envelope as business requests.
function Protocol.validateSaveRequest(request)
	local envelopeOk, envelopeError = validateEnvelope(request, saveActionSet)
	if not envelopeOk then
		return false, envelopeError
	end
	local action = request.action
	local payload = request.payload
	if not hasOnlyKeys(payload, SAVE_PAYLOAD_KEYS[action]) then
		return false, "UnexpectedField"
	end
	if SAVE_PAYLOAD_KEYS[action].saveId and not SaveProfile.isSaveId(payload.saveId) then
		return false, "InvalidSaveId"
	end
	if action == Protocol.SaveActions.Create then
		if payload.name ~= nil and not isNameText(payload.name) then
			return false, "InvalidName"
		end
		-- An absent size creates a Solo save.
		if payload.size ~= nil and not isSaveSize(payload.size) then
			return false, "InvalidSize"
		end
	elseif action == Protocol.SaveActions.Join then
		if not isInviteCode(payload.code) then
			return false, "InvalidInviteCode"
		end
	elseif action == Protocol.SaveActions.RemoveMember then
		if not isUserId(payload.userId) then
			return false, "InvalidUserId"
		end
	elseif action == Protocol.SaveActions.SetSize then
		if not isSaveSize(payload.size) then
			return false, "InvalidSize"
		end
	elseif action == Protocol.SaveActions.Rename then
		if not isNameText(payload.name) then
			return false, "InvalidName"
		end
	elseif action == Protocol.SaveActions.Delete then
		if not isNameText(payload.confirmName) then
			return false, "InvalidName"
		end
	end
	return true, nil
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

-- Drops a departed player's buckets so long-running servers do not accumulate them.
function Protocol.forgetUser(limiter, playerUserId: number)
	local prefix = tostring(playerUserId) .. ":"
	for key in pairs(limiter.buckets) do
		if string.sub(key, 1, #prefix) == prefix then
			limiter.buckets[key] = nil
		end
	end
end

-- Counts the entries inside the window without recording a new one (CM2-S2 join lockout).
function Protocol.recentCount(limiter, playerUserId: number, action: string, timestamp: number): number
	local bucket = limiter.buckets[tostring(playerUserId) .. ":" .. action]
	if bucket == nil then
		return 0
	end
	local cutoff = timestamp - limiter.windowSeconds
	local count = 0
	for _, previous in ipairs(bucket) do
		if previous > cutoff then
			count += 1
		end
	end
	return count
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
