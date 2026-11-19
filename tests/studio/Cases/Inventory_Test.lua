--!strict
return function(t)
    local Inventory = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Inventory"))
    local expect = t.expect
    -- Adds and removes whole units without allowing a negative remainder.
    t.test("adds then removes stock", function()
        local stock = {}
        local key = Inventory.key("FrasierFir", "Medium")
        expect.truthy(Inventory.add(stock, key, 3))
        expect.truthy(Inventory.remove(stock, key, 2))
        expect.equal(Inventory.count(stock, key), 1)
    end)
    -- Invalid changes cannot mutate stock.
    t.test("rejects invalid or excessive removal", function()
        local stock = {}
        local key = Inventory.key("NobleFir", "Small")
        expect.falsy(Inventory.add(stock, key, 1.5))
        expect.falsy(Inventory.remove(stock, key, 1))
        expect.equal(Inventory.count(stock, key), 0)
    end)
end
