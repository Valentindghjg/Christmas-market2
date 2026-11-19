--!strict
local GameConfig = require(script.Parent.GameConfig)
local Inventory = require(script.Parent.Inventory)

local BusinessState = {}
BusinessState.SCHEMA_VERSION = 1

function BusinessState.new()
    return {
        schemaVersion = BusinessState.SCHEMA_VERSION,
        cash = GameConfig.StartingCash,
        reputation = GameConfig.StartingReputation,
        stock = {},
        pendingOrders = {},
        sales = 0,
        revenue = 0,
        spent = 0,
        history = {},
        mediumPrices = {
            FrasierFir = GameConfig.Trees.FrasierFir.initialMediumPrice,
            NobleFir = GameConfig.Trees.NobleFir.initialMediumPrice,
            BlueSpruce = GameConfig.Trees.BlueSpruce.initialMediumPrice,
        },
    }
end

function BusinessState.validate(state)
    if type(state) ~= "table" or state.schemaVersion ~= BusinessState.SCHEMA_VERSION then return false end
    if type(state.cash) ~= "number" or state.cash < 0 or state.cash ~= state.cash then return false end
    if type(state.reputation) ~= "number" or state.reputation < 0 then return false end
    if type(state.stock) ~= "table" or type(state.pendingOrders) ~= "table" then return false end
    for key, quantity in pairs(state.stock) do
        if type(key) ~= "string" or type(quantity) ~= "number" or quantity < 0 or quantity > 100000 or quantity ~= math.floor(quantity) then
            return false
        end
    end
    return true
end

function BusinessState.record(state, eventType: string, amount: number)
    local history = state.history
    table.insert(history, { kind = eventType, amount = amount, at = os.time() })
    while #history > 100 do table.remove(history, 1) end
end

function BusinessState.buyStock(state, species: string, size: string, quantity: number, unitCost: number)
    if not BusinessState.validate(state) then return false, "InvalidState" end
    if not GameConfig.Trees[species] then return false, "UnknownSpecies" end
    if size ~= "Small" and size ~= "Medium" and size ~= "Large" then return false, "InvalidSize" end
    if type(quantity) ~= "number" or quantity ~= math.floor(quantity) or quantity < 1 or quantity > 100 then return false, "InvalidQuantity" end
    if type(unitCost) ~= "number" or unitCost ~= math.floor(unitCost) or unitCost < 0 or unitCost > 100000 then return false, "InvalidPrice" end
    local cost = quantity * unitCost
    if state.cash < cost then return false, "InsufficientFunds" end
    local key = Inventory.key(species, size)
    if Inventory.count(state.stock, key) + quantity > 100000 then return false, "Capacity" end
    if not Inventory.add(state.stock, key, quantity) then return false, "Capacity" end
    state.cash -= cost
    state.spent += cost
    BusinessState.record(state, "Purchase", -cost)
    return true, cost
end

function BusinessState.sellStock(state, species: string, size: string, salePrice: number)
    if not BusinessState.validate(state) then return false, "InvalidState" end
    if not GameConfig.Trees[species] then return false, "UnknownSpecies" end
    if type(salePrice) ~= "number" or salePrice ~= math.floor(salePrice) or salePrice < 0 or salePrice > 100000 then return false, "InvalidPrice" end
    local key = Inventory.key(species, size)
    if not Inventory.remove(state.stock, key, 1) then return false, "OutOfStock" end
    state.cash += salePrice
    state.revenue += salePrice
    state.sales += 1
    BusinessState.record(state, "Sale", salePrice)
    return true, salePrice
end

return BusinessState
