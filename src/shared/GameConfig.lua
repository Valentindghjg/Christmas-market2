--!strict
local GameConfig = {}

GameConfig.StartingCash = 84
GameConfig.StartingReputation = 90
GameConfig.SizeMultipliers = { Small = 0.8, Medium = 1.0, Large = 1.3 }

GameConfig.Trees = {
    FrasierFir = { displayName = "Frasier Fir", wholesaleMedium = 32, typicalMedium = 80, initialMediumPrice = 82 },
    NobleFir = { displayName = "Noble Fir", wholesaleMedium = 37, typicalMedium = 92, initialMediumPrice = 96 },
    BlueSpruce = { displayName = "Blue Spruce", wholesaleMedium = 42, typicalMedium = 105, initialMediumPrice = 105 },
}

GameConfig.Employees = {
    Cashier = { hireCost = 1200, role = "Checkout" },
    LotWorker = { hireCost = 1800, role = "DeliveryStockingLoading" },
}

GameConfig.HQ = {
    ChristmasPavilion = {
        cashCost = 2500,
        requiredReputation = 250,
        requiredLotExpansion = 1,
        requiredParkingSpaces = 4,
        unlockedTreeCount = 4,
        checkoutStations = 2,
        employeeCapacity = 3,
        customerPatienceBonus = 0.12,
    },
}

return GameConfig
