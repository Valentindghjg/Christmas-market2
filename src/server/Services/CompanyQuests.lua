--!strict
-- Quest board and reward grants of the company service (CM2-G11, docs/plans/CM2-G11.md): a
-- mixin that CompanyStateService installs. The board lives in the company record
-- (shared/QuestBoard.lua, schema 21); Quest.Claim pays inside the company's critical section.
-- grantReward pays a player's daily reward (DailyRewardService) or Advent door (AdventService,
-- CM2-A1) into the active save.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BusinessState = require(Shared:WaitForChild("BusinessState"))
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local QuestBoard = require(Shared:WaitForChild("QuestBoard"))
local SaveProfile = require(Shared:WaitForChild("SaveProfile"))
local ShopConfig = require(Shared:WaitForChild("ShopConfig"))

local CompanyQuests = {}

local REWARD_KINDS = { DailyReward = true, AdventReward = true }
local MEMBER_ROLES = { Owner = true, Member = true }
local SLOT_COUNT = 4

local function isAmount(value: unknown): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value == math.floor(value)
		and value >= 0
end

function CompanyQuests.install(CompanyStateService)
	-- Quest.Claim inside _dispatch (any member; idempotency and limits come from handle).
	function CompanyStateService:_claimQuest(state, payload): (boolean, any)
		local ok, reward = QuestBoard.claim(state, self._clock(), payload.slot, payload.period)
		if not ok then
			return false, reward
		end
		state.cash += reward.cash
		state.reputation += reward.reputation
		BusinessState.record(state, "QuestReward", reward.cash)
		return true, { slot = reward.slot, cash = reward.cash, reputation = reward.reputation }
	end

	-- Read-only board view for the company summary; never stores a fresh board.
	function CompanyStateService:questView(state)
		return QuestBoard.view(state, self._clock())
	end

	-- Pays a reward of `kind` to a member's live save. Returns (true, {revision, cash,
	-- reputation, boostSeconds, decorCount}) with the new totals, or (false, errorCode).
	-- extras (CM2-A1): Cash Rush seconds clamped at BoostCapSeconds (boostSeconds = the seconds
	-- applied) and one decor item into decorInventory (decorCount = its new count).
	function CompanyStateService:grantReward(
		companyId: string,
		userId: number,
		kind: string,
		cash: number,
		reputation: number,
		extras: { boostSeconds: number?, decorId: string? }?
	): (boolean, any)
		if not REWARD_KINDS[kind] or not isAmount(cash) or not isAmount(reputation) then
			return false, "InvalidReward"
		end
		local boostSeconds = if extras ~= nil then extras.boostSeconds else nil
		local decorId = if extras ~= nil then extras.decorId else nil
		if
			boostSeconds ~= nil
			and (not isAmount(boostSeconds) or (boostSeconds :: number) > ShopConfig.BoostCapSeconds)
		then
			return false, "InvalidReward"
		end
		if
			decorId ~= nil and (type(decorId) ~= "string" or table.find(GameConfig.Advent.DecorItems, decorId) == nil)
		then
			return false, "InvalidReward"
		end
		if not self:isAvailable(companyId) then
			return false, "CompanyUnavailable"
		end
		local session = self._sessions[companyId]
		local entered, ok, result = self:_withSession(companyId, session, function(state)
			if not MEMBER_ROLES[state.members[SaveProfile.userIdText(userId)]] then
				return false, "Forbidden"
			end
			state.cash += cash
			state.reputation += reputation
			local boostApplied = 0
			if boostSeconds ~= nil then
				local before = state.purchases.boosts.CashX2
				local after = math.min(before + boostSeconds, ShopConfig.BoostCapSeconds)
				state.purchases.boosts.CashX2 = after
				boostApplied = after - before
			end
			local decorCount = nil
			if decorId ~= nil then
				decorCount = math.min((state.decorInventory[decorId] or 0) + 1, GameConfig.Advent.DecorMaxCount)
				state.decorInventory[decorId] = decorCount
			end
			BusinessState.record(state, kind, cash)
			state.revision += 1
			session.dirty = true
			return true,
				{
					revision = state.revision,
					cash = state.cash,
					reputation = state.reputation,
					boostSeconds = boostApplied,
					decorCount = decorCount,
				}
		end)
		if not entered then
			return false, ok
		end
		return ok, result
	end

	-- Studio test instrument only (StudioTestService): sets a slot's progress on the current
	-- board, capped at its target.
	function CompanyStateService:setQuestProgressForTest(companyId: string, slot: number, progress: number): boolean
		if not isAmount(slot) or slot < 1 or slot > SLOT_COUNT or not isAmount(progress) then
			return false
		end
		local session = self._sessions[companyId]
		if not session or not session.healthy then
			return false
		end
		local entered = self:_withSession(companyId, session, function(state)
			QuestBoard.refresh(state, self._clock())
			local quest = QuestBoard.questFor(state.quests.period, slot)
			state.quests.progress[slot] = math.min(quest.target, progress)
			session.dirty = true
			state.revision += 1
			return true
		end)
		return entered
	end

	-- Studio test instrument only (StudioTestService): moves the stored board one period back
	-- (minimum 0), keeping progress and claims, so the next access rotates it.
	function CompanyStateService:ageQuestBoardForTest(companyId: string): boolean
		local session = self._sessions[companyId]
		if not session or not session.healthy then
			return false
		end
		local entered = self:_withSession(companyId, session, function(state)
			state.quests.period = math.max(0, QuestBoard.periodOf(self._clock()) - 1)
			session.dirty = true
			return true
		end)
		return entered
	end
end

return CompanyQuests
