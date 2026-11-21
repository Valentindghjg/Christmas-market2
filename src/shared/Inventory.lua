--!strict
local Inventory = {}
local GameConfig = require(script.Parent.GameConfig)

export type InventoryState = { [string]: number }

local function isPositiveInteger(value: unknown): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value == math.floor(value)
		and value > 0
end

function Inventory.key(species: string, size: string): string
	assert(species:match("^[%w_]+$") ~= nil, "invalid species")
	assert(size == "Small" or size == "Medium" or size == "Large", "invalid size")
	return species .. ":" .. size
end

function Inventory.count(state: InventoryState, key: string): number
	local value = state[key]
	if type(value) ~= "number" or value ~= math.floor(value) or value < 0 or value ~= value then
		return 0
	end
	return value
end

function Inventory.add(state: InventoryState, key: string, amount: number): boolean
	if not isPositiveInteger(amount) then
		return false
	end
	local old = Inventory.count(state, key)
	if old + amount > GameConfig.MaxStockPerSku then
		return false
	end
	state[key] = old + amount
	return true
end

function Inventory.remove(state: InventoryState, key: string, amount: number): boolean
	if not isPositiveInteger(amount) then
		return false
	end
	local old = Inventory.count(state, key)
	if old < amount then
		return false
	end
	if old == amount then
		state[key] = nil
	else
		state[key] = old - amount
	end
	return true
end

return Inventory
