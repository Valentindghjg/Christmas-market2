--!strict
-- CM2-45: the event schedule, its window, the countdown parts and the saved purchases' shape.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local AdventCalendar = require(Shared:WaitForChild("AdventCalendar"))
	local EventCalendar = require(Shared:WaitForChild("EventCalendar"))
	local EventConfig = require(Shared:WaitForChild("EventConfig"))
	local GameConfig = require(Shared:WaitForChild("GameConfig"))
	local ShopConfig = require(Shared:WaitForChild("ShopConfig"))
	local expect = t.expect

	local NOV_29_NOON = 1795953600 -- 2026-11-29 12:00 UTC

	local function isInteger(value: unknown): boolean
		return type(value) == "number" and value == math.floor(value)
	end

	t.test("has a valid, sorted schedule", function()
		local previousEnd = -math.huge
		local decorIds = {}
		for _, event in ipairs(EventConfig.Events) do
			expect.truthy(ShopConfig.isKey(event.id))
			expect.truthy(event.startsAt < event.endsAt)
			expect.truthy(event.startsAt >= previousEnd)
			previousEnd = event.endsAt
			expect.truthy(#event.items <= EventConfig.MaxItemsPerEvent)
			for _, item in ipairs(event.items) do
				expect.truthy(ShopConfig.isKey(item.key))
				expect.truthy(isInteger(item.price) and item.price > 0)
				expect.truthy(isInteger(item.limit) and item.limit >= 1 and item.limit <= EventConfig.MaxBuyCount)
				for _, decor in ipairs(item.decor) do
					expect.falsy(decorIds[decor.id])
					decorIds[decor.id] = true
					expect.equal(table.find(GameConfig.Advent.DecorItems, decor.id), nil)
					expect.truthy(isInteger(decor.count) and decor.count >= 1)
					expect.truthy(EventConfig.isDecorItem(decor.id))
				end
			end
			for _, key in ipairs(event.robuxItems) do
				local entry = ShopConfig.byKey(key)
				expect.truthy(entry)
				expect.equal((entry :: ShopConfig.Product).category, "Event")
			end
		end
		expect.truthy(#EventConfig.Events <= EventConfig.MaxEvents)
		local advent1 = EventConfig.Events[1]
		expect.equal(advent1.id, "Advent1")
		expect.equal(advent1.startsAt, AdventCalendar.utcTime(2026, 11, 29, 0))
		expect.equal(advent1.endsAt, AdventCalendar.utcTime(2026, 12, 6, 0))
		expect.falsy(EventConfig.isDecorItem("AdventWreath"))
		expect.falsy(EventConfig.isDecorItem(5))
	end)

	t.test("opens and closes on its dates", function()
		local advent1 = EventConfig.Events[1]
		expect.equal(EventCalendar.active(advent1.startsAt - 1), nil)
		expect.equal(EventCalendar.active(advent1.endsAt), nil)
		expect.equal(EventCalendar.active(0 / 0), nil)
		expect.equal(EventCalendar.active(math.huge), nil)
		expect.equal(EventCalendar.active(advent1.startsAt), advent1)
		expect.equal(EventCalendar.active(advent1.endsAt - 1), advent1)
		local open = EventCalendar.view(NOV_29_NOON)
		expect.equal(open.id, "Advent1")
		expect.equal(open.titleKey, "eventTitleAdvent1")
		expect.equal(open.endsIn, 561600)
		local outside = EventCalendar.view(advent1.endsAt)
		expect.equal(outside.id, "")
		expect.equal(outside.titleKey, "")
		expect.equal(outside.endsIn, 0)
		expect.equal(EventCalendar.item(advent1, "CandlelightPack"), advent1.items[1])
		expect.equal(EventCalendar.item(advent1, "EventTreeCandlelight"), nil)
		expect.equal(EventCalendar.item(advent1, 5), nil)
	end)

	t.test("formats the countdown", function()
		local function parts(seconds: number, key: string, first: number, second: number)
			local gotKey, gotFirst, gotSecond = EventCalendar.countdown(seconds)
			expect.equal(gotKey, key)
			expect.equal(gotFirst, first)
			expect.equal(gotSecond, second)
		end
		parts(561600, "eventEndsDays", 6, 12)
		parts(3600, "eventEndsHours", 1, 0)
		parts(3599, "eventEndsMinutes", 59, 59)
		parts(-5, "eventEndsMinutes", 0, 0)
		parts(0 / 0, "eventEndsMinutes", 0, 0)
	end)

	t.test("validates the stored purchases", function()
		expect.truthy(EventCalendar.isPurchases({}))
		expect.truthy(EventCalendar.isPurchases({ Advent1 = { CandlelightPack = 1 } }))
		expect.truthy(EventCalendar.isPurchases({ Later9 = { X = 2 } }))
		expect.falsy(EventCalendar.isPurchases(nil))
		expect.falsy(EventCalendar.isPurchases("Advent1"))
		expect.falsy(EventCalendar.isPurchases({ Advent1 = { CandlelightPack = 0 } }))
		expect.falsy(EventCalendar.isPurchases({ Advent1 = { CandlelightPack = 100 } }))
		expect.falsy(EventCalendar.isPurchases({ Advent1 = { CandlelightPack = 1.5 } }))
		expect.falsy(EventCalendar.isPurchases({ ["1bad"] = { CandlelightPack = 1 } }))
		expect.falsy(EventCalendar.isPurchases({ Advent1 = { ["1bad"] = 1 } }))
		expect.falsy(EventCalendar.isPurchases({ Advent1 = 1 }))
		local many = {}
		for index = 1, 65 do
			many["Event" .. index] = { Item = 1 }
		end
		expect.falsy(EventCalendar.isPurchases(many))
	end)

	t.test("accepts event decor in the decor crate", function()
		expect.truthy(AdventCalendar.isDecorInventory({ CandleArch = 3 }))
		expect.falsy(AdventCalendar.isDecorInventory({ Nope = 1 }))
	end)
end
