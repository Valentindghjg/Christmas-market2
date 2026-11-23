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
end
