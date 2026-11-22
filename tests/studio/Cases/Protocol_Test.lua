--!strict
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local Protocol = require(Shared:WaitForChild("Protocol"))
	local expect = t.expect

	-- Server accepts only a bounded, typed supplier request.
	t.test("validates supplier order shape", function()
		local ok = Protocol.validateRequest({
			version = 1,
			requestId = "order_1234",
			action = Protocol.Actions.SupplierPlaceOrder,
			payload = { speciesId = "FrasierFir", sizeId = "Medium", quantity = 2 },
		})
		expect.truthy(ok)
	end)

	-- A caller cannot inject a wholesale price into a request.
	t.test("rejects fabricated client price", function()
		local ok, reason = Protocol.validateRequest({
			version = 1,
			requestId = "order_5678",
			action = Protocol.Actions.SupplierPlaceOrder,
			payload = { speciesId = "FrasierFir", sizeId = "Medium", quantity = 2, unitCost = 0 },
		})
		expect.falsy(ok)
		expect.equal(reason, "UnexpectedField")
	end)

	-- The same request ID cannot open a second financial mutation.
	t.test("deduplicates request IDs", function()
		local state = BusinessState.new("personal:42", 42)
		local first = Protocol.beginRequest(state, "order_9999", Protocol.Actions.SupplierPlaceOrder, 100)
		local second, previous = Protocol.beginRequest(state, "order_9999", Protocol.Actions.SupplierPlaceOrder, 101)
		expect.truthy(first)
		expect.falsy(second)
		expect.equal(previous.requestId, "order_9999")
	end)

	-- Floods are limited per player and action.
	t.test("rate limits repeated actions", function()
		local limiter = Protocol.newRateLimiter(2, 10)
		expect.truthy(Protocol.allowRequest(limiter, 42, "Supplier.PlaceOrder", 100))
		expect.truthy(Protocol.allowRequest(limiter, 42, "Supplier.PlaceOrder", 101))
		expect.falsy(Protocol.allowRequest(limiter, 42, "Supplier.PlaceOrder", 102))
	end)

	t.test("forgets a departed player's rate-limit buckets", function()
		local limiter = Protocol.newRateLimiter(1, 10)
		expect.truthy(Protocol.allowRequest(limiter, 42, "Supplier.PlaceOrder", 100))
		expect.truthy(Protocol.allowRequest(limiter, 420, "Supplier.PlaceOrder", 100))
		Protocol.forgetUser(limiter, 42)
		expect.truthy(Protocol.allowRequest(limiter, 42, "Supplier.PlaceOrder", 101))
		expect.falsy(Protocol.allowRequest(limiter, 420, "Supplier.PlaceOrder", 101))
	end)

	local function stockPayload(overrides: { [string]: any }?)
		local payload: { [string]: any } = {
			bay = 1,
			speciesId = "FrasierFir",
			sizeId = "Medium",
			x = 0,
			z = 0,
			rotation = 0,
			count = 1,
			gap = 0.5,
		}
		for key, value in pairs(overrides or {}) do
			payload[key] = value
		end
		return payload
	end

	local function stockRequest(action: string, payload)
		return Protocol.validateRequest({
			version = 1,
			requestId = "place_1234",
			action = action,
			payload = payload,
		})
	end

	-- Extra keys could otherwise reach the saved record or carry non-serializable values.
	t.test("rejects placement transforms with extra or non-finite fields", function()
		local function place(payload)
			return stockRequest(Protocol.Actions.StockPlace, payload)
		end
		expect.truthy(place(stockPayload()))
		expect.falsy(place(stockPayload({ junk = "x" })))
		expect.falsy(place(stockPayload({ x = 0 / 0 })))
		expect.falsy(place(stockPayload({ rotation = "90" })))
		local missing = stockPayload()
		missing.rotation = nil
		expect.falsy(place(missing))
	end)

	-- CM2-G14: Stock.Place and Stock.Store accept only bounded, typed fields.
	t.test("validates Stock.Place and Stock.Store payloads", function()
		local function placeReason(overrides): string?
			local _, reason = stockRequest(Protocol.Actions.StockPlace, stockPayload(overrides))
			return reason
		end
		expect.truthy(stockRequest(Protocol.Actions.StockPlace, stockPayload()))
		expect.truthy(
			stockRequest(
				Protocol.Actions.StockPlace,
				stockPayload({ bay = 4, count = 10, rotation = 315, gap = 4, x = -200, z = 200 })
			)
		)
		expect.equal(placeReason({ bay = 0 }), "InvalidBay")
		expect.equal(placeReason({ bay = 5 }), "InvalidBay")
		expect.equal(placeReason({ count = 0 }), "InvalidQuantity")
		expect.equal(placeReason({ count = 11 }), "InvalidQuantity")
		expect.equal(placeReason({ rotation = 30 }), "InvalidPlacement")
		expect.equal(placeReason({ rotation = 360 }), "InvalidPlacement")
		expect.equal(placeReason({ gap = 0.3 }), "InvalidPlacement")
		expect.equal(placeReason({ gap = 4.5 }), "InvalidPlacement")
		expect.equal(placeReason({ x = 0 / 0 }), "InvalidPlacement")
		expect.equal(placeReason({ z = 200.5 }), "InvalidPlacement")
		expect.equal(placeReason({ speciesId = "Pine" }), "UnknownSpecies")
		expect.equal(placeReason({ sizeId = "Huge" }), "InvalidSize")
		expect.equal(placeReason({ cost = 0 }), "UnexpectedField")
		local function storeReason(payload): string?
			local _, reason = stockRequest(Protocol.Actions.StockStore, payload)
			return reason
		end
		expect.truthy(stockRequest(Protocol.Actions.StockStore, { placementId = "placement:abc:1" }))
		expect.equal(storeReason({ placementId = "" }), "InvalidPlacementId")
		expect.equal(storeReason({ placementId = string.rep("a", 97) }), "InvalidPlacementId")
		expect.equal(storeReason({ placementId = 5 }), "InvalidPlacementId")
		expect.equal(storeReason({ placementId = "placement:abc:1", bay = 1 }), "InvalidPlacementId")
	end)

	t.test("removed actions are unknown", function()
		for _, action in { "Delivery.Unload", "Inventory.Place", "Inventory.Pickup" } do
			local ok, reason = Protocol.validateRequest({
				version = 1,
				requestId = "removed_1234",
				action = action,
				payload = {},
			})
			expect.falsy(ok)
			expect.equal(reason, "UnknownAction")
		end
	end)

	t.test("rejects unknown quest IDs before they reach the company lock", function()
		local ok, reason = Protocol.validateRequest({
			version = 1,
			requestId = "quest_1234",
			action = Protocol.Actions.QuestClaim,
			payload = { questId = "FreeMoney" },
		})
		expect.falsy(ok)
		expect.equal(reason, "InvalidQuest")
	end)
	-- G1/G5 actions accept only bounded integers and known items.
	t.test("validates order carry, load and sell-back payloads", function()
		local function check(action, payload)
			return Protocol.validateRequest({
				version = 1,
				requestId = "g1_request",
				action = action,
				payload = payload,
			})
		end
		expect.truthy(check(Protocol.Actions.OrderCarry, { orderNumber = 3 }))
		expect.truthy(check(Protocol.Actions.OrderLoad, { orderNumber = 3, carNumber = 3 }))
		expect.truthy(check(Protocol.Actions.OrderRelease, { orderNumber = 3 }))
		local _, fractional = check(Protocol.Actions.OrderCarry, { orderNumber = 1.5 })
		expect.equal(fractional, "InvalidOrderNumber")
		local _, missingCar = check(Protocol.Actions.OrderLoad, { orderNumber = 3 })
		expect.equal(missingCar, "InvalidOrderNumber")
		local _, injected = check(Protocol.Actions.OrderLoad, { orderNumber = 3, carNumber = 3, reputation = 99 })
		expect.equal(injected, "UnexpectedField")
		expect.truthy(
			check(Protocol.Actions.SupplierSellBack, { speciesId = "NobleFir", sizeId = "Small", quantity = 2 })
		)
		local _, refund = check(
			Protocol.Actions.SupplierSellBack,
			{ speciesId = "NobleFir", sizeId = "Small", quantity = 2, refund = 1000 }
		)
		expect.equal(refund, "UnexpectedField")
		local _, zero =
			check(Protocol.Actions.SupplierSellBack, { speciesId = "NobleFir", sizeId = "Small", quantity = 0 })
		expect.equal(zero, "InvalidQuantity")
	end)

	-- CM2-S1: Save.* requests are typed, bounded and carry only their own fields.
	local SAVE_ID = "42_" .. string.rep("ab", 8)
	local function saveRequest(action, payload)
		return Protocol.validateSaveRequest({
			version = 1,
			requestId = "save_request_1",
			action = action,
			payload = payload,
		})
	end

	t.test("validates save action payloads", function()
		local Save = Protocol.SaveActions
		expect.truthy(saveRequest(Save.List, {}))
		expect.truthy(saveRequest(Save.Create, {}))
		expect.truthy(saveRequest(Save.Create, { name = "" }))
		expect.truthy(saveRequest(Save.Create, { name = "My Lot" }))
		expect.truthy(saveRequest(Save.Rename, { saveId = SAVE_ID, name = "New Name" }))
		expect.truthy(saveRequest(Save.Delete, { saveId = SAVE_ID, confirmName = "new name" }))
		expect.truthy(saveRequest(Save.Play, { saveId = SAVE_ID }))
		local _, badId = saveRequest(Save.Play, { saveId = "42_NOTHEX" })
		expect.equal(badId, "InvalidSaveId")
		local _, missingId = saveRequest(Save.Rename, { name = "x" })
		expect.equal(missingId, "InvalidSaveId")
		local _, longName = saveRequest(Save.Rename, { saveId = SAVE_ID, name = string.rep("a", 101) })
		expect.equal(longName, "InvalidName")
		local _, longCreate = saveRequest(Save.Create, { name = string.rep("a", 101) })
		expect.equal(longCreate, "InvalidName")
		local _, numberConfirm = saveRequest(Save.Delete, { saveId = SAVE_ID, confirmName = 5 })
		expect.equal(numberConfirm, "InvalidName")
		expect.truthy(saveRequest(Save.Rename, { saveId = SAVE_ID, name = string.rep("a", 100) }))
	end)

	t.test("rejects unknown or extra save fields", function()
		local _, extra = saveRequest(Protocol.SaveActions.Play, { saveId = SAVE_ID, cash = 1000 })
		expect.equal(extra, "UnexpectedField")
		local _, listExtra = saveRequest(Protocol.SaveActions.List, { all = true })
		expect.equal(listExtra, "UnexpectedField")
		local _, unknown = saveRequest("Save.Steal", {})
		expect.equal(unknown, "UnknownAction")
		local _, crossed = Protocol.validateRequest({
			version = 1,
			requestId = "save_request_2",
			action = Protocol.SaveActions.List,
			payload = {},
		})
		expect.equal(crossed, "UnknownAction")
		local _, envelope = Protocol.validateSaveRequest({
			version = 2,
			requestId = "save_request_3",
			action = "Save.List",
			payload = {},
		})
		expect.equal(envelope, "UnsupportedVersion")
	end)

	-- CM2-S2: co-op save actions validate every new field.
	t.test("validates co-op save payloads", function()
		local Save = Protocol.SaveActions
		expect.truthy(saveRequest(Save.Join, { code = "12345" }))
		expect.truthy(saveRequest(Save.LeaveTeam, { saveId = SAVE_ID }))
		expect.truthy(saveRequest(Save.Team, {}))
		expect.truthy(saveRequest(Save.RemoveMember, { userId = 43 }))
		expect.truthy(saveRequest(Save.RegenerateCode, {}))
		expect.truthy(saveRequest(Save.SetSize, { size = "Trio" }))
		expect.truthy(saveRequest(Save.Create, { name = "Team Lot", size = "Quad" }))
		local _, hugeCreate = saveRequest(Save.Create, { size = "Huge" })
		expect.equal(hugeCreate, "InvalidSize")
		local _, hugeSet = saveRequest(Save.SetSize, { size = "Huge" })
		expect.equal(hugeSet, "InvalidSize")
		local _, missingSize = saveRequest(Save.SetSize, {})
		expect.equal(missingSize, "InvalidSize")
		for _, code in { "01234", "1234", 12345, "12a45" } do
			local _, reason = saveRequest(Save.Join, { code = code })
			expect.equal(reason, "InvalidInviteCode")
		end
		for _, userId in { 0, 1.5, "7" } do
			local _, reason = saveRequest(Save.RemoveMember, { userId = userId })
			expect.equal(reason, "InvalidUserId")
		end
		local _, badLeave = saveRequest(Save.LeaveTeam, { saveId = "nope" })
		expect.equal(badLeave, "InvalidSaveId")
		local _, extra = saveRequest(Save.Join, { code = "12345", saveId = SAVE_ID })
		expect.equal(extra, "UnexpectedField")
		local _, teamExtra = saveRequest(Save.Team, { all = true })
		expect.equal(teamExtra, "UnexpectedField")
	end)

	-- CM2-S3: Save.Teleport carries a saveId or a code; a teammate search a co-op size.
	t.test("validates teleport and finder payloads", function()
		local Save = Protocol.SaveActions
		expect.truthy(saveRequest(Save.Teleport, { saveId = SAVE_ID }))
		expect.truthy(saveRequest(Save.Teleport, { code = "12345" }))
		local _, both = saveRequest(Save.Teleport, { saveId = SAVE_ID, code = "12345" })
		expect.equal(both, "InvalidTeleportTarget")
		local _, neither = saveRequest(Save.Teleport, {})
		expect.equal(neither, "InvalidTeleportTarget")
		local _, badId = saveRequest(Save.Teleport, { saveId = "42_NOTHEX" })
		expect.equal(badId, "InvalidSaveId")
		for _, code in { "01234", "1234", 12345 } do
			local _, reason = saveRequest(Save.Teleport, { code = code })
			expect.equal(reason, "InvalidInviteCode")
		end
		expect.truthy(saveRequest(Save.FinderStart, {}))
		expect.truthy(saveRequest(Save.FinderStart, { size = "Quad" }))
		expect.truthy(saveRequest(Save.FinderStart, { size = "Duo" }))
		for _, size in { "Solo", "Huge", 2 } do
			local _, reason = saveRequest(Save.FinderStart, { size = size })
			expect.equal(reason, "InvalidSize")
		end
		expect.truthy(saveRequest(Save.FinderStop, {}))
		expect.truthy(saveRequest(Save.FinderList, {}))
		expect.truthy(saveRequest(Save.FinderJoin, { saveId = SAVE_ID }))
		local _, badJoin = saveRequest(Save.FinderJoin, { saveId = "nope" })
		expect.equal(badJoin, "InvalidSaveId")
		for _, case in
			{
				{ Save.Teleport, { saveId = SAVE_ID, cash = 1 } },
				{ Save.FinderStart, { size = "Duo", name = "x" } },
				{ Save.FinderStop, { all = true } },
				{ Save.FinderList, { all = true } },
				{ Save.FinderJoin, { saveId = SAVE_ID, code = "12345" } },
			}
		do
			local _, reason = saveRequest(case[1], case[2])
			expect.equal(reason, "UnexpectedField")
		end
	end)

	t.test("counts recent requests without recording them", function()
		local limiter = Protocol.newRateLimiter(3, 60)
		expect.equal(Protocol.recentCount(limiter, 7, "fail", 100), 0)
		expect.truthy(Protocol.allowRequest(limiter, 7, "fail", 100))
		expect.truthy(Protocol.allowRequest(limiter, 7, "fail", 110))
		expect.equal(Protocol.recentCount(limiter, 7, "fail", 120), 2)
		expect.equal(Protocol.recentCount(limiter, 7, "fail", 120), 2)
		expect.equal(Protocol.recentCount(limiter, 8, "fail", 120), 0)
		-- Only entries newer than the window count.
		expect.equal(Protocol.recentCount(limiter, 7, "fail", 165), 1)
		expect.truthy(Protocol.allowRequest(limiter, 7, "fail", 165))
		expect.equal(Protocol.recentCount(limiter, 7, "fail", 165), 2)
	end)

	t.test("accepts Douglas Fir orders and rejects the display spelling as an ID", function()
		local ok = Protocol.validateRequest({
			version = 1,
			requestId = "order_douglas",
			action = Protocol.Actions.SupplierPlaceOrder,
			payload = { speciesId = "DouglasFir", sizeId = "Small", quantity = 1 },
		})
		expect.truthy(ok)
		local fraserOk, reason = Protocol.validateRequest({
			version = 1,
			requestId = "order_fraser",
			action = Protocol.Actions.SupplierPlaceOrder,
			payload = { speciesId = "FraserFir", sizeId = "Small", quantity = 1 },
		})
		expect.falsy(fraserOk)
		expect.equal(reason, "UnknownSpecies")
	end)
end
