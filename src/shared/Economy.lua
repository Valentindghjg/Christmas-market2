--!strict
local GameConfig = require(script.Parent.GameConfig)
local Economy = {}

local function isFiniteInteger(value: unknown): boolean
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge and value == math.floor(value)
end

function Economy.priceForSize(mediumPrice: number, size: string): number
    assert(isFiniteInteger(mediumPrice) and mediumPrice >= 0, "invalid medium price")
    local multiplier = GameConfig.SizeMultipliers[size]
    assert(multiplier ~= nil, "invalid size")
    return math.floor(mediumPrice * multiplier + 0.5)
end

function Economy.profit(salePrice: number, wholesaleCost: number): number
    assert(isFiniteInteger(salePrice) and salePrice >= 0, "invalid sale price")
    assert(isFiniteInteger(wholesaleCost) and wholesaleCost >= 0, "invalid wholesale cost")
    return salePrice - wholesaleCost
end

function Economy.canAfford(balance: number, amount: number): boolean
    return isFiniteInteger(balance) and isFiniteInteger(amount) and amount >= 0 and balance >= amount
end

return Economy
