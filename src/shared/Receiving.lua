--!strict
-- Receiving bays (CM2-G14, docs/plans/CM2-G14.md). Pure functions over state.bays and the
-- pending orders: one order = one bay, a bay keeps its trees until they are stocked out,
-- stored elsewhere or sold. A bay is busy while it holds trees or a pending order targets it.
local GameConfig = require(script.Parent.GameConfig)
local Inventory = require(script.Parent.Inventory)

local Receiving = {}
Receiving.BayCount = GameConfig.Receiving.BayCount

export type Bay = { speciesId: string, counts: { [string]: number } }
export type BayView = {
	index: number,
	speciesId: string,
	counts: { Small: number, Medium: number, Large: number },
	total: number,
	arriving: number,
	arrivesIn: number,
}

local function isFiniteInteger(value: unknown): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value == math.floor(value)
end

local function isPositiveInteger(value: unknown): boolean
	return isFiniteInteger(value) and (value :: number) > 0
end

local function isBayIndex(value: unknown): boolean
	return isFiniteInteger(value) and (value :: number) >= 1 and (value :: number) <= Receiving.BayCount
end

local function quantityOf(order): number
	return if type(order) == "table" and isPositiveInteger(order.quantity) then order.quantity else 0
end

-- Species in the observed supplier order, then any other configured species sorted.
local function speciesOrder(): { string }
	local ordered = table.clone(GameConfig.SpeciesOrder)
	local seen = {}
	for _, speciesId in ipairs(ordered) do
		seen[speciesId] = true
	end
	local others = {}
	for speciesId in pairs(GameConfig.Trees) do
		if not seen[speciesId] then
			table.insert(others, speciesId)
		end
	end
	table.sort(others)
	for _, speciesId in ipairs(others) do
		table.insert(ordered, speciesId)
	end
	return ordered
end

local function sortedOrderIds(state): { string }
	local ids = {}
	if type(state.pendingOrders) == "table" then
		for orderId in pairs(state.pendingOrders) do
			if type(orderId) == "string" then
				table.insert(ids, orderId)
			end
		end
	end
	table.sort(ids)
	return ids
end

function Receiving.newBays(): { Bay }
	local bays = {}
	for _ = 1, Receiving.BayCount do
		table.insert(bays, { speciesId = "", counts = {} })
	end
	return bays
end

function Receiving.bayTotal(bay): number
	local total = 0
	if type(bay) == "table" and type(bay.counts) == "table" then
		for _, value in pairs(bay.counts) do
			if isPositiveInteger(value) then
				total += value
			end
		end
	end
	return total
end

-- Pending quantity that targets bay i.
local function arrivingFor(state, index: number): number
	local total = 0
	if type(state.pendingOrders) == "table" then
		for _, order in pairs(state.pendingOrders) do
			if type(order) == "table" and order.bay == index then
				total += quantityOf(order)
			end
		end
	end
	return total
end

-- The bay's trees plus the pending quantities with order.bay == i.
function Receiving.bayLoad(state, index: number): number
	local bays = state.bays
	local bay = if type(bays) == "table" then bays[index] else nil
	return Receiving.bayTotal(bay) + arrivingFor(state, index)
end

function Receiving.isBusy(state, index: number): boolean
	return Receiving.bayLoad(state, index) > 0
end

function Receiving.freeBay(state): number?
	for index = 1, Receiving.BayCount do
		if not Receiving.isBusy(state, index) then
			return index
		end
	end
	return nil
end

function Receiving.usedCount(state): number
	local used = 0
	for index = 1, Receiving.BayCount do
		if Receiving.isBusy(state, index) then
			used += 1
		end
	end
	return used
end

function Receiving.storedTotal(state): number
	local total = 0
	if type(state.bays) == "table" then
		for index = 1, Receiving.BayCount do
			total += Receiving.bayTotal(state.bays[index])
		end
	end
	return total
end

-- A new table of stored trees per SKU ("<speciesId>:<sizeId>").
function Receiving.totals(state): { [string]: number }
	local totals = {}
	if type(state.bays) ~= "table" then
		return totals
	end
	for index = 1, Receiving.BayCount do
		local bay = state.bays[index]
		if type(bay) == "table" and GameConfig.Trees[bay.speciesId] and type(bay.counts) == "table" then
			for _, sizeId in ipairs(GameConfig.SizeIds) do
				local value = bay.counts[sizeId]
				if isPositiveInteger(value) then
					local key = Inventory.key(bay.speciesId, sizeId)
					totals[key] = (totals[key] or 0) + value
				end
			end
		end
	end
	return totals
end

function Receiving.count(state, speciesId: string, sizeId: string): number
	local total = 0
	if type(state.bays) ~= "table" then
		return total
	end
	for index = 1, Receiving.BayCount do
		local bay = state.bays[index]
		if type(bay) == "table" and bay.speciesId == speciesId and type(bay.counts) == "table" then
			local value = bay.counts[sizeId]
			if isPositiveInteger(value) then
				total += value
			end
		end
	end
	return total
end

-- Adds n trees to bay i; fails if the bay is busy with another species.
function Receiving.add(state, index: number, speciesId: string, sizeId: string, n: number): boolean
	local bay = if type(state.bays) == "table" then state.bays[index] else nil
	if type(bay) ~= "table" or type(bay.counts) ~= "table" then
		return false
	end
	if not GameConfig.Trees[speciesId] or not GameConfig.isValidSize(sizeId) or not isPositiveInteger(n) then
		return false
	end
	if Receiving.isBusy(state, index) and bay.speciesId ~= speciesId then
		return false
	end
	bay.speciesId = speciesId
	local old = bay.counts[sizeId]
	bay.counts[sizeId] = (if isPositiveInteger(old) then old else 0) + n
	return true
end

-- Takes exactly n trees of one size from bay i; zero counts are removed.
function Receiving.take(state, index: number, sizeId: string, n: number): boolean
	local bay = if type(state.bays) == "table" then state.bays[index] else nil
	if type(bay) ~= "table" or type(bay.counts) ~= "table" or not isPositiveInteger(n) then
		return false
	end
	local old = bay.counts[sizeId]
	if not isPositiveInteger(old) or old < n then
		return false
	end
	if old == n then
		bay.counts[sizeId] = nil
	else
		bay.counts[sizeId] = old - n
	end
	return true
end

-- Takes up to n trees of one SKU for a sale: bays with the fewest of that SKU first, ties to
-- the lower index, so that bays free up. Returns how many it took.
function Receiving.takeForSale(state, speciesId: string, sizeId: string, n: number): number
	if not isPositiveInteger(n) or type(state.bays) ~= "table" then
		return 0
	end
	local candidates = {}
	for index = 1, Receiving.BayCount do
		local bay = state.bays[index]
		if type(bay) == "table" and bay.speciesId == speciesId and type(bay.counts) == "table" then
			local value = bay.counts[sizeId]
			if isPositiveInteger(value) then
				table.insert(candidates, { index = index, count = value })
			end
		end
	end
	table.sort(candidates, function(a, b)
		if a.count ~= b.count then
			return a.count < b.count
		end
		return a.index < b.index
	end)
	local taken = 0
	for _, candidate in ipairs(candidates) do
		if taken >= n then
			break
		end
		local amount = math.min(candidate.count, n - taken)
		if Receiving.take(state, candidate.index, sizeId, amount) then
			taken += amount
		end
	end
	return taken
end

-- The bay a stored-back tree goes to: the lowest-index bay of the same species with room,
-- else the lowest free bay, else nil.
function Receiving.storeBay(state, speciesId: string): number?
	if type(state.bays) == "table" then
		for index = 1, Receiving.BayCount do
			local bay = state.bays[index]
			if
				type(bay) == "table"
				and bay.speciesId == speciesId
				and Receiving.bayLoad(state, index) < GameConfig.Receiving.BayCapacity
			then
				return index
			end
		end
	end
	return Receiving.freeBay(state)
end

local function clearIdleSpecies(state)
	for index = 1, Receiving.BayCount do
		local bay = state.bays[index]
		if type(bay) == "table" and not Receiving.isBusy(state, index) then
			bay.speciesId = ""
		end
	end
end

-- Repairs bays and order-to-bay links after a load or a mutation.
function Receiving.normalize(state)
	local bays = state.bays
	if type(bays) ~= "table" then
		return
	end
	for index = 1, Receiving.BayCount do
		if type(bays[index]) ~= "table" then
			bays[index] = { speciesId = "", counts = {} }
		end
		local counts = bays[index].counts
		if type(counts) == "table" then
			for sizeId, value in pairs(counts) do
				if value == 0 then
					counts[sizeId] = nil
				end
			end
		end
	end
	clearIdleSpecies(state)
	for _, orderId in ipairs(sortedOrderIds(state)) do
		local order = state.pendingOrders[orderId]
		-- An order without a known species cannot claim a bay (it would give the bay no species).
		if type(order) == "table" and GameConfig.Trees[order.speciesId] then
			local bay = if isBayIndex(order.bay) then bays[order.bay] else nil
			if bay == nil or bay.speciesId ~= order.speciesId then
				order.bay = nil
				local free = Receiving.freeBay(state)
				if free then
					order.bay = free
					bays[free].speciesId = order.speciesId
				end
			end
		end
	end
	clearIdleSpecies(state)
end

-- Schema 12 -> 13: moves the stored stock and pending orders into bays. Trees or orders that
-- do not fit are refunded at wholesale; the caller credits the returned refund.
function Receiving.migrateStock(state): number
	local stock = if type(state.stock) == "table" then state.stock else {}
	state.bays = Receiving.newBays()
	local refund = 0
	-- Delivered orders join the stock.
	for _, orderId in ipairs(sortedOrderIds(state)) do
		local order = state.pendingOrders[orderId]
		if type(order) == "table" and order.status == "Delivered" then
			if GameConfig.Trees[order.speciesId] and GameConfig.isValidSize(order.sizeId) then
				local key = Inventory.key(order.speciesId, order.sizeId)
				stock[key] = Inventory.count(stock, key) + quantityOf(order)
			end
			state.pendingOrders[orderId] = nil
		end
	end
	local capacity = GameConfig.Receiving.BayCapacity
	for _, speciesId in ipairs(speciesOrder()) do
		local current: number? = nil
		for _, sizeId in ipairs(GameConfig.SizeIds) do
			local remaining = Inventory.count(stock, Inventory.key(speciesId, sizeId))
			while remaining > 0 do
				if current == nil or Receiving.bayTotal(state.bays[current]) >= capacity then
					current = Receiving.freeBay(state)
				end
				if current == nil then
					refund += remaining * (GameConfig.wholesaleFor(speciesId, sizeId) or 0)
					remaining = 0
				else
					local bay = state.bays[current]
					local put = math.min(capacity - Receiving.bayTotal(bay), remaining)
					bay.speciesId = speciesId
					bay.counts[sizeId] = (bay.counts[sizeId] or 0) + put
					remaining -= put
				end
			end
		end
	end
	-- Pending orders, earliest first, each get a free bay or are refunded.
	local pending = {}
	for _, orderId in ipairs(sortedOrderIds(state)) do
		local order = state.pendingOrders[orderId]
		if type(order) == "table" and order.status == "Pending" and GameConfig.Trees[order.speciesId] then
			table.insert(pending, { orderId = orderId, order = order })
		end
	end
	local function dueOf(order): number
		return if isFiniteInteger(order.dueAt) then order.dueAt else math.huge
	end
	table.sort(pending, function(a, b)
		local aDue, bDue = dueOf(a.order), dueOf(b.order)
		if aDue ~= bDue then
			return aDue < bDue
		end
		return a.orderId < b.orderId
	end)
	for _, entry in ipairs(pending) do
		local order = entry.order
		order.bay = nil
		local free = Receiving.freeBay(state)
		if free then
			order.bay = free
			state.bays[free].speciesId = order.speciesId
		else
			refund += (GameConfig.wholesaleFor(order.speciesId, order.sizeId) or 0) * quantityOf(order)
			state.pendingOrders[entry.orderId] = nil
		end
	end
	state.stock = nil
	return refund
end

function Receiving.view(state, now: number): { BayView }
	local views: { BayView } = {}
	for index = 1, Receiving.BayCount do
		local bay = if type(state.bays) == "table" then state.bays[index] else nil
		local counts = if type(bay) == "table" and type(bay.counts) == "table" then bay.counts else {}
		local function countOf(sizeId: string): number
			local value = counts[sizeId]
			return if isPositiveInteger(value) then value else 0
		end
		local arriving = 0
		local firstDue: number? = nil
		if type(state.pendingOrders) == "table" then
			for _, order in pairs(state.pendingOrders) do
				if type(order) == "table" and order.bay == index then
					arriving += quantityOf(order)
					if isFiniteInteger(order.dueAt) and (firstDue == nil or order.dueAt < firstDue) then
						firstDue = order.dueAt
					end
				end
			end
		end
		local view: BayView = {
			index = index,
			speciesId = if type(bay) == "table" and type(bay.speciesId) == "string" then bay.speciesId else "",
			counts = { Small = countOf("Small"), Medium = countOf("Medium"), Large = countOf("Large") },
			total = countOf("Small") + countOf("Medium") + countOf("Large"),
			arriving = arriving,
			arrivesIn = if firstDue ~= nil then math.max(0, firstDue - now) else -1,
		}
		table.insert(views, view)
	end
	return views
end

return Receiving
