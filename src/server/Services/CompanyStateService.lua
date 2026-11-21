--!strict
-- Serializes all authoritative company mutations behind one in-memory session per company.
--
-- Persistence model: every mutation runs to completion inside the company's critical
-- section without yielding, then marks the session dirty. flushDirty() writes the whole
-- record atomically (at most once per GameConfig.SaveFlushSeconds when driven by the
-- server loop), and every healthy session is re-saved at least once per
-- GameConfig.AutosaveSeconds to renew its lock. Because balances, inventory, orders and
-- request IDs live in one record, a crash can only roll a company back to its last
-- consistent save; it can never persist a debit without its matching effect.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BusinessState = require(Shared:WaitForChild("BusinessState"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Protocol = require(Shared:WaitForChild("Protocol"))
local SupplierCatalog = require(Shared:WaitForChild("SupplierCatalog"))
local AnalyticsService = require(script.Parent:WaitForChild("AnalyticsService"))
local CustomerSimulationService = require(script.Parent:WaitForChild("CustomerSimulationService"))
local EmployeeService = require(script.Parent:WaitForChild("EmployeeService"))
local PlacementService = require(script.Parent:WaitForChild("PlacementService"))
local PricingService = require(script.Parent:WaitForChild("PricingService"))
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))
local QuestService = require(script.Parent:WaitForChild("QuestService"))

local CompanyStateService = {}
CompanyStateService.__index = CompanyStateService

-- Persistence results that mean this server no longer owns a valid writable session.
local FAIL_CLOSED_SAVE_ERRORS = { SessionLocked = true, NotLoaded = true }

local function now(): number
	return os.time()
end

function CompanyStateService.new(persistence, clock, randomRoll)
	local self = setmetatable({}, CompanyStateService)
	self._persistence = persistence
	self._clock = clock or now
	self._randomRoll = randomRoll or math.random
	self._sessions = {}
	self._loading = {}
	self._limiter = Protocol.newRateLimiter(10, 10)
	-- Caps a player's total request volume across all actions.
	self._globalLimiter = Protocol.newRateLimiter(40, 10)
	self._customerSequence = 0
	self._placementsChanged = nil
	return self
end

-- Trusted server code (world visuals) subscribes to authoritative display changes.
function CompanyStateService:setPlacementsChangedHandler(handler)
	self._placementsChanged = handler
end

function CompanyStateService:loadPersonalCompany(userId: number)
	local companyId = "personal:" .. tostring(userId)
	-- A previous session may still be saving after a fast rejoin to this server.
	-- Loading now would let that unload release the lock under the new session.
	if self._sessions[companyId] or self._loading[companyId] then
		return nil, "SessionBusy"
	end
	self._loading[companyId] = true
	local called, state, errorCode = pcall(self._persistence.load, self._persistence, companyId, userId)
	self._loading[companyId] = nil
	if not called then
		return nil, "LoadFailed:" .. tostring(state)
	end
	if not state then
		return nil, errorCode
	end
	self._sessions[companyId] = {
		state = state,
		busy = false,
		healthy = true,
		corrupt = false,
		unloading = false,
		saving = false,
		dirty = false,
		lastSavedAt = self._clock(),
	}
	return state, nil
end

function CompanyStateService:isAvailable(companyId: string): boolean
	local session = self._sessions[companyId]
	return session ~= nil and session.healthy and not session.unloading
end

function CompanyStateService:isDirty(companyId: string): boolean
	local session = self._sessions[companyId]
	return session ~= nil and session.dirty
end

function CompanyStateService:_companyIds(): { string }
	local ids = {}
	for companyId in pairs(self._sessions) do
		table.insert(ids, companyId)
	end
	table.sort(ids)
	return ids
end

function CompanyStateService:_enter(session)
	while session.busy do
		task.wait()
	end
	session.busy = true
end

function CompanyStateService:_leave(session)
	session.busy = false
end

-- Runs fn(state) inside the company's critical section. fn must not yield. A runtime
-- error releases the section and fails the session closed (it is never saved again),
-- instead of leaving it busy forever and stalling every later caller and server loop.
function CompanyStateService:_withSession(companyId: string, session, fn)
	self:_enter(session)
	if not session.healthy or session.unloading or self._sessions[companyId] ~= session then
		self:_leave(session)
		return false, "CompanyUnavailable", nil
	end
	local ok, first, second = pcall(fn, session.state)
	self:_leave(session)
	if not ok then
		session.healthy = false
		session.corrupt = true
		warn(
			string.format("[ChristmasMarket2] %s failed closed after an internal error: %s", companyId, tostring(first))
		)
		return false, "InternalError", nil
	end
	return true, first, second
end

-- Saves the live record once. Concurrent callers wait for an in-flight save first.
function CompanyStateService:_save(companyId: string, session): (boolean, string?)
	while session.saving do
		task.wait()
	end
	session.saving = true
	session.dirty = false
	local called, saved, errorCode = pcall(self._persistence.save, self._persistence, companyId, session.state)
	session.saving = false
	if called and saved then
		session.lastSavedAt = self._clock()
		return true, nil
	end
	session.dirty = true
	local reason = if called then tostring(errorCode) else "SaveFailed:" .. tostring(saved)
	if FAIL_CLOSED_SAVE_ERRORS[reason] or self._clock() - session.lastSavedAt >= GameConfig.SaveFailClosedSeconds then
		session.healthy = false
	end
	return false, reason
end

-- Persists dirty sessions plus any session whose lock renewal is due. force saves
-- every healthy session. Returns ok, savedCount, failureCount.
function CompanyStateService:flushDirty(force: boolean?)
	local failures = 0
	local saved = 0
	for _, companyId in ipairs(self:_companyIds()) do
		local session = self._sessions[companyId]
		if session and session.healthy and not session.unloading and not session.saving then
			local renewalDue = self._clock() - session.lastSavedAt >= GameConfig.AutosaveSeconds
			if force or session.dirty or renewalDue then
				if self:_save(companyId, session) then
					saved += 1
				else
					failures += 1
				end
			end
		end
	end
	return failures == 0, saved, failures
end

function CompanyStateService:autosaveAll()
	return self:flushDirty(true)
end

function CompanyStateService:unloadCompany(companyId: string)
	local session = self._sessions[companyId]
	if not session then
		return true, nil
	end
	if session.unloading then
		-- PlayerRemoving and BindToClose can both unload; the first caller owns it.
		while self._sessions[companyId] == session do
			task.wait()
		end
		return true, nil
	end
	session.unloading = true
	-- Wait for an in-flight mutation so the final save sees a complete record.
	self:_enter(session)
	self:_leave(session)
	local saved, saveError = true, nil
	if not session.corrupt then
		saved, saveError = self:_save(companyId, session)
	end
	if self._sessions[companyId] == session then
		self._sessions[companyId] = nil
	end
	local called, released, releaseError = pcall(self._persistence.release, self._persistence, companyId)
	if not saved then
		return false, saveError
	end
	if session.corrupt then
		return false, "InternalError"
	end
	if not called then
		return false, "ReleaseFailed:" .. tostring(released)
	end
	return released, releaseError
end

function CompanyStateService:forgetUser(userId: number)
	Protocol.forgetUser(self._limiter, userId)
	Protocol.forgetUser(self._globalLimiter, userId)
end

function CompanyStateService:_notifyPlacements(companyId: string, session)
	local handler = self._placementsChanged
	if handler and self._sessions[companyId] == session then
		local ok, err = pcall(handler, companyId, session.state.layout.placements)
		if not ok then
			warn(string.format("[ChristmasMarket2] placement visual sync failed for %s: %s", companyId, tostring(err)))
		end
	end
end

-- Runs one server-owned pass over every available session under its critical section.
-- step(state) returns the number of changes and whether displayed trees changed.
function CompanyStateService:_runPass(filter, step)
	local failures = 0
	local total = 0
	for _, companyId in ipairs(self:_companyIds()) do
		local session = self._sessions[companyId]
		if session and session.healthy and not session.unloading and (filter == nil or filter(session.state)) then
			local ok, changes, placementsChanged = self:_withSession(companyId, session, function(state)
				local changed, displayChanged = step(state)
				if changed > 0 then
					state.revision += 1
					session.dirty = true
				end
				return changed, displayChanged
			end)
			if ok then
				total += changes
				if placementsChanged then
					self:_notifyPlacements(companyId, session)
				end
			elseif changes == "InternalError" then
				failures += 1
			end
		end
	end
	return failures == 0, total, failures
end

-- System pricing uses the same per-company critical section as player actions.
function CompanyStateService:applyAutoPricingAll()
	return self:_runPass(function(state)
		return state.autoPricing == true
	end, function(state)
		local _, updated = PricingService.applyAutomatic(state)
		return if type(updated) == "table" and next(updated) ~= nil then 1 else 0, false
	end)
end

-- Performs bounded logical NPC visits per company; a completed sale is one atomic change.
function CompanyStateService:simulateCustomerVisits()
	return self:_runPass(nil, function(state)
		local completedSales = 0
		local visitsThisTick = math.min(1 + state.staff.Cashier, GameConfig.MaxCustomerVisitsPerTick)
		for _ = 1, visitsThisTick do
			self._customerSequence += 1
			local started, visit =
				CustomerSimulationService.beginVisit(state, self._customerSequence, self._clock(), self._randomRoll())
			if started and CustomerSimulationService.completeVisit(state, visit, self._clock()) then
				completedSales += 1
			end
		end
		return completedSales, completedSales > 0
	end)
end

function CompanyStateService:reconcileDeliveriesAll()
	return self:_runPass(nil, function(state)
		local reconciled, delivered = BusinessState.reconcileDeliveries(state, self._clock())
		return if reconciled then delivered else 0, false
	end)
end

function CompanyStateService:autoUnloadDeliveriesAll()
	return self:_runPass(function(state)
		return state.staff.LotWorker > 0
	end, function(state)
		local delivered = {}
		for orderId, order in pairs(state.pendingOrders) do
			if order.status == "Delivered" then
				table.insert(delivered, orderId)
			end
		end
		table.sort(delivered)
		local unloaded = 0
		for _, orderId in ipairs(delivered) do
			if BusinessState.unloadOrder(state, orderId, self._clock()) then
				unloaded += 1
			end
		end
		return unloaded, false
	end)
end

local OWNER_MANAGER = { Owner = true, Manager = true }
local OWNER_MANAGER_WORKER = { Owner = true, Manager = true, Worker = true }
local ACTION_ROLES = {
	[Protocol.Actions.SupplierPlaceOrder] = OWNER_MANAGER,
	[Protocol.Actions.QuestClaim] = OWNER_MANAGER,
	[Protocol.Actions.PricingSetMediumPrice] = OWNER_MANAGER,
	[Protocol.Actions.PricingSetAuto] = OWNER_MANAGER,
	[Protocol.Actions.EmployeeHire] = OWNER_MANAGER,
	[Protocol.Actions.ProgressionBuyLotExpansion] = OWNER_MANAGER,
	[Protocol.Actions.ProgressionBuyParking] = OWNER_MANAGER,
	[Protocol.Actions.ProgressionBuyHQ] = OWNER_MANAGER,
	[Protocol.Actions.DeliveryUnload] = OWNER_MANAGER_WORKER,
	[Protocol.Actions.InventoryPlace] = OWNER_MANAGER_WORKER,
	[Protocol.Actions.InventoryPickup] = OWNER_MANAGER_WORKER,
}
-- Read-only queries are available to every member, including visitors.
local MEMBER_QUERIES = {
	[Protocol.Actions.SupplierRequestQuote] = true,
	[Protocol.Actions.CompanyGetSummary] = true,
}

local function canPerformAction(state, userId: number, action: string): boolean
	local role = state.members[tostring(userId)]
	if role == nil then
		return false
	end
	if MEMBER_QUERIES[action] then
		return true
	end
	local allowed = ACTION_ROLES[action]
	return allowed ~= nil and allowed[role] == true
end

local STATUS_ORDER = { Delivered = 1, Pending = 2 }

local function deliverySummary(state)
	local orders = {}
	for orderId, order in pairs(state.pendingOrders) do
		table.insert(orders, {
			orderId = orderId,
			speciesId = order.speciesId,
			sizeId = order.sizeId,
			quantity = order.quantity,
			status = order.status,
			dueAt = order.dueAt,
		})
	end
	-- Sort before truncating so ready deliveries are never hidden behind pending ones.
	table.sort(orders, function(a, b)
		local aRank, bRank = STATUS_ORDER[a.status] or 3, STATUS_ORDER[b.status] or 3
		if aRank ~= bRank then
			return aRank < bRank
		end
		if a.dueAt ~= b.dueAt and type(a.dueAt) == "number" and type(b.dueAt) == "number" then
			return a.dueAt < b.dueAt
		end
		return a.orderId < b.orderId
	end)
	while #orders > 10 do
		table.remove(orders)
	end
	return orders
end

local function placementCount(state): number
	local count = 0
	for _ in pairs(state.layout.placements) do
		count += 1
	end
	return count
end

local PLACEMENT_ACTIONS = {
	[Protocol.Actions.InventoryPlace] = true,
	[Protocol.Actions.InventoryPickup] = true,
}

-- Applies one validated request to the live record. Must not yield.
function CompanyStateService:_dispatch(session, state, userId: number, request)
	if not canPerformAction(state, userId, request.action) then
		return { ok = false, errorCode = "Forbidden" }
	end
	local payload = request.payload
	if request.action == Protocol.Actions.SupplierRequestQuote then
		return {
			ok = true,
			revision = state.revision,
			data = SupplierCatalog.quote(payload.speciesId, payload.sizeId),
		}
	end
	if request.action == Protocol.Actions.CompanyGetSummary then
		return {
			ok = true,
			revision = state.revision,
			data = {
				cash = state.cash,
				reputation = state.reputation,
				plot = table.clone(state.progression),
				analytics = AnalyticsService.summary(state),
				deliveries = deliverySummary(state),
				stock = table.clone(state.stock),
				placementCount = placementCount(state),
			},
		}
	end

	local started, record = Protocol.beginRequest(state, request.requestId, request.action, self._clock())
	if not started then
		-- previousResult lets a client that retried after a timeout learn the outcome.
		return {
			ok = false,
			errorCode = "DuplicateRequest",
			previousResult = record.result,
			revision = state.revision,
		}
	end
	local succeeded, result = false, "UnknownAction"
	local action = request.action
	if action == Protocol.Actions.SupplierPlaceOrder then
		succeeded, result = BusinessState.placeOrder(
			state,
			request.requestId,
			payload.speciesId,
			payload.sizeId,
			payload.quantity,
			self._clock()
		)
	elseif action == Protocol.Actions.DeliveryUnload then
		succeeded, result = BusinessState.unloadOrder(state, payload.orderId, self._clock())
	elseif action == Protocol.Actions.InventoryPlace then
		succeeded, result = PlacementService.place(
			state,
			"placement:" .. request.requestId,
			payload.speciesId,
			payload.sizeId,
			payload.transform
		)
	elseif action == Protocol.Actions.InventoryPickup then
		succeeded, result = PlacementService.pickup(state, payload.placementId)
	elseif action == Protocol.Actions.PricingSetMediumPrice then
		succeeded, result = PricingService.setMediumPrice(state, payload.speciesId, payload.mediumPrice)
	elseif action == Protocol.Actions.PricingSetAuto then
		succeeded, result = PricingService.setAutomatic(state, payload.enabled)
	elseif action == Protocol.Actions.EmployeeHire then
		succeeded, result = EmployeeService.hire(state, payload.employeeId)
	elseif action == Protocol.Actions.ProgressionBuyLotExpansion then
		succeeded, result = ProgressionService.buyLotExpansion(state)
	elseif action == Protocol.Actions.ProgressionBuyParking then
		succeeded, result = ProgressionService.buyParking(state)
	elseif action == Protocol.Actions.ProgressionBuyHQ then
		succeeded, result = ProgressionService.buyHQ(state, payload.hqId)
	elseif action == Protocol.Actions.QuestClaim then
		succeeded, result = QuestService.claim(state, payload.questId)
	end
	Protocol.finishRequest(record, succeeded and "Success" or tostring(result))
	-- The request record changed even when the action was rejected.
	session.dirty = true
	if not succeeded then
		return { ok = false, errorCode = result, revision = state.revision }
	end
	state.revision += 1
	return {
		ok = true,
		revision = state.revision,
		data = result,
		placementsChanged = PLACEMENT_ACTIONS[action] == true,
	}
end

function CompanyStateService:handle(companyId: string, userId: number, request)
	local valid, validationError = Protocol.validateRequest(request)
	if not valid then
		return { ok = false, errorCode = validationError }
	end
	if
		not Protocol.allowRequest(self._globalLimiter, userId, "*", self._clock())
		or not Protocol.allowRequest(self._limiter, userId, request.action, self._clock())
	then
		return { ok = false, errorCode = "RateLimited" }
	end
	local session = self._sessions[companyId]
	if not session or not session.healthy or session.unloading then
		return { ok = false, errorCode = "CompanyUnavailable" }
	end
	local entered, response = self:_withSession(companyId, session, function(state)
		return self:_dispatch(session, state, userId, request)
	end)
	if not entered then
		return { ok = false, errorCode = response }
	end
	if response.placementsChanged then
		self:_notifyPlacements(companyId, session)
	end
	response.placementsChanged = nil
	return response
end

-- Server-only projection for world visuals. It deliberately exposes no mutable
-- company state to clients; callers must be trusted server code.
function CompanyStateService:getPlacements(companyId: string)
	local session = self._sessions[companyId]
	if not session or not session.healthy then
		return nil
	end
	return session.state.layout.placements
end

return CompanyStateService
