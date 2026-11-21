--!strict
-- Paid customer orders waiting at a parked car (docs/REFERENCE_GAME_LIVE_TEST.md §3.7).
-- A sale creates an order with a sequential number tied to the customer's parking space;
-- the tree is carried to the car with the same number. Every transition happens exactly
-- once inside the company critical section; the client never supplies prices or rewards.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BusinessState = require(Shared:WaitForChild("BusinessState"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local TreeHeight = require(Shared:WaitForChild("TreeHeight"))

local CustomerOrderService = {}

local function isPositiveInteger(value: unknown): boolean
	return type(value) == "number" and value == value and value == math.floor(value) and value >= 1 and value < 2 ^ 31
end

local function orderCount(state): number
	local count = 0
	for _ in pairs(state.customerOrders) do
		count += 1
	end
	return count
end

local function sortedOrders(state)
	local orders = {}
	for _, order in pairs(state.customerOrders) do
		table.insert(orders, order)
	end
	table.sort(orders, function(a, b)
		return a.orderNumber < b.orderNumber
	end)
	return orders
end

-- Parking tier 1 always offers the observed base spaces; upgrades add more.
function CustomerOrderService.parkingSpaces(state): number
	return math.max(GameConfig.Customers.BaseParkingSpaces, state.progression.parkingSpaces)
end

-- Every browsing (reserved) or waiting (paid) customer occupies one parked car.
function CustomerOrderService.activeCustomers(state): number
	local count = orderCount(state)
	for _ in pairs(state.reservations) do
		count += 1
	end
	return count
end

function CustomerOrderService.freeParking(state): number
	local free = CustomerOrderService.parkingSpaces(state) - CustomerOrderService.activeCustomers(state)
	local orderRoom = GameConfig.Customers.MaxOpenCustomerOrders - orderCount(state)
	return math.max(0, math.min(free, orderRoom))
end

local function freeParkingSpace(state): number
	local used = {}
	for _, order in pairs(state.customerOrders) do
		used[order.parkingSpace] = true
	end
	for index = 1, CustomerOrderService.parkingSpaces(state) do
		if not used[index] then
			return index
		end
	end
	return CustomerOrderService.parkingSpaces(state) + 1
end

-- Turns a settled sale into an order waiting at the customer's car.
function CustomerOrderService.createFromSale(state, sale, timestamp: number)
	if type(sale) ~= "table" or type(sale.placementId) ~= "string" then
		return false, "InvalidSale"
	end
	if orderCount(state) >= GameConfig.Customers.MaxOpenCustomerOrders then
		return false, "TooManyCustomerOrders"
	end
	local orderNumber = state.nextOrderNumber
	local order = {
		orderNumber = orderNumber,
		speciesId = sale.speciesId,
		sizeId = sale.sizeId,
		heightTenths = TreeHeight.tenthsFor(sale.placementId, sale.sizeId) or 0,
		salePrice = sale.salePrice,
		soldAt = timestamp,
		expiresAt = timestamp + GameConfig.Customers.PickupPatienceSeconds,
		parkingSpace = freeParkingSpace(state),
	}
	state.nextOrderNumber += 1
	state.customerOrders[tostring(orderNumber)] = order
	return true, order
end

local function find(state, orderNumber: unknown)
	if not isPositiveInteger(orderNumber) then
		return nil
	end
	return state.customerOrders[tostring(orderNumber)]
end

local function carriedBy(state, userId: number)
	for _, order in pairs(state.customerOrders) do
		if order.carriedBy == userId then
			return order
		end
	end
	return nil
end

function CustomerOrderService.carriedOrderNumber(state, userId: number): number?
	local order = carriedBy(state, userId)
	return if order then order.orderNumber else nil
end

function CustomerOrderService.carry(state, userId: number, orderNumber: number)
	local order = find(state, orderNumber)
	if not order then
		return false, "UnknownOrder"
	end
	if order.carriedBy == userId then
		return true, order.orderNumber
	end
	if order.carriedBy ~= nil then
		return false, "AlreadyCarried"
	end
	if carriedBy(state, userId) then
		return false, "HandsFull"
	end
	order.carriedBy = userId
	return true, order.orderNumber
end

function CustomerOrderService.release(state, userId: number, orderNumber: number)
	local order = find(state, orderNumber)
	if not order then
		return false, "UnknownOrder"
	end
	if order.carriedBy ~= userId then
		return false, "NotCarrying"
	end
	order.carriedBy = nil
	return true, order.orderNumber
end

-- Drops whatever this player carries (respawn, leaving the plot).
function CustomerOrderService.releaseCarriedBy(state, userId: number): number
	local released = 0
	for _, order in pairs(state.customerOrders) do
		if order.carriedBy == userId then
			order.carriedBy = nil
			released += 1
		end
	end
	return released
end

local function complete(state, order, timestamp: number)
	local fast = timestamp - order.soldAt <= GameConfig.Customers.FastLoadSeconds
	local gain = if fast then GameConfig.Customers.FastLoadReputation else GameConfig.Customers.SlowLoadReputation
	state.customerOrders[tostring(order.orderNumber)] = nil
	state.reputation += gain
	state.loadedOrders += 1
	BusinessState.record(state, "OrderLoaded", 0)
	return { orderNumber = order.orderNumber, reputationGain = gain, fast = fast }
end

-- Completes an order only for the carrying player at the car with the same number.
function CustomerOrderService.load(state, userId: number, orderNumber: number, carNumber: number, timestamp: number)
	local order = find(state, orderNumber)
	if not order then
		return false, "UnknownOrder"
	end
	if order.carriedBy ~= userId then
		return false, "NotCarrying"
	end
	if carNumber ~= orderNumber then
		return false, "WrongCar"
	end
	return true, complete(state, order, timestamp)
end

-- Customers whose patience ran out drive off unhappy; the paid sale stays booked.
function CustomerOrderService.expire(state, timestamp: number): number
	local expired = 0
	for _, order in ipairs(sortedOrders(state)) do
		if order.expiresAt <= timestamp then
			state.customerOrders[tostring(order.orderNumber)] = nil
			state.reputation = math.max(0, state.reputation - GameConfig.Customers.MissedPickupReputationPenalty)
			state.missedPickups += 1
			BusinessState.record(state, "PickupMissed", 0)
			expired += 1
		end
	end
	return expired
end

-- A hired Lot Worker loads uncarried orders once the walk to the car is done.
function CustomerOrderService.autoLoad(state, timestamp: number): number
	if state.staff.LotWorker < 1 then
		return 0, {}
	end
	local loaded = {}
	for _, order in ipairs(sortedOrders(state)) do
		if order.carriedBy == nil and timestamp - order.soldAt >= GameConfig.Customers.WorkerLoadSeconds then
			complete(state, order, timestamp)
			table.insert(loaded, order.orderNumber)
		end
	end
	return #loaded, loaded
end

-- Client-safe projection for HUD and world visuals.
function CustomerOrderService.summary(state)
	local orders = {}
	for _, order in ipairs(sortedOrders(state)) do
		table.insert(orders, {
			orderNumber = order.orderNumber,
			speciesId = order.speciesId,
			sizeId = order.sizeId,
			heightTenths = order.heightTenths,
			parkingSpace = order.parkingSpace,
			expiresAt = order.expiresAt,
			carried = order.carriedBy ~= nil,
		})
	end
	return {
		orders = orders,
		parkingSpaces = CustomerOrderService.parkingSpaces(state),
		activeCustomers = CustomerOrderService.activeCustomers(state),
		loadedOrders = state.loadedOrders,
		missedPickups = state.missedPickups,
		drivePastCustomers = state.drivePastCustomers,
	}
end

return CustomerOrderService
