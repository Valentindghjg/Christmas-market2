--!strict
local Inventory = {}

export type InventoryState = {[string]: number}

function Inventory.key(species: string, size: string): string
    assert(species:match("^[%w_]+$") ~= nil, "invalid species")
    assert(size == "Small" or size == "Medium" or size == "Large", "invalid size")
    return species .. ":" .. size
end

function Inventory.count(state: InventoryState, key: string): number
    return state[key] or 0
end

function Inventory.add(state: InventoryState, key: string, amount: number): boolean
    if amount ~= math.floor(amount) or amount <= 0 then return false end
    local old = Inventory.count(state, key)
    if old + amount > 100000 then return false end
    state[key] = old + amount
    return true
end

function Inventory.remove(state: InventoryState, key: string, amount: number): boolean
    if amount ~= math.floor(amount) or amount <= 0 then return false end
    local old = Inventory.count(state, key)
    if old < amount then return false end
    if old == amount then state[key] = nil else state[key] = old - amount end
    return true
end

return Inventory
