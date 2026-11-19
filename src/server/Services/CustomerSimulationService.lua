--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local CustomerProfile = require(Shared:WaitForChild("CustomerProfile"))
local CustomerSelection = require(Shared:WaitForChild("CustomerSelection"))
local CustomerService = require(script.Parent:WaitForChild("CustomerService"))

local CustomerSimulationService = {}

-- A deterministic server visit reserves at most one eligible tree; callers own scheduling.
function CustomerSimulationService.beginVisit(state, customerNumber: number, timestamp: number, roll: number)
	if type(roll) ~= "number" or roll < 0 or roll > 1 then
		return false, "InvalidRoll"
	end
	local profile = CustomerProfile.create(customerNumber)
	if not profile then
		return false, "InvalidCustomer"
	end
	local candidate = CustomerSelection.choose(state, profile)
	if not candidate then
		return false, "NoEligibleStock"
	end
	if roll > candidate.conversionScore then
		return false, "NoConversion"
	end
	local reserved, reservation =
		CustomerService.reserve(state, candidate.placementId, profile.id, timestamp, profile.patienceSeconds)
	if not reserved then
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

function CustomerSimulationService.completeVisit(state, visit, timestamp: number)
	if type(visit) ~= "table" or type(visit.placementId) ~= "string" or type(visit.customerId) ~= "string" then
		return false, "InvalidVisit"
	end
	return CustomerService.completeReservedSale(state, visit.placementId, visit.customerId, timestamp)
end

return CustomerSimulationService
