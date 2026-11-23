--!strict
-- Staff transactions of the company service (CM2-25/26, docs/plans/CM2-25-26a.md): a mixin
-- that CompanyStateService installs. Server-trusted callers only (StaffNpcService); no client
-- request reaches these methods. Each runs inside the company's critical section, never
-- yields and returns false/nil when the session is not available. Staff never cost money
-- after the one-time hire: nothing here debits cash.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Receiving = require(Shared:WaitForChild("Receiving"))
local Stocking = require(Shared:WaitForChild("Stocking"))
local CustomerOrderService = require(script.Parent:WaitForChild("CustomerOrderService"))
local PlacementService = require(script.Parent:WaitForChild("PlacementService"))

local StaffConfig = GameConfig.Staff

local CompanyStaff = {}

-- A sold spot the Lot Worker restocks: { x, z, rotation, sizeId, speciesId }.
export type Spot = { x: number, z: number, rotation: number, sizeId: string, speciesId: string? }

local function finite(value: unknown): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local KEEP_SPOT_CODES = { NotEnoughTrees = true, BayChanged = true }

-- Runtime list of sold spots (newest last, at most VacatedSpotCap); never saved.
function CompanyStaff.noteVacated(session, spot)
	local spots = session.vacatedSpots
	if spots == nil then
		spots = {}
		session.vacatedSpots = spots
	end
	table.insert(spots, spot)
	while #spots > StaffConfig.VacatedSpotCap do
		table.remove(spots, 1)
	end
end

-- The bay to restock from: the lowest index holding the size and the sold species, else the
-- lowest index holding the size.
local function chooseBay(state, sizeId: string, speciesId: string?): number?
	local fallback: number? = nil
	for index = 1, Receiving.BayCount do
		local bay = state.bays[index]
		local stored = if type(bay) == "table" and type(bay.counts) == "table" then bay.counts[sizeId] else nil
		if type(stored) == "number" and stored >= 1 then
			if speciesId ~= nil and bay.speciesId == speciesId then
				return index
			end
			if fallback == nil then
				fallback = index
			end
		end
	end
	return fallback
end

local function findSpot(spots, spot): number?
	if type(spots) ~= "table" or type(spot) ~= "table" then
		return nil
	end
	for index, entry in ipairs(spots) do
		if entry.x == spot.x and entry.z == spot.z and entry.sizeId == spot.sizeId then
			return index
		end
	end
	return nil
end

function CompanyStaff.install(CompanyStateService)
	-- Runs fn(state, session) in the critical section of an available session.
	local function withLive(self, companyId: string, fn): (boolean, any, any)
		local session = self._sessions[companyId]
		if session == nil or not self:isAvailable(companyId) then
			return false, nil, nil
		end
		local entered, first, second = self:_withSession(companyId, session, function(state)
			return fn(state, session)
		end)
		if not entered then
			return false, nil, nil
		end
		return true, first, second
	end

	-- What the staff director needs of a live company; nil unless it is available.
	function CompanyStateService:getStaffView(companyId: string)
		local entered, view = withLive(self, companyId, function(state, session)
			local hired = {}
			for _, role in ipairs(StaffConfig.WorkingRoles) do
				hired[role] = type(state.staff[role]) == "number" and state.staff[role] >= 1
			end
			return {
				token = session.token,
				hired = hired,
				energy = table.clone(state.staffEnergy),
				breakArea = table.clone(state.breakArea),
				lotExpansion = state.progression.lotExpansion,
			}
		end)
		return if entered then view else nil
	end

	-- Copies whole-number energy into the record. It rides along with the next save: no dirty
	-- flag, no revision.
	function CompanyStateService:setStaffEnergy(companyId: string, energies: { [string]: number }): boolean
		if type(energies) ~= "table" then
			return false
		end
		local entered = withLive(self, companyId, function(state)
			for _, role in ipairs(StaffConfig.Roles) do
				local value = energies[role]
				if finite(value) then
					state.staffEnergy[role] = math.floor(math.clamp(value, 0, StaffConfig.Energy.Max))
				end
			end
			return true
		end)
		return entered
	end

	-- The oldest order nobody carries, or nil.
	function CompanyStateService:staffPeekOrder(companyId: string)
		local _, peeked = withLive(self, companyId, function(state)
			local best = nil
			for _, order in pairs(state.customerOrders) do
				if order.carriedBy == nil and (best == nil or order.orderNumber < best.orderNumber) then
					best = order
				end
			end
			if best == nil then
				return nil
			end
			return { orderNumber = best.orderNumber, parkingSpace = best.parkingSpace, sizeId = best.sizeId }
		end)
		return peeked
	end

	function CompanyStateService:staffClaimOrder(companyId: string, orderNumber: number): (boolean, string?)
		local entered, ok, code = withLive(self, companyId, function(state, session)
			local carried, result = CustomerOrderService.carry(state, StaffConfig.CarrierUserId, orderNumber)
			if not carried then
				return false, result
			end
			state.revision += 1
			session.dirty = true
			return true, nil
		end)
		if not entered then
			return false, "CompanyUnavailable"
		end
		if ok then
			self:_notifyOrders(companyId, self._sessions[companyId])
		end
		return ok, code
	end

	-- Loads the carried order into its car exactly once; the customer leaves a review.
	function CompanyStateService:staffLoadOrder(companyId: string, orderNumber: number): (boolean, any)
		local entered, ok, result = withLive(self, companyId, function(state, session)
			local loaded, review =
				CustomerOrderService.load(state, StaffConfig.CarrierUserId, orderNumber, orderNumber, self._clock())
			if not loaded then
				return false, review
			end
			state.revision += 1
			session.dirty = true
			return true, review
		end)
		if not entered then
			return false, "CompanyUnavailable"
		end
		if ok then
			local session = self._sessions[companyId]
			self:_notifyOrders(companyId, session, { orderNumber })
			self:_notifyReviews(companyId, session, { result })
		end
		return ok, result
	end

	function CompanyStateService:staffReleaseOrder(companyId: string, orderNumber: number): boolean
		local entered, ok = withLive(self, companyId, function(state, session)
			local released = CustomerOrderService.release(state, StaffConfig.CarrierUserId, orderNumber)
			if released then
				state.revision += 1
				session.dirty = true
			end
			return released
		end)
		if entered and ok then
			self:_notifyOrders(companyId, self._sessions[companyId])
		end
		return entered and ok == true
	end

	-- The oldest sold spot that can be restocked. A spot that no longer fits is dropped; a spot
	-- without a bay holding its size waits (kept).
	function CompanyStateService:staffPeekRestock(companyId: string)
		local _, peeked = withLive(self, companyId, function(state, session)
			local spots = session.vacatedSpots
			if spots == nil then
				return nil
			end
			local input = Stocking.layoutInput(state)
			local index = 1
			while index <= #spots do
				local spot = spots[index]
				if not Stocking.check(input, spot.x, spot.z, spot.sizeId) then
					table.remove(spots, index)
				else
					local bay = chooseBay(state, spot.sizeId, spot.speciesId)
					if bay ~= nil then
						return { x = spot.x, z = spot.z, rotation = spot.rotation, sizeId = spot.sizeId, bay = bay }
					end
					index += 1
				end
			end
			return nil
		end)
		return peeked
	end

	-- Places one tree from a bay on the sold spot in one atomic step; the bay count drops only
	-- here. NotEnoughTrees, BayChanged or no bay keep the spot; other refusals drop it.
	function CompanyStateService:staffRestock(companyId: string, spot): (boolean, string?)
		local entered, ok, code = withLive(self, companyId, function(state, session)
			local spots = session.vacatedSpots
			local index = findSpot(spots, spot)
			if index == nil then
				return false, "NoSpot"
			end
			local entry = spots[index]
			local bay = chooseBay(state, entry.sizeId, entry.speciesId)
			if bay == nil then
				return false, "NotEnoughTrees"
			end
			local prefix = "staff:" .. state.revision .. ":" .. math.floor(self._clock())
			local placed, result = PlacementService.stockFromBay(
				state,
				prefix,
				bay,
				state.bays[bay].speciesId,
				entry.sizeId,
				entry.x,
				entry.z,
				entry.rotation,
				1,
				GameConfig.Placement.Gap.Default
			)
			if not placed then
				if not KEEP_SPOT_CODES[result] then
					table.remove(spots, index)
				end
				return false, result
			end
			table.remove(spots, index)
			state.revision += 1
			session.dirty = true
			return true, nil
		end)
		if not entered then
			return false, "CompanyUnavailable"
		end
		if ok then
			local session = self._sessions[companyId]
			self:_notifyPlacements(companyId, session)
			self:_notifyReceiving(companyId, session)
		end
		return ok, code
	end
end

return CompanyStaff
