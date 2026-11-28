--!strict
-- CM2-V2-ORD (docs/plans/CM2-V2-ORD.md): the "Recent orders" rows of the Supplier tab. The server
-- summary lists one record per species and size of an order; this module groups the records of
-- one order, remembers it for the session and keeps it as "Delivered" once the server drops it.
-- Cost and ETA come from the server summary; this module only groups and labels them.
-- The memory is session-only and never persisted.
local GameConfig = require(script.Parent.GameConfig)

export type Entry = {
	groupId: string,
	quantity: number,
	cost: number,
	createdAt: number,
	dueClock: number,
	delivered: boolean,
}
export type Row = { groupId: string, quantity: number, cost: number, status: string, eta: number }

type Group = { groupId: string, quantity: number, cost: number, createdAt: number, arrivesIn: number }

local OrderStatus = {}

local function finite(value: unknown): number
	if type(value) == "number" and value == value and value > -math.huge and value < math.huge then
		return value
	end
	return 0
end

-- Newest first; the group id breaks ties so the order never depends on table iteration order.
local function newerFirst(a: Entry, b: Entry): boolean
	if a.createdAt ~= b.createdAt then
		return a.createdAt > b.createdAt
	end
	return a.groupId > b.groupId
end

function OrderStatus.status(eta: number, delivered: boolean): string
	if delivered then
		return "Delivered"
	end
	if eta > GameConfig.Receiving.TruckPullInSeconds then
		return "Preparing"
	end
	return "InTransit"
end

function OrderStatus.track(memory: { [string]: Entry }, deliveries: unknown, nowClock: number)
	if type(deliveries) ~= "table" then
		return
	end
	local groups: { [string]: Group } = {}
	for _, record in pairs(deliveries :: { [unknown]: unknown }) do
		if type(record) == "table" then
			local fields = record :: { [string]: unknown }
			local groupId = if type(fields.groupId) == "string"
				then fields.groupId
				elseif type(fields.orderId) == "string" then fields.orderId
				else nil
			local quantity = finite(fields.quantity)
			if groupId ~= nil and quantity > 0 then
				local createdAt = finite(fields.createdAt)
				local arrivesIn = math.max(0, finite(fields.arrivesIn))
				local group = groups[groupId]
				if group == nil then
					groups[groupId] = {
						groupId = groupId,
						quantity = quantity,
						cost = finite(fields.cost),
						createdAt = createdAt,
						arrivesIn = arrivesIn,
					}
				else
					group.quantity += quantity
					group.cost += finite(fields.cost)
					group.createdAt = math.min(group.createdAt, createdAt)
					group.arrivesIn = math.max(group.arrivesIn, arrivesIn)
				end
			end
		end
	end

	for groupId, group in pairs(groups) do
		local entry = memory[groupId]
		if entry == nil then
			memory[groupId] = {
				groupId = groupId,
				quantity = group.quantity,
				cost = group.cost,
				createdAt = group.createdAt,
				dueClock = nowClock + group.arrivesIn,
				delivered = false,
			}
		else
			entry.quantity = math.max(entry.quantity, group.quantity)
			entry.cost = math.max(entry.cost, group.cost)
			entry.createdAt = group.createdAt
			entry.dueClock = nowClock + group.arrivesIn
			entry.delivered = false
		end
	end

	local delivered: { Entry } = {}
	for groupId, entry in pairs(memory) do
		if groups[groupId] == nil then
			entry.delivered = true
		end
		if entry.delivered then
			table.insert(delivered, entry)
		end
	end
	table.sort(delivered, newerFirst)
	for index = GameConfig.Supplier.RecentOrders + 1, #delivered do
		memory[delivered[index].groupId] = nil
	end
end

function OrderStatus.rows(memory: { [string]: Entry }, nowClock: number): { Row }
	local entries: { Entry } = {}
	for _, entry in pairs(memory) do
		table.insert(entries, entry)
	end
	table.sort(entries, newerFirst)
	local rows: { Row } = {}
	for index = 1, math.min(#entries, GameConfig.Supplier.RecentOrders) do
		local entry = entries[index]
		local eta = math.max(0, math.ceil(entry.dueClock - nowClock))
		table.insert(rows, {
			groupId = entry.groupId,
			quantity = entry.quantity,
			cost = entry.cost,
			status = OrderStatus.status(eta, entry.delivered),
			eta = eta,
		})
	end
	return rows
end

return OrderStatus
