--!strict
-- CM2-G14: bay -> display (stockFromBay) and display -> bay (storeBack) transitions.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local GameConfig = require(Shared:WaitForChild("GameConfig"))
	local Receiving = require(Shared:WaitForChild("Receiving"))
	local PlacementService = require(game:GetService("ServerScriptService").Server.Services.PlacementService)
	local expect = t.expect

	local function stateWithBays(bays: { any })
		local state = BusinessState.new("personal:42", 42)
		for index, bay in ipairs(bays) do
			state.bays[index] = { speciesId = bay[1], counts = bay[2] }
		end
		return state
	end

	local function placeAt(state, prefix: string, bay: number, speciesId: string, x: number, z: number, count: number?)
		return PlacementService.stockFromBay(state, prefix, bay, speciesId, "Medium", x, z, 0, count or 1, 0.5)
	end

	local function placementCount(state): number
		local count = 0
		for _ in pairs(state.layout.placements) do
			count += 1
		end
		return count
	end

	local function medium()
		return {
			speciesId = "DouglasFir",
			sizeId = "Medium",
			transform = { x = -35, y = 0, z = -13, rotation = 0 },
		}
	end

	t.test("moves one tree between storage and display", function()
		local state = stateWithBays({ { "FrasierFir", { Medium = 1 } } })
		local ok, result = placeAt(state, "placement:req1", 1, "FrasierFir", -35, -13)
		expect.truthy(ok)
		expect.equal(result.placementIds[1], "placement:req1:1")
		expect.equal(result.bay, 1)
		expect.equal(result.remaining.Medium, 0)
		expect.equal(Receiving.count(state, "FrasierFir", "Medium"), 0)
		expect.equal(state.bays[1].speciesId, "")
		local stored, back = PlacementService.storeBack(state, "placement:req1:1")
		expect.truthy(stored)
		expect.equal(back.bay, 1)
		expect.equal(state.bays[1].counts.Medium, 1)
		expect.equal(state.layout.placements["placement:req1:1"], nil)
		expect.truthy(BusinessState.validate(state))
	end)

	-- Only validated numbers are persisted; the server builds the transform itself.
	t.test("stores a sanitized copy of the transform", function()
		local state = stateWithBays({ { "FrasierFir", { Medium = 1 } } })
		expect.truthy(
			PlacementService.stockFromBay(state, "placement:req2", 1, "FrasierFir", "Medium", -35.004, -13, 90, 1, 0)
		)
		local stored = state.layout.placements["placement:req2:1"].transform
		local keys = 0
		for _ in pairs(stored) do
			keys += 1
		end
		expect.equal(keys, 4)
		expect.equal(stored.x, -35)
		expect.equal(stored.y, 0)
		expect.equal(stored.z, -13)
		expect.equal(stored.rotation, 90)
	end)

	t.test("rejects positions outside the owner's lot", function()
		local state = stateWithBays({ { "FrasierFir", { Medium = 1 } } })
		local ok, reason = placeAt(state, "placement:req3", 1, "FrasierFir", 0, 45)
		expect.falsy(ok)
		expect.equal(reason, "OutsideLot")
		expect.equal(state.bays[1].counts.Medium, 1)
		expect.equal(placementCount(state), 0)
		local huge, hugeReason = placeAt(state, "placement:req3", 1, "FrasierFir", 0, 500)
		expect.falsy(huge)
		expect.equal(hugeReason, "InvalidPlacement")
	end)

	-- Storing a reserved tree would orphan the reservation and invalidate the record.
	t.test("refuses to pick up a reserved tree", function()
		local state = BusinessState.new("personal:42", 42)
		state.layout.placements.reserved_1 = { speciesId = "FrasierFir", sizeId = "Medium" }
		state.reservations.reserved_1 = { customerId = "npc:1", expiresAt = 200, salePrice = 82 }
		local ok, reason = PlacementService.storeBack(state, "reserved_1")
		expect.falsy(ok)
		expect.equal(reason, "Reserved")
		expect.truthy(state.layout.placements.reserved_1)
		expect.equal(Receiving.storedTotal(state), 0)
		expect.truthy(BusinessState.validate(state))
	end)

	t.test("enforces the display placement cap", function()
		local state = stateWithBays({ { "FrasierFir", { Medium = 1 } } })
		for index = 1, GameConfig.MaxPlacements do
			state.layout.placements["existing_" .. index] = { speciesId = "FrasierFir", sizeId = "Medium" }
		end
		local ok, reason = placeAt(state, "placement:req4", 1, "FrasierFir", -35, -13)
		expect.falsy(ok)
		expect.equal(reason, "PlacementLimit")
		expect.equal(state.bays[1].counts.Medium, 1)
	end)

	-- STK-02: a row is validated as a whole before anything changes.
	t.test("a row fill places all trees or none", function()
		local state = stateWithBays({ { "DouglasFir", { Medium = 5 } } })
		local blocked, reason = placeAt(state, "placement:blocked", 1, "DouglasFir", -10.6, -20, 5)
		expect.falsy(blocked)
		expect.equal(reason, "KeepClear")
		expect.equal(placementCount(state), 0)
		expect.equal(state.bays[1].counts.Medium, 5)
		local ok, result = placeAt(state, "placement:req", 1, "DouglasFir", -35, -20, 5)
		expect.truthy(ok)
		expect.equal(#result.placementIds, 5)
		for index = 1, 5 do
			expect.equal(result.placementIds[index], "placement:req:" .. index)
			expect.truthy(state.layout.placements["placement:req:" .. index])
		end
		expect.equal(placementCount(state), 5)
		expect.equal(state.bays[1].speciesId, "")
		expect.equal(next(state.bays[1].counts), nil)
		expect.truthy(BusinessState.validate(state))
	end)

	-- STK-03: a tree leaves the lot and enters a bay exactly once.
	t.test("store mode returns the tree without duplication", function()
		local state = stateWithBays({ { "DouglasFir", { Medium = 2 } } })
		expect.truthy(placeAt(state, "placement:dup_a", 1, "DouglasFir", -35, -13))
		expect.truthy(placeAt(state, "placement:dup_b", 1, "DouglasFir", -28, -13))
		local before = Receiving.storedTotal(state) + placementCount(state)
		expect.truthy(PlacementService.storeBack(state, "placement:dup_a:1"))
		expect.equal(Receiving.storedTotal(state) + placementCount(state), before)
		local again, reason = PlacementService.storeBack(state, "placement:dup_a:1")
		expect.falsy(again)
		expect.equal(reason, "UnknownPlacement")
		expect.equal(Receiving.storedTotal(state) + placementCount(state), before)
		expect.equal(state.bays[1].counts.Medium, 1)
		expect.truthy(BusinessState.validate(state))
	end)

	t.test("stores back to the same species, a free bay, or refuses", function()
		local same = stateWithBays({ { "DouglasFir", { Medium = 3 } } })
		same.layout.placements.p1 = medium()
		local ok, result = PlacementService.storeBack(same, "p1")
		expect.truthy(ok)
		expect.equal(result.bay, 1)
		expect.equal(same.bays[1].counts.Medium, 4)

		local full = stateWithBays({ { "DouglasFir", { Medium = 9 } } })
		full.layout.placements.p1 = medium()
		local fullOk, fullResult = PlacementService.storeBack(full, "p1")
		expect.truthy(fullOk)
		expect.equal(fullResult.bay, 2)
		expect.equal(full.bays[2].speciesId, "DouglasFir")
		expect.equal(full.bays[2].counts.Medium, 1)

		local busy = stateWithBays({
			{ "DouglasFir", { Medium = 9 } },
			{ "FrasierFir", { Small = 1 } },
			{ "NobleFir", { Small = 1 } },
			{ "BlueSpruce", { Small = 1 } },
		})
		busy.layout.placements.p1 = medium()
		local busyOk, busyReason = PlacementService.storeBack(busy, "p1")
		expect.falsy(busyOk)
		expect.equal(busyReason, "NoFreeBay")
		expect.truthy(busy.layout.placements.p1)

		local packed = stateWithBays({
			{ "DouglasFir", { Medium = 8 } },
			{ "FrasierFir", { Small = 9 } },
			{ "NobleFir", { Small = 9 } },
			{ "BlueSpruce", { Small = 4 } },
		})
		packed.layout.placements.p1 = medium()
		local packedOk, packedReason = PlacementService.storeBack(packed, "p1")
		expect.falsy(packedOk)
		expect.equal(packedReason, "StorageFull")
		expect.equal(packed.bays[1].counts.Medium, 8)
		expect.truthy(packed.layout.placements.p1)
	end)

	t.test("rejects a changed bay or too few trees", function()
		local state = stateWithBays({ { "DouglasFir", { Medium = 2 } } })
		local changed, changedReason = placeAt(state, "placement:changed", 1, "FrasierFir", -35, -13)
		expect.falsy(changed)
		expect.equal(changedReason, "BayChanged")
		local short, shortReason = placeAt(state, "placement:short", 1, "DouglasFir", -35, -20, 3)
		expect.falsy(short)
		expect.equal(shortReason, "NotEnoughTrees")
		expect.equal(state.bays[1].counts.Medium, 2)
		expect.equal(state.bays[1].speciesId, "DouglasFir")
		expect.equal(placementCount(state), 0)
	end)

	t.test("legacy placements without a transform do not block spacing", function()
		local state = stateWithBays({ { "DouglasFir", { Medium = 1 } } })
		state.layout.placements.legacy_1 = { speciesId = "DouglasFir", sizeId = "Medium" }
		local ok = placeAt(state, "placement:legacy", 1, "DouglasFir", -35, -13)
		expect.truthy(ok)
		expect.equal(placementCount(state), 2)
	end)
end
