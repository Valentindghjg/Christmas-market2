--!strict
-- CM2-A1: the pure Advent calendar maths (UTC dates, window, doors, rewards, validation).
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local AdventCalendar = require(Shared:WaitForChild("AdventCalendar"))
	local GameConfig = require(Shared:WaitForChild("GameConfig"))
	local expect = t.expect

	local DEC_1 = 1796083200 -- 2026-12-01 00:00 UTC
	local DEC_3_NOON = 1796299200 -- 2026-12-03 12:00 UTC
	local DEC_25 = 1798156800 -- 2026-12-25 00:00 UTC

	local function expectDate(now: number, year: number, month: number, day: number)
		local date = AdventCalendar.dateOf(now)
		expect.equal(date.year, year)
		expect.equal(date.month, month)
		expect.equal(date.day, day)
	end

	t.test("converts UTC dates both ways", function()
		expect.equal(AdventCalendar.utcTime(2026, 12, 1, 0), DEC_1)
		expect.equal(AdventCalendar.utcTime(2026, 12, 3, 12), DEC_3_NOON)
		expect.equal(AdventCalendar.utcTime(2026, 12, 25, 0), DEC_25)
		expect.equal(AdventCalendar.utcTime(2024, 2, 29, 0), 1709164800)
		expect.equal(AdventCalendar.utcTime(2027, 12, 2, 0), 1827705600)
		expectDate(1796083199, 2026, 11, 30)
		expectDate(1709164800, 2024, 2, 29)
	end)

	t.test("opens on Dec 1 and closes after Dec 24", function()
		local before = AdventCalendar.view(nil, DEC_1 - 1)
		expect.equal(before.phase, "Before")
		expect.equal(before.today, 0)
		local first = AdventCalendar.view(nil, DEC_1)
		expect.equal(first.phase, "Open")
		expect.equal(first.today, 1)
		local last = AdventCalendar.view(nil, DEC_25 - 1)
		expect.equal(last.phase, "Open")
		expect.equal(last.today, 24)
		local ended = AdventCalendar.view(nil, DEC_25)
		expect.equal(ended.phase, "Ended")
		expect.equal(ended.today, 0)
	end)

	t.test("rejects a future door and opens missed doors", function()
		local locked, lockedError = AdventCalendar.open(nil, DEC_3_NOON, 4)
		expect.equal(locked, nil)
		expect.equal(lockedError, "DoorLocked")
		local afterFirst, firstError = AdventCalendar.open(nil, DEC_3_NOON, 1)
		expect.equal(firstError, nil)
		local afterThird, thirdError = AdventCalendar.open(afterFirst, DEC_3_NOON, 3)
		expect.equal(thirdError, nil)
		expect.equal(afterThird.year, 2026)
		expect.equal(afterThird.opened, 5)
		local view = AdventCalendar.view(afterThird, DEC_3_NOON)
		expect.equal(view.opened, 5)
		expect.equal(view.claimable, 1)
	end)

	t.test("opens each door once per year", function()
		local opened = AdventCalendar.open(nil, DEC_3_NOON, 1)
		local again, againError = AdventCalendar.open(opened, DEC_3_NOON, 1)
		expect.equal(again, nil)
		expect.equal(againError, "AlreadyClaimed")
		local lastYear, lastYearError = AdventCalendar.open({ year = 2025, opened = 1 }, DEC_3_NOON, 1)
		expect.equal(lastYearError, nil)
		expect.equal(lastYear.year, 2026)
		expect.equal(lastYear.opened, 1)
	end)

	t.test("refuses everything outside the window", function()
		for _, now in { DEC_25, DEC_1 - 1 } do
			local result, code = AdventCalendar.open(nil, now, 1)
			expect.equal(result, nil)
			expect.equal(code, "CalendarClosed")
		end
		for _, door in { 0, 25, 1.5, 0 / 0 } do
			local result, code = AdventCalendar.open(nil, DEC_3_NOON, door)
			expect.equal(result, nil)
			expect.equal(code, "InvalidDoor")
		end
	end)

	t.test("has 24 rising doors of five shapes", function()
		local config = GameConfig.Advent
		expect.equal(#config.Doors, 24)
		local last = { cash = 0, reputation = 0, boostSeconds = 0 }
		for door = 1, 24 do
			local reward = AdventCalendar.rewardFor(door)
			local special = door == 6 or door == 24
			if special then
				expect.truthy(reward.cash > 0)
				expect.truthy(reward.reputation > 0)
				expect.equal(reward.boostSeconds, 0)
				expect.truthy(reward.decor ~= nil)
			else
				local kinds = 0
				for _, field in { "cash", "reputation", "boostSeconds" } do
					local amount = (reward :: any)[field]
					if amount > 0 then
						kinds += 1
						expect.truthy(amount > last[field])
						last[field] = amount
					end
				end
				if reward.decor ~= nil then
					kinds += 1
				end
				expect.equal(kinds, 1)
			end
			if reward.decor ~= nil then
				expect.truthy(table.find(config.DecorItems, reward.decor) ~= nil)
			end
		end
	end)

	t.test("validates the stored field and the decor inventory", function()
		expect.truthy(AdventCalendar.isValid(nil))
		expect.truthy(AdventCalendar.isValid({ year = 2026, opened = 0 }))
		expect.falsy(AdventCalendar.isValid({ year = 2026, opened = 2 ^ 24 }))
		expect.falsy(AdventCalendar.isValid({ year = 1999, opened = 0 }))
		expect.falsy(AdventCalendar.isValid({ year = 2026, opened = 0, extra = true }))
		expect.truthy(AdventCalendar.isDecorInventory({}))
		expect.truthy(AdventCalendar.isDecorInventory({ AdventWreath = 1 }))
		expect.falsy(AdventCalendar.isDecorInventory({ Nope = 1 }))
		expect.falsy(AdventCalendar.isDecorInventory({ AdventWreath = 0 }))
		expect.falsy(AdventCalendar.isDecorInventory({ AdventWreath = 1000 }))
		expect.falsy(AdventCalendar.isDecorInventory({ AdventWreath = 1.5 }))
	end)
end
