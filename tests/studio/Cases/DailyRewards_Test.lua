--!strict
-- CM2-G11: the daily reward streak maths (shared/DailyRewards.lua).
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local DailyRewards = require(Shared:WaitForChild("DailyRewards"))
	local expect = t.expect

	t.test("uses the server's UTC day", function()
		expect.equal(DailyRewards.dayOf(86399), 0)
		expect.equal(DailyRewards.dayOf(86400), 1)
		expect.equal(DailyRewards.secondsLeft(86399), 1)
	end)

	t.test("starts a new player on day 1", function()
		local status = DailyRewards.status(nil, 100)
		expect.truthy(status.claimable)
		expect.equal(status.nextIndex, 1)
	end)

	t.test("advances the streak on consecutive days and wraps after day 7", function()
		local daily = nil
		local expected = { 1, 2, 3, 4, 5, 6, 7, 1 }
		for offset = 0, 7 do
			local nextDaily, index = DailyRewards.claim(daily, 100 + offset)
			expect.truthy(nextDaily)
			expect.equal(index, expected[offset + 1])
			daily = nextDaily
		end
		expect.equal(daily.lastDay, 107)
		expect.equal(daily.streak, 1)
	end)

	t.test("resets the streak after a missed day", function()
		local nextDaily, index = DailyRewards.claim({ lastDay = 100, streak = 4 }, 102)
		expect.truthy(nextDaily)
		expect.equal(index, 1)
		expect.equal(nextDaily.streak, 1)
		expect.equal(nextDaily.lastDay, 102)
	end)

	t.test("rejects a second claim on the same day and a clock behind the claim", function()
		local daily = { lastDay = 100, streak = 3 }
		local sameDay, sameCode = DailyRewards.claim(daily, 100)
		expect.equal(sameDay, nil)
		expect.equal(sameCode, "AlreadyClaimed")
		local earlier, earlierCode = DailyRewards.claim(daily, 99)
		expect.equal(earlier, nil)
		expect.equal(earlierCode, "AlreadyClaimed")
		local status = DailyRewards.status(daily, 100)
		expect.falsy(status.claimable)
		expect.equal(status.nextIndex, 4)
	end)

	t.test("pays the observed table and doubles only for members", function()
		local cash = { 400, 500, 0, 700, 900, 0, 2500 }
		local reputation = { 0, 0, 150, 0, 0, 300, 0 }
		for index = 1, 7 do
			local reward = DailyRewards.rewardFor(index, false)
			expect.equal(reward.cash, cash[index])
			expect.equal(reward.reputation, reputation[index])
			expect.equal(reward.doubled, false)
			local doubled = DailyRewards.rewardFor(index, true)
			expect.equal(doubled.cash, cash[index] * 2)
			expect.equal(doubled.reputation, reputation[index] * 2)
			expect.equal(doubled.doubled, true)
		end
	end)

	t.test("validates the stored field and the group state", function()
		expect.truthy(DailyRewards.isValid(nil))
		expect.truthy(DailyRewards.isValid({ lastDay = 0, streak = 7 }))
		expect.falsy(DailyRewards.isValid({ lastDay = 5, streak = 0 }))
		expect.falsy(DailyRewards.isValid({ lastDay = 5, streak = 8 }))
		expect.falsy(DailyRewards.isValid({ lastDay = -1, streak = 1 }))
		expect.falsy(DailyRewards.isValid({ lastDay = 1.5, streak = 1 }))
		expect.falsy(DailyRewards.isValid({ lastDay = 5, streak = 1, extra = true }))
		expect.falsy(DailyRewards.isValid("daily"))
		expect.equal(DailyRewards.groupState(0, true), "Hidden")
		expect.equal(DailyRewards.groupState(5, false), "Join")
		expect.equal(DailyRewards.groupState(5, true), "Active")
	end)
end
