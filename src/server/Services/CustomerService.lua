--!strict
-- Minimal authoritative checkout for an NPC-selected displayed tree.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Economy"))
local BusinessState = require(Shared:WaitForChild("BusinessState"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local QuestBoard = require(Shared:WaitForChild("QuestBoard"))

local CustomerService = {}

local function isValidCustomerId(customerId: unknown): boolean
	return type(customerId) == "string" and #customerId >= 1 and #customerId <= 128
end

function CustomerService.releaseExpired(state, timestamp: number)
	if not BusinessState.validate(state) or type(timestamp) ~= "number" or timestamp ~= math.floor(timestamp) then
		return false, "InvalidState"
	end
	local released = 0
	for placementId, reservation in pairs(state.reservations) do
		if reservation.expiresAt <= timestamp then
			state.reservations[placementId] = nil
			released += 1
		end
	end
	return true, released
end

-- Locks a displayed tree and its server-derived price before checkout.
function CustomerService.reserve(state, placementId: string, customerId: string, timestamp: number, duration: number?)
	if not BusinessState.validate(state) then
		return false, "InvalidState"
	end
	if type(placementId) ~= "string" or not isValidCustomerId(customerId) then
		return false, "InvalidReservation"
	end
	if type(timestamp) ~= "number" or timestamp ~= math.floor(timestamp) or timestamp < 0 then
		return false, "InvalidTime"
	end
	local reservationDuration = duration or GameConfig.CustomerReservationSeconds
	if
		type(reservationDuration) ~= "number"
		or reservationDuration ~= math.floor(reservationDuration)
		or reservationDuration < 1
	then
		return false, "InvalidDuration"
	end
	CustomerService.releaseExpired(state, timestamp)
	local placement = state.layout.placements[placementId]
	if type(placement) ~= "table" then
		return false, "Unavailable"
	end
	if state.reservations[placementId] then
		return false, "Reserved"
	end
	local mediumPrice = state.mediumPrices[placement.speciesId]
	if type(mediumPrice) ~= "number" then
		return false, "InvalidPrice"
	end
	local salePrice = Economy.priceForSize(mediumPrice, placement.sizeId)
	state.reservations[placementId] = {
		customerId = customerId,
		expiresAt = timestamp + reservationDuration,
		salePrice = salePrice,
	}
	return true, { salePrice = salePrice, expiresAt = timestamp + reservationDuration }
end

-- Releases a customer's own reservation (CM2-N1 give-up paths). Never touches placements or cash.
function CustomerService.cancelReservation(state, placementId: string, customerId: string): (boolean, string?)
	local reservations = if type(state) == "table" then state.reservations else nil
	local reservation = if type(reservations) == "table" and type(placementId) == "string"
		then reservations[placementId]
		else nil
	if type(reservation) ~= "table" then
		return false, "ReservationRequired"
	end
	if reservation.customerId ~= customerId then
		return false, "ReservationOwnerMismatch"
	end
	reservations[placementId] = nil
	return true, nil
end

-- Settles only the specific, unexpired reservation; replays cannot credit again.
function CustomerService.completeReservedSale(state, placementId: string, customerId: string, timestamp: number)
	if not BusinessState.validate(state) then
		return false, "InvalidState"
	end
	if type(placementId) ~= "string" or not isValidCustomerId(customerId) then
		return false, "InvalidReservation"
	end
	if type(timestamp) ~= "number" or timestamp ~= math.floor(timestamp) or timestamp < 0 then
		return false, "InvalidTime"
	end
	local reservation = state.reservations[placementId]
	if type(reservation) ~= "table" then
		return false, "ReservationRequired"
	end
	if reservation.expiresAt <= timestamp then
		state.reservations[placementId] = nil
		return false, "ReservationExpired"
	end
	if reservation.customerId ~= customerId then
		return false, "ReservationOwnerMismatch"
	end
	if type(state.layout.placements[placementId]) ~= "table" then
		state.reservations[placementId] = nil
		return false, "Unavailable"
	end
	local salePrice = reservation.salePrice
	local placement = state.layout.placements[placementId]
	state.reservations[placementId] = nil
	state.layout.placements[placementId] = nil
	state.cash += salePrice
	state.revenue += salePrice
	state.sales += 1
	state.reputation += GameConfig.Customers.SaleReputation
	BusinessState.record(state, "Sale", salePrice)
	QuestBoard.noteSale(state, timestamp, salePrice, placement.sizeId)
	return true,
		{
			salePrice = salePrice,
			reputationGain = GameConfig.Customers.SaleReputation,
			placementId = placementId,
			speciesId = placement.speciesId,
			sizeId = placement.sizeId,
		}
end

return CustomerService
