--!strict
return function(t)
    local Economy = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Economy"))
    local expect = t.expect
    -- Uses the observed size rule with round-half-up results.
    t.test("prices observed size tiers", function()
        expect.equal(Economy.priceForSize(82, "Small"), 66)
        expect.equal(Economy.priceForSize(82, "Medium"), 82)
        expect.equal(Economy.priceForSize(82, "Large"), 107)
    end)
    -- Rejects non-finite and non-integral money values.
    t.test("rejects invalid money", function()
        expect.throws(function() Economy.priceForSize(math.huge, "Medium") end)
        expect.throws(function() Economy.priceForSize(82.5, "Medium") end)
        expect.falsy(Economy.canAfford(84, math.huge))
    end)
end
