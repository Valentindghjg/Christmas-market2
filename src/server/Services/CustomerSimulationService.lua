--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CustomerProfile = require(Shared:WaitForChild("CustomerProfile"))
local CustomerSelection = require(Shared:WaitForChild("CustomerSelection"))
local CustomerService = require(script.Parent:WaitForChild("CustomerService"))
local CustomerOrderService = require(script.Parent:WaitForChild("CustomerOrderService"))

local CustomerSimulationService = {}

-- A deterministic server visit reserves at most one eligible tree; callers own scheduling.
-- A customer only arrives when a parking space is free (callers check freeParking).
function CustomerSimulationService.beginVisit(state, customerNumber: number, timestamp: number, roll: number)
	if type(roll) ~= "number" or roll < 0 or roll > 1 then
		return false, "InvalidRoll"
	end
	state.customerVisits += 1
	local profile = CustomerProfile.create(customerNumber)
	if not profile then
		state.abandonedCustomers += 1
		return false, "InvalidCustomer"
	end
	local candidate = CustomerSelection.choose(state, profile)
	if not candidate then
		state.abandonedCustomers += 1
		return false, "NoEligibleStock"
	end
	if roll > candidate.conversionScore then
		state.abandonedCustomers += 1
		return false, "NoConversion"
	end
	local reserved, reservation =
		CustomerService.reserve(state, candidate.placementId, profile.id, timestamp, profile.patienceSeconds)
	if not reserved then
		state.abandonedCustomers += 1
		return false, reservation
	end
	return true,
		{
			customerId = profile.id,
			placementId = candidate.placementId,
			salePrice = candidate.salePrice,
			expiresAt = reservation.expiresAt,
		}
end

-- Settles the sale, then leaves the customer waiting at the car for the tree.
function CustomerSimulationService.completeVisit(state, visit, timestamp: number)
	if type(visit) ~= "table" or type(visit.placementId) ~= "string" or type(visit.customerId) ~= "string" then
		return false, "InvalidVisit"
	end
	local sold, sale = CustomerService.completeReservedSale(state, visit.placementId, visit.customerId, timestamp)
	if not sold then
		return false, sale
	end
	local _, order = CustomerOrderService.createFromSale(state, sale, timestamp)
	sale.order = order
	return true, sale
end

return CustomerSimulationService
