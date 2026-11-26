--!strict
-- CM2-G12b: sanitizing the published leaderboard rows and the value formats per board.
return function(t)
	local LeaderboardView =
		require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("LeaderboardView"))
	local expect = t.expect

	t.test("sanitizes rows", function()
		local rows = LeaderboardView.rows({
			{ rank = 3, name = "Carol", value = 30 },
			{ rank = 0, name = "Zero", value = 99 },
			{ rank = 11, name = "Eleven", value = 1 },
			{ rank = 1.5, name = "Half", value = 50 },
			{ rank = 1, name = "Alice", value = 100 },
			{ rank = 1, name = "Duplicate", value = 100 },
			{ rank = 4, name = "NaN", value = 0 / 0 },
			{ rank = 5, name = "Negative", value = -1 },
			"not a table",
			{ rank = 2, name = string.rep("x", 33), value = 60 },
		})
		expect.equal(#rows, 3)
		expect.equal(rows[1].rank, 1)
		expect.equal(rows[1].name, "Alice")
		expect.equal(rows[2].rank, 2)
		expect.equal(rows[2].name, nil)
		expect.equal(rows[2].value, 60)
		expect.equal(rows[3].rank, 3)
		expect.equal(rows[3].name, "Carol")
		expect.equal(#LeaderboardView.rows(nil), 0)
		expect.equal(#LeaderboardView.rows("[]"), 0)
	end)

	t.test("formats values per board", function()
		local key, text = LeaderboardView.valueText("CashEarned", 12345)
		expect.equal(key, "hudCash")
		expect.equal(text, "12,345")
		key, text = LeaderboardView.valueText("Reputation", 1234)
		expect.equal(key, "lbReputation")
		expect.equal(text, "1,234")
		key, text = LeaderboardView.valueText("HoursPlayed", 5400)
		expect.equal(key, "lbHours")
		expect.equal(text, "1.5")
		key, text = LeaderboardView.valueText("RobuxSpent", 1234)
		expect.equal(key, "lbRobux")
		expect.equal(text, "1,234")
		expect.equal(LeaderboardView.rankText(0), nil)
		expect.equal(LeaderboardView.rankText(4), "4")
	end)
end
