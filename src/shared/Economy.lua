--!strict
local GameConfig = require(script.Parent.GameConfig)
local Economy = {}

function Economy.priceForSize(mediumPrice: number, size: string): number
    assert(mediumPrice >= 0 and mediumPrice == mediumPrice, "invalid medium price")
    local multiplier = GameConfig.SizeMultipliers[size]
    assert(multiplier ~= nil, "invalid size")
    return math.floor(mediumPrice * multiplier + 0.5)
end

function Economy.profit(salePrice: number, wholesaleCost: number): number
    return salePrice - wholesaleCost
end

function Economy.canAfford(balance: number, amount: number): boolean
    return amount >= 0 and balance >= amount
end

return Economy
