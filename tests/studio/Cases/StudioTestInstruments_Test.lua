--!strict
-- CM2-G20: the Studio test instruments of CompanyStateService (visit, staff, snapshot).
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local GameConfig = require(Shared:WaitForChild("GameConfig"))
	local Service = require(
		game:GetService("ServerScriptService")
			:WaitForChild("Server")
			:WaitForChild("Services")
			:WaitForChild("CompanyStateService")
	)
	local expect = t.expect
	local COMPANY = "personal:42"

	local function fakePersistence()
		local records = {}
		return {
			load = function(_, companyId, ownerUserId)
				records[companyId] = records[companyId] or BusinessState.new(companyId, ownerUserId)
				return records[companyId], nil
			end,
			save = function(_, companyId, state)
				records[companyId] = state
				return true, nil
			end,
			release = function()
				return true, nil
			end,
		}
	end

	local function request(id: string, action: string, payload)
		return { version = 1, requestId = id, action = action, payload = payload }
	end

	-- A company with `quantity` Medium Douglas Fir ordered, delivered into bay 1 and displayed.
	local function displayedCompany(quantity: number)
		expect.truthy(quantity <= 8)
		local now = 100
		local service = Service.new(fakePersistence(), function()
			return now
		end, function()
			return 0
		end)
		local state = service:loadCompany("personal:42", 42)
		local ordered = service:handle(
			COMPANY,
			42,
			request(
				"order_0001",
				"Supplier.PlaceOrder",
				{ speciesId = "DouglasFir", sizeId = "Medium", quantity = quantity }
			)
		)
		expect.truthy(ordered.ok)
		now += GameConfig.DeliverySeconds
		local reconciled, delivered = service:reconcileDeliveriesAll()
		expect.truthy(reconciled)
		expect.equal(delivered, 1)
		for index = 1, quantity do
			-- Slots (-35, -13), (-28, -13), (-35, -6), (-28, -6), ...
			local x = if index % 2 == 1 then -35 else -28
			local z = -13 + 7 * ((index - 1) // 2)
			local placed = service:handle(
				COMPANY,
				42,
				request("place_" .. string.format("%03d", index), "Stock.Place", {
					bay = 1,
					speciesId = "DouglasFir",
					sizeId = "Medium",
					x = x,
					z = z,
					rotation = 0,
					count = 1,
					gap = 0.5,
				})
			)
			expect.truthy(placed.ok)
		end
		return service, state
	end

	local function placementCount(state): number
		local count = 0
		for _ in pairs(state.layout.placements) do
			count += 1
		end
		return count
	end

	t.test("visitForTest sells a displayed tree and creates an order", function()
		local service, state = displayedCompany(1)
		expect.equal(placementCount(state), 1)
		local ok, orderNumber = service:visitForTest(COMPANY, 8)
		expect.truthy(ok)
		expect.equal(orderNumber, 1)
		expect.equal(state.sales, 1)
		expect.equal(placementCount(state), 0)
		local summary = service:getCustomerOrders(COMPANY)
		expect.equal(#summary.orders, 1)
	end)

	t.test("visitForTest reports a profile that cannot afford the tree (CM2-SALE2)", function()
		local service, state = displayedCompany(1)
		local ok, reason = service:visitForTest(COMPANY, 5)
		expect.falsy(ok)
		expect.equal(reason, "NoEligibleStock")
		expect.equal(state.sales, 0)
		expect.equal(placementCount(state), 1)
	end)

	t.test("visitForTest rejects invalid input", function()
		local service = displayedCompany(1)
		local zero, zeroReason = service:visitForTest(COMPANY, 0)
		expect.falsy(zero)
		expect.equal(zeroReason, "InvalidCustomer")
		local fraction, fractionReason = service:visitForTest(COMPANY, 1.5)
		expect.falsy(fraction)
		expect.equal(fractionReason, "InvalidCustomer")
		local unknown, unknownReason = service:visitForTest("personal:99", 8)
		expect.falsy(unknown)
		expect.equal(unknownReason, "CompanyUnavailable")
	end)

	t.test("visitForTest needs a free parking space", function()
		local service = displayedCompany(3)
		expect.truthy(service:setProgressionForTest(COMPANY, { parkingTier = 2 }))
		expect.truthy(service:visitForTest(COMPANY, 8))
		expect.truthy(service:visitForTest(COMPANY, 32))
		local ok, reason = service:visitForTest(COMPANY, 56)
		expect.falsy(ok)
		expect.equal(reason, "NoParking")
	end)

	t.test("setStaffForTest sets and clears a Lot Worker without touching cash", function()
		local service = Service.new(fakePersistence(), function()
			return 100
		end)
		local state = service:loadCompany("personal:42", 42)
		local cash = state.cash
		expect.truthy(service:setStaffForTest(COMPANY, "LotWorker", 1))
		expect.equal(state.staff.LotWorker, 1)
		expect.truthy(service:setStaffForTest(COMPANY, "LotWorker", 0))
		expect.equal(state.staff.LotWorker, 0)
		expect.equal(state.cash, cash)
		expect.falsy(service:setStaffForTest(COMPANY, "Janitor", 2))
		expect.falsy(service:setStaffForTest(COMPANY, "LotWorker", 2))
	end)

	t.test("snapshotForTest returns a detached copy", function()
		local service = Service.new(fakePersistence(), function()
			return 100
		end)
		service:loadCompany("personal:42", 42)
		local snapshot = service:snapshotForTest(COMPANY)
		expect.truthy(snapshot)
		local copy = snapshot :: any
		copy.stock["DouglasFir:Medium"] = 99
		copy.staff.LotWorker = 1
		local again = service:snapshotForTest(COMPANY) :: any
		expect.equal(again.stock["DouglasFir:Medium"], nil)
		expect.equal(again.staff.LotWorker, 0)
		expect.equal(service:snapshotForTest("personal:99"), nil)
	end)
end
