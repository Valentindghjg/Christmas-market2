--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BusinessState = require(Shared:WaitForChild("BusinessState"))
local CustomerProfile = require(Shared:WaitForChild("CustomerProfile"))
local CustomerSelection = require(Shared:WaitForChild("CustomerSelection"))
local Tutorial = require(Shared:WaitForChild("Tutorial"))
local CustomerService = require(script.Parent:WaitForChild("CustomerService"))
local CustomerOrderService = require(script.Parent:WaitForChild("CustomerOrderService"))

local CustomerSimulationService = {}

-- A deterministic server visit reserves at most one eligible tree; callers own scheduling.
-- A customer only arrives when a parking space is free (callers check freeParking).
-- options (CM2-N1): duration replaces the profile's patience as the reservation length and
-- customerId replaces the profile ID as the reservation owner (a walking NPC's visit ID).
-- priceTolerance (CM2-46a, Evergreen VIP) lets the customer pay that much over its budget.
-- guaranteed (CM2-SALE1) picks with `CustomerSelection.chooseGuaranteed`.
function CustomerSimulationService.beginVisit(
	state,
	customerNumber: number,
	timestamp: number,
	roll: number,
	options: {
		duration: number?,
		customerId: string?,
		priceTolerance: number?,
		guaranteed: boolean?,
	}?
)
	if type(roll) ~= "number" or roll < 0 or roll > 1 then
		return false, "InvalidRoll"
	end
	state.customerVisits += 1
	local profile = CustomerProfile.create(customerNumber)
	if not profile then
		state.abandonedCustomers += 1
		return false, "InvalidCustomer"
	end
	local candidate = if options ~= nil and options.guaranteed == true
		then CustomerSelection.chooseGuaranteed(state)
		else CustomerSelection.choose(state, profile, if options ~= nil then options.priceTolerance else nil)
	if not candidate then
		state.abandonedCustomers += 1
		return false, "NoEligibleStock"
	end
	if roll > candidate.conversionScore then
		state.abandonedCustomers += 1
		return false, "NoConversion"
	end
	local duration = if options ~= nil and options.duration ~= nil then options.duration else profile.patienceSeconds
	local customerId = if options ~= nil and options.customerId ~= nil then options.customerId else profile.id
	local reserved, reservation = CustomerService.reserve(state, candidate.placementId, customerId, timestamp, duration)
	if not reserved then
		state.abandonedCustomers += 1
		return false, reservation
	end
	return true,
		{
			customerId = customerId,
			placementId = candidate.placementId,
			salePrice = candidate.salePrice,
			expiresAt = reservation.expiresAt,
		}
end

-- Settles the sale, then leaves the customer waiting at the car for the tree.
-- parkingSpace and claims (CM2-N1): the walking customer's car keeps its space, and runtime
-- parking claims are skipped when the order needs a free one. queueSeconds (CM2-G15) is the
-- walking customer's queue time for the review. cashMultiplier (CM2-46a, Golden Till and Cash
-- Rush) pays salePrice x (multiplier - 1) on top; the bonus counts as revenue too.
function CustomerSimulationService.completeVisit(
	state,
	visit,
	timestamp: number,
	parkingSpace: number?,
	claims,
	queueSeconds: number?,
	cashMultiplier: number?
)
	if type(visit) ~= "table" or type(visit.placementId) ~= "string" or type(visit.customerId) ~= "string" then
		return false, "InvalidVisit"
	end
	local sold, sale = CustomerService.completeReservedSale(state, visit.placementId, visit.customerId, timestamp)
	if not sold then
		return false, sale
	end
	if type(cashMultiplier) == "number" and cashMultiplier > 1 and cashMultiplier ~= math.huge then
		local bonus = math.floor(sale.salePrice * (cashMultiplier - 1))
		state.cash += bonus
		state.revenue += bonus
		sale.bonus = bonus
		BusinessState.record(state, "SaleBonus", bonus)
	end
	local _, order = CustomerOrderService.createFromSale(state, sale, timestamp, parkingSpace, claims, queueSeconds)
	sale.order = order
	Tutorial.advance(state, "Sold")
	return true, sale
end

return CustomerSimulationService
