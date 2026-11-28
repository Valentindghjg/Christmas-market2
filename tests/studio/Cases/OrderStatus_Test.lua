--!strict
-- CM2-V2-ORD: grouping, memory and status of the Supplier tab's recent orders.
return function(t)
	local OrderStatus = require(game:GetService("ReplicatedStorage").Shared.OrderStatus)
	local expect = t.expect

	local function record(groupId: string, quantity: number, cost: number, createdAt: number, arrivesIn: number)
		return {
			orderId = groupId .. ":x",
			groupId = groupId,
			quantity = quantity,
			cost = cost,
			createdAt = createdAt,
			arrivesIn = arrivesIn,
		}
	end

	t.test("status boundaries", function()
		expect.equal(OrderStatus.status(6, false), "Preparing")
		expect.equal(OrderStatus.status(5, false), "InTransit")
		expect.equal(OrderStatus.status(0, false), "InTransit")
		expect.equal(OrderStatus.status(9, true), "Delivered")
	end)

	t.test("groups records of one order", function()
		local memory = {}
		OrderStatus.track(memory, { record("order:a", 3, 30, 10, 20), record("order:a", 2, 20, 10, 25) }, 0)
		local rows = OrderStatus.rows(memory, 0)
		expect.equal(#rows, 1)
		expect.equal(rows[1].quantity, 5)
		expect.equal(rows[1].cost, 50)
		expect.equal(rows[1].eta, 25)
	end)

	t.test("eta counts down to In Transit", function()
		local memory = {}
		OrderStatus.track(memory, { record("order:a", 1, 10, 1, 30) }, 0)
		local early = OrderStatus.rows(memory, 24.5)
		expect.equal(early[1].status, "Preparing")
		expect.equal(early[1].eta, 6)
		local late = OrderStatus.rows(memory, 25)
		expect.equal(late[1].status, "InTransit")
		expect.equal(late[1].eta, 5)
	end)

	t.test("vanished order becomes Delivered", function()
		local memory = {}
		OrderStatus.track(memory, { record("order:a", 4, 40, 1, 30) }, 0)
		OrderStatus.track(memory, {}, 10)
		local rows = OrderStatus.rows(memory, 10)
		expect.equal(#rows, 1)
		expect.equal(rows[1].status, "Delivered")
		expect.equal(rows[1].quantity, 4)
		expect.equal(rows[1].cost, 40)
	end)

	t.test("non-table deliveries change nothing", function()
		local memory = {}
		OrderStatus.track(memory, { record("order:a", 4, 40, 1, 30) }, 0)
		OrderStatus.track(memory, nil, 10)
		local rows = OrderStatus.rows(memory, 10)
		expect.equal(#rows, 1)
		expect.equal(rows[1].status, "Preparing")
	end)

	t.test("keeps the newest 4 delivered, newest first", function()
		local memory = {}
		local records = {}
		for index = 1, 6 do
			table.insert(records, record("order:" .. index, 1, 10, index, 30))
		end
		OrderStatus.track(memory, records, 0)
		OrderStatus.track(memory, {}, 40)
		local rows = OrderStatus.rows(memory, 40)
		expect.equal(#rows, 4)
		expect.equal(rows[1].groupId, "order:6")
		expect.equal(rows[2].groupId, "order:5")
		expect.equal(rows[3].groupId, "order:4")
		expect.equal(rows[4].groupId, "order:3")
		local count = 0
		for _ in pairs(memory) do
			count += 1
		end
		expect.equal(count, 4)
	end)

	t.test("skips malformed records", function()
		local memory = {}
		OrderStatus.track(memory, {
			{ quantity = 2, cost = 10 },
			record("order:nan", 0 / 0, 10, 1, 5),
			record("order:zero", 0, 10, 1, 5),
			"not a record",
		}, 0)
		expect.equal(#OrderStatus.rows(memory, 0), 0)
	end)
end
