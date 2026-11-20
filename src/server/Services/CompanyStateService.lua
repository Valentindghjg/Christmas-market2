--!strict
-- Serializes all authoritative company mutations behind one in-memory session per company.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BusinessState = require(Shared:WaitForChild("BusinessState"))
local Protocol = require(Shared:WaitForChild("Protocol"))
local SupplierCatalog = require(Shared:WaitForChild("SupplierCatalog"))
local PlacementService = require(script.Parent:WaitForChild("PlacementService"))
local PricingService = require(script.Parent:WaitForChild("PricingService"))
local EmployeeService = require(script.Parent:WaitForChild("EmployeeService"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local CustomerSimulationService = require(script.Parent:WaitForChild("CustomerSimulationService"))
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))
local AnalyticsService = require(script.Parent:WaitForChild("AnalyticsService"))
local QuestService = require(script.Parent:WaitForChild("QuestService"))

local CompanyStateService = {}
CompanyStateService.__index = CompanyStateService

local function now(): number
	return os.time()
end

function CompanyStateService.new(persistence, clock, randomRoll)
	local self = setmetatable({}, CompanyStateService)
	self._persistence = persistence
	self._clock = clock or now
	self._randomRoll = randomRoll or math.random
	self._sessions = {}
	self._limiter = Protocol.newRateLimiter(10, 10)
	self._customerSequence = 0
	return self
end

function CompanyStateService:loadPersonalCompany(userId: number)
	local companyId = "personal:" .. tostring(userId)
	local state, errorCode = self._persistence:load(companyId, userId)
	if not state then
		return nil, errorCode
	end
	self._sessions[companyId] = { state = state, busy = false, healthy = true }
	return state, nil
end

function CompanyStateService:unloadCompany(companyId: string)
	local session = self._sessions[companyId]
	if not session then
		return true, nil
	end
	local saved, errorCode = self._persistence:save(companyId, session.state)
	if not saved then
		session.healthy = false
		return false, errorCode
	end
	self._sessions[companyId] = nil
	return self._persistence:release(companyId)
end

function CompanyStateService:autosaveAll()
	local failures = 0
	for companyId, session in pairs(self._sessions) do
		if session.healthy then
			local saved = self._persistence:save(companyId, session.state)
			if not saved then
				session.healthy = false
				failures += 1
			end
		end
	end
	return failures == 0, failures
end

-- System pricing uses the same per-company critical section and save boundary as player actions.
function CompanyStateService:applyAutoPricingAll()
	local failures = 0
	local updatedCompanies = 0
	for companyId, session in pairs(self._sessions) do
		if session.healthy and session.state.autoPricing then
			self:_enter(session)
			local updated = PricingService.applyAutomatic(session.state)
			if updated then
				session.state.revision += 1
				local saved = self._persistence:save(companyId, session.state)
				if saved then
					updatedCompanies += 1
				else
					session.healthy = false
					failures += 1
				end
			end
			self:_leave(session)
		end
	end
	return failures == 0, updatedCompanies, failures
end

-- Performs at most one logical NPC visit per healthy company and persists a completed sale atomically.
function CompanyStateService:simulateCustomerVisits()
	local failures = 0
	local sales = 0
	for companyId, session in pairs(self._sessions) do
		if session.healthy then
			self:_enter(session)
			local completedSales = 0
			local visitsThisTick = math.min(1 + session.state.staff.Cashier, GameConfig.MaxCustomerVisitsPerTick)
			for _ = 1, visitsThisTick do
				self._customerSequence += 1
				local started, visit = CustomerSimulationService.beginVisit(
					session.state,
					self._customerSequence,
					self._clock(),
					self._randomRoll()
				)
				if started and CustomerSimulationService.completeVisit(session.state, visit, self._clock()) then
					completedSales += 1
				end
			end
			if completedSales > 0 then
				session.state.revision += 1
				local saved = self._persistence:save(companyId, session.state)
				if saved then
					sales += completedSales
				else
					session.healthy = false
					failures += 1
				end
			end
			self:_leave(session)
		end
	end
	return failures == 0, sales, failures
end

function CompanyStateService:reconcileDeliveriesAll()
	local failures = 0
	local arrivals = 0
	for companyId, session in pairs(self._sessions) do
		if session.healthy then
			self:_enter(session)
			local reconciled, delivered = BusinessState.reconcileDeliveries(session.state, self._clock())
			if reconciled and delivered > 0 then
				session.state.revision += 1
				local saved = self._persistence:save(companyId, session.state)
				if saved then
					arrivals += delivered
				else
					session.healthy = false
					failures += 1
				end
			end
			self:_leave(session)
		end
	end
	return failures == 0, arrivals, failures
end

function CompanyStateService:autoUnloadDeliveriesAll()
	local failures = 0
	local unloaded = 0
	for companyId, session in pairs(self._sessions) do
		if session.healthy and session.state.staff.LotWorker > 0 then
			self:_enter(session)
			local changed = false
			for orderId, order in pairs(session.state.pendingOrders) do
				if order.status == "Delivered" then
					local didUnload = BusinessState.unloadOrder(session.state, orderId, self._clock())
					if didUnload then
						changed = true
						unloaded += 1
					end
				end
			end
			if changed then
				session.state.revision += 1
				local saved = self._persistence:save(companyId, session.state)
				if not saved then
					session.healthy = false
					failures += 1
				end
			end
			self:_leave(session)
		end
	end
	return failures == 0, unloaded, failures
end

local function canPerformAction(state, userId: number, action: string): boolean
	local role = state.members[tostring(userId)]
	if action == Protocol.Actions.SupplierPlaceOrder then
		return role == "Owner" or role == "Manager"
	end
	if action == Protocol.Actions.SupplierRequestQuote then
		return role ~= nil
	end
	if action == Protocol.Actions.CompanyGetSummary then
		return role ~= nil
	end
	if action == Protocol.Actions.QuestClaim then
		return role == "Owner" or role == "Manager"
	end
	if action == Protocol.Actions.DeliveryUnload then
		return role == "Owner" or role == "Manager" or role == "Worker"
	end
	if action == Protocol.Actions.InventoryPlace or action == Protocol.Actions.InventoryPickup then
		return role == "Owner" or role == "Manager" or role == "Worker"
	end
	if action == Protocol.Actions.PricingSetMediumPrice or action == Protocol.Actions.PricingSetAuto then
		return role == "Owner" or role == "Manager"
	end
	if action == Protocol.Actions.EmployeeHire then
		return role == "Owner" or role == "Manager"
	end
	if
		action == Protocol.Actions.ProgressionBuyLotExpansion
		or action == Protocol.Actions.ProgressionBuyParking
		or action == Protocol.Actions.ProgressionBuyHQ
	then
		return role == "Owner" or role == "Manager"
	end
	return false
end

local function deliverySummary(state)
	local orders = {}
	for orderId, order in pairs(state.pendingOrders) do
		if #orders >= 10 then
			break
		end
		table.insert(orders, {
			orderId = orderId,
			speciesId = order.speciesId,
			sizeId = order.sizeId,
			quantity = order.quantity,
			status = order.status,
			dueAt = order.dueAt,
		})
	end
	table.sort(orders, function(a, b)
		return a.orderId < b.orderId
	end)
	return orders
end

local function stockSummary(state)
	return table.clone(state.stock)
end

local function placementCount(state): number
	local count = 0
	for _ in pairs(state.layout.placements) do
		count += 1
	end
	return count
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

function CompanyStateService:handle(companyId: string, userId: number, request)
	local valid, validationError = Protocol.validateRequest(request)
	if not valid then
		return { ok = false, errorCode = validationError }
	end
	if not Protocol.allowRequest(self._limiter, userId, request.action, self._clock()) then
		return { ok = false, errorCode = "RateLimited" }
	end
	local session = self._sessions[companyId]
	if not session or not session.healthy then
		return { ok = false, errorCode = "CompanyUnavailable" }
	end

	self:_enter(session)
	local state = session.state
	local response
	if not canPerformAction(state, userId, request.action) then
		response = { ok = false, errorCode = "Forbidden" }
	elseif request.action == Protocol.Actions.SupplierRequestQuote then
		response = {
			ok = true,
			revision = state.revision,
			data = SupplierCatalog.quote(request.payload.speciesId, request.payload.sizeId),
		}
	elseif request.action == Protocol.Actions.CompanyGetSummary then
		response = {
			ok = true,
			revision = state.revision,
			data = {
				cash = state.cash,
				reputation = state.reputation,
				plot = state.progression,
				analytics = AnalyticsService.summary(state),
				deliveries = deliverySummary(state),
				stock = stockSummary(state),
				placementCount = placementCount(state),
			},
		}
	else
		local started, record = Protocol.beginRequest(state, request.requestId, request.action, self._clock())
		if not started then
			response = { ok = false, errorCode = "DuplicateRequest", revision = state.revision }
		else
			local succeeded, result = false, "UnknownAction"
			if request.action == Protocol.Actions.SupplierPlaceOrder then
				succeeded, result = BusinessState.placeOrder(
					state,
					request.requestId,
					request.payload.speciesId,
					request.payload.sizeId,
					request.payload.quantity,
					self._clock()
				)
			elseif request.action == Protocol.Actions.DeliveryUnload then
				succeeded, result = BusinessState.unloadOrder(state, request.payload.orderId, self._clock())
			elseif request.action == Protocol.Actions.InventoryPlace then
				succeeded, result = PlacementService.place(
					state,
					"placement:" .. request.requestId,
					request.payload.speciesId,
					request.payload.sizeId,
					request.payload.transform
				)
			elseif request.action == Protocol.Actions.InventoryPickup then
				succeeded, result = PlacementService.pickup(state, request.payload.placementId)
			elseif request.action == Protocol.Actions.PricingSetMediumPrice then
				succeeded, result =
					PricingService.setMediumPrice(state, request.payload.speciesId, request.payload.mediumPrice)
			elseif request.action == Protocol.Actions.PricingSetAuto then
				succeeded, result = PricingService.setAutomatic(state, request.payload.enabled)
			elseif request.action == Protocol.Actions.EmployeeHire then
				succeeded, result = EmployeeService.hire(state, request.payload.employeeId)
			elseif request.action == Protocol.Actions.ProgressionBuyLotExpansion then
				succeeded, result = ProgressionService.buyLotExpansion(state)
			elseif request.action == Protocol.Actions.ProgressionBuyParking then
				succeeded, result = ProgressionService.buyParking(state)
			elseif request.action == Protocol.Actions.ProgressionBuyHQ then
				succeeded, result = ProgressionService.buyHQ(state, request.payload.hqId)
			elseif request.action == Protocol.Actions.QuestClaim then
				succeeded, result = QuestService.claim(state, request.payload.questId)
			end
			Protocol.finishRequest(record, succeeded and "Success" or tostring(result))
			if succeeded then
				state.revision += 1
			end
			local saved, saveError = self._persistence:save(companyId, state)
			if not saved then
				session.healthy = false
				response = { ok = false, errorCode = "SaveFailed:" .. tostring(saveError) }
			elseif succeeded then
				response = { ok = true, revision = state.revision, data = result }
			else
				response = { ok = false, errorCode = result, revision = state.revision }
			end
		end
	end
	self:_leave(session)
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
