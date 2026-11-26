--!strict
-- CM2-G11: the quest board of one save (shared/QuestBoard.lua).
return function(t)
	local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local GameConfig = require(Shared:WaitForChild("GameConfig"))
	local QuestBoard = require(Shared:WaitForChild("QuestBoard"))
	local expect = t.expect

	local ROTATION = GameConfig.Quests.RotationSeconds

	-- A state holding only the board, at period `period` (time = the period's start + 10).
	local function stateAt(period: number): (any, number)
		return { quests = QuestBoard.new(period) }, period * ROTATION + 10
	end

	t.test("builds the board for a period", function()
		local expectedVariant = { [0] = 1, [1] = 2, [2] = 3, [3] = 1 }
		for period = 0, 3 do
			local variant = expectedVariant[period]
			for slot = 1, 3 do
				local quest = QuestBoard.questFor(period, slot)
				local definition = GameConfig.Quests.Slots[slot][variant]
				expect.equal(quest.slot, slot)
				expect.equal(quest.kind, definition.kind)
				expect.equal(quest.target, definition.target)
				expect.equal(quest.sizeId, definition.sizeId)
				expect.equal(quest.rewardCash, definition.rewardCash)
				expect.equal(quest.rewardReputation, 0)
			end
			local bonus = QuestBoard.questFor(period, 4)
			expect.equal(bonus.kind, "SellTrees")
			expect.equal(bonus.target, 15)
			expect.equal(bonus.rewardCash, 550)
			expect.equal(bonus.rewardReputation, 100)
		end
		expect.equal(QuestBoard.questFor(0, 1).textKey, "questOrderTrees")
		expect.equal(QuestBoard.questFor(0, 2).textKey, "questSalesCash")
		expect.equal(QuestBoard.questFor(0, 3).textKey, "questSellSmall")
		expect.equal(QuestBoard.questFor(1, 3).textKey, "questSellMedium")
		expect.equal(QuestBoard.questFor(2, 3).textKey, "questSellLarge")
		expect.equal(QuestBoard.questFor(0, 4).textKey, "questSellTrees")
		expect.equal(QuestBoard.periodOf(ROTATION - 1), 0)
		expect.equal(QuestBoard.periodOf(ROTATION), 1)
	end)

	t.test("counts orders, sales and sizes", function()
		local state, now = stateAt(0)
		QuestBoard.note(state, now, "OrderTrees", 4)
		expect.equal(state.quests.progress[1], 4)
		QuestBoard.noteSale(state, now, 120, "Small")
		expect.equal(state.quests.progress[2], 120)
		expect.equal(state.quests.progress[3], 1)
		expect.equal(state.quests.progress[4], 1)
		QuestBoard.noteSale(state, now, 80, "Medium")
		expect.equal(state.quests.progress[2], 200)
		expect.equal(state.quests.progress[3], 1)
		expect.equal(state.quests.progress[4], 2)
		QuestBoard.note(state, now, "OrderTrees", 0)
		QuestBoard.note(state, now, "OrderTrees", 1.5)
		expect.equal(state.quests.progress[1], 4)
	end)

	t.test("caps progress at the target and stops after a claim", function()
		local state, now = stateAt(0)
		QuestBoard.note(state, now, "OrderTrees", 25)
		expect.equal(state.quests.progress[1], 10)
		local ok = QuestBoard.claim(state, now, 1, 0)
		expect.truthy(ok)
		state.quests.progress[1] = 3
		QuestBoard.note(state, now, "OrderTrees", 5)
		expect.equal(state.quests.progress[1], 3)
		QuestBoard.note(state, now, "SalesCash", 999999)
		expect.equal(state.quests.progress[2], 2800)
	end)

	t.test("claims once and returns the configured reward", function()
		local state, now = stateAt(0)
		QuestBoard.note(state, now, "OrderTrees", 10)
		local ok, reward = QuestBoard.claim(state, now, 1, 0)
		expect.truthy(ok)
		expect.equal(reward.slot, 1)
		expect.equal(reward.cash, 150)
		expect.equal(reward.reputation, 0)
		expect.equal(state.quests.claimed[1], true)
		local again, code = QuestBoard.claim(state, now, 1, 0)
		expect.falsy(again)
		expect.equal(code, "AlreadyClaimed")
	end)

	t.test("locks the bonus until quests 1-3 are claimed", function()
		local state, now = stateAt(0)
		state.quests.progress = { 10, 2800, 3, 15 }
		local locked, lockedCode = QuestBoard.claim(state, now, 4, 0)
		expect.falsy(locked)
		expect.equal(lockedCode, "BonusLocked")
		for slot = 1, 3 do
			expect.truthy((QuestBoard.claim(state, now, slot, 0)))
		end
		local ok, reward = QuestBoard.claim(state, now, 4, 0)
		expect.truthy(ok)
		expect.equal(reward.slot, 4)
		expect.equal(reward.cash, 550)
		expect.equal(reward.reputation, 100)
	end)

	t.test("rotation drops progress and pays nothing offline", function()
		local period = 5
		local state = { quests = QuestBoard.new(period) }
		state.quests.progress = { 15, 2000, 3, 15 }
		local later = (period + 2) * ROTATION + 10
		local ok, code = QuestBoard.claim(state, later, 1, period + 2)
		expect.falsy(ok)
		expect.equal(code, "Incomplete")
		expect.equal(state.quests.period, period + 2)
		for slot = 1, 4 do
			expect.equal(state.quests.progress[slot], 0)
			expect.equal(state.quests.claimed[slot], false)
		end
	end)

	t.test("rejects a claim for another period", function()
		local state, now = stateAt(3)
		state.quests.progress = { 10, 2800, 3, 0 }
		local ok, code = QuestBoard.claim(state, now, 1, 2)
		expect.falsy(ok)
		expect.equal(code, "QuestsRotated")
		expect.equal(state.quests.period, 3)
		expect.equal(state.quests.claimed[1], false)
		expect.equal(state.quests.progress[1], 10)
	end)

	t.test("views without mutating and validates the stored board", function()
		local state = { quests = QuestBoard.new(1) }
		state.quests.progress = { 15, 0, 0, 0 }
		local now = 4 * ROTATION + 100
		local view = QuestBoard.view(state, now)
		expect.equal(view.period, 4)
		expect.equal(view.endsIn, ROTATION - 100)
		expect.equal(view.claimable, 0)
		expect.equal(#view.quests, 4)
		expect.equal(view.quests[1].progress, 0)
		expect.equal(view.quests[4].locked, true)
		expect.equal(state.quests.period, 1)
		expect.equal(state.quests.progress[1], 15)
		local current = { quests = QuestBoard.new(4) }
		current.quests.progress = { 10, 0, 0, 0 }
		local currentView = QuestBoard.view(current, now)
		expect.equal(currentView.claimable, 0)
		current.quests.progress = { 20, 0, 0, 0 }
		currentView = QuestBoard.view(current, now)
		expect.equal(currentView.quests[1].complete, true)
		expect.equal(currentView.claimable, 1)

		expect.truthy(QuestBoard.isValid(QuestBoard.new(0)))
		expect.falsy(QuestBoard.isValid(nil))
		expect.falsy(
			QuestBoard.isValid({ period = -1, progress = { 0, 0, 0, 0 }, claimed = { false, false, false, false } })
		)
		expect.falsy(
			QuestBoard.isValid({ period = 0, progress = { 0, 0, 0 }, claimed = { false, false, false, false } })
		)
		expect.falsy(
			QuestBoard.isValid({ period = 0, progress = { 0, 0, 0, 1.5 }, claimed = { false, false, false, false } })
		)
		expect.falsy(
			QuestBoard.isValid({ period = 0, progress = { 0, 0, 0, -1 }, claimed = { false, false, false, false } })
		)
		expect.falsy(
			QuestBoard.isValid({ period = 0, progress = { 0, 0, 0, 0 }, claimed = { false, false, false, 1 } })
		)
		expect.falsy(QuestBoard.isValid({
			period = 0,
			progress = { 0, 0, 0, 0 },
			claimed = { false, false, false, false },
			x = 1,
		}))
	end)
end
