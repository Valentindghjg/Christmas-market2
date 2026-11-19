--!strict
-- Minimal authoritative checkout for an NPC-selected displayed tree.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Economy = require(Shared:WaitForChild("Economy"))
local BusinessState = require(Shared:WaitForChild("BusinessState"))

local CustomerService = {}

function CustomerService.completeSale(state, placementId: string)
	local placement = state.layout.placements[placementId]
	if type(placement) ~= "table" then
		return false, "Unavailable"
	end
	local mediumPrice = state.mediumPrices[placement.speciesId]
	if type(mediumPrice) ~= "number" then
		return false, "InvalidPrice"
	end
	local salePrice = Economy.priceForSize(mediumPrice, placement.sizeId)
	state.layout.placements[placementId] = nil
	state.cash += salePrice
	state.revenue += salePrice
	state.sales += 1
	state.reputation += 1
	BusinessState.record(state, "Sale", salePrice)
	return true, { salePrice = salePrice, reputationGain = 1 }
end

return CustomerService
