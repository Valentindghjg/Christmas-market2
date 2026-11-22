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
local SaveProfile = require(Shared:WaitForChild("SaveProfile"))
local SupplierCatalog = require(Shared:WaitForChild("SupplierCatalog"))
local AnalyticsService = require(script.Parent:WaitForChild("AnalyticsService"))
local CustomerOrderService = require(script.Parent:WaitForChild("CustomerOrderService"))
local CustomerSimulationService = require(script.Parent:WaitForChild("CustomerSimulationService"))
local SupplierStockService = require(script.Parent:WaitForChild("SupplierStockService"))
local EmployeeService = require(script.Parent:WaitForChild("EmployeeService"))
local PlacementService = require(script.Parent:WaitForChild("PlacementService"))
local PricingService = require(script.Parent:WaitForChild("PricingService"))
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))
local QuestService = require(script.Parent:WaitForChild("QuestService"))

local CompanyStateService = {}
CompanyStateService.__index = CompanyStateService

-- Persistence results that mean this server no longer owns a valid writable session.
local FAIL_CLOSED_SAVE_ERRORS = { SessionLocked = true, NotLoaded = true }
-- A second unload caller polls the first one's retrying unload at this interval (CM2-R5).
local UNLOAD_POLL_SECONDS = 0.1

local function now(): number
	return os.time()
end

-- wait (CM2-R5) runs the final-save retry delays; tests inject it. The default is lazy
-- because Lune has no task library.
function CompanyStateService.new(persistence, clock, randomRoll, wait)
	local self = setmetatable({}, CompanyStateService)
	self._persistence = persistence
	self._clock = clock or now
	self._randomRoll = randomRoll or math.random
	self._wait = wait or function(seconds: number)
		task.wait(seconds)
	end
	-- Service-clock time at which the server began shutting down (CM2-R5).
	self._shutdownAt = nil
	self._sessions = {}
	self._loading = {}
	self._limiter = Protocol.newRateLimiter(10, 10)
	-- Caps a player's total request volume across all actions.
	self._globalLimiter = Protocol.newRateLimiter(40, 10)
	self._customerSequence = 0
	self._placementsChanged = nil
	self._ordersChanged = nil
	return self
end

-- Studio test instrument only (main.server.lua StudioTestHook): the next simulated
-- customer gets profile number `value + 1`, so a playtest can pick a matching profile.
function CompanyStateService:setCustomerSequence(value: number)
	if type(value) == "number" and value >= 0 and value == math.floor(value) then
		self._customerSequence = value
	end
end

-- Trusted server code (world visuals) subscribes to authoritative display changes.
function CompanyStateService:setPlacementsChangedHandler(handler)
	self._placementsChanged = handler
end

-- Trusted server code (cars, pickup trees, carried trees) follows customer orders.
function CompanyStateService:setCustomerOrdersChangedHandler(handler)
	self._ordersChanged = handler
end

-- Trusted server code (SaveSlotService wiring in main.server.lua) learns when a live
-- session stops accepting mutations, so the HUD can show why (CM2-R3).
function CompanyStateService:setSessionFailedHandler(handler)
	self._sessionFailed = handler
end

-- Marks the session failed and reports it once. An unloading session is never reported:
-- its owner is already leaving it.
function CompanyStateService:_failSession(companyId: string, session, code: string)
	session.healthy = false
	if session.unloading or session.failReported then
		return
	end
	session.failReported = true
	local handler = self._sessionFailed
	if handler then
		local ok, err = pcall(handler, companyId, code)
		if not ok then
			warn(
				string.format("[ChristmasMarket2] session failure handler errored for %s: %s", companyId, tostring(err))
			)
		end
	end
end

-- options (CM2-S2) pass through to PersistenceService:load ({saveSize?, requireExisting?}).
function CompanyStateService:loadCompany(companyId: string, ownerUserId: number, saveName: string?, options)
	-- A previous session may still be saving after a fast rejoin to this server.
	-- Loading now would let that unload release the lock under the new session.
	if self._sessions[companyId] or self._loading[companyId] then
		return nil, "SessionBusy"
	end
	self._loading[companyId] = true
	local called, state, errorCode =
		pcall(self._persistence.load, self._persistence, companyId, ownerUserId, saveName, options)
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
		failReported = false,
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

-- A session exists (healthy or not) or a load is in progress (CM2-S2).
function CompanyStateService:hasSession(companyId: string): boolean
	return self._sessions[companyId] ~= nil or self._loading[companyId] == true
end

-- A session that stopped accepting mutations and is not being unloaded.
function CompanyStateService:isFailed(companyId: string): boolean
	local session = self._sessions[companyId]
	return session ~= nil and not session.healthy and not session.unloading
end

-- The user's role in the live record ("Owner" or "Member"); nil without a healthy session.
function CompanyStateService:memberRole(companyId: string, userId: number): string?
	local session = self._sessions[companyId]
	if not session or not session.healthy then
		return nil
	end
	return session.state.members[SaveProfile.userIdText(userId)]
end

-- Detached team view of the live record; nil without a healthy session.
function CompanyStateService:teamInfo(companyId: string)
	local session = self._sessions[companyId]
	if not session or not session.healthy then
		return nil
	end
	local state = session.state
	return {
		ownerUserId = state.ownerUserId,
		saveName = state.saveName,
		saveSize = state.saveSize,
		inviteCode = state.inviteCode,
		members = table.clone(state.members),
	}
end

-- Applies a team change (BusinessState member/code/size helper) to the live record. mutate
-- must not yield and returns (true, result) or (false, errorCode). Success marks the session
-- dirty without a revision bump; saveNow saves once at once. A failed save keeps the session
-- dirty and still returns ok with saved = false. Returns (ok, errorCode?, result?, saved).
function CompanyStateService:changeTeam(companyId: string, mutate, saveNow: boolean?): (boolean, string?, any, boolean)
	local session = self._sessions[companyId]
	if not session then
		return false, "CompanyUnavailable", nil, false
	end
	local entered, changed, result = self:_withSession(companyId, session, function(state)
		local ok, value = mutate(state)
		if ok then
			session.dirty = true
		end
		return ok, value
	end)
	if not entered then
		return false, changed, nil, false
	end
	if not changed then
		return false, result, nil, false
	end
	local saved = false
	if saveNow then
		saved = (self:_save(companyId, session))
	end
	return true, nil, result, saved
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
		self:_failSession(companyId, session, "InternalError")
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
	if reason == "SessionLocked" then
		self:_failSession(companyId, session, "SessionLocked")
	elseif
		FAIL_CLOSED_SAVE_ERRORS[reason] or self._clock() - session.lastSavedAt >= GameConfig.SaveFailClosedSeconds
	then
		self:_failSession(companyId, session, "SaveFailed")
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

-- Shutdown began (BindToClose): retrying final saves are capped at
-- UnloadRetry.ShutdownSeconds from now, and abortOnFailure no longer calls an unload off.
function CompanyStateService:beginShutdown()
	if self._shutdownAt == nil then
		self._shutdownAt = self._clock()
	end
end

-- Sessions whose final save is in progress or being retried (BindToClose waits for them).
function CompanyStateService:unloadingCount(): number
	local count = 0
	for _, session in pairs(self._sessions) do
		if session.unloading == true then
			count += 1
		end
	end
	return count
end

-- The last moment a failed final save may be retried (CM2-R5).
function CompanyStateService:_unloadDeadline(session): number
	local deadline = session.unloadStartedAt + GameConfig.SaveFailClosedSeconds
	if self._shutdownAt ~= nil then
		deadline = math.min(deadline, self._shutdownAt + GameConfig.UnloadRetry.ShutdownSeconds)
	end
	return deadline
end

-- Saves the session a final time and releases its lock (CM2-R5). A failed final save is
-- retried after each GameConfig.UnloadRetry delay until it succeeds, the lock is lost, the
-- delays are used up or the deadline passes. The lock is released only after a successful
-- save (or for a state that can never be saved); after giving up it expires on its own.
-- options.abortOnFailure calls the unload off after a first retryable failure of a healthy
-- session before shutdown: the session stays live and the result is "UnloadAborted".
-- options.onRetry(attempt) runs before every retry wait.
function CompanyStateService:unloadCompany(
	companyId: string,
	options: { abortOnFailure: boolean?, onRetry: ((attempt: number) -> ())? }?
): (boolean, string?)
	local session = self._sessions[companyId]
	if not session then
		return true, nil
	end
	if session.unloading then
		-- PlayerRemoving and BindToClose can both unload; the first caller owns it. The
		-- second caller waits until the first one has stored its results (Amendment R5-A2).
		while not session.unloadFinished and (self._sessions[companyId] ~= session or session.unloading) do
			self._wait(UNLOAD_POLL_SECONDS)
		end
		if session.unloadFinished ~= true then
			-- The first caller called its unload off; the session is live again.
			return false, "UnloadAborted"
		end
		return session.unloadOk == true, session.unloadError
	end
	local abortOnFailure = options ~= nil and options.abortOnFailure == true
	local onRetry = if options ~= nil then options.onRetry else nil
	session.unloading = true
	session.unloadStartedAt = self._clock()
	-- Wait for an in-flight mutation so the final save sees a complete record.
	self:_enter(session)
	self:_leave(session)

	local outcome = nil
	local lastError = nil
	local attempt = 0
	while outcome == nil do
		attempt += 1
		if session.corrupt then
			outcome = "Corrupt"
		else
			local saved, saveError = self:_save(companyId, session)
			if saved then
				outcome = "Saved"
			elseif saveError ~= nil and FAIL_CLOSED_SAVE_ERRORS[saveError] then
				outcome = saveError
			else
				lastError = saveError
				if abortOnFailure and session.healthy and self._shutdownAt == nil then
					session.unloading = false
					session.unloadStartedAt = nil
					warn(
						string.format(
							"[ChristmasMarket2] final save of %s failed (%s); the session stays live",
							companyId,
							tostring(lastError)
						)
					)
					return false, "UnloadAborted"
				end
				local delay = GameConfig.UnloadRetry.DelaysSeconds[attempt]
				local remaining = self:_unloadDeadline(session) - self._clock()
				if delay == nil or remaining <= 0 then
					outcome = "GaveUp"
				else
					local waitSeconds = math.min(delay, remaining)
					warn(
						string.format(
							"[ChristmasMarket2] final save of %s failed (attempt %d): %s; retrying in %ds",
							companyId,
							attempt,
							tostring(lastError),
							waitSeconds
						)
					)
					if onRetry then
						local hooked, hookError = pcall(onRetry, attempt)
						if not hooked then
							warn(
								string.format(
									"[ChristmasMarket2] unload retry hook failed for %s: %s",
									companyId,
									tostring(hookError)
								)
							)
						end
					end
					self._wait(waitSeconds)
				end
			end
		end
	end

	if self._sessions[companyId] == session then
		self._sessions[companyId] = nil
	end
	local ok, errorCode = false, nil
	if outcome == "GaveUp" then
		warn(
			string.format(
				"[ChristmasMarket2] final save of %s abandoned after %d attempts: %s; changes since the last save are lost and the lock expires on its own",
				companyId,
				attempt,
				tostring(lastError)
			)
		)
		ok, errorCode = false, "SaveFailed"
	else
		local called, released, releaseError = pcall(self._persistence.release, self._persistence, companyId)
		if outcome == "Corrupt" then
			ok, errorCode = false, "InternalError"
		elseif outcome == "Saved" then
			if attempt > 1 then
				print(string.format("[ChristmasMarket2] final save of %s succeeded on attempt %d", companyId, attempt))
			end
			if not called then
				ok, errorCode = false, "ReleaseFailed:" .. tostring(released)
			else
				ok, errorCode = released, releaseError
			end
		else
			ok, errorCode = false, outcome
		end
	end
	session.unloadOk = ok
	session.unloadError = errorCode
	session.unloadFinished = true
	return ok, errorCode
end

-- Copies the profile's save name into the live record (CM2-S1: the profile is the source).
-- Marks the session dirty without a revision bump.
function CompanyStateService:setSaveName(companyId: string, name: string): boolean
	local session = self._sessions[companyId]
	if not session or type(name) ~= "string" then
		return false
	end
	local entered = self:_withSession(companyId, session, function(state)
		state.saveName = name
		session.dirty = true
		return true
	end)
	return entered
end

function CompanyStateService:forgetUser(userId: number)
	Protocol.forgetUser(self._limiter, userId)
	Protocol.forgetUser(self._globalLimiter, userId)
end

function CompanyStateService:_notifyPlacements(companyId: string, session)
	local handler = self._placementsChanged
	if handler and self._sessions[companyId] == session then
		local ok, err = pcall(handler, companyId, session.state.layout.placements, session.state.mediumPrices)
		if not ok then
			warn(string.format("[ChristmasMarket2] placement visual sync failed for %s: %s", companyId, tostring(err)))
		end
	end
end

-- loadedNumbers lists orders just loaded into cars (they leave with the tree on the roof).
function CompanyStateService:_notifyOrders(companyId: string, session, loadedNumbers: { number }?)
	local handler = self._ordersChanged
	if handler and self._sessions[companyId] == session then
		local summary = CustomerOrderService.summary(session.state)
		summary.loadedNumbers = loadedNumbers or {}
		local ok, err = pcall(handler, companyId, summary)
		if not ok then
			warn(string.format("[ChristmasMarket2] customer order sync failed for %s: %s", companyId, tostring(err)))
		end
	end
end

-- Runs one server-owned pass over every available session under its critical section.
-- step(state) returns the number of changes, whether displayed trees changed and
-- whether customer orders changed.
function CompanyStateService:_runPass(filter, step)
	local failures = 0
	local total = 0
	for _, companyId in ipairs(self:_companyIds()) do
		local session = self._sessions[companyId]
		if session and session.healthy and not session.unloading and (filter == nil or filter(session.state)) then
			local ok, changes, flags = self:_withSession(companyId, session, function(state)
				local changed, displayChanged, ordersChanged = step(state)
				if changed > 0 then
					state.revision += 1
					session.dirty = true
				end
				return changed, { display = displayChanged == true, orders = ordersChanged }
			end)
			if ok then
				total += changes
				if flags.display then
					self:_notifyPlacements(companyId, session)
				end
				if flags.orders then
					self:_notifyOrders(companyId, session, type(flags.orders) == "table" and flags.orders.loaded or nil)
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
-- Customers arrive by car: with every parking space taken the next car drives past.
function CompanyStateService:simulateCustomerVisits()
	return self:_runPass(nil, function(state)
		local completedSales = 0
		local freeParking = CustomerOrderService.freeParking(state)
		if freeParking < 1 then
			-- Counted for analytics only; it is saved with the next real change or lock renewal.
			if next(state.layout.placements) ~= nil then
				state.drivePastCustomers += 1
			end
			return 0, false, false
		end
		local visitsThisTick = math.min(1 + state.staff.Cashier, GameConfig.MaxCustomerVisitsPerTick, freeParking)
		for _ = 1, visitsThisTick do
			self._customerSequence += 1
			local started, visit =
				CustomerSimulationService.beginVisit(state, self._customerSequence, self._clock(), self._randomRoll())
			if started and CustomerSimulationService.completeVisit(state, visit, self._clock()) then
				completedSales += 1
			end
		end
		return completedSales, completedSales > 0, completedSales > 0
	end)
end

-- Customers whose patience ran out leave; a Lot Worker loads waiting orders.
function CompanyStateService:serviceCustomerOrdersAll()
	return self:_runPass(function(state)
		return next(state.customerOrders) ~= nil
	end, function(state)
		local expired = CustomerOrderService.expire(state, self._clock())
		local loadedCount, loadedNumbers = CustomerOrderService.autoLoad(state, self._clock())
		local changed = expired + loadedCount
		return changed, false, if changed > 0 then { loaded = loadedNumbers } else false
	end)
end

function CompanyStateService:refreshSupplierStockAll()
	return self:_runPass(nil, function(state)
		local refreshed = SupplierStockService.refreshIfDue(state, self._clock(), self._randomRoll)
		return if refreshed then 1 else 0, false, false
	end)
end

-- Drops anything this player carries (respawn, leaving). Server-trusted callers only.
function CompanyStateService:releaseCarried(companyId: string, userId: number): number
	local session = self._sessions[companyId]
	if not session then
		return 0
	end
	local ok, released = self:_withSession(companyId, session, function(state)
		local count = CustomerOrderService.releaseCarriedBy(state, userId)
		if count > 0 then
			state.revision += 1
			session.dirty = true
		end
		return count
	end)
	if ok and released > 0 then
		self:_notifyOrders(companyId, session)
	end
	return if ok then released else 0
end

-- The order this player carries according to the authoritative record, if any.
function CompanyStateService:getCarriedOrderNumber(companyId: string, userId: number): number?
	local session = self._sessions[companyId]
	if not session or not session.healthy then
		return nil
	end
	return CustomerOrderService.carriedOrderNumber(session.state, userId)
end

-- Server-only projection of customer orders for world visuals and reach checks.
function CompanyStateService:getCustomerOrders(companyId: string)
	local session = self._sessions[companyId]
	if not session or not session.healthy then
		return nil
	end
	return CustomerOrderService.summary(session.state)
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

-- CM2-S2 (PRODUCT_SPEC, OWNER DECIDED): the owner and every member may perform every
-- gameplay action and query. Owner-only save management lives in SaveSlotService.
local MEMBER_ACTIONS = {
	[Protocol.Actions.SupplierPlaceOrder] = true,
	[Protocol.Actions.QuestClaim] = true,
	[Protocol.Actions.PricingSetMediumPrice] = true,
	[Protocol.Actions.PricingSetAuto] = true,
	[Protocol.Actions.EmployeeHire] = true,
	[Protocol.Actions.ProgressionBuyLotExpansion] = true,
	[Protocol.Actions.ProgressionBuyParking] = true,
	[Protocol.Actions.ProgressionBuyHQ] = true,
	[Protocol.Actions.DeliveryUnload] = true,
	[Protocol.Actions.InventoryPlace] = true,
	[Protocol.Actions.InventoryPickup] = true,
	[Protocol.Actions.OrderCarry] = true,
	[Protocol.Actions.OrderLoad] = true,
	[Protocol.Actions.OrderRelease] = true,
	[Protocol.Actions.SupplierSellBack] = true,
	[Protocol.Actions.SupplierRequestQuote] = true,
	[Protocol.Actions.CompanyGetSummary] = true,
}

local function canPerformAction(state, userId: number, action: string): boolean
	local role = state.members[SaveProfile.userIdText(userId)]
	if role ~= "Owner" and role ~= "Member" then
		return false
	end
	return MEMBER_ACTIONS[action] == true
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
	[Protocol.Actions.SupplierSellBack] = true,
	-- Price labels on displayed trees follow manual price changes.
	[Protocol.Actions.PricingSetMediumPrice] = true,
}

local ORDER_ACTIONS = {
	[Protocol.Actions.OrderCarry] = true,
	[Protocol.Actions.OrderLoad] = true,
	[Protocol.Actions.OrderRelease] = true,
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
				receiving = BusinessState.receivingSummary(state),
				supplier = SupplierStockService.summary(state, self._clock()),
				customers = CustomerOrderService.summary(state),
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
		SupplierStockService.refreshIfDue(state, self._clock(), self._randomRoll)
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
	elseif action == Protocol.Actions.OrderCarry then
		succeeded, result = CustomerOrderService.carry(state, userId, payload.orderNumber)
	elseif action == Protocol.Actions.OrderLoad then
		succeeded, result =
			CustomerOrderService.load(state, userId, payload.orderNumber, payload.carNumber, self._clock())
	elseif action == Protocol.Actions.OrderRelease then
		succeeded, result = CustomerOrderService.release(state, userId, payload.orderNumber)
	elseif action == Protocol.Actions.SupplierSellBack then
		succeeded, result = SupplierStockService.sellBack(state, payload.speciesId, payload.sizeId, payload.quantity)
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
		ordersChanged = ORDER_ACTIONS[action] == true,
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
	if response.ordersChanged then
		local loaded = if request.action == Protocol.Actions.OrderLoad and type(response.data) == "table"
			then { response.data.orderNumber }
			else nil
		self:_notifyOrders(companyId, session, loaded)
	end
	response.placementsChanged = nil
	response.ordersChanged = nil
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

-- Studio test instruments only (StudioTestService); never called by gameplay code.

-- One forced, converting customer visit (roll 0) for the given profile number.
-- Returns true plus the new order number, or false plus the reason.
function CompanyStateService:visitForTest(companyId: string, customerNumber: number): (boolean, number | string)
	if type(customerNumber) ~= "number" or customerNumber < 1 or customerNumber ~= math.floor(customerNumber) then
		return false, "InvalidCustomer"
	end
	local session = self._sessions[companyId]
	if not session or not session.healthy then
		return false, "CompanyUnavailable"
	end
	local entered, success, result = self:_withSession(companyId, session, function(state)
		if CustomerOrderService.freeParking(state) < 1 then
			return false, "NoParking"
		end
		local timestamp = self._clock()
		local started, visit = CustomerSimulationService.beginVisit(state, customerNumber, timestamp, 0)
		-- beginVisit counted the visit (and an abandonment) in the record.
		state.revision += 1
		session.dirty = true
		if not started then
			return false, visit
		end
		local sold, sale = CustomerSimulationService.completeVisit(state, visit, timestamp)
		if not sold then
			return false, sale
		end
		if type(sale.order) ~= "table" then
			return false, "NoOrderCreated"
		end
		return true, sale.order.orderNumber
	end)
	if not entered then
		return false, success
	end
	if success then
		self:_notifyPlacements(companyId, session)
		self:_notifyOrders(companyId, session)
	end
	return success, result
end

-- Sets the hired count of one employee type without touching cash.
function CompanyStateService:setStaffForTest(companyId: string, employeeId: string, count: number): boolean
	local employee = GameConfig.Employees[employeeId]
	if
		not employee
		or type(count) ~= "number"
		or count ~= math.floor(count)
		or count < 0
		or count > employee.maxCount
	then
		return false
	end
	local session = self._sessions[companyId]
	if not session or not session.healthy then
		return false
	end
	local entered = self:_withSession(companyId, session, function(state)
		state.staff[employeeId] = count
		state.revision += 1
		session.dirty = true
		return true
	end)
	return entered
end

-- Detached copy of the figures a playtest compares; nil without a healthy session.
function CompanyStateService:snapshotForTest(companyId: string): {}?
	local session = self._sessions[companyId]
	if not session or not session.healthy then
		return nil
	end
	local state = session.state
	local pending = {}
	for orderId, order in pairs(state.pendingOrders) do
		table.insert(pending, { orderId = orderId, status = order.status, quantity = order.quantity })
	end
	table.sort(pending, function(a, b)
		return a.orderId < b.orderId
	end)
	return {
		saveName = state.saveName,
		cash = state.cash,
		reputation = state.reputation,
		revision = state.revision,
		revenue = state.revenue,
		sales = state.sales,
		stock = table.clone(state.stock),
		mediumPrices = table.clone(state.mediumPrices),
		staff = table.clone(state.staff),
		loadedOrders = state.loadedOrders,
		missedPickups = state.missedPickups,
		drivePastCustomers = state.drivePastCustomers,
		placementCount = placementCount(state),
		receiving = BusinessState.receivingSummary(state),
		pendingOrders = pending,
		customerOrders = CustomerOrderService.summary(state).orders,
	}
end

return CompanyStateService
