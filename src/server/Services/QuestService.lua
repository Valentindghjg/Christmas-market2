--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local BusinessState = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("BusinessState"))

local QuestService = {}

function QuestService.status(state, questId: string)
	local quest = GameConfig.Quests[questId]
	if not quest then
		return nil
	end
	local value = state[quest.metric]
	return {
		questId = questId,
		progress = type(value) == "number" and value or 0,
		target = quest.target,
		claimed = state.questClaims[questId] == true,
		complete = type(value) == "number" and value >= quest.target,
	}
end

function QuestService.claim(state, questId: string)
	local quest = GameConfig.Quests[questId]
	if not quest then
		return false, "UnknownQuest"
	end
	if state.questClaims[questId] then
		return false, "AlreadyClaimed"
	end
	if state[quest.metric] < quest.target then
		return false, "Incomplete"
	end
	state.questClaims[questId] = true
	state.cash += quest.rewardCash
	BusinessState.record(state, "QuestReward", quest.rewardCash)
	return true, quest.rewardCash
end

return QuestService
