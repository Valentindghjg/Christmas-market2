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

local CompanyStateService = {}
CompanyStateService.__index = CompanyStateService

local function now(): number
	return os.time()
end

function CompanyStateService.new(persistence, clock)
	local self = setmetatable({}, CompanyStateService)
	self._persistence = persistence
	self._clock = clock or now
	self._sessions = {}
	self._limiter = Protocol.newRateLimiter(10, 10)
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

local function canPerformAction(state, userId: number, action: string): boolean
	local role = state.members[tostring(userId)]
	if action == Protocol.Actions.SupplierPlaceOrder then
		return role == "Owner" or role == "Manager"
	end
	if action == Protocol.Actions.SupplierRequestQuote then
		return role ~= nil
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
	return false
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

return CompanyStateService
