--!strict
-- CM2-G15: customer reviews, the lot rating and lot likes.
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local BusinessState = require(Shared:WaitForChild("BusinessState"))
	local GameConfig = require(Shared:WaitForChild("GameConfig"))
	local Localization = require(Shared:WaitForChild("Localization"))
	local Reviews = require(Shared:WaitForChild("Reviews"))
	local expect = t.expect

	t.test("stars fall as service time grows", function()
		local expected = {
			{ 0, 5 },
			{ 30, 5 },
			{ 31, 4 },
			{ 50, 4 },
			{ 51, 3 },
			{ 75, 3 },
			{ 76, 2 },
			{ 105, 2 },
			{ 106, 1 },
			{ 10000, 1 },
		}
		for _, case in ipairs(expected) do
			expect.equal(Reviews.starsFor(case[1]), case[2])
		end
		local previous = Reviews.starsFor(0)
		for seconds = 1, 200 do
			local stars = Reviews.starsFor(seconds)
			expect.truthy(stars <= previous)
			previous = stars
		end
	end)

	t.test("slow service earns less reputation", function()
		local gains = GameConfig.Reviews.ReputationByStars
		for index = 2, #gains do
			expect.truthy(gains[index] > gains[index - 1])
		end
		expect.equal(gains[3], 6)
		expect.equal(gains[5], 9)
	end)

	t.test("review text names the slower part", function()
		expect.equal(Reviews.textKeyFor(5, 0, 10), "reviewGreat")
		expect.equal(Reviews.textKeyFor(4, 20, 20), "reviewGood")
		expect.equal(Reviews.textKeyFor(3, 40, 15), "reviewSlowService")
		expect.equal(Reviews.textKeyFor(3, 15, 40), "reviewSlowTree")
		expect.equal(Reviews.textKeyFor(2, 60, 30), "reviewSlowService")
		expect.equal(Reviews.textKeyFor(2, 30, 60), "reviewSlowTree")
		expect.equal(Reviews.textKeyFor(1, 0, 200), "reviewVerySlow")
		for key in pairs(Reviews.TextKeys) do
			expect.equal(type(Localization.Strings.en[key]), "string")
			expect.equal(type(Localization.Strings.de[key]), "string")
		end
	end)

	t.test("rating averages the recent window", function()
		local state = BusinessState.new("save:42_x", 42)
		expect.equal(Reviews.ratingTenths(state), nil)
		for _, stars in ipairs({ 5, 4, 3 }) do
			Reviews.record(state, stars)
		end
		expect.equal(Reviews.ratingTenths(state), 40)
		local window = GameConfig.Reviews.RatingWindow
		local full = BusinessState.new("save:42_x", 42)
		for _ = 1, window + 5 do
			Reviews.record(full, 4)
		end
		expect.equal(#full.reviews.recent, window)
		expect.equal(full.reviews.count, window + 5)
		expect.truthy(BusinessState.validate(full))
	end)

	t.test("a lot can be liked once per UTC day", function()
		local state = BusinessState.new("save:42_x", 42)
		local ok, total = Reviews.like(state, 77, 10)
		expect.truthy(ok)
		expect.equal(total, 1)
		local again, reason = Reviews.like(state, 77, 10)
		expect.falsy(again)
		expect.equal(reason, "AlreadyLikedToday")
		local nextDay, nextTotal = Reviews.like(state, 77, 11)
		expect.truthy(nextDay)
		expect.equal(nextTotal, 2)
		local entries = 0
		for _ in pairs(state.likes.today) do
			entries += 1
		end
		expect.equal(entries, 1)
		expect.truthy(BusinessState.validate(state))
	end)

	t.test("nobody likes their own save", function()
		local state = BusinessState.new("save:42_x", 42)
		local own, ownReason = Reviews.like(state, 42, 10)
		expect.falsy(own)
		expect.equal(ownReason, "OwnLot")
		state.saveSize = "Duo"
		expect.truthy(BusinessState.addMember(state, 55))
		local member, memberReason = Reviews.like(state, 55, 10)
		expect.falsy(member)
		expect.equal(memberReason, "OwnLot")
		expect.equal(state.likes.total, 0)
	end)

	t.test("likes per day are capped", function()
		local state = BusinessState.new("save:42_x", 42)
		local limit = GameConfig.Reviews.MaxLikesPerDay
		for index = 1, limit do
			expect.truthy(Reviews.like(state, 1000 + index, 10))
		end
		local full, reason = Reviews.like(state, 999999, 10)
		expect.falsy(full)
		expect.equal(reason, "LikesFull")
		expect.equal(state.likes.total, limit)
	end)

	t.test("utcDay switches at UTC midnight", function()
		expect.equal(Reviews.utcDay(86399), 0)
		expect.equal(Reviews.utcDay(86400), 1)
	end)
end
