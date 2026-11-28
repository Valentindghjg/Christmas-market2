--!strict
return function(t)
	local Protocol = require(game:GetService("ReplicatedStorage").Shared.Protocol)
	local expect = t.expect

	t.test("accepts the payload-free summary query", function()
		expect.truthy(Protocol.validateRequest({
			version = 1,
			requestId = "summary_1",
			action = Protocol.Actions.CompanyGetSummary,
			payload = {},
		}))
	end)

	t.test("rejects client state fields on summary query", function()
		local ok, reason = Protocol.validateRequest({
			version = 1,
			requestId = "summary_2",
			action = Protocol.Actions.CompanyGetSummary,
			payload = { cash = 999999 },
		})
		expect.falsy(ok)
		expect.equal(reason, "UnexpectedField")
	end)

	-- CM2-25/26 part b: the Employees tab reads only the summary's staff table.
	t.test("summary lists staff roles, capacity and the break area", function()
		local BusinessState = require(game:GetService("ReplicatedStorage").Shared.BusinessState)
		local Service = require(game:GetService("ServerScriptService").Server.Services.CompanyStateService)
		local records = {}
		local service = Service.new({
			load = function(_, companyId, ownerUserId)
				records[companyId] = records[companyId] or BusinessState.new(companyId, ownerUserId)
				return records[companyId], nil
			end,
			save = function()
				return true, nil
			end,
			release = function()
				return true, nil
			end,
		}, function()
			return 100
		end)
		local state = service:loadCompany("personal:42", 42)
		state.cash = 5000
		local function request(requestId: string, action: string, payload)
			return service:handle(
				"personal:42",
				42,
				{ version = 1, requestId = requestId, action = action, payload = payload }
			)
		end
		expect.truthy(request("staff_hire_1", "Employee.Hire", { employeeId = "Cashier" }).ok)
		local response = request("staff_summary_1", "Company.GetSummary", {})
		expect.truthy(response.ok)
		local staff = response.data.staff
		expect.equal(staff.capacity, 2)
		expect.equal(staff.hiredCount, 1)
		expect.equal(staff.breakArea.x, state.breakArea.x)
		expect.equal(staff.breakArea.z, state.breakArea.z)
		expect.equal(staff.breakArea.rotation, state.breakArea.rotation)
		expect.equal(#staff.roles, 3)
		expect.equal(staff.roles[1].id, "Cashier")
		expect.equal(staff.roles[2].id, "LotWorker")
		expect.equal(staff.roles[3].id, "LotManager")
		expect.equal(staff.roles[1].hired, true)
		expect.equal(staff.roles[1].status, "Arriving")
		expect.equal(staff.roles[1].energy, 100)
		expect.equal(staff.roles[1].hireCost, 1200)
		expect.equal(staff.roles[2].hired, false)
		expect.equal(staff.roles[2].status, nil)
		expect.equal(staff.roles[2].hireCost, 1800)
		expect.equal(staff.roles[2].locked, false)
		expect.equal(staff.roles[3].locked, true)
		expect.equal(staff.roles[3].hireCost, 1250000)
	end)

	-- CM2-G9a: the summary's ladder rows come from Progression.rows, as the purchase check does.
	t.test("summary carries the ladder rows", function()
		local BusinessState = require(game:GetService("ReplicatedStorage").Shared.BusinessState)
		local Service = require(game:GetService("ServerScriptService").Server.Services.CompanyStateService)
		local service = Service.new({
			load = function(_, companyId, ownerUserId)
				return BusinessState.new(companyId, ownerUserId), nil
			end,
			save = function()
				return true, nil
			end,
			release = function()
				return true, nil
			end,
		}, function()
			return 100
		end)
		expect.truthy(service:loadCompany("personal:42", 42))
		local response = service:handle(
			"personal:42",
			42,
			{ version = 1, requestId = "ladder_summary_1", action = "Company.GetSummary", payload = {} }
		)
		expect.truthy(response.ok)
		local ladder = response.data.progression
		local lotNext = ladder.lotExpansion.next
		expect.equal(lotNext.target, 1)
		expect.equal(#lotNext.rows, 1)
		expect.equal(lotNext.rows[1].id, "Cash")
		expect.equal(lotNext.rows[1].have, 84)
		expect.equal(lotNext.rows[1].need, 1200)
		expect.equal(lotNext.rows[1].met, false)
		local ids = {}
		for _, row in ipairs(ladder.hq.next.rows) do
			table.insert(ids, row.id)
		end
		expect.equal(table.concat(ids, ","), "LotExpansion,ParkingTier,Reputation,Cash")
	end)

	-- CM2-V2-ORD: the Supplier tab groups, prices and times orders from these read-only fields.
	t.test("summary deliveries carry group, cost and ETA", function()
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local BusinessState = require(ReplicatedStorage.Shared.BusinessState)
		local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
		local Service = require(game:GetService("ServerScriptService").Server.Services.CompanyStateService)
		local now = 100
		local service = Service.new({
			load = function(_, companyId, ownerUserId)
				return BusinessState.new(companyId, ownerUserId), nil
			end,
			save = function()
				return true, nil
			end,
			release = function()
				return true, nil
			end,
		}, function()
			return now
		end)
		local state = service:loadCompany("personal:42", 42)
		state.cash = 5000
		local placed = service:handle("personal:42", 42, {
			version = 1,
			requestId = "order_summary_1",
			action = "Supplier.PlaceOrder",
			payload = {
				lines = {
					{ speciesId = "DouglasFir", sizeId = "Medium", quantity = 2 },
					{ speciesId = "NobleFir", sizeId = "Small", quantity = 1 },
				},
			},
		})
		expect.truthy(placed.ok)
		local function deliveries()
			local response = service:handle("personal:42", 42, {
				version = 1,
				requestId = "order_summary_q" .. tostring(now),
				action = "Company.GetSummary",
				payload = {},
			})
			expect.truthy(response.ok)
			return response.data.deliveries
		end
		local list = deliveries()
		expect.equal(#list, 2)
		expect.equal(string.sub(list[1].groupId, 1, 6), "order:")
		expect.equal(list[1].groupId, list[2].groupId)
		for _, entry in ipairs(list) do
			expect.equal(entry.createdAt, 100)
			expect.equal(entry.cost, GameConfig.wholesaleFor(entry.speciesId, entry.sizeId) * entry.quantity)
			expect.equal(entry.arrivesIn, GameConfig.DeliverySeconds)
		end
		now = 110
		for _, entry in ipairs(deliveries()) do
			expect.equal(entry.arrivesIn, GameConfig.DeliverySeconds - 10)
		end
	end)
end
