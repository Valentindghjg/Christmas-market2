--!strict
-- Quest board of one save (CM2-G11, docs/plans/CM2-G11.md): 3 rotating quests plus a bonus,
-- stored as `quests = { period, progress {x4}, claimed {x4} }` (schema 21, index 4 = bonus).
-- Progress grows only from play events, so offline time never pays; a stale board is replaced
-- on the next note or claim. This module never touches cash and must not require
-- BusinessState (cycle); CompanyQuests pays and records the reward.
local GameConfig = require(script.Parent.GameConfig)

local Config = GameConfig.Quests

local QuestBoard = {}

local SLOT_COUNT = 4
local BONUS_SLOT = 4

export type Board = { period: number, progress: { number }, claimed: { boolean } }

local function isInteger(value: unknown): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value == math.floor(value)
end

local function textKeyFor(definition: any): string
	if definition.kind == "SellSize" then
		return "questSell" .. definition.sizeId
	end
	return "quest" .. definition.kind
end

local function isArrayOf(value: any, check: (unknown) -> boolean): boolean
	if type(value) ~= "table" then
		return false
	end
	local count = 0
	for key, entry in pairs(value) do
		if not isInteger(key) or key < 1 or key > SLOT_COUNT or not check(entry) then
			return false
		end
		count += 1
	end
	return count == SLOT_COUNT
end

local function bonusUnlocked(board: Board): boolean
	for slot = 1, SLOT_COUNT - 1 do
		if not board.claimed[slot] then
			return false
		end
	end
	return true
end

function QuestBoard.periodOf(now: number): number
	return math.floor(now / Config.RotationSeconds)
end

function QuestBoard.new(period: number): Board
	return { period = period, progress = { 0, 0, 0, 0 }, claimed = { false, false, false, false } }
end

function QuestBoard.questFor(period: number, slot: number)
	local definition = if slot == BONUS_SLOT then Config.Bonus else Config.Slots[slot][(period % 3) + 1]
	return {
		slot = slot,
		kind = definition.kind,
		sizeId = definition.sizeId,
		target = definition.target,
		rewardCash = definition.rewardCash,
		rewardReputation = definition.rewardReputation or 0,
		textKey = textKeyFor(definition),
	}
end

function QuestBoard.isValid(quests: any): boolean
	if type(quests) ~= "table" then
		return false
	end
	for key in pairs(quests) do
		if key ~= "period" and key ~= "progress" and key ~= "claimed" then
			return false
		end
	end
	return isInteger(quests.period)
		and quests.period >= 0
		and isArrayOf(quests.progress, function(value)
			return isInteger(value) and (value :: number) >= 0 and (value :: number) <= Config.MaxProgress
		end)
		and isArrayOf(quests.claimed, function(value)
			return type(value) == "boolean"
		end)
end

-- Replaces a board from another period by an empty one for the current period.
function QuestBoard.refresh(state: any, now: number): boolean
	local period = QuestBoard.periodOf(now)
	if type(state.quests) == "table" and state.quests.period == period then
		return false
	end
	state.quests = QuestBoard.new(period)
	return true
end

function QuestBoard.note(state: any, now: number, kind: string, amount: number, sizeId: string?)
	QuestBoard.refresh(state, now)
	if not isInteger(amount) or amount < 1 then
		return
	end
	local board: Board = state.quests
	for slot = 1, SLOT_COUNT do
		local quest = QuestBoard.questFor(board.period, slot)
		if quest.kind == kind and not board.claimed[slot] and (kind ~= "SellSize" or quest.sizeId == sizeId) then
			board.progress[slot] = math.min(quest.target, board.progress[slot] + amount)
		end
	end
end

function QuestBoard.noteSale(state: any, now: number, salePrice: number, sizeId: string)
	QuestBoard.note(state, now, "SalesCash", salePrice)
	QuestBoard.note(state, now, "SellTrees", 1)
	QuestBoard.note(state, now, "SellSize", 1, sizeId)
end

function QuestBoard.claim(state: any, now: number, slot: number, period: number): (boolean, any)
	QuestBoard.refresh(state, now)
	local board: Board = state.quests
	if period ~= board.period then
		return false, "QuestsRotated"
	end
	if board.claimed[slot] then
		return false, "AlreadyClaimed"
	end
	if slot == BONUS_SLOT and not bonusUnlocked(board) then
		return false, "BonusLocked"
	end
	local quest = QuestBoard.questFor(board.period, slot)
	if board.progress[slot] < quest.target then
		return false, "Incomplete"
	end
	board.claimed[slot] = true
	return true, { slot = slot, cash = quest.rewardCash, reputation = quest.rewardReputation }
end

-- Read-only: a stale stored board is shown as the fresh board of the current period.
function QuestBoard.view(state: any, now: number)
	local current = QuestBoard.periodOf(now)
	local stored = state.quests
	local board: Board = if type(stored) == "table" and stored.period == current
		then stored
		else QuestBoard.new(current)
	local unlocked = bonusUnlocked(board)
	local rows = {}
	local claimable = 0
	for slot = 1, SLOT_COUNT do
		local quest = QuestBoard.questFor(board.period, slot)
		local progress = board.progress[slot]
		local complete = progress >= quest.target
		local locked = slot == BONUS_SLOT and not unlocked
		if complete and not board.claimed[slot] and not locked then
			claimable += 1
		end
		rows[slot] = {
			slot = quest.slot,
			kind = quest.kind,
			sizeId = quest.sizeId,
			target = quest.target,
			rewardCash = quest.rewardCash,
			rewardReputation = quest.rewardReputation,
			textKey = quest.textKey,
			progress = progress,
			claimed = board.claimed[slot],
			complete = complete,
			locked = locked,
		}
	end
	return {
		period = board.period,
		endsIn = (board.period + 1) * Config.RotationSeconds - now,
		claimable = claimable,
		quests = rows,
	}
end

return QuestBoard
