--!strict
-- Finite supplier stock with a refresh timer, demand tags, a recommended order and
-- sell-back (docs/REFERENCE_GAME_LIVE_TEST.md §4.1). All quantities and refunds are
-- derived from server config; the client only names a species, size and quantity.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BusinessState = require(Shared:WaitForChild("BusinessState"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Inventory = require(Shared:WaitForChild("Inventory"))

local SupplierStockService = {}

-- Supplier rows in the OBSERVED order (GameConfig.SpeciesOrder).
local function sortedSpecies(): { string }
	return table.clone(GameConfig.SpeciesOrder)
end

local function clampRoll(value: unknown): number
	if type(value) ~= "number" or value ~= value then
		return 0.5
	end
	return math.clamp(value, 0, 1)
end

-- Rolls new availability and demand tags once the refresh time has passed.
function SupplierStockService.refreshIfDue(state, timestamp: number, roll: () -> number): boolean
	local supplier = state.supplier
	if timestamp < supplier.refreshAt then
		return false
	end
	local config = GameConfig.Supplier
	local stock = {}
	local demand = {}
	for _, speciesId in ipairs(sortedSpecies()) do
		for _, sizeId in ipairs(GameConfig.SizeIds) do
			local key = Inventory.key(speciesId, sizeId)
			local base = config.BaseStock[sizeId]
			local factor = 1 - config.StockVariance + 2 * config.StockVariance * clampRoll(roll())
			stock[key] = math.max(1, math.floor(base * factor + 0.5))
			local demandRoll = clampRoll(roll())
			if demandRoll < config.HighDemandChance then
				demand[key] = "High"
			elseif demandRoll > 1 - config.LowDemandChance then
				demand[key] = "Low"
			end
		end
	end
	supplier.stock = stock
	supplier.demand = demand
	supplier.refreshAt = timestamp + config.RefreshSeconds
	return true
end

-- Per species: the observed shape (1 small, 2 medium) limited by stock, one bay and cash.
function SupplierStockService.recommend(state)
	local lines = {}
	local quantity, cost = 0, 0
	for _, speciesId in ipairs(sortedSpecies()) do
		for _, sizeId in ipairs({ "Small", "Medium" }) do
			local wanted = GameConfig.Supplier.RecommendedPerSpecies[sizeId] or 0
			local available = Inventory.count(state.supplier.stock, Inventory.key(speciesId, sizeId))
			local unitCost = GameConfig.wholesaleFor(speciesId, sizeId) or 0
			local take = math.min(wanted, available, GameConfig.Receiving.BayCapacity - quantity)
			while take > 0 and cost + take * unitCost > state.cash do
				take -= 1
			end
			if take > 0 then
				table.insert(lines, { speciesId = speciesId, sizeId = sizeId, quantity = take })
				quantity += take
				cost += take * unitCost
			end
		end
	end
	return { lines = lines, quantity = quantity, cost = cost }
end

-- OBSERVED refunds round half up (46 x 25% = 11.5 -> 12).
function SupplierStockService.refundFor(speciesId: string, sizeId: string): number?
	local unitCost = GameConfig.wholesaleFor(speciesId, sizeId)
	if not unitCost then
		return nil
	end
	return math.floor(unitCost * GameConfig.Supplier.SellBackFraction + 0.5)
end

-- Sells trees back from storage first, then from the lot; reserved trees are never sold.
-- All-or-nothing: an impossible request changes nothing.
function SupplierStockService.sellBack(state, speciesId: string, sizeId: string, quantity: number)
	local refund = SupplierStockService.refundFor(speciesId, sizeId)
	if not refund then
		return false, "InvalidItem"
	end
	if type(quantity) ~= "number" or quantity ~= math.floor(quantity) or quantity < 1 then
		return false, "InvalidQuantity"
	end
	local key = Inventory.key(speciesId, sizeId)
	local fromStorage = math.min(Inventory.count(state.stock, key), quantity)
	local fromLot = {}
	local placementIds = {}
	for placementId, placement in pairs(state.layout.placements) do
		if
			placement.speciesId == speciesId
			and placement.sizeId == sizeId
			and state.reservations[placementId] == nil
		then
			table.insert(placementIds, placementId)
		end
	end
	table.sort(placementIds)
	for _, placementId in ipairs(placementIds) do
		if fromStorage + #fromLot >= quantity then
			break
		end
		table.insert(fromLot, placementId)
	end
	if fromStorage + #fromLot < quantity then
		return false, "NotEnoughTrees"
	end
	if fromStorage > 0 then
		Inventory.remove(state.stock, key, fromStorage)
	end
	for _, placementId in ipairs(fromLot) do
		state.layout.placements[placementId] = nil
	end
	local total = refund * quantity
	state.cash += total
	BusinessState.record(state, "SellBack", total)
	return true, { sold = quantity, refund = total, fromLot = #fromLot }
end

-- Server wholesale per SKU so the client shows exactly the prices the server charges.
local function wholesaleTable(): { [string]: number }
	local prices = {}
	for _, speciesId in ipairs(GameConfig.SpeciesOrder) do
		for _, sizeId in ipairs(GameConfig.SizeIds) do
			local unitCost = GameConfig.wholesaleFor(speciesId, sizeId)
			if unitCost then
				prices[Inventory.key(speciesId, sizeId)] = unitCost
			end
		end
	end
	return prices
end

function SupplierStockService.summary(state, timestamp: number)
	return {
		refreshIn = math.max(0, state.supplier.refreshAt - timestamp),
		stock = table.clone(state.supplier.stock),
		demand = table.clone(state.supplier.demand),
		recommended = SupplierStockService.recommend(state),
		sellBackFraction = GameConfig.Supplier.SellBackFraction,
		wholesale = wholesaleTable(),
	}
end

return SupplierStockService
